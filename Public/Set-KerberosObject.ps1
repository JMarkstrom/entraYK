<#
.SYNOPSIS
Creates and configures an Azure AD Kerberos Server object for hybrid identity authentication.

.DESCRIPTION
Creates and publishes a new Azure AD Kerberos Server object in Active Directory and Azure AD.
Enables seamless single sign-on between on-premises Active Directory and Azure AD (Entra ID).

.PARAMETER Domain
The fully qualified domain name (FQDN) of your on-premises Active Directory domain.

.PARAMETER CloudCredential
The Azure AD Global Administrator credentials.

.PARAMETER DomainCredential
The Domain Administrator credentials for the on-premises Active Directory.

.EXAMPLE
Set-KerberosObject -Domain "contoso.corp.com"
# Script will prompt for credentials if not provided

.EXAMPLE
$cloudCred = Get-Credential
$domainCred = Get-Credential
Set-KerberosObject -Domain "contoso.corp.com" -CloudCredential $cloudCred -DomainCredential $domainCred

.NOTES
Requires:
- AzureADKerberos module
- Azure AD Connect
- Global Administrator rights in Entra ID
- Domain Administrator rights in on-premises AD
- PowerShell must be run as Administrator

.LINK
https://github.com/JMarkstrom/entraYK

.LINK
https://rb.gy/x9sz
#>

#Requires -Modules AzureADKerberos
#Requires -RunAsAdministrator

function Set-KerberosObject {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidatePattern('^[a-zA-Z0-9]+(\.[a-zA-Z0-9]+)*\.[a-zA-Z]{2,}$')]
        [string]$Domain,

        [Parameter(Mandatory = $true)]
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()]
        $CloudCredential,

        [Parameter(Mandatory = $true)]
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()]
        $DomainCredential
    )

    begin {
        # Display preview warning and get confirmation
        Write-Warning "This cmdlet is currently in PREVIEW and should not be used in production environments."
        $confirmation = Read-Host "Do you want to continue? (Y/N)"
        if ($confirmation -ne 'Y') {
            Write-Host "Operation aborted by user."
            return
        }

        # Verify module is available
        $moduleDir = "C:\Program Files\Microsoft Azure Active Directory Connect\AzureADKerberos"
        if (-not (Test-Path "$moduleDir\AzureAdKerberos.psd1")) {
            throw "AzureAdKerberos module not found in $moduleDir"
        }

        # Import the module
        Import-Module "$moduleDir\AzureAdKerberos.psd1"
    }

    process {
        try {
            # Create the new Azure AD Kerberos Server object
            Set-AzureADKerberosServer -Domain $Domain -CloudCredential $CloudCredential -DomainCredential $DomainCredential

            # Verify the creation
            $kerberosServer = Get-AzureADKerberosServer -Domain $Domain -CloudCredential $CloudCredential -DomainCredential $DomainCredential
            
            if ($kerberosServer) {
                Write-Verbose "Azure AD Kerberos Server object was created successfully."
                $kerberosServer # Output the server object
            } else {
                throw "Failed to create Azure AD Kerberos Server object."
            }
        }
        catch {
            throw "Error configuring Kerberos Server object: $_"
        }
    }
}
