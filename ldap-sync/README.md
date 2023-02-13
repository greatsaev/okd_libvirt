## Create project `ldap_sync`
## set service account password
`oc create secret generic ldap-secret --from-literal=bindPassword=<LDAP SA password> -n openshift-config`
## create `ldap_cr.yaml`
```YAML
apiVersion: config.openshift.io/v1
kind: OAuth
metadata:
  name: cluster
spec:
  identityProviders:
  - name: ldapidp
    mappingMethod: claim
    type: LDAP
    ldap:
      attributes:
        id:
        - sAMAccountName
        email:
        - mail
        name:
        - displayName
        preferredUsername:
        - cn
      bindDN: "CN=okd,OU=ex,DC=ex,DC=example,DC=com"
      bindPassword:
        name: ldap-secret
      insecure: true
      url: "ldap://example.com:389/OU=ex,DC=ex,DC=example,DC=com?sAMAccountName?sub?(memberof=CN=okd-users,OU=Security_groups_admins,OU=ex,DC=ex,DC=example,DC=com)"
```
## Enable ldap IdP
`oc apply -f ldap_cr.yaml`

# Group sync
## Create `ldap-group-sync.yaml`
```YAML
kind: LDAPSyncConfig
apiVersion: v1
url: ldap://example.com:389
insecure: true
bindDN: CN=okd,OU=ex,DC=ex,DC=example,DC=com
bindPassword: '<LDAP SA password>'
groupUIDNameMapping:
  "CN=okd-admins,OU=Security_groups_admins,OU=ex,DC=ex,DC=example,DC=com": okd-admins
  "CN=okd-users,OU=Security_groups_admins,OU=ex,DC=ex,DC=example,DC=com": okd-users
augmentedActiveDirectory:
    groupsQuery:
        derefAliases: never
        pageSize: 0
    groupUIDAttribute: dn
    groupNameAttributes: [ cn ]
    usersQuery:
        baseDN: "OU=ex,DC=ex,DC=example,DC=com"
        scope: sub
        derefAliases: never
        filter: (objectclass=person)
        pageSize: 0
    userNameAttributes: [ cn ]
    groupMembershipAttributes: [ "memberOf:1.2.840.113556.1.4.1941:" ]
```
## Create `whitelist.txt`
```
CN=okd-admins,OU=Security_groups_admins,OU=ex,DC=ex,DC=example,DC=com
CN=okd-users,OU=Security_groups_admins,OU=ex,DC=ex,DC=example,DC=com
```

## Dry run to validate
`oc adm groups sync --whitelist=whitelist.txt --sync-config=ldap-group-sync.yaml`

## Apply
`oc adm groups sync --whitelist=whitelist.txt --sync-config=ldap-group-sync.yaml --confirm`


# Group sync automation
## Create a file rbac-ldap-group-sync.yaml
```YAML
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: ldap-group-sync
rules:
- apiGroups:
  - user.openshift.io
  resources:
  - groups
  verbs:
  - create
  - update
  - patch
  - delete
  - get
  - list
```
Then run
`oc apply rbac-ldap-group-sync.yaml`
## Create secret with SA password
`oc create secret generic ldap-secret --from-literal=bindPassword=<LDAP SA password>`
## Create Cluster Role Bindind, Task SA, sync config map
```YAML
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: ldap-group-syncer
subjects:
  - kind: ServiceAccount
    name: ldap-group-syncer
    namespace: ldap-sync
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: ldap-group-sync
```
`oc create -f ldap-sync-cluster-role-binding.yaml`
```YAML
kind: ServiceAccount
apiVersion: v1
metadata:
  name: ldap-group-syncer
  namespace: ldap-sync
```
`oc create -f ldap-sync-service-account.yaml`
```YAML
kind: ConfigMap
apiVersion: v1
metadata:
  name: ldap-group-syncer
  namespace: ldap-sync
data:
  sync.yaml: |
    kind: LDAPSyncConfig
    apiVersion: v1
    url: ldap://example.com:389
    insecure: true
    bindDN: CN=okd,OU=ex,DC=ex,DC=example,DC=com
    bindPassword:
      file: "/etc/secrets/bindPassword"
    groupUIDNameMapping:
      "CN=okd-admins,OU=Security_groups_admins,OU=ex,DC=ex,DC=example,DC=com": okd-admins
      "CN=okd-users,OU=Security_groups_admins,OU=ex,DC=ex,DC=example,DC=com": okd-users
    augmentedActiveDirectory:
        groupsQuery:
            derefAliases: never
            pageSize: 0
        groupUIDAttribute: dn
        groupNameAttributes: [ cn ]
        usersQuery:
            baseDN: "OU=ex,DC=ex,DC=example,DC=com"
            scope: sub
            derefAliases: never
            filter: (objectclass=person)
            pageSize: 0
        userNameAttributes: [ cn ]
        groupMembershipAttributes: [ "memberOf:1.2.840.113556.1.4.1941:" ]
```
`oc create -f ldap-sync-config-map.yaml`
```YAML
kind: ConfigMap
apiVersion: v1
metadata:
  name: ldap-group-syncer-wl
  namespace: ldap-sync
data:
  whitelist.txt: |
    CN=okd-admins,OU=Security_groups_admins,OU=ex,DC=ex,DC=example,DC=com
    CN=okd-users,OU=Security_groups_admins,OU=ex,DC=ex,DC=example,DC=com
```
`oc create -f ldap-whitelist-config-map.yaml`
## Create cronjob-ldap-group-sync.yaml
```YAML
apiVersion: batch/v1
kind: CronJob
metadata:
  name: ldap-group-sync
  namespace: ldap-sync
spec:
  schedule: '*/15 * * * *'
  concurrencyPolicy: Forbid
  suspend: false
  jobTemplate:
    spec:
      backoffLimit: 0
      ttlSecondsAfterFinished: 1800
      template:
        spec:
          containers:
            - name: ldap-group-sync
              image: "registry.redhat.io/openshift4/ose-cli:latest"
              command:
                - "/bin/bash"
                - "-c"
                - "oc adm groups sync --sync-config=/etc/config/sync.yaml --whitelist=/etc/config-wl/whitelist.txt --confirm"
              volumeMounts:
                - mountPath: "/etc/config"
                  name: "ldap-sync-volume"
                - mountPath: "/etc/secrets"
                  name: "ldap-bind-password"
                - mountPath: "/etc/config-wl"
                  name: "ldap-sync-whitelist"
          volumes:
            - name: "ldap-sync-volume"
              configMap:
                name: "ldap-group-syncer"
            - name: "ldap-sync-whitelist"
              configMap:
                name: "ldap-group-syncer-wl"
            - name: "ldap-bind-password"
              secret:
                secretName: "ldap-secret"
          restartPolicy: "Never"
          terminationGracePeriodSeconds: 30
          activeDeadlineSeconds: 500
          dnsPolicy: "ClusterFirst"
          serviceAccountName: "ldap-group-syncer"
```
Create task:
`oc apply -f cronjob-ldap-group-sync.yaml`

