#!/bin/bash

# ---------------------------------------------------------
# SeaweedFS Docker Compose Setup Script
# This script sets up SeaweedFS with Docker Compose, generates
# necessary certificates, and starts the containers.
# ---------------------------------------------------------

# Ensure docker compose is installed
if ! command -v docker-compose &> /dev/null; then
  echo "docker-compose could not be found. Please install it first."
  exit 1
fi

# Load .env
set -o allexport
# shellcheck disable=SC1091
source .env
set +o allexport

echo "Loading environment variables from .env file..."
# Sanitize and escape subject based on OS
if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "win32" ]]; then
  echo "Detected MSYS/MinGW environment. Adjusting CA Subject for compatibility..."
  # Escape forward slashes for MSYS (double backslashes to prevent path rewriting)
  # Remove leading slash, then escape remaining slashes
  trimmed="${CA_SUBJECT#/}"                          # remove first /
  escaped="${trimmed//\//\\}"                        # replace / with \
  SAFE_SUBJECT="//${escaped}"                        # prepend double slash
else
  echo "Detected Unix-like environment. Using CA Subject as is..."
  SAFE_SUBJECT="$CA_SUBJECT"
fi

echo "Using CA Subject: $SAFE_SUBJECT"

# Create certs directory if it doesn't exist
mkdir -p certs

if [[ ! -f certs/s3.key || ! -f certs/s3.crt ]]; then
  echo "Generating S3 certificate and key..."

  # Gen Key
  openssl genrsa -out certs/s3.key 2048

  # Gen CSR
  openssl req -new -key certs/s3.key -out certs/s3.csr \
      -subj "$SAFE_SUBJECT"

  # Gen CA
  openssl x509 -req -days 3650 -in certs/s3.csr -signkey certs/s3.key -out certs/s3.crt

  echo "S3 certificate and key generated successfully."
else
  echo "S3 certificate and key already exist. Skipping generation."
fi

# Check if docker-compose.yml exists
if [[ ! -f docker-compose.yml ]]; then
  echo "docker-compose.yml not found. Please ensure you are in the correct directory."
  exit 1
fi 

# Start the Docker containers
echo "Starting Docker containers with docker-compose..."
docker-compose up -d