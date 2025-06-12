import time
import pandas as pd
import streamlit as st
from config import api_url
from modules.request import requestAuth

# Cache data


def get_accounts():
    res = requestAuth.get("accounts")
    if res.status_code == 200:
        return res.json()
    else:
        raise Exception("Failed to load accounts.")


def render():

    st.subheader("Accounts")

    # Button to refresh
    if st.button("Refresh"):
        st.rerun()

    # Get accounts from API flask
    with st.spinner("Loading accounts..."):
        accounts = get_accounts()

    if len(accounts) == 0:
        st.warning("No accounts found.")
        st.stop()

    # Load to dataframe
    df = pd.DataFrame(accounts, columns=[
        "id",
        "name",
        "email",
        "status",

        "id_custom_plan",
        "plan_expiration",
        "month_before_banned",
        "max_of_apps",
        "max_vector_space",
        "max_annotation_quota_limit",
        "max_documents_upload_quota",

        "last_login_at",
        "last_login_ip",
        "last_active_at",
        "created_at",
        "updated_at"
    ])

    df = df.sort_values(by=['created_at'])

    # Convert plan_expiration strings to datetime for editing
    df['plan_expiration'] = pd.to_datetime(df['plan_expiration'])

    # Show accounts
    edited_df = st.data_editor(
        df,
        column_config={
            "status": st.column_config.SelectboxColumn(
                "status",
                help="Account status",
                options=["pending", "uninitialized",
                         "active", "banned", "closed"],
                required=True,
            ),
            "id_custom_plan": st.column_config.TextColumn(  # replaced StringColumn -> TextColumn
                "id_custom_plan",
                help="The ID of the custom plan",
                required=True,
            ),
            "plan_expiration": st.column_config.DatetimeColumn(
                "plan_expiration",
                help="The date when the plan expires",
                required=True,
            ),
            "month_before_banned": st.column_config.NumberColumn(
                "month_before_banned",
                help="The number of months before the user account is banned",
                required=True,
            ),
            "max_of_apps": st.column_config.NumberColumn(
                "max_of_apps",
                help="The maximum number of apps that a user can create",
                required=True,
            ),
            "max_vector_space": st.column_config.NumberColumn(
                "max_vector_space",
                help="The maximum size vector spaces (MB)",
                required=True,
            ),
            "max_annotation_quota_limit": st.column_config.NumberColumn(
                "max_annotation_quota_limit",
                help="The maximum number of annotation quota limit that a user can create",
                required=True,
            ),
            "max_documents_upload_quota": st.column_config.NumberColumn(
                "max_documents_upload_quota",
                help="The maximum number of documents upload quota that a user can create",
                required=True,
            ),
        },
        disabled=[
            "id",
            "name",
            "email",
            "last_login_at",
            "last_login_ip",
            "last_active_at",
            "created_at",
            "updated_at"
        ],
        hide_index=True,
    )

    # Save changes
    edited_df = edited_df.to_dict(orient="records")
    if df.to_dict(orient="records") == edited_df:
        pass
    else:
        # Convert any pandas Timestamps to JSON-serializable strings
        for rec in edited_df:
            ts = rec.get("plan_expiration")
            if isinstance(ts, pd.Timestamp):
                rec["plan_expiration"] = ts.isoformat()

        res = requestAuth.put(
            "accounts",
            json=edited_df,
        )

        if res.status_code == 200:
            st.success("Changes saved successfully.")
            st.rerun()
        else:
            st.error("Failed to save changes.")
            time.sleep(2)
            st.rerun()

    # Delete account by ID, UI form for input ID to delete
    st.markdown("### Delete Account")
    with st.form("delete_account_form"):
        delete_id = st.text_input("Enter Account ID to delete")
        submit_button = st.form_submit_button("Delete Account")

    if submit_button:
        if delete_id:
            try:
                st.write(f"{api_url}/accounts/{delete_id}")
                res = requestAuth.delete(
                    f"accounts/{delete_id}",
                )

                try:
                    resjson = res.json()
                    if resjson['status'] == "success":
                        st.success(
                            f"Account {delete_id} deleted successfully.")
                        st.rerun()
                    else:
                        st.error(f"Error: {resjson['message']}")
                except:
                    st.error(f"Unknow error: {res.text}")
            except Exception as e:
                st.error(f"Error request: {e}")
        else:
            st.error("Please enter a valid Account ID.")
