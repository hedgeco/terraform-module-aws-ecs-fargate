# Task role assume policy
data "aws_iam_policy_document" "task_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

# Task logging privileges
data "aws_iam_policy_document" "task_permissions" {
  statement {
    effect = "Allow"

    resources = compact([
      "${var.log_group_name != "" ? "" : aws_cloudwatch_log_group.main.0.arn}:*",
      "${var.enable_datadog_agent_debug != false ? aws_cloudwatch_log_group.datadog_logs[0].arn : ""}"
    ])

    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
  }
}

# Task logging privileges & ssm
data "aws_iam_policy_document" "ssm_task_permissions" {
  statement {
    effect    = "Allow"
    resources = ["*"]
    actions = [
      "ssmmessages:CreateControlChannel",
      "ssmmessages:CreateDataChannel",
      "ssmmessages:OpenControlChannel",
      "ssmmessages:OpenDataChannel"
    ]
  }
}

# Task ecr privileges
data "aws_iam_policy_document" "task_execution_permissions" {
  statement {
    effect = "Allow"

    resources = [
      "*",
    ]

    actions = [
      "ecr:GetAuthorizationToken",
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
  }

  statement {
    effect = "Allow"

    resources = [
          "arn:aws:secretsmanager:${data.aws_region.current.id}:${data.aws_caller_identity.current.id}:secret:DATADOG_API_KEY*",
          "arn:aws:secretsmanager:${data.aws_region.current.id}:${data.aws_caller_identity.current.id}:secret:DATADOG_APP_KEY*",
    ]

    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret",
      "secretsmanager:ListSecrets"
    ]
  }
  statement {
    effect = "Allow"

    resources = [
          "arn:aws:ssm:${data.aws_region.current.id}:${data.aws_caller_identity.current.id}:parameter:DATADOG_API_KEY",
          "arn:aws:ssm:${data.aws_region.current.id}:${data.aws_caller_identity.current.id}:parameter:DATADOG_APP_KEY",
    ]

    actions = [
      "ssm:GetParameters"
    ]
  }
  
}

data "aws_kms_key" "secretsmanager_key" {
  key_id = var.repository_credentials_kms_key
}

data "aws_iam_policy_document" "read_repository_credentials" {
  statement {
    effect = "Allow"

    resources = [
      var.repository_credentials,
      data.aws_kms_key.secretsmanager_key.arn,
    ]

    actions = [
      "secretsmanager:GetSecretValue",
      "kms:Decrypt",
    ]
  }
}

data "aws_kms_key" "task_container_secrets_key" {
  key_id = var.task_container_secrets_kms_key
}

data "aws_iam_policy_document" "task_container_secrets" {
  statement {
    effect = "Allow"

    resources = concat(
      [data.aws_kms_key.task_container_secrets_key.arn],
      [for i in var.task_container_secrets : replace(i["valueFrom"], "/:[^:]+::$/", "")]
    )
    actions = [
      "secretsmanager:GetSecretValue",
      "kms:Decrypt",
    ]
  }
}

