local export = {}

local m_compound = require("Module:compound")
local m_languages = require("Module:languages")
local m_debug = require("Module:debug")

local rsplit = mw.text.split


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
		
		["t"] = {list = true, allow_holes = true, require_index = true},
		["gloss"] = {list = true, allow_holes = true, require_index = true, alias_of = "t"},
		["tr"] = {list = true, allow_holes = true, require_index = true},
		["ts"] = {list = true, allow_holes = true, require_index = true},
		["g"] = {list = true, allow_holes = true, require_index = true},
		["id"] = {list = true, allow_holes = true, require_index = true},
		["alt"] = {list = true, allow_holes = true, require_index = true},
		["q"] = {list = true, allow_holes = true, require_index = true},
		["lit"] = {},
		-- Note, lit1=, lit2=, ... are different from lit=
		["partlit"] = {list = "lit", allow_holes = true, require_index = true},
		["pos"] = {},
		-- Note, pos1=, pos2=, ... are different from pos=
		["partpos"] = {list = "pos", allow_holes = true, require_index = true},
		-- Note, lang1=, lang2=, ... are different from lang=; the former apply to
		-- individual arguments, while the latter applies to all arguments
		["partlang"] = {list = "lang", allow_holes = true, require_index = true},
		["sc"] = {},
		-- Note, sc1=, sc2=, ... are different from sc=; the former apply to
		-- individual arguments when lang1=, lang2=, ... is specified, while
		-- the latter applies to all arguments where langN=... isn't specified
		["partsc"] = {list = "sc", allow_holes = true, require_index = true},
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
	local term = args[term_index][i]
	local alt = args["alt"][i]
	local id = args["id"][i]
	local lang = args["partlang"][i]
	local sc = fetch_script(args["partsc"][i], "sc" .. i)
	
	local tr = args["tr"][i]
	local ts = args["ts"][i]
	local gloss = args["t"][i]
	local pos = args["partpos"][i]
	local lit = args["partlit"][i]
	local q = args["q"][i]
	local g = args["g"][i]

	if lang then
		lang = m_languages.getByCode(lang, "lang" .. i, "allow etym")
	end
	
	if not (term or alt or tr or ts) then
		require("Module:debug").track(template .. "/no term or alt or tr")
		return nil
	else
		local termlang, actual_term
		if term then
			termlang, actual_term = term:match("^([A-Za-z0-9._-]+):(.*)$")
			if termlang and termlang ~= "w" then -- special handling for w:... links to Wikipedia
				-- -1 since i is one-based
				termlang = m_languages.getByCode(termlang, term_index + i - 1, "allow etym")
			else
				termlang = nil
				actual_term = term
			end
		end
		if lang and termlang then
			error(("Both lang%s= and a language in %s= given; specify one or the other"):format(i, term_index + i - 1))
		end
		return { term = actual_term, alt = alt, id = id, lang = lang or termlang, sc = sc, tr = tr,
			ts = ts, gloss = gloss, pos = pos, lit = lit, q = q,
			genders = g and rsplit(g, ",") or {}
		}
	end
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
