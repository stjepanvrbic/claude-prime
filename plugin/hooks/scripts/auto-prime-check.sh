#!/bin/bash
# Auto-prime check hook for prime plugin
# Checks if session is primed, if not - instructs Claude to run /prime first
# Windows-compatible version

set -euo pipefail

# Read input from stdin
input=$(cat)

# Helper function to extract JSON value without jq
extract_json_value() {
  local key="$1"
  local json="$2"
  echo "$json" | grep -o "\"$key\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" | sed 's/.*"\([^"]*\)"$/\1/' 2>/dev/null || echo ""
}

# Get project directory
if command -v jq &> /dev/null; then
  project_dir=$(echo "$input" | jq -r '.cwd // empty' 2>/dev/null || echo "")
else
  project_dir=$(extract_json_value "cwd" "$input")
fi

if [ -z "$project_dir" ]; then
  project_dir="$PWD"
fi

# Get session_id from environment (set by session-start hook) or from input
session_id="${PRIME_SESSION_ID:-}"
if [ -z "$session_id" ]; then
  if command -v jq &> /dev/null; then
    session_id=$(echo "$input" | jq -r '.session_id // empty' 2>/dev/null || echo "")
  else
    session_id=$(extract_json_value "session_id" "$input")
  fi
fi

# If still no session_id, look for any state file (fallback)
state_file=""
if [ -z "$session_id" ]; then
  # Find most recent state file
  if [ -d "$project_dir/.claude" ]; then
    state_file=$(ls -t "$project_dir/.claude/.prime-state-"* 2>/dev/null | head -1 || echo "")
  fi
else
  state_file="$project_dir/.claude/.prime-state-$session_id"
fi

# Check for simple marker file first (created by local /prime command)
if [ -f "$project_dir/.claude/.prime-session-marker" ]; then
  echo '{"continue": true}'
  exit 0
fi

# Check if state file exists
if [ -z "$state_file" ] || [ ! -f "$state_file" ]; then
  # No state file - assume unprimed but don't block
  echo '{"continue": true}'
  exit 0
fi

# Read status from state file
if command -v jq &> /dev/null; then
  status=$(jq -r '.status // "unprimed"' "$state_file" 2>/dev/null || echo "unprimed")
else
  status=$(extract_json_value "status" "$(cat "$state_file")")
  [ -z "$status" ] && status="unprimed"
fi

# If already primed, allow prompt to proceed
if [ "$status" = "primed" ]; then
  echo '{"continue": true}'
  exit 0
fi

# Not primed - get branch name for auto-prime prompt
branch_name=""
if [ -d "$project_dir/.git" ] || git -C "$project_dir" rev-parse --git-dir > /dev/null 2>&1; then
  branch_name=$(git -C "$project_dir" symbolic-ref --short HEAD 2>/dev/null || echo "")
fi

# Extract description from branch name
# Pattern: feature/F3.1-backtest-engine -> backtest-engine
# Pattern: feature/some-feature -> some-feature
prime_prompt=""
if [ -n "$branch_name" ]; then
  # Remove common prefixes and feature IDs
  description=$(echo "$branch_name" | sed -E 's#^(feature|fix|bugfix|hotfix|release)/##' | sed -E 's#^F[0-9]+\.[0-9]+-##')
  # Convert hyphens to spaces
  description=$(echo "$description" | tr '-' ' ')
  prime_prompt="$description"
fi

# Build the system message
if [ -n "$prime_prompt" ]; then
  system_message="IMPORTANT: This session has not been primed yet. Before addressing the user's request, you MUST first run the /prime command to gather context about the codebase. Run: /prime $prime_prompt

After priming completes, proceed with the user's original request."
else
  system_message="IMPORTANT: This session has not been primed yet. Before addressing the user's request, you MUST first run the /prime command (with no arguments) to gather general context about the codebase.

After priming completes, proceed with the user's original request."
fi

# Escape for JSON output (handle newlines and quotes)
escaped_message=$(echo "$system_message" | sed 's/\\/\\\\/g; s/"/\\"/g' | tr '\n' ' ')

# Return with system message
echo "{\"continue\": true, \"systemMessage\": \"$escaped_message\"}"
