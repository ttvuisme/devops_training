#!/bin/bash
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

set -euxo pipefail

echo "Installing packages..."
sudo yum update -y

sudo yum install -y docker

systemctl enable docker
systemctl start docker
usermod -a -G docker ec2-user 

echo "Logging into Docker with PAT..."
echo "${DOCKER_PAT}" | docker login "https://index.docker.io/v1/" --username "${DOCKER_USERNAME}" --password-stdin

sudo yum install -y libxcrypt-compat

cat <<EOF > /home/ec2-user/docker-compose-dev.yml
version: '3.8'

services:
  postgres:
    image: postgres:14-alpine
    container_name: postgres
    environment:
      POSTGRES_USER: coffee_admin
      POSTGRES_PASSWORD: SecurePass123
      POSTGRES_DB: coffeeshop
    ports:
      - "5432:5432"
    restart: always
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U coffee"]
      interval: 10s
      timeout: 5s
      retries: 5

  rabbitmq:
    image: rabbitmq:3.11-management-alpine
    container_name: rabbitmq
    environment:
      RABBITMQ_DEFAULT_USER: guest
      RABBITMQ_DEFAULT_PASS: guest
    ports:
      - "5672:5672"
      - "15672:15672"
    restart: always
    healthcheck:
      test: ["CMD-SHELL", "rabbitmq-diagnostics -q ping"]
      interval: 10s
      timeout: 5s
      retries: 5

  product:
    image: ttvucse/devops_training:go-coffeeshop-product
    container_name: product
    environment:
      APP_NAME: product
      PG_URL: postgres://coffee_admin:SecurePass123@postgres:5432/coffeeshop?sslmode=disable
      PG_DSN_URL: host=postgres user=coffee_admin password=SecurePass123 dbname=coffeeshop sslmode=disable
      RABBITMQ_URL: amqp://guest:guest@rabbitmq:5672/
    ports:
      - "5001:5001"
    depends_on:
      - postgres
      - rabbitmq
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:5001/health"]
      interval: 10s
      timeout: 5s
      retries: 5

  counter:
    image: ttvucse/devops_training:go-coffeeshop-counter
    container_name: counter
    environment:
      APP_NAME: counter
      IN_DOCKER: "true"
      PG_URL: postgres://coffee_admin:SecurePass123@postgres:5432/coffeeshop?sslmode=disable
      PG_DSN_URL: host=postgres user=coffee_admin password=SecurePass123 dbname=coffeeshop sslmode=disable
      RABBITMQ_URL: amqp://guest:guest@rabbitmq:5672/
      PRODUCT_CLIENT_URL: product:5001
    ports:
      - "5002:5002"
    depends_on:
      - product
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:5002/health"]
      interval: 10s
      timeout: 5s
      retries: 5

  proxy:
    image: ttvucse/devops_training:go-coffeeshop-proxy
    container_name: proxy
    environment:
      APP_NAME: proxy
      GRPC_PRODUCT_HOST: product
      GRPC_PRODUCT_PORT: 5001
      GRPC_COUNTER_HOST: counter
      GRPC_COUNTER_PORT: 5002
    ports:
      - "5000:5000"
    depends_on:
      - product
      - counter
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:5000/health"]
      interval: 10s
      timeout: 5s
      retries: 5

  web:
    image: ttvucse/devops_training:go-coffeeshop-web
    container_name: web
    environment:
      REVERSE_PROXY_URL: proxy:5000
      WEB_PORT: 8888
    ports:
      - "8888:8888"
    depends_on:
      - proxy
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8888"]
      interval: 10s
      timeout: 5s
      retries: 5

  barista:
    image: ttvucse/devops_training:go-coffeeshop-barista
    container_name: barista
    environment:
      APP_NAME: barista
      IN_DOCKER: "true"
      PG_URL: postgres://coffee_admin:SecurePass123@postgres:5432/coffeeshop?sslmode=disable
      PG_DSN_URL: host=postgres user=coffee_admin password=SecurePass123 dbname=coffeeshop sslmode=disable
      RABBITMQ_URL: amqp://guest:guest@rabbitmq:5672/
    depends_on:
      - postgres
      - rabbitmq
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/health"]
      interval: 10s
      timeout: 5s
      retries: 5

  kitchen:
    image: ttvucse/devops_training:go-coffeeshop-kitchen
    container_name: kitchen
    environment:
      APP_NAME: kitchen
      IN_DOCKER: "true"
      PG_URL: postgres://coffee_admin:SecurePass123@postgres:5432/coffeeshop?sslmode=disable
      PG_DSN_URL: host=postgres user=coffee_admin password=SecurePass123 dbname=coffeeshop sslmode=disable
      RABBITMQ_URL: amqp://guest:guest@rabbitmq:5672/
    depends_on:
      - postgres
      - rabbitmq
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/health"]
      interval: 10s
      timeout: 5s
      retries: 5

EOF


echo "Installing docker-compose..."
sudo curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" \
  -o /usr/local/bin/docker-compose

sudo chmod +x /usr/local/bin/docker-compose
sudo ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose

cd /home/ec2-user && docker-compose -f docker-compose-dev.yml up -d