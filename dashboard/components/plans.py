import time
import pandas as pd
import streamlit as st
from uuid import uuid4
from modules.request import requestAuth

# Function generates a random UUID
def generate_random_id():
    return str(uuid4())

# Add functions for Plans API
def get_plans():
    res = requestAuth.get("plans")
    if res.status_code == 200:
        return res.json()
    else:
        st.error(f"Failed to load plans: {res.status_code} {res.text}")
        return []


def update_plans(plans_data):
    res = requestAuth.put(
        "plans",
        json=plans_data,
    )
    return res


def render():
    st.subheader("Manage Plans")

    # Button to refresh
    if st.button("Refresh Plans"):
        st.rerun()

    # Get plans from API
    with st.spinner("Loading plans..."):
        plans_data = get_plans()

    if 'plans_df' not in st.session_state or st.session_state.plans_data != plans_data:
        st.session_state.plans_data = plans_data
        # Convert nested features dict to separate columns for editing
        flat_plans = []
        for plan in plans_data:
            flat_plan = plan.copy()
            features = flat_plan.pop('features', {})
            flat_plan.update(features)
            flat_plans.append(flat_plan)
        st.session_state.plans_df = pd.DataFrame(flat_plans)
        # Ensure plan_expiration is integer days
        if 'plan_expiration' in st.session_state.plans_df.columns:
            st.session_state.plans_df['plan_expiration'] = st.session_state.plans_df['plan_expiration'].astype(
                int)

    if st.session_state.plans_df.empty:
        st.warning("No plans found or failed to load.")
        # Optionally allow creating the first plan
        if st.button("Add First Plan"):
            # Add a default row to the DataFrame in session state
            default_features = {
                "members": 1,
                "apps": 10,
                "vector_space": 100,
                "knowledge_rate_limit": 10,
                "annotation_quota_limit": 100,
                "documents_upload_quota": 50
            }
            new_plan_row = pd.DataFrame([{
                "id": str(generate_random_id()),
                "name": "New Plan",
                "description": "Default description",
                "price": 0.0,
                "plan_expiration": 30,  # default days
                **default_features
            }])
            st.session_state.plans_df = pd.concat(
                [st.session_state.plans_df, new_plan_row], ignore_index=True)
            st.rerun()

    else:
        st.info("Edit plan details below. Click 'Add New Plan' to add a row, then 'Save Changes' to update all plans.")

        edited_plans_df = st.data_editor(
            st.session_state.plans_df,
            column_config={
                "id": st.column_config.TextColumn("ID (read-only)", disabled=True),
                "name": st.column_config.TextColumn("Name", required=True),
                "description": st.column_config.TextColumn("Description"),
                "price": st.column_config.NumberColumn("Price", format="%.2f", required=True),
                "plan_expiration": st.column_config.NumberColumn(
                    "Expiration Days",
                    help="Number of days until expiration",
                    required=True,
                    min_value=0
                ),
                "members": st.column_config.NumberColumn("Members Limit", required=True, min_value=1),
                "apps": st.column_config.NumberColumn("Apps Limit", required=True, min_value=0),
                "vector_space": st.column_config.NumberColumn("Vector Space (MB)", required=True, min_value=0),
                "knowledge_rate_limit": st.column_config.NumberColumn("Knowledge Rate Limit", required=True, min_value=0),
                "annotation_quota_limit": st.column_config.NumberColumn("Annotation Quota Limit", required=True, min_value=0),
                "documents_upload_quota": st.column_config.NumberColumn("Docs Upload Quota", required=True, min_value=0),
            },
            hide_index=True,
            num_rows="dynamic",

            key="plan_editor",
            column_order=[
                "id", "name", "description", "price", "plan_expiration",
                "members", "apps", "vector_space", "knowledge_rate_limit",
                "annotation_quota_limit", "documents_upload_quota"
            ],
        )

        # Check if changes were made
        original_df_dict = st.session_state.plans_df.to_dict(orient="records")
        edited_df_dict = edited_plans_df.to_dict(orient="records")

        col1, col2 = st.columns(2)
        with col1:
            # Button to add a new plan row to the editor
            if st.button("Add New Plan Row"):
                default_features = {
                    "members": 1,
                    "apps": 10,
                    "vector_space": 100,
                    "knowledge_rate_limit": 10,
                    "annotation_quota_limit": 100,
                    "documents_upload_quota": 50
                }
                new_id = str(generate_random_id())
                # Add to the DataFrame being edited
                new_plan_row = pd.DataFrame([{
                    "id": new_id,
                    "name": "New Plan",
                    "description": "Enter description",
                    "price": 0.0,
                    "plan_expiration": 30,  # default days
                    **default_features
                }])
                # Update the session state DataFrame directly for the editor
                st.session_state.plans_df = pd.concat(
                    [edited_plans_df, new_plan_row], ignore_index=True)
                st.rerun()

        with col2:
            # Save changes button (only active if changes detected)
            save_disabled = original_df_dict == edited_df_dict
            if st.button("Save Changes", disabled=save_disabled):
                # Reconstruct the nested structure expected by the API
                plans_to_save = []
                for _, row in edited_plans_df.iterrows():
                    plan_dict = row.to_dict()
                    features = {
                        "members": int(plan_dict.pop("members")),
                        "apps": int(plan_dict.pop("apps")),
                        "vector_space": int(plan_dict.pop("vector_space")),
                        "knowledge_rate_limit": int(plan_dict.pop("knowledge_rate_limit")),
                        "annotation_quota_limit": int(plan_dict.pop("annotation_quota_limit")),
                        "documents_upload_quota": int(plan_dict.pop("documents_upload_quota"))
                    }
                    # Number of days until expiration
                    plan_dict['plan_expiration'] = int(
                        plan_dict['plan_expiration'])
                    plan_dict['features'] = features
                    # Ensure price is float
                    plan_dict['price'] = float(plan_dict['price'])
                    plans_to_save.append(plan_dict)

                res = update_plans(plans_to_save)

                if res.status_code == 200:
                    st.success("Plans updated successfully.")
                    # Update session state with the saved data and rerun
                    st.session_state.plans_data = plans_to_save
                    st.session_state.plans_df = edited_plans_df
                    time.sleep(1)
                    st.rerun()
                else:
                    st.error(
                        f"Failed to save plans: {res.status_code} {res.text}")
                    time.sleep(2)
