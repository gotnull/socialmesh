#!/bin/bash

# Socialmesh Backend Services Startup Script
# Starts marketplace-api and mesh-observer containers

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${CYAN}╔════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║     Socialmesh Backend Services        ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════╝${NC}"
echo ""

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo -e "${RED}Error: Docker is not running${NC}"
    echo "Please start Docker and try again"
    exit 1
fi

# Parse arguments
ACTION="${1:-up}"
DETACH="${2:--d}"

case "$ACTION" in
    up|start)
        echo -e "${YELLOW}Starting services...${NC}"
        docker-compose up --build $DETACH
        
        if [ "$DETACH" = "-d" ]; then
            echo ""
            echo -e "${GREEN}Services started successfully!${NC}"
            echo ""
            echo -e "  ${CYAN}Marketplace API:${NC}  http://localhost:3000"
            echo -e "  ${CYAN}Mesh Observer:${NC}    http://localhost:3001"
            echo ""
            echo -e "  ${CYAN}View logs:${NC}        ./start-services.sh logs"
            echo -e "  ${CYAN}Stop services:${NC}    ./start-services.sh stop"
            echo -e "  ${CYAN}Service status:${NC}   ./start-services.sh status"
        fi
        ;;
        
    down|stop)
        echo -e "${YELLOW}Stopping services...${NC}"
        docker-compose down
        echo -e "${GREEN}Services stopped${NC}"
        ;;
        
    restart)
        echo -e "${YELLOW}Restarting services...${NC}"
        docker-compose down
        docker-compose up --build -d
        echo -e "${GREEN}Services restarted${NC}"
        ;;
        
    logs)
        SERVICE="${2:-}"
        if [ -n "$SERVICE" ]; then
            docker-compose logs -f "$SERVICE"
        else
            docker-compose logs -f
        fi
        ;;
        
    status)
        echo -e "${YELLOW}Service Status:${NC}"
        echo ""
        docker-compose ps
        echo ""
        
        # Health checks
        echo -e "${YELLOW}Health Checks:${NC}"
        echo -n "  Marketplace API: "
        if curl -s http://localhost:3000/health > /dev/null 2>&1; then
            echo -e "${GREEN}✓ healthy${NC}"
        else
            echo -e "${RED}✗ unhealthy${NC}"
        fi
        
        echo -n "  Mesh Observer:   "
        if curl -s http://localhost:3001/health > /dev/null 2>&1; then
            echo -e "${GREEN}✓ healthy${NC}"
        else
            echo -e "${RED}✗ unhealthy${NC}"
        fi
        ;;
        
    build)
        echo -e "${YELLOW}Building services...${NC}"
        docker-compose build
        echo -e "${GREEN}Build complete${NC}"
        ;;
        
    clean)
        echo -e "${YELLOW}Cleaning up...${NC}"
        docker-compose down -v --rmi local
        echo -e "${GREEN}Cleanup complete${NC}"
        ;;
        
    *)
        echo "Usage: $0 {up|start|down|stop|restart|logs|status|build|clean}"
        echo ""
        echo "Commands:"
        echo "  up, start    Start all services (default)"
        echo "  down, stop   Stop all services"
        echo "  restart      Restart all services"
        echo "  logs [svc]   View logs (optionally for specific service)"
        echo "  status       Show service status and health"
        echo "  build        Build containers without starting"
        echo "  clean        Stop and remove containers, volumes, images"
        exit 1
        ;;
esac
