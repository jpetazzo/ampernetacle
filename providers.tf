terraform {
  required_providers {
    oci = {
      source  = "oracle/oci"
      version = "5.27.0"
    }
  }
}

provider "oci" {
  tenancy_ocid        = var.tenancy_ocid
  config_file_profile = "DEFAULT"
}
