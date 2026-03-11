#!/usr/bin/env bash
set -euo pipefail

# YoorQuezt Demo Setup
# One-time setup: pull images, verify Docker, create .env

CYAN='\033[0;36m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'
BOLD='\033[1m'

echo -e "${BOLD}${CYAN}YoorQuezt Demo Setup${NC}\n"

# Check prerequisites
echo "Checking prerequisites..."

if ! command -v docker &> /dev/null; then
  echo -e "${RED}Docker not found. Install Docker Desktop: https://docker.com${NC}"
  exit 1
fi
echo -e "  ${GREEN}Docker installed${NC}"

if ! docker info &> /dev/null 2>&1; then
  echo -e "${RED}Docker daemon not running. Start Docker Desktop.${NC}"
  exit 1
fi
echo -e "  ${GREEN}Docker daemon running${NC}"

if ! command -v docker compose &> /dev/null && ! command -v docker-compose &> /dev/null; then
  echo -e "${RED}Docker Compose not found.${NC}"
  exit 1
fi
echo -e "  ${GREEN}Docker Compose available${NC}"

# Check for minikube (optional)
if command -v minikube &> /dev/null; then
  echo -e "  ${GREEN}Minikube available (optional Kubernetes demo)${NC}"
else
  echo -e "  Minikube not found (optional — install for Kubernetes demo)"
fi

# Create .env if not exists
if [ ! -f .env ]; then
  cat > .env << 'EOF'
# YoorQuezt Demo Environment
MESH_SHARED_KEY=demo-shared-key-32bytes!
MEV_API_TOKEN=demo-token
EOF
  echo -e "\n  ${GREEN}Created .env file${NC}"
fi

# Pull images
echo -e "\nPulling Docker images..."
docker compose pull

echo -e "\n${BOLD}${GREEN}Setup complete!${NC}"
echo ""
echo "Run the demo:"
echo "  make up          # Start all services"
echo "  make demo        # 60-second demo"
echo "  make demo-full   # 5-minute demo"
echo ""
echo "Kubernetes demo:"
echo "  make minikube-start   # Start cluster"
echo "  make minikube-deploy  # Deploy services"
echo "  make minikube-demo    # Run demo"
