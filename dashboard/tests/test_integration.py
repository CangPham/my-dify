"""
Dashboard Integration Tests
"""
import requests
import pytest
import os

API_URL = os.getenv("API_URL", "http://localhost:5001")
API_TOKEN = "89fisiqoo009"

class TestDashboardAPI:
    """Test Dashboard API endpoints"""
    
    def test_api_health(self):
        """Test API health endpoint"""
        response = requests.get(
            f"{API_URL}/dashboard/",
            headers={"api-token": API_TOKEN}
        )
        assert response.status_code == 200
        
    def test_accounts_endpoint(self):
        """Test accounts endpoint"""
        response = requests.get(
            f"{API_URL}/dashboard/accounts",
            headers={"api-token": API_TOKEN}
        )
        assert response.status_code == 200
        data = response.json()
        assert isinstance(data, list)
        
    def test_plans_endpoint(self):
        """Test plans endpoint"""
        response = requests.get(
            f"{API_URL}/dashboard/plans",
            headers={"api-token": API_TOKEN}
        )
        assert response.status_code == 200
        
    def test_explore_endpoint(self):
        """Test explore endpoint"""
        response = requests.get(
            f"{API_URL}/dashboard/explore",
            headers={"api-token": API_TOKEN}
        )
        assert response.status_code == 200
        
    def test_invalid_token(self):
        """Test invalid API token"""
        response = requests.get(
            f"{API_URL}/dashboard/accounts",
            headers={"api-token": "invalid"}
        )
        assert response.status_code == 401
        
    def test_missing_token(self):
        """Test missing API token"""
        response = requests.get(f"{API_URL}/dashboard/accounts")
        assert response.status_code == 401

if __name__ == "__main__":
    pytest.main([__file__, "-v"])
