#!/bin/bash

set -e 

# aws eks update-kubeconfig --name coffeeshop-prod --region ap-southeast-1

NAMESPACE=coffeeshop-prod

echo "Create namespace..."
kubectl apply -f 1-namespaces/prod.yaml

echo "Create secrets..."
kubectl apply -n $NAMESPACE -f 2-secrets/

echo "Create config maps..."
kubectl apply -n $NAMESPACE -f 3-configs/

eco "Deploy GP3 storage..."
kubectl apply -n $NAMESPACE -f 4-databases/gp3-storageclass.yaml

echo "Deploy PostgreSQL..."
kubectl apply -n $NAMESPACE -f 4-databases/postgres/

echo "Deploy RabbitMQ..."
kubectl apply -n $NAMESPACE -f 4-databases/rabbitmq/

echo "Waiting for PostgreSQL and RabbitMQ become ready..."
kubectl rollout status statefulset/postgresql -n $NAMESPACE --timeout=120s
kubectl rollout status statefulset/rabbitmq -n $NAMESPACE --timeout=120s


# Product
kubectl apply -n $NAMESPACE -f 5-services/product/

# Counter
kubectl apply -n $NAMESPACE -f 5-services/counter/

# Barista, Kitchen, Proxy
kubectl apply -n $NAMESPACE -f 5-services/barista/
kubectl apply -n $NAMESPACE -f 5-services/kitchen/
kubectl apply -n $NAMESPACE -f 5-services/proxy/

kubectl apply -n $NAMESPACE -f 5-services/web/

# Ingress for web
# kubectl apply -n $NAMESPACE -f 5-services/ingress.yaml
# kubectl apply -n $NAMESPACE -f web-ingress.yaml

echo "Successfully deployed all services in $NAMESPACE namespace."