output "staff_group_object_ids" {
  value = { for k, g in azuread_group.staff : k => g.object_id }
}
