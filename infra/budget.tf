# Alerta de custo: avisa por e-mail quando o gasto mensal se aproximar do limite.
# Só é criado se você preencher budget_email. Os 2 primeiros budgets da conta são gratuitos.

resource "aws_budgets_budget" "monthly" {
  count = var.budget_email == "" ? 0 : 1

  name         = "${var.project}-mensal"
  budget_type  = "COST"
  limit_amount = tostring(var.monthly_budget_usd)
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  # Sem isso o budget desconta os créditos da conta (US$ 100) e o gasto "aparente"
  # ficaria perto de zero: o alerta não dispararia. Aqui medimos o uso bruto.
  cost_types {
    include_credit = false
    include_refund = false
  }

  # Avisos por e-mail a 50%, 80% e 100% do limite (gasto real)
  dynamic "notification" {
    for_each = [50, 80, 100]
    content {
      comparison_operator        = "GREATER_THAN"
      threshold                  = notification.value
      threshold_type             = "PERCENTAGE"
      notification_type          = "ACTUAL"
      subscriber_email_addresses = [var.budget_email]
    }
  }

  # Aviso quando a PREVISÃO do mês passar de 100% do limite
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = [var.budget_email]
  }
}
