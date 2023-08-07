local export = {}

local listToSet = require("Module:table/listToSet")
local rsplit = mw.text.split

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


local m_dialect_tags
local function memoize_require_dialect_tags()
	if not m_dialect_tags then
		m_dialect_tags = require("Module:dialect tags")
	end
	return m_dialect_tags
end


-- Replace comma+whitespace in the non-modifier parts of an alternating run (after parse_balanced_segment_run() is
-- called). See split_on_comma() in [[Module:dialect tags]].
local function escape_comma_whitespace_in_alternating_run(run)
	local need_tempcomma_undo = false
	for i, seg in ipairs(run) do
		if i % 2 == 1 then
			local this_need_tempcomma_undo
			if seg:find(",") then
				run[i], this_need_tempcomma_undo = memoize_require_dialect_tags().escape_comma_whitespace(seg)
			end
			need_tempcomma_undo = need_tempcomma_undo or this_need_tempcomma_undo
		end
	end
	return need_tempcomma_undo
end

-- Params that modify a descendant term (as also supported by {{l}}, {{m}}). Doesn't include gloss=, which we
-- handle specially.
local param_term_mods = {"alt", "g", "id", "lit", "pos", "sc", "t", "tr", "ts"}
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
local misc_list_params = {"q", "qq", "tag"}
local misc_list_param_set = listToSet(misc_list_params)

local function desc_or_desc_tree(frame, desc_tree)
	local params
	if desc_tree then
		params = {
			[1] = {required = true, default = "gem-pro"},
			[2] = {required = true, list = true, allow_holes = true, default = "*fuhsaz"},
			["notext"] = {type = "boolean"},
			["noalts"] = {type = "boolean"},
			["noparent"] = {type = "boolean"},
		}
	else
		params = {
			[1] = {required = true},
			[2] = {list = true, allow_holes = true},
			["alts"] = {type = "boolean"}
		}
	end

	-- Add a "regular" list param such as g=, gloss=, lit=, etc. "Regular" here means that `param` and `param1` are
	-- the same thing. `type` if given is the param type (e.g. "boolean") and `alias_of` is used for params that are
	-- aliases of other params.
	local function add_regular_list_param(param, type, alias_of)
		params[param] = {type = type, alias_of = alias_of, list = true, allow_holes = true}
	end
	-- Add an index-separated list param such as bor=, calq=, qq=, etc. "Index-separated" means that `param` and
	-- `param1` are different. Non-numbered `param` is accessible as `args.param` while numbered `param1`, `param2`,
	-- etc. are accessible as `args.partparam[1]`, `args.partparam[2]`, etc. `type` if given is the param type (e.g.
	-- "boolean") and `alias_of` is used for params that are aliases of other params.
	local function add_index_separated_list_param(param, type, alias_of)
		params[param] = {alias_of = alias_of, type = type}
		params["part" .. param] = {alias_of = alias_of and "part" .. alias_of or nil, type = type,
			list = param, allow_holes = true, require_index = true}
	end

	for _, term_mod in ipairs(param_term_mods) do
		add_regular_list_param(term_mod)
	end
	-- Handle gloss= specially because it's an alias.
	add_regular_list_param("gloss", nil, "t")
	for _, bortype in ipairs(bortypes) do
		add_index_separated_list_param(bortype, "boolean")
	end
	for _, calque_alias in ipairs(calque_aliases) do
		add_index_separated_list_param(calque_alias, "boolean", "clq")
	end
	for _, partial_calque_alias in ipairs(partial_calque_aliases) do
		add_index_separated_list_param(partial_calque_alias, "boolean", "pclq")
	end
	for _, misc_list_param in ipairs(misc_list_params) do
		add_index_separated_list_param(misc_list_param)
	end

	-- Add other single params.
	for k, v in pairs({
		["sclb"] = {type = "boolean"},
		["nolb"] = {type = "boolean"},
		["sandbox"] = {type = "boolean"},
	}) do
		params[k] = v
	end

	local namespace = mw.title.getCurrentTitle().nsText

	local parent_args
	if frame.args[1] then
		parent_args = frame.args
	else
		parent_args = frame:getParent().args
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

	if args.sandbox then
		if namespace == "" or namespace == "Reconstruction" then
			error("The sandbox module, Module:descendants tree/sandbox, should not be used in entries.")
		end
	end
	
	local lang = args[1]
	local terms = args[2]
	local alts = args["alt"]
	
	local m_desctree
	if desc_tree or alts then
		if args.sandbox or require("Module:yesno")(frame.args.sandbox, false) then
			m_desctree = require("Module:descendants tree/sandbox")
		else
			m_desctree = require("Module:descendants tree")
		end
	end
	
	if mw.title.getCurrentTitle().nsText == "Template" then
		lang = lang or "en"
		if #terms == 0 then
			terms = {"word"}
			terms.maxindex = 1
		end
	end

	local m_languages = require("Module:languages")
	lang = m_languages.getByCode(lang, 1, "allow etym")
	
	if lang:getCode() ~= lang:getNonEtymologicalCode() then
		-- [[Special:WhatLinksHere/Template:tracking/descendant/etymological]]
		track("etymological")
		track("etymological/" .. lang:getCode())
	end

	local languageName = lang:getDisplayForm()

	local label

	if args["sclb"] then
		local sc = args["sc"][1] and require("Module:scripts").getByCode(args["sc"][1], "sc")
		if sc then
			label = sc:getDisplayForm()
		else
			local term, alt = terms[1], alts[1]
			label = lang:findBestScript(term or alt):getDisplayForm()
		end
	else
		label = languageName
	end

	-- Find the maximum index among any of the list parameters.
	local maxmaxindex = terms.maxindex
	for k, v in pairs(args) do
		if type(v) == "table" and v.maxindex and v.maxindex > maxmaxindex then
			maxmaxindex = v.maxindex
		end
	end

	-- Convert a raw tag= param (or nil) to a list of formatted dialect tags; unrecognized tags are passed through
	-- unchanged. Return nil if nil passed in.
	local function tags_to_dialects(tags)
		if not tags then
			return nil
		end
		local m_dialect_tags = memoize_require_dialect_tags()
		return m_dialect_tags.make_dialects(m_dialect_tags.split_on_comma(tags), lang)
	end

	-- Return a function of one argument `arg` (a param name), which fetches args[`arg`] if index == 0, else
	-- args["part" .. `arg`][index].
	local function get_val(index)
		return function(arg)
			if index == 0 then
				return args[arg]
			else
				return args["part" .. arg][index]
			end
		end
	end

	-- Return the arrow text for the `index`th term, or the overall arrow text if index == 0.
	local function get_arrow(index)
		local val = get_val(index)
		local arrow

		if val("bor") then
			arrow = add_tooltip("→", "borrowed")
		elseif val("lbor") then
			arrow = add_tooltip("→", "learned borrowing")
		elseif val("slb") then
			arrow = add_tooltip("→", "semi-learned borrowing")
		elseif val("obor") then
			arrow = add_tooltip("→", "orthographic borrowing")
		elseif args["translit"] then
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
	local function get_pre_qualifiers(index)
		local val = get_val(index)
		local quals

		if index > 0 then
			quals = tags_to_dialects(val("tag"))
		end
		if val("q") then
			quals = quals or {}
			table.insert(quals, val("q"))
		end
		if quals then
			return require("Module:qualifier").format_qualifier(quals) .. " "
		else
			return ""
		end
	end

	-- Return the post-qualifier text for the `index`th term, or the overall post-qualifier text if index == 0.
	local function get_post_qualifiers(index)
		local val = get_val(index)
		local postqs = {}

		if val("inh") then
			table.insert(postqs, qualifier("inherited"))
		end
		if val("lbor") then
			table.insert(postqs, qualifier("learned"))
		end
		if val("slb") then
			table.insert(postqs, qualifier("semi-learned"))
		end
		if val("translit") then
			table.insert(postqs, qualifier("transliteration"))
		end
		if val("clq") then
			table.insert(postqs, qualifier("calque"))
		end
		if val("pclq") then
			table.insert(postqs, qualifier("partial calque"))
		end
		if val("sml") then
			table.insert(postqs, qualifier("semantic loan"))
		end
		if val("qq") then
			table.insert(postqs, require("Module:qualifier").format_qualifier(val("qq")))
		end
		if index == 0 then
			local dialects = tags_to_dialects(val("tag"))
			if dialects then
				table.insert(postqs, memoize_require_dialect_tags().post_format_dialects(dialects))
			end
		end
		if #postqs > 0 then
			return " " .. table.concat(postqs, " ")
		else
			return ""
		end
	end

	local parts = {}
	local descendants = {}
	local saw_descendants = false
	local seen_terms = {}
	local put
	local use_semicolon = false

	local ind = 0
	for i = 1, maxmaxindex do
		local term = terms[i]
		if term ~= ";" then
			ind = ind + 1
			local alt = args["alt"][ind]
			local id = args["id"][ind]
			local sc = args["sc"][ind] and require("Module:scripts").getByCode(args["sc"][ind], "sc" .. (ind == 1 and "" or ind)) or nil
			local tr = args["tr"][ind]
			local ts = args["ts"][ind]
			local gloss = args["t"][ind]
			local pos = args["pos"][ind]
			local lit = args["lit"][ind]
			local g = args["g"][ind] and rsplit(args["g"][ind], "%s*,%s*") or {}
			local link

			local termobj =	{
				lang = lang,
			}
			-- Initialize `termobj` with indexed modifier params such as t1, t2, etc. and alt1, alt2, etc. Inline
			-- modifiers specified using the <...> notation override these.
			local function reinit_termobj(term)
				termobj.term = term
				termobj.sc = sc
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
			-- Construct a link out of `termobj`.
			local function get_link()
				local link = ""
				-- If an individual term has a literal comma in it, use semicolons for all joiners. Otherwise we use
				-- semicolon only if the user specified a literal semicolon as a term.
				if termobj.term and termobj.term:find(",") then
					use_semicolon = true
				end
				if termobj.term ~= "-" then -- including term == nil
					link = require("Module:links").full_link(termobj, nil, true)
				elseif termobj.ts or termobj.gloss or #termobj.genders > 0 then
					-- [[Special:WhatLinksHere/Template:tracking/descendant/no term]]
					track("no term")
					termobj.term = nil
					link = require("Module:links").full_link(termobj, nil, true)
					link = link
						:gsub("<small>%[Term%?%]</small> ", "")
						:gsub("<small>%[Term%?%]</small>&nbsp;", "")
						:gsub("%[%[Category:[^%[%]]+ term requests%]%]", "")
				else -- display no link at all
					-- [[Special:WhatLinksHere/Template:tracking/descendant/no term or annotations]]
					track("no term or annotations")
				end
				return link
			end

			-- Check for new-style argument, e.g. מרים<tr:Miryem>. But exclude HTML entry with <span ...>, <i ...>,
			-- <br/> or similar in it, caused by wrapping an argument in {{l|...}}, {{af|...}} or similar. Basically,
			-- all tags of the sort we parse here should consist of less-than + letters + greater-than, e.g. <bor>, or
			-- less-than + letters + colon + arbitrary text with balanced angle brackets + greater-than, e.g. <tr:...>,
			-- so if we see a tag on the outer level that isn't in this format, we don't try to parse it. The
			-- restriction to the outer level is to allow generated HTML inside of e.g. qualifier tags, such as
			-- foo<q:similar to {{m|fr|bar}}>.
			if term and term:find("<") and not term:find("<[a-z]*[^a-z:>]") then
				if not put then
					put = require("Module:parse utilities")
				end
				local run = put.parse_balanced_segment_run(term, "<", ">")
				-- Split the non-modifier parts of an alternating run on comma, but not on comma+whitespace.
				local need_tempcomma_undo = escape_comma_whitespace_in_alternating_run(run)
				local comma_separated_runs
				if need_tempcomma_undo then
					comma_separated_runs =
						put.split_alternating_runs_and_frob_raw_text(run, ",",
							memoize_require_dialect_tags().unescape_comma_whitespace)
				else
					comma_separated_runs = put.split_alternating_runs(run, ",")
				end
				local sub_links = {}

				local function parse_err(msg)
					local parts = {}
					for _, run in ipairs(comma_separated_runs) do
						table.insert(parts, table.concat(run))
					end
					error(msg .. ": " .. (i + 1) .. "=" .. table.concat(parts, ","))
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
						local prefix, arg = modtext:match("^([a-z]+):(.*)$")
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
								termobj.sc = require("Module:scripts").getByCode(arg, "" .. (i + 1) .. ":sc")
							elseif param_term_mod_set[prefix] then
								termobj[prefix] = arg
							elseif misc_list_param_set[prefix] then
								if j < #comma_separated_runs then
									parse_err("Modifier " .. run[k] .. " should come after the last term")
								end
								args["part" .. prefix][ind] = arg
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
						table.insert(sub_links, sub_link)
					end
				end
				link = table.concat(sub_links, "/")
			elseif term and term:find(",") then
				local sub_terms = memoize_require_dialect_tags().split_on_comma(term)
				local sub_links = {}
				for _, sub_term in ipairs(sub_terms) do
					reinit_termobj(sub_term)
					local sub_link = get_link()
					if sub_link ~= "" then
						table.insert(sub_links, sub_link)
					end
				end
				link = table.concat(sub_links, "/")
			else
				reinit_termobj(term)
				link = get_link()
			end

			local arrow = get_arrow(ind)
			local preqs = get_pre_qualifiers(ind)
			local postqs = get_post_qualifiers(ind)
			local alts

			if desc_tree and term and term ~= "-" then
				table.insert(seen_terms, term)
				-- This is what I ([[User:Benwing2]]) had in Nov 2020 when I first implemented this.
				-- Since then, [[User:Fytcha]] added `true` as the fourth param.
				-- descendants[ind] = m_desctree.getDescendants(entryLang, term, id, maxmaxindex > 1)
				descendants[ind] = m_desctree.getDescendants(lang, sc, term, id, true)
				if descendants[ind] then
					saw_descendants = true
				end
			end

			descendants[ind] = descendants[ind] or ""

			if term and (desc_tree and not args["noalts"] or not desc_tree and args["alts"]) then
				-- [[Special:WhatLinksHere/Template:tracking/descendant/alts]]
				track("alts")
				alts = m_desctree.getAlternativeForms(lang, sc, term, id)
			else
				alts = ""
			end

			local linktext = table.concat{preqs, link, alts, postqs}
			if not args["notext"] then
				linktext = arrow .. linktext
			end
			if linktext ~= "" then
				if i > 1 then
					table.insert(parts, terms[i - 1] == ";" and "; " or ", ")
				end
				table.insert(parts, linktext)
			end
		end
	end

	if error_on_no_descendants and desc_tree and not saw_descendants then
		if #seen_terms == 0 then
			error("[[Template:desctree]] invoked but no terms to retrieve descendants from")
		elseif #seen_terms == 1 then
			error("No Descendants section was found in the entry [[" .. seen_terms[1] ..
				"]] under the header for " .. lang:getNonEtymologicalName() .. ".")
		else
			for i, term in ipairs(seen_terms) do
				seen_terms[i] = "[[" .. term .. "]]"
			end
			error("No Descendants section was found in any of the entries " ..
				table.concat(seen_terms, ", ") .. " under the header for " .. lang:getNonEtymologicalName() .. ".")
		end
	end

	descendants = table.concat(descendants)
	if args["noparent"] then
		return descendants
	end

	local initial_arrow = get_arrow(0)
	local initial_preqs = get_pre_qualifiers(0)
	local final_postqs = get_post_qualifiers(0)

	if use_semicolon then
		for i = 2, #parts - 1, 2 do
			parts[i] = ";"
		end
	end

	local all_linktext = initial_preqs .. table.concat(parts) .. final_postqs .. descendants

	if args["notext"] then
		return all_linktext
	elseif args["nolb"] then
		return initial_arrow .. all_linktext
	else
		return table.concat{initial_arrow, label, ":", all_linktext ~= "" and " " or "", all_linktext}
	end
end

function export.descendant(frame)
	return desc_or_desc_tree(frame, false) .. require("Module:TemplateStyles")("Module:etymology/style.css")
end

function export.descendants_tree(frame)
	return desc_or_desc_tree(frame, true)
end

return export
