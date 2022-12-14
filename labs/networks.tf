resource "google_compute_network" "ext" {
  name = "external-vpc"
  auto_create_subnetworks = false
}
resource "google_compute_network" "int" {
  name = "internal-vpc"
  auto_create_subnetworks = false
}
resource "google_compute_network" "hasync" {
  name = "hasync-vpc"
  auto_create_subnetworks = false
}
resource "google_compute_network" "mgmt" {
  name = "mgmt-vpc"
  auto_create_subnetworks = false
}
resource "google_compute_network" "frontend" {
  name = "vpc-wrkld-frontend"
  auto_create_subnetworks = false
  delete_default_routes_on_create = true
}
resource "google_compute_network" "backend" {
  name = "vpc-wrkld-backend"
  auto_create_subnetworks = false
  delete_default_routes_on_create = true
}

resource "google_compute_subnetwork" "ext" {
  network       = google_compute_network.ext.self_link
  name          = "external-sb"
  region        = var.gcp_region
  ip_cidr_range = "172.20.0.0/24"
}
resource "google_compute_subnetwork" "int" {
  network       = google_compute_network.int.self_link
  name          = "internal-sb"
  region        = var.gcp_region
  ip_cidr_range = "172.20.1.0/24"
}
resource "google_compute_subnetwork" "hasync" {
  network       = google_compute_network.hasync.self_link
  name          = "hasync-sb"
  region        = var.gcp_region
  ip_cidr_range = "172.20.2.0/24"
}
resource "google_compute_subnetwork" "mgmt" {
  network       = google_compute_network.mgmt.self_link
  name          = "mgmt-sb"
  region        = var.gcp_region
  ip_cidr_range = "172.20.3.0/24"
}

resource "google_compute_subnetwork" "frontend" {
  network       = google_compute_network.frontend.self_link
  name          = "frontend"
  region        = var.gcp_region
  ip_cidr_range = "10.0.0.0/24"
}
resource "google_compute_subnetwork" "backend" {
  network       = google_compute_network.backend.self_link
  name          = "backend"
  region        = var.gcp_region
  ip_cidr_range = "10.0.1.0/24"
}
