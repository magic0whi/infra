# resource "google_compute_disk" "swap_tmp" {
#   name = "${var.name}-swap-tmp"
#   zone = var.zone
#   type = "pd-balanced"
#   size = 4
# }

resource "google_compute_instance" "node" {
  name         = var.name
  zone         = var.zone
  machine_type = "e2-micro"
  tags         = concat(["allow-icmp", "allow-ssh", "allow-https", "allow-iperf3", "allow-easytier"], var.extra_tags)

  allow_stopping_for_update = true
  desired_status            = var.desired_status
  can_ip_forward            = true
  enable_display            = true
  deletion_protection       = false
  labels                    = { goog-ec-src = "vm_add-tf" }

  metadata = {
    serial-port-enable = true
    ssh-keys           = var.ssh_keys
  }

  # attached_disk {
  #   source      = google_compute_disk.swap_tmp.id
  #   device_name = google_compute_disk.swap_tmp.name
  #   mode        = "READ_WRITE"
  # }

  boot_disk {
    auto_delete = true
    device_name = var.boot_disk_name
    initialize_params {
      image = "projects/debian-cloud/global/images/debian-13-trixie-v20260310"
      size  = 30
      type  = "pd-standard"
    }
    mode = "READ_WRITE"
  }

  network_interface {
    network    = var.network_id
    subnetwork = var.network_name
    access_config { network_tier = "STANDARD" }
  }

  service_account {
    email = var.sa_email
    scopes = [
      "https://www.googleapis.com/auth/devstorage.read_only",
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring.write",
      "https://www.googleapis.com/auth/service.management.readonly",
      "https://www.googleapis.com/auth/servicecontrol",
      "https://www.googleapis.com/auth/trace.append"
    ]
  }

  shielded_instance_config {
    enable_integrity_monitoring = true
    enable_secure_boot          = false
    enable_vtpm                 = true
  }
}
