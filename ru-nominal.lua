--[[
This module holds functions shared between ru-noun and ru-adjective.
]]

local export = {}

local lang = require("Module:languages").getByCode("ru")

local m_links = require("Module:links")
local m_table = require("Module:table")
local com = require("Module:ru-common")
local m_ru_translit = require("Module:ru-translit")
local m_table_tools = require("Module:table tools")

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

local function concat_maybe_moving_notes(x, y, movenotes)
	if movenotes then
		local xentry, xnotes = m_table_tools.separate_notes(x)
		local yentry, ynotes = m_table_tools.separate_notes(y)
		return xentry .. yentry .. xnotes .. ynotes
	else
		return x .. y
	end
end

-- Concatenate two Russian strings RU1 and RU2 that may have corresponding
-- manual transliteration TR1 and TR2 (which should be nil if there is no
-- manual translit). If DOPAIR, return a two-item list of the combined
-- Russian and manual translit (which will be nil if both TR1 and TR2 are
-- nil); else, return two values, the combined Russian and manual translit.
-- If MOVENOTES, extract any footnote symbols at the end of RU1 and move
-- them to the end of the concatenated string, before any footnote symbols
-- for RU2; same thing goes for TR1 and TR2.
function export.concat_russian_tr(ru1, tr1, ru2, tr2, dopair, movenotes)
	local ru, tr
	if not tr1 and not tr2 then
		ru = concat_maybe_moving_notes(ru1, ru2, movenotes)
	else
		if not tr1 then
			tr1 = export.translit_no_links(ru1)
		end
		if not tr2 then
			tr2 = export.translit_no_links(ru2)
		end
		ru, tr = concat_maybe_moving_notes(ru1, ru2, movenotes), com.j_correction(concat_maybe_moving_notes(tr1, tr2, movenotes))
	end
	if dopair then
		return {ru, tr}
	else
		return ru, tr
	end
end

-- Concatenate two Russian/translit combinations (where each combination is
-- a two-element list of {RUSSIAN, TRANSLIT} where TRANSLIT may be nil) by
-- individually concatenating the Russian and translit portions, and return
-- a concatenated combination as a two-element list. If the manual translit
-- portions of both terms on entry are nil, the result will also have nil
-- manual translit. If MOVENOTES, extract any footnote symbols at the end
-- of TERM1 and move them after the concatenated string and before any
-- footnote symbols at the end of TERM2.
function export.concat_paired_russian_tr(term1, term2, movenotes)
	assert(type(term1) == "table")
	assert(type(term2) == "table")
	local ru1, tr1 = term1[1], term1[2]
	local ru2, tr2 = term2[1], term2[2]
	return export.concat_russian_tr(ru1, tr1, ru2, tr2, "dopair", movenotes)
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

-- Given a list of forms, where each form is a two-element list of {RUSSIAN, TRANSLIT}, strip footnote symbols from the
-- end of the Russian and translit.
function export.strip_notes_from_forms(forms)
	local newforms = {}
	for _, form in ipairs(forms) do
		local ru, tr = form[1], form[2]
		ru, _ = m_table_tools.separate_notes(ru)
		if tr then
			tr, _ = m_table_tools.separate_notes(tr)
		end
		table.insert(newforms, {ru, tr})
	end
	return newforms
end

-- Given a list of forms, where each form is a two-element list of {RUSSIAN, TRANSLIT}, unzip into parallel lists of
-- Russian and translit. The latter list may have gaps in it.
function export.unzip_forms(forms)
	local rulist = {}
	local trlist = {}
	for i, form in ipairs(forms) do
		local ru, tr = form[1], form[2]
		rulist[i] = ru
		trlist[i] = tr
	end
	return rulist, trlist
end

-- Given parallel lists of Russian and translit (where the latter list may have gaps in it), return a list of forms,
-- where each form is a two-element list of {RUSSIAN, TRANSLIT}.
function export.zip_forms(rulist, trlist)
	local forms = {}
	for i, ru in ipairs(rulist) do
		table.insert(forms, {ru, trlist[i]})
	end
	return forms
end

-- Given a list of forms, where each form is a two-element list of {RUSSIAN, TRANSLIT}, combine adjacent forms with
-- identical Russian, concatenating the translit with a comma in between.
function export.combine_translit_of_adjacent_heads(forms)
	local newforms = {}
	if #forms == 0 then
		return newforms
	end
	table.insert(newforms, {forms[1][1], forms[1][2]})
	for i = 2, #forms do
		-- If the Russian of the next form is the same as that of the last one, combine their translits and modify
		-- newforms[] in-place. Otherwise add the next form to newforms[]. Make sure to clone the form rather than
		-- just appending it directly since we may modify it in-place; we don't want to side-effect `forms` as passed
		-- in.
		if forms[i][1] == newforms[#newforms][1] then
			local tr1 = newforms[#newforms][2]
			local tr2 = forms[i][2]
			if not tr1 and not tr2 then
				-- this shouldn't normally happen
			else
				tr1 = tr1 or export.translit_no_links(newforms[#newforms][1])
				tr2 = tr2 or export.translit_no_links(forms[i][1])
				if tr1 == tr2 then
					-- this shouldn't normally happen
				else
					newforms[#newforms][2] = tr1 .. ", " .. tr2
				end
			end
		else
			table.insert(newforms, {forms[i][1], forms[i][2]})
		end
	end
	return newforms
end

function export.strip_ending(ru, tr, ending)
	local strippedru = rsub(ru, ending .. "$", "")
	if strippedru == ru then
		error("Argument " .. ru .. " doesn't end with expected ending " .. ending)
	end
	ru = strippedru
	tr = export.strip_tr_ending(tr, ending)
	return ru, tr
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
			-- The following regexp is not quite the same as com.vowels. For one thing
			-- it includes й, which is important. It leaves out ы, which may or may not
			-- be important.
			if old and conv == "и" and rfind(ending, "^́?[аеёиійоуэюяѣ]") then
				conv = "і"
			end
			suf = conv .. ending
		end
	end
	-- If <adj> is present in the suffix, it means we need to translate it
	-- specially; do that now.
	local is_adj = rfind(suf, "<adj>")
	suf = rsub(suf, "<adj>", "")
	local suftr = is_adj and m_ru_translit.tr_adj(suf, "include monosyllabic jo accent")
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

export.nonsyllabic_suffixes = m_table.listToSet({"", "ъ", "ь", "й"})

export.sibilant_suffixes = m_table.listToSet({"ш", "щ", "ч", "ж"})

return export
