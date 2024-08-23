local export = {}

local romut_module = "Module:romance utilities"
local strutils_module = "Module:string utilities"

local m_str_utils = require(strutils_module)

local concat = table.concat
local rsubn = m_str_utils.gsub
local rfind = m_str_utils.find
local rmatch = m_str_utils.match

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
	return rsub(stem, "(" .. AV .. ")$", function(v) return remove_accent[v] or v end)
end

local prepositions = {
	-- a + optional article
	"a ",
	"às? ",
	"aos? ",
	-- de + optional article
	"de ",
	"d[oa]s? ",
	"d'",
	-- em + optional article
	"em ",
	"n[oa]s? ",
	-- por + optional article
	"por ",
	"pel[oa]s? ",
	-- others
	"até ",
	"com ",
	"como ",
	"entre ",
	"para ",
	"sem ",
	"sob ",
	"sobre ",
}

local function call_handle_multiword(form, special, make_fun, fun_name)
	local retval = require(romut_module).handle_multiword(form, special, make_fun, prepositions)
	if retval then
		if #retval ~= 1 then
			error("Internal error: Should have one return value for " .. fun_name .. ": " .. concat(retval, ","))
		end
		return retval[1]
	end
	return nil
end

function export.make_plural(form, special)
	local retval = call_handle_multiword(form, special, export.make_plural, "make_plural")
	if retval then
		return retval
	end

	local function try(from, to)
		local newform, changed = rsubb(form, from, to)
		if changed then
			form = newform
		end
		return changed
	end

	-- This is ported from the former [[Module:pt-plural]] except that the old code sometimes returned nil (final -ão
	-- other than -ção and -são, final consonant other than [lrmzs]), whereas we always return a default plural
	-- (all -ão -> ões, all final consonants other than [lrmzs] are left unchanged).
	local changed = try("ão$", "ões") or
		try("aõ$", "oens") or
		try("(" .. AV .. ".*)[ei]l$", "%1eis") or -- final unstressed -el or -il
		try("el$", "éis") or -- final stressed -el
		try("il$", "is") or -- final stressed -il
		try("(" .. AV .. ".*)ol$", "%1ois") or -- final unstressed -ol
		try("ol$", "óis") or -- final stressed -ol
		try("(" .. V .. ")l$", "%1is") or -- any other vowel + -l
		try("m$", "ns") or -- final -m
		try("([rz])$", "%1es") or -- final -r or -z
		try("(" .. V .. ")$", "%1s") or -- final vowel
		try("([ºª])$", "%1s") or -- ordinal indicator
		try("(" .. AV .. ")s$", function(av) return (remove_accent[av] or av) .. "ses" end) or -- final -ês, -ós etc.
		try("^(" .. NAV .. "*" .. C .. "[ui]s)$", "%1es") -- final stressed -us or -is after consonant

	return form
end

function export.make_feminine(form, special)
	local retval = call_handle_multiword(form, special, export.make_feminine, "make_feminine")
	if retval then
		return retval
	end

	local function try(from, to)
		local newform, changed = rsubb(form, from, to)
		if changed then
			form = newform
		end
		return changed
	end

	local changed =
		-- Exceptions: [[afegão]] (afegã), [[alazão]] (alazã), [[alemão]] (alemã), [[ancião]] (anciã),
		--             [[anglo-saxão]] (anglo-saxã), [[beirão]] (beirã/beiroa), [[bretão]] (bretã), [[cão]] (cã),
		--             [[castelão]] (castelã/castelona[rare]/casteloa[rare]), [[catalão]] (catalã), [[chão]] (chã),
		--             [[cristão]] (cristã), [[fodão]] (fodão since from [[foda]]), [[grão]] (grã), [[lapão]] (lapoa),
		--             [[letão]] (letã), [[meão]] (meã), [[órfão]] (órfã), [[padrão]] (padrão), [[pagão]] (pagã),
		--             [[paleocristão]] (paleocristã), [[parmesão]] (parmesã), [[romão]] (romã), [[são]] (sã),
		--             [[saxão]] (saxã), [[temporão]] (temporã), [[teutão]] (teutona/teutã/teutoa), [[vão]] (vã),
		--             [[varão]] (varoa), [[verde-limão]] (invariable), [[vilão]] (vilã/viloa)
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
		try("eu$", "eia")

	-- note: [[espanhol]] (espanhola), but this is the only case in ''-ol'' (vs. [[bemol]], [[mongol]] with no
	-- change in the feminine)
	return form
end

function export.make_masculine(form, special)
	local retval = call_handle_multiword(form, special, export.make_masculine, "make_masculine")
	if retval then
		return retval
	end

	local function try(from, to)
		local newform, changed = rsubb(form, from, to)
		if changed then
			form = newform
		end
		return changed
	end

	local changed =
		try("([dts])ora$", "%1or") or
		try("a$", "o") or
		-- ordinal indicator
		try("ª$", "º")

	return form
end

local function munge_form_for_ending(form, typ)
	local function try(from, to)
		local newform, changed = rsubb(form, from, to)
		if changed then
			form = newform
		end
		return changed
	end

	local changed =
		try("ão$", "on") or
		typ ~= "aug" and try("c[oa]$", "qu") or
		typ ~= "aug" and try("g[oa]$", "gu") or
		try("[oae]$", "") or
		typ == "sup" and try("z$", "c") or
		-- Adverb stems won't have the acute accent but we should handle them correctly regardless.
		try("[áa]vel$", "abil") or
		try("[íi]vel$", "ibil") or
		try("eu$", "euz")

	-- Remove accent (-ês, -ário, -ático, etc.) when adding ending.
	form = rsub(form, "(" .. AV .. ")(.-)$", function(av, rest) return (remove_accent[av] or av) .. rest end)

	return form
end

function export.make_absolute_superlative(form, special)
	local retval = call_handle_multiword(form, special, export.make_absolute_superlative, "make_absolute_superlative")
	if retval then
		return retval
	end

	return munge_form_for_ending(form, "sup") .. "íssimo"
end

function export.make_adverbial_absolute_superlative(form, special)
	local retval = call_handle_multiword(form, special, export.make_adverbial_absolute_superlative, "make_adverbial_absolute_superlative")
	if retval then
		return retval
	end

	return munge_form_for_ending(form, "sup") .. "issimamente"
end

function export.make_diminutive(form, special)
	local retval = call_handle_multiword(form, special, export.make_diminutive, "make_diminutive")
	if retval then
		return retval
	end

	return munge_form_for_ending(form, "dim") .. "inho"
end

function export.make_augmentative(form, special)
	local retval = call_handle_multiword(form, special, export.make_augmentative, "make_augmentative")
	if retval then
		return retval
	end

	return munge_form_for_ending(form, "aug") .. "ão"
end


return export
