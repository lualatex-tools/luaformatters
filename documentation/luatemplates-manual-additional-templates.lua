
local ADDITIONALS = {}

local function term()
--[[
    Local function with a closure to keep track of used \term elements.
    A term is printed in monospace font, but the *first* appearance of a
    term will additionally be colored!
    The optional argument may be used to specify the core form of a term.
--]]
    local used_terms = {}

    return function (self, term, options)
        local ref_term = term
        if options ~= '' then ref_term = options end
        if used_terms[ref_term] then
            return self:wrap_macro('texttt', term)
        else
            used_terms[ref_term] = true
            return self:wrap_macro('textcolor', {
                'OliveGreen',
                self:wrap_macro('texttt', term)
            })
        end
    end
end


ADDITIONALS.formatters = {
    cary = [[Mary Flagler Cary Music Collection \emph{(Pierpont Morgan Library)}]],
    DV = {
        f = [[\textsc{d}\,<<<dnumber>>>]],
        color = 'cyan',
        comment = 'Deutsch-Verzeichnis (= Schubert catalogue)',
    },
    luavar = {
        f = [[\texttt{<<<name>>>}]],
        comment = 'A Lua name/variable'
    },
    package = {
        f = [[\texttt{<<<name>>>}]],
        comment = 'A LaTeX package, Lua module etc.',
        color = 'olive'
    },
    term = {
        -- use a local function with a closure, keeping track of uses.
        f = term(),
        comment = 'A specific term or name',
        -- coloring is done *inside* the function itself
        color = 'nocolor',
    }
}


return ADDITIONALS
