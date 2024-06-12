#!/bin/bash

# Get a list of all k3s nodes
nodes=$(kubectl get nodes -o name)

# Loop through each node
for node in $nodes; do
  echo "Cleaning up images on $node..."
  # Use k3s crictl to prune unused images
  kubectl ssh $node -- sudo k3s crictl rmi --prune
done

echo "Cleanup complete."
