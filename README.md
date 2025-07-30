# SQLEncrypt

Automate SSL/TLS certificate issuance and binding for SQL Server instances using dbatools.

---

## Table of Contents

- [Overview](#overview)  
- [Features](#features)  
- [Prerequisites](#prerequisites)  
- [Installation](#installation)  
- [Configuration](#configuration)  
- [Usage](#usage)  
- [Logging](#logging)  
- [Troubleshooting](#troubleshooting)  
- [Contributing](#contributing)  
- [License](#license)  

---

## Overview

**SQLEncrypt** streamlines the process of enrolling, renewing, and binding SSL/TLS certificates to your SQL Server instances. It leverages the [dbatools](https://dbatools.io) PowerShell module (and its `dbatools.library` dependency) to:

- Verify certificate templates on your CA  
- Enroll new certificates with your chosen template, DNS names, and cryptographic settings  
- Bind certificates to SQL Server via registry and ACL updates  
- Enable forced encryption on the SQL Server endpoint  
- Restart the SQL Server service as needed  

---

## Features

- **Certificate template validation** on the specified CA  
- **Automated enrollment** of new certificates with custom key length and hash algorithm  
- **Automatic renewal** when certificates are within a configurable expiry threshold  
- **Binding** of certificates to SQL Server and optional forced encryption  
- **Detailed logging** of every step for auditing and troubleshooting  

---

## Prerequisites

- **PowerShell 5.1** or later  
- **Windows Server** or client with:
  - Access to your Certificate Authority  
  - Permissions to manage certificates in the LocalMachine store  
  - Permissions to restart the SQL Server service  
- [**dbatools**](https://dbatools.io) PowerShell module  
- [**dbatools.library**](https://dbatools.io) (dependency of dbatools)

---

## Installation

1. **Clone** or **download** this repository:  
   ```powershell
   git clone https://github.com/YourOrg/SQLEncrypt.git
   cd SQLEncrypt
   ```
2. ***Install*** the required modules (if not already installed):
   ```powershell
   Install-Module dbatools -Scope AllUsers -Force
   Install-Module dbatools.library -Scope AllUsers -Force
   ```

 ## Configuration

> ⚠️ **Edit these variables before running the script.**

```powershell
# Parent folder containing dbatools modules (dbatools + dbatools.library)
$DbaToolsModuleFolder = '\\fileserver\PSScripts\Modules'

# Target SQL Server instance (default or named)
$SqlInstance         = 'localhost'

# Certificate Authority to enroll from
$CaServer            = 'CA01'
$CaName              = 'Contoso-EnterpriseCA'

# Certificate template (must be enabled on that CA)
$Template            = 'WebServer'

# DNS name(s) for the certificate
$DnsName             = 'sql01.contoso.com'

# Friendly Name for the certificate (defaults to HOSTNAME_SSL)
$FriendlyName        = "$($env:COMPUTERNAME)_SSL"

# Cryptographic settings to satisfy template policy
$KeyLength           = 2048           # e.g. 2048, 4096
$HashAlgorithm       = 'Sha256'       # e.g. Sha256, Sha384, Sha512

# Renewal threshold (days before expiry)
$RenewThresholdDays  = 30

# Whether to force-encrypt all connections
$ForceEncryption     = $true

# Path for logging (ensure folder exists)
$LogFile             = 'C:\temp\Automate-SQLTLS.log'

```

## Usage

Run the main script in an elevated PowerShell session:

```powershell
.\Automate-SQLTLS.ps1
```
The script will:

- Check that your specified template is available on the CA.
- Import the dbatools modules from $DbaToolsModuleFolder.
- Inspect the currently bound certificate (if any) and calculate days until expiry.
- If within the renewal threshold, enroll a new certificate and bind it.
- (Optional) Enable forced encryption on the SQL Server endpoint.
- Restart the SQL Server service to apply changes.

#Logging
All operations and errors are logged to the file specified in $LogFile. Each entry follows this format:
```ruby
YYYY-MM-DD HH:mm:ss [LEVEL] Message
```
Levels: INFO, WARN, ERROR

## Troubleshooting

- **“Module folder not found”**  
  Verify that `$DbaToolsModuleFolder` points to the correct network path where both `dbatools` and `dbatools.library` are installed.

- **“Template not found”**  
  Ensure that your CA has the specified template enabled and that you have permissions to enroll certificates from it.

- **Permission or ACL issues**  
  Run PowerShell as an administrator and make sure the machine account (or user) has appropriate privileges on the CA and in the certificate store.

---

## Contributing

1. Fork the repository  
2. Create a feature branch (`git checkout -b feature/my-feature`)  
3. Commit your changes (`git commit -m 'Add feature'`)  
4. Push to the branch (`git push origin feature/my-feature`)  
5. Open a Pull Request  

Please adhere to the existing code style and include meaningful commit messages.

---

## License

This project is licensed under the **MIT License**. See the [LICENSE](LICENSE) file for details.















   
