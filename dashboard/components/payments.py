import time
import pandas as pd
import requests
import streamlit as st
from modules.request import requestAuth
from config import config

# function payment settings
def get_payment_settings():
    res = requestAuth.get("payment_settings")
    if res.status_code == 200:
        return res.json()
    else:
        st.error(
            f"Failed to load payment settings. Status code: {res.status_code}")
        try:
            st.error(f"Error details: {res.json()}")
        except:
            st.error(f"Error details: {res.text}")
        return None  # Return None or a default dict if loading fails


# helper to fetch payment history
def get_payment_history():
    res = requestAuth.get("payment_history")
    if res.status_code == 200:
        return res.json()
    else:
        st.error(f"Failed to load payment history. Status code: {res.status_code}")
        try:
            st.error(f"Error details: {res.json()}")
        except:
            st.error(f"Error details: {res.text}")
        return None


def render():
    st.subheader("Payment Settings")

    # Button to refresh
    if st.button("Refresh Settings"):
        # Clear cache before rerun
        st.cache_data.clear()
        st.rerun()

    # Get payment settings from API
    with st.spinner("Loading payment settings..."):
        settings = get_payment_settings()

    if settings is None:
        st.error(
            "Could not load payment settings. Please check the API connection or logs.")
        st.stop()

    # Ensure all expected keys exist, providing defaults if necessary
    settings.setdefault('access_token', '')
    settings.setdefault('account_name', '')
    settings.setdefault('account_id', '')
    settings.setdefault('bank_id', '')  # Ensure bank_id exists

    # Define bank options (code: name)
    bank_options = {
        "ICB": "(970415) VietinBank", "VCB": "(970436) Vietcombank", "BIDV": "(970418) BIDV",
        "VBA": "(970405) Agribank", "OCB": "(970448) OCB", "MB": "(970422) MBBank",
        "TCB": "(970407) Techcombank", "ACB": "(970416) ACB", "VPB": "(970432) VPBank",
        "TPB": "(970423) TPBank", "STB": "(970403) Sacombank", "HDB": "(970437) HDBank",
        "VCCB": "(970454) VietCapitalBank", "SCB": "(970429) SCB", "VIB": "(970441) VIB",
        "SHB": "(970443) SHB", "EIB": "(970431) Eximbank", "MSB": "(970426) MSB",
        "CAKE": "(546034) CAKE", "Ubank": "(546035) Ubank", "TIMO": "(963388) Timo",
        "VTLMONEY": "(971005) ViettelMoney", "VNPTMONEY": "(971011) VNPTMoney",
        "SGICB": "(970400) SaigonBank", "BAB": "(970409) BacABank", "PVCB": "(970412) PVcomBank",
        "Oceanbank": "(970414) Oceanbank", "NCB": "(970419) NCB", "SHBVN": "(970424) ShinhanBank",
        "ABB": "(970425) ABBANK", "VAB": "(970427) VietABank", "NAB": "(970428) NamABank",
        "PGB": "(970430) PGBank", "VIETBANK": "(970433) VietBank", "BVB": "(970438) BaoVietBank",
        "SEAB": "(970440) SeABank", "COOPBANK": "(970446) COOPBANK", "LPB": "(970449) LPBank",
        "KLB": "(970452) KienLongBank", "KBank": "(668888) KBank", "KBHN": "(970462) KookminHN",
        "KEBHANAHCM": "(970466) KEBHanaHCM", "KEBHANAHN": "(970467) KEBHANAHN", "MAFC": "(977777) MAFC",
        "CITIBANK": "(533948) Citibank", "KBHCM": "(970463) KookminHCM", "VBSP": "(999888) VBSP",
        "WVN": "(970457) Woori", "VRB": "(970421) VRB", "UOB": "(970458) UnitedOverseas",
        "SCVN": "(970410) StandardChartered", "PBVN": "(970439) PublicBank", "NHB HN": "(801011) Nonghyup",
        "IVB": "(970434) IndovinaBank", "IBK - HCM": "(970456) IBKHCM", "IBK - HN": "(970455) IBKHN",
        "HSBC": "(458761) HSBC", "HLBVN": "(970442) HongLeong", "GPB": "(970408) GPBank",
        "DOB": "(970406) DongABank", "DBS": "(796500) DBSBank", "CIMB": "(422589) CIMB",
        "CBB": "(970444) CBBank"
    }
    bank_codes = list(bank_options.keys())

    # Find index for default value
    current_bank_id = settings.get('bank_id', '')
    try:
        # Set index to the current bank_id if it exists in our list, otherwise default to 0 (first item)
        current_index = bank_codes.index(
            current_bank_id) if current_bank_id in bank_codes else 0
    except ValueError:
        current_index = 0  # Fallback in case index() fails unexpectedly

    # Display settings in a form
    with st.form("payment_settings_form"):
        st.markdown("#### Configure Payment Gateway Details")
        access_token = st.text_input(
            "Access Token", value=settings['access_token'], type="password")
        account_name = st.text_input(
            "Account Name", value=settings['account_name'])
        account_id = st.text_input("Account ID", value=settings['account_id'])
        # Use selectbox for Bank ID
        bank_id = st.selectbox(
            "Bank",
            options=bank_codes,
            index=current_index,
            # Display name, fallback to code if not found
            format_func=lambda code: bank_options.get(code, code)
        )

        submitted = st.form_submit_button("Save Settings")

        if submitted:
            updated_settings = {
                "access_token": access_token,
                "account_name": account_name,
                "account_id": account_id,
                "bank_id": bank_id  # bank_id now holds the selected code
            }

            # Send updated settings to API
            try:
                res = requestAuth.put(
                    "payment_settings",
                    json=updated_settings,
                )
                if res.status_code == 200:
                    st.success("Payment settings saved successfully.")
                    # Clear cache after successful update
                    st.cache_data.clear()
                    time.sleep(1)  # Give user time to see the message
                    st.rerun()
                else:
                    st.error(
                        f"Failed to save settings. Status code: {res.status_code}")
                    try:
                        st.error(f"Error details: {res.json()}")
                    except:
                        st.error(f"Error details: {res.text}")
            except requests.exceptions.RequestException as e:
                st.error(f"Failed to connect to API: {e}")
    
    # Webhook URL
    st.markdown("#### Webhook URL")
    webhook_url = config['payment']['webhook_url']
    st.text_input("Webhook URL", value=webhook_url, disabled=True)
    st.markdown(
        "Webhook URL is used to receive payment notifications. Please configure it in your payment gateway settings.")

    # === Payment History Section ===
    st.subheader("Payment History")
    with st.spinner("Loading payment history..."):
        history = get_payment_history()
    if history is not None:
        if len(history) > 0:
            df = pd.DataFrame(history, columns=[
                'id', 'id_account', 'id_plan', 'type', 'transactionID', 'amount', 'description', 'date', 'bank'
            ])
            st.dataframe(df)
        else:
            st.info("No payment history records found.")
    else:
        st.error("Could not load payment history.")
