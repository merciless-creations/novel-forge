#!/usr/bin/env bash
# watcher.sh — DropZone file watcher daemon for novel-forge
#
# Watches ~/DropZone/ for .zip files. When one appears:
#   1. Validates zip safety (no path traversal)
#   2. Creates .inbox/<zip-name-without-extension>/ (nukes if exists)
#   3. Extracts zip contents there
#   4. Removes the zip from DropZone
#   5. Tells the running OpenCode server to process the inbox
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

# ─── Zip Safety Check ──────────────────────────────────────────────────────

# Validate that a zip file doesn't contain path traversal attacks (Zip Slip)
# or absolute paths that could write outside the target directory.
validate_zip_safety() {
  local zip_path="$1"

  # List all entries and check for dangerous paths
  local bad_entries
  bad_entries="$(unzip -l "$zip_path" 2>/dev/null | awk 'NR>3 && !/^-/ && NF>=4 {print $NF}' | grep -E '(^/|\.\./)')" || true

  if [[ -n "$bad_entries" ]]; then
    log_error "SECURITY: Zip file contains dangerous paths (path traversal):"
    echo "$bad_entries" >&2
    return 1
  fi

  return 0
}

# ─── Wait for File Complete ─────────────────────────────────────────────────

# Wait until a file stops growing (copy is complete).
# Checks file size twice with a delay; if size is stable, file is ready.
wait_for_file_complete() {
  local filepath="$1"
  local max_wait=60  # seconds
  local elapsed=0

  while [[ $elapsed -lt $max_wait ]]; do
    [[ -f "$filepath" ]] || return 1

    local size1 size2
    size1="$(stat -c%s "$filepath" 2>/dev/null || stat -f%z "$filepath" 2>/dev/null)" || return 1
    sleep 2
    size2="$(stat -c%s "$filepath" 2>/dev/null || stat -f%z "$filepath" 2>/dev/null)" || return 1

    if [[ "$size1" == "$size2" && "$size1" -gt 0 ]]; then
      return 0  # File size stable and non-zero
    fi

    elapsed=$((elapsed + 2))
  done

  log_warn "Timed out waiting for file to finish copying: $(basename "$filepath")"
  return 1
}

# ─── Zip Processing ────────────────────────────────────────────────────────

process_zip() {
  local zip_path="$1"
  local zip_filename
  zip_filename="$(basename "$zip_path")"
  local inbox_name="${zip_filename%.zip}"

  log_info "Detected: ${zip_filename}"

  # Wait for file to finish copying
  if ! wait_for_file_complete "$zip_path"; then
    log_error "File not ready or disappeared: ${zip_filename}"
    return 1
  fi

  # Validate zip safety (Zip Slip protection)
  if ! validate_zip_safety "$zip_path"; then
    log_error "Rejecting unsafe zip file: ${zip_filename}"
    nf_notify_error "Rejected ${zip_filename} — contains unsafe file paths."
    return 1
  fi

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

  # Retry up to 3 times with backoff if OpenCode isn't reachable
  local attempt
  for attempt in 1 2 3; do
    if "${NF_OPENCODE}" run --attach "${NF_OPENCODE_URL}" "${message}" 2>/dev/null; then
      log_ok "OpenCode notified."
      return 0
    fi
    if [[ $attempt -lt 3 ]]; then
      log_warn "OpenCode not reachable (attempt ${attempt}/3), retrying in ${attempt}0s..."
      sleep "$((attempt * 10))"
    fi
  done

  log_warn "Could not reach OpenCode server at ${NF_OPENCODE_URL} after 3 attempts"
  log_warn "Files are ready in .inbox/${inbox_name}/ — process manually when OpenCode is running."
  nf_notify_error "OpenCode server not reachable. Files saved to .inbox/${inbox_name}/"
  return 1
}

# ─── Watch Loop ─────────────────────────────────────────────────────────────

watch_dropzone_linux() {
  log_info "Watching ${NF_DROPZONE}/ for .zip files (inotifywait)..."

  # Use close_write to ensure the file is fully written before processing.
  # Also watch moved_to for files moved into the directory.
  inotifywait -m -e close_write -e moved_to --format '%f' "$NF_DROPZONE" | while read -r filename; do
    if [[ "$filename" == *.zip ]]; then
      process_zip "${NF_DROPZONE}/${filename}"
    fi
  done
}

watch_dropzone_macos() {
  log_info "Watching ${NF_DROPZONE}/ for .zip files (fswatch)..."

  # fswatch flags: -0 for null-delimited output
  # Use --event flags if supported, fall back to basic monitoring
  # The wait_for_file_complete function handles the "still copying" race condition
  if fswatch --help 2>&1 | grep -q -- '--event'; then
    fswatch -0 --event Created --event Updated --event Renamed "$NF_DROPZONE" | while read -r -d '' filepath; do
      if [[ "$filepath" == *.zip ]]; then
        process_zip "$filepath"
      fi
    done
  else
    # Older fswatch without --event support
    fswatch -0 "$NF_DROPZONE" | while read -r -d '' filepath; do
      if [[ "$filepath" == *.zip ]]; then
        process_zip "$filepath"
      fi
    done
  fi
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
