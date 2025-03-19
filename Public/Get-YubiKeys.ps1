<#
.SYNOPSIS
Retrieves and reports on Yubico device-bound passkey authenticators (YubiKeys) by user in Microsoft Entra ID.

.DESCRIPTION
This Cmdlet connects to Microsoft Entra ID and generates a report of registered Yubico device-bound passkey 
authenticators (YubiKeys) for specified users or all accessible users in the tenant. For each listed user,
the report includes firmware version(s) and authenticator nickname(s) of each associated YubiKey.

.EXAMPLE
Get-YubiKeys -User "bob@contoso.com" 
Get YubiKey information for a single user

.EXAMPLE
Get-YubiKeys -User "bob@contoso.com", "alice@contoso.com"
Get YubiKey information for multiple users

.EXAMPLE
Get-YubiKeys -All
Get YubiKey information for all users you have access to in the tenant

.NOTES
- Requires the Microsoft.Graph PowerShell module
- Requires appropriate permissions in Entra ID (User.Read.All, Device.Read.All)
- Will prompt for authentication if not already connected to Microsoft Graph

.LINK
https://github.com/JMarkstrom/entraYK

.LINK
https://yubi.co/aaguids
#>

# Function with parameters
function Get-YubiKeys {
    [CmdletBinding()]
    param (
        [Parameter(ParameterSetName = "SpecificUsers", HelpMessage = "Specify one or more users by their UPN.")]
        [string[]] $User,

        [Parameter(ParameterSetName = "AllUsers",
                  HelpMessage = "Get YubiKey information for all users you have access to in the tenant.")]
        [switch]
        $All
    )

    begin {

        # Call the function to check and install the required module(s)
        Resolve-ModuleDependencies -ModuleName "Microsoft.Graph.Authentication"

        # Define required scopes
        $requiredScopes = @("User.Read.All", "Device.Read.All","UserAuthenticationMethod.Read.All")

    }

    process {

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
                    Connect-MgGraph -Scopes $requiredScopes -NoWelcome # -UseDeviceAuthentication
                    
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
        
        Clear-Host
        if ($PSCmdlet.ParameterSetName -eq "SpecificUsers") {
            # Ensure proper validation of each user
            $users = foreach ($userUpn in $User) {
                if ($userUpn -and $userUpn.Trim() -ne "") {
                    try {
                        Write-Verbose "Retrieving user: $userUpn"
                        Get-MgUser -Filter "userPrincipalName eq '$userUpn'"
                    } catch {
                        Write-Warning "Failed to retrieve user: $userUpn. Error: $_"
                    }
                }
            }
                    
            if (-not $users) {
                Write-Warning "No specified users were found."
                return
            }
        }
        elseif ($PSCmdlet.ParameterSetName -eq "AllUsers") {
            
            # Warn the user when using -All parameter
            Write-Warning "You are about to retrieve YubiKey information for ALL accessible users in the tenant.`n"
            
            $proceed = $false
            do {
                $ans = Read-Host "Proceed? (Y/n)"
                switch ($ans.ToLower()) {
                    {$_ -eq 'y' -or $_ -eq ''} {
                        Write-Debug "`nProceeding with retrieval of selected users..."
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

            $users = Get-MgUser -All:$true -PageSize 100
            if (-not $users) {
                Clear-Host
                Write-Warning "No users found in tenant."
                return
            }
        } else {
            Write-Warning "Either -User or -All parameter must be specified."
            return
        }
        
        $totalUsers = $users.Count
        
        # Initialize an array to store the report data
        $report = @()
        $counter = 0

        Clear-Host

        # Loop through each user in the tenant
        foreach ($currentUser in $users) {
            $counter++
            $percentComplete = [math]::Round(($counter / $totalUsers) * 100)
            Write-Progress -Activity "Now processing" -Status "user ($counter of $totalUsers)" -PercentComplete $percentComplete

            try {
                $authMethods = Get-MgUserAuthenticationMethod -UserId $currentUser.Id
                $hasFido2 = $false
                
                if ($authMethods) {
                    foreach ($method in $authMethods) {
                        $odataType = $method.AdditionalProperties['@odata.type']

                        if ($odataType -eq "#microsoft.graph.fido2AuthenticationMethod") {
                            $hasFido2 = $true
                            $aaguid = $method.AdditionalProperties['aaGuid']
                            $nickname = $method.AdditionalProperties['displayName']
                            # Get only the first matching firmware for this AAGUID
                            $info = $YubiKeyInfo | Where-Object { $_.'AAGUID' -eq $aaguid } | Select-Object -First 1
                            $firmware = $info.Firmware
                            $certification = $info.Certification

                            $report += [pscustomobject]@{
                                UPN      = $currentUser.UserPrincipalName
                                Nickname = $nickname
                                Firmware = $firmware
                                Certification = $certification
                            }
                        }
                    }
                }
                
                # Add user to report with empty strings if they don't have any FIDO2 methods
                if (-not $hasFido2) {
                    $report += [pscustomobject]@{
                        UPN      = $currentUser.UserPrincipalName
                        Nickname = ""
                        Firmware = ""
                        Certification = ""
                    }
                }
            } catch {
                Write-Error "Failed processing user $($currentUser.UserPrincipalName): $_"
            }
        }

        # Clear screen and display summary
        Clear-Host
        Write-Host "*************************************************************************************************" -ForegroundColor Yellow
        Write-Host "YUBIKEY ASSIGNMENTS REPORT" -ForegroundColor Yellow
        Write-Host "*************************************************************************************************" -ForegroundColor Yellow
        Write-Host "ℹ️ A user with multiple assignments will appear multiple times!" -ForegroundColor Yellow
        # Return the report
        $report | Format-Table -AutoSize
        Write-Host ""

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