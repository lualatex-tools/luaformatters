# Building `luaformatters.tex`

In order to compile the manual the following conditions have to be met:

* (of course) `luaformatters` must be properly installed
* The `minted` package must be installed
* The `Pygments` program must be installed (see `minted` manual)
* `lualatex` must be called with `--shell-escape` for `minted` to work  
  This can be done with one ouf of:
  - `lualatex --shell-escape luaformatters.tex`
  - `latexmk luaformatters.tex`

Note that `latexmk` currently seems to fail with the “Number of LaTeX
runs exceeded” error.
