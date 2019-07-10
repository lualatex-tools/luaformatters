--[[
    Basic configuration file showing most features but with minimal
    code and comments.
--]]

local CONFIG = {
    -- Prefix to auto-generated macro names
    prefix = '',
    formatters = {
    -- argument-less templates
        -- declare as string template
        BaB = [[B\,\&\,B]],
        -- declare as formatter entry table
        mediadir = {
            comment = 'relative path to a media directory',
            f = './media',
            color = 'nocolor',
        },
        -- hidden formatter, no LaTeX macro created
        _short = [[My hidden shorthand.]],
    -- templates with *one* argument
        -- style plus additional elements
        cmd = {
            f = [[\texttt{\textbf{\textbackslash <<<name>>>}}]],
            color = 'nocolor',
            comment = 'Typeset a command name (without explicit argument support)'
        },
        -- with optional argument (default value provided)
        image = {
            f = [[\includegraphics[<<<options>>>]{\mediadir/<<<image>>>}]],
            color = 'nocolor',
            opt = 'width=2cm',
        },
    -- templates with multiple arguments
        -- nested hierarchy, accessed as 'literature.book' or `\literatureBook`
        literature = {
            -- args is required to specify order of >1 mandatory arguments
            book = {
                f = [[<<<title>>>\textsuperscript{(ed.\,<<<edition>>>)}]],
                args = { 'title', 'edition' },
            },
        -- assign alternative macro name (default would be \literatureBookShort)
            book_short = {
                name = 'bookShort',
                f = [[\textbf{<<<author>>>}: \emph{<<<title>>>} (<<<year>>>)]],
                args = {'author', 'title', 'year'},
            },
        },
    -- formatter functions defined in the table constructor
        reverse = function (self, text) return text:reverse() end,
        -- definition with a formatter entry
        check_range = { -- will produce the macro \checkRange
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
        -- configure a function implemented separately
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
