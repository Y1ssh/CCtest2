# CCtest2

## Software inventory scripts

Two scripts that report what is installed on a machine — OS details, installed
applications, WSL distributions, developer toolchains, and package-manager
globals.

### Windows

```powershell
powershell -ExecutionPolicy Bypass -File inventory.ps1
powershell -ExecutionPolicy Bypass -File inventory.ps1 -OutFile inventory.txt
```

Reports installed apps from the registry uninstall keys (64-bit, 32-bit, and
per-user), `winget list`, WSL distributions and versions, developer tools on
PATH, npm/pip globals, and running services.

### Linux, WSL, macOS

```bash
./inventory.sh
./inventory.sh > inventory.txt
```

Reports OS and kernel details, whether it is running under WSL, developer tools
on PATH, system packages (dpkg / rpm / Homebrew / pacman), and npm, pip, gem,
and cargo globals.

Both scripts are read-only — they install nothing and change no settings.
