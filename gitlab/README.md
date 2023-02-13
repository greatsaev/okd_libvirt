
# Install via helm:
`helm upgrade -n gitlab-th2 --install gitlab gitlab/gitlab   --timeout 600s --set certmanager-issuer.email=1@e.com --set global.hosts.domain=th2.apps.okd.example.com`

Wait till migration job done.

# TLS Encryption
## Create keys
### CA
If you use CA create key and certificate request:

`openssl genrsa -out gitlab.th2.apps.okd.example.com.key 2048`

`openssl req -new -key gitlab.th2.apps.okd.example.com.key -out srt-elk-test.example.com.csr`

Sign it in your CA and get certificates in Base64 format
## Create secret for Ingress
`oc create secret tls gitlab-th2 --key gitlab.th2.apps.okd.example.com.key --cert dgitlab.th2.apps.okd.example.com.cer`
## Set secret in `gitlab-webservice-default` Ingress
```YAML
spec:
  tls:
    - hosts:
        - gitlab.th2.apps.okd.example.com
      secretName: gitlab-th2
```

## Create gitlab.domain.com.crt
If custom CA is used add its cert there:
```
  -----BEGIN CERTIFICATE-----
  (Your primary SSL certificate: your_domain_name.cer)
  -----END CERTIFICATE-----
  -----BEGIN CERTIFICATE-----
  (Your intermediate certificate) (CA)
  -----END CERTIFICATE-----
  -----BEGIN CERTIFICATE-----
  (Your root certificate) If so present
  -----END CERTIFICATE-----
```
## Create secret for gitlab-runner with site and CA certs
`oc create secret generic git-th2-ca --from-file gitlab.th2.apps.okd.example.com.crt`
## Set secret in Deployment `gitlab-runner`
```YAML
          volumeMounts:
            - name: git-th2-ca
              mountPath: /home/gitlab-runner/.gitlab-runner/certs/
      volumes:
        - name: git-th2-ca
          secret:
            secretName: git-th2-ca
            defaultMode: 420
```

# Create route
Location: https://gitlab.th2.apps.okd.example.com

Service: gitlab-nginx-ingress-controller

Target port: https

TLS: passthrough, redirect insecure


or with yaml:

`oc apply -f route.yaml`

# Root password
`oc exec -it gitlab-toolbox-5674d4c574-rdgk4 -- bash`

`gitlab-rails console -e production`

`user = User.find_by(username: 'root')`

`user.password = ''`

`user.password_confirmation = ''`

`user.save`

`exit`


# Links:
https://docs.gitlab.com/runner/configuration/tls-self-signed.html

https://docs.gitlab.com/runner/faq/
