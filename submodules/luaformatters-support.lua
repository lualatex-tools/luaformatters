local err, warn, info, log = luatexbase.provides_module({
    name               = "luaformatters.support",
    version            = '0.8',
    date               = "2019/07/02",
    description        = "Lua module for templating. Supporting functions.",
    author             = "Urs Liska",
    copyright          = "2019- Urs Liska",
    license            = "GPL3",
})

--[[
    This file implements support functions that can be used from any
    formatter using the self:... notation. The functions will be stored in the
    main Formatters table lua_formatters and are defined in a separate file to
    better separate between the genuine tasks of the Formatters table and these
    supporting functions.
--]]

local SUPPORT = {}

function SUPPORT:split_list(str, pat)
--[[
    Split a string into a list at the given pattern.
    Built upon: http://lua-users.org/wiki/SplitJoin
--]]
--[[
    TODO: Investigate a luatex-like solution with str:explode().
    The following does *not* work because the pattern is included in the list.
    local t = {}
    for _, elt in ipairs(str:explode(pat)) do
        if elt ~= pat then table.insert(t, elt) end
    end
--]]
    local t = {}
    local fpat = "(.-)" .. pat
    local last_end = 1
    local s, e, cap = str:find(fpat, 1)
    while s do
        if s ~= 1 or cap ~= "" then
            table.insert(t,cap)
        end
        last_end = e+1
        s, e, cap = str:find(fpat, last_end)
    end
    if last_end <= #str then
        cap = str:sub(last_end)
        table.insert(t, cap)
    end
    return t
end

function SUPPORT:split_range(text, separator)
--[[
    Split a string into two fields at the first hyphen, returning 'from' and 'to'.
    Any further hyphens (even in '--') are given to the 'to' field:
    '3--4' will yield '3' and '-4'
    If there is no hyphen 'from' will hold the whole string while 'to' is nil.
--]]
    local from, to = text:match('(.-)%-(.*)')
    if not to then
        return text, nil
    else
        return from, to
    end
end

function SUPPORT:wrap_kv_option(key, value)
--[[
    Process a key/value pair to be used as a key/value option.
    If a value is provided return 'key={value}' to protect the value from
    possible commas misleading a parser. If no value is provided return the key
    alone.
    In order to provide this as a complete optional argument use
    SUPPORT:wrap_optional_arg on the result.
--]]
    if value and value ~= '' then
        return string.format([[%s={%s}]], key, value)
    else
        return key
    end
end

function SUPPORT:wrap_macro(macro, ...)
--[[
    Wrap one or multiple values in a macro invocation.
    - macro (string)
      The name of the macro
    - value (string or table)
      One or multiple values. An empty string or nil causes one single argument
      (or delimiter) to be created:
      'mymacro', '' => \mymacro{}
      Multiple values are mapped to multiple arguments:
      'mymacro', { 'one', 'two', 'three' } => \mymacro{one}{two}{three}
      In addition to the sequence the table may contain one named field
      'options' whose content will be added as an optional argument:
      'mymacro', { 'one', 'two', options = '3pt' } => \mymacro[3pt]{one}{two}
--]]
    local result = string.format([[\%s]], macro)
    local opt = ''
    local args = ''
    for _, v in ipairs{ ... } do
        if type(v) == 'string' then
            args = args .. string.format('{%s}', v)
        else
            opt = self:wrap_optional_arg(v[1])
        end
    end
    if args == '' and opt == '' then args = '{}' end
    return result .. opt .. args
end

function SUPPORT:wrap_optional_arg(opt)
--[[
    Wrap an optional argument in square brackets if it is provided,
    otherwise return an empty string.
--]]
    if opt and opt ~= '' then
        return '['..opt..']'
    else
        return ''
    end
end

function SUPPORT:write_latex(latex)
--[[
    Convenience function because it's sometimes awkward to write
    long strings, having to use an intermediate variable.
--]]
    tex.print(latex:explode('\n'))
end

return SUPPORT
