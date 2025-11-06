output "primary_vpc_id" {
  description = "Primary region VPC ID"
  value       = module.vpc_primary.vpc_id
}

output "aurora_primary_endpoint" {
  description = "Aurora primary cluster endpoint"
  value       = module.aurora_global.primary_endpoint
  sensitive   = true
}

output "route53_domain" {
  description = "Route 53 domain name"
  value       = module.route53_failover.domain_name
}

output "alb_dns_names" {
  description = "Load balancer DNS names"
  value = {
    primary   = module.alb_primary.dns_name
    secondary = module.alb_secondary.dns_name
    dr        = module.alb_dr.dns_name
  }
}
