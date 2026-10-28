
#!/bin/sh
# Portable launcher: this program uses Bash features internally.
# If started by sh/dash/another POSIX shell, re-execute it with Bash.
# This lets users launch it from different shells, provided Bash is installed.
if [ -z "${BASH_VERSION:-}" ]; then
    if command -v bash >/dev/null 2>&1; then
        exec bash "$0" "$@"
    fi
    printf '%s\n' 'Error: Linux Mirror Manager requires Bash, but Bash was not found.' >&2
    exit 127
fi

# ============================================================
#  LINUX MIRROR MANAGER
#  Detect | Diagnose | Benchmark | Configure
#  Version 1.4.0: validate every active suite, component and APT architecture
#
#  Developed by: Parham Shyasi
#  GitHub: https://github.com/parham0541
#  Version: 1.4.0
# ============================================================

set -uo pipefail
export LC_ALL=C

APP="Linux Mirror Manager"
VERSION="1.4.0"
GITHUB="https://github.com/parham0541"

# -------------------- TERMINAL THEME -------------------------

if [[ -t 1 ]]; then
    RESET=$'\033[0m'
    BOLD=$'\033[1m'
    DIM=$'\033[2m'
    RED=$'\033[38;5;203m'
    GREEN=$'\033[38;5;82m'
    YELLOW=$'\033[38;5;220m'
    BLUE=$'\033[38;5;75m'
    CYAN=$'\033[38;5;87m'
    PURPLE=$'\033[38;5;177m'
    WHITE=$'\033[38;5;255m'
    ORANGE=$'\033[38;5;208m'
else
    RESET="" BOLD="" DIM=""
    RED="" GREEN="" YELLOW="" BLUE=""
    CYAN="" PURPLE="" WHITE="" ORANGE=""
fi

info()    { printf '  %s●%s %s\n' "$BLUE" "$RESET" "$*"; }
ok()      { printf '  %s✔%s %s\n' "$GREEN" "$RESET" "$*"; }
warn()    { printf '  %s⚠%s %s\n' "$YELLOW" "$RESET" "$*"; }
fail()    { printf '  %s✘%s %s\n' "$RED" "$RESET" "$*"; }

hr() {
    printf '%s%s%s\n' "$DIM" \
        "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" \
        "$RESET"
}

wait_key() {
    printf '\n  %sPress ENTER to continue...%s' "$DIM" "$RESET"
    read -r _ || true
}

# -------------------- ASCII BRANDING -------------------------

banner() {
    printf '\033[2J\033[H'
    printf '%s' "$CYAN"
    cat <<'ART'
  ██╗     ██╗███╗   ██╗██╗   ██╗██╗  ██╗
  ██║     ██║████╗  ██║██║   ██║╚██╗██╔╝
  ██║     ██║██╔██╗ ██║██║   ██║ ╚███╔╝
  ██║     ██║██║╚██╗██║██║   ██║ ██╔██╗
  ███████╗██║██║ ╚████║╚██████╔╝██╔╝ ██╗
  ╚══════╝╚═╝╚═╝  ╚═══╝ ╚═════╝ ╚═╝  ╚═╝

       M I R R O R   M A N A G E R
ART
    printf '%s' "$RESET"
    printf '  %sDetect%s  %s•%s  %sDiagnose%s  %s•%s  %sBenchmark%s  %s•%s  %sConfigure%s\n' \
        "$WHITE" "$RESET" "$DIM" "$RESET" \
        "$WHITE" "$RESET" "$DIM" "$RESET" \
        "$WHITE" "$RESET" "$DIM" "$RESET" \
        "$WHITE" "$RESET"
    hr
    printf '  %sDeveloped by%s  %sParham Shyasi%s\n' \
        "$DIM" "$RESET" "$BOLD" "$RESET"
    printf '  %sGitHub:%s %s\n' "$DIM" "$RESET" "$GITHUB"
    printf '  %sVersion %s%s\n\n' "$DIM" "$VERSION" "$RESET"
}

# -------------------- SYSTEM DETECTION -----------------------

detect_system() {
    if [[ ! -r /etc/os-release ]]; then
        fail "/etc/os-release not found."
        exit 1
    fi

    # shellcheck disable=SC1091
    . /etc/os-release

    OS_ID="${ID:-unknown}"
    OS_NAME="${PRETTY_NAME:-Unknown Linux}"
    OS_VERSION="${VERSION_ID:-unknown}"
    OS_CODENAME="${VERSION_CODENAME:-}"
    OS_FAMILY="unknown"
    PKG_MANAGER="unknown"

    ARCH="$(uname -m 2>/dev/null || echo unknown)"
    KERNEL="$(uname -r 2>/dev/null || echo unknown)"
    HOSTNAME_VALUE="$(hostname 2>/dev/null || echo unknown)"
    INIT_SYSTEM="unknown"

    [[ -n "${UBUNTU_CODENAME:-}" ]] &&
        OS_CODENAME="$UBUNTU_CODENAME"

    if command -v apt-get >/dev/null 2>&1; then
        PKG_MANAGER="APT"
    elif command -v dnf >/dev/null 2>&1; then
        PKG_MANAGER="DNF"
    elif command -v yum >/dev/null 2>&1; then
        PKG_MANAGER="YUM"
    elif command -v pacman >/dev/null 2>&1; then
        PKG_MANAGER="Pacman"
    elif command -v zypper >/dev/null 2>&1; then
        PKG_MANAGER="Zypper"
    fi

    case "$OS_ID" in
        ubuntu|xubuntu|kubuntu|lubuntu|pop|elementary)
            OS_FAMILY="ubuntu"
            ;;
        linuxmint)
            OS_FAMILY="mint"
            ;;
        debian)
            OS_FAMILY="debian"
            ;;
        kali)
            OS_FAMILY="kali"
            ;;
        fedora)
            OS_FAMILY="fedora"
            ;;
        rhel|centos|rocky|almalinux|ol|amzn)
            OS_FAMILY="rpm"
            ;;
        arch|manjaro|endeavouros)
            OS_FAMILY="arch"
            ;;
        opensuse*|sles)
            OS_FAMILY="suse"
            ;;
    esac

    if [[ -d /run/systemd/system ]]; then
        INIT_SYSTEM="systemd"
    elif command -v rc-service >/dev/null 2>&1; then
        INIT_SYSTEM="OpenRC"
    fi
}

show_system() {
    printf '\n'
    printf '  %s╭──────────────── SYSTEM PROFILE ────────────────╮%s\n' \
        "$PURPLE" "$RESET"
    printf '  │ Distribution : %-32.32s │\n' "$OS_NAME"
    printf '  │ OS ID        : %-32.32s │\n' "$OS_ID"
    printf '  │ Version      : %-32.32s │\n' "$OS_VERSION"
    printf '  │ Codename     : %-32.32s │\n' "${OS_CODENAME:-unknown}"
    printf '  │ Architecture : %-32.32s │\n' "$ARCH"
    printf '  │ Kernel       : %-32.32s │\n' "$KERNEL"
    printf '  │ Package tool : %-32.32s │\n' "$PKG_MANAGER"
    printf '  │ Init system  : %-32.32s │\n' "$INIT_SYSTEM"
    printf '  │ Hostname     : %-32.32s │\n' "$HOSTNAME_VALUE"
    printf '  ╰────────────────────────────────────────────────╯\n'
}

# -------------------- DEPENDENCY CHECK -----------------------

check_dependencies() {
    local cmd
    local missing=()

    for cmd in curl awk sed grep sort python3; do
        command -v "$cmd" >/dev/null 2>&1 || missing+=("$cmd")
    done

    if ((${#missing[@]} > 0)); then
        fail "Missing commands: ${missing[*]}"
        printf '  Install missing utilities and run this program again.\n'
        exit 1
    fi
}

# -------------------- MIRROR CATALOG -------------------------

# Format:
# region|name|base_url|family
#
# Iranian candidates appear first. A candidate is not trusted
# until its release metadata is tested successfully.

declare -a MIRRORS=()
declare -a RESULT_NAMES=()
declare -a RESULT_URLS=()
declare -a RESULT_TIMES=()
declare -a RESULT_REGIONS=()
declare -a RESULT_STATUS=()

add_mirror() {
    MIRRORS+=("$1|$2|$3|$4")
}

load_mirrors() {
    MIRRORS=()

    case "$OS_FAMILY" in
        ubuntu|mint)
            # IRAN — Ubuntu archive candidates
            add_mirror IR "Shatel" \
                "https://mirror.shatel.ir/ubuntu" ubuntu
            add_mirror IR "IUT Isfahan" \
                "https://repo.iut.ac.ir/ubuntu" ubuntu
            add_mirror IR "Pishgaman" \
                "https://ubuntu.pishgaman.net/ubuntu" ubuntu
            add_mirror IR "IranServer" \
                "https://mirror.iranserver.com/ubuntu" ubuntu
            add_mirror IR "ManageIT" \
                "https://manageit.ir/ubuntu" ubuntu
            add_mirror IR "KimiaHost" \
                "https://kimiahost.com/ubuntu" ubuntu
            add_mirror IR "Sindad" \
                "https://ir.ubuntu.sindad.cloud/ubuntu" ubuntu
            add_mirror IR "LinuxMirrors" \
                "https://linuxmirrors.ir/ubuntu" ubuntu
            add_mirror IR "Pardisco" \
                "https://mirrors.pardisco.co/ubuntu" ubuntu
            add_mirror IR "0-1 Cloud" \
                "https://0-1.cloud/ubuntu" ubuntu
            add_mirror IR "Iran archive" \
                "https://ir.archive.ubuntu.com/ubuntu" ubuntu

            # INTERNATIONAL — Ubuntu
            add_mirror GLOBAL "Official Ubuntu" \
                "https://archive.ubuntu.com/ubuntu" ubuntu
            add_mirror GLOBAL "Kernel.org" \
                "https://mirrors.edge.kernel.org/ubuntu" ubuntu
            add_mirror GLOBAL "University of Maryland" \
                "https://mirror.umd.edu/ubuntu" ubuntu
            add_mirror GLOBAL "Waterloo CSC" \
                "https://mirror.csclub.uwaterloo.ca/ubuntu" ubuntu
            add_mirror GLOBAL "Princeton" \
                "https://mirror.math.princeton.edu/pub/ubuntu" ubuntu
            ;;

        debian)
            # IRAN — Debian archive candidates
            add_mirror IR "FamaServer" \
                "https://mirror.famaserver.com/debian" debian
            add_mirror IR "Petiak" \
                "https://archive.debian.petiak.ir/debian" debian
            add_mirror IR "Shatel" \
                "https://mirror.shatel.ir/debian" debian
            add_mirror IR "IUT Isfahan" \
                "https://repo.iut.ac.ir/debian" debian
            add_mirror IR "IranServer" \
                "https://mirror.iranserver.com/debian" debian
            add_mirror IR "LinuxMirrors" \
                "https://linuxmirrors.ir/debian" debian
            add_mirror IR "Pardisco" \
                "https://mirrors.pardisco.co/debian" debian
            add_mirror IR "0-1 Cloud" \
                "https://0-1.cloud/debian" debian
            add_mirror IR "Abrha" \
                "https://repo.abrha.net/debian" debian
            add_mirror IR "MobinHost" \
                "https://mirror.mobinhost.com/debian" debian

            # INTERNATIONAL — Debian
            add_mirror GLOBAL "Official Debian CDN" \
                "https://deb.debian.org/debian" debian
            add_mirror GLOBAL "Germany" \
                "https://ftp.de.debian.org/debian" debian
            add_mirror GLOBAL "United States" \
                "https://ftp.us.debian.org/debian" debian
            add_mirror GLOBAL "UK Oxford" \
                "https://mirror.ox.ac.uk/debian" debian
            add_mirror GLOBAL "Kernel.org" \
                "https://mirrors.edge.kernel.org/debian" debian
            add_mirror GLOBAL "Japan RIKEN" \
                "https://ftp.riken.jp/Linux/debian/debian" debian
            add_mirror GLOBAL "India" \
                "https://debian.mirror.net.in/debian" debian
            ;;

        kali)
            # Kali must use Kali-compatible archive metadata.
            add_mirror GLOBAL "Official Kali HTTP" \
                "http://http.kali.org/kali" kali
            add_mirror GLOBAL "Official Kali HTTPS" \
                "https://archive.kali.org/kali" kali
            ;;

        fedora|rpm)
            warn "RPM catalog is not enabled for automatic configuration."
            warn "Fedora, RHEL, Rocky and AlmaLinux need separate metadata tests."
            ;;

        *)
            warn "No verified catalog is configured for $OS_NAME."
            ;;
    esac

    # Linux Mint uses Ubuntu repositories only for its Ubuntu base.
    # Mint's own repository is intentionally not replaced.
    if [[ "$OS_FAMILY" == "mint" ]]; then
        warn "Ubuntu base candidates only; Linux Mint repositories remain untouched."
    fi
}

# -------------------- MIRROR VALIDATION ----------------------

# Collect architectures enabled by dpkg. On Ubuntu this may include
# amd64 plus foreign architectures such as i386.
get_required_architectures() {
    local arch
    local -a arches=()

    command -v dpkg >/dev/null 2>&1 || return 1
    arch="$(dpkg --print-architecture 2>/dev/null)"
    [[ -n "$arch" ]] || return 1
    arches+=("$arch")

    while IFS= read -r arch; do
        [[ -n "$arch" ]] && arches+=("$arch")
    done < <(dpkg --print-foreign-architectures 2>/dev/null)

    # Print unique architecture names, one per line.
    printf '%s\n' "${arches[@]}" | awk 'NF && !seen[$0]++'
}

# Read the enabled official repository targets from both legacy .list and
# Deb822 .sources files. Output format: suite|component component ...
# Third-party repositories are deliberately ignored.
get_required_targets() {
    python3 - "$OS_FAMILY" "$OS_CODENAME" <<'PY_TARGETS'
import glob
import re
import sys
from pathlib import Path

family, codename = sys.argv[1:3]
files = [Path('/etc/apt/sources.list')]
files += [Path(p) for p in glob.glob('/etc/apt/sources.list.d/*.list')]
files += [Path(p) for p in glob.glob('/etc/apt/sources.list.d/*.sources')]

if family == 'ubuntu' or family == 'mint':
    official = re.compile(r'^https?://(?:[a-z]{2}\.)?archive\.ubuntu\.com/ubuntu(?:/|$)', re.I)
elif family == 'debian':
    official = re.compile(r'^https?://deb\.debian\.org/debian(?:/|$)', re.I)
else:
    print(f'{codename}|main')
    raise SystemExit(0)

targets = {}

def add(uri_list, suites, components):
    if not any(official.match(uri) for uri in uri_list):
        return
    for suite in suites:
        suite = suite.strip()
        if not suite or suite.startswith('/'): # path-style suites need a different layout
            continue
        comps = [c for c in components if c]
        if not comps:
            comps = ['main']
        targets.setdefault(suite, set()).update(comps)

for path in files:
    try:
        content = path.read_text(encoding='utf-8', errors='replace')
    except OSError:
        continue
    if path.suffix == '.sources':
        for paragraph in re.split(r'\n\s*\n', content):
            fields = {}
            current = None
            for line in paragraph.splitlines():
                if not line.strip() or line.lstrip().startswith('#'):
                    continue
                if line[:1].isspace() and current:
                    fields[current] += ' ' + line.strip()
                    continue
                match = re.match(r'^([A-Za-z][A-Za-z0-9-]*):\s*(.*)$', line)
                if match:
                    current = match.group(1).lower()
                    fields[current] = match.group(2).strip()
            if fields.get('enabled', 'yes').lower() == 'no':
                continue
            if 'deb' not in fields.get('types', 'deb').split():
                continue
            add(fields.get('uris', '').split(), fields.get('suites', '').split(),
                fields.get('components', '').split())
    else:
        for line in content.splitlines():
            line = line.split('#', 1)[0].strip()
            if not re.match(r'^deb\s+', line):
                continue
            rest = re.sub(r'^deb\s+', '', line)
            if rest.startswith('[') and ']' in rest:
                rest = rest.split(']', 1)[1].strip()
            tokens = rest.split()
            if len(tokens) < 2:
                continue
            uri, suite = tokens[0], tokens[1]
            add([uri], [suite], tokens[2:])

if not targets:
    targets[codename] = {'main'}
for suite in sorted(targets):
    print(suite + '|' + ' '.join(sorted(targets[suite])))
PY_TARGETS
}

# Validate actual Release metadata and Packages indexes for every active
# official suite/component and every enabled dpkg architecture. This catches
# mirrors that are reachable but incomplete (e.g. missing i386 Packages).
test_mirror() {
    local base="$1"
    local family="$2"
    local codename="$3"
    local result status elapsed metadata_url content
    local arch suite component suffix index_url release_arches release_components
    local target suite_components index_found arch_summary
    local -a required_arches=() targets=()

    case "$family" in
        ubuntu|debian)
            [[ -n "$codename" ]] || return 1
            ;;
        kali)
            metadata_url="${base%/}/dists/kali-rolling/Release"
            result="$(curl -L -sS --connect-timeout 5 --max-time 15 -o /dev/null \
                -w '%{http_code}|%{time_total}' "$metadata_url" 2>/dev/null)" || return 1
            IFS='|' read -r status elapsed <<< "$result"
            [[ "$status" == "200" ]] || return 1
            content="$(curl -fL -sS --connect-timeout 5 --max-time 15 "$metadata_url" 2>/dev/null)" || return 1
            grep -qE '^(Origin|Label|Suite|Codename|Date|Architectures|Components):' <<< "$content" || return 1
            printf '%s|%s|%s\n' "$elapsed" "$metadata_url" "kali"
            return 0
            ;;
        *) return 1 ;;
    esac

    mapfile -t required_arches < <(get_required_architectures) || return 1
    ((${#required_arches[@]} > 0)) || return 1
    mapfile -t targets < <(get_required_targets) || return 1
    ((${#targets[@]} > 0)) || return 1

    # The first Release fetch also provides the latency measurement.
    local first_suite="${targets[0]%%|*}"
    metadata_url="${base%/}/dists/${first_suite}/Release"
    result="$(curl -L -sS --connect-timeout 5 --max-time 15 -o /dev/null \
        -w '%{http_code}|%{time_total}' "$metadata_url" 2>/dev/null)" || return 1
    IFS='|' read -r status elapsed <<< "$result"
    [[ "$status" == "200" ]] || return 1

    for target in "${targets[@]}"; do
        suite="${target%%|*}"
        suite_components="${target#*|}"
        metadata_url="${base%/}/dists/${suite}/Release"
        content="$(curl -fL -sS --connect-timeout 4 --max-time 10 "$metadata_url" 2>/dev/null)" || {
            printf 'UNSUPPORTED|%s|Release metadata missing for suite %s\n' "${required_arches[0]}" "$suite"
            return 1
        }
        grep -qE '^(Origin|Label|Suite|Codename|Date|Architectures|Components):' <<< "$content" || {
            printf 'UNSUPPORTED|%s|Invalid Release metadata for suite %s\n' "${required_arches[0]}" "$suite"
            return 1
        }
        release_arches="$(awk -F': *' '$1 == "Architectures" {print $2; exit}' <<< "$content")"
        release_components="$(awk -F': *' '$1 == "Components" {print $2; exit}' <<< "$content")"

        for arch in "${required_arches[@]}"; do
            if [[ -n "$release_arches" && ! " $release_arches " =~ [[:space:]]${arch}[[:space:]] ]]; then
                printf 'UNSUPPORTED|%s|Release for %s does not list architecture %s\n' "$arch" "$suite" "$arch"
                return 1
            fi
            for component in $suite_components; do
                if [[ -n "$release_components" && ! " $release_components " =~ [[:space:]]${component}[[:space:]] ]]; then
                    printf 'UNSUPPORTED|%s|Release for %s does not list component %s\n' "$arch" "$suite" "$component"
                    return 1
                fi
                index_found=0
                for suffix in xz gz ''; do
                    index_url="${base%/}/dists/${suite}/${component}/binary-${arch}/Packages"
                    [[ -n "$suffix" ]] && index_url+=".${suffix}"
                    # HEAD checks existence without downloading multi-megabyte Packages indexes.
                    if curl -fIL -sS --connect-timeout 3 --max-time 6 \
                        -o /dev/null "$index_url" 2>/dev/null; then
                        index_found=1
                        break
                    fi
                done
                if (( index_found == 0 )); then
                    printf 'UNSUPPORTED|%s|suite=%s,component=%s,index=binary-%s/Packages\n' \
                        "$arch" "$suite" "$component" "$arch"
                    return 1
                fi
            done
        done
    done

    arch_summary="$(printf '%s ' "${required_arches[@]}" | sed 's/[[:space:]]*$//')"
    printf '%s|%s|%s\n' "$elapsed" "$metadata_url" "$arch_summary"
}

# -------------------- LOADING ANIMATION ----------------------

spinner_start() {
    local message="$1"
    local pid="$2"
    local frames=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
    local i=0

    while kill -0 "$pid" 2>/dev/null; do
        printf '\r  %s%s%s %s' \
            "$CYAN" "${frames[$i]}" "$RESET" "$message"
        i=$(((i + 1) % ${#frames[@]}))
        sleep 0.10
    done

    printf '\r%80s\r' ""
}

# -------------------- SCAN AND RANK --------------------------

scan_mirrors() {
    RESULT_NAMES=()
    RESULT_URLS=()
    RESULT_TIMES=()
    RESULT_REGIONS=()
    RESULT_STATUS=()

    local total="${#MIRRORS[@]}"
    local count=0
    local entry region name url family result elapsed metadata
    local temp_file pid

    if ((total == 0)); then
        warn "No mirror candidates available."
        return
    fi

    printf '\n'
    printf '  %s╭────────────── MIRROR DIAGNOSTICS ──────────────╮%s\n' \
        "$CYAN" "$RESET"

    if [[ "$PKG_MANAGER" == "APT" && ( "$OS_FAMILY" == "ubuntu" || "$OS_FAMILY" == "debian" || "$OS_FAMILY" == "mint" ) ]]; then
        local scan_arches
        scan_arches="$(get_required_architectures 2>/dev/null | paste -sd, -)"
        info "Required APT architectures: ${scan_arches:-unknown}"
        info "A mirror is accepted only if active architecture indexes are available."
    fi

    for entry in "${MIRRORS[@]}"; do
        IFS='|' read -r region name url family <<< "$entry"
        ((count += 1))

        printf '  %s[%02d/%02d]%s %-24s ' \
            "$DIM" "$count" "$total" "$RESET" "$name"

        temp_file="$(mktemp)" || {
            fail "Unable to create a temporary file."
            return
        }

        # Run the network test in the background to animate the UI.
        (
            test_mirror "$url" "$family" "$OS_CODENAME" > "$temp_file"
        ) &
        pid=$!

        spinner_start "Testing repository metadata..." "$pid"
        wait "$pid" || true

        result="$(cat "$temp_file" 2>/dev/null || true)"
        rm -f "$temp_file"

        if [[ "$result" == UNSUPPORTED\|* ]]; then
            local _tag bad_arch bad_reason
            IFS='|' read -r _tag bad_arch bad_reason <<< "$result"
            printf '%sUNSUITABLE%s  %s: %s\n' \
                "$RED" "$RESET" "$bad_arch" "$bad_reason"
        elif [[ -n "$result" ]]; then
            IFS='|' read -r elapsed metadata _supported_arches <<< "$result"

            RESULT_NAMES+=("$name")
            RESULT_URLS+=("$url")
            RESULT_TIMES+=("$elapsed")
            RESULT_REGIONS+=("$region")
            RESULT_STATUS+=("OK:${_supported_arches:-unknown}")

            printf '%sVALID%s  %ss  %s  [arch: %s]\n' \
                "$GREEN" "$RESET" "$elapsed" "$region" "${_supported_arches:-unknown}"
        else
            printf '%sUNAVAILABLE / INVALID METADATA%s\n' "$RED" "$RESET"
        fi
    done

    # Prioritize Iranian mirrors, then sort by response time.
    if ((${#RESULT_NAMES[@]} > 1)); then
        local sorted
        sorted="$(
            for count in "${!RESULT_NAMES[@]}"; do
                local priority=1
                [[ "${RESULT_REGIONS[$count]}" == "IR" ]] && priority=0
                printf '%s %s %s\n' \
                    "$priority" "${RESULT_TIMES[$count]}" "$count"
            done | sort -n -k1,1 -k2,2
        )"

        local -a names=() urls=() times=() regions=() statuses=()
        local priority index

        while read -r priority elapsed index; do
            [[ "$index" =~ ^[0-9]+$ ]] || continue

            names+=("${RESULT_NAMES[$index]}")
            urls+=("${RESULT_URLS[$index]}")
            times+=("${RESULT_TIMES[$index]}")
            regions+=("${RESULT_REGIONS[$index]}")
            statuses+=("${RESULT_STATUS[$index]}")
        done <<< "$sorted"

        RESULT_NAMES=("${names[@]}")
        RESULT_URLS=("${urls[@]}")
        RESULT_TIMES=("${times[@]}")
        RESULT_REGIONS=("${regions[@]}")
        RESULT_STATUS=("${statuses[@]}")
    fi

    printf '  %s╰───────────────────────────────────────────────╯%s\n' \
        "$CYAN" "$RESET"
}

# -------------------- RESULTS TABLE --------------------------

show_results() {
    printf '\n'
    printf '  %s╔════════════════════════════════════════════════════════════════════╗%s\n' \
        "$PURPLE" "$RESET"
    printf '  %s║                       MIRROR LEADERBOARD                          ║%s\n' \
        "$PURPLE" "$RESET"
    printf '  %s╚════════════════════════════════════════════════════════════════════╝%s\n' \
        "$PURPLE" "$RESET"

    if ((${#RESULT_NAMES[@]} == 0)); then
        warn "No mirror passed the metadata check."
        warn "Check your internet connection or try again later."
        return
    fi

    printf '  %-4s %-9s %-25s %-12s %s\n' \
        "NO." "REGION" "MIRROR" "SECONDS" "BASE URL"
    hr

    local i region_label
    for i in "${!RESULT_NAMES[@]}"; do
        region_label="GLOBAL"
        [[ "${RESULT_REGIONS[$i]}" == "IR" ]] && region_label="IRAN"

        printf '  %s%-4d%s %-9s %-25.25s %-12s %s\n' \
            "$GREEN" "$((i + 1))" "$RESET" \
            "$region_label" "${RESULT_NAMES[$i]}" \
            "${RESULT_TIMES[$i]}" "${RESULT_URLS[$i]}"
    done

    printf '\n'
    info "Iranian mirrors are prioritized; response time is measured per request."
    warn "This is metadata response time, not a full download-speed benchmark."
}

# -------------------- CURRENT REPOSITORIES ------------------

show_current_sources() {
    printf '\n'
    printf '  %sCURRENT REPOSITORY CONFIGURATION%s\n' "$BOLD" "$RESET"
    hr

    case "$PKG_MANAGER" in
        APT)
            local found=0 f
            if [[ -f /etc/apt/sources.list ]]; then
                printf '\n  %s\n' "/etc/apt/sources.list"
                grep -E '^[[:space:]]*deb(-src)?[[:space:]]|^[[:space:]]*(Types|URIs|Suites|Components|Enabled):' \
                    /etc/apt/sources.list 2>/dev/null || true
                found=1
            fi

            if [[ -d /etc/apt/sources.list.d ]]; then
                while IFS= read -r -d '' f; do
                    printf '\n  %s\n' "$f"
                    if [[ "$f" == *.sources ]]; then
                        # Show Deb822 source fields without dumping unrelated comments.
                        grep -E '^[[:space:]]*(Types|URIs|Suites|Components|Enabled|Signed-By):' \
                            "$f" 2>/dev/null || true
                    else
                        grep -E '^[[:space:]]*deb(-src)?[[:space:]]' \
                            "$f" 2>/dev/null || true
                    fi
                    found=1
                done < <(
                    find /etc/apt/sources.list.d -maxdepth 1 -type f \
                        \( -name '*.list' -o -name '*.sources' \) -print0
                )
            fi

            ((found == 1)) || warn "No APT source files were found."
            info "Deb822 .sources files are now inspected as well."
            ;;
        DNF|YUM)
            if command -v dnf >/dev/null 2>&1; then
                dnf repolist 2>/dev/null || true
            else
                yum repolist 2>/dev/null || true
            fi
            ;;
        Pacman)
            grep -E '^[[:space:]]*Server[[:space:]]*=' \
                /etc/pacman.conf 2>/dev/null || true
            ;;
        Zypper)
            zypper repos 2>/dev/null || true
            ;;
        *)
            warn "Repository display is not implemented for $PKG_MANAGER."
            ;;
    esac
}

# -------------------- SAFE APT BACKUP ------------------------

apply_apt_mirror() {
    local selected_url="$1"
    local family="$OS_FAMILY"

    if [[ "$EUID" -ne 0 ]]; then
        fail "Root access is required. Run: sudo $0"
        return 1
    fi

    # Avoid changing Mint-specific, Kali, or RPM repository configuration.
    if [[ "$family" != "ubuntu" && "$family" != "debian" ]]; then
        warn "Automatic source modification is disabled for $OS_NAME."
        warn "No changes have been made."
        return 1
    fi

    local backup_dir="/var/backups/linux-mirror-manager/$(date +%Y%m%d-%H%M%S)"
    local -a files=()
    local f

    [[ -f /etc/apt/sources.list ]] && files+=("/etc/apt/sources.list")

    if [[ -d /etc/apt/sources.list.d ]]; then
        while IFS= read -r -d '' f; do
            files+=("$f")
        done < <(
            find /etc/apt/sources.list.d -maxdepth 1 -type f \
                \( -name '*.list' -o -name '*.sources' \) -print0
        )
    fi

    if ((${#files[@]} == 0)); then
        fail "No APT source files found."
        return 1
    fi

    mkdir -p "$backup_dir" || {
        fail "Could not create backup directory."
        return 1
    }

    for f in "${files[@]}"; do
        cp -a --parents "$f" "$backup_dir" || {
            fail "Backup failed. Aborting before making changes."
            return 1
        }
    done

    info "Backup created: $backup_dir"

    # Change only recognized official archive URLs. Third-party repositories
    # and security.ubuntu.com are intentionally left unchanged.
    if ! MIRROR_URL="$selected_url" DISTRO_FAMILY="$family" \
        python3 - "${files[@]}" <<'PY'
import os
import re
import sys
from pathlib import Path

mirror = os.environ["MIRROR_URL"].rstrip("/")
family = os.environ["DISTRO_FAMILY"]

if family == "ubuntu":
    pattern = re.compile(
        r"https?://(?:archive\.ubuntu\.com|[a-z]{2}\.archive\.ubuntu\.com)/ubuntu"
    )
elif family == "debian":
    pattern = re.compile(r"https?://deb\.debian\.org/debian")
else:
    raise SystemExit("Unsupported distribution")

changed_files = []
total = 0

for filename in sys.argv[1:]:
    path = Path(filename)
    original = path.read_text(encoding="utf-8")
    updated, count = pattern.subn(lambda _: mirror, original)

    if count:
        path.write_text(updated, encoding="utf-8")
        changed_files.append(str(path))
        total += count
        print(f"Updated {path}: {count} URL(s)")

if total == 0:
    print("No supported official archive URL was found in .list or .sources files.")
    raise SystemExit(2)

print(f"Changed {total} official archive URL(s) across {len(changed_files)} file(s).")
PY
    then
        warn "No supported source URL was changed."
        warn "Backup retained at $backup_dir"
        return 1
    fi

    printf '\n'
    info "Refreshing APT metadata..."

    if apt-get update; then
        ok "APT metadata refresh completed."
        info "Backup: $backup_dir"
        return 0
    fi

    fail "APT update failed."
    warn "Attempting to restore the original APT source files..."

    for f in "${files[@]}"; do
        cp -a "$backup_dir$f" "$f" || {
            fail "Automatic restore failed for $f"
            warn "Manual recovery directory: $backup_dir"
            return 1
        }
    done

    warn "Original source files restored. Rechecking APT metadata..."
    if apt-get update; then
        ok "Original repositories restored and APT metadata refresh succeeded."
    else
        warn "Original files were restored, but apt-get update still fails."
        warn "Check network connectivity and repository configuration."
    fi
    info "Backup retained at: $backup_dir"
    return 1
}

# -------------------- MAIN MENU ------------------------------

main_menu() {
    while true; do
        printf '\n'
        hr
        printf '  %sMAIN MENU%s\n' "$BOLD" "$RESET"
        hr

        printf '  %s[1]%s  System information\n' "$CYAN" "$RESET"
        printf '  %s[2]%s  Inspect current repositories\n' "$CYAN" "$RESET"
        printf '  %s[3]%s  Scan and rank available mirrors\n' "$CYAN" "$RESET"
        printf '  %s[4]%s  Choose and apply a mirror\n' "$CYAN" "$RESET"
        printf '  %s[5]%s  About this project\n' "$CYAN" "$RESET"
        printf '  %s[0]%s  Exit\n' "$RED" "$RESET"

        printf '\n  %sSelect an option:%s ' "$WHITE" "$RESET"
        local choice
        read -r choice || return

        case "$choice" in
            1)
                show_system
                wait_key
                ;;
            2)
                show_current_sources
                wait_key
                ;;
            3)
                load_mirrors
                scan_mirrors
                show_results
                wait_key
                ;;
            4)
                load_mirrors
                scan_mirrors
                show_results

                if ((${#RESULT_NAMES[@]} == 0)); then
                    wait_key
                    continue
                fi

                printf '\n  Enter mirror number (0 to cancel): '
                local selected
                read -r selected || continue

                [[ "$selected" =~ ^[0-9]+$ ]] || {
                    warn "Please enter a valid number."
                    continue
                }

                ((selected == 0)) && continue

                if ((selected < 1 || selected > ${#RESULT_NAMES[@]})); then
                    warn "Selection is out of range."
                    continue
                fi

                local index=$((selected - 1))

                printf '\n'
                info "Selected: ${RESULT_NAMES[$index]}"
                info "URL: ${RESULT_URLS[$index]}"
                warn "This operation changes system repository configuration."
                printf '  Type APPLY to continue: '

                local confirm
                read -r confirm || continue

                if [[ "$confirm" == "APPLY" ]]; then
                    apply_apt_mirror "${RESULT_URLS[$index]}" || true
                else
                    info "Cancelled. No changes requested."
                fi

                wait_key
                ;;
            5)
                printf '\n'
                printf '  %sLinux Mirror Manager%s\n' "$BOLD" "$RESET"
                printf '  Version     : %s\n' "$VERSION"
                printf '  Developer   : Parham Shyasi\n'
                printf '  GitHub      : %s\n' "$GITHUB"
                printf '  Purpose     : Diagnose and select Linux mirrors.\n'
                printf '\n'
                wait_key
                ;;
            0)
                printf '\n  %sGoodbye!%s\n\n' "$CYAN" "$RESET"
                return
                ;;
            *)
                warn "Invalid option."
                ;;
        esac
    done
}

# -------------------- STARTUP -------------------------------

banner
detect_system
check_dependencies
show_system

if [[ "$EUID" -ne 0 ]]; then
    warn "Read-only mode: scanning works without root."
    info "Use sudo only when you want to change system sources."
fi

main_menu
