local err, warn, info, log = luatexbase.provides_module({
    name               = "luaformatters.builtins",
    version            = '0.8',
    date               = "2019/07/02",
    description        = "luaformatters, built-in formatters.",
    author             = "Urs Liska",
    copyright          = "2019- Urs Liska",
    license            = "GPL3",
})

--[[
    The *BUILTINS* table provides general formatters that can either be used
    from custom formatters in modular style or published as LaTeX macros during
    a client's configuration stage.
    It may serve as an example of a luaformatters client file, but it includes
    a few pretty specific table tricks.
--]]

--[[
    *Formatters*
    For better clarity in the source file a Formatters table is locally
    stored and later hooked into BUILTINS as BUILTINS.formatters.
    Any code in Formatters will eventually be exposed to the Formatters
    formatter lookup, while code in BUILTINS is private to this module.

    All functions in the table will be wrapped in a formatter entry table,
    with the `name` property prepended with an underscore.  Therefore all
    the built-in formatters are “hidden” by default and won't trigger the
    creation of LaTeX macros.

    Within any function in Formatters, “self” will refer to the Formatter
    object but benefit from the metatable indexing (described in formatter.lua)
--]]
local Formatters = {}

local BUILTINS = lua_formatters:new{
    name = 'builtins',
    formatters = Formatters,
    docstrings = {}
}

local formatters_opts = lua_options.client('formatters')

--[[
    BUILTINS.
    “private” code used by the Formatters entries
--]]

function BUILTINS:add_ssscript(direction, base, element, parenthesis)
--[[
    Add a super- or subscript to the given base string.
    If `element` is not given or an empty string, no action is taken.
    If `parenthesis` is a true value the super/subscript is wrapped in
    parentheses.
--]]
    if not (element and element ~= '') then return base end
    if parenthesis then element = '(' .. element .. ')' end
    return base .. self:format(direction, element)
end


-----------------------------------------------
-- Docstrings section
-----------------------------------------------

function Formatters:docstring_inline(key, options)
--[[
    Return a minted-formatted docstring inline to a paragraph.
    If options.args contains a comma-separated list of argument values
    they are inserted, otherwise the argument names are printed.
    If options.demo is present the docstring is followed by an actual demo
    of the macro -- this is most probably only useful in combination with
    options.args.
    The docstring is separated from the demo by ': ' or any value passed
    with options.docsep.
    Asking for a non-existent key will trigger a warning and return a warning
    message to the document.
--]]
    options.single = true
    options.nocomment = true

    local formatter = self:formatter(key)
    if not formatter then err(string.format([[
Docstring requested, but no formatter found at key
%s
]], key))
    end
    local docstring = formatter:docstring(options)
    local result = string.format([[\mintinline{tex}{%s}]], docstring)
    if options.demo then
        local separator = options.demosep
        if separator == 'default' then
            separator = formatters_opts['demosep-inline']
        end
        result = result..string.format([[
%s%s]], separator , docstring)
    end
    return result
end

function Formatters:docstring_minted(key, options)
--[[
    Return a docstring wrapped in a {minted} environment.
    If options.args contains a comma-separated list of argument values
    they are inserted, otherwise the argument names are printed.
    If options.demo is present the docstring is followed by an actual demo
    of the macro -- this is most probably only useful in combination with
    options.args.
    The docstring is separated from the demo by a \par\noindent or any value
    passed with options.docsep.
    Asking for a non-existent key will trigger a warning and return a warning
    message to the document.
--]]
    local formatter = self:formatter(key)
    local docstring = formatter:docstring(options)
    local result = string.format([[
\begin{minted}{tex}
%s
\end{minted}
]], docstring)
    if options.demo then
        local separator = options.demosep
        if options.demosep == 'default' then
            separator = formatters_opts['demosep-minted']
        end
        result = result..string.format([[
%s
%s
]], separator, docstring)
    end
    return result
end

function Formatters:docstrings(client_name, options)
--[[
    Return a list of docstrings for a single client.
--]]
    local formatters = self._formatters[client_name]
    local names = {}
    for k,v in pairs(formatters) do
        if not v:is_hidden() then table.insert(names, k) end
    end
    table.sort(names, function(a,b)
        return formatters[a]:name():lower() < formatters[b]:name():lower()
    end)
    local result = {}
    for _, key in ipairs(names) do
        table.insert(result, self:formatter(key):docstring(options))
    end
    return table.concat(result, '\n')
end

function Formatters:docstrings_minted(client_name, options)
--[[
    Return full documentation for a single client in a minted environment.

    `options` are currently not used (it doesn't make sense to fill in
    data, and there's no way how to integrate a demo for this. Options may be
    used at some point to configure the behaviour/appearance, though.)
--]]
    return string.format([[
\begin{minted}{tex}
%s
\end{minted}
]], self:format('docstrings', client_name, options))
end

-- TODO: Create docstrings for whole tree, standalone file export

-----------------------------------------------
-- End docstrings section
-----------------------------------------------


-----------------------------------------------
-- Start built-in formatters
-----------------------------------------------


function Formatters:add_subscript(base, super, parenthesis)
--[[
    Add a subscript the the given base string.
--]]
    return BUILTINS.add_ssscript(self, 'subscript', base, super, parenthesis)
end

function Formatters:add_superscript(base, super, parenthesis)
--[[
    Add a superscript the the given base string.
--]]
    return BUILTINS.add_ssscript(self, 'superscript', base, super, parenthesis)
end

function Formatters:add_element(base, element, separator)
--[[
    Built-in formatter:
    Add an element to a base string, using either the separator
    specified by the package options or a given one.
--]]
    if base == '' then
        return element
    elseif element == '' then
        return base
    else
        local sep = separator or formatters_opts['element-separator']
        if not separator then
            warn([[
Bug:
Add_element swallows spaces
from option-provided separator!]])
        end
        return base .. sep .. element
    end
end

function Formatters:bold(text)
--[[
    Make text bold
--]]
    return self:wrap_macro('textbf', text)
end

function Formatters:capitalize(word)
--[[
    Capitalize the first letter in the given word/string.
--]]
    if word == '' then return ''
    elseif #word == 1 then return word:upper()
    else return word:sub(1, 1):upper() .. word:sub(2)
    end
end

function Formatters:case(case, text)
--[[
    Format text according to a given case strategy.
    TODO: Maybe add camelcasing or other more advanced features?
--]]
    local templates = {
        normal = '%s',
        allsmallcaps = [[\textsc{\lowercase{%s}}]],
        smallcaps = [[\textsc{%s}]],
        upper = [[\uppercase{%s}]],
        lower = [[\lowercase{%s}]]
    }
    return string.format(templates[case or 'normal'], text)
end

function Formatters:emph(text)
--[[
    Emphasize the given text
    NOTE: This may not be exposed as a LaTeX macro directly, but it may be useful
    to use from within formatter functions.
--]]
    return self:wrap_macro('emph', text)
end

function Formatters:italic(text)
--[[
    Make the given text italic
--]]
    return self:wrap_macro('textit', text)
end

function Formatters:list_format(text, options)
--[[
    Format a list specified from a BibTeX-style list field.
    `text` is parsed as a list from a single text.
    By default input is parsed using the separator ' and ',
    the output separators are specified with the 'list-sep' and
    the 'list-last-sep' package options.
    If an option table is given it may contain the following options:
    - input_separator
      Change the parsing behaviour (in case 'and' is valid part of an input element)
    - separator
      separator to be used for all but the last element pairs
    - last_sep
      separator to be used for the last element pair
    TODO: incorporate biblatex's list compressing behaviour
    - formatter
      If a formatter is given as an option every list element is passed to
      that (similar to the `map` construct in some programming languages).
      formatter may be either a key (as passed to Formatters:formatter()) or an
      actual function. The returned formatter must accept exactly one argument,
      so the registered 'styles' may be good formatters. Some of the built-in
      formatters are also suitable, maybe the most-used formatter is 'range'
      (see Formatters:range) or 'number' (see Buitlins:number).
--]]
    if not text or text == ''  then return '' end

    local elements = self:split_list(text, options.input_separator or ' and ')
    local formatter = options.formatter
    if formatter then
        for i, elt in ipairs(elements) do
            if type(formatter) == 'function' then
                elements[i] = formatter(self, elt)
            else
                elements[i] = self:format(formatter, elt)
            end
        end
    end
    return self:format('list_join', elements, {
        separator = options.separator or formatters_opts['list-sep'],
        last_sep = options.last_sep or formatters_opts['list-last-sep'],
    })
end

function Formatters:list_join(list, options)
--[[
    Join a list of strings with ', '.
    If the list is empty an empty string is returned.
    If the list consists of one element this is returned as-is.
    With `options` the behaviour can be changed:
    - options.separator
      specifies a different separator for all but the last join
    - options.last_sep
      specifies the separator between the last two elements.
     the given separator, last_sep or ', '. If it is *not* given the default
     is the regular separator.
    TODO: integrate/emulate biblatex's handling of compressing long lists.
    NOTE: table.concat mostly does the same but doesn't provide the option
    for a different last separator. Considering that list compression is also
    planned it seems OK to do it manually.
--]]
    local sep = options.separator or ', '
    local last_sep = options.last_sep or sep
    if #list == 0 then return ''
    elseif #list == 1 then return list[1]
    elseif #list == 2 then return list[1]..last_sep..list[2]
    else
        local result = list[1]
        local index, last = 1, #list
        repeat
            index = index + 1
            result = result..sep..list[index]
        until index == last - 1
        return result..last_sep..list[last]
    end
end

function Formatters:number(text, options)
--[[
    Format numbers (WIP), including handling case for roman numerals.
    If `text` is either a simple number or contains a '\' (in which
    case it is considered a custom-formatted text) it is returned as-is,
    otherwise the case (only useful for roman numerals, e.g. in paginations)
    will be processed according to the 'number-case' package option or the
    'number-case' option in the passed `options`.
--]]
    if tonumber(text) or text:find('\\') then return text end
    return self:format('case', options['number-case'], text)
end

function Formatters:range(text, options)
--[[
    Parse and format a range (useful e.g. for pagination commands).
    A range is first considered as a string with one hyphen in it. This is split in
    two at the *first* hyphen, any subsequent hyphens (also when the range is written as
    3--4) will be part of the second part.
    The two parts are consider as 'from' and 'to'.
    If there is no hyphen the text is considered as a single element/number, without a 'to'.
    Each element may be one out of:
    - numbers
      => anything that Lua's `tonumber` function accepts as a number
    - roman numerals
      depending on the package option 'number-case' these are left as they are or processed
      to a consistent case.
      NOTE: This affects *any* text, which may or may not be desirable/acceptable
    - LaTeX-formatted text. If any '\' is found the part is left untouched.
    - 'f' or 'ff' ('to' part only)
      If the 'to' part is 'f' or 'ff' it is replaced with the value of the
      'range-follow' or 'fange-ffollow' option, by default 'f.' and 'ff.', while
      the range separator is suppressed
    The range separator is controlled by the 'range-sep' package option,
    which by default is '--'.
    The package options can also be overridden by the optional `options` table.
    --]]
    local formatter = options.formatter or 'number'
    local from, to = self:split_range(text)
    if not to then return self:format(formatter, text, options)
    elseif to:sub(1, 1) == 'f' then
        local follow_key = 'range-'..to..'ollow'
        local follow = options[follow_key] or formatters_opts[follow_key]
        return self:format(formatter, from, options) .. follow
    else
        local range_sep = options['range-sep'] or formatters_opts['range-sep']
        return self:format(formatter, from, options) .. range_sep .. self:format(formatter, to, options)
    end
end

function Formatters:range_list(text, options)
--[[
    Format a list using 'range' as the formatter.
    This is to make the range list (e.g. for page ranges) easily accessible
    as a built-in formatter.
--]]
    options.formatter = 'range'
    return self:format('list_format', text, options)
end

function Formatters:subscript(text)
--[[
    Format text as subscript
--]]
    return self:wrap_macro('textsubscript', text)
end

function Formatters:superscript(text)
--[[
    Format text as superscript
--]]
    return self:wrap_macro('textsuperscript', text)
end

-----------------------------------------------------
-----------------------------------------------------

--[[
    Initialize all built-in formatters to be hidden
    by wrapping them in a table with a `name` field
    prepended by an underscore.
--]]
for k, v in pairs(Formatters) do
    Formatters[k] = {
        name = '_'..k,
        f = v
    }
end

if formatters_opts['self-documentation'] then
--[[
    Configure the docstring formatters to create macros.
--]]
    local opts = {
        ['args'] = { 'default', lua_formatters.is_str },
        ['demo'] = { 'false', 'true', '' },
        ['demosep'] = { 'default', lua_formatters.is_str },
        ['nocomment'] = { 'false', 'true', ''}
    }
    BUILTINS:add_configuration{
        docstring_inline = {
            name = 'luaMacroDocInline',
            comment = 'Write a documentation string',
            color = 'nocolor',
            options = opts,
        },
        docstring_minted = {
            name = 'luaMacroDoc',
            comment =
                'Write a single documentation string in a minted environment',
            color = 'nocolor',
            options = opts,
        },
        docstrings_minted = {
            name = 'luaMacroDocClient',
            comment = 'Write doc strings for a whole client',
            color = 'nocolor',
            options = opts,
        }
    }
end

return BUILTINS
