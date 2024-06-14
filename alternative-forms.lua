local export = {}
local m_links = require("Module:links")
local m_languages = require("Module:languages")
local put_module = "Module:parse utilities"
local labels_module = "Module:labels"

local rsplit = mw.text.split

local function track(page)
	require("Module:debug/track")("alter/" .. page)
end

local param_mods = {
	alt = {},
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
	pos = {},
	lit = {},
	id = {},
	sc = {
		separate_no_index = true,
		extra_specs = {type = "script"},
	},
}

--[==[
Main function for displaying alternative forms. Extracted out from the template-callable function so this can be
called by other modules (in particular, [[Module:descendants tree]]). `show_labels_after_terms` (used by
[[Module:descendants tree]]) causes labels to be placed in brackets after each term rather than at the end using an
em-dash. `allow_self_link` causes terms the same as the pagename to be shown normally; otherwise they are displayed
unlinked.
]==]
function export.display_alternative_forms(parent_args, pagename, show_labels_after_terms, allow_self_link)
	local params = {
		[1] = {required = true, type = "language", etym_lang = true, default = "en"},
		[2] = {list = true, allow_holes = true},
		["sc"] = {type = "script"},
	}

	local m_param_utils = require(parameter_utilities_module)
	m_param_utils.augment_param_mods_with_pron_qualifiers(param_mods)
	m_param_utils.augment_params_with_modifiers(params, param_mods)

	local args = require("Module:parameters").process(parent_args, params)

	local raw_labels = {}
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
		-- this term parameter and any others contain labels.
		if i > 1 and not prev then
			raw_labels = {unpack(args[2], i, maxmaxindex)}
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

	-- The template must have either items or labels.
	if items[1] == nil and raw_labels[1] == nil then error("No terms found!") end

	-- If any term had an embedded comma, override all joiners to be semicolons.
	if use_semicolon then
		for i, item in ipairs(items) do
			if i > 1 then
				item.joiner = "; "
			end
		end
	end

	local labels
	if #raw_labels > 0 then
		labels = require(labels_module).get_label_list_info(raw_labels, lang, "nocat")
	end

	-- Format all the items, including joiners, pre-qualifiers, post-qualifiers and (if `show_labels_after_terms` is
	-- given) labels.
	for i, item in ipairs(items) do
		items[i] = item.joiner .. m_links.full_link(item, nil, allow_self_link, "show qualifiers")
		-- Temporarily turn this off till we can fix it correctly.
		if false then -- show_labels_after_terms and labelsthen
			items[i] = items[i] .. " " .. require(labels_module).format_processed_labels {
				labels = labels, lang = lang, open = "[", close = "]"
			}
		end
	end

	-- Construct the final output.
	if not show_labels_after_terms then
		-- If there are labels, construct them now and append to final output.
		if labels then
			local formatted_labels
			if lang:hasTranslit() then
				formatted_labels = " &mdash; " .. require(labels_module).format_processed_labels {
					labels = labels, lang = lang
				}
			else
				formatted_labels = " " .. require(labels_module).format_processed_labels {
					labels = labels, lang = lang, open = "(", close = ")"
				}
			end

			table.insert(items, formatted_labels)
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
