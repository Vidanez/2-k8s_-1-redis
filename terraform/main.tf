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
