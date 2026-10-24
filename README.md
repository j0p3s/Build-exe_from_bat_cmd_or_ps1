# Build-exe from .bat, .cmd or .ps1

Turn any Windows batch (`.bat` / `.cmd`) or PowerShell (`.ps1`) script into a single, self-contained `.exe` — with your own version number and copyright in the file properties.

No installs, no Visual Studio, no third-party tools. Just drag and drop.

![Windows 10/11](https://img.shields.io/badge/Windows-10%20%7C%2011-0078D6)
![License: MIT](https://img.shields.io/badge/License-MIT-green)

---

## Features

- **Drag and drop** one or more scripts onto `Build-exe.bat` — each one becomes `<name>.exe` next to the script.
- **Works out of the box** — uses the C# compiler built into Windows (.NET Framework 4.x). If it is missing, it downloads the portable Microsoft Roslyn compiler from NuGet automatically.
- **File properties** — asks for a **version number** and an **owner name**, and writes them to the EXE's *Properties → Details* tab (File version, Product version, Copyright).
- **Optional UAC elevation** — choose whether the EXE asks for administrator rights when started.
- **Your script is untouched** — it is embedded byte-for-byte, so its encoding (ANSI, UTF-8, with or without BOM, accented characters) stays exactly as it was.
- **PowerShell syntax check** — `.ps1` files are parsed before building, and errors are shown with line numbers.
- **Arguments and exit codes** — arguments passed to the EXE go to the script, and the EXE returns the script's exit code.
- **64-bit aware** — always runs the 64-bit `cmd.exe` / `powershell.exe` on 64-bit Windows.

## Requirements

- Windows 10 or Windows 11
- Windows PowerShell 5.1 (included with Windows 10/11)
- Internet connection **only** if the built-in C# compiler is missing

## Usage

1. Download `Build-exe.bat`.
2. Drag your `.bat`, `.cmd` or `.ps1` file onto it.
   (Or double-click `Build-exe.bat` and drag the script into the window, then press **Enter**.)
3. Answer the questions:

   | Question | Example | Default |
   |---|---|---|
   | Should the EXE ask for administrator rights (UAC)? | `Y` / `N` | `N` after 30 seconds |
   | Version number | `1.2.3` | Version of the existing EXE, or `1.0.0` |
   | Owner name for the copyright | `j0p3s` | Owner of the existing EXE, or your Windows user name |

4. The EXE is created in the same folder as the script.

```
--------------------------------------------------------
Should the EXE ask for administrator rights (UAC) when started [Y,N]?N
[*] Source : C:\Tools\MyScript.ps1
[*] Type   : PowerShell script
[*] Admin  : No (asInvoker)
[*] Checking PowerShell syntax...
[+] Syntax OK.
Version number for MyScript.exe [Enter = 1.0.0]: 1.2.0
[*] Version: 1.2.0  (file version 1.2.0.0)
Owner name for the copyright [Enter = Joao]: j0p3s
[*] Copyright: Copyright (c) 2026 j0p3s
[*] Checking for C# compiler (csc.exe)...
[+] Using compiler: C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe
[*] Compiling MyScript.exe...
[+] Built: C:\Tools\MyScript.exe (12 KB)
[+] File version: 1.2.0.0   Product version: 1.2.0
[+] Copyright: Copyright (c) 2026 j0p3s
```

### Version formats

| You type | File version | Product version |
|---|---|---|
| `1` | `1.0.0.0` | `1` |
| `1.2.3` | `1.2.3.0` | `1.2.3` |
| `v2.0` | `2.0.0.0` | `v2.0` |
| `1.2.3-beta` | `1.2.3.0` | `1.2.3-beta` |
| `1.2.3.4` | `1.2.3.4` | `1.2.3.4` |

Each number can be from `0` to `65534`.

### What goes into the file properties

| Field | Value |
|---|---|
| File description | Script name |
| Product name | Script name |
| File version | Numeric version (4 parts) |
| Product version | Version exactly as typed |
| Copyright | `Copyright (c) <year> <owner>` |
| Company | Owner name (not shown in the Details tab, but read by other tools) |

When you rebuild an existing EXE, the builder suggests its current version and owner, so you can just press **Enter**.

## How it works

1. The script is copied byte-for-byte and embedded in the EXE as a resource.
2. A small C# launcher is generated and compiled with `csc.exe`, together with a manifest (`asInvoker` or `requireAdministrator`) and the version information.
3. When the EXE runs, it extracts the script to a unique folder in `%TEMP%` (keeping its original file name), runs it with `cmd.exe /d /c` or `powershell.exe -NoProfile -ExecutionPolicy Bypass -File`, waits for it to finish, and deletes the temporary folder.

## Things to know

### `%~dp0` and `$PSScriptRoot` point to `%TEMP%`

The script runs from a temporary folder, so `%~dp0` (batch) and `$PSScriptRoot` (PowerShell) point there — **not** to the folder the EXE is in. If your script needs files next to it, use the variables the EXE sets:

| Variable | Batch | PowerShell | Value |
|---|---|---|---|
| `EXE_DIR` | `%EXE_DIR%` | `$env:EXE_DIR` | Folder of the EXE, with trailing `\` |
| `EXE_PATH` | `%EXE_PATH%` | `$env:EXE_PATH` | Full path of the EXE |

A script that works both as a script and as an EXE:

```bat
if defined EXE_DIR (set "HERE=%EXE_DIR%") else (set "HERE=%~dp0")
```

```powershell
$Here = if ($env:EXE_DIR) { $env:EXE_DIR } else { $PSScriptRoot }
```

See the [`examples`](examples) folder.

### Self-elevating scripts

Scripts that restart themselves as administrator (for example with `Start-Process -Verb RunAs` on `%~f0`) will fail, because the temporary copy is deleted when the first instance ends. Build those with **Y** for the administrator question instead — the EXE then starts elevated and the script does not need to restart itself.

### Antivirus warnings

Unsigned EXEs that wrap scripts are sometimes flagged by antivirus software as a false positive. If that happens, you can sign the EXE with your own code-signing certificate or submit it to your antivirus vendor for review.

### This is not obfuscation

The script is stored as-is inside the EXE and written to `%TEMP%` while it runs. Anyone can extract it. Do not put passwords or secrets in it.

## Debugging

To debug `Build-exe.bat` itself, or the scripts you build, you can use [Batch-debug](https://github.com/j0p3s/Batch-debug) — drag the script onto it to get a full log of every command and its output.

## License

[MIT](LICENSE)
