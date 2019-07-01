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
local Builtins = {}

function Templates:setup(var_name, config)
--[[
    Create a new Templates object.
    If a `config` table is provided, included templates,
    formatters, shorthands and styles are installed in the object.
    Specifically, the existing of the following subtables triggers
    specific actions:
    - templates
      installs the included hierarchy of templates.
      These will be available through the `format()` and `write()` methods.
    - formatters
      Like templates, but handles formatting functions.
    - shorthands
      Installs the given shorthands as formatters
      *and creates corresponding LaTeX commands*. The key of each shorthand
      will be used as the command name.
    - styles
      Same as with shorthands. (Styles are formatting functions that expect
      exactly one argument which is used to replace a '<<<text>>>'
      template).
    - mappings
      Creates complex LaTeX commands accessing available formatters and templates.
    For details about the three last items refer to the Templates:create_NN
    methods.
    If any of these subtables is not provided it can be added later as well.
    If no templates or formatters are provided, still several of the built-in
    formatters can be used from the Templates object.
--]]
    config = config or {}
    local o = {
        _name = var_name,
        _macro_prefix = config.prefix or '',
        _namespace = config.namespace or {},
        _builtin_formatters = {
            -- The following formatters are special functions
            -- handling the auto-generated shorthands and styles
            -- TODO: Probably these are obsolete when the generic command
            -- creation is implemented.
            shorthand = Templates.shorthand,
            style = Templates.style,
        }
    }
    setmetatable(o, self)
    self.__index = function (_, key) return self[key] or Builtins[key] end
    for _, category in pairs({'shorthands', 'styles', 'templates', 'formatters'}) do
        local root = config[category]
        if root then
            self.assign_formatters(o, o._namespace, root)
        end
    end
    if config.shorthands then
        self.create_shorthands(o, config.shorthands)
    end
    if config.styles then
        self.create_styles(o, config.styles)
    end
    if config.mapping then
        self.create_commands(o, config.mapping)
    end
    _G[var_name] = o
    return o
end

function Templates:assign_formatters(target, source)
--[[
    Recursively assign formatters from one category
    to the namespace.
--]]
    for k, v in pairs(source) do
        if target[k] then
            --[[
                key is found in namespace,
                so go down one level in the hierarchy.
                NOTE: This will fail if k does not refer to a namespace node
                but to a formatter already defined in an earlier category.
                TODO: Is there a way to check this condition to prevent
                really obscure errors?
            --]]
            self:assign_formatters(target[k], v)
        else
            --[[
                Key is *not* found in namespace, so we assume it's a formatter.
                This must be a valid formatter function or template.
            --]]
            target[k] = v
        end
    end
end

function Templates:create_command(name, properties)
--[[
    Create a single LaTeX command using this object's templates and formatters.
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
          If `color = 'nocolor'` is given than this command will *never* be
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
    tex.print(string.format([[
    \newcommand{\%s}%s%s{\directlua{%s:write(%s, %s)}}]],
    name, arg_num, opt, self._name, formatter, args))
end

function Templates:create_commands(map)
--[[
    Create a number of LaTeX commands based on a mapping table.
    - map
      is a flat table whose keys are the names of the created commands
      and whose values are the properties of the corresponding command
      (see Templates:create_command() for details).
--]]
  for name, properties in pairs(map) do
      self:create_command(name, properties)
  end
end

function Templates:create_shorthand(key, template)
--[[
    Create a “shorthand” LaTeX command.
    - `key`
      will be the name of the command
    - `template`
      the replacement text or an array with template and color, where the
      special color 'nocolor' will prevent the coloring even when it is
      globally switched on.
--]]
    local color = 'default'
    if type (template) == 'table' then
        color = template[2]
        template = template[1]
    end
    self:find_parent(key, self._namespace)[key] = template
    tex.print(string.format([[
\newcommand{\%s}{\directlua{%s:write({ 'shorthand', '%s' }, '%s')}}]],
      key, self._name, color, key))
end

function Templates:create_shorthands(templates)
--[[
    Create multiple “shorthand” LaTeX commands.
    - templates
      table with templates (see Templates:create_shorthand)
--]]
    for key, result in pairs(templates) do
        self:create_shorthand(key, result)
    end
end

function Templates:create_style(key, template)
--[[
    Create a “style” LaTeX command.
    Styles are regular character styles but can be anything where a single
    argument is replaced with some text.
    - `key`
      will be the name of the command
    - `template`
      the template where the command's single argument will be replaced with.
      NOTE: The template *must* include the key `<<<text>>>`
      This is either a string, or an array with two strings. In this the first
      string is the template and the second a color. The special color 'nocolo'
      prevents the style to be colored even when coloring is switched on.
--]]
    local color = 'default'
    if type(template) == 'table' then
        color = template[2]
        template = template[1]
    end
    if not template:find('<<<text>>>') then
        err(string.format([[
Trying to create style "%s"
but template does not include "<<<text>>>":
%s]], key, template))
    end
    self:find_parent(key, self._namespace)[key] = template
    tex.print(string.format([=[
        \newcommand{\%s}[1]{\directlua{%s:write({ 'style', '%s' }, '%s', %s)}}]=],
        key, self._name, color, key, self:_numbered_argument(1)))
end

function Templates:create_styles(styles)
    --[[
        Create multiple “style” LaTeX commands.
        - templates
          table with templates (see Templates:create_style)
    --]]
    for key, template in pairs(styles) do
        self:create_style(key, template)
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
    Format and return the given data using a formatter addressed by `key`.
    Produces an error if no formatter can be found for the key.
    NOTE:
    - if `key` points to a *function* :
      - ... is passed on to it as its argument(s)
      - a `self` argument is passed to the function and points to the
        current `Templates` object.
      - the function is expected to return a string.
    - if `key` points to a *template*:
      - ... must be one out of:
        - a table mapping field names to values for the replacment
          (which have to match the fields in the template)
        - a string, which will be replaced with the first field found
          in the template.
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
        Builtins,
        self._builtin_formatters, -- TODO: Remove when obsolete
        self._namespace,
    } do
        result = self:find_node(key, root)
        if result then return result end
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

function Templates:_replace(template, data)
--[[
    Replace the fields in the given template with data from the given table.
    Fields are defined by a keyword enclosed by three pairs of angled brackets.
    The keywords must not contain hyphens and should be limited to alphabetic characters.
--]]

--[[
    TODO:
    accept string as argument and replace it with the first field found in the
    template.
--]]
    if type(data) ~= 'table' then
        err(string.format([[
Trying to replace template with non-table data.
    Template:
%s
    Data:
%s]], template, data))
    end
    for k, v in pairs(data) do
        template = template:gsub('<<<'..k..'>>>', v)
    end
    return template
end

function Templates:replace(key, data)
--[[
    Replace fields from a template.
    - key
      Name/path of a template
    - data
      Table with replacement data (keys are template fields, values the data)
--]]
    return self:_replace(self:template(key), data)
end

function Templates:shorthand(key)
--[[
    Return the string stored as shorthand for the given key.
    TODO: Check if it can be removed or moved to Builtins
--]]
    return self:formatter(key) or err('Shorthand not defined: '..key)
end


function Templates:split_list(str, pat)
--[[
    Split a string into a list at the given pattern.
    Built upon: http://lua-users.org/wiki/SplitJoin
--]]
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
    return t, cnt
--[[
    TODO: Investigate a luatex-like solution with str:explode().
    The following does *not* work because the pattern is included in the list.
    local t = {}
    for _, elt in ipairs(str:explode(pat)) do
        if elt ~= pat then table.insert(t, elt) end
    end
    local cnt = #t
--]]
end

function Templates:split_range(text)
--[[
    Split a string into two fields at the first hyphen, returning 'from' and 'to'.
    Any further hyphens (even in '--') are given to the 'to' field:
    '3--4' will yield '3' and '-4'
    If there is no hyphen 'from' will hold the whole string while 'to' is nil.
--]]
    local from, to = text:match('(.-)%-(.*)')
    if not to then
        return text, nil
    else
        return from, to
    end
end

function Templates:style(style, text)
--[[
    Apply a style to the given text.
    - style
      must refer to a stored style.
    TODO: Check if this can be removed or moved to Builtins
--]]
    local template = self:formatter(style) or err('Style not defined: ' .. style)
    return self:_replace(template, { text = text })
end

function Templates:template(key)
--[[
    Retrieve a template for the given key.
    Raise an error if no template is defined or if a function is found instead.
--]]
    local result = self:formatter(key) or err(string.format('Template "%s" undefined', key))
    if type(result) == 'string' then
        return result
    else
        err(string.format([[
Template for "%s"
is not a template but a function.]], key))
    end
end

function Templates:wrap_kv_option(key, value)
--[[
    Process a key/value pair to be used as a key/value option.
    If a value is provided return 'key={value}' to protect the value from
    possible commas misleading a parser. If no value is provided return the key
    alone.
    In order to provide this as a complete optional argument use
    Templates:wrap_optional_arg on the result.
--]]
    if value and value ~= '' then
        return string.format([[%s={%s}]], key, value)
    else
        return key
    end
end

function Templates:wrap_macro(macro, value)
--[[
    Wrap one or multiple values in a macro invocation.
    - macro (string)
      The name of the macro
    - value (string or table)
      One or multiple values. An empty string or nil causes one single argument
      (or delimiter) to be created:
      'mymacro', '' => \mymacro{}
      Multiple values are mapped to multiple arguments:
      'mymacro', { 'one', 'two', 'three' } => \mymacro{one}{two}{three}
--]]
    local result = string.format([[\%s]], macro)
    if not value then
        value = { '' }
    elseif type(value) == 'string' then
        value = { value }
    end
    for _, v in ipairs(value) do
        result = result .. string.format('{%s}', v)
    end
    return result
end

function Templates:wrap_optional_arg(opt)
--[[
    Wrap an optional argument in square brackets if it is provided,
    otherwise return an empty string.
--]]
    if opt and opt ~= '' then
        return '['..opt..']'
    else
        return ''
    end
end

function Templates:_write(content, color)
--[[
    Write some content to the TeX document and optionally color it.
    Use a color when all of the following conditions are met:
    * the 'color' package option is set
    * A color package has been loaded TODO: Not implemented yet
    * The given color is not 'nocolor'
--]]
    if template_opts.color and color ~= 'nocolor' then
        if color == 'default' then color = template_opts['default-color'] end
        content = self:wrap_macro('textcolor', { color, content })
    end
    tex.print(content:explode('\n'))
end

function Templates:write(key_color, ...)
--[[
    Process some data using a formatter and write it to the TeX document.
    - key_color (string or table)
      Either a string key pointing to a formatter (template/function)
      or a table with such a key and a color.
      If a simple key is given color defaults to 'default' (using the package option).
    - ...
      All remaining arguments are passed on to the formatter.
      NOTE: If the formatter is a template string, there must be exactly one
      further argument with a table specifying the key/value replacements.
--]]
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



function Builtins:_add_ssscript(direction, base, element, parenthesis)
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

function Builtins:add_subscript(base, super, parenthesis)
--[[
    Add a subscript the the given base string.
--]]
    return self:_add_ssscript('sub', base, super, parenthesis)
end

function Builtins:add_superscript(base, super, parenthesis)
--[[
    Add a superscript the the given base string.
--]]
    return self:_add_ssscript('super', base, super, parenthesis)
end

function Builtins:add_element(base, element, separator)
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

function Builtins:bold(text)
--[[
    Make text bold
--]]
    return self:wrap_macro('textbf', text)
end

function Builtins:case(case, text)
--[[
    Format text according to a given case strategy.
    TODO: Maybe add camelcasing or other more advanced features?
--]]
    local templates = {
        normal = '%s',
        allsmallcaps = [[\textsc{\lowercase{%s}}]],
        smallcaps = [[\textsc{%s}]],
        upper = [[\uppercase{%s}]],
        lower = [[\lowercase{%s}]]
    }
    return string.format(templates[case], text)
end

function Templates:italic(text)
--[[
    Make the given text italic
--]]
    return self:wrap_macro('textit', text)
end

function Builtins:list_format(text, options)
--[[
    Format a list specified from a BibTeX-style list field.
    `text` is parsed as a list from a single text.
    By default input is parsed using the separator ' and ',
    the output separators are specified with the 'list-sep' and
    the 'list-last-sep' package options.
    If an option table is given it may contain the following options:
    - input_separator
      Change the parsing behaviour (in case 'and' is valid part of an input element)
    - separator
      separator to be used for all but the last element pairs
    - last_sep
      separator to be used for the last element pair
    TODO: incorporate biblatex's list compressing behaviour
    - formatter
      If a formatter is given as an option every list element is passed to
      that (similar to the `map` construct in some programming languages).
      formatter may be either a key (as passed to Templates:formatter()) or an
      actual function. The returned formatter must accept exactly one argument,
      so the registered 'styles' may be good formatters. Some of the built-in
      formatters are also suitable, maybe the most-used formatter is 'range'
      (see Templates:range) or 'number' (see Templates:number).
--]]
    if not text or text == ''  then return '' end
    options = options or {}

    local elements = self:split_list(text, options.input_separator or ' and ')
    local formatter = options.formatter
    if formatter then
        for i, elt in ipairs(elements) do
            if type(formatter) == 'function' then
                elements[i] = formatter(self, elt)
            else
                elements[i] = self:format(formatter, elt)
            end
        end
    end
    return self:list_join(elements, {
        separator = options.separator or template_opts['list-sep'],
        last_sep = options.last_sep or template_opts['list-last-sep'],
    })
end

function Builtins:list_join(list, options)
--[[
    Join a list of strings with ', '.
    If the list is empty an empty string is returned.
    If the list consists of one element this is returned as-is.
    With `options` the behaviour can be changed:
    - options.separator
      specifies a different separator for all but the last join
    - options.last_sep
      specifies the separator between the last two elements.
     the given separator, last_sep or ', '. If it is *not* given the default
     is the regular separator.
    TODO: integrate/emulate biblatex's handling of compressing long lists.
    NOTE: table.concat mostly does the same but doesn't provide the option
    for a different last separator. Considering that list compression is also
    planned it seems OK to do it manually.
--]]
    local options = options or {}
    local sep = options.separator or ', '
    local last_sep = options.last_sep or sep
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

function Builtins:number(text, options)
--[[
    Format numbers (WIP), including handling case for roman numerals.
    If `text` is either a simple number or contains a '\' (in which
    case it is considered a custom-formatted text) it is returned as-is,
    otherwise the case (only useful for roman numerals, e.g. in paginations)
    will be processed according to the 'number-case' package option or the
    'number-case' option in the passed `options`.
--]]
    options = options or {}
    if tonumber(text) or text:find('\\') then return text end
    return self:format('case',
        options['number-case'] or template_opts['number-case'],
        text)
end

function Builtins:range(text, options)
--[[
    Parse and format a range (useful e.g. for pagination commands).
    A range is first considered as a string with one hyphen in it. This is split in
    two at the *first* hyphen, any subsequent hyphens (also when the range is written as
    3--4) will be part of the second part.
    The two parts are consider as 'from' and 'to'.
    If there is no hyphen the text is considered as a single element/number, without a 'to'.
    Each element may be one out of:
    - numbers
      => anything that Lua's `tonumber` function accepts as a number
    - roman numerals
      depending on the package option 'number-case' these are left as they are or processed
      to a consistent case.
      NOTE: This affects *any* text, which may or may not be desirable/acceptable
    - LaTeX-formatted text. If any '\' is found the part is left untouched.
    - 'f' or 'ff' ('to' part only)
      If the 'to' part is 'f' or 'ff' it is replaced with the value of the
      'range-follow' or 'fange-ffollow' option, by default 'f.' and 'ff.', while
      the range separator is suppressed
    The range separator is controlled by the 'range-sep' package option,
    which by default is '--'.
    The package options can also be overridden by the optional `options` table.
    --]]
    options = options or {}
    local from, to = self:split_range(text)
    if not to then return self:number(text)
    elseif to == 'f' then
        local range_follow = options['range-follow'] or template_opts['range-follow']
        return self:number(from) .. range_follow
    elseif to == 'ff' then
        local range_ffollow = options['range-ffollow'] or template_opts['range-ffollow']
        return self:number(from) .. range_ffollow
    else
        local range_sep = options['range-sep'] or template_opts['range-sep']
        return self:number(from) .. range_sep .. self:number(to)
    end
end

function Builtins:range_list(text)
--[[
    Format a list using 'range' as the formatter.
    This is to make the range list (e.g. for page ranges) easily accessible
    as a built-in formatter.
--]]
    return self:list_format(text, { formatter = 'range' })
end



return Templates
