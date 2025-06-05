variable "schedules" {
  description = "List of EventBridge Scheduler schedules"
  type = list(object({
    name                  = string
    schedule_expression   = string                 # cron or rate
    flexible_time_window  = optional(bool, false)
    target_type           = string                 # "lambda", "sns", "sqs"
    target_arn            = string
    input                 = optional(string)
    timezone              = optional(string)
    role_arn              = optional(string)       # IAM role for invocation
    state                 = optional(string, "ENABLED")
    group_name            = optional(string, "default")
    
  }))
  default = []
}

locals {
  scheduler_configs = [
    for s in var.schedules : merge(s, {
      Name = replace(s.name, "_", "-")
    })
  ]

  sqs_schedules = [
    for s in local.scheduler_configs : s
    if s.target_type == "sqs"
  ]
}


resource "aws_scheduler_schedule" "this" {
  count = length(local.scheduler_configs)

  name                = local.scheduler_configs[count.index].Name
  group_name          = try(local.scheduler_configs[count.index].group_name, "default")
  schedule_expression = local.scheduler_configs[count.index].schedule_expression

  flexible_time_window {
    mode = try(local.scheduler_configs[count.index].flexible_time_window, false) ? "FLEXIBLE" : "OFF"
  }

  state    = try(local.scheduler_configs[count.index].state, "ENABLED")
#   timezone = try(local.scheduler_configs[count.index].timezone, null)

  target {
    arn      = local.scheduler_configs[count.index].target_arn
    role_arn = try(local.scheduler_configs[count.index].role_arn, null)
    input    = try(local.scheduler_configs[count.index].input, null)
  }
}










resource "aws_iam_role" "sqs_scheduler_role" {
  count = length([for s in local.sqs_schedules : s if try(s.role_arn, null) == null])

  name = "scheduler-sqs-${local.sqs_schedules[count.index].Name}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "scheduler.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy" "sqs_scheduler_policy" {
  count = length(aws_iam_role.sqs_scheduler_role)

  role = aws_iam_role.sqs_scheduler_role[count.index].name

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = "sqs:SendMessage",
        Resource = local.sqs_schedules[count.index].target_arn
      }
    ]
  })
}



output "schedule_names" {
  value = [for s in aws_scheduler_schedule.this : s.name]
}

output "schedule_arns" {
  value = [for s in aws_scheduler_schedule.this : s.arn]
}

output "sqs_role_arns" {
  value = try([for r in aws_iam_role.sqs_scheduler_role : r.arn], [])
}
