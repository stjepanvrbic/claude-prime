#!/bin/bash
# Auto-prime check hook for prime plugin
# Checks if session is primed, if not - instructs Claude to run /prime first

set -euo pipefail

# Read input from stdin
input=$(cat)

# Get project directory
project_dir=$(echo "$input" | jq -r '.cwd // empty')
if [ -z "$project_dir" ]; then
  project_dir="$PWD"
fi

# Get session_id from environment (set by session-start hook) or from input
session_id="${PRIME_SESSION_ID:-}"
if [ -z "$session_id" ]; then
  session_id=$(echo "$input" | jq -r '.session_id // empty')
fi

# If still no session_id, look for any state file (fallback)
if [ -z "$session_id" ]; then
  state_file=$(ls -t "$project_dir/.claude/.prime-state-"* 2>/dev/null | head -1 || true)
else
  state_file="$project_dir/.claude/.prime-state-$session_id"
fi

# Check if state file exists
if [ -z "$state_file" ] || [ ! -f "$state_file" ]; then
  # No state file - this shouldn't happen if session-start ran, but handle gracefully
  # Assume unprimed and continue
  echo '{"continue": true}'
  exit 0
fi

# Read state
status=$(jq -r '.status // "unprimed"' "$state_file" 2>/dev/null || echo "unprimed")

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
# Pattern: fix/bug-description -> bug-description
prime_prompt=""
if [ -n "$branch_name" ]; then
  # Remove common prefixes
  description=$(echo "$branch_name" | sed -E 's#^(feature|fix|bugfix|hotfix|release)/##' | sed -E 's#^F[0-9]+\.[0-9]+-##')
  # Convert hyphens to spaces for readability
  description=$(echo "$description" | tr '-' ' ')
  prime_prompt="$description"
fi

# Build the system message
if [ -n "$prime_prompt" ]; then
  system_message="IMPORTANT: This session has not been primed yet. Before addressing the user's request, you MUST first run the /prime command to gather context about the codebase. Run: /prime $prime_prompt\n\nAfter priming completes, proceed with the user's original request."
else
  system_message="IMPORTANT: This session has not been primed yet. Before addressing the user's request, you MUST first run the /prime command (with no arguments) to gather general context about the codebase.\n\nAfter priming completes, proceed with the user's original request."
fi

# Return with system message instructing Claude to prime first
# Escape the message for JSON
escaped_message=$(echo "$system_message" | jq -Rs '.')

cat << EOF
{
  "continue": true,
  "systemMessage": $escaped_message
}
EOF
