local export = {}

local m_links = require("Module:links")
local affix_module = "Module:affix"
local parameter_utilities_module = "Module:parameter utilities"

local force_cat = false -- set to true for testing


local function verb_obj_or_verb_verb(data, frame, obj_or_verb)
	local parent_args = frame:getParent().args
	local object_or_verb = obj_or_verb == "obj" and "object" or "verb"
	local params = {
		[1] = {list = true, required = true, disallow_holes = true},
		["sort"] = {},
		["nocat"] = {type = "boolean"},
		["nocap"] = {type = "boolean"},
		["notext"] = {type = "boolean"},
	}

	local m_param_utils = require(parameter_utilities_module)

	local param_mods = m_param_utils.construct_param_mods {
		{default = true, require_index = true},
		{group = "link", exclude = {"tr", "ts", "sc"}},
		{group = {"q", "l", "ref"}},
		-- Override to have separate_no_index set so we have an overall lit=.
		{param = "lit", separate_no_index = true},
		{param = {"pl", "imp"}},
		{param = "type", set = {"verb", "object", "connector"}},
	}

	local items, args = m_param_utils.process_list_arguments {
		params = params,
		param_mods = param_mods,
		raw_args = parent_args,
		process_args_before_parsing = function(args)
			if #args[1] < 2 then
				local NAMESPACE = mw.title.getCurrentTitle().nsText
				if NAMESPACE == "Template" then
					for _, defarg in ipairs(data.default_args) do
						table.insert(args[1], defarg)
					end
				else
					error(("Need at least two numbered arguments to [[Template:%s-%s]]"):format(
						data.lang:getCode(), template_name))
				end
			end
		end,
		termarg = 1,
		track_module = "romance-etymology",
		parse_lang_prefix = true,
		-- Don't include `lang` because the code below expects it to be set only when explicitly given
	}

	for i, item in ipairs(items) do
		if not item.term:find("%[") then
			local parttype = item.type
			if not parttype then
				if i == 1 then
					parttype = "verb"
				elseif i == #items then
					parttype = object_or_verb
				else
					if data.looks_like_infinitive(item.term) then
						parttype = "verb"
					else
						parttype = "connector"
					end
				end
			end
			if parttype ~= "object" and item.pl then
				parse_err(("Can't specify <pl:...> with an argument that is not an object (argument type is '%s')"):
					format(parttype))
			end
			if parttype ~= "verb" and item.imp then
				parse_err(("Can't specify <imp:...> with an argument that is not a verb (argument type is '%s')"):
					format(parttype))
			end
			if parttype == "verb" then
				local imp
				item.imp = item.imp or "+"
				if item.imp:find("^%+") then
					if item.lang then
						parse_err(("Can't form default imperative given with explicit language code prefix '%s'"):
							format(item.lang:getCode()))
					end
					imp = data.make_imperative(item.imp, item.term, parse_err)
					if not imp then
						parse_err("Default imperative algorithm was unable to form the imperative")
					end
				elseif item.imp then
					imp = item.imp
				end
				if imp then
					item.term = ("[[%s|%s]]"):format(item.term, imp)
				end
			elseif parttype == "object" then
				local pl
				if item.pl == "1" or item.pl and item.pl:find("^%+") then
					if item.lang then
						parse_err(("Can't form default plural of term '%s' given with explicit language code prefix '%s'"):
							format(item.term, item.lang:getCode()))
					end
					pl = data.make_plural(item.pl, item.term, parse_err)
					if not pl then
						parse_err(("Default plural algorithm was unable to form the plural of term '%s'"):format(item.term))
					end
				elseif item.pl then
					pl = item.pl
				end
				if pl then
					item.term = ("[[%s|%s]]"):format(item.term, pl)
				end
			end
		end

		item.lang = item.lang or data.lang
		items[i] = m_links.full_link(item, "term", "allow self link", "show qualifiers")
	end

	local result = {}
	local function ins(text)
		table.insert(result, text)
	end

	if not args.notext then
		if args.nocap then
			ins("verb-" .. object_or_verb)
		else
			ins("Verb-" .. object_or_verb)
		end
		ins(" compound, composed of ")
	end

	ins(require(affix_module).join_formatted_parts {
		data = {
			lang = data.lang,
			nocat = args.nocat,
			sort_key = args.sort,
			lit = args.lit.default,
			force_cat = force_cat,
			q = args.q.default,
			qq = args.qq.default,
			l = args.l.default,
			ll = args.ll.default,
		},
		parts_formatted = items,
		categories = {("verb-%s compounds"):format(object_or_verb)},
	})
	return table.concat(result)
end


function export.verb_obj(data, frame)
	return verb_obj_or_verb_verb(data, frame, "obj")
end


function export.verb_verb(data, frame)
	return verb_obj_or_verb_verb(data, frame, "verb")
end


return export
