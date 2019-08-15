local err, warn, info, log = luatexbase.provides_module({
    name               = "luaformatters.formatter",
    version            = '0.8',
    date               = "2019/07/02",
    description        = "luaformatters, Formatter handling.",
    author             = "Urs Liska",
    copyright          = "2019- Urs Liska",
    license            = "GPL3",
})

--[[
    Formatter class.
    This class is a wrapper and abstraction around a formatter
    template or function.  When a formatter entry table is registered
    with lua_formatters it is replaced with a new Formatter instance.

    The data is stored in local fields and exposed through getter/setter
    functions that should be used from outside.
--]]

-- Table to be returned
local Formatter = {}

--[[
    Index function
    When called regularly, `self` inside a formatter refers to the
    instance of the `Formatter` class.
    However, fields of `self` are looked up from a number of places,
    in the following order:
    - the concrete instance
    - the Formatter prototype (the code in this file)
    - the “parent”, which is a lua_formatters “client”
    - lua_formatters (the Formatters table)
--]]
Formatter.__index = function (t, key)
    return Formatter[key]
    or t:parent()[key]
    or lua_formatters[key]
end

local formatters_opts = lua_options.client('formatters')

function Formatter:new(parent, key, formatter)
--[[
    Create and return a new Formatter instance, providing defaults for
    those fields that are ready to have them at this point.
    A *new* table is created while the original formatter is not changed.
--]]
    if type(formatter) == 'string' then
        formatter = { template = formatter }
    elseif type(formatter) == 'function' then
        formatter = { func = formatter }
    end
    local o = {
        -- flag to discern from primitive Formatter Entry Table
        _is_Formatter = true,
        -- holds the actual macro arguments
        _macro_args = {},
        -- key for accessing the formatter
        _key = key,
        -- lua_formatters “client”
        _parent = parent,
        -- "option clients" for option validation
        _option_clients = {},
    }
    setmetatable(o, Formatter)
    -- initialize macro name, may be overridden if 'name' property is given
    o._name = Formatter._make_name(o, key)
    -- assign options declaration if given
    if formatter.options then
        o._options = lua_options.Opts:new(formatter.options)
        for k, _ in pairs(formatter.options) do
            o._option_clients[k] = o._options
        end
        formatter.options = nil
    end
    o._create = formatter.create or 'new*'
    formatter = o._validate_client_options(o, formatter)
    -- copy all properties that are given explicitly
    Formatter.update(o, formatter)
    return o
end

function Formatter:apply(...)
--[[
    Apply the formatter (called from the LaTeX macro).
    If the formatter is a template call apply_template().
    If it is a function check if it contains an optional argument,
    process it with self:check_options and call the internal formatter.
    This means that within a formatter the `options` argument is already
    parsed and (optionally) validated.
--]]
    if self._func then
        local args = { ... }
        -- ensure args have been processed (even in hidden formatter)
        self:args()
        local opt_index = self:has_options()
        if opt_index then
            local options = table.remove(args, opt_index)
            options = self:check_options(options)
            table.insert(args, opt_index, options)
        end
        return self:_func(unpack(args))
    else
        return self:apply_template(...)
    end
end

function Formatter:_apply_template(template, ...)
--[[
    Use the template to format the given values.

    The argument(s) may be one out of:
    - a string
      Find a single replacement field in the template
      and replace it with the argument
    - an association table
      The table will be used to match fields with data
      TODO: Consider validating this too (match fields, like it is
      done during macro creation)
    - an array plus additional arguments
      The array contains field names, whose number must match
      the number of remaining varargs.
--]]
    -- first set up the replacement table
    local args = { ... }
    if #args == 0 then return template end
    local data
    local first = table.remove(args, 1)

    if type(first) == 'string' then
        local fields = self:_fields_from_template(template)
        if #fields == 0 then
            warn([[
Replace template containing no fields
with a single string. Returning the template,
ignoring the replacement value.
Template:
%s
Replacement:
%s
]], template, first)
            return template
        elseif #fields > 1 then
            warn([[
Replace template containing multiple fields
with a single string. Using the first field,
leaving the following field(s) unreplaced:
Template:
%s
Replacement:
%s
]], template, first)
        end
        data = { [fields[1]] = first }
    elseif #first == 0 then
        -- Obviously the (first) argument is a replacement table
        data = first
    else
        -- first argument is expected to an array with field names
        -- TODO: validate the argument number
        data = {}
        for i, v in ipairs(first) do
            data[v] = args[i]
        end
    end

    return self:_replace(template, data)
end

function Formatter:apply_template(...)
--[[
    Apply the template that is stored in the Formatter object.
--]]
    return self:_apply_template(self:template(), ...)
end

function Formatter:args()
--[[
    Cache and return a (potentially empty) array with macro argument names.
    Construct that array upon first request, depending on the type of the
    internal formatter and the presence of given arguments.
    Handling arguments for string templates may fail if the user input
    is faulty with regard to matching fields to arguments.
--]]
    if #self._macro_args == 0 then
        if self:is_func() then
            self:_set_args_from_function()
        elseif self._args then
            self:_check_explicit_template_args()
        else
            self:_set_args_from_template()
        end
    end
    if self:has_options() and not self._opt then self._opt = '' end
    return self._macro_args
end

function Formatter:check_options(options, ignore_declarations)
--[[
    Make sure that an options argument is a processed table (even if empty).
    Should be used by any formatter function having an optional argument.

    If the formatter has an options declaration it is guaranteed that the
    returned table has all the options, with default or given values.
--]]
    local result = {}
    if self._options then
        -- preset with values from declarations
        for k,v in pairs(self._options.options) do
            result[k] = v
        end
    end
    if self._client_options then
        -- load options from client, retrieve currently set values.
        for client, opts in pairs(self._client_options) do
            for _, opt in ipairs(opts) do
                result[opt] = lua_options.get_option(client, opt)
            end
        end
    end
    if not options then return result
    elseif type(options) == 'table' then
        --[[
            If the options argument is already a table we can assume it
            already has been validated, either through an earlier call of
            this function or manually in Lua code (TODO: is that true?),
            so we only overwrite the defaults with the given values.
        --]]
        for k, v in pairs(options) do
            result[k] = v
        end
    else
        -- finally we have a 'plain' option string
        -- first parse the string to a table, without validation
        local loc_opts = formatters_opts:check_local_options(options, true)
        -- iterate over options to validate them as formatter or client option
        for k, v in pairs(loc_opts) do
            client = self._option_clients[k]
            if client then
                -- validate with the available option client
                k, v = client:sanitize_option(k, v)
                client:validate_option(k, loc_opts)
                result[k] = v
            elseif self._options then
                -- if options are defined we have to validate,
                -- otherwise unknown options would be ignored.
                err(string.format([[
Unknown option
`%s`
for Formatter
`%s`.
]], k, self:name()))
            end
        end

        -- handle boolean values, converting from strings to booleans
        -- NOTE: empty string represents `true`
        -- TODO: Should this be handled/fixed in lyluatex-options?
        for k, v in pairs(result) do
            if v == '' or v == 'true' then result[k] = true
            elseif v == 'false' then result[k] = false end
        end
        -- store the original string in case someone needs it
        table.insert(result, options)
    end
    return result
end

function Formatter:color()
--[[
    Cache and return the formatter's 'color' property.
    NOTE: 'nocolor' prevents the coloring for this formatter altogether.
--]]
    if not self._color then
        self._color = 'default'
    end
    return self._color
end

function Formatter:comment()
--[[
    Cache and return the formatter's 'comment' property.
    Used for docstrings.
--]]
    if not self._comment then
        self._comment = ''
    end
    return self._comment
end

function Formatter:docstring(options)
--[[
    Populate and return the macro docstring (the LaTeX code needed to use)
    this formatter.
    - nocomment
      If this option is missing a comment (if available) is prepended
    - args
      If this array is given its values are used as sample data for the
      macro, otherwise the stored names are displayed.
--]]

    if not self._docstring then
        local msg = string.format([[
Docstring requested for macro %s
but package option 'self-documentation' seems not to be active
        ]], self:name())
        warn(msg)
        return(msg)
    end

    local result = ''

    -- Prepend a line comment if present and not disabled
    if (not options.nocomment and formatters_opts['doc-comment'])
    and self:comment() ~= '' then
        result = string.format([[
%% %s
]], self:comment())
    end

    -- load docstring template
    result = result..self._docstring

    if self._doc_args then
        -- Populate docstring with argument names or values
        local docargs = {}
        local value = ''
        if options.args ~= 'default' then
            --[[
                If an args option is given (as a comma-separated list,
                NOTE: spaces around the commas are preserved.)
                the actual values are inserted.
                If not enough args are given the remaining values
                are retrieved from the argument names.
            --]]
            docargs = options.args:explode(',')
            if #docargs < #self._doc_args then
                for i = #docargs + 1, #self._doc_args, 1 do
                    table.insert(docargs, '<'..self._doc_args[i]..'>')
                end
            end
        else
            -- else use the argument names.
            docargs = self._doc_args
        end

        -- interpolate values in argument fields.
        for _, v in ipairs(docargs) do
            result = result:gsub('<<<arg>>>', v, 1)
        end
    end

    return result
end

function Formatter:_fields_from_template(template)
--[[
    Return an array table with all template fields in the given template.
    Order of appearance is preserved, duplicates are suppressed.
    If an 'options' field is present, it is stored in the first position.
--]]
    local result, _result = {}, {}
    if template:find('options') then
        table.insert(result, 'options')
        _result.options = true
    end
    for element in template:gmatch('<<<(%w+)>>>') do
        if not _result[element] then
            _result[element] = true
            table.insert(result, element)
        end
    end
    return result
end

function Formatter:fields()
--[[
    The fields in the current Formatter.
    Will be retrieved upon first use. Stores the index of an `options`
    field to indicate that the Formatter *has* options.
--]]
    if not self._fields then
        self._fields = {}
        if self._template then
            self._fields = self:_fields_from_template(self:template())
            if self._fields[1] == 'options' then
                self._opt_index = 1
            end
        end
    end
    return self._fields
end

function Formatter:_format(key, ...)
--[[
    Locate a formatter local to the parent and apply it
--]]
    local formatter = self:parent()._local_formatters[key] or
        err(string.format([[
Formatter %s
not found in client
%s
        ]], self:parent():name(), key))
    return formatter:apply(...)
end

function Formatter:has_options()
--[[
    Return the argument index of the optional argument (if present) or nil.
--]]
    -- ensure the arguments are parsed.
    self:fields()
    return self._opt_index
end

function Formatter:is_formatter(obj)
--[[
    Return true if the given object is a Formatter instance.
    NOTE: A table originally has to have the field `f` while
    after being processed in Formatter:new() this becomes `_f`.
--]]
    return
    type(obj) == 'string'
    or type(obj) == 'function'
    or (type(obj) == 'table'
        and (obj._func or obj.func or obj._template or obj.template))
end

function Formatter:is_func()
--[[
    Return true if the formatter is function-based, false if template-based.
--]]
    return self._func ~= nil
end

function Formatter:is_hidden()
--[[
    A formatter is considered “hidden” if its name or any segment of its key
    starts with an underscore.
    A hidden formatter may still be used through Formatters:format(),
    but no LaTeX macro is generated.
--]]
    if self._name:sub(1, 1) == '_' then return true end
end

function Formatter:key()
--[[
    Return the formatter's key (no caching required, this is always present)
--]]
    return self._key
end

function Formatter:macro()
--[[
    Cache and return a LaTeX macro for the formatter,
    unless the formatter is hidden.
--]]
    if self:is_hidden() then return end
    if not self._macro then
        self:_create_macro()
    end
    return self._macro
end

function Formatter:name()
--[[
    Return the formatter's name (caching not required)
--]]
    return self._name
end

function Formatter:parent()
--[[
    Return a formatter's parent object.
    The “parent” is the templates table that has originally been passed
    to Formatters:new as 'client'.
--]]
    return self._parent
end

function Formatter:_replace(template, replacements)
--[[
    Replace all fields passed by the `replacements` table
    in the string `template`
--]]
    for k, v in pairs(replacements) do
        template = template:gsub('<<<'..k..'>>>', v)
    end
    return template
end

function Formatter:replace(template, ...)
--[[
    Apply the templating logic to a *given* template.
    Basically the same as apply_template, but with a user-provided argument.
--]]
    return self:_apply_template(template, ...)
end

function Formatter:set_parent(parent)
    self._parent = parent
end

function Formatter:template()
--[[
    Return the string template if present, or nil
--]]
    return self._template
end

function Formatter:update(properties)
    -- assign all configuration parameters to the formatter entry
    for k, v in pairs(properties) do
        self['_'..k] = v
    end
end


--[[
    Private functions for internal use only
--]]

function Formatter:_check_explicit_template_args()
--[[
    Perform validity checks for explicitly given args against
    the formatter template.
    - If a field in the template has no corresponding argument,
      issue a warning (while this is most probably erroneous it
      doesn't warrant aborting the compilation)
    - If an argument doesn't have a corresponding field, produce an error.

    TODO: Make sure this code can't be considerably condensed ...
    https://github.com/uliska/luaformatters/issues/31
--]]
    local fields = self:fields()
    local _fields, _args = {}, {}
    self._macro_args = {}
    for _, v in pairs(self._args) do table.insert(self._macro_args, v) end

    -- Create lookup table with template field names
    for _, v in ipairs(fields) do
        _fields[v] = true
    end
    -- Check if all given args have a matching field.
    for _, v in ipairs(self._args) do
        if not _fields[v] then
            err(string.format([[
Error configuring template.
Argument '%s' does not match any field.
Available Fields:
- %s
]], v, table.concat(fields, '\n- ')))
        end
        -- Populate lookup table
        _args[v] = true
    end

    -- Check if all template fields have a matching arg. Handle `options` field.
    for _, v in ipairs(fields) do
        if v == 'options' then
            _args.options = true
            table.insert(self._macro_args, 1, 'options')
        elseif not _args[v] then
            warn(string.format([[
Problem configuring template.
Field '%s' has no matching argument
and will not be replaced.
Present arguments:
- %s
]], v, table.concat(self._args, '\n- ')))
        end
    end
end

function Formatter:_create_macro()
--[[
    Create a LaTeX macro from the given entry.
    All generated LaTeX macro work by calling Formatters:write() in a
    \directlua macro, passing their arguments to a specific formatter,
    either as a vararg to a function or as a replacement table to a
    template-based formatter.
    (only creates the macro, doesn't return it)
--]]

    -- string representation of macro acguments
    local args = self:_format_args()
    if args ~= '' then args = ', ' .. args end

    -- set up way the macro is created in LaTeX
    local create, star = self._create:match('(.+)(*)')
    if not create then
        create = self._create
        star = ''
    end

    -- Set up templates, nested for better readability
    local wrapper_template = [[
\<<<create>>>command<<<star>>>{\<<<name>>>}<<<argnums>>>{\directlua{<<<lua>>>}}]]
    local lua_template = [[
lua_formatters:write({ '<<<formatter>>>', '<<<color>>>' }<<<args>>>)]]

    -- Populate templates with actual data
    wrapper_template = wrapper_template:gsub(
    '<<<create>>>', create):gsub(
    '<<<star>>>', star):gsub(
    '<<<name>>>', self:name()):gsub(
    '<<<argnums>>>', self:_format_arg_nums())

    lua_template = lua_template:gsub(
        '<<<formatter>>>', self._key):gsub(
        '<<<color>>>', self:color()):gsub(
        '<<<args>>>', args)
    self._macro = wrapper_template:gsub('<<<lua>>>', lua_template)

    -- Create docstring for the macro
    if formatters_opts['self-documentation'] then
        local doc_template = [[
\<<<name>>><<<opt>>><<<args>>>]]
        local argstring = ''
        local opt = ''
        local macro_args = self:args()
        if #macro_args > 0 then
            local doc_args = {}
            if self:has_options() then
                if self._opt == '' then
                    table.insert(doc_args, 'options')
                else
                    table.insert(doc_args, self._opt)
                end
                opt = '[<<<arg>>>]'
            end
            for _, v in ipairs(macro_args) do
                if v ~= 'options' then
                    table.insert(doc_args, v)
                    argstring = argstring..'{<<<arg>>>}'
                end
            end
            self._doc_args = doc_args
        end
        self._docstring = doc_template:gsub(
            '<<<name>>>', self:name()):gsub(
            '<<<opt>>>', opt):gsub(
            '<<<args>>>', argstring)
    end
end

function Formatter:_format_arg_nums()
--[[
    Return a string used for specifying macro argument numbers
--]]
    local args = self:args()
    -- format 'number of arguments'
    local result, arg_cnt = '', 0
    if #args > 0 then
        result = '['.. #args .. ']'
    else
        return ''
    end
    -- format optional argument
    if self:has_options() then
        result = result .. '[' .. self._opt .. ']'
    end
    return result
end

function Formatter:_format_args()
--[[
    Return a string used as the argument specification in a created
    macro. Arguments are the last elements in the \directlua call
    to lua_formatters:write().
--]]
    local args = ''
    -- Skip if there are no arguments
    local macro_args = self:args()
    if #macro_args > 0 then
        if self:is_func() then
            args = self:_macro_function_argstring()
        else
            args = self:_macro_template_argstring()
        end
    end
    return args
end

function Formatter:_macro_function_argstring()
--[[
    Return the string representing the formatter arguments in the \directlua call.
    If the function has an `options` argument this has to be mapped to the
    macro's first (optional) argument.
--]]
--[[
    The `arg_indexes` table specifies the order in which LaTeX arguments
    are passed on to the Lua function.
    Needed for shifting an `options` argument to the head
--]]
    local arg_indexes, args = {}, {}
    local macro_args = self:args()
    for i=1, #macro_args, 1 do table.insert(arg_indexes, i) end
    -- Move an 'options' arg to the beginning (as the LaTeX #1 argument)
    local opt_index = self:has_options()
    if opt_index then
        table.remove(arg_indexes, 1)
        table.insert(arg_indexes, opt_index, 1)
    end

    -- Generate arguments and populate a list `args`
    for _, index in ipairs(arg_indexes) do
        table.insert(args, self:_numbered_argument(index))
    end
    return table.concat(args, ',')
end

function Formatter:_macro_template_argstring()
--[[
    Handle template args. This is simpler because argument order
    has been specified manually, and `options` argument has already
    been moved to head in
--]]
    local args = {}
    for i, arg in ipairs(self:args()) do
        table.insert(args, string.format([[
%s = %s]], arg, self:_numbered_argument(i)))
    end
    return '{' .. table.concat(args, ',') .. '}'
end

function Formatter:_make_name(key)
--[[
    Generate a macro name from the given key.
    Works by converting the dot-notation to mixed case.
    If a prefix is specified in the parent this is prepended.
    Underscores (except leading ones) are converted to mixedCase as well.
--]]
    key = key or self._key
    local nodes = key:explode('.')
    local result = self:parent():prefix()
    for _, node in ipairs(nodes) do
        if node:sub(1,1) == '_' then return '_' end
        if result == '' then result = result .. node
        else result = result .. node:sub(1,1):upper() .. node:sub(2)
        end
    end

    -- Convert underscores to mixedCase too.
    local is_hidden = ''
    if result:sub(1, 1) == '_' then
        is_hidden = '_'
        result = result:sub(2)
    end
    char = result:match('_(.)')
    while char do
        result = result:gsub('_.', char:upper())
        char = result:match('_(.)')
    end
    return is_hidden .. result
end

function Formatter:_numbered_argument(number)
--[[
    Generate a numbered argument for use in a generated LaTeX command.
    NOTE: From all the ways to protect the `#1` arguments in the
    \directlua{} invocations this seems to be the only one working in all
    cases so far. I don't know if there's an “official” way to do this, though,
    or if there are cases where this one fails too.
--]]
    return string.format([["\luatexluaescapestring{\unexpanded{#%s}}"]], number)
end

function Formatter:_set_args_from_function()
--[[
    Retrieve the arguments from a formatter function (through introspection).
    If an `options` argument is present store its position for the mapping of
    LaTeX macro arguments.
--]]
    local formatter = self._func
    -- ignore any given arguments
    self._macro_args = {}
    local arg_cnt = debug.getinfo(formatter).nparams
    local arg
    for i=2, arg_cnt, 1 do -- skip the 'self' argument
        arg = debug.getlocal(formatter, i)
        if arg == 'options' then
            self._opt_index = i - 1
        end
        table.insert(self._macro_args, arg)
    end
end

function Formatter:_set_args_from_template()
--[[
    Try to extract the replacement fields from a template that has been declared
    without an explicit `args` field.
    This is only possible if the templates has not more than one mandatory and
    one `options` argument.
--]]
    local max = 1
    local fields = self:fields()
    self._macro_args = {}
    for i, v in ipairs(fields) do
        if v == 'options' then
            max = max + 1
            self._opt_index = i
        end
        if i > max then
            err(string.format([[
    Error configuring template.
    Can't automatically determine the order
    of arguments in Formatters with more than
    one (plus 'options') fields. Please
    specify arguments manually:
    %s
    ]], self:template()))
        end
        table.insert(self._macro_args, v)
    end
end

function Formatter:_validate_client_options(formatter)
--[[
    Validate given client options.
    Client options can only work if there's a corresponding option,
    i.e. a lua_options client, which also have to have all options defined.
--]]
    local options = formatter.client_options
    if options then
        if #options > 0 then
            -- client options are given as an array, assign to "current" client
            options = { [self._parent:name()] = options }
        end
        local client
        for cname, opts in pairs(options) do
            client = lua_options.client(cname)
            if not client then
                err(string.format([[
Try registering client option
for non-existing client
`%s`
in Formatter
`%s`.
    ]], cname, self:name()))
            end
            self._option_clients[cname] = client
            for _, opt in ipairs(opts) do
                if client:has_option(opt) then
                    self._option_clients[opt] = client
                else
                    err(string.format([[
Trying to set non-existent client option
`%s`
for client
`%s`
in formatter
`%s`.
]], opt, cname, self:name()))
                end
            end
        end
    end
    return formatter
end


return Formatter
