resource "aws_sqs_queue" "my_queue" {
  name = "my-scheduler-queue"
}

module "eventbridge_schedules" {
  source = "../modules/schedule"

  schedules = [
    {
      name                = "sqs-schedule-job"
      schedule_expression = "rate(1 hour)"
      target_type         = "sqs"
      target_arn          = aws_sqs_queue.my_queue.arn
      input = jsonencode({
        MessageBody = "Hello from Scheduler!"
        QueueUrl    = aws_sqs_queue.my_queue.url
      })
    }
  ]
}
