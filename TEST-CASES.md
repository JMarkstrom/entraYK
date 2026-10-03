# Test cases by cmdlet (entraYK)

This document lists suggested test cases for the **exported** cmdlets in `entraYK` (`entraYK.psd1`). Most scenarios require a test Entra ID tenant, appropriate Graph permissions, and (for enrollment) a physical YubiKey and an elevated PowerShell session. Mark each case as **manual**, **integration**, or **automated** when you implement tests.

---

## Get-YubiKeys

GYK-01
  Scenario: `-User` with one valid UPN that has FIDO2 methods
  Expected: Report rows include that user with nickname/firmware where AAGUID matches known YubiKeys

GYK-02
  Scenario: `-User` with multiple valid UPNs (array)
  Expected: All resolved users processed; report includes each

GYK-03
  Scenario: `-User` with UPN that does not exist in tenant
  Expected: Warning for failed user; no fatal crash (or empty result as implemented)

GYK-04
  Scenario: `-User` with empty string / whitespace-only entry in array
  Expected: Empty entries skipped; remaining users still processed

GYK-05
  Scenario: `-All` after confirming at prompt (`Y` or Enter)
  Expected: All accessible users enumerated; report built with progress

GYK-06
  Scenario: `-All` and user answers `n` at confirmation
  Expected: Operation cancelled; no bulk query

GYK-07
  Scenario: User with no FIDO2 methods
  Expected: Row present with empty nickname/firmware/certification

GYK-08
  Scenario: User with multiple FIDO2 credentials
  Expected: Multiple rows for same UPN (per cmdlet behavior)

GYK-09
  Scenario: No `-User` and no `-All` (if invocable)
  Expected: Warning that a parameter must be specified; early return

GYK-10
  Scenario: Already connected to Graph with full required scopes
  Expected: No re-auth prompt path (or minimal); cmdlet completes

GYK-11
  Scenario: Connected with missing scopes
  Expected: Re-auth or scope warning path; eventually succeeds or fails clearly

GYK-12
  Scenario: `Disconnect-MgGraph` after success
  Expected: Session disconnected without unhandled error

---

## Register-YubiKey

RYK-01
  Scenario: `-User <valid UPN>` default (random PIN, default length)
  Expected: YubiKey configured; passkey registered; `output.csv` appended; Graph disconnected in `end`

RYK-02
  Scenario: `-User` with `-PinLength 6` (non-default)
  Expected: PIN length respected where device minimum allows

RYK-03
  Scenario: `-User` with no PIN charset switch (default)
  Expected: Numeric random PIN generated

RYK-03a
  Scenario: `-User` with `-Alphanumeric`
  Expected: Alphanumeric random PIN generated

RYK-04
  Scenario: `-User` with `-Pin` fixed PIN (valid length, non-trivial)
  Expected: Fixed PIN path (`UserFixedPin`); not combined with `-PinLength`/`-Alphanumeric`

RYK-05
  Scenario: `-User` with invalid UPN format (not `local@domain.tld`)
  Expected: `ValidatePattern` failure before Graph/YubiKey

RYK-06
  Scenario: `-User` valid UPN but user not found / Graph `NotFound`
  Expected: Clear error from FIDO2 creation options path

RYK-07
  Scenario: `-Group <display name>` with user members only
  Expected: Each member processed; summary counts; CSV updated

RYK-08
  Scenario: `-Group` with no users or group missing
  Expected: Warning and early return (no partial enroll)

RYK-09
  Scenario: `-Group` confirmation answered `n` (non-yes)
  Expected: Operation cancelled

RYK-10
  Scenario: `-Group` with `-Pin` (`GroupFixedPin`)
  Expected: All members use fixed PIN path

RYK-11
  Scenario: YubiKey with `clientPin` already set
  Expected: FIDO2 reset runs; failure on reset terminates (no silent continue)

RYK-12
  Scenario: `Set-YubikeyFIDO2PIN` failure
  Expected: Terminating error; no Entra registration POST

RYK-13
  Scenario: Requested PIN length below device `MinimumPinLength`
  Expected: `PIN_LENGTH_MISMATCH` path; message references device minimum

RYK-14
  Scenario: `Connect-Yubikey` failure
  Expected: Caught with “Failed to detect YubiKey” style error

RYK-15
  Scenario: Run without administrator elevation
  Expected: Error in `begin` requiring admin

RYK-16
  Scenario: Multiple groups match same display name (Graph)
  Expected: First group used; warning logged (`Get-GroupMembers`)

---

## Set-YubiKeyAuthMethod

SAM-01
  Scenario: `-All` after confirmation
  Expected: Default passkey profile key restriction updated with the full supported YubiKey AAGUID set; self-service registration enabled

SAM-02
  Scenario: `-AAGUID` with one known valid YubiKey AAGUID
  Expected: Default passkey profile restricts to that AAGUID; self-service registration enabled

SAM-03
  Scenario: `-AAGUID` with multiple valid AAGUIDs
  Expected: All included in the Default passkey profile restriction list; self-service registration enabled

SAM-04
  Scenario: `-AAGUID` with unknown / non-YubiKey GUID
  Expected: Error: not a valid YubiKey AAGUID; no policy change

SAM-05
  Scenario: `-All` yields empty AAGUID list (edge / data file)
  Expected: Error: no valid AAGUIDs; operation cancelled

SAM-06
  Scenario: User declines confirmation (`n`)
  Expected: Cancelled; no Graph mutation

SAM-07
  Scenario: Invalid confirmation input loop
  Expected: Reprompt until `y`/`n`/Enter

SAM-08
  Scenario: Graph permissions insufficient
  Expected: Clear authentication or API error

---

## Set-YubiKeyAuthStrength

SAS-01
  Scenario: `-All` after confirmation
  Expected: Authentication strength created/updated with firmware ≥ 5.7 YubiKey AAGUIDs + TAP (per design)

SAS-02
  Scenario: `-AAGUID` single valid GUID
  Expected: Strength includes that model

SAS-03
  Scenario: `-AAGUID` multiple valid GUIDs
  Expected: Strength includes each

SAS-04
  Scenario: `-Name` custom policy name
  Expected: Policy uses supplied name (default otherwise `YubiKey`)

SAS-05
  Scenario: `-AAGUID` invalid GUID
  Expected: Error; early return

SAS-06
  Scenario: `-All` results in no AAGUIDs (empty selection)
  Expected: Error: no valid AAGUIDs

SAS-07
  Scenario: User declines confirmation
  Expected: Cancelled

SAS-08
  Scenario: Graph write failure
  Expected: Handled error; tenant state unchanged or partially updated per API behavior

---

## Cross-cutting (all Graph cmdlets)

X-01
  Scenario: Import module on PowerShell 7.6+
  Expected: No parse errors; functions exported per manifest

X-02
  Scenario: `Resolve-ModuleDependencies` when Graph module missing
  Expected: Install/import path or clear failure

X-03
  Scenario: Non-interactive host (`ReadKey` / `Read-Host` unavailable)
  Expected: Document limitation or add `-Force` tests when implemented

---

## Private helpers (optional unit-test targets)

Not exported; useful if you add **Pester** tests without Graph or hardware:

- `New-Fido2RandomPin` — length bounds, `-Numeric`, weak-PIN rejection, `-EnforceCharacterDiversity` mutual exclusion.
- `Get-YubiKeyInfo` — returns expected structure (static JSON/data).
- `Get-GroupMembers` — filter escaping, pagination (mock `Invoke-MgGraphRequest`).

---

*Generated for manual QA and future automation; align IDs with your test tracker if used.*
