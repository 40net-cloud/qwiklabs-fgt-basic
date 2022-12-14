module "fgt_ha" {
  source = "./fortigate-gcp-ha-ap-lb-terraform"

  region = var.gcp_region
  image_family = "fortigate-72-byol"
  subnets = [
    google_compute_subnetwork.ext.name,
    google_compute_subnetwork.int.name,
    google_compute_subnetwork.hasync.name,
    google_compute_subnetwork.mgmt.name,
  ]
  frontends = ["qwik-app1"]

  depends_on = [
    google_compute_network_peering.hub_to_front,
    google_compute_network_peering.front_to_hub,
    google_compute_network_peering.hub_to_back,
    google_compute_network_peering.back_to_hub
  ]
}

resource "google_compute_instance" "frontend" {
  zone = var.gcp_zone
  name = "wrkld-frontend-vm"
  machine_type = "e2-standard-2"
  tags = ["frontend"]
  boot_disk {
    initialize_params {
      image              = "projects/ubuntu-os-cloud/global/images/family/ubuntu-2204-lts"
    }
  }
  network_interface {
    subnetwork           = google_compute_subnetwork.frontend.id
    network_ip           = "10.0.0.2"
  }
  metadata = {
    startup-script = file("./startup-script-frontend.tpl")
  }
}

resource "google_compute_instance" "backend" {
  zone = var.gcp_zone
  name = "wrkld-backend-vm"
  machine_type = "e2-standard-2"
  tags = ["backend"]
  boot_disk {
    initialize_params {
      image              = "projects/ubuntu-os-cloud/global/images/family/ubuntu-2204-lts"
    }
  }
  network_interface {
    subnetwork           = google_compute_subnetwork.backend.id
    network_ip           = "10.0.1.2"
  }
  metadata_startup_script = file("./startup-script-backend.sh")

  metadata = {
    app-code = filebase64("./webapp/app.tar.gz")
  }
}

resource "google_compute_network_peering" "hub_to_front" {
  name                 = "peer-hub-front"
  network              = google_compute_network.int.self_link
  peer_network         = google_compute_network.frontend.self_link
  export_custom_routes = true
}
resource "google_compute_network_peering" "front_to_hub" {
  name                 = "peer-front-hub"
  network              = google_compute_network.frontend.self_link
  peer_network         = google_compute_network.int.self_link
  import_custom_routes = true
}

resource "google_compute_network_peering" "hub_to_back" {
  name                 = "peer-hub-backend"
  network              = google_compute_network.int.self_link
  peer_network         = google_compute_network.backend.self_link
  export_custom_routes = true
}
resource "google_compute_network_peering" "back_to_hub" {
  name                 = "peer-backend-hub"
  network              = google_compute_network.backend.self_link
  peer_network         = google_compute_network.int.self_link
  import_custom_routes = true
}

resource "google_compute_firewall" "tofrontend" {
  name                 = "fw-frontend-allow"
  network              = google_compute_network.frontend.self_link
  source_ranges        = ["0.0.0.0/0"]
  target_tags          = ["frontend"]

  allow {
    protocol             = "all"
  }
}

resource "google_compute_firewall" "tobackend" {
  name                 = "fw-backend-allow"
  network              = google_compute_network.backend.self_link
  source_ranges        = ["10.0.0.0/8"]
  target_tags          = ["backend"]

  allow {
    protocol             = "all"
  }
}
