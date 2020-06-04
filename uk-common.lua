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


local first_palatalization = {
	["к"] = "ч",
	["г"] = "ж",
	["х"] = "ш",
	["ц"] = "ч",
}


local second_palatalization = {
	["к"] = "ц",
	["г"] = "з",
	["х"] = "с",
}


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


function export.apply_first_palatalization(word)
	return rsub(word, "^(.*)([кгхц])$",
		function(prefix, lastchar) return prefix .. first_palatalization[lastchar] end
	)
end


function export.apply_second_palatalization(word)
	return rsub(word, "^(.*)([кгх])$",
		function(prefix, lastchar) return prefix .. second_palatalization[lastchar] end
	)
end


function export.reduce(word)
end


function export.is_vocalic(stem)
	return rfind(stem, export.vowel_c .. AC .. "?$")
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


function export.combine_stem_ending(stem, ending)
	if stem == "?" then
		return "?"
	elseif export.is_stressed(ending) then
		return export.remove_stress(stem) .. ending
	else
		return stem .. ending
	end
end


function export.generate_form(form, footnote)
	if footnote then
		return {form = form, footnotes = {footnote}}
	else
		return form
	end
end


function export.show_forms(forms, lemmas, footnotes, slots_table)
	local footnote_obj = {
		notes = {},
		seen_notes = {},
		noteindex = 1,
	}
	local accel_lemma = lemmas[1]
	forms.lemma = #lemmas > 0 and table.concat(lemmas, ", ") or mw.title.getCurrentTitle().text

	local m_table_tools = require("Module:table tools")
	for slot, accel_form in pairs(slots_table) do
		local formvals = forms[slot]
		if formvals then
			local uk_spans = {}
			local tr_spans = {}
			for i, form in ipairs(formvals) do
				-- FIXME, this doesn't necessarily work correctly if there is an
				-- embedded link in form.form.
				local uk_text = export.remove_monosyllabic_stress(form.form)
				local link, tr
				if form.form == "—" or form.form == "?" then
					link = uk_text
				else
					local accel_obj
					if accel_lemma and not form.no_accel then
						accel_obj = {
							form = accel_form,
							lemma = accel_lemma,
						}
					end
					local ukentry, uknotes = m_table_tools.get_notes(uk_text)
					link = m_links.full_link{lang = lang, term = ukentry,
						tr = "-", accel = accel_obj} .. uknotes
				end
				tr = export.translit_no_links(uk_text)
				local trentry, trnotes = m_table_tools.get_notes(tr)
				tr = require("Module:script utilities").tag_translit(trentry, lang, "default", " style=\"color: #888;\"") .. trnotes
				if form.footnotes then
					local link_indices = {}
					for _, footnote in ipairs(form.footnotes) do
						footnote = require("Module:inflection utilities").expand_footnote(footnote)
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
				table.insert(uk_spans, link)
				table.insert(tr_spans, tr)
			end
			local uk_span = table.concat(uk_spans, ", ")
			local tr_span = table.concat(tr_spans, ", ")
			forms[slot] = uk_span .. "<br />" .. tr_span
		else
			forms[slot] = "—"
		end
	end

	local all_notes = footnote_obj.notes
	for _, note in ipairs(footnotes) do
		local symbol, entry = m_table_tools.get_initial_notes(note)
		table.insert(all_notes, symbol .. entry)
	end
	forms.footnote = table.concat(all_notes, "<br />")
end


return export
