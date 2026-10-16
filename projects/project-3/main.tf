terraform {
  required_providers {
    oci = { source = "oracle/oci" } # version pinned in modules/oci/provider
  }
}
variable "compartment_id" {
  type        = string
  description = "OCI compartment OCID (tenancy OCID = root compartment)"
}

module "providers" { source = "../../modules/oci/provider" }

provider "oci" { config_file_profile = "DEFAULT" } # auth + region from ~/.oci/config
provider "oci" {
  alias               = "tokyo"
  config_file_profile = "DEFAULT"
  region              = "ap-tokyo-1"
}

variable "temp_nodes" {
  type        = bool
  default     = false
  description = "Create temporary paid nodes to build billing history (apply -var temp_nodes=true; plain apply destroys them)"
}

locals {
  nodes = [{ name = "proteus-nixos-3" }]
  # Always Free only applies in the home region, so A1.Flex is billed here
  tokyo_temp_nodes = var.temp_nodes ? [{ name = "proteus-tmp-0", shape = "VM.Standard.A1.Flex", ocpus = 1, memory_in_gbs = 2 }] : []
}

module "network" {
  source         = "../../modules/oci/network"
  compartment_id = var.compartment_id
}

module "network_tokyo" {
  source         = "../../modules/oci/network"
  providers      = { oci = oci.tokyo }
  compartment_id = var.compartment_id
  cidr           = "10.43.0.0/16"
}

module "nodes" {
  source   = "../../modules/oci/node"
  for_each = { for n in local.nodes : n.name => n }

  compartment_id          = var.compartment_id
  name                    = each.value.name
  swap_volume_size_in_gbs = try(each.value.swap_in_gbs, null)
  subnet_id               = module.network.subnet_id
}

module "temp_nodes_tokyo" {
  source    = "../../modules/oci/node"
  providers = { oci = oci.tokyo }
  for_each  = { for n in local.tokyo_temp_nodes : n.name => n }

  compartment_id          = var.compartment_id
  name                    = each.value.name
  shape                   = each.value.shape
  ocpus                   = each.value.ocpus
  memory_in_gbs           = each.value.memory_in_gbs
  swap_volume_size_in_gbs = try(each.value.swap_in_gbs, null)
  subnet_id               = module.network_tokyo.subnet_id
}
