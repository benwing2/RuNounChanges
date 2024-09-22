local export = {}
local pos_functions = {}

local lang = require("Module:languages").getByCode("nl")

-- The main entry point.
-- This is the only function that can be invoked from a template.
function export.show(frame)
	PAGENAME = mw.title.getCurrentTitle().text
	
	-- The part of speech. This is also the name of the category that
	-- entries go in. However, the two are separate (the "cat" parameter)
	-- because you sometimes want something to behave as an adjective without
	-- putting it in the adjectives category.
	local poscat = frame.args[1] or error("Part of speech has not been specified. Please pass parameter 1 to the module invocation.")
	
	local params = {
		["head"] = {list = true},
	}
	
	if pos_functions[poscat] then
		for key, val in pairs(pos_functions[poscat].params) do
			params[key] = val
		end
	end
	
	local args = require("Module:parameters").process(frame:getParent().args, params)
	
	local data = {lang = lang, pos_category = poscat, categories = {}, heads = args["head"], genders = {}, inflections = {}, tracking_categories = {}}
	
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
			local comparatives = args[1]
			comparatives.label = "[[Appendix:Glossary#comparative|comparative]]"
			
			local superlatives = args[2]
			superlatives.label = "[[Appendix:Glossary#superlative|superlative]]"
			
			-- Generate forms if none were given
			if #comparatives == 0 then
				if mode == "inv" or mode == "pred" then
					table.insert(comparatives, "peri")
				else
					table.insert(comparatives, require("Module:nl-adjectives").make_comparative(PAGENAME))
				end
			end
			
			if #superlatives == 0 then
				if mode == "inv" or mode == "pred" then
					table.insert(superlatives, "peri")
				else
					-- Add preferred periphrastic superlative, if necessary
					if
						PAGENAME:find("[iï]de$") or PAGENAME:find("[^eio]e$") or
						PAGENAME:find("s$") or PAGENAME:find("sch$") or PAGENAME:find("x$") or
						PAGENAME:find("sd$") or PAGENAME:find("st$") or PAGENAME:find("sk$") then
						table.insert(superlatives, "peri")
					end
					
					table.insert(superlatives, require("Module:nl-adjectives").make_superlative(PAGENAME))
				end
			end
			
			-- Replace "peri" with phrase
			for key, val in ipairs(comparatives) do
				if val == "peri" then comparatives[key] = "[[meer]] " .. PAGENAME end
			end
			
			for key, val in ipairs(superlatives) do
				if val == "peri" then superlatives[key] = "[[meest]] " .. PAGENAME end
			end
			
			table.insert(data.inflections, comparatives)
			table.insert(data.inflections, superlatives)
		end
	end
}

-- Display additional inflection information for an adverb
pos_functions["adverbs"] = {
	params = {
		[1] = {},
		[2] = {},
		},
	func = function(args, data)
		local comp = args[1]
		local sup = args[2]
		
		if comp then
			if not sup then
				sup = PAGENAME .. "st"
			end
			
			table.insert(data.inflections, {label = "[[Appendix:Glossary#comparative|comparative]]", comp})
			table.insert(data.inflections, {label = "[[Appendix:Glossary#superlative|superlative]]", sup})
		end
	end
}

-- Display information for a noun's gender
-- This is separate so that it can also be used for proper nouns
function noun_gender(args, data)
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

pos_functions["proper nouns"] = {
	params = {
		[1] = {list = "g"},
		["adj"] = {list = true},
		["mdem"] = {list = true},
		["fdem"] = {list = true},
		},
	func = function(args, data)
		noun_gender(args, data)
		
		local adjectives = args["adj"]
		local mdems = args["mdem"]
		local fdems = args["fdem"]
		local nm = #mdems
		local nf = #fdems
		local demonyms = {label = "demonym"}
		
		--adjective for toponyms
		if #adjectives>0 then
			for i, a in ipairs(adjectives) do
				adjectives[i] = {term = a}
			end
			adjectives.label = "adjective"
			table.insert(data.inflections, adjectives)
		end
		--demonyms for toponyms
		if nm+nf>0 then
			for i, m in ipairs(mdems) do
				demonyms[i] = {term = m, genders = {"m"}}
			end
			for i, f in ipairs(fdems) do
				demonyms[i+nm] = {term = f, genders = {"f"}}
			end
			table.insert(data.inflections, demonyms)
		end
	end
}

-- Display additional inflection information for a noun
pos_functions["nouns"] = {
	params = {
		[1] = {list = "g"},
		[2] = {list = "pl"},
		["pl\1qual"] = {list = true, allow_holes = true},
		[3] = {list = "dim"},
		
		["f"] = {list = true},
		["m"] = {list = true},
		},
	func = function(args, data)
		noun_gender(args, data)
		
		local plurals = args[2]
		local pl_qualifiers = args["plqual"]
		local diminutives = args[3]
		local feminines = args["f"]
		local masculines = args["m"]
		
		-- Plural
		if data.genders[1] == "p" then
			table.insert(data.inflections, {label = "[[Appendix:Glossary#plural only|plural only]]"})
		elseif plurals[1] == "-" then
			table.insert(data.inflections, {label = "[[Appendix:Glossary#uncountable|uncountable]]"})
			table.insert(data.categories, "Dutch uncountable nouns")
		else
			local generated = generate_plurals(PAGENAME)
			
			-- Process the plural forms
			for i, p in ipairs(plurals) do
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
					elseif not PAGENAME:find("[ -]") then
						if p == PAGENAME then
							table.insert(data.categories, "Dutch indeclinable nouns")
						elseif
							p == PAGENAME .. "den" or p == PAGENAME:gsub("ee$", "eden") or
							p == PAGENAME .. "des" or p == PAGENAME:gsub("ee$", "edes") then
							table.insert(data.categories, "Dutch nouns with plural in -den")
						elseif p == PAGENAME:gsub("([ao])$", "%1%1ien") or p == PAGENAME:gsub("oe$", "oeien") then
							table.insert(data.categories, "Dutch nouns with glide vowel in plural")
						elseif p == PAGENAME:gsub("y$", "ies") then
							table.insert(data.categories, "Dutch nouns with English plurals")
						elseif
							p == PAGENAME:gsub("a$", "ae") or
							p == PAGENAME:gsub("[ei]x$", "ices") or
							p == PAGENAME:gsub("is$", "es") or
							p == PAGENAME:gsub("men$", "mina") or
							p == PAGENAME:gsub("ns$", "ntia") or
							p == PAGENAME:gsub("o$", "ones") or
							p == PAGENAME:gsub("o$", "onen") or
							p == PAGENAME:gsub("s$", "tes") or
							p == PAGENAME:gsub("us$", "era") or
							p == mw.ustring.gsub(PAGENAME, "[uü]s$", "i") or
							p == mw.ustring.gsub(PAGENAME, "[uü]m$", "a") or
							p == PAGENAME:gsub("x$", "ges") then
							table.insert(data.categories, "Dutch nouns with Latin plurals")
						elseif
							p == PAGENAME:gsub("os$", "oi") or
							p == PAGENAME:gsub("on$", "a") or
							p == PAGENAME:gsub("a$", "ata") then
							table.insert(data.categories, "Dutch nouns with Greek plurals")
						else
							table.insert(data.categories, "Dutch irregular nouns")
						end
						
						if plural and not mw.title.new(plural).exists then
							table.insert(data.categories, "Dutch nouns with missing plurals")
						end
					end
				end
				
				plurals[i] = {term = p, q = {pl_qualifiers[i]}}
			end
			
			-- Add the plural forms
			plurals.label = "plural"
			plurals.accel = {form = "p"}
			plurals.request = true
			table.insert(data.inflections, plurals)
		end
		
		-- Add the diminutive forms
		if diminutives[1] == "-" then
			-- do nothing
		else
			-- Process the diminutive forms
			for i, p in ipairs(diminutives) do
				diminutives[i] = {term = p, genders = {"n"}}
			end
			
			diminutives.label = "[[Appendix:Glossary#diminutive|diminutive]]"
			diminutives.accel = {form = "diminutive"}
			diminutives.request = true
			table.insert(data.inflections, diminutives)
		end
		
		-- Add the feminine forms
		if #feminines > 0 then
			feminines.label = "feminine"
			table.insert(data.inflections, feminines)
		end
		
		-- Add the masculine forms
		if #masculines > 0 then
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
		
		if #args[2] == 0 then
			args[2] = {"-s"}
		end
		
		args[3] = {"-"}
		args["f"] = {}
		args["m"] = {}
		args["plqual"] = {}
		
		pos_functions["nouns"].func(args, data)
	end
}

-- Display additional inflection information for diminutiva tantum nouns ({{nl-noun-dim-tant}}).
pos_functions["diminutiva tantum nouns"] = {
	params = {
		[1] = {list = "pl"},
		["pl\1qual"] = {list = true, allow_holes = true},

		["f"] = {list = true},
		["m"] = {list = true},
		},
	func = function(args, data)
		data.pos_category = "nouns"
		table.insert(data.categories, "Dutch diminutiva tantum")
		args[2] = args[1]		
		args[1] = {"n"}

		if #args[2] == 0 then
			args[2] = {"-s"}
		end
		
		args[3] = {"-"}

		pos_functions["nouns"].func(args, data)
	end
}

function generate_plurals(PAGENAME)
	local m_common = require("Module:nl-common")
	local generated = {}
	
	generated["-s"] = PAGENAME .. "s"
	generated["-'s"] = PAGENAME .. "'s"
	
	local stem_FF = m_common.add_e(PAGENAME, false, false)
	local stem_TF = m_common.add_e(PAGENAME, true, false)
	local stem_FT = m_common.add_e(PAGENAME, false, true)
	
	generated["-es"] = stem_FF .. "s"
	generated["-@es"] = stem_TF .. "s"
	generated["-:es"] = stem_FT .. "s"
	
	generated["-en"] = stem_FF .. "n"
	generated["-@en"] = stem_TF .. "n"
	generated["-:en"] = stem_FT .. "n"
	
	generated["-eren"] = m_common.add_e(PAGENAME .. (PAGENAME:find("n$") and "d" or ""), false, false) .. "ren"
	generated["-:eren"] = stem_FT .. "ren"
	
	if PAGENAME:find("f$") then
		local stem = PAGENAME:gsub("f$", "v")
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
	elseif PAGENAME:find("s$") then
		local stem = PAGENAME:gsub("s$", "z")
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
	elseif PAGENAME:find("heid$") then
		generated["-heden"] = PAGENAME:gsub("heid$", "heden")
	end
	
	return generated
end

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
