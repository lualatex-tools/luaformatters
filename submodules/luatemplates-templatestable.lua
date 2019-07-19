local err, warn, info, log = luatexbase.provides_module({
    name               = "luatemplates.templates-table",
    version            = '0.8',
    date               = "2019/07/02",
    description        = "luatemplates, Base table for Templates Tables.",
    author             = "Urs Liska",
    copyright          = "2019- Urs Liska",
    license            = "GPL3",
})

local TemplatesTable = {}
TemplatesTable.__index = TemplatesTable

function TemplatesTable:new(properties)
--[[
    Create new instance.
    The argument may either be a name or a table with at least a `name` field.
    Optional table fields:
    - `prefix`
      prefix to use for generated macro names
    - `strict`
      if set to true formatters may only be added to existing subtables
      (either created manually or through TemplatesTables:provide_namespace)
    - `namespace`
      if set (a single string or a table) create the given namespace.
    - `formatters`
      (nested) table with formatters
    - `_local`
      (nested) table with local formatters (available only
      from within the client)
    - `configuration`
      flat table with formatter configuration entries
--]]
    if type(properties) == 'string' then
        properties = { name = properties }
    end
    local o = {
        _name = properties.name or err([[
    Trying to create a new Templates Table
    without specifying a name.
    ]]),
        _prefix = properties.prefix,
        _display_name = properties.display_name or properties.name,
        formatters = properties.formatters or {},
        _local = properties._local or {},
        -- will hold a flat table with dot-notation keys
        _local_formatters = {},
        configuration = properties.configuration or {}
    }
    if properties.strict == nil then
        o._strict = true
    else
        o._strict = properties.strict
    end
    setmetatable(o, TemplatesTable)
    if properties.namespace then
        self.provide_namespace(o, properties.namespace)
    end
    return o
end

function TemplatesTable:add_configuration(...)
--[[
    Add configuration to the table.
    The variable arguments can consist of zero or one strings and a a table.
    The optional string is a noop comment, just for documenting the input file.
    The table adds configuration entries to the table, adding data to existing
    or publishing hidden formatters.
    Each entry is either a string or a Formatter Entry Table.
    If it is a string then it will update the formatter's `name`, possibly
    publishing a previously hidden formatter.
      NOTE: It is not clear what happens when the name of a previously
      *published* formatter is changed: see
      https://github.com/uliska/luatemplates/issues/34
--]]

    local function get_formatter_entry(key)
    --[[
        Find an entry for the formatter requested to be modified.
        Return the formatter's parent node and last key-element or nil, nil.
    --]]
        local formatter
        -- First look up within the current client's formatters subtable
        local parent, entry_key = self:parent_node(key, self.formatters, {
            leaf_must_exist = true
        })
        if not parent then
            -- Look for a previously registered formatter
            formatter = lua_templates:formatter(key)
        end
        if formatter then return formatter end

        if not parent then
            err(string.format([[
Trying to configure formatter entry
but no formatter found at key
%s
]], key))
        end
        local result = parent[entry_key]
        -- Wrap a formatter in a Formatter Entry Table if necessary
        if type(result) == 'string' or type(result) == 'function' then
            parent[entry_key] = { f = result }
            result = parent[entry_key]
        end
        return result
    end


    local args = {...}
    local entry
    for _, arg in ipairs(args) do
        if type(arg) == 'string' then
            -- do nothing, just for input clarity
        else
            -- Iterate over all given entries
            for key, formatter in pairs(arg) do
                if type(formatter) == 'string' then
                    -- Wrap name to Formatter Entry Table
                    formatter = { name = formatter }
                end
                entry = get_formatter_entry(key)
                if entry._is_Formatter then
                    -- The formatter has already been created as an object
                    -- and registered with a previous client
                    entry:update(formatter)
                    -- Store an additional reference in “our” formatters list,
                    -- (create that if necessary)
                    if not lua_templates._formatters[self._name] then
                        lua_templates._formatters[self._name] = {}
                    end
                    lua_templates._formatters[self._name][key] = entry
                else
                    -- The formatter has only been provided by the current
                    -- client. Modify in-place, Formatter object will be
                    -- created in Templates:add()
                    for k,v in pairs(formatter) do
                        entry[k] = v
                    end
                end
            end
        end
    end
end

local function err_namespace(key)
    if type(key) == 'table' then
        key = table.concat(key, '.')
    end
    err(string.format([[
    Trying to add formatters
    at non-existing key
    %s
    To allow this either create
    the node manually or through
    TemplatesTable:provide_namespace(),
    or set the 'strict' property
    for this table to 'false'.
    ]], key))
end

function TemplatesTable:_add_formatter(root, key, formatter)
--[[
    Add a single formatter at a specific key.
    - `key`
      Address in dot-notation.
      Node is created if not present and table's `strict` property is false
    - `formatter`
      Formatter in any of the accepted forms:
      template string, function or formatter entry table
--]]
    local parent, last_key = self:parent_node(key, root, {
        create = not self._strict,
        leaf_must_exist = false,
    })
    if not parent then err_namespace(key) end
    parent[last_key] = formatter
end

function TemplatesTable:add_formatters(...)
--[[
    Add a number of formatters to the table.
    root is either self.formatters or self._local_formatters.
    The variable arguments may consist of zero to two strings plus a table.
    The first string is a noop comment, just for documenting the input file.
    The second string is the root node in the formatters table -
    if this node doesn't exist and the table's `strict` property is false
    it will silently be created.
    The table maps keys to formatter entries.
--]]
    local args = {...}
    local root = self.formatters
    local comment, parent
    for _, arg in ipairs(args) do
        if type(arg) == 'string' then
            if not comment then
                comment = arg
            else
                parent = self:node(arg, root, not self._strict)
                if not parent then err_namespace(arg) end
            end
        else
            parent = parent or root
            for k, v in pairs(arg) do
                parent[k] = v
            end
        end
    end
end

function TemplatesTable:add_formatter(key, formatter)
-- See TemplatesTable:_add_formatter
    self:_add_formatter(self.formatters, key, formatter)
end

function TemplatesTable:add_local_formatter(key, formatter)
-- See TemplatesTable:_add_formatter
    self:_add_formatter(self._local, key, formatter)
end

function TemplatesTable:add_local_formatters(formatters)
-- See TemplatesTable:_add_formatters
    for k, v in pairs(formatters) do
        self:add_local_formatter(k, v)
    end
end

function TemplatesTable:configure_formatter(key, properties)
--[[
    Apply manual configuration to a given item.
    This can be used to expose hidden (e.g. built-in) formatters as
    LaTeX macros, or to extend the configuration of registered formatters,
    typically used for formatter functions that have been defined
    with the standalone `function Templates:<name>` syntax.
    If `properties` is a string it is considered to be the formatter's new name.
    To publish a hidden formatter the `name` field must be provided with a
    string that doesn't start with an underscore.
    - locate the formatter by the `key` field
      This may refer to a formatter in this table or to one of another,
      previously registered client.
      NOTE: It is only possible to “unhide” formatters from other clients,
      updating the configuration of a formatter that has already created
      a LaTeX macro in another client will fail.
    - update all fields in the formatter with the given data.
    - register the formatter also in the *current client's* formatter subtree
      (otherwise it wouldn't be created as a macro)
--]]
    if type(properties) == 'string' then
        properties = { name = properties }
    end
    self.configuration[key] = properties
end

function TemplatesTable:name()
    return self._name
end

function TemplatesTable:node(path, root, create)
--[[
    Return a node in the TemplatesTable.formatters subtree,
    creating nodes along the way if necessary (and the `create`
    argument is true).
--]]
    if path == '' then return root end
    if type(path) == 'string' then path = path:explode('.') end
    local cur_node, next_node = root
    for _, k in ipairs(path) do
        next_node = cur_node[k]
        if next_node then
            cur_node = next_node
        elseif create then
            cur_node[k] = {}
            cur_node = cur_node[k]
        else
            return
        end
    end
    return cur_node
end

function TemplatesTable:parent_node(key, roots, opts)
--[[
    Retrieve the parent node from a given dot-list key.
    Return the parent node and the trailing key element.
    If `create` is true then missing nodes are created along the way.
    Otherwise if no node is found return nil and nil.
--]]

    if not opts then opts = {} end
    if roots then
        roots = { roots }
    else
        roots = {}
        for _, client in ipairs(self._client_order_rev) do
            table.insert(roots, self._clients[client].formatters)
        end
    end
    local path = key:explode('.')
    local last_key = table.remove(path, #path)
    for _, root in ipairs(roots) do
        local parent = self:node(path, root, opts.create)
        if parent
        and (parent[last_key] or opts.create or not opts.leaf_must_exist) then
            return parent, last_key
        end
    end
    return nil, nil
end

function TemplatesTable:prefix()
    return self._prefix or ''
end

function TemplatesTable:provide_namespace(keys)
--[[
    Verify the existence or create nodes for all given keys.
    This can serve as documentation and to simplify coding
    for standalone function definitions.
    The argument can be a single string or an array of strings
    (keys in dot-notation)
--]]
    if type(keys) == 'string' then
        keys = { keys }
    end
    for _, v in ipairs(keys) do
        _ = self:node(v, self.formatters, true)
        _ = self:node(v, self._local, true)
    end
end

return TemplatesTable
