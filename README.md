# flatcar-ha-ignition

Flatcar Linux Kubernetes Cluster with Ignition Scripts

## Base configuration URL

https://www.flatcar.org/docs/latest/container-runtimes/high-availability-kubernetes/

## Prerequisites

- Butane binary executable to convert butane definition into ignition file. Download it from there -> https://github.com/coreos/butane/releases and install with this command

```bash
wget -c https://github.com/coreos/butane/releases/download/v0.25.1/butane-x86_64-unknown-linux-gnu -O butane
chmod +x butane
```

- A Linux Server with KVM Virtualization Enabled (including qemu-kvm Virtual Machine Manager)
- Allocatable IP Addresses for each vms

## Environments

3 Control Plane Nodes and 2 Worker Nodes installed with Flatcar Linux and Kubernetes v1.35 cluster with Calico CNI v3.31.5. The spec is 2 vCPU, 2GB Memory and 20GB Stoage (in rootfs). It also has the Floating IP for kubernetes api server reachability and enabling High-Availability

```
floatingip 192.168.122.100

gpmcontrolplane1 192.168.122.101
gpmcontrolplane2 192.168.122.102
gpmcontrolplane3 192.168.122.103
gpmworker1 192.168.122.104
gpmworker2 192.168.122.105
```

## Pre-provisioning

1. Ensure that the latest image is downloaded and inside into the Linux Hypervisor

```shell
wget -c https://stable.release.flatcar-linux.net/amd64-usr/4459.2.4/flatcar_production_qemu_uefi_image.img
```

2. Use the scripts scripts/gencert.sh to generate necessary kubernetes certs as described below. Then it will be injected into the butane definition to support the kubernetes installation:
   Reference: https://kubernetes.io/docs/setup/best-practices/certificates/

```
/etc/kubernetes/pki/ca.crt
/etc/kubernetes/pki/ca.key
/etc/kubernetes/pki/sa.key
/etc/kubernetes/pki/sa.pub
/etc/kubernetes/pki/front-proxy-ca.crt
/etc/kubernetes/pki/front-proxy-ca.key
/etc/kubernetes/pki/etcd/ca.crt
/etc/kubernetes/pki/etcd/ca.key
```

Run the script

```shell
chmod +x scripts/{gencert.sh,cert-yaml-injection.sh}
./scripts/gencert.sh
./scripts/cert-yaml-injection.sh
```

3. Start the VMs using the script "start-vm.sh"

```shell
chmod +x {start-vm.sh,stop-vm.sh}
./start-vm.sh
```
