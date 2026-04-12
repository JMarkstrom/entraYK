    <#
    .SYNOPSIS
    Generates a random FIDO2-compatible PIN (ASCII letters and digits, or digits only with -Numeric).

    .DESCRIPTION
    Produces a PIN suitable for YubiKey FIDO2: NFC Form C normalized, UTF-8 length at most 63 bytes 
    (ASCII alphanumeric uses one byte per character). See Yubico FIDO2 PIN documentation for more details.
    
    Rejects PINs that are a single repeated character or that match a small blocklist of weak values 
    in accordance with Yubico's FIDO2 PIN complexity requirements (see links below).

    .PARAMETER PinLength
    Number of characters. Must be between 4 and 63 inclusive.

    .PARAMETER Numeric
    If set, the PIN uses only ASCII digits (0-9). Still subject to weak-PIN rejection. Cannot be combined with -EnforceCharacterDiversity.

    .PARAMETER EnforceCharacterDiversity
    Require at least one uppercase, one lowercase, and one digit. Cannot be used with -Numeric.

    .OUTPUTS
    System.String

    .NOTES
    Internal helper; not exported from the module.

    .LINK
    Yubico FIDO2 PIN requirements:
    https://docs.yubico.com/yesdk/users-manual/application-fido2/fido2-pin.html

    .LINK
    YubiKey firmware PIN complexity rules:
    https://docs.yubico.com/hardware/yubikey/yk-tech-manual/5.7-firmware-specifics.html#pin-complexity
    #>

function New-Fido2RandomPin {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateRange(4, 63)]
        [int]$PinLength,

        [Parameter()]
        [switch]$Numeric,

        [Parameter()]
        [switch]$EnforceCharacterDiversity
    )

    if ($Numeric -and $EnforceCharacterDiversity) {
        throw "Cannot use -EnforceCharacterDiversity with -Numeric (digit-only PINs have no letter case)."
    }

    # Initialize blocklist once per session (case-insensitive for alphabetic entries)
    if (-not $script:Fido2BlockedPins) {
        $script:Fido2BlockedPins = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
        foreach ($entry in @(
            '123456', '123123', '654321', '123321', '112233', '121212', '123456789',
            'password', 'qwerty', '12345678', '1234567', '520520', '123654', '1234567890',
            '159753', 'qwerty123', 'abc123', 'password1', 'iloveyou', '1q2w3e4r'
        )) {
            [void]$script:Fido2BlockedPins.Add($entry)
        }
    }

    # ASCII digits only, or digits + uppercase + lowercase
    $alphabet = if ($Numeric) { '0123456789' } else { '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz' }
    $alphabetLen = $alphabet.Length

    $attempt = 0
    $maxAttempts = 1000

    # Build random candidates until one satisfies checks below
    do {
        $attempt++

        if ($attempt -gt $maxAttempts) {
            throw "Failed to generate a valid FIDO2 PIN after $maxAttempts attempts."
        }

        # Generate PIN using cryptographically secure RNG
        $chars = [char[]]::new($PinLength)
        for ($i = 0; $i -lt $PinLength; $i++) {
            $chars[$i] = $alphabet[[System.Security.Cryptography.RandomNumberGenerator]::GetInt32($alphabetLen)]
        }

        $pin = -join $chars

        # NFC normalization (redundant for ASCII, kept for future-proofing)
        $pinNfc = $pin.Normalize([System.Text.NormalizationForm]::FormC)

        # Reject if normalization changed length (should never happen with ASCII)
        if ($pinNfc.Length -ne $PinLength) { continue }

        # Reject if exceeds 63 bytes UTF-8 (also impossible with ASCII but kept for correctness)
        if ([System.Text.Encoding]::UTF8.GetByteCount($pinNfc) -gt 63) { continue }

        # Reject repeated single character (e.g., "AAAAAA", "111111")
        if ($pinNfc -match '^(.)\1+$') { continue }

        # Reject known weak PINs
        if ($script:Fido2BlockedPins.Contains($pinNfc)) { continue }

        # Optional: enforce character diversity
        if ($EnforceCharacterDiversity) {
            $hasDigit = $pinNfc -match '\d'
            $hasLower = $pinNfc -cmatch '[a-z]'
            $hasUpper = $pinNfc -cmatch '[A-Z]'

            if (-not ($hasDigit -and $hasLower -and $hasUpper)) { continue }
        }

        return $pinNfc
    } while ($true)
}