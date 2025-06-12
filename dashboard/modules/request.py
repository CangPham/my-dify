import requests
from config import config, api_url
api_token = config['api']['token']

class RequestAuth:
    def __init__(self, api_url, api_token):
        self.api_token = api_token
        self.api_url = api_url

    def get(self, url, **kwargs):
        headers = kwargs.get('headers', {})
        headers['api-token'] = self.api_token
        kwargs['headers'] = headers
        return requests.get(f"{self.api_url}/{url}", **kwargs)
    
    def post(self, url, **kwargs):
        headers = kwargs.get('headers', {})
        headers['api-token'] = self.api_token
        headers['Content-Type'] = 'application/json'
        kwargs['headers'] = headers
        return requests.post(f"{self.api_url}/{url}", **kwargs)
    
    def put(self, url, **kwargs):
        headers = kwargs.get('headers', {})
        headers['api-token'] = self.api_token
        headers['Content-Type'] = 'application/json'
        kwargs['headers'] = headers
        return requests.put(f"{self.api_url}/{url}", **kwargs)
    
    def delete(self, url, **kwargs):
        headers = kwargs.get('headers', {})
        headers['api-token'] = self.api_token
        kwargs['headers'] = headers
        return requests.delete(f"{self.api_url}/{url}", **kwargs)
    
requestAuth = RequestAuth(api_url, api_token)