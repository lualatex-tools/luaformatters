local FORMAT = lua_templates:new('format')

--[[
    Use self:format() to reuse formatters defined in the same
    or another Client.
    foo has been defined in MANUAL/'manual', so it can safely be
    used directly, but for the sake of the example a check is done
    first and the unmodified input returned as “fallback”.
--]]

function FORMAT.formatters:Bar(text)
    local result = ''
    local f = self:formatter('foo')
    -- Alternative approach searching only a specific Client
    -- local f = self:formatter({'manual', 'foo'})
    if not f then return text end
    for i=1, #text, 1 do
        result = result .. self:format('foo', text:sub(i, i))
    end
    return result
end

--[[
    Another function using a registered formatter, this time a built-in.
    For built-in formatters it is strictly unnecessary to check their
    availability.
    NOTE: The *function* name `check_range` will produce a
    *macro* name `\checkRange`.
--]]
function FORMAT.formatters:check_range(text)
    local processed = self:format('range', text)
    if processed ~= text then
        text = processed .. string.format([[ (input was: \texttt{\{%s\}})]], text)
    end
    return text
end

return FORMAT
