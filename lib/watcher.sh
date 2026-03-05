#!/usr/bin/env bash
# watcher.sh — DropZone file watcher daemon for novel-forge
#
# Watches ~/DropZone/ for .zip files. When one appears:
#   1. Creates .inbox/<zip-name-without-extension>/ (nukes if exists)
#   2. Extracts zip contents there
#   3. Removes the zip from DropZone
#   4. Tells the running OpenCode server to process the inbox
#
# This script is DUMB. It does not convert files, check series, or
# make decisions. It only moves files and notifies OpenCode.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/platform.sh"
source "${SCRIPT_DIR}/notify.sh"

# ─── Configuration ──────────────────────────────────────────────────────────

# These can be overridden via environment variables
NF_DROPZONE="${NF_DROPZONE:-${HOME}/DropZone}"
NF_NOVELS_DIR="${NF_NOVELS_DIR:-${HOME}/novels}"
NF_INBOX_DIR="${NF_NOVELS_DIR}/.inbox"
NF_OPENCODE_PORT="${NF_OPENCODE_PORT:-4096}"
NF_OPENCODE_URL="http://localhost:${NF_OPENCODE_PORT}"

# ─── Setup ──────────────────────────────────────────────────────────────────

ensure_dirs() {
  mkdir -p "$NF_DROPZONE"
  mkdir -p "$NF_INBOX_DIR"
}

# ─── Zip Processing ────────────────────────────────────────────────────────

process_zip() {
  local zip_path="$1"
  local zip_filename
  zip_filename="$(basename "$zip_path")"
  local inbox_name="${zip_filename%.zip}"

  log_info "Detected: ${zip_filename}"

  # Create inbox folder (nuke if exists)
  local inbox_path="${NF_INBOX_DIR}/${inbox_name}"
  if [[ -d "$inbox_path" ]]; then
    log_info "Clearing existing inbox: ${inbox_name}"
    rm -rf "$inbox_path"
  fi
  mkdir -p "$inbox_path"

  # Extract zip contents
  log_info "Extracting to .inbox/${inbox_name}/"
  if ! unzip -q -o "$zip_path" -d "$inbox_path" 2>/dev/null; then
    log_error "Failed to extract ${zip_filename}"
    nf_notify_error "Failed to extract ${zip_filename}. Check if the zip file is valid."
    rm -rf "$inbox_path"
    return 1
  fi

  # Remove the zip from DropZone
  rm -f "$zip_path"
  log_ok "Extracted ${zip_filename} → .inbox/${inbox_name}/"

  # Tell OpenCode to process
  notify_opencode "$inbox_name"
}

# ─── OpenCode Communication ────────────────────────────────────────────────

notify_opencode() {
  local inbox_name="$1"
  local message="New manuscript files in .inbox/${inbox_name}/. Process them."

  log_info "Notifying OpenCode..."

  if ! "${NF_OPENCODE}" run --attach "${NF_OPENCODE_URL}" "${message}" 2>/dev/null; then
    log_warn "Could not reach OpenCode server at ${NF_OPENCODE_URL}"
    log_warn "Files are ready in .inbox/${inbox_name}/ — process manually when OpenCode is running."
    nf_notify_error "OpenCode server not reachable. Files saved to .inbox/${inbox_name}/"
    return 1
  fi

  log_ok "OpenCode notified."
}

# ─── Watch Loop ─────────────────────────────────────────────────────────────

watch_dropzone_linux() {
  log_info "Watching ${NF_DROPZONE}/ for .zip files (inotifywait)..."

  # inotifywait watches for new files moved into or created in the directory
  inotifywait -m -e close_write -e moved_to --format '%f' "$NF_DROPZONE" | while read -r filename; do
    if [[ "$filename" == *.zip ]]; then
      # Small delay to ensure the file is fully written
      sleep 1
      process_zip "${NF_DROPZONE}/${filename}"
    fi
  done
}

watch_dropzone_macos() {
  log_info "Watching ${NF_DROPZONE}/ for .zip files (fswatch)..."

  fswatch -0 --event Created --event MovedTo "$NF_DROPZONE" | while read -r -d '' filepath; do
    if [[ "$filepath" == *.zip ]]; then
      # Small delay to ensure the file is fully written
      sleep 1
      process_zip "$filepath"
    fi
  done
}

# ─── Main ───────────────────────────────────────────────────────────────────

main() {
  ensure_dirs

  log_info "novel-forge watcher starting"
  log_info "  DropZone:  ${NF_DROPZONE}"
  log_info "  Inbox:     ${NF_INBOX_DIR}"
  log_info "  OpenCode:  ${NF_OPENCODE_URL}"
  echo ""

  # Check that the file watcher tool is available
  local watcher_tool
  watcher_tool="$(detect_file_watcher)"
  if [[ "$watcher_tool" == "missing" ]]; then
    log_error "File watcher not found."
    if [[ "$NF_OS" == "linux" ]]; then
      log_error "Install inotify-tools: sudo apt-get install inotify-tools"
    elif [[ "$NF_OS" == "macos" ]]; then
      log_error "Install fswatch: brew install fswatch"
    fi
    exit 1
  fi

  # Also process any .zip files already sitting in DropZone
  for existing_zip in "${NF_DROPZONE}"/*.zip; do
    [[ -f "$existing_zip" ]] || continue
    process_zip "$existing_zip"
  done

  # Start watching
  case "$NF_OS" in
    linux) watch_dropzone_linux ;;
    macos) watch_dropzone_macos ;;
  esac
}

main "$@"
