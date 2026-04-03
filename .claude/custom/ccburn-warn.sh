#!/bin/bash
# UserPromptSubmit hook: delta-based session burn warning
#
# Warns when a single turn burned a disproportionate amount of the session
# OR when the session is running critically high overall.
# Silent otherwise — no noise on every prompt.
#
# State: ~/.claude/ccburn-state  (last utilization, plain float)
# Thresholds:
#   DELTA_WARN   = 0.06  (warn if one turn burned >6% of session)
#   SESSION_WARN = 0.78  (warn if session is >78% consumed)
#   SESSION_CRIT = 0.90  (hard warning, be very concise)

STATE_FILE="$HOME/.claude/ccburn-state"
DELTA_WARN=0.06
SESSION_WARN=0.78
SESSION_CRIT=0.90

data=$(ccburn --json --once 2>/dev/null)
[ -z "$data" ] && exit 0

# Extract current utilization and reset info
read -r cur_util resets_in_min weekly_util <<< "$(echo "$data" | python3 -c "
import json, sys
d = json.load(sys.stdin)
s = d.get('limits', {}).get('session', {})
w = d.get('limits', {}).get('weekly', {})
util = s.get('utilization', 0)
rim = s.get('resets_in_minutes') or 0
wu = w.get('utilization', 0)
print(util, int(rim), wu)
" 2>/dev/null)"

[ -z "$cur_util" ] && exit 0

# Load previous utilization and last warned tier (0=none, 1=warn, 2=crit)
last_util=0
last_tier=0
if [ -f "$STATE_FILE" ]; then
  last_util=$(sed -n '1p' "$STATE_FILE" 2>/dev/null || echo 0)
  last_tier=$(sed -n '2p' "$STATE_FILE" 2>/dev/null || echo 0)
fi

# Compute current tier
cur_tier=$(python3 -c "
cur = float('$cur_util')
last = float('$last_util' or 0)
# Reset tier if session rolled over (utilization dropped)
if cur < last - 0.05:
    print(0)
elif cur >= $SESSION_CRIT:
    print(2)
elif cur >= $SESSION_WARN:
    print(1)
else:
    print(0)
" 2>/dev/null)

# Save current state for next turn
printf '%s\n%s\n' "$cur_util" "$cur_tier" > "$STATE_FILE"

# Compute delta (previous turn's cost)
delta=$(python3 -c "
cur = float('$cur_util')
last = float('$last_util')
d = cur - last
print(round(d, 4) if d > 0 else 0)
" 2>/dev/null)

# Check if anything warrants a message
msg=$(python3 -c "
cur = float('$cur_util')
delta = float('$delta' or 0)
rim = int('$resets_in_min' or 0)
wu = float('$weekly_util' or 0)
cur_tier = int('$cur_tier' or 0)
last_tier = int('$last_tier' or 0)
delta_warn = float('$DELTA_WARN')

parts = []

if delta >= delta_warn:
    pct = round(delta * 100)
    parts.append(f'Last turn burned {pct}% of session budget.')

# Only warn on session tier if we just crossed into a new (higher) tier
if cur_tier > last_tier:
    pct = round(cur * 100)
    hours = round(rim / 60, 1)
    if cur_tier == 2:
        parts.append(f'CRITICAL: session at {pct}% (resets in {hours}h). Be extremely concise — no exploratory reads, no re-reads, targeted edits only.')
    elif cur_tier == 1:
        parts.append(f'Session at {pct}% (resets in {hours}h). Prefer concise responses and avoid unnecessary file reads.')

if wu >= 0.85:
    wpct = round(wu * 100)
    parts.append(f'Weekly usage also high: {wpct}%.')

print(' '.join(parts))
" 2>/dev/null)

[ -z "$msg" ] && exit 0

jq -n --arg ctx "$msg" '{"additionalContext": $ctx}'
