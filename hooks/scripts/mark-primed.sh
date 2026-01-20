#!/bin/bash
# Mark session as primed
# Windows-compatible version
# Usage: mark-primed.sh [project_dir]

set -euo pipefail

project_dir="${1:-$PWD}"

# Helper function to extract JSON value without jq
extract_json_value() {
  local key="$1"
  local json="$2"
  echo "$json" | grep -o "\"$key\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" | sed 's/.*"\([^"]*\)"$/\1/' 2>/dev/null || echo ""
}

# Find the state file for this session
state_file="${PRIME_STATE_FILE:-}"

if [ -z "$state_file" ]; then
  # Try to find the most recent state file
  if [ -d "$project_dir/.claude" ]; then
    state_file=$(ls -t "$project_dir/.claude/.prime-state-"* 2>/dev/null | head -1 || echo "")
  fi
fi

if [ -z "$state_file" ] || [ ! -f "$state_file" ]; then
  # No state file found - create a generic one
  mkdir -p "$project_dir/.claude"
  state_file="$project_dir/.claude/.prime-state-default"
fi

# Read current state to preserve session_id
if [ -f "$state_file" ]; then
  if command -v jq &> /dev/null; then
    session_id=$(jq -r '.session_id // "unknown"' "$state_file" 2>/dev/null || echo "unknown")
  else
    session_id=$(extract_json_value "session_id" "$(cat "$state_file")")
    [ -z "$session_id" ] && session_id="unknown"
  fi
else
  session_id="unknown"
fi

# Get current timestamp
timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date +%Y-%m-%dT%H:%M:%SZ)

# Update state file
cat > "$state_file" << EOF
{
  "status": "primed",
  "session_id": "$session_id",
  "primed_at": "$timestamp"
}
EOF

echo "Session marked as primed"
