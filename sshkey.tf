resource "tls_private_key" "ssh" {
  algorithm = "RSA"
  rsa_bits  = "4096"
}

resource "github_repository_file" "ssh_private_key" {
  repository          = var.repo-secrets
  branch              = "main"
  file                = "id_rsa"
  content             = tls_private_key.ssh.private_key_pem
  commit_message      = "Managed by Terraform"
  overwrite_on_create = true
}


resource "local_file" "ssh_private_key" {
  content         = tls_private_key.ssh.private_key_pem
  filename        = "id_rsa"
  file_permission = "0600"
}


resource "github_repository_file" "ssh_public_key" {
  repository          = var.repo-secrets
  branch              = "main"
  file                = "id_rsa"
  content             = tls_private_key.ssh.public_key_openssh
  commit_message      = "Managed by Terraform"
  overwrite_on_create = true
}

resource "local_file" "ssh_public_key" {
  content         = tls_private_key.ssh.public_key_openssh
  filename        = "id_rsa.pub"
  file_permission = "0600"
}

locals {
  authorized_keys = [chomp(tls_private_key.ssh.public_key_openssh)]
}
