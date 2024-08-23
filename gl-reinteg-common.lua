local export = {}

local romut_module = "Module:romance utilities"

local rsubn = mw.ustring.gsub
local rfind = mw.ustring.find
local rmatch = mw.ustring.match

local unaccented_vowel = "aeiouàAEIOUÀ"
local accented_vowel = "áéíóúýâêôÁÉÍÓÚÝÂÊÔ"
local maybe_accented_vowel = "ãõÃÕ"
local vowel = unaccented_vowel .. accented_vowel .. maybe_accented_vowel
local V = "[" .. vowel .. "]"
export.V = V
local AV = "[" .. accented_vowel .. "]"
export.AV = AV
local NAV = "[^" .. accented_vowel .. "]"
export.NAV = NAV
local C = "[^" .. vowel .. ".]"
export.C = C
local remove_accent = {
	["á"]="a", ["é"]="e", ["í"]="i", ["ó"]="o", ["ú"]="u", ["ý"]="y", ["â"]="a", ["ê"]="e", ["ô"]="o",
	["Á"]="A", ["É"]="E", ["Í"]="I", ["Ó"]="O", ["Ú"]="U", ["Ý"]="Y", ["Â"]="A", ["Ê"]="E", ["Ô"]="O"
}
export.remove_accent = remove_accent

-- version of rsubn() that discards all but the first return value
local function rsub(term, foo, bar)
	local retval = rsubn(term, foo, bar)
	return retval
end

export.rsub = rsub

-- version of rsubn() that returns a 2nd argument boolean indicating whether
-- a substitution was made.
local function rsubb(term, foo, bar)
	local retval, nsubs = rsubn(term, foo, bar)
	return retval, nsubs > 0
end

export.rsubb = rsubb

-- apply rsub() repeatedly until no change
local function rsub_repeatedly(term, foo, bar)
	while true do
		local new_term = rsub(term, foo, bar)
		if new_term == term then
			return term
		end
		term = new_term
	end
end

export.rsub_repeatedly = rsub_repeatedly

function export.remove_final_accent(stem)
	return rsub(stem, "(" .. AV .. ")(" .. C .. "*)$", function(v, c) return (remove_accent[v] or v) .. c end)
end

local prepositions = {
	-- a + optional article
	"a ",
	"às? ",
	"aos? ",
	-- com + optional article
	"com ",
	"coa?s? ",
	"d'",
	-- de + optional article
	"de ",
	"d[oa]s? ",
	"d'",
	-- en/em + optional article
	"em ",
	"n[oa]s? ",
	-- por + optional article
	"por ",
	"pol[oa]s? ",
	-- others
	"para ",
	"at[áé] ",
	"com[oa] ",
	"entre ",
	"se[nm] ",
	"sob? ",
	"sobre ",
}

local function call_handle_multiword(term, special, make_fun, fun_name)
	local retval = require(romut_module).handle_multiword(term, special, make_fun, prepositions)
	if retval then
		if #retval ~= 1 then
			error("Internal error: Should have one return value for " .. fun_name .. ": " .. table.concat(retval, ","))
		end
		return retval[1]
	end
	return nil
end

local function make_try(word)
	return function(from, to)
		local newval, changed = rsubb(word, from, to)
		if changed then
			return newval
		end
		return nil
	end
end

function export.make_plural(term, special)
	local retval = call_handle_multiword(term, special, export.make_plural, "make_plural")
	if retval then
		return retval
	end

	local try = make_try(term)
	-- This is ported from [[Module:pt-common]] and based off of http://agal-gz.org/faq/doku.php?id=pt_agal:normas:norma_da_agal:morfologia:o_nome.
	return
		try("ão$", "ões") or
		try("aõ$", "oens") or
		try("(" .. AV .. ".*)[ei]l$", "%1eis") or -- final unstressed -el or -il
		try("el$", "éis") or -- final stressed -el
		try("il$", "is") or -- final stressed -il
		try("(" .. AV .. ".*)ol$", "%1ois") or -- final unstressed -ol
		try("ol$", "óis") or -- final stressed -ol
		try("(" .. V .. ")l$", "%1is") or -- any other vowel + -l
		try("m$", "ns") or -- final -m
		try("(" .. V .. ")$", "%1s") or -- final vowel
		try("([ºª])$", "%1s") or -- ordinal indicator
		try("([íú]s)$", "%1es") or -- [[país]] -> países
		try("(" .. AV .. ")s$", function(av) return (remove_accent[av] or av) .. "ses" end) or -- final -ês, -ós etc.
		try("^(" .. NAV .. "*" .. C .. "[ui]s)$", "%1es") or -- final stressed -us or -is after consonant
		try("^(" .. NAV .. "*[aeo][ui]s)$", "%1es") or -- final stressed diphthong + -s e.g. [[deus]]
		try("([aeo])iz$", "%1ízes") or -- [[raiz]] -> raízes
		try("([aeo])uz$", "%1úzes") or -- same for u; not sure if there are any examples
		try("([rzn])$", "%1es") or -- final -r, -z, -n: [[hífen]], [[flor]], [[pior]], [[cruz]], [[rapaz]]
		try("([sx])$", "%1") or -- unstressed final -s, final cluster with -s or final -x: no change
		term .. "s"
end

function export.make_feminine(term, is_noun, special)
	local retval = call_handle_multiword(term, special, function(term) return export.make_feminine(term, is_noun) end,
		"make_feminine")
	if retval then
		return retval
	end

	local try = make_try(term)

	-- This is ported from [[Module:pt-common]] and based off of http://agal-gz.org/faq/doku.php?id=pt_agal:normas:norma_da_agal:morfologia:o_nome.
	return
		-- Exceptions: [[afegão]] (afegã), [[alazão]] (alazã), [[alemão]] (alemã), [[ancião]] (anciã),
		--             [[anglo-saxão]] (anglo-saxã), [[beirão]] (beirã/beiroa), [[bretão]] (bretã), [[cão]] (cã),
		--             [[castelão]] (castelã/castelona[rare]/casteloa[rare]), [[catalão]] (catalã), [[chão]] (chã),
		--             [[cristão]] (cristã), [[fodão]] (fodão since from [[foda]]), [[grão]] (grã), [[lapão]] (lapoa),
		--             [[letão]] (letã), [[meão]] (meã), [[órfão]] (órfã), [[padrão]] (padrão), [[pagão]] (pagã),
		--             [[paleocristão]] (paleocristã), [[parmesão]] (parmesã), [[romão]] (romã), [[são]] (sã),
		--             [[saxão]] (saxã), [[temporão]] (temporã), [[teutão]] (teutona/teutã/teutoa), [[vão]] (vã),
		--             [[varão]] (varoa), [[verde-limão]] (invariable), [[vilão]] (vilã/viloa)
		try("ám$", "á") or
		try("ao$", "á") or
		try("om$", "ona") or
		try("ão$", "ona") or
		try("o$", "a") or
		-- ordinal indicator
		try("º$", "ª") or
		-- [[francês]], [[português]], [[inglês]], [[holandês]] etc.
		try("ês$", "esa") or
		-- [[francez]], [[portuguez]], [[inglez]], [[holandez]] (archaic)
		try("ez$", "eza") or
		-- adjectives in:
		-- * [[-ador]], [[-edor]] ([[amortecedor]], [[comovedor]], etc.), [[-idor]] ([[inibidor]], etc.)
		-- * -tor ([[condutor]], [[construtor]], [[coletor]], etc.)
		-- * -sor ([[admissor]], [[censor]], [[decisor]], etc.)
		-- but not:
		-- * [[anterior]]/[[posterior]]/[[inferior]]/[[maior]]/[[pior]]/[[melhor]]
		-- * [[bicolor]]/[[incolor]]/[[multicolor]]/etc., [[indolor]], etc.
		try("([dts][oô]r)$", "%1a") or
		-- [[amebeu]], [[aqueu]], [[aquileu]], [[arameu]], [[cananeu]], [[cireneu]], [[egeu]], [[eritreu]],
		-- [[europeu]], [[galileu]], [[indo-europeu]]/[[indoeuropeu]], [[macabeu]], [[mandeu]], [[pigmeu]],
		-- [[proto-indo-europeu]]
		-- Exceptions: [[judeu]] (judia), [[sandeu]] (sandia)
		try("eu$", "eia") or
		is_noun and try("e$", "a") or
		-- note: [[espanhol]] (espanhola), but this is the only case in ''-ol'' (vs. [[bemol]], [[mongol]] with no
		-- change in the feminine)
		term
end

function export.make_masculine(term, special)
	local retval = call_handle_multiword(term, special, export.make_masculine, "make_masculine")
	if retval then
		return retval
	end

	local try = make_try(term)

	return
		try("([dts])ora$", "%1or") or
		try("a$", "o") or
		-- ordinal indicator
		try("ª$", "º") or
		term
end

-- FIXME: Next two copied from [[Module:es-common]]. Move to a utilities module.

-- Add links around words. If multiword_only, do it only in multiword terms.
function export.add_links(term, multiword_only)
	if term == "" or term == " " then
		return term
	end
	if not term:find("%[%[") then
		if rfind(term, "[%s%p]") then --optimization to avoid loading [[Module:headword]] on single-word terms
			local m_headword = require("Module:headword")
			if m_headword.head_is_multiword(term) then
				term = m_headword.add_multiword_links(term)
			end
		end
		if not multiword_only and not term:find("%[%[") then
			term = "[[" .. term .. "]]"
		end
	end
	return term
end


function export.strip_redundant_links(term)
	-- Strip redundant brackets surrounding entire term.
	return rmatch(term, "^%[%[([^%[%]]*)%]%]$") or term
end

return export
