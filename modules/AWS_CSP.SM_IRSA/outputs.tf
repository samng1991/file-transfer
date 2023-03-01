output "role_arn" {
  description = "The Amazon Resource Name (ARN) of the role"
  value       = try(aws_iam_role.this.arn, null) 
}