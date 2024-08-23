local export = {}
local pos_functions = {}

local force_cat = false -- for testing; if true, categories appear in non-mainspace pages

local rfind = mw.ustring.find
local rmatch = mw.ustring.match

local m_table = require("Module:table")
local com = require("Module:es-common")
local inflection_utilities_module = "Module:User:Benwing2/inflection utilities"
local headword_module = "Module:headword"
local romut_module = "Module:romance utilities"
local es_verb_module = "Module:es-verb"

local lang = require("Module:languages").getByCode("es")
local langname = lang:getCanonicalName()

local rsub = com.rsub
local usub = mw.ustring.sub

local function track(page)
	require("Module:debug").track("es-headword/" .. page)
	return true
end

-- The main entry point.
-- This is the only function that can be invoked from a template.
function export.show(frame)
	local poscat = frame.args[1]
		or error("Part of speech has not been specified. Please pass parameter 1 to the module invocation.")

	local parargs = frame:getParent().args

	local params = {
		["head"] = {list = true},
		["id"] = {},
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

	local pagename = args.pagename or mw.loadData("Module:headword/data").pagename

	local user_specified_heads = args.head
	local heads = user_specified_heads
	if args.nolinkhead then
		if #heads == 0 then
			heads = {pagename}
		end
	else
		local romut = require(romut_module)
		local auto_linked_head = romut.add_links_to_multiword_term(pagename, args.splithyph)
		if #heads == 0 then
			heads = {auto_linked_head}
		else
			for i, head in ipairs(heads) do
				if head:find("^~") then
					head = romut.apply_link_modifiers(auto_linked_head, usub(head, 2))
					heads[i] = head
				end
			end
		end
	end

	local data = {
		lang = lang,
		pos_category = poscat,
		categories = {},
		heads = heads,
		user_specified_heads = user_specified_heads,
		no_redundant_head_cat = #user_specified_heads == 0,
		genders = {},
		inflections = {},
		pagename = pagename,
		id = args.id,
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
		pos_functions[poscat].func(args, data, frame, is_suffix)
	end

	if args.json then
		return require("Module:JSON").toJSON(data)
	end

	return require(headword_module).full_headword(data)
end

-----------------------------------------------------------------------------------------
--                                     Utility functions                               --
-----------------------------------------------------------------------------------------

local function glossary_link(entry, text)
	text = text or entry
	return "[[Appendix:Glossary#" .. entry .. "|" .. text .. "]]"
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
		table.insert(infls, {term = term, q = fetch_qualifiers(quals[i])})
	end
	return infls
end


local function replace_hash_with_lemma(term, lemma)
	-- If there is a % sign in the lemma, we have to replace it with %% so it doesn't get interpreted as a capture replace
	-- expression.
	lemma = lemma:gsub("%%", "%%%%")
	-- Assign to a variable to discard second return value.
	term = term:gsub("#", lemma)
	return term
end

local function check_all_missing(data, forms, plpos)
	for _, form in ipairs(forms) do
		if type(form) == "table" then
			form = form.term
		end
		if form then
			local title = mw.title.new(form)
			if title and not title.exists then
				table.insert(data.categories, langname .. " " .. plpos .. " with red links in their headword lines")
			end
		end
	end
end

local function insert_ancillary_inflection(data, forms, quals, label, plpos)
	if forms and #forms > 0 then
		local terms = process_terms_with_qualifiers(forms, quals)
		check_all_missing(data, terms, plpos)
		terms.label = label
		table.insert(data.inflections, terms)
	end
end

-----------------------------------------------------------------------------------------
--                                       Adjectives                                    --
-----------------------------------------------------------------------------------------

local function do_adjective(args, data, pos, is_suffix, is_superlative)
	local feminines = {}
	local masculine_plurals = {}
	local feminine_plurals = {}
	if is_suffix then
		pos = "suffix"
	end
	local plpos = require("Module:string utilities").pluralize(pos)

	if not is_suffix then
		data.pos_category = plpos
	end

	if args.sp then
		local romut = require(romut_module)
		if not romut.allowed_special_indicators[args.sp] then
			local indicators = {}
			for indic, _ in pairs(romut.allowed_special_indicators) do
				table.insert(indicators, "'" .. indic .. "'")
			end
			table.sort(indicators)
			error("Special inflection indicator beginning can only be " ..
				m_table.serialCommaJoin(indicators, {dontTag = true}) .. ": " .. args.sp)
		end
	end

	local lemma = data.pagename

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
			error("Can't specify inflections with an invariable " .. pos)
		end
	elseif args.fonly then
		-- feminine-only
		if #args.f > 0 then
			error("Can't specify explicit feminines with feminine-only " .. pos)
		end
		if #args.pl > 0 then
			error("Can't specify explicit plurals with feminine-only " .. pos .. ", use fpl=")
		end
		if #args.mpl > 0 then
			error("Can't specify explicit masculine plurals with feminine-only " .. pos)
		end
		local argsfpl = args.fpl
		if #argsfpl == 0 then
			argsfpl = {"+"}
		end
		for i, fpl in ipairs(argsfpl) do
			local quals = fetch_qualifiers(args.fpl_qual[i])
			if fpl == "+" then
				-- Generate default feminine plural.
				local defpls = com.make_plural(lemma, "f", args.sp)
				if not defpls then
					error("Unable to generate default plural of '" .. lemma .. "'")
				end
				for _, defpl in ipairs(defpls) do
					table.insert(feminine_plurals, {term = defpl, q = quals})
				end
			else
				table.insert(feminine_plurals, {term = replace_hash_with_lemma(fpl, lemma), q = quals})
			end
		end

		check_all_missing(data, feminine_plurals, plpos)

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
			else
				f = replace_hash_with_lemma(f, lemma)
			end
			table.insert(feminines, {term = f, q = fetch_qualifiers(args.f_qual[i])})
		end

		local fem_like_lemma = #feminines == 1 and feminines[1].term == lemma and not feminines[1].q
		if fem_like_lemma then
			table.insert(data.categories, langname .. " epicene " .. plpos)
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
			local quals = fetch_qualifiers(args.mpl_qual[i])
			if mpl == "+" then
				-- Generate default masculine plural.
				local defpls = com.make_plural(lemma, "m", args.sp)
				if not defpls then
					error("Unable to generate default plural of '" .. lemma .. "'")
				end
				for _, defpl in ipairs(defpls) do
					table.insert(masculine_plurals, {term = defpl, q = quals})
				end
			else
				table.insert(masculine_plurals, {term = replace_hash_with_lemma(mpl, lemma), q = quals})
			end
		end

		for i, fpl in ipairs(argsfpl) do
			if fpl == "+" then
				for _, f in ipairs(feminines) do
					-- Generate default feminine plural; f is a table.
					local defpls = com.make_plural(f.term, "f", args.sp)
					if not defpls then
						error("Unable to generate default plural of '" .. f.term .. "'")
					end
					local fquals = fetch_qualifiers(args.fpl_qual[i], f.q)
					for _, defpl in ipairs(defpls) do
						table.insert(feminine_plurals, {term = defpl, q = fquals})
					end
				end
			else
				fpl = replace_hash_with_lemma(fpl, lemma)
				table.insert(feminine_plurals, {term = fpl, q = fetch_qualifiers(args.fpl_qual[i])})
			end
		end

		if args.mapoc then
			check_all_missing(data, args.mapoc, plpos)
		end
		check_all_missing(data, feminines, plpos)
		check_all_missing(data, masculine_plurals, plpos)
		check_all_missing(data, feminine_plurals, plpos)

		insert_ancillary_inflection(data, args.mapoc, args.mapoc_qual, "masculine singular before a noun", plpos)

		local fem_pl_like_masc_pl = #masculine_plurals > 0 and #feminine_plurals > 0 and
			m_table.deepEquals(masculine_plurals, feminine_plurals)
		local masc_pl_like_lemma = #masculine_plurals == 1 and masculine_plurals[1].term == lemma and
			not masculine_plurals[1].q
		if fem_like_lemma and fem_pl_like_masc_pl and masc_pl_like_lemma then
			-- actually invariable
			table.insert(data.inflections, {label = glossary_link("invariable")})
			table.insert(data.categories, langname .. " indeclinable " .. plpos)
		else
			-- Make sure there are feminines given and not same as lemma.
			if not fem_like_lemma then
				insert_inflection(feminines, "feminine", "f|s")
			elseif args.gneut then
				data.genders = {"gneut"}
			else
				data.genders = {"mf"}
			end

			if fem_pl_like_masc_pl then
				if args.gneut then
					insert_inflection(masculine_plurals, "plural", "p")
				else
					insert_inflection(masculine_plurals, "masculine and feminine plural", "p")
				end
			else
				insert_inflection(masculine_plurals, "masculine plural", "m|p")
				insert_inflection(feminine_plurals, "feminine plural", "f|p")
			end
		end
	end

	insert_ancillary_inflection(data, args.comp, args.comp_qual, "comparative", plpos)
	insert_ancillary_inflection(data, args.sup, args.sup_qual, "superlative", plpos)
	insert_ancillary_inflection(data, args.dim, args.dim_qual, "diminutive", plpos)
	insert_ancillary_inflection(data, args.aug, args.aug_qual, "augmentative", plpos)

	if args.irreg and is_superlative then
		table.insert(data.categories, langname .. " irregular superlative " .. plpos)
	end
end


local function get_adjective_params(adjtype)
	local params = {
		["inv"] = {type = "boolean"}, --invariable
		["sp"] = {}, -- special indicator: "first", "first-last", etc.
		["f"] = {list = true}, --feminine form(s)
		["f_qual"] = {list = "f\1_qual", allow_holes = true},
		["pl"] = {list = true}, --plural override(s)
		["pl_qual"] = {list = "pl\1_qual", allow_holes = true},
		["mpl"] = {list = true}, --masculine plural override(s)
		["mpl_qual"] = {list = "mpl\1_qual", allow_holes = true},
		["fpl"] = {list = true}, --feminine plural override(s)
		["fpl_qual"] = {list = "fpl\1_qual", allow_holes = true},
	}
	if adjtype == "base" then
		params["mapoc"] = {list = true} --masculine apocopated (before a noun)
		params["mapoc_qual"] = {list = "mapoc\1_qual", allow_holes = true}
		params["comp"] = {list = true} --comparative(s)
		params["comp_qual"] = {list = "comp\1_qual", allow_holes = true}
		params["sup"] = {list = true} --superlative(s)
		params["sup_qual"] = {list = "sup\1_qual", allow_holes = true}
		params["dim"] = {list = true} --diminutive(s)
		params["dim_qual"] = {list = "dim\1_qual", allow_holes = true}
		params["aug"] = {list = true} --augmentative(s)
		params["aug_qual"] = {list = "aug\1_qual", allow_holes = true}
		params["fonly"] = {type = "boolean"} -- feminine only
		params["gneut"] = {type = "boolean"} -- gender-neutral adjective e.g. [[latine]]
		params["hascomp"] = {} -- has comparative
	end
	if adjtype == "sup" then
		params["irreg"] = {type = "boolean"}
	end
	return params
end

-- Display additional inflection information for an adjective
pos_functions["adjectives"] = {
	params = get_adjective_params("base"),
	func = function(args, data, frame, is_suffix)
		do_adjective(args, data, "adjective", is_suffix, false)
	end
}

pos_functions["past participles"] = {
	params = get_adjective_params("part"),
	func = function(args, data, frame, is_suffix)
		do_adjective(args, data, "participle", is_suffix, false)
		data.pos_category = "past participles"
	end,
}

pos_functions["determiners"] = {
	params = get_adjective_params("det"),
	func = function(args, data, frame, is_suffix)
		do_adjective(args, data, "determiner", is_suffix, false)
	end
}

pos_functions["pronouns"] = {
	params = get_adjective_params("pron"),
	func = function(args, data, frame, is_suffix)
		do_adjective(args, data, "pronoun", is_suffix, false)
	end
}

pos_functions["comparative adjectives"] = {
	params = get_adjective_params("comp"),
	func = function(args, data, frame, is_suffix)
		do_adjective(args, data, "adjective", is_suffix, false)
	end
}

pos_functions["superlative adjectives"] = {
	params = get_adjective_params("sup"),
	func = function(args, data, frame, is_suffix)
		do_adjective(args, data, "adjective", is_suffix, true)
	end
}

-----------------------------------------------------------------------------------------
--                                         Adverbs                                     --
-----------------------------------------------------------------------------------------

pos_functions["adverbs"] = {
	params = {
		["sup"] = {list = true}, --superlative(s)
	},
	func = function(args, data)
		if #args.sup > 0 then
			check_all_missing(data, args.sup, "adverbs")
			args.sup.label = "superlative"
			table.insert(data.inflections, args.sup)
		end
	end,
}

-----------------------------------------------------------------------------------------
--                                        Numerals                                     --
-----------------------------------------------------------------------------------------

pos_functions["cardinal numbers"] = {
	params = {
		["f"] = {list = true}, --feminine(s)
		["mapoc"] = {list = true}, --masculine apocopated form(s)
	},
	func = function(args, data)
		data.pos_category = "numerals"
		table.insert(data.categories, 1, langname .. " cardinal numbers")

		if #args.f > 0 then
			table.insert(data.genders, "m")
			check_all_missing(data, args.f, "numerals")
			args.f.label = "feminine"
			table.insert(data.inflections, args.f)
		end
		if #args.mapoc > 0 then
			check_all_missing(data, args.mapoc, "numerals")
			args.mapoc.label = "masculine before a noun"
			table.insert(data.inflections, args.mapoc)
		end
	end,
}

-----------------------------------------------------------------------------------------
--                                          Nouns                                      --
-----------------------------------------------------------------------------------------

local allowed_genders = require("Module:table/listToSet")(
	{"m", "f", "mf", "mfbysense", "mfequiv", "gneut", "n", "m-p", "f-p", "mf-p", "mfbysense-p", "mfequiv-p", "gneut-p", "n-p", "?", "?-p"}
)


local function process_genders(data, genders, g_qual)
	for i, g in ipairs(genders) do
		if not allowed_genders[g] then
			error("Unrecognized gender: " .. g)
		end
		if g_qual[i] then
			table.insert(data.genders, {spec = g, qualifiers = {g_qual[i]}})
		else
			table.insert(data.genders, g)
		end
	end
end

-- Display additional inflection information for a noun
local function do_noun(args, data, pos, is_suffix)
	local is_plurale_tantum = false
	local has_singular = false
	if is_suffix then
		pos = "suffix"
	end
	local plpos = require("Module:string utilities").pluralize(pos)

	data.genders = {}
	local saw_m = false
	local saw_f = false
	local saw_gneut = false
	local gender_for_irreg_ending, gender_for_make_plural
	process_genders(data, args[1], args.g_qual)
	-- Check for specific genders and pluralia tantum.
	for _, g in ipairs(args[1]) do
		if g:find("-p$") then
			is_plurale_tantum = true
		else
			has_singular = true
			if g == "m" or g == "mf" or g == "mfbysense" then
				saw_m = true
			end
			if g == "f" or g == "mf" or g == "mfbysense" then
				saw_f = true
			end
			if g == "gneut" then
				saw_gneut = true
			end
		end
	end
	if saw_m and saw_f then
		gender_for_irreg_ending = "mf"
	elseif saw_f then
		gender_for_irreg_ending = "f"
	else
		gender_for_irreg_ending = "m"
	end
	gender_for_make_plural = saw_gneut and "gneut" or gender_for_irreg_ending

	local lemma = data.pagename

	local plurals = {}

	if is_plurale_tantum and not has_singular then
		if #args[2] > 0 then
			error("Can't specify plurals of plurale tantum " .. pos)
		end
		table.insert(data.inflections, {label = glossary_link("plural only")})
	else
		-- Gather plurals, handling requests for default plurals
		for _, pl in ipairs(args[2]) do
			if pl == "+" then
				local default_pls = com.make_plural(lemma, gender_for_make_plural)
				for _, defp in ipairs(default_pls) do
					table.insert(plurals, defp)
				end
			elseif pl:find("^%+") then
				pl = require(romut_module).get_special_indicator(pl)
				local default_pls = com.make_plural(lemma, gender_for_make_plural, pl)
				for _, defp in ipairs(default_pls) do
					table.insert(plurals, defp)
				end
			else
				table.insert(plurals, replace_hash_with_lemma(pl, lemma))
			end
		end

		-- Check for special plural signals
		local mode = nil

		if #plurals > 0 and #plurals[1] == 1 then
			if plurals[1] == "?" or plurals[1] == "!" or plurals[1] == "-" or plurals[1] == "~" then
				mode = plurals[1]
				table.remove(plurals, 1)  -- Remove the mode parameter
			else
				error("Unexpected plural code")
			end
		end

		if mode == "?" then
			-- Plural is unknown
			table.insert(data.categories, langname .. " " .. plpos .. " with unknown or uncertain plurals")
		elseif mode == "!" then
			-- Plural is not attested
			table.insert(data.inflections, {label = "plural not attested"})
			table.insert(data.categories, langname .. " " .. plpos .. " with unattested plurals")
			return
		elseif mode == "-" then
			-- Uncountable noun; may occasionally have a plural
			table.insert(data.categories, langname .. " uncountable " .. plpos)

			-- If plural forms were given explicitly, then show "usually"
			if #plurals > 0 then
				table.insert(data.inflections, {label = "usually " .. glossary_link("uncountable")})
				table.insert(data.categories, langname .. " countable " .. plpos)
			else
				table.insert(data.inflections, {label = glossary_link("uncountable")})
			end
		else
			-- Countable or mixed countable/uncountable
			if #plurals == 0 then
				local pls = com.make_plural(lemma, gender_for_make_plural)
				if pls then
					for _, pl in ipairs(pls) do
						table.insert(plurals, pl)
					end
				end
			end
			if mode == "~" then
				-- Mixed countable/uncountable noun, always has a plural
				table.insert(data.inflections, {label = glossary_link("countable") .. " and " .. glossary_link("uncountable")})
				table.insert(data.categories, langname .. " uncountable " .. plpos)
				table.insert(data.categories, langname .. " countable " .. plpos)
			else
				-- Countable nouns
				table.insert(data.categories, langname .. " countable " .. plpos)
			end
		end
	end

	if #plurals > 1 then
		table.insert(data.categories, langname .. " " .. plpos .. " with multiple plurals")
	end

	-- Gather masculines/feminines. For each one, generate the corresponding plural(s).
	local function handle_mf(mfs, gender, inflect, default_plurals)
		local retval = {}
		for _, mf in ipairs(mfs) do
			if mf == "+" then
				-- Generate default feminine.
				mf = inflect(lemma)
			else
				mf = replace_hash_with_lemma(mf, lemma)
			end
			local special = require(romut_module).get_special_indicator(mf)
			if special then
				mf = inflect(lemma, special)
			end
			table.insert(retval, mf)
			local mfpls = com.make_plural(mf, gender, special)
			if mfpls then
				for _, mfpl in ipairs(mfpls) do
					-- Add an accelerator for each masculine/feminine plural whose lemma
					-- is the corresponding singular, so that the accelerated entry
					-- that is generated has a definition that looks like
					-- # {{plural of|es|MFSING}}
					table.insert(default_plurals, {term = mfpl, accel = {form = "p", lemma = mf}})
				end
			end
		end
		return retval
	end

	local feminine_plurals = {}
	local feminines = handle_mf(args.f, "f", com.make_feminine, feminine_plurals)
	local masculine_plurals = {}
	local masculines = handle_mf(args.m, "m", com.make_masculine, masculine_plurals)

	local function handle_mf_plural(mfpl, gender, default_plurals, singulars)
		local new_mfpls = {}
		for i, mfpl in ipairs(mfpl) do
			local accel
			if #mfpl == #singulars then
				-- If same number of overriding masculine/feminine plurals as singulars,
				-- assume each plural goes with the corresponding singular
				-- and use each corresponding singular as the lemma in the accelerator.
				-- The generated entry will have # {{plural of|es|SINGULAR}} as the
				-- definition.
				accel = {form = "p", lemma = singulars[i]}
			else
				accel = nil
			end
			if mfpl == "+" then
				for _, defpl in ipairs(default_plurals) do
					-- defpl is already a table
					table.insert(new_mfpls, defpl)
				end
			elseif mfpl:find("^%+") then
				mfpl = require(romut_module).get_special_indicator(mfpl)
				for _, mf in ipairs(singulars) do
					local default_mfpls = com.make_plural(mf, gender, mfpl)
					for _, defp in ipairs(default_mfpls) do
						table.insert(new_mfpls, {term = defp, accel = accel})
					end
				end
			else
				table.insert(new_mfpls, {term = replace_hash_with_lemma(mfpl, lemma), accel = accel})
			end
		end
		return new_mfpls
	end

	if #args.fpl > 0 then
		-- Override any existing feminine plurals.
		feminine_plurals = handle_mf_plural(args.fpl, "f", feminine_plurals, feminines)
	end

	if #args.mpl > 0 then
		-- Override any existing masculine plurals.
		masculine_plurals = handle_mf_plural(args.mpl, "m", masculine_plurals, masculines)
	end

	check_all_missing(data, plurals, plpos)
	check_all_missing(data, feminines, plpos)
	check_all_missing(data, feminine_plurals, plpos)
	check_all_missing(data, masculines, plpos)
	check_all_missing(data, masculine_plurals, plpos)
	check_all_missing(data, args.dim, plpos)
	check_all_missing(data, args.aug, plpos)
	check_all_missing(data, args.pej, plpos)

	if #plurals > 0 then
		plurals.label = "plural"
		plurals.accel = {form = "p"}
		table.insert(data.inflections, plurals)
	end

	if #feminines > 0 then
		feminines.label = "feminine"
		feminines.accel = {form = "f"}
		table.insert(data.inflections, feminines)
	end

	if #feminine_plurals > 0 then
		feminine_plurals.label = "feminine plural"
		table.insert(data.inflections, feminine_plurals)
	end

	if #masculines > 0 then
		masculines.label = "masculine"
		table.insert(data.inflections, masculines)
	end

	if #masculine_plurals > 0 then
		masculine_plurals.label = "masculine plural"
		table.insert(data.inflections, masculine_plurals)
	end

	if #args.dim > 0 then
		args.dim.label = glossary_link("diminutive")
		table.insert(data.inflections, args.dim)
	end

	if #args.aug > 0 then
		args.aug.label = glossary_link("augmentative")
		table.insert(data.inflections, args.aug)
	end

	if #args.pej > 0 then
		args.pej.label = glossary_link("pejorative")
		table.insert(data.inflections, args.pej)
	end

	-- Maybe add category 'Spanish nouns with irregular gender' (or similar)
	local irreg_gender_lemma = rsub(lemma, " .*", "") -- only look at first word
	if (rfind(irreg_gender_lemma, "o$") and (gender_for_irreg_ending == "f" or gender_for_irreg_ending == "mf")) or
		(irreg_gender_lemma:find("a$") and (gender_for_irreg_ending == "m" or gender_for_irreg_ending == "mf")) then
		table.insert(data.categories, langname .. " nouns with irregular gender")
	end
end

local function get_noun_params(is_proper)
	return {
		[1] = {list = "g", required = not is_proper, default = "?"}, --gender
		["g_qual"] = {list = "g\1_qual", allow_holes = true},
		[2] = {list = "pl"}, --plural override(s)
		-- ["pl_qual"] = {list = "pl\1_qual", allow_holes = true},
		["f"] = {list = true}, --feminine form(s)
		-- ["f_qual"] = {list = "f\1_qual", allow_holes = true},
		["m"] = {list = true}, --masculine form(s)
		-- ["m_qual"] = {list = "m\1_qual", allow_holes = true},
		["fpl"] = {list = true}, --feminine plural override(s)
		-- ["fpl_qual"] = {list = "fpl\1_qual", allow_holes = true},
		["mpl"] = {list = true}, --masculine plural override(s)
		-- ["mpl_qual"] = {list = "mpl\1_qual", allow_holes = true},
		["dim"] = {list = true}, --diminutive(s)
		-- ["dim_qual"] = {list = "dim\1_qual", allow_holes = true},
		["aug"] = {list = true}, --diminutive(s)
		-- ["aug_qual"] = {list = "aug\1_qual", allow_holes = true},
		["pej"] = {list = true}, --pejorative(s)
		-- ["pej_qual"] = {list = "pej\1_qual", allow_holes = true},
	}
end

pos_functions["nouns"] = {
	params = get_noun_params(),
	func = function(args, data, frame, is_suffix)
		do_noun(args, data, "noun", is_suffix)
	end,
}

pos_functions["proper nouns"] = {
	params = get_noun_params("is proper"),
	func = function(args, data, frame, is_suffix)
		do_noun(args, data, "noun", is_suffix, "is proper")
	end,
}

-----------------------------------------------------------------------------------------
--                                          Verbs                                      --
-----------------------------------------------------------------------------------------

pos_functions["verbs"] = {
	params = {
		[1] = {},
		["pres"] = {list = true}, --present
		["pres_qual"] = {list = "pres\1_qual", allow_holes = true},
		["pret"] = {list = true}, --preterite
		["pret_qual"] = {list = "pret\1_qual", allow_holes = true},
		["part"] = {list = true}, --participle
		["part_qual"] = {list = "part\1_qual", allow_holes = true},
		["pagename"] = {}, -- for testing
		["noautolinktext"] = {type = "boolean"},
		["noautolinkverb"] = {type = "boolean"},
		["attn"] = {type = "boolean"},
	},
	func = function(args, data)
		local preses, prets, parts

		if args.attn then
			table.insert(data.categories, "Requests for attention concerning " .. langname)
			return
		end

		local es_verb = require(es_verb_module)
		local alternant_multiword_spec = es_verb.do_generate_forms(args, "es-verb", data.heads[1])

		local specforms = alternant_multiword_spec.forms
		local function slot_exists(slot)
			return specforms[slot] and #specforms[slot] > 0
		end

		local function do_finite(slot_tense, label_tense)
			-- Use pres_3s if it exists and pres_1s doesn't exist (e.g. impersonal verbs); similarly for pres_3p (only3p verbs);
			-- but fall back to pres_1s if neither pres_1s nor pres_3s nor pres_3p exist (e.g. [[empedernir]]).
			local has_1s = slot_exists(slot_tense .. "_1s")
			local has_3s = slot_exists(slot_tense .. "_3s")
			local has_3p = slot_exists(slot_tense .. "_3p")
			if has_1s or (not has_3s and not has_3p) then
				return {
					slot = slot_tense .. "_1s",
					label = ("first-person singular %s"):format(label_tense),
				}
			elseif has_3s then
				return {
					slot = slot_tense .. "_3s",
					label = ("third-person singular %s"):format(label_tense),
				}
			else
				return {
					slot = slot_tense .. "_3p",
					label = ("third-person plural %s"):format(label_tense),
				}
			end
		end

		preses = do_finite("pres", "present")
		prets = do_finite("pret", "preterite")
		parts = {
			slot = "pp_ms",
			label = "past participle",
		}

		if #args.pres > 0 or #args.pret > 0 or #args.part > 0 then
			track("verb-old-multiarg")
		end

		local function strip_brackets(qualifiers)
			if not qualifiers then
				return nil
			end
			local stripped_qualifiers = {}
			for _, qualifier in ipairs(qualifiers) do
				local stripped_qualifier = qualifier:match("^%[(.*)%]$")
				if not stripped_qualifier then
					error("Internal error: Qualifier should be surrounded by brackets at this stage: " .. qualifier)
				end
				table.insert(stripped_qualifiers, stripped_qualifier)
			end
			return stripped_qualifiers
		end

		local function do_verb_form(args, qualifiers, slot_desc, skip_if_empty)
			local forms
			local to_insert

			if #args == 0 then
				forms = specforms[slot_desc.slot]
				if not forms or #forms == 0 then
					if skip_if_empty then
						return
					end
					forms = {{form = "-"}}
				end
			elseif #args == 1 and args[1] == "-" then
				forms = {{form = "-"}}
			else
				forms = {}
				for i, arg in ipairs(args) do
					local qual = qualifiers[i]
					if qual then
						-- FIXME: It's annoying we have to add brackets and strip them out later. The inflection
						-- code adds all footnotes with brackets around them; we should change this.
						qual = {"[" .. qual .. "]"}
					end
					local form = arg
					if not args.noautolinkverb then
						-- [[Module:inflection utilities]] already loaded by [[Module:es-verb]]
						form = require(inflection_utilities_module).add_links(form)
					end
					table.insert(forms, {form = form, footnotes = qual})
				end
			end

			if forms[1].form == "-" then
				to_insert = {label = "no " .. slot_desc.label}
			else
				local into_table = {label = slot_desc.label}
				for _, form in ipairs(forms) do
					local qualifiers = strip_brackets(form.footnotes)
					-- Strip redundant brackets surrounding entire form. These may get generated e.g.
					-- if we use the angle bracket notation with a single word.
					local stripped_form = rmatch(form.form, "^%[%[([^%[%]]*)%]%]$") or form.form
					-- Don't include accelerators if brackets remain in form, as the result will be wrong.
					-- FIXME: For now, don't include accelerators. We should use {{es-verb form of}} instead.
					-- local this_accel = not stripped_form:find("%[%[") and accel or nil
					local this_accel = nil
					table.insert(into_table, {term = stripped_form, q = qualifiers, accel = this_accel})
				end
				to_insert = into_table
			end

			table.insert(data.inflections, to_insert)
		end

		local skip_pres_if_empty
		if alternant_multiword_spec.no_pres1_and_sub then
			table.insert(data.inflections, {label = "no first-person singular present"})
			table.insert(data.inflections, {label = "no present subjunctive"})
		end
		if alternant_multiword_spec.no_pres_stressed then
			table.insert(data.inflections, {label = "no stressed present indicative or subjunctive"})
			skip_pres_if_empty = true
		end
		if alternant_multiword_spec.only3s then
			table.insert(data.inflections, {label = glossary_link("impersonal")})
		elseif alternant_multiword_spec.only3sp then
			table.insert(data.inflections, {label = "third-person only"})
		elseif alternant_multiword_spec.only3p then
			table.insert(data.inflections, {label = "third-person plural only"})
		end

		local function expand_footnotes_and_references(footnotes)
			if not footnotes then
				return nil
			end
			return require("Module:inflection utilities").fetch_headword_qualifiers_and_references(footnotes)
		end

		do_verb_form(args.pres, args.pres_qual, preses, skip_pres_if_empty)
		do_verb_form(args.pret, args.pret_qual, prets)
		do_verb_form(args.part, args.part_qual, parts)

		-- Add categories.
		for _, cat in ipairs(alternant_multiword_spec.categories) do
			table.insert(data.categories, cat)
		end

		-- If the user didn't explicitly specify head=, or specified exactly one head (not 2+) and we were able to
		-- incorporate any links in that head into the 1= specification, use the infinitive generated by
		-- [[Module:es-verb]] in place of the user-specified or auto-generated head. This was copied from
		-- [[Module:it-headword]], where doing this gets accents marked on the verb(s). We don't have accents marked on
		-- the verb but by doing this we do get any footnotes on the infinitive propagated here. Don't do this if the
		-- user gave multiple heads or gave a head with a multiword-linked verbal expression such as Italian
		-- '[[dare esca]] [[al]] [[fuoco]]' (FIXME: give Spanish equivalent).
		if #data.user_specified_heads == 0 or (
			#data.user_specified_heads == 1 and alternant_multiword_spec.incorporated_headword_head_into_lemma
		) then
			data.heads = {}
			for _, lemma_obj in ipairs(alternant_multiword_spec.forms.infinitive_linked) do
				local quals, refs = expand_footnotes_and_references(lemma_obj.footnotes)
				table.insert(data.heads, {term = lemma_obj.form, q = quals, refs = refs})
			end
		end
	end
}

-----------------------------------------------------------------------------------------
--                                      Phrases                                        --
-----------------------------------------------------------------------------------------

pos_functions["phrases"] = {
	params = {
		["g"] = {list = true},
		["g_qual"] = {list = "g\1_qual", allow_holes = true},
		["m"] = {list = true},
		["m_qual"] = {list = "m\1_qual", allow_holes = true},
		["f"] = {list = true},
		["f_qual"] = {list = "f\1_qual", allow_holes = true},
	},
	func = function(args, data)
		data.genders = {}
		process_genders(data, args.g, args.g_qual)
		insert_ancillary_inflection(data, args.m, args.m_qual, "masculine", "phrases")
		insert_ancillary_inflection(data, args.f, args.f_qual, "feminine", "phrases")
	end,
}

-----------------------------------------------------------------------------------------
--                                    Suffix forms                                     --
-----------------------------------------------------------------------------------------

pos_functions["suffix forms"] = {
	params = {
		[1] = {required = true, list = true},
		["g"] = {list = true},
		["g_qual"] = {list = "g\1_qual", allow_holes = true},
	},
	func = function(args, data)
		data.genders = {}
		process_genders(data, args.g, args.g_qual)
		local suffix_type = {}
		for _, typ in ipairs(args[1]) do
			table.insert(suffix_type, typ .. "-forming suffix")
		end
		table.insert(data.inflections, {label = "non-lemma form of " .. require("Module:table").serialCommaJoin(suffix_type, {conj = "or"})})
	end,
}

return export
