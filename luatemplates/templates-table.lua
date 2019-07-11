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
TemplatesTable.__index = function(t, key)
    return
    t.formatters[key]
    or TemplatesTable[key]
    or lua_templates[key]
end

function TemplatesTable:new(properties)
--[[
    Create new instance.
    The argument may either be a name or a table with at least a `name` field.
    Additionally it may include a `prefix` field and `formatters` and
    `configuration` subtables.
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
        formatters = properties.formatters or {},
        configuration = properties.configuration or {}
    }
    setmetatable(o, TemplatesTable)
    return o
end

function TemplatesTable:add_configuration(...)
--[[
    Add configuration to the table.
    The variable arguments can consist of zero or one strings and a a table.
    The optional string is a noop comment, just for documenting the input file.
    The table adds configuration entries to the table, adding data to existing
    or publishing hidden formatters.
--]]
    local args = {...}
    local root = self.configuration
    local comment
    for _, arg in ipairs(args) do
        if type(arg) == 'string' then
            comment = arg
        else
            for k, v in pairs(arg) do
                root[k] = v
            end
        end
    end
end

function TemplatesTable:add_formatters(...)
--[[
    Add a number of formatters to the table.
    The variable arguments may consist of zero to two strings plus a table.
    The first string is a noop comment, just for documenting the input file.
    The second string is the root node in the formatters table - if this node
    (or any intermediate nodes) doesn't exist it will silently be created.
    The table maps keys to formatter entries.
--]]
    local args = {...}
    local comment, root
    for _, arg in ipairs(args) do
        if type(arg) == 'string' then
            if not comment then
                comment = arg
            else
                root = self:node(arg)
            end
        else
            root = root or self.formatters
            for k, v in pairs(arg) do
                root[k] = v
            end
        end
    end
end

function TemplatesTable:name()
    return self._name
end

function TemplatesTable:node(path)
--[[
    Return a node in the TemplatesTabel.formatters subtree,
    creating nodes along the way if necessary.
--]]
    root = self.formatters
    if path == '' then return root end
    local cur_node, next_node = root
    for _, k in ipairs(path:explode('.')) do
        next_node = cur_node[k]
        if next_node then
            cur_node = next_node
        else
            cur_node[k] = {}
            cur_node = cur_node[k]
        end
    end
    return cur_node
end

function TemplatesTable:prefix()
    return self._prefix or ''
end

return TemplatesTable
