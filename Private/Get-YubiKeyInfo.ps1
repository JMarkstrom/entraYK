    <#
    .SYNOPSIS
    Returns the mapping of YubiKey AAGUIDs to their corresponding firmware versions.
    
    .DESCRIPTION
    Internal helper function that maintains the mapping between YubiKey AAGUIDs and firmware versions.
    Source: https://yubi.co/aaguids
  
    .NOTES
    This is an internal function and should not be exported from the module.
    
    .LINK
    https://yubi.co/aaguids
    #>

    function Get-YubiKeyInfo {
        [CmdletBinding()]
        param()
        
    return @(
        @{Model="YubiKey 5 (USB-A, No NFC)"; Firmware="5.1"; AAGUID="cb69481e-8ff7-4039-93ec-0a2729a154a8"; Certification="Level 1"},
        @{Model="YubiKey 5 (USB-A, No NFC)";Firmware="5.2 / 5.4"; AAGUID="ee882879-721c-4913-9775-3dfcce97072a"; Certification="Level 1"},
        @{Model="YubiKey 5 NFC"; Firmware="5.1"; AAGUID="fa2b99dc-9e39-4257-8f92-4a30d23c4118"; Certification="Level 1"},
        @{Model="YubiKey 5 NFC"; Firmware="5.2 / 5.4"; AAGUID="2fc0579f-8113-47ea-b116-bb5a8db9202a"; Certification="Level 1"},
        @{Model="YubiKey 5 NFC"; Firmware="5.7"; AAGUID="a25342c0-3cdc-4414-8e46-f4807fca511c"; Certification="Level 2"},
        @{Model="YubiKey 5 NFC CSPN"; Firmware="5.4"; AAGUID="c1f9a0bc-1dd2-404a-b27f-8e29047a43fd"; Certification="Level 2"},
        @{Model="YubiKey 5 NFC FIPS"; Firmware="5.4"; AAGUID="c1f9a0bc-1dd2-404a-b27f-8e29047a43fd"; Certification="Level 2"},
        @{Model="YubiKey 5 Nano"; Firmware="5.1"; AAGUID="cb69481e-8ff7-4039-93ec-0a2729a154a8"; Certification="Level 1"},
        @{Model="YubiKey 5 Nano"; Firmware="5.2 / 5.4"; AAGUID="ee882879-721c-4913-9775-3dfcce97072a"; Certification="Level 1"},
        @{Model="YubiKey 5 Nano"; Firmware="5.1"; AAGUID="fa2b99dc-9e39-4257-8f92-4a30d23c4118"; Certification="Level 1"},
        @{Model="YubiKey 5 Nano"; Firmware="5.2 / 5.4"; AAGUID="2fc0579f-8113-47ea-b116-bb5a8db9202a"; Certification="Level 1"},
        @{Model="YubiKey 5 Nano"; Firmware="5.7"; AAGUID="a25342c0-3cdc-4414-8e46-f4807fca511c"; Certification="Level 2"},
        @{Model="YubiKey 5 Nano"; Firmware="5.4"; AAGUID="c1f9a0bc-1dd2-404a-b27f-8e29047a43fd"; Certification="Level 2"},
        @{Model="YubiKey 5 Nano"; Firmware="5.7"; AAGUID="a25342c0-3cdc-4414-8e46-f4807fca511c"; Certification="Level 2"},
        @{Model="YubiKey 5 Nano"; Firmware="5.2 / 5.4"; AAGUID="ee882879-721c-4913-9775-3dfcce97072a"; Certification="Level 1"},
        @{Model="YubiKey 5 Nano"; Firmware="5.7"; AAGUID="19083c3d-8383-4b18-bc03-8f1c9ab2fd1b"; Certification="Level 2"},
        @{Model="YubiKey 5 Nano CSPN"; Firmware="5.4"; AAGUID="ee882879-721c-4913-9775-3dfcce97072a"; Certification="Level 1"},
        @{Model="YubiKey 5 Nano FIPS"; Firmware="5.4"; AAGUID="73bb0cd4-e502-49b8-9c6f-b59445bf720b"; Certification="Level 2"},
        @{Model="YubiKey 5C"; Firmware="5.1"; AAGUID="cb69481e-8ff7-4039-93ec-0a2729a154a8"; Certification="Level 1"},
        @{Model="YubiKey 5C"; Firmware="5.2 / 5.4"; AAGUID="ee882879-721c-4913-9775-3dfcce97072a"; Certification="Level 1"},
        @{Model="YubiKey 5C"; Firmware="5.7"; AAGUID="19083c3d-8383-4b18-bc03-8f1c9ab2fd1b"; Certification="Level 2"},
        @{Model="YubiKey 5C Nano CSPN"; Firmware="5.4"; AAGUID="ee882879-721c-4913-9775-3dfcce97072a"; Certification="Level 1"},
        @{Model="YubiKey 5C Nano FIPS"; Firmware="5.4"; AAGUID="73bb0cd4-e502-49b8-9c6f-b59445bf720b"; Certification="Level 2"},
        @{Model="YubiKey 5C NFC"; Firmware="5.2 / 5.4"; AAGUID="2fc0579f-8113-47ea-b116-bb5a8db9202a"; Certification="Level 1"},
        @{Model="YubiKey 5C NFC"; Firmware="5.7"; AAGUID="a25342c0-3cdc-4414-8e46-f4807fca511c"; Certification="Level 2"},
        @{Model="YubiKey 5C NFC CSPN"; Firmware="5.4"; AAGUID="2fc0579f-8113-47ea-b116-bb5a8db9202a"; Certification="Level 1"},
        @{Model="YubiKey 5C NFC FIPS"; Firmware="5.4"; AAGUID="c1f9a0bc-1dd2-404a-b27f-8e29047a43fd"; Certification="Level 2"},
        @{Model="YubiKey 5Ci"; Firmware="5.2 / 5.4"; AAGUID="c5ef55ff-ad9a-4b9f-b580-adebafe026d0"; Certification="Level 1"},
        @{Model="YubiKey 5Ci"; Firmware="5.7"; AAGUID="a02167b9-ae71-4ac7-9a07-06432ebb6f1c"; Certification="Level 2"},
        @{Model="YubiKey 5Ci CSPN"; Firmware="5.4"; AAGUID="c5ef55ff-ad9a-4b9f-b580-adebafe026d0"; Certification="Level 1"},
        @{Model="YubiKey 5Ci FIPS"; Firmware="5.4"; AAGUID="85203421-48f9-4355-9bc8-8a53846e5083"; Certification="Level 2"},
        @{Model="Security Key By Yubico (Blue)"; Firmware="5.1"; AAGUID="f8a011f3-8c0a-4d15-8006-17111f9edc7d"; Certification="Level 1"},
        @{Model="Security Key By Yubico (Blue)"; Firmware="5.2 / 5.4"; AAGUID="b92c3f9a-c014-4056-887f-140a2501163b"; Certification="Level 1"},
        @{Model="Security Key NFC (Blue)"; Firmware="5.1"; AAGUID="6d44ba9b-f6ec-2e49-b930-0c8fe920cb73"; Certification="Level 1"},
        @{Model="Security Key NFC (USB-A, USB-C) (Blue)"; Firmware="5.2 / 5.4"; AAGUID="149a2021-8ef6-4133-96b8-81f8d5b7f1f5"; Certification="Level 1"},
        @{Model="YubiKey Bio - FIDO Edition"; Firmware="5.5 / 5.6"; AAGUID="d8522d9f-575b-4866-88a9-ba99fa02f35b"; Certification="Level 1"},    
        @{Model="YubiKey Bio - FIDO Edition"; Firmware="5.7"; AAGUID="dd86a2da-86a0-4cbe-b462-4bd31f57bc6f"; Certification="Level 1"},
        @{Model="YubiKey Bio Series - Multi-protocol Edition"; Firmware="5.6"; AAGUID="7d1351a6-e097-4852-b8bf-c9ac5c9ce4a3"; Certification="Level 1"},
        @{Model="YubiKey Bio Series - Multi-protocol Edition"; Firmware="5.7"; AAGUID="90636e1f-ef82-43bf-bdcf-5255f139d12f"; Certification="Level 1"},
        @{Model="Security Key NFC (Black) (USB-A, USB-C)"; Firmware="5.4"; AAGUID="a4e9fc6d-4cbe-4758-b8ba-37598bb5bbaa"; Certification="Level 2"},
        @{Model="Security Key NFC (Black) (USB-A, USB-C)"; Firmware="5.7"; AAGUID="e77e3c64-05e3-428b-8824-0cbeb04b829d"; Certification="Level 2"},
        @{Model="Security Key NFC - Enterprise Edition (USB-A, USB-C) (Black)"; Firmware="5.4"; AAGUID="0bb43545-fd2c-4185-87dd-feb0b2916ace"; Certification="Level 2"},
        @{Model="Security Key NFC - Enterprise Edition (USB-A, USB-C) (Black)"; Firmware="5.7"; AAGUID="47ab2fb4-66ac-4184-9ae1-86be814012d5"; Certification="Level 2"},
        @{Model="YubiKey 5 NFC"; Firmware="5.7"; AAGUID="1ac71f64-468d-4fe0-bef1-0e5f2f551f18"; Certification="Level 2"},
        @{Model="YubiKey 5 Nano"; Firmware="5.7"; AAGUID="20ac7a17-c814-4833-93fe-539f0d5e3389"; Certification="Level 2"},
        @{Model="YubiKey 5C"; Firmware="5.7"; AAGUID="20ac7a17-c814-4833-93fe-539f0d5e3389"; Certification="Level 2"},
        @{Model="YubiKey 5C Nano"; Firmware="5.7"; AAGUID="20ac7a17-c814-4833-93fe-539f0d5e3389"; Certification="Level 2"},
        @{Model="YubiKey 5C NFC"; Firmware="5.7"; AAGUID="1ac71f64-468d-4fe0-bef1-0e5f2f551f18"; Certification="Level 2"},
        @{Model="YubiKey 5Ci"; Firmware="5.7"; AAGUID="b90e7dc1-316e-4fee-a25a-56a666a670fe"; Certification="Level 2"},
        @{Model="YubiKey Bio Series - FIDO Edition"; Firmware="5.7"; AAGUID="8c39ee86-7f9a-4a95-9ba3-f6b097e5c2ee"; Certification="N/A"},
        @{Model="YubiKey Bio Series - Multi-protocol Edition"; Firmware="5.7"; AAGUID="97e6a830-c952-4740-95fc-7c78dc97ce47"; Certification="N/A"},
        @{Model="Security Key NFC - Enterprise Edition (USB-A, USB-C) (Black)"; Firmware="5.7"; AAGUID="9ff4cc65-6154-4fff-ba09-9e2af7882ad2"; Certification="Level 2"}
    )
} 