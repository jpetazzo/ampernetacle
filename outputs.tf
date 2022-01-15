output "ssh" {
  value = format(
    "\nssh -i %s -l %s %s\n",
    local_file.ssh_private_key.filename,
    "k8s",
    oci_core_instance._[1].public_ip
  )
}
