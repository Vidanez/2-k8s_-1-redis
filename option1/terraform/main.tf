provider "google" {
  project = var.project_id
  region  = var.region
}

# Create VPC network
resource "google_compute_network" "vpc_network" {
  name = "redis-vpc"
}

# Create subnet for primary cluster
resource "google_compute_subnetwork" "primary_subnet" {
  name          = "primary-cluster-subnet"
  region        = var.region
  ip_cidr_range = "10.1.0.0/16"
  network       = google_compute_network.vpc_network.self_link
}

# Create subnet for secondary cluster
resource "google_compute_subnetwork" "secondary_subnet" {
  name          = "secondary-cluster-subnet"
  region        = var.region
  ip_cidr_range = "10.2.0.0/16"
  network       = google_compute_network.vpc_network.self_link
}

# Create primary GKE cluster
resource "google_container_cluster" "primary_cluster" {
  name               = "primary-cluster"
  location           = var.region
  initial_node_count = var.num_nodes
  node_config {
    machine_type = var.machine_type
    disk_size_gb = 30
  }
  subnetwork = google_compute_subnetwork.primary_subnet.self_link
}

# Create secondary GKE cluster
resource "google_container_cluster" "secondary_cluster" {
  name               = "secondary-cluster"
  location           = var.region
  initial_node_count = var.num_nodes
  node_config {
    machine_type = var.machine_type
    disk_size_gb = 30
  }
  subnetwork = google_compute_subnetwork.secondary_subnet.self_link
}

# Allow internal traffic
resource "google_compute_firewall" "allow-internal" {
  name    = "allow-internal"
  network = google_compute_network.vpc_network.name

  allow {
    protocol = "tcp"
    ports    = ["6379"]
  }

  source_ranges = ["10.0.0.0/8"]
}

# Allow external traffic to Load Balancer
resource "google_compute_firewall" "allow-external" {
  name    = "allow-external"
  network = google_compute_network.vpc_network.name

  allow {
    protocol = "tcp"
    ports    = ["6379"]
  }

  source_ranges = ["0.0.0.0/0"]
}

# Variable declarations
variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "region" {
  description = "The GCP region"
  type        = string
}

variable "machine_type" {
  description = "The machine type for the cluster nodes"
  type        = string
}

variable "num_nodes" {
  description = "The number of nodes in each cluster"
  type        = number
}