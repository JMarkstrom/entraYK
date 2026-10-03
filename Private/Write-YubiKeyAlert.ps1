    <#
    .SYNOPSIS
    Plays a short audible alert for YubiKey touch prompts.

    .DESCRIPTION
    On Windows, uses Console.Beep. On macOS and Linux, writes the ASCII BEL
    character so the terminal can sound its bell when enabled. Failures are
    ignored so registration is never blocked by sound support.

    .NOTES
    Internal helper; not exported from the module.
    #>

    function Write-YubiKeyAlert {
        [CmdletBinding()]
        param()

        try {
            if ($IsWindows) {
                [Console]::Beep(300, 500)
            } else {
                [Console]::Write("`a")
            }
        } catch {
            # Sound is optional; continue without failing registration.
        }
    }
