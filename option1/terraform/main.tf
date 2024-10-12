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

# Create instance templates for clusters
resource "google_compute_instance_template" "instance_template" {
  for_each = google_container_cluster.cluster

  name         = "${each.key}-instance-template"
  machine_type = var.machine_type
  disks {
    boot  = true
    auto_delete = true
    source_image = "projects/debian-cloud/global/images/family/debian-10"
  }
  network_interfaces {
    network    = google_compute_network.vpc_network.name
    subnetwork = google_compute_subnetwork.subnet[each.key].name
  }
}

# Create instance group managers for clusters
resource "google_compute_instance_group_manager" "instance_group_manager" {
  for_each = google_compute_instance_template.instance_template

  name               = "${each.key}-instance-group-manager"
  base_instance_name = each.key
  instance_template  = each.value.self_link
  zone               = "${var.region}-b"
  target_size        = var.num_nodes

  version {
    instance_template = each.value.self_link
  }
}

# Create a backend service for the Load Balancer
resource "google_compute_backend_service" "redis_backend_service" {
  name     = "redis-backend-service"
  protocol = "TCP"
  load_balancing_scheme = "EXTERNAL"
  backend {
    group = google_compute_instance_group_manager.instance_group_manager["primary-cluster"].self_link
  }
  backend {
    group = google_compute_instance_group_manager.instance_group_manager["secondary-cluster"].self_link
  }
}

# Create a target TCP proxy for the Load Balancer
resource "google_compute_target_tcp_proxy" "redis_tcp_proxy" {
  name            = "redis-tcp-proxy"
  backend_service = google_compute_backend_service.redis_backend_service.self_link
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
