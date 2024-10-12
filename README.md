# OPTION 1 SOLUTION NOT USING MULTI-CLUSTER

## Overview

This project demonstrates how to set up a Redis Cluster across two Kubernetes clusters using Terraform and Helm on Google Cloud Platform (GCP). The goal is to deploy a Redis Cluster that spans two GKE clusters, ensuring high availability and data consistency.

## Prerequisites

- A Google Cloud Platform (GCP) account.

## Setup Instructions

### 1. Clone the Repository

First, clone the repository to your local machine or GCP Shell Console.

```sh
git clone https://github.com/Vidanez/2-k8s_1-redis.git
cd 2-k8s_1-redis
```

### 2. Initialize Terraform

Initialize Terraform in the cloned repository directory.

```sh
terraform init
```

### 3. Apply Terraform Configuration

Run the Terraform apply command to create the VPC, subnets, and Kubernetes clusters.

```sh
terraform apply
```

Confirm the apply action when prompted. Terraform will create the VPC, subnets, and two GKE clusters as defined in the `main.tf` file.

### 4. Configure Kubernetes Contexts

Set up contexts for both clusters to easily switch between them.

```sh
# Get credentials and set context for primary cluster
gcloud container clusters get-credentials primary-cluster --zone europe-west1
kubectl config rename-context $(kubectl config current-context) primary-cluster

# Get credentials and set context for secondary cluster
gcloud container clusters get-credentials secondary-cluster --zone europe-west1
kubectl config rename-context $(kubectl config current-context) secondary-cluster
```

## Deployment Instructions

### 1. Prepare `values.yaml` for Redis Cluster Helm Chart

Create a `values.yaml` file with the necessary configuration for Redis Cluster.

```yaml
# values.yaml for Redis Helm chart
global:
  name: redis-cluster

cluster:
  enabled: true
  slaveCount: 1
  replicas: 6
  resources:
    requests:
      memory: "256Mi"
      cpu: "100m"
    limits:
      memory: "512Mi"
      cpu: "200m"

service:
  type: ClusterIP
  annotations:
    service.alpha.kubernetes.io/tolerate-unready-endpoints: "true"

redis:
  password: ""
  tls:
    enabled: false

networkPolicy:
  enabled: false

persistence:
  enabled: false

metrics:
  enabled: false
```

### 2. Deploy Redis Cluster Using Helm

Deploy the Redis Cluster Helm chart to both clusters using the configured `values.yaml`.

```sh
# Deploy to primary cluster
helm install redis-cluster-primary bitnami/redis-cluster -f values.yaml --kube-context primary-cluster

# Deploy to secondary cluster
helm install redis-cluster-secondary bitnami/redis-cluster -f values.yaml --kube-context secondary-cluster
```

### 3. Deploy Headless Service for Redis Cluster

Create and deploy a headless service to enable service discovery.

Create a `redis-headless-service.yaml` file with the following content:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: redis-headless
  labels:
    app: redis
spec:
  ports:
  - port: 6379
    name: redis
  clusterIP: None
  selector:
    app: redis
```

Deploy this service in both clusters:

```sh
# Deploy headless service to primary cluster
kubectl apply -f redis-headless-service.yaml --context primary-cluster

# Deploy headless service to secondary cluster
kubectl apply -f redis-headless-service.yaml --context secondary-cluster
```

#### Why and Usage of the Redis Headless Service

The headless service is used to enable service discovery within the Kubernetes clusters. By setting `clusterIP: None`, the service does not get a cluster IP address, and instead, DNS queries for the service return the IP addresses of the associated pods. This allows Redis nodes to discover each other and form a cluster.

### 4. Configure Global Load Balancer

Set up a global load balancer to route traffic to the Redis instances across both clusters.

Create a `main.tf` file with the following content:

```hcl
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
```

### Note on Load Balancer Configuration

The Load Balancer configuration is optional but recommended for simplifying client access to the Redis Cluster. It provides a single endpoint for clients to connect to, abstracting the complexity of managing multiple Redis nodes.

## Testing and Validation

### 1. Check Redis Cluster Status

Check the status of the Redis Cluster.

```sh
# Get the Redis Cluster pod name in the primary cluster
REDIS_CLUSTER_POD_PRIMARY=$(kubectl get pods --context primary-cluster -l app.kubernetes.io/name=redis-cluster -o jsonpath="{.items.metadata.name}")

# Check the status of the Redis Cluster
kubectl exec -it $REDIS_CLUSTER_POD_PRIMARY --context primary-cluster -- redis-cli -c cluster nodes
```

### 2. Inject Data and Verify Consistency

Inject data into Redis Cluster and verify that it is consistent across both clusters.

```sh
# Inject data into Redis Cluster in the primary cluster
kubectl exec -it $REDIS_CLUSTER_POD_PRIMARY --context primary-cluster -- redis-cli -c set key "value"

# Get the Redis Cluster pod name in the secondary cluster
REDIS_CLUSTER_POD_SECONDARY=$(kubectl get pods --context secondary-cluster -l app.kubernetes.io/name=redis-cluster -o jsonpath="{.items.metadata.name}")

# Retrieve data from Redis Cluster in the secondary cluster
kubectl exec -it $REDIS_CLUSTER_POD_SECONDARY --context secondary-cluster -- redis-cli -c get key
```

### 3. Simulate Failures

Simulate node, cluster, and Redis pod failures to test the high availability setup.

```sh
# Get the Redis master pod name in the primary cluster
REDIS_MASTER_POD=$(kubectl get pods --context primary-cluster -l app.kubernetes.io/name=redis-cluster,role=master -o jsonpath="{.items.metadata.name}")

# Delete the Redis master pod to simulate a failover
kubectl delete pod $REDIS_MASTER_POD --context primary-cluster

# Check the status of the Redis Cluster to see the new master
kubectl exec -it $REDIS_CLUSTER_POD_PRIMARY --context primary-cluster -- redis-cli -c cluster nodes
```

## Troubleshooting

### Common Issues

1. **Terraform Apply Errors:**
   - Ensure your GCP project ID is correct and you have the necessary permissions.

2. **Kubernetes Context Configuration:**
   - Verify that the contexts are correctly set up and you can switch between them without issues.

3. **Redis Cluster Deployment Issues:**
   - Check the Helm deployment logs for any errors and ensure the `values.yaml` file is correctly configured.

---

### Files to Include in the Repository

1. **`main.tf`** (Terraform configuration file)
2. **`terraform.tfvars`** (Terraform variables values file)
3. **`values.yaml`** (Helm values file for Redis Cluster)
4. **`redis-headless-service.yaml`** (Headless service for Redis)

# OPTION 2 SOLUTION USING MULTI-CLUSTER

https://github.com/bryonbaker/rhai-redis-demo/blob/main/doc/demo-script.md Building a Global Redis Cache with OpenShift and Red Hat Application Interconnect (aka Skupper)
