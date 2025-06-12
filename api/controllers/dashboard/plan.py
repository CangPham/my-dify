import random
import re
import urllib.parse
from datetime import UTC, datetime, timedelta

from flask import jsonify, request
from flask_restful import Resource

from controllers.console import api as api_console
from controllers.dashboard import api, api_key_required
from extensions.ext_database import db
from models.account import Account
from models.alies_payments_custom import AliesPaymentsCustom
from models.payments_history_custom import PaymentsHistoryCustom
from models.system_custom_info import SystemCustomInfo

from .models import *

# Helper function

# Gen 8 digit random number
def generate_random_number():
    return str(random.randint(10000000, 99999999))

def decode_description_pay(description):
    # Lowercase the description
    description = description.lower()
    # Extract the plan ID from the description using regex
    match = re.search(r'\bplan(\d{8})\b', description or '')
    return match.group(1) if match else None

def generate_image_url_pay(bank_id, account_id, amount, description, account_name):
    # Generate the image URL using the provided parameters
    # Encode the parameters to ensure they are URL-safe
    parameters = {
        "amount": amount,
        "addInfo": description,
        "accountName": account_name
    }
    encoded_parameters = urllib.parse.urlencode(parameters)
    return f"https://img.vietqr.io/image/{bank_id}-{account_id}-print.png?{encoded_parameters}"

# API endpoint to get and update payment settings
class ApiPaymentSettings(Resource):
    method_decorators = [api_key_required]

    def get(self):
        # Get all system custom info
        system_custom_info = db.session.query(SystemCustomInfo).filter(
            SystemCustomInfo.name.in_(["payment_settings"])
        ).first()

        # Check if system custom info exists
        if not system_custom_info:
            # Create a new system custom info if it doesn't exist
            system_custom_info = SystemCustomInfo(name="payment_settings", value=PaymentSettingsModel().model_dump(mode='json'))
            # Add default payment settings
            db.session.add(system_custom_info)
            db.session.commit()

        # Pydantic v2 uses model_dump() instead of dict()
        # Ensure the model loaded from DB is validated against the current model definition
        settings_data = system_custom_info.value
        # Add default values for potentially missing fields if loaded from an older schema
        validated_settings = PaymentSettingsModel.model_validate(settings_data)
        return jsonify(validated_settings.model_dump(mode='json'))

    def put(self):
        # Get the request data
        data = request.get_json()

        # Get the existing system custom info
        system_custom_info = db.session.query(SystemCustomInfo).filter(
            SystemCustomInfo.name == "payment_settings"
        ).first()

        # Create a new system custom info if it doesn't exist
        if not system_custom_info:
            system_custom_info = SystemCustomInfo(name="payment_settings", value=PaymentSettingsModel().model_dump(mode='json'))

        # Pydantic v2 uses model_validate
        try:
            payment_settings = PaymentSettingsModel.model_validate(data)
        except Exception as e:
             return jsonify({"status": "error", "message": f"Invalid data format: {e}"}), 400

        # Update the existing payment settings with the new data
        system_custom_info.value = payment_settings.model_dump(mode='json')

        # Commit the changes to the database
        db.session.add(system_custom_info)
        db.session.commit()

        # Return a success message
        return jsonify({"status": "success", "message": "Payment settings updated successfully."})
    
class ApiPaymentSettingsPublic(Resource):
    def get(self):
        # Get all system custom info
        system_custom_info = db.session.query(SystemCustomInfo).filter(
            SystemCustomInfo.name.in_(["payment_settings"])
        ).first()

        # Check if system custom info exists
        if not system_custom_info:
            # Create a new system custom info if it doesn't exist
            system_custom_info = SystemCustomInfo(name="payment_settings", value=PaymentSettingsModel().model_dump(mode='json'))
            # Add default payment settings
            db.session.add(system_custom_info)
            db.session.commit()

        # Pydantic v2 uses model_dump() instead of dict()
        # Ensure the model loaded from DB is validated against the current model definition
        settings_data = system_custom_info.value
        # Add default values for potentially missing fields if loaded from an older schema
        validated_settings = PaymentSettingsModelPublic.model_validate(settings_data)
        return jsonify(validated_settings.model_dump(mode='json'))

# API endpoint to get and update plans
class ApiPlan(Resource):
    method_decorators = [api_key_required]

    def get(self):
        # Get all system custom info
        system_custom_info = db.session.query(SystemCustomInfo).filter(
            SystemCustomInfo.name.in_(["plan"])
        ).first()

        object_plans = []

        # Check if system custom info exists
        if not system_custom_info:
           # Create a new system custom info if it doesn't exist
            system_custom_info = SystemCustomInfo(name="plan", value=[])
            # Add default plans
            db.session.add(system_custom_info)
            db.session.commit()
        else:
            # Convert the value from list[json] to list[PlanModel]
            # Skip plans with string expiration date
            raw_plans = system_custom_info.value
            list_of_plans = []
            for plan in raw_plans:
                exp = plan.get("plan_expiration")
                if isinstance(exp, str):
                    continue
                list_of_plans.append(plan)
            object_plans = [PlanModel.model_validate(plan) for plan in list_of_plans]
        
        # Pydantic v2 uses model_dump() instead of dict()
        return jsonify([plan.model_dump(mode='json') for plan in object_plans])
    
    def put(self):
        # Get the request data
        data = request.get_json()

        # Pydantic v2 uses model_validate
        plans = [PlanModel.model_validate(plan) for plan in data]
        # Get the existing system custom info
        system_custom_info = db.session.query(SystemCustomInfo).filter(
            SystemCustomInfo.name == "plan"
        ).first()
        
        # Create a new system custom info if it doesn't exist
        if not system_custom_info:
            system_custom_info = SystemCustomInfo(name="plan", value=[])
        
        # Update the existing plans with the new data
        # Pydantic v2 uses model_dump() instead of dict()
        system_custom_info.value = [plan.model_dump(mode='json') for plan in plans]

        # Commit the changes to the database
        db.session.add(system_custom_info)
        db.session.commit()

        # Return a success message
        return jsonify({"status": "success", "message": "Plan updated successfully."})
    
class ApiPlanPublic(Resource):
    def get(self):
        # Get all system custom info
        system_custom_info = db.session.query(SystemCustomInfo).filter(
            SystemCustomInfo.name.in_(["plan"])
        ).first()

        object_plans = []

        # Check if system custom info exists
        if not system_custom_info:
           # Create a new system custom info if it doesn't exist
            system_custom_info = SystemCustomInfo(name="plan", value=[])
            # Add default plans
            db.session.add(system_custom_info)
            db.session.commit()
        else:
            # Convert the value from list[json] to list[PlanModel]
            # Skip plans with string expiration date
            raw_plans = system_custom_info.value
            list_of_plans = []
            for plan in raw_plans:
                exp = plan.get("plan_expiration")
                if isinstance(exp, str):
                    continue
                list_of_plans.append(plan)
            object_plans = [PlanModel.model_validate(plan) for plan in list_of_plans]
        
        # Pydantic v2 uses model_dump() instead of dict()
        return jsonify([plan.model_dump(mode='json') for plan in object_plans])

# API endpoint to handle payment requests
class ApiPayRequest(Resource):
    def post(self):
        # Get the request data
        data = request.get_json()

        # Pydantic v2 uses model_validate
        pay_request = PayRequestModel.model_validate(data)

        # Get the existing system custom info
        system_custom_info = db.session.query(SystemCustomInfo).filter(
            SystemCustomInfo.name == "plan"
        ).first()
        # Check if system custom info exists
        if not system_custom_info:
            return jsonify({"status": "error", "message": "Plan not found."}), 404
        # Get the plan data
        plan_data = system_custom_info.value
        plan = next((plan for plan in plan_data if plan["id"] == pay_request.id_plan), None)
        if not plan:
            return jsonify({"status": "error", "message": "Plan not found."}), 404
        # Get the account data
        account = db.session.query(Account).filter_by(id=pay_request.id_account).first()
        if not account:
            return jsonify({"status": "error", "message": "Account not found."}), 404
        # Check if exits alies payment then delete old one
        alies_payment = db.session.query(AliesPaymentsCustom).filter_by(id_account=pay_request.id_account).first()
        if alies_payment:
            db.session.delete(alies_payment)
            db.session.commit()
        # Add to the alies payments table
        alies_payment_info = AliesPaymentsInfo(
            id_account=pay_request.id_account,
            id_plan=pay_request.id_plan
        )
        alies_payment = AliesPaymentsCustom(
            alies=generate_random_number(),
            id_account=pay_request.id_account,
            # Dict
            value=alies_payment_info.model_dump(mode='json'),
        )
        db.session.add(alies_payment)
        db.session.commit()

        # Get the payment settings
        payment_settings = db.session.query(SystemCustomInfo).filter(
            SystemCustomInfo.name == "payment_settings"
        ).first()
        if not payment_settings:
            return jsonify({"status": "error", "message": "Payment settings not found."}), 404
        # Get the payment settings data
        payment_settings_data = payment_settings.value
        # Pydantic v2 uses model_validate
        try:
            payment_settings = PaymentSettingsModel.model_validate(payment_settings_data)
        except Exception as e:
            return jsonify({"status": "error", "message": f"Invalid payment settings format: {e}"}), 400

        # Return the payment URL
        return jsonify({
            "status": "success",
            "message": "Payment request created successfully.",
            "url": generate_image_url_pay(
                bank_id=payment_settings.bank_id,
                account_id=payment_settings.account_id,
                amount=int(plan["price"]),
                description=f"plan{alies_payment.alies}",
                account_name=payment_settings.account_name
            ),
            "alies": alies_payment.alies,
        })
    
    # Check if alies payment exists for check pay success
    def get(self, id_account):
        # Get the alies payment
        alies_payment = db.session.query(AliesPaymentsCustom).filter_by(id_account=id_account).first()
        if not alies_payment:
            # Return dict and status code directly
            return {"status": "error", "message": "Alies payment not found."}, 404

        # Return dict directly
        return {"status": "success", "message": "Alies payment found.", "alies": alies_payment.alies}

# API endpoint to handle payment history
class ApiPaymentHistory(Resource):
    method_decorators = [api_key_required]

    def get(self):
        # Get PaymentsHistoryCustom
        payments_history = db.session.query(PaymentsHistoryCustom).all()
        # Convert the value from list[json] to list[PaymentHistoryModel]
        object_payments = [PaymentHistoryModel.model_validate(payment.value) for payment in payments_history]
        # Pydantic v2 uses model_dump() instead of dict()
        return jsonify([payment.model_dump(mode='json') for payment in object_payments])

# Webhook endpoint to handle payment notifications
class ApiPlanWebhook(Resource):
    def post(self):
        # check Authorization header
        auth = request.headers.get('Authorization', '')
        if not auth.startswith('Bearer '):
            return 'Access Token không được cung cấp hoặc không hợp lệ.', 401
        token = auth[7:]
        # fetch stored token
        sys_info = db.session.query(SystemCustomInfo).filter_by(name='payment_settings').first()
        if not sys_info:
            return 'Access Token không được cung cấp hoặc không hợp lệ.', 401
        settings = PaymentSettingsModel.model_validate(sys_info.value)
        if token != settings.access_token:
            return 'Chữ ký không hợp lệ.', 401

        payload = request.get_json()
        if not payload or not payload.get('status') or not payload.get('data'):
            return jsonify({'status': False, 'msg': 'Invalid payload'}), 400

        for item in payload['data']:
            try:
                payment = PaymentHistoryModel.model_validate(item)
            except Exception as e:
                print(f"Error validating payment data: {e}")
                continue
            # record history
            hist = PaymentsHistoryCustom(value=payment.model_dump(mode='json'))
            db.session.add(hist)
            # extract alies ID
            alies_id = decode_description_pay(payment.description)
            if not alies_id:
                print(f"Invalid alies ID in description: {payment.description}")
                continue
            alies = db.session.query(AliesPaymentsCustom).filter_by(alies=alies_id).first()
            if not alies:
                print(f"Alies payment not found for ID: {alies_id}")
                continue
            info = AliesPaymentsInfo.model_validate(alies.value)

            payment.id_account = info.id_account
            payment.id_plan = info.id_plan
            hist = PaymentsHistoryCustom(value=payment.model_dump(mode='json'))
            db.session.add(hist)
            
            # get plan definitions
            plan_cfg = db.session.query(SystemCustomInfo).filter_by(name='plan').first()
            plans = plan_cfg.value if plan_cfg else []
            plan = next((p for p in plans if p.get('id') == info.id_plan), None)
            if not plan:
                print(f"Plan not found for ID: {info.id_plan}")
                continue
            # find account
            account = db.session.query(Account).filter_by(id=info.id_account).first()
            if not account or payment.amount < plan.get('price', 0):
                print(f"Account not found or payment amount is less than plan price for account ID: {info.id_account}")
                continue
            # assign plan and expiration
            account.id_custom_plan = info.id_plan
            account.plan_expiration = datetime.now(UTC) + timedelta(days=plan.get('plan_expiration', 0))
            db.session.add(account)
            db.session.delete(alies)

        db.session.commit()
        return jsonify({'status': True, 'msg': 'OK'})

api.add_resource(ApiPlanWebhook, "/webhook/plan")
api.add_resource(ApiPlan, "/plans")
api.add_resource(ApiPaymentSettings, "/payment_settings")
api.add_resource(ApiPaymentHistory, "/payment_history")
api_console.add_resource(ApiPlanPublic, "/custom/plans")
api_console.add_resource(ApiPaymentSettingsPublic, "/custom/payment_settings")
api_console.add_resource(ApiPayRequest, "/custom/pay_request", "/custom/pay_request/<string:id_account>")