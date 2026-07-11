#!/usr/bin/env bash
input=$(cat)

IFS='|' read -r ctx_str tok_str model_str < <(
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
      (.model.display_name // "") ] | join("|")
  '
)

# glob picks last alphabetically — not guaranteed latest on multi-version, but usually fine
hooks=(~/.claude/plugins/cache/caveman/caveman/*/hooks/caveman-statusline.sh)
caveman=$(bash "${hooks[${#hooks[@]}-1]}" <<< "$input" 2>/dev/null)

parts=""
[ -n "$tok_str" ] && parts="$tok_str "
parts="$parts$ctx_str"
[ -n "$model_str" ] && parts="$parts $model_str"
[ -n "$caveman" ] && parts="$parts | $caveman"

echo "$parts"
