# Enable multicast for project:
- for OVN kubernetes (https://docs.openshift.com/container-platform/4.8/networking/ovn_kubernetes_network_provider/enabling-multicast.html)

`oc annotate namespace <namespace> k8s.ovn.org/multicast-enabled=true` 



- for openshift network plugin (https://docs.openshift.com/container-platform/4.6/networking/openshift_sdn/enabling-multicast.html)

`oc annotate netnamespace gitlab-th2 netnamespace.network.openshift.io/multicast-enabled=true` 

# Create network

`oc edit networks.operator.openshift.io cluster`

```YAML
spec:
  additionalNetworks:
  - name: macvlan-main
    namespace: gitlab-th2
    rawCNIConfig: '{ "cniVersion": "0.3.1", "name": "macvlan-main", "type": "macvlan",
      "mode": "bridge", "master": "ens9", "ipam": { "type": "host-local", "subnet":
      "224.224.224.0/24","rangeStart": "224.224.224.20","rangeEnd": "224.224.224.254"
      } }'
	  type: Raw

```

or

```YAML
spec:
  additionalNetworks:
  - name: host-dev
    namespace: gitlab-th2
    rawCNIConfig: '{ "cniVersion": "0.3.1", "name": "work-network", "type": "host-device",
      "device": "ens8", "ipam": { "type": "host-local", "subnet": "224.224.224.0/24", "rangeStart":
      "224.224.224.20", "rangeEnd": "224.224.224.254" }  }'
```

# Create network attachment

```YAML
apiVersion: "k8s.cni.cncf.io/v1"
kind: NetworkAttachmentDefinition
metadata:
  name: macvlan-main
spec:
  config: '{
      "cniVersion": "0.3.0",
      "type": "macvlan",
      "master": "ens8",
      "mode": "bridge",
      "ipam": {
        "type": "host-local",
        "subnet": "224.224.224.0/24",
        "rangeStart": "224.224.224.20",
        "rangeEnd": "224.224.224.254"
      }
    }'
```

or

```YAML 
apiVersion: "k8s.cni.cncf.io/v1"
kind: NetworkAttachmentDefinition
metadata:
  name: host-dev
spec:
  config: '{
  "cniVersion": "0.3.1",
  "name": "work-network",
  "type": "host-device",
  "device": "eth1",
  "ipam": {
    "type": "host-local",
    "subnet": "224.224.224.0/24",
    "rangeStart": "224.224.224.20",
    "rangeEnd": "224.224.224.254"
  }

}'
```

`oc apply -f nad.yaml`

# Create pod with network attached

```YAML
apiVersion: v1
kind: Pod
metadata:
  name: multicast-example-macvlan
  annotations:
    k8s.v1.cni.cncf.io/networks: macvlan-main
spec:
  containers:
  - name: example-multicast-pod
    command: ["iperf", "-s", "-u", "-B", "224.224.224.22%net1", "-i", "1"]
    image: bagoulla/iperf:2.0
  nodeSelector:
    eth: ens9
```

Links:

https://docs.openshift.com/container-platform/4.8/networking/multiple_networks/attaching-pod.html

https://access.redhat.com/documentation/en-us/openshift_container_platform/4.2/html-single/networking/index#configuring-host-device

https://github.com/spectriclabs/k8s-mcast-example

