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

local lc_vowel = "aeiouyáéíóúýěů"
local uc_vowel = uupper(lc_vowel)
export.vowel = lc_vowel .. uc_vowel
export.vowel_c = "[" .. export.vowel .. "]"
export.non_vowel_c = "[^" .. export.vowel .. "]"
local lc_cons = "bcdfghjklmnpqrstvwxzčňřšžďť"
local uc_cons = uupper(lc_cons)
export.cons = lc_cons .. uc_cons
export.cons_c = "[" .. export.cons .. "]"
-- uppercase consonants
export.uppercase = lc_vowel .. uc_vowel
export.uppercase_c = "[" .. export.uppercase .. "]"
local lc_paired_palatal = "ňďť"
local uc_paired_palatal = "ŇĎŤ"
export.paired_palatal = lc_paired_palatal .. uc_paired_palatal
local lc_paired_plain = "ndt"
local uc_paired_plain = "NDT"
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


function export.iotate(stem)
	error("Unimplemented")
	stem = rsub(stem, "с[кт]$", "щ")
	stem = rsub(stem, "з[дгґ]$", "ждж")
	stem = rsub(stem, "к?т$", "ч")
	stem = rsub(stem, "зк$", "жч")
	stem = rsub(stem, "[кц]$", "ч")
	stem = rsub(stem, "[сх]$", "ш")
	stem = rsub(stem, "[гз]$", "ж")
	stem = rsub(stem, "д$", "дж")
	stem = rsub(stem, "([бвмпф])$", "%1л")
	return stem
end


function export.apply_first_palatalization(word)
	local function try(from, to)
		local stem = rmatch(word, "^(.*)" .. from .. "$")
		if stem then
			return stem .. to
		end
		return nil
	end
	return try("ch", "š") or
		try("[hg]", "ž") or
		try("tr", "tř") or
		try("sk", "št") or
		try("ck", "čt") or
		try("[kc]", "č") or
		word
end


function export.apply_second_palatalization(word)
	local function try(from, to)
		local stem = rmatch(word, "^(.*)" .. from .. "$")
		if stem then
			return stem .. to
		end
		return nil
	end
	return try("ch", "š") or
		try("[hg]", "z") or
		try("r", "ř") or
		try("sk", "št") or
		try("ck", "čt") or
		try("k", "c") or
		word
end


function export.reduce(word)
	local pre, letter, post = rmatch(word, "^(.*)([eEěĚ])́?(" .. export.cons_c .. "+)$")
	if not pre then
		return nil
	end
	if (letter == "ě" or letter == "Ě") and rfind(pre, "[" .. export.paired_plain .. "]") then
		pre = export.paired_plain_to_palatal[pre]
	end
	return pre .. post
end


function export.dereduce(stem)
	local pre, letter, post = rmatch(stem, "^(.*)(" .. export.cons_c .. ")(" .. export.cons_c .. ")$")
	if not pre then
		return nil
	end
	local is_upper = rfind(post, export.uppercase_c)
	if rfind(letter, "[" .. export.paired_palatal .. "]") then
		letter = export.paired_palatal_to_plain[letter]
		epvowel = is_upper and "Ě" or "ě"
	else
		epvowel = is_upper and "E" or "e"
	end
	return pre .. letter .. epvowel .. post
end


return export
