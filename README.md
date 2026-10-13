# Linux Diagnostic Toolkit (Assignment 1)

A modular, production-ready Linux diagnostic toolkit written in Bash. This toolkit provides system administrators and DevOps engineers with automated tools to inspect hardware and operating system metrics, monitor filesystem disk usage against dynamic thresholds, and verify network connectivity and port availability.

---

## Repository Structure

```text
assignment-1/
├── README.md           # Toolkit documentation, command explanations, and usage guide
├── system-info.sh      # Runtime hardware, OS, memory, and uptime diagnostic script
├── disk-check.sh       # Filesystem disk capacity validation and alert script
├── network-check.sh    # DNS resolution, interface inspection, ping, and TCP port scanner
├── grade.sh            # Automated verification test suite
├── logs/               # Diagnostic log storage
│   ├── .gitkeep        # Directory retention placeholder for Git
│   ├── system-info.log # Execution logs from system-info.sh
│   ├── disk-check.log  # Execution logs from disk-check.sh
│   └── network-check.log # Execution logs from network-check.sh
├── notes.txt           # Assignment specification document
└── date.txt            # Reference documentation for system date/time formatting
```

---

## Prerequisites & Permissions

Ensure all scripts have executable permissions prior to running:

```bash
# Grant executable permissions to all diagnostic scripts and grader
chmod +x system-info.sh disk-check.sh network-check.sh grade.sh
```

Required utilities (standard across POSIX/Linux distributions):
- `bash` (version 4.0+)
- `coreutils` (`date`, `uname`, `whoami`, `pwd`, `cat`, `df`, `head`, `cut`, `tr`)
- `procps` (`uptime`, `free`)
- `util-linux` (`lscpu`)
- `iproute2` (`ip`)
- `iputils-ping` (`ping`)
- `netcat` / `nc` (or built-in Bash `/dev/tcp`)
- `git`

---

## Diagnostic Scripts & Command Explanations

Each script is heavily commented internally explaining each command and Bash construct. Below is an exhaustive reference explaining how each script and command operates.

### 1. `system-info.sh`

#### Purpose
Collects and displays critical host information obtained dynamically from the Linux kernel and operating system at runtime.

#### Usage
```bash
./system-info.sh
```

#### Commands Used & Detailed Explanations
| Command | Options / Syntax | Explanation |
| :--- | :--- | :--- |
| `set` | `-euo pipefail` | Strict error handling: `-e` exits immediately on command failure, `-u` treats unset variables as fatal errors, `-o pipefail` ensures pipeline failures propagate. |
| `BASH_SOURCE[0]` | `${BASH_SOURCE[0]}` | Bash internal array holding source paths; `${BASH_SOURCE[0]}` reliably references the path of the executing script. |
| `dirname` | `dirname "${BASH_SOURCE[0]}"` | Strips the non-directory suffix from the script path to yield its parent directory. |
| `pwd` | `pwd` | Returns the current working directory as an absolute pathname. |
| `mkdir` | `-p "$LOG_DIR"` | Creates the `logs/` directory if missing; `-p` suppresses errors if the directory already exists. |
| `date` | `+%Y-%m-%d %H:%M:%S` | Formats current timestamp into standardized ISO-like format (Year-Month-Day Hours:Minutes:Seconds) for logging. |
| `hostname` | `hostname` | Queries the system kernel for the machine's configured network hostname. |
| `whoami` | `whoami` | Prints the effective username associated with the current running process. |
| `date` | `+%Y-%m-%d %H:%M:%S %Z` | Prints date, time, and active timezone abbreviation (e.g. UTC, WAT). |
| `source` | `source /etc/os-release` | Reads the standardized distribution release file `/etc/os-release` and exports distribution details like `PRETTY_NAME` into script environment. |
| `uname` | `-r` | Prints the kernel release version string (e.g., `7.0.0-34-generic`). |
| `uname` | `-m` | Prints machine hardware architecture name (e.g., `x86_64`, `aarch64`). |
| `uptime` | `-p` | Displays total system running duration in pretty human-readable format (`up 2 hours, 10 minutes`). |
| `lscpu` | `lscpu \| grep -i 'Model name:'` | Reads CPU architecture from kernel `sysfs`, filtering the line containing processor brand and frequency. |
| `sed` | `s/Model name:[[:space:]]*//` | Stream editor used to strip leading label text and whitespace from CPU model output. |
| `nproc` | `nproc` | Queries the number of available processing units / logical CPU cores. |
| `free` | `-h` | Reports total, used, and free system memory in human-readable units (MiB/GiB). |
| `awk` | `awk '/^Mem:/ {print $2, $3, $4}'` | Pattern-matches line starting with `Mem:` and extracts column 2 (Total), 3 (Used), and 4 (Free). |
| `>>` | `echo ... >> "$LOG_FILE"` | Shell redirection operator appending log entries to `logs/system-info.log` without overwriting prior history. |

---

### 2. `disk-check.sh`

#### Purpose
Monitors disk capacity on any target mount point (defaulting to root `/`) and compares usage percentage against an integer threshold (1–100).

#### Usage
```bash
./disk-check.sh <threshold> [path]
```

#### Arguments
- `<threshold>`: Mandatory integer from `1` to `100`.
- `[path]`: Optional filesystem path or mount point. Defaults to `/`.

#### Exit Codes
- `0`: Disk usage is strictly below the threshold.
- `1`: Disk usage reaches or exceeds the threshold.
- `2`: Invalid input (missing threshold, non-integer, out-of-range value, or non-existent path).

#### Commands Used & Detailed Explanations
| Command | Options / Syntax | Explanation |
| :--- | :--- | :--- |
| `[[ $# -lt 1 ]]` | Test operator `$#` | Checks the count of positional parameters passed to the script; triggers error exit if no threshold was supplied. |
| `=~` | `[[ "$1" =~ ^[0-9]+$ ]]` | Regular expression matching operator in Bash. Validates that the threshold string consists strictly of numeric digits. |
| `(( ... ))` | `(( THRESHOLD < 1 \|\| THRESHOLD > 100 ))` | Arithmetic evaluation compound command; evaluates integer values and flags out-of-range inputs. |
| `${2:-/}` | Parameter expansion | Defaults `TARGET_PATH` to `/` if parameter `$2` is unset or null. |
| `[[ ! -e "$TARGET_PATH" ]]` | File existence test `-e` | Verifies whether the specified filesystem path exists before running inspection commands. |
| `df` | `-P "$TARGET_PATH"` | Displays filesystem disk space usage in POSIX portable format (`-P`). Guarantees one line per filesystem to avoid field splitting errors. |
| `awk` | `NR==2 {print $5}` | Parses the output of `df`, selecting record number 2 (data row) and extracting field 5 (percentage capacity, e.g., `52%`). |
| `${USAGE_RAW%\%}` | Suffix removal | Bash parameter expansion trimming trailing `%` character, leaving an integer value for numerical evaluation. |
| `(( USAGE_PCT < THRESHOLD ))` | Arithmetic comparison | Compares current disk usage against threshold to determine return code and log classification (`OK` vs `ALERT`). |

---

### 3. `network-check.sh`

#### Purpose
Provides end-to-end network diagnostic verification:
1. Validates host and port arguments.
2. Resolves hostnames via system NSS/DNS and prints resolved IP addresses.
3. Displays local network interface configuration and IP addresses.
4. Performs an ICMP echo check (`ping`).
5. Evaluates TCP port availability if a port (`1–65535`) is provided.

#### Usage
```bash
# Basic check (ping + DNS + interfaces)
./network-check.sh <hostname-or-ip>

# Port check (adds TCP port reachability test)
./network-check.sh <hostname-or-ip> <port>
```

#### Exit Codes
- `0`: Check succeeded (ICMP ping succeeded, or TCP port is open).
- `1`: Connectivity check failed (ping failed or TCP port closed).
- `2`: Invalid input (missing host, invalid port format, port out of range 1–65535).

#### Commands Used & Detailed Explanations
| Command | Options / Syntax | Explanation |
| :--- | :--- | :--- |
| `getent` | `ahosts "$TARGET_HOST"` | Queries Name Service Switch databases (`/etc/hosts`, DNS) to resolve hostnames into IPv4 and IPv6 addresses. |
| `sort` | `-u` | Filters and sorts output, eliminating redundant IP addresses. |
| `ip` | `-br addr` | `iproute2` utility displaying network interfaces in "brief" format (`-br`), listing interface names, link state (`UP`/`DOWN`), and assigned CIDR IP addresses. |
| `ping` | `-c 2 -W 2 "$TARGET_HOST"` | Transmits exactly 2 ICMP ECHO packets (`-c 2`) with a maximum 2-second timeout per probe (`-W 2`), verifying basic IP reachability without blocking. |
| `nc` | `-z -w 3 "$TARGET_HOST" "$TARGET_PORT"` | Netcat network utility running in zero-I/O scan mode (`-z`) with a 3-second connection timeout (`-w 3`) to probe whether a remote TCP port is open. |
| `/dev/tcp` | `timeout 3 bash -c "</dev/tcp/host/port"` | Fallback TCP socket connection mechanism built directly into Bash, guarded by the `timeout` command. |

---

## Logging Mechanism

All scripts automatically log execution operations with ISO-standard timestamps and execution status into the `logs/` directory:
- `logs/system-info.log`: Records user invocations, system metrics, and execution status.
- `logs/disk-check.log`: Records path evaluated, disk percentage, threshold, and status (`OK`, `ALERT`, or `ERROR`).
- `logs/network-check.log`: Records target host, resolution results, ICMP ping status, TCP port checks, and exit codes.

The `logs/.gitkeep` file ensures the logging directory is tracked in Git even when log files are clean.

---

## Automated Grading Verification (`grade.sh`)

The included `grade.sh` script verifies compliance with assignment requirements:
- Required files presence (`README.md`, `system-info.sh`, `disk-check.sh`, `network-check.sh`)
- Bash syntax validation (`bash -n`)
- Executable bit check (`-x`)
- Output and runtime behavior of `system-info.sh`
- Input argument validation and exit codes for `disk-check.sh`
- Network argument validation, port checks, and exit codes for `network-check.sh`
- Presence of log entries in `logs/`
- Git commit count (minimum 5) and feature branch detection

Run the grader at any time:
```bash
./grade.sh
```

---

## Git Workflow & Branching Strategy

The repository follows a clean Git feature branching workflow:
1. **Repository Setup**: Initialized on `main` branch with base project structure.
2. **Feature Branching**: Development occurred on a non-main feature branch (`feature/linux-diagnostic-toolkit`).
3. **Commit History**: At least 5 granular, meaningful commits adhering to Conventional Commits:
   - `chore: initial project setup with grade.sh and logs structure`
   - `feat: implement system-info.sh for runtime hardware and OS diagnostics`
   - `feat: implement disk-check.sh with threshold validation and logging`
   - `feat: implement network-check.sh for host resolution and port diagnostics`
   - `docs: add comprehensive toolkit documentation and command explanations in README.md`
4. **Merge Integration**: Merged into `main` branch preserving the feature branch reference for grader compliance.
