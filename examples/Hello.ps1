# Example PowerShell script for Build-exe.bat
# Drag this file onto Build-exe.bat to get Hello.exe
param([string]$Name = 'World')

# Folder of the EXE when built, folder of the script when run directly
$Here = if ($env:EXE_DIR) { $env:EXE_DIR } else { $PSScriptRoot }

Write-Host "Hello, $Name!" -ForegroundColor Green
Write-Host ''
Write-Host "Running from : $PSScriptRoot"
Write-Host "Home folder  : $Here"
Write-Host "PowerShell   : $($PSVersionTable.PSVersion)"
Write-Host ''
Write-Host 'Press any key to exit...' -ForegroundColor Yellow
[Console]::ReadKey($true) | Out-Null
exit 0
