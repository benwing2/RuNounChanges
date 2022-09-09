local export = {}
local pos_functions = {}
local rfind = mw.ustring.find
local rmatch = mw.ustring.match
local rsubn = mw.ustring.gsub
local rsplit = mw.text.split

local m_links = require("Module:links")
local m_table = require("Module:table")
local com = require("Module:pt-common")
local lang = require("Module:languages").getByCode("pt")
local langname = lang:getCanonicalName()

local suffix_categories = {
	["adjectives"] = true,
	["adverbs"] = true,
	["nouns"] = true,
	["verbs"] = true,
	["prepositional phrases"] = true,
}

local function track(page)
	require("Module:debug").track("pt-headword/" .. page)
	return true
end

local function glossary_link(entry, text)
	text = text or entry
	return "[[Appendix:Glossary#" .. entry .. "|" .. text .. "]]"
end


local function check_all_missing(forms, plpos, tracking_categories)
	for _, form in ipairs(forms) do
		if type(form) == "table" then
			form = form.term
		end
		if form then
			local title = mw.title.new(form)
			if title and not title.exists then
				table.insert(tracking_categories, langname .. " " .. plpos .. " with red links in their headword lines")
			end
		end
	end
end


-- The main entry point.
-- This is the only function that can be invoked from a template.
function export.show(frame)
	local poscat = frame.args[1] or error("Part of speech has not been specified. Please pass parameter 1 to the module invocation.")

	local parargs = frame:getParent().args

	local params = {
		["head"] = {list = true},
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

	local heads = args["head"]
	if args.nolinkhead then
		if #heads == 0 then
			heads = {pagename}
		end
	else
		local auto_linked_head = require("Module:romance utilities").add_lemma_links(pagename, args.splithyph)
		if #heads == 0 then
			heads = {auto_linked_head}
		else
			for _, head in ipairs(heads) do
				if head == auto_linked_head then
					track("redundant-head")
				end
			end
		end
	end

	local data = {
		lang = lang,
		pos_category = poscat,
		categories = {},
		heads = heads,
		genders = {},
		inflections = {},
		categories = {},
		pagename = pagename
	}

	if pagename:find("^%-") and suffix_categories[poscat] then
		data.pos_category = "suffixes"
		local singular_poscat = poscat:gsub("s$", "")
		table.insert(data.categories, langname .. " " .. singular_poscat .. "-forming suffixes")
	end

	local tracking_categories = {}

	if pos_functions[poscat] then
		pos_functions[poscat].func(args, data, tracking_categories, frame)
	end

	if args["json"] then
		return require("Module:JSON").toJSON(data)
	end

	return require("Module:headword").full_headword(data)
		.. (#tracking_categories > 0 and require("Module:utilities").format_categories(tracking_categories, lang) or "")
end


local function fetch_qualifiers(qual, existing)
	if not qual then
		return existing
	end
	if not existing then
		return {qual}
	end
	local retval = {}
	for _, e in ipairs(existing) do
		table.insert(retval, e)
	end
	table.insert(retval, qual)
	return retval
end


local function process_terms_with_qualifiers(terms, quals)
	local infls = {}
	for i, term in ipairs(terms) do
		table.insert(infls, {term = term, qualifiers = fetch_qualifiers(quals[i])})
	end
	return infls
end


local function do_adjective(args, data, tracking_categories, pos, is_superlative)
	local feminines = {}
	local masculine_plurals = {}
	local feminine_plurals = {}
	local plpos = require("Module:string utilities").pluralize(pos)

	local romut = require("Module:romance utilities")
	data.pos_category = plpos
	
	if args.sp and not romut.allowed_special_indicators[args.sp] then
		local indicators = {}
		for indic, _ in pairs(romut.allowed_special_indicators) do
			table.insert(indicators, "'" .. indic .. "'")
		end
		table.sort(indicators)
		error("Special inflection indicator beginning can only be " ..
			m_table.serialCommaJoin(indicators, {dontTag = true}) .. ": " .. args.sp)
	end

	local lemma = m_links.remove_links(data.heads[1]) -- should always be specified

	local function insert_inflection(forms, label, accel)
		if #forms > 0 then
			if forms[1].term == "-" then
				table.insert(data.inflections, {label = "no " .. label})
			else
				forms.label = label
				forms.accel = {form = accel}
				table.insert(data.inflections, forms)
			end
		end
	end

	if args.inv then
		-- invariable adjective
		table.insert(data.inflections, {label = glossary_link("invariable")})
		table.insert(data.categories, langname .. " indeclinable " .. plpos)
		if args.sp or #args.f > 0 or #args.pl > 0 or #args.mpl > 0 or #args.fpl > 0 then
			error("Can't specify inflections with an invariable adjective")
		end
	elseif args.fonly then
		-- feminine-only
		if #args.f > 0 then
			error("Can't specify explicit feminines with feminine-only adjective")
		end
		if #args.pl > 0 then
			error("Can't specify explicit plurals with feminine-only adjective, use fpl=")
		end
		if #args.mpl > 0 then
			error("Can't specify explicit masculine plurals with feminine-only adjective")
		end
		local argsfpl = args.fpl
		if #argsfpl == 0 then
			argsfpl = {"+"}
		end
		for i, fpl in ipairs(argsfpl) do
			if fpl == "+" then
				local defpl = com.make_plural(lemma, args.sp)
				if not defpl then
					error("Unable to generate default plural of '" .. lemma .. "'")
				end
				fpl = defpl
			elseif fpl == "#" then
				fpl = lemma
			end
			table.insert(feminine_plurals, {term = fpl, fetch_qualifiers(args.fpl_qual[i])})
		end

		check_all_missing(feminine_plurals, plpos, tracking_categories)

		table.insert(data.inflections, {label = "feminine-only"})
		insert_inflection(feminine_plurals, "feminine plural", "f|p")
	else
		-- Gather feminines.
		local argsf = args.f
		if #argsf == 0 then
			argsf = {"+"}
		end
		for i, f in ipairs(argsf) do
			if f == "+" then
				-- Generate default feminine.
				f = com.make_feminine(lemma, args.sp)
			elseif f == "#" then
				f = lemma
			end
			table.insert(feminines, {term = f, qualifiers = fetch_qualifiers(args.f_qual[i])})
		end

		local argsmpl = args.mpl
		local argsfpl = args.fpl
		if #args.pl > 0 then
			if #argsmpl > 0 or #argsfpl > 0 or args.mpl_qual.maxindex > 0 or args.fpl_qual.maxindex > 0 then
				error("Can't specify both pl= and mpl=/fpl=")
			end
			argsmpl = args.pl
			args.mpl_qual = args.pl_qual
			argsfpl = args.pl
			args.fpl_qual = args.pl_qual
		end
		if #argsmpl == 0 then
			argsmpl = {"+"}
		end
		if #argsfpl == 0 then
			argsfpl = {"+"}
		end

		for i, mpl in ipairs(argsmpl) do
			if mpl == "+" then
				-- Generate default masculine plural.
				local defpl = com.make_plural(lemma, args.sp)
				if not defpl then
					error("Unable to generate default plural of '" .. lemma .. "'")
				end
				mpl = defpl
			elseif mpl == "#" then
				mpl = lemma
			end
			table.insert(masculine_plurals, {term = mpl, qualifiers = fetch_qualifiers(args.mpl_qual[i])})
		end

		for i, fpl in ipairs(argsfpl) do
			if fpl == "+" then
				for _, f in ipairs(feminines) do
					-- Generate default feminine plural; f is a table.
					local defpl = com.make_plural(f.term, args.sp)
					if not defpl then
						error("Unable to generate default plural of '" .. f.term .. "'")
					end
					table.insert(feminine_plurals, {term = defpl, qualifiers = fetch_qualifiers(args.fpl_qual[i], f.qualifiers)})
				end
			elseif fpl == "#" then
				table.insert(feminine_plurals, {term = lemma, qualifiers = fetch_qualifiers(args.fpl_qual[i])})
			else
				table.insert(feminine_plurals, {term = fpl, qualifiers = fetch_qualifiers(args.fpl_qual[i])})
			end
		end

		check_all_missing(feminines, plpos, tracking_categories)
		check_all_missing(masculine_plurals, plpos, tracking_categories)
		check_all_missing(feminine_plurals, plpos, tracking_categories)

		local fem_like_lemma = #feminines == 1 and feminines[1].term == lemma and not feminines[1].qualifiers
		local fem_pl_like_masc_pl = #masculine_plurals > 0 and #feminine_plurals > 0 and
			m_table.deepEquals(masculine_plurals, feminine_plurals)
		local masc_pl_like_lemma = #masculine_plurals == 1 and masculine_plurals[1].term == lemma and
			not masculine_plurals[1].qualifiers
		if fem_like_lemma and fem_pl_like_masc_pl and masc_pl_like_lemma then
			-- actually invariable
			table.insert(data.inflections, {label = glossary_link("invariable")})
			table.insert(data.categories, langname .. " indeclinable " .. plpos)
		else
			-- Make sure there are feminines given and not same as lemma.
			if not fem_like_lemma then
				insert_inflection(feminines, "feminine", "f|s")
			end

			if fem_pl_like_masc_pl then
				insert_inflection(masculine_plurals, "plural", "p")
				data.genders = {"mf"}
			else
				insert_inflection(masculine_plurals, "masculine plural", "m|p")
				insert_inflection(feminine_plurals, "feminine plural", "f|p")
			end
		end
	end

	if args.n and #args.n > 0 then
		local neuters = process_terms_with_qualifiers(args.n, args.n_qual)
		check_all_missing(neuters, plpos, tracking_categories)
		neuters.label = "neuter"
		table.insert(data.inflections, neuters)
	end

	if args.hascomp then
		if args.hascomp == "both" then
			table.insert(data.inflections, {label = "sometimes " .. glossary_link("comparable")})
			table.insert(data.categories, langname .. " comparable adjectives")
			table.insert(data.categories, langname .. " uncomparable adjectives")
		else
			local hascomp = require("Module:yesno")(args.hascomp)
			if hascomp == true then
				table.insert(data.inflections, {label = glossary_link("comparable")})
				table.insert(data.categories, langname .. " comparable adjectives")
			elseif hascomp == false then
				table.insert(data.inflections, {label = "not " .. glossary_link("comparable")})
				table.insert(data.categories, langname .. " uncomparable adjectives")
			else
				error("Unrecognized value for hascomp=: " .. args.hascomp)
			end
		end
	elseif args.comp and #args.comp > 0 or args.sup and #args.sup > 0 then
		table.insert(data.inflections, {label = glossary_link("comparable")})
		table.insert(data.categories, langname .. " comparable adjectives")
	end

	if args.comp and #args.comp > 0 then
		local comps = process_terms_with_qualifiers(args.comp, args.comp_qual)
		check_all_missing(comps, plpos, tracking_categories)
		comps.label = "comparative"
		table.insert(data.inflections, comps)
	end

	if args.sup and #args.sup > 0 then
		local sups = process_terms_with_qualifiers(args.sup, args.sup_qual)
		check_all_missing(sups, plpos, tracking_categories)
		sups.label = "superlative"
		table.insert(data.inflections, sups)
	end

	if args.irreg and is_superlative then
		table.insert(data.categories, langname .. " irregular superlative adjectives")
	end
end

local function get_adjective_params(adjtype)
	local params = {
		["inv"] = {type = "boolean"}, --invariable
		["sp"] = {}, -- special indicator: "first", "first-last", etc.
		["f"] = {list = true}, --feminine form(s)
		["f_qual"] = {list = "f=_qual", allow_holes = true},
		["pl"] = {list = true}, --plural override(s)
		["pl_qual"] = {list = "pl=_qual", allow_holes = true},
		["mpl"] = {list = true}, --masculine plural override(s)
		["mpl_qual"] = {list = "mpl=_qual", allow_holes = true},
		["fpl"] = {list = true}, --feminine plural override(s)
		["fpl_qual"] = {list = "fpl=_qual", allow_holes = true},
	}
	if adjtype == "base" or adjtype == "part" or adjtype == "det" then
		params["comp"] = {list = true} --comparative(s)
		params["comp_qual"] = {list = "comp=_qual", allow_holes = true}
		params["sup"] = {list = true} --superlative(s)
		params["sup_qual"] = {list = "sup=_qual", allow_holes = true}
		params["fonly"] = {type = "boolean"} -- feminine only
		params["hascomp"] = {} -- has comparative
	end
	if adjtype == "sup" then
		params["irreg"] = {type = "boolean"}
	end
	if adjtype == "pron" then
		params["n"] = {list = true} --neuter form(s)
		params["n_qual"] = {list = "n=_qual", allow_holes = true}
	end
	return params
end

pos_functions["adjectives"] = {
	params = get_adjective_params("base"),
	func = function(args, data, tracking_categories)
		do_adjective(args, data, tracking_categories, "adjective")
	end,
}

pos_functions["comparative adjectives"] = {
	params = get_adjective_params("comp"),
	func = function(args, data, tracking_categories)
		do_adjective(args, data, tracking_categories, "adjective")
	end,
}

pos_functions["superlative adjectives"] = {
	params = get_adjective_params("sup"),
	func = function(args, data, tracking_categories)
		do_adjective(args, data, tracking_categories, "adjective", true)
	end,
}

pos_functions["past participles"] = {
	params = get_adjective_params("part"),
	func = function(args, data, tracking_categories)
		do_adjective(args, data, tracking_categories, "participle")
		data.pos_category = "past participles"
	end,
}

pos_functions["determiners"] = {
	params = get_adjective_params("det"),
	func = function(args, data, tracking_categories)
		do_adjective(args, data, tracking_categories, "determiner")
	end,
}

pos_functions["adjective-like pronouns"] = {
	params = get_adjective_params("pron"),
	func = function(args, data, tracking_categories)
		do_adjective(args, data, tracking_categories, "pronoun")
	end,
}

return export
