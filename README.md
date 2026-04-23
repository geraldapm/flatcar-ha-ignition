# flatcar-ha-ignition

Flatcar Linux Kubernetes Cluster with Ignition Scripts

## Base configuration URL

https://www.flatcar.org/docs/latest/container-runtimes/high-availability-kubernetes/

## Prerequisites

- Web Server that hosts ignition scrips and downloadable
- A Linux Server with KVM Virtualization Enabled (including qemu-kvm Virtual Machine Manager)
- Allocatable IP Addresses

## Environments

3 Control Plane Nodes and 2 Worker Nodes installed with Flatcar Linux and Kubernetes v1.35 cluster with Calico CNI v3.31.5. The spec is 2 vCPU, 2GB Memory and 20GB Stoage (in rootfs). It also has the Floating IP for kubernetes api server reachability and enabling High-Availability

gpmcontrolplane1 192.168.122.101
gpmcontrolplane2 192.168.122.102
gpmcontrolplane3 192.168.122.103
gpmworker1 192.168.122.104
gpmworker2 192.168.122.105

floatingip 192.168.122.100

We also have a controller node (optional) to operate the cluster and running the web server to download the ignition scripts.
gpmctrl 192.168.122.10

## Pre-provisioning

1. Ensure that the latest image is downloaded and inside into the Linux Hypervisor

```shell
wget -c https://stable.release.flatcar-linux.net/amd64-usr/4459.2.4/flatcar_production_qemu_uefi_image.img
```

2. Use the scripts scripts/gencert.sh to generate necessary kubernetes certs as described below:
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
chmod +x scripts/gencert.sh
./scripts/gencert.sh
```
