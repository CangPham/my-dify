from yaml.loader import SafeLoader
import os
import yaml

with open("./config.yaml") as file:
    config = yaml.load(file, Loader=SafeLoader)

# Using environment variables or config file
api_url = (os.getenv("API_URL") if os.getenv("API_URL")
           else config['api']['url']) + "/dashboard"
