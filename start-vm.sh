#!/bin/bash

PATH=$PATH:$(pwd)

### Define IP Subnet for CIDR assignment including floating IP and gateway IP

IP_SUBNET=192.168.122.0/24

### Set IP Subnet Gateway
IP_GATEWAY="$(echo $IP_SUBNET | cut -d. -f1-3).1"

### Define the Virtual IP or Floating IP
IP_FLOATING="$(echo $IP_SUBNET | cut -d. -f1-3).99"

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

### Define the first controlplane IP to init the kubeadm cluster
IP_RANGE_CONTROLPLANE1=192.168.122.101

# Define the VM names array
vms=($(echo "$hostlist" | awk '{print $2}'))

### Define the default directory gen
CURRENT_DIR=$(pwd)

BUTANE_AUTOGEN_DIR=$CURRENT_DIR/butane-autogen
BUTANE_STATIC_DIR=$CURRENT_DIR/butane-config
BUTANE_GENERATED_DIR=$CURRENT_DIR/butane-generated
IGNITION_DIR=$CURRENT_DIR/ignition

IMAGE_DIR=$CURRENT_DIR/images
TEMPLATE_DISK_FILE="$IMAGE_DIR/flatcar_production_qemu_uefi_image.img"

### VM Specs
VCPU=2
MEMORY_MB=2048
NETWORK_IFACE=virbr0

### POD and service CIDR
POD_CIDR=10.244.0.0/16
SERVICE_CIDR=10.96.0.0/12

### Versioning used in the provisioning scripts
K8S_VERSION="v1.35.2"
CRIO_VERSION="v1.35.2"
CALICO_VERSION="v3.31.5"

### Kubeadm configuration command
KUBEADM_INIT_COMMAND='/usr/local/bin/kubeadm config images pull; /usr/local/bin/kubeadm init --token ${K8S_TOKEN} --cri-socket=unix:///var/run/crio/crio.sock --control-plane-endpoint ${APISERVER_ENDPOINT} --upload-certs --config /etc/kubernetes/kubeadm-init.yaml'
KUBEADM_CONTROLPLANE_JOIN_COMMAND='/usr/local/bin/kubeadm config images pull; /usr/local/bin/kubeadm join ${APISERVER_ENDPOINT} --token ${K8S_TOKEN} --discovery-token-ca-cert-hash ${K8S_HASH} --ignore-preflight-errors=FileAvailable--etc-kubernetes-pki-ca.crt --cri-socket=unix:///var/run/crio/crio.sock --control-plane --certificate-key ${K8S_CERT_KEY} --config /etc/kubernetes/kubeadm-init.yaml'
KUBEADM_WORKER_JOIN_COMMAND='/usr/local/bin/kubeadm join ${APISERVER_ENDPOINT} --cri-socket=unix:///var/run/crio/crio.sock  --token ${K8S_TOKEN} --discovery-token-ca-cert-hash ${K8S_HASH} --ignore-preflight-errors=FileAvailable--etc-kubernetes-pki-ca.crt --config /etc/kubernetes/kubeadm-init.yaml'

if [[ $1 == "--provision" ]];
then
sed -i "s+###FLOATINGIP###+$IP_FLOATING+g" $BUTANE_STATIC_DIR/butane-keepalived.yaml
sed -i "s+###POD_CIDR###+$POD_CIDR+g" $BUTANE_STATIC_DIR/butane-kubeadm.yaml
sed -i "s+###SERVICE_CIDR###+$SERVICE_CIDR+g" $BUTANE_STATIC_DIR/butane-kubeadm.yaml
sed -i "s+###FLOATINGIP###+$IP_FLOATING+g" $BUTANE_STATIC_DIR/butane-kubeadm.yaml
sed -i "s+###K8S_VERSION###+$K8S_VERSION+g" $BUTANE_STATIC_DIR/butane-kubeadm.yaml
sed -i "s+###CRIO_VERSION###+$CRIO_VERSION+g" $BUTANE_STATIC_DIR/butane-crio.yaml
sed -i "s+###CALICO_VERSION###+$CALICO_VERSION+g" $BUTANE_STATIC_DIR/butane-calico.yaml

# create the generated butane directory
mkdir -p $BUTANE_GENERATED_DIR $IGNITION_DIR

### Generate kubernetes certs
bash ./scripts/gencert.sh

### Generate cert butane config
bash ./scripts/cert-yaml-injection.sh

### Generate ssh butane config
bash ./scripts/ssh-generator.sh

### Generate haproxy butane config
floating_ip=$IP_FLOATING hostlist="$hostlist" bash ./scripts/haproxy-generator.sh
fi

for vm in ${vms[*]}; do 
    IP_ADDR="$(echo "$hostlist" | grep $vm | awk '{print $1}')"
    CIDR="$(echo $IP_SUBNET | cut -d'/' -f2)"

    echo "Starting VM $vm with IP Address $IP_ADDR/$CIDR gateway $IP_GATEWAY"

if [[ $1 == "--provision" ]];
then
    # Set node role to controlplane/worker
    K8S_SERVER_STRING="controlplane"
    K8S_MODE="controlplane"

    if [[ "$vm" == *"$K8S_SERVER_STRING"*  ]]; then
    echo "Starting $vm as kubernetes $K8S_MODE node"
    else
    K8S_MODE="worker"
    echo "Starting $vm as kubernetes $K8S_MODE node"
    fi

    # Generate different host config per VM
    sed -i "s+###IP_GATEWAY###+$IP_GATEWAY+g" $BUTANE_STATIC_DIR/butane-common.yaml
    sed -i "s+/###CIDR###+/$CIDR+g" $BUTANE_STATIC_DIR/butane-common.yaml
    sed -i "s+###HOSTNAME###+$vm+g" $BUTANE_STATIC_DIR/butane-common.yaml
    sed -i "s+###IP_ADDRESS###+$IP_ADDR+g" $BUTANE_STATIC_DIR/butane-common.yaml


    if [[ "$IP_ADDR" == "$IP_RANGE_CONTROLPLANE1" ]]; then
        sed -i "s+###FIRSTNODE_IP###+$IP_ADDR+g" $BUTANE_STATIC_DIR/butane-kubeadm.yaml 
        sed -i "s+###KUBEADM_MODE###+$KUBEADM_INIT_COMMAND+g" $BUTANE_STATIC_DIR/butane-kubeadm.yaml 
 
        cat << EOF > $BUTANE_GENERATED_DIR/butane-$vm.yaml
        variant: fcos
        version: 1.5.0
        ignition:
            config:
                merge:
                - inline: |-
                    $(butane $BUTANE_STATIC_DIR/butane-common.yaml)
                - inline: |-
                    $(butane $BUTANE_AUTOGEN_DIR/butane-ssh.yaml)
                - inline: |-
                    $(butane $BUTANE_STATIC_DIR/butane-keepalived.yaml)
                - inline: |-
                    $(butane $BUTANE_AUTOGEN_DIR/butane-haproxy.yaml)
                - inline: |-
                    $(butane $BUTANE_AUTOGEN_DIR/butane-certk8s.yaml)
                - inline: |-
                    $(butane $BUTANE_STATIC_DIR/butane-kubeadm.yaml)
                - inline: |-
                    $(butane $BUTANE_STATIC_DIR/butane-calico.yaml)
EOF

        sed -i "s+$IP_ADDR+###FIRSTNODE_IP###+g" $BUTANE_STATIC_DIR/butane-kubeadm.yaml
        sed -i "s+$KUBEADM_INIT_COMMAND+###KUBEADM_MODE###+g" $BUTANE_STATIC_DIR/butane-kubeadm.yaml 

    elif [[ "$K8S_MODE" == "controlplane"  ]]; then
        sed -i "s+###KUBEADM_MODE###+$KUBEADM_CONTROLPLANE_JOIN_COMMAND+g" $BUTANE_STATIC_DIR/butane-kubeadm.yaml 

        cat << EOF > $BUTANE_GENERATED_DIR/butane-$vm.yaml
        variant: fcos
        version: 1.5.0
        ignition:
            config:
                merge:
                - inline: |-
                    $(butane $BUTANE_STATIC_DIR/butane-common.yaml)
                - inline: |-
                    $(butane $BUTANE_AUTOGEN_DIR/butane-ssh.yaml)
                - inline: |-
                    $(butane $BUTANE_STATIC_DIR/butane-keepalived.yaml)
                - inline: |-
                    $(butane $BUTANE_AUTOGEN_DIR/butane-haproxy.yaml)
                - inline: |-
                    $(butane $BUTANE_AUTOGEN_DIR/butane-certk8s.yaml)
                - inline: |-
                    $(butane $BUTANE_STATIC_DIR/butane-kubeadm.yaml)
EOF

        sed -i "s+$KUBEADM_CONTROLPLANE_JOIN_COMMAND+###KUBEADM_MODE###+g" $BUTANE_STATIC_DIR/butane-kubeadm.yaml 
    else
        sed -i "s+###KUBEADM_MODE###+$KUBEADM_WORKER_JOIN_COMMAND" $BUTANE_STATIC_DIR/butane-kubeadm.yaml 

        cat << EOF > $BUTANE_GENERATED_DIR/butane-$vm.yaml
        variant: fcos
        version: 1.5.0
        ignition:
            config:
                merge:
                - inline: |-
                    $(butane $BUTANE_STATIC_DIR/butane-common.yaml)
                - inline: |-
                    $(butane $BUTANE_AUTOGEN_DIR/butane-ssh.yaml)
                - inline: |-
                    $(butane $BUTANE_AUTOGEN_DIR/butane-tokenk8s.yaml)
                - inline: |-
                    $(butane $BUTANE_STATIC_DIR/butane-kubeadm.yaml)
EOF

        sed -i "s+$KUBEADM_WORKER_JOIN_COMMAND+###KUBEADM_MODE###+g" $BUTANE_STATIC_DIR/butane-kubeadm.yaml 
    fi

    # Generate ignition file from compiled butane files
    butane $BUTANE_GENERATED_DIR/butane-$vm.yaml > $IGNITION_DIR/$vm.ign

    #Remove unused butane generated file
    rm -f $BUTANE_GENERATED_DIR/butane-$vm.yaml

    ### Rollback per-vm config
    sed -i "s+/$CIDR+/###CIDR###+g" $BUTANE_STATIC_DIR/butane-common.yaml
    sed -i "s+$vm+###HOSTNAME###+g" $BUTANE_STATIC_DIR/butane-common.yaml
    sed -i "s+$IP_ADDR+###IP_ADDRESS###+g" $BUTANE_STATIC_DIR/butane-common.yaml
    sed -i "s+$IP_GATEWAY+###IP_GATEWAY###+g" $BUTANE_STATIC_DIR/butane-common.yaml

    # qemu-img create -f qcow2 -F qcow2 -b $TEMPLATE_DISK_FILE $IMAGE_DIR/$vm.qcow2

    # virt-install \
    # --name=$vm \
    # --ram=$MEMORY_MB \
    # --vcpus=$VCPU \
    # --import \
    # --disk size=20,path=$IMAGE_DIR/$vm.qcow2,device=disk,bus=virtio \
    # --os-variant opensuse-unknown \
    # --network bridge=$NETWORK_IFACE,model=virtio \
    # --graphics vnc,listen=0.0.0.0 --noautoconsole \
    # --sysinfo type=fwcfg,entry0.name="opt/com.coreos/config",entry0.file="$IGNITION_DIR/$vm.ign"
# else
    # virsh start $vm
fi


done

if [[ $1 == "--provision" ]];
then
# Rollback global config
sed -i "s+$IP_FLOATING+###FLOATINGIP###+g" $BUTANE_STATIC_DIR/butane-keepalived.yaml
sed -i "s+$POD_CIDR+###POD_CIDR###+g" $BUTANE_STATIC_DIR/butane-kubeadm.yaml
sed -i "s+$SERVICE_CIDR+###SERVICE_CIDR###+g" $BUTANE_STATIC_DIR/butane-kubeadm.yaml
sed -i "s+$IP_FLOATING+###FLOATINGIP###+g" $BUTANE_STATIC_DIR/butane-kubeadm.yaml
sed -i "s+$K8S_VERSION+###K8S_VERSION###+g" $BUTANE_STATIC_DIR/butane-kubeadm.yaml
sed -i "s+$CRIO_VERSION+###CRIO_VERSION###+g" $BUTANE_STATIC_DIR/butane-crio.yaml
sed -i "s+$CALICO_VERSION+###CALICO_VERSION###+g" $BUTANE_STATIC_DIR/butane-calico.yaml
fi

## Cleanup ssh known_hosts as the nodes will be provisioed back-forth
# > ~/.ssh/known_hosts



