Great, let's create a detailed README file based on your requirements. Here's a draft for your repository:

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

## Testing and Validation

### 1. Inject Data and Verify Consistency

Inject data into Redis and verify that it is consistent across both clusters.

```sh
# Inject data into Redis in primary cluster
kubectl exec -it <redis-pod> --context primary-cluster -- redis-cli set key "value"

# Retrieve data from Redis in secondary cluster
kubectl exec -it <redis-pod> --context secondary-cluster -- redis-cli get key
```

### 2. Simulate Failures

Simulate node, cluster, and Redis pod failures to test the high availability setup.

```sh
# Simulate node failure in primary cluster
kubectl drain <node-name> --ignore-daemonsets --delete-local-data --context primary-cluster

# Simulate cluster failure
gcloud container clusters delete secondary-cluster --zone europe-west1

# Simulate Redis pod failure
kubectl delete pod <redis-pod> --context primary-cluster
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

This README file provides a comprehensive guide to setting up and demonstrating the Redis high availability setup across two Kubernetes clusters. If you have any further questions or need additional details, feel free to ask!
