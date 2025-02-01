## Installing and Using entraYK

### Installation Instructions:
1. Extract the ZIP (likely done if you are reading this)
   - Unzip the folder to a directory of your choice, e.g., `C:\Modules\entraYK`.  

2. Open PowerShell  
   - Start PowerShell 7 by running:  
     pwsh

3. Import the Module  
   - Run the following command (replace <path> with the actual location):  
     Import-Module "<path>\entraYK\entraYK.psd1"
   - If you placed the module in a standard module path (`$env:ProgramFiles\WindowsPowerShell\Modules` or  
     `$env:USERPROFILE\Documents\PowerShell\Modules`), you can simply run:  
     Import-Module entraYK

4. Verify Installation  
   - Run:  
     Get-Module entraYK -ListAvailable

5. Run a Cmdlet  
   - Execute your desired cmdlet, e.g.:  
     Get-YubiKeys -User user@domain.com

### Tips & Notes:
- If you encounter an "untrusted module" warning, you may need to unblock the file:  
  Unblock-File -Path "<path>\entraYK\entraYK.psd1"
- If you want to auto-load the module, consider adding it to your PowerShell profile.
