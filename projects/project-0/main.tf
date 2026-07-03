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

provider "google" {
  project     = var.project_id
  credentials = file(var.credential)
}

locals { # Define Nodes
  nodes = [
    {
      name = "proteus-nixos-0"
      zone = "us-west1-b"
      # desired_status = "TERMINATED"
    }
  ]
}

module "network" { source = "../../modules/vpc_network" }

module "nodes" {
  source   = "../../modules/gce_node"
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

# Temporary Rescue VM for fixing proteus-nixos-0
# resource "google_compute_instance" "rescue_vm" {
#   name         = "nixos-rescue-vm"
#   zone         = "us-west1-b"
#   machine_type = "e2-micro"
#   # Allow standard access for debugging
#   tags = ["allow-icmp", "allow-ssh", "allow-https", "allow-iperf3", "allow-easytier"]

#   allow_stopping_for_update = true
#   desired_status            = "RUNNING"
#   can_ip_forward            = true
#   enable_display            = true
#   deletion_protection       = false
#   labels                    = { goog-ec-src = "vm_add-tf" }


#   metadata = {
#     serial-port-enable = true
#     ssh-keys           = var.ssh_keys
#   }

#   boot_disk {
#     initialize_params {
#       image = "projects/debian-cloud/global/images/debian-13-trixie-v20260310"
#       size  = 30
#       type  = "pd-standard"
#     }
#     mode = "READ_WRITE"
#   }

#   # Attach the broken instance's boot disk as a secondary drive
#   attached_disk {
#     # Reference the disk created by the module for proteus-nixos-0
#     source      = "projects/${var.project_id}/zones/us-west1-b/disks/proteus-nixos-0"
#     device_name = "broken-disk"
#     mode        = "READ_WRITE"
#   }

#   network_interface {
#     network    = module.network.network_id
#     subnetwork = module.network.network_name
#     access_config { network_tier = "STANDARD" }
#   }
#   service_account {
#     email = var.sa_email
#     scopes = [
#       "https://www.googleapis.com/auth/devstorage.read_only",
#       "https://www.googleapis.com/auth/logging.write",
#       "https://www.googleapis.com/auth/monitoring.write",
#       "https://www.googleapis.com/auth/service.management.readonly",
#       "https://www.googleapis.com/auth/servicecontrol",
#       "https://www.googleapis.com/auth/trace.append"
#     ]
#   }
#   shielded_instance_config {
#     enable_integrity_monitoring = true
#     enable_secure_boot          = false
#     enable_vtpm                 = true
#   }
# }
