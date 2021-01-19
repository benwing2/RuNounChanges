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

--[=[
In order to understand the following parsing code, you need to understand how inflected
text specs work. They are intended to work with inflected text where individual words to
be inflected may be followed by inflection specs in angle brackets. The format of the
text inside of the angle brackets is up to the individual language and part-of-speech
specific implementation. A real-world example is as follows:
"[[медичний|меди́чна]]<+> [[сестра́]]<*,*#.pr>". This is the inflection of a multiword
expression "меди́чна сестра́", which means "nurse" (literally "medical sister"), consisting
of two words: the adjective меди́чна ("medical" in the feminine singular) and the noun
сестра́ ("sister"). The specs in angle brackets follow each word to be inflected; for
example, <+> means that the preceding word should be declined as an adjective.

The code below works in terms of balanced expressions, which are bounded by delimiters
such as < > or [ ]. The intention is to allow separators such as spaces to be embedded
inside of delimiters; such embedded separators will not be parsed as separators.
For example, Ukrainian noun specs allow footnotes in brackets to be inserted inside of
angle brackets; something like "меди́чна<+> сестра́<pr.[this is a footnote]>" is legal,
as is "[[медичний|меди́чна]]<+> [[сестра́]]<pr.[this is an <i>italicized footnote</i>]>",
and the parsing code should not be confused by the embedded brackets, spaces or angle
brackets.

The parsing is done by two functions, which work in close concert:
parse_balanced_segment_run() and split_alternating_runs(). To illustrate, consider
the following:

parse_balanced_segment_run("foo<M.proper noun> bar<F>", "<", ">") =
  {"foo", "<M.proper noun>", " bar", "<F>", ""}

then

split_alternating_runs({"foo", "<M.proper noun>", " bar", "<F>", ""}, " ") =
  {{"foo", "<M.proper noun>", ""}, {"bar", "<F>", ""}}

Here, we start out with a typical inflected text spec "foo<M.proper noun> bar<F>",
call parse_balanced_segment_run() on it, and call split_alternating_runs() on the
result. The output of parse_balanced_segment_run() is a list where even-numbered
segments are bounded by the bracket-like characters passed into the function,
and odd-numbered segments consist of the surrounding text. split_alternating_runs()
is called on this, and splits *only* the odd-numbered segments, grouping all
segments between the specified character. Note that the inner lists output by
split_alternating_runs() are themselves in the same format as the output of
parse_balanced_segment_run(), with bracket-bounded text in the even-numbered segments.
Hence, such lists can be passed again to split_alternating_runs().
]=]


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

--[=[
Split a list of alternating textual runs of the format returned by
`parse_balanced_segment_run` on `splitchar`. This only splits the odd-numbered
textual runs (the portions between the balanced open/close characters).
The return value is a list of lists, where each list contains an odd number of
elements, where the even-numbered elements of the sublists are the original
balanced textual run portions. For example, if we do

parse_balanced_segment_run("foo<M.proper noun> bar<F>", "<", ">") =
  {"foo", "<M.proper noun>", " bar", "<F>", ""}

then

split_alternating_runs({"foo", "<M.proper noun>", " bar", "<F>", ""}, " ") =
  {{"foo", "<M.proper noun>", ""}, {"bar", "<F>", ""}}

Note that we did not touch the text "<M.proper noun>" even though it contains a space
in it, because it is an even-numbered element of the input list. This is intentional and
allows for embedded separators inside of brackets/parens/etc. Note also that the inner
lists in the return value are of the same form as the input list (i.e. they consist of
alternating textual runs where the even-numbered segments are balanced runs), and can in
turn be passed to split_alternating_runs().

If `preserve_splitchar` is passed in, the split character is included in the output,
as follows:

split_alternating_runs({"foo", "<M.proper noun>", " bar", "<F>", ""}, " ", true) =
  {{"foo", "<M.proper noun>", ""}, {" "}, {"bar", "<F>", ""}}

Consider what happens if the original string has multiple spaces between brackets,
and multiple sets of brackets without spaces between them.

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
	-- form insertion in the presence of inflection generating functions that may return nil,
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


-- Combine two sets of footnotes. If either is nil, just return the other, and if both are nil,
-- return nil.
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
	if not notetext then
		error("Internal error: Footnote should be surrounded by brackets: " .. note)
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
	return m_string_utilities.ucfirst(notetext) .. "."
end


-- Combine a form (either a string or a table {form = FORM, footnotes = FOOTNOTES, ...}) with footnotes.
-- Do the minimal amount of work; e.g. if FOOTNOTES is nil, just return FORM.
function export.combine_form_and_footnotes(form, footnotes)
	if type(footnotes) == "string" then
		footnotes = {footnotes}
	end
	if footnotes then
		if type(form) == "table" then
			form = m_table.shallowcopy(form)
			form.footnotes = export.combine_footnotes(form.footnotes, footnotes)
			return form
		else
			return {form = form, footnotes = footnotes}
		end
	else
		return form
	end
end


-- Older entry point. FIXME: Obsolete me.
function export.generate_form(form, footnotes)
	return export.combine_form_and_footnotes(form, footnotes)
end


-- Combine a single form (either a string or object {form = FORM, footnotes = FOOTNOTES, ...}) or a list of same
-- along with footnotes and return a list of forms where each returned form is an object
-- {form = FORM, footnotes = FOOTNOTES, ...}.
function export.convert_to_general_list_form(word_or_words, footnotes)
	if type(word_or_words) == "string" then
		return {{form = word_or_words, footnotes = footnotes}}
	elseif word_or_words.form then
		return {export.combine_form_and_footnotes(word_or_words, footnotes)}
	else
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
	lang, combine_stem_ending_tr, footnotes)
	if stems == nil or endings == nil then
		return
	end
	if type(stems) == "string" and type(endings) == "string" then
		export.insert_form(forms, slot, {form = combine_stem_ending(stems, endings), footnotes = footnotes})
	elseif type(stems) == "string" and is_table_of_strings(endings) then
		for _, ending in ipairs(endings) do
			export.insert_form(forms, slot, {form = combine_stem_ending(stems, ending), footnotes = footnotes})
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


function export.add_multiple_forms(forms, slot, sets_of_forms, combine_stem_ending,
	lang, combine_stem_ending_tr, footnotes)
	if #sets_of_forms == 0 then
		return
	elseif #sets_of_forms == 1 then
		local formset = iut.convert_to_general_list_form(sets_of_forms[1], footnotes)
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
	-- Call parse_balanced_segment_run() to keep multiword links together.
	local bracketed_runs = export.parse_balanced_segment_run(text, "[", "]")
	-- Split on space or hyphen. Use preserve_splitchar so we know whether the separator was
	-- a space or hyphen.
	local space_separated_groups = export.split_alternating_runs(bracketed_runs, "[ %-]", "preserve splitchar")

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
		local base = props.parse_indicator_spec(segments[i])
		base.before_text = before_text
		base.before_text_no_links = m_links.remove_links(base.before_text)
		base.before_text_translit = before_text_translit
		base.lemma = lemma
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
  parse_indicator_spec = FUNCTION_TO_PARSE_AN_INDICATOR_SPEC (required; takes one argument,
                           a string surrounded by angle brackets, and should return a
						   word_spec object containing properties describing the indicators
						   inside of the angle brackets),
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


-- Older entry point. FIXME: Convert all uses of this to use export.parse_inflected_text instead. 
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


local function append_forms(props, formtable, slot, forms, before_text, before_text_no_links,
	before_text_translit)
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
				local new_form = old_form.form .. before_text .. form.form
				local new_translit
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
				local new_footnotes = export.combine_footnotes(old_form.footnotes, form.footnotes)
				table.insert(ret_forms, {form=new_form, translit=new_translit,
					footnotes=new_footnotes})
			end
		end
	end
	formtable[slot] = ret_forms
end


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
	table.sort(link_indices)
	return '<sup style="color: red">' .. table.concat(link_indices, ",") .. '</sup>'
end


--[=[
Convert the forms in `forms` (a list of form objects, each of which is a table of the form
{ form = FORM, translit = MANUAL_TRANSLIT_OR_NIL, footnotes = FOOTNOTE_LIST_OR_NIL, no_accel = TRUE_TO_SUPPRESS_ACCELERATORS })
into strings. Each form list turns into a string consisting of a comma-separated list of linked forms, with accelerators
(unless `no_accel` is set in a given form). `props` is a table used in generating the strings, as follows:
{
  lang = LANG_OBJECT,
  lemmas = LEMMAS,
  slot_table = SLOT_TABLE,
  slot_list = SLOT_LIST,
  include_translit = BOOLEAN,
  canonicalize = FUNCTION_TO_CANONICALIZE_EACH_FORM,
  transform_link = FUNCTION_TO_TRANSFORM_EACH_LINK,
  join_spans = FUNCTION_TO_JOIN_SPANS,
  allow_footnote_symbols = BOOLEAN,
  footnotes = EXTRA_FOOTNOTES,
}
`lemmas` is the list of lemmas, used in the accelerators.
`slot_list` is a list of two-element lists of slots and associated accelerator inflections.
`slot_table` is a table mapping slots to associated accelerator inflections.
  (One of `slot_list` or `slot_table` must be given.)
If `include_translit` is given, transliteration is included in the generated strings.
`canonicalize` is an optional function of one argument (a form) to canonicalize each form before processing; it can return nil
  for no change.
`transform_link` is an optional function to transform a linked form prior to further processing; it is passed three arguments
  (slot, link, link_tr) and should return the transformed link (or if translit is active, it should return the transformed link
  and corresponding translit). It can return nil for no change.
`join_spans` is an optional function of three arguments (slot, orig_spans, tr_spans) where the spans in question are after
  linking and footnote processing. It should return a string (the joined spans) or nil for the default algorithm, which separately
  joins the orig_spans and tr_spans with commas and puts a newline between them.
If `allow_footnote_symbols` is given, footnote symbols attached to forms (e.g. numbers, asterisk) are separated off, placed outside
the links, and superscripted. In this case, `footnotes` should be a list of footnotes (preceded by footnote symbols, which are
superscripted). These footnotes are combined with any footnotes found in the forms and placed into `forms.footnotes`.
]=]
function export.show_forms(forms, props)
	local footnote_obj = export.create_footnote_obj()
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


--[=[
Older entry point. Same as `show_forms` but automatically sets include_translit = true in props.
]=]
function export.show_forms_with_translit(forms, lemmas, slot_table, props, footnotes, allow_footnote_symbols)
	props.lemmas = lemmas
	props.slot_table = slot_table
	props.footnotes = footnotes
	props.allow_footnote_symbols = allow_footnote_symbols
	props.include_translit = true
	return export.show_forms(forms, props)
end


return export
