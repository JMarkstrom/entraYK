<#
.SYNOPSIS
Configures a custom authentication strength in Microsoft Entra ID for YubiKeys.

.DESCRIPTION
This Cmdlet creates a custom authentication strength policy in Microsoft Entra ID. It allows you to add support 
for all FIDO2 passkey-capable YubiKey models or select YubiKey models by their AAGUID(s). 
Non-YubiKey models (AAGUIDs) will be rejected.

NOTE: To ensure account recovery, the authentication strength also includes Temporary Access Pass (TAP) support.

.PARAMETER AAGUID
Specify one or more AAGUIDs to include in the authentication strength. 

.PARAMETER All
Use all supported YubiKey AAGUIDs

.PARAMETER Name
Name of the authentication strength policy

.EXAMPLE
Set-YubiKeyAuthStrength -All
Adds a custom authentication strength using all FIDO2 passkey-capable YubiKey models

.EXAMPLE
Set-YubiKeyAuthStrength -AAGUID "fa2b99dc-9e39-4257-8f92-4a30d23c4118"
Adds a custom authentication strength using only select YubiKey model(s) by their AAGUID(s).

.EXAMPLE
Set-YubiKeyAuthStrength -AAGUID "fa2b99dc-9e39-4257-8f92-4a30d23c4118", "2fc0579f-8113-47ea-b116-bb5a8db9202a"
Adds a custom authentication strength using select YubiKey model(s) by their AAGUID(s).

.EXAMPLE
Set-YubiKeyAuthStrength -AAGUID "a25342c0-3cdc-4414-8e46-f4807fca511c" -Name "YubiKey 5.7"
Adds a custom authentication strength using select YubiKey model(s) by their AAGUID(s) with a custom policy name.

.NOTES
- Ensure that you are connected to the Microsoft Graph API with the appropriate permissions
- Confirm that your YubiKey(s) matches the AAGUID(s) being configured. Misconfiguration may result in account lockouts.
- To ensure account recovery, the authentication strength also includes Temporary Access Pass (TAP) support.


.LINK
https://github.com/JMarkstrom/entraYK

.LINK
https://yubi.co/aaguids
#>

# Powershell and module requirements
#Requires -PSEdition Core
#Requires -Modules Microsoft.Graph.Authentication

# Function with parameters
function Set-YubiKeyAuthStrength {
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
        $All,

        [Parameter(Mandatory = $false,
                  HelpMessage = "Name of the authentication strength policy")]
        [string]
        $Name = "YubiKey"
    )

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
                Connect-MgGraph -Scopes $requiredScopes -NoWelcome #-UseDeviceAuthentication
                
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

    # Get information about YubiKeys from helper function
    $YubiKeyInfo = Get-YubiKeyInfo

    # Determine AAGUIDs to use
    $selectedAAGUIDs = if ($All) { 
        Write-Debug "Using all supported YubiKey AAGUIDs"
        $YubiKeyInfo | Select-Object -ExpandProperty AAGUID | Where-Object { 
            $_ -match '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$' 
        }
    } else { 
        Write-Debug "Using specified AAGUID(s): $($AAGUID -join ', ')"
        $validAAGUIDs = @()
        foreach ($guid in $AAGUID) {
            Write-Debug "Checking GUID: $guid"
            if ($guid -in ($YubiKeyInfo | Select-Object -ExpandProperty AAGUID)) {
                $validAAGUIDs += $guid
            } else {
                Write-Error "'$guid' is not a valid YubiKey AAGUID!"
                return
            }
        }
        $validAAGUIDs
    }

    Write-Debug "Final valid AAGUIDs: $($selectedAAGUIDs -join ', ')"

    # Exit if no AAGUIDs were selected
    if (-not $selectedAAGUIDs) {
        Write-Error "No valid AAGUIDs were provided. Operation cancelled."
        return
    }

    Write-Debug "Final selectedAAGUIDs before API call: $($selectedAAGUIDs | ConvertTo-Json)"

    # Warn the user on pending configuration:
    Clear-Host
    Write-Warning "This will add a custom authentication strength containing YubiKey(s) and single-use TAP:`n"

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

    # Run the call
    $Uri = "https://graph.microsoft.com/v1.0/policies/authenticationStrengthPolicies"
    $Body = @{
        "displayName"           = $Name
        "description"          = "YubiKey as a device-bound passkey"
        "requirementsSatisfied" = "mfa"
        "allowedCombinations"   = @("fido2", "temporaryAccessPassOneTime")
        "combinationConfigurations@odata.context" = "https://graph.microsoft.com/v1.0/$metadata#policies/authenticationStrengthPolicies('2cfa0df2-3dea-481b-b183-dc4dddae201a')/combinationConfigurations"
        "combinationConfigurations" = @(
            @{
                "@odata.type"       = "#microsoft.graph.fido2CombinationConfiguration"
                "id"                = "0a12d2e3-436e-498e-8484-fc8c06c8a846"
                "appliesToCombinations" = @("fido2")
                "allowedAAGUIDs"    = @($selectedAAGUIDs)  # Wrap in @() to ensure array format
            }
        )
    } | ConvertTo-Json -Depth 3 -Compress

    try {
        Invoke-MgGraphRequest -Method POST -Uri $Uri -Body $Body -ContentType "application/json" | Out-Null
        Write-Host "Successfully added custom authentication strength to Entra ID." -ForegroundColor Green
    } catch {
        Write-Host "Unable to add authentication strength (check if definition already exists)!" -ForegroundColor Red
        #Write-Host $_.Exception.Message -ForegroundColor Red
        #Write-Debug $_.Exception.Response.Content
    }
    # Disconnect from Microsoft Graph
    try {
        Write-Debug "Disconnecting from Microsoft Graph..."
        Disconnect-MgGraph | Out-Null  # Suppress output
        Write-Debug "Disconnected from Microsoft Graph"
    } catch {
        Write-Warning "Failed to disconnect from Microsoft Graph: $_"
    }
}