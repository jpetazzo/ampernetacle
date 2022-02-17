terraform {
  cloud {
    organization = "wagner-bernardes-teixeira"
    workspaces {
      name = "kubernetes-on-arm-with-oracle"
    }
  }
}
# terraform {
#   backend "remote" {
#     organization = "wagner-bernardes-teixeira"

#     workspaces {
#       name = "kubernetes-on-arm-with-oracle"
#     }
#   }
# }
