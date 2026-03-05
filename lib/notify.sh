#!/usr/bin/env bash
# notify.sh — Cross-platform desktop notifications for novel-forge
# Sourced by other scripts. Do not execute directly.

# Requires: lib/platform.sh sourced first

# ─── Desktop Notification ───────────────────────────────────────────────────

# Send a desktop notification to the user.
# Usage: nf_notify "Title" "Message body"
nf_notify() {
  local title="${1:-Novel Forge}"
  local body="${2:-}"
  local urgency="${3:-normal}"  # low, normal, critical

  case "$NF_OS" in
    linux)
      if command -v notify-send &>/dev/null; then
        notify-send --urgency="$urgency" "$title" "$body" 2>/dev/null || true
      else
        # Fallback: just log it
        log_warn "Desktop notifications unavailable (install libnotify-bin)"
        log_info "NOTIFICATION: $title — $body"
      fi
      ;;
    macos)
      osascript -e "display notification \"$body\" with title \"$title\"" 2>/dev/null || true
      ;;
  esac
}

# Convenience wrappers

# Notify user that new chapters have been processed
nf_notify_chapters_processed() {
  local count="$1"
  local series="${2:-unknown series}"
  nf_notify "Novel Forge" "${count} chapter(s) processed for ${series}. Open your browser to review." "normal"
}

# Notify user that a new series was detected and needs setup
nf_notify_new_series() {
  nf_notify "Novel Forge — Action Required" "New manuscript detected that doesn't match any known series. Open your browser to set it up." "critical"
}

# Notify user about continuity issues found
nf_notify_continuity_issues() {
  local count="$1"
  local series="${2:-}"
  nf_notify "Novel Forge — Continuity Check" "${count} issue(s) found in ${series}. Open your browser to review." "normal"
}

# Notify user that processing is complete with no issues
nf_notify_all_clear() {
  local series="${1:-}"
  nf_notify "Novel Forge" "Processing complete for ${series}. No continuity issues found." "low"
}

# Notify user of an error
nf_notify_error() {
  local message="$1"
  nf_notify "Novel Forge — Error" "$message" "critical"
}
