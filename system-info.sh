#!/usr/bin/env bash
# ==============================================================================
# Script Name: system-info.sh
# Description: Collects and displays runtime system diagnostics including
#              hostname, current user, date/time, operating system, kernel
#              version, uptime, CPU info, memory info, and working directory.
#              Logs execution events with timestamps to logs/system-info.log.
# ==============================================================================


# Explanation: Configures strict error handling:
#   -e: Exit immediately if any command exits with a non-zero exit status.
#   -u: Treat unset variables and parameters as errors and exit immediately.
#   -o pipefail: Pipeline returns the status of the last command to fail,
#                or zero if all commands exit successfully.
set -euo pipefail


# Explanation: Accurately identifies the absolute path to the directory where
#              this script resides, regardless of current working directory.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"


# Explanation: Sets the path to the logs folder and the specific log file.
LOG_DIR="${SCRIPT_DIR}/logs"
LOG_FILE="${LOG_DIR}/system-info.log"


# Explanation: Creates the logs directory if it does not exist.
#              The -p flag suppresses errors if the directory already exists.
mkdir -p "$LOG_DIR"


# Explanation: Generates a standardized timestamp string (YYYY-MM-DD HH:MM:SS)
#              used to prefix diagnostic entries in the log file.
LOG_TIMESTAMP="$(date '+%Y-%m-%d %H:%M:%S')"


# Explanation: Appends a log entry to the log file documenting the start of
#              the system info collection and the user initiating it.
echo "[$LOG_TIMESTAMP] [INFO] system-info.sh started by user '${USER:-$(whoami)}'" >> "$LOG_FILE"

# ------------------------------------------------------------------------------
# Collect Runtime Diagnostics
# ------------------------------------------------------------------------------


# Explanation: Queries the system kernel to return the network hostname of the machine.
SYS_HOSTNAME="$(hostname)"


# Explanation: Queries the system to return the effective username of the current user.
SYS_USER="$(whoami)"


# Explanation: Formats and returns the current system date, time, and active timezone.
SYS_DATETIME="$(date '+%Y-%m-%d %H:%M:%S %Z')"

# [[ -f /etc/os-release ]] and source /etc/os-release
# Explanation: Checks for the standard OS release definition file and loads its
#              environment variables to extract the friendly OS name (PRETTY_NAME).
if [[ -f /etc/os-release ]]; then
    # shellcheck disable=SC1091
    source /etc/os-release
    SYS_OS="${PRETTY_NAME:-$NAME}"
else
    
    # Explanation: Fallback to printing the kernel/OS name if /etc/os-release is unavailable.
    SYS_OS="$(uname -s)"
fi


# Explanation: Prints the running Linux kernel version string at runtime.
SYS_KERNEL="$(uname -r)"


# Explanation: Displays the machine uptime in pretty format (e.g., 'up 2 hours, 15 minutes').
#              Falls back to standard uptime if '-p' is unsupported on older systems.
if uptime -p >/dev/null 2>&1; then
    SYS_UPTIME="$(uptime -p)"
else
    
    # Explanation: Strips standard uptime output to display system uptime duration.
    SYS_UPTIME="$(uptime | awk -F', ' '{print $1}')"
fi


# Explanation: Reads CPU architecture and model information from the Linux kernel,
#              using grep to find the Model line, head to take the first line,
#              and sed to strip out the 'Model name:' prefix and whitespace.
if command -v lscpu >/dev/null 2>&1; then
    SYS_CPU_MODEL="$(lscpu | grep -i 'Model name:' | head -n 1 | sed -e 's/Model name:[[:space:]]*//' -e 's/^[[:space:]]*//')"
else
    
    # Explanation: Fallback mechanism reading the model name directly from /proc/cpuinfo.
    SYS_CPU_MODEL="$(grep -m 1 'model name' /proc/cpuinfo | cut -d: -f2 | sed 's/^[[:space:]]*//')"
fi


# Explanation: Returns the total number of processing units / CPU cores available to the current process.
SYS_CPU_CORES="$(nproc 2>/dev/null || grep -c '^processor' /proc/cpuinfo)"


# Explanation: Returns the hardware machine architecture (such as x86_64, aarch64, or armv7l).
SYS_ARCH="$(uname -m)"


# Explanation: Displays memory statistics in human-readable units (MiB, GiB) and
#              uses awk to extract Total ($2), Used ($3), and Free ($4) fields.
if command -v free >/dev/null 2>&1; then
    SYS_MEM_TOTAL="$(free -h | awk '/^Mem:/ {print $2}')"
    SYS_MEM_USED="$(free -h | awk '/^Mem:/ {print $3}')"
    SYS_MEM_FREE="$(free -h | awk '/^Mem:/ {print $4}')"
    SYS_MEM_DISPLAY="Total: ${SYS_MEM_TOTAL} | Used: ${SYS_MEM_USED} | Free: ${SYS_MEM_FREE}"
else
    # Command: grep and awk on /proc/meminfo
    # Explanation: Fallback reading total memory from the /proc/meminfo virtual filesystem.
    SYS_MEM_TOTAL="$(grep 'MemTotal:' /proc/meminfo | awk '{print $2 " " $3}')"
    SYS_MEM_DISPLAY="Total: ${SYS_MEM_TOTAL}"
fi


# Explanation: Outputs the absolute pathname of the current working directory.
SYS_CWD="$(pwd)"

# ------------------------------------------------------------------------------
# Display Diagnostics to Standard Output
# ------------------------------------------------------------------------------


# Explanation: Prints formatted diagnostic information clearly to standard output.
echo "============================================================"
echo "               SYSTEM INFORMATION REPORT                    "
echo "============================================================"
echo "Hostname:                  $SYS_HOSTNAME"
echo "Current User:              $SYS_USER"
echo "Date/Time:                 $SYS_DATETIME"
echo "Operating System:          $SYS_OS"
echo "Kernel Version:            $SYS_KERNEL"
echo "Uptime:                    $SYS_UPTIME"
echo "CPU Information:           ${SYS_CPU_MODEL:-Unknown CPU} ($SYS_CPU_CORES cores, $SYS_ARCH)"
echo "Memory Information:        $SYS_MEM_DISPLAY"
echo "Current Working Directory: $SYS_CWD"
echo "============================================================"


# Explanation: Captures completion timestamp for log entry.
COMPLETION_TIMESTAMP="$(date '+%Y-%m-%d %H:%M:%S')"


# Explanation: Appends operation summary entry to the log file recording completion.
echo "[$COMPLETION_TIMESTAMP] [INFO] system-info.sh completed successfully (Hostname: $SYS_HOSTNAME, User: $SYS_USER, Kernel: $SYS_KERNEL, Uptime: $SYS_UPTIME)" >> "$LOG_FILE"

# Explanation: Exits the script with status code 0 indicating successful execution.
exit 0