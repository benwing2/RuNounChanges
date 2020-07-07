local export = {}

local u = mw.ustring.char
local rsplit = mw.text.split
local rfind = mw.ustring.find
local rsubn = mw.ustring.gsub
local ulen = mw.ustring.len

-- version of rsubn() that discards all but the first return value
local function rsub(term, foo, bar)
	local retval = rsubn(term, foo, bar)
	return retval
end


local AC = u(0x0301) -- acute =  ́
local GR = u(0x0300) -- acute =  ̀

export.vowel = "аеіоуяэыёюАЕІОУЯЭЫЁЮ"
export.vowel_c = "[" .. export.vowel .. "]"
export.non_vowel_c = "[^" .. export.vowel .. "]"
export.velar = "кгґх"
export.velar_c = "[" .. export.velar .. "]"


export.VAR1 = u(0xFFF0)
export.VAR2 = u(0xFFF1)
export.VAR3 = u(0xFFF2)
export.var_code_c = "[" .. export.VAR1 .. export.VAR2 .. export.VAR3 .. "]"


local grave_deaccenter = {
	[GR] = "", -- grave accent
	["ѐ"] = "е", -- composed Cyrillic chars w/grave accent
	["Ѐ"] = "Е",
	["ѝ"] = "и",
	["Ѝ"] = "И",
}

local deaccenter = mw.clone(grave_deaccenter)
deaccenter[AC] = "" -- acute accent

local destresser = mw.clone(deaccenter)
destresser["ё"] = "е"
destresser["Ё"] = "Е"
destresser["о"] = "а"
destresser["О"] = "А"
destresser["э"] = "а"
destresser["Э"] = "А"

local pre_tonic_stresser = mw.clone(destresser)
pre_tonic_stresser["ё"] = "я"
pre_tonic_stresser["Ё"] = "Я"


-- Remove acute and grave accents; don't affect ёЁ.
function export.remove_accents(word)
	return rsub(word, "[́̀ѐЀѝЍ]", deaccenter)
end


function export.remove_variant_codes(word)
	return rsub(word, export.var_code_c, "")
end


function export.needs_accents(text)
	for _, word in ipairs(rsplit(text, "%s+")) do
		-- A word needs accents if it contains no accent or ё and has more than one vowel
		if not export.is_stressed(word) and not export.is_monosyllabic(word) then
			return true
		end
	end
	return false
end


function export.is_stressed(word)
	return rfind(word, "[́ёЁ]")
end


function export.is_initial_stressed(word)
	return rfind(word, "^" .. export.non_vowel_c .. "*" .. export.vowel_c .. AC) or
		not rfind(word, AC) and rfind(word, "^" .. export.non_vowel_c .. "*[ёЁ]")
end


function export.is_final_stressed(word)
	return rfind(word, AC .. export.non_vowel_c .. "*$") or
		not rfind(word, AC) and rfind(word, "[ёЁ]" .. export.non_vowel_c .. "*$")
end


-- Make a word unstressed, appropriately handling akanye and yakanye. PRE_TONIC indicates
-- whether ё should be converted to я (PRE_TONIC is true) or е (otherwise).
function export.make_unstressed(word, pre_tonic)
	local destresser = pre_tonic and pre_tonic_destresser or destresser
	-- ё may occur in unstressed syllables, e.g. ра́дыё "radio". э may occur in
	-- unstressed syllables, e.g. тэлеві́зар "television". Possibly the same
	-- with о. In this case, we don't want to modify the ё/э/о. But we do want to
	-- modify stressed ё́/э́/о́ appropriately.
	if rfind(word, AC) then
		word = rsub(word, "([ёЁэЭоО])́", function(vowel)
			return destresser[vowel]
		end)
		return rsub(word, AC, "")
	end
	return rsub(word, "[̀ёЁэЭоОѐЀѝЍ]", destresser)
end


-- Move the stress notionally left one syllable from an unspecified syllable to the right
-- of the given word to the last syllable of the word. Doing this stresses the last syllable
-- and may cause a vowel alternation. If `vowel_alternant` is given, it should be "ao"
-- (in Latin letters) to indicate a change from Cyrillic а -> о or я —> ё, and "ae"
-- (in Latin letters) to indicate a change from Cyrillic а -> э or я -> е.
function export.move_stress_left_onto_last_syllable(stem, vowel_alternant)
	if rfind(word, AC) then
		error("Stem '" .. stem .. "' already has stress on it")
	end
	stem = rsub(stem, "(" .. export.vowel_c .. ")(" .. export.non_vowel_c .. "-)$", "%1" .. AC .. "%2")
	if vowel_alternant == "ao" then
		local new_stem = rsub(stem, "([ая])́", {["а"] = "о", ["я"] = "ё"})
		if new_stem == stem then
			error("Indicator 'ao' can't be applied because stem '" .. stem .. "' doesn't have an а or я as its last vowel")
		end
		stem = new_stem
	elseif vowel_alternant == "ae" then
		local new_stem = rsub(stem, "([ая])́", {["а"] = "э", ["я"] = "е"})
		if new_stem == stem then
			error("Indicator 'ae' can't be applied because stem '" .. stem .. "' doesn't have an а or я as its last vowel")
		end
		stem = new_stem
	end
	-- An е that was two syllables to the left of the stress must turn into я.
	stem = rsub(stem, "е(" .. export.non_vowel_c .. "*" .. export.vowel_c ..
		export.non_vowel_c .. "*)$", "я%1")
	return stem
end


function export.is_multi_stressed(text)
	for _, word in ipairs(rsplit(text, "[%s%-]+")) do
		if ulen(rsub(word, "[^́]", "")) > 1 then
			return true
		end
	end
	return false
end


-- Check if word is monosyllabic (also includes words without vowels).
function export.is_monosyllabic(word)
	local num_syl = ulen(rsub(word, export.non_vowel_c, ""))
	return num_syl <= 1
end


-- If word is monosyllabic, add an accent mark to the vowel. Don't affect ёЁ.
function export.add_monosyllabic_stress(word)
	if export.is_monosyllabic(word) and not rfind(word, "^%-") and not rfind(word, "%-$") and
		not export.is_stressed(word) then
		word = rsub(word, "(" .. export.vowel_c .. ")", "%1" .. AC)
	end
	return word
end


-- If word is monosyllabic, remove accent marks from the vowel.
function export.remove_monosyllabic_accents(word)
	if export.is_monosyllabic(word) and not rfind(word, "^%-") and not rfind(word, "%-$") then
		return export.remove_accents(word)
	end
	return word
end


-- Handles the alternation between initial і/у and й/ў.
function export.initial_alternation(word, previous)
	if type(word) == "table" then
		word, previous = word.args[1], word.args[2]
	end
	if rfind(word, "^[іІ]") or rfind(word, "^[йЙ]" .. export.non_vowel_c) then
		if rfind(previous, export.vowel_c .. AC .. "?$") then
			return rsub(word, "^[іІ]", {["і"] = "й", ["І"] = "Й"})
		else
			return rsub(word, "^[йЙ]", {["й"] = "і", ["Й"] = "І"})
		end
	elseif rfind(word, "^[уУ]") or rfind(word, "^[ўЎ]" .. export.non_vowel_c) then
		if rfind(previous, export.vowel_c .. AC .. "?$") then
			return rsub(word, "^[уУ]", {["у"] = "ў", ["У"] = "Ў"})
		else
			return rsub(word, "^[ўЎ]", {["ў"] = "у", ["Ў"] = "У"})
		end
	end
	
	return word
end


function export.u_v_alternation_msg(frame)
	local m_links = require("Module:links")
	local lang = require("Module:languages").getByCode("be")
	local params = {
		[1] = {}
	}
	local parargs = frame:getParent().args
	local args = require("Module:parameters").process(parargs, params)
	local alternant = args[1] or mw.title.getCurrentTitle().text
	local ualt, valt, ufirst
	if rfind(alternant, "^[ўЎ]") then
		valt = alternant
		ualt = rsub(export.add_monosyllabic_stress(valt), "^([ўЎ])", {["ў"] = "у", ["Ў"] = "У"})
		ufirst = false
	else
		ualt = alternant
		valt = export.remove_monosyllabic_accents(rsub(ualt, "^([уУ])", {["у"] = "ў", ["У"] = "Ў"}))
		ufirst = true
	end
	ualt = m_links.full_link({lang = lang, term = ualt}, "term") .. " (used after consonants or at the beginning of a clause)"
	valt = m_links.full_link({lang = lang, term = valt}, "term") .. " (used after vowels)"
	local first, second
	if ufirst then
		first, second = ualt, valt
	else
		first, second = valt, ualt
	end
	return "The forms " .. first .. " and " .. second .. " differ in pronunciation but are considered variants of the same word."
end


return export
