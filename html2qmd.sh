#!/usr/bin/env bash
# Convert a rendered, self-contained Quarto HTML page back into a .qmd.
# Usage: html2qmd.sh [--yaml FILE] page.html [out.qmd]
# Writes out.qmd plus <name>_images/ (static images embedded in the page) next to it.
#   --yaml FILE   use FILE's contents as the YAML header (after the title line)
#                 instead of the minimal default (html: self-contained, toc).
set -euo pipefail

usage="usage: $0 [--yaml FILE] page.html [out.qmd]"
yaml=""
if [ "${1:-}" = "--yaml" ]; then
  [ $# -ge 3 ] || { echo "$usage" >&2; exit 1; }
  yaml="$2"; shift 2
fi
[ $# -ge 1 ] || { echo "$usage" >&2; exit 1; }

command -v pandoc >/dev/null || { echo "pandoc not found" >&2; exit 1; }

in="$1"
out="${2:-${in%.html}.qmd}"
name="$(basename "${out%.qmd}")"
outdir="$(cd "$(dirname "$out")" && pwd)"
here="$(cd "$(dirname "$0")" && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

[ -e "$out" ] && { echo "refusing to overwrite $out" >&2; exit 1; }

title="$(sed -n 's:.*<title>\(.*\)</title>.*:\1:p' "$in" | head -1)"
title="${title//\"/\\\"}"

# Only the article body: <main> minus the title block and copy buttons.
a=$(grep -n '<main' "$in" | head -1 | cut -d: -f1 || true)
b=$(grep -n '</main>' "$in" | tail -1 | cut -d: -f1 || true)
[ -n "$a" ] && [ -n "$b" ] || { echo "$in: no <main> element, not a Quarto HTML page" >&2; exit 1; }
sed -n "${a},${b}p" "$in" \
  | sed '/<header id="title-block-header"/,/<\/header>/d; s/<button[^>]*code-copy-button[^>]*>.*<\/button>//' \
  > "$tmp/main.html"

(cd "$tmp" && pandoc main.html -f html \
  -t markdown-raw_html-native_divs-native_spans-fenced_divs-header_attributes-link_attributes \
  --wrap=none --lua-filter="$here/html2qmd.lua" --extract-media=media -o body.md)

# Static (non-chunk) images: move out of media/ with readable names.
if [ -d "$tmp/media" ]; then
  mkdir -p "$outdir/${name}_images"
  i=0
  for f in "$tmp"/media/*; do
    i=$((i + 1)); ext="${f##*.}"; new="${name}_images/image-$i.$ext"
    cp "$f" "$outdir/$new"
    sed "s#media/$(basename "$f")#$new#g" "$tmp/body.md" > "$tmp/body.new" && mv "$tmp/body.new" "$tmp/body.md"
  done
fi

{
  printf -- '---\ntitle: "%s"\n' "$title"
  if [ -n "$yaml" ]; then
    cat "$yaml"
  else
    printf 'format:\n  html:\n    self-contained: true\n'
    grep -q 'id="TOC"' "$in" && printf '    toc: true\n'
  fi
  printf -- '---\n\n'
  cat "$tmp/body.md"
} > "$out"

echo "wrote $out"
grep -q 'TODO: code for this output was hidden' "$out" && echo "note: some chunks had hidden code, search for TODO" || true

# Data files the chunks read: they are not in the HTML and must be supplied.
files="$(awk '/^```\{/{f=1; next} /^```/{f=0} f' "$out" \
  | grep -oE "(^|[^A-Za-z0-9_.])(read_csv2?|read\.csv2?|read_tsv|read_delim|read\.delim|read\.table|read_table|read_excel|read_sav|read_dta|read_parquet|readRDS|load|fread)\( *[\"'][^\"']+[\"']" \
  | sed -E "s/^[^\"']*[\"']//; s/[\"']\$//" | sort -u || true)"
[ -z "$files" ] || echo "needs data files: $(echo "$files" | tr '\n' ' ')"
