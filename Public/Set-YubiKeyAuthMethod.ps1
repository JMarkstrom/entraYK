<#
.SYNOPSIS
Configures and enables the 'Passkey (FIDO2)' authentication method in Microsoft Entra ID for YubiKey support.

.DESCRIPTION
This Cmdlet configures and enables the 'Passkey (FIDO2)' method in Microsoft Entra ID for YubiKey support.
It enforces attestation with authenticator restrictions set to either whitelist all FIDO2 passkey-capable YubiKey  
models or select YubiKey models by their AAGUID(s). Non-YubiKey models (AAGUIDs) will be rejected.

.PARAMETER AAGUID
Specify one or more AAGUIDs to include in the authentication method.

.PARAMETER All
Use all supported YubiKey AAGUIDs

.EXAMPLE
Set-YubiKeyAuthMethod -All
Configures and enables the 'Passkey (FIDO2)' using all FIDO2 passkey-capable YubiKey models

.EXAMPLE
Set-YubiKeyAuthMethod -AAGUID "fa2b99dc-9e39-4257-8f92-4a30d23c4118"
Configures and enables the 'Passkey (FIDO2)' using using only select YubiKey model(s) by their AAGUID(s).

.EXAMPLE
Set-YubiKeyAuthMethod -AAGUID "fa2b99dc-9e39-4257-8f92-4a30d23c4118", "2fc0579f-8113-47ea-b116-bb5a8db9202a"
Configures and enables the 'Passkey (FIDO2)' using using select YubiKey model(s) by their AAGUID(s).

.NOTES
- Ensure that you are connected to the Microsoft Graph API with the appropriate permissions
- Confirm that your YubiKey(s) matches the AAGUID(s) being configured. Misconfiguration may result in account lockouts.

.LINK
https://github.com/JMarkstrom/entraYK

.LINK
https://yubi.co/aaguids
#>

# Powershell and module requirements
#Requires -PSEdition Core
#Requires -Modules Microsoft.Graph.Authentication

# Function with parameters
function Set-YubiKeyAuthMethod {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true,
                  ParameterSetName = "SpecificAAGUIDs",
                  HelpMessage = "Specify one or more AAGUIDs.")]
        [string[]]
        $AAGUID,

        [Parameter(Mandatory = $true,
                  ParameterSetName = "AllAAGUIDs",
                  HelpMessage = "Use all supported YubiKey AAGUIDs")]
        [switch]
        $All
    )

    # Get information about YubiKeys from helper function
    $YubiKeyInfo = Get-YubiKeyInfo

    # Validate AAGUIDs first before connecting to Graph
    $selectedAAGUIDs = if ($All) { 
        $YubiKeyInfo | Select-Object -ExpandProperty AAGUID
    } else { 
        $validAAGUIDs = @()
        foreach ($guid in $AAGUID) {
            if ($guid -in ($YubiKeyInfo | Select-Object -ExpandProperty AAGUID)) {
                $validAAGUIDs += $guid
            } else {
                Write-Error "'$guid' is not a valid YubiKey AAGUID!"
                return
            }
        }
        Write-Debug "Using specified AAGUID(s): $($validAAGUIDs -join ', ')"
        $validAAGUIDs
    }

    # Exit if no AAGUIDs were selected
    if (-not $selectedAAGUIDs) {
        Write-Error "No valid AAGUIDs were provided. Operation cancelled."
        return
    }

    # Define required scopes
    $requiredScopes = @("Policy.ReadWrite.ConditionalAccess", "Policy.ReadWrite.AuthenticationMethod")

    # Check if already connected with correct permissions
    $context = Get-MgContext
    $needsAuth = $false
    $needsBrowserAuth = $false

    if ($null -eq $context) {
        $needsAuth = $true
        $needsBrowserAuth = $true
    } else {
        # Check if all required scopes are present (case-insensitive comparison)
        $missingScopes = $requiredScopes | Where-Object { $context.Scopes -notcontains $_ }
        if ($missingScopes.Count -gt 0) {
            $needsAuth = $true
            Write-Host "Missing required scopes: $($missingScopes -join ', ')" -ForegroundColor Yellow
        }
    }

    # Handle authentication
    if ($needsAuth) {
        # Show prompt before any authentication attempts
        Clear-Host
        Write-Host "NOTE: Authenticate in the browser to obtain the required permissions (press any key to continue)"
        [System.Console]::ReadKey() > $null
        Clear-Host

        Write-Debug "Attempting to refresh existing token"
        try {
            # First try silent token refresh
            Connect-MgGraph -Scopes $requiredScopes -NoWelcome -ErrorAction Stop
            
            # Verify connection was successful
            $context = Get-MgContext
            if ($null -eq $context) {
                $needsBrowserAuth = $true
            }
        } catch {
            Write-Debug "Silent token refresh failed, will attempt browser authentication"
            $needsBrowserAuth = $true
        }

        if ($needsBrowserAuth) {
            try {
                Connect-MgGraph -Scopes $requiredScopes -NoWelcome -UseDeviceAuthentication
                
                # Verify final connection status
                $context = Get-MgContext
                if ($null -eq $context) {
                    throw "Authentication failed! Please ensure you approve all requested permissions."
                }
            } catch {
                Write-Error "Failed to authenticate: $_"
                throw
            }
        }
    } else {
        Write-Debug "Already authenticated with the required permissions."
    }
    
    # Warn the user on pending configuration:
    Clear-Host
    Write-Warning "This will enable the Passkey (FIDO2) authentication method with YubiKey(s):`n"

    $proceed = $false  # Flag to control continuation
    do {
        $ans = Read-Host "Proceed with configuration? (Y/n)"
        switch ($ans) {
            'y' {
                Write-Debug "Continuing with Entra ID configuration..."
                Clear-Host
                $proceed = $true  # Set flag to exit the loop
                break
            }
            'n' {
                Clear-Host
                Write-Output "Operation cancelled."
                return
            }
            default {
                Write-Output "Invalid input. Please enter 'y' or 'n'."
            }
        }
    } while (-not $proceed)  # Keep looping until $proceed is true


    # Get the FIDO2 authentication method configuration
    $Uri = "https://graph.microsoft.com/beta/authenticationMethodsPolicy/authenticationMethodConfigurations/FIDO2"
    $Body = @{
        "@odata.type"          = "#microsoft.graph.fido2AuthenticationMethodConfiguration"
        "isAttestationEnforced" = $true
        "keyRestrictions"       = @{
            "isEnforced"      = $true
            "enforcementType" = "allow"
            "aaGuids"         = @($selectedAAGUIDs)  # Wrap in @() to ensure array format
        }
        "includeTargets@odata.context" = "https://graph.microsoft.com/beta/$metadata#authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2')/microsoft.graph.fido2AuthenticationMethodConfiguration/includeTargets"
        "includeTargets" = @(
            @{
                "targetType"            = "group"
                "id"                    = "all_users"
                "isRegistrationRequired" = $false
                "allowedPasskeyProfiles" = @()
            }
        )
        "passkeyProfiles" = @()
    } | ConvertTo-Json -Depth 3 -Compress

    try {
        Invoke-MgGraphRequest -Method PATCH -Uri $Uri -Body $Body -ContentType "application/json" | Out-Null
        Write-Host "Successfully configured Passkey (FIDO2) method with YubiKeys in Entra ID." -ForegroundColor Green
        
    } catch {
        Write-Host "Failed to configure authentication method!" -ForegroundColor Red
    }
    # Disconnect from Microsoft Graph
    try {
        Write-Host "Disconnecting from Microsoft Graph..."
        Disconnect-MgGraph
        Write-Debug "Disconnected from Microsoft Graph"
    } catch {
        Write-Debug "Failed to disconnect from Microsoft Graph: $_"
    }
}
