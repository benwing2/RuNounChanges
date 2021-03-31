local export = {}

local TEMPC1 = u(0xFFF1)
local TEMPC2 = u(0xFFF2)
local TEMPV1 = u(0xFFF3)
local DIV = u(0xFFF4)
local vowel = "aeiouáéíóúý" .. TEMPV1
local V = "[" .. vowel .. "]"
local SV = "[áéíóúý]" -- stressed vowel
local W = "[iyuw]" -- glide
local C = "[^" .. vowel .. ".]"

export.vowel = vowel
export.V = V
export.SV = SV
export.W = W 
export.C = C 

local remove_stress = {
	["á"] = "a", ["é"] = "e", ["í"] = "i", ["ó"] = "o", ["ú"] = "u", ["ý"] = "y"
}
local add_stress = {
	["a"] = "á", ["e"] = "é", ["i"] = "í", ["o"] = "ó", ["u"] = "ú", ["y"] = "ý"
}

export.remove_stress = remove_stress
export.add_stress = add_stress


-- version of rsubn() that discards all but the first return value
local function rsub(term, foo, bar)
	local retval = rsubn(term, foo, bar)
	return retval
end

export.rsub = rsub

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


-- Syllabify a word. This implements the full syllabification algorithm, based on the corresponding code
-- in [[Module:es-pronunc]]. This is more than is needed for the purpose of this module, which doesn't
-- care so much about syllable boundaries, but won't hurt.
function export.syllabify(word)
	word = DIV .. word .. DIV
	-- gu/qu + front vowel; make sure we treat the u as a consonant; a following
	-- i should not be treated as a consonant ([[alguien]] would become ''álguienes''
	-- if pluralized)
	word = rsub(word, "([gq])u([eiéí])", "%1" .. TEMPC2 .. "%2")
	local vowel_to_glide = { ["i"] = TEMPC1, ["u"] = TEMPC2 }
	-- i and u between vowels should behave like consonants ([[paranoia]], [[baiano]], [[abreuense]],
	-- [[alauita]], [[Malaui]], etc.)
	word = rsub_repeatedly(word, "(" .. V .. ")([iu])(" .. V .. ")",
		function(v1, iu, v2) return v1 .. vowel_to_glide[iu] .. v2 end
	)
	-- y between consonants or after a consonant at the end of the word should behave like a vowel
	-- ([[ankylosaurio]], [[cryptomeria]], [[brandy]], [[cherry]], etc.)
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
		if rfind(syllables[i], SV) then
			return i
		end
	end
	-- Monosyllabic words are stressed on that syllable.
	if #syllables == 1 then
		return 1
	end
	-- Unaccented words ending in a vowel or a vowel + s/n are stressed on the preceding syllable.
	if rfind(syllables[i], V .. "[sn]?$") then
		return i - 1
	end
	-- Remaining words are stressed on the last syllable.
	return i
end


-- Add an accent to the appropriate vowel in a syllable, if not already accented.
function export.add_accent_to_syllable(syllable)
	-- Don't do anything if syllable already stressed.
	if rfind(syllable, SV) then
		return syllable
	end
	-- Prefer to accent an a/e/o in case of a diphthong or triphthong (the first one if for some reason
	-- there are multiple, which should not occur with the standard syllabification algorithm);
	-- otherwise, do the last i or u in case of a diphthong ui or iu.
	if rfind(syllable, "[aeo]") then
		return rsub(syllable, "^(.-)([aeo])", function(prev, v) return prev .. add_stress[v] end)
	end
	return rsub(syllable, "^(.*)([iu])", function(prev, v) return prev .. add_stress[v] end)
end


-- Remove any accent from a syllable.
function export.remove_accent_from_syllable(syllable)
	return rsub(syllable, SV, remove_stress)
end


-- Return true if an accent is needed on syllable number `sylno` if that syllable were to receive the stress,
-- given the syllables of a word. The current accent may be on any syllable.
function export.accent_needed(syllables, sylno)
	-- Diphthongs iu and ui are normally stressed on the second vowel, so if the accent is on the first vowel,
	-- it's needed.
	if rfind(syllables[sylno], "íu") or rfind(syllables[sylno], "úi") then
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
	-- The conditions are slightly different when dealing with preceding or following vowels because ui and ui
	-- diphthongs are by default stressed on the second vowel. We also have to ignore h between the vowels.
	local accented_syllable = export.add_accent_to_syllable(unaccented_syllables[sylno])
	if sylno > 1 and rfind(unaccented_syllables[sylno - 1], "[aeo]$") and rfind(accented_syllable, "^h?[íú]") then
		return true
	end
	if sylno < #syllables then
		if rfind(accented_syllable, "í$") and rfind(unaccented_syllables[sylno + 1], "^h?[aeou]") or
		rfind(accented_syllable, "ú$") and rfind(unaccented_syllables[sylno + 1], "^h?[aeio]") then
		return true
	end
	return false
end


return export
