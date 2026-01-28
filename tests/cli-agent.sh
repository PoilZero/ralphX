#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORKSPACE_ROOT="$(cd "$ROOT_DIR/.." && pwd)"
TMP_ROOT="$WORKSPACE_ROOT/tmp"

mkdir -p "$TMP_ROOT"

STUB_DIR="$TMP_ROOT/ralphx-agent-stubs-$$"
BASE_DIR="$TMP_ROOT/ralphx-agent-cli-tests-$$"

mkdir -p "$STUB_DIR" "$BASE_DIR"

create_stub() {
  local name="$1"
  cat > "$STUB_DIR/$name" <<'EOS'
#!/usr/bin/env bash
set -e
if [ -n "${RALPHX_TEST_MARKER:-}" ]; then
  printf '%s\n' "$0" > "$RALPHX_TEST_MARKER"
fi
if [ -n "${RALPHX_TEST_ARGS:-}" ]; then
  printf '%s\n' "$*" > "$RALPHX_TEST_ARGS"
fi
printf '<promise>COMPLETE</promise>\n'
EOS
  chmod +x "$STUB_DIR/$name"
}

for cmd in amp claude codex opencode; do
  create_stub "$cmd"
done

assert_file_contains() {
  local file="$1"
  local needle="$2"
  if ! grep -q -- "$needle" "$file"; then
    echo "Assertion failed: $file does not contain $needle" >&2
    exit 1
  fi
}

run_case() {
  local name="$1"
  local workdir="$BASE_DIR/$name"
  shift
  mkdir -p "$workdir"
  git -C "$workdir" init -b main >/dev/null
  "$@" >"$workdir/run.log" 2>&1
  printf '%s\n' "$workdir"
}

run_case_no_git() {
  local name="$1"
  local workdir="$BASE_DIR/$name"
  shift
  mkdir -p "$workdir"
  "$@" >"$workdir/run.log" 2>&1
  printf '%s\n' "$workdir"
}

# Case 1: --agent selects codex
case1_dir=$(run_case "agent-flag" bash -c "cd \"$BASE_DIR/agent-flag\" && PATH=\"$STUB_DIR:\$PATH\" RALPHX_TEST_MARKER=\"$BASE_DIR/agent-flag/marker.txt\" RALPHX_TEST_ARGS=\"$BASE_DIR/agent-flag/args.txt\" \"$ROOT_DIR/ralph.sh\" --agent codex \"Create a file AGENT_OK.txt with content AGENT_OK\" 1")
assert_file_contains "$case1_dir/marker.txt" "codex"
assert_file_contains "$case1_dir/args.txt" "--dangerously-bypass-approvals-and-sandbox"
if grep -q -- "--skip-git-repo-check" "$case1_dir/args.txt"; then
  echo "Assertion failed: --skip-git-repo-check should not be used inside git repo" >&2
  exit 1
fi

# Case 2: RALPHX_AGENT selects codex
case2_dir=$(run_case "env-var" bash -c "cd \"$BASE_DIR/env-var\" && PATH=\"$STUB_DIR:\$PATH\" RALPHX_TEST_MARKER=\"$BASE_DIR/env-var/marker.txt\" RALPHX_TEST_ARGS=\"$BASE_DIR/env-var/args.txt\" RALPHX_AGENT=codex \"$ROOT_DIR/ralph.sh\" \"Create a file ENV_OK.txt with content ENV_OK\" 1")
assert_file_contains "$case2_dir/marker.txt" "codex"
assert_file_contains "$case2_dir/args.txt" "--dangerously-bypass-approvals-and-sandbox"
if grep -q -- "--skip-git-repo-check" "$case2_dir/args.txt"; then
  echo "Assertion failed: --skip-git-repo-check should not be used inside git repo" >&2
  exit 1
fi

# Case 3: lowercase ralphx_agent is ignored
case3_dir=$(run_case "lowercase-env" bash -c "cd \"$BASE_DIR/lowercase-env\" && PATH=\"$STUB_DIR:\$PATH\" RALPHX_TEST_MARKER=\"$BASE_DIR/lowercase-env/marker.txt\" ralphx_agent=codex \"$ROOT_DIR/ralph.sh\" \"Create a file LOWER_OK.txt with content LOWER_OK\" 1")
assert_file_contains "$case3_dir/marker.txt" "amp"

# Case 4: non-git codex adds skip check
case4_dir=$(run_case_no_git "codex-non-git" bash -c "cd \"$BASE_DIR/codex-non-git\" && PATH=\"$STUB_DIR:\$PATH\" RALPHX_TEST_MARKER=\"$BASE_DIR/codex-non-git/marker.txt\" RALPHX_TEST_ARGS=\"$BASE_DIR/codex-non-git/args.txt\" \"$ROOT_DIR/ralph.sh\" --agent codex \"Create a file NON_GIT_OK.txt with content NON_GIT_OK\" 1")
assert_file_contains "$case4_dir/marker.txt" "codex"
assert_file_contains "$case4_dir/args.txt" "--dangerously-bypass-approvals-and-sandbox"
assert_file_contains "$case4_dir/args.txt" "--skip-git-repo-check"

# Case 5: --tool errors out
case5_dir="$BASE_DIR/tool-deprecated"
mkdir -p "$case5_dir"
set +e
PATH="$STUB_DIR:$PATH" "$ROOT_DIR/ralph.sh" --tool codex 1 >"$case5_dir/run.log" 2>&1
status=$?
set -e
if [ "$status" -eq 0 ]; then
  echo "Assertion failed: --tool did not error" >&2
  exit 1
fi
assert_file_contains "$case5_dir/run.log" "Error: --tool is deprecated. Use --agent."

echo "OK: cli agent tests passed"
