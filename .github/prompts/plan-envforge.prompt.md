# PLAN.md: envforge Architecture & Design Specification

## 1. Goals and Non-Goals

### Primary Goals
- Enable reproducible project/workspace environments without global tool assumptions
- Automate environment setup (direnv integration, tool installation, PATH wiring)
- Provide a lightweight CLI for bootstrapping workspaces and projects
- Offer context-aware behavior: detect execution context (workspace vs. project vs. neither)
- Establish clear conventions for `.bin` scripts and tool delegation
- Zero system-wide pollution (all tools installed locally)

### Non-Goals
- Task running or build orchestration (projects define build behavior)
- Replacing existing build tools (Gradle, CMake, Maven, etc.)
- Global configuration or system-level changes
- Handling CI/CD pipeline configuration

---

## 2. Core Abstractions and Terminology

### Workspace
- A top-level container representing a course, monorepo, or shared context
- Provides: shared `.envrc`, shared `.bin/` scripts, shared tool installation directory
- Contains: one or more projects
- Projects inherit environment from parent workspace

### Project
- Smallest independently valid unit
- Can exist standalone or nested within a workspace
- Provides: project-specific `.envrc`, `.bin/` scripts, tool declarations
- Inherits workspace environment if nested
- Tools installed at project level remain project-local even when inheriting from workspace

### Tool
- External executable: Java, Gradle, CMake, Node, Python, etc.
- Installed once in global cache (`~/.envforge/tools/`) and referenced by projects/workspaces
- Projects declare required tools and versions in `.envforge/tools.yaml`
- `.envrc` references global installations via PATH modifications
- Never assumed to exist in system PATH; envforge manages availability

### Activation
- direnv automatically loads `.envrc` when entering a directory
- `.envrc` modifies PATH, environment variables, and available tools
- No side effects occur during `.envrc` evaluation (pure environment declaration)

### Delegation
- `.bin/` scripts act as command adapters (e.g., `build`, `run`, `test`)
- Each script delegates to underlying project tools (Gradle, CMake, etc.)
- Scripts know project conventions but don't implement core logic

---

## 3. Filesystem Layout and Directory Conventions

### Workspace Structure
```
my-workspace/                 # Workspace root
├── .envrc                     # Workspace environment (direnv)
├── .bin/                      # Workspace scripts (build, run, test, etc.)
├── .envforge/                 # envforge metadata
│   └── tools.yaml             # Tool declarations and versions
├── projects/                  # Recommended: nested projects
│   └── project-1/
│   └── project-2/
└── README.md
```

### Standalone Project Structure
```
my-project/                   # Project root
├── .envrc                     # Project environment (direnv)
├── .bin/                      # Project scripts
├── .envforge/                 # envforge metadata
│   └── tools.yaml             # Tool declarations and versions
├── src/                       # Project sources (convention)
├── build/                     # Project build outputs (convention)
└── README.md
```

### Directory Conventions
- `.envrc`: direnv manifest; declares available tools and environment variables
- `.bin/`: executable scripts; never modify these directly at runtime
- `.envforge/`: envforge metadata and configuration
- `.envrc.local`: optional user overrides (in `.gitignore`)

### Global Tool Cache
```
~/.envforge/
├── tools/                     # Global tool installations
│   ├── java/
│   │   ├── 17/
│   │   ├── 21/
│   │   └── 22/
│   ├── gradle/
│   │   ├── 8.5/
│   │   └── 8.6/
│   └── cmake/
│       └── 3.28/
└── cache/                     # Download cache for installers
```

---

## 4. CLI Command Structure and Context Rules

### CLI Shape
```bash
envforge workspace create <name> [--path <dir>] [--tools <comma-sep-list>]
envforge project create <name> [--path <dir>] [--tools <comma-sep-list>]
envforge tool install <tool> [--workspace] [--project]
envforge tool list [--installed] [--available]
envforge update                   # Check tools.yaml for changes and sync
envforge init                     # Initialize current directory as project/workspace
envforge status                   # Show current context (workspace/project/none)
```

### Context Detection Rules
1. **Workspace context**: Script executed inside directory containing `.envrc` with `ENVFORGE_TYPE=workspace`
2. **Project context**: Script executed inside directory containing `.envrc` with `ENVFORGE_TYPE=project`
3. **Nested context**: Project inside workspace inherits workspace environment
4. **Root context**: No `.envrc` found; envforge treats as standalone
5. **Default behavior**: Commands operate on current directory; `--path` overrides

### Context-Aware Behavior
- `envforge tool install gradle`: installs to global cache (`~/.envforge/tools/`); registers tool in current project/workspace `.envforge/tools.yaml`
- `envforge project create`: creates in current directory or `--path`; fails if already in project
- `envforge workspace create`: creates in current directory or `--path`; warns and confirms if nesting within another workspace

---

## 5. Tool Installation and Lifecycle Strategy

### Tool Installation
1. **Discovery**: envforge detects tool requests (from `tools.yaml` declarations or CLI)
2. **Check cache**: Look for existing installation in `~/.envforge/tools/<tool>/<version>/`
3. **Availability check**: If not cached, query remote registries (GitHub releases, Maven Central, official repos)
4. **Download**: Fetch binary/archive matching OS and architecture to `~/.envforge/cache/`
5. **Install**: Extract to `~/.envforge/tools/<tool>/<version>/` hierarchy
6. **Record**: Write metadata to project/workspace `.envforge/tools.yaml` (tool name, version)
7. **Availability**: Update `.envrc` to expose tool via PATH from global cache

### Tool Versioning
- Versions pinned per project/workspace in `.envforge/tools.yaml`
- Format: 
  ```yaml
  tools:
    gradle:
      version: "8.5"
      path: "~/.envforge/tools/gradle/8.5"
    java:
      version: "21"
      path: "~/.envforge/tools/java/21"
  ```
- `path` field allows users to override default global cache location with custom installations
- Tools installed once in global cache at `~/.envforge/tools/<tool>/<version>/` by default
- Multiple projects can reference the same cached tool installation
- CLI supports version selection: `envforge tool install gradle@8.5`
- `.envrc` respects pinned versions and paths; no automatic upgrades
- Versions are always pinned to ensure reproducibility

### Tool Removal
- `envforge tool remove <tool>` removes tool from current project/workspace `.envforge/tools.yaml`
- Does not delete from global cache (other projects may use it)
- `envforge tool prune` cleans unused versions from `~/.envforge/tools/` (not referenced by any project)
- `.envrc` cleanup may be needed after removal

### Update Workflow
- Users can manually edit `.envforge/tools.yaml` to change versions or add tools
- Running `envforge update` syncs the environment with the YAML configuration
- Missing tools are installed; changed versions trigger reinstallation
- Removed tools are uninstalled

### Supported Tools (Initial Set)
- **JVM**: Java, Gradle, Maven, Kotlin
- **C/C++**: CMake, GCC, Clang
- **Node.js**: Node, npm, yarn, pnpm, Next.js
- **Python**: Python, pip, pipenv, Poetry
- **Container & Orchestration**: Docker, Kubernetes
- **Other**: Git, Rust toolchain
- Extensible: users can define custom tool providers

---

## 6. `.envrc` Responsibilities and Constraints

### `.envrc` Must
- Declare available tools and versions
- Modify PATH to include global tool cache (`~/.envforge/tools/`) and local `.bin/`
- Export version information (e.g., `JAVA_HOME`, `GRADLE_HOME`) pointing to global cache
- Load direnv stdlib (e.g., `use flake`, `dotenv`)
- Be idempotent and side-effect-free

### `.envrc` Must NOT
- Run installation scripts
- Download or extract tools
- Execute build commands
- Write files to disk (except via direnv's own mechanisms)
- Assume global tools exist

### Workspace `.envrc`
```bash
export ENVFORGE_TYPE=workspace
export ENVFORGE_CACHE="$HOME/.envforge/tools"

# Load tools into PATH from global cache
path_add "$PWD/.bin"
path_add "$ENVFORGE_CACHE/java/21/bin"
path_add "$ENVFORGE_CACHE/gradle/8.5/bin"

# Export tool homes pointing to global cache
export JAVA_HOME="$ENVFORGE_CACHE/java/21"
export GRADLE_HOME="$ENVFORGE_CACHE/gradle/8.5"
```

### Project `.envrc` (inherits workspace if nested)
```bash
export ENVFORGE_TYPE=project
export ENVFORGE_CACHE="$HOME/.envforge/tools"

# Load tools into PATH from global cache
path_add "$PWD/.bin"
path_add "$ENVFORGE_CACHE/java/21/bin"
path_add "$ENVFORGE_CACHE/gradle/8.5/bin"

# Export tool homes
export JAVA_HOME="$ENVFORGE_CACHE/java/21"
export GRADLE_HOME="$ENVFORGE_CACHE/gradle/8.5"
```

---

## 7. `.bin` Delegation Philosophy

### Design Principle
- `.bin` scripts are **adapters**, not implementations
- Each script knows project conventions and delegates to underlying tools
- Scripts are executable; always checked into version control

### Example: `build` Script
```bash
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
  exit 1
fi
```

### Example: `brun` Script
```bash
#!/bin/bash
# .bin/brun - Build and run in one command

"$PWD/.bin/build" && "$PWD/.bin/run"
```

### Responsibilities
- Detect project type (Gradle, CMake, Maven, custom)
- Delegate to appropriate tool with correct flags
- Handle errors and exit codes
- Optionally log or cache results

### Not Responsibilities
- Installing or managing tools (envforge handles this)
- Parsing complex configuration
- Implementing business logic
- Running multiple unrelated tasks (each script = one concern)

### Naming Convention
- `build`: Run build
- `run`: Execute application
- `test`: Run test suite
- `brun`: Build and run in sequence
- `clean`: Remove artifacts
- `format`: Code formatting
- Custom scripts allowed (e.g., `deploy`, `lint`)

---

## 8. Workspace vs Project Behavior Differences

| Aspect | Workspace | Project |
|--------|-----------|---------|
| **Scope** | Container for shared context | Independent unit |
| **Can contain** | Projects, shared scripts, tools | Only own scripts and tools |
| **Environment** | Parent; inherited by nested projects | Standalone or inherits workspace |
| **.envrc** | Top-level; sets defaults | Project-specific; may extend workspace |
| **Tool installation** | References global cache | References global cache |
| **.bin/` Scripts | Shared utilities available to all projects | Project-specific commands |
| **Nesting** | Can nest with confirmation | Projects can nest in workspaces |
| **Use case** | Course, monorepo, team infrastructure | Individual project or module |

### Nested Project Environment Merging
- Workspace `.envrc` loads first
- Project `.envrc` loads second
- Project PATH prepends local `.bin/` before workspace `.bin/`
- Projects can declare different tool versions than workspace; version declared in project shadows workspace version
- Environment variables: project overrides workspace
- **Important**: All tools install to global cache (`~/.envforge/tools/`); projects declare which versions they need

---

## 9. Error Handling and Guardrails

### Installation Errors
- **Missing tool**: Automatically attempt installation to global cache; fail with clear message if unsupported
- **Network failure**: Retry with backoff; use existing cached download if available
- **Compatibility**: Check OS/arch; skip if incompatible; suggest alternatives
- **Permission**: Ensure `~/.envforge/tools/` is writable; error if not

### Context Errors
- **Ambiguous context**: Warn if both workspace and project `.envrc` exist at same level
- **Orphaned tools**: Warn if tools reference missing `.envrc`
- **Nested workspaces**: Warn user and request confirmation before creating nested workspace

### Activation Errors
- **direnv not installed**: Clear instruction to install direnv
- **Missing tool at runtime**: Error with suggestion to run `envforge tool install`
- **Path collision**: Warn if local tools shadow system tools

### Configuration Errors
- **Invalid YAML**: Fail with parse error and line number
- **Unknown tool**: Warn and skip during `envforge update`
- **Conflicting versions**: Error if multiple versions specified for same tool

### Guardrails
- Never remove `.envrc` or `.bin/` without confirmation
- Always back up tool metadata before major operations
- Validate `.envforge/tools.yaml` before activation
- Log all tool installations and removals to `.envforge/audit.log`

---

## 10. Extensibility and Future Roadmap

### Extension Points
1. **Custom tool providers**: Fixed set initially with pluggable provider interface for extensibility
2. **Tool hooks**: Pre/post install scripts (e.g., custom compilation)
3. **Plugin scripts**: Additional `.bin/` scripts from community or third-party sources
4. **Environment layers**: Support multiple `.envrc.d/` files for modular configuration

### Tool Provider Strategy
- Phase 1: Fixed, hardcoded set of popular tools
- Phase 2+: Plugin interface allowing users to register custom tool providers via `.envforge/providers/` directory
- Provider interface defines: download URLs, version detection, installation logic, PATH configuration

### Future Ideas (Out of Scope v1)
- **Template system**: `envforge scaffold <template>` for common project patterns
- **Dependency resolution**: Auto-install transitive tool dependencies
- **Workspace sync**: Share workspace configurations across team members
- **Analytics**: Track tool usage, build times, test coverage
- **Integration**: GitHub Actions, GitLab CI templates for CI integration
- **GUI**: Web-based workspace/project management
- **Language bindings**: Python, Go, Rust APIs for tool interaction

### Roadmap Phases
- **Phase 1 (MVP)**: Core CLI, workspace/project creation, fixed tool set (Java/Gradle/CMake/Node/Next.js/Kubernetes), basic error handling, YAML configuration
- **Phase 2**: Extend tool catalog, improve direnv integration, `.bin/` templates, `envforge update` command
- **Phase 3**: Custom tool providers via plugin system, workspace sync, nested workspace support
- **Phase 4**: GUI, analytics, advanced integrations

---

## Answers to Design Questions

### 1. Project Naming
The project has been renamed from "scafforge" to **envforge** to better reflect its focus on environment management rather than just scaffolding.

### 2. Tool Catalog Strategy
Use a **fixed set of supported tools initially**, with a **pluggable provider model** introduced in later phases. This balances quick MVP delivery with long-term extensibility.

### 3. Configuration Format
Use **hand-editable YAML** (`.envforge/tools.yaml`) for tool declarations. Introduce `envforge update` command to sync environment when YAML is manually edited.

### 4. Nested Workspaces
**Allow nested workspaces** with clear warning and confirmation prompt. Users may have legitimate use cases (e.g., course workspace containing assignment workspaces).

### 5. Version Pinning
**Always pin tool versions** to ensure reproducibility. No automatic upgrades. Users must explicitly change version in `tools.yaml` and run `envforge update` to upgrade.
