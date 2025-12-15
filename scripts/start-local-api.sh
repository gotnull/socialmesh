#!/bin/bash
# start-local-api.sh - Starts local development APIs with auto-detected IP

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
ENV_FILE="$PROJECT_ROOT/.env"

# Get current local IP (works on macOS and Linux)
get_local_ip() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        ifconfig | grep "inet " | grep -v 127.0.0.1 | head -1 | awk '{print $2}'
    else
        # Linux
        hostname -I | awk '{print $1}'
    fi
}

LOCAL_IP=$(get_local_ip)

if [ -z "$LOCAL_IP" ]; then
    echo "❌ Could not detect local IP address"
    exit 1
fi

echo "🌐 Detected local IP: $LOCAL_IP"

# Update .env file with current IP
if [ -f "$ENV_FILE" ]; then
    # Update LOCAL_API_HOST
    if grep -q "LOCAL_API_HOST=" "$ENV_FILE"; then
        CURRENT_HOST=$(grep "LOCAL_API_HOST=" "$ENV_FILE" | cut -d'=' -f2)
        if [ "$CURRENT_HOST" != "$LOCAL_IP" ]; then
            echo "📝 Updating LOCAL_API_HOST: $CURRENT_HOST → $LOCAL_IP"
            sed -i '' "s/LOCAL_API_HOST=.*/LOCAL_API_HOST=$LOCAL_IP/" "$ENV_FILE"
        else
            echo "✅ LOCAL_API_HOST already correct: $LOCAL_IP"
        fi
    fi

    # Update MARKETPLACE_URL
    if grep -q "MARKETPLACE_URL=" "$ENV_FILE"; then
        OLD_URL=$(grep "MARKETPLACE_URL=" "$ENV_FILE" | cut -d'=' -f2)
        NEW_URL="http://$LOCAL_IP:3000/api/widgets"
        if [ "$OLD_URL" != "$NEW_URL" ]; then
            echo "📝 Updating MARKETPLACE_URL: $OLD_URL → $NEW_URL"
            sed -i '' "s|MARKETPLACE_URL=.*|MARKETPLACE_URL=$NEW_URL|" "$ENV_FILE"
        else
            echo "✅ MARKETPLACE_URL already correct: $NEW_URL"
        fi
    fi
else
    echo "⚠️  .env file not found at $ENV_FILE"
fi

# Stop any existing containers
echo ""
echo "🛑 Stopping existing containers..."
cd "$PROJECT_ROOT/marketplace-api"
docker-compose down 2>/dev/null || true
cd "$PROJECT_ROOT/mesh-observer"
docker-compose down 2>/dev/null || true

# Start marketplace API
echo ""
echo "🚀 Starting marketplace-api on port 3000..."
cd "$PROJECT_ROOT/marketplace-api"
docker-compose up -d

# Start mesh-observer
echo ""
echo "🚀 Starting mesh-observer on port 3001..."
cd "$PROJECT_ROOT/mesh-observer"
docker-compose up -d

# Wait for startup
sleep 3

# Show logs
echo ""
echo "📋 Marketplace API logs:"
cd "$PROJECT_ROOT/marketplace-api"
docker-compose logs --tail=5

echo ""
echo "📋 Mesh Observer logs:"
cd "$PROJECT_ROOT/mesh-observer"
docker-compose logs --tail=5

echo ""
echo "✅ Local APIs started!"
echo "   Marketplace API: http://$LOCAL_IP:3000/api/widgets"
echo "   Mesh Observer:   http://$LOCAL_IP:3001/api/nodes"
echo ""
echo "📱 Your iOS device can now connect to both services."
