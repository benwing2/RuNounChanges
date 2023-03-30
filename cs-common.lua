local export = {}

local lang = require("Module:languages").getByCode("cs")
local m_links = require("Module:links")
local m_table = require("Module:table")
local m_string_utilities = require("Module:string utilities")

local u = mw.ustring.char
local rsplit = mw.text.split
local rfind = mw.ustring.find
local rmatch = mw.ustring.match
local rsubn = mw.ustring.gsub
local ulen = mw.ustring.len
local uupper = mw.ustring.upper

-- version of rsubn() that discards all but the first return value
local function rsub(term, foo, bar)
	local retval = rsubn(term, foo, bar)
	return retval
end

-- version of rsubn() that returns a 2nd argument boolean indicating whether
-- a substitution was made.
local function rsubb(term, foo, bar)
	local retval, nsubs = rsubn(term, foo, bar)
	return retval, nsubs > 0
end

export.TEMP_CH = u(0xFFF0) -- used to substitute ch temporarily in the default-reducible code
export.TEMP_OU = u(0xFFF1) -- used to substitute ou temporarily in is_monosyllabic()

local lc_vowel = "aeiouyáéíóúýěů" .. TEMP_OU
local uc_vowel = uupper(lc_vowel)
export.vowel = lc_vowel .. uc_vowel
export.vowel_c = "[" .. export.vowel .. "]"
export.non_vowel_c = "[^" .. export.vowel .. "]"
-- Consonants that can never form a syllabic nucleus.
local lc_non_syllabic_cons = "bcdfghjkmnpqstvwxzčňšžďť" .. export.TEMP_CH
local uc_non_syllabic_cons = uupper(lc_non_syllabic_cons)
local non_syllabic_cons = lc_non_syllabic_cons .. uc_non_syllabic_cons
local non_syllabic_cons_c = "[" .. non_syllabic_cons .. "]"
local lc_syllabic_cons = "lrř"
local uc_syllabic_cons = uupper(lc_syllabic_cons)
local lc_cons = lc_non_syllabic_cons .. lc_syllabic_cons
local uc_cons = uupper(lc_cons)
export.cons = lc_cons .. uc_cons
export.cons_c = "[" .. export.cons .. "]"
export.lowercase = lc_vowel .. lc_cons
export.lowercase = "[" .. export.lowercase .. "]"
export.uppercase = uc_vowel .. uc_cons
export.uppercase_c = "[" .. export.uppercase .. "]"
local lc_paired_palatal = "ňďť"
local uc_paired_palatal = uuper(lc_paired_palatal)
export.paired_palatal = lc_paired_palatal .. uc_paired_palatal
local lc_paired_plain = "ndt"
local uc_paired_plain = uupper(lc_paired_plain)
export.paired_plain = lc_paired_plain .. uc_paired_plain
export.paired_palatal_to_plain = {
	["ň"] = "n",
	["Ň"] = "N",
	["ť"] = "t",
	["Ť"] = "T",
	["ď"] = "d",
	["Ď"] = "D",
}
export.paired_plain_to_palatal = {}
for k, v in pairs(export.paired_palatal_to_plain) do
	export.paired_plain_to_palatal[v] = k
end
local lc_velar = "kgh"
local uc_velar = uupper(lc_velar)
export.velar = lc_velar .. uc_velar
export.velar_c = "[" .. export.velar .. "]"
local lc_labial = "mpbfv"
local uc_labial = uupper(lc_labial)
export.labial = lc_labial .. uc_labial
export.labial_c = "[" .. export.labial .. "]"
local lc_not_followable_by_y = "cčjřšž"
local uc_not_followable_by_y = uupper(lc_not_followable_by_y)
export.not_followable_by_y = lc_not_followable_by_y .. uc_not_followable_by_y
export.not_followable_by_y_c = "[" .. export.not_followable_by_y .. "]"


-- Return true if `word` is monosyllabic. Beware of words like [[čtvrtek]], [[plný]] and [[třmen]], which aren't
-- monosyllabic but have only one vowel, and contrariwise words like [[brouk]], which are monosyllabic but have
-- two vowels.
function export.is_monosyllabic(word)
	word = word:gsub("ou", TEMP_OU)
	-- Convert all vowels to 'e'.
	word = rsub(word, export.vowel_c, "e")
	-- All consonants next to a vowel are non-syllabic; convert to 't'.
	word = rsub(word, export.cons_c .. "e", "te")
	word = rsub(word, "e" .. export.cons_c, "et")
	-- Convert all remaining non-syllabic consonants to 't'.
	word = rsub(word, export.non_syllabic_cons_c, "t")
	-- At this point, what remains is 't', 'e', or a syllabic consonant. Count the latter two types.
	word = word:gsub("t", "")
	return ulen(word) <= 1
end


function export.apply_vowel_alternation(alt, stem)
	local modstem, origvowel
	if alt == "quant" or alt == "quant-ě" then
		-- [[sníh]] "snow", gen sg. [[sněhu]]
		-- [[míra]] "snow", gen sg. [[měr]]
		-- [[hůl]] "cane", gen sg. [[hole]]
		-- [[práce]] "work", ins sg. [[prací]]
		modstem = rsub(stem, "(.)([íůáé])(" .. export.cons_c .. "*)$",
			function(pre, vowel, post)
				origvowel = vowel
				if vowel == "í" then
					if alt == "quant-ě" then
						if rfind(pre, "[" .. export.paired_plain .. export.labial .. "]$") then
							return pre .. "ě" .. post
						else
							return pre .. "e" .. post
						end
					else
						return pre .. "i" .. post
					end
				elseif vowel == "ů" then
					return pre .. "o" .. post
				elseif vowel == "é" then
					return pre .. "e" .. post
				else
					return pre .. "a" .. post
				end
			end
		)
		if modstem == stem then
			error("Indicator '" .. alt .. "' can't be applied because stem '" .. stem .. "' doesn't have an í, ů, á or é as its last vowel")
		end
	else
		return stem, nil
	end
	return modstem, origvowel
end


local function make_try(word)
	return function try(from, to)
		local stem = rmatch(word, "^(.*)" .. from .. "$")
		if stem then
			return stem .. to
		end
		return nil
	end
end


function export.iotate(stem)
	-- FIXME! This is based off of page 14 of Janda and Townsend but needs reviewing with verbs.
	local try = make_try(word)
	return
		try("st", "št") or
		try("zd", "žd") or
		try("t", "c") or
		try("d", "z") or
		try("s", "š") or
		try("z", "ž") or
		try("r", "ř") or
		try("ch", "š") or
		try("[kc]", "č") or
		try("[hg]", "ž") or
		word
end


function export.apply_first_palatalization(word)
	local try = make_try(word)
	return
		try("ch", "š") or
		try("[hg]", "ž") or
		try("tr", "tř") or
		try("sk", "št") or
		try("ck", "čt") or
		try("[kc]", "č") or
		word
end


function export.apply_second_palatalization(word)
	local try = make_try(word)
	return
		try("ch", "š") or
		try("[hg]", "z") or
		try("r", "ř") or
		try("sk", "št") or
		try("ck", "čt") or
		try("k", "c") or
		word
end


function export.reduce(word)
	local pre, letter, vowel, post = rmatch(word, "^(.*)(" .. export.cons_c .. ")([eě])(" .. export.cons_c .. "+)$")
	if not pre then
		return nil
	end
	if vowel == "ě" and rfind(letter, "[" .. export.paired_plain .. "]") then
		letter = export.paired_plain_to_palatal[letter]
	end
	return pre .. letter .. post
end


function export.dereduce(stem)
	local pre, letter, post = rmatch(stem, "^(.*)(" .. export.cons_c .. ")(" .. export.cons_c .. ")$")
	if not pre then
		return nil
	end
	local epvowel
	if rfind(letter, "[" .. export.paired_palatal .. "]") then
		letter = export.paired_palatal_to_plain[letter]
		epvowel = "ě"
	else
		epvowel = "e"
	end
	return pre .. letter .. epvowel .. post
end


function export.convert_paired_plain_to_palatal(stem, ending)
	if ending and not rfind(ending, "^[ěií]") then
		return stem
	end
	local stembegin, lastchar = rmatch(stem, "^(.*)([" .. export.paired_plain .. "])$")
	if lastchar then
		return stembegin .. export.paired_plain_to_palatal[lastchar]
	else
		return stem
	end
end


function export.convert_paired_palatal_to_plain(stem, ending)
	-- For stems that alternate between n/t/d and ň/ť/ď, we always maintain the stem in the latter format and
	-- convert to the corresponding plain as needed, with e -> ě (normally we always have 'ě' as the ending, but
	-- the user may specify 'e').
	if ending and not rfind(ending, "^[eěií]") then
		return stem, ending
	end
	local stembegin, lastchar = rmatch(stem, "^(.*)([" .. export.paired_palatal .. "])$")
	if lastchar then
		if ending == "e" then
			ending = rsub(ending, "^e", "ě")
		end
		return stembegin .. export.paired_palatal_to_plain[lastchar], ending
	else
		return stem, ending
	end
end


function export.combine_stem_ending(base, slot, stem, ending)
	if stem == "?" then
		return "?"
	else
		stem, ending = export.convert_paired_palatal_to_plain(stem, ending)
		-- There are occasional occurrences of soft-only consonants at the end of the stem in hard paradigms, e.g.
		-- [[banjo]] "banjo", [[gadžo]] "gadjo (non-Romani)", [[Miša]] "Misha, Mike". These force a following y to turn
		-- into i.
		if rfind(ending, "^y") and rfind(stem, export.not_followable_by_y_c .. "$") then
			ending = rsub(ending, "^y", "i")
		end
		if base.all_uppercase then
			stem = uupper(stem)
		end
		return stem .. ending
	end
end


return export
