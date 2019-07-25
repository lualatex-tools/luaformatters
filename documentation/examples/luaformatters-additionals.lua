--[[
    Formatters Table with the rest of functionality that is just *used*
    in the manual but not specifically demonstrated as examples.
--]]

local ADDITIONALS = lua_formatters:new_client('additionals')

ADDITIONALS.formatters = {
    argument = {
        f = [[\texttt{<<<argname>>>}]],
        color = 'Fuchsia',
    },
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
    NOTE = {
        f = [[\textbf{\uppercase{<<<note>>>}}]],
        color = 'red',
    },
    package = {
        f = [[\texttt{<<<name>>>}]],
        comment = 'A LaTeX package, Lua module etc.',
        color = 'olive'
    },
}

return ADDITIONALS
