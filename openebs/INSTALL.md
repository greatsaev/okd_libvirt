# openEBS cStor dynamic storage

## Installation

### 1. create cluster role and etc

`oc apply -f openebs-priv_psp.yaml `

`oc apply -f openebs-clusterrole.yaml `

`oc apply -f openebs-clusterrole-ass.yaml `


### 1.1. add scc 
`oc adm policy add-scc-to-user privileged -z openebs-cstor-csi-node-sa -n openebs`

`oc adm policy add-scc-to-user privileged -z openebs-cstor-csi -n openebs`

`oc adm policy add-scc-to-user privileged -z openebs-cstor-operator -n openebs`

### 2. install operators

`oc apply -f https://openebs.github.io/charts/openebs-operator.yaml `

`oc apply -f https://openebs.github.io/charts/cstor-operator.yaml `

### 3. check that all pods and deployements are up

`oc get all`

### 4. Enable iscsi on nodes

`for node in $(oc get nodes -l node-role.kubernetes.io/worker -o jsonpath='{.items[*].metadata.name}'); do oc debug node/${node} -- chroot /host systemctl enable --now iscsid; done`

### 5. Attach disks to worker nodes
### 6. Check that they are discovered by cstor:
`oc get bd`
#### 6.a Cleanup fs and bd:
`for node in $(oc get nodes -l node-role.kubernetes.io/worker -o jsonpath='{.items[*].metadata.name}'); do oc debug node/${node} -- chroot /host wipefs -fa /dev/vdb1 ; done`

`for node in $(oc get bd -o jsonpath='{.items[*].metadata.name}' -o jsonpath='{.items[*].metadata.name}'); do oc delete bd/${node} ; done`

#### 6.b. restart daemonsets to update bd info:
`oc rollout restart daemonset openebs-ndm-node-exporter`

`oc rollout restart daemonset openebs-ndm`

`oc rollout restart daemonset openebs-cstor-csi-node`

### 7. Enable dac_override selinux
on each node:

`echo "(allow iscsid_t self (capability (dac_override)))" > /etc/iscsiadm-fix.cil && semodule -i /etc/iscsiadm-fix.cil`
### 8. Create storage pool
`oc apply -f cspc-single.yaml`

`oc get cspc`
### 9. Create storage class
`oc apply -f sc.yaml`

## Change openshift registry storage from ephemeral to persistent
1. Create PVC
2. `oc edit configs.imageregistry.operator.openshift.io cluster`
```YAML
  storage:
    managementState: Managed
    pvc:
      claim: image-registry-storage
```

## Troubleshooting

### Can not drain node because of cstor-pool pods

  Delete all PodDisruptionBudgets assosiated with that pod and recreate them after node maintanance 