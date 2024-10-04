local export = {}
local pos_functions = {}
local rsubn = mw.ustring.gsub

local lang = require("Module:languages").getByCode("sk")
local langname = lang:getCanonicalName()

local suffix_categories = {
	["adjectives"] = true,
	["adverbs"] = true,
	["nouns"] = true,
	["verbs"] = true,
	["prepositional phrases"] = true,
}

-- version of rsubn() that discards all but the first return value
local function rsub(term, foo, bar)
	local retval = rsubn(term, foo, bar)
	return retval
end

local function track(page)
	require("Module:debug").track("sk-headword/" .. page)
	return true
end

local function glossary_link(entry, text)
	text = text or entry
	return "[[Appendix:Glossary#" .. entry .. "|" .. text .. "]]"
end

-- The main entry point.
-- This is the only function that can be invoked from a template.
function export.show(frame)
	local poscat = frame.args[1] or error("Part of speech has not been specified. Please pass parameter 1 to the module invocation.")

	local params = {
		["head"] = {list = true},
		["nolinkhead"] = {type = "boolean"},
		["pagename"] = {}, -- for testing
		["sort"] = {}, -- FIXME, needed?
	}

	if pos_functions[poscat] then
		for key, val in pairs(pos_functions[poscat].params) do
			params[key] = val
		end
	end

	local parargs = frame:getParent().args
	local args = require("Module:parameters").process(parargs, params)

	local pagename = args.pagename or mw.title.getCurrentTitle().text

	local heads = args.head
	if pos_functions[poscat] and pos_functions[poscat].param1_is_head and args[1] then
		table.insert(heads, 1, args[1])
	end

	local data = {
		lang = lang,
		pos_category = poscat,
		categories = {},
		heads = heads,
		genders = {},
		inflections = {},
		categories = {},
		pagename = pagename,
		sort_key = args.sort,
	}

	if pagename:find("^%-") and suffix_categories[poscat] then
		data.pos_category = "suffixes"
		local singular_poscat = poscat:gsub("s$", "")
		table.insert(data.categories, langname .. " " .. singular_poscat .. "-forming suffixes")
	end

	if pos_functions[poscat] then
		pos_functions[poscat].func(args, data)
	end

	return require("Module:headword").full_headword(data)
end

local listToSet = require("Module:table/listToSet")
local allowed_genders = listToSet {
	"m", "m-an", "m-in", "f", "n", "mf", "mf-an", "mf-in", "mfbysense", "mfbysense-an", "mfbysense-in",
	"m-p", "m-an-p", "m-in-p", "f-p", "n-p", "mf-p", "mf-an-p", "mf-in-p", "mfbysense-p", "mfbysense-an-p", "mfbysense-in-p",
	"?",
}
local allowed_decl_patterns = listToSet {
	"chlap", "dievča", "dub", "gazdiná", "hrdina", "kosť", "mesto", "srdce", "stroj", "ulica", "vysvedčenie", "žena",
	-- In use but not in the Appendix
	"dlaň", "idea", "kuli", "pani",
}

local function get_noun_pos(is_proper)
	return {
		params = {
			["indecl"] = {type = "boolean"},
			[1] = {alias_of = "g"},
			["g"] = {list = true},
			["gen"] = {list = true},
			["genqual"] = {list = true, allow_holes = true},
			["genpl"] = {list = true},
			["genplqual"] = {list = true, allow_holes = true},
			["pl"] = {list = true},
			["plqual"] = {list = true, allow_holes = true},
			["decl"] = {list = true},
			["declqual"] = {list = true, allow_holes = true},
			["f"] = {list = true},
			["fqual"] = {list = true, allow_holes = true},
			["m"] = {list = true},
			["mqual"] = {list = true, allow_holes = true},
			["dim"] = {list = true},
			["dimqual"] = {list = true, allow_holes = true},
			["pej"] = {list = true},
			["pejqual"] = {list = true, allow_holes = true},
			["aug"] = {list = true},
			["augqual"] = {list = true, allow_holes = true},			
			["adj"] = {list = true},
			["adjqual"] = {list = true, allow_holes = true},
			["dem"] = {list = true},
			["demqual"] = {list = true, allow_holes = true},
			["fdem"] = {list = true},
			["fdemqual"] = {list = true, allow_holes = true},
			},
		func = function(args, data)
			-- Gather genders
			data.genders, animacy = args.g, true

			-- Validate genders
			for _, g in ipairs(data.genders) do
				if not allowed_genders[g] then
					error("Unrecognized " .. langname .. " gender: " .. g)
				end

				-- aminacy is undefined if masculine genders don't specify animacy
				if g:match("m") then animacy = animacy and g:match("-[ai]n") end
				
				if g:match("f") and #args.m > 0 then
					table.insert(data.categories, langname .. " female equivalent nouns")
				end
				
				if g:match("m") and #args.f > 0 then
					table.insert(data.categories, langname .. " male equivalent nouns")
				end
			end

			if #data.genders == 0 or not animacy then
				table.insert(data.categories, langname .. " terms with undefined animacy")
			end

			-- Validate declension patterns
			for _, decl in ipairs(args.decl) do
				if not allowed_decl_patterns[decl] then
					error("Unrecognized " .. langname .. " declension pattern: " .. decl)
				end
			end

			local function process_inflection(label, infls, quals, frob)
				infls.label = label
				for i, infl in ipairs(infls) do
					if frob then
						infl = frob(infl)
					end
					if quals[i] then
						infls[i] = {term = infl, q = {quals[i]}}
					end
				end
				if #infls > 0 then
					table.insert(data.inflections, infls)
				end
			end

			if args.indecl then
				table.insert(data.inflections, {label = glossary_link("indeclinable")})
			end

			-- Process all inflections.
			process_inflection("genitive singular", args["gen"], args["genqual"])
			process_inflection("nominative plural", args["pl"], args["plqual"])
			process_inflection("genitive plural", args["genpl"], args["genplqual"])
			process_inflection("declension pattern of", args["decl"], args["declqual"], function(decl)
				return ("[[Appendix:%s declension pattern %s|%s]]"):format(langname, decl, decl)
			end)
			process_inflection("feminine", args["f"], args["fqual"])
			process_inflection("masculine", args["m"], args["mqual"])
			process_inflection("diminutive", args["dim"], args["dimqual"])
			process_inflection("pejorative", args["pej"], args["pejqual"])
			process_inflection("augmentative", args["aug"], args["augqual"])
			process_inflection("related adjective", args["adj"], args["adjqual"])
			process_inflection("demonym", args["dem"], args["demqual"])
			process_inflection("female demonym", args["fdem"], args["fdemqual"])
		end
	}
end

pos_functions["nouns"] = get_noun_pos(false)

pos_functions["proper nouns"] = get_noun_pos(true)

return export
