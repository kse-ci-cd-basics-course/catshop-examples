# An auto scaling group is the cloud's `count`, same as Google's managed
# instance group: declare how many there should be and something else keeps it
# true. The group joins the target group, rather than the load balancer
# pointing at instances.

resource "aws_launch_template" "app" {
  name_prefix   = "${var.name}-"
  image_id      = var.ami
  instance_type = "t3.micro"

  vpc_security_group_ids = [aws_security_group.app.id]

  user_data = base64encode(<<-EOT
    #!/bin/bash
    dnf install -y docker && systemctl enable --now docker
    docker run -d --restart=always -p 8080:8080 \
      -e DATABASE_URL="postgresql://catshop:${random_password.db.result}@${aws_db_instance.main.address}:5432/catshop" \
      ${var.image}
  EOT
  )
}

resource "aws_autoscaling_group" "app" {
  name                = "${var.name}-asg"
  min_size            = var.replicas
  max_size            = var.replicas
  desired_capacity    = var.replicas
  vpc_zone_identifier = aws_subnet.public[*].id

  # Membership of the pool is a property of the GROUP here. On Google the
  # backend service names the instance group instead.
  target_group_arns = [aws_lb_target_group.app.arn]
  health_check_type = "ELB"

  launch_template {
    id      = aws_launch_template.app.id
    version = "$Latest"
  }
}
