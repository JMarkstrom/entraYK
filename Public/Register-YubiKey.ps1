<#
.SYNOPSIS
Enrolls and registers a YubiKey as device-bound passkey (FIDO2) for a user in Microsoft Entra ID.

.DESCRIPTION
This Cmdlet automates the enrollment of a YubiKey as device-bound passkey (FIDO2) credential in Microsoft Entra ID 
using PowerShellYK and Microsoft Graph API.

.PARAMETER User
The ID or UPN of the user that we are enrolling for
The User Principal Name (UPN) or Object ID of the target user in Entra ID

.EXAMPLE
Enroll-YubiKey -User bob@contoso.com
Performs YubiKey configuration and registration of a passkey (FIDO2) credential for the specified user

.NOTES
- Requires the powerShellYK module
- Requires local administrator rights (for managing FIDO2)
- Requires the Microsoft.Graph PowerShell module
- Requires appropriate permissions in Entra ID (UserAuthenticationMethod.ReadWrite.All)

.LINK
https://github.com/JMarkstrom/entraYK
.LINK
https://github.com/virot/powershellYK/
#>

# Function with parameters
function Register-YubiKey {
    [CmdletBinding(DefaultParameterSetName = 'Enroll-on-behalf-of-user')]
    param
    (
        [Parameter(Mandatory=$True,
                  HelpMessage = "The User Principal Name (UPN) or Object ID of the target user")]
        [ValidateNotNullOrEmpty()]
        [ValidatePattern('^([^@]+@[^@]+\.[^@]+|[0-9a-fA-F]{8}-([0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12})$',
            ErrorMessage = "UserID must be either a valid UPN (email format) or Object ID (GUID format)")]
        [string]
        $User
    )

    begin {

        # Call the function to check and install the required module(s)
        Resolve-ModuleDependencies -ModuleName "Microsoft.Graph.Authentication"
        Resolve-ModuleDependencies -ModuleName "powershellYK"
        
        # Check if user is administrator
        if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
            Write-Error "Administrator privileges required to run this cmdlet!" -ErrorAction Stop
        }

        # Define required scopes
        $requiredScopes = @("Directory.Read.All", "UserAuthenticationMethod.ReadWrite.All")

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


        # Store UserID based on parameter input
        $UserID = $User 
        
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
            #Clear-Host
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

        # Suppress informational messages
        $InformationPreference = 'SilentlyContinue'

        # Warn the user on pending configuration:
        Clear-Host
        Write-Warning "Please insert a YubiKey NOW and press any key to continue:"
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
        if ($PSCmdlet.ParameterSetName -in @('Enroll-on-behalf-of-user')) {
            Write-Debug -Message "Starting passkey (FIDO2) credential creation in Entra ID"
            try {
                # Add verbose output before the request
                Write-Verbose "Requesting FIDO2 creation options for user: $UserID"
                
                # Modify the request to capture more error details
                $FIDO2Options = Invoke-MgGraphRequest -Method "GET" `
                    -Uri "/beta/users/$UserID/authentication/fido2Methods/creationOptions(challengeTimeoutInMinutes=5)" `
                    -ErrorAction Stop
            } catch {
                $statusCode = $_.Exception.Response.StatusCode
                
                # Check specific error conditions
                if ($statusCode -eq 'BadRequest') {
                    throw "Failed to get FIDO2 creation options. Please verify:
                    1. The user '$UserID' exists in Entra ID
                    2. You have sufficient permissions (UserAuthenticationMethod.ReadWrite.All)
                    3. FIDO2 authentication is enabled in your Entra ID tenant
                    
                    Full error: $($_.Exception.Message)"
                } else {
                    Write-Error "Failed to get FIDO2 creation options" -ErrorAction Stop -Category InvalidOperation -ErrorId "FIDO2CreationFailed" -RecommendedAction "Please check your permissions and try again" -Message "Status: $statusCode. Error: $($_.Exception.Message)"
                }
            }

            # Initialize FIDO2 parameters for YubiKey registration
            # Create challenge object from server response
            $challenge = [powershellYK.FIDO2.Challenge]::new($FIDO2Options.publicKey.challenge)
            
            # Create user entity with proper Base64URL decoding of user ID
            $userEntity = [Yubico.YubiKey.Fido2.UserEntity]::new([System.Convert]::FromBase64String("$($FIDO2Options.publicKey.user.id -replace "-","+" -replace "_","/")"))
            $userEntity.Name = $FIDO2Options.publicKey.user.name
            $userentity.DisplayName = $FIDO2Options.publicKey.user.displayName
            
            # Create relying party (RP) object with the server's RP ID
            $RelyingParty = [Yubico.YubiKey.Fido2.RelyingParty]::new($FIDO2Options.publicKey.rp.id)
            
            # Extract supported cryptographic algorithms
            $Algorithms = $FIDO2Options.publicKey.pubKeyCredParams|Select-Object -ExpandProperty Alg
            
            # Prompt the user to touch the YubiKey during the key generation process
            Clear-Host
            [console]::beep(300, 500); Write-Host "[!] Please touch the YubiKey to perform key generation..."

            # Create new FIDO2 credential on YubiKey
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

            # Update display name if provided as a parameter
            if ($PSBoundParameters.ContainsKey('DisplayName'))
            {
                $ReturnJSON.displayName = $DisplayName.Trim();
            }
            
            # Make API call to register the FIDO2 credential in Entra ID
            $result = Invoke-MgGraphRequest -Method "POST" `
                -Uri "https://graph.microsoft.com/beta/users/$UserID/authentication/fido2Methods" `
                -OutputType ([Microsoft.Graph.PowerShell.Authentication.Models.OutputType]::HttpResponseMessage) `
                -ContentType 'application/json' `
                -Body ($ReturnJSON | ConvertTo-JSON -Depth 4) `
                -SkipHttpErrorCheck

            # Provide feedback based on the registration result
            if ($result.IsSuccessStatusCode) {
                Write-Debug -Message "YubiKey successfully onboarded for user: $UserID with displayname: $($ReturnJSON.displayName)"
            } else {
                Write-Error -Message "Failed to onboard YubiKey. Attestation failed: $err"
            }
        }

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
            'UPN' = $UserID
            'Model' = $yubiKeyInfo.PrettyName
            'Serial Number' = $yubiKeyInfo.SerialNumber
            'PIN' = $pin
        } | Export-Csv -Path $csvFilePath -Append -NoTypeInformation -UseQuotes Never


        # Clear screen and display summary
        Clear-Host
        Write-Host "*******************************************" -ForegroundColor Yellow
        Write-Host "USER SUCCESSFULLY ONBOARDED WITH A YUBIKEY!" -ForegroundColor Yellow
        Write-Host "*******************************************" -ForegroundColor Yellow
        Write-Host "📝 Information saved to: $csvFilePath" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "UPN: $UserID" -ForegroundColor Green
        Write-Host "Model: $($yubiKeyInfo.PrettyName)" -ForegroundColor Green
        Write-Host "Serial Number: $($yubiKeyInfo.SerialNumber)" -ForegroundColor Green
        Write-Host "PIN: $pin" -ForegroundColor Green
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