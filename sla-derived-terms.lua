--[=[
	This module implements {{*-derived terms}} for various Slavic languages, which creates a list or table of
	verbs derived from a base verb.

	Potentially this supports all Slavic languages, but in practice additional work is needed for Ukrainian and
	Belarusian to properly handle stressed prefixes (particularly Belarusian вы́-, Ukrainian ви́-). To add this
	support, you need to provide the appropriate language-specific version of paste_prefix_suffix(); see
	ru_paste_prefix_suffix() for the Russian version, which provides a starting point. (Handling Ukrainian and
	Belarusian should be easier because these languages don't normally support or need manual transliteration.)

	Author: Benwing2; rewritten from initial version by Erutuon.

	FIXME:
	1. Brackets. [DONE]
	2. Period as prefix value (needed?). [DONE]
	3. Properly propagate all modifiers. [DONE]
	4. Consider adding default aspect to table if term occurs as both perfective and imperfective.
]=]

local export = {}

local m_table = require("Module:table")
local m_links = require("Module:links")

local rsplit = mw.text.split
local rsubn = mw.ustring.gsub

-- version of rsubn() that discards all but the first return value
local function rsub(term, foo, bar)
	local retval = rsubn(term, foo, bar)
	return retval
end

local function transliterate(lang, term)
	return lang:transliterate(m_links.remove_links(term))
end

local function default_paste_prefix_suffix(lang, prefix, prefix_tr, suffix, suffix_tr, aspect)
	if not prefix_tr and not suffix_tr then
		return prefix .. suffix, nil
	end
	prefix_tr = prefix_tr or transliterate(lang, prefix)
	suffix_tr = suffix_tr or transliterate(lang, suffix)
	return prefix .. suffix, prefix_tr .. suffix_tr
end

local function ru_paste_prefix_suffix(lang, prefix, prefix_tr, suffix, suffix_tr, aspect)
	local com = require("Module:ru-common")
	prefix_tr = prefix_tr and com.decompose(prefix_tr) or nil
	suffix_tr = suffix_tr and com.decompose(suffix_tr) or nil
	if aspect == "impf" then
		prefix, prefix_tr = com.make_unstressed(prefix, prefix_tr)
	end
	if com.is_stressed(prefix) then
		suffix, suffix_tr = com.make_unstressed(suffix, suffix_tr)
	end
	local verb, verb_tr = com.concat_russian_tr(prefix, prefix_tr, suffix, suffix_tr)
	verb_tr = verb_tr and com.recompose(verb_tr) or nil
	return com.remove_monosyllabic_accents(verb, verb_tr)
end

local function combine_qualifiers(q1, q2)
	if q1 == nil then
		return q2
	elseif q2 == nil then
		return q1
	else
		return q1 .. ", " .. q2
	end
end

local modifiers = {"q", "qq", "t", "gloss", "tr", "ts", "g", "id", "alt", "pos", "lit"}

local function parse_aspect_pair(arg, arg_index, state, lang_module)
	local pair = {}
	local suffixes = false
	if arg == "-" then
		return false
	end
	local origarg = arg

	if arg:find("^%*") then
		suffixes = true
		arg = rsub(arg, "^%*", "")
	end

	local function parse_err(msg)
		error(msg .. ": " .. arg_index .. "=" .. origarg)
	end

	local function parse_term_with_modifiers(run)
		local obj
		local within_brackets = run[1]:match("^%[(.*)%]$")
		if within_brackets then
			obj = {term = within_brackets, brackets = true}
		else
			obj = {term = run[1]}
		end
		if obj.term == "." then
			obj.term = ""
		end

		for j = 2, #run - 1, 2 do
			if run[j + 1] ~= "" then
				parse_err("Extraneous text '" .. run[j + 1] .. "' after modifier")
			end
			local modtext = run[j]:match("^<(.*)>$")
			if not modtext then
				parse_err("Internal error: Modifier '" .. modtext .. "' isn't surrounded by angle brackets")
			end
			local prefix, value = modtext:match("^([a-z]+):(.*)$")
			if not prefix then
				parse_err(("Modifier %s lacks a prefix, should begin with one of %s followed by a colon"):format(
					run[j], table.concat(modifiers, ",")))
			end
			if not m_table.contains(modifiers, prefix) then
				parse_err(("Unrecognized prefix '%s' in modifier %s, should be one of %s"):format(
					prefix, run[j], table.concat(modifiers, ",")))
			end
			local dest = prefix
			if prefix == "t" then
				dest = "gloss"
			elseif prefix == "g" then
				dest = "genders"
			end
			if obj[dest] then
				parse_err("Modifier '" .. prefix .. "' occurs twice, second occurrence " .. run[j])
			end
			obj[dest] = prefix == "g" and rsplit(value, "%s*,%s*") or value
		end

		return obj
	end

	if arg:find("<") then -- and not arg:find("^[^<]*<[a-z]*[^a-z:]") then
		if not state.put then
			state.put = require("Module:parse utilities")
		end

		local segments = state.put.parse_balanced_segment_run(arg, "<", ">")
		local slash_separated_groups =
			state.put.split_alternating_runs_and_frob_raw_text(segments, "/", state.put.strip_spaces)
		if #slash_separated_groups == 1 then
			pair.prefix = parse_term_with_modifiers(slash_separated_groups[1])
		elseif #slash_separated_groups > 2 then
			parse_err("Saw more than two slashes")
		else
			local function process_terms(segments)
				local retval = {}
				local comma_separated_groups =
					state.put.split_alternating_runs_and_frob_raw_text(segments, ",", state.put.strip_spaces)
				for _, comma_separated_group in ipairs(comma_separated_groups) do
					table.insert(retval, parse_term_with_modifiers(comma_separated_group))
				end
				return retval
			end

			local pfs, impfs = unpack(slash_separated_groups)
			pair.pfs = process_terms(pfs)
			pair.impfs = process_terms(impfs)
		end
	else
		local split_on_slash = rsplit(arg, "%s*/%s*")
		if #split_on_slash == 1 then
			pair.prefix = parse_term_with_modifiers({arg})
		elseif #split_on_slash > 2 then
			parse_err("Saw more than two slashes")
		else
			local pfs, impfs = unpack(split_on_slash)
			local function process_terms(terms)
				local retval = {}
				terms = rsplit(terms, "%s*,%s*")
				for _, term in ipairs(terms) do
					table.insert(retval, parse_term_with_modifiers({term}))
				end
				return retval
			end

			pair.pfs = process_terms(pfs)
			pair.impfs = process_terms(impfs)
		end
	end

	if pair.prefix and pair.prefix.term:find(",") then
		parse_err(("Commas not allowed in single prefix spec '%s'"):format(pair.prefix.term))
	end

	if suffixes then
		if pair.prefix then
			parse_err("Can't specify a single prefix with leading *")
		end
		local function remove_bare_hyphens(terms)
			local retval = {}
			for _, term in ipairs(terms) do
				if term.term ~= "-" then
					table.insert(retval, term)
				end
			end
			return retval
		end

		state.pf_suffixes = remove_bare_hyphens(pair.pfs)
		state.impf_suffixes = remove_bare_hyphens(pair.impfs)
		if #state.pf_suffixes == 0 and #state.impf_suffixes == 0 then
			parse_err("Need at least one perfective or imperfective suffix")
		end
		return nil
	end

	if pair.prefix then
		-- A single prefix; combine with all template suffixes.
		if not state.pf_suffixes then
			parse_err(
				("Saw prefix '%s' with no preceding template suffixes (line beginning with *)"):format(pair.prefix.term)
			)
		end
		pair.prefix.term = rsub(pair.prefix.term, "%-$", "")
		if pair.prefix.tr then
			pair.prefix.tr = rsub(pair.prefix.tr, "%-$", "")
		end

		-- Error on prefix properties we don't know how to handle.
		for _, prop in ipairs {"ts", "alt", "genders", "id", "pos", "lit"} do
			if pair.prefix[prop] then
				parse_error(
					("Can't handle property '%s' in prefix '%s'"):format(prop, pair.prefix.term))
			end
		end

		local function prefix_template_suffixes(prefix, terms, aspect)
			local retval = {}
			for _, term in ipairs(terms) do
				term = m_table.shallowcopy(term)
				for _, prop in ipairs {"ts", "alt"} do
					if term[prop] then
						parse_err(
							("For aspect=%s, can't handle property '%s' in suffix '%s' when combining with prefix"):
							format(aspect, prop, term.term))
					end
				end
				term.term, term.tr = lang_module.paste_prefix_suffix(lang_module.lang, prefix.term, prefix.tr,
					term.term, term.tr, aspect)
				table.insert(retval, term)
			end
			return retval
		end

		-- Do the prefixing.
		pair.pfs = prefix_template_suffixes(pair.prefix, state.pf_suffixes, "pf")
		pair.impfs = prefix_template_suffixes(pair.prefix, state.impf_suffixes, "impf")

		-- Now propagate t= (goes into 'gloss') and qq= to the last resulting term, and q= to the first resulting term.
		local last_term
		if #pair.impfs > 0 then
			last_term = pair.impfs[#pair.impfs]
		else
			last_term = pair.pfs[#pair.pfs]
		end
		last_term.qq = combine_qualifiers(last_term.qq, pair.prefix.qq)
		if last_term.gloss and pair.prefix.gloss then
			parse_err(("Can't override gloss '%s' of term '%s' with gloss '%s' of prefix '%s'"):
			format(last_term.gloss, last_imp.term, pair.prefix.gloss, prefix.term))
		elseif pair.prefix.gloss then
			last_term.gloss = prefix.gloss
		end
		local first_term
		if #pair.pfs > 0 then
			first_term = pair.pfs[1]
		else
			first_term = pair.impfs[1]
		end
		first_term.q = combine_qualifiers(first_term.q, pair.prefix.q)
	else
		local function handle_aspect_terms(terms, template_suffixes, aspect)
			local retval = {}
			for i, term in ipairs(terms) do
				if term.term ~= "-" then
					if term.term:find("%-$") or term.term == "" then
						-- prefix to add to corresponding template suffix
						if #template_suffixes < i then
							local numsuf = #template_suffixes
							parse_err(
								("For aspect=%s, term #%s=%s is a prefix but there %s only %s corresponding template suffix%s"):
								format(aspect, i, term.term, numsuf == 1 and "is" or "are", numsuf,
								numsuf == 1 and "" or "es"))
						end

						-- Fetch suffix; clone because we are modifying it destructively and may reuse it later for
						-- another prefix.
						local newterm = m_table.shallowcopy(template_suffixes[i])

						-- Don't know how to combine ts= or alt= values.
						for _, prop in ipairs {"ts", "alt"} do
							if newterm[prop] or term[prop] then
								parse_err(
									("For aspect=%s, can't handle property '%s' in prefix '%s' or suffix '%s' when combining them"):
									format(aspect, prop, term.term, newterm.term))
							end
						end

						-- Combine term and translit, along with qualifiers and brackets.
						newterm.term, newterm.tr =
							lang_module.paste_prefix_suffix(lang_module.lang, rsub(term.term, "%-$", ""),
								term.tr and rsub(term.tr, "%-$", "") or nil, newterm.term, newterm.tr, aspect)
						newterm.q = combine_qualifiers(newterm.q, term.q)
						newterm.qq = combine_qualifiers(newterm.qq, term.qq)
						newterm.brackets = newterm.brackets or term.brackets

						-- Remaining properties are copied from prefix to suffix if not already in suffix.
						for _, prop in ipairs {"gloss", "genders", "id", "pos", "lit"} do
							if newterm[prop] and term[prop] then
								parse_err(
									("For aspect=%s, can't handle property '%s' occurring along with both prefix '%s' and suffix '%s' when combining them"):
									format(aspect, prop, term.term, newterm.term))
							end
							if term[prop] then
								newterm[prop] = term[prop]
							end
						end

						table.insert(retval, newterm)
					else
						table.insert(retval, term)
					end
				end
			end
			return retval
		end
		pair.pfs = handle_aspect_terms(pair.pfs, state.pf_suffixes, "pf")
		pair.impfs = handle_aspect_terms(pair.impfs, state.impf_suffixes, "impf")
	end

	if #pair.pfs == 0 and #pair.impfs == 0 then
		parse_err("Need at least one perfective or imperfective term")
	end

	return pair
end

local function parse_args(lang, args)
	local lang_module = {lang = lang}
	if lang:getCode() == "ru" then
		lang_module.paste_prefix_suffix = ru_paste_prefix_suffix
	else
		lang_module.paste_prefix_suffix = default_paste_prefix_suffix
	end

	local state = {}
	local groups = {}
	local group = {}
	for i, arg in ipairs(args[1]) do
		local pair = parse_aspect_pair(arg, i, state, lang_module)
		if pair == false then
			if #group == 0 then
				error("No items in group terminated by single hyphen in arg #" .. i)
			end
			table.insert(groups, group)
			group = {}
		elseif pair then
			table.insert(group, pair)
		end
	end
	if #group > 0 then
		table.insert(groups, group)
	end
	return groups
end

local function format_aspect_terms(lang, term_groups, include_default_aspect)
	local all_formatted_items = {}
	for _, group in ipairs(term_groups) do
		local group_formatted_items = {}
		for _, items in ipairs(group) do
			local sort_key = nil
			local function handle_aspect_terms(terms, aspect)
				local term_parts = {}
				for _, term in ipairs(terms) do
					sort_key = sort_key or lang:makeSortKey(term.term)
					local preq_text = term.q and require("Module:qualifier").format_qualifier(term.q) .. " " or ""
					if not term.genders and include_default_aspect then
						term.genders = {aspect}
					end
					term.lang = lang
					local linked_term = m_links.full_link(term)
					if term.brackets then
						linked_term = "[" .. linked_term .. "]"
					end
					table.insert(term_parts, preq_text .. linked_term
						.. (term.qq and " " .. require("Module:qualifier").format_qualifier(term.qq) or ""))
				end
				return table.concat(term_parts, ", ")
			end
			table.insert(group_formatted_items, {
				pfs = handle_aspect_terms(items.pfs, "pf"),
				impfs = handle_aspect_terms(items.impfs, "impf"),
				sort_key = sort_key
			})
		end
		table.sort(group_formatted_items, function(a, b) return a.sort_key < b.sort_key end)
		for _, formatted_item in ipairs(group_formatted_items) do
			table.insert(all_formatted_items, formatted_item)
		end
	end
	return all_formatted_items
end

local function format_terms_as_list(lang, formatted_items)
	for i, formatted_item in ipairs(formatted_items) do
		if formatted_item.pfs == "" then
			formatted_items[i] = formatted_item.impfs
		elseif formatted_item.impfs == "" then
			formatted_items[i] = formatted_item.pfs
		else
			formatted_items[i] = formatted_item.pfs .. ", " .. formatted_item.impfs
		end
	end
	return require("Module:columns").create_list {
		header = "verbs",
		format_header = true,
		content = formatted_items,
		lang = lang,
		column_count = 2,
		collapse = true,
	}
end

local function format_terms_as_table(lang, formatted_items)
	local lines = {}
	table.insert(lines, '{| class="wikitable vsSwitcher" data-toggle-category="derived terms"\n! perfective !! class="vsToggleElement" | imperfective')

	for i, formatted_item in ipairs(formatted_items) do
		table.insert(lines, '|- class="vsHide"\n| ' .. formatted_item.pfs .. " || " .. formatted_item.impfs)
	end
	table.insert(lines, "|}")
	return table.concat(lines, "\n")
end

function export.imperfectives_and_perfectives(frame)
	local iparams = {
		["format"] = {default = "list"},
		["lang"] = {},
	}
	local iargs = require("Module:parameters").process(frame.args, iparams)

	local params = {
		["format"] = {},
		[1] = {list = true},
	}
	local args = require("Module:parameters").process(frame:getParent().args, params)
	local format = args.format or iargs.format
	local lang = require("Module:languages").getByCode(iargs.lang, "lang")
	if format ~= "list" and format ~= "table" then
		error(("Unrecognized format '%s'; possible values are 'list', 'table'"):format(format))
	end
	local groups = parse_args(lang, args)
	local formatted_items = format_aspect_terms(lang, groups, format == "list")
	return format == "list" and format_terms_as_list(lang, formatted_items) or
		format_terms_as_table(lang, formatted_items)
end

return export
