<#
.SYNOPSIS
Configures and enables the 'Passkey (FIDO2)' authentication method in Microsoft Entra ID for YubiKey support.

.DESCRIPTION
This Cmdlet configures and enables the 'Passkey (FIDO2)' method in Microsoft Entra ID for YubiKey support.
It updates the tenant's Default passkey profile in place: device-bound passkeys only, attestation enforced
at registration, and an allow list of either all FIDO2 passkey-capable YubiKey models or select models by
their AAGUID(s). Self-service registration is enabled. Non-YubiKey models (AAGUIDs) will be rejected.
The tenant must already have opted in to passkey profiles.

.PARAMETER AAGUID
Specify one or more AAGUIDs to include in the authentication method.

.PARAMETER All
Use all supported YubiKey AAGUIDs

.EXAMPLE
Set-YubiKeyAuthMethod -All
Updates the Default passkey profile to allow all FIDO2 passkey-capable YubiKey models

.EXAMPLE
Set-YubiKeyAuthMethod -AAGUID "fa2b99dc-9e39-4257-8f92-4a30d23c4118"
Updates the Default passkey profile to allow only select YubiKey model(s) by their AAGUID(s).

.EXAMPLE
Set-YubiKeyAuthMethod -AAGUID "fa2b99dc-9e39-4257-8f92-4a30d23c4118", "2fc0579f-8113-47ea-b116-bb5a8db9202a"
Updates the Default passkey profile to allow select YubiKey model(s) by their AAGUID(s).

.NOTES
- Ensure that you are connected to the Microsoft Graph API with the appropriate permissions
- Confirm that your YubiKey(s) matches the AAGUID(s) being configured. Misconfiguration may result in account lockouts.

.LINK
https://github.com/JMarkstrom/entraYK

.LINK
https://yubi.co/aaguids
#>


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

    begin {

        # Call the function to check and install the required module(s)
        Resolve-ModuleDependencies -ModuleName "Microsoft.Graph.Authentication"

        # Define required scopes
        $requiredScopes = @("Policy.ReadWrite.ConditionalAccess", "Policy.ReadWrite.AuthenticationMethod")

    }

    process {
        # Get information about YubiKeys from helper function
        $YubiKeyInfo = Get-YubiKeyInfo

        # Validate AAGUIDs first before connecting to Graph
        $selectedAAGUIDs = if ($All) { 
            $YubiKeyInfo | Select-Object -ExpandProperty AAGUID -Unique
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
            Write-Host "NOTE: Authenticate in the browser to obtain the required permissions (press any key to continue)" -ForegroundColor Yellow
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
                    Connect-MgGraph -Scopes $requiredScopes -NoWelcome
                    
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
        Write-Warning @"
This will update the Default passkey profile for all users assigned to it:
- Allow only device-bound passkeys
- Enforce attestation at registration
- Restrict AAGUIDs to the selected YubiKeys
- Turn on self-service registration

"@

        $proceed = $false
        do {
            $ans = Read-Host "Proceed? (Y/n)"
            switch ($ans.ToLower()) {
                {$_ -eq 'y' -or $_ -eq ''} {
                    Write-Debug "Continuing with Entra ID configuration..."
                    $proceed = $true
                    break
                }
                'n' {
                    Clear-Host
                    Write-Host "Operation cancelled by user." -ForegroundColor Red
                    return
                }
                default {
                    Write-Output "Invalid input. Please enter 'y' or 'n'."
                }
            }
        } while (-not $proceed)


        $Uri = "https://graph.microsoft.com/v1.0/policies/authenticationMethodsPolicy/authenticationMethodConfigurations/fido2"

        try {
            $policy = Invoke-MgGraphRequest -Method GET -Uri $Uri -ErrorAction Stop

            $defaultProfileId = [string]$policy.defaultPasskeyProfile
            $existingProfiles = @($policy.passkeyProfiles | Where-Object { $_ })
            $defaultProfile = $existingProfiles | Where-Object { [string]$_.id -eq $defaultProfileId } | Select-Object -First 1

            if ([string]::IsNullOrWhiteSpace($defaultProfileId) -or -not $defaultProfile) {
                throw "Passkey profiles are not enabled. Opt in to passkey profiles in the Microsoft Entra admin center, then run this command again."
            }

            $passkeyProfiles = @()
            foreach ($profile in $existingProfiles) {
                $profileId = [string]$profile.id
                if ($profileId -eq $defaultProfileId) {
                    $passkeyProfiles += @{
                        id                     = $profileId
                        name                   = [string]$profile.name
                        passkeyTypes           = "deviceBound"
                        attestationEnforcement = "registrationOnly"
                        keyRestrictions        = @{
                            isEnforced      = $true
                            enforcementType = "allow"
                            aaGuids         = @($selectedAAGUIDs)
                        }
                    }
                } else {
                    $restrictions = $profile.keyRestrictions
                    $otherAaGuids = @()
                    $isEnforced = $false
                    $enforcementType = "allow"
                    if ($restrictions) {
                        $isEnforced = [bool]$restrictions.isEnforced
                        if ($restrictions.enforcementType) {
                            $enforcementType = [string]$restrictions.enforcementType
                        }
                        if ($restrictions.aaGuids) {
                            $otherAaGuids = @($restrictions.aaGuids | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) })
                        }
                    }
                    $passkeyProfiles += @{
                        id                     = $profileId
                        name                   = [string]$profile.name
                        passkeyTypes           = $profile.passkeyTypes
                        attestationEnforcement = $profile.attestationEnforcement
                        keyRestrictions        = @{
                            isEnforced      = $isEnforced
                            enforcementType = $enforcementType
                            aaGuids         = $otherAaGuids
                        }
                    }
                }
            }

            $includeTargets = @()
            $foundAllUsers = $false
            foreach ($target in @($policy.includeTargets | Where-Object { $_ })) {
                if ([string]$target.id -eq "all_users") {
                    $foundAllUsers = $true
                    $includeTargets += @{
                        targetType             = "group"
                        id                     = "all_users"
                        isRegistrationRequired = [bool]$target.isRegistrationRequired
                        allowedPasskeyProfiles = @($defaultProfileId)
                    }
                } else {
                    $assignedProfiles = @()
                    if ($target.allowedPasskeyProfiles) {
                        $assignedProfiles = @($target.allowedPasskeyProfiles | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) })
                    }
                    $includeTargets += @{
                        targetType             = if ($target.targetType) { [string]$target.targetType } else { "group" }
                        id                     = [string]$target.id
                        isRegistrationRequired = [bool]$target.isRegistrationRequired
                        allowedPasskeyProfiles = $assignedProfiles
                    }
                }
            }

            if (-not $foundAllUsers) {
                $includeTargets += @{
                    targetType             = "group"
                    id                     = "all_users"
                    isRegistrationRequired = $false
                    allowedPasskeyProfiles = @($defaultProfileId)
                }
            }

            $Body = @{
                "@odata.type"                    = "#microsoft.graph.fido2AuthenticationMethodConfiguration"
                state                             = "enabled"
                isSelfServiceRegistrationAllowed  = $true
                isAttestationEnforced             = $true
                includeTargets                    = @($includeTargets)
                passkeyProfiles                   = @($passkeyProfiles)
            } | ConvertTo-Json -Depth 6 -Compress

            Invoke-MgGraphRequest -Method PATCH -Uri $Uri -Body $Body -ContentType "application/json" -ErrorAction Stop | Out-Null

            # Clear screen and display summary
            Clear-Host
            Write-Host "*************************************************************************" -ForegroundColor Yellow
            Write-Host "YUBIKEY AUTHENTICATION METHOD CONFIGURATION COMPLETED SUCCESSFULLY!" -ForegroundColor Yellow
            Write-Host "*************************************************************************" -ForegroundColor Yellow
            Write-Host "Successfully updated the Default passkey profile with YubiKeys in Entra ID." -ForegroundColor Green
            Write-Host ""

        } catch {
            Clear-Host
            $errorText = $_.ErrorDetails.Message
            if ([string]::IsNullOrWhiteSpace($errorText)) {
                $errorText = $_.Exception.Message
            }
            Write-Host "Failed to configure authentication method!" -ForegroundColor Red
            Write-Host $errorText -ForegroundColor Red
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
}