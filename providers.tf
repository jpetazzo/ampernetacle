terraform {
  required_providers {
    oci = {
      source  = "oracle/oci"
      version = "4.76.0"
    }
  }
}


provider "oci" {
  auth                = "SecurityToken"
  config_file_profile = "default"
  region              = "eu-amsterdam-1"
}
