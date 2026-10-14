#!/usr/bin/env bash
# Round trip: render example/demo.qmd -> html2qmd -> render again -> diff article text.
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
work="$(mktemp -d)"
trap 'rm -r "$work"' EXIT

text() {  # article text of a rendered page
  local f="$1" a b
  a=$(grep -n '<main' "$f" | head -1 | cut -d: -f1)
  b=$(grep -n '</main>' "$f" | tail -1 | cut -d: -f1)
  sed -n "${a},${b}p" "$f" | pandoc -f html -t plain --wrap=none | sed 's/ *$//'
}

mkdir "$work/orig" "$work/new"
cp "$here/example/demo.qmd" "$here/example/demo.csv" "$work/orig/"
cp "$here/example/demo.csv" "$work/new/"

(cd "$work/orig" && quarto render demo.qmd >/dev/null 2>&1)
"$here/html2qmd.sh" "$work/orig/demo.html" "$work/new/demo.qmd"
(cd "$work/new" && quarto render demo.qmd >/dev/null 2>&1)

text "$work/orig/demo.html" > "$work/orig.txt"
text "$work/new/demo.html" > "$work/new.txt"
if diff "$work/orig.txt" "$work/new.txt"; then
  echo "PASS"
else
  echo "FAIL (differences above)" >&2; exit 1
fi
