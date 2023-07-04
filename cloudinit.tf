locals {
  packages = [
    "apt-transport-https",
    "build-essential",
    "ca-certificates",
    "containerd.io",
    "curl",
    "docker-ce",
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
              ${indent(8, data.http.kubernetes_repo_key.response_body)}
          docker.list:
            source: "deb https://download.docker.com/linux/ubuntu jammy stable"
            key: |
              ${indent(8, data.http.docker_repo_key.response_body)}
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
          apiVersion: kubeadm.k8s.io/v1beta3
          bootstrapTokens:
          - token: ${local.kubeadm_token}
          ---
          kind: KubeletConfiguration
          apiVersion: kubelet.config.k8s.io/v1beta1
          cgroupDriver: cgroupfs
          ---
          kind: ClusterConfiguration
          apiVersion: kubeadm.k8s.io/v1beta3
          apiServer:
            certSANs:
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
    filename     = "1-allow-inbound-traffic.sh"
    content_type = "text/x-shellscript"
    content      = <<-EOF
      #!/bin/sh
      sed -i "s/-A INPUT -j REJECT --reject-with icmp-host-prohibited//" /etc/iptables/rules.v4 
      sed -i "s/-A FORWARD -j REJECT --reject-with icmp-host-prohibited//" /etc/iptables/rules.v4
      # There appears to be a bug in the netfilter-persistent scripts:
      # the "reload" and "restart" actions seem to append the rules files
      # to the existing rules (instead of replacing them), perhaps because
      # the "stop" action is disabled. So instead, we need to flush the
      # rules first before we load the new rule set.
      netfilter-persistent flush
      netfilter-persistent start
    EOF
  }

  # Docker's default containerd configuration disables CRI.
  # Let's re-enable it.
  part {
    filename     = "2-re-enable-cri.sh"
    content_type = "text/x-shellscript"
    content      = <<-EOF
      #!/bin/sh
      echo "# Use containerd's default configuration instead of the one shipping with Docker." > /etc/containerd/config.toml
      systemctl restart containerd
    EOF
  }

  dynamic "part" {
    for_each = each.value.role == "controlplane" ? ["yes"] : []
    content {
      filename     = "3-kubeadm-init.sh"
      content_type = "text/x-shellscript"
      content      = <<-EOF
        #!/bin/sh
        PUBLIC_IP_ADDRESS=$(curl https://icanhazip.com/)
        sed -i s/@@PUBLIC_IP_ADDRESS@@/$PUBLIC_IP_ADDRESS/ /etc/kubeadm_config.yaml
        kubeadm init --config=/etc/kubeadm_config.yaml --ignore-preflight-errors=NumCPU
        export KUBECONFIG=/etc/kubernetes/admin.conf
        kubectl apply -f https://github.com/weaveworks/weave/releases/download/v2.8.1/weave-daemonset-k8s-1.11.yaml
        mkdir -p /home/k8s/.kube
        cp $KUBECONFIG /home/k8s/.kube/config
        chown -R k8s:k8s /home/k8s/.kube
      EOF
    }
  }

  dynamic "part" {
    for_each = each.value.role == "worker" ? ["yes"] : []
    content {
      filename     = "3-kubeadm-join.sh"
      content_type = "text/x-shellscript"
      content      = <<-EOF
      #!/bin/sh
      KUBE_API_SERVER=${local.nodes[1].ip_address}:6443
      while ! curl --insecure https://$KUBE_API_SERVER; do
        echo "Kubernetes API server ($KUBE_API_SERVER) not responding."
        echo "Waiting 10 seconds before we try again."
        sleep 10
      done
      echo "Kubernetes API server ($KUBE_API_SERVER) appears to be up."
      echo "Trying to join this node to the cluster."
      kubeadm join --discovery-token-unsafe-skip-ca-verification --token ${local.kubeadm_token} $KUBE_API_SERVER
    EOF
    }
  }
}

data "http" "kubernetes_repo_key" {
  url = "https://packages.cloud.google.com/apt/doc/apt-key.gpg"
}

data "http" "docker_repo_key" {
  url = "https://download.docker.com/linux/debian/gpg"
}

# The kubeadm token must follow a specific format:
# - 6 letters/numbers
# - a dot
# - 16 letters/numbers

resource "random_string" "token1" {
  length  = 6
  numeric = true
  lower   = true
  special = false
  upper   = false
}

resource "random_string" "token2" {
  length  = 16
  numeric = true
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
