output "url" {
  description = "An ALB answers on a DNS name, never on an address you own. Google hands you a global anycast IP instead."
  value       = "http://${aws_lb.main.dns_name}"
}

output "db_endpoint" {
  value = aws_db_instance.main.address
}
