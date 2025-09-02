#!/usr/bin/env bash
# Git Operations Library
# Provides Git-related functions for NixOS configuration management

# Check if we're in a git repository
is_git_repo() {
    git rev-parse --git-dir >/dev/null 2>&1
}

# Initialize git repository if needed
init_git_repo() {
    if ! is_git_repo; then
        log_warn "Not in a git repository"
        if confirm "Initialize git repository?" "y"; then
            run_git "init" "Initialize git repository"
            run_git "add ." "Stage all files"
            run_git "commit -m 'Initial commit'" "Create initial commit" || true
            print_success "Git repository initialized"
            return 0
        else
            log_error "Git repository required for flakes"
            return 1
        fi
    fi
    return 0
}

# Get count of modified files
get_modified_count() {
    git status --porcelain 2>/dev/null | wc -l
}

# Check if there are unstaged changes
has_unstaged_changes() {
    [[ $(get_modified_count) -gt 0 ]]
}

# Check if there are staged changes
has_staged_changes() {
    [[ $(git diff --cached 2>/dev/null | wc -l) -gt 0 ]]
}

# Stage all changes
stage_all_changes() {
    if has_unstaged_changes; then
        local modified_count
        modified_count=$(get_modified_count)
        log_info "Found $modified_count modified files"
        
        run_git "add -A" "Stage all changes"
        print_success "Changes staged"
        return 0
    else
        log_debug "No changes to stage"
        return 1
    fi
}

# Auto-stage changes for rebuild
auto_stage_for_rebuild() {
    local no_stage="${1:-false}"
    
    if [[ "$no_stage" == "true" ]]; then
        log_debug "Auto-staging disabled"
        return 0
    fi
    
    if ! is_git_repo; then
        log_debug "Not in git repository, skipping auto-stage"
        return 0
    fi
    
    if has_unstaged_changes; then
        local modified_count
        modified_count=$(get_modified_count)
        log_info "Found $modified_count modified files"
        
        if [[ "${AUTO_YES:-false}" == "true" ]] || [[ "${AUTO_STAGE:-true}" == "true" ]]; then
            stage_all_changes
        else
            log_warn "Repository has unstaged changes"
            log_info "Flakes only see committed/staged files"
            
            if confirm "Stage all changes?" "y"; then
                stage_all_changes
            fi
        fi
    fi
}

# Auto-commit changes
auto_commit_changes() {
    local no_commit="${1:-false}"
    local message="${2:-Configuration update $(date +%Y-%m-%d)}"
    
    if [[ "$no_commit" == "true" ]]; then
        log_debug "Auto-commit disabled"
        return 0
    fi
    
    if [[ "${AUTO_COMMIT:-true}" != "true" ]]; then
        log_debug "Auto-commit not enabled"
        return 0
    fi
    
    if has_staged_changes; then
        log_info "Creating auto-commit: $message"
        run_git "commit -m '$message'" "Commit changes" >/dev/null
        print_success "Changes committed"
        return 0
    else
        log_debug "No staged changes to commit"
        return 1
    fi
}

# Prepare git for rebuild (stage and optionally commit)
prepare_git_for_rebuild() {
    local no_stage="${1:-false}"
    local no_commit="${2:-false}"
    
    if ! is_git_repo; then
        log_debug "Not in git repository"
        return 0
    fi
    
    # Stage changes
    auto_stage_for_rebuild "$no_stage"
    
    # Commit if needed
    if [[ "$no_stage" != "true" ]]; then
        auto_commit_changes "$no_commit"
    fi
    
    return 0
}

# Add file to git
add_file_to_git() {
    local file="$1"
    
    if ! is_git_repo; then
        log_debug "Not in git repository"
        return 0
    fi
    
    if [[ -f "$file" ]]; then
        run_git "add '$file'" "Add $file to git" 2>/dev/null || true
    fi
}

# Get current branch
get_current_branch() {
    git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "main"
}

# Get latest commit hash
get_latest_commit() {
    git rev-parse --short HEAD 2>/dev/null || echo "none"
}

# Check if file is tracked by git
is_tracked() {
    local file="$1"
    git ls-files --error-unmatch "$file" >/dev/null 2>&1
}

# Check if file is ignored
is_ignored() {
    local file="$1"
    git check-ignore "$file" >/dev/null 2>&1
}

# Create backup branch before major changes
create_backup_branch() {
    local branch_name="${1:-backup-$(date +%Y%m%d-%H%M%S)}"
    
    if is_git_repo; then
        log_info "Creating backup branch: $branch_name"
        run_git "branch '$branch_name'" "Create backup branch"
        return 0
    fi
    return 1
}

# Show git status summary
show_git_status() {
    if ! is_git_repo; then
        return 0
    fi
    
    local modified_count
    modified_count=$(get_modified_count)
    
    if [[ $modified_count -gt 0 ]]; then
        log_info "Git status: $modified_count modified files"
        if [[ "${VERBOSE:-false}" == "true" ]]; then
            git status --short
        fi
    else
        log_debug "Git status: clean"
    fi
}

# Export all functions
export -f is_git_repo init_git_repo get_modified_count
export -f has_unstaged_changes has_staged_changes
export -f stage_all_changes auto_stage_for_rebuild auto_commit_changes
export -f prepare_git_for_rebuild add_file_to_git
export -f get_current_branch get_latest_commit
export -f is_tracked is_ignored create_backup_branch
export -f show_git_status