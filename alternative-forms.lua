local export = {}
local m_links = require("Module:links")
local m_languages = require("Module:languages")
local put_module = "Module:parse utilities"

local rsplit = mw.text.split

-- See if the language's dialectal data module has a label corresponding to the dialect argument.
function export.getLabel(dialect, dialect_data)
	local data = dialect_data[dialect] or ( dialect_data.labels and dialect_data.labels[dialect] )
	local alias_of = ( dialect_data.aliases and dialect_data.aliases[dialect] )
	if not data then
		if alias_of then
			data = dialect_data[alias_of] or ( dialect_data.labels and dialect_data.labels[alias_of] )
		end
	end
	if data then
		local display = data.display or dialect
		if data.appendix then
			dialect = '[[Appendix:' .. data.appendix .. '|' .. display .. ']]'
		else
			local target = data.link
			dialect = target and '[[w:'.. target .. '|' .. display .. ']]' or display
		end
	end
	return dialect
end

function export.make_dialects(raw, lang)
	local dialect_page = 'Module:'.. lang:getCode() ..':Dialects'
	local dialect_info
	if raw[1] then
		dialect_info = mw.title.new(dialect_page).exists and mw.loadData(dialect_page) or false
	end

	local dialects = {}

	for _, dialect in ipairs(raw) do
		table.insert(dialects, dialect_info and export.getLabel(dialect, dialect_info) or dialect)
	end

	return dialects
end

local function track(page)
	require("Module:debug/track")("alter/" .. page)
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

-- Main function for displaying alternative forms. Extracted out from the template-callable function so this can be
-- called by other modules (in particular, [[Module:descendants tree]]). `show_dialect_tags_after_terms` (used by
-- [[Module:descendants tree]]) causes dialect tags to be placed in brackets after each term rather than at the end
-- using an em-dash. `allow_self_link` causes terms the same as the pagename to be shown normally; otherwise they are
-- displayed unlinked.
function export.display_alternative_forms(parent_args, pagename, show_dialect_tags_after_terms, allow_self_link)
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

	local rawDialects = {}
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
		-- this term parameter and any others contain dialect or other labels.
		if i > 1 and not prev then
			rawDialects = {unpack(args[2], i, maxmaxindex)}
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
					-- [[Special:WhatLinksHere/Template:tracking/alter/alt]]
					-- [[Special:WhatLinksHere/Template:tracking/alter/id]]
					-- [[Special:WhatLinksHere/Template:tracking/alter/tr]]
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
					local arg = args[param_key][termno]
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

	-- The template must have either items or dialect labels.
	if items[1] == nil and rawDialects[1] == nil then error("No terms found!") end

	-- If any term had an embedded comma, override all joiners to be semicolons.
	if use_semicolon then
		for i, item in ipairs(items) do
			if i > 1 then
				item.joiner = "; "
			end
		end
	end

	local dialects = export.make_dialects(rawDialects, lang)

	-- Format all the items, including joiners, pre-qualifiers, post-qualifiers and (if `show_dialect_tags_after_terms`
	-- is given) dialect tags.
	for i, item in ipairs(items) do
		items[i] = item.joiner .. m_links.full_link(item, nil, allow_self_link, "show qualifiers")
		-- Temporarily turn this off till we can fix it correctly.
		if false then -- show_dialect_tags_after_terms and #dialects > 0 then
			items[i] = items[i] .. " " .. require("Module:qualifier").format_qualifier(dialects, "[", "]")
		end
	end

	-- Construct the final output.
	if not show_dialect_tags_after_terms then
		-- If there are dialect or similar tags, construct them now and append to final output.
		if #dialects > 0 then
			local dialect_label
			if lang:hasTranslit() then
				dialect_label = " &mdash; ''" .. table.concat(dialects, ", ") .. "''"
			else
				dialect_label = " (''" .. table.concat(dialects, ", ") .. "'')"
			end

			-- Fixes the problem of '' being added to '' at the end of last dialect parameter
			dialect_label = mw.ustring.gsub(dialect_label, "''''", "")
			table.insert(items, dialect_label)
		end
	end

	return table.concat(items)
end

-- Template-callable function for displaying alternative forms.
function export.create(frame)
	local parent_args = frame:getParent().args
	local title = mw.title.getCurrentTitle()
	local PAGENAME = title.text
	return export.display_alternative_forms(parent_args, title)
end

function export.categorize(frame)
	local content = {}

	local title = mw.title.getCurrentTitle()
	local titletext = title.text
	local namespace = title.nsText
	local subpagename = title.subpageText

	-- subpagename ~= titletext if it is a documentation page
	if namespace == "Module" and subpagename == titletext then
		local langCode = mw.ustring.match(titletext, "^([^:]+):")
		local lang = m_languages.getByCode(langCode) or error('"' .. langCode .. '" is not a valid language code.')
		content.canonicalName = lang:getCanonicalName()

		local categories =
[=[
[[Category:<canonicalName> modules|dialects]]
[[Category:Dialectal data modules|<canonicalName>]]
]=]

		categories = mw.ustring.gsub(categories, "<([^>]+)>", content)
		return categories
	end
end

return export
