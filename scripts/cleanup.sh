#!/bin/bash
echo "🗑️  Destroying multi-region infrastructure..."
terraform destroy -auto-approve
echo "✅ Cleanup complete"
