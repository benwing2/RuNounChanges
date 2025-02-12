local export = {}

local concat = table.concat
local insert = table.insert
local listToSet = require("Module:table").listToSet
local rsplit = mw.text.split

local descendants_tree_module = "Module:descendants tree"
local labels_module = "Module:labels"
local languages_module = "Module:languages"
local links_module = "Module:links"
local parse_utilities_module = "Module:parse utilities"
local scripts_module = "Module:scripts"
local table_module = "Module:table"

local error_on_no_descendants = false

local function qualifier(content)
	if content then
		return '<span class="ib-brac qualifier-brac">(</span><span class="ib-content qualifier-content">' .. content .. '</span><span class="ib-brac qualifier-brac">)</span>'
	end
end

local function track(page)
	return require("Module:debug/track")("descendant/" .. page)
end

local function ine(arg)
	if arg == "" then
		return nil
	else
		return arg
	end
end

local function add_tooltip(text, tooltip)
	return '<span class="desc-arr" title="' .. tooltip .. '">' .. text .. '</span>'
end

local function split_on_comma(term)
	if term:find(",%s") then
		return require(parse_utilities_module).split_on_comma(term)
	else
		return rsplit(term, ",")
	end
end

-- Params that modify a descendant term (as also supported by {{l}}, {{m}}). Doesn't include gloss=, which we
-- handle specially.
local param_term_mods = {"alt", "g", "id", "lit", "pos", "t", "tr", "ts"}
local param_term_mod_set = listToSet(param_term_mods)
-- Boolean params indicating whether a descendant term (or all terms) are particular sorts of borrowings.
local bortypes = {"inh", "bor", "lbor", "slb", "obor", "translit", "der", "clq", "pclq", "sml", "unc"}
local bortype_set = listToSet(bortypes)
-- Aliases of clq=.
local calque_aliases = {"cal", "calq", "calque"}
local calque_alias_set = listToSet(calque_aliases)
-- Aliases of pclq=.
local partial_calque_aliases = {"pcal", "pcalq", "pcalque"}
local partial_calque_alias_set = listToSet(partial_calque_aliases)
-- Miscellaneous list params.
local misc_list_params = {"q", "qq", "lb"}
local misc_list_param_set = listToSet(misc_list_params)

-- Add a "regular" list param such as g=, gloss=, lit=, etc. "Regular" here means that `param` and `param1` are
-- the same thing. `type` if given is the param type (e.g. "boolean") and `alias_of` is used for params that are
-- aliases of other params.
local function add_regular_list_param(params, param, type, alias_of)
	params[param] = {type = type, alias_of = alias_of, list = true, allow_holes = true}
end

-- Add an index-separated list param such as bor=, calq=, qq=, etc. "Index-separated" means that `param` and
-- `param1` are different. Non-numbered `param` is accessible as `args.param` while numbered `param1`, `param2`,
-- etc. are accessible as `args.partparam[1]`, `args.partparam[2]`, etc. `type` if given is the param type (e.g.
-- "boolean") and `alias_of` is used for params that are aliases of other params.
local function add_index_separated_list_param(params, param, type, alias_of)
	params[param] = {alias_of = alias_of, type = type}
	params["part" .. param] = {alias_of = alias_of and "part" .. alias_of or nil, type = type,
		list = param, allow_holes = true, require_index = true}
end

-- Convert a raw lb= param (or nil) to a list of label info objects of the format described in get_label_info() in
-- [[Module:labels]]). Unrecognized labels will end up with an unchanged display form. Return nil if nil passed in.
local function split_and_process_raw_labels(raw_lb, lang)
	if not raw_lb then
		return nil
	end
	return require(labels_module).split_and_process_raw_labels { labels = raw_lb, lang = lang, nocat = true }
end

-- Return a function of one argument `arg` (a param name), which fetches args[`arg`] if index == 0, else
-- args["part" .. `arg`][index].
local function get_val(args, index)
	return function(arg)
		if index == 0 then
			return args[arg]
		else
			return args["part" .. arg][index]
		end
	end
end

-- Return the arrow text for the `index`th term, or the overall arrow text if index == 0.
local function get_arrow(args, index)
	local val = get_val(args, index)
	local arrow

	if val("bor") then
		arrow = add_tooltip("→", "borrowed")
	elseif val("lbor") then
		arrow = add_tooltip("→", "learned borrowing")
	elseif val("slb") then
		arrow = add_tooltip("→", "semi-learned borrowing")
	elseif val("obor") then
		arrow = add_tooltip("→", "orthographic borrowing")
	elseif val("translit") then
		arrow = add_tooltip("→", "transliteration")
	elseif val("clq") then
		arrow = add_tooltip("→", "calque")
	elseif val("pclq") then
		arrow = add_tooltip("→", "partial calque")
	elseif val("sml") then
		arrow = add_tooltip("→", "semantic loan")
	elseif val("inh") or (val("unc") and not val("der")) then
		arrow = add_tooltip(">", "inherited")
	else
		arrow = ""
	end
	-- allow der=1 in conjunction with bor=1 to indicate e.g. English "pars recta"
	-- derived and borrowed from Latin "pars".
	if val("der") then
		arrow = arrow .. add_tooltip("⇒", "reshaped by analogy or addition of morphemes")
	end

	if val("unc") then
		arrow = arrow .. add_tooltip("?", "uncertain")
	end

	if arrow ~= "" then
		arrow = arrow .. " "
	end

	return arrow
end

-- Return the pre-qualifier text for the `index`th term, or the overall pre-qualifier text if index == 0.
local function get_pre_qualifiers(args, index, lang)
	local val = get_val(args, index)
	local quals

	if index > 0 then
		local labels = split_and_process_raw_labels(val("lb"), lang)
		if labels then
			labels = require(labels_module).format_processed_labels {
				labels = labels, lang = lang, no_ib_content = true
			}
			if labels ~= "" then -- not sure labels can be an empty string but it seems possible in some circumstances
				quals = {labels}
			end
		end
	end
	if val("q") then
		quals = quals or {}
		insert(quals, val("q"))
	end
	if quals then
		return require("Module:qualifier").format_qualifier(quals) .. " "
	else
		return ""
	end
end

-- Return the post-qualifier text for the `index`th term, or the overall post-qualifier text if index == 0.
local function get_post_qualifiers(args, index, lang)
	local val = get_val(args, index)
	local postqs = {}

	if val("inh") then
		insert(postqs, qualifier("inherited"))
	end
	if val("lbor") then
		insert(postqs, qualifier("learned"))
	end
	if val("slb") then
		insert(postqs, qualifier("semi-learned"))
	end
	if val("translit") then
		insert(postqs, qualifier("transliteration"))
	end
	if val("clq") then
		insert(postqs, qualifier("calque"))
	end
	if val("pclq") then
		insert(postqs, qualifier("partial calque"))
	end
	if val("sml") then
		insert(postqs, qualifier("semantic loan"))
	end
	if val("qq") then
		insert(postqs, require("Module:qualifier").format_qualifier(val("qq")))
	end
	if index == 0 then
		local labels = split_and_process_raw_labels(val("lb"), lang)
		if labels then
			labels = require(labels_module).format_processed_labels {
				labels = labels, lang = lang
			}
			if labels ~= "" then
				insert(postqs, "&mdash; " .. labels)
			end
		end
	end
	if #postqs > 0 then
		return " " .. concat(postqs, " ")
	else
		return ""
	end
end

local function desc_or_desc_tree(frame, desc_tree)
	local params
	local boolean = {type = "boolean"}
	if desc_tree then
		params = {
			[1] = {required = true, type = "language", family = true, default = "gem-pro"},
			[2] = {required = true, list = true, allow_holes = true, default = "*fuhsaz"},
			["notext"] = boolean,
			["noalts"] = boolean,
			["noparent"] = boolean,
		}
	else
		params = {
			[1] = {required = true, type = "language", family = true, default = "en"},
			[2] = {list = true, allow_holes = true},
			["alts"] = boolean
		}
		-- If template namespace.
		if mw.title.getCurrentTitle().namespace == 10 then
			params[2].default = "word"
		end
	end
	
	for _, term_mod in ipairs(param_term_mods) do
		add_regular_list_param(params, term_mod)
	end
	-- Handle gloss= specially because it's an alias.
	add_regular_list_param(params, "gloss", nil, "t")
	-- Handle sc= specially because the type is "script".
	add_regular_list_param(params, "sc", "script")
	for _, bortype in ipairs(bortypes) do
		add_index_separated_list_param(params, bortype, "boolean")
	end
	for _, calque_alias in ipairs(calque_aliases) do
		add_index_separated_list_param(params, calque_alias, "boolean", "clq")
	end
	for _, partial_calque_alias in ipairs(partial_calque_aliases) do
		add_index_separated_list_param(params, partial_calque_alias, "boolean", "pclq")
	end
	for _, misc_list_param in ipairs(misc_list_params) do
		add_index_separated_list_param(params, misc_list_param)
	end

	-- Add other single params.
	params.sclang = boolean
	params.sclb = {type = "boolean", alias_of = "sclang"}
	params.nolang = boolean
	params.nolb = {type = "boolean", alias_of = "nolang"}

	local namespace = mw.title.getCurrentTitle().nsText

	local parent_args
	if frame.args[1] then
		parent_args = frame.args
	else
		parent_args = frame:getParent().args
	end

	-- FIXME: Temporary error message.
	for arg, _ in pairs(parent_args) do
		if type(arg) == "string" and arg:find("^tag[0-9]*$") then
			local lbarg = arg:gsub("^tag", "lb")
			error(("Use %s= instead of %s="):format(lbarg, arg))
		end
	end

	-- Error to catch most uses of old-style parameters.
	if ine(parent_args[4]) and not ine(parent_args[3]) and not ine(parent_args.tr2) and not ine(parent_args.ts2)
		and not ine(parent_args.t2) and not ine(parent_args.gloss2) and not ine(parent_args.g2)
		and not ine(parent_args.alt2) then
		error("You specified a term in 4= and not one in 3=. You probably meant to use t= to specify a gloss instead. "
			.. "If you intended to specify two terms, put the second term in 3=.")
	end
	if not ine(parent_args[3]) and not ine(parent_args.alt2) and not ine(parent_args.tr2) and not ine(parent_args.ts2)
		and ine(parent_args.g2) then
		error("You specified a gender in g2= but no term in 3=. You were probably trying to specify two genders for "
			.. "a single term. To do that, put both genders in g=, comma-separated.")
	end

	local args = require("Module:parameters").process(parent_args, params)

	local lang = args[1]
	local terms = args[2]
	local alts = args.alt
	
	if (namespace == "" or namespace == "Reconstruction") and (lang:hasType("appendix-constructed") and not lang:hasType("regular")) then
		error("Terms in appendix-only constructed languages may not be given as descendants.")
	end

	local fetch_alt_forms = desc_tree and not args.noalts or not desc_tree and args.alts

	local m_desctree
	if desc_tree or fetch_alt_forms then
		m_desctree = require(descendants_tree_module)
	end
	
	if lang:getCode() ~= lang:getFullCode() then
		-- [[Special:WhatLinksHere/Wiktionary:Tracking/descendant/etymological]]
		track("etymological")
		track("etymological/" .. lang:getCode())
	end

	local is_family = lang:hasType("family")
	local proxy_lang
	if is_family then
		-- [[Special:WhatLinksHere/Wiktionary:Tracking/descendant/family]]
		track("family")
		track("family/" .. lang:getCode())
		proxy_lang = require(languages_module).getByCode("und")
	else
		proxy_lang = lang
	end

	local languageName
	if is_family then
		-- The display form for families includes the word "languages", which we probably don't want to
		-- display.
		languageName = lang:getCanonicalName()
	else
		languageName = lang:getDisplayForm()
	end
	local langtag
	
	if args.sclang then
		local sc = args.sc[1]
		if sc then
			langtag = sc:getDisplayForm()
		else
			local term, alt = terms[1], alts[1]
			local best_sc
			if is_family then
				best_sc = require(scripts_module).findBestScriptWithoutLang(term or alt, "none is last resort")
			else
				best_sc = lang:findBestScript(term or alt)
			end
			langtag = best_sc:getDisplayForm()
		end
	else
		langtag = languageName
	end
	
	-- Find the maximum index among any of the list parameters.
	local maxmaxindex = terms.maxindex
	for k, v in pairs(args) do
		if type(v) == "table" and v.maxindex and v.maxindex > maxmaxindex then
			maxmaxindex = v.maxindex
		end
	end
	
	local parts = {}
	local terms_for_descendant_trees = {}
	-- Keep track of descendants whose descendant tree we fetch. Don't fetch the same descendant tree twice (which
	-- can happen especially with Arabic-script terms with the same unvocalized spelling but differing vocalization).
	-- This happens e.g. with Ottoman Turkish [[پورتقال]], which has {{desctree|fa-cls|پُرْتُقَال|پُرْتِقَال|bor=1}}, with
	-- two terms that have the same unvocalized spelling.
	local terms_and_ids_fetched = {}
	local descendant_terms_seen = {}
	local use_semicolon = false

	local ind = 0
	for i = 1, maxmaxindex do
		local term = terms[i]
		if term ~= ";" then
			ind = ind + 1
			local alt = args.alt[ind]
			local id = args.id[ind]
			local sc = args.sc[ind]
			local tr = args.tr[ind]
			local ts = args.ts[ind]
			local gloss = args.t[ind]
			local pos = args.pos[ind]
			local lit = args.lit[ind]
			local g = args.g[ind] and rsplit(args.g[ind], "%s*,%s*") or {}
			local link
			local terms_for_alt_forms = {}

			local termobj =	{
				lang = proxy_lang,
			}
			-- Initialize `termobj` with indexed modifier params such as t1, t2, etc. and alt1, alt2, etc. Inline
			-- modifiers specified using the <...> notation override these.
			local function reinit_termobj(term)
				termobj.term = term
				termobj.sc = sc
				termobj.track_sc = true
				termobj.term = term
				termobj.alt = alt
				termobj.id = id
				termobj.tr = tr
				termobj.ts = ts
				termobj.genders = g
				termobj.gloss = gloss
				termobj.pos = pos
				termobj.lit = lit
			end
			-- Construct a link out of `termobj`. Also add the term to the list of descendant trees and/or alternative
			-- forms to fetch, if the page+ID combination hasn't already been seen.
			local function get_link()
				local link = ""
				-- If an individual term has a literal comma in it, use semicolons for all joiners. Otherwise we use
				-- semicolon only if the user specified a literal semicolon as a term.
				if termobj.term and termobj.term:find(",") then
					use_semicolon = true
				end
				if termobj.term ~= "-" then -- including term == nil
					link = require("Module:links").full_link(termobj, nil, true)
					if termobj.term and (desc_tree or fetch_alt_forms) then
						local entry_name = require(links_module).get_link_page(termobj.term, lang, sc)
						-- NOTE: We use the term and ID as the key, but not the language. This is OK currently because
						-- all terms have the same language; but if we ever add support for a term-specific language,
						-- we need to fix this.
						local term_and_id = termobj.id and entry_name .. "!!!" .. termobj.id or entry_name
						if not terms_and_ids_fetched[term_and_id] then
							terms_and_ids_fetched[term_and_id] = true
							local term_for_fetching = {
								lang = lang, entry_name = entry_name, id = termobj.id
							}
							if desc_tree then
								if is_family then
									error("No support currently (and probably ever) for fetching a descendant tree when a family code instead of language code is given")
								end
								if error_on_no_descendants then
									require(table_module).insertIfNot(descendant_terms_seen,
										{ term = termobj.term, id = termobj.id })
								end
								table.insert(terms_for_descendant_trees, term_for_fetching)
							end
							if fetch_alt_forms then
								if is_family then
									error("No support currently (and probably ever) for fetching alternative forms when a family code instead of language code is given")
								end
								-- [[Special:WhatLinksHere/Wiktionary:Tracking/descendant/alts]]
								track("alts")
								table.insert(terms_for_alt_forms, term_for_fetching)
							end
						end
					end
				elseif termobj.ts or termobj.gloss or #termobj.genders > 0 then
					-- [[Special:WhatLinksHere/Wiktionary:Tracking/descendant/no term]]
					track("no term")
					termobj.term = nil
					link = require("Module:links").full_link(termobj, nil, true)
					link = link
						:gsub("<small>%[Term%?%]</small> ", "")
						:gsub("<small>%[Term%?%]</small>&nbsp;", "")
						:gsub("%[%[Category:[^%[%]]+ term requests%]%]", "")
				else -- display no link at all
					-- [[Special:WhatLinksHere/Wiktionary:Tracking/descendant/no term or annotations]]
					track("no term or annotations")
				end
				return link
			end

			-- Check for inline modifier, e.g. מרים<tr:Miryem>. But exclude HTML entry with <span ...>, <i ...>,
			-- <br/> or similar in it, caused by wrapping an argument in {{l|...}}, {{af|...}} or similar.
			if term and term:find("<") and not require(parse_utilities_module).term_contains_top_level_html(term) then
				local run = require(parse_utilities_module).parse_balanced_segment_run(term, "<", ">")
				-- Split the non-modifier parts of an alternating run on comma, but not on comma+whitespace.
				local comma_separated_runs = require(parse_utilities_module).split_alternating_runs_on_comma(run)
				local sub_links = {}

				local function parse_err(msg)
					local parts = {}
					for _, run in ipairs(comma_separated_runs) do
						insert(parts, concat(run))
					end
					error(msg .. ": " .. (i + 1) .. "=" .. concat(parts, ","))
				end
				for j, run in ipairs(comma_separated_runs) do
					reinit_termobj(run[1])
					local seen_mods = {}
					for k = 2, #run - 1, 2 do
						if run[k + 1] ~= "" then
							parse_err("Extraneous text '" .. run[k + 1] .. "' after modifier")
						end
						local modtext = run[k]:match("^<(.*)>$")
						if not modtext then
							parse_err("Internal error: Modifier '" .. modtext .. "' isn't surrounded by angle brackets")
						end
						local prefix, arg = modtext:match("^(%l+):(.*)$")
						if prefix then
							if seen_mods[prefix] then
								parse_err("Modifier '" .. prefix .. "' occurs twice, second occurrence " .. run[k])
							end
							seen_mods[prefix] = true
							if prefix == "t" or prefix == "gloss" then
								termobj.gloss = arg
							elseif prefix == "g" then
								termobj.genders = rsplit(arg, "%s*,%s*")
							elseif prefix == "sc" then
								termobj.sc = arg
							elseif param_term_mod_set[prefix] then
								termobj[prefix] = arg
							elseif misc_list_param_set[prefix] then
								if j < #comma_separated_runs then
									parse_err("Modifier " .. run[k] .. " should come after the last term")
								end
								args["part" .. prefix][ind] = arg
							elseif prefix == "tag" then
								-- FIXME: Remove support for <tag:...> in favor of <lb:...>
								error("Use <lb:...> instead of <tag:...>")
							else
								parse_err("Unrecognized prefix '" .. prefix .. "' in modifier " .. run[k])
							end
						elseif j < #comma_separated_runs then
							parse_err("Modifier " .. run[k] .. " should come after the last term")
						else
							if seen_mods[modtext] then
								parse_err("Modifier '" .. modtext .. "' occurs twice")
							end
							seen_mods[modtext] = true
							if bortype_set[modtext] then
								args["part" .. modtext][ind] = true
							elseif calque_alias_set[modtext] then
								args.partclq[ind] = true
							elseif partial_calque_alias_set[modtext] then
								args.partpclq[ind] = true
							else
								parse_err("Unrecognized modifier '" .. modtext .. "'")
							end
						end
					end
					local sub_link = get_link()
					if sub_link ~= "" then
						insert(sub_links, sub_link)
					end
				end
				link = concat(sub_links, "/")
			elseif term and term:find(",") then
				local sub_terms = split_on_comma(term)
				local sub_links = {}
				for _, sub_term in ipairs(sub_terms) do
					reinit_termobj(sub_term)
					local sub_link = get_link()
					if sub_link ~= "" then
						insert(sub_links, sub_link)
					end
				end
				link = concat(sub_links, "/")
			else
				reinit_termobj(term)
				link = get_link()
			end

			local arrow = get_arrow(args, ind)
			local preqs = get_pre_qualifiers(args, ind, proxy_lang)
			local postqs = get_post_qualifiers(args, ind, proxy_lang)

			insert(parts, {
				arrow = arrow, preqs = preqs, link = link, terms_for_alt_forms = terms_for_alt_forms, postqs = postqs,
				use_semicolon = terms[i - 1] == ";"
			})
		end
	end

	local descendant_trees = {}
	for _, descterm in ipairs(terms_for_descendant_trees) do
		-- When I ([[User:Benwing2]]) first implemented this in Nov 2020, I had `maxmaxindex > 1` as the last argument.
		-- Since then, [[User:Fytcha]] changed the last param to `true`.
		local descendant_tree = m_desctree.get_descendants(descterm.lang, descterm.entry_name, descterm.id, true)
		if descendant_tree and descendant_tree ~= "" then
			insert(descendant_trees, descendant_tree)
		end
	end

	if error_on_no_descendants and desc_tree and not descendant_trees[1] then
		local function format_term_seen(term_seen)
			if term_seen.id then
				return ("[[%s]] with ID '%s'"):format(term_seen.term, term_seen.id)
			else
				return ("[[%s]]"):format(term_seen.term)
			end
		end
		if #descendant_terms_seen == 0 then
			error("[[Template:desctree]] invoked but no terms to retrieve descendants from")
		elseif #descendant_terms_seen == 1 then
			error(("No Descendants section was found in the entry %s under the header for %s"):format(
				format_term_seen(descendant_terms_seen[1]), lang:getFullName()))
		else
			for i, term_seen in ipairs(descendant_terms_seen) do
				descendant_terms_seen[i] = format_term_seen(term_seen)
			end
			error(("No Descendants section was found in any of the entries %s under the header for %s"):format(
				concat(descendant_terms_seen, ", "), lang:getFullName()))
		end
	end

	local descendants = concat(descendant_trees)
	if args.noparent then
		return descendants
	end

	local initial_arrow = get_arrow(args, 0)
	local initial_preqs = get_pre_qualifiers(args, 0, proxy_lang)
	local final_postqs = get_post_qualifiers(args, 0, proxy_lang)

	-- Now format each part. We wait to do this because we may not know the separator (semicolon or comma) till now.
	for i, part in ipairs(parts) do
		local partparts = {}
		local function ins(text)
			insert(partparts, text)
		end
		if not args.notext then
			ins(part.arrow)
		end
		ins(part.preqs)
		ins(part.link)
		for _, altterm in ipairs(part.terms_for_alt_forms) do
			local altform = m_desctree.get_alternative_forms(altterm.lang, altterm.entry_name, altterm.id,
				use_semicolon and "; " or ", ")
			if altform ~= "" then
				ins(use_semicolon and "; " or ", ")
				ins(altform)
			end
		end
		ins(part.postqs)
		local parttext = concat(partparts)
		if i > 1 and parttext ~= "" then
			parttext = ((use_semicolon or part.use_semicolon) and "; " or ", ") .. parttext
		end
		parts[i] = parttext
	end

	local all_linktext = initial_preqs .. concat(parts) .. final_postqs .. descendants

	if args.notext then
		return all_linktext
	elseif args.nolang then
		return initial_arrow .. all_linktext
	else
		return concat { initial_arrow, langtag, ":", all_linktext ~= "" and " " or "", all_linktext }
	end
end

function export.descendant(frame)
	return desc_or_desc_tree(frame, false) .. require("Module:TemplateStyles")("Module:etymology/style.css")
end

function export.descendants_tree(frame)
	return desc_or_desc_tree(frame, true)
end

return export
