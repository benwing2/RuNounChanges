local export = {}

local m_links = require("Module:links")
local m_string_utilities = require("Module:string utilities")
local m_table = require("Module:table")

local rsplit = mw.text.split
local rfind = mw.ustring.find
local rmatch = mw.ustring.match
local rsubn = mw.ustring.gsub

-- version of rsubn() that discards all but the first return value
local function rsub(term, foo, bar)
	local retval = rsubn(term, foo, bar)
	return retval
end


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


-- Parse a string containing matched instances of parens, brackets or the like.
-- Return a list of strings, alternating between textual runs not containing the
-- open/close characters and runs beginning and ending with the open/close
-- characters. For example,
--
-- parse_balanced_segment_run("foo(x(1)), bar(2)", "(", ")") = {"foo", "(x(1))", ", bar", "(2)", ""}.
function export.parse_balanced_segment_run(segment_run, open, close)
	local break_on_open_close = m_string_utilities.capturing_split(segment_run, "([%" .. open .. "%" .. close .. "])")
	local text_and_specs = {}
	local level = 0
	local seg_group = {}
	for i, seg in ipairs(break_on_open_close) do
		if i % 2 == 0 then
			if seg == open then
				table.insert(seg_group, seg)
				level = level + 1
			else
				assert(seg == close)
				table.insert(seg_group, seg)
				level = level - 1
				if level < 0 then
					error("Unmatched " .. close .. " sign: '" .. segment_run .. "'")
				elseif level == 0 then
					table.insert(text_and_specs, table.concat(seg_group))
					seg_group = {}
				end
			end
		elseif level > 0 then
			table.insert(seg_group, seg)
		else
			table.insert(text_and_specs, seg)
		end
	end
	if level > 0 then
		error("Unmatched " .. open .. " sign: '" .. segment_run .. "'")
	end
	return text_and_specs
end


-- Split a list of alternating textual runs of the format returned by
-- `parse_balanced_segment_run` on `splitchar`. This only splits the odd-numbered
-- textual runs (the portions between the balanced open/close characters).
-- The return value is a list of lists, where each list contains an odd number of
-- elements, where the even-numbered elements of the sublists are the original
-- balanced textual run portions. For example, if we do
--
-- parse_balanced_segment_run("foo[x[1]][2]/baz:bar[3]", "[", "]") =
--   {"foo", "[x[1]]", "", "[2]", "/baz:bar", "[3]", ""}
--
-- then
--
-- split_alternating_runs({"foo", "[x[1]]", "", "[2]", "/baz:bar", "[3]", ""}, ":") =
--   {{"foo", "[x[1]]", "", "[2]", "/baz"}, {"bar", "[2]", ""}}
--
-- Note that each element of the outer list is of the same form as the input,
-- consisting of alternating textual runs where the even-numbered segments
-- are balanced runs, and can in turn be passed to split_alternating_runs().
function export.split_alternating_runs(segment_runs, splitchar, preserve_splitchar)
	local grouped_runs = {}
	local run = {}
	for i, seg in ipairs(segment_runs) do
		if i % 2 == 0 then
			table.insert(run, seg)
		else
			local parts =
				preserve_splitchar and m_string_utilities.capturing_split(seg, "(" .. splitchar .. ")") or
				rsplit(seg, splitchar)
			table.insert(run, parts[1])
			for j=2,#parts do
				table.insert(grouped_runs, run)
				run = {parts[j]}
			end
		end
	end
	if #run > 0 then
		table.insert(grouped_runs, run)
	end
	return grouped_runs
end


-- Given a list of forms (each of which is a table of the form
-- {form=FORM, translit=MANUAL_TRANSLIT, footnotes=FOOTNOTES}), concatenate into a
-- SLOT=FORM//TRANSLIT,FORM//TRANSLIT,... string (or SLOT=FORM,FORM,... if no translit),
-- replacing embedded | signs with <!>.
function export.concat_forms_in_slot(forms)
	if forms then
		local new_vals = {}
		for _, v in ipairs(forms) do
			local form = v.form
			if v.translit then
				form = form .. "//" .. v.translit
			end
			table.insert(new_vals, rsub(form, "|", "<!>"))
		end
		return table.concat(new_vals, ",")
	else
		return nil
	end
end


-- Insert a form (an object of the form {form=FORM, translit=MANUAL_TRANSLIT, footnotes=FOOTNOTES})
-- into a list of such forms. If the form is already present, the footnotes of the existing and
-- new form might be combined (specifically, footnotes in the new form beginning with ! will be
-- combined).
function export.insert_form_into_list(list, form)
	-- Don't do anything if the form object or the form inside it is nil. This simplifies
	-- form insertion in the presence of declension generating functions that may return nil,
	-- such as generate_noun_vocative() and generate_noun_count_form().
	if not form or not form.form then
		return
	end
	for _, listform in ipairs(list) do
		if listform.form == form.form and listform.translit == form.translit then
			-- Form already present; maybe combine footnotes.
			if form.footnotes then
				-- The behavior here has changed; track cases where the old behavior might
				-- be needed by adding ! to the footnote.
				require("Module:debug").track("inflection-utilities/combining-footnotes")
				local any_footnotes_with_bang = false
				for _, footnote in ipairs(form.footnotes) do
					if rfind(footnote, "^%[!") then
						any_footnotes_with_bang = true
						break
					end
				end
				if any_footnotes_with_bang then
					if not listform.footnotes then
						listform.footnotes = {}
					else
						listform.footnotes = m_table.shallowcopy(listform.footnotes)
					end
					for _, footnote in ipairs(form.footnotes) do
						local already_seen = false
						if rfind(footnote, "^%[!") then
							for _, existing_footnote in ipairs(listform.footnotes) do
								if rsub(existing_footnote, "^%[!", "") == rsub(footnote, "^%[!", "") then
									already_seen = true
									break
								end
							end
							if not already_seen then
								table.insert(listform.footnotes, footnote)
							end
						end
					end
				end
			end
			return
		end
	end
	-- Form not found.
	table.insert(list, form)
end

-- Insert a form (an object of the form {form=FORM, translit=MANUAL_TRANSLIT, footnotes=FOOTNOTES})
-- into the given slot in the given form table.
function export.insert_form(formtable, slot, form)
	-- Don't do anything if the form object or the form inside it is nil. This simplifies
	-- form insertion in the presence of declension generating functions that may return nil,
	-- such as generate_noun_vocative() and generate_noun_count_form().
	if not form or not form.form then
		return
	end
	if not formtable[slot] then
		formtable[slot] = {}
	end
	export.insert_form_into_list(formtable[slot], form)
end


-- Insert a list of forms (each of which is an object of the form
-- {form=FORM, translit=MANUAL_TRANSLIT, footnotes=FOOTNOTES}) into the given slot in the given
-- form table. FORMS can be nil.
function export.insert_forms(formtable, slot, forms)
	if not forms then
		return
	end
	for _, form in ipairs(forms) do
		export.insert_form(formtable, slot, form)
	end
end


-- Map a function over the form values in FORMS (a list of objects of the form
-- {form=FORM, translit=MANUAL_TRANSLIT, footnotes=FOOTNOTES}). The function is called with
-- two arguments, the original form and manual translit; if manual translit isn't relevant,
-- it's fine to declare the function with only one argument. The return value is either a
-- single value (the new form) or two values (the new form and new manual translit).
-- Use insert_form_into_list() to insert them into the returned list in case two different
-- forms map to the same thing.
function export.map_forms(forms, fun)
	if not forms then
		return nil
	end
	local retval = {}
	for _, form in ipairs(forms) do
		local newform, newtranslit = fun(form.form, form.translit)
		newform = {form=newform, translit=newtranslit, footnotes=form.footnotes}
		export.insert_form_into_list(retval, newform)
	end
	return retval
end


-- Map a list-returning function over the form values in FORMS (a list of objects of the form
-- {form=FORM, translit=MANUAL_TRANSLIT, footnotes=FOOTNOTES}). The function is called witih
-- two arguments, the original form and manual translit; if manual translit isn't relevant,
-- it's fine to declare the function with only one argument. The return value is either a
-- list of forms or a list of objects of the form {form=FORM, translit=MANUAL_TRANSLIT}.
-- Use insert_form_into_list() to insert them into the returned list in case two different
-- forms map to the same thing.
function export.flatmap_forms(forms, fun)
	if not forms then
		return nil
	end
	local retval = {}
	for _, form in ipairs(forms) do
		local funret = fun(form.form, form.translit)
		for _, fr in ipairs(funret) do
			local newform
			if type(fr) == "table" then
				newform = {form=fr.form, translit=fr.translit, footnotes=form.footnotes}
			else
				newform = {form=fr, footnotes=form.footnotes}
			end
			export.insert_form_into_list(retval, newform)
		end
	end
	return retval
end


-- Map a function over the form values in FORMS (a single string, a single object of the form
-- {form=FORM, translit=MANUAL_TRANSLIT, footnotes=FOOTNOTES}, or a list of either of the
-- previous two types). If FIRST_ONLY is given and FORMS is a list, only map over the first
-- element. Return value is of the same form as FORMS. The function is called with two
-- arguments, the original form and manual translit; if manual translit isn't relevant,
-- it's fine to declare the function with only one argument. The return value is either a
-- single value (the new form) or two values (the new form and new manual translit).
function export.map_form_or_forms(forms, fn, first_only)
	if forms == nil then
		return nil
	elseif type(forms) == "string" then
		return forms == "?" and "?" or fn(forms)
	elseif forms.form then
		if forms.form == "?" then
			return {form = "?", footnotes = forms.footnotes}
		end
		local newform, newtranslit = fn(forms.form, forms.translit)
		return {form=newform, translit=newtranslit, footnotes=forms.footnotes}
	else
		local retval = {}
		for i, form in ipairs(forms) do
			if first_only then
				return export.map_form_or_forms(form, fn)
			end
			table.insert(retval, export.map_form_or_forms(form, fn))
		end
		return retval
	end
end


function export.combine_footnotes(notes1, notes2)
	if not notes1 and not notes2 then
		return nil
	end
	if not notes1 then
		return notes2
	end
	if not notes2 then
		return notes1
	end
	local combined = m_table.shallowcopy(notes1)
	for _, note in ipairs(notes2) do
		m_table.insertIfNot(combined, note)
	end
	return combined
end


-- Expand a given footnote (as specified by the user, including the surrounding brackets)
-- into the form to be inserted into the final generated table.
function export.expand_footnote(note)
	local notetext = rmatch(note, "^%[!?(.*)%]$")
	assert(notetext)
	if footnote_abbrevs[notetext] then
		notetext = footnote_abbrevs[notetext]
	else
		local split_notes = m_string_utilities.capturing_split(notetext, "<(.-)>")
		for i, split_note in ipairs(split_notes) do
			if i % 2 == 0 then
				split_notes[i] = footnote_abbrevs[split_note]
				if not split_notes[i] then
					-- Don't error for now, because HTML might be in the footnote.
					-- Instead we should switch the syntax here to e.g. <<a>> to avoid
					-- conflicting with HTML.
					split_notes[i] = "<" .. split_note .. ">"
					--error("Unrecognized footnote abbrev: <" .. split_note .. ">")
				end
			end
		end
		notetext = table.concat(split_notes)
	end
	return m_string_utilities.ucfirst(notetext) .. "."
end


local function convert_to_general_form(word_or_words)
	if type(word_or_words) == "string" then
		return {{form = word_or_words}}
	elseif word_or_words.form then
		return {word_or_words}
	else
		local retval = {}
		for _, form in ipairs(word_or_words) do
			if type(form) == "string" then
				table.insert(retval, {form = form})
			else
				table.insert(retval, form)
			end
		end
		return retval
	end
end


local function is_table_of_strings(forms)
	for k, v in pairs(forms) do
		if type(k) ~= "number" or type(v) ~= "string" then
			return false
		end
	end
	return true
end


function export.add_forms(forms, slot, stems, endings, combine_stem_ending,
	lang, combine_stem_ending_tr)
	if stems == nil or endings == nil then
		return
	end
	if type(stems) == "string" and type(endings) == "string" then
		export.insert_form(forms, slot, {form = combine_stem_ending(stems, endings)})
	elseif type(stems) == "string" and is_table_of_strings(endings) then
		for _, ending in ipairs(endings) do
			export.insert_form(forms, slot, {form = combine_stem_ending(stems, ending)})
		end
	else
		stems = convert_to_general_form(stems)
		endings = convert_to_general_form(endings)
		for _, stem in ipairs(stems) do
			for _, ending in ipairs(endings) do
				local footnotes = nil
				if stem.footnotes and ending.footnotes then
					footnotes = m_table.shallowcopy(stem.footnotes)
					for _, footnote in ipairs(ending.footnotes) do
						m_table.insertIfNot(footnotes, footnote)
					end
				elseif stem.footnotes then
					footnotes = stem.footnotes
				elseif ending.footnotes then
					footnotes = ending.footnotes
				end
				local new_form = combine_stem_ending(stem.form, ending.form)
				local new_translit
				if stem.translit or ending.translit then
					if not lang or not combine_stem_ending_tr then
						error("Internal error: With manual translit, 'lang' and 'combine_stem_ending_tr' must be passed to 'add_forms'")
					end
					local stem_tr = stem.translit or lang:transliterate(m_links.remove_links(stem.form))
					local ending_tr = ending.translit or lang:transliterate(m_links.remove_links(ending.form))
					new_translit = combine_stem_ending_tr(stem_tr, ending_tr)
				end
				export.insert_form(forms, slot, {form = new_form, translit = new_translit, footnotes = footnotes})
			end
		end
	end
end


--[=[
Parse a multiword spec such as "[[медичний|меди́чна]]<+> [[сестра́]]<*,*#.pr> (in Ukrainian).
The return value is a table of the form
{
  word_specs = {WORD_SPEC, WORD_SPEC, ...},
  post_text = "TEXT-AT-END",
}

where WORD_SPEC describes an individual declined word and "TEXT-AT-END" is any raw text that
may occur after all declined words. Each WORD_SPEC is of the form returned
by parse_indicator_spec():

{
  lemma = "LEMMA",
  before_text = "TEXT-BEFORE-WORD",
  before_text_no_links = "TEXT-BEFORE-WORD-NO-LINKS",
  -- Fields as described in parse_indicator_spec()
  ...
}

For example, the return value for "[[медичний|меди́чна]]<+> [[сестра́]]<*,*#.pr>" is
{
  word_specs = {
    {
      lemma = "[[медичний|меди́чна]]",
      overrides = {},
      adj = true,
      before_text = "",
      before_text_no_links = "",
      forms = {},
    },
    {
      lemma = "[[сестра́]]",
      overrides = {},
	  stresses = {
		{
		  reducible = true,
		  genpl_reversed = false,
		},
		{
		  reducible = true,
		  genpl_reversed = true,
		},
	  },
	  animacy = "pr",
      before_text = " ",
      before_text_no_links = " ",
      forms = {},
    },
  },
  post_text = "",
}
]=]
local function parse_multiword_spec(segments, parse_indicator_spec, allow_default_indicator)
	local multiword_spec = {
		word_specs = {}
	}
	if allow_default_indicator and #segments == 1 then
		table.insert(segments, "<>")
		table.insert(segments, "")
	end
	for i = 2, #segments - 1, 2 do
		local bracketed_runs = export.parse_balanced_segment_run(segments[i - 1], "[", "]")
		local space_separated_groups = export.split_alternating_runs(bracketed_runs, "[ %-]", "preserve splitchar")
		local before_text = {}
		local lemma
		for j, space_separated_group in ipairs(space_separated_groups) do
			if j == #space_separated_groups then
				lemma = table.concat(space_separated_group)
				if lemma == "" then
					error("Word is blank: '" .. table.concat(segments) .. "'")
				end
			else
				table.insert(before_text, table.concat(space_separated_group))
			end
		end
		local base = parse_indicator_spec(segments[i])
		base.before_text = table.concat(before_text)
		base.before_text_no_links = m_links.remove_links(base.before_text)
		base.lemma = lemma
		table.insert(multiword_spec.word_specs, base)
	end
	multiword_spec.post_text = segments[#segments]
	multiword_spec.post_text_no_links = m_links.remove_links(multiword_spec.post_text)
	return multiword_spec
end


--[=[
Parse an alternant, e.g. "((родо́вий,родови́й))" or "((ру́син<pr>,руси́н<b.pr>))" (both in Ukrainian).
The return value is a table of the form
{
  alternants = {MULTIWORD_SPEC, MULTIWORD_SPEC, ...}
}

where MULTIWORD_SPEC describes a given alternant and is as returned by parse_multiword_spec().
]=]
local function parse_alternant(alternant, parse_indicator_spec, allow_default_indicator)
	local parsed_alternants = {}
	local alternant_text = rmatch(alternant, "^%(%((.*)%)%)$")
	local segments = export.parse_balanced_segment_run(alternant_text, "<", ">")
	local comma_separated_groups = export.split_alternating_runs(segments, ",")
	local alternant_spec = {alternants = {}}
	for _, comma_separated_group in ipairs(comma_separated_groups) do
		table.insert(alternant_spec.alternants,
			parse_multiword_spec(comma_separated_group, parse_indicator_spec, allow_default_indicator))
	end
	return alternant_spec
end


--[=[
Top-level parsing function. Parse a multiword spec that may have alternants in it.
The return value is a table of the form
{
  alternant_or_word_specs = {ALTERNANT_OR_WORD_SPEC, ALTERNANT_OR_WORD_SPEC, ...}
  post_text = "TEXT-AT-END",
  post_text_no_links = "TEXT-AT-END-NO-LINKS",
}

where ALTERNANT_OR_WORD_SPEC is either an alternant spec as returned by parse_alternant()
or a multiword spec as described in the comment above parse_multiword_spec(). An alternant spec
looks as follows:
{
  alternants = {MULTIWORD_SPEC, MULTIWORD_SPEC, ...},
  before_text = "TEXT-BEFORE-ALTERNANT",
  before_text_no_links = "TEXT-BEFORE-ALTERNANT",
}
i.e. it is like what is returned by parse_alternant() but has extra `before_text`
and `before_text_no_links` fields.
]=]
function export.parse_alternant_multiword_spec(text, parse_indicator_spec, allow_default_indicator)
	local alternant_multiword_spec = {alternant_or_word_specs = {}}
	local alternant_segments = m_string_utilities.capturing_split(text, "(%(%(.-%)%))")
	local last_post_text, last_post_text_no_links
	for i = 1, #alternant_segments do
		if i % 2 == 1 then
			local segments = export.parse_balanced_segment_run(alternant_segments[i], "<", ">")
			local multiword_spec = parse_multiword_spec(segments, parse_indicator_spec,
				-- Don't set allow_default_indicator if alternants are present and we're
				-- processing the non-alternant text.
				allow_default_indicator and #alternant_segments == 1)
			for _, word_spec in ipairs(multiword_spec.word_specs) do
				table.insert(alternant_multiword_spec.alternant_or_word_specs, word_spec)
			end
			last_post_text = multiword_spec.post_text
			last_post_text_no_links = multiword_spec.post_text_no_links
		else
			local alternant_spec = parse_alternant(alternant_segments[i],
				parse_indicator_spec, allow_default_indicator)
			alternant_spec.before_text = last_post_text
			alternant_spec.before_text_no_links = last_post_text_no_links
			table.insert(alternant_multiword_spec.alternant_or_word_specs, alternant_spec)
		end
	end
	alternant_multiword_spec.post_text = last_post_text
	alternant_multiword_spec.post_text_no_links = last_post_text_no_links
	return alternant_multiword_spec
end


-- Decline alternants in ALTERNANT_SPEC (an object as returned by parse_alternant()).
-- This sets the form values in `ALTERNANT_SPEC.forms` for all slots.
-- (If a given slot has no values, it will not be present in `ALTERNANT_SPEC.forms`).
local function decline_alternants(alternant_spec, props)
	alternant_spec.forms = {}
	for _, multiword_spec in ipairs(alternant_spec.alternants) do
		export.decline_multiword_or_alternant_multiword_spec(multiword_spec, props)
		for slot, _ in pairs(props.slot_table) do
			if not props.skip_slot(slot) then
				export.insert_forms(alternant_spec.forms, slot, multiword_spec.forms[slot])
			end
		end
	end
end


local function append_forms(props, formtable, slot, forms, before_text, before_text_no_links)
	if not forms then
		return
	end
	local old_forms = formtable[slot] or {{form = ""}}
	local ret_forms = {}
	local before_text_translit
	for _, old_form in ipairs(old_forms) do
		for _, form in ipairs(forms) do
			local old_form_vars = props.get_variants(old_form.form)
			local form_vars = props.get_variants(form.form)
			if old_form_vars and form_vars and old_form_vars ~= form_vars then
				-- Reject combination due to non-matching variant codes.
			else
				local new_form = old_form.form .. before_text .. form.form
				local new_translit
				if old_form.translit or form.translit then
					if not props.lang then
						error("Internal error: If manual translit is given, 'props.lang' must be set")
					end
					if not before_text_translit then
						before_text_translit = props.lang:transliterate(before_text_no_links)
					end
					local old_translit = old_form.translit or props.lang:transliterate(m_links.remove_links(old_form.form))
					local translit = form.translit or props.lang:transliterate(m_links.remove_links(form.form))
					new_translit = old_translit .. before_text_translit .. translit
				end
				local new_footnotes = export.combine_footnotes(old_form.footnotes, form.footnotes)
				table.insert(ret_forms, {form=new_form, translit=new_translit,
					footnotes=new_footnotes})
			end
		end
	end
	formtable[slot] = ret_forms
end


function export.decline_multiword_or_alternant_multiword_spec(multiword_spec, props)
	multiword_spec.forms = {}

	local is_alternant_multiword = not not multiword_spec.alternant_or_word_specs
	for _, word_spec in ipairs(is_alternant_multiword and multiword_spec.alternant_or_word_specs or multiword_spec.word_specs) do
		if word_spec.alternants then
			decline_alternants(word_spec, props)
		else
			props.decline_word_spec(word_spec)
		end
		for slot, _ in pairs(props.slot_table) do
			if not props.skip_slot(slot) then
				append_forms(props, multiword_spec.forms, slot, word_spec.forms[slot],
					rfind(slot, "linked") and word_spec.before_text or word_spec.before_text_no_links,
					word_spec.before_text_no_links
				)
			end
		end
	end
	if multiword_spec.post_text ~= "" then
		local pseudoform = {{form=""}}
		for slot, _ in pairs(props.slot_table) do
			-- If slot is empty or should be skipped, don't try to append post-text.
			if not props.skip_slot(slot) and multiword_spec.forms[slot] then
				append_forms(props, multiword_spec.forms, slot, pseudoform,
					rfind(slot, "linked") and multiword_spec.post_text or multiword_spec.post_text_no_links,
					multiword_spec.post_text_no_links
				)
			end
		end
	end
end


function export.map_word_specs(alternant_multiword_spec, fun)
	for _, alternant_or_word_spec in ipairs(alternant_multiword_spec.alternant_or_word_specs) do
		if alternant_or_word_spec.alternants then
			for _, multiword_spec in ipairs(alternant_or_word_spec.alternants) do
				for _, word_spec in ipairs(multiword_spec.word_specs) do
					fun(word_spec)
				end
			end
		else
			fun(alternant_or_word_spec)
		end
	end
end


function export.generate_form(form, footnotes)
	if type(footnotes) == "string" then
		footnotes = {footnotes}
	end
	if footnotes then
		return {form = form, footnotes = footnotes}
	else
		return form
	end
end


function export.create_footnote_obj()
	return {
		notes = {},
		seen_notes = {},
		noteindex = 1,
	}
end


function export.get_footnote_text(form, footnote_obj)
	if not form.footnotes then
		return ""
	end
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
	return '<sup style="color: red">' .. table.concat(link_indices, ",") .. '</sup>'
end


--[=[
Convert the forms in `forms` (a list of form objects, each of which is a table of the form
{ form = FORM, translit = MANUAL_TRANSLIT_OR_NIL, footnotes = FOOTNOTE_LIST_OR_NIL,
no_accel = TRUE_TO_SUPPRESS_ACCELERATORS }) into strings. Each form list turns into a string
consisting of a comma-separated list of linked forms, with accelerators (unless `no_accel`
is set in a given form). `lemmas` is the list of lemmas, used in the accelerators.
`slots_table` is a table of slots and associated accelerator inflections. `props` is a table
used in generating the strings, as follows:
{ lang = LANG_OBJECT, canonicalize = FUNCTION_TO_CANONICALIZE_EACH_FORM }.
If `allow_footnote_symbols` is given, footnote symbols attached to forms (e.g. numbers,
asterisk) are separated off, placed outside the links, and superscripted. In this case,
`footnotes` should be a list of footnotes (preceded by footnote symbols, which are
superscripted). These footnotes are combined with any footnotes found in the forms and
placed into `forms.footnotes`.
]=]
function export.show_forms_with_translit(forms, lemmas, slots_table, props, footnotes, allow_footnote_symbols)
	local footnote_obj = export.create_footnote_obj()
	local accel_lemma = lemmas[1]
	local accel_lemma_translit
	if type(accel_lemma) == "table" then
		accel_lemma_translit = accel_lemma.translit
		accel_lemma = accel_lemma.form
	end
	for i, lemma in ipairs(lemmas) do
		if type(lemma) == "table" then
			lemmas[i] = lemma.form
		end
	end
	forms.lemma = #lemmas > 0 and table.concat(lemmas, ", ") or mw.title.getCurrentTitle().text

	local m_table_tools = require("Module:table tools")
	local m_script_utilities = require("Module:script utilities")
	for slot, accel_form in pairs(slots_table) do
		local formvals = forms[slot]
		if formvals then
			local orig_spans = {}
			local tr_spans = {}
			for i, form in ipairs(formvals) do
				local orig_text = props.canonicalize(form.form)
				local link, tr
				if form.form == "—" or form.form == "?" then
					link = orig_text
				else
					local accel_obj
					if accel_lemma and not form.no_accel then
						accel_obj = {
							form = accel_form,
							translit = form.translit,
							lemma = accel_lemma,
							lemma_translit = accel_lemma_translit,
						}
					end
					local origentry, orignotes
					if allow_footnote_symbols then
						origentry, orignotes = m_table_tools.get_notes(orig_text)
					else
						origentry, orignotes = orig_text, ""
					end
					link = m_links.full_link{lang = props.lang, term = origentry,
						tr = "-", accel = accel_obj} .. orignotes
				end
				tr = form.translit or props.lang:transliterate(m_links.remove_links(orig_text))
				local trentry, trnotes
				if allow_footnote_symbols then
					trentry, trnotes = m_table_tools.get_notes(tr)
				else
					trentry, trnotes = tr, ""
				end
				tr = m_script_utilities.tag_translit(trentry, props.lang, "default", " style=\"color: #888;\"") .. trnotes
				if form.footnotes then
					local footnote_text = export.get_footnote_text(form, footnote_obj)
					link = link .. footnote_text
					tr = tr .. footnote_text
				end
				table.insert(orig_spans, link)
				table.insert(tr_spans, tr)
			end
			local orig_span = table.concat(orig_spans, ", ")
			local tr_span = table.concat(tr_spans, ", ")
			forms[slot] = orig_span .. "<br />" .. tr_span
		else
			forms[slot] = "—"
		end
	end

	local all_notes = footnote_obj.notes
	if footnotes then
		for _, note in ipairs(footnotes) do
			local symbol, entry = m_table_tools.get_initial_notes(note)
			table.insert(all_notes, symbol .. entry)
		end
	end
	forms.footnote = table.concat(all_notes, "<br />")
end


return export
