variable "project_id" {
  type        = string
  description = "GCP Project ID from tfvafs"
}
variable "sa_email" {
  type        = string
  description = "The service account email to associate with nodes"
}
variable "credential" {
  type        = string
  description = "The credential to access the gcloud"
}

provider "google" {
  project     = var.project_id
  credentials = file(var.credential)
}

locals {
  nodes = [
    {
      name = "proteus-nixos-2"
      zone = "europe-west10-c"
    },
    {
      name = "proteus-nixos-3"
      zone = "asia-northeast1-b"
    },
    {
      name = "proteus-nixos-4"
      zone = "europe-west2-c"
    },
    {
      name = "proteus-nixos-5"
      zone = "asia-east2-a"
    }
  ]
}

module "network" { source = "../../modules/vpc_network" }

module "nodes" {
  source   = "../../modules/gce_node"
  for_each = { for n in local.nodes : n.name => n }

  project        = var.project_id
  sa_email       = var.sa_email
  name           = each.value.name
  boot_disk_name = each.value.name
  zone           = each.value.zone

  network_id   = module.network.network_id
  network_name = module.network.network_name
}
