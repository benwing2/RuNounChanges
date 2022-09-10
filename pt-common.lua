local export = {}

local rsubn = mw.ustring.gsub

local unaccented_vowel = "aeiouà"
local accented_vowel = "áéíóúýâêô"
local maybe_accented_vowel = "ãõ"
local vowel = unaccented_vowel .. accented_vowel .. maybe_accented_vowel
local V = "[" .. vowel .. "]"
local AV = "[" .. accented_vowel .. "]"
local NAV = "[^" .. accented_vowel .. "]"
local C = "[^" .. vowel .. ".]"
local remove_accent = {["á"]="a", ["é"]="e", ["í"]="i", ["ó"]="o", ["ú"]="u", ["ý"]="y", ["â"]="a", ["ê"]="e", ["ô"]="o"}

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

local prepositions = {
	-- a + optional article
	"a ",
	"às? ",
	"aos? ",
	-- de + optional article
	"de ",
	"d[oa]s? ",
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

function export.make_plural(form, special)
	local retval = require("Module:romance utilities").handle_multiword(form, special, export.make_plural, prepositions)
	if retval then
		if #retval ~= 1 then
			error("Internal error: Should have one return value for make_plural: " .. table.concat(retval, ","))
		end
		return retval[1]
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
		try("(" .. AV .. ")s$", function(av) return (remove_accent[av] or av) .. "ses" end) or -- final -ês, -ós etc.
		try("^(" .. NAV .. "*" .. C .. "[ui]s)$", "%1es") -- final stressed -us or -is after consonant

	return form
end

function export.make_feminine(form, special)
	local retval = require("Module:romance utilities").handle_multiword(form, special, export.make_feminine, prepositions)
	if retval then
		if #retval ~= 1 then
			error("Internal error: Should have one return value for make_feminine: " .. table.concat(retval, ","))
		end
		return retval[1]
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
	local retval = require("Module:romance utilities").handle_multiword(form, special, export.make_masculine, prepositions)
	if retval then
		if #retval ~= 1 then
			error("Internal error: Should have one return value for make_masculine: " .. table.concat(retval, ","))
		end
		return retval[1]
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
		try("a$", "o")

	return form
end


return export
