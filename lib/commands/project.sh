#!/bin/bash

# ============================================================================
# Project Command Handler
# ============================================================================

project_command() {
  local subcommand="${1:-}"
  shift 2>/dev/null || true
  
  case "$subcommand" in
    create)
      project_create "$@"
      ;;
    -h|--help)
      project_help
      ;;
    *)
      error "Unknown project subcommand: $subcommand"
      project_help
      return 1
      ;;
  esac
}

project_help() {
  cat <<EOF
Usage: envforge project create <name> [options]

Options:
  --path <dir>        Create project in specified directory (default: current)
  --tools <list>      Comma-separated list of tools to declare (e.g., java,gradle)
  -h, --help          Show this help message

Examples:
  envforge project create my-project
  envforge project create my-project --path /tmp
  envforge project create my-project --tools java,gradle,cmake
EOF
}

project_create() {
  local proj_name="${1:-}"
  shift || true
  
  if [[ -z "$proj_name" ]]; then
    error "Project name is required"
    project_help
    return 1
  fi
  
  # Check for help flag early
  for arg in "$@"; do
    if [[ "$arg" == "-h" ]] || [[ "$arg" == "--help" ]]; then
      project_help
      return 0
    fi
  done
  
  # Validate project name
  if ! validate_name "$proj_name"; then
    return 1
  fi
  
  # Check if we're already in a project
  local current_context=$(get_context_type)
  if [[ "$current_context" == "$CONTEXT_PROJECT" ]]; then
    error "Cannot create project inside another project"
    return 1
  fi
  
  # Parse additional options
  local proj_path=""
  local tools_list=""
  
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --path)
        proj_path="$2"
        shift 2
        ;;
      --tools)
        tools_list="$2"
        shift 2
        ;;
      -h|--help)
        project_help
        return 0
        ;;
      *)
        error "Unknown option: $1"
        return 1
        ;;
    esac
  done
  
  # Use current directory if no path specified
  if [[ -z "$proj_path" ]]; then
    proj_path="$PWD/$proj_name"
  else
    proj_path="${proj_path/#\~/$HOME}/$proj_name"
  fi
  
  # Validate path
  if ! validate_path "$(dirname "$proj_path")"; then
    return 1
  fi
  
  # Check if project already exists
  if file_exists "$proj_path"; then
    error "Project already exists: $proj_path"
    return 1
  fi
  
  # Create project directory structure
  log "Creating project: $proj_name"
  
  if ! mkdir_safe "$proj_path"; then
    return 1
  fi
  
  if ! mkdir_safe "$proj_path/.bin"; then
    return 1
  fi
  
  if ! mkdir_safe "$proj_path/.envforge"; then
    return 1
  fi
  
  # Create .envrc
  if ! create_project_envrc "$proj_path"; then
    return 1
  fi
  
  # Create tools.yaml
  if ! create_tools_yaml "$proj_path" "$tools_list"; then
    return 1
  fi
  
  # Create default .bin scripts
  if ! create_default_bin_scripts "$proj_path"; then
    return 1
  fi
  
  # Create README.md
  if ! create_project_readme "$proj_path" "$proj_name"; then
    return 1
  fi
  
  # Log to audit
  audit_log "Project created: $proj_path"
  
  success "Project created successfully!"
  log "Location: $proj_path"
  log "Next steps:"
  log "  1. cd $proj_path"
  log "  2. direnv allow"
  log "  3. envforge tool install <tool>"
  
  return 0
}

# Create .envrc for project
create_project_envrc() {
  local proj_path="$1"
  local envrc_file="$proj_path/.envrc"
  
  debug "Creating .envrc: $envrc_file"
  
  cat > "$envrc_file" <<'EOF'
# envforge project environment
export ENVFORGE_TYPE=project
export ENVFORGE_CACHE="${HOME}/.envforge/tools"

# Add project bin to PATH
path_add "$PWD/.bin"
EOF
  
  if [[ $? -ne 0 ]]; then
    error "Failed to create .envrc"
    return 1
  fi
  
  return 0
}

# Create default .bin scripts
create_default_bin_scripts() {
  local proj_path="$1"
  local bin_dir="$proj_path/.bin"
  
  debug "Creating default .bin scripts"
  
  # build script
  cat > "$bin_dir/build" <<'EOF'
#!/bin/bash
# .bin/build - Adapter for project build

if [[ -f "build.gradle" ]]; then
  gradle build "$@"
elif [[ -f "CMakeLists.txt" ]]; then
  cmake --build build "$@"
elif [[ -f "Makefile" ]]; then
  make "$@"
else
  echo "Error: No build tool detected" >&2
  echo "Supported: build.gradle, CMakeLists.txt, Makefile" >&2
  exit 1
fi
EOF
  make_executable "$bin_dir/build" || return 1
  
  # run script
  cat > "$bin_dir/run" <<'EOF'
#!/bin/bash
# .bin/run - Run the project

echo "Error: run script not configured for this project" >&2
echo "Edit .bin/run to implement project-specific run logic" >&2
exit 1
EOF
  make_executable "$bin_dir/run" || return 1
  
  # test script
  cat > "$bin_dir/test" <<'EOF'
#!/bin/bash
# .bin/test - Run project tests

if [[ -f "build.gradle" ]]; then
  gradle test "$@"
elif [[ -f "CMakeLists.txt" ]]; then
  cd build && ctest "$@"
elif [[ -f "Makefile" ]] && grep -q "^test:" Makefile; then
  make test "$@"
else
  echo "Error: No test framework detected" >&2
  exit 1
fi
EOF
  make_executable "$bin_dir/test" || return 1
  
  # clean script
  cat > "$bin_dir/clean" <<'EOF'
#!/bin/bash
# .bin/clean - Clean project artifacts

if [[ -f "build.gradle" ]]; then
  gradle clean "$@"
elif [[ -d "build" ]]; then
  rm -rf build "$@"
elif [[ -f "Makefile" ]] && grep -q "^clean:" Makefile; then
  make clean "$@"
else
  echo "Warning: No clean target found" >&2
fi
EOF
  make_executable "$bin_dir/clean" || return 1
  
  # brun script (build + run)
  cat > "$bin_dir/brun" <<'EOF'
#!/bin/bash
# .bin/brun - Build and run in one command

"$PWD/.bin/build" && "$PWD/.bin/run" "$@"
EOF
  make_executable "$bin_dir/brun" || return 1
  
  debug "Created default .bin scripts"
  return 0
}

# Create README.md for project
create_project_readme() {
  local proj_path="$1"
  local proj_name="$2"
  local readme_file="$proj_path/README.md"
  
  debug "Creating README.md: $readme_file"
  
  cat > "$readme_file" <<EOF
# $proj_name Project

This is an envforge project. It provides a reproducible development environment using direnv and locally-managed tools.

## Getting Started

1. Enable direnv for this project:
   \`\`\`bash
   direnv allow
   \`\`\`

2. Install required tools:
   \`\`\`bash
   envforge tool install java@21
   envforge tool install gradle@8.5
   \`\`\`

3. Build and run:
   \`\`\`bash
   .bin/build
   .bin/run
   .bin/test
   \`\`\`

## Scripts

The \`.bin/\` directory contains project scripts:
- **build**: Build the project (auto-detects Gradle, CMake, Makefile)
- **run**: Execute the project
- **test**: Run test suite
- **clean**: Remove build artifacts
- **brun**: Build and run in one command

## Tools

Tools are declared in \`.envforge/tools.yaml\`. Each tool is installed globally in \`~/.envforge/tools/\` and referenced locally via environment variables.

## Learn More

See PLAN.md in the envforge repository for architecture details.
EOF
  
  if [[ $? -ne 0 ]]; then
    error "Failed to create README.md"
    return 1
  fi
  
  return 0
}
