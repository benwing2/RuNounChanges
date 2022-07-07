local export = {}

local m_languages = require("Module:languages")
local m_links = require("Module:links")
local rsplit = mw.text.split

local function wrap_span(text, lang, sc)
	return '<span class="' .. sc .. '" lang="' .. lang .. '">' .. text .. '</span>'
end

local param_mods = {"t", "alt", "tr", "ts", "pos", "lit", "id", "sc", "g", "q", "qq"}
-- Do m_table.listToSet(param_mods) inline, maybe saving memory?
local param_mod_set = {}
for _, param_mod in ipairs(param_mods) do
	param_mod_set[param_mod] = true
end

local m_dialect_tags
local function memoize_require_dialect_tags()
	if not m_dialect_tags then
		m_dialect_tags = require("Module:dialect tags")
	end
	return m_dialect_tags
end

-- Convert a raw tag= param (or nil) to a list of formatted dialect tags; unrecognized tags are passed through
-- unchanged. Return nil if nil passed in.
local function tags_to_dialects(lang, tags)
	if not tags then
		return nil
	end
	local m_dialect_tags = memoize_require_dialect_tags()
	return m_dialect_tags.make_dialects(m_dialect_tags.split_on_comma(tags), lang)
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
		local sc = require("Module:scripts").findBestScript(term, lang):getCode()
		local fragment = term:find("#")
		if fragment then
			link = "[[" .. args[2][maxindex] .. "|Thesaurus:" .. wrap_span(term:sub(1, fragment-1), lang:getCode(), sc) .. "]]"
		else
			link = "[[" .. args[2][maxindex] .. "|Thesaurus:" .. wrap_span(term, lang:getCode(), sc) .. "]]"
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
	params.tag = {}
	params.parttag = {list = "tag", allow_holes = true, require_index = true}

	local args = require("Module:parameters").process(frame:getParent().args, params)
	
	local nym_type = frame.args[1]
	local nym_type_class = string.gsub(nym_type, "%s", "-")
	local lang = m_languages.getByCode(args[1], 1)
	
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
			local termobj = {
				joiner = i > 1 and (args[2][i - 1] == ";" and "; " or ", ") or "",
				q = args["q"][syn],
				qq = args["qq"][syn],
				tag = args["parttag"][syn],
				term = {
					lang = lang, term = item, id = args["id"][syn],
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
					put = require("Module:parse utilities")
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
					if param_mod_set[prefix] or prefix == "tag" then
						local obj_to_set
						if prefix == "q" or prefix == "qq" or prefix == "tag" then
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
			elseif item and item:find(",", 1, true) then
				-- FIXME: Why is this here and when is it used?
				use_semicolon = true
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
		local preq_text
		if item.q or item.tag then
			local preq = tags_to_dialects(lang, item.tag)
			if item.q then
				preq = preq or {}
				table.insert(preq, item.q)
			end
			preq_text = require("Module:qualifier").format_qualifier(preq) .. " "
		else
			preq_text = ""
		end
		items[i] = item.joiner .. preq_text .. m_links.full_link(item.term)
			.. (item.qq and " " .. require("Module:qualifier").format_qualifier(item.qq) or "")
	end

	local dialects = tags_to_dialects(lang, args.tag)
	local tag_postq = dialects and " " .. memoize_require_dialect_tags().post_format_dialects(dialects) or ""
	return "<span class=\"nyms " .. nym_type_class .. "\"><span class=\"defdate\">" .. 
		mw.getContentLanguage():ucfirst(nym_type) .. ((#items > 1 or thesaurus ~= "") and "s" or "") ..
		":</span> " .. table.concat(items) .. tag_postq .. thesaurus .. "</span>"
end


return export
