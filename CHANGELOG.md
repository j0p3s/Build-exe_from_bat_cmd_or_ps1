# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project uses [Semantic Versioning](https://semver.org/).

## [1.0.0] - 2026-10-24

### Added

- Build a self-contained `.exe` from a dropped `.bat`, `.cmd` or `.ps1` file.
- Build several scripts at once by dropping them together.
- Interactive mode: double-click and drag a script into the window.
- Automatic use of the built-in .NET Framework C# compiler, with automatic download of the portable Microsoft Roslyn compiler from NuGet when it is missing.
- Prompt for UAC elevation (`asInvoker` or `requireAdministrator`).
- Prompt for a version number, written to *File version* and *Product version*.
- Prompt for an owner name, written to *Copyright* and *Company*.
- Previous version and owner suggested when rebuilding an existing EXE.
- PowerShell syntax check before building, with line numbers.
- Script embedded byte-for-byte, keeping its original encoding.
- Arguments passed through to the script and its exit code returned by the EXE.
- `EXE_DIR` and `EXE_PATH` environment variables for scripts that need files next to the EXE.

[1.0.0]: https://github.com/j0p3s/Build-exe_from_bat_cmd_or_ps1/releases/tag/v1.0.0
