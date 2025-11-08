<#
.SYNOPSIS
Enrolls and registers a YubiKey as device-bound passkey (FIDO2) for a user or group of users in Microsoft Entra ID.

.DESCRIPTION
This Cmdlet automates the enrollment of a YubiKey as device-bound passkey (FIDO2) credential in Microsoft Entra ID 
using PowerShellYK and Microsoft Graph API. It can register a YubiKey for a single user or for all members of a group.

.PARAMETER User
The User Principal Name (UPN) or Object ID of the target user in Entra ID.

.PARAMETER Group
The display name of a group in Entra ID. All members of this group will be registered with YubiKeys.

.EXAMPLE
Register-YubiKey -User bob@contoso.com
Performs YubiKey configuration and registration of a passkey (FIDO2) credential for the specified user

.EXAMPLE
Register-YubiKey -Group "Users"
Registers YubiKeys for all members of the specified group. You will be prompted to insert a new YubiKey for each user.

.NOTES
- Requires the powerShellYK module
- Requires local administrator rights (for managing FIDO2)
- Requires the Microsoft.Graph PowerShell module
- Requires appropriate permissions in Entra ID (UserAuthenticationMethod.ReadWrite.All, GroupMember.Read.All)
- When using -Group, you will need a separate YubiKey for each group member

.LINK
https://github.com/JMarkstrom/entraYK
.LINK
https://github.com/virot/powershellYK/
#>

# Helper function to get group members from Entra ID
function Get-GroupMembers {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]$GroupName
    )

    try {
        Write-Debug "Searching for group: $GroupName"
        
        # Search for the group by display name
        $groups = Invoke-MgGraphRequest -Method "GET" `
            -Uri "https://graph.microsoft.com/beta/groups?`$filter=displayName eq '$($GroupName -replace "'", "''")'&`$select=id,displayName" `
            -ErrorAction Stop

        if (-not $groups.value -or $groups.value.Count -eq 0) {
            Write-Error "Group '$GroupName' not found in Entra ID." -ErrorAction Stop
            return $null
        }

        if ($groups.value.Count -gt 1) {
            Write-Warning "Multiple groups found with name '$GroupName'. Using the first one: $($groups.value[0].id)"
        }

        $groupId = $groups.value[0].id
        Write-Debug "Found group ID: $groupId"

        # Get group members (only users, filter out groups and service principals)
        $members = @()
        $nextLink = "https://graph.microsoft.com/beta/groups/$groupId/members?`$select=id,userPrincipalName"

        do {
            $response = Invoke-MgGraphRequest -Method "GET" -Uri $nextLink -ErrorAction Stop
            
            # Filter to only include users (not groups or service principals)
            foreach ($member in $response.value) {
                if ($member.'@odata.type' -eq '#microsoft.graph.user') {
                    $members += [PSCustomObject]@{
                        Id = $member.id
                        UserPrincipalName = $member.userPrincipalName
                    }
                }
            }

            # Check for pagination
            $nextLink = $response.'@odata.nextLink'
        } while ($nextLink)

        Write-Debug "Found $($members.Count) user member(s) in group"
        return $members

    } catch {
        Write-Error "Failed to retrieve group members: $_" -ErrorAction Stop
        return $null
    }
}

# Helper function to register a YubiKey for a single user
function Register-SingleUserYubiKey {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]$UserID,
        
        [Parameter(Mandatory=$true)]
        [string]$UserUPN,
        
        [Parameter(Mandatory=$true)]
        [string]$CSVFilePath,
        
        [Parameter(Mandatory=$false)]
        [switch]$SuppressDetailedOutput
    )

    # Suppress informational messages
    $InformationPreference = 'SilentlyContinue'

    # Warn the user on pending configuration:
    Clear-Host
    Write-Warning "Please insert a YubiKey NOW for user: $UserUPN"
    Write-Warning "Press any key to continue:"
    [System.Console]::ReadKey() > $null
    Clear-Host

    # Connect to YubiKey
    Connect-Yubikey

    # Function to generate a random PIN (default length: 4)
    function New-RandomPin {
        param ([int]$Length = 4)
        # Generate a random PIN
        $pin = -join (
            (48..57) | Get-Random -Count $Length | ForEach-Object { [char]$_ }
        )
        return $pin
    }

    # Call the function to generate the PIN
    $pin = New-RandomPin 4 # TODO: Make this a parameter

    # Convert the PIN to a SecureString because powershellYK expects it!
    $securePin = ConvertTo-SecureString -String $pin -AsPlainText -Force

    # Get general information about the YubiKey and store it in a variable
    try {
        $yubiKeyInfo = Get-Yubikey
        $fidoInfo = Get-YubikeyFIDO2
    } catch {
        Write-Error "Failed to detect YubiKey" -ErrorAction Stop -Category DeviceError -RecommendedAction "Please ensure the YubiKey is properly connected and try again" -ErrorRecord $_
    }

    # Naming convention for YubiKeys in Entra ID
    $DisplayName = "YubiKey with S/N: $((Get-YubiKey).SerialNumber)"

    # Check if FIDO2 PIN is already set to determine if we should reset applet
    if ($fidoInfo.Options['clientPin']) {
        try {
            # Now reset FIDO2 applet if PIN is set...
            Reset-YubikeyFIDO2 -Confirm:$false # Skip the warning!
        } catch {
            Write-Error "Failed to reset the FIDO2 applet: $_"
        }
    }

    # Set the random PIN created earlier
    Set-YubikeyFIDO2PIN -NewPIN $securePin

    # Try to set Minimum PIN Length (may not be supported on older firmware)
    try {
        Set-YubiKeyFIDO2 -MinimumPINLength 4 # TODO: Make this a parameter
    } catch {
        Write-Debug "Attempted to set minimum PIN length, but it is unsupported by the YubiKey firmware (continuing)."
    }

    # Handle direct enrollment of YubiKey for a user
    Write-Debug -Message "Starting Passkey (FIDO2) credential creation in Entra ID"
    try {
        # Add verbose output before the request
        Write-Verbose "Requesting Passkey (FIDO2) creation requirements for user: $UserID"
        
        # Modify the request to capture more error details
        $FIDO2Options = Invoke-MgGraphRequest -Method "GET" `
            -Uri "/beta/users/$UserID/authentication/fido2Methods/creationOptions(challengeTimeoutInMinutes=5)" `
            -ErrorAction Stop
    } catch {
        $statusCode = $_.Exception.Response.StatusCode
        
        # Check specific error conditions
        if ($statusCode -eq 'BadRequest') {
            throw "Failed to get Passkey (FIDO2) creation requirements. Please verify:
            1. You have sufficient permissions (UserAuthenticationMethod.ReadWrite.All, GroupMember.Read.All)
            2. You have sufficient access to the user's Administrative Unit (AU)
            3. Passkey (FIDO2) authentication is enabled in your Entra ID tenant
            
            Full error: $($_.Exception.Message)"
        } else {
            Write-Error "Failed to get Passkey (FIDO2) creation requirements" -ErrorAction Stop -Category InvalidOperation -ErrorId "FIDO2CreationFailed" -RecommendedAction "Please check your permissions and try again" -Message "Status: $statusCode. Error: $($_.Exception.Message)"
        }
    }

    # Initialize FIDO2 parameters for YubiKey registration
    # Create challenge object from Relying Party (RP) response
    $challenge = [powershellYK.FIDO2.Challenge]::new($FIDO2Options.publicKey.challenge)
    
    # Create user entity with proper Base64URL decoding of user ID
    $userEntity = [Yubico.YubiKey.Fido2.UserEntity]::new([System.Convert]::FromBase64String("$($FIDO2Options.publicKey.user.id -replace "-","+" -replace "_","/")"))
    $userEntity.Name = $FIDO2Options.publicKey.user.name
    $userentity.DisplayName = $FIDO2Options.publicKey.user.displayName
    
    # Create Relying Party (RP) object with the RP ID
    $RelyingParty = [Yubico.YubiKey.Fido2.RelyingParty]::new($FIDO2Options.publicKey.rp.id)
    
    # Extract supported cryptographic algorithms
    $Algorithms = $FIDO2Options.publicKey.pubKeyCredParams|Select-Object -ExpandProperty Alg
    
    # Prompt the user to touch the YubiKey during the key generation process
    Clear-Host
    [console]::beep(300, 500); Write-Host "[!] Please touch the YubiKey to perform key generation..."

    # Create new Passkey (FIDO2) credential on YubiKey
    $FIDO2Response = New-YubiKeyFIDO2Credential -RelyingParty $RelyingParty -Discoverable $true -Challenge $challenge -UserEntity $userEntity -RequestedAlgorithms $Algorithms
    
    # Prepare response data for Microsoft Graph API
    $ReturnJSON = @{
        'displayName' = $DisplayName.Trim()
        'publicKeyCredential' = @{
            'id' = $FIDO2Response.GetBase64UrlSafeCredentialID()
            'response' = @{
                'clientDataJSON' = $FIDO2Response.GetBase64clientDataJSON()
                'attestationObject' = $FIDO2Response.GetBase64AttestationObject()
            }     
        }
    }
    
    # Make API call to register the Passkey (FIDO2) credential in Entra ID
    $result = Invoke-MgGraphRequest -Method "POST" `
        -Uri "https://graph.microsoft.com/beta/users/$UserID/authentication/fido2Methods" `
        -OutputType ([Microsoft.Graph.PowerShell.Authentication.Models.OutputType]::HttpResponseMessage) `
        -ContentType 'application/json' `
        -Body ($ReturnJSON | ConvertTo-JSON -Depth 4) `
        -SkipHttpErrorCheck

    # Provide feedback based on the registration result
    if (-not $result.IsSuccessStatusCode) {
        $errorBody = $result.Content.ReadAsStringAsync().Result
        throw "Failed to onboard YubiKey. Status: $($result.StatusCode). Error: $errorBody"
    }

    Write-Debug -Message "YubiKey successfully onboarded for user: $UserID with displayname: $($ReturnJSON.displayName)"

    # Force the user to change the PIN on first use
    try {
        Set-YubiKeyFIDO2 -ForcePINChange
    } catch {
        Write-Debug "Attempted to set Force PIN Change, but it is unsupported by this YubiKey firmware (continuing)."
    }

    # Enable Secure Transport Mode (restricted NFC)
    try {
        Set-YubiKey -SecureTransportMode
    } catch {
        Write-Debug "Attempted to set Restricted NFC, but it is unsupported by this YubiKey firmware (continuing)."
    }

    # Create object with the required attributes
    [PSCustomObject]@{
        'UPN' = $UserUPN
        'Model' = $yubiKeyInfo.PrettyName
        'Serial Number' = $yubiKeyInfo.SerialNumber
        'PIN' = $pin
    } | Export-Csv -Path $CSVFilePath -Append -NoTypeInformation -UseQuotes Never

    # Display success message only if not suppressed (for group operations)
    if (-not $SuppressDetailedOutput) {
        Clear-Host
        Write-Host "*******************************************" -ForegroundColor Yellow
        Write-Host "USER SUCCESSFULLY ONBOARDED WITH A YUBIKEY!" -ForegroundColor Yellow
        Write-Host "*******************************************" -ForegroundColor Yellow
        Write-Host "UPN: $UserUPN" -ForegroundColor Green
        Write-Host "Model: $($yubiKeyInfo.PrettyName)" -ForegroundColor Green
        Write-Host "Serial Number: $($yubiKeyInfo.SerialNumber)" -ForegroundColor Green
        Write-Host "PIN: $pin" -ForegroundColor Green
        Write-Host ""
    }
}

# Function with parameters
function Register-YubiKey {
    [CmdletBinding(DefaultParameterSetName = 'Enroll-on-behalf-of-user')]
    param
    (
        [Parameter(Mandatory=$True,
                  ParameterSetName = 'Enroll-on-behalf-of-user',
                  HelpMessage = "The User Principal Name (UPN) or Object ID of the target user")]
        [ValidateNotNullOrEmpty()]
        [ValidatePattern('^([^@]+@[^@]+\.[^@]+|[0-9a-fA-F]{8}-([0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12})$',
            ErrorMessage = "UserID must be either a valid UPN (email format) or Object ID (GUID format)")]
        [string]
        $User,

        [Parameter(Mandatory=$True,
                  ParameterSetName = 'Enroll-for-group',
                  HelpMessage = "The display name of a group in Entra ID. All members will be enrolled with YubiKeys.")]
        [ValidateNotNullOrEmpty()]
        [string]
        $Group
    )

    begin {

        # Call the function to check and install the required module(s)
        Resolve-ModuleDependencies -ModuleName "Microsoft.Graph.Authentication"
        Resolve-ModuleDependencies -ModuleName "powershellYK"
        
        # Check if user (enrollment agent) is local administrator
        if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
            Write-Error "Administrator privileges required to run this cmdlet!" -ErrorAction Stop
        }

        # Define required scopes (GroupMember.Read.All needed for group operations)
        $requiredScopes = @("Directory.Read.All", "UserAuthenticationMethod.ReadWrite.All", "GroupMember.Read.All")

        # Check if a CSV output file exists else create it
        $csvFilePath = Join-Path -Path (Get-Location) -ChildPath "output.csv"
        if (-Not (Test-Path -Path $csvFilePath)) {
            Write-Debug "No existing CSV file found in the current directory. Creating a new one..."
            New-Item -Path $csvFilePath -ItemType File -Force | Out-Null
            Set-Content -Path $csvFilePath -Value "UPN,Model,Serial Number,PIN" -Encoding UTF8
        } else {
            Write-Debug "Found existing CSV file in the current directory. Appending to it..."
        }

    }

    process {  

        # Check if already connected with correct permissions (needed for both user and group operations)
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

        # Determine if we're processing a single user or a group
        if ($PSCmdlet.ParameterSetName -eq 'Enroll-for-group') {
            # Handle group-based registration
            $groupMembers = Get-GroupMembers -GroupName $Group
            
            if (-not $groupMembers -or $groupMembers.Count -eq 0) {
                Write-Warning "No members found in group '$Group' or group does not exist."
                return
            }

            Clear-Host
            Write-Host "Found $($groupMembers.Count) member(s) in group '$Group'" -ForegroundColor Yellow
            Write-Host "You will need to ensure supply of YubiKey for each user ($($groupMembers.Count) YubiKeys required)." -ForegroundColor Yellow
            Write-Host ""
            $proceed = Read-Host "Proceed with user registration? (Y/n)"
            if ($proceed -and $proceed.ToLower() -ne 'y' -and $proceed -ne '') {
                Write-Host "Operation cancelled by user." -ForegroundColor Red
                return
            }

            $successCount = 0
            $failCount = 0
            $counter = 0

            foreach ($member in $groupMembers) {
                $counter++
                $memberId = $member.Id
                $memberUpn = $member.UserPrincipalName

                Clear-Host
                Write-Host "Processing user $counter of $($groupMembers.Count): $memberUpn" -ForegroundColor Cyan
                Write-Host ""

                try {
                    Register-SingleUserYubiKey -UserID $memberId -UserUPN $memberUpn -CSVFilePath $csvFilePath -SuppressDetailedOutput
                    $successCount++
                    Write-Host "✓ Successfully registered YubiKey for $memberUpn" -ForegroundColor Green
                } catch {
                    $failCount++
                    Write-Warning "Failed to register YubiKey for $memberUpn : $_"
                }

                # Prompt before next user (except for the last one)
                if ($counter -lt $groupMembers.Count) {
                    Write-Host ""
                    Write-Host "Press any key to continue with next user..." -ForegroundColor Yellow
                    [System.Console]::ReadKey() > $null
                }
            }

            # Final summary
            Clear-Host
            Write-Host "*******************************************" -ForegroundColor Yellow
            Write-Host "GROUP REGISTRATION SUMMARY" -ForegroundColor Yellow
            Write-Host "*******************************************" -ForegroundColor Yellow
            Write-Host "Total users processed: $($groupMembers.Count)" -ForegroundColor Cyan
            Write-Host "Successful: $successCount" -ForegroundColor Green
            Write-Host "Failed: $failCount" -ForegroundColor $(if ($failCount -gt 0) { "Red" } else { "Green" })
            Write-Host ""
            Write-Host "📝 Information saved to: $csvFilePath" -ForegroundColor Yellow
            Write-Host ""

            # Disconnect from Microsoft Graph
            try {
                Write-Debug "Disconnecting from Microsoft Graph..."
                Disconnect-MgGraph | Out-Null  # Suppress output
                Write-Debug "Disconnected from Microsoft Graph"
            } catch {
                Write-Warning "Failed to disconnect from Microsoft Graph: $_"
            }

            return
        }

        # Single user registration (original flow)
        # Store UserID based on parameter input
        $UserID = $User 

        # Single user registration - call the reusable function
        Register-SingleUserYubiKey -UserID $UserID -UserUPN $UserID -CSVFilePath $csvFilePath

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