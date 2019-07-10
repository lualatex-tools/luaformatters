local MWE = {
    formatters = {
        cmd = [[\texttt{\textbf{\textbackslash <<<name>>>}}]],
        package = {
            f = [[\texttt{<<<name>>>}]],
            color = 'olive',
            comment = "A comment"
        },
    },
    configuration = {
        bold = 'bold',
    },
}

function MWE.formatters:XXX(text)
    return text:gsub('.', 'X')
end

return MWE
