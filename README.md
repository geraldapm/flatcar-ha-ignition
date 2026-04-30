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
- FAST Internet connection for downloading required binaries

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
mkdir image
wget -c https://stable.release.flatcar-linux.net/amd64-usr/4459.2.4/flatcar_production_qemu_uefi_image.img -O image/
```

2. Generate ignition scripts and other resources with this command:

```shell
bash generate-ignition.sh --generate-cert
```

3. When needed, you can delete all ignition scripts and other resources with this command:

```shell
bash reset-ignition.sh --destroy
```

## Provisioning

Provision the VMs with this command:

```shell
bash start-vm.sh --provision
```

When needed, you can stop the VM with this command:

```shell
bash stop-vm.sh
```

and starting it once again with this command:

```shell
bash start-vm.sh
```

## Cleanup

If you need to stop the VMs and deleting all provisioned VMs, use this command

```shell
bash stop-vm.sh --destroy
```
