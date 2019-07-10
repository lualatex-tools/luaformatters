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

function TemplatesTable:name()
    return self._name
end

function TemplatesTable:prefix()
    return self._prefix or ''
end

return TemplatesTable
