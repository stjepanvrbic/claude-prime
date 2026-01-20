#!/bin/bash
# Session start hook for prime plugin
# Creates a unique session state file marking this session as "unprimed"
# Windows-compatible version

set -euo pipefail

# Read input from stdin
input=$(cat)

# Extract session_id - try jq first, fallback to grep/sed
if command -v jq &> /dev/null; then
  session_id=$(echo "$input" | jq -r '.session_id // empty' 2>/dev/null || echo "")
else
  # Fallback: extract session_id using grep/sed
  session_id=$(echo "$input" | grep -o '"session_id"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*"\([^"]*\)"$/\1/' 2>/dev/null || echo "")
fi

# If no session_id, generate one
if [ -z "$session_id" ]; then
  # Try multiple methods for UUID generation
  if command -v uuidgen &> /dev/null; then
    session_id=$(uuidgen | tr '[:upper:]' '[:lower:]')
  elif command -v powershell &> /dev/null; then
    # Windows PowerShell
    session_id=$(powershell -Command "[guid]::NewGuid().ToString()" 2>/dev/null || echo "")
  elif [ -f /proc/sys/kernel/random/uuid ]; then
    # Linux
    session_id=$(cat /proc/sys/kernel/random/uuid)
  else
    # Last resort: timestamp + random
    session_id="$(date +%s)-$RANDOM-$RANDOM"
  fi
fi

# Get project directory
if command -v jq &> /dev/null; then
  project_dir=$(echo "$input" | jq -r '.cwd // empty' 2>/dev/null || echo "")
else
  project_dir=$(echo "$input" | grep -o '"cwd"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*"\([^"]*\)"$/\1/' 2>/dev/null || echo "")
fi

if [ -z "$project_dir" ]; then
  project_dir="$PWD"
fi

# Create .claude directory if it doesn't exist
mkdir -p "$project_dir/.claude"

# Create state file with session info
state_file="$project_dir/.claude/.prime-state-$session_id"

# Get current timestamp
timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date +%Y-%m-%dT%H:%M:%SZ)

# Write initial state (manual JSON to avoid jq dependency)
cat > "$state_file" << EOF
{
  "status": "unprimed",
  "session_id": "$session_id",
  "created_at": "$timestamp"
}
EOF

# Store session_id in env file for other hooks to use
if [ -n "${CLAUDE_ENV_FILE:-}" ]; then
  echo "export PRIME_SESSION_ID=\"$session_id\"" >> "$CLAUDE_ENV_FILE"
  echo "export PRIME_STATE_FILE=\"$state_file\"" >> "$CLAUDE_ENV_FILE"
fi

# Return success with minimal output
echo '{"continue": true, "suppressOutput": true}'
