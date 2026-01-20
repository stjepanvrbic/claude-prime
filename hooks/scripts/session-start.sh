#!/bin/bash
# Session start hook for prime plugin
# Creates a unique session state file marking this session as "unprimed"

set -euo pipefail

# Read input from stdin
input=$(cat)

# Extract session_id from input
session_id=$(echo "$input" | jq -r '.session_id // empty')

# If no session_id, generate a UUID
if [ -z "$session_id" ]; then
  # Generate UUID - works on both Linux and macOS
  if command -v uuidgen &> /dev/null; then
    session_id=$(uuidgen | tr '[:upper:]' '[:lower:]')
  else
    # Fallback: use /dev/urandom
    session_id=$(cat /proc/sys/kernel/random/uuid 2>/dev/null || head -c 32 /dev/urandom | xxd -p | head -c 32)
  fi
fi

# Get project directory
project_dir=$(echo "$input" | jq -r '.cwd // empty')
if [ -z "$project_dir" ]; then
  project_dir="$PWD"
fi

# Create .claude directory if it doesn't exist
mkdir -p "$project_dir/.claude"

# Create state file with session info
state_file="$project_dir/.claude/.prime-state-$session_id"

# Write initial state
cat > "$state_file" << EOF
{
  "status": "unprimed",
  "session_id": "$session_id",
  "created_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF

# Store session_id in env file for other hooks to use
if [ -n "${CLAUDE_ENV_FILE:-}" ]; then
  echo "export PRIME_SESSION_ID=\"$session_id\"" >> "$CLAUDE_ENV_FILE"
  echo "export PRIME_STATE_FILE=\"$state_file\"" >> "$CLAUDE_ENV_FILE"
fi

# Return success with minimal output
echo '{"continue": true, "suppressOutput": true}'
