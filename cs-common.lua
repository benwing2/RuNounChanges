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

local lc_plain_labial = "mpbfvw"
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


function export.apply_vowel_alternation(alt, stem, noerror, ring_u_to_u)
	local modstem, origvowel
	if alt == "quant" or alt == "quant-ě" then
		modstem = rsub(stem, "(.)([ýíůáé])(" .. export.cons_c .. "*)$",
			function(pre, vowel, post)
				origvowel = vowel
				if alt == "quant-ě" then
					if vowel == "í" or vowel == "á" then
						-- [[sníh]] "snow", gen sg. 'sněhu'
						-- [[míra]] "snow", gen pl. 'měr'
						-- [[zábsti]] pres1s 'zebu'
						-- [[smát se]] pres1s 'směji se'
						-- [[přát]] pres1s 'přeji'
						-- Use combine_stem_ending() so we get ě or e as appropriate (and conceivably we could have
						-- e.g. 'ťát' -> 'těji' or similar).
						return export.combine_stem_ending(nil, nil, pre, "ě" .. post)
					else
						error(("Bad vowel in form '%s' for quantitative ě alternation, should be í or á"):format(stem))
					end
				elseif vowel == "í" then
					return pre .. "i" .. post
				elseif vowel == "ý" then
					return pre .. "y" .. post
				elseif vowel == "ů" then
					-- [[hůl]] "cane", gen sg. 'hole'
					-- [[půlit]] impv. 'pul'
					return pre .. (ring_u_to_u and "u" or "o") .. post
				elseif vowel == "é" then
					return pre .. "e" .. post
				else
					-- [[práce]] "work", ins sg. 'prací'
					return pre .. "a" .. post
				end
			end
		)
		-- [[houba]] "mushroom", gen pl. [[hub]]
		modstem = rsub(modstem, "ou(" .. export.cons_c .. "*)$", "u%1")
		if modstem == stem then
			if noerror then
				return stem, nil
			else
				error("Indicator '" .. alt .. "' can't be applied because stem '" .. stem .. "' doesn't have an í, ů, ou, á or é as its last vowel")
			end
		end
	elseif alt then
		error("Unrecognized quantitative alternation indicator '" .. alt .. "'")
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


function export.iotate(word)
	local try = make_try(word)
	return
		try("s[tť]", "šť") or
		try("z[dď]", "žď") or
		try("[tť]", "c") or
		try("[dď]", "z") or
		try("n", "ň") or
		try("s", "š") or
		try("z", "ž") or
		try("r", "ř") or
		try("ch", "š") or
		try("[kc]", "č") or
		try("[hg]", "ž") or
		word
end


function export.apply_first_palatalization(word, adjective_or_verb)
	if not adjective_or_verb then
		-- -rr doesn't palatalize (e.g. [[torr]] voc_s 'torre') but otherwise -Cr normally does.
		if rfind(word, "rr$") then
			return word
		end
		local stem = rmatch(word, "^(.*" .. export.cons_c .. ")r$")
		if stem then
			return stem .. "ř"
		end
	end
	local try = make_try(word)
	return
		try("ch", "š") or
		try("[hg]", "ž") or
		adjective_or_verb and try("sk", "šť") or
		adjective_or_verb and try("ck", "čť") or
		try("[kc]", "č") or
		word
end


function export.apply_second_palatalization(word, adjective_or_verb)
	local try = make_try(word)
	return
		try("ch", "š") or
		try("[hg]", "z") or
		try("rr", "ř") or
		try("r", "ř") or
		adjective_or_verb and try("sk", "šť") or
		adjective_or_verb and try("ck", "čť") or
		try("k", "c") or
		try("t", "ť") or
		try("d", "ď") or
		try("n", "ň") or
		word
end


function export.reduce(word)
	local pre, letter, vowel, post = rmatch(word, "^(.*)([" .. export.cons .. "y%-])([eě])(" .. export.cons_c .. "+)$")
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
	-- For stems that alternate between n/t/d and ň/ť/ď, we always maintain the stem in the latter format and convert
	-- to the corresponding plain as needed, with e -> ě. Likewise, stems ending in /bj/ /vj/ etc. use TEMP_SOFT_LABIAL.
	if ending and not rfind(ending, "^[Eeěií]") then
		stem = stem:gsub(export.TEMP_SOFT_LABIAL, "")
		return stem, ending
	end
	local stembegin, lastchar = rmatch(stem, "^(.*)([" .. export.paired_palatal .. export.TEMP_SOFT_LABIAL .. "])$")
	if lastchar then
		ending = ending and rsub(ending, "^e", "ě") or nil
		stem = stembegin .. export.paired_palatal_to_plain[lastchar]
	end
	-- 'E' has served its purpose of preventing the e -> ě conversion after a paired palatal (i.e. it depalatalizes
	-- paired palatals).
	ending = ending and rsub(ending, "^E", "e") or nil
	return stem, ending
end


function export.combine_stem_ending(base, slot, stem, ending)
	if stem == "?" then
		return "?"
	else
		-- There are occasional occurrences of soft-only consonants at the end of the stem in hard paradigms, e.g.
		-- [[banjo]] "banjo", [[gadžo]] "gadjo (non-Romani)", [[Miša]] "Misha, Mike", [[paša]] "pasha". These force a
		-- following y to turn into i. Things are tricky with -c; [[hec]] "joke" (hard masculine) has ins_pl 'hecy',
		-- but [[paňáca]] "jester, fop" has ins_pl 'paňáci'. We have to set a flag to indicate whether to allow y after
		-- c. This needs to proceed depalatalization of paired palatal consonants in the case of e.g. [[říďa]]
		-- "principal, headmaster", with instrumental plural 'řídi' (říďy -> říďi -> řídi).
		if rfind(ending, "^y") and (rfind(stem, export.inherently_soft_not_c_c .. "$") or
			not (base and base.hard_c) and rfind(stem, "[cC]$")) then
			ending = rsub(ending, "^y", "i")
		end
		-- Convert ňe and ňě -> ně. Convert nE and ňE -> ne. Convert ňi and ni -> ni.
		stem, ending = export.convert_paired_palatal_to_plain(stem, ending)
		-- We specify endings with -e/ě using ě, but some consonants cannot be followed by ě; convert to plain e.
		if rfind(ending, "^ě") and not rfind(stem, export.followable_by_e_hacek_c .. "$") then
			ending = rsub(ending, "^ě", "e")
		end
		if base and base.all_uppercase then
			stem = uupper(stem)
		end
		return stem .. ending
	end
end


return export
