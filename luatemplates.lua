local err, warn, info, log = luatexbase.provides_module({
    name               = "luatemplates",
    version            = '0.1',
    date               = "2019/06/26",
    description        = "Lua module for templating.",
    author             = "Urs Liska",
    copyright          = "2019 - Urs Liska",
    license            = "GPL3",
})

local Templates = {}

function Templates:new(templates, formatters)
  local o = {
    _templates = {}, -- create *copy*
    _formatters = formatters or {} -- create *reference*
  }
  if type(templates) == 'table' then
    for k, v in pairs(templates) do
      o._templates[k] = v
    end
  end
  o._templates['number-case-normal'] = '<<<number>>>'
  o._templates['number-case-smallcaps'] = '\\textsc{\\lowercase{<<<number>>>}}'
  o._templates['number-case-upper'] = '\\uppercase{<<<number>>>}'
  o._templates['number-case-lower'] = '\\lowercase{<<<number>>>}'
  setmetatable(o, self)
  self.__index = self
  return o
end

function Templates:add_element(base, element, separator)
  if base == '' then
    return element
  else
    local sep = separator or template_opts['element-separator']
    warn("Achtung: add_element verschluckt Leerzeichen!")
    return base .. sep .. ' ' .. element
  end
end

function Templates:add_superscript(base, super, parenthesis)
  if not (super and super ~= '') then return base end
  if parenthesis then super = '(' .. super .. ')' end
  return base .. '\\textsuperscript{' .. super .. '}'
end

function Templates:format(key, ...)
  local formatter = self:formatter(key)
  if formatter and type(formatter) == 'function' then
    return formatter(self, ...)
  else
    return self:replace(key, ...)
  end
end

function Templates:formatter(key)
  -- first check for Templates method
  local method = self[key]
  if method and type(method) == 'function' then return method end
  -- recursively look into the _formatters table
  local cur_table = self._formatters
  for _, k in ipairs(key:explode('.')) do
    cur_table = cur_table[k]
    if not cur_table then return end
  end
  return cur_table
end

--[[
TODO: Translate and check (if it still matches the behaviour)
Formatiere einen Zahlbereich (z.B. Seiten), unterstüzt werden dabei:
- Einzelne Zahlen (5)
- Römische Ziffern
  - v
  - VII
  (werden alle in Kapitälchen umgewandelt)
- Formatierte Texte (sobald ein '\' vorkommt, wird der ganze Eintrag übernommen)
  - 8\,\textsuperscript{\textsc{iv}}
    (hier müssen auch die Kapitälchen manuell formatiert werden)
- Bereiche, getrennt durch einfachen Bindestrich
  - 5-6
  - xi-xiv
- Bereiche mit 'ff' als zweitem Teil:
  - 12-ff => wird zu LaTeX-Code 12\,ff.
- Aufzählungen:
  - 5 and 11 and 17-19
  der letzte Eintrag wird mit 'u.' abgetrennt, vorige mit Komma
- Alle Kombinationen:
  - 5 and 7-ff and 6\textsuperscript{b}
--]]
function Templates:list_process(text, formatter)
  if not text or text == ''  then return '' end
  local elements = self:split_list(text, ' and ')
  if formatter then
    for i, elt in ipairs(elements) do
      if type(formatter) == 'function' then
        elements[i] = formatter(self, elt)
      else
        elements[i] = self:format(formatter, elt)
      end
    end
  end
  if #elements == 1 then return elements[1]
  elseif #elements == 2 then
    return elements[1] .. ' ' .. template_opts['list-last-sep'] .. ' ' .. elements[2]
  end
  local result = ''
  local last = table.remove(elements)
  for i, elt in ipairs(elements) do
    -- TODO: The hard-coded spaces are bad. However, it seems
    -- that trailing spaces are removed from the options.
    if i > 1 then result = result .. template_opts['list-sep'] .. ' ' end
    result = result .. elt
  end
  return result .. template_opts['list-last-sep'] .. ' ' .. last
end

function Templates:number(text)
  if tonumber(text) or text:find('\\') then return text
  else
    return self:replace('number-case-' .. template_opts['number-case'], {
      number = text })
  end
end

function Templates:range(text)
  local from, to = self:split_range(text)
  if not to then return self:number(text)
  elseif to == 'f' then
    return self:number(from) .. template_opts['range-follow']
  elseif to == 'ff' then
    return self:number(from) .. template_opts['range-ffollow']
  else
    return self:number(from) .. template_opts['range-sep'] .. self:number(to)
  end
end

function Templates:replace(key, data)
  if type(data) ~= 'table' then err(
    string.format('Trying to replace templates with non-table data %s', data)) end
  local result = self:template(key)
  for k, v in pairs(data) do
    result = result:gsub('<<<'..k..'>>>', v)
  end
  return result
end

function Templates:set_template(key, template)
  self._templates[key] = template
end

-- From: http://lua-users.org/wiki/SplitJoin
function Templates:split_list(str, pat)
  local t = {}
  local cnt = 1
  local fpat = "(.-)" .. pat
  local last_end = 1
  local s, e, cap = str:find(fpat, 1)
  while s do
    if s ~= 1 or cap ~= "" then
       table.insert(t,cap)
       cnt = cnt + 1
    end
    last_end = e+1
    s, e, cap = str:find(fpat, last_end)
  end
  if last_end <= #str then
    cap = str:sub(last_end)
    table.insert(t, cap)
  end
  --[[
  TODO: Investigate a luatex-like solution with str:explode().
  The following does *not* work because the pattern is added to the list.
  --
  local t = {}
  for _, elt in ipairs(str:explode(pat)) do
    if elt ~= pat then table.insert(t, elt) end
  end
  local cnt = #t
  --]]
  return t, cnt
end

function Templates:split_range(text)
--[[

--]]
  local from, to = text:match('(.-)%-(.*)')
  if not to then
    return text, nil
  else
    return from, to
  end
end

function Templates:template(key)
  return self._templates[key] or err(string.format('Template "%s" undefined', key))
end

function Templates:wrap_kv_option(key, value)
  if value and value ~= '' then
    return string.format([[%s={%s}]], key, value)
  else
    return ''
  end
end

function Templates:wrap_macro(macro, value)
--[[
    If value is not empty return it wrapped in a macro, or an empty string.
    'macro' is a macro name without the leading backslash:
    'mymacro', 'myvalue' will return \mymacro{myvalue}
--]]
    if value and value ~= '' then
        return string.format([[\%s{%s}]], macro, value)
    else
        return ''
    end
end

function Templates:wrap_optional_arg(opt, key)
  if type(opt) == 'table' then opt = opt[key] end
  if opt and opt ~= '' then
    return '['..opt..']'
  else
    return ''
  end
end

function Templates:write(key_color, ...)
  local key, color = key_color, template_opts['default-color']
  if type(key_color) == 'table' then
    key = key_color[1]
    color = key_color[2]
  end
  local result = self:format(key, ...)
  if template_opts.color and color ~= 'nocolor' then
    result = '\\textcolor{' .. color .. '}{' .. result .. '}'
  end
  tex.print(result:explode('\n'))
end

return Templates
