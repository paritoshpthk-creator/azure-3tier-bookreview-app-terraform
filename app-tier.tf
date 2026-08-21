# app-tier.tf

# 1. Custom Script Extension to permanently provision Flask App
resource "azurerm_virtual_machine_extension" "flask_setup" {
  name                 = "flask-app-init"
  virtual_machine_id   = azurerm_linux_virtual_machine.app_vm.id
  publisher            = "Microsoft.Azure.Extensions"
  type                 = "CustomScript"
  type_handler_version = "2.1"

  settings = jsonencode({
    commandToExecute = "mkdir -p /app && echo 'from flask import Flask\napp = Flask(__name__)\n@app.route(\"/\")\ndef home():\n    return \"Book Review App Tier is up and running on port 5000!\"\nif __name__ == \"__main__\":\n    app.run(host=\"0.0.0.0\", port=5000)' > /app/app.py && apt-get update -y && apt-get install -y python3-flask && echo '[Unit]\nDescription=Flask Application\nAfter=network.target\n[Service]\nUser=root\nWorkingDirectory=/app\nExecStart=/usr/bin/python3 /app/app.py\nRestart=always\n[Install]\nWantedBy=multi-user.target' > /etc/systemd/system/flaskapp.service && systemctl daemon-reload && systemctl enable flaskapp && systemctl restart flaskapp"
  })
}