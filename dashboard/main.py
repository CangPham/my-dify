import streamlit as st
import streamlit_authenticator as stauth

from config import config
# print(f"API URL: {api_url}")

st.set_page_config(page_title="Dashboard", page_icon=":bar_chart:", layout="wide")

authenticator = stauth.Authenticate(
    config['credentials'],
    config['cookie']['name'],
    config['cookie']['key'],
    config['cookie']['expiry_days']
)

# Load components
from components.accounts import render as render_accounts
from components.plans import render as render_plans
from components.payments import render as render_payments
from components.explore import render as render_explore

try:
    authenticator.login()
except Exception as e:
    st.error(e)

if st.session_state['authentication_status']:
    # Sidebar
    st.sidebar.title("Navigation")
    menu = st.sidebar.radio("Go to", ["Accounts", "Plans", "Payments", "Explore"])

    if menu == "Accounts":
        render_accounts()

    elif menu == "Plans":
        render_plans()

    elif menu == "Payments":
        render_payments()

    elif menu == "Explore":
        render_explore()

else:
    st.warning("Please log in to access the dashboard.")