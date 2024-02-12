local export = {}

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
export.TEMP_SOFT_LABIAL = u(0xFFF1) -- used to indicate that a labial consonant is soft and needs i after it

local lc_vowel = "aeiouyąęó"
local uc_vowel = uupper(lc_vowel)
export.vowel = lc_vowel .. uc_vowel
export.vowel_c = "[" .. export.vowel .. "]"
export.non_vowel_c = "[^" .. export.vowel .. "]"
local lc_cons = "bcćdfghjklłmnńprqstvwxzżź" .. export.TEMP_CH .. export.TEMP_SOFT_LABIAL
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

local lc_paired_palatal = "ćńśź"
local uc_paired_palatal = uupper(lc_paired_palatal)
export.paired_palatal = lc_paired_palatal .. uc_paired_palatal
local lc_paired_plain = "cnsz"
local uc_paired_plain = uupper(lc_paired_plain)
export.paired_plain = lc_paired_plain .. uc_paired_plain
export.paired_palatal_to_plain = {
	["ć"] = "c",
	["Ć"] = "C",
	["ń"] = "n",
	["Ń"] = "N",
	["ś"] = "s",
	["Ś"] = "S",
	["ź"] = "z",
	["Ź"] = "Z",
}
export.paired_plain_to_palatal = {}
for k, v in pairs(export.paired_palatal_to_plain) do
	export.paired_plain_to_palatal[v] = k
end
export.paired_palatal_to_plain[export.TEMP_SOFT_LABIAL] = ""
for labial in mw.ustring.gmatch(export.plain_labial, ".") do
	export.paired_plain_to_palatal[labial] = labial .. export.TEMP_SOFT_LABIAL
end

local lc_inherently_soft = "ćńśź" .. export.TEMP_SOFT_LABIAL
local uc_inherently_soft = uupper(lc_inherently_soft)
export.inherently_soft = lc_inherently_soft .. uc_inherently_soft
export.inherently_soft_c = "[" .. export.inherently_soft .. "]"


local function make_try(word)
	return function(from, to)
		local subbed
		word, subbed = rsubb(word, "^(.*)" .. from .. "$", "%1" .. to)
		if subbed then
			return word
		end
		return nil
	end
end


function export.soften_masc_pers_pl(word)
	local try = make_try(word)
	return
		try("ch", "si") or
		try("h", "si") or
		try("sł", "śli") or
		try("zł", "źli") or
		try("ł", "li") or
		try("r", "rzy") or
		try("sn", "śni") or
		try("zn", "źni") or
		try("st", "ści") or
		try("t", "ci") or
		try("zd", "ździ") or
		try("d", "dzi") or
		try("sz", "si") or
		try("([cdr]z)", "%2y") or
		try("([fwmpbnsz])", "%2i") or
		try("stk", "scy") or -- [[wszystek]] -> 'wszysci'
		try("k", "cy") or
		try("g", "dzy") or
		word .. "y"
end


function export.soften_fem_dat_sg(word)
	local try = make_try(word)
	return
		try("ch", "sze") or
		try("h", "że") or
		try("sł", "śle") or
		try("zł", "źle") or
		try("ł", "le") or
		try("(" .. export.vowel_c .. ")j", "%2i") or
		try("([jl])", "%2i") or
		try("r", "rze") or
		try("sn", "śnie") or
		try("zn", "źnie") or
		-- n below
		try("sm", "śmie") or
		-- FIXME: zm? The old code had a note '-zm should not be palatalized' but also had zm -> zmie.
		-- m below
		try("st", "ście") or
		try("t", "cie") or
		try("zd", "ździe") or
		try("d", "dzie") or
		try("([cdsr]z)", "%2y") or
		try("([fwmpbnsz])", "%2ie") or
		try("([fwmpbcnsz]i)", "%2") or
		try("stk", "sce") or -- FIXME: examples?
		try("k", "ce") or
		try("g", "dze") or
		word .. "y"
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
	-- FIXME
	--if ending and not rfind(ending, "^[ěií]") then
	--	return stem
	--end
	local stembegin, lastchar = rmatch(stem, "^(.*)([" .. export.paired_plain .. export.plain_labial .. "])$")
	if lastchar then
		return stembegin .. export.paired_plain_to_palatal[lastchar]
	else
		return stem
	end
end


function export.convert_paired_palatal_to_plain(stem, ending)
	-- For stems that alternate between ci/ni/si/zi and ć/ń/ś/ź, we always maintain the stem in the latter format and
	-- convert to the corresponding plain as needed. Likewise, stems ending in /bj/ /vj/ etc. use TEMP_SOFT_LABIAL.
	-- FIXME
	--if ending and not rfind(ending, "^[Eeěií]") then
	--	stem = stem:gsub(export.TEMP_SOFT_LABIAL, "")
	--	return stem, ending
	--end
	local stembegin, lastchar = rmatch(stem, "^(.*)([" .. export.paired_palatal .. export.TEMP_SOFT_LABIAL .. "])$")
	if lastchar then
		-- FIXME
		-- ending = ending and rsub(ending, "^e", "ě") or nil
		stem = stembegin .. export.paired_palatal_to_plain[lastchar]
	end
	-- FIXME
	-- 'E' has served its purpose of preventing the e -> ě conversion after a paired palatal (i.e. it depalatalizes
	-- paired palatals).
	-- ending = ending and rsub(ending, "^E", "e") or nil
	return stem -- , ending
end


function export.combine_stem_ending(base, slot, stem, ending)
	if stem == "?" then
		return "?"
	else
		if ending:find("^y") and (rfind(stem, export.inherently_soft_c .. "$") or stem:find("[kgl]$")) then
			ending = ending:gsub("^y", "i")
		end
		if rfind(ending, "^" .. export.vowel_c) then
			-- Convert ńi -> ni, and ńe (or any other vowel) -> nie.
			stem = export.convert_paired_palatal_to_plain(stem) .. (ending == "i" and "" or "i")
		end
		if stem:find("j$") and ending:find("^i") then
			stem = stem:gsub("j$", "")
		end
		if base and base.all_uppercase then
			stem = uupper(stem)
		end
		return stem .. ending
	end
end


return export
