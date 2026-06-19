# Session 9 Demo 2 — CloudWatch Dashboard + IaC Coverage

Build a CloudWatch dashboard from Terraform, add an IaC coverage audit document, and write a runbook — then prove the entire stack can be destroyed and rebuilt from CI with zero manual steps.

## What students learn

- How to define a CloudWatch dashboard widget using `jsonencode()` so Terraform expressions (resource ARNs, variable values) are validated at plan time instead of failing at runtime
- Why the `region` field in each dashboard widget must be explicit, and what happens when it is missing
- How to construct a clickable dashboard URL from Terraform outputs so a runbook never has a hardcoded link
- What an IaC coverage audit document (`iac-coverage.md`) is, what it proves, and how to keep it current
- How to write a runbook section in `infra/README.md` that references `terraform output` values instead of hardcoded endpoints
- How to demonstrate one-click deployment by destroying the environment and letting CI rebuild it from zero

## Project structure

```
.
├── app/                          # Flask application (unchanged from Demo 1)
├── load-gen.sh                   # Sends traffic to the ALB to populate dashboard graphs
└── infra/
    ├── main.tf                   # Root module — wires all child modules together
    ├── versions.tf               # Terraform + provider version pins, S3 backend config
    ├── variables.tf              # Root-level input variables
    ├── outputs.tf                # Root-level outputs (alb_dns_name, dashboard_url, etc.)
    ├── envs/dev/
    │   └── dev.tfvars            # Environment-specific values (email, thresholds, image URL)
    ├── docs/
    │   └── iac-coverage.md       # IaC audit table — created during this demo
    ├── modules/
    │   ├── networking/           # VPC, subnets, NAT gateway, IGW, route tables
    │   ├── compute/              # ALB, ECS cluster/service/task, ECR repository
    │   ├── secrets/              # Secrets Manager secret, IAM task role + policy
    │   └── observability/
    │       ├── main.tf           # Log group, SNS, alarms — dashboard added here
    │       ├── variables.tf      # Module inputs — aws_region variable added here
    │       └── outputs.tf        # Module outputs — dashboard_url added here
    └── bootstrap/
        └── main.tf               # One-time S3 state bucket provisioning (already applied)
```

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.10
- [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html) configured with credentials
- [Docker](https://docs.docker.com/get-docker/) (required only if rebuilding the container image)
- Git and a GitHub account (required for the one-click proof step)

## Demo workflow

### 1. Verify the starting state

The `start/` directory contains the complete Demo 1 end state — VPC, ALB, ECS, ECR, IAM, Secrets Manager, CloudWatch log group, three alarms, SNS, and a budget. Confirm the infrastructure is live:

```bash
cd infra
terraform output alb_dns_name
curl http://$(terraform output -raw alb_dns_name)/health
```

Expected output:

```json
{"status": "ok"}
```

### 2. Add `aws_cloudwatch_dashboard` to the observability module

Open `infra/modules/observability/main.tf` and append the following resource at the bottom of the file:

```hcl
resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.environment}-${var.app_name}"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 8
        height = 6
        properties = {
          title   = "Request Count"
          view    = "timeSeries"
          stacked = false
          metrics = [
            ["AWS/ApplicationELB", "RequestCount",
              "LoadBalancer", var.alb_arn_suffix,
              { stat = "Sum", period = 60 }]
          ]
          region = var.aws_region
        }
      },
      {
        type   = "metric"
        x      = 8
        y      = 0
        width  = 8
        height = 6
        properties = {
          title   = "HTTP 5xx Errors"
          view    = "timeSeries"
          stacked = false
          metrics = [
            ["AWS/ApplicationELB", "HTTPCode_Target_5XX_Count",
              "LoadBalancer", var.alb_arn_suffix,
              { stat = "Sum", period = 60, color = "#d62728" }]
          ]
          region = var.aws_region
        }
      },
      {
        type   = "alarm"
        x      = 16
        y      = 0
        width  = 8
        height = 6
        properties = {
          title = "Cost Alert Status"
          alarms = [
            aws_cloudwatch_metric_alarm.estimated_charges.arn
          ]
        }
      }
    ]
  })
}
```

### 3. Add the `aws_region` variable to the observability module

Open `infra/modules/observability/variables.tf` and add:

```hcl
variable "aws_region" {
  description = "AWS region where the observability resources are created. Used in the CloudWatch dashboard widget region field."
  type        = string
}
```

Then open `infra/main.tf` and pass the variable to the observability module call:

```hcl
module "observability" {
  # ... existing arguments ...
  aws_region = var.aws_region
}
```

### 4. Add a `dashboard_url` output

Open `infra/modules/observability/outputs.tf` and add:

```hcl
output "dashboard_url" {
  description = "Direct URL to the CloudWatch dashboard"
  value       = "https://${var.aws_region}.console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#dashboards:name=${aws_cloudwatch_dashboard.main.dashboard_name}"
}
```

### 5. Create `infra/docs/iac-coverage.md`

Create the file `infra/docs/iac-coverage.md`:

```markdown
# IaC Coverage Audit

| Application Component | Cloud Service Used | Terraform Resource Type | Module Path |
|---|---|---|---|
| Virtual network | Amazon VPC | `aws_vpc`, `aws_subnet` | `modules/networking` |
| Load balancer | Application Load Balancer | `aws_lb`, `aws_lb_listener`, `aws_lb_target_group` | `modules/compute` |
| Container runtime | Amazon ECS Fargate | `aws_ecs_cluster`, `aws_ecs_task_definition`, `aws_ecs_service` | `modules/compute` |
| Container registry | Amazon ECR | `aws_ecr_repository` | `modules/compute` |
| App secrets | AWS Secrets Manager | `aws_secretsmanager_secret` | `modules/secrets` |
| Task identity | AWS IAM | `aws_iam_role`, `aws_iam_role_policy` | `modules/secrets` |
| Application logs | Amazon CloudWatch Logs | `aws_cloudwatch_log_group` | `modules/observability` |
| Service alarms | Amazon CloudWatch Alarms | `aws_cloudwatch_metric_alarm` | `modules/observability` |
| Alert notifications | Amazon SNS | `aws_sns_topic`, `aws_sns_topic_subscription` | `modules/observability` |
| Cost alert | Amazon CloudWatch Alarms (Billing) | `aws_cloudwatch_metric_alarm` | `modules/observability` |
| Budget ceiling | AWS Budgets | `aws_budgets_budget` | `modules/observability` |
| Operations dashboard | Amazon CloudWatch Dashboards | `aws_cloudwatch_dashboard` | `modules/observability` |

## Notes

- All resources are provisioned by Terraform and tracked in state. No manual console changes.
- CI/CD pipeline (`terraform-ci.yml`) runs `fmt`, `validate`, and `plan` on every PR.
- Destroy + reapply verified on YYYY-MM-DD — see commit `<hash>` for the CI run.
```

### 6. Add a `## Runbook` section to `infra/README.md`

Open `infra/README.md` and append the following section:

```markdown
## Runbook

### Deploy from zero

1. **Provision infrastructure**
   ```bash
   terraform init
   terraform apply -var-file="envs/dev/dev.tfvars"
   ```
   Confirm the SNS subscription email before continuing.

2. **Build and push Docker image**
   ```bash
   aws ecr get-login-password | docker login --username AWS --password-stdin <ecr-url>
   docker build -t <ecr-url>/<repo>:latest ./app
   docker push <ecr-url>/<repo>:latest
   ```

3. **Verify health**
   ```bash
   curl http://$(terraform output -raw alb_dns_name)/health
   # Expected: {"status": "ok"}
   ```

4. **Monitor**
   - Dashboard: `terraform output -raw dashboard_url`
   - Alarms: AWS Console → CloudWatch → Alarms
   - Logs: AWS Console → CloudWatch → Log groups → `/app/dev/<app_name>`
```

### 7. Apply the changes

```bash
terraform plan -var-file="envs/dev/dev.tfvars"
terraform apply -var-file="envs/dev/dev.tfvars"
```

After apply, open the dashboard in your browser:

```bash
terraform output -raw dashboard_url
```

Expected output:

```
https://us-west-2.console.aws.amazon.com/cloudwatch/home?region=us-west-2#dashboards:name=dev-session9-demo2
```

The dashboard shows three widgets: **Request Count**, **HTTP 5xx Errors**, and **Cost Alert Status**.

### 8. One-click deployment proof

Destroy the environment, then let CI rebuild it from zero to prove no manual steps are required:

```bash
terraform destroy -var-file="envs/dev/dev.tfvars"
```

Push your changes to GitHub. The CI workflow (`terraform-ci.yml`) runs `plan` and `apply` automatically. After the run completes, verify:

- All resources are recreated
- `curl http://$(terraform output -raw alb_dns_name)/health` returns `{"status": "ok"}`
- The dashboard URL is accessible and shows populated widgets

Record the GitHub Actions run URL and commit hash — these are your D5-F and D5-I evidence. Update the `Notes` section of `iac-coverage.md` with the date and commit hash.

### 9. Clean up

```bash
terraform destroy -var-file="envs/dev/dev.tfvars"
```

## Expected outcomes

By the end of this demo, students should be able to:

1. Write a `aws_cloudwatch_dashboard` resource using `jsonencode()` so Terraform expressions are embedded directly in the widget JSON and validated at plan time
2. Explain why each CloudWatch dashboard widget requires an explicit `region` field and what the silent failure looks like when it is missing
3. Construct a dashboard URL output from `var.aws_region` and a resource attribute so the link stays correct across environment changes
4. Produce an `iac-coverage.md` table that maps every application component to its Terraform resource type and module path
5. Write a runbook that references `terraform output` values instead of hardcoded endpoints
6. Demonstrate one-click deployment by running `terraform destroy`, pushing to GitHub, and verifying CI rebuilds the environment from zero
