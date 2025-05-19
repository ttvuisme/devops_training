#!/bin/bash

set -e

# Configuration
NAMESPACE=coffeeshop-prod
TIMEOUT=120s

echo "Starting cleanup of $NAMESPACE namespace..."

# 1. Delete application services (reverse order of deployment)
echo "Deleting application services..."
kubectl delete -n $NAMESPACE -f 5-services/web/ --ignore-not-found=true
kubectl delete -n $NAMESPACE -f 5-services/proxy/ --ignore-not-found=true
kubectl delete -n $NAMESPACE -f 5-services/kitchen/ --ignore-not-found=true
kubectl delete -n $NAMESPACE -f 5-services/barista/ --ignore-not-found=true
kubectl delete -n $NAMESPACE -f 5-services/counter/ --ignore-not-found=true
kubectl delete -n $NAMESPACE -f 5-services/product/ --ignore-not-found=true

# 3. Delete databases (with wait for complete deletion)
echo "Deleting database resources..."
kubectl delete -n $NAMESPACE -f 4-databases/rabbitmq/ --ignore-not-found=true
kubectl delete -n $NAMESPACE -f 4-databases/postgres/ --ignore-not-found=true

# Wait for databases to fully terminate
echo "Waiting for databases to terminate..."
kubectl wait --for=delete statefulset/rabbitmq -n $NAMESPACE --timeout=$TIMEOUT || true
kubectl wait --for=delete statefulset/postgresql -n $NAMESPACE --timeout=$TIMEOUT || true

# 4. Delete storage class
echo "Deleting storage class..."
kubectl delete -n $NAMESPACE -f 4-databases/gp3-storageclass.yaml --ignore-not-found=true

# 5. Delete configs and secrets
echo "Deleting config maps..."
kubectl delete -n $NAMESPACE -f 3-configs/ --ignore-not-found=true

echo "Deleting secrets..."
kubectl delete -n $NAMESPACE -f 2-secrets/ --ignore-not-found=true

# 6. Delete namespace (will delete any remaining resources)
echo "Deleting namespace..."
kubectl delete namespace $NAMESPACE --ignore-not-found=true

# 7. Verify cleanup
echo "Verifying all resources are deleted..."
RESOURCES=$(kubectl get all,ingress,pvc -n $NAMESPACE 2>/dev/null || true)
if [ -z "$RESOURCES" ]; then
  echo "Cleanup completed successfully in $NAMESPACE namespace."
else
  echo "Warning: Some resources still exist in $NAMESPACE namespace:"
  echo "$RESOURCES"
  exit 1
fi