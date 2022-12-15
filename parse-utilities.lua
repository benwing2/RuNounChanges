local export = {}

local m_string_utilities = require("Module:string utilities")

local rsplit = mw.text.split
local u = mw.ustring.char
local rsubn = mw.ustring.gsub

-- version of rsubn() that discards all but the first return value
local function rsub(term, foo, bar)
	local retval = rsubn(term, foo, bar)
	return retval
end


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
	return m_string_utilities.capturing_split(segment_run, "(%b" .. open .. close .. ")")
end

-- The following is an equivalent, older implementation that does not use %b (written before I was aware of %b).
--[=[
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
]=]


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
function export.split_alternating_runs(segment_runs, splitchar, preserve_splitchar, frob)
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


function export.strip_spaces(text)
	return rsub(text, "^%s*(.-)%s*$", "%1")
end


-- Apply an arbitrary function `frob` to the "raw-text" segments in a split run set (the output of
-- split_alternating_runs()). We leave alone stuff within balanced delimiters (footnotes, inflection specs and the
-- like), as well as splitchars themselves if present. `preserve_splitchar` indicates whether splitchars are present
-- in the split run set. `frob` is a function of one argument (the string to frob) and should return one argument (the
-- frobbed string). We operate by only frobbing odd-numbered segments, and only in odd-numbered runs if
-- preserve_splitchar is given.
function export.frob_raw_text_alternating_runs(split_run_set, frob, preserve_splitchar)
	for i, run in ipairs(split_run_set) do
		if not preserve_splitchar or i % 2 == 1 then
			for j, segment in ipairs(run) do
				if j % 2 == 1 then
					run[j] = frob(segment)
				end
			end
		end
	end
end


-- Like split_alternating_runs() but applies an arbitrary function `frob` to "raw-text" segments in the result (i.e.
-- not stuff within balanced delimiters such as footnotes and inflection specs, and not splitchars if present). `frob`
-- is a function of one argument (the string to frob) and should return one argument (the frobbed string).
function export.split_alternating_runs_and_frob_raw_text(run, splitchar, frob, preserve_splitchar)
	local split_runs = export.split_alternating_runs(run, splitchar, preserve_splitchar)
	export.frob_raw_text_alternating_runs(split_runs, frob, preserve_splitchar)
	return split_runs
end


-- Split the non-modifier parts of an alternating run (after parse_balanced_segment_run() is called) on comma, but not
-- on comma+whitespace.
function export.split_alternating_runs_on_comma(run, tempcomma)
	tempcomma = tempcomma or u(0xFFF0)

	-- First replace comma with a temporary character in comma+whitespace sequences.
	local need_tempcomma_undo = false
	for i, seg in ipairs(run) do
		if i % 2 == 1 then
			if seg:find(",%s") then
				run[i] = run[i]:gsub(",(%s)", tempcomma .. "%1")
				need_tempcomma_undo = true
			end
		end
	end

	if need_tempcomma_undo then
		function unescape_comma_whitespace(val)
			-- Undo the replacement of comma with a temporary char.
			val = val:gsub(tempcomma, ",") -- assign to temp to discard second retval
			return val
		end
		return export.split_alternating_runs_and_frob_raw_text(run, ",", unescape_comma_whitespace)
	else
		return export.split_alternating_runs(run, ",")
	end
end


return export
