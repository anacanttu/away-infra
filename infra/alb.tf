resource "aws_lb" "main" {
  name               = "alb-${var.project}"
  load_balancer_type = "application"
  internal           = false
  # Descarta cabeçalhos HTTP inválidos (mitiga request smuggling)
  drop_invalid_header_fields = true
  security_groups            = [aws_security_group.alb.id]
  subnets                    = [aws_subnet.pub_a.id, aws_subnet.pub_b.id] # ALB exige 2 AZs
}

resource "aws_lb_target_group" "app" {
  name     = "tg-${var.project}-app"
  port     = var.app_port
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    path                = var.app_health_check_path
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 30
  }
}

resource "aws_lb_target_group_attachment" "app" {
  target_group_arn = aws_lb_target_group.app.arn
  target_id        = aws_instance.app.id
  port             = var.app_port
}

# --- Certificado HTTPS (ACM), validado por DNS ---
# O domínio não está na AWS, então a validação é manual: depois do primeiro passo
# (veja README), você cria o registro CNAME mostrado em "acm_validation_records"
# no painel onde o domínio é gerenciado.
resource "aws_acm_certificate" "main" {
  domain_name       = local.fqdn
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

# Só termina quando o CNAME de validação existir no DNS
resource "aws_acm_certificate_validation" "main" {
  certificate_arn = aws_acm_certificate.main.arn
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.main.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = aws_acm_certificate_validation.main.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

# HTTP (80) só redireciona para HTTPS
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}
