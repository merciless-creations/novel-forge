#!/usr/bin/env bash
# setup.sh — Novel Forge bootstrap installer
#
# This script sets up everything a non-technical novel author needs:
#   1. System dependencies (Docker, pandoc, unzip, file watcher, notifications)
#   2. FalkorDB (graph database for knowledge graph)
#   3. uv (Python package manager)
#   4. MCP servers (Graphiti, Mem0, AI Writers Workshop)
#   5. API keys (OpenAI, Mem0)
#   6. Git repository for the author's novels
#   7. OpenCode configuration (opencode.json, AGENTS.md, skills, templates)
#   8. Background services (watcher daemon + OpenCode web server)
#
# Usage: bash setup.sh [--novels-dir ~/my-novels] [--port 4096]
#
# Prerequisites: OpenCode must already be installed.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/platform.sh"
source "${SCRIPT_DIR}/lib/notify.sh"

# ─── Configuration ──────────────────────────────────────────────────────────

NF_NOVELS_DIR="${NF_NOVELS_DIR:-${HOME}/novels}"
NF_OPENCODE_PORT="${NF_OPENCODE_PORT:-4096}"
NF_DROPZONE="${NF_DROPZONE:-${HOME}/DropZone}"

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --novels-dir)
      NF_NOVELS_DIR="$2"
      shift 2
      ;;
    --port)
      NF_OPENCODE_PORT="$2"
      shift 2
      ;;
    --dropzone)
      NF_DROPZONE="$2"
      shift 2
      ;;
    --help|-h)
      echo "Usage: bash setup.sh [OPTIONS]"
      echo ""
      echo "Options:"
      echo "  --novels-dir DIR   Where to create/use your novels repo (default: ~/novels)"
      echo "  --port PORT        OpenCode web server port (default: 4096)"
      echo "  --dropzone DIR     Where to drop zip files (default: ~/DropZone)"
      echo "  --help, -h         Show this help message"
      exit 0
      ;;
    *)
      log_error "Unknown option: $1"
      exit 1
      ;;
  esac
done

# ─── Pre-flight Checks ─────────────────────────────────────────────────────

preflight() {
  echo ""
  echo "╔══════════════════════════════════════════════╗"
  echo "║         Novel Forge — Setup Wizard           ║"
  echo "╚══════════════════════════════════════════════╝"
  echo ""
  log_info "Operating system: ${NF_OS}"
  log_info "Package manager:  ${NF_PKG_MANAGER}"
  log_info "Novels directory: ${NF_NOVELS_DIR}"
  log_info "DropZone:         ${NF_DROPZONE}"
  log_info "OpenCode port:    ${NF_OPENCODE_PORT}"
  echo ""

  # Check OpenCode is installed
  if [[ ! -f "${NF_OPENCODE}" ]]; then
    log_error "OpenCode not found at ${NF_OPENCODE}"
    log_error "Please install OpenCode first: https://opencode.ai"
    exit 1
  fi
  log_ok "OpenCode found"

  # Check package manager
  if [[ "$NF_PKG_MANAGER" == "unknown" || "$NF_PKG_MANAGER" == "missing" ]]; then
    log_error "No supported package manager found."
    if [[ "$NF_OS" == "macos" ]]; then
      log_error "Install Homebrew first: https://brew.sh"
    else
      log_error "Install apt, dnf, or pacman."
    fi
    exit 1
  fi
  log_ok "Package manager: ${NF_PKG_MANAGER}"

  echo ""
  if ! prompt_yes_no "Ready to install Novel Forge?"; then
    log_info "Setup cancelled."
    exit 0
  fi
  echo ""
}

# ─── Step 1: System Dependencies ───────────────────────────────────────────

install_system_deps() {
  log_info "Step 1/8: Installing system dependencies..."

  # pandoc
  if ! command -v pandoc &>/dev/null; then
    log_info "Installing pandoc..."
    pkg_install pandoc
  fi
  log_ok "pandoc installed"

  # unzip
  if ! command -v unzip &>/dev/null; then
    log_info "Installing unzip..."
    pkg_install unzip
  fi
  log_ok "unzip installed"

  # git
  if ! command -v git &>/dev/null; then
    log_info "Installing git..."
    pkg_install git
  fi
  log_ok "git installed"

  # File watcher
  local watcher
  watcher="$(detect_file_watcher)"
  if [[ "$watcher" == "missing" ]]; then
    log_info "Installing file watcher..."
    if [[ "$NF_OS" == "linux" ]]; then
      pkg_install inotify-tools
    elif [[ "$NF_OS" == "macos" ]]; then
      pkg_install fswatch
    fi
  fi
  log_ok "File watcher installed"

  # Desktop notifications
  local notifier
  notifier="$(detect_notifier)"
  if [[ "$notifier" == "missing" ]]; then
    log_info "Installing desktop notification support..."
    if [[ "$NF_OS" == "linux" ]]; then
      pkg_install libnotify-bin 2>/dev/null || pkg_install libnotify 2>/dev/null || true
    fi
    # macOS has osascript built in
  fi
  log_ok "Desktop notifications available"

  echo ""
}

# ─── Step 2: Docker & FalkorDB ─────────────────────────────────────────────

install_docker_falkordb() {
  log_info "Step 2/8: Setting up Docker & FalkorDB..."

  # Docker
  if ! command -v docker &>/dev/null; then
    log_info "Installing Docker..."
    if [[ "$NF_OS" == "linux" ]]; then
      # Install Docker using the convenience script
      curl -fsSL https://get.docker.com | sudo sh
      sudo usermod -aG docker "$USER"
      log_warn "You were added to the docker group. You may need to log out and back in."
    elif [[ "$NF_OS" == "macos" ]]; then
      log_error "Please install Docker Desktop for Mac: https://www.docker.com/products/docker-desktop/"
      log_error "Then re-run this setup."
      exit 1
    fi
  fi
  log_ok "Docker installed"

  # Start Docker if not running
  if ! docker info &>/dev/null 2>&1; then
    if [[ "$NF_OS" == "linux" ]]; then
      sudo systemctl start docker 2>/dev/null || true
      sudo systemctl enable docker 2>/dev/null || true
    fi
    # On macOS, Docker Desktop needs to be started manually
    if ! docker info &>/dev/null 2>&1; then
      log_warn "Docker doesn't seem to be running. Please start Docker and re-run setup."
    fi
  fi

  # FalkorDB
  if ! docker ps -a --format '{{.Names}}' | grep -q '^falkordb$'; then
    log_info "Creating FalkorDB container..."
    docker run -d \
      --name falkordb \
      --restart unless-stopped \
      -p 6379:6379 \
      falkordb/falkordb:latest
    log_ok "FalkorDB container created and running"
  elif ! docker ps --format '{{.Names}}' | grep -q '^falkordb$'; then
    log_info "Starting existing FalkorDB container..."
    docker start falkordb
    # Set restart policy in case it wasn't set
    docker update --restart unless-stopped falkordb 2>/dev/null || true
    log_ok "FalkorDB started"
  else
    log_ok "FalkorDB already running"
  fi

  echo ""
}

# ─── Step 3: uv (Python package manager) ───────────────────────────────────

install_uv() {
  log_info "Step 3/8: Installing uv (Python package manager)..."

  if [[ ! -f "${NF_UV}" ]] && ! command -v uv &>/dev/null; then
    curl -LsSf https://astral.sh/uv/install.sh | sh
  fi
  log_ok "uv installed"

  echo ""
}

# ─── Step 4: MCP Servers ───────────────────────────────────────────────────

install_mcp_servers() {
  log_info "Step 4/8: Installing MCP servers..."

  mkdir -p "${NF_MCP_DIR}"

  # --- Graphiti Memory MCP ---
  if [[ ! -d "${NF_GRAPHITI_DIR}" ]]; then
    log_info "Installing Graphiti Memory MCP server..."
    git clone https://github.com/getzep/graphiti.git "${NF_GRAPHITI_DIR}"

    # Create Python venv and install deps
    local graphiti_mcp="${NF_GRAPHITI_DIR}/mcp_server"
    "${NF_UV}" venv "${graphiti_mcp}/.venv" 2>/dev/null || true
    "${NF_UV}" pip install --directory "${graphiti_mcp}" -r "${graphiti_mcp}/requirements.txt" 2>/dev/null || \
    "${NF_UV}" sync --directory "${graphiti_mcp}" 2>/dev/null || true
    log_ok "Graphiti Memory MCP installed"
  else
    log_ok "Graphiti Memory MCP already installed"
  fi

  # --- Mem0 MCP ---
  if [[ ! -f "${NF_MEM0_BIN}" ]] && ! command -v mem0-mcp-server &>/dev/null; then
    log_info "Installing Mem0 MCP server..."
    "${NF_UV}" tool install mem0-mcp 2>/dev/null || \
    pip install --user mem0-mcp 2>/dev/null || true
    log_ok "Mem0 MCP installed"
  else
    log_ok "Mem0 MCP already installed"
  fi

  # --- AI Writers Workshop MCP ---
  if [[ ! -d "${NF_WRITERS_WORKSHOP_DIR}" ]]; then
    log_info "Installing AI Writers Workshop MCP server..."
    git clone https://github.com/merciless-creations/ai-writers-workshop.git "${NF_WRITERS_WORKSHOP_DIR}"
    log_ok "AI Writers Workshop MCP installed"
  else
    log_ok "AI Writers Workshop MCP already installed"
  fi

  echo ""
}

# ─── Step 5: API Keys ──────────────────────────────────────────────────────

configure_api_keys() {
  log_info "Step 5/8: Configuring API keys..."
  echo ""
  log_info "Novel Forge needs API keys for its AI features."
  log_info "These will be stored in your shell config: ${NF_SHELL_CONFIG}"
  echo ""

  local need_reload=false

  # OpenAI API Key
  if [[ -z "${OPENAI_API_KEY:-}" ]]; then
    log_info "An OpenAI API key is required for the knowledge graph."
    log_info "Get one at: https://platform.openai.com/api-keys"
    echo ""
    local openai_key
    prompt_secret "Enter your OpenAI API key (sk-...)" openai_key

    if [[ -n "$openai_key" ]]; then
      echo "" >> "${NF_SHELL_CONFIG}"
      echo "# Novel Forge API keys" >> "${NF_SHELL_CONFIG}"
      echo "export OPENAI_API_KEY=\"${openai_key}\"" >> "${NF_SHELL_CONFIG}"
      export OPENAI_API_KEY="$openai_key"
      need_reload=true
      log_ok "OpenAI API key saved"
    else
      log_warn "Skipped OpenAI API key — knowledge graph features will not work"
    fi
  else
    log_ok "OpenAI API key already set"
  fi

  # Mem0 API Key
  if [[ -z "${MEM0_API_KEY:-}" ]]; then
    echo ""
    log_info "A Mem0 API key is needed for memory features."
    log_info "Get one at: https://app.mem0.ai/dashboard/api-keys"
    echo ""
    local mem0_key
    prompt_secret "Enter your Mem0 API key (m0-...)" mem0_key

    if [[ -n "$mem0_key" ]]; then
      # Only add the header if we didn't just add it
      if [[ "$need_reload" != true ]]; then
        echo "" >> "${NF_SHELL_CONFIG}"
        echo "# Novel Forge API keys" >> "${NF_SHELL_CONFIG}"
      fi
      echo "export MEM0_API_KEY=\"${mem0_key}\"" >> "${NF_SHELL_CONFIG}"
      export MEM0_API_KEY="$mem0_key"
      need_reload=true
      log_ok "Mem0 API key saved"
    else
      log_warn "Skipped Mem0 API key — memory features will not work"
    fi
  else
    log_ok "Mem0 API key already set"
  fi

  if [[ "$need_reload" == true ]]; then
    log_info "API keys saved to ${NF_SHELL_CONFIG}"
    log_info "They'll be active in new terminal sessions automatically."
  fi

  echo ""
}

# ─── Step 6: Novels Repository ─────────────────────────────────────────────

setup_novels_repo() {
  log_info "Step 6/8: Setting up your novels repository..."

  # Create the novels directory and initialize git
  if [[ ! -d "${NF_NOVELS_DIR}" ]]; then
    mkdir -p "${NF_NOVELS_DIR}"
    git -C "${NF_NOVELS_DIR}" init
    log_ok "Created novels repository at ${NF_NOVELS_DIR}"
  elif [[ ! -d "${NF_NOVELS_DIR}/.git" ]]; then
    git -C "${NF_NOVELS_DIR}" init
    log_ok "Initialized git in existing ${NF_NOVELS_DIR}"
  else
    log_ok "Novels repository exists at ${NF_NOVELS_DIR}"
  fi

  # Create DropZone
  mkdir -p "${NF_DROPZONE}"
  log_ok "DropZone created at ${NF_DROPZONE}"

  # Create .inbox
  mkdir -p "${NF_NOVELS_DIR}/.inbox"

  # Copy framework files into the novels repo
  log_info "Installing Novel Forge framework files..."

  # AGENTS.md
  cp "${SCRIPT_DIR}/AGENTS.md" "${NF_NOVELS_DIR}/AGENTS.md"
  log_ok "  AGENTS.md"

  # AI Prompt.md
  cp "${SCRIPT_DIR}/AI Prompt.md" "${NF_NOVELS_DIR}/AI Prompt.md"
  log_ok "  AI Prompt.md"

  # opencode.json
  install_opencode_json
  log_ok "  opencode.json"

  # .gitignore
  if [[ ! -f "${NF_NOVELS_DIR}/.gitignore" ]]; then
    cp "${SCRIPT_DIR}/.gitignore" "${NF_NOVELS_DIR}/.gitignore"
    log_ok "  .gitignore"
  fi

  # Skills
  local skills_dir="${NF_NOVELS_DIR}/.opencode/skills"
  mkdir -p "${skills_dir}"

  for skill in continuity-checker prose-auditor world-bible manuscript-processor; do
    local src="${SCRIPT_DIR}/.opencode/skills/${skill}/SKILL.md"
    local dst="${skills_dir}/${skill}/SKILL.md"
    if [[ -f "$src" ]]; then
      mkdir -p "${skills_dir}/${skill}"
      cp "$src" "$dst"
      log_ok "  skill: ${skill}"
    fi
  done

  # Templates (copy to repo for reference)
  mkdir -p "${NF_NOVELS_DIR}/.novel-forge/templates"
  cp "${SCRIPT_DIR}/templates/"* "${NF_NOVELS_DIR}/.novel-forge/templates/" 2>/dev/null || true
  log_ok "  templates"

  # Initial commit
  if ! git -C "${NF_NOVELS_DIR}" log --oneline -1 &>/dev/null; then
    git -C "${NF_NOVELS_DIR}" add -A
    git -C "${NF_NOVELS_DIR}" commit -m "Initialize Novel Forge framework

- AGENTS.md: Editorial continuity system rules
- AI Prompt.md: Prose style rules
- opencode.json: MCP server configuration
- Skills: continuity-checker, prose-auditor, world-bible, manuscript-processor
- Templates: SERIES.yaml, characters.md, locks.yaml, timeline.md"
    log_ok "Initial commit created"
  fi

  echo ""
}

# ─── Helper: Generate opencode.json ────────────────────────────────────────

install_opencode_json() {
  # Generate opencode.json with correct paths for this user
  cat > "${NF_NOVELS_DIR}/opencode.json" << JSONEOF
{
  "\$schema": "https://opencode.ai/config.json",
  "mcp": {
    "graphiti-memory": {
      "type": "local",
      "command": [
        "${NF_UV}",
        "run",
        "--isolated",
        "--directory",
        "${NF_GRAPHITI_DIR}/mcp_server",
        "--project",
        ".",
        "main.py",
        "--transport",
        "stdio",
        "--group-id",
        "novels"
      ],
      "environment": {
        "OPENAI_API_KEY": "{env:OPENAI_API_KEY}",
        "FALKORDB_URI": "redis://localhost:6379"
      },
      "enabled": true
    },
    "mem0": {
      "type": "local",
      "command": [
        "${NF_MEM0_BIN}"
      ],
      "environment": {
        "MEM0_API_KEY": "{env:MEM0_API_KEY}"
      },
      "enabled": true
    },
    "ai-writers-workshop": {
      "type": "local",
      "command": [
        "python3",
        "${NF_WRITERS_WORKSHOP_DIR}/mcp_server/server.py"
      ],
      "environment": {
        "PYTHONPATH": "${NF_WRITERS_WORKSHOP_DIR}"
      },
      "enabled": true
    }
  }
}
JSONEOF
}

# ─── Step 7: Install Watcher Script ────────────────────────────────────────

install_watcher() {
  log_info "Step 7/8: Installing file watcher..."

  local watcher_bin="${HOME}/.local/bin/novel-forge-watcher"
  mkdir -p "${HOME}/.local/bin"

  # Create a wrapper script that sets the environment and runs the watcher
  cat > "$watcher_bin" << WATCHEREOF
#!/usr/bin/env bash
# Novel Forge watcher — auto-generated by setup.sh
# Do not edit; re-run setup.sh to regenerate.

export NF_DROPZONE="${NF_DROPZONE}"
export NF_NOVELS_DIR="${NF_NOVELS_DIR}"
export NF_OPENCODE_PORT="${NF_OPENCODE_PORT}"
export PATH="${HOME}/.opencode/bin:${HOME}/.local/bin:\${PATH}"

# Source API keys
if [[ -f "${NF_SHELL_CONFIG}" ]]; then
  source "${NF_SHELL_CONFIG}" 2>/dev/null || true
fi

exec bash "${NF_NOVELS_DIR}/.novel-forge/watcher.sh"
WATCHEREOF
  chmod +x "$watcher_bin"

  # Copy the watcher script into the novels directory
  mkdir -p "${NF_NOVELS_DIR}/.novel-forge"
  cp "${SCRIPT_DIR}/lib/watcher.sh" "${NF_NOVELS_DIR}/.novel-forge/watcher.sh"
  cp "${SCRIPT_DIR}/lib/platform.sh" "${NF_NOVELS_DIR}/.novel-forge/platform.sh"
  cp "${SCRIPT_DIR}/lib/notify.sh" "${NF_NOVELS_DIR}/.novel-forge/notify.sh"

  # Fix the source paths in the copied watcher
  sed -i.bak "s|source \"\${SCRIPT_DIR}/platform.sh\"|source \"${NF_NOVELS_DIR}/.novel-forge/platform.sh\"|" \
    "${NF_NOVELS_DIR}/.novel-forge/watcher.sh"
  sed -i.bak "s|source \"\${SCRIPT_DIR}/notify.sh\"|source \"${NF_NOVELS_DIR}/.novel-forge/notify.sh\"|" \
    "${NF_NOVELS_DIR}/.novel-forge/watcher.sh"
  rm -f "${NF_NOVELS_DIR}/.novel-forge/"*.bak

  log_ok "Watcher installed at ${watcher_bin}"
  echo ""
}

# ─── Step 8: Background Services ───────────────────────────────────────────

install_services() {
  log_info "Step 8/8: Setting up background services..."

  if [[ "$NF_SERVICE_MANAGER" == "systemd" ]]; then
    install_systemd_services
  elif [[ "$NF_SERVICE_MANAGER" == "launchd" ]]; then
    install_launchd_services
  fi

  echo ""
}

install_systemd_services() {
  mkdir -p "${NF_SERVICE_DIR}"

  # Watcher service
  local watcher_unit="${NF_SERVICE_DIR}/novel-forge-watcher.service"
  sed \
    -e "s|%h|${HOME}|g" \
    "${SCRIPT_DIR}/services/novel-forge-watcher.service" > "$watcher_unit"
  # Patch environment variables into the unit
  sed -i "s|NF_NOVELS_DIR=.*|NF_NOVELS_DIR=${NF_NOVELS_DIR}|" "$watcher_unit"
  sed -i "s|NF_DROPZONE=.*|NF_DROPZONE=${NF_DROPZONE}|" "$watcher_unit"
  sed -i "s|NF_OPENCODE_PORT=.*|NF_OPENCODE_PORT=${NF_OPENCODE_PORT}|" "$watcher_unit"
  log_ok "Watcher systemd unit installed"

  # OpenCode service
  local opencode_unit="${NF_SERVICE_DIR}/novel-forge-opencode.service"
  sed \
    -e "s|%h|${HOME}|g" \
    -e "s|--port 4096|--port ${NF_OPENCODE_PORT}|" \
    "${SCRIPT_DIR}/services/novel-forge-opencode.service" > "$opencode_unit"
  sed -i "s|WorkingDirectory=.*|WorkingDirectory=${NF_NOVELS_DIR}|" "$opencode_unit"
  log_ok "OpenCode systemd unit installed"

  # Reload and enable
  systemctl --user daemon-reload
  systemctl --user enable novel-forge-watcher.service
  systemctl --user enable novel-forge-opencode.service
  log_ok "Services enabled (will start on next login)"

  if prompt_yes_no "Start services now?"; then
    systemctl --user start novel-forge-opencode.service
    sleep 2
    systemctl --user start novel-forge-watcher.service
    log_ok "Services started"
    log_info "OpenCode web UI: http://localhost:${NF_OPENCODE_PORT}"
  fi
}

install_launchd_services() {
  mkdir -p "${NF_SERVICE_DIR}"

  # Watcher plist
  local watcher_plist="${NF_SERVICE_DIR}/com.novel-forge.watcher.plist"
  cp "${SCRIPT_DIR}/services/com.novel-forge.watcher.plist" "$watcher_plist"
  # Replace ~ with actual home dir
  sed -i '' "s|~/|${HOME}/|g" "$watcher_plist" 2>/dev/null || \
  sed -i "s|~/|${HOME}/|g" "$watcher_plist"
  log_ok "Watcher launchd plist installed"

  # OpenCode plist
  local opencode_plist="${NF_SERVICE_DIR}/com.novel-forge.opencode.plist"
  cp "${SCRIPT_DIR}/services/com.novel-forge.opencode.plist" "$opencode_plist"
  sed -i '' "s|~/|${HOME}/|g" "$opencode_plist" 2>/dev/null || \
  sed -i "s|~/|${HOME}/|g" "$opencode_plist"
  sed -i '' "s|--port 4096|--port ${NF_OPENCODE_PORT}|g" "$opencode_plist" 2>/dev/null || \
  sed -i "s|--port 4096|--port ${NF_OPENCODE_PORT}|g" "$opencode_plist"
  log_ok "OpenCode launchd plist installed"

  if prompt_yes_no "Start services now?"; then
    launchctl load "$opencode_plist" 2>/dev/null || true
    sleep 2
    launchctl load "$watcher_plist" 2>/dev/null || true
    log_ok "Services loaded"
    log_info "OpenCode web UI: http://localhost:${NF_OPENCODE_PORT}"
  fi
}

# ─── Completion ─────────────────────────────────────────────────────────────

finish() {
  echo ""
  echo "╔══════════════════════════════════════════════╗"
  echo "║       Novel Forge — Setup Complete!          ║"
  echo "╚══════════════════════════════════════════════╝"
  echo ""
  log_ok "Your novels repository: ${NF_NOVELS_DIR}"
  log_ok "Drop zone for manuscripts: ${NF_DROPZONE}"
  log_ok "OpenCode web UI: http://localhost:${NF_OPENCODE_PORT}"
  echo ""
  log_info "HOW TO USE:"
  echo ""
  echo "  1. Export your novel chapters from Word as .docx files"
  echo "  2. Put them in a .zip file"
  echo "  3. Drop the .zip in ${NF_DROPZONE}/"
  echo "  4. Open http://localhost:${NF_OPENCODE_PORT} in your browser"
  echo "  5. The AI will process your chapters and check for continuity issues"
  echo ""
  log_info "The file watcher and OpenCode server run automatically in the background."
  log_info "They start when you log in and restart if they crash."
  echo ""

  # Clean up: remove the cloned novel-forge repo (we've copied everything we need)
  if prompt_yes_no "Setup is complete. Remove the novel-forge installer files?" "n"; then
    log_info "Keeping installer files at ${SCRIPT_DIR}"
    log_info "You can safely delete this directory: rm -rf ${SCRIPT_DIR}"
  fi
}

# ─── Main ───────────────────────────────────────────────────────────────────

main() {
  preflight
  install_system_deps
  install_docker_falkordb
  install_uv
  install_mcp_servers
  configure_api_keys
  setup_novels_repo
  install_watcher
  install_services
  finish
}

main "$@"
