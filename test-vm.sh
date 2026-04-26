#!/bin/bash

floating_ip="192.168.122.100"

hostlist=$(cat <<EOF
192.168.122.101     gpmcontrolplane1
192.168.122.102     gpmcontrolplane2
192.168.122.103     gpmcontrolplane3
192.168.122.104     gpmworker1    
192.168.122.105     gpmworker2
EOF
)

vms=($(echo "$hostlist" | awk '{print $2}'))


for vm in ${vms[*]}; do
echo "$vm - IP $(echo "$hostlist" | grep $vm | awk '{print $1}')"
done

echo "$testhaproxy"


