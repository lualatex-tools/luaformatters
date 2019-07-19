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
    *Templates* is the main table that is also returned and will be
    available as the global variable `lua_templates`.

    Arbitrary numbers of “clients” can register template tables with
    formatters. The clients tables will be stored in
    Templates._clients[<client_name>], and all available formatters will
    be stored in Templates._formatters[<client_name>].
    The pseudo-client `builtin` will be registered in the first place,
    before any real client gets the chance.

    Each client table will get Templates set as its metatable, so
    any code in a client's toplevel table can use `self` to access fields
    both from itself and from Templates.

    Each declared formatter will be wrapped in a Formatter object.
    Formatter's __index function will look for missing fields in the
    Formatters table, in the “parent” client, in Templates, and in the
    “parent”'s formatters subtable.
--]]
local Templates = {
    _formatters = {},
    _clients = {},
    _client_order_rev = {},
}
Templates.__index = Templates
-- Has to be made available as global function already now
_G['lua_templates'] = Templates

-- Load supporting modules
local Formatter = require('luatemplates-formatter')
local TemplatesTable = require('luatemplates-templatestable')
-- load supporter functions and hook them into the Templates table.
for k, v in pairs(require('luatemplates-support')) do
    Templates[k] = v
end


--[[
    Public interface, to be used for library management, but also from
    within formatter functions.
--]]

function Templates:new(properties)
    return TemplatesTable:new(properties)
end

function Templates:add(client)
--[[
    Register a new client.
    Store the complete client table in self._clients[name]
    Register included formatters within self._formatters[name],
      making sure they are proper Formatter objects.
    Replace the original formatter entry table with the Formatter object
    Process additional configuration.
    Create LaTeX macros.
--]]

    -- TODO: Handle conflicts (prevent, overwrite, update)
    self._clients[client:name()] = client
    table.insert(self._client_order_rev, 1, client:name())
    -- TODO: Document that the client will get these fields set
    -- (so if they'd use them they'd get overridden)

    -- Register the formatters local to the client
    self:_register_local_formatters(client)
    -- Process the entries in client.formatter
    self:_register_formatters(client)
    -- Process additional configuration
    self:_configure_formatters(client)
    -- Create LaTeX macros
    self:_create_macros(client)

    return o
end


function Templates:format(key, ...)
--[[
    Format and return the given data using a formatter addressed by `key`.
    Produces an error if no formatter can be found for the key.
    NOTE:
    The vararg has to match the expectation of the determined formatter, and
    especially depends on whether the formatter is template-based or
    function-based.
    For a function the number of arguments must match the function's signature.
    Templates typically receive a key=value replacement table, but for more
    options please refer to the comments in Formatter:apply().
--]]
    local formatter = self:formatter(key)
    if not formatter then
        err(string.format([[
Trying to format values
%s
but no template/formatter found at key
%s]], ..., key))
    end
    return formatter:apply(...)
end

function Templates:formatter(key)
--[[
    Find a formatter matching the given key.
    key may be either an array with a client name and a key or only a key.
    If it is an array only the given client is searched.
    If it is a plain key then clients are searched in reverse order of
    registration (i.e. identical keys of packages registered later
    will take precendence.)
    If no formatter with the given key is found, nil is returned.
--]]
    local result, roots = '', {}
    if type(key) == 'table' then
        roots = { self._formatters[key[1]] }
        key = key[2]
    else
        for _, v in ipairs(self._client_order_rev) do
            table.insert(roots, self._formatters[v])
        end
    end
    for _, root in ipairs(roots) do
        result = root[key]
        if result then return result end
        for _, v in pairs(root) do
            if v:name() == key then return v end
        end
    end
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
    Internal functions not intended for use by client code.
--]]

function Templates:_configure_formatter(client, key, properties)
--[[
    Apply manual configuration for a given item.
    - locate the formatter by the `key` field
      (will find the formatter in reverse order of addition)
    - update all fields in the formatter with the given data.
    - If `properties` is a string it is considered to be the
      formatter's new name.
    - If a name property is present (macro is renamed),
      add a copy of the Formatter entry in the current client's
      entries table to trigger the creation of a macro
--]]
    if type(properties) == 'string' then
        properties = { name = properties }
    end

    local formatter = self:formatter(key)
    if not formatter then err(string.format([[
Error configuring command entry.
No formatter found at key: %s]], key))
    end
    formatter:update(properties)
    if properties.name then
        self._formatters[client:name()][key] = formatter
    end
end

function Templates:_configure_formatters(client)
--[[
    Provide additional configuration to formatters or
    publish hidden formatters as LaTeX macros.
--]]
    if not client.configuration then return end
    for macro_name, properties in pairs(client.configuration) do
        self:_configure_formatter(client, macro_name, properties)
    end
end

function Templates:_create_macros(client)
--[[
    Create the LaTeX macros from the non-hidden formatters in a client.
--]]
    local macro
    for key, formatter in pairs(self._formatters[client:name()]) do
        macro = formatter:macro()
        if macro then
            self:write_latex(macro)
        end
    end
end

function Templates:_do_register_formatters(client, key, root, _local)
    --[[
        Recursively walk the client's `formatters` tree
        and register all the formatters in a flat table at
        self._formatters[client:name()]
    --]]
    local function next_key(next)
        if key == '' then
            return next
        else
            return key .. '.' .. next
        end
    end
    local formatter
    for k, v in pairs(root) do
        local next = next_key(k)
        if Formatter:is_formatter(v) then
            formatter = Formatter:new(client, next, v)
            if _local then
                client._local_formatters[next] = formatter
            else
                self._formatters[client:name()][next] = formatter
            end
            root[k] = formatter
        else
            self:_do_register_formatters(client, next, v, _local)
        end
    end
end

function Templates:_register_formatters(client)
--[[
    Recursively visit all formatter entries in client,
    create Formatter objects from them and register them in
    Templates's formatter table.
--]]
    if not self._formatters[client:name()] then
        self._formatters[client:name()] = {}
    end
    self:_do_register_formatters(client, '', client.formatters)
end

function Templates:_register_local_formatters(client)
--[[
    Recursively visit all local formatter entries in client,
    create Formatter objects from them and register as local formatters.
--]]
    self:_do_register_formatters(client, '', client._local, true)
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
        content = self:wrap_macro('textcolor', color, content )
    end
    self:write_latex(content)
end



--[[]
Handle some dependencies
Ensure that a color package is loaded,
otherwise require xcolor.
--]]
local function handle_dependencies()
    if template_opts['self-documentation'] then
        Templates:write_latex([[\RequirePackage{minted}
]])
    elseif template_opts.color then
        -- Only do this when minted hasn't been loaded before
        Templates:write_latex([[
\makeatletter
\@ifpackageloaded{xcolor}{}
{\@ifpackageloaded{color}{}{\RequirePackage{xcolor}}}
\makeatother
]])
    end
end

handle_dependencies()

-- Register the built-in formatters.
Templates:add(require('luatemplates-builtins'))

return Templates
