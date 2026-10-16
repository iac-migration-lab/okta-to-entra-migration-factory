# One import block per seeded configuration object (run 1). Users and group memberships are not imported:
# they are personal data and go to Azure Blob from the snapshot workflow, never to Git (docs/run-1-scope.md section 1).

import {
  to = okta_group.custserv
  id = "00g18sc660tmWyUj0698"
}

import {
  to = okta_group.finance
  id = "00g18sc2sxyLBvB1J698"
}

import {
  to = okta_group.it
  id = "00g18sc4r6df83yDe698"
}

import {
  to = okta_app_oauth.iac_oidc_portal
  id = "0oa18sc1unaUIsCxT698"
}

import {
  to = okta_app_saml.iac_saml_hr_portal
  id = "0oa18sc2q56pVIkoF698"
}

import {
  to = okta_app_saml.slack
  id = "0oa18sc4qjtLVSFGE698"
}

import {
  to = okta_app_saml.iac_saml_it_tools
  id = "0oa18sc4rb0oNOWxW698"
}

import {
  to = okta_app_saml.iac_saml_finance_ledger
  id = "0oa18sc5fzk7InLPE698"
}

import {
  to = okta_app_saml.iac_saml_custserv_desk
  id = "0oa18sc6c20GO1b7L698"
}

import {
  to = okta_network_zone.iac_zone_office
  id = "nzo18sc64kx7AOoT9698"
}

import {
  to = okta_auth_server.iac_authz_api
  id = "aus18sc6umlRvsbzb698"
}

import {
  to = okta_auth_server_scope.iac_read
  id = "aus18sc6umlRvsbzb698/scp18sc5l8hXLH1k8698"
}

import {
  to = okta_auth_server_claim.department
  id = "aus18sc6umlRvsbzb698/ocl18sc587qEq5fiW698"
}

import {
  to = okta_auth_server_policy.iac_authz_portal
  id = "aus18sc6umlRvsbzb698/00p18sc79aprWOCYz698"
}

import {
  to = okta_auth_server_policy_rule.allow_auth_code
  id = "aus18sc6umlRvsbzb698/00p18sc79aprWOCYz698/0pr18sc71ijfBwr9c698"
}

import {
  to = okta_policy_password.iac_pwd_staff
  id = "00p18sc99wfcdKKEW698"
}

import {
  to = okta_policy_rule_password.iac_pwd_staff_rule
  id = "00p18sc99wfcdKKEW698/0pr18sc75kxdM2MTi698"
}

import {
  to = okta_policy_signon.iac_gsp_staff
  id = "00p18sc45fmrpa80E698"
}

import {
  to = okta_policy_rule_signon.iac_gsp_staff_rule
  id = "00p18sc45fmrpa80E698/0pr18sc2pyheDZRxa698"
}

import {
  to = okta_app_signon_policy.iac_authn_saml_apps
  id = "rst18sc587hHu7Tao698"
}

import {
  to = okta_app_signon_policy_rule.finance_2fa
  id = "rst18sc587hHu7Tao698/rul18sc61kwoq0LSF698"
}

import {
  to = okta_app_signon_policy_rule.office_zone
  id = "rst18sc587hHu7Tao698/rul18sc6c3uDI28Ty698"
}

import {
  to = okta_app_signon_policy_rule.catch_all_rule
  id = "rst18sc587hHu7Tao698/rul18sc587ifbuYz4698"
}

import {
  to = okta_app_group_assignments.iac_oidc_portal
  id = "0oa18sc1unaUIsCxT698"
}

import {
  to = okta_app_group_assignments.iac_saml_hr_portal
  id = "0oa18sc2q56pVIkoF698"
}

import {
  to = okta_app_group_assignments.slack
  id = "0oa18sc4qjtLVSFGE698"
}

import {
  to = okta_app_group_assignments.iac_saml_it_tools
  id = "0oa18sc4rb0oNOWxW698"
}

import {
  to = okta_app_group_assignments.iac_saml_finance_ledger
  id = "0oa18sc5fzk7InLPE698"
}

import {
  to = okta_app_group_assignments.iac_saml_custserv_desk
  id = "0oa18sc6c20GO1b7L698"
}
