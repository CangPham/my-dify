from flask_restful import Resource

from configs import dify_config
from controllers.dashboard import api


class IndexApi(Resource):
    def get(self):
        return {
            "welcome": "Dify Dashboard by Hotamago",
            "api_version": "v1",
            "server_version": dify_config.CURRENT_VERSION,
        }


api.add_resource(IndexApi, "/")
