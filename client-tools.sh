#!/bin/bash


#installing cffsl

install-cffsl()
{
      wget -q --show-progress --https-only --timestamping \
           https://pkg.cfssl.org/R1.2/cfssl_linux-amd64 \
           https://pkg.cfssl.org/R1.2/cfssljson_linux-amd64
      chmod +x cfssl_linux-amd64 cfssljson_linux-amd64
      mv cfssl_linux-amd64 /usr/local/bin/cfssl
      mv cfssljson_linux-amd64 /usr/local/bin/cfssljson
      cfssl version
}

install-kubectl()
{
	wget https://storage.googleapis.com/kubernetes-release/release/v1.9.0/bin/linux/amd64/kubectl
	chmod +x kubectl
	mv kubectl /usr/local/bin/
	kubectl version --client
}

