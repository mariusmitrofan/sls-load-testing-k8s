import base64

with open("ldap.toml", "rb") as file:
  encoded_string = str(base64.b64encode(file.read()))[2:-1]

with open("custom-grafana-config.yaml") as f:
  newText=f.read().replace('ldap_config_encrypted_here', encoded_string)

with open("custom-grafana-config.yaml", "w") as f:
  f.write(newText)