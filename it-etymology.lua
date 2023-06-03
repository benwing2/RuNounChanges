local export = {}

local m_links = require("Module:links")
local m_languages = require("Module:languages")
local put_module = "Module:parse utilities"
local com_module = "Module:it-common"
local compound_module = "Module:compound"
local lang = m_languages.getByCode("it")

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
		-- no 'tr' or 'ts', doesn't make sense for Italian
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
		-- no 'sc', doesn't make sense for Italian
	}
	if include_pl_and_type then
		param_mods.pl = {}
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


local function parse_term_with_modifiers(paramname, val, pre_initialized_obj, include_pl_and_type)
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


local function form_imperative(inf, parse_err)
	local stem, ending = inf:match("^(.*)([aei]re)$")
	if not stem then
		parse_err(("Unrecognized infinitive '%s', doesn't end in -are, -ere or -ire"):format(inf))
	end
	if ending == "are" then
		return stem .. "a"
	else
		return stem .. "i"
	end
end


local function parse_and_format_parts(parts, get_part_type)
	for i, term in ipairs(parts) do
		local parsed = parse_term_with_modifiers(i, term, nil, "include pl and type")
		if not parsed.term:find("%[") then
			local parttype = parsed.type
			if not parttype then
				parttype = get_part_type(i, parsed.term)
			end
			if parttype ~= "object" and parsed.pl then
				parse_err(("Can't specify <pl:...> with an argument that is not an object (argument type is '%s')"):
					format(parttype))
			end
			if parttype == "verb" then
				if parsed.lang then
					parse_err(("Can't form imperative of term '%s' given with explicit language code prefix '%s'"):
						format(parsed.term, parsed.lang:getCode()))
				end
				local imperative = form_imperative(parsed.term, parse_err)
				parsed.term = ("[[%s|%s]]"):format(parsed.term, imperative)
			elseif parttype == "object" then
				local pl
				if parsed.pl == "1" then
					if parsed.lang then
						parse_err(("Can't form default plural of term '%s' given with explicit language code prefix '%s'"):
							format(parsed.term, parsed.lang:getCode()))
					end
					-- "Guess" a gender based on the ending. We can't pass in a "?" because then we'll get an error on terms ending in
					-- -a because they have different plurals depending on the gender.
					local gender = parsed.term:find("a$") and "f" or "m"
					pl = require(com_module).make_plural(parsed.term, gender)
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

		parsed.lang = parsed.lang or lang
		parts[i] = link_with_qualifiers(parsed)
	end

end


function export.it_verb_obj(frame)
	local args = parse_args(frame:getParent().args)

	if #args[1] < 2 then
	    local NAMESPACE = mw.title.getCurrentTitle().nsText
		if NAMESPACE == "Template" then
			table.insert(args[1], "lavare<t:to wash>")
			table.insert(args[1], "piatto<t:plates><pl:1>")
		else
			error("Need at least two numbered arguments to [[Template:it-verb-obj]]")
		end
	end

	parse_and_format_parts(args[1], function(i, term)
		local parttype
		if i == 1 then
			parttype = "verb"
		elseif i == #args[1] then
			parttype = "object"
		elseif term:find("[aei]re$") then
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

	ins(require(compound_module).concat_parts(lang, args[1], {"verb-object compounds"}, args.nocat, args.sort, args.lit,
		force_cat))
	return table.concat(result)
end


function export.it_verb_verb(frame)
	local args = parse_args(frame:getParent().args)

	if #args[1] < 2 then
	    local NAMESPACE = mw.title.getCurrentTitle().nsText
		if NAMESPACE == "Template" then
			table.insert(args[1], "lavare<t:to wash>")
			table.insert(args[1], "asciugare<t:dry>")
		else
			error("Need at least two numbered arguments to [[Template:it-verb-verb]]")
		end
	end

	parse_and_format_parts(args[1], function(i, term)
		return "verb"
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

	ins(require(compound_module).concat_parts(lang, args[1], {"verb-verb compounds"}, args.nocat, args.sort, args.lit,
		force_cat))
	return table.concat(result)
end


function export.it_deverbal(frame)
	local list_with_holes = { list = true, allow_holes = true }
	local params = {
		[1] = {required = true, list = true},
		
		["alt"] = list_with_holes,
		["t"] = list_with_holes,
		["gloss"] = {alias_of = "t", list = true, allow_holes = true},
		["g"] = list_with_holes,
		["id"] = list_with_holes,
		["lit"] = list_with_holes,
		["pos"] = list_with_holes,
		["q"] = list_with_holes,
		["qq"] = list_with_holes,
		-- no tr, ts or sc; not relevant for Italian

		["nocap"] = {type = "boolean"},
		["notext"] = {type = "boolean"},
		["nocat"] = {type = "boolean"},
		["sort"] = {},
		["pagename"] = {}, -- for testing
	}

	local args = require("Module:parameters").process(frame:getParent().args, params)

	if #args[1] == 0 then
	    local NAMESPACE = mw.title.getCurrentTitle().nsText
		if NAMESPACE == "Template" then
			table.insert(args[1], "cozzare<t:to collide, to crash>")
			args.pagename = "cozzo"
		else
			error("Internal error: Something went wrong with [[Module:parameters]]; it should not allow zero numbered arguments")
		end
	end

	local pagename = args.pagename or mw.title.getCurrentTitle().subpageText
	local suffix = pagename:match("([aeo])$")
	if not suffix then
		error(("Pagename '%s' does not end in a recognizable deverbal suffix -a, -e or -o"):format(pagename))
	end

	local suffix_obj = m_links.full_link({
		term = "-" .. suffix,
		lang = lang,
		id = "deverbal",
	}, "term")

	for i, term in ipairs(args[1]) do
		local parsed = parse_term_with_modifiers(i, term, {
			alt = args.alt[i],
			gloss = args.t[i],
			genders = args.g[i] and rsplit(args.g[i], ",") or nil,
			id = args.id[i],
			pos = args.pos[i],
			lit = args.lit[i],
			q = args.q[i],
			qq = args.qq[i],
		}, false)
		parsed.lang = parsed.lang or lang
		local formatted_part = link_with_qualifiers(parsed)
		args[1][i] = require(compound_module).concat_parts(lang, {formatted_part, suffix_obj},
			{"deverbals", "terms suffixed with -" .. suffix .. " (deverbal)"},
			args.nocat, args.sort, nil, force_cat) -- FIXME: should we support lit= here?
	end

	result = {}
	local function ins(text)
		table.insert(result, text)
	end

	if not args.notext then
		if args.nocap then
			ins(glossary_link("Appendix:deverbal", "deverbal"))
		else
			ins(glossary_link("Appendix:deverbal", "Deverbal"))
		end
		ins(" from ")
	end

	if #args[1] == 1 then
		ins(args[1][1])
	else
		ins(require("Module:table").serialCommaJoin(args[1], {conj = "or"}))
	end

	return table.concat(result)
end


return export
