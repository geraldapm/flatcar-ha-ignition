#!/bin/bash
set -e
cert_dir=./certs

mkdir butane-autogen
output_yaml="butane-autogen/butane-tokenk8s.yaml"
indent="          "

# Encode certificates for YAML
ca_crt=$(sed "s/^/${indent}/" "$cert_dir/kubernetes-ca-chain.crt")
ca_key=$(sed "s/^/${indent}/" "$cert_dir/kubernetes-ca.key")
front_proxy_ca_crt=$(sed "s/^/${indent}/" "$cert_dir/front-proxy-ca-chain.crt")
front_proxy_ca_key=$(sed "s/^/${indent}/" "$cert_dir/front-proxy-ca.key")
sa_key=$(sed "s/^/${indent}/" "$cert_dir/service-accounts.key")
sa_pub=$(sed "s/^/${indent}/" "$cert_dir/service-accounts.crt")
etcd_ca_crt=$(sed "s/^/${indent}/" "$cert_dir/etcd-ca-chain.crt")
etcd_ca_key=$(sed "s/^/${indent}/" "$cert_dir/etcd-ca.key")

# Compute CA hash
ca_hash="sha256:$(openssl x509 -pubkey -in "$cert_dir/kubernetes-ca-chain.crt" | openssl rsa -pubin -outform der 2>/dev/null | openssl dgst -sha256 -hex | sed 's/^.* //')"
encoded_base64_ca_hash=$(echo -n "$ca_hash" | base64 -w 0)

# Write the header to the output YAML file
cat > "$output_yaml" <<-EOF
---
# This is generated using generate-k8s-certs.sh
variant: flatcar
version: 1.1.0
storage:
  files:
    - path: /etc/kubernetes/pki/ca.crt
      contents:
        inline: |
$ca_crt
    - path: /etc/kubernetes/pki/ca.key
      contents:
        inline: |
$ca_key
    - path: /etc/kubernetes/pki/front-proxy-ca.crt
      contents:
        inline: |
$front_proxy_ca_crt
    - path: /etc/kubernetes/pki/front-proxy-ca.key
      contents:
        inline: |
$front_proxy_ca_key
    - path: /etc/kubernetes/pki/sa.key
      contents:
        inline: |
$sa_key
    - path: /etc/kubernetes/pki/sa.pub
      contents:
        inline: |
$sa_pub
    - path: /etc/kubernetes/pki/etcd/ca.crt
      contents:
        inline: |
$etcd_ca_crt
    - path: /etc/kubernetes/pki/etcd/ca.key
      contents:
        inline: |
$etcd_ca_key
    - path: /etc/kubernetes/certs.conf
      contents:
        inline: |
            K8S_TOKEN='$token'
            K8S_HASH='$ca_hash'
EOF

echo "Kubernetes certificates have been generated successfully!"
echo "YAML file '$output_yaml' has been successfully overwritten!"