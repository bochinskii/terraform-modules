
#
# Global Accelerator
#

resource "aws_globalaccelerator_accelerator" "ga" {
  name            = var.ga_name
  ip_address_type = "IPV4"
  enabled         = true

  attributes {
    flow_logs_enabled   = false
  }

  tags = {
    Name = var.ga_name
  }
}

resource "aws_globalaccelerator_listener" "instances_ga" {
  accelerator_arn = aws_globalaccelerator_accelerator.ga.id
  client_affinity = "SOURCE_IP"
  protocol        = "TCP"

  port_range {
    from_port = 80
    to_port   = 80
  }
}


resource "aws_globalaccelerator_endpoint_group" "instance_ga_first" {
  listener_arn = aws_globalaccelerator_listener.instances_ga.id
  endpoint_group_region = data.aws_region.current_region_first.name

  health_check_interval_seconds = var.health_checks_ga["health_check_interval_seconds"]
  health_check_path = var.health_checks_ga["health_check_path"]
  health_check_protocol = var.health_checks_ga["health_check_protocol"]
  threshold_count = var.health_checks_ga["threshold_count"]

  traffic_dial_percentage = 100

  endpoint_configuration {
    endpoint_id = aws_instance.instance_first.id
    weight      = 128
  }
}

resource "aws_globalaccelerator_endpoint_group" "instance_ga_second" {
  listener_arn = aws_globalaccelerator_listener.instances_ga.id
  endpoint_group_region = data.aws_region.current_region_second.name

  health_check_interval_seconds = var.health_checks_ga["health_check_interval_seconds"]
  health_check_path = var.health_checks_ga["health_check_path"]
  health_check_protocol = var.health_checks_ga["health_check_protocol"]
  threshold_count = var.health_checks_ga["threshold_count"]

  traffic_dial_percentage = 100

  endpoint_configuration {
    endpoint_id = aws_instance.instance_second.id
    weight      = 128
  }
}
