local err, warn, info, log = luatexbase.provides_module({
    name               = "luatemplates-manual-config",
    version            = '0.8',
    date               = "2019/07/02",
    description        = "Lua module for templating, sample templates.",
    author             = "Urs Liska",
    copyright          = "2019- Urs Liska",
    license            = "GPL3",
})

--[[
    Demo configuration file for the luatemplates package's MWE.
    This file defines and returns one Lua table CONFIG with the following structure:
        CONFIG = {
            shorthands = {},
            styles = {},
            templates = {},
            mapping = {},
            formatters = {},
        }
    This table will then be passed to Templates:setup to automagically produce
    the full set of LaTeX commands.
    It is not necessary to supply all of these, only those that are needed.
    Alternatively it is also possible to supply all or some formatters after
    the setup (which may be useful for modular or programmatically generated
    structures), but this is not covered in the MWE.

    `shorthands`, `styles` and `templates` (basically) consist of strings with
    names (except for optional color handling).
    `mapping` contains specifications for more complex commands.
    `formatters` contains formatting *functions*. These could equally be
    defined directly in the table constructor, but it is more straightforward
    and maintainable to define them later with
        function CONFIG.formatters:NAME()
    (see below for details.)
--]]

local CONFIG = {
    --[[
        If present all generated macros are prefixed with this string,
        which may be useful for writing packages to avoid name clashes with
        other packages.
    --]]
    prefix = '',
    --[[
        The namespace is applied to all categories, and all templates and
        formatter functions must adhere to them (i.e. have to be stored in
        table hierarchies matching the namespace).  Macro names are automatically
        generated from the namespace, replacing the dot structure with mixed
        case, so `literature.book` will by default produce the macro
        \literatureBook.
        Arbitrary nesting depth is possible, but all “leaves” should be
        empty tables because this structure is used to validate the
        input structure of the actual formatters.
    --]]
    namespace = {
        literature = {},
        music = {}
    },
    --[[
        *Shorthands* are text strings that are returned as-is.
        Basically the same could be achieved by simply using \newcommand in
        LaTeX, but the shorthands will also be available to other formatting
        functions, and they benefit from the package's color handling.
        For each shorthand a LaTeX command with the corresponding name will
        automatically be created.
    --]]
    shorthands = {
        -- Simplest form of defining shorthands (2 examples): key and string:
        -- shorthand to save typing and provide consistency, e.g. for brand names
        cary = [[Mary Flagler Cary Music Collection \emph{(Pierpont Morgan Library)}]],
        -- shorthand to ensure orthotypographic consistency
        BaB = [[B\,\&\,B]],
        -- This is to show how formatters can be reused.  In a real-world
        -- project this would of course be more complex to point to a real
        -- media directory
        mediadir = {
            comment = 'relative path to a media directory',
            f = './media',
            color = 'nocolor',
        },
        --[[
            Regular form as a table:
            - f (mandatory) is the formatter.
            - color: optional color.
              If not provided 'default' is used from the package Options
              Special value 'nocolor' suppresses all coloring
            - comment
              Documents *here*, but is also used for external documentation
            Further options:
            - name (string): Override generated macro name
            - args (array table). Not used in shorthands
            - opt (string). Default value for optional argument. Not used here
        --]]
        -- shorthand with special color
        alert = {
            f = [[\textbf{!!!!!}]],
            color = 'red',
            comment = 'a red bold sequence of exclamation points'
        },
        -- names must be valid for LaTeX macros:
        --illegal_name = [[LaTeX commands can't have underscores]],
        -- commands must not already be defined:
        --emph = [[\emph{} has already been defined.]],
        -- the returned string must result in valid LaTeX code.
        -- \broken would result in an error. It can be defined but not used.
        _broken = [[\emph{would result in invalid LaTeX]],
    },
    --[[
        *Styles*
    --]]
    styles = {
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
        -- specify specific color ("D" = Deutsch-Verzeichnis = Schubert catalogue)
        DV = {
            f = [[\textsc{d}\,<<<dnumber>>>]],
            color = 'cyan',
            comment = 'Deutsch-Verzeichnis',
        },
        image = {
            f = [[\includegraphics[<<<options>>>]{\mediadir/<<<image>>>}]],
            color = 'nocolor',
            opt = 'width=2cm',
        },
    },
    templates = {
        literature = {
            book = {
                f = [[<<<title>>>\textsuperscript{(ed.\,<<<edition>>>)}]],
                args = { 'title', 'edition' },
            },
        },
        book = {
            name = 'bookShort',
            comment = 'A book definition for inline use',
            f = [[\textbf{<<<author>>>}: \emph{<<<title>>>} (<<<year>>>)]],
            color = 'magenta',
            args = {'author', 'title', 'year'},
            -- opt does not make sense here
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
    },
    --[[
        Formatting functions *can* be specified directly within the table
        constructor, but for all but the simplest forms it is usually
        more idiomatic to use the standalone function definition as
        shown later in this file.
        Note that in this way of definition the 'self' argument has to be
        specified explicitly, without the : notation.
    --]]
    formatters = {
        -- A simple formatter with one argument.
        reverse = --function (self, text) return text:reverse() end,
        function (self, text, options)
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
                local processed = self:range(text)
                if processed ~= text then
                    text = processed .. string.format([[ (input was: \texttt{\{%s\}})]], text)
                end
                return text
            end
        },
    },
    configuration = {
        names = 'list_format',
        range = 'range',
        pages = 'range_list',
        reverse = {
            key = 'reverse',
            comment = 'Reverse the given string, optionally in small caps.'
        }
    }
}

function CONFIG.formatters:X(text)
    return text:gsub('.', 'X')
end



return CONFIG
