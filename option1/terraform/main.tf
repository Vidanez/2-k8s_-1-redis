provider "google" {
  project = var.project_id
  region  = var.region
}

variable "project_id" {
  description = "The project ID to deploy to"
  type        = string
}

variable "region" {
  description = "The region to deploy to"
  type        = string
}

variable "machine_type" {
  description = "The machine type to use for the nodes"
  type        = string
}

variable "num_nodes" {
  description = "The number of nodes to create in the cluster"
  type        = number
}

resource "google_compute_network" "vpc_network" {
  name = "redis-vpc"
}

resource "google_compute_subnetwork" "primary_subnet" {
  name          = "primary-cluster-subnet"
  ip_cidr_range = "10.0.0.0/16"
  region        = var.region
  network       = google_compute_network.vpc_network.id
}

resource "google_compute_subnetwork" "secondary_subnet" {
  name          = "secondary-cluster-subnet"
  ip_cidr_range = "10.1.0.0/16"
  region        = var.region
  network       = google_compute_network.vpc_network.id
}

resource "google_compute_firewall" "allow-internal" {
  name    = "allow-internal"
  network = google_compute_network.vpc_network.name

  allow {
    protocol = "tcp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "udp"
    ports    = ["0-65535"]
  }

  source_ranges = ["10.0.0.0/16", "10.1.0.0/16"]
}

resource "google_compute_firewall" "allow-external" {
  name    = "allow-external"
  network = google_compute_network.vpc_network.name

  allow {
    protocol = "tcp"
    ports    = ["22", "3389", "80", "443"]
  }

  source_ranges = ["0.0.0.0/0"]
}

resource "google_container_cluster" "primary_cluster" {
  name               = "primary-cluster"
  location           = var.region
  network            = google_compute_network.vpc_network.id
  subnetwork         = google_compute_subnetwork.primary_subnet.id
  initial_node_count = var.num_nodes
  deletion_protection = false

  node_config {
    machine_type = var.machine_type
    disk_size_gb = 50  
  }
}

resource "google_container_cluster" "secondary_cluster" {
  name               = "secondary-cluster"
  location           = var.region
  network            = google_compute_network.vpc_network.id
  subnetwork         = google_compute_subnetwork.secondary_subnet.id
  initial_node_count = var.num_nodes
  deletion_protection = false

  node_config {
    machine_type = var.machine_type
    disk_size_gb = 50  
  }
}
