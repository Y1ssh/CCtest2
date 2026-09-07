<#
.SYNOPSIS
    Inventories software installed on a Windows PC.

.DESCRIPTION
    Reports installed applications (registry + winget), WSL distributions,
    developer toolchains found on PATH, and package-manager globals.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File inventory.ps1
    powershell -ExecutionPolicy Bypass -File inventory.ps1 -OutFile inventory.txt
#>
param(
    [string]$OutFile
)

if ($OutFile) { Start-Transcript -Path $OutFile -Force | Out-Null }

function Write-Section($Title) {
    Write-Host ""
    Write-Host ("=" * 70)
    Write-Host "  $Title"
    Write-Host ("=" * 70)
}

function Get-ToolVersion($Command, $VersionArgs) {
    $path = (Get-Command $Command -ErrorAction SilentlyContinue).Source
    if (-not $path) { return $null }
    $version = "(installed)"
    try {
        # Take the first line containing a digit, not the first line outright:
        # gradle and perl lead with blank lines and separator rules.
        $lines = & $Command @VersionArgs 2>&1 | ForEach-Object { ($_ | Out-String).Trim() }
        $raw = $lines | Where-Object { $_ -match '\d' } | Select-Object -First 1
        if (-not $raw) { $raw = $lines | Select-Object -First 1 }
        if ($raw) {
            $version = if ($raw.Length -gt 58) { $raw.Substring(0, 58) } else { $raw }
        }
    } catch { }
    [pscustomobject]@{ Tool = $Command; Version = $version; Path = $path }
}

Write-Section "SYSTEM"
$os = Get-CimInstance Win32_OperatingSystem
$cs = Get-CimInstance Win32_ComputerSystem
[pscustomobject]@{
    ComputerName = $env:COMPUTERNAME
    OS           = $os.Caption
    Version      = "$($os.Version) (Build $($os.BuildNumber))"
    Architecture = $os.OSArchitecture
    CPU          = (Get-CimInstance Win32_Processor | Select-Object -First 1).Name
    RAM_GB       = [math]::Round($cs.TotalPhysicalMemory / 1GB, 1)
    PowerShell   = $PSVersionTable.PSVersion.ToString()
} | Format-List

Write-Section "INSTALLED APPLICATIONS (registry)"
$uninstallKeys = @(
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'
    'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
    'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'
)
$apps = Get-ItemProperty $uninstallKeys -ErrorAction SilentlyContinue |
    Where-Object { $_.DisplayName -and -not $_.SystemComponent } |
    Select-Object DisplayName, DisplayVersion, Publisher, InstallDate |
    Sort-Object DisplayName -Unique
Write-Host "Found $($apps.Count) applications."
$apps | Format-Table -AutoSize

Write-Section "WINGET PACKAGES"
if (Get-Command winget -ErrorAction SilentlyContinue) {
    winget list --disable-interactivity 2>&1
} else {
    Write-Host "winget not installed."
}

Write-Section "WSL"
if (Get-Command wsl -ErrorAction SilentlyContinue) {
    Write-Host "--- Distributions ---"
    # WSL emits UTF-16; force the console to read it correctly.
    $prev = [Console]::OutputEncoding
    [Console]::OutputEncoding = [System.Text.Encoding]::Unicode
    wsl --list --verbose 2>&1
    Write-Host "--- WSL version ---"
    wsl --version 2>&1
    [Console]::OutputEncoding = $prev
} else {
    Write-Host "WSL not installed."
}

Write-Section "DEVELOPER TOOLCHAINS"
$tools = @(
    @{ c = 'git';      a = @('--version') }
    @{ c = 'gh';       a = @('--version') }
    @{ c = 'node';     a = @('--version') }
    @{ c = 'npm';      a = @('--version') }
    @{ c = 'yarn';     a = @('--version') }
    @{ c = 'pnpm';     a = @('--version') }
    @{ c = 'bun';      a = @('--version') }
    @{ c = 'deno';     a = @('--version') }
    @{ c = 'python';   a = @('--version') }
    @{ c = 'py';       a = @('--version') }
    @{ c = 'pip';      a = @('--version') }
    @{ c = 'conda';    a = @('--version') }
    @{ c = 'uv';       a = @('--version') }
    @{ c = 'poetry';   a = @('--version') }
    @{ c = 'ruby';     a = @('--version') }
    @{ c = 'go';       a = @('version')   }
    @{ c = 'rustc';    a = @('--version') }
    @{ c = 'cargo';    a = @('--version') }
    @{ c = 'java';     a = @('-version')  }
    @{ c = 'javac';    a = @('-version')  }
    @{ c = 'mvn';      a = @('--version') }
    @{ c = 'gradle';   a = @('--version') }
    @{ c = 'dotnet';   a = @('--version') }
    @{ c = 'php';      a = @('--version') }
    @{ c = 'perl';     a = @('--version') }
    @{ c = 'docker';   a = @('--version') }
    @{ c = 'kubectl';  a = @('version', '--client') }
    @{ c = 'terraform';a = @('--version') }
    @{ c = 'aws';      a = @('--version') }
    @{ c = 'az';       a = @('--version') }
    @{ c = 'gcloud';   a = @('--version') }
    @{ c = 'psql';     a = @('--version') }
    @{ c = 'mysql';    a = @('--version') }
    @{ c = 'sqlite3';  a = @('--version') }
    @{ c = 'code';     a = @('--version') }
    @{ c = 'claude';   a = @('--version') }
    @{ c = 'ffmpeg';   a = @('-version')  }
    @{ c = 'make';     a = @('--version') }
    @{ c = 'cmake';    a = @('--version') }
)
$found   = [System.Collections.Generic.List[object]]::new()
$missing = [System.Collections.Generic.List[string]]::new()
foreach ($t in $tools) {
    $result = Get-ToolVersion $t.c $t.a
    if ($result) { $found.Add($result) } else { $missing.Add($t.c) }
}
$found | Format-Table -AutoSize -Wrap
Write-Host "Not found on PATH: $($missing -join ', ')"

Write-Section "GLOBAL PACKAGES"
if (Get-Command npm -ErrorAction SilentlyContinue) {
    Write-Host "--- npm -g ---"
    npm ls -g --depth=0 2>$null
}
if (Get-Command pip -ErrorAction SilentlyContinue) {
    Write-Host "--- pip ---"
    pip list 2>$null
}

Write-Section "SERVICES (running)"
Get-Service | Where-Object Status -eq 'Running' |
    Select-Object Name, DisplayName | Sort-Object Name | Format-Table -AutoSize

if ($OutFile) {
    Stop-Transcript | Out-Null
    Write-Host "`nSaved to $OutFile"
}
