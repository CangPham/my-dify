
from flask import jsonify, request
from flask_restful import Resource

from controllers.dashboard import api, api_key_required
from models import db
from models.model import App, RecommendedApp


def app_to_dict(recommended_app):
    return {
        "id": recommended_app.id,
        "app_id": recommended_app.app_id,
        "description": recommended_app.description,
        "copyright": recommended_app.copyright,
        "privacy_policy": recommended_app.privacy_policy,
        "category": recommended_app.category,
        "position": recommended_app.position,
        "is_listed": recommended_app.is_listed,
        "install_count": recommended_app.install_count,
        "created_at": recommended_app.created_at.isoformat() if recommended_app.created_at else None,
        "updated_at": recommended_app.updated_at.isoformat() if recommended_app.updated_at else None,
    }

class ApiExplore(Resource):
    method_decorators = [api_key_required]

    def get(self):
        # Get the list of recommended apps joined with App to get the name
        recommended_apps_join = db.session.query(RecommendedApp).all()

        # Convert the list of recommended apps to a list of dictionaries
        recommended_apps_list = [app_to_dict(rec_app) for rec_app in recommended_apps_join]
        # Return the list of recommended apps as JSON
        return jsonify(recommended_apps_list)
        
    def post(self):
        # Get recommended apps from the request body
        new_recommended_app = request.json
        # Check if app_id already exists
        existing_app = db.session.query(RecommendedApp).filter_by(app_id=new_recommended_app["app_id"]).first()
        if existing_app:
            return {"status": "error", "message": "App ID already exists."}, 400
        # Check if app_id is existing in the App table
        existing_app_in_app = db.session.query(App).filter_by(id=new_recommended_app["app_id"]).first()
        if not existing_app_in_app:
            return {"status": "error", "message": "App ID not found in App table."}, 404
        # Create a new RecommendedApp object
        new_app = RecommendedApp(
            app_id=new_recommended_app["app_id"],
            # Use get method with default values to avoid KeyError
            description=new_recommended_app.get("description", "."),
            copyright=new_recommended_app.get("copyright", "."),
            privacy_policy=new_recommended_app.get("privacy_policy", "."),
            category=new_recommended_app.get("category", "."),
            position=new_recommended_app.get("position", 0), # Default position to 0
            is_listed=new_recommended_app.get("is_listed", True), # Default is_listed to True
            install_count=new_recommended_app.get("install_count", 0), # Default install_count to 0
        )
        # Add the new app to the session
        db.session.add(new_app)
        # Commit the session to save the new app to the database
        db.session.commit()
        return {"status": "success", "message": "App added successfully."}, 201
    
    def put(self, re_id:str):
        # Get the updated app data from the request body
        updated_app_data = request.json
        # Find the existing app in the database
        existing_app = db.session.query(RecommendedApp).filter_by(id=re_id).first()
        if not existing_app:
            return {"status": "error", "message": "App ID not found."}, 404
        # Check if app_id is existing in the App table
        existing_app_in_app = db.session.query(App).filter_by(id=updated_app_data["app_id"]).first()
        if not existing_app_in_app:
            return {"status": "error", "message": "App ID not found in App table."}, 404
        # Check if app_id already exists in the RecommendedApp table
        if updated_app_data["app_id"] != existing_app.app_id:
            app_with_same_id = db.session.query(RecommendedApp).filter_by(app_id=updated_app_data["app_id"]).first()
            if app_with_same_id:
                return {"status": "error", "message": "App ID already exists."}, 400
        # Update the app's attributes with the new data using get with default values
        existing_app.app_id = updated_app_data.get("app_id", existing_app.app_id)
        existing_app.description = updated_app_data.get("description", existing_app.description)
        existing_app.copyright = updated_app_data.get("copyright", existing_app.copyright)
        existing_app.privacy_policy = updated_app_data.get("privacy_policy", existing_app.privacy_policy)
        existing_app.category = updated_app_data.get("category", existing_app.category)
        existing_app.position = updated_app_data.get("position", existing_app.position)
        existing_app.is_listed = updated_app_data.get("is_listed", existing_app.is_listed)
        existing_app.install_count = updated_app_data.get("install_count", existing_app.install_count)
        # Commit the session to save the changes to the database
        db.session.commit()
        return {"status": "success", "message": "App updated successfully."}, 200
    
    def delete(self, re_id:str):
        # Find the app in the database
        app_to_delete = db.session.query(RecommendedApp).filter_by(id=re_id).first()
        if not app_to_delete:
            return {"status": "error", "message": "App ID not found."}, 404
        # Delete the app from the session
        db.session.delete(app_to_delete)
        # Commit the session to save the changes to the database
        db.session.commit()
        return {"status": "success", "message": "App deleted successfully."}, 200

api.add_resource(ApiExplore, "/explore", "/explore/<string:re_id>")