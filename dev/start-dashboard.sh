#!/bin/bash

# =============================================================================
# Dify Dashboard Development Startup Script
# =============================================================================

set -e

echo "🚀 Starting Dify Dashboard Development Environment..."

# Check if .env exists
if [ ! -f .env ]; then
    echo "📝 Creating .env file from .env.example..."
    cp .env.example .env
    echo "✅ Please edit .env file with your configuration"
fi

# Start database and redis
echo "🗄️ Starting database services..."
cd docker
docker-compose up -d db redis

# Wait for database to be ready
echo "⏳ Waiting for database to be ready..."
sleep 10

# Run migrations
echo "🔄 Running database migrations..."
cd ../api
uv run flask db upgrade

# Start API server
echo "🌐 Starting API server..."
uv run flask run --host 0.0.0.0 --port 5001 --debug &
API_PID=$!

# Wait for API to start
sleep 5

# Start Dashboard
echo "📊 Starting Dashboard..."
cd ../dashboard
export API_URL="http://localhost:5001"
streamlit run main.py --server.port=8501 --server.address=0.0.0.0 &
DASHBOARD_PID=$!

echo "✅ Dashboard development environment started!"
echo ""
echo "🔗 Access URLs:"
echo "   Dashboard: http://localhost:8501"
echo "   API:       http://localhost:5001"
echo "   Login:     admin / @DifyAdmin2024"
echo ""
echo "🛑 To stop: kill $API_PID $DASHBOARD_PID"

# Keep script running
wait
