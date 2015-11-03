--[[
This module holds functions shared between ru-noun and ru-adjective.
]]

local export = {}

local lang = require("Module:languages").getByCode("ru")

local ut = require("Module:utils")
local m_links = require("Module:links")
local com = require("Module:ru-common")
local m_ru_translit = require("Module:ru-translit")

local u = mw.ustring.char
local rfind = mw.ustring.find
local rsubn = mw.ustring.gsub
local rmatch = mw.ustring.match
local rsplit = mw.text.split
local ulower = mw.ustring.lower
local uupper = mw.ustring.upper
local usub = mw.ustring.sub

-- version of rsubn() that discards all but the first return value
local function rsub(term, foo, bar)
	local retval = rsubn(term, foo, bar)
	return retval
end

--------------------------------------------------------------------------
--                        Used for manual translit                      --
--------------------------------------------------------------------------

function export.translit_no_links(text)
	return com.translit(m_links.remove_links(text))
end

function export.split_russian_tr(term, dopair)
	local ru, tr
	if not rfind(term, "//") then
		ru = term
	else
		splitvals = rsplit(term, "//")
		if #splitvals ~= 2 then
			error("Must have at most one // in a Russian//translit expr: '" .. term .. "'")
		end
		ru, tr = splitvals[1], com.decompose(splitvals[2])
	end
	if dopair then
		return {ru, tr}
	else
		return ru, tr
	end
end

function export.concat_russian_tr(ru1, tr1, ru2, tr2, dopair)
	local ru, tr
	if not tr1 and not tr2 then
		ru = ru1 .. ru2
	else
		if not tr1 then
			tr1 = export.translit_no_links(ru1)
		end
		if not tr2 then
			tr2 = export.translit_no_links(ru2)
		end
		ru, tr = ru1 .. ru2, com.j_correction(tr1 .. tr2)
	end
	if dopair then
		return {ru, tr}
	else
		return ru, tr
	end
end

function export.concat_paired_russian_tr(term1, term2)
	assert(type(term1) == "table")
	assert(type(term2) == "table")
	local ru1, tr1 = term1[1], term1[2]
	local ru2, tr2 = term2[1], term2[2]
	return export.concat_russian_tr(ru1, tr1, ru2, tr2, "dopair")
end

function export.concat_forms(forms)
	local joined_rutr = {}
	for _, form in ipairs(forms) do
		local ru, tr = form[1], form[2]
		if tr then
			table.insert(joined_rutr, ru .. "//" .. tr)
		else
			table.insert(joined_rutr, ru)
		end
	end
	return table.concat(joined_rutr, ",")
end

function export.strip_tr_ending(tr, ending)
	if not tr then return nil end
	local endingtr = rsub(export.translit_no_links(ending), "^([Jj])", "%1?")
	local strippedtr = rsub(tr, endingtr .. "$", "")
	if strippedtr == tr then
		error("Translit " .. tr .. " doesn't end with expected ending " .. endingtr)
	end
	return strippedtr
end

function export.combine_stem_and_suffix(stem, tr, suf, rules, old)
	local first = usub(suf, 1, 1)
	if rules then
		local conv = rules[first]
		if conv then
			local ending = usub(suf, 2)
			if old and conv == "и" and rfind(ending, "^́?[" .. com.vowel .. "]") then
				conv = "і"
			end
			suf = conv .. ending
		end
	end
	-- If <adj> is present in the suffix, it means we need to translate it
	-- specially; do that now.
	local is_adj = rfind(suf, "<adj>")
	suf = rsub(suf, "<adj>", "")
	local suftr = is_adj and m_ru_translit.tr_adj(suf)
	return export.concat_russian_tr(stem, tr, suf, suftr, "dopair"), suf
end

--------------------------------------------------------------------------
--                          Sibilant/Velar/ц rules                      --
--------------------------------------------------------------------------

local stressed_sibilant_rules = {
	["я"] = "а",
	["ы"] = "и",
	["ё"] = "о́",
	["ю"] = "у",
}

local stressed_c_rules = {
	["я"] = "а",
	["ё"] = "о́",
	["ю"] = "у",
}

local unstressed_sibilant_rules = {
	["я"] = "а",
	["ы"] = "и",
	["о"] = "е",
	["ю"] = "у",
}

local unstressed_c_rules = {
	["я"] = "а",
	["о"] = "е",
	["ю"] = "у",
}

local velar_rules = {
	["ы"] = "и",
}

export.stressed_rules = {
	["ш"] = stressed_sibilant_rules,
	["щ"] = stressed_sibilant_rules,
	["ч"] = stressed_sibilant_rules,
	["ж"] = stressed_sibilant_rules,
	["ц"] = stressed_c_rules,
	["к"] = velar_rules,
	["г"] = velar_rules,
	["х"] = velar_rules,
}

export.unstressed_rules = {
	["ш"] = unstressed_sibilant_rules,
	["щ"] = unstressed_sibilant_rules,
	["ч"] = unstressed_sibilant_rules,
	["ж"] = unstressed_sibilant_rules,
	["ц"] = unstressed_c_rules,
	["к"] = velar_rules,
	["г"] = velar_rules,
	["х"] = velar_rules,
}

export.nonsyllabic_suffixes = ut.list_to_set({"", "ъ", "ь", "й"})

export.sibilant_suffixes = ut.list_to_set({"ш", "щ", "ч", "ж"})

return export

-- For Vim, so we get 4-space tabs
-- vim: set ts=4 sw=4 noet:
