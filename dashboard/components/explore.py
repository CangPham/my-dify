import pandas as pd
import streamlit as st
import time
from modules.request import requestAuth  # đã sẵn dùng: tự động đính kèm token

# -----------------------------------------------------------
# Helpers
# -----------------------------------------------------------
@st.cache_data(ttl=30, show_spinner=False)
def _load_recommended_apps():
    """Gọi GET /explore – trả về list(dict)."""
    res = requestAuth.get("explore")
    if res.status_code == 200:
        return res.json()
    else:
        st.error(f"Lỗi tải dữ liệu: {res.text}")
        st.stop()


def _update_app(row_dict):
    """PUT /explore/<id> với dữ liệu đã chỉnh sửa."""
    re_id = row_dict["id"]
    payload = {k: v for k, v in row_dict.items() if k != "id"}
    res = requestAuth.put(f"explore/{re_id}", json=payload)
    if res.status_code == 200:
        return True, "Cập nhật thành công"
    # --> trả về tuple để xử lý thông báo
    try:
        msg = res.json().get("message", res.text)
    except Exception:
        msg = res.text
    return False, msg


def _delete_app(re_id):
    res = requestAuth.delete(f"explore/{re_id}")
    if res.status_code == 200:
        return True, "Đã xoá thành công"
    try:
        msg = res.json().get("message", res.text)
    except Exception:
        msg = res.text
    return False, msg


def _add_app(payload):
    res = requestAuth.post("explore", json=payload)
    if res.status_code == 201:
        return True, "Đã thêm thành công"
    try:
        msg = res.json().get("message", res.text)
    except Exception:
        msg = res.text
    return False, msg


# -----------------------------------------------------------
# Main render
# -----------------------------------------------------------
def render():
    st.subheader("Explore – Recommended Apps")

    # Nút refresh
    if st.button("Làm mới"):
        st.cache_data.clear()
        st.rerun()

    # -------------------------------------------------------
    # 1. HIỂN THỊ & CHỈNH SỬA
    # -------------------------------------------------------
    with st.spinner("Đang tải dữ liệu…"):
        data = _load_recommended_apps()

    if not data:
        st.info("Chưa có bản ghi Recommended App nào.")
    else:
        # Chuyển thành DataFrame để hiển thị/biên tập
        df = pd.DataFrame(data)

        # Sắp xếp để dễ xem
        df = df.sort_values(by=["position", "install_count", "created_at"])

        # Bộ cấu hình cột cho Data Editor
        column_cfg = {
            "description": st.column_config.TextColumn(
                "Mô tả", help="Mô tả ngắn về app", required=False
            ),
            "copyright": st.column_config.TextColumn(
                "Bản quyền", help="Thông tin bản quyền", required=False
            ),
            "privacy_policy": st.column_config.TextColumn(
                "Chính sách riêng tư (URL)", help="Liên kết tới chính sách", required=False
            ),
            "category": st.column_config.TextColumn(
                "Phân loại", help="Danh mục hiển thị", required=False
            ),
            "position": st.column_config.NumberColumn(
                "Vị trí", help="Thứ tự ưu tiên hiển thị", required=True, step=1
            ),
            "is_listed": st.column_config.SelectboxColumn(
                "Đang hiển thị?", options=[True, False], required=True
            ),
            "install_count": st.column_config.NumberColumn(
                "Lượt cài đặt", help="Tổng số lượt cài đặt", required=True, step=1
            ),
        }

        disabled_cols = [
            "id",
            "app_id",
            "name",
            "created_at",
            "updated_at",
        ]

        edited_df = st.data_editor(
            df,
            hide_index=True,
            column_config=column_cfg,
            disabled=disabled_cols,
        )

        # So sánh thay đổi
        origin_records = df.to_dict(orient="records")
        edited_records = edited_df.to_dict(orient="records")

        if origin_records != edited_records:
            # Tìm các bản ghi thay đổi
            diff = [
                rec for rec, ori in zip(edited_records, origin_records) if rec != ori
            ]
            with st.spinner("Đang lưu thay đổi…"):
                errors = []
                for rec in diff:
                    ok, msg = _update_app(rec)
                    if not ok:
                        errors.append(f"ID {rec['id']}: {msg}")

            if errors:
                st.error("Một số bản ghi lưu KHÔNG thành công:\n\n" + "\n".join(errors))
            else:
                st.success("Tất cả thay đổi đã được lưu.")
                st.cache_data.clear()
                time.sleep(1)
                st.rerun()

    # -------------------------------------------------------
    # 2. THÊM MỚI
    # -------------------------------------------------------
    st.markdown("---")
    st.markdown("### Thêm Recommended App")

    with st.form("add_app_form", clear_on_submit=True):
        col1, col2 = st.columns(2)
        with col1:
            app_id = st.text_input("App ID *", help="ID của App gốc (bắt buộc)")
            position = st.number_input("Vị trí hiển thị", value=0, step=1)
            is_listed = st.selectbox("Đang hiển thị?", [True, False], index=0)
            install_count = st.number_input("Lượt cài đặt", value=0, step=1)

        with col2:
            category = st.text_input("Phân loại", value="sample")
            description = st.text_area("Mô tả", value="sample")
            copyright_ = st.text_input("Bản quyền", value="sample")
            privacy_policy = st.text_input("Privacy Policy URL", value="sample")

        submitted = st.form_submit_button("Thêm mới")

        if submitted:
            if not app_id:
                st.error("`App ID` là bắt buộc.")
            else:
                payload = {
                    "app_id": app_id,
                    "position": position,
                    "is_listed": is_listed,
                    "install_count": install_count,
                    # Các trường có thể rỗng
                    "category": category or None,
                    "description": description or None,
                    "copyright": copyright_ or None,
                    "privacy_policy": privacy_policy or None,
                }
                ok, msg = _add_app(payload)
                if ok:
                    st.success(msg)
                    st.cache_data.clear()
                    time.sleep(1)
                    st.rerun()
                else:
                    st.error(f"Lỗi: {msg}")

    # -------------------------------------------------------
    # 3. XOÁ
    # -------------------------------------------------------
    st.markdown("---")
    st.markdown("### Xoá Recommended App")

    with st.form("delete_app_form"):
        delete_id = st.text_input("Nhập `ID` muốn xoá")
        submit_delete = st.form_submit_button("Xoá")

    if submit_delete:
        if delete_id:
            ok, msg = _delete_app(delete_id)
            if ok:
                st.success(msg)
                st.cache_data.clear()
                time.sleep(1)
                st.rerun()
            else:
                st.error(f"Lỗi: {msg}")
        else:
            st.error("Vui lòng nhập ID hợp lệ.")