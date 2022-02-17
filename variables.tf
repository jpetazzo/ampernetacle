variable "name" {
  type    = string
  default = "kubernetes-on-arm-with-oracle"
}

/*
Available flex shapes:
"VM.Optimized3.Flex"  # Intel Ice Lake
"VM.Standard3.Flex"   # Intel Ice Lake
"VM.Standard.A1.Flex" # Ampere Altra
"VM.Standard.E3.Flex" # AMD Rome
"VM.Standard.E4.Flex" # AMD Milan
*/

variable "shape" {
  type    = string
  default = "VM.Standard.A1.Flex"
}

variable "how_many_nodes" {
  type    = number
  default = 4
}

variable "availability_domain" {
  type    = number
  default = 0
}

variable "ocpus_per_node" {
  type    = number
  default = 1
}

variable "memory_in_gbs_per_node" {
  type    = number
  default = 6
}

variable "tenancy_ocid" {
  type    = string
  default = "ocid1.tenancy.oc1..aaaaaaaa3onf6do5s3gk3qn45uny3g7s5wgs2bddlugek6ytruzr4n7eqinq"
}
variable "user_ocid" {
  type    = string
  default = "ocid1.user.oc1..aaaaaaaa4mfi4ngkxmbed7oi7a6hjmtefbimwsfccth5huccdboxt3trp3nq"
}
variable "fingerprint" {
  type    = string
  default = "d4:12:1a:6b:5b:60:87:af:84:32:ae:92:63:f9:7a:e4"
}
variable "private_key_path" {
  type    = string
  default = "/home/wagner/Downloads/oracleidentitycloudservice_wagnerbernardesteixeira-02-15-01-42.pem"
}
variable "region" {
  type    = string
  default = "uk-london-1"
}
variable "compartment_id" {
  type    = string
  default = "ocid1.tenancy.oc1..aaaaaaaa3onf6do5s3gk3qn45uny3g7s5wgs2bddlugek6ytruzr4n7eqinq"
}
