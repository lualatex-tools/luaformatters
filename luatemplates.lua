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

function Templates:new(formatters)
--[[
    Create a new Templates object.
    If a `formatters` table is provided, included templates,
    formatters, shorthands and styles are installed in the object.
    However, if they are provided later through the `create_NN`
    commands LaTeX macros can be written automatically (see manual).
    [TODO: Provide a command to simply insert templates]
    If no templates or formatters are provided, still a number of
    built-in formatters can be used from the Templates object.
--]]
    formatters = formatters or {}
    local o = {
        _templates = formatters.templates or {},
        _formatters = formatters.formatters or {},
        _shorthands = formatters.shorthands or {},
        _styles = formatters.styles or {},
        _builtin_formatters = {
            -- These formatters are generic formatting functions
            -- that should be usable directly from outside.
            -- Just keep in mind that they expect a first `self`
            -- argument that should point to the Templates table.
            add_element = Templates.add_element,
            add_subscript = Templates.add_subscript,
            add_superscript = Templates.add_superscript,
            number = Templates.number,
            range = Templates.range,
            -- The following formatters are special functions
            -- handling the auto-generated shorthands and styles
            shorthand = Templates.shorthand,
            style = Templates.style,
        }
    }
    o._formatters['number-case'] = {
        normal = function (self, text)
            return text
        end,
        smallcaps = function (self, text)
            return string.format([[\textsc{\lowercase{%s}}]], text)
        end,
        upper = function (self, text)
            return string.format([[\uppercase{%s}]], text)
        end,
        lower = function (self, text)
            return string.format([[\lowercase{%s}]], text)
        end,
    }
    setmetatable(o, self)
    self.__index = self
    return o
end

function Templates:add_element(base, element, separator)
--[[
    Built-in formatter:
    Add an element to a base string, using either the separator
    specified by the package options or a given one.
--]]
    if base == '' then
        return element
    else
        local sep = separator or template_opts['element-separator']
        if not separator then
            warn([[
Bug:
Add_element swallows spaces
from option-provided separator!]])
        end
        return base .. sep .. element
    end
end

function Templates:_add_ssscript(direction, base, element, parenthesis)
--[[
    Add a super- or subscript to the given base string.
    If `element` is not given or an empty string, no action is taken.
    If `parenthesis` is a true value the super/subscript is wrapped in
    parentheses.
--]]
    if not (element and element ~= '') then return base end
    if parenthesis then element = '(' .. element .. ')' end
    return base .. self:wrap_macro('text'..direction..'script', element)
end

function Templates:add_subscript(base, super, parenthesis)
--[[
    Add a subscript the the given base string.
--]]
    return self:_add_ssscript('sub', base, super, parenthesis)
end

function Templates:add_superscript(base, super, parenthesis)
--[[
    Add a superscript the the given base string.
--]]
    return self:_add_ssscript('super', base, super, parenthesis)
end

function Templates:create_command(var_name, name, properties)
--[[
    Create a single LaTeX command using this object's templates and formatters.
    - var_name
      The name of a global variable by which this Templates object can be
      referenced inside \directlua{}
    - name
      The name of the resulting command
    - properties
      The properties of the resulting command, either a string or a table.
      - If it is a string it is considered the key to a formatting method,
        and a command with *one* argument - which is passed to the formatter -
        is created. NOTE: This may *not* be a *template* since simple templating
        commands with one argument are handled through the *styles* mechanism.
      - If it is a table then it may include mandatory and optional keys:
        - f (string)[mandatory]
          The formatter function (identical to the single string above)
        - color (string)
          If a color is specified this will be used instead of the `default-color`
          package option (if the `color` option is true, that is).
          I `color = 'nocolor'` is given than this command will *never* be
          wrapped in a \textcolor command - which may be necessary for more
          complex commands or environments where this wrap might break things.
        - opt (string)
          If `opt` is given the command will get an optional argument.
          The content of this field will be supplied as the default value, so
          `opt = ''` will result in `[]` while
          `opt = 'foo=bar'` will give `[foo=bar]`
        - args (array table)
          If `args` is given it should be an array with argument names.
          This array is only used to determine the number of arguments
          that are passed on to the formatter function while their *names*
          are ignored. However, it is recommended to use the actual argument
          names used in the formatter, for documentation purposes.
        - keys (array table) [TODO: This is not implemented yet]
          If `keys` is given `args` and `opt` will be ignored and a
          template replacement command is created instead - so in this case the
          `f` argument must point to a template rather than a formatter.
          The keys refer to the keys used in the template, and the command
          creates as many arguments as there are keys. So from
              `name = 'mycommand' f = 'my.template' keys = {'foo', 'bar'}`
          the command will look like
              `\mycommand[2]{...}`
          while an invocation
              `\mycommand{hey}{there}`
          will result in the call
              `Templates:write('my.template', { foo = 'hey', bar = 'there' })`
--]]
    local formatter, color, arg_num, opt, args = '', '', 0, '', ''
    local key = properties.f or properties
    if type(properties) == 'string' then
        formatter = string.format([['%s']], properties)
        color = 'default'
        opt = ''
        arg_num = '[1]'
        args = self:_numbered_argument(1)
    else
        formatter = string.format([[
            {'%s','%s'}]], properties.f, properties.color or 'default')
        args = {}
        if properties.opt then
            arg_num = 1
            opt = string.format('[%s]', properties.opt)
            table.insert(args, self:_numbered_argument(1))
        end
        if properties.args then
            for _ in ipairs(properties.args) do
                arg_num = arg_num + 1
                table.insert(args, string.format(self:_numbered_argument(arg_num)))
            end
        end
        args = self:list_join(args)
        if arg_num > 0 then
            arg_num = string.format('[%s]', arg_num)
        else
            arg_num = ''
        end
    end
    if not self:formatter(key) then
        err(string.format([[
Trying to create the LaTeX command "\%s"
but no formatter/template found at key
"%s"]], name, key))
    end
    local result = string.format([[
    \newcommand{\%s}%s%s{\directlua{%s:write(%s, %s)}}]],
    name, arg_num, opt, var_name, formatter, args)
    if k == 'manuskript' then
        print()
        print("Generierter Befehl")
        print(result)
        --      err("Ende")
    end
    tex.print(result) -- TODO: avoid `result` variable after debugging is done
end

function Templates:create_commands(var_name, map)
--[[
    Create a number of LaTeX commands based on a mapping table.
    - var_name
      The name of a global variable by which this Templates object can be
      referenced inside \directlua{}
    - map
      is a flat table whose keys are the names of the created commands
      and whose values are the properties of the corresponding command
      (see Templates:create_command() for details).
--]]
  for name, properties in pairs(map) do
      self:create_command(var_name, name, properties)
  end
end

function Templates:create_shorthand(var_name, key, result)
--[[
    Create a “shorthand” LaTeX command.
    - var_name
      The name of a global variable by which this Templates object can be
      referenced inside \directlua{}
    - `key`
      will be the name of the command
    - `result`
      the replacement text:
      `Templates:create_shorthand('my_templates', 'abbr', 'my abbreviation')`
      will produce the equivalent to
      `\newcommand{\abbr}{my abbreviation}`
--]]
    self._shorthands[key] = result
    tex.print(string.format([[
\newcommand{\%s}{\directlua{%s:write('shorthand', '%s')}}]],
      key, var_name, key))
end

function Templates:create_shorthands(var_name, templates)
--[[
    Create multiple “shorthand” LaTeX commands.
    - var_name
      The name of a global variable by which this Templates object can be
      referenced inside \directlua{}
    - templates
      table with templates (see Templates:create_shorthand)
--]]
    for key, result in pairs(templates) do
        self:create_shorthand(var_name, key, result)
    end
end

function Templates:create_style(var_name, key, template)
    --[[
        Create a “style” LaTeX command.
        Styles are regular character styles but can be anything where a single
        argument is replaced with some text.
        - var_name
          The name of a global variable by which this Templates object can be
          referenced inside \directlua{}
        - `key`
          will be the name of the command
        - `template`
          the template where the command's single argument will be replaced with.
          NOTE: The template *must* include the key `<<<text>>>`
    --]]
    if not template:find('<<<text>>>') then
        err(string.format([[
Trying to create style "%s"
but template does not include "<<<text>>>":
%s]], key, template))
    end
    self._styles[key] = template
    tex.print(string.format([=[
      \newcommand{\%s}[1]{\directlua{%s:write('style', '%s', %s)}}]=],
      key, var_name, key, self:_numbered_argument(1)))
end

function Templates:create_styles(var_name, styles)
    --[[
        Create multiple “style” LaTeX commands.
        - var_name
          The name of a global variable by which this Templates object can be
          referenced inside \directlua{}
        - templates
          table with templates (see Templates:create_style)
    --]]
    for key, template in pairs(styles) do
        self:create_style(var_name, key, template)
    end
end

function Templates:find_node(key, root, create)
--[[
    Find a node in a tree (table)
    - key (string)
      Name of the node in dot-list-notation.
      If an empty string is provided return the original root.
    - root (table)
      Starting point for the search (usually a toplevel table in Templates)
    - create (boolean)
      If the given node is not found in the table it is either created
      (as an empty table) or nil is returned, depending on `create` being
      a true value.
--]]
    if key == '' then return root end
    local cur_node, next_node = root
    for _, k in ipairs(key:explode('.')) do
        next_node = cur_node[k]
        if next_node then
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

function Templates:find_parent(key, root, create)
--[[
    Find a parent and key name.
    - key (string)
      Name of the node in dot-list-notation.
      If an empty string is provided return the original root.
    - root (table)
      Starting point for the search (usually a toplevel table in Templates)
    - create (boolean)
      If the given node is not found in the table it is either created
      (as an empty table) or nil is returned, depending on `create` being
      a true value.
--]]
    if key == '' then return root, nil end
    local path, k = key:match('(.*)%.(.*)')
    if path then
        return self:find_node(path, root, create), k
    else
        if root[key] then
            return root, key
        elseif create then
            root[key] = {}
            return root, key
        else
            return root, nil
        end
    end
end

function Templates:format(key, ...)
--[[
    Format and return the given data
    using either template replacement or a formatting function.
    NOTE: if `key` points to a *template* ... must be exactly
    one table holding the replacement pairs.
--]]
    local formatter = self:formatter(key)
    if not formatter then
        err(string.format([[
        Trying to format values
        %s
        but no template/formatter found at key
        %s]], ..., key))
    end
    if type(formatter) == 'function' then
        return formatter(self, ...)
    else
        return self:replace(key, ...)
    end
end

function Templates:formatter(key)
--[[
    Find a formatter matching the given key.
    Look for both templates and formatter methods.
--]]
    local result
    for _, root in ipairs{
        self._builtin_formatters,
        self._formatters,
        self._shorthands,
        self._styles,
        self._templates
    } do
        result = self:find_node(key, root)
        if result then return result end
    end
end

function Templates:list_join(list, separator, last_sep)
--[[
    Join a list of strings with the given separator, last_sep or ', '.
    Having a different last_sep makes sense in “human-language” itemizations
    and is modeled after biblatex's handling.
    TODO: integrate biblatex's handling of compressing long lists.
    NOTE: Is it really true that there is no such command in Lua?
--]]
    sep = separator or ', '
    last_sep = last_sep or ', '
    if #list == 0 then return ''
    elseif #list == 1 then return list[1]
    elseif #list == 2 then return list[1]..last_sep..list[2]
    else
        local result = list[1]
        local index, last = 1, #list
        repeat
            index = index + 1
            result = result..sep..list[index]
        until index == last - 1
        return result..last_sep..list[last]
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

function Templates:_numbered_argument(number)
--[[
    Generate a numbered argument for use in a generated LaTeX command.
    NOTE: From all the ways to protect the `#1` arguments in the
    \directlua{} invocations this seems to be the only one working in all
    cases so far. I don't know if there's an “official” way to do this, though.
--]]
    return string.format([["\luatexluaescapestring{\unexpanded{#%s}}"]], number)
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
  parent, key = self:find_parent(key, self._templates, true)
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
    If value is not empty return it wrapped in a macro, else an empty string.
    'macro' is a macro name without the leading backslash:
    'mymacro', 'myvalue' will return \mymacro{myvalue}
    TODO: Support a value *list*, creating multiple arguments, including an
    optional one.
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
