# Every Conditional Access policy that a plan creates or updates must exclude the break-glass group
# (CLAUDE.md: break-glass excluded from every CA policy, by module and by Conftest rule).
package main

bg_ca_exclusion_group_id := "21008cb0-56d6-4fc4-9f1c-9e20dc1d5620" # bg-ca-exclusion

deny contains msg if {
	rc := input.resource_changes[_]
	rc.type == "azuread_conditional_access_policy"
	some action in rc.change.actions
	action in {"create", "update"}
	not excludes_break_glass(rc.change.after)
	msg := sprintf("%s: CA policy must exclude bg-ca-exclusion (%s)", [rc.address, bg_ca_exclusion_group_id])
}

excludes_break_glass(after) if {
	bg_ca_exclusion_group_id in after.conditions[0].users[0].excluded_groups
}
