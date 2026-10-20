# A new Conditional Access policy starts in report-only; turning it on is a separate, reviewed change.
package main

deny contains msg if {
	rc := input.resource_changes[_]
	rc.type == "azuread_conditional_access_policy"
	"create" in rc.change.actions
	rc.change.after.state != "enabledForReportingButNotEnforced"
	msg := sprintf("%s: new CA policy must start report-only (state enabledForReportingButNotEnforced, got %s)", [rc.address, rc.change.after.state])
}
