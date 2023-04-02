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
export.TEMP_SOFT_LABIAL = u(0xFFF1) -- used to indicate that a labial consonant is soft and needs ě

local lc_vowel = "aeiouyáéíóúýěů"
local uc_vowel = uupper(lc_vowel)
export.vowel = lc_vowel .. uc_vowel
export.vowel_c = "[" .. export.vowel .. "]"
export.non_vowel_c = "[^" .. export.vowel .. "]"
-- Consonants that can never form a syllabic nucleus.
local lc_non_syllabic_cons = "bcdfghjkmnpqstvwxzčňšžďť" .. export.TEMP_CH .. export.TEMP_SOFT_LABIAL
local uc_non_syllabic_cons = uupper(lc_non_syllabic_cons)
export.non_syllabic_cons = lc_non_syllabic_cons .. uc_non_syllabic_cons
export.non_syllabic_cons_c = "[" .. export.non_syllabic_cons .. "]"
local lc_syllabic_cons = "lrř"
local uc_syllabic_cons = uupper(lc_syllabic_cons)
local lc_cons = lc_non_syllabic_cons .. lc_syllabic_cons
local uc_cons = uupper(lc_cons)
export.cons = lc_cons .. uc_cons
export.cons_c = "[" .. export.cons .. "]"
export.lowercase = lc_vowel .. lc_cons
export.lowercase_c = "[" .. export.lowercase .. "]"
export.uppercase = uc_vowel .. uc_cons
export.uppercase_c = "[" .. export.uppercase .. "]"

local lc_velar = "kgh"
local uc_velar = uupper(lc_velar)
export.velar = lc_velar .. uc_velar
export.velar_c = "[" .. export.velar .. "]"

local lc_plain_labial = "mpbfv"
local lc_labial = lc_plain_labial .. export.TEMP_SOFT_LABIAL
local uc_plain_labial = uupper(lc_plain_labial)
local uc_labial = uupper(lc_labial)
export.plain_labial = lc_plain_labial .. uc_plain_labial
export.labial = lc_labial .. uc_labial
export.labial_c = "[" .. export.labial .. "]"

local lc_paired_palatal = "ňďť"
local uc_paired_palatal = uupper(lc_paired_palatal)
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
export.paired_palatal_to_plain[export.TEMP_SOFT_LABIAL] = ""
for labial in mw.ustring.gmatch(export.plain_labial, ".") do
	export.paired_plain_to_palatal[labial] = labial .. export.TEMP_SOFT_LABIAL
end

local lc_followable_by_e_hacek = lc_paired_plain .. lc_plain_labial
local uc_followable_by_e_hacek = uc_paired_plain .. uc_plain_labial
export.followable_by_e_hacek = lc_followable_by_e_hacek .. uc_followable_by_e_hacek
export.followable_by_e_hacek_c = "[" .. export.followable_by_e_hacek .. "]"
local lc_inherently_soft_not_c = "čjřšžťďň" -- c is sometimes hard
local uc_inherently_soft_not_c = uupper(lc_inherently_soft_not_c)
export.inherently_soft_not_c = lc_inherently_soft_not_c .. uc_inherently_soft_not_c
export.inherently_soft_not_c_c = "[" .. export.inherently_soft_not_c .. "]"
export.inherently_soft = export.inherently_soft_not_c .. "cC"
export.inherently_soft_c = "[" .. export.inherently_soft .. "]"


-- Return true if `word` is monosyllabic. Beware of words like [[čtvrtek]], [[plný]] and [[třmen]], which aren't
-- monosyllabic but have only one vowel, and contrariwise words like [[brouk]], which are monosyllabic but have
-- two vowels.
function export.is_monosyllabic(word)
	-- Treat ou as a single vowel.
	word = word:gsub("ou", "ů")
	word = word:gsub("ay$", "aj")
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
						if rfind(pre, "[" .. export.followable_by_e_hacek .. "]$") then
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
	return function(from, to)
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


function export.apply_first_palatalization(word, is_adjective)
	-- -rr doesn't palatalize (e.g. [[torr]] voc_s 'torre') but otherwise -Cr normally does.
	if rfind(word, "rr$") then
		return word
	end
	local stem = rmatch(word, "^(.*" .. export.cons_c .. ")r$")
	if stem then
		return stem .. "ř"
	end
	local try = make_try(word)
	return
		try("ch", "š") or
		try("[hg]", "ž") or
		is_adjective and try("sk", "št") or
		is_adjective and try("ck", "čt") or
		try("[kc]", "č") or
		word
end


function export.apply_second_palatalization(word, is_adjective)
	local try = make_try(word)
	return
		try("ch", "š") or
		try("[hg]", "z") or
		try("r", "ř") or
		is_adjective and try("sk", "št") or
		is_adjective and try("ck", "čt") or
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
	local stembegin, lastchar = rmatch(stem, "^(.*)([" .. export.followable_by_e_hacek .. "])$")
	if lastchar then
		return stembegin .. export.paired_plain_to_palatal[lastchar]
	else
		return stem
	end
end


function export.convert_paired_palatal_to_plain(stem, ending)
	-- For stems that alternate between n/t/d and ň/ť/ď, we always maintain the stem in the latter format and
	-- convert to the corresponding plain as needed, with e -> ě. Likewise stems ending in /bj/ /vj/ etc.
	-- use TEMP_SOFT_LABIAL.
	if ending and not rfind(ending, "^[eěií]") then
		return stem, ending
	end
	local stembegin, lastchar = rmatch(stem, "^(.*)([" .. export.paired_palatal .. export.TEMP_SOFT_LABIAL .. "])$")
	if lastchar then
		ending = rsub(ending, "^e", "ě")
		return stembegin .. export.paired_palatal_to_plain[lastchar], ending
	else
		return stem, ending
	end
end


function export.combine_stem_ending(base, slot, stem, ending)
	if stem == "?" then
		return "?"
	else
		-- Convert ňe and ňě -> ně.
		stem, ending = export.convert_paired_palatal_to_plain(stem, ending)
		-- We specify endings with -e/ě using ě, but some consonants cannot be followed by ě; convert to plain e.
		if rfind(ending, "^ě") and not rfind(stem, export.followable_by_e_hacek_c .. "$") then
			ending = rsub(ending, "^ě", "e")
		end
		-- There are occasional occurrences of soft-only consonants at the end of the stem in hard paradigms, e.g.
		-- [[banjo]] "banjo", [[gadžo]] "gadjo (non-Romani)", [[Miša]] "Misha, Mike", [[paša]] "pasha". These force a
		-- following y to turn into i. Things are tricky with -c; [[hec]] "joke" (hard masculine) has ins_pl 'hecy',
		-- but [[paňáca]] "jester, fop" has ins_pl 'paňáci'. We have to set a flag to indicate whether to allow y after
		-- c.
		if rfind(ending, "^y") and (rfind(stem, export.inherently_soft_not_c_c .. "$") or
			not base.hard_c and rfind(stem, "[cC]$")) then
			ending = rsub(ending, "^y", "i")
		end
		if base.all_uppercase then
			stem = uupper(stem)
		end
		return stem .. ending
	end
end


return export
