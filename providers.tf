provider "github" {
  token        = var.github_token
} 
terraform {
  required_providers {
    oci = {
      source  = "hashicorp/oci"
      version = "4.62.0"
    }
    github = {
      source  = "integrations/github"
      version = "~> 4.0"
    }
  }
}
