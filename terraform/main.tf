provider "google" {
  project = "hip-limiter-345408"
  region  = "europe-west1"
}

resource "google_container_cluster" "primary" {
  name     = "primary-cluster"
  location = "europe-west1"
  node_config {
    machine_type = "e2-medium"
    disk_size_gb = 30
  }
  initial_node_count = 1
}

resource "google_container_cluster" "secondary" {
  name     = "secondary-cluster"
  location = "europe-west1"
  node_config {
    machine_type = "e2-medium"
    disk_size_gb = 30
  }
  initial_node_count = 1
}
