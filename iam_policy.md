# IAM Policy for Deployment

The policy provided below is intended to provide the least privilage required to deploy dnstwist-monitor to AWS.  

## Policy v1.0.1
```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "VisualEditor0",
            "Effect": "Allow",
            "Action": [
                "logs:ListTagsLogGroup",
                "lambda:CreateFunction",
                "iam:GetPolicyVersion",
                "events:EnableRule",
                "lambda:ListVersionsByFunction",
                "events:PutRule",
                "iam:DeletePolicy",
                "iam:CreateRole",
                "iam:AttachRolePolicy",
                "iam:ListInstanceProfilesForRole",
                "iam:PassRole",
                "iam:DetachRolePolicy",
                "ssm:DescribeParameters",
                "iam:ListAttachedRolePolicies",
                "ec2:DescribeAccountAttributes",
                "lambda:DeleteFunction",
                "events:RemoveTargets",
                "events:ListTargetsByRule",
                "iam:GetRole",
                "events:DescribeRule",
                "iam:GetPolicy",
                "logs:DescribeLogGroups",
                "logs:DeleteLogGroup",
                "lambda:GetFunction",
                "iam:DeleteRole",
                "logs:CreateLogGroup",
                "iam:CreatePolicy",
                "lambda:UpdateFunctionCode",
                "events:DeleteRule",
                "events:PutTargets",
                "iam:ListPolicyVersions",
                "events:ListTagsForResource",
                "logs:PutRetentionPolicy"
            ],
            "Resource": "*"
        },
        {
            "Sid": "VisualEditor1",
            "Effect": "Allow",
            "Action": [
                "dynamodb:CreateTable",
                "ssm:PutParameter",
                "ssm:DeleteParameter",
                "dynamodb:TagResource",
                "dynamodb:DescribeTable",
                "ssm:ListTagsForResource",
                "dynamodb:DescribeContinuousBackups",
                "dynamodb:ListTagsOfResource",
                "ssm:GetParameters",
                "dynamodb:DescribeTimeToLive",
                "dynamodb:DeleteTable",
                "ssm:GetParameter"
            ],
            "Resource": [
                "arn:aws:dynamodb:*:*:table/dnstwist*",
                "arn:aws:ssm:*:*:document/*",
                "arn:aws:ssm:*:*:patchbaseline/*",
                "arn:aws:ssm:*:*:maintenancewindow/*",
                "arn:aws:ssm:*:*:managed-instance/*",
                "arn:aws:ssm:*:*:parameter/dnstwist*"
            ]
        }
    ]
}
```
