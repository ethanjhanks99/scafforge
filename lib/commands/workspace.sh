#!/bin/bash

# ============================================================================
# Workspace Command Handler
# ============================================================================

workspace_command() {
  local subcommand="${1:-}"
  shift 2>/dev/null || true
  
  case "$subcommand" in
    create)
      workspace_create "$@"
      ;;
    -h|--help)
      workspace_help
      ;;
    *)
      error "Unknown workspace subcommand: $subcommand"
      workspace_help
      return 1
      ;;
  esac
}

workspace_help() {
  cat <<EOF
Usage: envforge workspace create <name> [options]

Options:
  --path <dir>        Create workspace in specified directory (default: current)
  --tools <list>      Comma-separated list of tools to declare (e.g., java,gradle)
  -h, --help          Show this help message

Examples:
  envforge workspace create my-workspace
  envforge workspace create my-workspace --path /tmp
  envforge workspace create my-workspace --tools java,gradle,cmake
EOF
}

workspace_create() {
  local ws_name="${1:-}"
  shift || true
  
  if [[ -z "$ws_name" ]]; then
    error "Workspace name is required"
    workspace_help
    return 1
  fi
  
  # Check for help flag early
  for arg in "$@"; do
    if [[ "$arg" == "-h" ]] || [[ "$arg" == "--help" ]]; then
      workspace_help
      return 0
    fi
  done
  
  # Validate workspace name
  if ! validate_name "$ws_name"; then
    return 1
  fi
  
  # Parse additional options
  local ws_path=""
  local tools_list=""
  
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --path)
        ws_path="$2"
        shift 2
        ;;
      --tools)
        tools_list="$2"
        shift 2
        ;;
      -h|--help)
        workspace_help
        return 0
        ;;
      *)
        error "Unknown option: $1"
        return 1
        ;;
    esac
  done
  
  # Use current directory if no path specified
  if [[ -z "$ws_path" ]]; then
    ws_path="$PWD/$ws_name"
  else
    ws_path="${ws_path/#\~/$HOME}/$ws_name"
  fi
  
  # Validate path
  if ! validate_path "$(dirname "$ws_path")"; then
    return 1
  fi
  
  # Check if workspace already exists
  if file_exists "$ws_path"; then
    error "Workspace already exists: $ws_path"
    return 1
  fi
  
  # Create workspace directory structure
  log "Creating workspace: $ws_name"
  
  if ! mkdir_safe "$ws_path"; then
    return 1
  fi
  
  if ! mkdir_safe "$ws_path/.bin"; then
    return 1
  fi
  
  if ! mkdir_safe "$ws_path/.envforge"; then
    return 1
  fi
  
  # Create .envrc
  if ! create_workspace_envrc "$ws_path"; then
    return 1
  fi
  
  # Create tools.yaml
  if ! create_tools_yaml "$ws_path" "$tools_list"; then
    return 1
  fi
  
  # Create README.md
  if ! create_workspace_readme "$ws_path" "$ws_name"; then
    return 1
  fi
  
  # Log to audit
  audit_log "Workspace created: $ws_path"
  
  success "Workspace created successfully!"
  log "Location: $ws_path"
  log "Next steps:"
  log "  1. cd $ws_path"
  log "  2. direnv allow"
  log "  3. envforge project create <project-name>"
  
  return 0
}

# Create .envrc for workspace
create_workspace_envrc() {
  local ws_path="$1"
  local envrc_file="$ws_path/.envrc"
  
  debug "Creating .envrc: $envrc_file"
  
  cat > "$envrc_file" <<'EOF'
# envforge workspace environment
export ENVFORGE_TYPE=workspace
export ENVFORGE_CACHE="${HOME}/.envforge/tools"

# Add workspace bin to PATH
path_add "$PWD/.bin"
EOF
  
  if [[ $? -ne 0 ]]; then
    error "Failed to create .envrc"
    return 1
  fi
  
  return 0
}

# Create tools.yaml for workspace
create_tools_yaml() {
  local ws_path="$1"
  local tools_list="$2"
  local tools_file="$ws_path/.envforge/tools.yaml"
  
  debug "Creating tools.yaml: $tools_file"
  
  cat > "$tools_file" <<'EOF'
# envforge tools configuration
# List tools and their versions required by this workspace
tools: {}
  # Example:
  # java:
  #   version: "21"
  #   path: "~/.envforge/tools/java/21"
  # gradle:
  #   version: "8.5"
  #   path: "~/.envforge/tools/gradle/8.5"
EOF
  
  if [[ $? -ne 0 ]]; then
    error "Failed to create tools.yaml"
    return 1
  fi
  
  # TODO: Pre-populate with tools_list if provided
  
  return 0
}

# Create README.md for workspace
create_workspace_readme() {
  local ws_path="$1"
  local ws_name="$2"
  local readme_file="$ws_path/README.md"
  
  debug "Creating README.md: $readme_file"
  
  cat > "$readme_file" <<EOF
# $ws_name Workspace

This is an envforge workspace. It provides a reproducible development environment using direnv and local tool installations.

## Getting Started

1. Enable direnv for this workspace:
   \`\`\`bash
   direnv allow
   \`\`\`

2. Create projects within this workspace:
   \`\`\`bash
   envforge project create my-project
   \`\`\`

3. Add tools to projects:
   \`\`\`bash
   cd my-project
   envforge tool install java@21
   \`\`\`

## Structure

- \`.envrc\`: direnv configuration (defines environment)
- \`.bin/\`: Workspace-level scripts
- \`.envforge/tools.yaml\`: Tool declarations
- \`projects/\`: Recommended location for nested projects

## Learn More

See PLAN.md in the envforge repository for architecture details.
EOF
  
  if [[ $? -ne 0 ]]; then
    error "Failed to create README.md"
    return 1
  fi
  
  return 0
}
