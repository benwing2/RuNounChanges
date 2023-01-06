local export = {}

local m_languages = require("Module:languages")
local m_demonym = require("Module:demonym")

local rsplit = mw.text.split
local u = mw.ustring.char


-- Return a param_mods structure as required by parse_inline_modifiers() in [[Module:parse utilities]]:
-- * `convert`: An optional function to convert the raw argument into the form needed for further processing.
--              This function takes two parameters: (1) `arg` (the raw argument); (2) `parse_err` (a function to
--              generate an error).
-- * `item_dest`: The name of the key used when storing the parameter's value into the processed object.
--                Normally the same as the parameter's name. Different in the case of "t", where we store the gloss in
--                "gloss", and "g", where we store the genders in "genders".
local function get_param_mods(termparam)
	return {
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
			-- We need a conversion function to convert from script codes to script objects, which needs to know the name
			-- of the parameter we're modifying. (This only affects the error message.)
			convert = function(arg, parse_err)
				return require("Module:scripts").getByCode(arg, "" .. termparam .. ":sc")
			end,
		}
	}
end


local function get_valid_prefixes(param_mods)
	local valid_prefixes = {}
	for param_mod, _ in pairs(param_mods) do
		table.insert(valid_prefixes, param_mod)
	end
	table.sort(valid_prefixes)
	return valid_prefixes
end


local function fetch_script(sc, param)
	return sc and require("Module:scripts").getByCode(sc, param) or nil
end


local function parse_args(args, hack_params)
	local params = {
		[1] = {required = true, default = "und"},
		[2] = {list = true, required = true},
		
		["t"] = {list = true},
		["sort"] = {},
		["nocat"] = {type = "boolean"},
		["nocap"] = {type = "boolean"},
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
	local function parse_err(msg)
		if not put then
			put = require("Module:parse utilities")
		end
		error(msg .. ": " .. paramname .. "=" .. put.escape_brackets(val))
	end

	local function generate_obj(term)
		local obj = {}
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

	return m_demonym.show_demonym_adj {
		lang = lang,
		parts = terms,
		gloss = glosses,
		sort = args.sort,
		nocat = args.nocat,
		nocap = args.nocap,
		notext = args.notext,
	}
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
