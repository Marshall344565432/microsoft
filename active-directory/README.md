# Active Directory Management

Active Directory administration, maintenance, and automation scripts.

## Structure

```
active-directory/
├── scripts/        # AD administration automation
├── health-checks/  # AD health monitoring and diagnostics
└── maintenance/    # AD cleanup and maintenance tasks
```

## Focus Areas

### AD Health Checks
- Replication monitoring and troubleshooting
- Domain controller health validation
- DNS and DHCP integration checks
- FSMO role validation
- AD database integrity checks

### User & Group Management
- Bulk user creation/modification
- Group membership automation
- Stale account cleanup
- Password policy management
- Account lockout troubleshooting

### Maintenance Tasks
- Tombstone cleanup
- Inactive computer cleanup
- AD database optimization
- Backup and recovery automation
- Site and subnet management

### Security & Compliance
- Privileged account auditing
- GPO security auditing
- AD ACL management
- Kerberos troubleshooting
- Certificate auto-enrollment

## Requirements

- PowerShell 5.1+
- Active Directory module
- Administrator privileges
- Windows Server 2022
- Domain Admin rights (for some operations)

## Best Practices

- Test AD scripts in lab environment
- Always backup AD before major changes
- Monitor replication health daily
- Document all AD modifications
- Use least privilege for automation accounts
- Implement change control process
