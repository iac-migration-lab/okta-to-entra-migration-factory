# Created by hand 2026-10-01 (findings "Budget alert on the lab subscription"), imported 2026-10-18.
import {
  to = azurerm_consumption_budget_subscription.lab_monthly
  id = "/subscriptions/6ea51c80-90de-4914-bbc6-2af9b54bba9f/providers/Microsoft.Consumption/budgets/budget-iac-lab-monthly"
}

resource "azurerm_consumption_budget_subscription" "lab_monthly" {
  name            = "budget-iac-lab-monthly"
  subscription_id = "/subscriptions/6ea51c80-90de-4914-bbc6-2af9b54bba9f"
  amount          = 10
  time_grain      = "Monthly"

  time_period {
    start_date = "2026-10-01T00:00:00Z"
    end_date   = "2027-09-30T00:00:00Z"
  }

  dynamic "notification" {
    for_each = [50, 80, 100]
    content {
      enabled        = true
      operator       = "GreaterThanOrEqualTo"
      threshold      = notification.value
      threshold_type = "Actual"
      contact_emails = ["la-migration-lab@outlook.com"]
    }
  }
}
