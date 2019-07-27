--[[
    A real-world example taken from an actual project.
    Sparsely commented, the most interesting point is the reuse of code,
    especially the handling of local formatters.
    Note that the resulting macro names are basically German while comments
    and local names remain English.
--]]

local err, warn, info, log = luatexbase.provides_module({
    name               = "ulDissLuaConfig",
    version            = '0.9',
    date               = "2019/06/26",
    description        = "Lua module for ulDiss, Konfigurationsdaten.",
    author             = "Urs Liska",
    copyright          = "2019 - Urs Liska",
    license            = "none",
})

local lfs = require 'lfs'

local SCHUBERT = lua_formatters:new_client{
    name = 'diss',
    namespace = {
        'abb',
        'bereich',
        'gedicht',
        'musik',
        'schubert',
    }
}

--[[
    Add formatters in groups to make the input file more explicit.
--]]

SCHUBERT:add_formatters('Shorthands', {
    aao  = [[a.\,a.\,O.]],
    aga  = [[\textsc{aga}]],
    bis  = '--',
    idr  = [[i.\,d.\,R.]],
    lh   = [[l.\,H.]],
    rh   = [[r.\,H.]],
    sa   = [[s.\,a.]],
    su   = [[s.\,u.]],
    ua   = [[u.\,a.]],
    uA   = [[u.\,A.]],
    uU   = [[u.\,U.]],
    va   = [[v.\,a.]],
    zB   = [[z.\,B.]],
    ZB   = [[Z.\,B.]],
    NS   = [[Niederschrift]],
    RS   = [[\textsc{rs}]],
    nsI  = [[1.\,\textsc{ns}]],
    nsII = [[2.\,\textsc{ns}]],
})

SCHUBERT:add_formatters('Styles', {
    autor             = [[\textsc{<<<text>>>}]],
    begriff           = [[\textbfit{<<<text>>>}]],
    ulBegriff         = [[\textbfit{<<<text>>>}]],
    bibkey            = [[ (\cite{<<<key>>>})]],
    dichter           = [[\emph{<<<text>>>}]],
    liedtext          = [[\emph{\enquote{<<<text>>>}}]],
    person            = [[\textsc{<<<text>>>}]],
    textbfit          = [[\textbf{\textit{<<<text>>>}}]],
    textbfsf          = [[\textbf{\textsf{<<<text>>>}}]],
    vortragsanweisung = [[\emph{<<<text>>>}]],
    werktitel         = [[\emph{<<<text>>>}]],
    zitat             = [[\emph{<<<text>>>}]],
})

SCHUBERT:add_formatters('Formatters', {
    partref = {
        comment  = 'Reference to a section in another bookpart',
        template = [[\cref{<<<part>>>}, \vref{<<<reference>>>}]],
        args     = { 'part', 'reference' }
    },
    partrefrange = {
        comment  = 'Reference to a range in another bookpart',
        template = [[\cref{<<<part>>>}, \vrefrange{<<<from>>>}{<<<to>>>}]],
        args     = { 'part', 'from', 'to' }
    },
    todo = {
        comment  = 'Configurable TODO item',
        template = [[\textcolor{red}%
{\textbf{\textsf{[<<<options>>>] <<<anmerkung>>>}}}]],
        opt      = 'TODO: ',
    },
    xmpref = {
        comment  = [[Reference to a music example on potentially multiple pages]],
        template = [[
\cref{xmp:<<<key>>>}
\vpagerefrange{xmp:start-<<<key>>>}{xmp:<<<key>>>}]],
    },
    Xmpref = {
        comment  = "Reference to a potentially multipage music example.",
        template = [[
        \inputminted{lua}{examples/local-formatters.lua}
\Cref{xmp:<<<key>>>}
\vpagerefrange{xmp:start-<<<key>>>}{xmp:<<<key>>>}]],
    },
})


--[[
    Add local formatters, also in groups.
--]]

-- General local formatters
SCHUBERT:add_local_formatters{
    gedicht = {
        comment = 'Used within a "gedicht" environment',
        f       = [[
\setline{<<<startzeile>>>}%
\firstlinenum{<<<startzeile>>>}%
\linenumincrement{<<<intervall>>>}%
\itshape
\stanza
]],
        color   = 'nocolor'
    },

    -- General musical elements
    kontra_note        = [[\underline{<<<note>>>}]],
    noten              = [[\texttt{<<<noten>>>}]],
    opus               = [[op.\,<<<opus>>>]],
    Opus               = [[Op.\,<<<opus>>>]],
    seite              = [[S.\,<<<bereich>>>]],
    takt               = [[T.\,<<<bereich>>>]],
    tonart             = [[\emph{<<<tonart>>>}]],
    tonart_alternative = [[\emph{<<<alternative>>>/}<<<tonart>>>]],
    werknummer_sep     = [[/]],

    -- Schubert specific stuff
    bearbeitung = [[\textsc{ba}\,<<<ba>>>]],
    fassung = [[<<<fassung>>>.\,Fass.]],
    ba_fass = [[\textsc{ba}\,<<<bearbeitung>>>, Fass.\,<<<fassung>>>]],
    dv = [[\textsc{d}\\,<<<dv>>>]],
    lied = [[<<<titel>>> <<<werk>>>]],
    lied_dichter = [[<<<lied>>> \dichter{(<<<dichter>>>)}]],
    lied_nsa = [[<<<lied>>>\footnote{\nsa<<<nsa>>>.}]],
    lied_opus = [[<<<opus>>> (<<<dv>>>)]],
    nsa_band = [[\textsc{nga \lowercase{<<<serie>>>}/<<<band>>>}]],
}

--[[
    Building blocks used for inserting music examples,
    mostly in combination with the lyluatexmp package (unreleased).
--]]
SCHUBERT:add_local_formatters{
    manuskript = {
        f = [[
\begin{abbildung}<<<placement>>>%
\includegraphics<<<graphicsoptions>>>{\reporoot/abbildungen/manuskript/<<<key>>>}%
\caption{<<<caption>>><<<bibkey>>>}%
\label{<<<keytype>>>:<<<key>>>}%
\end{abbildung}%
]]},
    notenbeispiel = {
        f = [[
\lyfilemusicexample[%
<<<lyluatexoptions>>>,%
caption={<<<caption>>>},%
label={<<<keytype>>>:<<<key>>>},%
<<<lyluatexmpoptions>>>]{\reporoot/abbildungen/bsp/<<<key>>>}%
]]},
    nokey = {
        f = [[
\begin{lymusxmp}<<<placement>>>%
\bigskip
\center
%\captionsetup{listformat=xmpMissing}
\fcolorbox{red}{yellow}{%
  \parbox[c]{.7\textwidth}{~\\%
    \centering\textbf{\textsf{Kein Beispiel/Manuskript-Key angegeben}}\\[4pt]%
  }%
}%
\bigskip%
\caption{<<<caption>>>}%
\label{<<<keytype>>>:<<<key>>>}%
\end{lymusxmp}%
]]},
    nofile = {
        f = [[
\begin{lymusxmp}<<<placement>>>%
\label{<<<keytype>>>:start-<<<key>>>}
\center
\bigskip
%\captionsetup{listformat=xmpMissing}
\fcolorbox{red}{yellow}{%
  \parbox[c]{.7\textwidth}{~\\%
    \centering\textbf{\textsf{Fehlende Datei:}}\\[2pt]%
    \reporoot/abbildungen/bsp/<<<key>>>.[ly|png|jpg]\\
    \emph{Fehler oder Platzhalter}
  }%
}%
\bigskip%
\caption{<<<caption>>>}%
\label{<<<keytype>>>:<<<key>>>}%
\end{lymusxmp}%
]]}
}

--[[
    Configuration is here mostly used to map nested formatter keys
    to “flat” macro names.
    In a few instances coloring has to be suppressed.
--]]
SCHUBERT:add_configuration{
    ['abb.manuskript'] = {
        name = 'manuskript',
        color = 'nocolor',
    },
    ['abb.notenbeispiel'] = {
        name = 'notenbeispiel',
        color = 'nocolor',
    },

    ['bereich.seite'] = 'seite',
    ['bereich.takt'] =  'takt',

    ['gedicht'] = {
        name = 'gedichtKonf',
        color = 'nocolor'
    },

    ['musik.noten'] = 'noten',
    ['musik.opus'] = 'opus',
    ['musik.Opus'] = 'Opus',
    ['musik.tonart'] = 'tonart',

    ['schubert.dv'] = 'DV',
    ['schubert.lied'] = 'lied',
    ['schubert.nsa'] = 'nsa',
    ['schubert.quelle'] = 'quelle',

    ['bereich.bereich'] = 'bereich',
}



--[[
  Formatierungsfunktionen
  NOTE: `self` verweist immer auf das `Formatters`-Objekt,
  nicht auf `Formatter`.
--]]

function SCHUBERT._local:caption(options)
  local result = ''
  if options.lied then
    result = self:format('schubert.lied',
      options.lied,
      options.dv or '\\todo{NN}',
      options.liedopt or ''
    )
  end
  if options.takt then
    result = self:format('add_element',
      result,
      self:format('bereich.takt', options.takt, options.taktopt or '')
    )
  end
  if options.caption then
    result = self:format('add_element', result, options.caption)
  end
  return result
end

function SCHUBERT._local:octave(text)
    local pitch, octave = text:match('([a-z]+)([^a-z]*)')
    if octave == ',' then
        pitch = pitch:gsub("^%l", string.upper)
        octave = ''
    elseif octave == ',,' then
        pitch = self:_format('kontra_note', { note = pitch:gsub("^%l", string.upper) })
        octave = ''
    end
    return pitch..octave
end


function SCHUBERT._local:version_string(options)
--[[
Erzeuge einen String für Fassung/Bearbeitung.
Keys in der options-Tabelle sind 'ba' und 'fass'.
Wenn kein Key gefunden wird, gebe leeren String zurück.
Wenn *ein* Key gefunden wird, verwende *nur* dessen Wert.
Wenn *beide* Keys gefunden werden, erzeuge detaillierten Text.
--]]
    options = self:check_options(options)
	local bearbeitung
	local fassung
	bearbeitung = options.ba
	fassung = options.fass
	-- Kein Parameter angegeben: Gebe leeren String zurück
	if not bearbeitung and not fassung then return ''
	-- Nur BA oder nur Fassung: Nutze nur das Argument
  elseif bearbeitung and not fassung then
		return self:_format('bearbeitung', { ba = bearbeitung })
	elseif fassung and not bearbeitung then
		return self:_format('fassung', { fassung = fassung })
	else
    return self:_format('ba_fass', {
      bearbeitung = bearbeitung,
      fassung = fassung
    })
  end
end

function SCHUBERT._local.musik:werknummer(text)
    return text:gsub(
    ' ', ''):gsub( -- Vereinheitlichung
    '/', ','):gsub(-- Vereinheitlichung
    ',', self:_format('werknummer_sep'))   -- Darstellung
end



--[[

--]]


function SCHUBERT.formatters:bibkey(options)
  if not options.bibkey then return '' end
  return self:format('bibkey', {key = options.bibkey })
end

function SCHUBERT.formatters:gedicht(options)
  options = self:check_options(options, true)
  local startzeile = options.startzeile or 1
  local intervall = options.intervall or 1000
  return self:_format('gedicht', {
    startzeile = startzeile,
    intervall = intervall,
  })
end

function SCHUBERT.formatters.bereich:bereich(text)
  return self:format('list_format', text, { formatter = 'range' })
end

function SCHUBERT.formatters.bereich:seite(text)
    return self:_format('seite', { bereich = self:format('bereich.bereich', text) })
end

function SCHUBERT.formatters.bereich:takt(text, options)
    options = self:check_options(options)
    options.formatter = 'range'
    local bereich = self:format('list_format', text, options)
    local result = self:_format('takt', bereich)
    local version = self:_format('version_string', options)
    if version ~= '' then
        result = self:format('add_superscript', result, version)
    end
    return result
end

function SCHUBERT.formatters.musik:manuskripttyp(typ)
    local formatter = self:formatter(typ)
    if formatter then return formatter:apply() else return typ end
end

function SCHUBERT.formatters.musik:noten(text)
    return self:_format('noten', self:_format('octave', text))
end

function SCHUBERT.formatters.musik:opus(text)
    return self:_format('opus', self:_format('musik.werknummer', text))
end

function SCHUBERT.formatters.musik:Opus(text)
    return self:_format('Opus', self:_format('musik.werknummer', text))
end

function SCHUBERT.formatters.musik:tonart(options, tonart)
    local ton = self:_format('tonart', tonart)
    local content = ton
    if options and options ~= '' then
        content = self:_format('tonart_alternative', {
            alternative = options,
            tonart = ton
        })
    end
    return content
end

function SCHUBERT.formatters.schubert:dv(dv)
    return self:_format('dv', self:_format('musik.werknummer', dv))
end

function SCHUBERT.formatters.schubert:lied(titel, dv, options)
    --[[
    TODO: simplify the coding with better templates
    --]]
    titel = self:format('werktitel', titel)
    werk = self:format('schubert.dv', dv)
    options = self:check_options(options)
    opus = ''
    if options.fass or options.ba then
        werk = self:format('add_superscript', werk,
        self:_format('version_string', options), true)
    end
    if options.opus then
        opus = self:format('musik.opus', options.opus, 'musik.opus')
        werk = self:_format('lied_opus', {
            opus = opus,
            dv = werk
        })
    end
    local result = self:_format('lied', {
        titel = titel,
        werk = werk
    })
    if options.typ then
        result = self:format('add_element', result, self:format('musik.manuskripttyp', options.typ), ', ')
    end
    if options.dichter then
        result = self:_format('lied_dichter', {
            lied = result,
            dichter = options.dichter
        })
    end
    if options.nsa then
        result = self:_format('lied_nsa', {
            lied = result,
            nsa = options.nsa
        })
    end
    return result
end

function SCHUBERT.formatters.schubert:nsa(options, band, seiten)
    options = self:check_options(options)
    local serie = options.serie or 'iv'
    local result = self:_format('nsa_band', {
        serie = serie,
        band = band
    })
    if options.nummer then
        result = self:format('add_element', result, options.nummer, ', ')
    end
    if options.abschnitt then
        result = self:format('add_element', result, options.abschnitt, ', ')
    end
    result = self:format('add_element',
    result,
    self:format('bereich.seite', seiten),
    ', ')
    return result
end

function SCHUBERT.formatters.schubert:quelle(options, sigel)
  return self:format('add_superscript',
    sigel, self:_format('version_string', options))
end

-- TODO: Temporäre Implementierung???
function SCHUBERT:check_key(options, keytype)
  if not options.key then return 'abb.nokey' end
  local file_base
  if keytype == 'xmp' then
    if lfs.isfile(diss_opts.root..'/abbildungen/bsp/'..options.key..'.ly') then
      return 'notenbeispiel'
    else return 'nofile' end
  else
    file_base = diss_opts.root..'/abbildungen/manuskript/'..options.key
    if lfs.isfile(file_base..'.png') or lfs.isfile(file_base..'.jpg')
    then
      return 'manuskript'
    else return 'nofile' end
  end
end

function SCHUBERT.formatters.abb:manuskript(options)
    options = diss_opts:check_local_options(options, true)
    local result = self:_format(self:check_key(options, 'fig'), {
        key = options.key or '',
        bibkey = self:format('bibkey', options),
        caption = self:_format('caption', options),
        placement = self:wrap_optional_arg(options.placement),
        graphicsoptions = self:wrap_optional_arg(options.graphics),
        keytype = 'fig'
    })
    return result
end

function SCHUBERT.formatters.abb:notenbeispiel(options)
    options = self:check_options(options)
    local key = options.key or ''
    local lyluatexmp
    if options.lyluatexmp then
        lyluatexmp = options.lyluatexmp..',startlabel=xmp:start-'..key
    else
        lyluatexmp = 'startlabel=xmp:start-'..key
    end
    local lyluatex = ''
    if options.lyluatex then
        lyluatex = self:wrap_kv_option('lyluatex', options.lyluatex)
    end

    local result = self:_format(self:check_key(options, 'xmp'), {
        key = key,
        caption = self:_format('caption', options),
        placement = self:wrap_optional_arg(options.placement),
        lyluatexoptions = lyluatex,
        lyluatexmpoptions = lyluatexmp,
        keytype = 'xmp'
    })
    return result
end

return SCHUBERT
