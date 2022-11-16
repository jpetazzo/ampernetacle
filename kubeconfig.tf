locals {
  is_windows = substr(pathexpand("~"), 0, 1) == "/" ? false : true
}
locals {
  bash       = "while ! curl -k https://${oci_core_instance._[1].public_ip}:6443; do sleep 1; done"
  powershell = "powershell .\\winInsecureCurl.ps1 ${oci_core_instance._[1].public_ip}"
  get_kubeconfig = "while ! sudo grep -q user /etc/kubernetes/admin.conf ; do sleep 1; done; sudo base64 -w0 /etc/kubernetes/admin.conf"
}

resource "null_resource" "wait_for_kube_apiserver" {
  depends_on = [oci_core_instance._[1]]
  provisioner "local-exec" {
    command = local.is_windows ? local.powershell : local.bash
  }
}

data "external" "kubeconfig" {
  depends_on = [null_resource.wait_for_kube_apiserver]
  program = local.is_windows ? [
    "powershell",
    <<EOT
    write-host "{`"base64`": `"$(ssh -o StrictHostKeyChecking=no -l k8s -i ${local_file.ssh_private_key.filename} ${oci_core_instance._[1].public_ip} "${local.get_kubeconfig}")`"}"
    EOT
    ] : [
    "sh",
    "-c",
    <<-EOT
      set -e
      cat >/dev/null
      echo '{"base64": "'$(
        ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
              -l k8s -i ${local_file.ssh_private_key.filename} \
              ${oci_core_instance._[1].public_ip} \
              "${local.get_kubeconfig}"
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
