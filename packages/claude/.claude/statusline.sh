#!/usr/bin/env bash
input=$(cat)

cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // "."')
branch=$(git -C "$cwd" branch --show-current 2>/dev/null)
dir_name=$(basename "$cwd")
usage=$(echo "$input" | jq -r '
  [ (.rate_limits.five_hour.used_percentage // empty | "5h \(. + 0.5 | floor)%"),
    (.rate_limits.seven_day.used_percentage // empty | "7d \(. + 0.5 | floor)%") ]
  | join(" · ")')

IFS='|' read -r ctx_str tok_str model_str effort_str < <(
  echo "$input" | jq -r '
    def fmtk:
      if . >= 1000000 then
        (. / 1000000) as $m
        | if ($m | floor) == $m then "\($m | floor)M"
          else "\(($m * 10 | floor) / 10)M" end
      elif . >= 1000 then
        (. / 1000) as $k
        | if ($k | floor) == $k then "\($k | floor)k"
          else "\(($k * 10 | floor) / 10)k" end
      else "\(. | floor)" end;
    def pct: if . == null then "[--]" else "[\(. + 0.5 | floor)%]" end;
    def toks:
      (.context_window.total_input_tokens // null) as $u
      | (.context_window.context_window_size // null) as $t
      | if $u == null or $t == null then "" else "\($u | fmtk)/\($t | fmtk)" end;
    [ (.context_window.used_percentage // null | pct),
      toks,
      (.model.display_name // ""),
      (.effort.level // "") ] | join("|")
  '
)

left=""
[ -n "$tok_str" ] && left="$tok_str "
left="$left$ctx_str"
[ -n "$model_str" ] && left="$left $model_str"
[ -n "$effort_str" ] && left="$left ($effort_str)"
left="$left   $dir_name"
[ -n "$branch" ] && left="$left   $branch"

# COLUMNS is set by Claude Code; tput cannot see the terminal from here.
# Nerd Font glyphs may render double-width, hence the slack of 4.
pad=$(( ${COLUMNS:-0} - ${#left} - ${#usage} - 4 ))
if [ -n "$usage" ] && [ "$pad" -gt 1 ]; then
  printf '%s%*s%s\n' "$left" "$pad" "" "$usage"
else
  echo "$left${usage:+  $usage}"
fi
