# Custom SAML 2.0 app, group CustServ. Test SP: IAM Showcase (docs/okta-seed-spec.md section 3).
resource "okta_app_saml" "iac_saml_custserv_desk" {
  label                 = "iac-saml-custserv-desk"
  status                = "ACTIVE"
  authentication_policy = okta_app_signon_policy.iac_authn_saml_apps.id

  sso_url                  = "https://sptest.iamshowcase.com/acs"
  recipient                = "https://sptest.iamshowcase.com/acs"
  destination              = "https://sptest.iamshowcase.com/acs"
  audience                 = "IAMShowcase"
  idp_issuer               = "http://www.okta.com/$${org.externalKey}"
  subject_name_id_format   = "urn:oasis:names:tc:SAML:1.1:nameid-format:emailAddress"
  subject_name_id_template = "$${user.userName}"
  authn_context_class_ref  = "urn:oasis:names:tc:SAML:2.0:ac:classes:PasswordProtectedTransport"
  response_signed          = true
  assertion_signed         = true
  signature_algorithm      = "RSA_SHA256"
  digest_algorithm         = "SHA256"
  honor_force_authn        = true
  saml_version             = "2.0"
  user_name_template       = "$${source.login}"
  user_name_template_type  = "BUILT_IN"
}

resource "okta_app_group_assignments" "iac_saml_custserv_desk" {
  app_id = okta_app_saml.iac_saml_custserv_desk.id
  group {
    id       = okta_group.custserv.id
    priority = 0
    profile  = jsonencode({})
  }
}
