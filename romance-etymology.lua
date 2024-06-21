local export = {}

local m_links = require("Module:links")
local affix_module = "Module:affix"
local parameter_utilities_module = "Module:parameter utilities"
local parameters_module = "Module:parameters"
local pron_qualifier_module = "Module:pron qualifier"

local force_cat = false -- set to true for testing


local function glossary_link(entry, text)
	text = text or entry
	return "[[Appendix:Glossary#" .. entry .. "|" .. text .. "]]"
end


local function link_with_qualifiers(part, pretext)
	local partparts = {}
	if part.q then
		table.insert(partparts, require("Module:qualifier").format_qualifier(part.q) .. " ")
	end
	if pretext then
		table.insert(partparts, pretext)
	end
	table.insert(partparts, m_links.full_link(part, "term", "allow self link"))
	if part.qq then
		table.insert(partparts, " " .. require("Module:qualifier").format_qualifier(part.qq))
	end
	return table.concat(partparts)
end


local function parse_and_format_parts(data, parent_args, get_part_type)
	local params = {
		[1] = {list = true, required = true, disallow_holes = true},
		["lit"] = {},
		["sort"] = {},
		["nocat"] = {type = "boolean"},
		["nocap"] = {type = "boolean"},
		["notext"] = {type = "boolean"},
	}

	local m_param_utils = require(parameter_utilities_module)

	local param_mods = m_param_utils.construct_param_mods {
		{group = "link", exclude = {"tr", "ts", "sc"}},
		{group = {"q", "l", "ref"}},
		{param = {"pl", "imp"}},
		{param = "type", set = {"verb", "object", "connector"}},
	}

	m_param_utils.augment_params_with_modifiers(params, param_mods)

	local args = require(parameters_module).process(parent_args, params)

	local items = m_param_utils.process_list_arguments {
		args = args,
		param_mods = param_mods,
		termarg = 1,
		track_module = "romance-etymology",
		parse_lang_prefix = true,
		lang = data.lang,
	}

	for i, item in ipairs(items) do
		if not item.term:find("%[") then
			local parttype = parsed.type
			if not parttype then
				parttype = get_part_type {
					items = items,
					item = item,
					item_index = i,
				}
			end
			if parttype ~= "object" and parsed.pl then
				parse_err(("Can't specify <pl:...> with an argument that is not an object (argument type is '%s')"):
					format(parttype))
			end
			if parttype ~= "verb" and parsed.imp then
				parse_err(("Can't specify <imp:...> with an argument that is not a verb (argument type is '%s')"):
					format(parttype))
			end
			if parttype == "verb" then
				local imp
				parsed.imp = parsed.imp or "+"
				if parsed.imp:find("^%+") then
					if parsed.lang then
						parse_err(("Can't form default imperative given with explicit language code prefix '%s'"):
							format(parsed.lang:getCode()))
					end
					imp = data.make_imperative(parsed.imp, parsed.term, parse_err)
					if not imp then
						parse_err("Default imperative algorithm was unable to form the imperative")
					end
				elseif parsed.imp then
					imp = parsed.imp
				end
				if imp then
					parsed.term = ("[[%s|%s]]"):format(parsed.term, imp)
				end
			elseif parttype == "object" then
				local pl
				if parsed.pl == "1" or parsed.pl and parsed.pl:find("^%+") then
					if parsed.lang then
						parse_err(("Can't form default plural of term '%s' given with explicit language code prefix '%s'"):
							format(parsed.term, parsed.lang:getCode()))
					end
					pl = data.make_plural(parsed.pl, parsed.term, parse_err)
					if not pl then
						parse_err(("Default plural algorithm was unable to form the plural of term '%s'"):format(parsed.term))
					end
				elseif parsed.pl then
					pl = parsed.pl
				end
				if pl then
					parsed.term = ("[[%s|%s]]"):format(parsed.term, pl)
				end
			end
		end

		parsed.lang = parsed.lang or data.lang
		parts[i] = link_with_qualifiers(parsed)
	end

end


function export.verb_obj(data, frame)
	local parent_args = frame:getParent().args
	local items = parse_and_format_parts(data, parent_args, function(itemdata)
		local parttype
		if itemdata.item_index == 1 then
			parttype = "verb"
		elseif itemdata.item_index == #itemdata.items then
			parttype = "object"
		else
			local term = itemdata.item.term or itemdata.item.alt
			if term and data.looks_like_infinitive(term) then
				parttype = "verb"
			else
				parttype = "connector"
			end
		end
		return parttype
	end)


	if #args[1] < 2 then
	    local NAMESPACE = mw.title.getCurrentTitle().nsText
		if NAMESPACE == "Template" then
			for _, defarg in ipairs(data.default_args) do
				table.insert(args[1], defarg)
			end
		else
			error(("Need at least two numbered arguments to [[Template:%s-verb-obj]]"):format(data.lang:getCode()))
		end
	end

	result = {}
	local function ins(text)
		table.insert(result, text)
	end

	if not args.notext then
		if args.nocap then
			ins("verb-object")
		else
			ins("Verb-object")
		end
		ins(" compound, composed of ")
	end

	ins(require(affix_module).concat_parts(data.lang, args[1], {"verb-object compounds"}, args.nocat, args.sort, args.lit,
		force_cat))
	return table.concat(result)
end


function export.verb_verb(data, frame)
	local args = parse_args(frame:getParent().args)

	if #args[1] < 2 then
	    local NAMESPACE = mw.title.getCurrentTitle().nsText
		if NAMESPACE == "Template" then
			for _, defarg in ipairs(data.default_args) do
				table.insert(args[1], defarg)
			end
		else
			error(("Need at least two numbered arguments to [[Template:%s-verb-verb]]"):format(data.lang:getCode()))
		end
	end

	parse_and_format_parts(data, args[1], function(i, term)
		local parttype
		if i == 1 or i == #args[1] then
			parttype = "verb"
		elseif data.looks_like_infinitive(term) then
			parttype = "verb"
		else
			parttype = "connector"
		end
		return parttype
	end)

	result = {}
	local function ins(text)
		table.insert(result, text)
	end

	if not args.notext then
		if args.nocap then
			ins("verb-verb")
		else
			ins("Verb-verb")
		end
		ins(" compound, composed of ")
	end

	ins(require(affix_module).concat_parts(data.lang, args[1], {"verb-verb compounds"}, args.nocat, args.sort, args.lit,
		force_cat))
	return table.concat(result)
end


return export
