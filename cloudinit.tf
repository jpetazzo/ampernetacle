locals {
  packages = [
    "apt-transport-https",
    "build-essential",
    "ca-certificates",
    "curl",
    "docker.io",
    "jq",
    "kubeadm",
    "kubelet",
    "lsb-release",
    "make",
    "prometheus-node-exporter",
    "python3-pip",
    "software-properties-common",
    "tmux",
    "tree",
    "unzip",
  ]
}

data "cloudinit_config" "_" {
  for_each = local.nodes

  part {
    filename     = "cloud-config.cfg"
    content_type = "text/cloud-config"
    content      = <<-EOF
      hostname: ${each.value.node_name}
      package_update: true
      package_upgrade: false
      packages:
      ${yamlencode(local.packages)}
      apt:
        sources:
          kubernetes.list:
            source: "deb https://apt.kubernetes.io/ kubernetes-xenial main"
            key: |
              ${indent(8, data.http.apt_repo_key.body)}
      users:
      - default
      - name: k8s
        primary_group: k8s
        groups: docker
        home: /home/k8s
        shell: /bin/bash
        sudo: ALL=(ALL) NOPASSWD:ALL
        ssh_authorized_keys:
        - ${tls_private_key.ssh.public_key_openssh}
      write_files:
      - path: /etc/kubeadm_token
        owner: "root:root"
        permissions: "0600"
        content: ${local.kubeadm_token}
      - path: /etc/kubeadm_config.yaml
        owner: "root:root"
        permissions: "0600"
        content: |
          kind: InitConfiguration
          apiVersion: kubeadm.k8s.io/v1beta2
          bootstrapTokens:
          - token: ${local.kubeadm_token}
          ---
          kind: KubeletConfiguration
          apiVersion: kubelet.config.k8s.io/v1beta1
          cgroupDriver: cgroupfs
          ---
          kind: ClusterConfiguration
          apiVersion: kubeadm.k8s.io/v1beta2
          apiServer:
            certSANs:
            - @@PUBLIC_IP_ADDRESS@@
      - path: /etc/nginx-metallb-config.yaml
        owner: "root:root"
        permissions: "0600"
        content: |
          apiVersion: v1
          kind: ConfigMap
          metadata:
            namespace: metallb-system
            name: config
          data:
            config: |
              address-pools:
              - name: default
                protocol: layer2
                addresses:
                - 10.0.0.11/32
          ---
          apiVersion: cert-manager.io/v1
          kind: ClusterIssuer
          metadata:
            name: letsencrypt-prod
            namespace: cert-manager
          spec:
            acme:
              email: my-email@gmail.com
              server: https://acme-v02.api.letsencrypt.org/directory
              privateKeySecretRef:
                name: letsencrypt-prod
              solvers:
              - http01:
                  ingress:
                    class: nginx
          ---
          apiVersion: v1 #this entire section i dont know if i've made it in the best way.
          kind: Service
          metadata:
            labels:
              app.kubernetes.io/component: controller
              app.kubernetes.io/instance: ingress-nginx
              app.kubernetes.io/managed-by: Helm
              app.kubernetes.io/name: ingress-nginx
            name: ingress-nginx-controller
            namespace: ingress-nginx
          spec:
            externalTrafficPolicy: Cluster #for now i dont know how to make it work with local.
            ipFamilies:
            - IPv4
            ipFamilyPolicy: SingleStack
            ports:
            - name: http
              port: 80
              protocol: TCP
              targetPort: http
            - name: https
              port: 443
              protocol: TCP
              targetPort: https
            selector:
              app.kubernetes.io/component: controller
              app.kubernetes.io/instance: ingress-nginx
              app.kubernetes.io/name: ingress-nginx
            sessionAffinity: None
            type: LoadBalancer #it is important to apply this config for ingress-nginx just to change this flag
            externalIPs:
            - @@PUBLIC_IP_ADDRESS@@
      - path: /home/k8s/.ssh/id_rsa
        defer: true
        owner: "k8s:k8s"
        permissions: "0600"
        content: |
          ${indent(4, tls_private_key.ssh.private_key_pem)}
      - path: /home/k8s/.ssh/id_rsa.pub
        defer: true
        owner: "k8s:k8s"
        permissions: "0600"
        content: |
          ${indent(4, tls_private_key.ssh.public_key_openssh)}
      EOF
  }

  # By default, all inbound traffic is blocked
  # (except SSH) so we need to change that.
  part {
    filename     = "allow-inbound-traffic.sh"
    content_type = "text/x-shellscript"
    content      = <<-EOF
      #!/bin/sh
      sed -i "s/-A INPUT -j REJECT --reject-with icmp-host-prohibited//" /etc/iptables/rules.v4 
      netfilter-persistent start
    EOF
  }

  dynamic "part" {
    for_each = each.value.role == "controlplane" ? ["yes"] : []
    content {
      filename     = "kubeadm-init.sh"
      content_type = "text/x-shellscript"
      content      = <<-EOF
        #!/bin/sh
        PUBLIC_IP_ADDRESS=$(curl https://icanhazip.com/)
        sed -i s/@@PUBLIC_IP_ADDRESS@@/$PUBLIC_IP_ADDRESS/ /etc/kubeadm_config.yaml
        kubeadm init --config=/etc/kubeadm_config.yaml --ignore-preflight-errors=NumCPU
        export KUBECONFIG=/etc/kubernetes/admin.conf
        kubever=$(kubectl version | base64 | tr -d '\n')
        kubectl apply -f https://cloud.weave.works/k8s/net?k8s-version=$kubever

        # Preparation for metallb: https://metallb.universe.tf/installation/
        kubectl get configmap kube-proxy -n kube-system -o yaml | \
        sed -e "s/strictARP: false/strictARP: true/" | \
        kubectl apply -f - -n kube-system

        # apply cert-manager, ingress-nginx, metal lb and longhorn to the cluster:
        kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.11.0/manifests/namespace.yaml
        kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.11.0/manifests/metallb.yaml
        kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.7.1/cert-manager.yaml
        kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.1.1/deploy/static/provider/baremetal/deploy.yaml
        kubectl apply -f https://raw.githubusercontent.com/longhorn/longhorn/v1.2.3/deploy/longhorn.yaml

        sed -i s/@@PUBLIC_IP_ADDRESS@@/$PUBLIC_IP_ADDRESS/ /etc/nginx-metallb-config.yaml
        kubectl apply -f /etc/nginx-metallb-config.yaml

        mkdir -p /home/k8s/.kube
        cp $KUBECONFIG /home/k8s/.kube/config
        chown -R k8s:k8s /home/k8s/.kube
      EOF
    }
  }

  dynamic "part" {
    for_each = each.value.role == "worker" ? ["yes"] : []
    content {
      filename     = "kubeadm-join.sh"
      content_type = "text/x-shellscript"
      content      = <<-EOF
      #!/bin/sh
      kubeadm join --discovery-token-unsafe-skip-ca-verification --token ${local.kubeadm_token} ${local.nodes[1].ip_address}:6443
    EOF
    }
  }
}

data "http" "apt_repo_key" {
  url = "https://packages.cloud.google.com/apt/doc/apt-key.gpg.asc"
}

# The kubeadm token must follow a specific format:
# - 6 letters/numbers
# - a dot
# - 16 letters/numbers

resource "random_string" "token1" {
  length  = 6
  number  = true
  lower   = true
  special = false
  upper   = false
}

resource "random_string" "token2" {
  length  = 16
  number  = true
  lower   = true
  special = false
  upper   = false
}

locals {
  kubeadm_token = format(
    "%s.%s",
    random_string.token1.result,
    random_string.token2.result
  )
}
