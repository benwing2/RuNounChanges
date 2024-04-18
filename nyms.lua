local export = {}

local m_languages = require("Module:languages")
local m_links = require("Module:links")
local put_module = "Module:parse utilities"
local labels_module = "Module:labels"
local rsplit = mw.text.split

local param_mods = {"t", "alt", "tr", "ts", "pos", "lit", "id", "sc", "g", "q", "qq"}
-- Do m_table.listToSet(param_mods) inline, maybe saving memory?
local param_mod_set = {}
for _, param_mod in ipairs(param_mods) do
	param_mod_set[param_mod] = true
end


local function track(page)
	return require("Module:debug/track")("nyms/" .. page)
end


local function wrap_span(text, lang, sc)
	return '<span class="' .. sc .. '" lang="' .. lang .. '">' .. text .. '</span>'
end


local function split_on_comma(term)
	if term:find(",%s") then
		return require(put_module).split_on_comma(term)
	else
		return rsplit(term, ",")
	end
end


-- Convert a raw lb= param (or nil) to a list of label info objects of the format described in get_label_info() in
-- [[Module:labels]]). Unrecognized labels will end up with an unchanged display form. Return nil if nil passed in.
local function get_label_list_info(raw_lb, lang)
	if not raw_lb then
		return nil
	end
	return require(labels_module).get_label_list_info(split_on_comma(raw_lb), lang, "nocat")
end

local function get_thesaurus_text(lang, args, maxindex)
	local thesaurus
	local thesaurus_links = {}
	
	while args[2][maxindex] and args[2][maxindex]:find("^Thesaurus:") do
		for _, param_mod in ipairs(param_mods) do
			if args[param_mod][maxindex] then
				error("You cannot use named parameters with Thesaurus links, but saw " .. param_mod .. maxindex .. "=")
			end
		end
		local link
		local term = args[2][maxindex]:sub(11) -- remove Thesaurus: from beginning
		local sc = lang:findBestScript(term):getCode()
		local fragment = term:find("#")
		if fragment then
			link = "[[" .. args[2][maxindex] .. "#" .. lang:getCanonicalName() .. "|Thesaurus:" .. wrap_span(term:sub(1, fragment-1), lang:getCode(), sc) .. "]]"
		else
			link = "[[" .. args[2][maxindex] .. "#" .. lang:getCanonicalName() .. "|Thesaurus:" .. wrap_span(term, lang:getCode(), sc) .. "]]"
		end
		
		table.insert(thesaurus_links, 1, link)
		
		maxindex = maxindex - 1
	end
	
	if #thesaurus_links > 0 then
		thesaurus = (maxindex == 0 and "''see'' " or "; ''see also'' ")
			.. table.concat(thesaurus_links, ", ")
	end
	
	return thesaurus or "", maxindex
end

function export.nyms(frame)
	local list_with_holes = {list = true, allow_holes = true}
	local params = {
		[1] = {required = true, default = "und"},
		[2] = {list = true, allow_holes = true, required = true},
	}
	for _, param_mod in ipairs(param_mods) do
		params[param_mod] = list_with_holes
	end
	params.lb = {}
	params.partlb = {list = "lb", allow_holes = true, require_index = true}

	local parent_args = frame:getParent().args

	-- FIXME: Temporary error message.
	for arg, _ in pairs(parent_args) do
		if type(arg) == "string" and arg:find("^tag[0-9]*$") then
			local lbarg = arg:gsub("^tag", "lb")
			error(("Use %s= instead of %s="):format(lbarg, arg))
		end
	end

	local args = require("Module:parameters").process(parent_args, params, nil, "nyms", "nyms")
	
	local nym_type = frame.args[1]
	local nym_type_class = string.gsub(nym_type, "%s", "-")
	local langcode = args[1]
	local lang = m_languages.getByCode(langcode, 1)
	
	local maxindex = math.max(args[2].maxindex, args["alt"].maxindex, args["tr"].maxindex)
	local thesaurus, link_maxindex = get_thesaurus_text(lang, args, maxindex)
	
	local items = {}
	local put
	local use_semicolon = false

	local syn = 0
	for i = 1, link_maxindex do
		local item = args[2][i]
		if item and item:find("^Thesaurus:") then
			error("A link to Thesaurus must be the last in the list")
		end
		if item ~= ";" then
			syn = syn + 1
			-- Parse off an initial language code (e.g. 'la:minūtia' or 'grc:[[σκῶρ|σκατός]]'). Don't parse if there's a space
			-- after the colon (happens e.g. if the user uses {{desc|...}} inside of {{col}}; not clear it applies to nyms).
			local termlangcode, actual_term
			if item then
				termlangcode, actual_term = item:match("^([A-Za-z._-]+):([^ ].*)$")
			end
			local termlang
			-- Make sure that only real language codes are handled as language links, so as to not catch interwiki
			-- or namespaces links.
			if termlangcode and (
				mw.loadData("Module:languages/code to canonical name")[termlangcode] or
				mw.loadData("Module:etymology languages/code to canonical name")[termlangcode]
			) then
				-- -1 since i is one-based
				termlang = m_languages.getByCode(termlangcode, 2 + i - 1, "allow etym")
				item = actual_term
			else
				termlang = lang
				termlangcode = nil
			end
			local termobj = {
				joiner = i > 1 and (args[2][i - 1] == ";" and "; " or ", ") or "",
				q = args["q"][syn],
				qq = args["qq"][syn],
				lb = args["partlb"][syn],
				term = {
					lang = termlang, term = item, id = args["id"][syn],
					sc = args["sc"][syn] and require("Module:scripts").getByCode(args["sc"][syn], "sc" .. syn) or nil,
					alt = args["alt"][syn], tr = args["tr"][syn], ts = args["ts"][syn],
					gloss = args["t"][syn], lit = args["lit"][syn], pos = args["pos"][syn],
					genders = args["g"][syn] and rsplit(args["g"][syn], ",") or nil,
				},
			}
		
			-- Check for new-style argument, e.g. מרים<tr:Miryem>. But exclude HTML entry with <span ...>,
			-- <i ...>, <br/> or similar in it, caused by wrapping an argument in {{l|...}}, {{af|...}} or similar.
			-- Basically, all tags of the sort we parse here should consist of a less-than sign, plus letters,
			-- plus a colon, e.g. <tr:...>, so if we see a tag on the outer level that isn't in this format,
			-- we don't try to parse it. The restriction to the outer level is to allow generated HTML inside
			-- of e.g. qualifier tags, such as foo<q:similar to {{m|fr|bar}}>.
			if item and item:find("<") and not item:find("^[^<]*<[a-z]*[^a-z:]") then
				if not put then
					put = require(put_module)
				end
				local run = put.parse_balanced_segment_run(item, "<", ">")
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
					if param_mod_set[prefix] or prefix == "lb" then
						local obj_to_set
						if prefix == "q" or prefix == "qq" or prefix == "lb" then
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
					elseif prefix == "tag" then
						-- FIXME: Remove support for <tag:...> in favor of <lb:...>
						error("Use <lb:...> instead of <tag:...>")
					else
						parse_err("Unrecognized prefix '" .. prefix .. "' in modifier " .. run[j])
					end
				end
			elseif item and item:find(",", 1, true) then
				-- FIXME: Why is this here and when is it used?
				use_semicolon = true
			end
			-- If a separate language code was given for the term, display the language name as a right qualifier.
			-- Otherwise it may not be obvious that the term is in a separate language (e.g. if the main language is 'zh'
			-- and the term language is a Chinese lect such as Min Nan). But don't do this for Translingual terms, which
			-- are often added to the list of English and other-language terms.
			if termlangcode and termlangcode ~= langcode and termlangcode ~= "mul" then
				termobj.qq = {termlang:getCanonicalName(), termobj.qq}
			end
		table.insert(items, termobj)
		end
	end

	if use_semicolon then
		for i, item in ipairs(items) do
			if i > 1 then
				item.joiner = "; "
			end
		end
	end

	for i, item in ipairs(items) do
		local label_text = ""
		if item.lb then
			local labels = get_label_list_info(item.lb, lang)
			if labels then
				label_text = " " .. require(labels_module).format_processed_labels {
					labels = labels, lang = lang, open = "[", close = "]"
				}
			end
		end
		items[i] = item.joiner .. (item.q and require("Module:qualifier").format_qualifier(item.q) .. " " or "") .. m_links.full_link(item.term)
			.. (item.qq and " " .. require("Module:qualifier").format_qualifier(item.qq) or "") .. label_text
	end

	local labels = get_label_list_info(args.lb, lang)
	local label_postq = labels and " &mdash; " .. require(labels_module).format_processed_labels {
		labels = labels, lang = lang 
	} or ""
	return "<span class=\"nyms " .. nym_type_class .. "\"><span class=\"defdate\">" .. 
		mw.getContentLanguage():ucfirst(nym_type) .. ((#items > 1 or thesaurus ~= "") and "s" or "") ..
		":</span> " .. table.concat(items) .. label_postq .. thesaurus .. "</span>"
end


return export
