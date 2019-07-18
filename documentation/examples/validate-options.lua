--[[
    Validating optional arguments.
    If an `options` table is specified in a Formatter Entry Table
    its content is used to prepopulate and to validate a given optional
    argument. After calling self:check_options with the given optional
    argument (TODO: modify Formatter:apply to automatically perform this
    conversion so a formatter function can rely on the `options` being
    processed) the `options` variable is guaranteed to refer to a table with
    all specified options, with default or locally given and validated values.
--]]

local VALIDATION = lua_templates:new{
    name = 'form',
}

function VALIDATION.formatters:do_format(text, options)
-- Use one out of a list of built-in formatters to format the text.
    options = self:check_options(options)
    return self:format(options.formatter, text)
end

function VALIDATION.formatters:gap(options)
--[[
    Insert a gap with configurable width and optional “redaction” rule
--]]
    options = self:check_options(options)
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
            ['width'] = { '3em', template_opts.is_dim },
            ['rule'] = { 'false', 'true', '' },
        }
    }
}

return VALIDATION
