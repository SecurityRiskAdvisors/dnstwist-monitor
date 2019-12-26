provider "aws" {
    region              = "${var.aws_region}"
}

data "aws_caller_identity" "current" {}
locals {
    function_name       = "dnstwist_monitor_${var.client_identifier}"
    account_id          = "${data.aws_caller_identity.current.account_id}"
}

resource "aws_ssm_parameter" "jira_url_param" {
    name              = "/${local.function_name}/jira_url"
    description       = "Jira URL used in Lambda function ${local.function_name}"
    type              = "String"
    value             = "${var.jira_url}"
}

resource "aws_ssm_parameter" "jira_user_param" {
    name              = "/${local.function_name}/jira_username"
    description       = "Jira username used in Lambda function ${local.function_name}"
    type              = "String"
    value             = "${var.jira_username}"
}

resource "aws_ssm_parameter" "jira_pass_param" {
    name              = "/${local.function_name}/jira_pass"
    description       = "Jira API key used in Lambda function ${local.function_name}"
    type              = "SecureString"
    value             = "${var.jira_pass}"
    key_id            = "alias/aws/ssm"
}

resource "random_integer" "cloudwatch_minute" {
  min                   = 19
  max                   = 29
}

resource "aws_cloudwatch_event_rule" "run_dnstwist" {
    name                = "${local.function_name}_scan"
    description         = "Run ${local.function_name} Lambda at specified times (shortly before 7:30 PM ET and 3:30 AM ET daily)"
    schedule_expression = "cron(${random_integer.cloudwatch_minute.result} 23,7 ? * * *)"
    is_enabled          = true
}

resource "aws_cloudwatch_event_target" "run_dnstwist_task" {
        rule            = "${aws_cloudwatch_event_rule.run_dnstwist.name}"
        arn             = "${aws_lambda_function.dnstwist_monitor_function.arn}"
        input           = <<EOF
{
    "OriginalDomain": "${var.client_domain}", 
    "ClientCode":"${var.client_identifier}"
}
EOF
}

resource "aws_dynamodb_table" "history" {
    name                = "${local.function_name}_history"
    billing_mode        = "PROVISIONED"
    read_capacity       = 5
    write_capacity      = 5
    hash_key            = "DomainName"
    range_key           = "OriginalDomain"

    attribute {
        name = "DomainName"
        type = "S"
    }

    attribute {
        name = "OriginalDomain"
        type = "S"
    }

    # attribute {
    #     name = "ClientID"
    #     type = "S"
    # }

    # attribute {
    #     name = "DiscoveredAt"
    #     type = "S"
    # }

    # attribute {
    #     name = "Fuzzer"
    #     type = "S"
    # }

    # attribute {
    #     name = "RawData"
    #     type = "S"
    # }
}

resource "aws_cloudwatch_log_group" "lambda_logs" {
    name                = "/aws/lambda/${local.function_name}"
    retention_in_days   = 14
}

# Generic SSM permissions without function name in parameter name are fallbacks
resource "aws_iam_policy" "lambda_policy_doc" {
    name = "${local.function_name}_lambda_exec_policy"
    path = "/"
    description         = "IAM policy for logging from Lambda"

    policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
        "Effect": "Allow",
        "Action": "logs:CreateLogGroup",
        "Resource": "arn:aws:logs:${var.aws_region}:${local.account_id}:*"
    },
    {
        "Effect": "Allow",
        "Action": [
            "logs:CreateLogStream",
            "logs:PutLogEvents"
        ],
        "Resource": "arn:aws:logs:${var.aws_region}:${local.account_id}:log-group:/aws/lambda/${local.function_name}:*"
    },
    {
        "Effect": "Allow",
        "Action": "ssm:GetParameter",
        "Resource": [
            "arn:aws:ssm:${var.aws_region}:${local.account_id}:parameter/${local.function_name}/jira_url",
            "arn:aws:ssm:${var.aws_region}:${local.account_id}:parameter/${local.function_name}/jira_username",
            "arn:aws:ssm:${var.aws_region}:${local.account_id}:parameter/${local.function_name}/jira_pass",
            "arn:aws:ssm:${var.aws_region}:${local.account_id}:parameter/dnstwist_monitor/jira_url",
            "arn:aws:ssm:${var.aws_region}:${local.account_id}:parameter/dnstwist_monitor/jira_username",
            "arn:aws:ssm:${var.aws_region}:${local.account_id}:parameter/dnstwist_monitor/jira_pass"
        ]
    },
    {
        "Effect": "Allow",
        "Action": [
            "dynamodb:BatchGetItem",
            "dynamodb:BatchWriteItem",
            "dynamodb:PutItem",
            "dynamodb:GetItem",
            "dynamodb:Scan",
            "dynamodb:Query",
            "dynamodb:UpdateItem"
        ],
        "Resource": "arn:aws:dynamodb:${var.aws_region}:${local.account_id}:table/${local.function_name}_history"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "lambda_policy" {
    role                = "${aws_iam_role.lambda_exec.name}"
    policy_arn          = "${aws_iam_policy.lambda_policy_doc.arn}"
}

resource "aws_lambda_function" "dnstwist_monitor_function" {
  function_name         = "${local.function_name}"

  filename              = "../build/deployment_package.zip"
  source_code_hash      = "${filesha256("../build/deployment_package.zip")}"

  handler               = "lambda_function.lambda_handler"
  runtime               = "python3.7"
  timeout               = var.function_timeout

  role                  = "${aws_iam_role.lambda_exec.arn}"
  depends_on            = ["aws_iam_role_policy_attachment.lambda_policy", "aws_cloudwatch_log_group.lambda_logs"]
}
# IAM role which dictates what other AWS services the Lambda function
# may access.
resource "aws_iam_role" "lambda_exec" {
    name                = "${local.function_name}_role"

    assume_role_policy  = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": "sts:AssumeRole",
            "Principal": {
                "Service": "lambda.amazonaws.com"
            },
            "Effect": "Allow",
            "Sid": ""
        }
    ]
}
EOF
}
