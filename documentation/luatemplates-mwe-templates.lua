local MWE = lua_templates:new('mwe')

function MWE.formatters:XXX(text)
    return text:gsub('.', 'X')
end

MWE:add_formatters('arbitrary comment', {
    cmd = [[\texttt{\textbf{\textbackslash <<<name>>>}}]],
    package = {
        f = [[\texttt{<<<name>>>}]],
        color = 'magenta',
        comment = "A comment"
    },
})

MWE:configure_formatter('bold', 'myBold')

MWE:configure_formatter('cmd', {
    color = 'magenta'
})

return MWE
