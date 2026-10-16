variable "project_id" {
  type        = string
  description = "GCP Project ID from tfvafs"
}
variable "sa_email" {
  type        = string
  description = "The service account email to associate with nodes"
}
# variable "ssh_keys" {
#   type        = string
#   description = "SSH keys to add to the instance metadata"
# }
variable "credential" {
  type        = string
  description = "The credential to access the gcloud"
}

module "providers" { source = "../../modules/gcp/provider" }

provider "google" {
  project     = var.project_id
  credentials = file(var.credential)
}

locals {
  nodes = [
    {
      name = "proteus-nixos-1"
      zone = "us-central1-c"
    },
  ]
}

module "network" { source = "../../modules/gcp/network" }

module "nodes" {
  source   = "../../modules/gcp/node"
  for_each = { for n in local.nodes : n.name => n }

  project  = var.project_id
  sa_email = var.sa_email
  # ssh_keys       = var.ssh_keys
  name           = each.value.name
  boot_disk_name = each.value.name
  zone           = each.value.zone

  network_id   = module.network.network_id
  network_name = module.network.network_name
}
