local CONFIG = {
    styles = {
        cmd = [[\texttt{\textbf{\textbackslash <<<name>>>}}]],
        package = {
            f = [[\texttt{<<<name>>>}]],
            color = 'olive'
        },
    },
    formatters = {},
}

function CONFIG.formatters:XXX(text)
    return text:gsub('.', 'X')
end

return CONFIG
