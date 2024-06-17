local export = {}

local m_links = require("Module:links")
local put_module = "Module:parse utilities"
local affix_module = "Module:affix"

local rfind = mw.ustring.find
local rsplit = mw.text.split
local u = mw.ustring.char
-- Assigned to `require("Module:parse utilities")` as necessary.
local put

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


local function get_param_mods(include_pl_and_type)
	local param_mods = {
		t = {
			-- We need to store the <t:...> inline modifier into the "gloss" key of the parsed part, because that is what
			-- [[Module:links]] expects.
			item_dest = "gloss",
		},
		gloss = {},
		-- no 'tr' or 'ts', doesn't make sense for Romance langs
		g = {
			-- We need to store the <g:...> inline modifier into the "genders" key of the parsed part, because that is what
			-- [[Module:links]] expects.
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
		-- no 'sc', doesn't make sense for Romance langs
	}
	if include_pl_and_type then
		param_mods.pl = {}
		param_mods.imp = {}
		param_mods.type = {
			convert = function(arg, parse_err)
				if arg ~= "verb" and arg ~= "object" and arg ~= "connector" then
					parse_err(("Argument '%s' should be either 'verb', 'object' or 'connector'"):format(arg))
				end
				return arg
			end,
		}
	end
	return param_mods
end


local function parse_args(args, hack_params)
	local params = {
		[1] = {list = true, required = true},
		["lit"] = {},
		["sort"] = {},
		["nocat"] = {type = "boolean"},
		["nocap"] = {type = "boolean"},
		["notext"] = {type = "boolean"},
	}

	if hack_params then
		hack_params(params)
	end

	return require("Module:parameters").process(args, params)
end


function export.parse_term_with_modifiers(paramname, val, pre_initialized_obj, include_pl_and_type)
	local function generate_obj(term, parse_err)
		local obj = pre_initialized_obj or {}
		if term:find(":") then
			if not put then
				put = require(put_module)
			end
			local actual_term, termlang = put.parse_term_with_lang(term, parse_err)
			obj.term = actual_term
			obj.lang = termlang
		else
			obj.term = term
		end
		return obj
	end

	-- Check for inline modifier, e.g. מרים<tr:Miryem>.
	if val:find("<") then
		if not put then
			put = require(put_module)
		end
		return put.parse_inline_modifiers(val, {
			paramname = paramname,
			param_mods = get_param_mods(include_pl_and_type),
			generate_obj = generate_obj,
		})
	else
		return generate_obj(val)
	end

	return part
end


local function parse_and_format_parts(data, parts, get_part_type)
	for i, term in ipairs(parts) do
		local parsed = export.parse_term_with_modifiers(i, term, nil, "include pl and type")
		local function parse_err(txt)
			-- FIXME: Consider passing in parse_err() from the outer caller.
			error(("%s: term '%s'"):format(txt, parsed.term))
		end
		if not parsed.term:find("%[") then
			local parttype = parsed.type
			if not parttype then
				parttype = get_part_type(i, parsed.term)
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
				if rfind(parsed.imp, "^%+") then
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
				if parsed.pl == "1" or parsed.pl and rfind(parsed.pl, "^%+") then
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
	local args = parse_args(frame:getParent().args)

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

	parse_and_format_parts(data, args[1], function(i, term)
		local parttype
		if i == 1 then
			parttype = "verb"
		elseif i == #args[1] then
			parttype = "object"
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
