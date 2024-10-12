provider "google" {
  project = var.project_id
  region  = var.region
}

# Create VPC network
resource "google_compute_network" "vpc_network" {
  name = "redis-vpc"
}

# Create subnets for clusters
resource "google_compute_subnetwork" "subnet" {
  for_each = {
    "primary-cluster"   = "10.1.0.0/16"
    "secondary-cluster" = "10.2.0.0/16"
  }

  name          = "${each.key}-subnet"
  region        = var.region
  ip_cidr_range = each.value
  network       = google_compute_network.vpc_network.self_link
}

# Create GKE clusters (using subnets)
resource "google_container_cluster" "cluster" {
  for_each = {
    for name in var.cluster_name : name => name
  }

  name               = each.key
  location           = var.region
  initial_node_count = var.num_nodes
  node_config {
    machine_type = var.machine_type
    disk_size_gb = 30
  }
  subnetwork = google_compute_subnetwork.subnet[each.key].self_link
}

# Create a backend service for the Load Balancer
resource "google_compute_backend_service" "redis_backend_service" {
  name     = "redis-backend-service"
  protocol = "TCP"
  load_balancing_scheme = "EXTERNAL"
  backend {
    group = google_container_cluster.cluster["primary-cluster"].instance_group_urls
  }
  backend {
    group = google_container_cluster.cluster["secondary-cluster"].instance_group_urls
  }
}

# Create a URL map for the Load Balancer
resource "google_compute_url_map" "redis_url_map" {
  name            = "redis-url-map"
  default_service = google_compute_backend_service.redis_backend_service.self_link
}

# Create a target TCP proxy for the Load Balancer
resource "google_compute_target_tcp_proxy" "redis_tcp_proxy" {
  name        = "redis-tcp-proxy"
  url_map     = google_compute_url_map.redis_url_map.self_link
}

# Create a global forwarding rule for the Load Balancer
resource "google_compute_global_forwarding_rule" "redis_forwarding_rule" {
  name       = "redis-forwarding-rule"
  target     = google_compute_target_tcp_proxy.redis_tcp_proxy.self_link
  port_range = "6379"
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

variable "cluster_name" {
  description = "List of cluster names"
  type        = list(string)
}

variable "machine_type" {
  description = "The machine type for the cluster nodes"
  type        = string
}

variable "num_nodes" {
  description = "The number of nodes in each cluster"
  type        = number
}