# luaformatters

`luaformatters` is a LuaLaTeX package assisting package
(and document) authors bridging the gap between the LaTeX and the Lua domains.  It allows to declare and program “formatters” completely in Lua files and have the corresponding LaTeX macros be generated automatically.  This reduces the complexity of writing Lua-based packages and encourages (and simplifies) code reuse and a modular programming style.

`luaformatters` is currently approaching an initial release as `v0.8`, and testing and feedback are highly welcome. The [Issue Tracker](https://github.com/uliska/luaformatters/issues) has milestones for 0.8, 0.9 and 1.0, plus issues without milestone for "some time after ...".

*Note:* For now it is necessary to make the [`luaoptions`](https://github.com/lualatex-tools/luaoptions) package from its Github repository availabe to LuaLaTeX.  As soon as `luaformatters` has been released to CTAN we'll make sure the packages are in sync and can be used from CTAN or TEX Live.
