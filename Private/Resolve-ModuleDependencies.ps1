function Resolve-ModuleDependencies {
    param (
        [string]$ModuleName,
        [string]$InstallCommand = $ModuleName # Defaults to the same name as the module
    )

    # Check if the module is installed
    if (-not (Get-Module -ListAvailable -Name $ModuleName)) {
        Write-Host "Missing required module '$ModuleName'. Installing..."
        try {
            Install-Module -Name $InstallCommand -Scope CurrentUser -Force -AllowClobber
            Write-Host "Module '$ModuleName' installed successfully."
        } catch {
            Write-Error "Failed to install required module '$ModuleName': $_"
            return
        }
    } else {
        Write-Debug "Found required module '$ModuleName'. Continuing..."
    }

    # Import the module if not already imported
    if (-not (Get-Module -Name $ModuleName)) {
        try {
            Import-Module -Name $ModuleName -ErrorAction Stop
            Write-Debug "Module '$ModuleName' imported successfully."
        } catch {
            Write-Error "Failed to import module '$ModuleName': $_"
        }
    } else {
        Write-Debug "Module '$ModuleName' is already imported."
    }
}