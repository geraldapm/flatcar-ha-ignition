#!/bin/bash



my_array=($(awk '{print $1}' input.txt))

### Define IP Subnet for CIDR assignment including floating IP and gateway IP

IP_SUBNET=192.168.122.0/24
IP_RANGE_START=100
IP_RANGE_CONTROLPLANE1=101

### Dynamic provisioning
IP_GATEWAY="$(echo $IP_SUBNET | cut -d. -f1-3).1"
IP_FLOATING="$(echo $IP_SUBNET | cut -d. -f1-3).99"

### Define the Virtual IP or Floating IP
floating_ip=$IP_FLOATING

### Define cluster member list
### Ensure that the hostname has "wontrol" and "worker" inside for node role filtering
hostlist=$(cat <<EOF
192.168.122.101     gpmcontrolplane1
192.168.122.102     gpmcontrolplane2
192.168.122.103     gpmcontrolplane3
192.168.122.104     gpmworker1    
192.168.122.105     gpmworker2
EOF
)

# Define the VM names array
vms=($(echo $hostlist | awk '{print $2}'))

controlplane_vm_ips=($(echo "$hostlist" | grep "control" | awk '{print $1}'))

BUTANE_AUTOGEN_DIR=$CURRENT_DIR/butane-autogen
BUTANE_STATIC_DIR=$CURRENT_DIR/butane-config

CURRENT_DIR=$(pwd)

IMAGE_DIR=$CURRENT_DIR/images
TEMPLATE_DISK_FILE="$IMAGE_DIR/flatcar_production_qemu_uefi_image.img"

VCPU=2
MEMORY_MB=2048
NETWORK_IFACE=virbr0

POD_CIDR=10.244.0.0/16
SERVICE_CIDR=10.96.0.0/12

for vm in ${vms[*]}; do 
    cp --update=none $TEMPLATE_DISK_FILE $IMAGE_DIR/$vm.qcow2

    IP_ADDR="$(echo "$hostlist" | grep $vm | awk '{print $1}')"
    CIDR="$(echo $IP_SUBNET | cut -d'/' -f2)"

    echo "Starting VM $vm with IP Address $IP_ADDR/$CIDR gateway $IP_GATEWAY"

    # Set node role to controlplane/worker
    K8S_SERVER_STRING="controlplane"
    K8S_MODE="controlplane"
    if [[ "$vm" == *"$K8S_SERVER_STRING"*  ]]; then
    echo "Starting $vm as kubernetes $K8S_MODE node"
    else
    K8S_MODE="worker"
    echo "Starting $vm as kubernetes $K8S_MODE node"
    fi

    sed -i "s+###IP_GATEWAY###+$IP_GATEWAY+g" butane-common.yaml
    sed -i "s+/###CIDR###+/$CIDR+g" butane-common.yaml
    sed -i "s+###HOSTNAME###+$vm+g" butane-common.yaml
    sed -i "s+###IP_ADDRESS###+$IP_ADDR+g" butane-common.yaml


    if (( IP_RANGE_START == IP_RANGE_CONTROLPLANE1 )); then
        sed -i "s+###FIRSTNODE_IP###+$IP_ADDR+g" butane-kubeadm.yaml 
        sed -i 's+###KUBEADM_MODE###+systemctl enable --now keepalived; /usr/local/bin/kubeadm init --config /etc/kubernetes/kubeadm-init.yaml; kubeadm token create --print-join-command --certificate-key "\$\(kubeadm init phase upload-certs --upload-certs | tail -n 1\)" > /tmp/controlplane-join.sh; kubeadm token create --print-join-command > /tmp/worker-join.sh+g' butane-kubeadm.yaml 
    elif [[ "$K8S_MODE" == "controlplane"  ]]; then
        sed -i 's+###KUBEADM_MODE###+scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@###FLOATINGIP###:/tmp/controlplane-join.sh /tmp/controlplane-join.sh ;echo "\$\(cat /tmp/controlplane-join.sh\) -v=5" | sudo PATH=/sbin:/usr/sbin:/usr/local/sbin:/root/bin:/usr/local/bin:/usr/bin:/bin bash; systemctl enable --now keepalived+g' butane-kubeadm.yaml 
    else
        sed -i 's+###KUBEADM_MODE###+scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@###FLOATINGIP###:/tmp/worker-join.sh /tmp/worker-join.sh; echo "\$\(cat /tmp/worker-join.sh\) -v=5" | sudo PATH=/sbin:/usr/sbin:/usr/local/sbin:/root/bin:/usr/local/bin:/usr/bin:/bin bash+g' butane-kubeadm.yaml 
    fi

    sed -i "s+###FLOATINGIP###+$IP_FLOATING+g" butane-keepalived.yaml

    sed -i "s+###POD_CIDR###+$POD_CIDR+g" butane-kubeadm.yaml
    sed -i "s+###SERVICE_CIDR###+$SERVICE_CIDR+g" butane-kubeadm.yaml
    sed -i "s+###FLOATINGIP###+$IP_FLOATING+g" butane-kubeadm.yaml

    if [[ "$K8S_MODE" == "controlplane"  ]]; then
    cat << EOF > butane-$vm.yaml
    variant: fcos
    version: 1.5.0
    ignition:
        config:
            merge:
            - inline: |-
                $(./butane ./butane-ssh.yaml)
            - inline: |-
                $(./butane ./butane-common.yaml)
            - inline: |-
                $(./butane ./butane-kubeadm.yaml)
            - inline: |-
                $(./butane ./butane-keepalived.yaml)
EOF
    else
    cat << EOF > butane-$vm.yaml
    variant: fcos
    version: 1.5.0
    ignition:
        config:
            merge:
            - inline: |-
                $(./butane ./butane-common.yaml)
            - inline: |-
                $(./butane ./butane-ssh.yaml)
            - inline: |-
                $(./butane ./butane-kubeadm.yaml)
EOF
    fi
    ./butane butane-$vm.yaml > $vm.ign

    #Remove unused butane generated file
    rm -f butane-$vm.yaml

    ### Rollback
    sed -i "s+/$CIDR+/###CIDR###+g" butane-common.yaml
    sed -i "s+$vm+###HOSTNAME###+g" butane-common.yaml
    sed -i "s+$IP_ADDR+###IP_ADDRESS###+g" butane-common.yaml
    sed -i "s+$IP_GATEWAY+###IP_GATEWAY###+g" butane-common.yaml

    sed -i "s+$IP_FLOATING+###FLOATINGIP###+g" butane-keepalived.yaml

    sed -i "s+$POD_CIDR+###POD_CIDR###+g" butane-kubeadm.yaml
    sed -i "s+$SERVICE_CIDR+###SERVICE_CIDR###+g" butane-kubeadm.yaml
    sed -i "s+$IP_FLOATING+###FLOATINGIP###+g" butane-kubeadm.yaml

    if (( IP_RANGE_START == IP_RANGE_CONTROLPLANE1 )); then
        sed -i "s+$IP_ADDR+###FIRSTNODE_IP###+g" butane-kubeadm.yaml
        sed -i 's+systemctl enable --now keepalived; /usr/local/bin/kubeadm init --config /etc/kubernetes/kubeadm-init.yaml; kubeadm token create --print-join-command --certificate-key "$(kubeadm init phase upload-certs --upload-certs | tail -n 1)" > /tmp/controlplane-join.sh; kubeadm token create --print-join-command > /tmp/worker-join.sh+###KUBEADM_MODE###+g' butane-kubeadm.yaml 
    elif [[ "$K8S_MODE" == "controlplane"  ]]; then
        sed -i 's+scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@###FLOATINGIP###:/tmp/controlplane-join.sh /tmp/controlplane-join.sh ;echo "$(cat /tmp/controlplane-join.sh) -v=5" | sudo PATH=/sbin:/usr/sbin:/usr/local/sbin:/root/bin:/usr/local/bin:/usr/bin:/bin bash; systemctl enable --now keepalived+###KUBEADM_MODE###+g' butane-kubeadm.yaml 
    else
        sed -i 's+scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@###FLOATINGIP###:/tmp/worker-join.sh /tmp/worker-join.sh; echo "$(cat /tmp/worker-join.sh) -v=5" | sudo PATH=/sbin:/usr/sbin:/usr/local/sbin:/root/bin:/usr/local/bin:/usr/bin:/bin bash+###KUBEADM_MODE###+g' butane-kubeadm.yaml 
    fi

    virt-install \
    --name=$vm \
    --ram=$MEMORY_MB \
    --vcpus=$VCPU \
    --import \
    --disk path=$vm.qcow2,device=disk,bus=virtio \
    --os-variant opensuse-unknown \
    --network bridge=$NETWORK_IFACE,model=virtio \
    --graphics vnc,listen=0.0.0.0 --noautoconsole \
    --sysinfo type=fwcfg,entry0.name="opt/com.coreos/config",entry0.file="$CURRENT_DIR/$vm.ign"

    virsh start $vm

    # rm -f $vm.ign
done

## Cleanup ssh known_hosts as the nodes will be provisioed back-forth
> ~/.ssh/known_hosts



