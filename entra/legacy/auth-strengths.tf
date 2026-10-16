# Built in the portal as "iac-authenticator-or-fido2" (the click path said iac-legacy-as-...); kept as found.
resource "azuread_authentication_strength_policy" "authenticator_or_fido2" {
  display_name         = "iac-authenticator-or-fido2"
  allowed_combinations = ["fido2", "password,microsoftAuthenticatorPush"]

  lifecycle {
    prevent_destroy = true
  }
}
