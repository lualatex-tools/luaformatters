# luatemplates

`luatemplates` is a package for LuaLaTeX, designed to assist package
and document authors with the recurring task of *templating*.  It
substantially reduces the complexity of interfacing the LaTeX and the Lua
domains, making it simpler to approach the development of document preambles and
packages purely in Lua.  At the same time it assists with and encourages a
modular style of programming templates and styles.

`luatemplates` is currently approaching an initial release as `v0.8`, and testing and feedback are highly welcome. The [Issue Tracker](https://github.com/uliska/luatemplates/issues) has milestones for 0.8, 0.9 and 1.0, plus issues without milestone for "some time after ...".

Since compiling the manual imposes extra requirements there is a temporary version available at 
[Nextcloud](https://cloud.ursliska.de/s/H7FBgTccMrn1pnT) in order to make it easier to dive into the package.

*Note:* For now it is necessary to run the [`lyluatex`](https://github.com/jperon/lyluatex) package from its Github repository (not the CTAN/TeX Live release), (concretely from the `check-non-package-opt` branch (unless https://github.com/jperon/lyluatex/pull/262 has been merged).
