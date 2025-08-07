#!/bin/bash

# Get the primary IP address (usually the public one)
PRIMARY_IP=$(ip route get 8.8.8.8 | awk '{print $7; exit}')

echo "Initializing Docker Swarm with IP: $PRIMARY_IP"
docker swarm init --advertise-addr $PRIMARY_IP

if [ $? -eq 0 ]; then
    echo "Docker Swarm initialized successfully!"
    echo "To add worker nodes, run the following command on each worker:"
    docker swarm join-token worker
else
    echo "Failed to initialize Docker Swarm"
    exit 1
fi
