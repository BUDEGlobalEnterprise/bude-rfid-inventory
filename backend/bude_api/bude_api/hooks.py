app_name = "bude_api"
app_title = "Bude API"
app_publisher = "Bude"
app_description = "API layer for the Bude RFID Inventory mobile platform."
app_license = "MIT"
app_version = "0.1.0"

required_apps = ["erpnext"]

# Idempotently ensure the bude_epc Custom Fields exist (no custom doctypes).
after_install = "bude_api.custom.rfid_fields.ensure_custom_fields"
after_migrate = "bude_api.custom.rfid_fields.ensure_custom_fields"
