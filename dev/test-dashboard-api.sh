#!/bin/bash

# =============================================================================
# Dashboard API Testing Script
# =============================================================================

API_URL="http://localhost:5001"
API_TOKEN="89fisiqoo009"

echo "🧪 Testing Dashboard API Endpoints..."

# Test API health
echo "1. Testing API health..."
curl -s -H "api-token: $API_TOKEN" "$API_URL/dashboard/" | jq .

# Test accounts endpoint
echo "2. Testing accounts endpoint..."
curl -s -H "api-token: $API_TOKEN" "$API_URL/dashboard/accounts" | jq .

# Test plans endpoint
echo "3. Testing plans endpoint..."
curl -s -H "api-token: $API_TOKEN" "$API_URL/dashboard/plans" | jq .

# Test explore endpoint
echo "4. Testing explore endpoint..."
curl -s -H "api-token: $API_TOKEN" "$API_URL/dashboard/explore" | jq .

# Test invalid token
echo "5. Testing invalid token..."
curl -s -H "api-token: invalid" "$API_URL/dashboard/accounts"

echo "✅ API testing completed!"
