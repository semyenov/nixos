#!/usr/bin/env bash
# Options Parser Library
# Provides consistent command-line option parsing

# Parse common options used across all commands
# Usage: parse_common_options "$@"
# Sets: DRY_RUN, VERBOSE, FORCE, AUTO_YES
parse_common_options() {
    local -a remaining_args=()
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                echo "help"
                return 0
                ;;
            -v|--verbose)
                VERBOSE=true
                LOG_LEVEL=$LOG_LEVEL_DEBUG
                shift
                ;;
            -n|--dry-run)
                DRY_RUN=true
                shift
                ;;
            -f|--force)
                FORCE=true
                shift
                ;;
            -y|--yes)
                AUTO_YES=true
                shift
                ;;
            *)
                remaining_args+=("$1")
                shift
                ;;
        esac
    done
    
    # Return remaining arguments
    printf '%s\n' "${remaining_args[@]}"
}

# Parse rebuild command options
# Usage: parse_rebuild_options "$@"
parse_rebuild_options() {
    local operation="switch"
    local upgrade=false
    local no_stage=false
    local no_commit=false
    local show_trace=false
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -u|--upgrade)
                upgrade=true
                shift
                ;;
            --no-stage)
                no_stage=true
                shift
                ;;
            --no-commit)
                no_commit=true
                shift
                ;;
            --show-trace)
                show_trace=true
                VERBOSE=true
                shift
                ;;
            switch|test|boot|dry-build)
                operation="$1"
                shift
                ;;
            *)
                shift
                ;;
        esac
    done
    
    # Export parsed options
    export REBUILD_OPERATION="$operation"
    export REBUILD_UPGRADE="$upgrade"
    export REBUILD_NO_STAGE="$no_stage"
    export REBUILD_NO_COMMIT="$no_commit"
    export REBUILD_SHOW_TRACE="$show_trace"
}

# Parse setup command options
# Usage: parse_setup_options "$@"
parse_setup_options() {
    local skip_hardware=false
    local skip_sops=false
    local skip_test=false
    local skip_build=false
    local quick=false
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --skip-hardware)
                skip_hardware=true
                shift
                ;;
            --skip-sops)
                skip_sops=true
                shift
                ;;
            --skip-test)
                skip_test=true
                shift
                ;;
            --skip-build)
                skip_build=true
                shift
                ;;
            -q|--quick)
                quick=true
                AUTO_YES=true
                shift
                ;;
            *)
                shift
                ;;
        esac
    done
    
    # Export parsed options
    export SETUP_SKIP_HARDWARE="$skip_hardware"
    export SETUP_SKIP_SOPS="$skip_sops"
    export SETUP_SKIP_TEST="$skip_test"
    export SETUP_SKIP_BUILD="$skip_build"
    export SETUP_QUICK="$quick"
}

# Parse test command options
# Usage: parse_test_options "$@"
parse_test_options() {
    local -a tests_to_run=()
    local parallel=true
    local fail_fast=false
    local format="terminal"
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -s|--sequential)
                parallel=false
                shift
                ;;
            -f|--fail-fast)
                fail_fast=true
                parallel=false
                shift
                ;;
            --format)
                shift
                format="$1"
                shift
                ;;
            all)
                tests_to_run=(syntax flake build modules secrets hardware security performance shellcheck formatting)
                shift
                ;;
            syntax|flake|build|modules|secrets|hardware|security|performance|shellcheck|formatting)
                tests_to_run+=("$1")
                shift
                ;;
            *)
                shift
                ;;
        esac
    done
    
    # Default to all tests if none specified
    [[ ${#tests_to_run[@]} -eq 0 ]] && tests_to_run=(syntax flake build modules secrets hardware security)
    
    # Export parsed options
    export TEST_PARALLEL="$parallel"
    export TEST_FAIL_FAST="$fail_fast"
    export TEST_FORMAT="$format"
    export TEST_TO_RUN="${tests_to_run[*]}"
}

# Parse clean command options
# Usage: parse_clean_options "$@"
parse_clean_options() {
    local keep_generations=5
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -k|--keep)
                shift
                keep_generations="$1"
                shift
                ;;
            -a|--all)
                keep_generations=0
                shift
                ;;
            *)
                shift
                ;;
        esac
    done
    
    export CLEAN_KEEP_GENERATIONS="$keep_generations"
}

# Parse update command options
# Usage: parse_update_options "$@"
parse_update_options() {
    local input=""
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                # Help is handled earlier
                shift
                ;;
            -*)
                # Unknown option
                shift
                ;;
            *)
                # Assume it's an input name
                input="$1"
                shift
                ;;
        esac
    done
    
    export UPDATE_INPUT="$input"
}

# Check if help was requested
# Usage: if is_help_requested "$@"; then show_help; fi
is_help_requested() {
    for arg in "$@"; do
        case "$arg" in
            -h|--help|help)
                return 0
                ;;
        esac
    done
    return 1
}

# Validate required options
# Usage: validate_required_option "VARIABLE_NAME" "Option description"
validate_required_option() {
    local var_name="$1"
    local description="$2"
    
    if [[ -z "${!var_name}" ]]; then
        log_error "$description is required"
        return 1
    fi
    return 0
}

# Export all functions
export -f parse_common_options parse_rebuild_options parse_setup_options
export -f parse_test_options parse_clean_options parse_update_options
export -f is_help_requested validate_required_option