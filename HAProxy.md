# HAProxy installation

## FCOS install
1. Generate ignition config from template but without ignition section
2. Install [FCOS](FCOS.md)

## Install and enable HAProxy
1. `rpm-ostree upgrade`
2. `rpm-ostree install haproxy`
3. `systemctl enable haproxy`

## SELinux
`setsebool -P haproxy\_connect\_any=True`

## Config
`/etc/haproxy/haproxy.cfg `
```
global
    log         127.0.0.1 local2
    chroot      /var/lib/haproxy
    pidfile     /var/run/haproxy.pid
    maxconn     4000
    user        haproxy
    group       haproxy
    daemon
    stats socket /var/lib/haproxy/stats
    
defaults
    mode                    http
    log                     global
    option                  dontlognull
    option http-server-close
    option                  redispatch
    retries                 3
    timeout http-request    10s
    timeout queue           1m
    timeout connect         10s
    timeout client          1m
    timeout server          1m
    timeout http-keep-alive 10s
    timeout check           10s
    maxconn                 3000
    
frontend stats
    bind *:1936
    mode            http
    log             global
    maxconn 10
    stats enable
    stats hide-version
    stats refresh 30s
    stats show-node
    stats show-desc Stats for ocp4 cluster 
    stats auth admin:ocp4
    stats uri /stats
listen api-server-6443 
    bind *:6443
    mode tcp
    server bootstrap bootstrap.okd.example.com:6443 check inter 1s backup 
    server master0 master0.okd.example.com:6443 check inter 1s
    server master1 master1.okd.example.com:6443 check inter 1s
    server master2 master2.okd.example.com:6443 check inter 1s
listen machine-config-server-22623 
    bind *:22623
    mode tcp
    server bootstrap bootstrap.okd.example.com:22623 check inter 1s backup 
    server master0 master0.okd.example.com:22623 check inter 1s
    server master1 master1.okd.example.com:22623 check inter 1s
    server master2 master2.okd.example.com:22623 check inter 1s
listen ingress-router-443 
    bind *:443
    mode tcp
    balance source
    server worker0 worker0.okd.example.com:443 check inter 1s
    server worker1 worker1.okd.example.com:443 check inter 1s
listen ingress-router-80 
    bind *:80
    mode tcp
    balance source
    server worker0 worker0.okd.example.com:80 check inter 1s
    server worker1 worker1.okd.example.com:443 check inter 1s
```

## Reboot
`systemctl reboot`

## Logging
`journalctl -b -f -u haproxy`