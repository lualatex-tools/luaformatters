--[[
    A single formatter function implemented using a *closure*
    which keeps track of state:  the first occurrence of any given “term”
    is formatted differently than subsequent ones.
--]]

local CLOSURE = lua_formatters:new_client('closure')

local function term()
--[[
    Local function with a closure to keep track of used \term elements.
    A term is printed in monospace font, but the *first* appearance of a
    term will additionally be colored!
    The optional argument may be used to specify the core form of a term.
--]]
    -- local variable that stores whether a given term has already been used.
    local used_terms = {}

    --[[
        Return value is the actual formatter function.
        This is what is registered as the formatter, with access to the
        persistent `used_terms` variable.
    --]]
    return function (self, term, options)
        local ref_term = term
        -- options is used as a simple string here,
        -- used to store the core form of a given term.
        if options[1] ~= '' then ref_term = options[1] end
        term = self:wrap_macro('texttt', term)
        if used_terms[ref_term] then
            return term
        else
            used_terms[ref_term] = true
            return self:wrap_macro('textcolor', 'OliveGreen', term)
        end
    end
end

CLOSURE:add_formatter('term', {
    -- here the *return value* of the local function `term()` is attached
    func = term(),
    comment = 'A specific term or name',
})

return CLOSURE
