# Three objects where Google needs five, and nginx needs one config file.
#
#   aws_lb                the thing with an address — and it is IN your subnets
#   aws_lb_target_group   the pool, and the health check lives on it
#   aws_lb_listener       the listener, and the default rule

resource "aws_lb" "main" {
  name               = "${var.name}-alb"
  load_balancer_type = "application"
  security_groups    = [aws_security_group.lb.id]

  # The subnets, plural, in different zones. This argument is why network.tf
  # declares two of them and why Google's equivalent needs none.
  subnets = aws_subnet.public[*].id
}

resource "aws_lb_target_group" "app" {
  name     = "${var.name}-tg"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  # On Google this is a separate top-level object that several backend services
  # can share. Here it belongs to the pool.
  health_check {
    path                = "/health"
    interval            = 10
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}
