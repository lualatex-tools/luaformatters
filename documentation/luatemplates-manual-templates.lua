local err, warn, info, log = luatexbase.provides_module({
    name               = "luatemplates-manual-templates",
    version            = '0.8',
    date               = "2019/07/02",
    description        = "Lua module for templating, sample templates.",
    author             = "Urs Liska",
    copyright          = "2019- Urs Liska",
    license            = "GPL3",
})

--[[
    Demo configuration file for the luatemplates package's MWE.
    This file defines and returns one Lua table MANUAL with the following structure:
        MANUAL = {
            formatters = ...,
            configuration = ...,
        }
    This table will then be passed to Templates:setup to automagically produce
    the full set of LaTeX commands.
--]]

local MANUAL = lua_templates:new('manual')

MANUAL:add_formatters('Shorthands', {
    --[[
    *Shorthands* are text strings that are returned as-is.
    Basically the same could be achieved by simply using \newcommand in
    LaTeX, but the shorthands will also be available to other formatting
    functions, and they benefit from the package's color handling.
    For each shorthand a LaTeX command with the corresponding name will
    automatically be created.
    --]]
    -- Simplest form of defining shorthands (2 examples): key and string:
    -- shorthand to save typing and provide consistency, e.g. for brand names
    cary = [[Mary Flagler Cary Music Collection \emph{(Pierpont Morgan Library)}]],
    -- shorthand to ensure orthotypographic consistency
    BaB = [[B\,\&\,B]],
    -- Declaration of a 'formatter entry table'
    -- This is to show how formatters can be reused (in the 'image' macro).
    -- In a real-world project this would of course be more complex to
    -- point to a real media directory.
    mediadir = {
        comment = 'relative path to a media directory',
        f = './media',
        color = 'nocolor',
    },
    -- names must be valid for LaTeX macros:
    --emph = [[\emph{} has already been defined.]],

    -- the returned string must result in valid LaTeX code.
    -- \broken would result in an error. It can be defined but not used.
    -- Therefore it is “hidden” through the leading underscore.
    _broken = [[\emph{would result in invalid LaTeX]],
})

MANUAL:add_formatters('Styles', {
        --[[
        *Styles*: Templates with *one* mandatory argument
    --]]
        -- simple style
        textbfit = [[\textbf{\textit{<<<text>>>}}]],
        -- style with additional text element (actually used for the MWE)
        cmd = {
            f = [[\texttt{\textbf{\textbackslash <<<name>>>}}]],
            color = 'nocolor',
            comment = 'Typeset a command name (without explicit argument support)'
        },
        luavar = {
            f = [[\texttt{<<<name>>>}]],
            comment = 'A Lua name/variable'
        },
        package = {
            f = [[\texttt{<<<name>>>}]],
            comment = 'A LaTeX package, Lua module etc.',
            color = 'olive'
        },
        DV = {
            f = [[\textsc{d}\,<<<dnumber>>>]],
            color = 'cyan',
            comment = 'Deutsch-Verzeichnis (= Schubert catalogue)',
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

MANUAL:add_formatters('Templates', {
    --[[
        *Templates*: templates with more than one named field.
    --]]
        literature = {
            --[[
                Table can be nested, so commands inside get a mixedCase name:
                \literatureBook
            --]]
            book = {
                f = [[<<<title>>>\textsuperscript{(ed.\,<<<edition>>>)}]],
                args = { 'title', 'edition' },
            },
            book_alternative = {
                name = 'bookShort',
                comment = 'A book definition for inline use',
                f = [[\textbf{<<<author>>>}: \emph{<<<title>>>} (<<<year>>>)]],
                color = 'magenta',
                args = {'author', 'title', 'year'},
                -- opt does not make sense here
            },
        },
            --[[
                A template with multiple mandatory and an optional argument.
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
        -- A simple formatter with one argument.
        reverse = function (self, text, options)
            options = self:check_options(options)
            local result = text:reverse()
            if options.smallcaps then
                result = self:wrap_macro('textsc', result)
            end
            return result
        end,
        --[[
            A somewhat more complex function, although still with one
            argument only. This one makes use of a builtin formatter.
            Defined in the full table syntax, which is slightly awkward.
            I would recommend defining the function separately and
            configure it in the configuration section.
        --]]
        check_range = {
            name = 'checkRange', -- underscores can't be used in LaTeX macros
            comment = 'Demonstrate the use of built-in functions function.',
            opt = 'foo=bar',
            f = function (self, options, text)
                local processed = self:format('range', text)
                if processed ~= text then
                    text = processed .. string.format([[ (input was: \texttt{\{%s\}})]], text)
                end
                return text
            end
        },
        foo = function(self, text) return '|' .. text .. '|' end,
})

--[[
    Standalone definition of functions.
    Note that these can also assign functions to nested tables,
    but these have to be created beforehand.
--]]
function MANUAL.formatters:X(text)
    return text:gsub('.', 'X')
end

function MANUAL.formatters:Bar(text)
    local result = ''
    for i=1, #text, 1 do
        result = result .. self.foo:apply(text:sub(i, i))
    end
    return result
end

--[[
    Publish built-in formatters by using arbitrary names without underscores.
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

--[[
    Configure a single formatter.
    Here too a name field could be given, or the name alone as a string.
--]]
MANUAL:configure_formatter('reverse', {
    comment = 'Reverse the given string, optionally in small caps.'
})

return MANUAL
