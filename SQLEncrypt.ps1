
# Configuration — EDIT THESE BEFORE RUNNING

# Parent folder containing dbatools modules (dbatools + dbatools.library)
$DbaToolsModuleFolder = '\\fileserver\PSScripts\Modules'

# Target SQL Server instance (default or named)
$SqlInstance         = 'localhost'

# Certificate Authority to enroll from
$CaServer            = 'CA01'
$CaName              = 'Contoso-EnterpriseCA'

# Certificate template (must be enabled on that CA)
$Template            = 'WebServer'

# DNS name(s) for the certificate (FQDN + any additional SANs)
# Provide as an array, e.g.
# @('sql01.contoso.com','sql01','alias.contoso.local')
$DnsNames            = @('sql01.contoso.com')

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
$LogFile             = 'C:\Temp\Automate-SQLTLS.log'
#=============================================

function Write-Log {
    param(
        [string] $Message,
        [ValidateSet('INFO','WARN','ERROR')]
        [string] $Level = 'INFO'
    )
    "$((Get-Date).ToString('yyyy-MM-dd HH:mm:ss')) [$Level] $Message" |
      Tee-Object -FilePath $LogFile -Append
}

try {
    Write-Log "=== Starting SSL Automation for $SqlInstance ==="

    #
    # 1) Verify template on CA
    #
    Write-Log "Checking templates on $CaServer\$CaName"
    $raw = & certutil -config "$CaServer\$CaName" -CATemplates 2>&1
    $found = $raw -split "`r?`n" | Where-Object { $_ -match "^\s*$([regex]::Escape($Template))\s*:" }
    if (-not $found) {
        Write-Log "Template '$Template' not available on $CaServer\$CaName" 'ERROR'
        throw "Template not found."
    }
    Write-Log "Template '$Template' confirmed on $CaServer\$CaName."

    #
    # 2) Import dbatools (and its library)
    #
    if (-not (Test-Path $DbaToolsModuleFolder)) {
        throw "Module folder not found: $DbaToolsModuleFolder"
    }
    $env:PSModulePath = "$DbaToolsModuleFolder;$env:PSModulePath"
    Import-Module dbatools -Force -ErrorAction Stop
    Write-Log "Imported dbatools modules."

    #
    # 3) Check current SQL-bound cert
    #
    $current = Get-DbaNetworkCertificate -SqlInstance $SqlInstance -ErrorAction SilentlyContinue
    if ($current) {
        $thumb = $current.Thumbprint
        Write-Log "Current bound thumbprint: $thumb"

        $cert = Get-ChildItem Cert:\LocalMachine\My |
                Where-Object Thumbprint -EQ $thumb

        if ($cert) {
            $daysLeft = ($cert.NotAfter - (Get-Date)).Days
        }
        else {
            Write-Log "WARNING: Bound certificate not found in store" 'WARN'
            $daysLeft = 0
        }

        Write-Log "Certificate expires in $daysLeft days"
    }
    else {
        Write-Log "No certificate currently bound."
        $daysLeft = 0
    }

    #
    # 4) Renew & bind if needed
    #
    if ($daysLeft -le $RenewThresholdDays) {
        Write-Log "Within threshold ($RenewThresholdDays days); renewing..."

        # 4a) Enroll new cert with FriendlyName, key size, hash, and SANs
        Write-Log "Requesting new cert from $CaServer\$CaName"
        Write-Log "  Template    : $Template"
        Write-Log "  DNS names   : $($DnsNames -join ', ')"
        Write-Log "  FriendlyName: $FriendlyName"
        Write-Log "  KeyLength   : $KeyLength"
        Write-Log "  HashAlg     : $HashAlgorithm"

        $newCert = New-DbaComputerCertificate `
            -CaServer            $CaServer `
            -CaName              $CaName `
            -CertificateTemplate $Template `
            -Dns                 $DnsNames `
            -FriendlyName        $FriendlyName `
            -KeyLength           $KeyLength `
            -HashAlgorithm       $HashAlgorithm `
            -ErrorAction Stop

        Write-Log "Enrolled cert: $($newCert.Thumbprint)"

        # 4b) Bind to SQL (registry + ACLs)
        Write-Log "Binding new cert to $SqlInstance"
        Set-DbaNetworkCertificate `
            -SqlInstance   $SqlInstance `
            -Thumbprint    $newCert.Thumbprint `
            -RestartService:$false `
            -EnableException `
            -ErrorAction Stop
        Write-Log "Certificate bound successfully"

        # 4c) Enable forced encryption if configured
        if ($ForceEncryption) {
            Write-Log "Enabling Force Encryption"
            Enable-DbaForceNetworkEncryption -SqlInstance $SqlInstance -ErrorAction Stop
            Write-Log "Force Encryption enabled."
        }

        # 4d) Restart SQL Server service
        $svc = if ($SqlInstance -like '*\*') {
            'MSSQL$' + ($SqlInstance.Split('\')[1])
        } else { 'MSSQLSERVER' }
        Write-Log "Restarting service $svc"
        Restart-Service -Name $svc -Force -ErrorAction Stop
        Write-Log "Service restarted."

        Write-Log "=== Renewal & binding complete ==="
    }
    else {
        Write-Log "No action: $daysLeft days remain (> $RenewThresholdDays)."
    }

} catch {
    Write-Log "ERROR: $_" 'ERROR'
    throw
}
