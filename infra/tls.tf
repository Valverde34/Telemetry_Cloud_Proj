# Private certificate authority (CA) and TLS certificate for the MQTT broker.
# Only our own containers need to trust it, so a private CA is enough.
# Note: the private keys end up in the Terraform state, which is why the state
# lives in a private, encrypted storage account (see infra/bootstrap).

resource "tls_private_key" "mqtt_ca" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P256"
}

resource "tls_self_signed_cert" "mqtt_ca" {
  private_key_pem       = tls_private_key.mqtt_ca.private_key_pem
  is_ca_certificate     = true
  validity_period_hours = 87600 # 10 years
  allowed_uses          = ["cert_signing", "crl_signing"]

  subject {
    common_name = "${var.project}-mqtt-ca"
  }
}

resource "tls_private_key" "mqtt_server" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P256"
}

resource "tls_cert_request" "mqtt_server" {
  private_key_pem = tls_private_key.mqtt_server.private_key_pem

  # Names the clients may use to reach the broker inside the environment.
  dns_names = ["mosquitto", "mosquitto.internal.${azurerm_container_app_environment.main.default_domain}"]

  subject {
    common_name = "mosquitto"
  }
}

resource "tls_locally_signed_cert" "mqtt_server" {
  cert_request_pem      = tls_cert_request.mqtt_server.cert_request_pem
  ca_private_key_pem    = tls_private_key.mqtt_ca.private_key_pem
  ca_cert_pem           = tls_self_signed_cert.mqtt_ca.cert_pem
  validity_period_hours = 8760 # 1 year
  allowed_uses          = ["digital_signature", "key_encipherment", "server_auth"]
}
