local MWE = lua_formatters:new_client('mwe')
MWE:add_formatter('red', [[\textcolor{red}{<<<text>>>}]])
function MWE.formatters:optReverse(text, options)
    if options.reverse then text = text:reverse() end
    return text
end
return MWE
