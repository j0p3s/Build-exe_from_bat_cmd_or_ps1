@echo off
setlocal
title Script to EXE Builder v1.0.0
cd /d "%~dp0"

echo ========================================================
echo   Script to EXE Builder v1.0.0  (.cmd / .bat / .ps1)
echo ========================================================
echo   Usage: drag one or more scripts onto this file,
echo          or run it and drag a script into the window.
echo ========================================================

:: All build logic runs in PowerShell. It is stored after the ::BUILDER::
:: line at the end of this file. cmd never reads past "exit /b".
set "SBC_BAT=%~f0"
set "SBC_RC=0"

if "%~1"=="" goto :ask

:loop
if "%~1"=="" goto :done
call :build "%~1"
shift
goto :loop

:ask
echo.
set "SBC_ASK="
set /p "SBC_ASK=Drag a .cmd, .bat or .ps1 file here and press Enter: "
if not defined SBC_ASK goto :done
set "SBC_ASK=%SBC_ASK:"=%"
call :build "%SBC_ASK%"
goto :done

:build
set "SBC_IN=%~f1"
echo.
echo --------------------------------------------------------
if not exist "%SBC_IN%" goto :notfound
choice /c YN /t 30 /d N /m "Should the EXE ask for administrator rights (UAC) when started"
if errorlevel 2 (set "SBC_ADMIN=0") else (set "SBC_ADMIN=1")
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$l=[IO.File]::ReadAllLines($env:SBC_BAT); $b=[Array]::IndexOf($l,'::BUILDER::'); if($b -lt 0){Write-Host '[ERROR] Builder section not found in this file.' -ForegroundColor Red; exit 1}; Invoke-Expression ($l[($b+1)..($l.Count-1)] -join [Environment]::NewLine)"
if errorlevel 1 set "SBC_RC=1"
exit /b

:notfound
echo [ERROR] File not found: "%SBC_IN%"
set "SBC_RC=1"
exit /b

:done
echo.
if "%SBC_RC%"=="0" (echo [DONE] All builds finished.) else (echo [ERROR] One or more builds failed.)
echo.
pause
exit /b %SBC_RC%

::BUILDER::
$ErrorActionPreference = 'Stop'
$ProgressPreference    = 'SilentlyContinue'

$Source    = $env:SBC_IN
$Admin     = ($env:SBC_ADMIN -eq '1')
$RoslynDir = Join-Path $env:LOCALAPPDATA 'RoslynCompiler'
$WorkDir   = Join-Path $env:TEMP ('ScriptExe_Build_' + [guid]::NewGuid().ToString('N'))

function Find-Csc {
    $candidates = @(
        (Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'),
        (Join-Path $env:WINDIR 'Microsoft.NET\Framework\v4.0.30319\csc.exe')
    )
    foreach ($c in $candidates) { if (Test-Path -LiteralPath $c) { return $c } }

    if (Test-Path -LiteralPath $RoslynDir) {
        $f = Get-ChildItem -LiteralPath $RoslynDir -Filter 'csc.exe' -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($f) { return $f.FullName }
    }

    $cmd = Get-Command 'csc.exe' -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    return $null
}

function Invoke-Elevated([string]$FilePath, [string]$Arguments) {
    # Runs a program as administrator (UAC prompt) and returns its exit code
    $p = Start-Process -FilePath $FilePath -ArgumentList $Arguments -Verb RunAs -Wait -PassThru
    return $p.ExitCode
}

function Install-NetFramework {
    $build   = [int](Get-CimInstance Win32_OperatingSystem).BuildNumber
    $release = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full' -Name Release -ErrorAction SilentlyContinue).Release
    Write-Host '[!] No C# compiler (csc.exe) found in the .NET Framework folder.' -ForegroundColor Yellow
    Write-Host ("    Installed .NET Framework 4.x release: {0}" -f $(if ($release) { $release } else { 'none' })) -ForegroundColor Gray

    # Step 1: enable the .NET Framework 4 feature that ships with Windows 10/11
    Write-Host '[*] Enabling the built-in .NET Framework 4 Windows feature (UAC prompt)...' -ForegroundColor Cyan
    try {
        $rc = Invoke-Elevated (Join-Path $env:WINDIR 'System32\dism.exe') '/Online /Enable-Feature /FeatureName:NetFx4-AdvSrvs /All /NoRestart /Quiet'
        Write-Host "    DISM exit code: $rc" -ForegroundColor Gray
    } catch {
        Write-Host "    Skipped: $($_.Exception.Message)" -ForegroundColor Yellow
    }
    if (Find-Csc) { return }

    # Step 2: download and install the .NET Framework Developer Pack
    #         4.8.1 needs Windows 10 21H2 (build 19044) or newer, older builds get 4.8
    if ($build -ge 19044) { $ver = '4.8.1'; $url = 'https://go.microsoft.com/fwlink/?linkid=2203306' }
    else                  { $ver = '4.8';   $url = 'https://go.microsoft.com/fwlink/?linkid=2088517' }
    $setup = Join-Path $env:TEMP ('ndp{0}-devpack-enu.exe' -f $ver.Replace('.', ''))

    try {
        Write-Host "[*] Downloading .NET Framework $ver Developer Pack from Microsoft..." -ForegroundColor Cyan
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -Uri $url -OutFile $setup -UseBasicParsing

        $sig = Get-AuthenticodeSignature -FilePath $setup
        if ($sig.Status -ne 'Valid' -or $sig.SignerCertificate.Subject -notmatch 'O=Microsoft Corporation') {
            throw 'The downloaded installer is not signed by Microsoft. It was not run.'
        }

        Write-Host "[*] Installing .NET Framework $ver Developer Pack (UAC prompt, this can take several minutes)..." -ForegroundColor Cyan
        $rc = Invoke-Elevated $setup '/q /norestart'
        switch ($rc) {
            0       { Write-Host "[+] .NET Framework $ver Developer Pack installed." -ForegroundColor Green }
            1641    { Write-Host "[+] Installed. A restart is required." -ForegroundColor Yellow }
            3010    { Write-Host "[+] Installed. A restart is required to finish." -ForegroundColor Yellow }
            1602    { Write-Host '[!] Installation was cancelled.' -ForegroundColor Yellow }
            5100    { Write-Host '[!] This PC does not meet the requirements for this .NET Framework version.' -ForegroundColor Yellow }
            default { Write-Host "[!] Installer ended with exit code $rc." -ForegroundColor Yellow }
        }
    } catch {
        Write-Host "[!] .NET Framework install failed: $($_.Exception.Message)" -ForegroundColor Yellow
    } finally {
        Remove-Item -LiteralPath $setup -Force -ErrorAction SilentlyContinue
    }
}

function Install-Roslyn {
    Write-Host '[!] Still no C# compiler found.' -ForegroundColor Yellow
    Write-Host '[*] Downloading portable Microsoft Roslyn compiler from NuGet...' -ForegroundColor Cyan
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $url = 'https://www.nuget.org/api/v2/package/Microsoft.Net.Compilers.Toolset/4.5.0'
    $zip = Join-Path $env:TEMP 'RoslynToolset.zip'
    Invoke-WebRequest -Uri $url -OutFile $zip -UseBasicParsing
    Write-Host '[*] Extracting compiler...' -ForegroundColor Cyan
    if (Test-Path -LiteralPath $RoslynDir) { Remove-Item -LiteralPath $RoslynDir -Recurse -Force }
    Expand-Archive -LiteralPath $zip -DestinationPath $RoslynDir -Force
    Remove-Item -LiteralPath $zip -Force -ErrorAction SilentlyContinue
}

# "1.2" / "v1.2.3" / "1.2.3-beta" -> "1.2.0.0" / "1.2.3.0" (numeric file version, max 4 parts, each 0-65534)
function ConvertTo-FileVersion([string]$Text) {
    $m = [regex]::Match($Text.Trim(), '^[vV]?(\d{1,5}(?:\.\d{1,5}){0,3})(?:[-+ ].*)?$')
    if (-not $m.Success) { return $null }
    $parts = New-Object System.Collections.Generic.List[int]
    foreach ($p in $m.Groups[1].Value.Split('.')) {
        $n = [int]$p
        if ($n -gt 65534) { return $null }
        $parts.Add($n)
    }
    while ($parts.Count -lt 4) { $parts.Add(0) }
    return ($parts -join '.')
}

function ConvertTo-CSharpString([string]$Text) {
    return $Text.Replace('"', '""')
}

try {
    # 1. Validate input
    $item = Get-Item -LiteralPath $Source
    $ext  = $item.Extension.ToLowerInvariant()
    if (@('.ps1', '.cmd', '.bat') -notcontains $ext) {
        throw "Unsupported file type '$ext'. Use a .cmd, .bat or .ps1 file."
    }
    $IsPs   = ($ext -eq '.ps1')
    $OutExe = Join-Path $item.DirectoryName ($item.BaseName + '.exe')

    Write-Host ("[*] Source : {0}" -f $item.FullName) -ForegroundColor Gray
    Write-Host ("[*] Type   : {0}" -f $(if ($IsPs) { 'PowerShell script' } else { 'Batch script' })) -ForegroundColor Gray
    Write-Host ("[*] Admin  : {0}" -f $(if ($Admin) { 'Yes (requireAdministrator)' } else { 'No (asInvoker)' })) -ForegroundColor Gray

    if ($item.Length -eq 0) { throw 'The script file is empty.' }

    # 2. PowerShell syntax check
    if ($IsPs) {
        Write-Host '[*] Checking PowerShell syntax...' -ForegroundColor Gray
        $tokens = $null; $errs = $null
        [System.Management.Automation.Language.Parser]::ParseFile($item.FullName, [ref]$tokens, [ref]$errs) | Out-Null
        if ($errs -and $errs.Count -gt 0) {
            $errs | ForEach-Object { Write-Host ("    Line {0}: {1}" -f $_.Extent.StartLineNumber, $_.Message) -ForegroundColor Red }
            throw 'The script has syntax errors.'
        }
        Write-Host '[+] Syntax OK.' -ForegroundColor Green
    }

    # 2b. Version number (suggests the version of an existing EXE with the same name)
    $DefaultVer = '1.0.0'
    if (Test-Path -LiteralPath $OutExe) {
        $oldVer = (Get-Item -LiteralPath $OutExe).VersionInfo.ProductVersion
        if ($oldVer -and (ConvertTo-FileVersion $oldVer)) { $DefaultVer = $oldVer.Trim() }
    }
    while ($true) {
        $answer = Read-Host ("Version number for {0}.exe [Enter = {1}]" -f $item.BaseName, $DefaultVer)
        if ([string]::IsNullOrWhiteSpace($answer)) { $answer = $DefaultVer }
        $ProductVer = $answer.Trim()
        $FileVer    = ConvertTo-FileVersion $ProductVer
        if ($FileVer) { break }
        Write-Host '[!] Invalid version. Use numbers like 1.2, 1.2.3 or 1.2.3.4 (a suffix such as 1.2.3-beta is allowed).' -ForegroundColor Yellow
    }
    Write-Host ("[*] Version: {0}  (file version {1})" -f $ProductVer, $FileVer) -ForegroundColor Gray

    # 2c. Owner name (suggests the owner of an existing EXE with the same name, else the Windows user)
    $DefaultOwner = $env:USERNAME
    if (Test-Path -LiteralPath $OutExe) {
        $oldInfo = (Get-Item -LiteralPath $OutExe).VersionInfo
        $oldCopy = [regex]::Match([string]$oldInfo.LegalCopyright, '^(?:Copyright\s*)?(?:\(c\))?\s*(?:\d{4}(?:-\d{4})?)?\s*(.+)$')
        if ($oldInfo.CompanyName) { $DefaultOwner = $oldInfo.CompanyName.Trim() }
        elseif ($oldCopy.Success -and $oldCopy.Groups[1].Value.Trim()) { $DefaultOwner = $oldCopy.Groups[1].Value.Trim() }
    }
    while ($true) {
        $answer = Read-Host ("Owner name for the copyright [Enter = {0}]" -f $DefaultOwner)
        if ([string]::IsNullOrWhiteSpace($answer)) { $answer = $DefaultOwner }
        $Owner = ($answer -replace '[\x00-\x1F]', '').Trim()
        if ($Owner) { break }
        Write-Host '[!] The owner name cannot be empty.' -ForegroundColor Yellow
    }
    $Copyright = "Copyright (c) {0} {1}" -f (Get-Date).Year, $Owner
    Write-Host ("[*] Copyright: {0}" -f $Copyright) -ForegroundColor Gray

    # 3. Compiler
    Write-Host '[*] Checking for C# compiler (csc.exe)...' -ForegroundColor Gray
    $csc = Find-Csc
    if (-not $csc) { Install-NetFramework; $csc = Find-Csc }
    if (-not $csc) { Install-Roslyn;       $csc = Find-Csc }
    if (-not $csc) { throw 'Could not find or install csc.exe. Check your internet connection, restart the PC and try again.' }
    Write-Host "[+] Using compiler: $csc" -ForegroundColor Green

    # 4. Generate sources. The script is embedded byte-for-byte as a resource,
    #    so its encoding (ANSI, UTF-8, BOM or not) stays exactly as it was.
    New-Item -ItemType Directory -Path $WorkDir -Force | Out-Null
    $payload = Join-Path $WorkDir 'payload.bin'
    $csFile  = Join-Path $WorkDir 'wrapper.cs'
    $manFile = Join-Path $WorkDir 'app.manifest'
    Copy-Item -LiteralPath $item.FullName -Destination $payload -Force

    $csharp = @'
using System;
using System.IO;
using System.Text;
using System.Reflection;
using System.Diagnostics;

// These attributes become the "Details" tab in the EXE's file properties
[assembly: AssemblyTitle(@"__TITLE__")]
[assembly: AssemblyDescription(@"__TITLE__")]
[assembly: AssemblyProduct(@"__TITLE__")]
[assembly: AssemblyCopyright(@"__COPYRIGHT__")]
[assembly: AssemblyCompany(@"__OWNER__")]
[assembly: AssemblyVersion("__FILEVER__")]
[assembly: AssemblyFileVersion("__FILEVER__")]
[assembly: AssemblyInformationalVersion(@"__PRODVER__")]

namespace ScriptExe
{
    class Program
    {
        const string ScriptName = @"__NAME__";
        const bool IsPowerShell = __ISPS__;

        static int Main(string[] args)
        {
            string dir = Path.Combine(Path.GetTempPath(), "ScriptExe_" + Guid.NewGuid().ToString("N"));
            string script = Path.Combine(dir, ScriptName);
            try
            {
                Directory.CreateDirectory(dir);
                using (Stream r = Assembly.GetExecutingAssembly().GetManifestResourceStream("ScriptPayload"))
                using (FileStream f = File.Create(script))
                {
                    r.CopyTo(f);
                }

                // Use 64-bit system tools on 64-bit Windows even if this process runs as 32-bit
                string sysDir = Environment.SystemDirectory;
                if (Environment.Is64BitOperatingSystem && !Environment.Is64BitProcess)
                    sysDir = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.Windows), "Sysnative");

                StringBuilder a = new StringBuilder();
                foreach (string s in args) a.Append(" \"" + s.Replace("\"", "") + "\"");

                string exe, argLine;
                if (IsPowerShell)
                {
                    exe = Path.Combine(sysDir, @"WindowsPowerShell\v1.0\powershell.exe");
                    argLine = "-NoProfile -ExecutionPolicy Bypass -File \"" + script + "\"" + a.ToString();
                }
                else
                {
                    exe = Path.Combine(sysDir, "cmd.exe");
                    argLine = "/d /c \"\"" + script + "\"" + a.ToString() + "\"";
                }
                if (!File.Exists(exe)) exe = Path.GetFileName(exe);

                string self = Assembly.GetExecutingAssembly().Location;
                ProcessStartInfo psi = new ProcessStartInfo(exe, argLine);
                psi.UseShellExecute = false;
                psi.EnvironmentVariables["EXE_PATH"] = self;
                psi.EnvironmentVariables["EXE_DIR"]  = Path.GetDirectoryName(self) + "\\";

                using (Process p = Process.Start(psi))
                {
                    p.WaitForExit();
                    return p.ExitCode;
                }
            }
            catch (Exception ex)
            {
                Console.Error.WriteLine("[ERROR] " + ex.Message);
                return 1;
            }
            finally
            {
                try { Directory.Delete(dir, true); } catch { }
            }
        }
    }
}
'@
    $csharp = $csharp.Replace('__NAME__', $item.Name.Replace('"', '""'))
    $csharp = $csharp.Replace('__ISPS__', $(if ($IsPs) { 'true' } else { 'false' }))
    $csharp = $csharp.Replace('__TITLE__', (ConvertTo-CSharpString $item.BaseName))
    $csharp = $csharp.Replace('__COPYRIGHT__', (ConvertTo-CSharpString $Copyright))
    $csharp = $csharp.Replace('__OWNER__', (ConvertTo-CSharpString $Owner))
    $csharp = $csharp.Replace('__FILEVER__', $FileVer)
    $csharp = $csharp.Replace('__PRODVER__', (ConvertTo-CSharpString $ProductVer))
    $utf8 = New-Object System.Text.UTF8Encoding($true)
    [IO.File]::WriteAllText($csFile, $csharp, $utf8)

    $level = if ($Admin) { 'requireAdministrator' } else { 'asInvoker' }
    $manifest = @'
<?xml version="1.0" encoding="utf-8"?>
<assembly manifestVersion="1.0" xmlns="urn:schemas-microsoft-com:asm.v1">
  <assemblyIdentity version="1.0.0.0" name="ScriptExe.app"/>
  <trustInfo xmlns="urn:schemas-microsoft-com:asm.v2">
    <security>
      <requestedPrivileges xmlns="urn:schemas-microsoft-com:asm.v3">
        <requestedExecutionLevel level="__LEVEL__" uiAccess="false" />
      </requestedPrivileges>
    </security>
  </trustInfo>
  <compatibility xmlns="urn:schemas-microsoft-com:compatibility.v1">
    <application>
      <supportedOS Id="{8e0f7a12-bfb3-4fe8-b9a5-48fd50a15a9a}"/>
    </application>
  </compatibility>
</assembly>
'@
    [IO.File]::WriteAllText($manFile, $manifest.Replace('__LEVEL__', $level), $utf8)

    # 5. Compile
    Write-Host ("[*] Compiling {0}..." -f (Split-Path -Leaf $OutExe)) -ForegroundColor Cyan
    if (Test-Path -LiteralPath $OutExe) {
        try { Remove-Item -LiteralPath $OutExe -Force }
        catch { throw "Cannot overwrite '$OutExe'. Close it if it is running and try again." }
    }
    & $csc /nologo /target:exe /platform:anycpu /optimize+ "/win32manifest:$manFile" "/resource:$payload,ScriptPayload" "/out:$OutExe" $csFile
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $OutExe)) { throw "csc.exe failed (exit code $LASTEXITCODE)." }

    $built = Get-Item -LiteralPath $OutExe
    Write-Host ("[+] Built: {0} ({1:N0} KB)" -f $OutExe, ($built.Length / 1KB)) -ForegroundColor Green
    Write-Host ("[+] File version: {0}   Product version: {1}" -f $built.VersionInfo.FileVersion, $built.VersionInfo.ProductVersion) -ForegroundColor Green
    Write-Host ("[+] Copyright: {0}" -f $built.VersionInfo.LegalCopyright) -ForegroundColor Green
    exit 0
}
catch {
    Write-Host "[ERROR] $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    if (Test-Path -LiteralPath $WorkDir) { Remove-Item -LiteralPath $WorkDir -Recurse -Force -ErrorAction SilentlyContinue }
}
