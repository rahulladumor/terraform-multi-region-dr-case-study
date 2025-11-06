# 🚀 Quick Start - Multi-Region DR

## Prerequisites
- Terraform 1.6+
- AWS CLI configured
- Access to 3 AWS regions

## Deploy (30-40 minutes)

```bash
# Initialize
terraform init

# Plan
terraform plan -out=tfplan

# Apply to all 3 regions
terraform apply tfplan
```

## Verify

```bash
# Check Aurora Global Database
aws rds describe-global-clusters

# Check Route53 health checks
aws route53 list-health-checks

# Test endpoint
curl $(terraform output cloudfront_url)
```

## Test Failover

```bash
./scripts/test-failover.sh us-east-1
```

## Cleanup

```bash
terraform destroy
```

**Cost**: ~$1,400/month (3 regions)
**RTO**: < 5 minutes
**RPO**: < 1 minute

See [README](README.md) for details.
