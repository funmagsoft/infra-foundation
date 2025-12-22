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

1. Review infra documentation [README.md](https://github.com/funmagsoft/infra-documentation/blob/main/README.md)

## Dependencies

- Phase 0: Resource Groups and State Storage Accounts must exist
