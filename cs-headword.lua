local export = {}
local pos_functions = {}

local force_cat = false -- for testing; if true, categories appear in non-mainspace pages

local lang = require("Module:languages").getByCode("cs")
local langname = "Czech"

-- Table of all valid genders.
local valid_genders = {
	["mfbysense"] = true,
	["mfbysense-p"] = true,
	["m-an"] = true,
	["m-an-p"] = true,
	["m-in"] = true,
	["m-in-p"] = true,
	["f"] = true,
	["f-p"] = true,
	["n"] = true,
	["n-p"] = true,
	["?"] = true,
	["?-p"] = true,
}

-- Table of all valid aspects.
local valid_aspects = {
	["impf"] = true,
	["pf"] = true,
	["both"] = true,
	["biasp"] = true,
	["?"] = true,
}

local rfind = mw.ustring.find

local function track(track_id)
	require("Module:debug/track")("cs-headword/" .. track_id)
	return true
end

local function glossary_link(anchor, text)
	text = text or anchor
	return "[[Appendix:Glossary#" .. anchor .. "|" .. text .. "]]"
end

-- The main entry point.
-- This is the only function that can be invoked from a template.
function export.show(frame)
	local iparams = {
		[1] = {required = true},
		["def"] = {},
	}
	local iargs = require("Module:parameters").process(frame.args, iparams)
	local args = frame:getParent().args
	local poscat = iargs[1]
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
		for key, val in pairs(pos_functions[poscat].params) do
			params[key] = val
		end
	end

    local args = require("Module:parameters").process(parargs, params)

	local pagename = args.pagename or mw.title.getCurrentTitle().text

	local data = {
		lang = lang,
		pos_category = poscat,
		categories = {},
		heads = args.head,
		genders = {},
		inflections = {},
		pagename = pagename,
		id = args.id,
		sort_key = args.sort,
		force_cat_output = force_cat,
	}

	local is_suffix = false
	if pagename:find("^%-") and poscat ~= "suffix forms" then
		is_suffix = true
		data.pos_category = "suffixes"
		local singular_poscat = require("Module:string utilities").singularize(poscat)
		table.insert(data.categories, langname .. " " .. singular_poscat .. "-forming suffixes")
		table.insert(data.inflections, {label = singular_poscat .. "-forming suffix"})
	end

	if pos_functions[poscat] then
		pos_functions[poscat].func(def, args, data, is_suffix)
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
	params = {
		[1] = {alias_of = "g"},
		["indecl"] = {type = "boolean"},
	}
	local function insert_list_param(arg)
		params[arg] = {list = true}
		params[arg .. "_qual"] = {list = arg .. "\1_qual", allow_holes = true}
	end
	insert_list_param("g")
	insert_list_param("m")
	insert_list_param("f")
	insert_list_param("adj")
	insert_list_param("dim")
	insert_list_param("aug")
	insert_list_param("pej")
	insert_list_param("dem")
	insert_list_param("fdem")
	return params
end

local function do_nouns(is_proper, def, args, data, is_suffix)
	for i, g in ipairs(args.g) do
		if not valid_genders[g] then
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
	if args.indecl then
		table.insert(data.inflections, {label = glossary_link("indeclinable")})
		table.insert(data.categories, langname .. " indeclinable nouns")
	end
	local function handle_infl(arg, label)
		local vals = args[arg]
		local quals = args[arg .. "_qual"]
		if #vals > 0 then
			local inflections = {}
			for i, val in ipairs(vals) do
				table.insert(inflections, {term = val, q = quals and quals[i] and {quals[i]} or nil})
			end
			inflections.label = label
			table.insert(data.inflections, inflections)
		end
	end
	
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
	 func = function(def, args, data, is_suffix)
	 	return do_nouns(false, def, args, data, is_suffix)
	 end,
}

pos_functions["proper nouns"] = {
	 params = get_noun_params("proper noun"),
	 func = function(def, args, data, is_suffix)
	 	return do_nouns("proper noun", def, args, data, is_suffix)
	 end,
}

pos_functions["verbs"] = {
	params = {
		["a"] = {default = "?"},
		["pf"] = {list = true},
		["impf"] = {list = true},
	},
	func = function(def, args, data, is_suffix)
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
	func = function(def, args, data, is_suffix)
		if args.indecl then
			table.insert(data.inflections, {label = glossary_link("indeclinable")})
			table.insert(data.categories, langname .. " indeclinable adjectives")
		end
		if args[1][1] == "-" then
			table.insert(data.inflections, {label = "not comparable"})
			table.insert(data.categories, langname .. " uncomparable adjectives")
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
			table.insert(data.categories, langname .. " comparable adjectives")
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
	func = function(def, args, data, is_suffix)
		if args[1][1] == "-" then
			table.insert(data.inflections, {label = "not comparable"})
			table.insert(data.categories, langname .. " uncomparable adverbs")
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
			table.insert(data.categories, langname .. " comparable adverbs")
		end
	end,
}

return export
