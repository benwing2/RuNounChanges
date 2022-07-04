local export = {}

local rsplit = mw.text.split
local u = mw.ustring.char
local TEMPCOMMA = u(0xFFF0)

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

local function escape_comma_whitespace(val)
	local need_tempcomma_undo = false
	if val:find(",%s") then
		-- We want to split on comma but not if followed by whitespace. Lua doesn't have negative lookahead
		-- assertions so it's a bit harder to do this. We do it by replacing comma followed by whitespace
		-- with a temporary char, doing the split and undoing the temporary char replacement.
		val = val:gsub(",(%s)", TEMPCOMMA .. "%1")
		need_tempcomma_undo = true
	end
	return val, need_tempcomma_undo
end

local function unescape_comma_whitespace(val)
	val = val:gsub(TEMPCOMMA, ",") -- assign to temp to discard second retval
	return val
end

local function split_on_comma(val)
	local escaped_val, need_tempcomma_undo = escape_comma_whitespace(val)
	escaped_val = rsplit(escaped_val, ",")
	if need_tempcomma_undo then
		escaped_val = unescape_comma_whitespace(escaped_val)
	return escaped_val
end

local function escape_comma_whitespace_in_alternating_run(run)
	local need_tempcomma_undo = false
	for i, seg in ipairs(run) do
		if i % 2 == 1 then
			local this_need_tempcomma_undo
			run[i], this_need_tempcomma_undo = escape_comma_whitespace(val)
			need_tempcomma_undo = need_tempcomma_undo or this_need_tempcomma_undo
		end
	end
	return need_tempcomma_undo
end

local function split_alternating_run_on_comma_and_unescape_comma_whitespace(run)
	return iut.split_alternating_runs_and_frob_raw_text(run, ",", false, unescape_comma_whitespace)
end

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

	-- Params that modify a descendant term (as also supported by {{l}}, {{m}}). 
	for _, term_mod in ipairs {"alt", "g", "id", "lit", "pos", "sc", "t", "tr", "ts"} do
		add_regular_list_param(term_mod)
	end
	-- Handle gloss= specially because it's an alias.
	add_regular_list_param("gloss", nil, "t")
	-- Boolean params indicating whether a descendant term (or all terms) are particular sorts of borrowings.
	for _, bortype in ipairs {"inh", "bor", "lbor", "slb", "translit", "der", "clq", "pclq", "sml", "unc"} do
		add_index_separated_list_param(bortype, "boolean")
	end
	-- Aliases of clq=.
	for _, calque_alias in ipairs {"cal", "calq", "calque"} do
		add_index_separated_list_param(calque_alias, "boolean", "clq")
	end
	-- Aliases of pclq=.
	for _, partial_calque_alias in ipairs {"pcal", "pcalq", "pcalque"} do
		add_index_separated_list_param(partial_calque_alias, "boolean", "pclq")
	end
	-- Miscellaneous list params.
	for _, misc_list_param in ipairs {"q", "qq", "tag"} do
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

	-- FIXME: Remove this after a few days.
	if parent_args.q or parent_args.q1 or parent_args.q2 or parent_args.q3 or parent_args.q4 or parent_args.q5
		or parent_args.q6 or parent_args.q7 or parent_args.q8 or parent_args.q9 then
		track("q")
		error("Please use qq= not q=. q= will be switching to put the qualifier *before* the term, not after.")
	end

	local args = require("Module:parameters").process(parent_args, params)

	if args.sandbox then
		if namespace == "" or namespace == "Reconstruction" then
			error("The sandbox module, Module:descendants tree/sandbox, should not be used in entries.")
		end
	end

	local m_desctree
	if desc_tree or args["alts"] then
		if args.sandbox or require("Module:yesno")(frame.args.sandbox, false) then
			m_desctree = require("Module:descendants tree/sandbox")
		else
			m_desctree = require("Module:descendants tree")
		end
	end

	local lang = args[1]
	local terms = args[2]

	if mw.title.getCurrentTitle().nsText == "Template" then
		lang = lang or "en"
		if #terms == 0 then
			terms = {"word"}
			terms.maxindex = 1
		end
	end

	local m_languages = require("Module:languages")
	lang = m_languages.getByCode(lang, 1, "allow etym")
	local entryLang = m_languages.getNonEtymological(lang)

	if not desc_tree and entryLang:getType() == "family" then
		error("Cannot use language family code in [[Template:desc]].")
	end

	if lang:getCode() ~= entryLang:getCode() then
		-- [[Special:WhatLinksHere/Template:tracking/descendant/etymological]]
		track("etymological")
		track("etymological/" .. lang:getCode())
	end

	local languageName = lang:getCanonicalName()

	local label

	if args["sclb"] then
		local sc = args["sc"][1] and require("Module:scripts").getByCode(args["sc"][1], "sc")
		local term = terms[1]
		if sc then
			label = sc:getCanonicalName()
		else
			label = require("Module:scripts").findBestScript(term, lang):getCanonicalName()
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
		return require("Module:alternative forms").make_dialects(split_on_comma(tags), lang)
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
				dialects = "&ndash; ''" .. table.concat(dialects, ", ") .. "''"
				-- Fixes the problem of '' being added to '' at the end of last dialect parameter
				dialects = dialects:gsub("''''", "")
				table.insert(postqs, dialects)
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
	local iut
	local use_semicolon = false

	-- If an individual term has a literal comma in it, use semicolons for all joiners. Otherwise we use semicolon
	-- only if the user specified a literal semicolon as a term.
	for i = 1, maxmaxindex do
		local term = terms[i]
		if term and term:find(",", 1, true) then
			use_semicolon = true
		end
	end

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

			local function get_link(term)
				local link = ""
				if term ~= "-" then -- including term == nil
					link = require("Module:links").full_link(
						{
							lang = entryLang,
							sc = sc,
							term = term,
							alt = alt,
							id = id,
							tr = tr,
							ts = ts,
							genders = g,
							gloss = gloss,
							pos = pos,
							lit = lit,
						},
						nil,
						true)
				elseif ts or gloss or #g > 0 then
					-- [[Special:WhatLinksHere/Template:tracking/descendant/no term]]
					track("no term")
					link = require("Module:links").full_link(
						{
							lang = entryLang,
							sc = sc,
							ts = ts,
							gloss = gloss,
							genders = g,
						},
						nil,
						true)
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
			if term and term:find("<") and not term:find("^[^<]*<[a-z]*[^a-z:]") then
				if not iut then
					iut = require("Module:inflection utilities")
				end
				local run = iut.parse_balanced_segment_run(term, "<", ">")
				local sub_terms = ...

				local function parse_err(msg)
					error(msg .. ": " .. (i + 1) .. "=" .. table.concat(run))
				end
				termobj.term.term = run[1]

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
						parse_err("Modifier " .. run[j] .. " lacks a prefix, should begin with one of '" ..
							table.concat(param_mods, ":', '") .. ":'")
					end
					if param_mod_set[prefix] then
						local obj_to_set
						if prefix == "q" or prefix == "qq" then
							obj_to_set = termobj
						else
							obj_to_set = termobj.term
						end
						if prefix == "t" then
							prefix = "gloss"
						elseif prefix == "g" then
							prefix = "genders"
							arg = rsplit(arg, ",")
						elseif prefix == "sc" then
							arg = require("Module:scripts").getByCode(arg, "" .. (i + 1) .. ":sc")
						end
						if obj_to_set[prefix] then
							parse_err("Modifier '" .. prefix .. "' occurs twice, second occurrence " .. run[j])
						end
						obj_to_set[prefix] = arg
					else
						parse_err("Unrecognized prefix '" .. prefix .. "' in modifier " .. run[j])
					end
				end
			if term and term:find(",") then
				local sub_terms = split_on_comma(term)
				local sub_links = {}
				for _, sub_term in ipairs(sub_terms) do
					local sub_link = get_link(sub_term)
					if sub_link ~= "" then
						table.insert(sub_links, sub_link)
					end
				end
				link = table.concat(sub_links, ", ")
			else
				link = get_link(term)
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
				descendants[ind] = m_desctree.getDescendants(entryLang, term, id, true)
				if descendants[ind] then
					saw_descendants = true
				end
			end

			descendants[ind] = descendants[ind] or ""

			if term and (desc_tree and not args["noalts"] or not desc_tree and args["alts"]) then
				-- [[Special:WhatLinksHere/Template:tracking/descendant/alts]]
				track("alts")
				alts = m_desctree.getAlternativeForms(entryLang, term, id)
			else
				alts = ""
			end

			local linktext = table.concat{preqs, link, alts, postqs}
			if not args["notext"] then
				linktext = arrow .. linktext
			end
			if linktext ~= "" then
				if i > 1 then
					table.insert(parts, (use_semicolon or terms[i - 1] == ";") and "; " or ", ")
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
				"]] under the header for " .. entryLang:getCanonicalName() .. ".")
		else
			for i, term in ipairs(seen_terms) do
				seen_terms[i] = "[[" .. term .. "]]"
			end
			error("No Descendants section was found in any of the entries " ..
				table.concat(seen_terms, ", ") .. " under the header for " .. entryLang:getCanonicalName() .. ".")
		end
	end

	descendants = table.concat(descendants)
	if args["noparent"] then
		return descendants
	end

	local initial_arrow = get_arrow(0)
	local initial_preqs = get_pre_qualifiers(0)
	local final_postqs = get_post_qualifiers(0)

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
