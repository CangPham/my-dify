from functools import wraps

from flask import Blueprint, request

from libs.external_api import ExternalApi

bp = Blueprint("dashboard", __name__, url_prefix="/dashboard")
api = ExternalApi(bp)
API_KEY = "89fisiqoo009"

# Decorator to check for API Key
def api_key_required(f):
    @wraps(f)
    def decorated_function(*args, **kwargs):
        api_key = request.headers.get('api-token')
        if not api_key or api_key != API_KEY:
            return {'message': 'Unauthorized: Invalid or missing API Key'}, 401
        return f(*args, **kwargs)
    return decorated_function

from . import accounts, explore, index, plan
# from . import reset