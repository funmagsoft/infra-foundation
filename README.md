# Infrastructure Foundation

Networking and foundational infrastructure for the ecare project.

## Purpose

This repository contains Terraform code for:

- Virtual Networks
- Subnets
- Network Security Groups (NSG)
- VPN Gateway (optional)
- Private DNS Zones

## Structure

```
terraform/
├── modules/
│   ├── network/
│   ├── vpn-gateway/
│   └── private-dns/
└── environments/
    ├── dev/
    ├── test/
    ├── stage/
    └── prod/
```

## Getting Started

1. Review `docs/NAMING-CONVENTIONS.md`
2. Review `docs/INFRASTRUCTURE-DESIGN.md`
3. Ensure Phase 0 prerequisites are complete
4. Navigate to environment directory: `cd terraform/environments/dev`
5. Initialize: `terraform init`
6. Plan: `terraform plan`
7. Apply: `terraform apply`

## Dependencies

- Phase 0: Resource Groups and State Storage Accounts must exist
