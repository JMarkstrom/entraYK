@{
    # Script module or binary module file associated with this manifest.
    RootModule = 'entraYK.psm1'

    # Version number of this module.
    ModuleVersion = '0.4.0'

    # ID used to uniquely identify this module
    GUID = '8f742c2f-7a76-4c6a-9c69-b2f2e14c3d9b'

    # Author of this module
    Author = 'Jonas Markström'

    # Company or vendor of this module
    CompanyName = 'swjm.blog'

    # Copyright statement for this module
    Copyright = '(c) 2025 SWJM All rights reserved.'

    # Description of the functionality provided by this module
    Description = 'PowerShell module for managing YubiKeys as device-bound passkeys (FIDO2) in Microsoft Entra ID'

    # Minimum version of the PowerShell engine required by this module
    PowerShellVersion = '7.0'

    # Modules that must be imported into the global environment prior to importing this module
    #RequiredModules = @('Microsoft.Graph')

    # Functions to export from this module
    FunctionsToExport = @(
        'Get-YubiKeys',
        'Register-YubiKey',
        'Set-YubiKeyAuthMethod',
        'Set-YubiKeyAuthStrength'
    )

    # Private data to pass to the module specified in RootModule/ModuleToProcess
    PrivateData = @{
        PSData = @{
            # Tags applied to this module for discovery
            Tags = @('YubiKey', 'EntraID', 'FIDO2', 'Security', 'Passkeys', 'Authentication', 'Entra', 'Microsoft-Entra-ID')

            # Project site URL
            ProjectUri = 'https://github.com/JMarkstrom/entraYK'

            # License URI for this module
            LicenseUri = 'https://github.com/JMarkstrom/entraYK/blob/main/LICENSE'
        }
    }
}

