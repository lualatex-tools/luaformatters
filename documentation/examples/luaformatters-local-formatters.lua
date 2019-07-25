--[[
    Handling of “local” formatters
--]]

local LOCALS = lua_formatters:new_client{
    name = 'locals',
    namespace = { 'tool' }
}

-- Add through provided functions
LOCALS:add_local_formatters{
    foo = [[\textbf{<<<foo>>>}]],
    bar = [[\textsc{<<<bar>>>}]]
}
-- Nested namespace is possible too
LOCALS:add_local_formatter('tool.bar', [[tool..bar]])

-- Directly define within ._local subtree
function LOCALS._local:rev(text)
    return text, text:reverse()
end

function LOCALS.formatters:reversify(text)
    --[[
        Invoke a local formatter through self:_format()
        (as opposed to self:format() for regular formatters).
        Note that the local formatter can return
        other values than single strings
    --]]
    local original, reversed = self:_format('rev', text)
    return original .. ' <=> ' .. reversed
end

function LOCALS.formatters:toolbar()
    -- call the nested local formatter
    return self:_format('tool.bar')
end

function LOCALS.formatters:foo_bar(first, second)
    first = self:_format('foo', first)
    second = self:_format('bar', second)
    return first .. ' | ' .. second
end

LOCALS:add_local_formatter('work-number', function (self, text)
    return text:gsub(
    ' ', ''):gsub(
    '/', ','):gsub(
    ',', [[,\,]])
end)

function LOCALS.formatters:dv(text)
    return self:format('DV', self:_format('work-number', text))
end

return LOCALS
