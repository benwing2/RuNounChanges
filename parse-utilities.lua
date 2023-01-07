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
specific implementation. A real-world example is as follows: "[[медичний|меди́чна]]<+> [[сестра́]]<*,*#.pr>". This is the
inflection of a multiword expression "меди́чна сестра́", which means "nurse" in Ukrainian (literally "medical sister"),
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


-- Split text on comma, but not on comma+whitespace. This is similar to `mw.text.split(text, ",")` but will not split
-- on commas directly followed by whitespace, to handle embedded commas in terms (which are almost always followed by
-- a space). `tempcomma` is the Unicode character to temporarily use when doing the splitting; normally U+FFF0, but
-- you can specify a different character if you use U+FFF0 for some internal purpose.
function export.split_on_comma(text, tempcomma)
	tempcomma = tempcomma or u(0xFFF0)

	-- First replace comma with a temporary character in comma+whitespace sequences.
	local need_tempcomma_undo = false
	if val:find(",%s") then
		val = val:gsub(",(%s)", tempcomma .. "%1")
		need_tempcomma_undo = true
	end

	-- Now split on comma.
	val = rsplit(val, ",")

	-- Now undo the replacement of comma with a temporary char if needed.
	if need_tempcomma_undo then
		for i, v in ipairs(val) do
			val[i] = v:gsub(tempcomma, ",")
		end
	end

	return val
end


-- Split the non-modifier parts of an alternating run (after parse_balanced_segment_run() is called) on comma, but not
-- on comma+whitespace. See `split_on_comma()` above for more information and the meaning of `tempcomma`.
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


-- Ensure that brackets display literally in error messages. Replacing with equivalent HTML escapes doesn't work
-- because they are displayed literally; but inserting a Unicode word-joiner symbol works.
function export.escape_brackets(term)
	term = term:gsub("%[%[", "[" .. u(0x2060) .. "[")
	return term
end


-- Parse a term that may have a language code preceding it (e.g. 'la:minūtia' or 'grc:[[σκῶρ|σκατός]]'). Return
-- two arguments, the term minus the language code and the language object corresponding to the language code.
-- Etymology-only languages are allowed. This function also correctly handles Wikipedia prefixes (e.g. 'w:Abatemarco'
-- or 'w:it:Colle Val d'Elsa') and converts them into two-part links, with the display form not including the Wikipedia
-- prefix. `parse_err` should be a function of one or two arguments to display an error (the second argument is the
-- number of stack frames to ignore when calling error(); if you declare your error function with only one argument,
-- things will still work fine).
function export.parse_term_with_lang(term, parse_err)
	-- Parse off an initial language code (e.g. 'la:minūtia' or 'grc:[[σκῶρ|σκατός]]'). Also handle Wikipedia prefixes
	-- ('w:Abatemarco' or 'w:it:Colle Val d'Elsa').
	local termlang, actual_term = term:match("^([A-Za-z0-9._-]+):(.*)$")
	if termlang == "w" then
		local foreign_wikipedia, foreign_term = actual_term:match("^([A-Za-z0-9._-]+):(.*)$")
		if foreign_wikipedia then
			termlang = termlang .. ":" .. foreign_wikipedia
			actual_term = foreign_term
		end
		if actual_term:find("[%[%]]") then
			parse_err("Cannot have brackets following a Wikipedia (w:...) link; place the Wikipedia link inside the brackets")
		end
		term = ("[[%s:%s|%s]]"):format(termlang, actual_term, actual_term)
		termlang = nil
	elseif termlang then
		termlang = require("Module:languages").getByCode(termlang, parse_err, "allow etym")
		term = actual_term
	end

	return term, termlang
end


--[=[
Parse a term that may have inline modifiers attached (e.g. 'rifiuti<q:plural-only>' or
'rinfusa<t:bulk cargo><lit:resupplying><qq:more common in the plural {{m|it|rinfuse}}>').
  * `arg` is the term to parse.
  * `paramname` is the name of the parameter where `arg` comes from, or nil if this isn't available (it is used only
     in error messages).
  * `param_mods` is a table describing the allowed inline modifiers (see below).
  * `generate_obj` is a function of one or two arguments that should parse the argument minus the inline modifiers
     and return a corresponding parsed  object (into which the inline modifiers will be rewritten). If declared with
     one argument, that will be the raw value to parse; if declared with two arguments, the second argument will be
     the `parse_err` function (see below).
  * `parse_err` is an optional function of one argument (an error message) and should display the error message,
    along with any desired contextual text (e.g. the argument name and value that triggered the error). If omitted,
    a default function will be generated which displays the error along with the original value of `arg` (passed
    through escape_brackets() above to ensure that bracketed text is displayed literally).
  * `split_on_comma` is an optional Boolean argument. If true, `arg` can consist of multiple comma-separated terms,
    each of which may be followed by inline modifiers, and the return value will be a list of parsed objects instead
    of a single object. Note that splitting on commas will not happen if there is whitespace directly following the
    comma, to allow for terms with embedded commas in them. The algorithm to split on commas is sensitive to inline
    modifier syntax and will not be confused by commas inside of inline modifiers, which do not trigger splitting
    (whether or not followed by whitespace).

`param_mods` is a table describing allowed modifiers. The keys of the table are modifier prefixes and the values are
tables describing how to parse and store the associated modifier values. Here is a typical example:

local param_mods = {
	t = {
		item_dest = "gloss",
	},
	gloss = {},
	pos = {},
	alt = {},
	lit = {},
	id = {},
	g = {
		item_dest = "genders",
		convert = function(arg)
			return rsplit(arg, ",")
		end,
	},
}

In the table values:
* `item_dest` specifies the destination key to store the object into (if not the same as the modifier key itself).
* `convert` is a function of one or two arguments (the modifier value and optionally the `parse_err` function as passed
  in or generated), and should parse and convert the value into the appropriate object. If omitted, the string value is
  stored unchanged.
* `store` describes how to store the converted modifier value into the parsed object. If omitted, the converted value
  is simply written into the parsed object under the appropriate key (but an error is generated if the key already has
  a value). If `store` == "insert", the converted value is appended to the key's value using table.insert();
  if the key has no value, it is first converted to an empty list. `store` == "insertIfNot" is similar but appends the
  value using insertIfNot() in [[Module:table]]. If `store == "insert-flattened", the converted value is assumed to be
  a list and the objects are appended one-by-one into the key's existing value using table.insert(). `store` ==
  "insertIfNot-flattened" is similar but appends using insertIfNot() in [[Module:table]]. WARNING: When using
  "insert-flattened" and "insertIfNot-flattened", if there is no existing value for the key, the converted value is
  just stored directly. This means that future appends will side-effect that value, so make sure that the return
  value of the conversion function for this key generates a fresh list each time.
]=]
function export.parse_inline_modifiers(arg, paramname, param_mods, generate_obj, parse_err, split_on_comma)
	local function get_valid_prefixes()
		local valid_prefixes = {}
		for param_mod, _ in pairs(param_mods) do
			table.insert(valid_prefixes, param_mod)
		end
		table.sort(valid_prefixes)
		return valid_prefixes
	end

	local function get_arg_gloss()
		if paramname then
			return ("%s=%s"):format(paramname, arg)
		else
			return arg
		end
	end

	if not parse_err then
		parse_err = function(msg, stack_frames_to_ignore)
			error(export.escape_brackets(("%s: %s"):format(msg, get_arg_gloss())), stack_frames_to_ignore)
		end
	end

	local segments = export.parse_balanced_segment_run(arg, "<", ">")

	local function parse_group(group)
		local dest_obj = generate_obj(group[1], parse_err)
		for k = 2, #group - 1, 2 do
			if group[k + 1] ~= "" then
				parse_err("Extraneous text '" .. group[k + 1] .. "' after modifier")
			end
			local modtext = group[k]:match("^<(.*)>$")
			if not modtext then
				parse_err("Internal error: Modifier '" .. group[k] .. "' isn't surrounded by angle brackets")
			end
			local prefix, val = modtext:match("^([a-zA-Z0-9+_-]+):(.*)$")
			if not prefix then
				local valid_prefixes = get_valid_prefixes()
				for i, valid_prefix in ipairs(valid_prefixes) do
					valid_prefixes[i] = "'" .. valid_prefix .. ":'"
				end
				parse_err("Modifier " .. group[k] .. " lacks a prefix, should begin with one of " ..
					require("Module:table").serialCommaJoin(valid_prefixes))
			end
			if param_mods[prefix] then
				local function prefix_parse_err(msg, stack_frames_to_ignore)
					error(export.escape_brackets(("%s: modifier prefix '%s' in %s"):format(msg, prefix, get_arg_gloss())), stack_frames_to_ignore)
				end
				local key = param_mods[prefix].item_dest or prefix
				local convert = param_mods[prefix].convert
				local converted
				if convert then
					converted = convert(val, prefix_parse_err)
				else
					converted = val
				end
				local store = param_mods[prefix].store
				if not store then
					if dest_obj[key] then
						parse_err("Modifier '" .. prefix .. "' occurs twice, second occurrence " .. group[k])
					end
					dest_obj[key] = converted
				elseif store == "insert" then
					if not dest_obj[key] then
						dest_obj[key] = {converted}
					else
						table.insert(dest_obj[key], converted)
					end
				elseif store == "insertIfNot" then
					if not dest_obj[key] then
						dest_obj[key] = {converted}
					else
						require("Module:table").insertIfNot(dest_obj[key], converted)
					end
				elseif store == "insert-flattened" then
					if not dest_obj[key] then
						dest_obj[key] = obj
					else
						for _, obj in ipairs(converted) do
							table.insert(dest_obj[key], obj)
						end
					end
				elseif store == "insertIfNot-flattened" then
					if not dest_obj[key] then
						dest_obj[key] = obj
					else
						for _, obj in ipairs(converted) do
							require("Module:table").insertIfNot(dest_obj[key], obj)
						end
					end
				else
					store(dest_obj, key, converted, prefix_parse_err)
				end
			else
				local valid_prefixes = get_valid_prefixes()
				for i, valid_prefix in ipairs(valid_prefixes) do
					valid_prefixes[i] = "'" .. valid_prefix .. "'"
				end
				parse_err("Unrecognized prefix '" .. prefix .. "' in modifier " .. group[k]
					.. ", should be " .. require("Module:table").serialCommaJoin(valid_prefixes))
			end
		end
		return dest_obj
	end

	if not split_on_comma then
		return parse_group(segments)
	else
		local retval = {}
		local comma_separated_groups =
			split_on_comma and put.split_alternating_runs_on_comma(segments) or {segments}
		for j, group in ipairs(comma_separated_groups) do
			table.insert(retval, dest_obj)
		end
		return retval
	end
end


return export
