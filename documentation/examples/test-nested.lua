local MWE = lua_formatters:new_client({
    name = 'mwe',
    namespace = { 'levelone' }
})
function MWE.formatters.levelone:optReverse(text, options)
    if options.reverse then text = text:reverse() end
    return text
end

MWE:add_configuration{
    ['levelone.optReverse'] = 'rev'
}

return MWE
