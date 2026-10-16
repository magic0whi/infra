terraform {
  required_providers {
    oci = { source = "oracle/oci" } # version pinned in modules/oci/provider
  }
}
variable "compartment_id" { type = string }
variable "cidr" {
  type    = string
  default = "10.42.0.0/16"
}

locals {
  tcp = [[22, 22], [443, 443], [8443, 8443], [3901, 3901], [5201, 5201], [11010, 11013]]
  udp = [[443, 443], [8443, 8443], [5201, 5201], [11010, 11012]]
}

resource "oci_core_vcn" "vcn" {
  compartment_id = var.compartment_id
  display_name   = "terraform-network"
  cidr_blocks    = [var.cidr]
  dns_label      = "tfnet"
}

resource "oci_core_internet_gateway" "igw" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.vcn.id
  display_name   = "terraform-network-igw"
}

resource "oci_core_default_route_table" "rt" {
  manage_default_resource_id = oci_core_vcn.vcn.default_route_table_id
  route_rules {
    destination       = "0.0.0.0/0"
    network_entity_id = oci_core_internet_gateway.igw.id
  }
}

resource "oci_core_security_list" "sl" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.vcn.id
  display_name   = "terraform-network-sl"

  egress_security_rules {
    destination = "0.0.0.0/0"
    protocol    = "all"
  }
  ingress_security_rules {
    source   = "0.0.0.0/0"
    protocol = "1" # ICMP
  }
  ingress_security_rules { # internal
    source   = var.cidr
    protocol = "all"
  }
  dynamic "ingress_security_rules" {
    for_each = local.tcp
    content {
      source   = "0.0.0.0/0"
      protocol = "6" # TCP
      tcp_options {
        min = ingress_security_rules.value[0]
        max = ingress_security_rules.value[1]
      }
    }
  }
  dynamic "ingress_security_rules" {
    for_each = local.udp
    content {
      source   = "0.0.0.0/0"
      protocol = "17" # UDP
      udp_options {
        min = ingress_security_rules.value[0]
        max = ingress_security_rules.value[1]
      }
    }
  }
}

resource "oci_core_subnet" "public" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.vcn.id
  # Adding 8 bits, slice '/16 + 8 = /24', netnum 0 picks the first subnet
  cidr_block        = cidrsubnet(var.cidr, 8, 0)
  display_name      = "terraform-network-public"
  dns_label         = "public"
  route_table_id    = oci_core_vcn.vcn.default_route_table_id
  security_list_ids = [oci_core_security_list.sl.id]
}

output "subnet_id" { value = oci_core_subnet.public.id }
