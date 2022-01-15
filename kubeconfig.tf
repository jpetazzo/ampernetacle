resource "null_resource" "wait_for_kube_apiserver" {
  depends_on = [oci_core_instance._[1]]
  provisioner "local-exec" {
    command = <<-EOT
      while ! curl -k https://${oci_core_instance._[1].public_ip}:6443; do
        sleep 1
      done
    EOT
  }
}

data "external" "kubeconfig" {
  depends_on = [null_resource.wait_for_kube_apiserver]
  program = [
    "sh",
    "-c",
    <<-EOT
      set -e
      cat >/dev/null
      echo '{"base64": "'$(
        ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
              -l k8s -i ${local_file.ssh_private_key.filename} \
              ${oci_core_instance._[1].public_ip} \
              sudo cat /etc/kubernetes/admin.conf | base64 -w0
            )'"}'
    EOT
  ]
}

resource "local_file" "kubeconfig" {
  content         = base64decode(data.external.kubeconfig.result.base64)
  filename        = "kubeconfig"
  file_permission = "0600"
  provisioner "local-exec" {
    command = "kubectl --kubeconfig=kubeconfig config set-cluster kubernetes --server=https://${oci_core_instance._[1].public_ip}:6443"
  }
}
