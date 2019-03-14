local export = {}

local m_compound = require("Module:compound")
local m_languages = require("Module:languages")
local m_debug = require("Module:debug")

local rsplit = mw.text.split


local function if_not_empty(val)
	if val == "" then
		return nil
	else
		return val
	end
end


local function to_boolean(val)
	if not val or val == "" then
		return false
	else
		return true
	end
end


local function fetch_lang(args, allow_compat)
	local compat = true

	if not allow_compat and args["lang"] then
		error('The |lang= parameter is not used by this template. Place the language code in parameter 1 instead.')
	end
	
	local lang = allow_compat and if_not_empty(args["lang"]) or nil
	if not lang then
		compat = false
		lang = if_not_empty(args[1])
	end
	
	if not lang and mw.title.getCurrentTitle().nsText == "Template" then
		lang = "und"
	end
	
	lang = lang and m_languages.getByCode(lang) or m_languages.err(lang, compat and "lang" or 1)
	return lang, compat
end

	
local function fetch_script(sc)
	sc = if_not_empty(sc)
	if sc then
		return require("Module:scripts").getByCode(sc) or error("The script code \"" .. sc .. "\" is not valid.")
	else
		return nil
	end
end


local function get_part(template, args, offset, i)
	offset = offset or 0
	
	local term = if_not_empty(args[i + offset])
	local alt = if_not_empty(args["alt" .. i])
	local id = if_not_empty(args["id" .. i])
	local lang = if_not_empty(args["lang" .. i])
	local sc = fetch_script(args["sc" .. i])
	
	local tr = if_not_empty(args["tr" .. i])
	local ts = if_not_empty(args["ts" .. i])
	local gloss = if_not_empty(args["t" .. i]) or if_not_empty(args["gloss" .. i])
	local pos = if_not_empty(args["pos" .. i])
	local lit = if_not_empty(args["lit" .. i])
	local q = if_not_empty(args["q" .. i])
	local g = if_not_empty(args["g" .. i])

	if lang then
		lang =
			m_languages.getByCode(lang) or
			require("Module:etymology languages").getByCode(lang) or
			m_languages.err(lang, "lang" .. i)
	end
	
	if not (term or alt or tr or ts) then
		require("Module:debug").track(template .. "/no term or alt or tr")
		return nil
	else
		return { term = term, alt = alt, id = id, lang = lang, sc = sc, tr = tr,
			ts = ts, gloss = gloss, pos = pos, lit = lit, q = q,
			genders = g and rsplit(g, ",") or {}
		}
	end
end


local function get_parts(template, args, offset, i)
	local parts = {}
	local start_index = i or 1

	-- Temporary tracking code for bare arguments of which numeric variants
	-- are recognized, but where the bare argument shouldn't occur.
	-- Eventually, this should be converted to use [[Module:parameters]] and
	-- the unrecognized arguments removed.
	local no_bare_args = {"tr", "ts", "alt", "id", "gloss", "t", "lit"}
	for _, bare_arg in ipairs(no_bare_args) do
		if args[bare_arg] then
			m_debug.track{
				template .. "/bare-" .. bare_arg,
				template .. "/bare-arg"
			}
			mw.log("bare arg in {{" .. template .. "}} was ignored: |" .. bare_arg .. "=" .. tostring(args[bare_arg]))
		end
	end
	
	for index = start_index, require("Module:table").maxIndex(args) do
		local part = get_part(template, args, offset, index)
		
		parts[index - start_index + 1] = part
	end
	
	return parts
end

local function parse_args(args, allow_compat, hack_params)
	local compat = args["lang"]
	if compat and not allow_compat then
		error('The |lang= parameter is not used by this template. Place the language code in parameter 1 instead.')
	end

	local params = {
		[compat and "lang" or 1] = {required = true, default = "und"},
		[compat and 1 or 2] = {list = true, allow_holes = true},
		
		["t"] = {list = true, allow_holes = true, require_index = true},
		["gloss"] = {list = true, allow_holes = true, require_index = true, alias_of = "t"},
		["tr"] = {list = true, allow_holes = true, require_index = true},
		["ts"] = {list = true, allow_holes = true, require_index = true},
		["g"] = {list = true, allow_holes = true, require_index = true},
		["id"] = {list = true, allow_holes = true, require_index = true},
		["alt"] = {list = true, allow_holes = true, require_index = true},
		["q"] = {list = true, allow_holes = true, require_index = true},
		["lit"] = {list = true, allow_holes = true, require_index = true},
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
	}

	if hack_params then
		hack_params(params)
	end

	args = require("Module:parameters").process(args, params)
	return args, compat and args[1] or args[2], fetch_lang(args, allow_compat), fetch_script(args["sc"])
end


local function get_parsed_part(template, args, terms, i)
	local term = terms[i]
	local alt = args["alt"][i]
	local id = args["id"][i]
	local lang = args["partlang"][i]
	local sc = fetch_script(args["partsc"][i])
	
	local tr = args["tr"][i]
	local ts = args["ts"][i]
	local gloss = args["t"][i]
	local pos = args["partpos"][i]
	local lit = args["lit"][i]
	local q = args["q"][i]
	local g = args["g"][i]

	if lang then
		lang =
			m_languages.getByCode(lang) or
			require("Module:etymology languages").getByCode(lang) or
			m_languages.err(lang, "lang" .. i)
	end
	
	if not (term or alt or tr or ts) then
		require("Module:debug").track(template .. "/no term or alt or tr")
		return nil
	else
		return { term = term, alt = alt, id = id, lang = lang, sc = sc, tr = tr,
			ts = ts, gloss = gloss, pos = pos, lit = lit, q = q,
			genders = g and rsplit(g, ",") or {}
		}
	end
end


local function get_parsed_parts(template, args, terms, start_index)
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
		local part = get_parsed_part(template, args, terms, index)
		parts[index - start_index + 1] = part
	end
	
	return parts
end


function export.affix(frame)
	local args, terms, lang, sc = parse_args(frame:getParent().args)

	local parts = get_parsed_parts("affix", args, terms)
	
	-- There must be at least one part to display. If there are gaps, a term
	-- request will be shown.
	if #parts == 0 then
		if mw.title.getCurrentTitle().nsText == "Template" then
			parts = { {term = "prefix-"}, {term = "base"}, {term = "-suffix"} }
		else
			error("You must provide at least one part.")
		end
	end
	
	return m_compound.show_affixes(lang, sc, parts, args["pos"], args["sort"], args["nocat"])
end


function export.compound(frame)
	local args, terms, lang, sc = parse_args(frame:getParent().args, "allow compat")

	local parts = get_parsed_parts("compound", args, terms)
	
	-- There must be at least one part to display. If there are gaps, a term
	-- request will be shown.
	if #parts == 0 then
		if mw.title.getCurrentTitle().nsText == "Template" then
			parts = { {term = "first"}, {term = "second"} }
		else
			error("You must provide at least one part of a compound.")
		end
	end
	
	return m_compound.show_compound(lang, sc, parts, args["pos"], args["sort"], args["nocat"])
end


function export.compound_like(frame)
	local function hack_params(params)
		params["pos"] = nil
		params["notext"] = {type = "boolean"}
	end

	local args, terms, lang, sc = parse_args(frame:getParent().args, nil, hack_params)

	local template = frame.args["template"]
	local nocat = args["nocat"]
	local notext = args["notext"]
	local text = not notext and frame.args["text"]
	local oftext = not notext and (frame.args["oftext"] or text and "of")
	local cat = not nocat and frame.args["cat"]

	local parts = get_parsed_parts(template, args, terms)

	if #parts == 0 then
		if mw.title.getCurrentTitle().nsText == "Template" then
			parts = { {term = "first"}, {term = "second"} }
		end
	end
	
	return m_compound.show_compound_like(lang, sc, parts, args["sort"], text, oftext, cat)
end


function export.interfix_compound(frame)
	local args, terms, lang, sc = parse_args(frame:getParent().args, "allow compat")

	local parts = get_parsed_parts("interfix-compound", args, terms)
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
	
	return m_compound.show_interfix_compound(lang, sc, base1, interfix, base2, args["pos"], args["sort"], args["nocat"])
end


function export.circumfix(frame)
	local args, terms, lang, sc = parse_args(frame:getParent().args, "allow compat")

	local parts = get_parsed_parts("circumfix", args, terms)
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
		
	return m_compound.show_circumfix(lang, sc, prefix, base, suffix, args["pos"], args["sort"], args["nocat"])
end


function export.confix(frame)
	local args, terms, lang, sc = parse_args(frame:getParent().args, "allow compat")

	local parts = get_parsed_parts("confix", args, terms)
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
		
	return m_compound.show_confix(lang, sc, prefix, base, suffix, args["pos"], args["sort"], args["nocat"])
end


function export.infix(frame)
	local args, terms, lang, sc = parse_args(frame:getParent().args, "allow compat")

	local parts = get_parsed_parts("infix", args, terms)
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
	
	return m_compound.show_infix(lang, sc, base, infix, args["pos"], args["sort"], args["nocat"])
end


function export.prefix(frame)
	local args, terms, lang, sc = parse_args(frame:getParent().args, "allow compat")

	local prefixes = get_parsed_parts("prefix", args, terms)
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
	
	return m_compound.show_prefixes(lang, sc, prefixes, base, args["pos"], args["sort"], args["nocat"])
end


function export.suffix(frame)
	local args, terms, lang, sc = parse_args(frame:getParent().args, "allow compat")

	local base = get_parsed_part("suffix", args, terms, 1)
	local suffixes = get_parsed_parts("suffix", args, terms, 2)
	
	-- Just to make sure someone didn't use the template in a silly way
	if #suffixes == 0 then
		if mw.title.getCurrentTitle().nsText == "Template" then
			base = {term = "base"}
			suffixes = { {term = "suffix"} }
		else
			error("You must provide at least one suffix.")
		end
	end
	
	return m_compound.show_suffixes(lang, sc, base, suffixes, args["pos"], args["sort"], args["nocat"])
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
	}
	
	local args = require("Module:parameters").process(frame:getParent().args, params)
	
	local lang = m_languages.getByCode(args[1]) or m_languages.err(lang, 1)
	local sc = fetch_script(args["sc"])

	local base = {term = args[2]}
	local transfix = {term = args[3]}
	
	return m_compound.show_transfix(lang, sc, base, transfix, args["pos"], args["sort"], args["nocat"])
end


function export.derivsee(frame)
	local args = frame:getParent().args
	
	local derivtype = frame.args["derivtype"]
	local mode = if_not_empty(frame.args["mode"])
	local lang
	local term
	
	if derivtype == "PIE root" then
		lang = m_languages.getByCode("ine-pro")
		term = if_not_empty(args[1] or args["head"])

		if term then
			term = "*" .. term .. "-"
		end
	else
		lang = fetch_lang(args)
		term = if_not_empty(args[2] or args["head"])
	end
	
	local id = if_not_empty(args["id"])
	local sc = fetch_script(args["sc"])
	local pos = if_not_empty(args["pos"])

	pos = pos or "word"
	
	-- Pluralize the part of speech name
	if pos:find("[sx]$") then
		pos = pos .. "es"
	else
		pos = pos .. "s"
	end
	
	if not term then
		if lang:getType() == "reconstructed" then
			term = "*" .. mw.title.getCurrentTitle().subpageText
		elseif lang:getType() == "appendix-constructed" then
			term = mw.title.getCurrentTitle().subpageText
		elseif mw.title.getCurrentTitle().nsText == "Reconstruction" then
			term = "*" .. mw.title.getCurrentTitle().subpageText
		else
			term = mw.title.getCurrentTitle().subpageText
		end
	end
	
	local category = nil
	
	if derivtype == "PIE root" then
		return frame:callParserFunction{
			name = "#categorytree",
			args = {
				"Terms derived from the PIE root " .. term .. (id and " (" .. id .. ")" or ""),
				depth = 0,
				class = "\"derivedterms\"",
				mode = mode,
				}
			}
	end
	
	if derivtype == "compound" then
		category = lang:getCanonicalName() .. " compounds with " .. term
	else
		category = lang:getCanonicalName() .. " " .. pos .. " " .. derivtype .. "ed with " .. term .. (id and " (" .. id .. ")" or "")
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
