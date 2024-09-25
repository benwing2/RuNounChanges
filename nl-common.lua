local export = {}

local m_str_utils = require("Module:string utilities")
local m_table = require("Module:table")

local lang = require("Module:languages").getByCode("nl")

local rsubn = m_str_utils.gsub
local rfind = m_str_utils.find
local rmatch = m_str_utils.match
local ulower = m_str_utils.lower
local usub = m_str_utils.sub

local function rsub(str, from, to)
	return (rsubn(str, from, to))
end

local irregular_diminutives = {
	{"blad", "blaadje"},
	{"gat", "gaatje"},
	{"glas", "glaasje"},
	{"jongen", "jongetje"},
	{"meid", "meisje"},
	{"pad", "paadje"},
	{"schip", "scheepje"},
	{"vat", "vaatje"},
}

local remove_diacritic = {
	["ä"] = "a",
	["ë"] = "e",
	["ï"] = "i",
	["ö"] = "o",
	["ü"] = "u",
	["â"] = "a",
	["ê"] = "e",
	["î"] = "i",
	["ô"] = "o",
	["û"] = "u",
}

local vowels = "AEIOUaeiouäëïöüâêîôû"
local V = "[" .. vowels .. "]"
local NV = "[^" .. vowels .. "]"
local long_vowels = m_table.listToSet {
	-- long monophthongs
	"aa", "ee", "ie", "oo", "uu",
	-- diphthongs
	"ai", "au", "ei", "eu", "ij", "oe", "ou", "oi", "ui"
}
local unstressed_last_two_letters_noun = m_table.listToSet {
	"er", "el", "en", "or", "em", "um"
}
local unstressed_last_two_letters_adjective = m_table.listToSet {
	"er", "el", "en", "or", "em", "um", "ig"
}

local lengthen = {
	["a"] = "aa",
	["e"] = "ee",
	["i"] = "ie",
	["o"] = "oo",
	["u"] = "uu",
	["A"] = "Aa",
	["E"] = "Ee",
	["I"] = "Ie",
	["O"] = "Oo",
	["U"] = "Uu",
	-- FIXME: Do the following ever occur and if so are these correct?
	["ä"] = "äa",
	["ë"] = "ëe",
	["ï"] = "ïe",
	["ö"] = "öo",
	["ü"] = "üu",
	-- FIXME: Do the following ever occur and if so are these correct?
	["â"] = "âa",
	["ê"] = "êe",
	["î"] = "îe",
	["ô"] = "ôo",
	["û"] = "ûu",
}

local devoice = {
	["z"] = "s", -- grijze -> grijs
	["v"] = "f", -- gave -> gaafje
}

local function devoice_final(form)
	local butlast, last = rmatch(form, "^(.*)(.)$")
	return butlast .. (devoice[last] or last)
end

local function normalize_form(form)
	return rsub(ulower(form), "[äëïöüâêîôû]", remove_diacritic)
end

local function ends_in_long_vowel(form)
	local last_two = rmatch(normalize_form(form), "(..)$")
	return last_two and long_vowels[last_two]
end

local function remove_final_e(form, final_multisyllable_stress)
	-- Must end in -e preceded by at least one vowel.
	local butlast = rmatch(form, "^(.*" .. V .. NV .. "*)[eë]$")
	if not butlast then
		return form
	end
	-- If ends in long vowel + -e (e.g. frije, luie), just truncate the -e.
	if ends_in_long_vowel(butlast) then
		return butlast
	end
	-- If ends in long vowel including + -e (e.g. twee?), return the whole thing.
	if ends_in_long_vowel(form) then
		return form
	end
	form = butlast
	local butlast = rmatch(form, "^(.*)" .. NV .. "$")
	if butlast and ends_in_long_vowel(butlast) then
		return devoice_final(form)
	end
	if not final_multisyllable_stress then
		local last_two = rmatch(normalize_form(form), V .. NV .. "*(..)$")
		if last_two and unstressed_last_two_letters_adjective[last_two] then
			return devoice_final(form)
		end
	end
	local butlast_two, last_v, last_c = rmatch(form, "^(.*)(" .. V .. ")(" .. NV .. ")$")
	if butlast_two then
		return butlast_two .. lengthen[last_v] .. devoice_final(last_c)
	end
	local base, last_c = rmatch(form, "^(.*)(" .. NV .. ")%2$")
	if base then
		return base .. devoice_final(last_c)
	end
	return devoice_final(form)
end

-- Based on [https://www.dutchgrammar.com/en/?n=NounsAndArticles.23].
function export.default_dim(lemma, final_multisyllable_stress, modifier_final_multisyllable_stress, first_only)
	if first_only then
		local first_word, rest = rmatch(lemma, "^([^ ]+) (.*)$")
		if first_word then
			return export.default_dim(first_word, final_multisyllable_stress, modifier_final_multisyllable_stress) .. " " ..
				rest
		end
	end
	local first_word, rest = rmatch(lemma, "^([^ ]+[eë]) (.*)$")
	if first_word then
		return remove_final_e(first_word, modifier_final_multisyllable_stress) .. " " .. export.default_dim(
				rest, final_multisyllable_stress, modifier_final_multisyllable_stress)
	end
	for _, ending_repl in ipairs(irregular_diminutives) do
		local ending, repl = unpack(ending_repl)
		if rfind(lemma, ending .. "$") then
			return usub(lemma, 1, -#ending - 1) .. repl
		end
	end
	if ends_in_long_vowel(lemma) then
		return lemma .. "tje"
	end
	if rfind(lemma, "[aouäöü]$") then
		return usub(lemma, 1, -2) .. lengthen[usub(lemma, -1)] .. "tje"
	end
	if rfind(lemma, "i$") then
		return lemma .. "etje"
	end
	if rfind(lemma, NV .. "y$") then
		return lemma .. "'tje"
	end
	if rfind(lemma, "é$") then
		return usub(lemma, 1, -2) .. "eetje"
	end
	if final_multisyllable_stress and rfind(lemma, "e$") then
		lemma = remove_final_e(lemma, true)
	end
	if (rfind(lemma, V .. "$") or rfind(lemma, "[wy]$") or
		rfind(lemma, "[rln]$") and ends_in_long_vowel(usub(lemma, 1, -2)) or rfind(lemma, "rn$")) then
		return lemma .. "tje"
	end
	if rfind(lemma, V .. NV .. "*[eë][rln]$") or rfind(lemma, V .. NV .. "*[oö]r$") then
		-- NOTE: we already handled LONGV .. [rln]$ above, so any occurrence of V .. (e[rln]|or)$ is not a long vowel
		-- or diphthong.
		return final_multisyllable_stress and lemma .. usub(lemma, -1) .. "etje" or lemma .. "tje"
	end
	if rfind(lemma, V .. "[rln]$") then
		-- NOTE: we already handled LONGV .. [rln]$ above, so any occurrence of V .. [rln]$ is not a long vowel or
		-- diphthong.
		return lemma .. usub(lemma, -1) .. "etje"
	end
	if rfind(lemma, "m$") and ends_in_long_vowel(usub(lemma, 1, -2)) or rfind(lemma, "[lr]m$") then
		return lemma .. "pje"
	end
	if rfind(lemma, V .. NV .. "*[eëuü]m$") then
		-- NOTE: we already handled LONGV .. m$ above, so any occurrence of V .. [eu]m$ is not a long vowel or
		-- diphthong.
		return final_multisyllable_stress and lemma .. usub(lemma, -1) .. "etje" or lemma .. "pje"
	end
	if rfind(lemma, V .. "m$") then
		-- NOTE: we already handled LONGV .. m$ above, so any occurrence of V .. m$ is not a long vowel or diphthong.
		return lemma .. usub(lemma, -1) .. "etje"
	end
	if rfind(lemma, "ng$") and ends_in_long_vowel(usub(lemma, 1, -3)) then
		-- NOTE: This may not exist.
		return lemma .. "je"
	end
	if rfind(lemma, V .. NV .. "*[iï]ng$") then
		-- NOTE: we already handled LONGV .. ng$ above, so any occurrence of V .. ing$ is not a long vowel or diphthong.
		return final_multisyllable_stress and lemma .. "etje" or usub(lemma, 1, -2) .. "kje"
	end
	if rfind(lemma, V .. "ng$") then
		-- NOTE: we already handled LONGV .. ng$ above, so any occurrence of V .. ng$ is not a long vowel or diphthong.
		return lemma .. "etje"
	end
	return lemma .. "je"
end

function export.add_e(stem, weak_final, lengthen)
	-- Vowel lengthening
	if lengthen then
		return rsub(stem, "i(.)$", "e%1") .. "e"
	-- Final weak syllable, no consonant doubling
	elseif weak_final then
		if stem:find("ie$") then
			return stem:gsub("ie$", "ië")
		else
			return stem .. "e"
		end
	else
		-- Ends in ee, ie, oe
		if stem:find("[eio]e$") then
			return stem .. "ë"
		-- Ends in e
		elseif stem:find("e$") then
			return stem
		-- Ends in double vowel + single consonant, remove one of the vowels
		elseif stem:find("([aeou])%1[bcdfgklmnpqrstvxz]$") then
			-- Add a diaeresis if the removal would create a digraph
			if rfind(stem, "[io]ee.$") then
				return rsub(stem, "..(.)$", "ë%1e")
			else
				return rsub(stem, ".(.)$", "%1e")
			end
		-- Ends in single vowel + single consonant, double the consonant
		elseif stem:find("[AaEeIiOoUu][bcdfgklmnpqrstvz]$") and not rfind(stem, "[IiïOoö]e.$") and (not rfind(stem, "[AaäEeëOoöUuü]i.$") or rfind(stem, "qui.$")) and not rfind(stem, "[AaäEeëOoö]u.$") then
			return rsub(stem, "(.)$", "%1%1e")
		else
			return stem .. "e"
		end
	end
end

return export
