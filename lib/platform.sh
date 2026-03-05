#!/usr/bin/env bash
# platform.sh — OS detection and tool aliases for novel-forge
# Sourced by other scripts. Do not execute directly.

set -euo pipefail

# ─── OS Detection ───────────────────────────────────────────────────────────

detect_os() {
  case "$(uname -s)" in
    Linux*)  echo "linux" ;;
    Darwin*) echo "macos" ;;
    *)       echo "unsupported" ;;
  esac
}

NF_OS="$(detect_os)"

if [[ "$NF_OS" == "unsupported" ]]; then
  echo "ERROR: novel-forge only supports Linux and macOS." >&2
  exit 1
fi

# ─── Shell Config File ─────────────────────────────────────────────────────

detect_shell_config() {
  if [[ "$NF_OS" == "macos" ]]; then
    echo "${HOME}/.zshrc"
  else
    # Linux: prefer .bashrc, fall back to .profile
    if [[ -f "${HOME}/.bashrc" ]]; then
      echo "${HOME}/.bashrc"
    else
      echo "${HOME}/.profile"
    fi
  fi
}

NF_SHELL_CONFIG="$(detect_shell_config)"

# ─── Tool Paths ─────────────────────────────────────────────────────────────

# OpenCode binary
NF_OPENCODE="${HOME}/.opencode/bin/opencode"

# uv (Python package manager)
NF_UV="${HOME}/.local/bin/uv"

# pandoc
if command -v pandoc &>/dev/null; then
  NF_PANDOC="$(command -v pandoc)"
else
  NF_PANDOC="pandoc"  # Will be installed by setup
fi

# Docker
if command -v docker &>/dev/null; then
  NF_DOCKER="$(command -v docker)"
else
  NF_DOCKER="docker"
fi

# ─── File Watcher Tool ──────────────────────────────────────────────────────

detect_file_watcher() {
  if [[ "$NF_OS" == "linux" ]]; then
    if command -v inotifywait &>/dev/null; then
      echo "inotifywait"
    else
      echo "missing"
    fi
  elif [[ "$NF_OS" == "macos" ]]; then
    if command -v fswatch &>/dev/null; then
      echo "fswatch"
    else
      echo "missing"
    fi
  fi
}

# ─── Desktop Notification Tool ──────────────────────────────────────────────

detect_notifier() {
  if [[ "$NF_OS" == "linux" ]]; then
    if command -v notify-send &>/dev/null; then
      echo "notify-send"
    else
      echo "missing"
    fi
  elif [[ "$NF_OS" == "macos" ]]; then
    # osascript is always available on macOS
    echo "osascript"
  fi
}

# ─── Package Manager ────────────────────────────────────────────────────────

detect_package_manager() {
  if [[ "$NF_OS" == "linux" ]]; then
    if command -v apt-get &>/dev/null; then
      echo "apt"
    elif command -v dnf &>/dev/null; then
      echo "dnf"
    elif command -v pacman &>/dev/null; then
      echo "pacman"
    else
      echo "unknown"
    fi
  elif [[ "$NF_OS" == "macos" ]]; then
    if command -v brew &>/dev/null; then
      echo "brew"
    else
      echo "missing"
    fi
  fi
}

NF_PKG_MANAGER="$(detect_package_manager)"

# ─── Package Install Wrappers ───────────────────────────────────────────────

pkg_install() {
  local pkg="$1"
  case "$NF_PKG_MANAGER" in
    apt)    sudo apt-get install -y "$pkg" ;;
    dnf)    sudo dnf install -y "$pkg" ;;
    pacman) sudo pacman -S --noconfirm "$pkg" ;;
    brew)   brew install "$pkg" ;;
    *)
      echo "ERROR: Cannot install '$pkg' — no supported package manager found." >&2
      echo "Please install '$pkg' manually and re-run setup." >&2
      return 1
      ;;
  esac
}

# ─── Service Manager ────────────────────────────────────────────────────────

detect_service_manager() {
  if [[ "$NF_OS" == "linux" ]]; then
    echo "systemd"
  elif [[ "$NF_OS" == "macos" ]]; then
    echo "launchd"
  fi
}

NF_SERVICE_MANAGER="$(detect_service_manager)"

# ─── Paths ──────────────────────────────────────────────────────────────────

# MCP server install locations
NF_MCP_DIR="${HOME}/.local/share/mcp-servers"
NF_GRAPHITI_DIR="${NF_MCP_DIR}/graphiti"
NF_WRITERS_WORKSHOP_DIR="${NF_MCP_DIR}/ai_writers_workshop"
NF_MEM0_BIN="${HOME}/.local/bin/mem0-mcp-server"

# Service file locations
if [[ "$NF_SERVICE_MANAGER" == "systemd" ]]; then
  NF_SERVICE_DIR="${HOME}/.config/systemd/user"
elif [[ "$NF_SERVICE_MANAGER" == "launchd" ]]; then
  NF_SERVICE_DIR="${HOME}/Library/LaunchAgents"
fi

# ─── Utility Functions ──────────────────────────────────────────────────────

log_info() {
  echo "[novel-forge] $*"
}

log_warn() {
  echo "[novel-forge] WARNING: $*" >&2
}

log_error() {
  echo "[novel-forge] ERROR: $*" >&2
}

log_ok() {
  echo "[novel-forge] ✓ $*"
}

prompt_yes_no() {
  local question="$1"
  local default="${2:-y}"
  local yn

  if [[ "$default" == "y" ]]; then
    read -r -p "[novel-forge] $question [Y/n] " yn
    yn="${yn:-y}"
  else
    read -r -p "[novel-forge] $question [y/N] " yn
    yn="${yn:-n}"
  fi

  case "$yn" in
    [Yy]*) return 0 ;;
    *)     return 1 ;;
  esac
}

prompt_value() {
  local question="$1"
  local var_name="$2"
  local default="${3:-}"
  local value

  if [[ -n "$default" ]]; then
    read -r -p "[novel-forge] $question [$default]: " value
    value="${value:-$default}"
  else
    read -r -p "[novel-forge] $question: " value
  fi

  eval "$var_name='$value'"
}

prompt_secret() {
  local question="$1"
  local var_name="$2"
  local value

  read -r -s -p "[novel-forge] $question: " value
  echo  # newline after hidden input
  eval "$var_name='$value'"
}
