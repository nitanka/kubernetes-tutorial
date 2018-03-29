#!/bin/bash

KUBERNETES_PUBLIC_ADDRESS=172.17.0.2
INTERNAL_IP=172.17.0.2
EXTERNAL_IP=172.17.0.2
instance=d56df529eeef
#generating the ca configuration

. client-tools.sh

install-cffsl
install-kubectl


generate-ca-config()
{
   
      `cat > ca-config.json <<EOF
      {
        "signing": {
          "default": {
            "expiry": "8760h"
          },
          "profiles": {
            "kubernetes": {
              "usages": ["signing", "key encipherment", "server auth", "client auth"],
              "expiry": "8760h"
            }
          }
        }
      }
      `
}


#Create a Certificate signing request
create-csr()
{

      `cat > ca-csr.json <<EOF
      {
        "CN": "Kubernetes",
        "key": {
          "algo": "rsa",
          "size": 2048
        },
        "names": [
          {
            "C": "US",
            "L": "Portland",
            "O": "Kubernetes",
            "OU": "CA",
            "ST": "Oregon"
          }
        ]
      }`
}

#generate the CA certificate and private key

generate-ca-pk()
{
	generate-ca-config
	create-csr
	cfssl gencert -initca ca-csr.json | cfssljson -bare ca
}


generate-ca-pk



generate-admin-config()
{
	`cat > admin-csr.json <<EOF
         {
           "CN": "admin",
           "key": {
             "algo": "rsa",
             "size": 2048
           },
           "names": [
             {
               "C": "US",
               "L": "Portland",
               "O": "system:masters",
               "OU": "Kubernetes The Hard Way",
               "ST": "Oregon"
             }
           ]
         }`
}

generate-admin-cer-pk()
{
	generate-admin-config
	cfssl gencert \
        -ca=ca.pem \
        -ca-key=ca-key.pem \
        -config=ca-config.json \
        -profile=kubernetes \
        admin-csr.json | cfssljson -bare admin
      
}


generate-admin-cer-pk


generate-client-config()
{
	`cat > ${instance}-csr.json <<EOF
         {
           "CN": "system:node:${instance}",
           "key": {
             "algo": "rsa",
             "size": 2048
           },
           "names": [
             {
               "C": "US",
               "L": "Portland",
               "O": "system:nodes",
               "OU": "Kubernetes The Hard Way",
               "ST": "Oregon"
             }
           ]
         }`
}

generate-client-certificate()
{
	generate-client-config

	cfssl gencert \
          -ca=ca.pem \
          -ca-key=ca-key.pem \
          -config=ca-config.json \
          -hostname=${instance},${EXTERNAL_IP},${INTERNAL_IP} \
          -profile=kubernetes \
          ${instance}-csr.json | cfssljson -bare ${instance}

}

generate-client-certificate


generate-kube-proxy-config()
{
	`
	cat > kube-proxy-csr.json <<EOF
        {
          "CN": "system:kube-proxy",
          "key": {
            "algo": "rsa",
            "size": 2048
          },
          "names": [
            {
              "C": "US",
              "L": "Portland",
              "O": "system:node-proxier",
              "OU": "Kubernetes The Hard Way",
              "ST": "Oregon"
            }
          ]
        }`
}

generate-kube-proxy-cert()
{
	generate-kube-proxy-config
	cfssl gencert \
         -ca=ca.pem \
         -ca-key=ca-key.pem \
         -config=ca-config.json \
         -profile=kubernetes \
         kube-proxy-csr.json | cfssljson -bare kube-proxy

}

generate-kube-proxy-cert



generate-api-server-config()
{
	`cat > kubernetes-csr.json <<EOF
         {
           "CN": "kubernetes",
           "key": {
             "algo": "rsa",
             "size": 2048
           },
           "names": [
             {
               "C": "US",
               "L": "Portland",
               "O": "Kubernetes",
               "OU": "Kubernetes The Hard Way",
               "ST": "Oregon"
             }
           ]
         }`

}

generate-api-server-cert()
{
	generate-api-server-config
	cfssl gencert \
         -ca=ca.pem \
         -ca-key=ca-key.pem \
         -config=ca-config.json \
         -hostname=${INTERNAL_IP},${KUBERNETES_PUBLIC_ADDRESS},127.0.0.1,kubernetes.default \
         -profile=kubernetes \
         kubernetes-csr.json | cfssljson -bare kubernetes
}     

generate-api-server-cert


generate-kubelet-config()
{
	kubectl config set-cluster kubernetes-the-hard-way \
          --certificate-authority=ca.pem \
          --embed-certs=true \
          --server=https://${KUBERNETES_PUBLIC_ADDRESS}:6443 \
          --kubeconfig=${instance}.kubeconfig


	kubectl config set-credentials system:node:${instance} \
          --client-certificate=${instance}.pem \
          --client-key=${instance}-key.pem \
          --embed-certs=true \
          --kubeconfig=${instance}.kubeconfig

	kubectl config set-context default \
          --cluster=kubernetes-the-hard-way \
          --user=system:node:${instance} \
          --kubeconfig=${instance}.kubeconfig

	kubectl config use-context default --kubeconfig=${instance}.kubeconfig
}



generate-kubelet-config



generate-kube-proxy-config()
{
	kubectl config set-cluster kubernetes-the-hard-way \
  --certificate-authority=ca.pem \
  --embed-certs=true \
  --server=https://${KUBERNETES_PUBLIC_ADDRESS}:6443 \
  --kubeconfig=kube-proxy.kubeconfig

	kubectl config set-credentials kube-proxy \
  --client-certificate=kube-proxy.pem \
  --client-key=kube-proxy-key.pem \
  --embed-certs=true \
  --kubeconfig=kube-proxy.kubeconfig

	kubectl config set-context default \
  --cluster=kubernetes-the-hard-way \
  --user=kube-proxy \
  --kubeconfig=kube-proxy.kubeconfig

	kubectl config use-context default --kubeconfig=kube-proxy.kubeconfig
}



generate-kube-proxy-config




generating-encryption-key()
{
	ENCRYPTION_KEY=$(head -c 32 /dev/urandom | base64)
	`cat > encryption-config.yaml <<EOF
         kind: EncryptionConfig
         apiVersion: v1
         resources:
           - resources:
               - secrets
             providers:
               - aescbc:
                   keys:
                     - name: key1
                       secret: ${ENCRYPTION_KEY}
               - identity: {}`
}


generating-encryption-key




setting-up-etcd()
{
	wget -q --show-progress --https-only --timestamping \
  "https://github.com/coreos/etcd/releases/download/v3.2.11/etcd-v3.2.11-linux-amd64.tar.gz"
	tar -xvf etcd-v3.2.11-linux-amd64.tar.gz
	mv etcd-v3.2.11-linux-amd64/etcd* /usr/local/bin/
	mkdir -p /etc/etcd /var/lib/etcd
	cp ca.pem kubernetes-key.pem kubernetes.pem /etc/etcd/
	ETCD_NAME=$(hostname -s)

	`cat > etcd.service <<EOF
         [Unit]
         Description=etcd
         Documentation=https://github.com/coreos
         
         [Service]
         ExecStart=/usr/local/bin/etcd \\
           --name ${ETCD_NAME} \\
           --cert-file=/etc/etcd/kubernetes.pem \\
           --key-file=/etc/etcd/kubernetes-key.pem \\
           --peer-cert-file=/etc/etcd/kubernetes.pem \\
           --peer-key-file=/etc/etcd/kubernetes-key.pem \\
           --trusted-ca-file=/etc/etcd/ca.pem \\
           --peer-trusted-ca-file=/etc/etcd/ca.pem \\
           --peer-client-cert-auth \\
           --client-cert-auth \\
           --initial-advertise-peer-urls https://${INTERNAL_IP}:2380 \\
           --listen-peer-urls https://${INTERNAL_IP}:2380 \\
           --listen-client-urls https://${INTERNAL_IP}:2379,http://127.0.0.1:2379 \\
           --advertise-client-urls https://${INTERNAL_IP}:2379 \\
           --initial-cluster-token etcd-cluster-0 \\
           --initial-cluster $(hostname -s)=https://${INTERNAL_IP}:2380 \\
           --initial-cluster-state new \\
           --data-dir=/var/lib/etcd
         Restart=on-failure
         RestartSec=5
         
         [Install]
         WantedBy=multi-user.target
         `
	mv etcd.service /etc/systemd/system/
	systemctl daemon-reload

	systemctl enable etcd
	systemctl start etcd
	ETCDCTL_API=3 etcdctl member list

}


setting-up-etcd
