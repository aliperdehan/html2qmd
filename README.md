# html2qmd

Rebuild a `.qmd` from a **rendered, self-contained Quarto HTML page**: for when you have the
HTML but lost the source. A bash script plus a pandoc Lua filter.

Checked on two pages: re-rendering the rebuilt `.qmd` gave an article whose text (prose, code,
tables, test output) matched the original HTML line for line.

## Usage

```bash
html2qmd.sh page.html [out.qmd]
html2qmd.sh --yaml header.yml page.html [out.qmd]
```

Needs `pandoc` (bundled with Quarto). It won't overwrite an existing `.qmd`, and it writes
static images to `<name>_images/` next to the output.

Then: fix up the header (see below), put the data files next to the `.qmd`, and `quarto render`.

**Move the original HTML out of the way first** (e.g. into `orig/`): rendering `X.qmd` writes
`X.html` and would overwrite it.

`--yaml FILE` puts the contents of `FILE` after the `title:` line instead of the minimal default
(`format: html: self-contained` and `toc: true` if the page had a TOC). For example:

```yaml
format:
  html:
    self-contained: true
    toc: true
    toc-depth: 4
editor: visual
editor_options:
  chunk_output_type: console
```

## Why it's possible

The Quarto HTML still contains everything visible on the page:

- text is inside `<main id="quarto-document-content">`
- every chunk is a `<div class="cell">` holding the **source code** (`div.sourceCode`) and its
  **output** (`div.cell-output*`)
- math is kept as LaTeX: `<span class="math display">\[...\]</span>`
- with `self-contained: true`, images are embedded as base64 `data:` URIs

## What the script does

1. Cuts out `<main>` and drops the title block and copy-to-clipboard buttons (the rest of the
   file, often ~1.5 MB, is Bootstrap/JS/CSS).
2. Runs pandoc HTML → markdown with `html2qmd.lua`, which:
   - turns each `div.cell` code block into a `{r}` (or `{python}`) chunk,
   - **drops rendered outputs**, since tables and plots come back on re-render,
   - turns math spans back into `$$...$$` / `$...$` (without this, pandoc escapes them to junk
     like `[\\\[...\\\]]{.math .display}`),
   - disables pandoc's `::: {}` divs / `{.class}` attributes so the markdown stays plain.
3. Extracts static images (ones pasted into the doc, not plot output) into `<name>_images/`.
4. Writes a YAML header (title from `<title>`).
5. Prints the data files the chunks read (`read_csv("x.csv")`, `readRDS(...)`, ...), if any.

## Data files

The HTML never contains the data files, only the code that reads them and its output. The script
prints `needs data files: ...` for the ones it finds in the visible chunks. Chunks hidden with
`echo: false` / `include: false` leave no code behind, so a hidden `read.csv("x.csv")` is not
listed; if the output mentions a dataset you can't account for, that's where it was loaded.
To get the files back:

- Look for the source's public repository (course or book materials often have one).
- Built-in and package datasets (`mtcars`, `carData::Mroz`, ...) need nothing.
- A small table can sometimes be rebuilt by hand from printed output (`head()`, `glimpse()`,
  `print(df)`), but only if the HTML shows all the rows.

## What can't be recovered

- **Chunk options** (`#| label`, `fig-cap`, `echo`, `warning`...): not recorded in the HTML.
- **Hidden code** (`echo: false`): only its output is in the HTML. The script leaves a
  `TODO` chunk where this happened; you have to rewrite that code.
- **Original YAML**: only guessable.
- **Inline R** (`` `r mean(x)` ``): shows only as its computed value in the text.
- **Chunk boundaries**: consecutive chunks in one cell come out back-to-back; split if needed.
- **Line breaks inside display equations** get collapsed to one line (renders the same).

## Gotchas

- Missing R packages stop the render at the first `library()` chunk; install them.
- pandoc's `--extract-media` rewrites image paths *after* the Lua filter runs, so image paths
  are fixed with `sed` afterwards, not in the filter.
- Checking the result: extract `<main>` from both HTMLs, run `pandoc -t plain` on each, and
  `diff`. `test.sh` does exactly this on a small example.

## Test

```bash
./test.sh
```

Renders `example/demo.qmd`, converts the HTML back, re-renders, and diffs the article text.
Needs `quarto` and `Rscript`.

## License

MIT, see `LICENSE`.
