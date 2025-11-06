#!/bin/bash
set -e

echo "🌐 Deploying Multi-Region DR Infrastructure"
echo "============================================"

# Check Terraform
if ! command -v terraform &> /dev/null; then
    echo "❌ Terraform not found"
    exit 1
fi

# Initialize
echo "📦 Initializing Terraform..."
terraform init

# Plan
echo "📋 Planning deployment..."
terraform plan -out=tfplan

# Apply
echo "🚀 Deploying to 3 regions..."
terraform apply tfplan

echo ""
echo "✅ Deployment complete!"
echo "   Regions: us-east-1, us-west-2, eu-west-1"
echo ""
terraform output
