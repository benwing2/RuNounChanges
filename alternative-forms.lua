local export = {}
local m_links = require("Module:links")
local m_languages = require("Module:languages")
local put_module = "Module:parse utilities"
local labels_module = "Module:labels"

local rsplit = mw.text.split

local function track(page)
	require("Module:debug/track")("alter/" .. page)
end

--[==[
Return a list of objects corresponding to the raw label tags in `raw_tags`, where "label tags" are the tags after two
vertical bars in {{tl|alt}}. Each object is of the format returned by `get_label_info` in [[Module:labels]], as the
separate dialectal data modules have been removed.

NOTE: This function no longer does anything other than call {get_label_info()} in [[Module:labels]].
]==]
function export.get_tag_info(raw_tags, lang)
	local tags = {}

	for _, tag in ipairs(raw_tags) do
		-- Pass in nocat to avoid extra work, since we won't use the categories.
		local display = require(labels_module).get_label_info { label = tag, lang = lang, nocat = true }
		table.insert(tags, display)
	end

	return tags
end

--[==[
Concatenate the tag objects specified in `tags` (the return value of `get_tag_info`). The tags are normally separated
by comma + space, but the `omit_preComma`, `omit_postComma`, `omit_preSpace` and `omit_postSpace` flags in the label
data are respected, just as {{tl|lb}} does. The resulting string is tagged with CSS class {ib-content} (as with
qualifiers), and the commas are tagged with CSS class {ib-comma} (again, as with qualifiers). `open` and `close` are
optional open and close brackets (in the general sense; e.g. they may be parentheses, square brackets, etc.) to prepend
and append, respectively, to the concatenated result. If specified, the brackets will be tagged with CSS class
{ib-brac} (as with qualifiers). If `no_outer_cs_class` is passed in, don't surround the concatenated result with a span
specifying the {ib-content} CSS class (commas separating labels will still be tagged with {ib-comma}); this allows the
caller to pass the result to {format_qualifier()} in [[Module:qualifier]].

'''WARNING''': This destructively modifies the `tags` list.
]==]
function export.concatenate_tags(tags, open, close, no_outer_css_class)
	local omit_preComma = false
	local omit_postComma = true
	local omit_preSpace = false
	local omit_postSpace = true
	
	for i, tag in ipairs(tags) do
		omit_preComma = omit_postComma
		omit_postComma = false
		omit_preSpace = omit_postSpace
		omit_postSpace = false

		local to_insert = tag.label
		local labdata = tag.data
		if labdata then
			omit_preComma = omit_preComma or labdata.omit_preComma
			omit_postComma = labdata.omit_postComma
			omit_preSpace = omit_preSpace or labdata.omit_preSpace
			omit_postSpace = labdata.omit_postSpace
		end

		if to_insert ~= "" then
			to_insert =
				(omit_preComma and "" or '<span class="ib-comma">,</span>') ..
				(omit_preSpace and "" or "&#32;") ..
				to_insert
		end
		tags[i] = to_insert
	end
	
	local ret = table.concat(tags, "")
	if not no_outer_css_class then
		ret = "<span class=\"ib-content\">" .. ret .. "</span>"
	end
	if open then
		ret = "<span class=\"ib-brac\">" .. open .. "</span>" .. ret .. "<span class=\"ib-brac\">" .. close .. "</span>"
	end
	return ret
end

-- Per-param modifiers, which can be specified either as separate parameters (e.g. t2=, pos3=) or as inline modifiers
-- <t:...>, <pos:...>, etc. The key is the name fo the parameter (e.g. "t", "pos") and the value is a table with
-- elements as follows:
-- * `extra_specs`: An optional table of extra key-value pairs to add to the spec used for parsing the parameter
--                  when specified as a separate parameter (e.g. {type = "boolean"} for a Boolean parameter, or
--                  {alias_of = "t"} for the "gloss" parameter, which is aliased to "t"), on top of the default, which
--                  is {list = true, allow_holes = true}.
-- * `convert`: An optional function to convert the raw argument into the form passed to [[Module:links]].
--              This function takes two parameters: (1) `arg` (the raw argument); (2) `parse_err` (a function used to
--              throw an error in case of a parse error).
-- * `item_dest`: The name of the key used when storing the parameter's value into the processed `term` or `termobj`
--                object. Normally the same as the parameter's name. Different in the case of "t", where we store the
--                gloss in "gloss", and "g", where we store the genders in "genders".
local param_mods = {
	t = {
		-- We need to store the t1=/t2= param and the <t:...> inline modifier into the "gloss" key of the parsed term,
		-- because that is what [[Module:links]] expects.
		item_dest = "gloss",
	},
	gloss = {
		-- The `extra_specs` handles the fact that "gloss" is an alias of "t".
		extra_specs = {alias_of = "t"},
	},
	tr = {},
	ts = {},
	g = {
		-- We need to store the g1=/g2= param and the <g:...> inline modifier into the "genders" key of the parsed term,
		-- because that is what [[Module:links]] expects.
		item_dest = "genders",
		convert = function(arg, parse_err)
			return rsplit(arg, ",")
		end,
	},
	id = {},
	alt = {},
	q = {},
	qq = {},
	lit = {},
	pos = {},
	sc = {
		-- sc1=, sc2=, ... are different from sc=; the former apply to individual arguments while the latter applies to
		-- all arguments. To handle this in separate parameters, we need to set the key in the `params` object passed to
		-- [[Module:parameters]] to something else (in this case "partsc") and set `list = "sc"` and
		-- `require_index = true` in the value of the `params` object. This causes [[Module:parameters]] to fetch
		-- parameters named sc1=, sc2= etc. but store them into "partsc", while sc= is stored into "sc".
		param_key = "partsc",
		require_index = true,
		extra_specs = {list = "sc"},
		convert = function(arg, parse_err)
			return require("Module:scripts").getByCode(arg, parse_err)
		end,
	},
}

local function get_valid_prefixes()
	local valid_prefixes = {}
	for param_mod, _ in pairs(param_mods) do
		table.insert(valid_prefixes, param_mod)
	end
	table.sort(valid_prefixes)
	return valid_prefixes
end

--[==[
Main function for displaying alternative forms. Extracted out from the template-callable function so this can be
called by other modules (in particular, [[Module:descendants tree]]). `show_tags_after_terms` (used by
[[Module:descendants tree]]) causes tags to be placed in brackets after each term rather than at the end using an
em-dash. `allow_self_link` causes terms the same as the pagename to be shown normally; otherwise they are displayed
unlinked.
]==]
function export.display_alternative_forms(parent_args, pagename, show_tags_after_terms, allow_self_link)
	local list_with_holes = { list = true, allow_holes = true }
	local params = {
		[1] = { required = true, default = "und" },
		[2] = list_with_holes,
		["sc"] = {},
	}

	-- Add parameters for each term modifier.
	for param_mod, param_mod_spec in pairs(param_mods) do
		local param_key = param_mod_spec.param_key or param_mod
		if not param_mod_spec.extra_specs then
			params[param_key] = list_with_holes
		else
			local param_spec = mw.clone(list_with_holes)
			for k, v in pairs(param_mod_spec.extra_specs) do
				param_spec[k] = v
			end
			if param_mod_spec.require_index then
				param_spec.require_index = true
			end
			params[param_key] = param_spec
		end
	end

	local args = require("Module:parameters").process(parent_args, params)
	local lang = m_languages.getByCode(args[1], 1)
	local sc = args["sc"] and require("Module:scripts").getByCode(args["sc"], "sc") or nil

	local raw_tags = {}
	local items = {}

	-- Find the maximum index among any of the list parameters.
	local maxmaxindex = 0
	for k, v in pairs(args) do
		if type(v) == "table" and v.maxindex and v.maxindex > maxmaxindex then
			maxmaxindex = v.maxindex
		end
	end

	if maxmaxindex == 0 then
		error("Either a positional parameter, alt parameter, id parameter, tr parameter, or ts parameter is required.")
	end

	-- Is set to true if there is a term (entry link, alt text, transliteration, transcription) at the previous index.
	local prev = false
	local use_semicolon = false
	local put

	local termno = 0
	for i = 1, maxmaxindex do
		-- If the previous term parameter was empty and we're not on the first term parameter,
		-- this term parameter and any others contain tags (dialect or other labels).
		if i > 1 and not prev then
			raw_tags = {unpack(args[2], i, maxmaxindex)}
			break
		end

		local term = args[2][i]

		if term ~= ";" then
			termno = termno + 1

			-- Compute whether any of the separate indexed params exist for this index.
			local any_param_at_index = term ~= nil
			for k, v in pairs(args) do
				-- Look for named list parameters. We check:
				-- (1) key is a string (excludes 2=, a numbered rather than named list param, because it needs to
				--     be indexed using `i` instead of `termno`);
				-- (2) value is a table (1= and sc= are converted into strings or nil rather than lists);
				-- (3) the value has an entry at index `termno` (the current logical index).
				if type(k) == "string" and type(v) == "table" and v[termno] then
					any_param_at_index = true
					-- Tracking for use of any specific indexed parameter. FIXME: Do we still need this?
					-- FIXME: If we don't need it, remove the call to track() below, add `break` below, and wrap
					-- the `for` loop in `if not any_param_at_index then` for efficiency purposes.
					-- break
					-- [[Special:WhatLinksHere/Wiktionary:Tracking/alter/alt]]
					-- [[Special:WhatLinksHere/Wiktionary:Tracking/alter/id]]
					-- [[Special:WhatLinksHere/Wiktionary:Tracking/alter/tr]]
					-- [etc.]
					track(k)
				end
			end

			-- If any of the params used for formatting this term is present, create a term and add it to the list.
			if any_param_at_index then
				-- Initialize the `termobj` object passed to full_link() in [[Module:links]].
				local termobj = {
					joiner = i > 1 and (args[2][i - 1] == ";" and "; " or ", ") or "",
					lang = lang,
					sc = sc,
					term = term,
				}

				-- Parse all the term-specific parameters and store in `termobj`.
				for param_mod, param_mod_spec in pairs(param_mods) do
					local dest = param_mod_spec.item_dest or param_mod
					local param_key = param_mod_spec.param_key or param_mod
					local arg = args[param_key] and args[param_key][termno]
					if arg then
						if param_mod_spec.convert then
							local function parse_err(msg, stack_frames_to_ignore)
								error(("%s: %s%s=%s"):format(msg, param_mod,
									(termno > 1 or param_mod_spec.require_index) and termno or "", arg),
									stack_frames_to_ignore
								)
							end
							arg = param_mod_spec.convert(arg, parse_err)
						end
						termobj[dest] = arg
					end
				end

				-- Check for inline modifier, e.g. מרים<tr:Miryem>. But exclude HTML entry with <span ...>, <i ...>,
				-- <br/> or similar in it, caused by wrapping an argument in {{l|...}}, {{af|...}} or similar.
				-- Basically, all tags of the sort we parse here should consist of a less-than sign, plus letters, plus
				-- a colon, e.g. <tr:...>, so if we see a tag on the outer level that isn't in this format, we don't
				-- try to parse it. The restriction to the outer level is to allow generated HTML inside of e.g.
				-- qualifier tags, such as foo<q:similar to {{m|fr|bar}}>.
				if term and term:find("<") and not term:find("^[^<]*<[a-z]*[^a-z:]") then
					local function generate_obj(term)
						termobj.term = term ~= "" and term or nil
						return termobj
					end

					require(put_module).parse_inline_modifiers(term, {
						-- Add 1 because first term index starts at 2.
						paramname = i + 1,
						param_mods = param_mods,
						generate_obj = generate_obj,
					})
				end

				-- If the displayed term (from .term or .alt) has an embedded comma, use a semicolon to join the terms.
				local term_text = termobj.term or termobj.alt
				if not use_semicolon and term_text then
					if term_text:find(",", 1, true) then
						use_semicolon = true
					end
				end

				-- If the to-be-linked term is the same as the pagename, display it unlinked.
				if not allow_self_link and termobj.term and (lang:makeEntryName(termobj.term)) == pagename then
					track("term is pagename")
					termobj.alt = termobj.alt or termobj.term
					termobj.term = nil
				end

				table.insert(items, termobj)
				prev = true
			else
				if math.max(args.alt.maxindex, args.id.maxindex, args.tr.maxindex, args.ts.maxindex) >= termno then
					track("too few terms")
				end

				prev = false
			end
		end
	end

	-- The template must have either items or tags.
	if items[1] == nil and raw_tags[1] == nil then error("No terms found!") end

	-- If any term had an embedded comma, override all joiners to be semicolons.
	if use_semicolon then
		for i, item in ipairs(items) do
			if i > 1 then
				item.joiner = "; "
			end
		end
	end

	local tags = export.get_tag_info(raw_tags, lang)

	-- Format all the items, including joiners, pre-qualifiers, post-qualifiers and (if `show_tags_after_terms` is
	-- given) tags.
	for i, item in ipairs(items) do
		items[i] = item.joiner .. m_links.full_link(item, nil, allow_self_link, "show qualifiers")
		-- Temporarily turn this off till we can fix it correctly.
		if false then -- show_tags_after_terms and #tags > 0 then
			items[i] = items[i] .. " " .. export.concatenate_tags(tags, "[", "]")
		end
	end

	-- Construct the final output.
	if not show_tags_after_terms then
		-- If there are tags, construct them now and append to final output.
		if #tags > 0 then
			local tag_label
			if lang:hasTranslit() then
				tag_label = " &mdash; " .. export.concatenate_tags(tags)
			else
				tag_label = " " .. export.concatenate_tags(tags, "(", ")")
			end

			table.insert(items, tag_label)
		end
	end

	return table.concat(items)
end

--[==[
Template-callable function for displaying alternative forms.
]==]
function export.create(frame)
	local parent_args = frame:getParent().args
	local title = mw.title.getCurrentTitle()
	local PAGENAME = title.text
	return export.display_alternative_forms(parent_args, title)
end

return export
