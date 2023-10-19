local export = {}

local u = mw.ustring.char
local rsplit = mw.text.split
local rsubn = mw.ustring.gsub
local rfind = mw.ustring.find
local rmatch = mw.ustring.match

local TEMPC1 = u(0xFFF1)
local TEMPC2 = u(0xFFF2)
local TEMPV1 = u(0xFFF3)
local DIV = u(0xFFF4)
local unaccented_vowel = "aeiouüAEIOUÜ"
local accented_vowel = "áéíóúýÁÉÍÓÚÝ"
local vowel = unaccented_vowel .. accented_vowel
local V = "[" .. vowel .. "]"
export.V = V
local AV = "[" .. accented_vowel .. "]"
export.AV = AV
local NAV = "[^" .. accented_vowel .. "]"
export.NAV = NAV
local W = "[iyuw]" -- glide
export.W = W
local C = "[^" .. vowel .. ".]"
export.C = C
local remove_accent = {
	["á"]="a", ["é"]="e", ["í"]="i", ["ó"]="o", ["ú"]="u", ["ý"]="y",
	["Á"]="A", ["É"]="E", ["Í"]="I", ["Ó"]="O", ["Ú"]="U", ["Ý"]="Y",
}
export.remove_accent = remove_accent
local add_accent = {
	["a"]="á", ["e"]="é", ["i"]="í", ["o"]="ó", ["u"]="ú", ["y"]="ý",
	["A"]="Á", ["E"]="É", ["I"]="Í", ["O"]="Ó", ["U"]="Ú", ["Y"]="Ý",
}
export.add_accent = add_accent

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

function export.add_final_accent(stem)
	return rsub(stem, "(" .. NAV .. ")(" .. C .. "*)$", function(v, c) return (add_accent[v] or v) .. c end)
end

local prepositions = {
	-- a + optional article
	"a ",
	"ás? ",
	"aos? ",
	-- con + optional article
	"con ",
	"coa?s? ",
	-- de + optional article
	"de ",
	"d[oa]s? ",
	"d'",
	-- en/em + optional article
	"en ",
	"n[oa]s? ",
	-- por + optional article
	"por ",
	"pol[oa]s? ",
	-- para + optional article
	"para ",
	"pr[óá]s? ",
	-- others
	"at[aé] ",
	"como ",
	"entre ",
	"sen ",
	"so ",
	"sobre ",
}

local function call_handle_multiword(form, special, make_fun, fun_name)
	local retval = require(romut_module).handle_multiword(form, special, make_fun, prepositions)
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
		local stem = rmatch(word, "^(.*)" .. from .. "$")
		if stem then
			return stem .. to
		end
		return nil
	end
end

function export.make_plural(form, special)
	local retval = call_handle_multiword(form, special, export.make_plural, "make_plural")
	if retval then
		return retval
	end

	local try = make_try(form)

	-- This is ported from the former [[Module:gl-plural]] except that the old code sometimes returned nil (final -ão
	-- other than -ção and -são, final consonant other than [lrmzs]), whereas we always return a default plural
	-- (all -ão -> ões, all final consonants other than [lrmzs] are left unchanged).
	return try("r$", "res") or
		try("z$", "ces") or
		try("(" .. V .. "be)l$", "%1is") or -- vowel + -bel
		try("(" .. AV .. ".*" .. V .. ")l$", "%1es") or -- non-final stress + -l e.g. [[túnel]] -> 'túneles'
		try("^(" .. C .. "*" .. V .. C .. "*)l$", "%1es") or -- monosyllable ending in -l e.g. [[sol]] -> 'soles'
		try("il$", "ís") or -- final stressed -il e.g. [[civil]] -> 'civís'
		try("(" .. V .. ")l$", "%1is") or -- any other vowel + -l e.g. [[papel]] -> 'papeis'
		try("(" V .. "[íú])s$", "%ses") or -- vowel + stressed í/ú + -s e.g. [[país]] -> 'países'
		try("(" .. AV .. ")s$", -- other final accented vowel + -s e.g. [[autobús]] -> 'autobuses'
			function(av) return remove_accent[av] .. "ses" end) or
		try("(" .. V .. "[iu]?s)$", "%1es") or -- diphthong + final -s e.g. [[deus]] -> 'deuses'
		try("^(C" .. "*" .. V .. "s)$", "%1es") or -- monosyllable + final -s e.g. [[fros]] -> 'froses', [[gas]] -> 'gases'
		try("([sx])$", "%1") or -- other final -s or -x (stressed on penult or antepenult or ending in cluster), e.g.
								-- [[mércores]], [[lapis]], [[lux]], [[unisex]], [[luns]]
		form .. "s" -- ending in vowel, -n or other consonant e.g. [[cadeira]], [[marroquí]], [[xersei]], [[limón]],
					-- [[club]], [[clip]], [[robot]], [[álbum]]
end

function export.make_feminine(form, is_noun, special)
	local retval = call_handle_multiword(form, special, function(form) return export.make_feminine(form, is_noun) end,
		"make_feminine")
	if retval then
		return retval
	end

	local try = make_try(form)

	return
		try("o$", "a") or
		try("º$", "ª") or -- ordinal indicator
		try("^(" .. C .. "*)u$", "%1úa") or -- [[nu]] -> núa, [[cru]] -> crúa
		try("^eu$", "ía") or -- [[sandeu]] -> sandía, [[xudeu]] -> xudía
		-- many nouns and adjectives in -án:
		-- [[afgán]], [[alazán]], [[aldeán]], [[alemán]], [[ancián]], [[aresán]], [[arnoián]], [[arousán]], [[artesán]],
		-- [[arzuán]], [[barregán]], [[bergantiñán]], [[bosquimán]], [[buxán]], [[caldelán]], [[camariñán]],
		-- [[capitán]], [[carnotán]], [[castelán]], [[catalán]], [[cidadán]], [[cirurxián]], [[coimbrán]], [[comarcán]],
		-- [[compostelán]], [[concidadán]], [[cortesán]], [[cotián]], [[cristián]], [[curmán]], [[desirmán]],
		-- [[ermitán]], [[ferrolán]], [[fisterrán]], [[gardián]], [[insán]], [[irmán]], [[louzán]], [[malpicán]],
		-- [[malsán]], [[mariñán]], [[marrán]], [[muradán]], [[musulmán]], [[muxián]], [[neurocirurxián]], [[nugallán]],
		-- [[otomán]], [[ourensán]], [[pagán]], [[paleocristián]], [[ponteareán]], [[pontecaldelán]], [[redondelán]],
		-- [[ribeirán]], [[rufián]], [[sacristán]], [[salnesán]], [[sancristán]], [[sultán]], [[tecelán]], [[temperán]],
		-- [[temporán]], [[truán]], [[turcomán]], [[ullán]], [[vilagarcián]], [[vilán]]
		--
		-- but not (instead in -ana):
		-- [[baleigán]], [[barbuzán]], [[barrigán]], [[barullán]], [[bergallán]], [[bocalán]], [[brután]], [[buleirán]],
		-- [[burrán]], [[burricán]], [[cabezán]], [[cachamoulán]], [[cachán]], [[cacholán]], [[cagán]], [[canelán]],
		-- [[cangallán]], [[carallán]], [[carcamán]], [[carneirán]], [[carroulán]], [[chalán]], [[charlatán]],
		-- [[cornán]], [[cornelán]], [[farfallán]], [[folán]], [[folgazán]], [[galbán]], [[guedellán]], [[lacazán]],
		-- [[langrán]], [[larpán]], [[leilán]], [[lerchán]], [[lombán]], [[lorán]], [[lordán]], [[loubán]],
		-- [[mentirán]], [[mourán]], [[orellán]], [[paduán]], [[pailán]], [[palafustrán]], [[papán]], [[parvallán]],
		-- [[paspán]], [[pastrán]], [[pelandrán]], [[pertegán]], [[pillabán]], [[porcallán]], [[ruán]],
		-- [[tangueleirán]], [[testalán]], [[testán]], [[toleirán]], [[vergallán]], [[zalapastrán]], [[zampallán]]
		try("án$", "á") or
		-- nouns in -z e.g. [[rapaz]]; but not [[feliz]], [[capaz]], [[perspicaz]], etc.
		-- only such adjective is [[andaluz]] -> andaluza, [[rapaz]] -> rapaza
		is_noun and try("z$", "za") or
		try("ín$", "ina") or -- [[bailarín]], [[benxamín]], [[danzarín]], [[galopín]], [[lampantín]], [[mandarín]],
							 -- [[palanquín]]; but not [[afín]], [[pimpín]], [[ruín]]
		-- [[abusón]], [[chorón]], [[felón]], etc.
		--
		-- but not (instead in -oa): [[anglosaxón]], [[baixosaxón]], [[beirón]], [[borgoñón]], [[bretón]], [[campión]],
		-- [[eslavón]], [[francón]], [[frisón]], [[gascón]], [[grisón]], [[ladrón]] (also fem. ladra), [[letón]],
		-- [[nipón]], [[patagón]], [[saxón]], [[teutón]], [[valón]], [[vascón]]
		--
		-- but not (invariable in singular): [[grelón]], [[maricón]], [[marón]], [[marrón]], [[roulón]], [[salmón]],
		-- [[xiprón]]
		try("ón$", "ona") or
		try("és$", "esa") or -- [[francés]], [[portugués]], [[fregués]], [[vigués]] etc.
							 -- but not [[cortés]], [[descortés]] 
		-- adjectives in:
		-- * [[-ador]], [[-edor]] ([[amortecedor]], [[compilador]], etc.), [[-idor]] ([[inhibidor]], etc.)
		-- * -tor ([[condutor]], [[construtor]], [[colector]], etc.)
		-- * -sor ([[agresor]], [[censor]], [[divisor]], etc.)
		-- but not:
		-- * [[anterior]]/[[posterior]]/[[inferior]]/[[júnior]]/[[maior]]/[[peor]]/[[mellor]]/etc.
		-- * [[bicolor]]/[[multicolor]]/etc.
		try("([dts]or)$", "%1a") or
		form
end

function export.make_masculine(form, special)
	local retval = call_handle_multiword(form, special, export.make_masculine, "make_masculine")
	if retval then
		return retval
	end

	local try = make_try(form)

	return
		try("([dts])ora$", "%1or") or
		try("a$", "o") or
		-- ordinal indicator
		try("ª$", "º") or
		form
end

-- Syllabify a word. This is copied and modified from [[Module:es-common]] and attempts to implements a full
-- syllabification algorithm, based on the corresponding code in [[Module:es-pronunc]]. This is more than is needed for
-- the purpose of this module, which doesn't care so much about syllable boundaries, but won't hurt.
function export.syllabify(word)
	word = DIV .. word .. DIV
	-- gu/qu + front vowel; make sure we treat the u as a consonant; a following i should not be treated as a consonant
	-- (may make no difference for Galician; necessary in Spanish for [[alguien]])
	word = rsub(word, "([gq])u([eiéí])", "%1" .. TEMPC2 .. "%2")
	local vowel_to_glide = { ["i"] = TEMPC1, ["u"] = TEMPC2 }
	-- i and u between vowels should behave like consonants ([[paranoia]], [[baiano]]); Spanish also has [[abreuense]],
	-- [[alauita]], [[Malaui]], etc. not in Galician
	word = rsub_repeatedly(word, "(" .. V .. ")([iu])(" .. V .. ")",
		function(v1, iu, v2) return v1 .. vowel_to_glide[iu] .. v2 end
	)
	-- y between consonants or after a consonant at the end of the word should behave like a vowel
	-- ([[ankylosaurio]], [[lycra]], [[hippy]], [[cherry]], etc.)
	word = rsub_repeatedly(word, "(" .. C .. ")y(" .. C .. ")",
		function(c1, c2) return c1 .. TEMPV1 .. c2 end
	)

	word = rsub_repeatedly(word, "(" .. V .. ")(" .. C .. W .. "?" .. V .. ")", "%1.%2")
	word = rsub_repeatedly(word, "(" .. V .. C .. ")(" .. C .. V .. ")", "%1.%2")
	word = rsub_repeatedly(word, "(" .. V .. C .. "+)(" .. C .. C .. V .. ")", "%1.%2")
	word = rsub(word, "([pbcktdg])%.([lr])", ".%1%2")
	word = rsub_repeatedly(word, "(" .. C .. ")%.s(" .. C .. ")", "%1s.%2")
	-- Any aeo, or stressed iu, should be syllabically divided from a following aeo or stressed iu.
	word = rsub_repeatedly(word, "([aeoáéíóúý])([aeoáéíóúý])", "%1.%2")
	word = rsub_repeatedly(word, "([ií])([ií])", "%1.%2")
	word = rsub_repeatedly(word, "([uú])([uú])", "%1.%2")
	word = rsub(word, "([" .. DIV .. TEMPC1 .. TEMPC2 .. TEMPV1 .. "])", {
		[DIV] = "",
		[TEMPC1] = "i",
		[TEMPC2] = "u",
		[TEMPV1] = "y",
	})
	return rsplit(word, "%.")
end


-- Return the index of the (last) stressed syllable.
function export.stressed_syllable(syllables)
	-- If a syllable is stressed, return it.
	for i = #syllables, 1, -1 do
		if rfind(syllables[i], AV) then
			return i
		end
	end
	-- Monosyllabic words are stressed on that syllable.
	if #syllables == 1 then
		return 1
	end
	local i = #syllables
	-- Unaccented words ending in a vowel or a vowel + n/s/ns are stressed on the preceding syllable.
	if rfind(syllables[i], V .. "n?s?$") then
		return i - 1
	end
	-- Remaining words are stressed on the last syllable.
	return i
end


-- Add an accent to the appropriate vowel in a syllable, if not already accented.
function export.add_accent_to_syllable(syllable)
	-- Don't do anything if syllable already stressed.
	if rfind(syllable, AV) then
		return syllable
	end
	-- Prefer to accent an a/e/o in case of a diphthong or triphthong (the first one if for some reason
	-- there are multiple, which should not occur with the standard syllabification algorithm);
	-- otherwise, do the first i or u in case of a diphthong ui or iu.
	if rfind(syllable, "[aeo]") then
		return rsub(syllable, "^(.-)([aeo])", function(prev, v) return prev .. add_accent[v] end)
	end
	return rsub(syllable, "^(.-)([iu])", function(prev, v) return prev .. add_accent[v] end)
end


-- Remove any accent from a syllable.
function export.remove_accent_from_syllable(syllable)
	return rsub(syllable, AV, remove_accent)
end


-- Return true if an accent is needed on syllable number `sylno` if that syllable were to receive the stress,
-- given the syllables of a word. The current accent may be on any syllable.
function export.accent_needed(syllables, sylno)
	-- Diphthongs iu and ui are normally stressed on the first vowel, so if the accent is on the second vowel,
	-- it's needed.
	if rfind(syllables[sylno], "iú") or rfind(syllables[sylno], "[uü]í") then
		return true
	end
	-- If the default-stressed syllable is different from `sylno`, accent is needed.
	local unaccented_syllables = {}
	for _, syl in ipairs(syllables) do
		table.insert(unaccented_syllables, export.remove_accent_from_syllable(syl))
	end
	local would_be_stressed_syl = export.stressed_syllable(unaccented_syllables)
	if would_be_stressed_syl ~= sylno then
		return true
	end
	-- At this point, we know that the stress would by default go on `sylno`, given the syllabification in
	-- `syllables`. Now we have to check for situations where removing the accent mark would result in a
	-- different syllabification. For example, países -> `pa.i.ses` but removing the accent mark would lead
	-- to `pai.ses`. Similarly, río -> `ri.o` but removing the accent mark would lead to single-syllable `rio`.
	-- We need to check whether (a) the stress falls on an i or u; (b) in the absence of an accent mark, the
	-- i or u would form a diphthong with a preceding or following vowel and the stress would be on that vowel.
	-- The conditions are slightly different when dealing with preceding or following vowels because iu and ui
	-- diphthongs are by default stressed on the first vowel.
	local accented_syllable = export.add_accent_to_syllable(unaccented_syllables[sylno])
	if sylno > 1 then
		if rfind(unaccented_syllables[sylno - 1], "[aeou]$") and rfind(accented_syllable, "^í") or
			rfind(unaccented_syllables[sylno - 1], "[aeio]$") and rfind(accented_syllable, "^ú") then
			return true
		end
	end
	if sylno < #syllables and rfind(accented_syllable, "[íú]$") and rfind(unaccented_syllables[sylno + 1], "^[aeo]") then
		return true
	end
	return false
end


-- FIXME: Next two copied from [[Module:es-common]]. Move to a utilities module.

-- Add links around words. If multiword_only, do it only in multiword forms.
function export.add_links(form, multiword_only)
	if form == "" or form == " " then
		return form
	end
	if not form:find("%[%[") then
		if rfind(form, "[%s%p]") then --optimization to avoid loading [[Module:headword]] on single-word forms
			local m_headword = require("Module:headword")
			if m_headword.head_is_multiword(form) then
				form = m_headword.add_multiword_links(form)
			end
		end
		if not multiword_only and not form:find("%[%[") then
			form = "[[" .. form .. "]]"
		end
	end
	return form
end


function export.strip_redundant_links(form)
	-- Strip redundant brackets surrounding entire form.
	return rmatch(form, "^%[%[([^%[%]]*)%]%]$") or form
end

return export
