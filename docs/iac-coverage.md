# IaC Coverage Audit

| Application Component | Cloud Service Used | Terraform Resource Type | Module Path |
|---|---|---|---|
| Virtual network | Amazon VPC | `aws_vpc`, `aws_subnet` | `modules/networking` |
| Load balancer | Application Load Balancer | `aws_lb`, `aws_lb_listener`, `aws_lb_target_group` | `modules/compute` |
| Container runtime | Amazon ECS Fargate | `aws_ecs_cluster`, `aws_ecs_task_definition`, `aws_ecs_service` | `modules/compute` |
| Container registry | Amazon ECR | `aws_ecr_repository` | `modules/compute` |
| App secrets | AWS Secrets Manager | `aws_secretsmanager_secret`, `aws_secretsmanager_secret_version` | `modules/secrets` |
| Task identity | AWS IAM | `aws_iam_role`, `aws_iam_role_policy` | `modules/secrets` |
| Application logs | Amazon CloudWatch Logs | `aws_cloudwatch_log_group` | `modules/observability` |
| Service alarms | Amazon CloudWatch Alarms | `aws_cloudwatch_metric_alarm` | `modules/observability` |
| Alert notifications | Amazon SNS | `aws_sns_topic`, `aws_sns_topic_subscription` | `modules/observability` |
| Cost alert | Amazon CloudWatch Alarms (Billing) | `aws_cloudwatch_metric_alarm` | `modules/observability` |
| Budget ceiling | AWS Budgets | `aws_budgets_budget` | `modules/observability` |
| Operations dashboard | Amazon CloudWatch Dashboards | `aws_cloudwatch_dashboard` | `modules/observability` |

## Notes

- All resources are provisioned by Terraform and tracked in remote state (S3 backend).
- No manual console changes. If a resource is not in this table, it is a compliance gap.
- CI/CD pipeline (`.github/workflows/terraform-ci.yml`) runs `fmt`, `validate`, and `plan` on every PR.
- Destroy + reapply verified on `YYYY-MM-DD` — replace with the date of your one-click proof run and the CI run URL.
