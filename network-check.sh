#!/usr/bin/env bash
# ==============================================================================
# Script Name: network-check.sh
# Usage:       ./network-check.sh <hostname-or-ip> [port]
# Description: Performs network diagnostics against a specified host:
#              1. Validates host and optional port arguments.
#              2. Resolves hostname to IP addresses and displays them.
#              3. Displays network interface configuration.
#              4. Conducts an ICMP connectivity (ping) test.
#              5. Tests TCP port connectivity if a port (1-65535) is specified.
#              Exits with:
#                0 - Network check succeeded (ping or port reachable).
#                1 - Connectivity check failed (ping timeout or port closed).
#                2 - Invalid argument (missing host, invalid port format/range).
#              Logs all checks with timestamps to logs/network-check.log.
# ==============================================================================

# Command: set -u
# Explanation: Treats unset variables as an error, terminating script execution
#              to prevent unexpected behavior from undefined variables.
set -u

# Command: BASH_SOURCE[0] with dirname, cd, and pwd
# Explanation: Resolves the directory path containing this script to locate
#              the project logs directory regardless of the current working directory.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Command: Variable assignments for log directory and file
# Explanation: Sets the paths for the logs folder and network diagnostic log file.
LOG_DIR="${SCRIPT_DIR}/logs"
LOG_FILE="${LOG_DIR}/network-check.log"

# Command: mkdir -p "$LOG_DIR"
# Explanation: Creates the logs directory if it does not already exist,
#              suppressing errors if the directory already exists.
mkdir -p "$LOG_DIR"

# Command: date '+%Y-%m-%d %H:%M:%S'
# Explanation: Formats the current date and time as YYYY-MM-DD HH:MM:SS for logging.
LOG_TIMESTAMP="$(date '+%Y-%m-%d %H:%M:%S')"

# ------------------------------------------------------------------------------
# Input Validation
# ------------------------------------------------------------------------------

# Command: [[ $# -lt 1 || -z "${1:-}" ]]
# Explanation: Tests whether at least one argument was passed and that it is not empty.
if [[ $# -lt 1 || -z "${1:-}" ]]; then
    # Command: echo to standard error (>&2)
    # Explanation: Writes error message and usage instructions to the standard error stream.
    echo "Error: Missing required hostname or IP address argument." >&2
    echo "Usage: $0 <hostname-or-ip> [port]" >&2
    echo "  hostname-or-ip : Target hostname, domain, or IP address" >&2
    echo "  port           : Optional TCP port number (1-65535)" >&2

    # Command: echo with redirection (>>)
    # Explanation: Appends failure record to network-check.log with timestamp.
    echo "[$LOG_TIMESTAMP] [ERROR] network-check.sh failed: missing host argument" >> "$LOG_FILE"

    # Command: exit 2
    # Explanation: Exits with code 2 indicating invalid input arguments.
    exit 2
fi

# Command: Parameter assignment for host target
# Explanation: Stores the first command-line argument into variable TARGET_HOST.
TARGET_HOST="$1"

# Command: [[ "$TARGET_HOST" =~ ^- ]] || [[ "$TARGET_HOST" =~ [[:space:]] ]]
# Explanation: Rejects arguments starting with hyphens (to prevent command injection
#              into utilities like ping or getent) or containing whitespace.
if [[ "$TARGET_HOST" =~ ^- ]] || [[ "$TARGET_HOST" =~ [[:space:]] ]]; then
    echo "Error: Invalid hostname or IP address format: '$TARGET_HOST'" >&2
    echo "[$LOG_TIMESTAMP] [ERROR] network-check.sh failed: invalid host format '$TARGET_HOST'" >> "$LOG_FILE"
    exit 2
fi

# Command: Variable initialization for optional port check
# Explanation: Defaults port tracking variables before evaluating optional second argument.
TARGET_PORT=""
PORT_CHECK_REQUESTED=false

# Command: [[ $# -ge 2 ]]
# Explanation: Checks if an optional second parameter (port) was provided by the user.
if [[ $# -ge 2 ]]; then
    PORT_ARG="$2"

    # Command: [[ ! "$PORT_ARG" =~ ^[0-9]+$ ]]
    # Explanation: Regular expression validation ensuring port is composed strictly of digits.
    if ! [[ "$PORT_ARG" =~ ^[0-9]+$ ]]; then
        echo "Error: Port must be an integer between 1 and 65535. Received: '$PORT_ARG'" >&2
        echo "[$LOG_TIMESTAMP] [ERROR] network-check.sh failed: non-numeric port '$PORT_ARG'" >> "$LOG_FILE"
        exit 2
    fi

    # Command: (( PORT_ARG < 1 || PORT_ARG > 65535 ))
    # Explanation: Validates that the port number falls within the legal TCP/UDP port range (1 to 65535).
    if (( PORT_ARG < 1 || PORT_ARG > 65535 )); then
        echo "Error: Port number out of range (1-65535). Received: $PORT_ARG" >&2
        echo "[$LOG_TIMESTAMP] [ERROR] network-check.sh failed: port '$PORT_ARG' out of range (1-65535)" >> "$LOG_FILE"
        exit 2
    fi

    TARGET_PORT="$PORT_ARG"
    PORT_CHECK_REQUESTED=true
fi

# ------------------------------------------------------------------------------
# Report Header
# ------------------------------------------------------------------------------

# Command: echo
# Explanation: Displays report banner to standard output.
echo "============================================================"
echo "                NETWORK CHECK REPORT                        "
echo "============================================================"
echo "Target Host:          $TARGET_HOST"
if [[ "$PORT_CHECK_REQUESTED" = true ]]; then
    echo "Target Port:          $TARGET_PORT"
fi

# ------------------------------------------------------------------------------
# Host Resolution
# ------------------------------------------------------------------------------

# Command: echo
# Explanation: Prints subsection header for host resolution.
echo "------------------------------------------------------------"
echo "Host Resolution:"

# Command: getent ahosts "$TARGET_HOST" with awk and sort
# Explanation: Resolves host using system NSS database (DNS, /etc/hosts),
#              extracts IP addresses from column 1, and removes duplicates with sort -u.
RESOLVED_IPS="$(getent ahosts "$TARGET_HOST" 2>/dev/null | awk '{print $1}' | sort -u || true)"

# Command: Fallback resolution with host command if getent yielded no result
# Explanation: Attempts DNS query via 'host' command if getent was empty or unavailable.
if [[ -z "$RESOLVED_IPS" ]] && command -v host >/dev/null 2>&1; then
    RESOLVED_IPS="$(host -t A "$TARGET_HOST" 2>/dev/null | awk '/has address/ {print $NF}' | sort -u || true)"
fi

# Command: [[ -n "$RESOLVED_IPS" ]]
# Explanation: Tests whether host resolution successfully found one or more IP addresses.
if [[ -n "$RESOLVED_IPS" ]]; then
    # Command: echo "$RESOLVED_IPS"
    # Explanation: Displays each resolved IP address for the target host.
    while IFS= read -r ip; do
        [[ -n "$ip" ]] && echo "  -> $ip"
    done <<< "$RESOLVED_IPS"
    RESOLUTION_LOG="Resolved to: $(echo "$RESOLVED_IPS" | tr '\n' ' ' | sed 's/[[:space:]]*$//')"
else
    # Command: echo to display resolution failure warning
    # Explanation: Alerts user that resolution failed, without crashing script execution.
    echo "  -> Warning: Unable to resolve hostname '$TARGET_HOST' to an IP address."
    RESOLUTION_LOG="Resolution failed"
fi

# ------------------------------------------------------------------------------
# Network Interface Information
# ------------------------------------------------------------------------------

# Command: echo
# Explanation: Prints subsection header for network interface details.
echo "------------------------------------------------------------"
echo "Network Interfaces:"

# Command: ip -br addr
# Explanation: Displays brief list of network interfaces, operational state (UP/DOWN),
#              and assigned IPv4/IPv6 addresses. Falls back to ip addr or ifconfig if needed.
if command -v ip >/dev/null 2>&1; then
    ip -br addr 2>/dev/null || ip addr
elif command -v ifconfig >/dev/null 2>&1; then
    ifconfig
else
    # Command: cat /proc/net/dev
    # Explanation: Fallback printing kernel network device statistics if neither ip nor ifconfig is installed.
    cat /proc/net/dev
fi

# ------------------------------------------------------------------------------
# Basic Connectivity Check (ICMP Ping)
# ------------------------------------------------------------------------------

# Command: echo
# Explanation: Prints subsection header for basic connectivity check.
echo "------------------------------------------------------------"
echo "Basic Connectivity Check (ICMP Ping):"

# Command: ping -c 2 -W 2 "$TARGET_HOST"
# Explanation: Sends 2 ICMP ECHO_REQUEST packets (-c 2) with a 2-second timeout (-W 2).
#              Output is evaluated to test if the remote host responds to ICMP.
PING_STATUS=1
if ping -c 2 -W 2 "$TARGET_HOST" >/dev/null 2>&1; then
    PING_STATUS=0
    echo "  Status: SUCCESS (Host responded to ICMP ping)"
    PING_LOG="Ping: SUCCESS"
else
    PING_STATUS=1
    echo "  Status: FAILED (Host did not respond to ICMP ping or ping blocked)"
    PING_LOG="Ping: FAILED"
fi

# ------------------------------------------------------------------------------
# TCP Port Connectivity Check (Optional)
# ------------------------------------------------------------------------------

TCP_STATUS=0
TCP_LOG="Port: Not checked"

# Command: [[ "$PORT_CHECK_REQUESTED" = true ]]
# Explanation: Evaluates whether the user supplied a port argument to test.
if [[ "$PORT_CHECK_REQUESTED" = true ]]; then
    echo "------------------------------------------------------------"
    echo "TCP Port Connectivity Check (Port $TARGET_PORT):"

    # Command: nc -z -w 3 "$TARGET_HOST" "$TARGET_PORT"
    # Explanation: Uses Netcat to test TCP connection in zero-I/O scan mode (-z)
    #              with a 3-second connection timeout (-w 3).
    #              Falls back to Bash /dev/tcp pseudo-device with timeout if nc is missing.
    if command -v nc >/dev/null 2>&1; then
        if nc -z -w 3 "$TARGET_HOST" "$TARGET_PORT" >/dev/null 2>&1; then
            TCP_STATUS=0
        else
            TCP_STATUS=1
        fi
    else
        # Command: timeout 3 bash -c "</dev/tcp/$TARGET_HOST/$TARGET_PORT"
        # Explanation: Pure Bash socket connection with a 3-second timeout.
        if timeout 3 bash -c "</dev/tcp/${TARGET_HOST}/${TARGET_PORT}" >/dev/null 2>&1; then
            TCP_STATUS=0
        else
            TCP_STATUS=1
        fi
    fi

    if [[ $TCP_STATUS -eq 0 ]]; then
        echo "  Status: SUCCESS (Port $TARGET_PORT is OPEN / reachable on $TARGET_HOST)"
        TCP_LOG="Port $TARGET_PORT: OPEN"
    else
        echo "  Status: FAILED (Port $TARGET_PORT is CLOSED or unreachable on $TARGET_HOST)"
        TCP_LOG="Port $TARGET_PORT: CLOSED"
    fi
fi

echo "============================================================"

# ------------------------------------------------------------------------------
# Evaluate Final Result, Write Log, and Exit
# ------------------------------------------------------------------------------

# Command: Evaluation of overall exit code
# Explanation: If a port was specified, exit code reflects TCP reachability.
#              Otherwise, exit code reflects ICMP ping reachability.
OVERALL_EXIT=0
if [[ "$PORT_CHECK_REQUESTED" = true ]]; then
    if [[ $TCP_STATUS -eq 0 ]]; then
        OVERALL_EXIT=0
    else
        OVERALL_EXIT=1
    fi
else
    if [[ $PING_STATUS -eq 0 ]]; then
        OVERALL_EXIT=0
    else
        OVERALL_EXIT=1
    fi
fi

# Command: date '+%Y-%m-%d %H:%M:%S'
# Explanation: Captures completion timestamp for the operation log.
COMPLETION_TIMESTAMP="$(date '+%Y-%m-%d %H:%M:%S')"

# Command: echo with redirection (>>)
# Explanation: Appends formatted log entry to network-check.log.
echo "[$COMPLETION_TIMESTAMP] [INFO] network-check: Target='$TARGET_HOST', $RESOLUTION_LOG, $PING_LOG, $TCP_LOG, ExitCode=$OVERALL_EXIT" >> "$LOG_FILE"

# Command: exit "$OVERALL_EXIT"
# Explanation: Exits script with 0 for success or 1 for connectivity failure.
exit "$OVERALL_EXIT"
