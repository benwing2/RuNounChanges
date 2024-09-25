local export = {}
local pos_functions = {}

local lang = require("Module:languages").getByCode("nl")
local nl_common_module = "Module:nl-common"
local parse_utilities_module = "Module:parse utilities"

local param_mods = {
	-- [[Module:headword]] expects part genders in `.genders`.
	g = {item_dest = "genders", sublist = true},
	id = {},
	q = {type = "qualifier"},
	qq = {type = "qualifier"},
	l = {type = "labels"},
	ll = {type = "labels"},
	-- [[Module:headword]] expects part references in `.refs`.
	ref = {item_dest = "refs", type = "references"},
}

local function parse_term_with_modifiers(paramname, val)
	local function generate_obj(term, parse_err)
		local obj = {term = term}
	end

	if val:find("<") then
		return require(parse_utilities_module).parse_inline_modifiers(val, {
			paramname = paramname,
			param_mods = param_mods,
			generate_obj = generate_obj,
		})
	else
		return generate_obj(val)
	end

	return part
end

local function parse_term_list_with_modifiers(paramname, list)
	local first, restpref
	if type(paramname) == "table" then
		first = paramname[1]
		restpref = paramname[2]
	else
		first = paramname
		restpref = paramname
	end
	for i, val in ipairs(list) do
		list[val] = parse_term_with_modifiers(i == 1 and first or restpref .. i, val)
	end
	return list
end

-- The main entry point.
-- This is the only function that can be invoked from a template.
function export.show(frame)
	-- The part of speech. This is also the name of the category that
	-- entries go in. However, the two are separate (the "cat" parameter)
	-- because you sometimes want something to behave as an adjective without
	-- putting it in the adjectives category.
	local poscat = frame.args[1] or error("Part of speech has not been specified. Please pass parameter 1 to the module invocation.")

	local params = {
		["head"] = {list = true},
		["pagename"] = {}, -- for testing
	}

	if pos_functions[poscat] then
		for key, val in pairs(pos_functions[poscat].params) do
			params[key] = val
		end
	end

	local args = require("Module:parameters").process(frame:getParent().args, params)

	local pagename = args.pagename or mw.loadData("Module:headword/data").pagename -- Accounts for unsupported titles.

	local data = {
		lang = lang,
		pos_category = poscat,
		categories = {},
		heads = args["head"],
		genders = {},
		inflections = {},
		tracking_categories = {},
		pagename = args.pagename,
		-- This is always set, and in the case of unsupported titles, it's the displayed version (e.g. 'C|N>K' instead
		-- of 'Unsupported titles/C through N to K').
		displayed_pagename = pagename,
	}

	if pos_functions[poscat] then
		pos_functions[poscat].func(args, data)
	end

	return require("Module:headword").full_headword(data) ..
		require("Module:utilities").format_categories(data.tracking_categories, lang, nil)
end

-- Display additional inflection information for an adjective
pos_functions["adjectives"] = {
	params = {
		[1] = {list = "comp"},
		[2] = {list = "sup"},
		[3] = {},
		},
	func = function(args, data)
		local mode = args[1][1]
		local pagename = data.displayed_pagename

		if mode == "inv" then
			table.insert(data.inflections, {label = "[[Appendix:Glossary#invariable|invariable]]"})
			table.insert(data.categories, "Dutch indeclinable adjectives")
			args[1][1] = args[2][1]
			args[2][1] = args[3]
		elseif mode == "pred" then
			table.insert(data.inflections, {label = "used only [[predicative]]ly"})
			table.insert(data.categories, "Dutch predicative-only adjectives")
			args[1][1] = args[2][1]
			args[2][1] = args[3]
		end

		local comp_mode = args[1][1]

		if comp_mode == "-" then
			table.insert(data.inflections, {label = "not [[Appendix:Glossary#comparable|comparable]]"})
		else
			-- Gather parameters
			local comparatives = parse_term_list_with_modifiers({"1", "comp"}, args[1])
			comparatives.label = "[[Appendix:Glossary#comparative|comparative]]"

			local superlatives = parse_term_list_with_modifiers({"2", "sup"}, args[2])
			superlatives.label = "[[Appendix:Glossary#superlative|superlative]]"

			-- Generate forms if none were given
			if #comparatives == 0 then
				if mode == "inv" or mode == "pred" then
					table.insert(comparatives, {term = "peri"})
				else
					table.insert(comparatives, {term = require("Module:nl-adjectives").make_comparative(pagename)})
				end
			end

			if #superlatives == 0 then
				if mode == "inv" or mode == "pred" then
					table.insert(superlatives, {term = "peri"})
				else
					-- Add preferred periphrastic superlative, if necessary
					if
						pagename:find("[iï]de$") or pagename:find("[^eio]e$") or
						pagename:find("s$") or pagename:find("sch$") or pagename:find("x$") or
						pagename:find("sd$") or pagename:find("st$") or pagename:find("sk$") then
						table.insert(superlatives, {term = "peri"})
					end

					table.insert(superlatives, {term = require("Module:nl-adjectives").make_superlative(pagename)})
				end
			end

			-- Replace "peri" with phrase
			for _, val in ipairs(comparatives) do
				if val.term == "peri" then val.term = "[[meer]] " .. pagename end
			end

			for _, val in ipairs(superlatives) do
				if val.term == "peri" then val.term = "[[meest]] " .. pagename end
			end

			table.insert(data.inflections, comparatives)
			table.insert(data.inflections, superlatives)
		end
	end
}

-- Display additional inflection information for an adverb
pos_functions["adverbs"] = {
	params = {
		[1] = {list = "comp"},
		[2] = {list = "sup"},
		},
	func = function(args, data)
		local pagename = data.displayed_pagename

		if args[1][1] then
			-- Gather parameters
			local comparatives = parse_term_list_with_modifiers({"1", "comp"}, args[1])
			comparatives.label = "[[Appendix:Glossary#comparative|comparative]]"

			local superlatives = parse_term_list_with_modifiers({"2", "sup"}, args[2])
			superlatives.label = "[[Appendix:Glossary#superlative|superlative]]"

			if not superlatives[1] then
				superlatives[1] = {term = pagename .. "st"}
			end

			table.insert(data.inflections, comparatives)
			table.insert(data.inflections, superlatives)
		end
	end
}

-- Display information for a noun's gender
-- This is separate so that it can also be used for proper nouns
local function noun_gender(args, data)
	for _, g in ipairs(args[1]) do
		if g == "c" then
			table.insert(data.categories, "Dutch nouns with common gender")
		elseif g == "p" then
			table.insert(data.categories, "Dutch pluralia tantum")
		elseif g ~= "m" and g ~= "f" and g ~= "n" then
			g = nil
		end

		table.insert(data.genders, g)
	end

	if #data.genders == 0 then
		table.insert(data.genders, "?")
	end

	-- Most nouns that are listed as f+m should really have only f
	if data.genders[1] == "f" and data.genders[2] == "m" then
		table.insert(data.categories, "Dutch nouns with f+m gender")
	end
end

local function generate_plurals(pagename)
	local m_common = require(nl_common_module)
	local generated = {}

	generated["-s"] = pagename .. "s"
	generated["-'s"] = pagename .. "'s"

	local stem_FF = m_common.add_e(pagename, false, false)
	local stem_TF = m_common.add_e(pagename, true, false)
	local stem_FT = m_common.add_e(pagename, false, true)

	generated["-es"] = stem_FF .. "s"
	generated["-@es"] = stem_TF .. "s"
	generated["-:es"] = stem_FT .. "s"

	generated["-en"] = stem_FF .. "n"
	generated["-@en"] = stem_TF .. "n"
	generated["-:en"] = stem_FT .. "n"

	generated["-eren"] = m_common.add_e(pagename .. (pagename:find("n$") and "d" or ""), false, false) .. "ren"
	generated["-:eren"] = stem_FT .. "ren"

	if pagename:find("f$") then
		local stem = pagename:gsub("f$", "v")
		local stem_FF = m_common.add_e(stem, false, false)
		local stem_TF = m_common.add_e(stem, true, false)
		local stem_FT = m_common.add_e(stem, false, true)

		generated["-ves"] = stem_FF .. "s"
		generated["-@ves"] = stem_TF .. "s"
		generated["-:ves"] = stem_FT .. "s"

		generated["-ven"] = stem_FF .. "n"
		generated["-@ven"] = stem_TF .. "n"
		generated["-:ven"] = stem_FT .. "n"

		generated["-veren"] = stem_FF .. "ren"
		generated["-:veren"] = stem_FT .. "ren"
	elseif pagename:find("s$") then
		local stem = pagename:gsub("s$", "z")
		local stem_FF = m_common.add_e(stem, false, false)
		local stem_TF = m_common.add_e(stem, true, false)
		local stem_FT = m_common.add_e(stem, false, true)

		generated["-zes"] = stem_FF .. "s"
		generated["-@zes"] = stem_TF .. "s"
		generated["-:zes"] = stem_FT .. "s"

		generated["-zen"] = stem_FF .. "n"
		generated["-@zen"] = stem_TF .. "n"
		generated["-:zen"] = stem_FT .. "n"

		generated["-zeren"] = stem_FF .. "ren"
		generated["-:zeren"] = stem_FT .. "ren"
	elseif pagename:find("heid$") then
		generated["-heden"] = pagename:gsub("heid$", "heden")
	end

	return generated
end

local function generate_diminutive(pagename, dim)
	local m_common = require(nl_common_module)
	if dim == "+" then
		dim = m_common.default_dim(pagename)
	elseif dim == "++" then
		dim = m_common.default_dim(pagename, "final multisyllable stress")
	elseif dim == "++/+" then
		dim = m_common.default_dim(pagename, false, "modifier final multisyllable stress")
	elseif dim == "++/++" then
		dim = m_common.default_dim(pagename, "final multisyllable stress", "modifier final multisyllable stress")
	elseif dim == "+first" then
		dim = m_common.default_dim(pagename, false, false, "first only")
	elseif dim == "++first" then
		dim = m_common.default_dim(pagename, "final multisyllable stress", false, "first only")
	elseif dim:sub(1, 1) == "-" then
		dim = pagename .. dim:sub(2)
	end
	return dim
end

pos_functions["proper nouns"] = {
	params = {
		[1] = {list = "g"},
		["adj"] = {list = true},
		["mdem"] = {list = true},
		["fdem"] = {list = true},
		},
	func = function(args, data)
		noun_gender(args, data)

		local adjectives = parse_term_list_with_modifiers("adj", args["adj"])
		local mdems = parse_term_list_with_modifiers("mdem", args["mdem"])
		local fdems = parse_term_list_with_modifiers("fdem", args["fdem"])
		local nm = #mdems
		local nf = #fdems
		local demonyms = {label = "demonym"}

		--adjective for toponyms
		if adjectives[1] then
			adjectives.label = "adjective"
			table.insert(data.inflections, adjectives)
		end
		--demonyms for toponyms
		if nm + nf > 0 then
			for i, m in ipairs(mdems) do
				if not m.genders then
					m.genders = {"m"}
				end
				demonyms[i] = m
			end
			for i, f in ipairs(fdems) do
				if not f.genders then
					f.genders = {"m"}
				end
				demonyms[i + nm] = f
			end
			table.insert(data.inflections, demonyms)
		end
	end
}

-- Display additional inflection information for a noun
pos_functions["nouns"] = {
	params = {
		[1] = {list = "g"},
		[2] = {list = "pl", disallow_holes = true},
		-- FIXME, remove this in favor of inline modifiers
		["pl\1qual"] = {list = true, allow_holes = true},
		[3] = {list = "dim"},

		["f"] = {list = true},
		["m"] = {list = true},
		},
	func = function(args, data, called_from)
		local pagename = data.displayed_pagename

		noun_gender(args, data)

		local plurals = parse_term_list_with_modifiers({called_from == "dimtant" and "1" or "2", "pl"}, args[2])
		local pl_qualifiers = args["plqual"]
		local diminutives = parse_term_list_with_modifiers({"3", "dim"}, args[3])
		local feminines = parse_term_list_with_modifiers("f", args["f"])
		local masculines = parse_term_list_with_modifiers("m", args["m"])

		-- Plural
		if data.genders[1] == "p" then
			table.insert(data.inflections, {label = "[[Appendix:Glossary#plural only|plural only]]"})
		elseif plurals[1] and plurals[1].term == "-" then
			table.insert(data.inflections, {label = "[[Appendix:Glossary#uncountable|uncountable]]"})
			table.insert(data.categories, "Dutch uncountable nouns")
		else
			local generated = generate_plurals(pagename)

			-- Process the plural forms
			for i, pobj in ipairs(plurals) do
				local p = pobj.term
				-- Is this a shortcut form?
				if p:sub(1,1) == "-" then
					if not generated[p] then
						error("The shortcut plural " .. p .. " could not be generated.")
					end

					if p:sub(-2) == "es" then
						table.insert(data.categories, "Dutch nouns with plural in -es")
					elseif p:sub(-1) == "s" then
						table.insert(data.categories, "Dutch nouns with plural in -s")
					elseif p:sub(-4) == "eren" then
						table.insert(data.categories, "Dutch nouns with plural in -eren")
					else
						table.insert(data.categories, "Dutch nouns with plural in -en")
					end

					if p:sub(2,2) == ":" then
						table.insert(data.categories, "Dutch nouns with lengthened vowel in the plural")
					end

					p = generated[p]
				-- Not a shortcut form, but the plural form specified directly.
				else
					local matches = {}

					for pi, g in pairs(generated) do
						if g == p then
							table.insert(matches, pi)
						end
					end

					if #matches > 0 then
						table.insert(data.tracking_categories, "nl-noun plural matches generated form")
					elseif not pagename:find("[ -]") then
						if p == pagename then
							table.insert(data.categories, "Dutch indeclinable nouns")
						elseif
							p == pagename .. "den" or p == pagename:gsub("ee$", "eden") or
							p == pagename .. "des" or p == pagename:gsub("ee$", "edes") then
							table.insert(data.categories, "Dutch nouns with plural in -den")
						elseif p == pagename:gsub("([ao])$", "%1%1ien") or p == pagename:gsub("oe$", "oeien") then
							table.insert(data.categories, "Dutch nouns with glide vowel in plural")
						elseif p == pagename:gsub("y$", "ies") then
							table.insert(data.categories, "Dutch nouns with English plurals")
						elseif
							p == pagename:gsub("a$", "ae") or
							p == pagename:gsub("[ei]x$", "ices") or
							p == pagename:gsub("is$", "es") or
							p == pagename:gsub("men$", "mina") or
							p == pagename:gsub("ns$", "ntia") or
							p == pagename:gsub("o$", "ones") or
							p == pagename:gsub("o$", "onen") or
							p == pagename:gsub("s$", "tes") or
							p == pagename:gsub("us$", "era") or
							p == mw.ustring.gsub(pagename, "[uü]s$", "i") or
							p == mw.ustring.gsub(pagename, "[uü]m$", "a") or
							p == pagename:gsub("x$", "ges") then
							table.insert(data.categories, "Dutch nouns with Latin plurals")
						elseif
							p == pagename:gsub("os$", "oi") or
							p == pagename:gsub("on$", "a") or
							p == pagename:gsub("a$", "ata") then
							table.insert(data.categories, "Dutch nouns with Greek plurals")
						else
							table.insert(data.categories, "Dutch irregular nouns")
						end

						if plural and not mw.title.new(plural).exists then
							table.insert(data.categories, "Dutch nouns with missing plurals")
						end
					end
				end

				pobj.term = p
				if pl_qualifiers[i] then
					pobj.q = {pl_qualifiers[i]}
				end
			end

			-- Add the plural forms
			plurals.label = "plural"
			plurals.accel = {form = "p"}
			plurals.request = true
			table.insert(data.inflections, plurals)
		end

		-- Add the diminutive forms
		if diminutives[1] and diminutives[1].term == "-" then
			-- do nothing
		else
			-- Process the diminutive forms
			for _, dimobj in ipairs(diminutives) do
				dimobj.term = generate_diminutive(pagename, dimobj.term)
				if not dimobj.genders then
					dimobj.genders = {"n"}
				end
			end

			diminutives.label = "[[Appendix:Glossary#diminutive|diminutive]]"
			diminutives.accel = {form = "diminutive"}
			diminutives.request = true
			table.insert(data.inflections, diminutives)
		end

		-- Add the feminine forms
		if feminines[1] then
			feminines.label = "feminine"
			table.insert(data.inflections, feminines)
		end

		-- Add the masculine forms
		if masculines[1] then
			masculines.label = "masculine"
			table.insert(data.inflections, masculines)
		end
	end
}

-- Display additional inflection information for a diminutive noun
pos_functions["diminutive nouns"] = {
	params = {
		[1] = {},
		[2] = {list = "pl"},
		},
	func = function(args, data)
		if not (args[1] == "n" or args[1] == "p") then
			args[1] = {"n"}
		else
			args[1] = {args[1]}
		end

		if not args[2][1] then
			args[2] = {{term = "-s"}}
		end

		args[3] = {{term = "-"}}
		args["f"] = {}
		args["m"] = {}
		-- FIXME: Remove this.
		args["plqual"] = {}

		pos_functions["nouns"].func(args, data, "dim")
	end
}

-- Display additional inflection information for diminutiva tantum nouns ({{nl-noun-dim-tant}}).
pos_functions["diminutiva tantum nouns"] = {
	params = {
		[1] = {list = "pl", disallow_holes = true},
		-- FIXME: Remove this.
		["pl\1qual"] = {list = true, allow_holes = true},

		["f"] = {list = true},
		["m"] = {list = true},
		},
	func = function(args, data)
		data.pos_category = "nouns"
		table.insert(data.categories, "Dutch diminutiva tantum")
		args[2] = args[1]
		args[1] = {"n"}

		if not args[2][1] then
			args[2] = {{term = "-s"}}
		end

		args[3] = {{term = "-"}}

		pos_functions["nouns"].func(args, data, "dimtant")
	end
}

pos_functions["past participles"] = {
	params = {
		[1] = {},
	},
	func = function(args, data)
		if args[1] == "-" then
			table.insert(data.inflections, {label = "not used adjectivally"})
			table.insert(data.categories, "Dutch non-adjectival past participles")
		end
	end
}

pos_functions["verbs"] = {
	params = {
		[1] = {},
		},
	func = function(args, data)
		if args[1] == "-" then
			table.insert(data.inflections, {label = "not inflected"})
			table.insert(data.categories, "Dutch uninflected verbs")
		end
	end
}

return export
