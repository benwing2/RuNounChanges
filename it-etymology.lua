local export = {}

local m_links = require("Module:links")
local m_languages = require("Module:languages")
local put_module = "Module:User:Benwing2/parse utilities"
local com_module = "Module:User:Benwing2/it-common"
local compound_module = "Module:compound"
local lang = m_languages.getByCode("it")

local rfind = mw.ustring.find
local rsubn = mw.ustring.gsub
local rsplit = mw.text.split
local u = mw.ustring.char
-- Assigned to `require("Module:parse utilities")` as necessary.
local put

local force_cat = false -- set to true for testing


-- version of rsubn() that discards all but the first return value
local function rsub(term, foo, bar)
	local retval = rsubn(term, foo, bar)
	return retval
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


local param_mods = {
	t = {
		-- We need to store the <t:...> inline modifier into the "gloss" key of the parsed part, because that is what
		-- [[Module:links]] expects.
		item_dest = "gloss",
	},
	gloss = {},
	tr = {},
	ts = {},
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
	sc = {
		convert = function(arg, parse_err)
			return require("Module:scripts").getByCode(arg, parse_err)
		end,
	},
	pl = {},
	type = {
		convert = function(arg, parse_err)
			if arg ~= "verb" and arg ~= "object" and arg ~= "connector" then
				parse_err(("Argument '%s' should be either 'verb', 'object' or 'connector'"):format(arg))
			end
			return arg
		end,
	},
}


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


local function parse_term_with_modifiers(paramname, val)
	local function generate_obj(term, parse_err)
		local obj = {}
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

	-- Check for inline modifier, e.g. מרים<tr:Miryem>. But exclude HTML entry with <span ...>, <i ...>, <br/> or
	-- similar in it, caused by wrapping an argument in {{l|...}}, {{m|...}} or similar. Basically, all tags of
	-- the sort we parse here should consist of a less-than sign, plus letters, plus a colon, e.g. <tr:...>, so if
	-- we see a tag on the outer level that isn't in this format, we don't try to parse it. The restriction to the
	-- outer level is to allow generated HTML inside of e.g. qualifier tags, such as foo<q:similar to {{m|fr|bar}}>.
	if val:find("<") then
		if not put then
			put = require(put_module)
		end
		return put.parse_inline_modifiers(val, paramname, param_mods, generate_obj, parse_err)
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
		local parsed = parse_term_with_modifiers(i, term)
		if not parsed.term:find("%[") then
			local parttype = parsed.type
			if not parttype then
				parttype = get_part_type(i, term)
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
		error("Need at least two numbered arguments to [[Template:it-verb-obj]]")
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
		error("Need at least two numbered arguments to [[Template:it-verb-verb]]")
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


return export
