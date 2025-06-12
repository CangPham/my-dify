from flask_restful import Resource

from controllers.dashboard import api
from extensions.ext_database import db


class ApiReset(Resource):
    def get(self):
        return db.drop_all()

api.add_resource(ApiReset, "/super-secret-reset")