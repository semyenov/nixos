#!/usr/bin/env bash
# Common library for NixOS configuration scripts
# Provides shared functions for logging, error handling, and utilities

# Strict error handling
set -euo pipefail
shopt -s inherit_errexit nullglob

# Script metadata
readonly SCRIPT_VERSION="1.0.0"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Color codes for output
readonly COLOR_RESET='\033[0m'
readonly COLOR_RED='\033[0;31m'
readonly COLOR_GREEN='\033[0;32m'
readonly COLOR_YELLOW='\033[1;33m'
readonly COLOR_BLUE='\033[0;34m'
readonly COLOR_MAGENTA='\033[0;35m'
readonly COLOR_CYAN='\033[0;36m'
readonly COLOR_WHITE='\033[1;37m'
readonly COLOR_GRAY='\033[0;90m'

# Logging levels
readonly LOG_LEVEL_DEBUG=0
readonly LOG_LEVEL_INFO=1
readonly LOG_LEVEL_WARNING=2
readonly LOG_LEVEL_ERROR=3
readonly LOG_LEVEL_CRITICAL=4

# Default log level (can be overridden)
LOG_LEVEL=${LOG_LEVEL:-$LOG_LEVEL_INFO}

# Terminal capabilities
readonly TERM_COLS="${COLUMNS:-$(tput cols 2>/dev/null || echo 80)}"
readonly IS_TTY="$(test -t 1 && echo true || echo false)"

# Lock file management
LOCK_FILE=""
LOCK_ACQUIRED=false

# Temporary files tracking
declare -a TEMP_FILES=()

# ========================
# Logging Functions
# ========================

log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp
    timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    
    case "$level" in
        DEBUG)
            [[ $LOG_LEVEL -le $LOG_LEVEL_DEBUG ]] || return 0
            echo -e "${COLOR_GRAY}[DEBUG] ${timestamp} - ${message}${COLOR_RESET}" >&2
            ;;
        INFO)
            [[ $LOG_LEVEL -le $LOG_LEVEL_INFO ]] || return 0
            echo -e "${COLOR_CYAN}[INFO]${COLOR_RESET} ${message}"
            ;;
        WARNING|WARN)
            [[ $LOG_LEVEL -le $LOG_LEVEL_WARNING ]] || return 0
            echo -e "${COLOR_YELLOW}[WARN]${COLOR_RESET} ${message}" >&2
            ;;
        ERROR)
            [[ $LOG_LEVEL -le $LOG_LEVEL_ERROR ]] || return 0
            echo -e "${COLOR_RED}[ERROR]${COLOR_RESET} ${message}" >&2
            ;;
        CRITICAL|FATAL)
            echo -e "${COLOR_RED}[CRITICAL]${COLOR_RESET} ${message}" >&2
            ;;
        *)
            echo -e "${message}"
            ;;
    esac
}

log_debug() { log DEBUG "$@"; }
log_info() { log INFO "$@"; }
log_warn() { log WARNING "$@"; }
log_error() { log ERROR "$@"; }
log_critical() { log CRITICAL "$@"; }

# Pretty print functions
print_header() {
    local header="$1"
    local width=${2:-$TERM_COLS}
    local line
    line=$(printf '=%.0s' $(seq 1 "$width"))
    
    echo
    echo -e "${COLOR_BLUE}${line}${COLOR_RESET}"
    echo -e "${COLOR_BLUE}${header}${COLOR_RESET}"
    echo -e "${COLOR_BLUE}${line}${COLOR_RESET}"
    echo
}

print_success() {
    echo -e "${COLOR_GREEN}✓${COLOR_RESET} $*"
}

print_warning() {
    echo -e "${COLOR_YELLOW}⚠${COLOR_RESET} $*"
}

print_error() {
    echo -e "${COLOR_RED}✗${COLOR_RESET} $*"
}

print_info() {
    echo -e "${COLOR_CYAN}ℹ${COLOR_RESET} $*"
}

print_step() {
    echo -e "${COLOR_MAGENTA}▶${COLOR_RESET} $*"
}

# Progress indicators
spinner() {
    local pid=$1
    local message="${2:-Working...}"
    local spinstr='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    
    if [[ "$IS_TTY" == "false" ]]; then
        echo "$message"
        wait "$pid"
        return $?
    fi
    
    while kill -0 "$pid" 2>/dev/null; do
        local temp=${spinstr#?}
        printf " [%c] %s\r" "$spinstr" "$message"
        spinstr=$temp${spinstr%"$temp"}
        sleep 0.1
    done
    
    wait "$pid"
    local exit_code=$?
    
    if [[ $exit_code -eq 0 ]]; then
        printf " ${COLOR_GREEN}[✓]${COLOR_RESET} %s\n" "$message"
    else
        printf " ${COLOR_RED}[✗]${COLOR_RESET} %s\n" "$message"
    fi
    
    return $exit_code
}

progress_bar() {
    local current=$1
    local total=$2
    local width=${3:-50}
    local percent=$((current * 100 / total))
    local filled=$((width * current / total))
    
    printf "\r["
    printf "%${filled}s" | tr ' ' '='
    printf "%$((width - filled))s" | tr ' ' '-'
    printf "] %3d%% (%d/%d)" "$percent" "$current" "$total"
    
    if [[ $current -eq $total ]]; then
        echo
    fi
}

# ========================
# Error Handling
# ========================

# Error trap handler
error_handler() {
    local exit_code=$?
    local line_no=$1
    local bash_lineno=$2
    local last_command=$3
    
    log_error "Command failed with exit code $exit_code"
    log_error "Line $line_no: $last_command"
    log_error "Called from line $bash_lineno"
    
    # Print stack trace
    local frame=0
    while caller $frame; do
        ((frame++))
    done | while read -r line func file; do
        log_error "  at $func ($file:$line)"
    done
    
    cleanup_on_exit
    exit "$exit_code"
}

# Set up error handling
setup_error_handling() {
    trap 'error_handler $LINENO $BASH_LINENO "$BASH_COMMAND"' ERR
    trap cleanup_on_exit EXIT INT TERM
}

# Cleanup function
cleanup_on_exit() {
    local exit_code=$?
    
    # Release lock if acquired
    if [[ "$LOCK_ACQUIRED" == "true" ]] && [[ -n "$LOCK_FILE" ]]; then
        rm -f "$LOCK_FILE"
        log_debug "Released lock: $LOCK_FILE"
    fi
    
    # Clean up temporary files
    for temp_file in "${TEMP_FILES[@]}"; do
        if [[ -e "$temp_file" ]]; then
            rm -rf "$temp_file"
            log_debug "Removed temp file: $temp_file"
        fi
    done
    
    return $exit_code
}

# ========================
# Utility Functions
# ========================

# Check if command exists
command_exists() {
    command -v "$1" &>/dev/null
}

# Check if running as root
is_root() {
    [[ $EUID -eq 0 ]]
}

# Require root privileges
require_root() {
    if ! is_root; then
        log_error "This operation requires root privileges"
        log_info "Please run with sudo"
        exit 1
    fi
}

# Require non-root
require_non_root() {
    if is_root; then
        log_error "This operation should not be run as root"
        log_info "Please run as a normal user"
        exit 1
    fi
}

# Confirm action
confirm() {
    local prompt="${1:-Continue?}"
    local default="${2:-n}"
    local response
    
    if [[ "$default" == "y" ]]; then
        prompt="$prompt [Y/n]: "
    else
        prompt="$prompt [y/N]: "
    fi
    
    if [[ "$IS_TTY" == "false" ]]; then
        log_warn "Non-interactive mode, using default: $default"
        [[ "$default" == "y" ]]
        return $?
    fi
    
    read -r -p "$prompt" response
    response=${response:-$default}
    
    [[ "$response" =~ ^[Yy]$ ]]
}

# Retry command with exponential backoff
retry_with_backoff() {
    local max_attempts="${1:-5}"
    local delay="${2:-1}"
    local max_delay="${3:-60}"
    shift 3
    
    local attempt=1
    while [[ $attempt -le $max_attempts ]]; do
        if "$@"; then
            return 0
        fi
        
        if [[ $attempt -lt $max_attempts ]]; then
            log_warn "Attempt $attempt failed, retrying in ${delay}s..."
            sleep "$delay"
            delay=$((delay * 2))
            [[ $delay -gt $max_delay ]] && delay=$max_delay
        fi
        
        ((attempt++))
    done
    
    log_error "All $max_attempts attempts failed"
    return 1
}

# Create temporary file/directory
create_temp_file() {
    local template="${1:-nixos-script.XXXXXX}"
    local temp_file
    temp_file="$(mktemp -t "$template")"
    TEMP_FILES+=("$temp_file")
    echo "$temp_file"
}

create_temp_dir() {
    local template="${1:-nixos-script.XXXXXX}"
    local temp_dir
    temp_dir="$(mktemp -d -t "$template")"
    TEMP_FILES+=("$temp_dir")
    echo "$temp_dir"
}

# Lock file management
acquire_lock() {
    local lock_name="${1:-script}"
    LOCK_FILE="/tmp/.nixos-${lock_name}.lock"
    
    local timeout="${2:-60}"
    local elapsed=0
    
    while [[ $elapsed -lt $timeout ]]; do
        if mkdir "$LOCK_FILE" 2>/dev/null; then
            LOCK_ACQUIRED=true
            echo $$ > "$LOCK_FILE/pid"
            log_debug "Acquired lock: $LOCK_FILE"
            return 0
        fi
        
        # Check if the process holding the lock is still running
        if [[ -f "$LOCK_FILE/pid" ]]; then
            local pid
            pid=$(<"$LOCK_FILE/pid")
            if ! kill -0 "$pid" 2>/dev/null; then
                log_warn "Removing stale lock from PID $pid"
                rm -rf "$LOCK_FILE"
                continue
            fi
        fi
        
        sleep 1
        ((elapsed++))
    done
    
    log_error "Failed to acquire lock after ${timeout}s"
    return 1
}

release_lock() {
    if [[ "$LOCK_ACQUIRED" == "true" ]] && [[ -n "$LOCK_FILE" ]]; then
        rm -rf "$LOCK_FILE"
        LOCK_ACQUIRED=false
        log_debug "Released lock: $LOCK_FILE"
    fi
}

# Backup file/directory
backup_file() {
    local file="$1"
    local backup_dir="${2:-backups}"
    local timestamp
    timestamp="$(date +%Y%m%d_%H%M%S)"
    
    if [[ ! -e "$file" ]]; then
        log_warn "File does not exist: $file"
        return 1
    fi
    
    mkdir -p "$backup_dir"
    local backup_path="$backup_dir/$(basename "$file").backup.$timestamp"
    
    cp -a "$file" "$backup_path"
    log_info "Backed up $file to $backup_path"
    echo "$backup_path"
}

# Version comparison
version_gt() {
    test "$(printf '%s\n' "$@" | sort -V | head -n 1)" != "$1"
}

version_ge() {
    test "$(printf '%s\n' "$@" | sort -V | head -n 1)" = "$2"
}

# Check system requirements
check_requirements() {
    local requirements=("$@")
    local missing=()
    
    for cmd in "${requirements[@]}"; do
        if ! command_exists "$cmd"; then
            missing+=("$cmd")
        fi
    done
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        log_error "Missing required commands: ${missing[*]}"
        log_info "Please install the missing dependencies"
        return 1
    fi
    
    return 0
}

# Get script runtime
get_runtime() {
    local start_time=$1
    local end_time
    end_time=$(date +%s)
    local runtime=$((end_time - start_time))
    
    local hours=$((runtime / 3600))
    local minutes=$(((runtime % 3600) / 60))
    local seconds=$((runtime % 60))
    
    if [[ $hours -gt 0 ]]; then
        printf "%dh %dm %ds" $hours $minutes $seconds
    elif [[ $minutes -gt 0 ]]; then
        printf "%dm %ds" $minutes $seconds
    else
        printf "%ds" $seconds
    fi
}

# Parse command line options
parse_options() {
    local -n opts=$1
    shift
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                opts[help]=true
                ;;
            -v|--verbose)
                LOG_LEVEL=$LOG_LEVEL_DEBUG
                opts[verbose]=true
                ;;
            -q|--quiet)
                LOG_LEVEL=$LOG_LEVEL_ERROR
                opts[quiet]=true
                ;;
            -n|--dry-run)
                opts[dry_run]=true
                ;;
            -f|--force)
                opts[force]=true
                ;;
            -y|--yes)
                opts[yes]=true
                ;;
            -*)
                log_error "Unknown option: $1"
                return 1
                ;;
            *)
                opts[args]+="$1 "
                ;;
        esac
        shift
    done
}

# Export all functions
export -f log log_debug log_info log_warn log_error log_critical
export -f print_header print_success print_warning print_error print_info print_step
export -f spinner progress_bar
export -f error_handler setup_error_handling cleanup_on_exit
export -f command_exists is_root require_root require_non_root
export -f confirm retry_with_backoff
export -f create_temp_file create_temp_dir
export -f acquire_lock release_lock
export -f backup_file
export -f version_gt version_ge
export -f check_requirements get_runtime parse_options