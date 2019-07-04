--[[
    Minimal configuration file showing the bare minimum of all features
--]]

-- local variable, this is what will be returned from the module
local CONFIG = {
    -- Prefix to auto-generated macro names
    prefix = '',
    -- Define accepted formatter hierarchy
    namespace = {
        literature = {},
        music = {}
    },
    -- argument-less templates
    shorthands = {
        -- formatter as string template
        BaB = [[B\,\&\,B]],
        -- formatter as entry table
        -- shorthand with special color
        mediadir = {
            comment = 'relative path to a media directory',
            f = './media',
            color = 'nocolor',
        },
        -- hidden formatter, available for use in Lua
        _short = [[My hidden shorthand.]],
    },
    -- templates with *one* argument
    styles = {
        -- simple “style”
        textbfit = [[\textbf{\textit{<<<text>>>}}]],
        -- style plus additional elements
        cmd = {
            f = [[\texttt{\textbf{\textbackslash <<<name>>>}}]],
            color = 'nocolor',
            comment = 'Typeset a command name (without explicit argument support)'
        },
        -- template with optional argument
        image = {
            f = [[\includegraphics[<<<options>>>]{\mediadir/<<<image>>>}]],
            color = 'nocolor',
            opt = 'width=2cm',
        },
    },
    -- templates with multiple arguments
    templates = {
        -- nested hierarchy, accessed as 'literature.book'
        literature = {
            book = {
                f = [[<<<title>>>\textsuperscript{(ed.\,<<<edition>>>)}]],
                args = { 'title', 'edition' },
            },
        },
        -- assign alternative macro name (default would be \literatureBook)
        book = {
            name = 'bookShort',
            f = [[\textbf{<<<author>>>}: \emph{<<<title>>>} (<<<year>>>)]],
            args = {'author', 'title', 'year'},
        },
    },
    -- formatting functions
    formatters = {
        -- functions *can* be defined in the table constructor
        reverse = function (self, text) return text:reverse() end,
        -- definition with a formatter entry
        check_range = {
            name = 'checkRange', -- underscores can't be used in LaTeX macros
            opt = 'foo=bar',
            f = function (self, options, text)
                local processed = self:range(text)
                if processed ~= text then
                    text = processed .. string.format([[
 (input was: \texttt{\{%s\}})]], text)
                end
                return text
            end
        },
    },
    -- expose built-in formatters, add configuration
    configuration = {
        -- create macros from built-in formatters
        range = 'range',
        pages = 'range_list',
        -- specify a function implemented separately
        XXX = {
            key = 'XXX',
            comment = 'Replace all characters with X.'
            color = 'green',
        }
    }
}

-- “regular” function definition, but without entry details
function CONFIG.formatters:XXX(text)
    return text:gsub('.', 'X')
end

return CONFIG
