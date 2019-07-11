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

MWE:add_configuration{
    bold = 'bold',
}

return MWE
