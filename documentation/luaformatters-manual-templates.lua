local err, warn, info, log = luatexbase.provides_module({
    name               = "luaformatters-manual-templates",
    version            = '0.8',
    date               = "2019/07/02",
    description        = "Lua module for templating, sample templates.",
    author             = "Urs Liska",
    copyright          = "2019- Urs Liska",
    license            = "GPL3",
})

--[[
    Demo configuration file for the luaformatters package's MWE.
    This module defines and returns one FormattersTable and returns it
    The returned table will then be passed to Formatters:add()
    to automagically produce the full set of LaTeX commands.
--]]

-- Create a new FormattersTable instance by referencing the global
-- `lua_formatters` variable
local MANUAL = lua_formatters:new('manual')

-- Add formatters, grouped by category.
-- (Note that the first string does have no meaning, it's just a comment)
MANUAL:add_formatters('Shorthands', {
    --[[
        Simplest form of defining shorthands:
        key (converted to macro name) and resulting string:
    --]]
    BaB = [[B\,\&\,B]],

    --[[
        Note that a template (or function, for that matter) declared
        by luaformatters may *use* other macros that have also been
        produced by luaformatters:
    --]]
    luaformatters = [[\package{luaformatters}]],

    --[[
        Resulting macro names must be possible.
    --]]
    -- emph = [[\emph{} has already been defined.]],

    --[[
        Declaration as a 'formatter entry table'.
        Mandatory field: `f`, everything else is inferred if necessary
    --]]
    -- This macro is (re)used in the `image` macro.
    -- 'nocolor' is used because we will want the bare text to be used in LaTeX.
    mediadir = {
        f = './media',
        comment = 'relative path to a media directory',
        color = 'nocolor',
    },

    --[[
        Hide the formatter.
        This formatter will be accessible through self:format('hidden'),
        but no LaTeX macro created.
    --]]
    hidden = {
        f = [[This would only be used by other Formatters
              but not from LaTeX]],
        name = '_hidden',
    },
})

MANUAL:add_formatters('Styles (templates with one mandatory argument)', {
        -- simple style
        textbfit = [[\textbf{\textit{<<<text>>>}}]],
        -- style with additional textual element
        cmd = {
            f = [[\texttt{\textbf{\textbackslash <<<name>>>}}]],
            color = 'nocolor',
            comment = 'Typeset a command name (without explicit argument support)'
        },
        -- includes an <<<options>>> field plus *one* named field,
        -- can therefore be inferred without an 'args' field.
        -- 'opt' sets default value for optional macro argument
        image = {
            f = [[\includegraphics[<<<options>>>]{\mediadir/<<<image>>>}]],
            color = 'nocolor',
            opt = 'width=2cm',
        },
})

MANUAL:add_formatters('Formatters (templates with more than one argument)', {
    --[[
        A template with multiple mandatory and one optional argument.
        The optional argument is indicated by an 'options' replacement
        field.  Since there is more than one mandatory argument, the
        'args' table has to be provided (note that the 'image' field is
        used twice in the template).  'nocolor' is required here because
        a 'figure' environment can't be wrapped in a \textcolor command.
    --]]
    floatImage = {
        f = [[
\begin{figure}
\centering
\includegraphics[<<<options>>>]{\mediadir/<<<image>>>}
\caption{<<<caption>>>}
\label{fig:<<<image>>>}
\end{figure}
]],
        args = {'image', 'caption'},
        color = 'nocolor',
    },
    --[[
        Table can be nested, so commands inside get a mixedCase name:
        \literatureBook
    --]]
    literature = {
        book = {
            f = [[<<<title>>>\textsuperscript{(ed.\,<<<edition>>>)}]],
            args = { 'title', 'edition' },
        },
    },
})

MANUAL:add_formatters('functions', {
    --[[
        *Formatter functions*
        These *can* be specified directly within the table
        constructor, but for all but the simplest forms it is usually
        more idiomatic to use the standalone function definition as
        shown later in this file.
        Note that in this way of definition the 'self' argument has to be
        specified explicitly, without the : notation.
    --]]
    -- a simple function with one named argument
    foo = function(self, text) return '|' .. text .. '|' end,
})


MANUAL:add_formatter('literature.book_alternative', {
    name = 'bookShort',
    comment = 'A book definition for inline use',
    f = [[\textbf{<<<author>>>}: \emph{<<<title>>>} (<<<year>>>)]],
    color = 'magenta',
    args = {'author', 'title', 'year'},
    -- opt does not make sense here
})

--[[
    By default formatters can only be added to existing nodes in the
    `formatters` subtable (this can be switched off by providing
    `strict = false` in the new() constructor).
    `provide_namespace()` takes an array of keys and creates the corresponding
    nodes for subsequent additions to work.
--]]
MANUAL:provide_namespace{
    'music.composer',
    'music.work'
}

--[[
    The following two formatters can be added
    thanks to the previous namespace provision.
--]]
MANUAL:add_formatter('music.composer.name', {
    f = [[\emph{<<<name>>>}]],
    color = 'magenta',
})

MANUAL:add_formatter('music.work.source', {
    f = [[\textsc{<<<abbreviation>>>}]],
    color = 'olive',
})

--[=[
    The following would fail because 'music.locations' is not in the namespace
    (try uncommenting and see the error message)
MANUAL:add_formatter('music.locations.concert_hall', [[\textbf{<<<name>>>}]])
--]=]

--[[
    Standalone definition of functions.
    Note that these can also assign functions to nested tables,
    but these have to be created beforehand.
--]]
function MANUAL.formatters:X(text)
-- A simple formatter with one argument
    return text:gsub('.', 'X')
end

function MANUAL.formatters:reverse(text, options)
--[[
    A slightly more complex function with one named and an optional argument.
    The `options` string has automatically been parsed into a table with
    self:check_options(options)
--]]
    local result = text:reverse()
    if options.upper then
        result = result:upper()
    end
    return result
end

--[[
    Configure a single formatter.
    Add the given fields to the formatter entry table.
    If this includes the `name` property (or the second argument is a string)
    the formatter is renamed (and possibly published through that).
--]]
MANUAL:configure_formatter('reverse', {
    comment = 'Reverse the given string, optionally in small caps.'
})

--[[
    Publish built-in formatters by using arbitrary names without underscores
    (NOTE: the built-in formatters have names that (unlike their keys) have
     leading underscores).
    An entry's value may either be the new name or a formatter entry table.
--]]
MANUAL:add_configuration('Publish built-in formatters', {
    list_format = 'names',
    range = 'range',
    range_list = {
        name = 'pages',
        color = 'magenta'
    },
})

return MANUAL
