--[[
    Validating optional arguments.
    If an `options` table is specified when creating the Templates Table,
    they are used to validate the optional argument in self:check_options.
    This affects both declared *keys* and expected *values/types*
--]]

local FORMATTERS = lua_templates:new{
    name = 'form',
    options = {
        ['formatter'] = { 'bold', 'italic', 'superscript' },
        ['distance']  = { '3em', template_opts.is_dim },
    }
}

function FORMATTERS.formatters:do_format(text, options)
    options = self:check_options(options)
    return self:format(options.formatter, text)
end

function FORMATTERS.formatters:gap(text, options)
    options = self:check_options(options)
    return self:wrap_macro('hspace*', options.distance) .. text
end

return FORMATTERS
