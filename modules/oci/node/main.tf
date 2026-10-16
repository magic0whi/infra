terraform {
  required_providers {
    oci = { source = "oracle/oci" } # version pinned in modules/oci/provider
  }
}
variable "compartment_id" { type = string }
variable "name" { type = string }
variable "subnet_id" { type = string }
variable "shape" {
  type    = string
  default = "VM.Standard.E2.1.Micro"
}
variable "ocpus" { # only for Flex shapes
  type    = number
  default = null
}
variable "memory_in_gbs" {
  type    = number
  default = null
}
variable "boot_volume_size_in_gbs" {
  type    = number
  default = 50 # null = image default (~47GB); custom sizes must be >= 50
}
variable "swap_volume_size_in_gbs" { # OCI block volume minimum is 50; null = no swap volume
  type    = number
  default = null
}
variable "ssh_keys" { # OCI wants plain authorized_keys format, no "user:" prefix
  type    = string
  default = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHBAm5d2IeApyfv8zLb7IMpex7wVHkCV86ztON7HFTkn proteus"
}

data "oci_identity_availability_domains" "ads" { compartment_id = var.compartment_id }

data "oci_core_images" "ubuntu" {
  compartment_id           = var.compartment_id
  operating_system         = "Canonical Ubuntu"
  operating_system_version = "24.04"
  shape                    = var.shape
  sort_by                  = "TIMECREATED"
  sort_order               = "DESC"
}

resource "oci_core_instance" "node" {
  compartment_id      = var.compartment_id
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
  display_name        = var.name
  shape               = var.shape

  dynamic "shape_config" {
    for_each = var.ocpus == null ? [] : [1]
    content {
      ocpus         = var.ocpus
      memory_in_gbs = var.memory_in_gbs
    }
  }

  create_vnic_details {
    subnet_id              = var.subnet_id
    assign_public_ip       = true
    hostname_label         = var.name
    skip_source_dest_check = true # equivalent of can_ip_forward
  }

  source_details {
    source_type             = "image"
    source_id               = data.oci_core_images.ubuntu.images[0].id
    boot_volume_size_in_gbs = var.boot_volume_size_in_gbs
  }

  metadata = { ssh_authorized_keys = var.ssh_keys }
}

resource "oci_core_volume" "swap_tmp" {
  count               = var.swap_volume_size_in_gbs == null ? 0 : 1
  compartment_id      = var.compartment_id
  availability_domain = oci_core_instance.node.availability_domain
  display_name        = "${var.name}-swap-tmp"
  size_in_gbs         = var.swap_volume_size_in_gbs
}

resource "oci_core_volume_attachment" "swap_tmp" {
  count           = length(oci_core_volume.swap_tmp)
  attachment_type = "paravirtualized" # shows up as a plain disk, no iSCSI login needed
  instance_id     = oci_core_instance.node.id
  volume_id       = oci_core_volume.swap_tmp[0].id
  display_name    = "${var.name}-swap-tmp"
}

moved {
  from = oci_core_volume.swap_tmp
  to   = oci_core_volume.swap_tmp[0]
}
moved {
  from = oci_core_volume_attachment.swap_tmp
  to   = oci_core_volume_attachment.swap_tmp[0]
}

output "public_ip" { value = oci_core_instance.node.public_ip }
