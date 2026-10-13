#!/usr/bin/env bash
# ==============================================================================
# Script Name: disk-check.sh
# Usage:       ./disk-check.sh <threshold> [path]
# Description: Checks filesystem disk usage for a specified path (default: /).
#              Validates that threshold is an integer between 1 and 100.
#              Displays the disk usage percentage.
#              Exits with:
#                0 - Disk usage is strictly below threshold.
#                1 - Disk usage reaches or exceeds threshold.
#                2 - Invalid input or path does not exist.
#              Logs all checks with timestamps to logs/disk-check.log.
# ==============================================================================

# Command: set -u
# Explanation: Treats unset variables as an error, terminating script execution
#              to prevent unexpected behavior from undefined variables.
set -u

# Command: BASH_SOURCE[0] with dirname, cd, and pwd
# Explanation: Resolves the directory path containing this script to locate
#              the project logs folder regardless of where the script is called from.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Command: Variable assignments for logging paths
# Explanation: Configures paths for log directory and disk-check log file.
LOG_DIR="${SCRIPT_DIR}/logs"
LOG_FILE="${LOG_DIR}/disk-check.log"

# Command: mkdir -p "$LOG_DIR"
# Explanation: Creates the logs directory if it does not already exist,
#              suppressing errors if the directory is already present.
mkdir -p "$LOG_DIR"

# Command: date '+%Y-%m-%d %H:%M:%S'
# Explanation: Formats the current runtime timestamp in YYYY-MM-DD HH:MM:SS format.
LOG_TIMESTAMP="$(date '+%Y-%m-%d %H:%M:%S')"

# ------------------------------------------------------------------------------
# Input Validation
# ------------------------------------------------------------------------------

# Command: [[ $# -lt 1 ]]
# Explanation: Checks whether the caller provided at least one positional argument.
#              If no threshold is supplied, displays usage and exits with code 2.
if [[ $# -lt 1 ]]; then
    # Command: echo to standard error (>&2)
    # Explanation: Outputs error message and usage instructions to standard error stream.
    echo "Error: Missing required threshold argument." >&2
    echo "Usage: $0 <threshold> [path]" >&2
    echo "  threshold : Integer from 1 to 100" >&2
    echo "  path      : Target filesystem path (default: /)" >&2

    # Command: echo with redirection (>>)
    # Explanation: Appends validation failure event with timestamp to log file.
    echo "[$LOG_TIMESTAMP] [ERROR] disk-check.sh failed: missing threshold argument" >> "$LOG_FILE"

    # Command: exit 2
    # Explanation: Returns exit code 2 indicating invalid input.
    exit 2
fi

# Command: Parameter assignment for threshold input
# Explanation: Stores the first command-line argument into variable THRESHOLD_ARG.
THRESHOLD_ARG="$1"

# Command: [[ ! "$THRESHOLD_ARG" =~ ^[0-9]+$ ]]
# Explanation: Uses regular expression matching to test if the threshold consists
#              solely of one or more decimal digits (positive integer check).
if ! [[ "$THRESHOLD_ARG" =~ ^[0-9]+$ ]]; then
    # Command: echo to stderr
    # Explanation: Prints error indicating threshold is not an integer.
    echo "Error: Threshold must be a positive integer between 1 and 100. Received: '$THRESHOLD_ARG'" >&2

    # Command: echo with redirection (>>)
    # Explanation: Appends non-numeric threshold error to the log file.
    echo "[$LOG_TIMESTAMP] [ERROR] disk-check.sh failed: non-numeric threshold '$THRESHOLD_ARG'" >> "$LOG_FILE"

    # Command: exit 2
    # Explanation: Exits with status code 2 for invalid input.
    exit 2
fi

# Command: Variable assignment converting to integer variable
# Explanation: Assigns the validated numeric threshold value.
THRESHOLD="$THRESHOLD_ARG"

# Command: (( THRESHOLD < 1 || THRESHOLD > 100 ))
# Explanation: Performs arithmetic evaluation to verify threshold falls in range 1-100.
if (( THRESHOLD < 1 || THRESHOLD > 100 )); then
    # Command: echo to stderr
    # Explanation: Prints out-of-range error message to standard error stream.
    echo "Error: Threshold out of range. Must be an integer from 1 to 100. Received: $THRESHOLD" >&2

    # Command: echo with redirection (>>)
    # Explanation: Logs out-of-range error with timestamp.
    echo "[$LOG_TIMESTAMP] [ERROR] disk-check.sh failed: threshold '$THRESHOLD' out of range (1-100)" >> "$LOG_FILE"

    # Command: exit 2
    # Explanation: Exits with status code 2 for out-of-range input.
    exit 2
fi

# Command: Parameter expansion with default value (${2:-/})
# Explanation: Evaluates second argument if provided, otherwise defaults to '/' (root filesystem).
TARGET_PATH="${2:-/}"

# Command: [[ ! -e "$TARGET_PATH" ]]
# Explanation: Verifies that the specified target path actually exists on the filesystem.
if [[ ! -e "$TARGET_PATH" ]]; then
    # Command: echo to stderr
    # Explanation: Prints non-existent target path error to standard error.
    echo "Error: Target path '$TARGET_PATH' does not exist." >&2

    # Command: echo with redirection (>>)
    # Explanation: Logs path not found error to log file.
    echo "[$LOG_TIMESTAMP] [ERROR] disk-check.sh failed: path '$TARGET_PATH' does not exist" >> "$LOG_FILE"

    # Command: exit 2
    # Explanation: Exits with status code 2 indicating invalid target path.
    exit 2
fi

# ------------------------------------------------------------------------------
# Disk Usage Inspection
# ------------------------------------------------------------------------------

# Command: df -P "$TARGET_PATH"
# Explanation: Runs the disk free utility in POSIX portable format (-P).
#              This ensures output fits on a single line per filesystem,
#              preventing broken wrapping on long device names.
DF_OUTPUT="$(df -P "$TARGET_PATH" 2>/dev/null)" || {
    echo "Error: Failed to query disk usage for '$TARGET_PATH'." >&2
    echo "[$LOG_TIMESTAMP] [ERROR] disk-check.sh failed: df execution error on '$TARGET_PATH'" >> "$LOG_FILE"
    exit 2
}

# Command: awk 'NR==2 {print $1}'
# Explanation: Extracts the filesystem device name from column 1 of line 2.
FS_DEVICE="$(echo "$DF_OUTPUT" | awk 'NR==2 {print $1}')"

# Command: awk 'NR==2 {print $6}'
# Explanation: Extracts the mount point path from column 6 of line 2.
FS_MOUNT="$(echo "$DF_OUTPUT" | awk 'NR==2 {print $6}')"

# Command: awk 'NR==2 {print $5}'
# Explanation: Extracts the raw capacity percentage string (e.g., '52%') from column 5 of line 2.
USAGE_RAW="$(echo "$DF_OUTPUT" | awk 'NR==2 {print $5}')"

# Command: Parameter expansion stripping percent sign (${USAGE_RAW%\%})
# Explanation: Removes the trailing '%' character to produce a clean integer for numerical comparison.
USAGE_PCT="${USAGE_RAW%\%}"

# Command: [[ ! "$USAGE_PCT" =~ ^[0-9]+$ ]]
# Explanation: Ensures the extracted disk usage value is a valid numeric integer.
if ! [[ "$USAGE_PCT" =~ ^[0-9]+$ ]]; then
    echo "Error: Unable to parse disk usage percentage for '$TARGET_PATH'." >&2
    echo "[$LOG_TIMESTAMP] [ERROR] disk-check.sh failed: could not parse usage percentage from '$DF_OUTPUT'" >> "$LOG_FILE"
    exit 2
fi

# ------------------------------------------------------------------------------
# Display Results
# ------------------------------------------------------------------------------

# Command: echo
# Explanation: Prints detailed disk usage metrics clearly to standard output.
echo "============================================================"
echo "                 DISK USAGE CHECK REPORT                    "
echo "============================================================"
echo "Target Path:          $TARGET_PATH"
echo "Filesystem:           $FS_DEVICE"
echo "Mounted On:           $FS_MOUNT"
echo "Current Disk Usage:   ${USAGE_PCT}%"
echo "Usage Threshold:      ${THRESHOLD}%"

# ------------------------------------------------------------------------------
# Evaluate Threshold & Set Exit Code
# ------------------------------------------------------------------------------

# Command: (( USAGE_PCT < THRESHOLD ))
# Explanation: Compares current usage percentage against the user-specified threshold.
if (( USAGE_PCT < THRESHOLD )); then
    # Command: echo
    # Explanation: Informs user that disk usage is safely below the configured threshold.
    echo "Status:               OK (Disk usage ${USAGE_PCT}% is below threshold ${THRESHOLD}%)"
    echo "============================================================"

    # Command: echo with redirection (>>)
    # Explanation: Records successful check entry with OK status in disk-check.log.
    echo "[$LOG_TIMESTAMP] [INFO] disk-check: Path '$TARGET_PATH' usage is ${USAGE_PCT}%, below threshold ${THRESHOLD}%. Status: OK" >> "$LOG_FILE"

    # Command: exit 0
    # Explanation: Exits with code 0 indicating usage is within acceptable limits.
    exit 0
else
    # Command: echo
    # Explanation: Alerts user that disk usage has reached or exceeded the threshold.
    echo "Status:               WARNING (Disk usage ${USAGE_PCT}% reaches or exceeds threshold ${THRESHOLD}%)"
    echo "============================================================"

    # Command: echo with redirection (>>)
    # Explanation: Records threshold alert warning event in disk-check.log.
    echo "[$LOG_TIMESTAMP] [WARN] disk-check: Path '$TARGET_PATH' usage is ${USAGE_PCT}%, reaches/exceeds threshold ${THRESHOLD}%. Status: ALERT" >> "$LOG_FILE"

    # Command: exit 1
    # Explanation: Exits with non-zero code (1) indicating threshold violation.
    exit 1
fi
