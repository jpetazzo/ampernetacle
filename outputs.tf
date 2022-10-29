output "ssh-with-k8s-user" {
  value = format(
    "\nssh -o StrictHostKeyChecking=no -i %s -l %s %s\n",
    local_file.ssh_private_key.filename,
    "k8s",
    oci_core_instance._[1].public_ip
  )
}

output "ssh-with-ubuntu-user" {
  value = join(
    "\n",
    [for i in oci_core_instance._ :
      format(
        "ssh -o StrictHostKeyChecking=no -l ubuntu -p 22 -i %s %s # %s",
        local_file.ssh_private_key.filename,
        i.public_ip,
        i.display_name
      )
    ]
  )
}
