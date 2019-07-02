local err, warn, info, log = luatexbase.provides_module({
    name               = "luatemplates",
    version            = '0.8',
    date               = "2019/07/02",
    description        = "Lua module for templating.",
    author             = "Urs Liska",
    copyright          = "2019- Urs Liska",
    license            = "GPL3",
})

--[[
    Main tables.
    *Templates* is the main table that is also returned.
    Client code will call Templates:setup for an instance
    and may then add formatter functions to that instance.

    *Builtins* contains formatter and helper functions that are not
    automatically exposed as LaTeX macros, but they
    - can be added through the configuration mechanism
    - can be accessed through Templates:format('<name>')
    - can be accessd through Templates:<name> as toplevel methods.
--]]
local Templates = {}
local Builtins = {}

function Templates:setup(var_name, config)
--[[
    Create a new Templates object.
    - `var_name`
      The created object will be stored in the global variable <var_name>.
      It can later be accessed from Lua code through this name, and the
      generated LaTeX macros also refer to it by this name.
      Typical names are composed like `<project_prefix>_templates`.
    A `config` table may include any or all of the following elements:
    - `prefix`
      A prefix string prepended to generated LaTeX macros
      (useful for package creation)
    - formatters in any or all of the `shorthands`, `styles`,
      `templates` and `formatters` subtables.
      These four trees are treated identically, and the separation only serves
      for better structuring of the input files.
      Each entry may be either a template string, a formatter function, or
      a formatter entry table (TODO: Where to refer to for information?)
      All entries whose keys/names do not start with an underscore will be
      automatically exposed as a LaTeX macro.
    - `namespace`
      A hierarchical namespace table can be used to define a namespace.
      formatters may be stored hierarchically to subtables corresponding
      to the `namespace` table.
      A namespace is not necessary when the entries are to be stored in a flat
      structure anyway.
      TODO: Currently misspellings of nodes will cause “formatters” to be
      assigned rather than going to the next namespace level, and the resulting
      error message is misleading.
    Elements missing in the config table (or a missing config table in the
    first place) can in theory be patched in at a later point, but this is
    strongly discouraged and there is no coding support for this.
--]]
    config = config or {}
    local o = {
        _name = var_name,
        _macro_prefix = config.prefix or '',
        _namespace = config.namespace or {},
        _formatters = {},
        _builtin_formatters = {}
    }
    setmetatable(o, self)
    -- Make Builtins members accessible through Templates:<key>
    self.__index = function (_, key) return self[key] or Builtins[key] end

    -- Register all functions from Builtins as formatters
    self.assign_formatters(o, '', {}, o._builtin_formatters, Builtins)
    -- Register all formatters provided by the client
    for _, category in pairs({'shorthands', 'styles', 'templates', 'formatters'}) do
        local root = config[category]
        if root then
            self.assign_formatters(o, '', o._namespace, o._formatters, root)
        end
    end
    -- Allow additional configuration, mainly for (builtin) functions
    self.configure(o, config.configuration)

    -- Create macros and documentation from registered formatters.
    self.create_macros(o, o._macro_prefix, o._namespace, o._formatters)

    -- Register the object as a global variable (used in the generated macros,
    -- but can also be used to acces 'self' later)
    _G[var_name] = o
    return o
end

function Templates:args_from_template(template)
--[[
    Generates an array table with argument names from a template, performing
    validity checks:
    - If the template has *no* fields ('shorthand') 'nil' is returned
    - If the templates has *one* field or 'options' plus another field
      the one or two field name(s) are returned in order of appearance.
    - If more than that number of fields is present an error is raised.
      (NOTE: While it *might* be ok to infer the order of arguments from the
       order of appearance in the template this would break the abstraction:
       Changes in the template might break existing usages of the command.)
--]]
    local fields, has_options = self:template_fields(template)
    local max_args
    if has_options then max_args = 2 else max_args = 1 end
    if #fields == 0 then
        return nil
    elseif #fields <= max_args then
        return fields, has_options
    else
        err(string.format([[
Error configuring template.
Can't automatically determine the order
of arguments in Templates with more than
one (plus 'options') fields:
%s
]], template))
    end
end

function Templates:assign_formatters(key, namespace, target, source)
--[[
    Recursively assign formatters from one category
    to the _formatters table, normalizing it to table syntax
    - namespace
      The current level in the namespace hierarchy.
      Used to determine whether an entry is a key to a sublevel
      or a formatter entry.
      NOTE: Currently there is no proper way to detect misspelled
      sublevel keys.
    - target
      Current level of the target tree (initially self._formatters)
    - source
      Current level of the source tree.
--]]
    local function next_key(k)
        if key == '' then
            return k
        else
            return key..'.'..k
        end
    end

    for k, v in pairs(source) do
        if target[k] and not namespace[k] then
            err(string.format([[
Namespace conflict: Node %s already defined!]], k))
        elseif namespace[k] then
            --[[
                key is found in namespace,
                so go down one level in the hierarchy.
            --]]
            if not target[k] then target[k] = {} end
            self:assign_formatters(next_key(k), namespace[k], target[k], v)
        else
            --[[
                Key is *not* found in namespace, so we assume it's a formatter.
                Validity is the responsibility of the definer.
            --]]
            target[k] = self:validate_formatter(next_key(k), v)
        end
    end
end

function Templates:check_args(entry)
--[[
    Perform validity checks for arguments in a formatter entry,
    depending on whether the formatter is a function or a template.
    Updates the given table and doesn't return a value.
--]]
    local has_options
    if type(entry.f) == 'function' then
        -- ignore any given arguments for functions
        entry.args = {}
        -- retrieve arguments by introspection
        local arg_cnt = debug.getinfo(entry.f).nparams
        local arg
        for i=2, arg_cnt, 1 do -- skip the 'self' argument
            arg = debug.getlocal(entry.f, i)
            if arg == 'options' and not entry.opt then entry.opt = '' end
            table.insert(entry.args, arg)
        end
    else -- template
        if not entry.args then
            -- Check if arguments can be inferred
            entry.args, has_options = self:args_from_template(entry.f)
            if has_options then entry.opt = '' end
        else
            -- Check validity of given arguments
            has_options = self:check_template_args(entry.args, entry.f)
            if has_options then
                if not entry.opt then entry.opt = '' end
            end
        end
    end
end

function Templates:check_template_args(args, template)
--[[
    Perform validity checks for given args against a template.
    - If a field in the template has no corresponding argument,
      issue a warning (while this is most probably erroneous it
      doesn't warrant aborting the compilation)
    - If an argument doesn't have a corresponding field, produce an error.

    TODO: Make sure this code can't be considerably condensed ...
--]]
    local _fields, _args = {}, {}
    local fields = self:template_fields(template)
    for _, v in ipairs(fields) do
        _fields[v] = true
    end
    for _, v in ipairs(args) do
        if not _fields[v] then
            err(string.format([[
Error configuring template.
Argument '%s' does not match any field.
Available Fields:
- %s
]], v, table.concat(fields, '\n- ')))
        end
        _args[v] = true
    end
    for _, v in ipairs(fields) do
        if not _args[v] then
            warn(string.format([[
Problem configuring template.
Field '%s' has no matching argument
and will not be replaced.
Present arguments:
- %s
]], v, table.concat(args, '\n- ')))
        end
    end
    -- return true if there is an 'options' argument
    return _args.options
end

function Templates:configure(map)
--[[
    Apply any provided manual configuration.
--]]
    if not map then return end
    for name, entry in pairs(map) do
        self:configure_entry(name, entry)
    end
end

function Templates:configure_entry(name, properties)
--[[
    Apply manual configuration for a given item.
    This can be used to expose builtin formatters as LaTeX macros,
    or to extend the configuration of registered formatters,
    typically used for formatter functions that have been defined
    with the standalone `function Templates:<name>` syntax.
    - check that a formatter exists at the given key
    - install it in self._formatters
      (for builtin formatters, *move* the entry to the _formatters tree)
    - give it a name
--]]
    if type(properties) == 'string' then
        properties = { key = properties }
    end
    properties.name = name
    local entry = self:find_node(properties.key, self._builtin_formatters)
    if entry then
        -- move a builtin formatter to the formatter hierarchy
        self._formatters[properties.key] = entry
        self._builtin_formatters[properties.key] = nil
    else
        entry = self:find_node(properties.key, self._formatters)
        if not entry then err(string.format([[
Error configuring command entry.
No formatter found at key: %s]], properties.key))
        end
    end
    -- assign all configuration parameters to the formatter entry
    for k, v in pairs(properties) do
        if k ~= 'key' then entry[k] = v end
    end
end

function Templates:create_macro(entry)
--[[
    Create a LaTeX macro from the given entry, assuming it is fully populated.

    TODO: Also (optionally) create a documentation string.
--]]
    -- NOTE: entry is nil if the name starts with an underscore, so it is skipped.
    if not entry then return end

    -- Set up variables
    local arg_num = ''
    if entry.args then arg_num = '['.. #entry.args .. ']' end
    local opt = ''
    if entry.opt then opt = '[' .. entry.opt .. ']' end
    local args = self:_macro_args(entry)
    local argsep = ''
    if args ~= '' then argsep = ', ' end

    -- Set up templates
    local wrapper_template = [[
\newcommand{\<<<name>>>}<<<argnum>>><<<opt>>>{\directlua{<<<lua>>>}}]]
    local lua_template = [[
<<<obj>>>:write({ '<<<formatter>>>', '<<<color>>>' }<<<argsep>>><<<args>>>)]]

    -- Populate templates with actual data
    wrapper_template = wrapper_template:gsub(
    '<<<name>>>', entry.name):gsub(
    '<<<argnum>>>', arg_num):gsub(
    '<<<opt>>>', opt)
    lua_template = lua_template:gsub(
        '<<<obj>>>', self._name):gsub(
        '<<<formatter>>>', entry.key):gsub(
        '<<<template>>>', entry.f):gsub(
        '<<<color>>>', entry.color):gsub(
        '<<<args>>>', args):gsub(
        '<<<argsep>>>', argsep)
    local macro = wrapper_template:gsub('<<<lua>>>', lua_template)
    tex.print(macro)
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
      a true value. Intermediate nodes may be created too.
--]]
    if not root then root = self._formatters end
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
      - ... must be a table mapping field names to values for the
          replacment (which have to match the fields in the template)
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
    NOTE: This returns a formatter and an *entry* containing the formatter.
    While somewhat redundant it is a convenience function for the usual case
    where only the formatter itself is required.
--]]
    local result
    for _, root in ipairs({self._formatters, self._builtin_formatters}) do
        result = self:find_node(key, root)
        if result then return result.f, result end
    end
end

function Templates:create_macros(prefix, namespace, parent)
--[[
    Walk the self._formatters tree and create LaTeX macros for all entries
    whose name doesn't start with an underscore.
--]]
    local function next_prefix(key)
        -- helper function to create the mixedCase default macro names
        if prefix == '' then
            return key
        else
            return prefix..self:capitalize(key)
        end
    end

    for k, v in pairs(parent) do
        if namespace[k] then
            -- Enter next level
            self:create_macros(
            next_prefix(k),
            namespace[k],
            parent[k])
        else
            -- Create macro after clean-up/completion of entry
            -- NOTE: process_entry returns nil if the name starts with
            -- an underscore.
            self:create_macro(self:process_entry(next_prefix(k), parent[k]))
        end
    end
end

function Templates:_macro_args(entry)
--[[
    Generate a string used to write arguments to the LaTeX macro.
    Handling depends on whether the formatter is a function or a template.
--]]
    local function indexof(array, value)
        for i, v in ipairs(array) do
            if v == value then return i end
        end
    end

    local is_func = type(entry.f) == 'function'
    local in_args, args = entry.args, {}
    -- Skip if there are no arguments
    if in_args then
        -- Move an 'options' arg to the beginning (as the LaTeX #1 argument)
        if entry.opt then
            local opt_index = indexof(in_args, 'options')
            if opt_index then
                table.remove(in_args, opt_index)
                table.insert(in_args, 1, 'options')
            end
        end
        -- Generate arguments and populate a list `args`
        for i, arg in ipairs(in_args) do
            if is_func then
                table.insert(args, self:_numbered_argument(i))
            else
                table.insert(args, string.format([[
    %s = %s]], arg, self:_numbered_argument(i)))
            end
        end
    end
    -- Massage the output depending on the target
    args = table.concat(args, ',')
    if not is_func then args = '{' .. args .. '}' end
    return args
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

function Templates:process_entry(name, entry)
--[[
    Update and complete a given formatter entry.
    - Assign 'name' if no name is explicitly in the given entry.
    - Set default color if no color is given in the entry.
    - Skip the rest if name starts with an underscore.
      (“Internal” formatters are accessible to the format() function
       but not to LaTeX. The same is true for builtin formatters that
       haven't been explicitly published through configuration.)
    - validate/generate arguments:
      - formatter functions get them from introspection
      - templates are checked for validity.
--]]
    entry.name = entry.name or name
    entry.color = entry.color or 'default'
    if entry.name:sub(1, 1) == '_' then return end
    entry.comment = entry.comment or ''
    self:check_args(entry)
    return entry
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

function Templates:split_list(str, pat)
--[[
    Split a string into a list at the given pattern.
    Built upon: http://lua-users.org/wiki/SplitJoin
--]]
--[[
    TODO: Investigate a luatex-like solution with str:explode().
    The following does *not* work because the pattern is included in the list.
    local t = {}
    for _, elt in ipairs(str:explode(pat)) do
        if elt ~= pat then table.insert(t, elt) end
    end
    local cnt = #t
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

function Templates:template_fields(template)
--[[
    Return an array table with all template fields in the given template.
    Order of appearance is preserved, duplicates are suppressed.
    If an 'options' field is present, a second value 'true' is returned
--]]
    local result = {}
    local _result = {}
    for element in template:gmatch('<<<(%w+)>>>') do
        if not _result[element] then
            _result[element] = true
            table.insert(result, element)
        end
    end
    return result, _result.options
end

function Templates:validate_formatter(key, entry)
--[[
    (Sort-of) validate an assumed formatter entry.
    If it is a simple (template) string or a function wrap it in a table.
    Otherwise check if it has an 'f' key.
--]]
    if type(entry) == 'string' or type(entry) == 'function' then
        entry = { f = entry }
    elseif not type(entry) == 'table' then
        err(string.format([[
Error assigning formatter. Table expected but
'%s: %s' provided.
]], type(entry), entry))
    end
    entry.key = key
    if not entry.f then
        local t = {}
        for k, v in pairs(entry) do
            table.insert(t, string.format('%s:\n%s', k, v))
        end
        err(string.format([[
Error assigning formatter.
Table passed but no proper formatter (f) included:
%s
]], table.concat(t, '\n')))
    end
    return entry
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



--[[
    The *Builtins* table holds helper functions and formatters dealing with
    styling and marking up strings, they help in a modular way of programming
    templates and stylesheets.
    All functions in this table can be implicitly invoked through
    Templates:format() or Templates:write(), but they are by default *not*
    exposed as LaTeX commands. However, this is possible by adding entries in
    the config.configuration subtable for Templates:setup.
    Templates also “inherits” from Builtins, so all elements of the Builtins
    table can be accessed directly through Templates:<name>. Since the Builtins
    table is not returned by this module this is the way external Lua code will
    have to access these functions.
--]]


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

function Builtins:capitalize(word)
--[[
    Capitalize the first letter in the given word/string.
--]]
    if word == '' then return '' end
    if #word == 1 then return word:upper() end
    return word:sub(1, 1):upper() .. word:sub(2)
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

function Builtins:emph(text)
--[[
    Emphasize the given text
    NOTE: This may not be exposed as a LaTeX macro directly, but it may be useful
    to use from within formatter functions.
--]]
    return self:wrap_macro('emph', text)
end

function Builtins:italic(text)
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
      (see Builtins:range) or 'number' (see Buitlins:number).
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
    return self:list_join({
        separator = options.separator or template_opts['list-sep'],
        last_sep = options.last_sep or template_opts['list-last-sep'],
    }, elements)
end

function Builtins:list_join(options, list)
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

function Builtins:shorthand(key)
--[[
    Return the string stored as shorthand for the given key.
    TODO: Check if it can be removed or moved to Builtins
--]]
    return self:formatter(key) or err('Shorthand not defined: '..key)
end

function Builtins:style(style, text)
--[[
    Apply a style to the given text.
    - style
      must refer to a stored style.
    TODO: Check if this can be removed or moved to Builtins
--]]
    local template = self:formatter(style) or err('Style not defined: ' .. style)
    return self:_replace(template, { text = text })
end

function Builtins:wrap_kv_option(key, value)
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

function Builtins:wrap_macro(macro, value)
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

function Builtins:wrap_optional_arg(opt)
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


return Templates
