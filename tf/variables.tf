variable "aws_region" {
    description = "The AWS region in which to create resources"
    type        = string
    default     = "us-east-1"
}

variable "client_identifier" {
    description = "A unique identifier for the client. Example: ABC0"
    type        = string
}

variable "client_domain" {
    description = "The domain name to be scanned"
    type        = string
}

variable "function_timeout" {
    description = "Lambda function timeout length, in seconds"
    type        = number
    default     = 900
}

variable "jira_url" {
    description = "URL to Jira instance"
    type        = string
}

variable "jira_username" {
    description = "Username for Jira instance"
    type        = string
}

variable "jira_pass" {
    description = "API key for Jira instance matching jira_username"
    type        = string
}