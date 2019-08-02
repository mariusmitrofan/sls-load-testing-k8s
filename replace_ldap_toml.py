import base64
import os
from dotenv import load_dotenv

load_dotenv()

output = """
verbose_logging = true
[[servers]]
host = "ldap_hostname_here"
port = 389
use_ssl = false
ssl_skip_verify = false

search_filter = "(sAMAccountName=%s)"
search_base_dns = ["search_base_dn_here"]

bind_dn = "bind_dn_user_here"
bind_password = 'bind_dn_password_here'

[servers.attributes]
name = "givenName"
surname = "sn"
username = "sAMAccountName"
member_of = "memberOf"
email =  "mail"

[[servers.group_mappings]]
group_dn = "group_admin_dn_here"
org_role = "Admin"
grafana_admin = true

[[servers.group_mappings]]
group_dn = "*"
org_role = "Editor"
"""

output = output.replace("ldap_hostname_here", os.getenv("LDAP_HOST"))
output = output.replace("search_base_dn_here", os.getenv("SEARCH_BASE_DN"))
output = output.replace("bind_dn_user_here", os.getenv("BIND_DN"))
output = output.replace("bind_dn_password_here", os.getenv("BIND_PASS"))
output = output.replace("group_admin_dn_here", os.getenv("GROUP_ADMIN_DN"))

output_encoded_bytes = base64.urlsafe_b64encode(output.encode("utf-8"))
output_encoded_string = str(output_encoded_bytes, "utf-8")

with open("custom-grafana-config.yaml") as f:
  newText=f.read().replace('ldap_config_encrypted_here', output_encoded_string)

with open("deploy-custom-grafana-config.yaml", "w") as f:
  f.write(newText)
