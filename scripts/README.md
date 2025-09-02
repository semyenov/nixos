# Scripts Directory

This directory contains helper scripts and libraries for managing the NixOS configuration.

> **Note**: These are legacy libraries used by the shell scripts. The project is migrating to [Taskfile](../Taskfile.yml) for task automation. New functionality should be added as tasks rather than shell scripts.

## Structure

```
scripts/
├── README.md       # This file
└── lib/            # Shell script libraries (legacy)
    ├── common.sh   # Shared bash library
    ├── dry-run.sh  # Dry-run functionality
    ├── errors.sh   # Error handling
    ├── git.sh      # Git operations
    ├── help.sh     # Help text generation
    ├── options.sh  # Option parsing
    └── tests.sh    # Test functions
```

## Common Library (`lib/common.sh`)

A comprehensive bash library providing utilities for all management scripts.

### Features

- **Logging**: Colored output with log levels
- **Error Handling**: Automatic error trapping and stack traces
- **User Interaction**: Confirmations and progress indicators
- **File Management**: Temporary files, backups, locking
- **Utilities**: Command checking, retry logic, option parsing

### Usage

Source the library in your scripts:

```bash
#!/usr/bin/env bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/scripts/lib/common.sh"

# Setup error handling
setup_error_handling

# Use logging functions
log_info "Starting process..."
print_success "Operation completed"
print_error "Something went wrong"

# Show progress
spinner $! "Processing..."
progress_bar $current $total

# User interaction
if confirm "Continue?" "y"; then
    log_info "Proceeding..."
fi

# Check requirements
check_requirements git nix age sops
```

### Available Functions

#### Logging
- `log_debug`, `log_info`, `log_warn`, `log_error`, `log_critical`
- `print_success`, `print_warning`, `print_error`, `print_info`, `print_step`
- `print_header` - Display section headers

#### Progress Indicators
- `spinner` - Animated spinner for background tasks
- `progress_bar` - Progress bar for batch operations

#### Utility Functions
- `command_exists` - Check if command is available
- `is_root` - Check if running as root
- `require_root` - Exit if not root
- `require_non_root` - Exit if root
- `confirm` - Interactive yes/no prompt
- `retry_with_backoff` - Retry failed commands

#### File Operations
- `create_temp_file` - Create temporary file
- `create_temp_dir` - Create temporary directory
- `backup_file` - Create timestamped backup
- `acquire_lock` - Prevent concurrent execution
- `release_lock` - Release script lock

#### Error Handling
- `setup_error_handling` - Enable error trapping
- `error_handler` - Handle errors with stack trace
- `cleanup_on_exit` - Clean up on script exit

#### Parsing
- `parse_options` - Parse command-line options

### Environment Variables

The library respects these environment variables:

- `LOG_LEVEL` - Set logging verbosity (0-4)
- `NO_COLOR` - Disable colored output
- `COLUMNS` - Terminal width for formatting

### Example Script

```bash
#!/usr/bin/env bash
# Example script using common.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/scripts/lib/common.sh"

# Script configuration
readonly SCRIPT_NAME="Example Script"
readonly VERSION="1.0.0"

# Global options
DRY_RUN=false
VERBOSE=false

show_usage() {
    cat <<EOF
$SCRIPT_NAME v$VERSION

Usage: $(basename "$0") [OPTIONS]

Options:
    -h, --help      Show this help
    -v, --verbose   Enable verbose output
    -n, --dry-run   Preview changes only
EOF
}

main() {
    # Parse options
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                show_usage
                exit 0
                ;;
            -v|--verbose)
                VERBOSE=true
                LOG_LEVEL=$LOG_LEVEL_DEBUG
                ;;
            -n|--dry-run)
                DRY_RUN=true
                ;;
            *)
                log_error "Unknown option: $1"
                exit 1
                ;;
        esac
        shift
    done
    
    # Setup
    setup_error_handling
    
    # Header
    print_header "$SCRIPT_NAME"
    
    # Check requirements
    check_requirements git nix || exit 1
    
    # Main logic
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would perform action"
    else
        log_info "Performing action..."
        # Do something
        print_success "Action completed"
    fi
}

main "$@"
```

## Best Practices

1. **Always source common.sh** for consistency
2. **Use setup_error_handling** for robust error handling
3. **Implement dry-run mode** for safety
4. **Provide clear help messages**
5. **Use appropriate log levels**
6. **Clean up resources** in cleanup_on_exit
7. **Check requirements** before proceeding
8. **Use locks** for operations that shouldn't run concurrently

## Creating New Scripts

1. Create script in project root or scripts/
2. Source the common library
3. Use consistent option parsing
4. Implement help/usage function
5. Add error handling
6. Test with dry-run mode
7. Document in relevant README files

## Maintenance

The common library is shared across all scripts. Changes should:
- Maintain backward compatibility
- Be thoroughly tested
- Follow existing patterns
- Include documentation updates