# Nothing under entra/legacy is destroyed (prevent_destroy is the first line, this is the second).
# The pipeline passes the root folder as data: conftest --data <file with {"context": {"root": "entra/legacy"}}>.
package main

deny contains msg if {
	data.context.root == "entra/legacy"
	rc := input.resource_changes[_]
	"delete" in rc.change.actions
	msg := sprintf("%s: entra/legacy objects must not be destroyed", [rc.address])
}
