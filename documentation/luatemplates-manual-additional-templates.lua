
local ADDITIONALS = {}

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
}

return ADDITIONALS
