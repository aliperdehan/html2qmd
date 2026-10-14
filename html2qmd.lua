-- Pandoc Lua filter: turn a rendered Quarto HTML page back into .qmd markdown.
-- Used by html2qmd.sh; see HOWTO.md.

local function has(el, pat)
  for _, c in ipairs(el.classes) do
    if c:match(pat) then return true end
  end
  return false
end

-- Quarto wraps each chunk in <div class="cell">: keep the source as {r}/{python}
-- chunks and drop the rendered output (it comes back on re-render).
function Div(el)
  if has(el, "^cell%-output") then return {} end
  if has(el, "^cell$") then
    local out, codes = {}, 0
    el:walk({ CodeBlock = function(cb)
      codes = codes + 1
      local lang = "r"
      for _, c in ipairs(cb.classes) do
        if c ~= "sourceCode" and not c:match("^code") then lang = c break end
      end
      table.insert(out, pandoc.RawBlock("markdown",
        "```{" .. lang .. "}\n" .. cb.text .. "\n```\n"))
    end })
    if codes == 0 then
      -- output with no visible source: the chunk had echo: false
      table.insert(out, pandoc.RawBlock("markdown",
        "```{r}\n#| echo: false\n# TODO: code for this output was hidden (echo: false) and is not in the HTML\n```"))
    end
    return out
  end
end

-- Quarto emits math as <span class="math display">\[...\]</span>; restore $$...$$ / $...$
function Span(el)
  if has(el, "^math$") then
    local t = pandoc.utils.stringify(el)
    if has(el, "^display$") then
      return pandoc.Math("DisplayMath", (t:gsub("^%s*\\%[", ""):gsub("\\%]%s*$", "")))
    end
    return pandoc.Math("InlineMath", (t:gsub("^%s*\\%(", ""):gsub("\\%)%s*$", "")))
  end
end
