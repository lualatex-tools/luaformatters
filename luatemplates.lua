local err, warn, info, log = luatexbase.provides_module({
    name               = "luatemplates",
    version            = '0.5',
    date               = "2019/06/28",
    description        = "Lua module for templating.",
    author             = "Urs Liska",
    copyright          = "2019- Urs Liska",
    license            = "GPL3",
})

local Templates = {}

function Templates:new(templates, formatters)
  local o = {
    _templates = templates or {},
    _formatters = formatters or {},
    _shorthands = {},
    _styles = {},
    _builtin_formatters = {
      add_element = Templates.add_element,
      add_superscript = Templates.add_superscript,
      number = Templates.number,
      range = Templates.range,
      shorthand = Templates.shorthand,
      style = Templates.style,
    }
  }
  o._formatters['number-case'] = {
    normal = function (self, text) return text end,
    smallcaps = function (self, text)
      return string.format([[\textsc{\lowercase{%s}}]], text) end,
    upper = function (self, text)
      return string.format([[\uppercase{%s}]], text) end,
    lower = function (self, text)
      return string.format([[\lowercase{%s}]], text) end,
  }
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

function Templates:_create_argument(number)
    return string.format([["\luatexluaescapestring{\unexpanded{#%s}}"]], number)
end

function Templates:create_commands(var_name, map)
  local opt, arg_num, args, formatter, color
  for k, v in pairs(map) do
    arg_num = 0
    args = ''
    opt = ''
    formatter = ''
    color = ''
    if type(v) == 'string' then
      formatter = string.format([['%s']], v)
      color = 'default'
      arg_num = '[1]'
      opt = ''
      args = self:_create_argument(1) --=[[[\string#1]]]=]
    else
      formatter = string.format([[{ '%s', '%s' }]],
        v.f, v.color or 'default')
      args = {}
      if v.opt then
        arg_num = 1
        opt = string.format('[%s]', v.opt)
        table.insert(args, self:_create_argument(1))
      end
      if v.args then
        for i, _ in ipairs(v.args) do
          arg_num = arg_num + 1
          table.insert(args, string.format(self:_create_argument(arg_num)))
        end
      end
      args = self:list_join(args, ', ')
      if arg_num > 0 then
        arg_num = string.format('[%s]', arg_num)
      else
        arg_num = ''
      end
    end
    local result = string.format([[
\newcommand{\%s}%s%s{\directlua{%s:write(%s, %s)}}]],
      k, arg_num, opt, var_name, formatter, args)
    if k == 'manuskript' then
      print()
      print("Generierter Befehl")
      print(result)
--      err("Ende")
    end
    tex.print(result)
  end
end

local map = {
  bereich = 'tools.bereich',
  dv = 'schubert.dv',
--  gedicht = { f = 'gedicht.gedicht', color = 'nocolor', opt = '' },
--  lied = { f = 'schubert.lied', args = { 'titel', 'dv' }, opt = '' },
--  manuskript = { f = 'abb.manuskript', color = 'nocolor', opt = '' },
  noten = 'musik.noten',
--  notenbeispiel = { f = 'abb.notenbeispiel', color = 'nocolor', opt = '' },
--  nsa = { f = 'schubert.nsa', args = { 'band', 'seiten' }, opt = '' },
  opus = 'musik.opus',
  Opus = 'musik.Opus',
--  quelle = { f = 'schubert.quelle', args = { 'sigel' }, opt = '' },
  seite = 'bereich.seite',
--  takt = { f = 'bereich.takt', args = { 'bereich' }, opt = '' },
--  tonart = { f = 'musik.tonart', args = { 'tonart', 'alternative' } },
}

function Templates:create_shorthands(var_name, templates)
  for k, v in pairs(templates) do
    self._shorthands[k] = v
    tex.print(string.format([[
      \newcommand{\%s}{\directlua{%s:write('shorthand', '%s')}}]],
      k, var_name, k))
  end
end

function Templates:create_styles(var_name, styles)
  for k, v in pairs(styles) do
    self._styles[k] = v
    tex.print(string.format([=[
      \newcommand{\%s}[1]{\directlua{%s:write('style', '%s', [[\string#1]])}}]=],
      k, var_name, k))
  end
end

function Templates:format(key, ...)
  local formatter = self:formatter(key)
  if formatter and type(formatter) == 'function' then
    return formatter(self, ...)
  else
    return self:replace(key, ...)
  end
end

function Templates:find_node(key, root, create)
  local cur_node = root
  local parent_node = root
  local next_node
  for _, k in ipairs(key:explode('.')) do
    next_node = cur_node[k]
    if next_node then
      parent_node = cur_node
      cur_node = next_node
    else
      if create then
        cur_node[k] = {}
        cur_node = cur_node[k]
      else
        return
      end
    end
  end
  return cur_node
end

function Templates:find_parent(key, root)
  local path, k
  path, k = key:match('(.*)%.(.*)')
  if path then
    return self:find_node(path, root, true), k
  else
    return root, key
  end
end

function Templates:formatter(key)
  -- first check for builtin formatting method of the Templates class
  local method = self._builtin_formatters[key]
  if method then return method end
  method = self:find_node(key, self._formatters)
  -- TODO: Search for templates
  return method
end

function Templates:list_join(list, separator)
    -- Is it true that there is no such command in Lua?
    if #list == 0 then return ''
    elseif #list == 1 then return list[1]
    elseif #list == 2 then return list[1]..separator..list[2]
    else
        local result = list[1]
        local index, last = 1, #list
        repeat
          index = index + 1
          result = result .. separator .. list[index]
        until index == last
        return result
    end
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
    return self:format('number-case.' .. template_opts['number-case'], text)
--    return self:replace('number-case-' .. template_opts['number-case'], {
--      number = text })
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

function Templates:_replace(template, data)
  if type(data) ~= 'table' then err(
    string.format('Trying to replace templates with non-table data %s', data)) end
  for k, v in pairs(data) do
    template = template:gsub('<<<'..k..'>>>', v)
  end
  return template
end

function Templates:replace(key, data)
  return self:_replace(self:template(key), data)
end

function Templates:set_template(key, template)
  local parent
  parent, key = self:find_parent(key, self._templates)
  parent[key] = template
end

function Templates:shorthand(key)
  return self._shorthands[key] or err('Shorthand not defined: '..key)
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

function Templates:style(style, text, color)
  local template = self._styles[style] or err('Style not defined: ' .. style)
  return self:_replace(template, { text = text })
end

function Templates:template(key)
  return self:find_node(key, self._templates)
  or err(string.format('Template "%s" undefined', key))
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

function Templates:_write(content, color)
  if template_opts.color and color and color ~= 'nocolor' then
    if color == 'default' then color = template_opts['default-color'] end
    content = '\\textcolor{' .. color .. '}{' .. content .. '}'
  end
  tex.print(content:explode('\n'))
end

function Templates:write(key_color, ...)
  local key, color
  if type(key_color) == 'string' then
    key = key_color
    color = 'default'
  else
    key = key_color[1]
    color = key_color[2]
  end
  self:_write(self:format(key, ...), color)
end

return Templates
