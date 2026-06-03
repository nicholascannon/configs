#!/usr/bin/env bash
input=$(cat)

ctx=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
model=$(echo "$input" | jq -r '.model.display_name // empty')
caveman=$(bash "/Users/nicholas/.claude/plugins/cache/caveman/caveman/84cc3c14fa1e/hooks/caveman-statusline.sh" <<< "$input" 2>/dev/null)

ctx_str=$([ -n "$ctx" ] && printf "[%.0f%%]" "$ctx" || echo "[--]")
model_str=$([ -n "$model" ] && echo "$model" || echo "")

parts="$ctx_str"
[ -n "$model_str" ] && parts=" $parts $model_str"
[ -n "$caveman" ] && parts=" $parts | $caveman"

echo "$parts"
