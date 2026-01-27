#!/bin/bash
# Ralph Wiggum - Long-running AI agent loop
# Usage: ./ralph.sh [--agent amp|claude|codex|opencode] [--prd /path/to/prd.json] [--prompt "task"] [max_iterations]

set -e

show_usage() {
  cat <<'EOF'
Usage:
  ralph.sh [--agent amp|claude|codex|opencode] [--prd /path/to/prd.json] [--prompt "task"] [max_iterations]

Notes:
  - If --prd is not provided, ralph.sh reads ./prd.json in the current directory.
  - If no prd.json is found, provide --prd or run: ralphx "your task"
  - Default agent can be set with the RALPHX_AGENT environment variable.
  - --tool is deprecated and will error. Use --agent.
EOF
}

escape_sed() {
  printf '%s' "$1" | sed -e 's/[\/&]/\\&/g'
}

# Parse arguments
AGENT="${RALPHX_AGENT:-amp}"
MAX_ITERATIONS=10
PRD_PATH=""
USER_PROMPT=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --agent)
      AGENT="$2"
      shift 2
      ;;
    --agent=*)
      AGENT="${1#*=}"
      shift
      ;;
    --tool|--tool=*)
      echo "Error: --tool is deprecated. Use --agent."
      exit 1
      ;;
    --prd)
      if [ -z "${2:-}" ]; then
        echo "Error: --prd requires a path."
        exit 1
      fi
      PRD_PATH="$2"
      shift 2
      ;;
    --prd=*)
      PRD_PATH="${1#*=}"
      shift
      ;;
    --prompt)
      if [ -z "${2:-}" ]; then
        echo "Error: --prompt requires text."
        exit 1
      fi
      USER_PROMPT="$2"
      shift 2
      ;;
    --prompt=*)
      USER_PROMPT="${1#*=}"
      shift
      ;;
    -h|--help)
      show_usage
      exit 0
      ;;
    *)
      # Assume it's max_iterations if it's a number
      if [[ "$1" =~ ^[0-9]+$ ]]; then
        MAX_ITERATIONS="$1"
      else
        if [ -z "$USER_PROMPT" ]; then
          USER_PROMPT="$1"
        else
          USER_PROMPT="$USER_PROMPT $1"
        fi
      fi
      shift
      ;;
  esac
done

if [ -n "$PRD_PATH" ] && [ -n "$USER_PROMPT" ]; then
  echo "Error: --prd and --prompt cannot be used together."
  exit 1
fi

# Validate agent choice
if [[ "$AGENT" != "amp" && "$AGENT" != "claude" && "$AGENT" != "codex" && "$AGENT" != "opencode" ]]; then
  echo "Error: Invalid agent '$AGENT'. Must be 'amp', 'claude', 'codex', or 'opencode'."
  exit 1
fi
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK_DIR=""

if [ -n "$USER_PROMPT" ]; then
  WORK_DIR="${PWD}/.ralphx"
  mkdir -p "$WORK_DIR"
  WORK_DIR="$(cd "$WORK_DIR" && pwd)"
  PRD_FILE="$WORK_DIR/prd.json"
else
  if [ -n "$PRD_PATH" ]; then
    PRD_FILE="$PRD_PATH"
  else
    PRD_FILE="${PWD}/prd.json"
  fi

  if [ ! -f "$PRD_FILE" ]; then
    echo "Error: prd.json not found at $PRD_FILE."
    echo "Provide --prd /path/to/prd.json or run: ralphx \"your task\""
    exit 1
  fi

  WORK_DIR="$(cd "$(dirname "$PRD_FILE")" && pwd)"
  PRD_FILE="$WORK_DIR/$(basename "$PRD_FILE")"
fi

PROGRESS_FILE="$WORK_DIR/progress.txt"
ARCHIVE_DIR="$WORK_DIR/archive"
LAST_BRANCH_FILE="$WORK_DIR/.last-branch"

if [ -n "$USER_PROMPT" ]; then
  PROMPT_TITLE=$(printf '%s' "$USER_PROMPT" | tr '\n' ' ' | cut -c1-60)
  jq -n --arg prompt "$USER_PROMPT" --arg title "$PROMPT_TITLE" '{
    project: "RalphPrompt",
    branchName: "main",
    description: "Prompt mode run",
    userStories: [
      {
        id: "PROMPT-001",
        title: $title,
        description: $prompt,
        acceptanceCriteria: [
          "Implement the requested change",
          "Typecheck passes"
        ],
        priority: 1,
        passes: false,
        notes: ""
      }
    ]
  }' > "$PRD_FILE"

  echo "# Ralph Progress Log" > "$PROGRESS_FILE"
  echo "Started: $(date)" >> "$PROGRESS_FILE"
  echo "---" >> "$PROGRESS_FILE"
fi

PRD_ESC=$(escape_sed "$PRD_FILE")
PROGRESS_ESC=$(escape_sed "$PROGRESS_FILE")

render_prompt() {
  local template="$1"
  sed -e "s/prd.json/$PRD_ESC/g" \
      -e "s/progress.txt/$PROGRESS_ESC/g" \
      -e "s/ (in the same directory as this file)//g" \
      "$template"
}

# Archive previous run if branch changed
if [ -f "$PRD_FILE" ] && [ -f "$LAST_BRANCH_FILE" ]; then
  CURRENT_BRANCH=$(jq -r '.branchName // empty' "$PRD_FILE" 2>/dev/null || echo "")
  LAST_BRANCH=$(cat "$LAST_BRANCH_FILE" 2>/dev/null || echo "")
  
  if [ -n "$CURRENT_BRANCH" ] && [ -n "$LAST_BRANCH" ] && [ "$CURRENT_BRANCH" != "$LAST_BRANCH" ]; then
    # Archive the previous run
    DATE=$(date +%Y-%m-%d)
    # Strip "ralph/" prefix from branch name for folder
    FOLDER_NAME=$(echo "$LAST_BRANCH" | sed 's|^ralph/||')
    ARCHIVE_FOLDER="$ARCHIVE_DIR/$DATE-$FOLDER_NAME"
    
    echo "Archiving previous run: $LAST_BRANCH"
    mkdir -p "$ARCHIVE_FOLDER"
    [ -f "$PRD_FILE" ] && cp "$PRD_FILE" "$ARCHIVE_FOLDER/"
    [ -f "$PROGRESS_FILE" ] && cp "$PROGRESS_FILE" "$ARCHIVE_FOLDER/"
    echo "   Archived to: $ARCHIVE_FOLDER"
    
    # Reset progress file for new run
    echo "# Ralph Progress Log" > "$PROGRESS_FILE"
    echo "Started: $(date)" >> "$PROGRESS_FILE"
    echo "---" >> "$PROGRESS_FILE"
  fi
fi

# Track current branch
if [ -f "$PRD_FILE" ]; then
  CURRENT_BRANCH=$(jq -r '.branchName // empty' "$PRD_FILE" 2>/dev/null || echo "")
  if [ -n "$CURRENT_BRANCH" ]; then
    echo "$CURRENT_BRANCH" > "$LAST_BRANCH_FILE"
  fi
fi

# Initialize progress file if it doesn't exist
if [ ! -f "$PROGRESS_FILE" ]; then
  echo "# Ralph Progress Log" > "$PROGRESS_FILE"
  echo "Started: $(date)" >> "$PROGRESS_FILE"
  echo "---" >> "$PROGRESS_FILE"
fi

echo "Starting Ralph - Agent: $AGENT - Max iterations: $MAX_ITERATIONS"

for i in $(seq 1 $MAX_ITERATIONS); do
  echo ""
  echo "==============================================================="
  echo "  Ralph Iteration $i of $MAX_ITERATIONS ($AGENT)"
  echo "==============================================================="

  # Run the selected tool with the ralph prompt
  case "$AGENT" in
    amp)
      AGENT_PROMPT=$(render_prompt "$SCRIPT_DIR/prompt.md")
      OUTPUT=$(printf '%s' "$AGENT_PROMPT" | amp --dangerously-allow-all 2>&1 | tee /dev/stderr) || true
      ;;
    claude)
      # Claude Code: use --dangerously-skip-permissions for autonomous operation, --print for output
      AGENT_PROMPT=$(render_prompt "$SCRIPT_DIR/CLAUDE.md")
      OUTPUT=$(printf '%s' "$AGENT_PROMPT" | claude --dangerously-skip-permissions --print 2>&1 | tee /dev/stderr) || true
      ;;
    codex)
      # Codex CLI: use exec for non-interactive runs, allow full auto and write access
      AGENT_PROMPT=$(render_prompt "$SCRIPT_DIR/CODEX.md")
      OUTPUT=$(codex exec --full-auto --sandbox danger-full-access "$AGENT_PROMPT" 2>&1 | tee /dev/stderr) || true
      ;;
    opencode)
      # OpenCode CLI: non-interactive prompt mode, hide spinner output
      AGENT_PROMPT=$(render_prompt "$SCRIPT_DIR/OPENCODE.md")
      OUTPUT=$(opencode -p "$AGENT_PROMPT" -q 2>&1 | tee /dev/stderr) || true
      ;;
  esac
  
  # Check for completion signal
  if echo "$OUTPUT" | grep -q "<promise>COMPLETE</promise>"; then
    echo ""
    echo "Ralph completed all tasks!"
    echo "Completed at iteration $i of $MAX_ITERATIONS"
    exit 0
  fi
  
  echo "Iteration $i complete. Continuing..."
  sleep 2
done

echo ""
echo "Ralph reached max iterations ($MAX_ITERATIONS) without completing all tasks."
echo "Check $PROGRESS_FILE for status."
exit 1
