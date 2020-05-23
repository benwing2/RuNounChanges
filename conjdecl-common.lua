local export = {}

local m_string_utilities = require("Module:string utilities")
local m_table = require("Module:table")

local rsplit = mw.text.split
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


-- Insert a form (an object of the form {form=FORM, footnotes=FOOTNOTES}) into a list of such
-- forms. If the form is already present, the footnotes of the existing and new form are combined.
function export.insert_form_into_list(list, form)
	-- Don't do anything if the form object or the form inside it is nil. This simplifies
	-- form insertion in the presence of declension generating functions that may return nil,
	-- such as generate_noun_vocative() and generate_noun_count_form().
	if not form or not form.form then
		return
	end
	for _, listform in ipairs(list) do
		if listform.form == form.form then
			-- Form already present; combine footnotes.
			if form.footnotes and #form.footnotes > 0 then
				if not listform.footnotes then
					listform.footnotes = {}
				end
				for _, footnote in ipairs(form.footnotes) do
					m_table.insertIfNot(listform.footnotes, footnote)
				end
			end
			return
		end
	end
	-- Form not found. Clone because we may modify the footnotes in-place.
	table.insert(list, m_table.deepcopy(form, true))
end

-- Insert a form (an object of the form {form=FORM, footnotes=FOOTNOTES}) into the given slot in
-- the given form table.
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


-- Insert a list of forms (each of which is an object of the form {form=FORM, footnotes=FOOTNOTES})
-- into the given slot in the given form table. FORMS can be nil.
function export.insert_forms(formtable, slot, forms)
	if not forms then
		return
	end
	for _, form in ipairs(forms) do
		export.insert_form(formtable, slot, form)
	end
end


-- Map a function over the form values in FORMS (a list of objects of the form
-- {form=FORM, footnotes=FOOTNOTES}). Use insert_form_into_list() to insert them into
-- the returned list in case two different forms map to the same thing.
function export.map_forms(forms, fun)
	if not forms then
		return nil
	end
	local retval = {}
	for _, form in ipairs(forms) do
		local newform = {form=fun(form.form), footnotes=form.footnotes}
		export.insert_form_into_list(retval, newform)
	end
	return retval
end


-- Map a list-returning function over the form values in FORMS (a list of objects of the form
-- {form=FORM, footnotes=FOOTNOTES}). Use insert_form_into_list() to insert them into
-- the returned list in case two different forms map to the same thing.
function export.flatmap_forms(forms, fun)
	if not forms then
		return nil
	end
	local retval = {}
	for _, form in ipairs(forms) do
		local funret = fun(form.form)
		for _, fr in ipairs(funret) do
			-- Clone the footnotes so we don't end up with two or more entries sharing
			-- the same footnote object, since the footnotes are mutated in-place.
			local newform = {form=fr, footnotes=m_table.shallowcopy(form.footnotes)}
			export.insert_form_into_list(retval, newform)
		end
	end
	return retval
end


-- Expand a given footnote (as specified by the user, including the surrounding brackets)
-- into the form to be inserted into the final generated table.
function export.expand_footnote(note)
	local notetext = rmatch(note, "^%[(.*)%]$")
	assert(notetext)
	if footnote_abbrevs[notetext] then
		notetext = footnote_abbrevs[notetext]
	else
		local split_notes = m_string_utilities.capturing_split(notetext, "<(.-)>")
		for i, split_note in ipairs(split_notes) do
			if i % 2 == 0 then
				split_notes[i] = footnote_abbrevs[split_note]
				if not split_notes[i] then
					error("Unrecognized footnote abbrev: <" .. split_note .. ">")
				end
			end
		end
		notetext = table.concat(split_notes)
	end
	return m_string_utilities.ucfirst(notetext) .. "."
end


return export
