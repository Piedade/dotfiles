#!/bin/bash
# Cycle layout (split -> tabbed -> stacking), but first walk up past any
# single-child wrapper containers so the toggle actually groups the focused
# window with its real siblings, instead of just wrapping itself alone.
#
# `layout toggle` always affects the PARENT of whatever is focused. So to
# make it affect an ancestor N levels up, we issue N `focus parent` first,
# then toggle, then N `focus child` to land back where we started - which
# keeps repeated presses stable instead of climbing further each time.
#
# If nothing in the whole workspace has real siblings (the window is really
# alone), we deliberately do NOT escalate to the workspace level: toggling
# there makes sway insert extra wrapper nodes instead of mutating in place,
# so we just fall back to the plain, un-escalated toggle.

hops=$(swaymsg -t get_tree | jq '
  def walk(path):
    if .focused == true then path
    else
      (path + [{type: .type, n: (((.nodes // []) | length) + ((.floating_nodes // []) | length))}]) as $p
      | (.nodes[]?, .floating_nodes[]?) | walk($p)
    end;
  (walk([]) | map(select(.type == "workspace" or .type == "con")) | reverse) as $ancestors
  | ($ancestors | map(.n >= 2) | index(true)) as $idx
  | if $idx == null then 0 else $idx end
')

[ -z "$hops" ] && hops=0

cmd="layout toggle split tabbed stacking"

if [ "$hops" -gt 0 ]; then
    up=$(printf 'focus parent, %.0s' $(seq 1 "$hops"))
    down=$(printf ', focus child%.0s' $(seq 1 "$hops"))
    swaymsg "${up}${cmd}${down}"
else
    swaymsg "$cmd"
fi
