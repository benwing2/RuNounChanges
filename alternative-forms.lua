local export = {}
local m_links = require("Module:links")
local m_languages = require("Module:languages")

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
--              This function takes three parameters: (1) `arg` (the raw argument); (2) `inline` (true if we're
--              processing an inline modifier, false otherwise); (4) `termno` (the logical index of the term being
--              processed, starting from 1).
-- * `item_dest`: The name of the key used when storing the parameter's value into the processed `term` or `termobj`
--                object. Normally the same as the parameter's name. Different in the case of "t", where we store the
--                gloss in "gloss", and "g", where we store the genders in "genders".
-- * `outer`: If true, store the value into `termobj` rather than `term`.
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
		convert = function(arg, inline, termno)
			return rsplit(arg, ",")
		end,
	},
	id = {},
	alt = {},
	q = {
		outer = true,
	},
	qq = {
		outer = true,
	},
	lit = {},
	pos = {},
}

local function get_valid_prefixes()
	local valid_prefixes = {}
	for param_mod, _ in pairs(param_mods) do
		table.insert(valid_prefixes, param_mod)
	end
	table.sort(valid_prefixes)
	return valid_prefixes
end

function export.create(frame)
	local title = mw.title.getCurrentTitle()
	local NAMESPACE = title.nsText
	local PAGENAME = title.text

	local list_with_holes = { list = true, allow_holes = true }
	local params = {
		[1] = { required = true, default = "und" },
		[2] = list_with_holes,
		["sc"] = {},
	}

	for param_mod, param_mod_spec in pairs(param_mods) do
		if not param_mod_spec.extra_specs then
			params[param_mod] = list_with_holes
		else
			local param_spec = mw.clone(list_with_holes)
			for k, v in pairs(param_mod_spec.extra_specs) do
				param_spec[k] = v
			end
			params[param_mod] = param_spec
		end
	end

	local args = require("Module:parameters").process(frame:getParent().args, params)
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
				-- Initialize the `termobj` object and the `term` object passed to full_link() in [[Module:links]].
				local termobj = {
					joiner = i > 1 and (args[2][i - 1] == ";" and "; " or ", ") or "",
					term = {
						lang = lang,
						sc = sc,
						term = term,
					},
				}

				-- Parse all the term-specific parameters and store in `term` or `termobj`.
				for param_mod, param_mod_spec in pairs(param_mods) do
					local dest = param_mod_spec.item_dest or param_mod
					local arg = args[param_mod][termno]
					if arg then
						if param_mod_spec.convert then
							arg = param_mod_spec.convert(arg, false, termno)
						end
						local obj = param_mod_spec.outer and termobj or termobj.term
						obj[dest] = arg
					end
				end

				-- Check for inline modifier, e.g. מרים<tr:Miryem>. But exclude HTML entry with <span ...>, <i ...>, <br/>
				-- or similar in it, caused by wrapping an argument in {{l|...}}, {{af|...}} or similar. Basically, all tags
				-- of the sort we parse here should consist of a less-than sign, plus letters, plus a colon, e.g. <tr:...>,
				-- so if we see a tag on the outer level that isn't in this format, we don't try to parse it. The
				-- restriction to the outer level is to allow generated HTML inside of e.g. qualifier tags, such as
				-- foo<q:similar to {{m|fr|bar}}>.
				if term and term:find("<") and not term:find("^[^<]*<[a-z]*[^a-z:]") then
					if not put then
						put = require("Module:parse utilities")
					end
					local run = put.parse_balanced_segment_run(term, "<", ">")
					local function parse_err(msg)
						-- Add 1 before first term index starts at 2.
						error(msg .. ": " .. (i + 1) .. "=" .. table.concat(run))
					end
					termobj.term.term = run[1] ~= "" and run[1] or nil

					for j = 2, #run - 1, 2 do
						if run[j + 1] ~= "" then
							parse_err("Extraneous text '" .. run[j + 1] .. "' after modifier")
						end
						local modtext = run[j]:match("^<(.*)>$")
						if not modtext then
							parse_err("Internal error: Modifier '" .. modtext .. "' isn't surrounded by angle brackets")
						end
						local prefix, arg = modtext:match("^([a-z]+):(.*)$")
						if not prefix then
							parse_err(("Modifier %s lacks a prefix, should begin with one of %s followed by a colon"):format(
								run[j], table.concat(get_valid_prefixes(), ",")))
						end
						local param_mod_spec = param_mods[prefix]
						if not param_mod_spec then
							parse_err(("Unrecognized prefix '%s' in modifier %s, should be one of %s"):format(
								prefix, run[j], table.concat(get_valid_prefixes(), ",")))
						end
						local dest = param_mod_spec.item_dest or prefix
						local obj = param_mod_spec.outer and termobj or termobj.term
						if obj[dest] then
							parse_err("Modifier '" .. prefix .. "' occurs twice, second occurrence " .. run[j])
						end
						if param_mod_spec.convert then
							arg = param_mod_spec.convert(arg, true, termno)
						end
						obj[dest] = arg
					end
				end

				-- FIXME: Either we should have a general mechanism in `param_mods` for default values, or (better) modify
				-- [[Module:links]] so it can handle nil for .genders.
				termobj.term.genders = termobj.term.genders or {}

				-- If the displayed term (from .term or .alt) has an embedded comma, use a semicolon to join the terms.
				local term_text = termobj.term.term or termobj.term.alt
				if not use_semicolon and term_text then
					if term_text:find(",", 1, true) then
						use_semicolon = true
					end
				end

				-- If the to-be-linked term is the same as the pagename, display it unlinked.
				if termobj.term.term and lang:makeEntryName(termobj.term.term) == PAGENAME then
					track("term is pagename")
					termobj.term.alt = termobj.term.alt or termobj.term.term
					termobj.term.term = nil
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

	-- Format all the items, including joiners, pre-qualifiers and post-qualifiers.
	for i, item in ipairs(items) do
		local preq_text = item.q and require("Module:qualifier").format_qualifier(item.q) .. " " or ""
		items[i] = item.joiner .. preq_text .. m_links.full_link(item.term)
			.. (item.qq and " " .. require("Module:qualifier").format_qualifier(item.qq) or "")
	end

	-- Construct the final output.
	local output = { table.concat(items) }

	-- If there are dialect or similar tags, construct them now and append to final output.
	local dialects = export.make_dialects(rawDialects, lang)
	if #dialects > 0 then
		local dialect_label
		if lang:hasTranslit() then
			dialect_label = " &ndash; ''" .. table.concat(dialects, ", ") .. "''"
		else
			dialect_label = " (''" .. table.concat(dialects, ", ") .. "'')"
		end

		-- Fixes the problem of '' being added to '' at the end of last dialect parameter
		dialect_label = mw.ustring.gsub(dialect_label, "''''", "")
		table.insert(output, dialect_label)
	end

	return table.concat(output)
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