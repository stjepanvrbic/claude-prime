#!/bin/bash
# Mark session as primed
# Usage: mark-primed.sh [project_dir]

set -euo pipefail

project_dir="${1:-$PWD}"

# Find the state file for this session
state_file="${PRIME_STATE_FILE:-}"

if [ -z "$state_file" ]; then
  # Try to find the most recent state file
  state_file=$(ls -t "$project_dir/.claude/.prime-state-"* 2>/dev/null | head -1 || true)
fi

if [ -z "$state_file" ] || [ ! -f "$state_file" ]; then
  # No state file found - create a generic one
  mkdir -p "$project_dir/.claude"
  state_file="$project_dir/.claude/.prime-state-default"
fi

# Read current state to preserve session_id
session_id=$(jq -r '.session_id // "unknown"' "$state_file" 2>/dev/null || echo "unknown")

# Update state file
cat > "$state_file" << EOF
{
  "status": "primed",
  "session_id": "$session_id",
  "primed_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF

echo "Session marked as primed"
