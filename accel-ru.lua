--[[
Author: Benwing2

This module holds Russian-specific accelerator code.
]]

local com = require("Module:ru-common")

local rfind = mw.ustring.find
local rsubn = mw.ustring.gsub
local rmatch = mw.ustring.match
local rsplit = mw.text.split

-- version of rsubn() that discards all but the first return value
local function rsub(term, foo, bar)
	local retval = rsubn(term, foo, bar)
	return retval
end

local function make_noun_decl(term, translit, form)
	local term_and_tr = com.combine_russian_tr(term, translit)
	if rfind(term, "[" .. com.cons .. "]ка$") then
		return term_and_tr .. "|*"
	elseif rfind(term, "[оё]́?к$") then
		return "b|" .. term_and_tr .. "|*"
	elseif rfind(term, "ость$") then
		return term_and_tr .. "|f"
	elseif rfind(term, "тель$") then
		return term_and_tr .. "|m"
	elseif rfind(term, "[ая]́?я$") and form == "f" then -- female equivalent
		return term_and_tr .. "|+"
	else
		-- FIXME, should we special-case diminutives in -ко? (often have plural in -ки)
		return term_and_tr
	end
end

return {generate = function (params, entry)
	local anntext = #params.targets > 1 and "|ann=y" or ""
	local pronun_parts = {}
	local targets = {}
	for _, target in ipairs(params.targets) do
		local ru, tr = target.term, target.translit
		tr = tr and com.decompose(tr) or nil
		table.insert(targets, {ru, tr})
	end
	targets = com.split_translit_of_adjacent_forms(targets0
	for _, target in ipairs(targets) do
		-- FIXME, add |pos= if ends in -е
		local ru, tr = unpack(target)
		if tr then
			-- FIXME, if translit specified need to reverse-translit
			table.insert(pronun_parts, "* {{ru-IPA|phon=" .. ru .. anntext .. "|FIXMETRANSLIT=" .. tr .. "}}")
		else
			table.insert(pronun_parts, "* {{ru-IPA|" .. ru .. anntext .. "}}")
		end
	end
	entry.pronunc = table.concat(pronun_parts, "\n")

	if params.pos == "noun" and (params.form == "f" or params.form == "diminutive" or params.form == "augmentative"
		or params.form == "abstract noun" or params.form == "verbal noun") then
		-- A noun, not a noun form (inflection).
		local decl_parts = {}
		for _, target in ipairs(targets) do
			local ru, tr = unpack(target)
			table.insert(decl_parts, make_noun_decl(ru, tr, params.form))
		end
		local decl = table.concat(decl_parts, "|or|")
		if params.form == "f" then
			-- FIXME, diminutives and augmentatives should propagate the lemma's animacy
			decl = decl .. "|a=an"
		end
		entry.def = entry.def .. ": FIXME_DEFINITION"
		decl = decl .. "|FIXME=1"
		params.head = "{{ru-noun+|" .. decl .. "}}"
		params.declension = "{{ru-noun-table|" .. decl .. "}}"
	end
end}
