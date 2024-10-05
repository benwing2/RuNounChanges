local export = {}
local pos_functions = {}

local force_cat = false -- for testing; if true, categories appear in non-mainspace pages

local listToSet = require("Module:table/listToSet")

-- Table of all valid genders.
local valid_genders = listToSet {
	"mfbysense", "mfbysense-p", "mfbysense-an", "mfbysense-an-p", "mfbysense-in", "mfbysense-in-p",
	"mf-an", "mf-an-p", "mf-in", "mf-in-p", "m-an", "m-an-p", "m-in", "m-in-p",
	"f", "f-p", "n", "n-p", "?", "?-p",
}
-- FUCKME. Many Slovak entries are missing the animacy. Fix them and then disallow not entering the animacy.
local addl_valid_sk_genders = listToSet {
	"mf", "mf-p", "m", "m-p",
}

-- Table of all valid aspects.
local valid_aspects = {
	"impf", "pf", "both", "biasp", "?",
}

local allowed_sk_decl_patterns = listToSet {
	"chlap", "dievča", "dub", "gazdiná", "hrdina", "kosť", "mesto", "srdce", "stroj", "ulica", "vysvedčenie", "žena",
	-- In use but not in the Appendix
	"dlaň", "idea", "kuli", "pani",
}

local rfind = mw.ustring.find

local function track(track_id)
	require("Module:debug/track")("cs-sk-headword/" .. track_id)
	return true
end

local function glossary_link(anchor, text)
	text = text or anchor
	return "[[Appendix:Glossary#" .. anchor .. "|" .. text .. "]]"
end

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

local function parse_term_with_modifiers(paramname, val, frob)
	local function generate_obj(term, parse_err)
		if frob then
			term = frob(term)
		end
		return {term = term}
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
end

local function parse_term_list_with_modifiers(paramname, list, frob)
	local first, restpref
	if type(paramname) == "table" then
		first = paramname[1]
		restpref = paramname[2]
	else
		first = paramname
		restpref = paramname
	end
	for i, val in ipairs(list) do
		list[i] = parse_term_with_modifiers(i == 1 and first or restpref .. i, val, frob)
	end
	return list
end

-- The main entry point.
-- This is the only function that can be invoked from a template.
function export.show(frame)
	local iparams = {
		[1] = {required = true},
		["lang"] = {required = true},
		["def"] = {},
	}
	local iargs = require("Module:parameters").process(frame.args, iparams)
	local args = frame:getParent().args
	local poscat = iargs[1]
	local langcode = iargs.lang
	if langcode ~= "cs" and langcode ~= "sk" then
		error("This module currently only works for lang=cs and lang=sk")
	end
	local lang = require("Module:languages").getByCode(langcode, true)
	local langname = lang:getCanonicalName()
	local def = iargs.def

	local parargs = frame:getParent().args

	local params = {
		["head"] = {list = true},
		["id"] = {},
		["sort"] = {},
		["splithyph"] = {type = "boolean"},
		["nolinkhead"] = {type = "boolean"},
		["json"] = {type = "boolean"},
		["pagename"] = {}, -- for testing
	}

	if pos_functions[poscat] then
		local params = pos_functions[poscat].params
		if type(params) == "function" then
			params = params(lang)
		end
		for key, val in pairs(pos_functions[poscat].params) do
			params[key] = val
		end
	end

    local args = require("Module:parameters").process(parargs, params)

	local pagename = args.pagename or mw.title.getCurrentTitle().text

	local data = {
		lang = lang,
		langname = langname,
		pos_category = poscat,
		categories = {},
		heads = args.head,
		genders = {},
		inflections = {},
		pagename = pagename,
		id = args.id,
		sort_key = args.sort,
		force_cat_output = force_cat,
		def = def,
		is_suffix = false,
	}

	if pagename:find("^%-") and poscat ~= "suffix forms" then
		data.is_suffix = true
		data.pos_category = "suffixes"
		local singular_poscat = require("Module:string utilities").singularize(poscat)
		table.insert(data.categories, langname .. " " .. singular_poscat .. "-forming suffixes")
		table.insert(data.inflections, {label = singular_poscat .. "-forming suffix"})
	end

	if pos_functions[poscat] then
		pos_functions[poscat].func(args, data)
	end

	-- mw.ustring.toNFD performs decomposition, so letters that decompose
	-- to an ASCII vowel and a diacritic, such as é, are counted as vowels and
	-- do not need to be included in the pattern.
	if not pagename:find("[ %-]") and not rfind(mw.ustring.lower(mw.ustring.toNFD(pagename)), "[aeiouyæœø]") then
		table.insert(data.categories, langname .. " words without vowels")
	end

    if args.json then
        return require("Module:JSON").toJSON(data)
    end
	
	return require("Module:headword").full_headword(data)
end

local function get_noun_params(is_proper)
	return function(lang)
		local list_param = {list = true, disallow_holes = true}
		params = {
			[1] = {alias_of = "g"},
			["g"] = list_param,
			["g_qual"] = {list = "g\1_qual", allow_holes = true},
			["indecl"] = {type = "boolean"},
			["m"] = list_param,
			["f"] = list_param,
			["adj"] = list_param,
			["dim"] = list_param,
			["aug"] = list_param,
			["pej"] = list_param,
			["dem"] = list_param,
			["fdem"] = list_param,
			["gen"] = list_param,
			["pl"] = list_param,
			["genpl"] = list_param,
		}
		if lang:getCode() == "sk" then
			params["decl"] = list_param
		end
		return params
	end
end

local function do_nouns(is_proper, args, data)
	for i, g in ipairs(args.g) do
		if valid_genders[g] then
			-- do nothing
		elseif data.lang:getCode() == "sk" and addl_valid_sk_genders[g] then
			table.insert(data.categories, data.langname .. " terms with undefined animacy")
		else
			error("Unrecognized gender: '" .. g .. "'")
		end
		-- mfbysense should always be animate so add that
		if g == "mfbysense" then
			g = "mfbysense-an"
		elseif g == "mfbysense-p" then
			g = "mfbysense-an-p"
		end
		track("gender-" .. g)
		if args.g_qual[i] then
			table.insert(data.genders, {spec = g, qualifiers = {args.g_qual[i]}})
		else
			table.insert(data.genders, g)
		end
	end
	if #data.genders == 0 then
		table.insert(data.categories, data.langname .. " terms with undefined animacy")
	end
	if args.indecl then
		table.insert(data.inflections, {label = glossary_link("indeclinable")})
		table.insert(data.categories, data.langname .. " indeclinable nouns")
	end
	if data.lang:getCode() == "sk" then
		-- Validate declension patterns
		for _, decl in ipairs(args.decl) do
			if not allowed_sk_decl_patterns[decl] then
				error("Unrecognized " .. data.langname .. " declension pattern: " .. decl)
			end
		end
	end

	local function handle_infl(arg, label, frob)
		local vals = parse_term_list_with_modifiers(arg, args[arg], frob)
		if #vals > 0 then
			vals.label = label
			table.insert(data.inflections, vals)
		end
	end
	
	handle_infl("gen", "genitive singular")
	handle_infl("pl", "nominative plural")
	handle_infl("genpl", "genitive plural")
	handle_infl("decl", "declension pattern of", function(decl)
		return ("[[Appendix:%s declension pattern %s|%s]]"):format(data.langname, decl, decl)
	end)
	handle_infl("m", "male equivalent")
	handle_infl("f", "female equivalent")
	handle_infl("adj", "related adjective")
	handle_infl("dim", "diminutive")
	handle_infl("aug", "augmentative")
	handle_infl("pej", "pejorative")
	handle_infl("dem", "demonym")
	handle_infl("fdem", "female demonym")
end

pos_functions["nouns"] = {
	 params = get_noun_params(false),
	 func = function(args, data)
	 	return do_nouns(false, args, data)
	 end,
}

pos_functions["proper nouns"] = {
	 params = get_noun_params("proper noun"),
	 func = function(args, data)
	 	return do_nouns("proper noun", args, data)
	 end,
}

pos_functions["verbs"] = {
	params = {
		["a"] = {default = "?"},
		["pf"] = {list = true, disallow_holes = true},
		["impf"] = {list = true, disallow_holes = true},
	},
	func = function(args, data)
		if not valid_aspects[args.a] then
			error("Unrecognized aspect: '" .. args.a .. "'")
		end
		data.genders = args.a == "both" and {"biasp"} or {args.a}
	
		local pf = args.pf
		if #pf > 0 then
			pf.label = "perfective"
			table.insert(data.inflections, pf)
		end
		local impf = args.impf
		if #impf > 0 then
			impf.label = "imperfective"
			table.insert(data.inflections, impf)
		end
	end,
}

pos_functions["adjectives"] = {
	params = {
		[1] = {list = "comp"},
		[2] = {list = "sup"},
		["adv"] = {list = true},
		["indecl"] = {type = "boolean"},
	},
	func = function(args, data)
		if args.indecl then
			table.insert(data.inflections, {label = glossary_link("indeclinable")})
			table.insert(data.categories, data.langname .. " indeclinable adjectives")
		end
		if args[1][1] == "-" then
			table.insert(data.inflections, {label = "not comparable"})
			table.insert(data.categories, data.langname .. " uncomparable adjectives")
		elseif #args[1] > 0 then
			local comp = args[1]
			local sup = args[2]
			if #sup == 0 then
				for _, c in ipairs(comp) do
					table.insert(sup, "nej" .. c)
				end
			end
			comp.label = "comparative"
			comp.accel = {form = "comparative"}
			sup.label = "superlative"
			sup.accel = {form = "superlative"}
			table.insert(data.inflections, comp)
			table.insert(data.inflections, sup)
			table.insert(data.categories, data.langname .. " comparable adjectives")
		end
		if #args.adv > 0 then
			args.adv.label = "adverb"
			table.insert(data.inflections, args.adv)
		end
	end,
}

pos_functions["adverbs"] = {
	params = {
		[1] = {list = "comp"},
		[2] = {list = "sup"},
	},
	func = function(args, data)
		if args[1][1] == "-" then
			table.insert(data.inflections, {label = "not comparable"})
			table.insert(data.categories, data.langname .. " uncomparable adverbs")
		elseif #args[1] > 0 then
			local comp = args[1]
			local sup = args[2]
			if #sup == 0 then
				for _, c in ipairs(comp) do
					table.insert(sup, "naj" .. c)
				end
			end
			comp.label = "comparative"
			comp.accel = {form = "comparative"}
			sup.label = "superlative"
			sup.accel = {form = "superlative"}
			table.insert(data.inflections, comp)
			table.insert(data.inflections, sup)
			table.insert(data.categories, data.langname .. " comparable adverbs")
		end
	end,
}

return export
