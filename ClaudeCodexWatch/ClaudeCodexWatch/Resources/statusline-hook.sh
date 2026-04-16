#!/bin/bash
# ClaudeCodexWatch statusline hook
# Receives Claude Code status JSON on stdin, writes it to the app's cache file,
# then outputs a single status line for Claude Code's terminal UI.
# Never exits non-zero; never blocks Claude Code.

CACHE_DIR="$HOME/Library/Application Support/ClaudeCodexWatch"
CACHE_FILE="$CACHE_DIR/claude_latest.json"
TMP_FILE="$CACHE_DIR/.claude_latest.tmp.$$"

# Read stdin (Claude Code sends JSON here)
INPUT="$(cat)"

# Ensure cache directory exists
mkdir -p "$CACHE_DIR"

# Write atomically: tmp file then rename
if [ -n "$INPUT" ]; then
    printf '%s' "$INPUT" > "$TMP_FILE"
    mv -f "$TMP_FILE" "$CACHE_FILE"
fi

# If a chain command is configured, pass input to it and print its output
if [ -n "${CCW_CHAIN_CMD:-}" ]; then
    printf '%s' "$INPUT" | eval "$CCW_CHAIN_CMD"
    exit 0
fi

# Default output: model | context% | session%
# Pass INPUT via a temp file so python3 heredoc can read it
if [ -n "$INPUT" ] && command -v python3 &>/dev/null; then
    PYINPUT_FILE="$CACHE_DIR/.pyinput.$$"
    printf '%s' "$INPUT" > "$PYINPUT_FILE"
    python3 - "$PYINPUT_FILE" <<'PYEOF'
import sys, json

try:
    with open(sys.argv[1]) as f:
        data = json.load(f)
    import os; os.unlink(sys.argv[1])
except Exception:
    data = {}

model = (data.get('model') or {}).get('display_name', 'Claude')
ctx_pct = (data.get('context_window') or {}).get('used_percentage')
session_pct = ((data.get('rate_limits') or {}).get('five_hour') or {}).get('used_percentage')

parts = [model]
if ctx_pct is not None:
    parts.append(f'ctx {ctx_pct:.0f}%')
if session_pct is not None:
    parts.append(f'session {session_pct:.0f}%')
print(' | '.join(parts))
PYEOF
else
    echo "ClaudeCodexWatch"
fi

exit 0
