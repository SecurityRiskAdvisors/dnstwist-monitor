# Terraform Configuration

Prior to applying the Terraform configuration, copy `terraform.tfvars.example` to `terraform.tfvars` and fill in the values to match your configuration. 

Notice: if you receive an error similar to the one below, you may need to manually [create the Systems Manager parameters in the AWS Console](https://console.aws.amazon.com/systems-manager/parameters/create).

```
Error: error creating SSM parameter: AccessDeniedException: User: arn:aws:iam::[REDACTED]:user/[REDACTED] is not authorized to perform: ssm:PutParameter on resource: arn:aws:ssm:[REDACTED]:[REDACTED]:parameter/dnstwist_monitor_ABC0/jira_url with an explicit deny
        status code: 400, request id: [REDACTED]
```

Parameters for manual creation (replace ABC0 with the appropriate client code):

[1]
```text
Name: /dnstwist_monitor_ABC0/jira_url
Type: String
Value: https://url-to-your-jira-instance.atlassian.net
```

[2]
```text
Name: /dnstwist_monitor_ABC0/jira_username
Type: String
Value: your-jira-user-email@example.com
```

[3]
```text
Name: /dnstwist_monitor_ABC0/jira_pass
Type: String
Value: YOURJIRAAPITOKEN
```

Retrieve Jira API token from https://id.atlassian.com/manage/api-tokens