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

local HYPMARKER = "⟐"

-- version of rsubn() that discards all but the first return value
local function rsub(term, foo, bar)
	local retval = rsubn(term, foo, bar)
	return retval
end

-- Insert an entry into an existing list if not already present, comparing the entry to items in the existing list
-- using a key function. If entry already found, combine it into the existing entry using combine_func, a function of
-- two arguments (the existing and new entries), which should return the combined entry. Return false if entry already
-- found, true if new entry inserted. If combine_func not specified, the existing entry is left alone. If combine_func
-- is specified, the return value will be written over the existing value (i.e. the existing list will be modified
-- in-place).
--
-- FIXME: General enough to consider moving to [[Module:table]].
local function insert_if_not_by_key(list, new_entry, keyfunc, combine_func)
	local new_entry_key = keyfunc(new_entry)
	for i, item in ipairs(list) do
		local item_key = keyfunc(item)
		if m_table.deepEquals(item_key, new_entry_key) then
			if combine_func then
				list[i] = combine_func(item, new_entry)
			end
			return false
		end
	end
	table.insert(list, new_entry)
	return true
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
--                      Formatting forms for display                    --
--------------------------------------------------------------------------

-- Generate a string to substitute into a particular form in a Wiki-markup table. `forms` is the list of forms,
-- generated by concat_word_forms(). `is_lemma` is true if we're formatting the entry for use in displaying the lemma
-- in the declension table title. In this case, we don't include the translit, and remove monosyllabic accents from the
-- Cyrillic (but not in multiword expressions). `accel_form` is the form code to speicfy in the accelerator, e.g.
-- 'nom|m|s', or nil for no accelerator. `lemma_forms` is the list of {RU, TR} lemma forms for use in the accelerator,
-- or nil if `accel_form` is nil. `remove_monosyllabic_accents_lemma_only` indicates that monosyllabic accents should
-- be removed only in the lemma; otherwise we remove them from all forms. (FIXME: Rethink why we have this flag; we
-- should be consistent.)
function export.show_form(forms, is_lemma, accel_form, lemma_forms, remove_monosyllabic_accents_lemma_only)
	local russianvals = {}
	local latinvals = {}
	local lemmavals = {}

	-- First fetch the lemma forms and translit. If there are adjacent forms that have identical Russian including
	-- stress but different translit (e.g. азербайджа́нец with translits 'azerbajdžánec' and 'azɛrbajdžánec'), we
	-- combine the translits, comma-separating them. (This is necessary because there is currently only one tr=
	-- field per term.) We don't do this when processing the forms below; instead we handle this in a different
	-- and more general fashion (see below).
	local lemmaru, lemmatr
	if accel_form and lemma_forms and lemma_forms[1] ~= "-" then
		lemma_forms = com.combine_translit_of_adjacent_heads(com.strip_notes_from_forms(lemma_forms))
		for i, form in ipairs(lemma_forms) do
			local ru, tr = unpack(lemma_forms[i])
			ru, tr = com.remove_monosyllabic_accents(ru, tr)
			lemma_forms[i] = {ru, tr}
		end
		lemmaru, lemmatr = com.unzip_forms(lemma_forms)
	end

	-- Accumulate separately the Russian and transliteration into RUSSIANVALS and LATINVALS, then concatenate each down
	-- below. We need a fair amount of logic here:
	-- (1) to separate out footnote symbols;
	-- (2) to separate out the hypothetical marker (a footnote symbol but causes display of the Russian and translit
	--     in a special font);
	-- (3) to maybe remove monosyllabic accents;
	-- (4) to deduplicate repeated forms.
	-- We used to generate the display (HTML) as we went, but this prevented proper deduplication because the
	-- accelerator classes included in the HTML were different for otherwise identical forms. (Specifically, if two
	-- forms are the same in the Russian but different in the translit, the Russian will have different display forms
	-- because the translit is included in the accelerator classes.) So what we do is accumulate, separately for the
	-- Russian and translit, objects containing the entry (Russian or translit), the separated footnote symbols,
	-- whether the entry is hypothetical, and (for Russian only) the corresponding translit(s), for accelerator
	-- generation. As we accumulate, we duduplicate based only on comparing the entries of two objects. If we need to
	-- deduplicate two objects, we also need to combine their footnotes and transliteration (in the latter case, by
	-- comma-separating; we do this because there is only one tr= field for each term).
	for _, form in ipairs(forms) do
		local ru, tr = form[1], form[2]
		local ruentry, runotes = m_table_tools.separate_notes(ru)
		local trentry, trnotes
		if tr then
			trentry, trnotes = m_table_tools.separate_notes(tr)
			trnotes = rsub(trnotes, HYPMARKER, "")
		end
		if (is_lemma or not remove_monosyllabic_accents_lemma_only) then
			ruentry, trentry = com.remove_monosyllabic_accents(ruentry, trentry)
		end
		local ishyp = rfind(runotes, HYPMARKER)
		if ishyp then
			runotes = rsub(runotes, HYPMARKER, "")
		end
		local ruobj = {entry = ruentry, tr = {trentry or true}, ishyp = ishyp, notes = runotes}
		if not trentry then
			trentry = com.translit_no_links(ruentry)
		end
		if not trnotes then
			trnotes = com.translit_no_links(runotes)
		end
		local trobj = {entry = trentry, ishyp = ishyp, notes = trnotes}

		local function keyfunc(obj)
			return obj.entry
		end
		local function combine_func_ru(obj1, obj2)
			for _, tr in ipairs(obj2.tr) do
				m_table.insertIfNot(obj1.tr, tr)
			end
			obj1.notes = obj1.notes .. obj2.notes
			obj1.ishyp = obj1.ishyp or obj2.ishyp
			return obj1
		end
		local function combine_func_tr(obj1, obj2)
			obj1.notes = obj1.notes .. obj2.notes
			obj1.ishyp = obj1.ishyp or obj2.ishyp
			return obj1
		end
		if is_lemma then
			-- m_table.insertIfNot(lemmavals, ruspan .. " (" .. trspan .. ")")
			insert_if_not_by_key(lemmavals, ruobj, keyfunc, combine_func_ru)
		else
			insert_if_not_by_key(russianvals, ruobj, keyfunc, combine_func_ru)
			insert_if_not_by_key(latinvals, trobj, keyfunc, combine_func_tr)
		end
	end

	-- Now finally format each object and concatenate them together.
	local function concatenate_ru(objs)
		local is_missing = false
		for i, obj in ipairs(objs) do
			local accel = nil
			if lemmaru then
				local translit = nil
				if #obj.tr == 1 and obj.tr[1] == true then
					-- no translit
				else
					for j, tr in ipairs(obj.tr) do
						if tr == true then
							obj.tr[j] = com.translit_no_links(obj.entry)
						end
					end
					translit = table.concat(obj.tr, ", ")
				end
				accel = {form = accel_form, translit = translit, lemma = lemmaru, lemma_translit = lemmatr}
			end
			if obj.entry == "-" and #forms == 1 then
				objs[i] = "&mdash;"
				is_missing = true
			end
			if obj.ishyp then
				-- no accelerator for hypothetical forms
				objs[i] = m_links.full_link({lang = lang, term = nil, alt = obj.entry, tr = "-"}, "hypothetical")
			else
				objs[i] = m_links.full_link({lang = lang, term = obj.entry, tr = "-", accel = accel})
			end
			objs[i] = objs[i] .. m_table_tools.superscript_notes(obj.notes)
		end
		return table.concat(objs, ", "), is_missing
	end

	local function concatenate_tr(objs)
		local scriptutils = require("Module:script utilities")
		for i, obj in ipairs(objs) do
			local trspan = m_links.remove_links(obj.entry) .. m_table_tools.superscript_notes(obj.notes)
			if obj.ishyp then
				-- FIXME, in the old [[Module:ru-noun]] code, notes were omitted from hypothetical entries. Correct?
				objs[i] = scriptutils.tag_text(trspan, lang, require("Module:scripts").getByCode("Latn"),
					"hypothetical")
			else
				objs[i] = scriptutils.tag_translit(trspan, lang, "default", " style=\"color: #888;\"")
			end
		end
		return table.concat(objs, ", ")
	end

	if is_lemma then
		local russian_span, is_missing = concatenate_ru(lemmavals)
		return russian_span
	else
		local russian_span, is_missing = concatenate_ru(russianvals)
		if is_missing then
			return russian_span
		end
		local latin_span = concatenate_tr(latinvals)
		return russian_span .. "<br />" .. latin_span
	end
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
