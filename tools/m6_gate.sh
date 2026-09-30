#!/usr/bin/env bash
# M6's closing gate (#118): lists every bug still open in the milestone whose
# title starts "M6:", and fails while any is left. Critical and high bugs must
# be fixed; a medium or low one must be fixed, or carried out of M6 with the
# owner's OK (moving it is what carrying means); a bug with no severity label
# is not known to be minor.
#
# Usage:  tools/m6_gate.sh
# Env:    HS_REPO (default honestarcade/HonestSolitaire)
# Exit:   0  no open bug in M6
#         1  blockers, one "BLOCKER" line each
#         2  no milestone titled "M6: …"
#         3  gh or jq missing, or a gh call failed
set -uo pipefail

REPO="${HS_REPO:-honestarcade/HonestSolitaire}"
command -v gh >/dev/null || { echo "m6-gate: gh is not on PATH" >&2; exit 3; }
command -v jq >/dev/null || { echo "m6-gate: jq is not on PATH" >&2; exit 3; }

milestones="$(gh api --paginate "repos/$REPO/milestones?state=all&per_page=100")" ||
  { echo "m6-gate: could not list milestones" >&2; exit 3; }
# --paginate prints one JSON array per page; jq reads them as a stream.
read -r number title < <(printf '%s\n' "$milestones" |
  jq -r '.[] | select(.title | startswith("M6:")) | "\(.number) \(.title)"' | head -1)
[ -n "${number:-}" ] || { echo "m6-gate: no milestone titled \"M6: …\"" >&2; exit 2; }

issues="$(gh api --paginate "repos/$REPO/issues?milestone=$number&state=open&per_page=100")" ||
  { echo "m6-gate: could not list the issues of milestone $number" >&2; exit 3; }

blockers=0
blocker() { # number what title
  echo "BLOCKER #$1 $2: $3"
  blockers=$((blockers + 1))
}

# One line per open bug (pull requests excluded): number, its labels between
# spaces, then the title.
while IFS=$'\t' read -r n labels t; do
  case "$labels" in
    *" sev:critical "*) blocker "$n" "sev:critical" "$t" ;;
    *" sev:high "*) blocker "$n" "sev:high" "$t" ;;
    *" sev:medium "* | *" sev:low "*)
      sev="$(printf '%s\n' "$labels" | grep -oE 'sev:(medium|low)' | head -1)"
      blocker "$n" "$sev still in M6 (fix it, or carry it with the owner's OK)" "$t"
      ;;
    *) blocker "$n" "no severity label" "$t" ;;
  esac
done < <(printf '%s\n' "$issues" | jq -r '
  .[]
  | select(.pull_request | not)
  | select(.state == "open")
  | select(any(.labels[].name; . == "bug"))
  | [(.number | tostring), " \([.labels[].name] | join(" ")) ", .title]
  | @tsv')

if [ "$blockers" -gt 0 ]; then
  echo "m6-gate: $blockers blocking bug(s) in $title" >&2
  exit 1
fi
echo "m6-gate: no open bug in $title"
