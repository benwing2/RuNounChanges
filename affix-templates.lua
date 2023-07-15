local export = {}

local m_affix = require("Module:affix")
local m_languages = require("Module:languages")
local put -- initialized once, when needed, to require("Module:parse utilities")

local rsplit = mw.text.split


-- Per-param modifiers, which can be specified either as separate parameters (e.g. t2=, pos3=) or as inline modifiers
-- <t:...>, <pos:...>, etc. The key is the name fo the parameter (e.g. "t", "pos") and the value is a table with
-- elements as follows:
-- * `extra_specs`: An optional table of extra key-value pairs to add to the spec used for parsing the parameter
--                  when specified as a separate parameter (e.g. {type = "boolean"} for a Boolean parameter, or
--                  {alias_of = "t"} for the "gloss" parameter, which is aliased to "t"), on top of the default, which
--                  is {list = true, allow_holes = true, require_index = true}.
-- * `convert`: An optional function to convert the raw argument into the form passed to [[Module:affix]].
--              This function takes four parameters: (1) `arg` (the raw argument); (2) `inline` (true if we're
--              processing an inline modifier, false otherwise); (3) `term_index` (the actual index of the first term);
--              (4) `i` (the logical index of the term being processed, starting from 1).
-- * `item_dest`: The name of the key used when storing the parameter's value into the processed `parts` list.
--                Normally the same as the parameter's name. Different in the case of "t", where we store the gloss in
--                "gloss", and "g", where we store the genders in "genders".
-- * `param_key`: The name of the key used in the `params` spec passed to [[Module:parameters]]. Normally the same as
--                the parameter's name. Different in the case of "lit", "sc", etc. where e.g. we distinguish per-term
--                parameters "lit1", "lit2", etc. from the overall parameter "lit".
local param_mods = {
	t = {
		-- We need to store the t1=/t2= param and the <t:...> inline modifier into the "gloss" key of the parsed part,
		-- because that is what [[Module:affix]] expects.
		item_dest = "gloss",
	},
	gloss = {
		-- The `extra_specs` handles the fact that "gloss" is an alias of "t".
		extra_specs = {alias_of = "t"},
	},
	tr = {},
	ts = {},
	g = {
		-- We need to store the g1=/g2= param and the <g:...> inline modifier into the "genders" key of the parsed part,
		-- because that is what [[Module:affix]] expects.
		item_dest = "genders",
		convert = function(arg, inline, term_index, i)
			return rsplit(arg, ",")
		end,
	},
	id = {},
	alt = {},
	q = {},
	qq = {},
	lit = {
		-- lit1=, lit2=, ... are different from lit=; the former describe the literal meaning of an individual argument
		-- while the latter applies to the expression as a whole and appears after them at the end. To handle this in
		-- separate parameters, we need to set the key in the `params` object passed to [[Module:parameters]] to
		-- something else (in this case "partlit") and set `list = "lit"` in the value of the `params` object. This
		-- causes [[Module:parameters]] to fetch parameters named lit1=, lit2= etc. but store them into "partlit", while
		-- lit= is stored into "lit".
		param_key = "partlit",
		extra_specs = {list = "lit"},
	},
	pos = {
		-- pos1=, pos2=, ... are different from pos=; the former indicate the part of speech of an individual argument
		-- and appear in parens after the term (similar to the pos= argument to {{l}}), while the latter applies to the
		-- expression as a whole and controls the names of various categories. We handle the distinction identically to
		-- lit1= etc. vs. lit=; see above.
		param_key = "partpos",
		extra_specs = {list = "pos"},
	},
	lang = {
		-- lang1=, lang2=, ... are different from 1=; the former set the language of individual arguments that are
		-- different from the overall language specified in 1=. Note that the preferred way of specifying a different
		-- language for a given individual argument is using a language-code prefix, e.g. 'la:minūtia' or
		-- 'grc:[[σκῶρ|σκατός]]', instead of using langN=. Since for compatibility purposes we may support lang= as
		-- a synonym of 1=, we can't store langN= in "lang". Instead we do the same as for lit1= etc. vs. lit= above.
		-- In addition, we need a conversion function to convert from language codes to language objects, which needs
		-- to conditionalize the `param` parameter of `getByCode` of [[Module:languages]] on whether the param is
		-- inline. (This only affects the error message.)
		param_key = "partlang",
		extra_specs = {list = "lang"},
		convert = function(arg, inline, term_index, i)
			-- term_index + i - 1 because we want to reference the actual term param name, which offsets from
			-- `term_index` (the index of the first term); subtract 1 since i is one-based.
			return m_languages.getByCode(arg, inline and "" .. (term_index + i - 1) .. ":lang" or "lang" .. i, "allow etym")
		end,
	},
	sc = {
		-- sc1=, sc2=, ... are different from sc=; the former apply to individual arguments when lang1=, lang2=, ...
		-- is specified, while the latter applies to all arguments where langN=... isn't specified. We handle the
		-- distinction identically to lit1= etc. vs. lit=; see above. In addition, we need a conversion function to
		-- convert from script codes to script objects, which needs to conditionalize the `param` parameter of
		-- `getByCode` of [[Module:scripts]] on whether the param is inline. (This only affects the error message.)
		param_key = "partsc",
		extra_specs = {list = "sc"},
		convert = function(arg, inline, term_index, i)
			-- term_index + i - 1 same as above for "lang".
			return require("Module:scripts").getByCode(arg, inline and "" .. (term_index + i - 1) .. ":sc" or "sc" .. i)
		end,
	},
}


local function get_valid_prefixes()
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


-- Parse raw arguments in `args`. If `extra_params` is specified, it should be a one-argument function that is called
-- on the `params` structure before parsing; its purpose is to specify additional allowed parameters or possibly disable
-- parameters. If `has_source` is given, there is a source-language parameter following 1= (which becomes the
-- "destination" language parameter) and preceding the terms. This is currently used for {{pseudo-loan}}. The
-- source-language parameter is allowed to be an etymology-only language while the language in 1= is currently not so
-- allowed (FIXME: should we change this?). Returns five values ARGS, TERM_INDEX, LANG_OBJ, SCRIPT_OBJ, SOURCE_LANG_OBJ
-- where ARGS is a table of the parsed arguments; TERM_INDEX is the argument containing all the terms; LANG_OBJ is the
-- language object corresponding to the language code specified in 1=; SCRIPT_OBJ is the script object corresponding to
-- sc= (if given, otherwise nil); and SOURCE_LANG_OBJ is the language object corresponding to the source-language code
-- specified in 2= if `has_source` is specified (otherwise nil).
local function parse_args(args, extra_params, has_source, ilangcode)
	if args.lang then
		error("The |lang= parameter is not used by this template. Place the language code in parameter 1 instead.")
	end

	local term_index = (ilangcode and 1 or 2) + (has_source and 1 or 0)
	local params = {
		[term_index] = {list = true, allow_holes = true},

		["lit"] = {},
		["sc"] = {},
		["pos"] = {},
		["sort"] = {},
	}

	if not ilangcode then
		params[1] = {required = true, default = "und"}
	end

	local source_index
	if has_source then
		source_index = term_index - 1
		params[source_index] = {required = true, default = "und"}
	end

	local default_param_spec = {list = true, allow_holes = true, require_index = true}
	for param_mod, param_mod_spec in pairs(param_mods) do
		local param_key = param_mod_spec.param_key or param_mod
		if not param_mod_spec.extra_specs then
			params[param_key] = default_param_spec
		else
			local param_spec = mw.clone(default_param_spec)
			for k, v in pairs(param_mod_spec.extra_specs) do
				param_spec[k] = v
			end
			params[param_key] = param_spec
		end
	end

	if extra_params then
		extra_params(params)
	end

	args = require("Module:parameters").process(args, params)
	local lang
	if ilangcode then
		lang = m_languages.getByCode(ilangcode, true)
	else
		lang = m_languages.getByCode(args[1], 1)
	end
	local source
	if has_source then
		source = m_languages.getByCode(args[source_index], source_index, "allow etym")
	end
	return args, term_index, lang, fetch_script(args["sc"], "sc"), source
end


-- Return an object containing all the properties of the `i`th term. `template` is the name of the calling template
-- (used only in the debug-tracking mechanism). `args` is the arguments as returned by parse_args(). `term_index` is
-- the argument containing all the terms. This handles all the complexities of fetching all the properties associated
-- with a term either out of separate parameters (e.g. pos3=, g2=) or from inline modifiers (e.g.
-- 'term<pos:noun><g:m-p>'). It also handles parsing off a separate language code attached to the beginning of a term or
-- specified using langN= or <lang:CODE>.
local function get_parsed_part(template, args, term_index, i)
	local part = {}
	local term = args[term_index][i]

	if not (term or args["alt"][i] or args["tr"][i] or args["ts"][i]) then
		require("Module:debug/track")(template .. "/no term or alt or tr")
		return nil
	end

	-- Parse all the term-specific parameters and store in `part`.
	for param_mod, param_mod_spec in pairs(param_mods) do
		local dest = param_mod_spec.item_dest or param_mod
		local param_key = param_mod_spec.param_key or param_mod
		local arg = args[param_key][i]
		if arg then
			if param_mod_spec.convert then
				arg = param_mod_spec.convert(arg, false, term_index, i)
			end
			part[dest] = arg
		end
	end

	-- Remove and remember an initial exclamation point from the term, and parse off an initial language code (e.g.
	-- 'la:minūtia' or 'grc:[[σκῶρ|σκατός]]').
	if term then
		local termlang, actual_term = term:match("^([A-Za-z0-9._-]+):(.*)$")
		if termlang and termlang ~= "w" then -- special handling for w:... links to Wikipedia
			-- -1 since i is one-based
			termlang = m_languages.getByCode(termlang, term_index + i - 1, "allow etym")
			term = actual_term
		else
			termlang = nil
		end
		if part.lang and termlang then
			error(("Both lang%s= and a language in %s= given; specify one or the other"):format(i, i + 1))
		end
		part.lang = part.lang or termlang
		part.term = term
	end

	-- Check for inline modifier, e.g. מרים<tr:Miryem>. But exclude HTML entry with <span ...>, <i ...>, <br/> or
	-- similar in it, caused by wrapping an argument in {{l|...}}, {{af|...}} or similar. Basically, all tags of
	-- the sort we parse here should consist of a less-than sign, plus letters, plus a colon, e.g. <tr:...>, so if
	-- we see a tag on the outer level that isn't in this format, we don't try to parse it. The restriction to the
	-- outer level is to allow generated HTML inside of e.g. qualifier tags, such as foo<q:similar to {{m|fr|bar}}>.
	if term and term:find("<") and not term:find("^[^<]*<[a-z]*[^a-z:]") then
		if not put then
			put = require("Module:parse utilities")
		end
		local run = put.parse_balanced_segment_run(term, "<", ">")
		local function parse_err(msg)
			error(msg .. ": " .. (i + 1) .. "=" .. table.concat(run))
		end
		part.term = run[1]

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
				parse_err(("Modifier %s lacks a prefix, should begin with one of %s followed by a colon"):format(
					run[j], table.concat(get_valid_prefixes(), ",")))
			end
			if not param_mods[prefix] then
				parse_err(("Unrecognized prefix '%s' in modifier %s, should be one of %s"):format(
					prefix, run[j], table.concat(get_valid_prefixes(), ",")))
			end
			local dest = param_mods[prefix].item_dest or prefix
			if part[dest] then
				parse_err("Modifier '" .. prefix .. "' occurs twice, second occurrence " .. run[j])
			end
			if param_mods[prefix].convert then
				arg = param_mods[prefix].convert(arg, true, term_index, i)
			end
			part[dest] = arg
		end
	end

	return part
end


-- Return an array of objects describing all the terms specified by the user. The meat of the work is done by
-- get_parsed_part(). `template`, `args` and `term_index` are as in get_parsed_part() and are required. Optional
-- `max_terms_allowed` restricts the number of terms that can be specified, and optional `start_index` specifies the
-- first index in the user-specified terms under the `term_index` argument to pull terms out of, defaulting to 1.
-- Currently only suffix() specifies a value for `start_index`, because the first term is handled differently by
-- suffix() compared with all the remaining terms.
local function get_parsed_parts(template, args, term_index, max_terms_allowed, start_index)
	local parts = {}
	start_index = start_index or 1

	-- Find the maximum index among any of the list parameters.
	local maxmaxindex = 0
	for k, v in pairs(args) do
		if type(v) == "table" and v.maxindex and v.maxindex > maxmaxindex then
			if max_terms_allowed and v.maxindex > max_terms_allowed then
				-- Try to determine the original parameter name associated with v.maxindex.
				if type(k) == "number" then
					-- Subtract one because e.g. if terms start at 2, the 4th term is in 5=.
					arg = k + v.maxindex - 1
				else
					arg = k .. v.maxindex
				end
				error(("In [[Template:%s|%s]], at most %s terms can be specified but argument %s specified, corresponding to term #%s")
					:format(template, template, max_terms_allowed, arg, v.maxindex))
			end
			maxmaxindex = v.maxindex
		end
	end

	for index = start_index, maxmaxindex do
		local part = get_parsed_part(template, args, term_index, index)
		parts[index - start_index + 1] = part
	end

	return parts
end


function export.affix(frame)
	local function extra_params(params)
		params["type"] = {}
		params["nocap"] = {type = "boolean"}
		params["notext"] = {type = "boolean"}
		params["nocat"] = {type = "boolean"}
		params["force_cat"] = {type = "boolean"}
	end

	local args, term_index, lang, sc = parse_args(frame:getParent().args, extra_params)

	if args["type"] and not m_affix.compound_types[args["type"]] then
		error("Unrecognized compound type: '" .. args["type"] .. "'")
	end

	local parts = get_parsed_parts("affix", args, term_index)

	-- There must be at least one part to display. If there are gaps, a term
	-- request will be shown.
	if not next(parts) and not args["type"] then
		if mw.title.getCurrentTitle().nsText == "Template" then
			parts = { {term = "prefix-"}, {term = "base"}, {term = "-suffix"} }
		else
			error("You must provide at least one part.")
		end
	end

	return m_affix.show_affixes(lang, sc, parts, args["pos"], args["sort"],
		args["type"], args["nocap"], args["notext"], args["nocat"], args["lit"], args["force_cat"])
end

function export.compound(frame)
	local function extra_params(params)
		params["type"] = {}
		params["nocap"] = {type = "boolean"}
		params["notext"] = {type = "boolean"}
		params["nocat"] = {type = "boolean"}
		params["force_cat"] = {type = "boolean"}
	end

	local args, term_index, lang, sc = parse_args(frame:getParent().args, extra_params)

	if args["type"] and not m_affix.compound_types[args["type"]] then
		error("Unrecognized compound type: '" .. args["type"] .. "'")
	end

	local parts = get_parsed_parts("compound", args, term_index)

	-- There must be at least one part to display. If there are gaps, a term
	-- request will be shown.
	if not next(parts) and not args["type"] then
		if mw.title.getCurrentTitle().nsText == "Template" then
			parts = { {term = "first"}, {term = "second"} }
		else
			error("You must provide at least one part of a compound.")
		end
	end

	return m_affix.show_compound(lang, sc, parts, args["pos"], args["sort"],
		args["type"], args["nocap"], args["notext"], args["nocat"], args["lit"], args["force_cat"])
end


function export.compound_like(frame)
	local iparams = {
		["lang"] = {},
		["template"] = {},
		["text"] = {},
		["oftext"] = {},
		["cat"] = {},
	}

	local iargs = require("Module:parameters").process(frame.args, iparams, nil, "affix/templates", "compound_like")
	local parent_args = frame:getParent().args

	local function extra_params(params)
		params["pos"] = nil
		params["nocap"] = {type = "boolean"}
		params["notext"] = {type = "boolean"}
		params["nocat"] = {type = "boolean"}
		params["force_cat"] = {type = "boolean"}
	end

	local args, term_index, lang, sc = parse_args(parent_args, extra_params, nil, iargs.lang)

	local template = iargs["template"]
	local nocat = args["nocat"]
	local notext = args["notext"]
	local text = not notext and iargs["text"]
	local oftext = not notext and (iargs["oftext"] or text and "of")
	local cat = not nocat and iargs["cat"]

	local parts = get_parsed_parts(template, args, term_index)

	if not next(parts) then
		if mw.title.getCurrentTitle().nsText == "Template" then
			parts = { {term = "first"}, {term = "second"} }
		end
	end

	return m_affix.show_compound_like(lang, sc, parts, args["sort"], text, oftext, cat, args["nocat"], args["lit"], args["force_cat"])
end


function export.surface_analysis(frame)
	local function ine(arg)
		-- Since we're operating before calling [[Module:parameters]], we need to imitate how that module processes arguments,
		-- including trimming since numbered arguments don't have automatic whitespace trimming.
		if not arg then
			return arg
		end
		arg = mw.text.trim(arg)
		if arg == "" then
			arg = nil
		end
		return arg
	end

	local parent_args = frame:getParent().args
	local etymtext
	local arg1 = ine(parent_args[1])
	if not arg1 then
		-- Allow omitted first argument to just display "By surface analysis".
		etymtext = ""
	elseif arg1:find("^%+") then
		-- If the first argument (normally a language code) is prefixed with a +, it's a template name.
		local template_name = arg1:sub(2)
		local new_args = {}
		for i, v in pairs(parent_args) do
			if type(i) == "number" then
				if i > 1 then
					new_args[i - 1] = v
				end
			else
				new_args[i] = v
			end
		end
		new_args.nocap = true
		etymtext = ", " .. frame:expandTemplate { title = template_name, args = new_args }
	end

	if etymtext then
		return (ine(parent_args.nocap) and "b" or "B") .. "y [[Appendix:Glossary#surface analysis|surface analysis]]" .. etymtext
	end

	local function extra_params(params)
		params["type"] = {}
		params["nocap"] = {type = "boolean"}
		params["notext"] = {type = "boolean"}
		params["nocat"] = {type = "boolean"}
		params["force_cat"] = {type = "boolean"}
	end

	local args, term_index, lang, sc = parse_args(parent_args, extra_params)

	if args["type"] and not m_affix.compound_types[args["type"]] then
		error("Unrecognized compound type: '" .. args["type"] .. "'")
	end

	local parts = get_parsed_parts("surface analysis", args, term_index)

	-- There must be at least one part to display. If there are gaps, a term
	-- request will be shown.
	if not next(parts) then
		if mw.title.getCurrentTitle().nsText == "Template" then
			parts = { {term = "first"}, {term = "second"} }
		else
			error("You must provide at least one part.")
		end
	end

	return m_affix.show_surface_analysis(lang, sc, parts, args["pos"], args["sort"],
		args["type"], args["nocap"], args["notext"], args["nocat"], args["lit"], args["force_cat"])
end


function export.circumfix(frame)
	local function extra_params(params)
		params["nocat"] = {type = "boolean"}
		params["force_cat"] = {type = "boolean"}
	end

	local args, term_index, lang, sc = parse_args(frame:getParent().args, extra_params)

	local parts = get_parsed_parts("circumfix", args, term_index, 3)
	local prefix = parts[1]
	local base = parts[2]
	local suffix = parts[3]

	-- Just to make sure someone didn't use the template in a silly way
	if not (prefix and base and suffix) then
		if mw.title.getCurrentTitle().nsText == "Template" then
			prefix = {term = "circumfix", alt = "prefix"}
			base = {term = "base"}
			suffix = {term = "circumfix", alt = "suffix"}
		else
			error("You must specify a prefix part, a base term and a suffix part.")
		end
	end

	return m_affix.show_circumfix(lang, sc, prefix, base, suffix, args["pos"], args["sort"], args["nocat"], args["lit"], args["force_cat"])
end


function export.confix(frame)
	local function extra_params(params)
		params["nocat"] = {type = "boolean"}
		params["force_cat"] = {type = "boolean"}
	end

	local args, term_index, lang, sc = parse_args(frame:getParent().args, extra_params)

	local parts = get_parsed_parts("confix", args, term_index, 3)
	local prefix = parts[1]
	local base = #parts >= 3 and parts[2] or nil
	local suffix = #parts >= 3 and parts[3] or parts[2]

	-- Just to make sure someone didn't use the template in a silly way
	if not (prefix and suffix) then
		if mw.title.getCurrentTitle().nsText == "Template" then
			prefix = {term = "prefix"}
			suffix = {term = "suffix"}
		else
			error("You must specify a prefix part, an optional base term and a suffix part.")
		end
	end

	return m_affix.show_confix(lang, sc, prefix, base, suffix, args["pos"], args["sort"], args["nocat"], args["lit"], args["force_cat"])
end


function export.pseudo_loan(frame)
	local function extra_params(params)
		params["pos"] = nil
		params["nocap"] = {type = "boolean"}
		params["notext"] = {type = "boolean"}
		params["nocat"] = {type = "boolean"}
		params["force_cat"] = {type = "boolean"}
	end

	local args, term_index, lang, sc, source = parse_args(frame:getParent().args, extra_params, "has source")

	local parts = get_parsed_parts("pseudo-loan", args, term_index)

	return require("Module:affix/pseudo-loan").show_pseudo_loan(lang, source, sc, parts, args["sort"],
		args["nocap"], args["notext"], args["nocat"], args["lit"], args["force_cat"])
end


function export.infix(frame)
	local function extra_params(params)
		params["nocat"] = {type = "boolean"}
		params["force_cat"] = {type = "boolean"}
	end

	local args, term_index, lang, sc = parse_args(frame:getParent().args, extra_params)

	local parts = get_parsed_parts("infix", args, term_index, 2)
	local base = parts[1]
	local infix = parts[2]

	-- Just to make sure someone didn't use the template in a silly way
	if not (base and infix) then
		if mw.title.getCurrentTitle().nsText == "Template" then
			base = {term = "base"}
			infix = {term = "infix"}
		else
			error("You must provide a base term and an infix.")
		end
	end

	return m_affix.show_infix(lang, sc, base, infix, args["pos"], args["sort"], args["nocat"], args["lit"], args["force_cat"])
end


function export.prefix(frame)
	local function extra_params(params)
		params["nocat"] = {type = "boolean"}
		params["force_cat"] = {type = "boolean"}
	end

	local args, term_index, lang, sc = parse_args(frame:getParent().args, extra_params)

	local prefixes = get_parsed_parts("prefix", args, term_index)
	local base = nil

	if #prefixes >= 2 then
		base = prefixes[#prefixes]
		prefixes[#prefixes] = nil
	end

	-- Just to make sure someone didn't use the template in a silly way
	if #prefixes == 0 then
		if mw.title.getCurrentTitle().nsText == "Template" then
			base = {term = "base"}
			prefixes = { {term = "prefix"} }
		else
			error("You must provide at least one prefix.")
		end
	end

	return m_affix.show_prefixes(lang, sc, prefixes, base, args["pos"], args["sort"], args["nocat"], args["lit"], args["force_cat"])
end


function export.suffix(frame)
	local function extra_params(params)
		params["nocat"] = {type = "boolean"}
		params["force_cat"] = {type = "boolean"}
	end

	local args, term_index, lang, sc = parse_args(frame:getParent().args, extra_params)

	local base = get_parsed_part("suffix", args, term_index, 1)
	local suffixes = get_parsed_parts("suffix", args, term_index, nil, 2)

	-- Just to make sure someone didn't use the template in a silly way
	if #suffixes == 0 then
		if mw.title.getCurrentTitle().nsText == "Template" then
			base = {term = "base"}
			suffixes = { {term = "suffix"} }
		else
			error("You must provide at least one suffix.")
		end
	end

	return m_affix.show_suffixes(lang, sc, base, suffixes, args["pos"], args["sort"], args["nocat"], args["lit"], args["force_cat"])
end


function export.derivsee(frame)
	local iargs = frame.args
	local iparams = {
		["derivtype"] = {},
		["mode"] = {},
	}
	local iargs = require("Module:parameters").process(frame.args, iparams)

	local params = {
		["head"] = {},
		["id"] = {},
		["sc"] = {},
		["pos"] = {},
	}
	local derivtype = iargs.derivtype
	if derivtype == "PIE root" then
		params[1] = {}
	else
		params[1] = {required = "true", default = "und"}
		params[2] = {}
	end

	local args = require("Module:parameters").process(frame:getParent().args, params)

	local lang
	local term

	if derivtype == "PIE root" then
		lang = m_languages.getByCode("ine-pro")
		term = args[1] or args["head"]

		if term then
			term = "*" .. term .. "-"
		end
	else
		lang = m_languages.getByCode(args[1], 1)
		term = args[2] or args["head"]
	end

	local id = args.id
	local sc = fetch_script(args.sc, "sc")
	local pos = require("Module:string utilities").pluralize(args.pos or "term")

	if not term then
		local SUBPAGE = mw.title.getCurrentTitle().subpageText
		if lang:hasType("reconstructed") or mw.title.getCurrentTitle().nsText == "Reconstruction" then
			term = "*" .. SUBPAGE
		elseif lang:hasType("appendix-constructed") then
			term = SUBPAGE
		else
			term = SUBPAGE
		end
	end

	if derivtype == "PIE root" then
		return frame:callParserFunction{
			name = "#categorytree",
			args = {
				"Terms derived from the Proto-Indo-European root " .. term .. (id and " (" .. id .. ")" or ""),
				depth = 0,
				class = "\"derivedterms\"",
				mode = iargs.mode,
				}
			}
	end

	local category = nil
	local langname = lang:getCanonicalName()
	if (derivtype == "compound" and pos == nil) then
		category = langname .. " compounds with " .. term
	elseif derivtype == "compound" then
		category = langname .. " compound " .. pos .. " with " .. term
	else
		category = langname .. " " .. pos .. " " .. derivtype .. "ed with " .. term .. (id and " (" .. id .. ")" or "")
	end

	return frame:callParserFunction{
		name = "#categorytree",
		args = {
			category,
			depth = 0,
			class = "\"derivedterms" .. (sc and " " .. sc:getCode() or "") .. "\"",
			namespaces = "-" .. (mw.title.getCurrentTitle().nsText == "Reconstruction" and " Reconstruction" or ""),
			}
		}
end

return export
