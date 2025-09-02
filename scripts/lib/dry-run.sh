#!/usr/bin/env bash
# Dry Run Utilities Library
# Provides consistent dry-run handling across scripts

# Global dry-run state (should be set by main script)
DRY_RUN="${DRY_RUN:-false}"

# Execute command only if not in dry-run mode
# Usage: run_command "command" "description"
run_command() {
    local command="$1"
    local description="${2:-$1}"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would execute: $description"
        return 0
    else
        eval "$command"
        return $?
    fi
}

# Execute command with output capture
# Usage: output=$(run_command_capture "command" "description")
run_command_capture() {
    local command="$1"
    local description="${2:-$1}"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would execute: $description"
        echo "[DRY RUN OUTPUT]"
        return 0
    else
        eval "$command"
        return $?
    fi
}

# Run file operation
# Usage: run_file_op "operation" "file" "description"
run_file_op() {
    local operation="$1"
    local file="$2"
    local description="${3:-$operation $file}"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would $description"
        return 0
    else
        case "$operation" in
            create)
                touch "$file"
                ;;
            delete|remove)
                rm -f "$file"
                ;;
            mkdir)
                mkdir -p "$file"
                ;;
            copy)
                local dest="$3"
                cp "$file" "$dest"
                ;;
            move)
                local dest="$3"
                mv "$file" "$dest"
                ;;
            *)
                log_error "Unknown file operation: $operation"
                return 1
                ;;
        esac
        return $?
    fi
}

# Write content to file
# Usage: write_file "file" "content" "description"
write_file() {
    local file="$1"
    local content="$2"
    local description="${3:-write to $file}"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would $description"
        if [[ "$VERBOSE" == "true" ]]; then
            echo "[DRY RUN] File content would be:"
            echo "$content" | sed 's/^/  /'
        fi
        return 0
    else
        echo "$content" > "$file"
        return $?
    fi
}

# Append content to file
# Usage: append_file "file" "content" "description"
append_file() {
    local file="$1"
    local content="$2"
    local description="${3:-append to $file}"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would $description"
        if [[ "$VERBOSE" == "true" ]]; then
            echo "[DRY RUN] Would append:"
            echo "$content" | sed 's/^/  /'
        fi
        return 0
    else
        echo "$content" >> "$file"
        return $?
    fi
}

# Run sudo command
# Usage: run_sudo "command" "description"
run_sudo() {
    local command="$1"
    local description="${2:-$1}"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would execute with sudo: $description"
        return 0
    else
        sudo $command
        return $?
    fi
}

# Run git command
# Usage: run_git "command" "description"
run_git() {
    local command="$1"
    local description="${2:-git $1}"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would execute: $description"
        return 0
    else
        git $command
        return $?
    fi
}

# Run nix command
# Usage: run_nix "command" "description"
run_nix() {
    local command="$1"
    local description="${2:-nix $1}"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would execute: $description"
        return 0
    else
        nix $command
        return $?
    fi
}

# Run nixos-rebuild
# Usage: run_nixos_rebuild "operation" "args"
run_nixos_rebuild() {
    local operation="$1"
    local args="${2:-}"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would execute: sudo nixos-rebuild $operation $args"
        return 0
    else
        sudo nixos-rebuild "$operation" $args
        return $?
    fi
}

# Check if in dry-run mode
is_dry_run() {
    [[ "$DRY_RUN" == "true" ]]
}

# Set dry-run mode
set_dry_run() {
    DRY_RUN="${1:-true}"
    export DRY_RUN
}

# Print dry-run warning
show_dry_run_warning() {
    if is_dry_run; then
        print_warning "DRY RUN MODE - No changes will be made"
    fi
}

# Dry-run wrapper for any command
# Usage: dry_run_wrapper command args...
dry_run_wrapper() {
    if is_dry_run; then
        log_info "[DRY RUN] Would execute: $*"
        return 0
    else
        "$@"
        return $?
    fi
}

# Export all functions
export -f run_command run_command_capture run_file_op
export -f write_file append_file
export -f run_sudo run_git run_nix run_nixos_rebuild
export -f is_dry_run set_dry_run show_dry_run_warning
export -f dry_run_wrapper