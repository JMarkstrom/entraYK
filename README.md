# entraYK

## ℹ️ About
**entraYK** is a PowerShell module for managing YubiKeys as device-bound passkeys (FIDO2) in Microsoft Entra ID.   
Functionality includes the ability to: 

- Configure the "Passkey (FIDO2)" authentication method,
- Create a custom authentication strength definition,
- Register a YubiKey as device-bound passkey on behalf of a user<sup>1</sup>
- List YubiKey attributes for all _or_ select user(s)<sup>2</sup>

<sup>1</sup>This Cmdlet is making use of Oscar Virot's [powershellYK](https://github.com/virot/powershellYK/) module.   
<sup>2</sup>Output includes YubiKey **nickname**, **firmware version** and Fido **certification level**.

## ⚠️ Disclaimer
The PowerShell module provided herein is made available on an "as-is" basis, without any warranties or representations, whether express, implied, or statutory, including but not limited to implied warranties of merchantability, fitness for a particular purpose, or non-infringement.

## 💻 Prerequisites
_Use of the powershellYK module requires the following prerequisites be met:_
- PowerShell 7 (```pwsh```)

## 💾 Installation
_To install entraYK:_

1. Open PowerShell
2. Execute command: ```Install-Module entraYK```
3. Press ```Y``` when prompted to proceed with installation
4. Execute command: ```Import-Module entraYK```

## 📖 Usage
_For usage instructions click a list item below or scroll down_   

- [Configure the "Passkey (FIDO2)" authentication method](#configure-the-passkey-fido2-authentication-method)    
- [Create a custom authentication strength definition](#create-a-custom-authentication-strength-definition)  
- [Register a YubiKey as device-bound passkey on behalf of a userl](#register-a-yubikey-as-device-bound-passkey-on-behalf-of-a-user)  
- [Create a Kerberos object](#create-a-kerberos-object)  
- [List YubiKey attributes for all or select user(s)](#list-yubikey-attributes-for-all-or-select-users)   


### Configure the "Passkey (FIDO2)" authentication method
This Cmdlet (Set-YubiKeyAuthMethod) configures the "Passkey (FIDO2)" authentication method in Microsoft Entra ID. Importantly it configures the method for all users and it enforces FIDO device attestation with white-listing of YubiKeys. The Cmdlet can whitelist either all(!) FIDO2-capable YubiKeys or select YubiKey models as defined by their AAGUID. The Cmdlet will reject non Yubico AAGUIDs.

   
**Enable the Passkey method defining all YubiKey models:**
```powershell
Set-YubiKeyAuthMethod -All
```
**Enable the Passkey method defining a specific YubiKey model by AAGUID:**
```powershell
Set-YubiKeyAuthMethod -AAGUID "fa2b99dc-9e39-4257-8f92-4a30d23c4118"
```
Resulting Entra ID configuration:   

![](/images/Set-YubiKeyAuthMethod.png)

**NOTE**: You can find YubiKey AAGUIDs here: https://yubi.co/aaguids

---

### Create a custom authentication strength definition
This Cmdlet (Set-YubiKeyAuthStrength) adds a custom authentication strength to Microsoft Entra ID. The Cmdlet can either add all(!) FIDO2-capable YubiKeys or select YubiKey models as defined by their AAGUID. In addition to any defined YubiKey the Cmdlet will also add support for Temporary Access Pass (TAP) as a single use authenticator. The method created will be named "YubiKey" and can be selected in Conditional Access policies to require phishing-resistant MFA using YubiKeys as device-bound passkeys. An optional user-selected name can be provided using the -Name parameter.

   
**Add a custom authentication strength using _all_ FIDO2 passkey-capable YubiKey models:**
```powershell
Set-YubiKeyAuthStrength -All
```
**Add a custom authentication strength using only _select_ YubiKey model(s) by their AAGUID(s):**
```powershell
Set-YubiKeyAuthStrength -AAGUID "fa2b99dc-9e39-4257-8f92-4a30d23c4118"
```
**Add a custom authentication strength with your name of choice**
```powershell
Set-YubiKeyAuthStrength -All -Name "AAL3"
```

Resulting Entra ID configuration:   

![](/images/Set-YubiKeyAuthStrength.png)

**NOTE**: You can find YubiKey AAGUIDs here: https://yubi.co/aaguids


---

### Register a YubiKey as device-bound passkey on behalf of a user
This Cmdlet (Register-YubiKey) performs Enrollment On Behalf Of (EOBO) with Microsoft Entra ID. The Cmdlet uses **powershellYK** for YubiKey configuration and credential creation. It will generate a random PIN, name the YubiKey to contain Serial Number for asset tracking purposes, and where supported it will set the ForceChangePin flag and enable Restricted NFC.


**Register a YubiKey on behalf of a user:**
```powershell
Register-YubiKey -User "alice@swjm.blog
```
Sample output:   

```bash
UPN           : alice@swjm.blog
Nickname      : YubiKey with S/N: 23616243
Serial Number : 23616243
PIN           : 5144
```
![](/images/Register-YubiKey.png)

---

### Create a Kerberos object
This Cmdlet (Set-KerberosObject) creates a Kerberos authentication object in Entra ID, enabling integration with the local Active Directory domain. This allows users to sign in to Windows using FIDO2 security keys and access AD-based resources over the network.
To streamline configuration the Cmdlet will fetch Active Directory domain name from user context and will install the required Entra ID PowerShell module (AzureADHybridAuthenticationManagement) on-behalf-of the current user and will only prompt for cloud identity.

**Create a Kerberos object for current domain**
```powershell
Set-KerberosObject
```

---


### List YubiKey attributes for all or select user(s)
This Cmdlet (Get-YubiKeys) lists properties about enrolled YubiKeys in Microsoft Entra ID. It can perform this listing either for all accessible users or for select user(s) by User Principal Name (UPN). Information presented includes firmware version, nickname as well as Fido certification level.


**Get YubiKey information for all users you have access to in the tenant:**
```powershell
Get-YubiKeys -All
```
Get YubiKey information for a single user:
```powershell
Get-YubiKeys -User "alice@swjm.blog" 
```

Sample output:   


```bash
UPN                Nickname        Firmware      Certfication
-------------------------------------------------------------
alice@swjm.blog    YubiKey 5 Nano  5.7           L2
bob@swjm.blog      YubiKey 5 NFC   5.7           L2
mike@swjm.blog     YubiKey 5C NFC  5.2 / 5.4     L1
```
**NOTE**: The logic to present firmware version is dependent on Entra ID storing YubiKey AAGUID.
Because AAGUIDs does not necessarily change with firmware version it is possible that a YubiKey is _either_ one firmware or another as shown above (```5.2 / 5.4```).

---

## 📖 Roadmap
Possible improvements includes:
- ~~Passkey "EOBO" enrollment using [powershellYK](https://github.com/virot/powershellYK)~~
- ~~Add ```-Name``` param for ```Set-YubiKeyAuthStrength```~~
- Entra ID Kerberos object creation
- Ability to fetch last used authenticator by UPN
- Configuration by Certification level (e.g.: "L2 only YubiKeys")
- Configuration by Firmware version (e.g: "all 5.7+ YubiKeys)


### 🥷🏻 Contributing
You can help by getting involved in the project, _or_ by donating (any amount!).   
Donations will support costs such as domain registration and code signing (planned).

[![Donate](https://www.paypalobjects.com/en_US/i/btn/btn_donate_LG.gif)](https://www.paypal.com/donate/?business=RXAPDEYENCPXS&no_recurring=1&item_name=Help+cover+costs+of+the+SWJM+blog+and+app+code+signing%2C+supporting+a+more+secure+future+for+all.&currency_code=USD)

## 📜 Release History
* 2025.02.01 `v0.4.0`
* 2025.02.01 `v0.3.0`
* 2025.01.28 `v0.2.0`
* 2025.01.26 `v0.1.0`
