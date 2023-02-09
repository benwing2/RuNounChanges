local export = {}

local m_languages = require("Module:languages")
local m_demonym = require("Module:demonym")
local put_module = "Module:parse utilities"

local rsplit = mw.text.split
local u = mw.ustring.char
-- Assigned to `require("Module:parse utilities")` as necessary.
local put


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
	}
}


local function parse_args(args, hack_params)
	local params = {
		[1] = {required = true, default = "und"},
		[2] = {list = true, required = true},
		
		["t"] = {list = true},
		["sort"] = {},
		["nocat"] = {type = "boolean"},
		["nocap"] = {type = "boolean"},
		["nodot"] = {type = "boolean"},
		["notext"] = {type = "boolean"},
	}

	if hack_params then
		hack_params(params)
	end

	args = require("Module:parameters").process(args, params)
	local lang = m_languages.getByCode(args[1], 1)
	return args, lang
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
	if val:find("<") and not val:find("^[^<]*<[a-z]*[^a-z:]") then
		if not put then
			put = require(put_module)
		end
		return put.parse_inline_modifiers(val, paramname, param_mods, generate_obj, parse_err)
	else
		return generate_obj(val)
	end

	return part
end


local function get_terms_and_glosses(args)
	for i, term in ipairs(args[2]) do
		args[2][i] = parse_term_with_modifiers(i + 1, term)
	end
	for i, gloss in ipairs(args.t) do
		args.t[i] = parse_term_with_modifiers("t" .. (i == 1 and "" or i), gloss)
	end

	return args[2], args.t
end


function export.demonym_adj(frame)
	local args, lang = parse_args(frame:getParent().args)

	local terms, glosses = get_terms_and_glosses(args)

	return m_demonym.format_demonym_adj {
		lang = lang,
		parts = terms,
		gloss = glosses,
		sort = args.sort,
		nocat = args.nocat,
		nocap = args.nocap,
		nodot = args.nodot,
		notext = args.notext,
	}
end


function export.demonym_noun(frame)
	local function hack_params(params)
		params.g = {}
		params.m = {list = true}
		params.gloss_is_gendered = {type = "boolean"}
	end

	local args, lang = parse_args(frame:getParent().args, hack_params)

	local terms, glosses = get_terms_and_glosses(args)

	for i, m in ipairs(args.m) do
		args.m[i] = parse_term_with_modifiers("m" .. (i == 1 and "" or i), m)
	end

	return m_demonym.format_demonym_noun {
		lang = lang,
		parts = terms,
		gloss = glosses,
		m = args.m,
		g = args.g,
		sort = args.sort,
		nocat = args.nocat,
		nocap = args.nocap,
		nodot = args.nodot,
		notext = args.notext,
		gloss_is_gendered = args.gloss_is_gendered,
	}
end


return export
