---

# Option 1 Solution Not Using Multi-Cluster

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
### Preparation
Update Helm Repositories: Ensure your Helm repositories are up to date. Run the following command to update the repositories:
```sh
helm repo update
```
Add the Bitnami Repository: If the Bitnami repository is not added or needs to be re-added, use the following command:
```sh
helm repo add bitnami https://charts.bitnami.com/bitnami
```
Verify the Repository: Check if the repository is correctly added and accessible:
```sh
helm search repo bitnami/redis-cluster
```

### 1. Use `values.yaml` for Redis Cluster Helm Chart

Use a `values.yaml` file with the necessary configuration for Redis Cluster.
option1/helm/values.yaml

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

Use file `redis-headless-service.yaml` at folder root


Deploy this service in both clusters:

```sh
# Deploy headless service to primary cluster
kubectl apply -f redis-headless-service.yaml --context primary-cluster

# Deploy headless service to secondary cluster
kubectl apply -f redis-headless-service.yaml --context secondary-cluster
```

#### Why and Usage of the Redis Headless Service

The headless service is used to enable service discovery within the Kubernetes clusters. By setting `clusterIP: None`, the service does not get a cluster IP address, and instead, DNS queries for the service return the IP addresses of the associated pods. This allows Redis nodes to discover each other and form a cluster.

## Load Balancer Configuration (CLI Commands)

To set up a load balancer using the CLI, follow these steps:

1. **Create a Backend Service:**

```sh
gcloud compute backend-services create redis-backend-service --global --protocol TCP
```

2. **Add Instance Groups to the Backend Service:**

```sh
# Add primary cluster instance group
gcloud compute backend-services add-backend redis-backend-service --global --instance-group=primary-cluster-group --instance-group-zone=europe-west1-b

# Add secondary cluster instance group
gcloud compute backend-services add-backend redis-backend-service --global --instance-group=secondary-cluster-group --instance-group-zone=europe-west1-b
```

3. **Create a Health Check:**

```sh
gcloud compute health-checks create tcp redis-health-check --port 6379
```

4. **Attach the Health Check to the Backend Service:**

```sh
gcloud compute backend-services update redis-backend-service --global --health-checks=redis-health-check
```

5. **Create a URL Map:**

```sh
gcloud compute url-maps create redis-url-map --default-service redis-backend-service
```

6. **Create a Target TCP Proxy:**

```sh
gcloud compute target-tcp-proxies create redis-tcp-proxy --backend-service=redis-backend-service
```

7. **Create a Global Forwarding Rule:**

```sh
gcloud compute forwarding-rules create redis-forwarding-rule --global --target-tcp-proxy=redis-tcp-proxy --ports=6379
```

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
4. **`redis-headless-service.yaml`** (Headless service for Redis Cluster)


# OPTION 2 USING MULTI-CLUSTER 

**k8s API Gateway** https://gateway-api.sigs.k8s.io/
Some options:
- **Istio** OpenSource https://istio.io/ service mesh that can manage traffic between services across multiple clusters
- **Consul** https://www.consul.io/ by HashiCorp is another service mesh that supports multi-cluster setups. It provides service discovery, configuration, and segmentation functionality.
- **Linkerd** https://linkerd.io/ Linkerd is a lightweight service mesh that can also manage traffic across multiple clusters. It simplifies the process of setting up a multi-cluster environment.

Some other but related
- **Google Anthos Fleet**, really close solutionto option 1 but administrating the clsuters under one set of commands
- **Skupper** https://github.com/bryonbaker/rhai-redis-demo/blob/main/doc/demo-script.md Building a Global Redis Cache with OpenShift and Red Hat Application Interconnect (aka Skupper)
