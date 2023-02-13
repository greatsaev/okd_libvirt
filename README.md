# okd cluster installation

Install okd 4.11 on libvirt/KVM virtual machines with no DHCP server

## Prerequisites

1.  Download from https://github.com/okd-project/okd/releases
    1.  openshift-install-linux-&lt;VER&gt;.tar.gz 
    2.  openshift-client-linux
2.  Untar
3.  `sudo mv oc /usr/local/bin`
4.  Create DNS records:

| Service/Nodes | template | IP example | Name example |     |
| --- | --- | --- | --- | --- |
| Kubernetes API | api.&lt;cluster\_name&gt;.&lt;base\_domain&gt; | 10.100.170.2 | api.okd.example.com | A DNS A/AAAA or CNAME record, and a DNS PTR record, to identify the API load balancer. These records must be resolvable by both clients external to the cluster and from all the nodes within the cluster. |
| Kubernetes API | api-int.&lt;cluster\_name&gt;.&lt;base\_domain&gt; | 10.100.170.2 |     | A DNS A/AAAA or CNAME record, and a DNS PTR record, to internally identify the API load balancer. These records must be resolvable from all the nodes within the cluster. |
| Routes | *.apps.&lt;cluster\_name&gt;.&lt;base\_domain&gt; | 10.100.170.2 |     |     |
| Bootstrap machine | bootstrap.&lt;cluster\_name&gt;.&lt;base\_domain&gt;. | 10.100.170.3 | bootstrap.okd.example.com |     |
| Control plane machines | &lt;master&gt;&lt;n&gt;.&lt;cluster\_name&gt;.&lt;base\_domain&gt; | 10.100.170.4<br>10.100.170.5<br>10.100.170.6 | master0.okd.example.com<br>master1.okd.example.com<br>master2.okd.example.com |     |
| Compute machines | &lt;worker&gt;&lt;n&gt;.&lt;cluster\_name&gt;.&lt;base\_domain&gt; | 10.100.170.7<br>10.100.170.8 | worker0.okd.example.com<br>worker1.okd.example.com |     |

5.   Prepare Ignition configs for every node and helper machine(see [FCOS_INSTALLATION](FCOS.md))
6.   Deploy helper machine with [HAProxy](HAProxy.md)

## Procedure

1. Create cluster installation dir:
    `mkdir okd-test`
2. Create `okd-test/install-config.yaml` ([sample](https://docs.okd.io/latest/installing/installing_platform_agnostic/installing-platform-agnostic.html#installation-bare-metal-config-yaml_installing-platform-agnostic))

```YAML
apiVersion: v1
baseDomain: example.com
compute: 
- hyperthreading: Enabled 
  name: worker
  platform: {}
  replicas: 0 
controlPlane: 
  hyperthreading: Enabled 
  name: master
  replicas: 3 
metadata:
  name: okd 
networking:
  clusterNetwork:
  - cidr: 172.20.0.0/14 
    hostPrefix: 22 
  networkType: OVNKubernetes
  serviceNetwork: 
  - 172.30.0.0/16
platform:
  none: {} 
pullSecret: '{"auths":{"fake":{"auth":"aWQ6cGFzcwo="}}}' # Get normal from RedHat(https://console.redhat.com/openshift/downloads)
sshKey: 'ssh-rsa AAAA....' 
capabilities:
  baselineCapabilitySet: None
  additionalEnabledCapabilities:
  - openshift-samples
  - marketplace
 
```
3. `./openshift-install create manifests --dir okd-test`
4. For 3-nodes cluster skip this step:

	4.1. Open the `<installation_directory>/manifests/cluster-scheduler-02-config.yml` file.

	4.2. Locate the `mastersSchedulable` parameter and ensure that it is set to `false`

5. `./openshift-install create ignition-configs --dir okd-test` and make them readable( `chmod aug+r okd-test/*.ign`) for serving them via web server(e.g. `docker run -d -v okd-test:/web -p 8081:8080 halverneus/static-file-server:latest`)
6. Deploy bootstrap node:

	a. Ensure that web servers with Ignition configs are up and configs are available

	b. On VMH(libvirt/KVM host) run `sudo ./mk_fcos_vm.sh <VM_BOOTSTRAP> <IP_BOOTSTRAP>`

	c. Wait until `journalctl -b -f -u haproxy` on helper machine shows that `machine-config-server-22623/bootstrap is UP` and `api-server-6443/bootstrap is UP`

7. Deploy master nodes:

	a. wait until bootstrap node availble via HAProxy

	b.  On VMH run `sudo ./mk_fcos_vm.sh <VM_MASTER-N> <IP_MASTER-N>` three times for each master node

8. Deploy worker nodes: `sudo ./mk_fcos_vm.sh <VM_WORKER-N> <IP_WORKER-N` at least for two nodes(for 3-nodes cluster installation skip this step)
9. Wait for bootstrap to complete:
`./openshift-install --dir okd-test wait-for bootstrap-complete --log-level=debug`
10. After bootstrap is completed shutdown bootstrap node and remove it from HAProxy
11. Approve certificates requests to add worker nodes to cluster (https://docs.okd.io/latest/installing/installing_platform_agnostic/installing-platform-agnostic.html#installation-approve-csrs_installing-platform-agnostic):
	1. export `export KUBECONFIG=okd-test/auth/kubeconfig`
	2. Confirm that the cluster recognizes the machines:
	`oc get nodes`
	2. Review the pending CSRs and ensure that you see the client requests with the Pending or Approved status for each machine that you added to the cluster:
	`oc get csr`
	3. To approve all pending CSRs, run the following command:
	`oc get csr -o go-template='{{range .items}}{{if not .status}}{{.metadata.name}}{{"\n"}}{{end}}{{end}}' | xargs --no-run-if-empty oc adm certificate approve`
	4. wait some time and check again for pending certificates and sign them
12. Create ephemeral registry:
`oc patch configs.imageregistry.operator.openshift.io cluster --type merge --patch '{"spec":{"managementState":"Managed","storage":{"emptyDir":{}}}}'`
If you want the registry to store your container images, follow the official OKD 4 [documentation](https://docs.okd.io/latest/registry/configuring_registry_storage/configuring-registry-storage-baremetal.html) to configure a persistent storage backend. There are many backend you can use, so just choose the more appropriate for your infrastructure.
13. Verify that all machines have ready status:
`oc get nodes`
14. Wait for install to complete:

    14.1 Run following command
`./openshift-install --dir test wait-for install-complete --log-level=debug`

    14.2 Watch the cluster components come online:
`watch -n5 oc get clusteroperators`


# Next steps

- Enable [LDAP](ldap-sync/README.md)
- Install dynamically provisioned storage [cStor](openebs/INSTALL.md)
- Enable [multicast](multicast.md)
- Update default ingress certificate


----
Useful Links:

https://github.com/okd-project/okd/blob/master/Guides/UPI/libvirt/libvirt.md



