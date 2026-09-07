#!/usr/bin/env bash
# Inventories software installed on a Linux, WSL, or macOS machine.
#
# Usage:
#   ./inventory.sh              # print to stdout
#   ./inventory.sh > out.txt    # save to a file

set -uo pipefail

section() {
    printf '\n%s\n  %s\n%s\n' "$(printf '=%.0s' {1..70})" "$1" "$(printf '=%.0s' {1..70})"
}

# Print "<tool>  <version>  <path>" for tools that exist on PATH.
# Java and friends print to stderr, so 2>&1 is required throughout. Take the
# first line containing a digit rather than the first line outright: gradle and
# perl lead with blank lines and separator rules before the actual version.
report_tool() {
    local cmd=$1; shift
    local path
    path=$(command -v "$cmd" 2>/dev/null) || return 1
    local out version
    out=$("$cmd" "$@" 2>&1 | grep -v 'Picked up')
    version=$(printf '%s\n' "$out" | grep -m1 -E '[0-9]')
    [ -z "$version" ] && version=$(printf '%s\n' "$out" | head -1)
    version=$(printf '%.58s' "${version:-(installed)}")
    printf '%-12s %-58s %s\n' "$cmd" "$version" "$path"
}

section "SYSTEM"
if [ -r /etc/os-release ]; then
    . /etc/os-release
    echo "OS:        ${PRETTY_NAME:-$NAME}"
elif [ "$(uname -s)" = "Darwin" ]; then
    echo "OS:        macOS $(sw_vers -productVersion 2>/dev/null)"
fi
echo "Kernel:    $(uname -sr)"
echo "Arch:      $(uname -m)"
echo "Host:      $(hostname)"
echo "Shell:     ${SHELL:-unknown}"
if grep -qi microsoft /proc/version 2>/dev/null; then
    echo "WSL:       yes — this is a WSL distro (${WSL_DISTRO_NAME:-unknown})"
else
    echo "WSL:       no"
fi
command -v nproc >/dev/null && echo "CPUs:      $(nproc)"
command -v free  >/dev/null && echo "RAM:       $(free -h | awk '/^Mem:/{print $2}')"

section "DEVELOPER TOOLCHAINS"
missing=()
while IFS='|' read -r cmd args; do
    [ -z "$cmd" ] && continue
    # shellcheck disable=SC2086
    report_tool "$cmd" $args || missing+=("$cmd")
done <<'TOOLS'
git|--version
gh|--version
node|--version
npm|--version
yarn|--version
pnpm|--version
bun|--version
deno|--version
python3|--version
pip3|--version
uv|--version
poetry|--version
pipx|--version
conda|--version
ruby|--version
gem|--version
go|version
rustc|--version
cargo|--version
java|-version
javac|-version
mvn|--version
gradle|--version
dotnet|--version
php|--version
composer|--version
perl|-v
gcc|--version
g++|--version
clang|--version
make|--version
cmake|--version
docker|--version
podman|--version
kubectl|version --client
helm|version
terraform|--version
aws|--version
az|--version
gcloud|--version
psql|--version
mysql|--version
sqlite3|--version
redis-cli|--version
mongosh|--version
curl|--version
wget|--version
jq|--version
rg|--version
fzf|--version
vim|--version
nvim|--version
tmux|-V
code|--version
claude|--version
ffmpeg|-version
pandoc|--version
TOOLS
printf '\nNot found on PATH: %s\n' "${missing[*]:-none}"

section "SYSTEM PACKAGES"
if command -v dpkg-query >/dev/null; then
    echo "Debian/Ubuntu — $(dpkg-query -f '.\n' -W 2>/dev/null | wc -l) packages installed"
    dpkg-query -W -f='${Package}\t${Version}\n' 2>/dev/null | sort
elif command -v rpm >/dev/null; then
    echo "RPM — $(rpm -qa | wc -l) packages installed"
    rpm -qa --qf '%{NAME}\t%{VERSION}\n' | sort
elif command -v brew >/dev/null; then
    echo "--- Homebrew formulae ---"; brew list --formula --versions
    echo "--- Homebrew casks ---";    brew list --cask --versions
elif command -v pacman >/dev/null; then
    pacman -Q
else
    echo "No recognized system package manager."
fi

section "GLOBAL LANGUAGE PACKAGES"
if command -v npm >/dev/null; then
    echo "--- npm -g ---"; npm ls -g --depth=0 2>/dev/null | tail -n +2
fi
if command -v pip3 >/dev/null; then
    echo "--- pip ---"; pip3 list 2>/dev/null
fi
if command -v gem >/dev/null; then
    echo "--- gem ---"; gem list --local 2>/dev/null | head -50
fi
if command -v cargo >/dev/null; then
    echo "--- cargo ---"; cargo install --list 2>/dev/null
fi

section "DONE"
