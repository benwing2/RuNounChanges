local export = {}

local m_links = require("Module:links")
local put = require("Module:parse utilities")
local m_languages = require("Module:languages")
local com_module = "Module:it-common"
local compound_module = "Module:compound"
local lang = m_languages.getByCode("it")

local rfind = mw.ustring.find
local rsubn = mw.ustring.gsub
local rsplit = mw.text.split
local u = mw.ustring.char

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
	table.insert(partparts, m_links.full_link(part, nil, "allow self link"))
	if part.qq then
		table.insert(partparts, " " .. require("Module:qualifier").format_qualifier(part.qq))
	end
	return table.concat(partparts)
end


-- Return a param_mods structure as required by parse_inline_modifiers() in [[Module:parse utilities]]:
-- * `convert`: An optional function to convert the raw argument into the form needed for further processing.
--              This function takes two parameters: (1) `arg` (the raw argument); (2) `parse_err` (a function to
--              generate an error).
-- * `item_dest`: The name of the key used when storing the parameter's value into the processed object.
--                Normally the same as the parameter's name. Different in the case of "t", where we store the gloss in
--                "gloss", and "g", where we store the genders in "genders".
local param_mods = 
{
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

	args = require("Module:parameters").process(args, params)
	local lang = m_languages.getByCode(args[1], 1)
	return args, lang
end


local function parse_term_with_modifiers(paramname, val)
	local function generate_obj(term)
		local obj = {}
		local term, lang = put.parse_term_with_modifiers(paramname, ...)
		-- Parse off an initial language code (e.g. 'la:minūtia' or 'grc:[[σκῶρ|σκατός]]'). Also handle Wikipedia prefixes
		-- ('w:Abatemarco' or 'w:it:Colle Val d'Elsa').
		local termlang, actual_term = term:match("^([A-Za-z0-9._-]+):(.*)$")
		if termlang == "w" then
			local foreign_wikipedia, foreign_term = actual_term:match("^([A-Za-z0-9._-]+):(.*)$")
			if foreign_wikipedia then
				termlang = termlang .. ":" .. foreign_wikipedia
				actual_term = foreign_term
			end
			if actual_term:find("[%[%]]") then
				parse_err("Cannot have brackets following a Wikipedia (w:...) link; place the Wikipedia link inside the brackets")
			end
			term = ("[[%s:%s|%s]]"):format(termlang, actual_term, actual_term)
			termlang = nil
		elseif termlang then
			termlang = m_languages.getByCode(termlang, paramname, "allow etym")
			term = actual_term
		end

		obj.lang = termlang
		obj.term = term
		return obj
	end

	-- Check for inline modifier, e.g. מרים<tr:Miryem>. But exclude HTML entry with <span ...>, <i ...>, <br/> or
	-- similar in it, caused by wrapping an argument in {{l|...}}, {{m|...}} or similar. Basically, all tags of
	-- the sort we parse here should consist of a less-than sign, plus letters, plus a colon, e.g. <tr:...>, so if
	-- we see a tag on the outer level that isn't in this format, we don't try to parse it. The restriction to the
	-- outer level is to allow generated HTML inside of e.g. qualifier tags, such as foo<q:similar to {{m|fr|bar}}>.
	if val:find("<") and not val:find("^[^<]*<[a-z]*[^a-z:]") then
		if not put then
			put = require("Module:parse utilities")
		end
		local param_mods = get_param_mods(paramname)
		return put.parse_inline_modifiers(val, param_mods, generate_obj, parse_err)
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


function export.it_verb_obj(frame)
	local args = parse_args(frame:getParent().args)

	if #args[1] < 2 then
		error("Need at least two numbered arguments to [[Template:it-verb-obj]]")
	end
	for i, term in ipairs(args[1]) do
		local parsed = parse_term_with_modifiers(i + 1, term)
		if not parsed.term:find("%[") then
			local parttype = parsed.type
			if not parttype then
				if i == 1 then
					parttype = "verb"
				elseif i == #args[1] then
					parttype = "object"
				elseif term:find("[aei]re$") then
					parttype = "verb"
				else
					parttype = "connector"
				end
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
					pl = require(com_module).make_plural(parsed.term, "?")
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
		args[1][i] = link_with_qualifiers(parsed)
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

	ins(require(compound_module).concat_parts(lang, args[1], {"verb-object compounds"}, args.nocat, args.sort, args.lit,
		force_cat))
	return table.concat(result)
end


function export.demonym_noun(frame)
	local function hack_params(params)
		params.g = {}
		params.m = {list = true}
	end

	local args, lang = parse_args(frame:getParent().args)

	local terms, glosses = get_terms_and_glosses(args)

	for i, m in ipairs(args.m) do
		args.m[i] = parse_term_with_modifiers("m" .. (i == 1 and "" or i), m)
	end

	return m_demonym.show_demonym_noun {
		lang = lang,
		parts = terms
		gloss = glosses,
		m = args.m,
		g = args.g,
		sort = args.sort,
		nocat = args.nocat,
		nocap = args.nocap,
		notext = args.notext,
	}
end


return export
