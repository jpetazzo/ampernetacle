# Ampernetacle

This is a Terraform configuration to deploy a Kubernetes cluster on
[Oracle Cloud Infrastructure][oci]. It creates a few virtual machines
and uses [kubeadm] to install a Kubernetes control plane on the first
machine, and join the other machines as worker nodes.

By default, it deploys a 4-node cluster using ARM machines. Each machine
has 1 OCPU and 6 GB of RAM, which means that the cluster fits within
Oracle's (pretty generous if you ask me) [free tier][freetier].

**It is not meant to run production workloads,**
but it's great if you want to learn Kubernetes with a "real" cluster
(i.e. a cluster with multiple nodes) without breaking the bank, *and*
if you want to develop or test applications on ARM.

## Getting started

1. Create an Oracle Cloud Infrastructure account (just follow [this link][createaccount]).
2. Have installed or [install kubernetes](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/#installing-kubeadm-kubelet-and-kubectl).
3. Have installed or [install terraform](https://learn.hashicorp.com/tutorials/terraform/install-cli?in=terraform/oci-get-started).
4. Have installed or [install OCI CLI ](https://docs.oracle.com/en-us/iaas/Content/API/SDKDocs/cliinstall.htm).
5. Configure [OCI credentials](https://learn.hashicorp.com/tutorials/terraform/oci-build?in=terraform/oci-get-started).
6. `terraform init`
7. `terraform apply`

That's it!

At the end of the `terraform apply`, a `kubeconfig` file is generated
in this directory. To use your new cluster, you can do:

```bash
export KUBECONFIG=$PWD/kubeconfig
kubectl get nodes
```

The command above should show you 4 nodes, named `node1` to `node4`.

You can also log into the VMs. At the end of the Terraform output
you should see a command that you can use to SSH into the first VM
(just copy-paste the command).

## Windows

The `kubeconfig.tf` file currently uses UNIX-specific commands which
don't work on Windows. (See #2.) I'm going to try and find a better
way to get the kubeconfig file; but meanwhile, you could try to run
it in WSL2. (Sorry!)

## Availability Domain

If you get a message like the following:

```
Error: 500-InternalError
│ ...
│ Service: Core Instance
│ Error Message: Out of host capacity.
```

...then you can try to switch to a different *availability domain*.
This can be done by changing the `availability_domain` input variable. (Thanks @uknbr for the contribution!)

## Customization

Check `variables.tf` to see tweakable parameters. You can change the number
of nodes, the size of the nodes, or switch to Intel/AMD instances if you'd
like. Keep in mind that if you switch to Intel/AMD instances, you won't get
advantage of the free tier.

## Stopping the cluster

`terraform destroy`

## Implementation details

This Terraform configuration:

- generates an OpenSSH keypair and a kubeadm token
- deploys 4 VMs using Ubuntu 20.04
- uses cloud-init to install and configure everything
- installs Docker and Kubernetes packages
- runs `kubeadm init` on the first VM
- runs `kubeadm join` on the other VMs
- installs the Weave CNI plugin
- transfers the `kubeconfig` file generated by `kubeadm`
- patches that file to use the public IP address of the machine

## Caveats

There is no cloud controller manager, which means that you cannot
create services with `type: LoadBalancer`; or rather, if you create
such services, their `EXTERNAL-IP` will remain `<pending>`.

To expose services, use `NodePort`.

Likewise, there is no ingress controller and no storage class.

(These might be added in a later iteration of this project.)

## Workaround for External-ip & Storage class

External IP -> [MetalLB][metallb].

kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.11.0/manifests/namespace.yaml
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.11.0/manifests/metallb.yaml

Just make sure to use 10.0.0.11/32 in address pool.

Storage Class -> [LongHorn][longhorn].

kubectl apply -f https://raw.githubusercontent.com/longhorn/longhorn/v1.2.3/deploy/longhorn.yaml

## Remarks

Oracle Cloud also has a managed Kubernetes service called
[Container Engine for Kubernetes (or OKE)][oke]. That service
doesn't have the caveats mentioned above; however, it's not part
of the free tier.

## What does "Ampernetacle" mean?

It's a *porte-manteau* between Ampere, Kubernetes, and Oracle.
It's probably not the best name in the world but it's the one
we have! If you have an idea for a better name let us know. 😊

[createaccount]: https://bit.ly/free-oci-dat-k8s-on-arm
[freetier]: https://www.oracle.com/cloud/free/
[kubeadm]: https://kubernetes.io/docs/reference/setup-tools/kubeadm/
[oci]: https://www.oracle.com/cloud/compute/
[oke]: https://www.oracle.com/cloud-native/container-engine-kubernetes/
[metallb]: https://metallb.universe.tf/installation/
[longhorn]: https://longhorn.io/docs/1.2.3/deploy/install/install-with-kubectl/
