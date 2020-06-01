local export = {}

local lang = require("Module:languages").getByCode("uk")
local m_links = require("Module:links")
local m_table = require("Module:table")
local m_string_utilities = require("Module:string utilities")
local m_uk_translit = require("Module:uk-translit")

local u = mw.ustring.char
local rsplit = mw.text.split
local rfind = mw.ustring.find
local rmatch = mw.ustring.match
local rsubn = mw.ustring.gsub
local ulen = mw.ustring.len
local ulower = mw.ustring.lower

-- version of rsubn() that discards all but the first return value
local function rsub(term, foo, bar)
	local retval = rsubn(term, foo, bar)
	return retval
end


local AC = u(0x0301) -- acute =  ́


export.vowel = "аеиоуіїяєюАЕИОУІЇЯЄЮ"
export.vowel_c = "[" .. export.vowel .. "]"
export.non_vowel_c = "[^" .. export.vowel .. "]"
export.cons = "бцдфгґчйклмнпрствшхзжьщ'БЦДФГҐЧЙКЛМНПРСТВШХЗЖЬЩ"
export.cons_c = "[" .. export.cons .. "]"
export.hushing = "чшжщЧШЖЩ"
export.hushing_c = "[" .. export.hushing .. "]"


function export.translit_no_links(text)
	return m_uk_translit.tr(m_links.remove_links(text))
end


function export.needs_accents(word)
	if rfind(word, AC) then
		return false
	-- A word needs accents if it contains more than one vowel
	elseif not export.is_monosyllabic(word) then
		return true
	else
		return false
	end
end


function export.is_stressed(word)
	return rfind(word, AC)
end


function export.remove_stress(word)
	return rsub(word, AC, "")
end


-- Handles the alternation between initial і/у and й/в.
function export.initial_alternation(word, previous)
	if rfind(word, "^[іІ]") or rfind(word, "^[йЙ]" .. export.non_vowel_c) then
		if rfind(previous, export.vowel_c .. AC .. "?$") then
			return rsub(word, "^[іІ]", {["і"] = "й", ["І"] = "Й"})
		else
			return rsub(word, "^[йЙ]", {["й"] = "і", ["Й"] = "І"})
		end
	elseif rfind(word, "^[уУ]") or rfind(word, "^[вВ]" .. export.non_vowel_c) then
		if rfind(previous, export.vowel_c .. AC .. "?$") then
			return rsub(word, "^[уУ]", {["у"] = "в", ["У"] = "В"})
		else
			return rsub(word, "^[вВ]", {["в"] = "у", ["В"] = "У"})
		end
	end
	
	return word
end


-- Check if word is monosyllabic (also includes words without vowels).
function export.is_monosyllabic(word)
	local num_syl = ulen(rsub(word, export.non_vowel_c, ""))
	return num_syl <= 1
end


-- If word is monosyllabic, add stress to the vowel.
function export.add_monosyllabic_stress(word)
	if export.is_monosyllabic(word) and not rfind(word, "^%-") and not rfind(word, AC) then
		word = rsub(word, "(" .. export.vowel_c .. ")", "%1" .. AC)
	end
	return word
end


-- If word is monosyllabic, remove stress from the vowel.
function export.remove_monosyllabic_stress(word)
	if export.is_monosyllabic(word) and not rfind(word, "^%-") then
		return export.remove_stress(word)
	end
	return word
end


-- Check if word is nonsyllabic.
function export.is_nonsyllabic(word)
	local num_syl = ulen(rsub(word, export.non_vowel_c, ""))
	return num_syl == 0
end


-- If word is unstressed, add stress onto initial syllable.
function export.maybe_stress_initial_syllable(word)
	if not rfind(word, AC) then
		-- stress first syllable
		word = rsub(word, "^(.-" .. export.vowel_c .. ")", "%1" .. AC)
	end
	return word
end


-- If word is unstressed, add stress onto final syllable.
function export.maybe_stress_final_syllable(word)
	if not rfind(word, AC) then
		-- stress last syllable
		word = rsub(word, "(.*" .. export.vowel_c .. ")", "%1" .. AC)
	end
	return word
end


function export.iotate(stem)
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


-- Given a list of forms (each of which is a table of the form {form=FORM, footnotes=FOOTNOTES}),
-- concatenate into a SLOT=FORM,FORM,... string, replacing embedded | signs with <!>.
function export.concat_forms_in_slot(forms)
	if forms then
		local new_vals = {}
		for _, v in ipairs(forms) do
			table.insert(new_vals, rsub(v.form, "|", "<!>"))
		end
		return table.concat(new_vals, ",")
	else
		return nil
	end
end


return export
