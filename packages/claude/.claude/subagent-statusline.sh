#!/usr/bin/env bash
jq -c '
  def short_model: sub("^claude-"; "") | sub("-[0-9]{8}$"; "");
  .tasks[]
  | { id,
      content: ([ (.agentType // .name // "agent"),
                  (.model // "…" | short_model),
                  (.effort // empty | tostring),
                  (.description // empty) ] | join(" · ")) }
'
