local export = {}

local lang = require("Module:languages").getByCode("bg")
local m_links = require("Module:links")
local m_table = require("Module:table")
local m_bg_translit = require("Module:bg-translit")

local u = mw.ustring.char
local rfind = mw.ustring.find
local rsubn = mw.ustring.gsub
local ulen = mw.ustring.len

-- version of rsubn() that discards all but the first return value
local function rsub(term, foo, bar)
	local retval = rsubn(term, foo, bar)
	return retval
end


local AC = u(0x0301) -- acute =  ́


export.vowel = "аеиоуяюъАЕИОУЯЮЪ"
export.vowel_c = "[" .. export.vowel .. "]"
export.non_vowel_c = "[^" .. export.vowel .. "]"
export.cons = "бцдфгчйклмнпрствшхзжьщБЦДФГЧЙКЛМНПРСТВШХЗЖЬЩ"
export.cons_c = "[" .. export.cons .. "]"


export.first_palatalization = {
	["к"] = "ч",
	["г"] = "ж",
	["х"] = "ш",
}


export.second_palatalization = {
	["к"] = "ц",
	["г"] = "з",
	["х"] = "с",
}


local footnote_abbrevs = {
	["a"] = "archaic",
	["c"] = "colloquial",
	["d"] = "dialectal",
	["fp"] = "folk-poetic",
	["l"] = "literary",
	["lc"] = "low colloquial",
	["p"] = "poetic",
	["pej"] = "pejorative",
	["r"] = "rare",
}


function export.translit_no_links(text)
	return m_bg_translit.tr(m_links.remove_links(text))
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
		word = rsub(word, AC, "")
	end
	return word
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


function export.init_footnote_obj()
	return {
		notes = {},
		seen_notes = {},
		noteindex = 1,
	}
end


function export.display_one_form(footnote_obj, formtable, slot, accel_lemma, slot_to_accel_form, raw, slash_join)
	local forms = formtable[slot]
	if forms then
		local accel_obj
		if accel_lemma then
			accel_obj = {
				form = slot_to_accel_form(slot),
				lemma = accel_lemma
			}
		end
		local bg_spans = {}
		local tr_spans = {}
		for i, form in ipairs(forms) do
			-- FIXME, this doesn't necessarily work correctly if there is an
			-- embedded link in form.form.
			local bg_text = export.remove_monosyllabic_stress(form.form)
			local link, tr
			if raw or form.form == "—" or form.form == "?" then
				link = bg_text
			else
				link = m_links.full_link{lang = lang, term = bg_text, tr = "-", accel = accel_obj}
			end
			tr = export.translit_no_links(bg_text)
			tr = require("Module:script utilities").tag_translit(tr, lang, "default", " style=\"color: #888;\"")
			if form.footnotes then
				local link_indices = {}
				for _, footnote in ipairs(form.footnotes) do
					footnote = export.expand_footnote(footnote)
					local this_noteindex = footnote_obj.seen_notes[footnote]
					if not this_noteindex then
						-- Generate a footnote index.
						this_noteindex = footnote_obj.noteindex
						footnote_obj.noteindex = footnote_obj.noteindex + 1
						table.insert(footnote_obj.notes, '<sup style="color: red">' .. this_noteindex .. '</sup>' .. footnote)
						footnote_obj.seen_notes[footnote] = this_noteindex
					end
					m_table.insertIfNot(link_indices, this_noteindex)
				end
				local footnote_text = '<sup style="color: red">' .. table.concat(link_indices, ",") .. '</sup>'
				link = link .. footnote_text
				tr = tr .. footnote_text
			end
			table.insert(bg_spans, link)
			table.insert(tr_spans, tr)
		end
		if slash_join then
			return table.concat(bg_spans, "/")
		else
			local bg_span = table.concat(bg_spans, ", ")
			local tr_span = table.concat(tr_spans, ", ")
			return bg_span .. "<br />" .. tr_span
		end
	else
		return "—"
	end
end


function export.display_forms(footnote_obj, from_forms, to_forms, slots_table_or_list, slots_is_list,
	accel_lemma, slot_to_accel_form, raw, slash_join)
	local function do_slot(slot)
		to_forms[slot] = export.display_one_form(footnote_obj, from_forms, slot, accel_lemma,
		slot_to_accel_form, raw, slash_join)
	end

	if slots_is_list then
		for _, slot in ipairs(slots_table_or_list) do
			do_slot(slot)
		end
	else
		for slot, _ in pairs(slots_table_or_list) do
			do_slot(slot)
		end
	end
end


return export
