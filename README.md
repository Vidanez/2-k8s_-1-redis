Sure, here's the updated README file without the content of the configuration files:

---

# Redis High Availability Setup Across Two Kubernetes Clusters

## Overview

This project demonstrates how to set up a Redis cluster with high availability across two Kubernetes clusters using Terraform and Helm on Google Cloud Platform (GCP). The goal is to deploy a Redis cluster that spans two GKE clusters, ensuring high availability and data consistency.

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

Run the Terraform apply command to create the Kubernetes clusters.

```sh
terraform apply
```

Confirm the apply action when prompted. Terraform will create the two GKE clusters as defined in the `main.tf` file.

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

### 1. Prepare `values.yaml` for Redis Helm Chart

Create a `values.yaml` file with the necessary configuration for Redis high availability.

### 2. Deploy Redis Using Helm

Deploy the Redis Helm chart to both clusters using the configured `values.yaml`.

```sh
# Deploy to primary cluster
helm install redis-primary bitnami/redis -f values.yaml --kube-context primary-cluster

# Deploy to secondary cluster
helm install redis-secondary bitnami/redis -f values.yaml --kube-context secondary-cluster
```

### 3. Deploy Headless Service for Redis

Create and deploy a headless service to enable service discovery.

Deploy this service in both clusters:

```sh
# Deploy headless service to primary cluster
kubectl apply -f redis-headless-service.yaml --context primary-cluster

# Deploy headless service to secondary cluster
kubectl apply -f redis-headless-service.yaml --context secondary-cluster
```

### 4. Configure Global Load Balancer

Set up a global load balancer to route traffic to the Redis instances across both clusters.

```sh
# Create a backend service
gcloud compute backend-services create redis-backend-service --global

# Add instance groups from both clusters to the backend service
gcloud compute backend-services add-backend redis-backend-service --instance-group=primary-cluster-group --instance-group-zone=europe-west1-b --global
gcloud compute backend-services add-backend redis-backend-service --instance-group=secondary-cluster-group --instance-group-zone=europe-west1-b --global

# Create a URL map
gcloud compute url-maps create redis-url-map --default-service redis-backend-service

# Create a target HTTP proxy
gcloud compute target-http-proxies create redis-http-proxy --url-map=redis-url-map

# Create a global forwarding rule
gcloud compute forwarding-rules create redis-forwarding-rule --global --target-http-proxy=redis-http-proxy --ports=6379
```

## Testing and Validation

### 1. Inject Data and Verify Consistency

Inject data into Redis and verify that it is consistent across both clusters.

```sh
# Get the Redis pod name in the primary cluster
REDIS_POD_PRIMARY=$(kubectl get pods --context primary-cluster -l app.kubernetes.io/name=redis -o jsonpath="{.items.metadata.name}")

# Inject data into Redis in primary cluster
kubectl exec -it $REDIS_POD_PRIMARY --context primary-cluster -- redis-cli set key "value"

# Get the Redis pod name in the secondary cluster
REDIS_POD_SECONDARY=$(kubectl get pods --context secondary-cluster -l app.kubernetes.io/name=redis -o jsonpath="{.items.metadata.name}")

# Retrieve data from Redis in secondary cluster
kubectl exec -it $REDIS_POD_SECONDARY --context secondary-cluster -- redis-cli get key
```

### 2. Simulate Failures

Simulate node, cluster, and Redis pod failures to test the high availability setup.

```sh
# Get the node name in the primary cluster
NODE_NAME_PRIMARY=$(kubectl get nodes --context primary-cluster -o jsonpath="{.items.metadata.name}")

# Simulate node failure in primary cluster
kubectl drain $NODE_NAME_PRIMARY --ignore-daemonsets --delete-local-data --context primary-cluster

# Simulate cluster failure
gcloud container clusters delete secondary-cluster --zone europe-west1

# Simulate Redis pod failure in primary cluster
kubectl delete pod $REDIS_POD_PRIMARY --context primary-cluster
```

## Troubleshooting

### Common Issues

1. **Terraform Apply Errors:**
   - Ensure your GCP project ID is correct and you have the necessary permissions.

2. **Kubernetes Context Configuration:**
   - Verify that the contexts are correctly set up and you can switch between them without issues.

3. **Redis Deployment Issues:**
   - Check the Helm deployment logs for any errors and ensure the `values.yaml` file is correctly configured.

---

### Files to Include in the Repository

1. **`main.tf`** (Terraform configuration file)
2. **`values.yaml`** (Helm values file for Redis)
3. **`redis-headless-service.yaml`** (Headless service for Redis)

By including these files and following the steps outlined in the README, you will be able to set up and demonstrate a Redis cluster with high availability across two Kubernetes clusters on GCP. If you have any further questions or need additional details, feel free to ask!
