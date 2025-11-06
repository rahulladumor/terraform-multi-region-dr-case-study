#!/bin/bash
echo "🔍 Validating Terraform configuration..."
terraform fmt -check
terraform validate
echo "✅ Validation complete"
