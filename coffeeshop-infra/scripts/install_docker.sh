#!/bin/bash

set -euo pipefail

echo "Installing packages..."
sudo yum update -y

sudo yum install -y docker

systemctl enable docker
systemctl start docker
usermod -a -G docker ec2-user 

echo "Installing docker-compose..."
DOCKER_COMPOSE_VERSION="1.29.2" && sudo curl -L "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" \
  -o /usr/local/bin/docker-compose

sudo chmod +x /usr/local/bin/docker-compose
sudo ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose

docker-compose -f docker-compose-dev.yml up -d