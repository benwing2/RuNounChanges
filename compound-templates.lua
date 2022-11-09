local export = {}

local m_compound = require("Module:compound")
local m_languages = require("Module:languages")

local rsplit = mw.text.split


-- Per-param modifiers, which can be specified either as separate parameters (e.g. t2=, pos3=) or as inline modifiers
-- <t:...>, <pos:...>, etc. The key is the name fo the parameter (e.g. "t", "pos") and the value is a table with
-- elements as follows:
-- * `extra_specs`: An optional table of extra key-value pairs to add to the spec used for parsing the parameter
--                  when specified as a separate parameter (e.g. {type = "boolean"} for a Boolean parameter, or
--                  {alias_of = "t"} for the "gloss" parameter, which is aliased to "t"), on top of the default, which
--                  is {list = true, allow_holes = true, require_index = true}.
-- * `convert`: An optional function to convert the raw argument into the form passed to [[Module:compound]].
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
		-- because that is what [[Module:compound]] expects.
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
		-- because that is what [[Module:compound]] expects.
		item_dest = "genders",
		convert = function(arg, inline, term_index, i)
			return rsplit(arg, ",")
		end,
	},
	id = {},
	alt = {},
	q = {},
	-- Not yet supported in [[Module:compound]].
	-- qq = {},
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


local function parse_args(args, allow_compat, hack_params, has_source)
	local compat = args["lang"]
	if compat and not allow_compat then
		error("The |lang= parameter is not used by this template. Place the language code in parameter 1 instead.")
	end

	local lang_index = compat and "lang" or 1
	local term_index = (compat and 1 or 2) + (has_source and 1 or 0)
	local params = {
		[lang_index] = {required = true, default = "und"},
		[term_index] = {list = true, allow_holes = true},
		
		["lit"] = {},
		["pos"] = {},
		["sc"] = {},
		["pos"] = {},
		["sort"] = {},
		["nocat"] = {type = "boolean"},
		["force_cat"] = {type = "boolean"},
	}

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

	if hack_params then
		hack_params(params)
	end

	args = require("Module:parameters").process(args, params)
	local lang = m_languages.getByCode(args[lang_index], lang_index)
	local source
	if has_source then
		source = m_languages.getByCode(args[source_index], source_index, "allow etym")
	end
	return args, term_index, lang, fetch_script(args["sc"], "sc"), source
end


local function get_parsed_part(template, args, term_index, i)
	local part = {}
	local term = args[term_index][i]

	if lang then
		lang = m_languages.getByCode(lang, "lang" .. i, "allow etym")
	end
	
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
			-- term_index + i - 1 because we want to reference the actual term param name, which offsets from
			-- `term_index` (the index of the first term); subtract 1 since i is one-based.
			termlang = m_languages.getByCode(termlang, term_index + i - 1, "allow etym")
			term = actual_term
		else
			termlang = nil
		end
		if part.lang and termlang then
			error(("Both lang%s= and a language in %s= given; specify one or the other"):format(i, term_index + i - 1))
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
			-- For term_index + i - 1, see the call to m_languages.getByCode() about 25 lines up.
			error(msg .. ": " .. (term_index + i - 1) .. "=" .. table.concat(run))
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

	-- FIXME: Either we should have a general mechanism in `param_mods` for default values, or (better) modify
	-- [[Module:compound]] so it can handle nil for .genders.
	part.genders = part.genders or {}

	return part
end


local function get_parsed_parts(template, args, term_index, start_index)
	local parts = {}
	start_index = start_index or 1

	-- Find the maximum index among any of the list parameters.
	local maxmaxindex = 0
	for k, v in pairs(args) do
		if type(v) == "table" and v.maxindex and v.maxindex > maxmaxindex then
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
	local function hack_params(params)
		params["type"] = {}
		params["nocap"] = {type = "boolean"}
		params["notext"] = {type = "boolean"}
	end

	local args, term_index, lang, sc = parse_args(frame:getParent().args, nil, hack_params)

	if args["type"] and not m_compound.compound_types[args["type"]] then
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
	
	return m_compound.show_affixes(lang, sc, parts, args["pos"], args["sort"],
		args["type"], args["nocap"], args["notext"], args["nocat"], args["lit"], args["force_cat"])
end


function export.compound(frame)
	local function hack_params(params)
		params["type"] = {}
		params["nocap"] = {type = "boolean"}
		params["notext"] = {type = "boolean"}
	end

	local args, term_index, lang, sc = parse_args(frame:getParent().args, nil, hack_params)

	if args["type"] and not m_compound.compound_types[args["type"]] then
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
	
	return m_compound.show_compound(lang, sc, parts, args["pos"], args["sort"],
		args["type"], args["nocap"], args["notext"], args["nocat"], args["lit"], args["force_cat"])
end


function export.compound_like(frame)
	local function hack_params(params)
		params["pos"] = nil
		params["nocap"] = {type = "boolean"}
		params["notext"] = {type = "boolean"}
	end

	local args, term_index, lang, sc = parse_args(frame:getParent().args, nil, hack_params)

	local template = frame.args["template"]
	local nocat = args["nocat"]
	local notext = args["notext"]
	local text = not notext and frame.args["text"]
	local oftext = not notext and (frame.args["oftext"] or text and "of")
	local cat = not nocat and frame.args["cat"]

	local parts = get_parsed_parts(template, args, term_index)

	if not next(parts) then
		if mw.title.getCurrentTitle().nsText == "Template" then
			parts = { {term = "first"}, {term = "second"} }
		end
	end
	
	return m_compound.show_compound_like(lang, sc, parts, args["sort"], text, oftext, cat, args["nocat"], args["lit"], args["force_cat"])
end


function export.interfix_compound(frame)
	local args, term_index, lang, sc = parse_args(frame:getParent().args)

	local parts = get_parsed_parts("interfix-compound", args, term_index)
	local base1 = parts[1]
	local interfix = parts[2]
	local base2 = parts[3]
	
	-- Just to make sure someone didn't use the template in a silly way
	if not (base1 and interfix and base2) then
		if mw.title.getCurrentTitle().nsText == "Template" then
			base1 = {term = "base1"}
			interfix = {term = "interfix"}
			base2 = {term = "base2"}
		else
			error("You must provide a base term, an interfix and a second base term.")
		end
	end
	
	return m_compound.show_interfix_compound(lang, sc, base1, interfix, base2, args["pos"], args["sort"], args["nocat"], args["lit"], args["force_cat"])
end


function export.circumfix(frame)
	local args, term_index, lang, sc = parse_args(frame:getParent().args)

	local parts = get_parsed_parts("circumfix", args, term_index)
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
		
	return m_compound.show_circumfix(lang, sc, prefix, base, suffix, args["pos"], args["sort"], args["nocat"], args["lit"], args["force_cat"])
end


function export.confix(frame)
	local args, term_index, lang, sc = parse_args(frame:getParent().args)

	local parts = get_parsed_parts("confix", args, term_index)
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
		
	return m_compound.show_confix(lang, sc, prefix, base, suffix, args["pos"], args["sort"], args["nocat"], args["lit"], args["force_cat"])
end


function export.pseudo_loan(frame)
	local function hack_params(params)
		params["pos"] = nil
		params["nocap"] = {type = "boolean"}
		params["notext"] = {type = "boolean"}
	end

	local args, term_index, lang, sc, source = parse_args(frame:getParent().args, nil, hack_params, "has source")

	local parts = get_parsed_parts("pseudo-loan", args, term_index)
	
	return require("Module:compound/pseudo-loan").show_pseudo_loan(lang, source, sc, parts, args["sort"],
		args["nocap"], args["notext"], args["nocat"], args["lit"], args["force_cat"])
end


function export.infix(frame)
	local args, term_index, lang, sc = parse_args(frame:getParent().args)

	local parts = get_parsed_parts("infix", args, term_index)
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
	
	return m_compound.show_infix(lang, sc, base, infix, args["pos"], args["sort"], args["nocat"], args["lit"], args["force_cat"])
end


function export.prefix(frame)
	local args, term_index, lang, sc = parse_args(frame:getParent().args)

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
	
	return m_compound.show_prefixes(lang, sc, prefixes, base, args["pos"], args["sort"], args["nocat"], args["lit"], args["force_cat"])
end


function export.suffix(frame)
	local args, term_index, lang, sc = parse_args(frame:getParent().args)

	local base = get_parsed_part("suffix", args, term_index, 1)
	local suffixes = get_parsed_parts("suffix", args, term_index, 2)
	
	-- Just to make sure someone didn't use the template in a silly way
	if #suffixes == 0 then
		if mw.title.getCurrentTitle().nsText == "Template" then
			base = {term = "base"}
			suffixes = { {term = "suffix"} }
		else
			error("You must provide at least one suffix.")
		end
	end
	
	return m_compound.show_suffixes(lang, sc, base, suffixes, args["pos"], args["sort"], args["nocat"], args["lit"], args["force_cat"])
end


function export.transfix(frame)
	local params = {
		[1] = {required = true, default = "und"},
		[2] = {required = true, default = "base"},
		[3] = {required = true, default = "transfix"},
		
		["nocat"] = {type = "boolean"},
		["pos"] = {},
		["sc"] = {},
		["sort"] = {},
		["lit"] = {},
	}
	
	local args = require("Module:parameters").process(frame:getParent().args, params)
	
	local lang = m_languages.getByCode(args[1], 1)
	local sc = fetch_script(args["sc"], "sc")

	local base = {term = args[2]}
	local transfix = {term = args[3]}
	
	return m_compound.show_transfix(lang, sc, base, transfix, args["pos"], args["sort"], args["nocat"], args["lit"], args["force_cat"])
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
		if lang:getType() == "reconstructed" then
			term = "*" .. SUBPAGE
		elseif lang:getType() == "appendix-constructed" then
			term = SUBPAGE
		elseif mw.title.getCurrentTitle().nsText == "Reconstruction" then
			term = "*" .. SUBPAGE
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
