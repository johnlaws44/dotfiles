#!/usr/bin/env bash
# Claude Code status line — AVIT zsh theme style, 3-line layout

input=$(cat)

# ── Stdin fields ──────────────────────────────────────────────────────────────
cwd=$(echo "$input"     | jq -r '.workspace.current_dir // .cwd // "."')
model=$(echo "$input"   | jq -r '.model.display_name // .model // ""')
version=$(echo "$input" | jq -r '.version // ""')
cost=$(echo "$input"    | jq -r '.cost.total_cost_usd // empty')

ctx_size=$(echo "$input" | jq -r '.context_window.context_window_size // empty')
ctx_pct=$(echo "$input"  | jq -r '.context_window.used_percentage // empty')
ctx_used=$(echo "$input" | jq -r '.context_window.total_input_tokens // empty')

sess_pct=$(echo "$input"   | jq -r '.rate_limits.five_hour.used_percentage // empty')
weekly_pct=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')
resets_at=$(echo "$input"  | jq -r '.rate_limits.five_hour.resets_at // empty')

# ── Path: last 2 components (line 1) + full cwd (line 3) ─────────────────────
dir=$(echo "$cwd" | awk -F'/' '{
  n=NF
  if (n==1) print $1
  else if ($1=="" && n==2) print "/"$2
  else print $(n-1)"/"$n
}')

# ── Git branch + remote link ──────────────────────────────────────────────────
branch=""
repo_link=""
if git -C "$cwd" --no-optional-locks rev-parse --is-inside-work-tree &>/dev/null 2>&1; then
  branch=$(git -C "$cwd" --no-optional-locks symbolic-ref --short HEAD 2>/dev/null)
  git_dirty=$(git -C "$cwd" --no-optional-locks status --porcelain 2>/dev/null | head -1)
  remote=$(git -C "$cwd" remote get-url origin 2>/dev/null)
  if [ -n "$remote" ]; then
    # Normalize SSH → HTTPS
    repo_link=$(echo "$remote" \
      | sed 's|git@github.com:|https://github.com/|' \
      | sed 's|\.git$||')
  fi
fi

# ── Reset timer from epoch ────────────────────────────────────────────────────
reset_str=""
if [ -n "$resets_at" ]; then
  now=$(date +%s)
  diff_sec=$(( ${resets_at%.*} - now ))
  if [ "$diff_sec" -gt 0 ]; then
    r_hrs=$(( diff_sec / 3600 ))
    r_min=$(( (diff_sec % 3600) / 60 ))
    [ "$r_hrs" -gt 0 ] && reset_str="${r_hrs}hr ${r_min}m" || reset_str="${r_min}m"
  fi
fi

# ── Thinking effort ───────────────────────────────────────────────────────────
effort="medium"
settings_effort=$(jq -r '.effortLevel // empty' ~/.claude/settings.json 2>/dev/null)
[ -n "$settings_effort" ] && effort="$settings_effort"

# ── Context bar ───────────────────────────────────────────────────────────────
ctx_bar=""
ctx_int=0
if [ -n "$ctx_pct" ] && [ -n "$ctx_size" ]; then
  effective_max=$(( ctx_size / 2 ))
  total_k=$(( effective_max / 1000 ))
  raw_pct=$(printf '%.0f' "$ctx_pct")
  ctx_int=$(( raw_pct * 2 ))
  [ "$ctx_int" -gt 100 ] && ctx_int=100
  used_k=$(( raw_pct * ctx_size / 100 / 1000 ))
  bar_width=16
  filled=$(( bar_width * ctx_int / 100 ))
  empty=$(( bar_width - filled ))
  bar=$(printf '%*s' "$filled" '' | tr ' ' '#')$(printf '%*s' "$empty" '' | tr ' ' '-')
  ctx_bar="[${bar}] ${used_k}k/${total_k}k (${ctx_int}%)"
fi

# ── Terminal width ────────────────────────────────────────────────────────────
term_w=$(tput cols 2>/dev/null || echo 120)

# ── Color helpers ─────────────────────────────────────────────────────────────
pct_color() {
  local pct=${1:-0}
  if   [ "$pct" -ge 80 ]; then printf '\033[0;31m'
  elif [ "$pct" -ge 50 ]; then printf '\033[0;33m'
  else                         printf '\033[0;32m'
  fi
}
rst='\033[0m'
mag='\033[1;35m'   # bold magenta — dir
grn='\033[0;32m'   # green        — branch, low usage
cyn='\033[0;36m'   # cyan         — model, weekly
wht='\033[0;37m'   # grey/white   — version, reset, effort
yel='\033[0;33m'   # yellow       — cost, mid usage
dim='\033[2;37m'   # dim grey     — cwd, link

# Strip ANSI for length measurement
ansi_len() { echo -e "$1" | sed 's/\033\[[0-9;]*m//g' | wc -c; }

# ── Line 1: usage stats ───────────────────────────────────────────────────────
L1=""
if [ -n "$sess_pct" ]; then
  s_int=$(printf '%.0f' "$sess_pct")
  L1="${L1}$(printf "$(pct_color $s_int)Session: %s%%${rst}" "$s_int")"
fi
if [ -n "$weekly_pct" ]; then
  w_int=$(printf '%.0f' "$weekly_pct")
  L1="${L1}  $(printf "${cyn}Weekly: %s%%${rst}" "$w_int")"
fi
if [ -n "$cost" ]; then
  L1="${L1}  $(printf "${yel}Cost: \$%.2f${rst}" "$cost")"
fi
if [ -n "$reset_str" ]; then
  L1="${L1}  $(printf "${wht}Reset: %s${rst}" "$reset_str")"
fi

# ── Line 2: model · version · thinking · context bar ─────────────────────────
L2=""
[ -n "$model"   ] && L2="${L2}$(printf "${cyn}%s${rst}" "$model")"
[ -n "$version" ] && L2="${L2}  $(printf "${wht}v%s${rst}" "$version")"
L2="${L2}  $(printf "${wht}Thinking: %s${rst}" "$effort")"
if [ -n "$ctx_bar" ]; then
  L2="${L2}  $(printf "$(pct_color $ctx_int)ctx:${rst} ${wht}%s${rst}" "$ctx_bar")"
fi

# ── Line 3: link · full cwd · branch ─────────────────────────────────────────
L3=""
if [ -n "$repo_link" ]; then
  L3="$(printf "${dim}🔗 ${repo_link}${rst}")"
fi
L3="${L3}  $(printf "${mag}%s${rst}" "$dir")"
if [ -n "$branch" ]; then
  dirty_str=""
  [ -n "$git_dirty" ] && dirty_str=" $(printf '\033[0;31m✗\033[0m')"
  L3="${L3}  $(printf "${grn}%s${rst}" "$branch")${dirty_str}"
fi

# ── Output ────────────────────────────────────────────────────────────────────
echo -e "$L1"
echo -e "$L2"
echo -e "$L3"
