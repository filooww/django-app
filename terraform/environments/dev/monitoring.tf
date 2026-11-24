locals {
  instances = {
    django     = module.django.id
    postgres   = module.postgres.id
    monitoring = module.monitoring.id
  }

  disk_alarms = {
    django-root     = { instance = module.django.id, path = "/" }
    postgres-root   = { instance = module.postgres.id, path = "/" }
    postgres-data   = { instance = module.postgres.id, path = "/var/lib/postgresql" }
    monitoring-root = { instance = module.monitoring.id, path = "/" }
  }

  alarm_actions = var.alarm_email != "" ? [aws_sns_topic.alarms[0].arn] : []
}

resource "aws_sns_topic" "alarms" {
  count = var.alarm_email != "" ? 1 : 0
  name  = "${local.name}-alarms"
}

resource "aws_sns_topic_subscription" "email" {
  count     = var.alarm_email != "" ? 1 : 0
  topic_arn = aws_sns_topic.alarms[0].arn
  protocol  = "email"
  endpoint  = var.alarm_email
}

resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  for_each = local.instances

  alarm_name          = "${local.name}-${each.key}-cpu-high"
  alarm_description   = "CPU above ${var.cpu_alarm_threshold}% for 10 minutes"
  namespace           = "AWS/EC2"
  metric_name         = "CPUUtilization"
  dimensions          = { InstanceId = each.value }
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 2
  threshold           = var.cpu_alarm_threshold
  comparison_operator = "GreaterThanThreshold"
  alarm_actions       = local.alarm_actions
  ok_actions          = local.alarm_actions
}

resource "aws_cloudwatch_metric_alarm" "status_check" {
  for_each = local.instances

  alarm_name          = "${local.name}-${each.key}-status-check"
  alarm_description   = "EC2 status check failed"
  namespace           = "AWS/EC2"
  metric_name         = "StatusCheckFailed"
  dimensions          = { InstanceId = each.value }
  statistic           = "Maximum"
  period              = 60
  evaluation_periods  = 2
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  alarm_actions       = local.alarm_actions
  ok_actions          = local.alarm_actions
}

resource "aws_cloudwatch_metric_alarm" "disk_low" {
  for_each = local.disk_alarms

  alarm_name          = "${local.name}-${each.key}-disk-low"
  alarm_description   = "Disk ${each.value.path} used above ${var.disk_alarm_threshold}%"
  namespace           = "CWAgent"
  metric_name         = "disk_used_percent"
  dimensions          = { InstanceId = each.value.instance, path = each.value.path, fstype = "ext4" }
  statistic           = "Maximum"
  period              = 300
  evaluation_periods  = 1
  threshold           = var.disk_alarm_threshold
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "missing"
  alarm_actions       = local.alarm_actions
  ok_actions          = local.alarm_actions
}
