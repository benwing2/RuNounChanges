local export = {}
local pos_functions = {}

local headword_utilities_module = require("Module:headword utilities")

local lang = require("Module:languages").getByCode("bg")
local langname = lang:getCanonicalName()

local function track(page)
	require("Module:debug/track")("bg-headword/" .. page)
	return true
end

local function glossary_link(anchor, text)
	text = text or anchor
	return "[[Appendix:Glossary#" .. anchor .. "|" .. text .. "]]"
end

-- The main entry point.
-- This is the only function that can be invoked from a template.
function export.show(frame)
	local poscat = frame.args[1] or error("Part of speech has not been specified. Please pass parameter 1 to the module invocation.")

	local params = {
		["head"] = {list = true, disallow_holes = true},
		[1] = {alias_of = "head"},
		["tr"] = {list = true, allow_holes = true},
		["id"] = {},
		["splithyph"] = {type = "boolean"},
		["nolinkhead"] = {type = "boolean"},
		["json"] = {type = "boolean"},
		["pagename"] = {}, -- for testing
	}
e
	if pos_functions[poscat] then
		for key, val in pairs(pos_functions[poscat].params) do
			params[key] = val
		end
	end
e
	local args = require("Module:parameters").process(frame:getParent().args, params)
	local pagename = args.pagename or mw.title.getCurrentTitle().subpageText

	local user_specified_heads = args.head
	local heads = user_specified_heads
	if args.nolinkhead then
		if #heads == 0 then
			heads = {pagename}
		else
			for i, head in ipairs(heads) do
				if head == auto_linked_head then
					track("redundant-head")
				end
				if not head or head == "+" then
					heads[i] = auto_linked_head
				end
			end
		end
	end

	local is_suffix = pagename:find("^%-") and poscat ~= "suffix forms"
	local orig_poscat = poscat
	poscat = pos_functions.overriding_poscat or poscat

	local data = {
		lang = lang,
		-- FIXME: Is the following necessary?
		pos_category = (mw.title.getCurrentTitle().nsText == "Reconstruction" and "reconstructed " or "") ..
			(is_suffix and "suffixes" or poscat),
		orig_poscat = orig_poscat,
		is_suffix = is_suffix,
		categories = {},
		heads = heads,
		user_specified_heads = user_specified_heads,
		no_redundant_head_cat = #user_specified_heads == 0,
		inflections = {},
		pagename = pagename,
		id = args.id,
		force_cat_output = force_cat,
	}

	if is_suffix then
		local singular_poscat = require("Module:string utilities").singularize(poscat)
		table.insert(data.categories, langname .. " " .. singular_poscat .. "-forming suffixes")
		table.insert(data.inflections, {label = singular_poscat .. "-forming suffix"})
	end

	if pos_functions[poscat] then
		pos_functions[poscat].func(args, data, is_suffix)
	end

	if args.json then
		return require("Module:JSON").toJSON(data)
	end

	return require("Module:headword").full_headword(data)
end


local function insert_infl(data, forms, label)
	if #forms > 0 then
		forms.label = label
		table.insert(data.inflections, forms)
	end
end


local function handle_infl(args, data, argpref, label)
	insert_infl(data, args[argpref], label)
end


pos_functions["verbs"] = {
	params = {
		[2] = {},
		["pf"] = {list = true},
		["impf"] = {list = true},
	}
	func = function(args, data)
		if args[2] == "pf" then
			data.genders = {"pf"}
		elseif args[2] == "impf" then
			data.genders = {"impf"}
		elseif args[2] == "both" or args[2] == "biasp" then
			data.genders = {"biasp"}
		elseif args[2] then
			error("Unrecognized aspect '" .. args[2] .. "'")
		end

		handle_infl(args, data, "pf", "perfective")
		handle_infl(args, data, "impf", "imperfective")
	end
}

local function verify_genders(genders) do
	for _, g in ipairs(genders) do
		if g == "m" or g == "m-p" or g == "f" or g == "f-p" or g == "n" or g == "n-p" or g == "p" or
			g == "mf" or g == "mf-p" or g == "mfbysense" or g == "mfbysense-p" then
			-- OK
		else
			error("Unrecognized gender: '" .. g .. "'")
		end
	end
end


nouns = {
	params = {
		[2] = {alias_of = "g"},
		["g"] = {list = true},
		["m"] = {list = true},
		["f"] = {list = true},
		["adj"] = {list = true},
		["dim"] = {list = true},
		["aug"] = {list = true},
		["pej"] = {list = true},
		["indecl"] = {type = "boolean"},
	}
	func = function(args, data)
		verify_genders(args.g)
		data.genders = args.g
		if args.indecl then
			table.insert(data.inflections, {label = glossary_link("indeclinable")})
		end
		handle_infl(args, data, "m", "masculine")
		handle_infl(args, data, "f", "feminine")
		handle_infl(args, data, "adj", "relational adjective")
		handle_infl(args, data, "dim", "diminutive")
		handle_infl(args, data, "aug", "augmentative")
		handle_infl(args, data, "pej", "pejorative")
	end,
}

pos_functions["nouns"] = nouns
pos_functions["proper nouns"] = nouns

-- Handle comparatives and superlatives for adjectives and adverbs, including user-specified comparatives and
-- superlatives and default-requested comparatives/superlatives using '+'. Code is the same for adjectives and adverbs.
local function handle_adj_adv_comp(args, data)
	local lemma = data.pagename
	local plpos = data.pos_category:gsub("^reconstructed ", "")

	if args.comp[1] == "-" then
		table.remove(args.comp, 1)
		if #args.comp > 0 then
			table.insert(data.inflections, {label = "sometimes " .. glossary_link("comparable")})
			table.insert(data.categories, langname .. " comparable " .. plpos)
			table.insert(data.categories, langname .. " uncomparable " .. plpos)
		else
			table.insert(data.inflections, {label = "not " .. glossary_link("comparable")})
			table.insert(data.categories, langname .. " uncomparable " .. plpos)
		end
	elseif #args.comp > 0 then
		table.insert(data.categories, langname .. " comparable " .. plpos)
	end

	-- If comp=+, use default comparative 'по́-...', and set a default superlative if unspecified.
	local saw_comp_plus = false
	local comps = {}
	for i, compval in ipairs(args.comp) do
		if compval == "+" then
			saw_comp_plus = true
			table.insert(comp, "по́-" .. head)
		else
			table.insert(comp, compval)
		end
	end
	if saw_comp_plus and #args.sup == 0 then
		args.sup = {"+"}
	end

	local sups = {}
	if args.sup[1] == "-" then
		table.insert(data.inflections, {label = "no superlative"})
	else
		-- If sup=+ (possibly from comp=+), use default superlative 'на́й-...'.
		for i, supval in ipairs(args.sup) do
			if supval == "+" then
				for _, head in ipairs(data.heads) do
					table.insert(sup, "на́й-" .. head)
				end
			else
				table.insert(sup, supval)
			end
		end
	end

	insert_infl(data, comps, "comparative")
	insert_infl(data, sups, "superlative")
end

pos_functions["adverbs"] = {
	params = {
		[2] = {alias_of = "comp"},
		["comp"] = {list = true},
		[3] = {alias_of = "sup"},
		["sup"] = {list = true},
	}
	func = function(args, data)
		handle_adj_adv_comp(args, data)
	end,
}


local function make_adjective_pos_function(pos)
	local params = {
		["indecl"] = {type = "boolean"},
		["dim"] = {list = true},
	}
	if pos == "adjectives" then
		params[2] = {alias_of = "comp"}
		params["comp"] = {list = true}
		params[3] = {alias_of = "sup"}
		params["sup"] = {list = true}
		params["adv"] = {list = true}
		params["absn"] = {list = true}
	end
	return {
		params = params,
		overriding_poscat = pos == "numerals" and "numerals" or nil,
		func = function(args, data)
			if args.indecl then
				table.insert(data.inflections, {label = glossary_link("indeclinable")})
			end
			handle_adj_adv_comp(args, data)
			handle_infl(args, data, "dim", "diminutive")
			handle_infl(args, data, "adv", "adverb")
			handle_infl(args, data, "absn", "abstract noun")
		end,
	}
end

pos_functions["adjectives"] = make_adjective_pos_function("adjectives")
pos_functions["determiners"] = make_adjective_pos_function("determiners")
pos_functions["pronouns"] = make_adjective_pos_function("pronouns")
pos_functions["numerals-adjective"] = make_adjective_pos_function("numerals")


pos_functions["participles"] = {
	params = {
		[2] = {required = true, list = true, default = "aor"},
	}
	func = function(args, data)
		table.insert(data.categories, "Bulgarian verb forms")
		for _, part in ipairs(args[2]) do
			if part == "adv" then
				table.insert(data.categories, "Bulgarian adverbial participles")
			elseif part == "aor" then
				table.insert(data.categories, "Bulgarian past active aorist participles")
			elseif part == "impf" then
				table.insert(data.categories, "Bulgarian past active imperfect participles")
			elseif part == "pres" then
				table.insert(data.categories, "Bulgarian present active participles")
			elseif part == "pass" or part == "ppp" then
				table.insert(data.categories, "Bulgarian past passive participles")
			elseif part == "prespass" then
				table.insert(data.categories, "Bulgarian present passive participles")
			else
				error("Unrecognized participle type '" .. part .. "': Should be adv, aor, impf, pres, pass or prespass")
			end
		end
	end
}


pos_functions["participle forms"] = {
	params = {},
	func = function(args, data)
		table.insert(data.categories, "Bulgarian verb forms")
	end
}


pos_functions["verbal nouns"] = {
	params = {
		["g"] = {list = true},
	},
	func = function(args, data)
		verify_genders(args.g)
		data.genders = args.g
		table.insert(data.categories, "Bulgarian verb forms")
	end
}


pos_functions["verbal noun forms"] = {
	params = {
		["g"] = {list = true},
	},
	overriding_poscat = "noun forms",
	func = function(args, data)
		verify_genders(args.g)
		data.genders = args.g
		table.insert(data.categories, "Bulgarian verb forms")
	end
}


return export
