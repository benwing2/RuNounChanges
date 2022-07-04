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


function export.remove_redundant_links(text)
	-- remove redundant link surrounding entire form
	return rsub(text, "^%[%[([^%[%]|]*)%]%]$", "%1")
end

------------------------------------------------------------------------------------------------------------
--                                             PARSING CODE                                               --
------------------------------------------------------------------------------------------------------------

--[=[
In order to understand the following parsing code, you need to understand how inflected text specs work. They are
intended to work with inflected text where individual words to be inflected may be followed by inflection specs in
angle brackets. The format of the text inside of the angle brackets is up to the individual language and part-of-speech
specific implementation. A real-world example is as follows: "[[медичний|меди́чна]]<+> [[сестра́]]<*,*#.pr>". This is the inflection of a multiword expression "меди́чна сестра́", which means "nurse" in Ukrainian (literally "medical sister"),
consisting of two words: the adjective меди́чна ("medical" in the feminine singular) and the noun сестра́ ("sister"). The
specs in angle brackets follow each word to be inflected; for example, <+> means that the preceding word should be
declined as an adjective.

The code below works in terms of balanced expressions, which are bounded by delimiters such as < > or [ ]. The
intention is to allow separators such as spaces to be embedded inside of delimiters; such embedded separators will not
be parsed as separators. For example, Ukrainian noun specs allow footnotes in brackets to be inserted inside of angle
brackets; something like "меди́чна<+> сестра́<pr.[this is a footnote]>" is legal, as is
"[[медичний|меди́чна]]<+> [[сестра́]]<pr.[this is an <i>italicized footnote</i>]>", and the parsing code should not be
confused by the embedded brackets, spaces or angle brackets.

The parsing is done by two functions, which work in close concert: parse_balanced_segment_run() and
split_alternating_runs(). To illustrate, consider the following:

parse_balanced_segment_run("foo<M.proper noun> bar<F>", "<", ">") =
  {"foo", "<M.proper noun>", " bar", "<F>", ""}

then

split_alternating_runs({"foo", "<M.proper noun>", " bar", "<F>", ""}, " ") =
  {{"foo", "<M.proper noun>", ""}, {"bar", "<F>", ""}}

Here, we start out with a typical inflected text spec "foo<M.proper noun> bar<F>", call parse_balanced_segment_run() on
it, and call split_alternating_runs() on the result. The output of parse_balanced_segment_run() is a list where
even-numbered segments are bounded by the bracket-like characters passed into the function, and odd-numbered segments
consist of the surrounding text. split_alternating_runs() is called on this, and splits *only* the odd-numbered
segments, grouping all segments between the specified character. Note that the inner lists output by
split_alternating_runs() are themselves in the same format as the output of parse_balanced_segment_run(), with
bracket-bounded text in the even-numbered segments. Hence, such lists can be passed again to split_alternating_runs().
]=]


-- Parse a string containing matched instances of parens, brackets or the like. Return a list of strings, alternating
-- between textual runs not containing the open/close characters and runs beginning and ending with the open/close
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


-- Like parse_balanced_segment_run() but accepts multiple sets of delimiters. For example,
--
-- parse_multi_delimiter_balanced_segment_run("foo[bar(baz[bat])], quux<glorp>", {{"[", "]"}, {"(", ")"}, {"<", ">"}}) =
--		{"foo", "[bar(baz[bat])]", ", quux", "<glorp>", ""}.
function export.parse_multi_delimiter_balanced_segment_run(segment_run, delimiter_pairs)
	local open_to_close_map = {}
	local open_close_items = {}
	for _, open_close in ipairs(delimiter_pairs) do
		local open, close = unpack(open_close)
		open_to_close_map[open] = close
		table.insert(open_close_items, "%" .. open)
		table.insert(open_close_items, "%" .. close)
	end
	local open_close_pattern = "([" .. table.concat(open_close_items) .. "])"
	local break_on_open_close = m_string_utilities.capturing_split(segment_run, open_close_pattern)
	local text_and_specs = {}
	local level = 0
	local seg_group = {}
	local open_at_level_zero
	for i, seg in ipairs(break_on_open_close) do
		if i % 2 == 0 then
			table.insert(seg_group, seg)
			if level == 0 then
				if not open_to_close_map[seg] then
					error("Unmatched " .. seg .. " sign: '" .. segment_run .. "'")
				end
				assert(open_at_level_zero == nil)
				open_at_level_zero = seg
				level = level + 1
			elseif seg == open_at_level_zero then
				level = level + 1
			elseif seg == open_to_close_map[open_at_level_zero] then
				level = level - 1
				assert(level >= 0)
				if level == 0 then
					table.insert(text_and_specs, table.concat(seg_group))
					seg_group = {}
					open_at_level_zero = nil
				end
			end
		elseif level > 0 then
			table.insert(seg_group, seg)
		else
			table.insert(text_and_specs, seg)
		end
	end
	if level > 0 then
		error("Unmatched " .. open_at_level_zero .. " sign: '" .. segment_run .. "'")
	end
	return text_and_specs
end


--[=[
Split a list of alternating textual runs of the format returned by `parse_balanced_segment_run` on `splitchar`. This
only splits the odd-numbered textual runs (the portions between the balanced open/close characters).  The return value
is a list of lists, where each list contains an odd number of elements, where the even-numbered elements of the sublists
are the original balanced textual run portions. For example, if we do

parse_balanced_segment_run("foo<M.proper noun> bar<F>", "<", ">") =
  {"foo", "<M.proper noun>", " bar", "<F>", ""}

then

split_alternating_runs({"foo", "<M.proper noun>", " bar", "<F>", ""}, " ") =
  {{"foo", "<M.proper noun>", ""}, {"bar", "<F>", ""}}

Note that we did not touch the text "<M.proper noun>" even though it contains a space in it, because it is an
even-numbered element of the input list. This is intentional and allows for embedded separators inside of
brackets/parens/etc. Note also that the inner lists in the return value are of the same form as the input list (i.e.
they consist of alternating textual runs where the even-numbered segments are balanced runs), and can in turn be passed
to split_alternating_runs().

If `preserve_splitchar` is passed in, the split character is included in the output, as follows:

split_alternating_runs({"foo", "<M.proper noun>", " bar", "<F>", ""}, " ", true) =
  {{"foo", "<M.proper noun>", ""}, {" "}, {"bar", "<F>", ""}}

Consider what happens if the original string has multiple spaces between brackets, and multiple sets of brackets
without spaces between them.

parse_balanced_segment_run("foo[dated][low colloquial] baz-bat quux xyzzy[archaic]", "[", "]") =
  {"foo", "[dated]", "", "[low colloquial]", " baz-bat quux xyzzy", "[archaic]", ""}

then

split_alternating_runs({"foo", "[dated]", "", "[low colloquial]", " baz-bat quux xyzzy", "[archaic]", ""}, "[ %-]") =
  {{"foo", "[dated]", "", "[low colloquial]", ""}, {"baz"}, {"bat"}, {"quux"}, {"xyzzy", "[archaic]", ""}}

If `preserve_splitchar` is passed in, the split character is included in the output,
as follows:

split_alternating_runs({"foo", "[dated]", "", "[low colloquial]", " baz bat quux xyzzy", "[archaic]", ""}, "[ %-]", true) =
  {{"foo", "[dated]", "", "[low colloquial]", ""}, {" "}, {"baz"}, {"-"}, {"bat"}, {" "}, {"quux"}, {" "}, {"xyzzy", "[archaic]", ""}}

As can be seen, the even-numbered elements in the outer list are one-element lists consisting of the separator text.
]=]
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


local function strip_spaces(text)
	return rsub(text, "^%s*(.-)%s*$", "%1")
end


-- Like split_alternating_runs() but strips spaces from both ends of the odd-numbered elements (only in
-- odd-numbered runs if preserve_splitchar is given). Effectively we leave alone the footnotes and splitchars
-- themselves, but otherwise strip extraneous spaces. Spaces in the middle of an element are also left alone.
function export.split_alternating_runs_and_strip_spaces(segment_runs, splitchar, preserve_splitchar)
	local split_runs = export.split_alternating_runs(segment_runs, splitchar, preserve_splitchar)
	for i, run in ipairs(split_runs) do
		if not preserve_splitchar or i % 2 == 1 then
			for j, element in ipairs(run) do
				if j % 2 == 1 then
					run[j] = strip_spaces(element)
				end
			end
		end
	end
	return split_runs
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


------------------------------------------------------------------------------------------------------------
--                                             INFLECTION CODE                                            --
------------------------------------------------------------------------------------------------------------

--[=[
The following code is used in building up the inflection of terms in inflected languages, where a term can potentially
consist of several inflected words, each surrounded by fixed text, and a given slot (e.g. accusative singular) of a
given word can potentially consist of multiple possible inflected forms. In addition, each form may be associated with
a manual translation and/or a list of footnotes (or qualifiers, in the case of headword lines). The following
terminology is helpful to understand:

* An `inflection dimension` is a particular dimension over which a term may be inflected, such as case, number, gender,
  person, tense, mood, voice, aspect, etc.
* A `term` is a word or multiword expression that can be inflected. A multiword term may in turn consist of several
  single-word inflected terms with surrounding fixed text. A term belongs to a particular `part of speech` (e.g. noun,
  verb, adjective, etc.).
* A `slot` is a particular combination of inflection dimensions. An example might be "accusative plural" for a noun,
  or "first-person singular present indicative" for a verb. Slots are named in a language-specific fashion. For
  example, the slot "accusative plural" might have a name "accpl", while "first-person singular present indicative"
  might be variously named "pres1s", "pres_ind_1_sg", etc. Each slot is filled with zero or more `forms`.
* A `form` is a particular inflection of a slot for a particular term. Forms are described using `form objects`, which
  are Lua objects taking the form {form="FORM", translit="MANUAL_TRANSLIT", footnotes={"FOOTNOTE", "FOOTNOTE", ...}}.
  FORM is a `form string` specifying the value of the form itself. MANUAL_TRANSLIT specifies optional manual
  transliteration for the form, in case (a) the form string is in a different script; and (b) either the form's
  automatic transliteration is incorrect and needs to be overridden, or the language of the term has no automatic
  transliteration (e.g. in the case of Persian and Hebrew). FOOTNOTE is a footnote to be attached to the form in
  question, and should be e.g. "[archaic]" or "[only in the meaning 'to succeed (an officeholder)']", i.e. the string
  must be surrounded by brackets and should begin with a lowercase letter and not end in a period/full stop. When such
  footnotes are converted to actual footnotes in a table of inflected forms, the brackets will be removed, the first
  letter will be capitalized and a period/full stop will be added to the end. (However, when such footnotes are used
  as qualifiers in headword lines, only the brackets will be removed, with no capitalization or final period.) Note
  that only FORM is mandatory. 
* The `lemma` is the particular form of a term under which the term is entered into a dictionary. For example, for
  verbs, it is most commonly the infinitive, but this differs for some languages: e.g. Latin, Greek and Bulgarian use
  the first-person singular present indicative (active voice in the case of Latin and Greek); Sanskrit and Macedonian
  use the third-person singular present indicative (active voice in the case of Sanskrit); Hebrew and Arabic use the
  third-person singular masculine past (aka "perfect"); etc. For nouns, the lemma form is most commonly the nominative
  singular, but e.g. for Old French it is the objective singular and for Sanskrit it is the root.
]=]


local function extract_footnote_modifiers(footnote)
	local footnote_mods, footnote_without_mods = rmatch(footnote, "^%[([!*+]?)(.*)%]$")
	if not footnote_mods then
		error("Saw footnote '" .. footnote .. "' not surrounded by brackets")
	end
	return footnote_mods, footnote_without_mods
end


-- Insert a form (an object of the form {form=FORM, translit=MANUAL_TRANSLIT, footnotes=FOOTNOTES}) into a list of such
-- forms. If the form is already present, the footnotes of the existing and new form might be combined (specifically,
-- footnotes in the new form beginning with ! will be combined).
function export.insert_form_into_list(list, form)
	-- Don't do anything if the form object or the form inside it is nil. This simplifies
	-- form insertion in the presence of inflection generating functions that may return nil,
	-- such as generate_noun_vocative() and generate_noun_count_form().
	if not form or not form.form then
		return
	end
	for _, listform in ipairs(list) do
		if listform.form == form.form and listform.translit == form.translit then
			-- Form already present; maybe combine footnotes.
			if form.footnotes then
				-- Check to see if there are existing footnotes with *; if so, remove them.
				if listform.footnotes then
					local any_footnotes_with_asterisk = false
					for _, footnote in ipairs(listform.footnotes) do
						local footnote_mods, _ = extract_footnote_modifiers(footnote)
						if rfind(footnote_mods, "%*") then
							any_footnotes_with_asterisk = true
							break
						end
					end
					if any_footnotes_with_asterisk then
						local filtered_footnotes = {}
						for _, footnote in ipairs(listform.footnotes) do
							local footnote_mods, _ = extract_footnote_modifiers(footnote)
							if not rfind(footnote_mods, "%*") then
								table.insert(filtered_footnotes, footnote)
							end
						end
						if #filtered_footnotes > 0 then
							listform.footnotes = filtered_footnotes
						else
							listform.footnotes = nil
						end
					end
				end

				-- The behavior here has changed; track cases where the old behavior might
				-- be needed by adding ! to the footnote.
				require("Module:debug").track("inflection-utilities/combining-footnotes")
				local any_footnotes_with_bang = false
				for _, footnote in ipairs(form.footnotes) do
					local footnote_mods, _ = extract_footnote_modifiers(footnote)
					if rfind(footnote_mods, "[!+]") then
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
						local footnote_mods, footnote_without_mods = extract_footnote_modifiers(footnote)
						if rfind(footnote_nods, "[!+]") then
							for _, existing_footnote in ipairs(listform.footnotes) do
								local existing_footnote_mods, existing_footnote_without_mods =
									extract_footnote_modifiers(existing_footnote)
								if existing_footnote_without_mods == footnote_without_mods then
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
	-- form insertion in the presence of inflection generating functions that may return nil,
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


function export.identity(form, translit)
	return form, translit
end


local function call_map_function_str(str, fun)
	if str == "?" then
		return "?"
	end
	local newform, newtranslit = fun(str)
	if newtranslit then
		return {form=newform, translit=newtranslit}
	else
		return newform
	end
end


local function call_map_function_obj(form, fun)
	if form.form == "?" then
		return {form = "?", footnotes = form.footnotes}
	end
	local newform, newtranslit = fun(form.form, form.translit)
	return {form=newform, translit=newtranslit, footnotes=form.footnotes}
end


-- Map a function over the form values in FORMS (a list of form objects of the form {form=FORM,
-- translit=MANUAL_TRANSLIT, footnotes=FOOTNOTES}). If the input form is "?", it is preserved on output and the
-- function is not called. The function is called with two arguments, the original form and manual translit; if manual
-- translit isn't relevant, it's fine to declare the function with only one argument. The return value is either a
-- single value (the new form) or two values (the new form and new manual translit). The footnotes (if any) from the
-- input form objects are preserved on output. Uses insert_form_into_list() to insert the resulting form objects into
-- the returned list in case two different forms map to the same thing.
function export.map_forms(forms, fun)
	if not forms then
		return nil
	end
	local retval = {}
	for _, form in ipairs(forms) do
		export.insert_form_into_list(retval, call_map_function_obj(form, fun))
	end
	return retval
end


-- Map a list-returning function over the form values in FORMS (a list of form objects of the form {form=FORM,
-- translit=MANUAL_TRANSLIT, footnotes=FOOTNOTES}). If the input form is "?", it is preserved on output and the
-- function is not called. The function is called with two arguments, the original form and manual translit; if manual
-- translit isn't relevant, it's fine to declare the function with only one argument. The return value is either a list
-- of forms or a list of form objects of the form {form=FORM, translit=MANUAL_TRANSLIT}. The footnotes (if any) from
-- the input form objects are preserved on output. Uses insert_form_into_list() to insert the resulting form objects
-- into the returned list in case two different forms map to the same thing.
function export.flatmap_forms(forms, fun)
	if not forms then
		return nil
	end
	local retval = {}
	for _, form in ipairs(forms) do
		local funret = form.form == "?" and {"?"} or fun(form.form, form.translit)
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


-- Map a function over the form values in FORMS (a single string, a form object of the form {form=FORM,
-- translit=MANUAL_TRANSLIT, footnotes=FOOTNOTES}, or a list of either of the previous two types). If the input form is
-- "?", it is preserved on output and the function is not called. If FIRST_ONLY is given and FORMS is a list, only map
-- over the first element. Return value is of the same form as FORMS, unless FORMS is a string and the function return
-- both form and manual translit (in which case the return value is a form object). The function is called with two
-- arguments, the original form and manual translit; if manual translit isn't relevant, it's fine to declare the
-- function with only one argument. The return value is either a single value (the new form) or two values (the new
-- form and new manual translit). The footnotes (if any) from the input form objects are preserved on output.
--
-- FIXME: This function is used only in [[Module:bg-verb]] and should be moved into that module.
function export.map_form_or_forms(forms, fun, first_only)
	if not forms then
		return nil
	elseif type(forms) == "string" then
		return call_map_function_str(forms, fun)
	elseif forms.form then
		return call_map_function_obj(forms, fun)
	else
		local retval = {}
		for i, form in ipairs(forms) do
			if first_only then
				return export.map_form_or_forms(form, fun)
			end
			table.insert(retval, export.map_form_or_forms(form, fun))
		end
		return retval
	end
end


-- Combine two sets of footnotes. If either is nil, just return the other, and if both are nil, return nil.
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


-- Expand a given footnote (as specified by the user, including the surrounding brackets) into the form to be inserted
-- into the final generated table. If `no_parse_refs` is not given and the footnote is a reference (of the form
-- '[ref:...]'), parse and return the specified reference(s). Two values are returned, `footnote_string` (the expanded
-- footnote, or nil if the second value is present) and `references` (a list of objects of the form
-- {text = TEXT, name = NAME, group = GROUP} if the footnote is a reference and `no_parse_refs` is not given, otherwise
-- nil). Unless `return_raw` is given, the returned footnote string is capitalized and has a final period added.
function export.expand_footnote_or_references(note, return_raw, no_parse_refs)
	local _, notetext = extract_footnote_modifiers(note)
	if not no_parse_refs and notetext:find("^ref:") then
		-- a reference
		notetext = rsub(notetext, "^ref:", "")
		local parsed_refs = require("Module:references").parse_references(notetext)
		for i, ref in ipairs(parsed_refs) do
			if type(ref) == "string" then
				parsed_refs[i] = {text = ref}
			end
		end
		return nil, parsed_refs
	end
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
	return return_raw and notetext or m_string_utilities.ucfirst(notetext) .. "."
end


-- Older entry point. Equivalent to expand_footnote_or_references(note, true).
-- FIXME: Convert all uses to use expand_footnote_or_references() instead.
function export.expand_footnote(note)
	return export.expand_footnote_or_references(note, false, "no parse refs")
end


function export.fetch_headword_qualifiers_and_references(footnotes)
	if not footnotes then
		return nil
	end
	local quals, refs
	for _, qualifier in ipairs(footnotes) do
		local this_footnote, this_refs = export.expand_footnote_or_references(qualifier, "return raw")
		if this_refs then
			if not refs then
				refs = this_refs
			else
				for _, ref in ipairs(this_refs) do
					table.insert(refs, ref)
				end
			end
		else
			if not quals then
				quals = {this_footnote}
			else
				table.insert(quals, this_footnote)
			end
		end
	end
	return quals, refs
end


-- Combine a form (either a string or a table) with additional footnotes, possibly replacing the form string and/or
-- translit in the process. Normally called in one of two ways:
-- (1) combine_form_and_footnotes(FORM_OBJ, ADDL_FOOTNOTES, NEW_FORM, NEW_TRANSLIT) where FORM_OBJ is an existing
--     form object (a table of the form {form = FORM, translit = TRANSLIT, footnotes = FOOTNOTES, ...}); ADDL_FOOTNOTES
--     is either nil, a single string (a footnote) or a list of footnotes; NEW_FORM is either nil or the new form
--     string to substitute; and NEW_TRANSLIT is either nil or the new translit string to substitute.
-- (2) combine_form_and_footnotes(FORM_STRING, FOOTNOTES), where FORM_STRING is a string and FOOTNOTES is either nil,
--     a single string (a footnote) or a list of footnotes.
--
-- In either case, a form object (a table of the form {form = FORM, translit = TRANSLIT, footnotes = FOOTNOTES, ...})
-- is returned, preserving as many properties as possible from any existing form object in FORM_OR_FORM_OBJ. Do the
-- minimal amount of work; e.g. if FORM_OR_FORM_OBJ is a form object and ADDL_FOOTNOTES, NEW_FORM and NEW_TRANSLIT are
-- all nil, the same object as passed in is returned. Under no circumstances is the existing form object side-effected.
function export.combine_form_and_footnotes(form_or_form_obj, addl_footnotes, new_form, new_translit)
	if type(addl_footnotes) == "string" then
		addl_footnotes = {addl_footnotes}
	end
	if not addl_footnotes and not new_form and not new_translit then
		return form_or_form_obj
	end
	if type(form_or_form_obj) == "string" then
		new_form = new_form or form_or_form_obj
		return {form = new_form, translit = new_translit, footnotes = addl_footnotes}
	end
	form_or_form_obj = m_table.shallowcopy(form_or_form_obj)
	if new_form then
		form_or_form_obj.form = new_form
	end
	if new_translit then
		form_or_form_obj.translit = new_translit
	end
	if addl_footnotes then
		form_or_form_obj.footnotes = export.combine_footnotes(form_or_form_obj.footnotes, addl_footnotes)
	end
	return form_or_form_obj
end


-- Older entry point. FIXME: Obsolete me.
function export.generate_form(form, footnotes)
	return export.combine_form_and_footnotes(form, footnotes)
end


-- Combine a single form (either a string or object {form = FORM, footnotes = FOOTNOTES, ...}) or a list of same
-- along with footnotes and return a list of forms where each returned form is an object
-- {form = FORM, footnotes = FOOTNOTES, ...}. If WORD_OR_WORDS is already in general list form and FOOTNOTES is nil,
-- return WORD_OR_WORDS directly rather than copying it.
function export.convert_to_general_list_form(word_or_words, footnotes)
	if type(footnotes) == "string" then
		footnotes = {footnotes}
	end
	if type(word_or_words) == "string" then
		return {{form = word_or_words, footnotes = footnotes}}
	elseif word_or_words.form then
		return {export.combine_form_and_footnotes(word_or_words, footnotes)}
	elseif not footnotes then
		-- Check if already in general list form and return directly if so.
		local must_convert = false
		for _, form in ipairs(word_or_words) do
			if type(form) == "string" then
				must_convert = true
				break
			end
		end
		if not must_convert then
			return word_or_words
		end
	end
	local retval = {}
	for _, form in ipairs(word_or_words) do
		if type(form) == "string" then
			table.insert(retval, {form = form, footnotes = footnotes})
		else
			table.insert(retval, export.combine_form_and_footnotes(form, footnotes))
		end
	end
	return retval
end


local function is_table_of_strings(forms)
	for k, v in pairs(forms) do
		if type(k) ~= "number" or type(v) ~= "string" then
			return false
		end
	end
	return true
end


-- Combine `stems` and `endings` and store into slot `slot` of form table `forms`. Either of `stems` and `endings` can
-- be nil, a single string, a list of strings, a form object or a list of form objects. The combination of a given stem
-- and ending happens using `combine_stem_ending`, which takes two parameters (stem and ending, each a string) and
-- returns one value (a string). If manual transliteration is present in either `stems` or `endings`, `lang` (a
-- language object) along with `combine_stem_ending_tr` (a function like `combine_stem_ending` for combining manual
-- transliteration) must be given. `footnotes`, if specified, is a list of additional footnotes to attach to the
-- resulting inflections (stem+ending combinations). The resulting inflections are inserted into the form table using
-- export.insert_form(), in case of duplication.
function export.add_forms(forms, slot, stems, endings, combine_stem_ending, lang, combine_stem_ending_tr, footnotes)
	if stems == nil or endings == nil then
		return
	end
	local function combine(stem, ending)
		if stem == "?" or ending == "?" then
			return "?"
		end
		return combine_stem_ending(stem, ending)
	end
	if type(stems) == "string" and type(endings) == "string" then
		export.insert_form(forms, slot, {form = combine(stems, endings), footnotes = footnotes})
	elseif type(stems) == "string" and is_table_of_strings(endings) then
		for _, ending in ipairs(endings) do
			export.insert_form(forms, slot, {form = combine(stems, ending), footnotes = footnotes})
		end
	else
		stems = export.convert_to_general_list_form(stems)
		endings = export.convert_to_general_list_form(endings, footnotes)
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
				local new_form = combine(stem.form, ending.form)
				local new_translit
				if new_form ~= "?" and (stem.translit or ending.translit) then
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


function export.add_multiple_forms(forms, slot, sets_of_forms, combine_stem_ending,
	lang, combine_stem_ending_tr, footnotes)
	if #sets_of_forms == 0 then
		return
	elseif #sets_of_forms == 1 then
		local formset = export.convert_to_general_list_form(sets_of_forms[1], footnotes)
		export.insert_forms(forms, slot, formset)
	elseif #sets_of_forms == 2 then
		local stems = sets_of_forms[1]
		local endings = sets_of_forms[2]
		export.add_forms(forms, slot, stems, endings, combine_stem_ending,
			lang, combine_stem_ending_tr, footnotes)
	else
		local prev = sets_of_forms[1]
		for i=2,#sets_of_forms do
			local tempdest = {}
			export.add_forms(tempdest, slot, prev, sets_of_forms[i], combine_stem_ending,
				lang, combine_stem_ending_tr, i == #sets_of_forms and footnotes or nil)
			prev = tempdest[slot]
		end
		export.insert_forms(forms, slot, prev)
	end
end
		

local function iterate_slot_list_or_table(props, do_slot)
	if props.slot_list then
		for _, slot_and_accel_form in ipairs(props.slot_list) do
			local slot, accel_form = unpack(slot_and_accel_form)
			do_slot(slot, accel_form)
		end
	else
		for slot, accel_form in pairs(props.slot_table) do
			do_slot(slot, accel_form)
		end
	end
end


local function parse_before_or_post_text(props, text, segments, lemma_is_last)
	-- If the text begins with a hyphen, include the hyphen in the set of allowed characters
	-- for an inflected segment. This way, e.g. conjugating "-ir" is treated as a regular
	-- -ir verb rather than a hyphen + irregular [[ir]].
	local is_suffix = rfind(text, "^%-")
	-- Call parse_balanced_segment_run() to keep multiword links together.
	local bracketed_runs = export.parse_balanced_segment_run(text, "[", "]")
	-- Split on space or hyphen. Use preserve_splitchar so we know whether the separator was
	-- a space or hyphen.
	local space_separated_groups = export.split_alternating_runs(bracketed_runs,
		is_suffix and " " or "[ %-]", "preserve splitchar")

	local parsed_components = {}
	local parsed_components_translit = {}
	local saw_manual_translit = false
	local lemma
	for j, space_separated_group in ipairs(space_separated_groups) do
		local component = table.concat(space_separated_group)
		if lemma_is_last and j == #space_separated_groups then
			lemma = component
			if lemma == "" and not props.allow_blank_lemma then
				error("Word is blank: '" .. table.concat(segments) .. "'")
			end
		elseif rfind(component, "//") then
			-- Manual translit or respelling specified.
			if not props.lang then
				error("Manual translit not allowed for this language; if this is incorrect, 'props.lang' must be set internally")
			end
			saw_manual_translit = true
			local split = rsplit(component, "//")
			if #split ~= 2 then
				error("Term with translit or respelling should have only one // in it: " .. component)
			end
			local translit
			component, translit = unpack(split)
			if props.transliterate_respelling then
				translit = props.transliterate_respelling(translit)
			end
			table.insert(parsed_components, component)
			table.insert(parsed_components_translit, translit)
		else
			table.insert(parsed_components, component)
			table.insert(parsed_components_translit, false) -- signal that it may need later transliteration
		end
	end

	if saw_manual_translit then
		for j, parsed_component in ipairs(parsed_components) do
			if not parsed_components_translit[j] then
				parsed_components_translit[j] =
					props.lang:transliterate(m_links.remove_links(parsed_component))
			end
		end
	end

	text = table.concat(parsed_components)
	local translit
	if saw_manual_translit then
		translit = table.concat(parsed_components_translit)
	end
	return text, translit, lemma
end


--[=[
Parse a segmented multiword spec such as "[[медичний|меди́чна]]<+> [[сестра́]]<*,*#.pr>" (in Ukrainian).
"Segmented" here means it is broken up on <...> segments using parse_balanced_segment_run(text, "<", ">"),
e.g. the above text would be passed in as {"[[медичний|меди́чна]]", "<+>", " [[сестра́]]", "<*,*#.pr>", ""}.

The return value is a table of the form
{
  word_specs = {WORD_SPEC, WORD_SPEC, ...},
  post_text = "TEXT-AT-END",
  post_text_no_links = "TEXT-AT-END-NO-LINKS",
  post_text_translit = "MANUAL-TRANSLIT-OF-TEXT-AT-END" or nil (if no manual translit or respelling was specified in the post-text)
}

where WORD_SPEC describes an individual inflected word and "TEXT-AT-END" is any raw text that may occur
after all inflected words. Individual words or linked text (including multiword text) may be given manual
transliteration or respelling in languages that support this using TEXT//TRANSLIT or TEXT//RESPELLING.
Each WORD_SPEC is of the form returned by parse_indicator_spec():

{
  lemma = "LEMMA",
  before_text = "TEXT-BEFORE-WORD",
  before_text_no_links = "TEXT-BEFORE-WORD-NO-LINKS",
  before_text_translit = "MANUAL-TRANSLIT-OF-TEXT-BEFORE-WORD" or nil (if no manual translit or respelling was specified in the before-text)
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
  post_text_no_links = "",
}
]=]
local function parse_multiword_spec(segments, props, disable_allow_default_indicator)
	local multiword_spec = {
		word_specs = {}
	}
	if not disable_allow_default_indicator and props.allow_default_indicator and #segments == 1 then
		table.insert(segments, "<>")
		table.insert(segments, "")
	end
	-- Loop over every other segment. The even-numbered segments are angle-bracket specs while
	-- the odd-numbered segments are the text between them.
	for i = 2, #segments - 1, 2 do
		local before_text, before_text_translit, lemma =
			parse_before_or_post_text(props, segments[i - 1], segments, "lemma is last")
		local base = props.parse_indicator_spec(segments[i], lemma)
		base.before_text = before_text
		base.before_text_no_links = m_links.remove_links(base.before_text)
		base.before_text_translit = before_text_translit
		base.lemma = base.lemma or lemma
		table.insert(multiword_spec.word_specs, base)
	end
	multiword_spec.post_text, multiword_spec.post_text_translit =
		parse_before_or_post_text(props, segments[#segments], segments)
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
local function parse_alternant(alternant, props)
	local parsed_alternants = {}
	local alternant_text = rmatch(alternant, "^%(%((.*)%)%)$")
	local segments = export.parse_balanced_segment_run(alternant_text, "<", ">")
	local comma_separated_groups = export.split_alternating_runs(segments, "%s*,%s*")
	local alternant_spec = {alternants = {}}
	for _, comma_separated_group in ipairs(comma_separated_groups) do
		table.insert(alternant_spec.alternants, parse_multiword_spec(comma_separated_group, props))
	end
	return alternant_spec
end


--[=[
Top-level parsing function. Parse text describing one or more inflected words.
`text` is the inflected text to parse, which generally has <...> specs following words to
be inflected, and may have alternants indicated using double parens. Examples:

"[[медичний|меди́чна]]<+> [[сестра́]]<*,*#.pr>" (Ukrainian, for [[медична сестра]] "nurse (lit. medical sister)")
"((ру́син<pr>,руси́н<b.pr>))" (Ukrainian, for [[русин]] "Rusyn")
"पंचायती//पंचाय*ती राज<M>" (Hindi, for [[पंचायती राज]] "village council", with phonetic respelling in the before-text component)
"((<M>,<M.plstem:फ़तूह.dirpl:फ़तूह>))" (Hindi, for [[फ़तह]] "win, victory", on that page, where the lemma is omitted and taken from the pagename)
"" (for any number of Hindi adjectives, where the lemma is omitted and taken from the pagename, and the angle bracket spec <> is assumed)
"काला<+>धन<M>" (Hindi, for [[कालाधन]] "black money")

`props` is an object specifying properties used during parsing, as follows:
{
  parse_indicator_spec = FUNCTION_TO_PARSE_AN_INDICATOR_SPEC (required; takes two arguments,
                           a string surrounded by angle brackets and the lemma, and should
                           return a word_spec object containing properties describing the
                           indicators inside of the angle brackets),
  lang = LANG_OBJECT (only needed if manual translit or respelling may be present using //),
  transliterate_respelling = FUNCTION_TO_TRANSLITERATE_RESPELLING (only needed of respelling
                               is allowed in place of manual translit after //; takes one
							   argument, the respelling or translit, and should return the
							   transliteration of any resplling but return any translit
							   unchanged),
  allow_default_indicator = BOOLEAN_OR_NIL (true if the indicator in angle brackets can
                              be omitted and will be automatically added at the end of the
							  multiword text (if no alternants) or at the end of each
							  alternant (if alternants present),
  allow_blank_lemma = BOOLEAN_OR_NIL (true if a blank lemma is allowed; in such a case, the
                        calling function should substitute a default lemma, typically taken
						from the pagename)
}

The return value is a table of the form
{
  alternant_or_word_specs = {ALTERNANT_OR_WORD_SPEC, ALTERNANT_OR_WORD_SPEC, ...}
  post_text = "TEXT-AT-END",
  post_text_no_links = "TEXT-AT-END-NO-LINKS",
  post_text_translit = "TRANSLIT-OF-TEXT-AT-END" (or nil),
}

where ALTERNANT_OR_WORD_SPEC is either an alternant spec as returned by parse_alternant()
or a multiword spec as described in the comment above parse_multiword_spec(). An alternant spec
looks as follows:
{
  alternants = {MULTIWORD_SPEC, MULTIWORD_SPEC, ...},
  before_text = "TEXT-BEFORE-ALTERNANT",
  before_text_no_links = "TEXT-BEFORE-ALTERNANT",
  before_text_translit = "TRANSLIT-OF-TEXT-BEFORE-ALTERNANT" (or nil),
}
i.e. it is like what is returned by parse_alternant() but has extra `before_text`
and `before_text_no_links` fields.
]=]
function export.parse_inflected_text(text, props)
	local alternant_multiword_spec = {alternant_or_word_specs = {}}
	local alternant_segments = m_string_utilities.capturing_split(text, "(%(%(.-%)%))")
	local last_post_text, last_post_text_no_links, last_post_text_translit
	for i = 1, #alternant_segments do
		if i % 2 == 1 then
			local segments = export.parse_balanced_segment_run(alternant_segments[i], "<", ">")
			-- Disable allow_default_indicator if alternants are present and we're processing
			-- the non-alternant text. Otherwise we will try to treat the non-alternant text
			-- surrounding the alternants as an inflected word rather than as raw text.
			local multiword_spec = parse_multiword_spec(segments, props, #alternant_segments ~= 1)
			for _, word_spec in ipairs(multiword_spec.word_specs) do
				table.insert(alternant_multiword_spec.alternant_or_word_specs, word_spec)
			end
			last_post_text = multiword_spec.post_text
			last_post_text_no_links = multiword_spec.post_text_no_links
			last_post_text_translit = multiword_spec.post_text_translit
		else
			local alternant_spec = parse_alternant(alternant_segments[i], props)
			alternant_spec.before_text = last_post_text
			alternant_spec.before_text_no_links = last_post_text_no_links
			alternant_spec.before_text_translit = last_post_text_translit
			table.insert(alternant_multiword_spec.alternant_or_word_specs, alternant_spec)
		end
	end
	alternant_multiword_spec.post_text = last_post_text
	alternant_multiword_spec.post_text_no_links = last_post_text_no_links
	alternant_multiword_spec.post_text_translit = last_post_text_translit
	return alternant_multiword_spec
end


-- Older entry point. FIXME: Convert all uses of this to use export.parse_inflected_text() instead. 
function export.parse_alternant_multiword_spec(text, parse_indicator_spec, allow_default_indicator, allow_blank_lemma)
	local props = {
		parse_indicator_spec = parse_indicator_spec,
		allow_default_indicator = allow_default_indicator,
		allow_blank_lemma = allow_blank_lemma,
	}
	return export.parse_inflected_text(text, props)
end


-- Inflect alternants in ALTERNANT_SPEC (an object as returned by parse_alternant()).
-- This sets the form values in `ALTERNANT_SPEC.forms` for all slots.
-- (If a given slot has no values, it will not be present in `ALTERNANT_SPEC.forms`).
local function inflect_alternants(alternant_spec, props)
	alternant_spec.forms = {}
	for _, multiword_spec in ipairs(alternant_spec.alternants) do
		export.inflect_multiword_or_alternant_multiword_spec(multiword_spec, props)
		iterate_slot_list_or_table(props, function(slot)
			if not props.skip_slot or not props.skip_slot(slot) then
				export.insert_forms(alternant_spec.forms, slot, multiword_spec.forms[slot])
			end
		end)
	end
end



--[=[
Subfunction of export.inflect_multiword_or_alternant_multiword_spec(). This is used in building up the inflections of
multiword expressions. The basic purpose of this function is to append a set of forms representing the inflections of
a given inflected term in a given slot onto the existing forms for that slot. Given a multiword expression potentially
consisting of several inflected terms along with fixed text in between, we work iteratively from left to right, adding
the new forms onto the existing ones. Normally, all combinations of new and existing forms are created, meaning if
there are M existing forms and N new ones, we will end up with M*N forms. However, some of these combinations can be
rejected using the variant mechanism (see the description of get_variants below).

Specifically, `formtable` is a table of per-slot forms, where the key is a slot and the value is a list of form objects
(objects of the form {form=FORM, translit=MANUAL_TRANSLIT, footnotes=FOOTNOTES}). `slot` is the slot in question.
`forms` specifies the forms to be appended onto the existing forms, and is likewise a list of form objects. `props`
is the same as in export.inflect_multiword_or_alternant_multiword_spec(). `before_text` is the fixed text that goes
before the forms to be added. `before_text_no_links` is the same as `before_text` but with any links (i.e. hyperlinks
of the form [[TERM]] or [[TERM|DISPLAY]]) converted into raw terms using remove_links() in [[Module:links]], and
`before_text_translit` is optional manual translit of `before_text_no_links`.

Note that the value "?" in a form is "infectious" in that if either the existing or new form has the value "?", the
resulting combination will also be "?". This allows "?" to be used to mean "unknown".
]=]
local function append_forms(props, formtable, slot, forms, before_text, before_text_no_links, before_text_translit)
	if not forms then
		return
	end
	local old_forms = formtable[slot] or {{form = ""}}
	local ret_forms = {}
	for _, old_form in ipairs(old_forms) do
		for _, form in ipairs(forms) do
			local old_form_vars = props.get_variants and props.get_variants(old_form.form) or ""
			local form_vars = props.get_variants and props.get_variants(form.form) or ""
			if old_form_vars ~= "" and form_vars ~= "" and old_form_vars ~= form_vars then
				-- Reject combination due to non-matching variant codes.
			else
				local new_form
				local new_translit
				if old_form.form == "?" or form.from == "?" then
					new_form = "?"
				else
					new_form = old_form.form .. before_text .. form.form
					if old_form.translit or before_text_translit or form.translit then
						if not props.lang then
							error("Internal error: If manual translit is given, 'props.lang' must be set")
						end
						if not before_text_translit then
							before_text_translit = props.lang:transliterate(before_text_no_links) or ""
						end
						local old_translit = old_form.translit or props.lang:transliterate(m_links.remove_links(old_form.form)) or ""
						local translit = form.translit or props.lang:transliterate(m_links.remove_links(form.form)) or ""
						new_translit = old_translit .. before_text_translit .. translit
					end
				end
				local new_footnotes = export.combine_footnotes(old_form.footnotes, form.footnotes)
				table.insert(ret_forms, {form=new_form, translit=new_translit,
					footnotes=new_footnotes})
			end
		end
	end
	formtable[slot] = ret_forms
end


--[=[
Top-level inflection function. Create the inflections of a noun, verb, adjective or similar. `multiword_spec` is as
returned by `parse_inflected_text` and describes the properties of the term to be inflected, including all the
user-provided inflection specifications (e.g. the number, gender, conjugation/declension/etc. of each word) and the
surrounding text. `props` indicates how to do the actual inflection (see below). The resulting inflected forms are
stored into the `.forms` property of `multiword_spec`. This property holds a table whose keys are slots (i.e. ID's
of individual inflected forms, such as "pres_1sg" for the first-person singular present indicative tense of a verb)
and whose values are lists of the form { form = FORM, translit = MANUAL_TRANSLIT_OR_NIL, footnotes = FOOTNOTE_LIST_OR_NIL},
where FORM is a string specifying the value of the form (e.g. "ouço" for the first-person singular present indicative
of the Portuguese verb [[ouvir]]); MANUAL_TRANSLIT_OR_NIL is the corresponding manual transliteration if needed (i.e.
if the form is in a non-Latin script and the automatic transliteration is incorrect or unavailable), otherwise nil;
and FOOTNOTE_LIST_OR_NIL is a list of footnotes to be attached to the form, or nil for no footnotes. Note that
currently footnotes must be surrounded by brackets, e.g "[archaic]", and should not begin with a capital letter or end
with a period. (Conversion from "[archaic]" to "Archaic." happens automatically.) 

This function has no return value, but modifies `multiword_spec` in-place, adding the `forms` table as described above.
After calling this function, call show_forms() on the `forms` table to convert the forms and footnotes given in this
table to strings suitable for display.

`props` is an object specifying properties used during inflection, as follows:
{
  slot_list = {{"SLOT", "ACCEL"}, {"SLOT", "ACCEL"}, ...},
  slot_table = {SLOT = "ACCEL", SLOT = "ACCEL", ...},
  skip_slot = FUNCTION_TO_SKIP_A_SLOT or nil,
  lang = LANG_OBJECT or nil,
  inflect_word_spec = FUNCTION_TO_INFLECT_AN_INDIVIDUAL_WORD,
  get_variants = FUNCTION_TO_RETURN_A_VARIANT_CODE or nil,
  include_user_specified_links = BOOLEAN,
}

`slot_list` is a list of two-element lists of slots and associated accelerator inflections. SLOT is arbitrary but
should correspond with slot names as generated by `inflect_word_spec`. ACCEL is the corresponding accelerator form;
e.g. if SLOT is "pres_1sg", ACCEL might be "1|s|pres|ind". ACCEL is actually unused during inflection, but is used
during show_forms(), which takes the same `slot_list` as a property upon input.

`slot_table` is a table mapping slots to associated accelerator inflections and serves the same function as
`slot_list`. Only one of `slot_list` or `slot_table` must be given. For new code it is preferable to use `slot_list`
because this allows you to control the order of processing slots, which may occasionally be important.

`skip_slot` is a function of one argument, a slot name, and should return a boolean indicating whether to skip the
given slot during inflection. It can be used, for example, to skip singular slots if the overall term being inflected
is plural-only, and vice-versa.

`lang` is a language object. This is only used to generate manual transliteration. If the language is written in the
Latin script or manual transliteration cannot be specified in the input to parse_inflected_text(), this can be omitted.
(Manual transliteration is allowed if the `lang` object is set in the `props` passed to parse_inflected_text().)

`inflect_word_spec` is the function to do the actual inflection. Note that for compatibility purposes the same function
can be set as the `decline_word_spec` property; don't use this in new code. It is passed a single argument, which is
a WORD_SPEC object describing the word to be inflected and the user-provided inflection specifications. It is exactly
the same as was returned by the `parse_indicator_spec` function provided in the `props` sent on input to
`parse_inflected_text`, but has additional fields describing the word to be inflected and the surrounding text, as
follows:
{
  lemma = "LEMMA",
  before_text = "TEXT-BEFORE-WORD",
  before_text_no_links = "TEXT-BEFORE-WORD-NO-LINKS",
  before_text_translit = "MANUAL-TRANSLIT-OF-TEXT-BEFORE-WORD" or nil (if no manual translit or respelling was specified in the before-text)
  -- Fields as described in parse_indicator_spec()
  ...
}

Here LEMMA is the word to be inflected as specified by the user (including any links if so given), and the
`before_text*` fields describe the raw text preceding the word to be inflected. Any other fields in this object are as
set by `parse_inflected_text`, and describe things like the gender, number, conjugation/declension, etc. as specified
by the user in the <...> spec following the word to be inflected.

`inflect_word_spec` should initialize the `.forms` property of the passed-in WORD_SPEC object to the inflected forms of
the word in question. The value of this property is a table of the same format as the `.forms` property that is
ultimately generated by inflect_multiword_or_alternant_multiword_spec() and described above near the top of this
documentation: i.e. a table whose keys are slots and whose values are lists of the form
  { form = FORM, translit = MANUAL_TRANSLIT_OR_NIL, footnotes = FOOTNOTE_LIST_OR_NIL}.

`get_variants` is either nil or a function of one argument (a string, the value of an individual form). The purpose of
this function is to ensure that in a multiword term where a given slot has more than one possible variant, the final
output has only parallel variants in it. For example, feminine nouns and adjectives in Russian have two possible
endings, one typically in -ой (-oj) and the other in -ою (-oju). If we have a feminine adjective-noun combination (or
a hyphenated feminine noun-noun combination, or similar), and we don't specify `get_variants`, we'll end up with four
values for the instrumental singular: one where both adjective and noun end in -ой, one where both end in -ою, and
two where one of the words ends in -ой and the other in -ою. In general if we have N words each with K variants, we'll
end up with an explosion of N^K possibilities. `get_variants` avoids this by returning a variant code (an arbitary
string) for each variant. If two words each have a non-empty variant code, and the variant codes disagree, the
combination will be rejected. If `get_variants` is not provided, or either variant code is an empty string, or the
variant codes agree, the combination is allowed.

The recommended way to use `get_variants` is as follows:
1. During inflection in `inflect_word_spec`, add a special character or string to each of the variants generated for a
   given slot when there is more than one. (As an optimization, do this only when there is more than one word being
   inflected.) Special Unicode characters can be used for this purpose, e.g. U+FFF0, U+FFF1, ..., U+FFFD, which have
   no meaning in Unicode.
2. Specify `get_variants` as a function that pulls out and returns the special character(s) or string included in the
   variant forms.
3. When calling show_forms(), specify a `canonicalize` function that removes the variant code character(s) or string
   from each form before converting to the display form.

See [[Module:hi-verb]] and [[Module:hi-common]] for an example of doing this in a generalized fashion. (Look for
add_variant_codes(), get_variants() and remove_variant_codes().)

`include_user_specified_links`, if given, ensures that user-specified links in the raw text surrounding a given word
are preserved in the output. If omitted or set to false, such links will be removed and the whole multiword expression
will be linked.
]=]
function export.inflect_multiword_or_alternant_multiword_spec(multiword_spec, props)
	multiword_spec.forms = {}

	local is_alternant_multiword = not not multiword_spec.alternant_or_word_specs
	for _, word_spec in ipairs(is_alternant_multiword and multiword_spec.alternant_or_word_specs or multiword_spec.word_specs) do
		if word_spec.alternants then
			inflect_alternants(word_spec, props)
		elseif props.decline_word_spec then
			props.decline_word_spec(word_spec)
		else
			props.inflect_word_spec(word_spec)
		end
		iterate_slot_list_or_table(props, function(slot)
			if not props.skip_slot or not props.skip_slot(slot) then
				append_forms(props, multiword_spec.forms, slot, word_spec.forms[slot],
					(rfind(slot, "linked") or props.include_user_specified_links) and
					word_spec.before_text or word_spec.before_text_no_links,
					word_spec.before_text_no_links, word_spec.before_text_translit
				)
			end
		end)
	end
	if multiword_spec.post_text ~= "" then
		local pseudoform = {{form=""}}
		iterate_slot_list_or_table(props, function(slot)
			-- If slot is empty or should be skipped, don't try to append post-text.
			if (not props.skip_slot or not props.skip_slot(slot)) and multiword_spec.forms[slot] then
				append_forms(props, multiword_spec.forms, slot, pseudoform,
					(rfind(slot, "linked") or props.include_user_specified_links) and
					multiword_spec.post_text or multiword_spec.post_text_no_links,
					multiword_spec.post_text_no_links, multiword_spec.post_text_translit
				)
			end
		end)
	end
end


-- Older entry point for inflecting a term. Equivalent to inflect_multiword_or_alternant_multiword_spec().
-- FIXME: Convert all uses to use inflect_multiword_or_alternant_multiword_spec() instead.
function export.decline_multiword_or_alternant_multiword_spec(multiword_spec, props)
	return export.inflect_multiword_or_alternant_multiword_spec(multiword_spec, props)
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


function export.create_footnote_obj()
	return {
		notes = {},
		seen_notes = {},
		noteindex = 1,
		seen_refs = {},
	}
end


function export.get_footnote_text(form, footnote_obj)
	if not form.footnotes then
		return ""
	end
	local link_indices = {}
	local all_refs = {}
	for _, footnote in ipairs(form.footnotes) do
		local refs
		footnote, refs = export.expand_footnote_or_references(footnote)
		if footnote then
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
		if refs then
			for _, ref in ipairs(refs) do
				if not ref.name then
					local this_refhash = footnote_obj.seen_refs[ref.text]
					if not this_refhash then
						-- Different text needs to have different auto-generated names, globally across the entire page,
						-- including across different invocations of {{it-verb}} or {{it-conj}}. The easiest way to accomplish
						-- this is to use a message-digest hashing function. It does not have to be cryptographically secure
						-- (MD5 is insecure); it just needs to have low probability of collisions.
						this_refhash = mw.hash.hashValue("md5", ref.text)
						footnote_obj.seen_refs[ref.text] = this_refhash
					end
					ref.autoname = this_refhash
				end
				-- I considered using "n" as the default group rather than nothing, to more clearly distinguish regular
				-- footnotes from references, but this requires referencing group "n" as <references group="n"> below,
				-- which is non-obvious.
				m_table.insertIfNot(all_refs, ref)
			end
		end
	end
	table.sort(link_indices)
	local function sort_refs(r1, r2)
		-- FIXME, we are now sorting on an arbitrary hash. Should we keep track of the order we
		-- saw the autonamed references and sort on that?
		if r1.autoname and r2.name then
			return true
		elseif r1.name and r2.autoname then
			return false
		elseif r1.name and r2.name then
			return r1.name < r2.name
		else
			return r1.autoname < r2.autoname
		end
	end
	table.sort(all_refs, sort_refs)
	for i, ref in ipairs(all_refs) do
		local refargs = {name = ref.name or ref.autoname, group = ref.group}
		all_refs[i] = mw.getCurrentFrame():extensionTag("ref", ref.text, refargs)
	end
	local link_text
	if #link_indices > 0 then
		link_text = '<sup style="color: red">' .. table.concat(link_indices, ",") .. '</sup>'
	else
		link_text = ""
	end
	local ref_text = table.concat(all_refs)
	if link_text ~= "" and ref_text ~= "" then
		return link_text .. "<sup>,</sup>" .. ref_text
	else
		return link_text .. ref_text
	end
end


--[=[
Convert the forms in `forms` (a list of form objects, each of which is a table of the form
{ form = FORM, translit = MANUAL_TRANSLIT_OR_NIL, footnotes = FOOTNOTE_LIST_OR_NIL, no_accel = TRUE_TO_SUPPRESS_ACCELERATORS })
into strings. Each form list turns into a string consisting of a comma-separated list of linked forms, with accelerators
(unless `no_accel` is set in a given form). `props` is a table used in generating the strings, as follows:
{
  lang = LANG_OBJECT,
  lemmas = {"LEMMA", "LEMMA", ...},
  slot_list = {{"SLOT", "ACCEL"}, {"SLOT", "ACCEL"}, ...},
  slot_table = {SLOT = "ACCEL", SLOT = "ACCEL", ...},
  include_translit = BOOLEAN,
  create_footnote_obj = nil or FUNCTION_TO_CREATE_FOOTNOTE_OBJ,
  canonicalize = nil or FUNCTION_TO_CANONICALIZE_EACH_FORM,
  transform_link = nil or FUNCTION_TO_TRANSFORM_EACH_LINK,
  join_spans = nil or FUNCTION_TO_JOIN_SPANS,
  allow_footnote_symbols = BOOLEAN,
  footnotes = nil or {"EXTRA_FOOTNOTE", "EXTRA_FOOTNOTE", ...},
}

`lemmas` is the list of lemmas, used in the accelerators.

`slot_list` is a list of two-element lists of slots and associated accelerator inflections. SLOT should correspond to
slots generated during inflect_multiword_or_alternant_multiword_spec(). ACCEL is the corresponding accelerator form;
e.g. if SLOT is "pres_1sg", ACCEL might be "1|s|pres|ind". ACCEL is used in generating entries for accelerator support
(see [[WT:ACCEL]]).

`slot_table` is a table mapping slots to associated accelerator inflections and serves the same function as
`slot_list`. Only one of `slot_list` or `slot_table` must be given. For new code it is preferable to use `slot_list`
because this allows you to control the order of processing slots, which may occasionally be important.

`include_translit`, if given, causes transliteration to be included in the generated strings.

`create_footnote_obj` is an optional function of no arguments to create the footnote object used to track footnotes;
see export.create_footnote_obj(). Customizing it is useful to prepopulate the footnote table using
export.get_footnote_text().

`canonicalize` is an optional function of one argument (a form) to canonicalize each form before processing; it can
return nil for no change. The most common purpose of this function is to remove variant codes from the form. See the
documentation for inflect_multiword_or_alternant_multiword_spec() for a description of variant codes and their purpose.

`transform_link` is an optional function to transform a linked form prior to further processing. It is passed three
arguments (slot, link, link_tr) and should return the transformed link (or if translit is active, it should return two
values, the transformed link and corresponding translit). It can return nil for no change. `transform_link` is used,
for example, in [[Module:de-verb]], where it adds the appropriate pronoun ([[ich]], [[du]], etc.) to finite verb forms,
and adds [[dass]] before special subordinate-clause variants of finte verb forms.

`join_spans` is an optional function of three arguments (slot, orig_spans, tr_spans) where the spans in question are
after linking and footnote processing. It should return a string (the joined spans) or nil for the default algorithm,
which separately joins the orig_spans and tr_spans with commas and puts a newline between them.

`allow_footnote_symbols`, if given, causes any footnote symbols attached to forms (e.g. numbers, asterisk) to be
separated off, placed outside the links, and superscripted. In this case, `footnotes` should be a list of footnotes
(preceded by footnote symbols, which are superscripted). These footnotes are combined with any footnotes found in the
forms and placed into `forms.footnotes`. This mechanism of specifying footnotes is provided for backward compatibility
with certain existing inflection modules and should not be used for new modules. Instead, use the regular footnote
mechanism specified using the `footnotes` property attached to each form object.
]=]
function export.show_forms(forms, props)
	local footnote_obj = props.create_footnote_obj and props.create_footnote_obj() or export.create_footnote_obj()
	local accel_lemma = props.lemmas[1]
	local accel_lemma_translit
	if type(accel_lemma) == "table" then
		accel_lemma_translit = accel_lemma.translit
		accel_lemma = accel_lemma.form
	end
	accel_lemma = accel_lemma and m_links.remove_links(accel_lemma) or nil
	local lemma_forms = {}
	for _, lemma in ipairs(props.lemmas) do
		if type(lemma) == "table" then
			m_table.insertIfNot(lemma_forms, lemma.form)
		else
			m_table.insertIfNot(lemma_forms, lemma)
		end
	end
	forms.lemma = #lemma_forms > 0 and table.concat(lemma_forms, ", ") or mw.title.getCurrentTitle().text

	local m_table_tools = require("Module:table tools")
	local m_script_utilities = require("Module:script utilities")
	local function do_slot(slot, accel_form)
		local formvals = forms[slot]
		if formvals then
			local orig_spans = {}
			local tr_spans = {}
			local orignotes, trnotes = "", ""
			if type(formvals) ~= "table" then
				error("Internal error: For slot '" .. slot .. "', expected table but saw " .. mw.dumpObject(formvals))
			end
			for i, form in ipairs(formvals) do
				local orig_text = props.canonicalize and props.canonicalize(form.form) or form.form
				local link
				if form.form == "—" or form.form == "?" then
					link = orig_text
				else
					local origentry
					if props.allow_footnote_symbols then
						origentry, orignotes = m_table_tools.get_notes(orig_text)
					else
						origentry = orig_text
					end
					-- remove redundant link surrounding entire form
					origentry = export.remove_redundant_links(origentry)
					local accel_obj
					-- check if form still has links; if so, don't add accelerators
					-- because the resulting entries will be wrong
					if accel_lemma and not form.no_accel and accel_form ~= "-" and
						not rfind(origentry, "%[%[") then
						accel_obj = {
							form = accel_form,
							translit = props.include_translit and form.translit or nil,
							lemma = accel_lemma,
							lemma_translit = props.include_translit and accel_lemma_translit or nil,
						}
					end
					link = m_links.full_link{lang = props.lang, term = origentry, tr = "-", accel = accel_obj}
				end
				local tr = props.include_translit and (form.translit or props.lang:transliterate(m_links.remove_links(orig_text))) or nil
				local trentry
				if props.allow_footnote_symbols and tr then
					trentry, trnotes = m_table_tools.get_notes(tr)
				else
					trentry = tr
				end
				if props.transform_link then
					local newlink, newtr = props.transform_link(slot, link, tr)
					if newlink then
						link, tr = newlink, newtr
					end
				end
				link = link .. orignotes
				tr = tr and m_script_utilities.tag_translit(trentry, props.lang, "default", " style=\"color: #888;\"") .. trnotes or nil
				if form.footnotes then
					local footnote_text = export.get_footnote_text(form, footnote_obj)
					link = link .. footnote_text
					tr = tr and tr .. footnote_text or nil
				end
				table.insert(orig_spans, link)
				if tr then
					table.insert(tr_spans, tr)
				end
			end
			local joined_spans
			if props.join_spans then
				joined_spans = props.join_spans(slot, orig_spans, tr_spans)
			end
			if not joined_spans then
				local orig_span = table.concat(orig_spans, ", ")
				local tr_span
				if #tr_spans > 0 then
					tr_span = table.concat(tr_spans, ", ")
				end
				if tr_span then
					joined_spans = orig_span .. "<br />" .. tr_span
				else
					joined_spans = orig_span
				end
			end
			forms[slot] = joined_spans
		else
			forms[slot] = "—"
		end
	end

	iterate_slot_list_or_table(props, do_slot)

	local all_notes = footnote_obj.notes
	if props.footnotes then
		for _, note in ipairs(props.footnotes) do
			local symbol, entry = m_table_tools.get_initial_notes(note)
			table.insert(all_notes, symbol .. entry)
		end
	end
	forms.footnote = table.concat(all_notes, "<br />")
end


-- Older entry point. Same as `show_forms` but automatically sets include_translit = true in props.
-- FIXME: Convert all uses to use show_forms() instead.
function export.show_forms_with_translit(forms, lemmas, slot_table, props, footnotes, allow_footnote_symbols)
	props.lemmas = lemmas
	props.slot_table = slot_table
	props.footnotes = footnotes
	props.allow_footnote_symbols = allow_footnote_symbols
	props.include_translit = true
	return export.show_forms(forms, props)
end


return export
