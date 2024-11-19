local export = {}
local pos_functions = {}

local force_cat = false -- for testing; if true, categories appear in non-mainspace pages

local rfind = mw.ustring.find

local require_when_needed = require("Module:utilities/require when needed")
local m_table = require("Module:table")
local headword_utilities_module = "Module:headword utilities"
local m_headword_utilities = require_when_needed(headword_utilities_module)
local glossary_link = require_when_needed(headword_utilities_module, "glossary_link")

local list_param = {list = true, disallow_holes = true}

-- Table of all valid genders by language, mapping user-specified gender specs to canonicalized versions.
local valid_number_suffixes = {"", "-p"}
local valid_genders = {"m", "f", "n"}
local valid_gender_specs = {}

for _, gender in ipairs(valid_genders) do
	for _, number in ipairs(valid_number_suffixes) do
		local spec = gender .. number
		dest[spec] = spec
	end
end

local function track(track_id)
	require("Module:debug/track")("gmq-headword/" .. track_id)
	return true
end

-- Parse and insert an inflection not requiring additional processing into `data.inflections`. The raw arguments come
-- from `args[field]`, which is parsed for inline modifiers. `label` is the label that the inflections are given;
-- sections enclosed in <<...>> are linked to the glossary. `accel` is the accelerator form, or nil.
local function parse_and_insert_inflection(data, args, field, label, accel)
	m_headword_utilities.parse_and_insert_inflection {
		headdata = data,
		forms = args[field],
		paramname = field,
		label = label,
		accel = accel and {form = accel} or nil,
	}
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
	if langcode ~= "cs" and langcode ~= "sk" and langcode ~= "zlw-ocs" and langcode ~= "zlw-osk" then
		error("This module currently only works for lang=cs, lang=sk, lang=zlw-ocs and lang=zlw-osk")
	end
	local lang = require("Module:languages").getByCode(langcode, true)
	local langname = lang:getCanonicalName()
	local def = iargs.def

	local parargs = frame:getParent().args

	local params = {
		["head"] = list_param,
		["id"] = {},
		["sort"] = {},
		["nolinkhead"] = {type = "boolean"},
		["json"] = {type = "boolean"},
		["pagename"] = {}, -- for testing
	}

	if pos_functions[poscat] then
		local posparams = pos_functions[poscat].params
		if type(posparams) == "function" then
			posparams = posparams(lang)
		end
		for key, val in pairs(posparams) do
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
		params = {
			[1] = {alias_of = "g"},
			["g"] = list_param,
			["g_qual"] = {list = "g\1_qual", allow_holes = true},
			["indecl"] = {type = "boolean"},
			["m"] = list_param,
			["f"] = list_param,
			["dim"] = list_param,
			["aug"] = list_param,
			["pej"] = list_param,
			["dem"] = list_param,
			["fdem"] = list_param,
			["gen"] = list_param,
			["pl"] = list_param,
		}
		return params
	end
end

local function do_nouns(is_proper, args, data)
	local specs = valid_gender_specs[data.lang:getCode()]
	for i, g in ipairs(args.g) do
		local canon_g = specs[g]
		if canon_g then
			g = canon_g
		else
			error("Unrecognized gender: '" .. g .. "'")
		end
		track("gender-" .. g)
		if args.g_qual[i] then
			table.insert(data.genders, {spec = g, qualifiers = {args.g_qual[i]}})
		else
			table.insert(data.genders, g)
		end
	end
	if #data.genders == 0 then
		table.insert(data.genders, "?")
	end
	if args.indecl then
		table.insert(data.inflections, {label = glossary_link("indeclinable")})
		table.insert(data.categories, data.langname .. " indeclinable nouns")
	end

	-- Parse and insert an inflection not requiring additional processing into `data.inflections`. The raw arguments
	-- come from `args[field]`, which is parsed for inline modifiers. If there is a corresponding qualifier field
	-- `FIELD_qual`, qualifiers may additionally come from there. `label` is the label that the inflections are given,
	-- which is linked to the glossary if surrounded by <<..>> (which is removed). `plpos` is the plural part of speech,
	-- used in [[Category:LANGNAME PLPOS with red links in their headword lines]]. `accel` is the accelerator form, or
	-- nil.
	local function handle_infl(field, label, frob)
		m_headword_utilities.parse_and_insert_inflection {
			headdata = data,
			forms = args[field],
			paramname = field,
			label = label,
			frob = frob,
		}
	end

	handle_infl("gen", "genitive singular")
	handle_infl("pl", "nominative plural")
	handle_infl("m", "male equivalent")
	handle_infl("f", "female equivalent")
	handle_infl("dim", "<<diminutive>>")
	handle_infl("aug", "<<augmentative>>")
	handle_infl("pej", "<<pejorative>>")
	handle_infl("dem", "<<demonym>>")
	handle_infl("fdem", "female <<demonym>>")
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

local function do_comparative_superlative(args, data, plpos)
	if args[1][1] == "-" then
		table.insert(data.inflections, {label = "not " .. glossary_link("comparable")})
		table.insert(data.categories, data.langname .. " uncomparable " .. plpos)
	elseif args[1][1] or args[2][1] then
		local comp = m_headword_utilities.parse_term_list_with_modifiers {
			paramname = {1, "comp"},
			forms = args[1],
		}
		local sup = m_headword_utilities.parse_term_list_with_modifiers {
			paramname = {2, "sup"},
			forms = args[2],
		}
		if comp[1] then
			comp.label = glossary_link("comparative")
			-- comp.accel = {form = "comparative"}
			table.insert(data.inflections, comp)
		end
		if sup[1] then
			sup.label = glossary_link("superlative")
			-- sup.accel = {form = "superlative"}
			table.insert(data.inflections, sup)
		end
		table.insert(data.categories, data.langname .. " comparable " .. plpos)
	end
end

pos_functions["adjectives"] = {
	params = function(lang)
		local params = {
			[1] = {list = "comp", disallow_holes = true},
			[2] = {list = "sup", disallow_holes = true},
			["adv"] = list_param,
			["indecl"] = {type = "boolean"},
		}
		return params
	end,
	func = function(args, data)
		if args.indecl then
			table.insert(data.inflections, {label = glossary_link("indeclinable")})
			table.insert(data.categories, data.langname .. " indeclinable adjectives")
		end
		do_comparative_superlative(args, data, "adjectives")
		parse_and_insert_inflection(data, args, "adv", "adverb")
	end,
}

pos_functions["adverbs"] = {
	params = {
		[1] = {list = "comp", disallow_holes = true},
		[2] = {list = "sup", disallow_holes = true},
	},
	func = function(args, data)
		do_comparative_superlative(args, data, "adverbs")
	end,
}

return export
