# Fedora CoreOS qemu(libvirt) install

1. Download [butane](https://github.com/coreos/butane/releases)

2. create ign files from [ignition_template.yaml](ignition_template.yaml) (change hostname,IP,node type(master/worker/bootstrap), check users and ssh keys)

    `./butane ignition_template.yaml -o <VM_NAME>.ign`

3. Download FCOS iso and PXE rootfs img (check compatible version with `./openshift-install coreos print-stream-json`)

    https://getfedora.org/en/coreos/download?tab=metal_virtualized&stream=stable&arch=x86_64
4. Copy ISO to `/var/lib/libvirt/images/` on qemu host
5. Serve IGN and PXE files via web server. E.g.:
`docker run -d -v <PATH_TO_IGN_AND_PXE>:/web -p 8080:8080 halverneus/static-file-server:latest`
6. Check vars in `mk_fcos_vm.sh` and run it on qemu host to create vm and install fcos

------
Useful Links:

https://docs.fedoraproject.org/en-US/fedora-coreos/authentication/
https://docs.fedoraproject.org/en-US/fedora-coreos/sysconfig-network-configuration/
https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/7/html/networking_guide/sec-configuring_ip_networking_from_the_kernel_command_line

https://discussion.fedoraproject.org/t/install-fcos-on-kvm-lvm/25625/25#my-working-script-1

https://hub.docker.com/r/halverneus/static-file-server