--[[
    Validating optional arguments.
    If an `options` table is specified in a Formatter Entry Table
    its content is used to prepopulate and to validate a given optional
    argument.
--]]

local VALIDATION = lua_formatters:new_client{
    name = 'form',
}

function VALIDATION.formatters:do_format(text, options)
-- Use one out of a list of built-in formatters to format the text.
    return self:format(options.formatter, text)
end

function VALIDATION.formatters:gap(options)
--[[
    Insert a gap with configurable width and optional “redaction” rule
--]]
    if options.rule then
        return self:wrap_macro('rule',
            options.width,
            '1em',
            { '-0.5ex' })
    else
        return self:wrap_macro('hspace*', options.width)
    end
end

VALIDATION:add_configuration{
    do_format = {
        options = {
            ['formatter'] = {'bold', 'italic', 'superscript'},
        }
    },
    gap = {
        options = {
            ['width'] = { '3em', lua_options.is_dim },
            ['rule'] = { 'false', 'true', '' },
        }
    }
}

return VALIDATION
