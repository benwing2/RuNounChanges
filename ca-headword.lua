local export = {}
local pos_functions = {}

local force_cat = false -- for testing; if true, categories appear in non-mainspace pages

local com = require("Module:ca-common")
local m_table = require("Module:table")
local romut_module = "Module:romance utilities"
local ca_verb_module = "Module:ca-verb"

local lang = require("Module:languages").getByCode("ca")
local langname = lang:getCanonicalName()

local rmatch = mw.ustring.match
local usub = mw.ustring.sub
local rsub = com.rsub

local function track(page)
	require("Module:debug/track")("ca-headword/" .. page)
	return true
end

-----------------------------------------------------------------------------------------
--                                    Main entry point                                 --
-----------------------------------------------------------------------------------------

-- The main entry point.
-- This is the only function that can be invoked from a template.
function export.show(frame)
	local poscat = frame.args[1] or error("Part of speech has not been specified. Please pass parameter 1 to the module invocation.")
	
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
	
	local args = require("Module:parameters").process(frame:getParent().args, params)
	local pagename = args.pagename or mw.title.getCurrentTitle().subpageText

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
		pos_functions[poscat].func(args, data, is_suffix)
	end

	if args.json then
		return require("Module:JSON").toJSON(data)
	end

	return require("Module:headword").full_headword(data)
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

	if args.f[1] == "ind" or args.f[1] == "inv" then
		-- invariable adjective
		table.insert(data.inflections, {label = glossary_link("invariable")})
		table.insert(data.categories, langname .. " indeclinable " .. plpos)
		if args.sp or #args.f > 1 or #args.pl > 0 or #args.mpl > 0 or #args.fpl > 0 then
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
				table.insert(feminine_plural, {term = replace_hash_with_lemma(fpl, lemma), q = quals})
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
			if f == "mf" then
				f = lemma
			elseif f == "+" then
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
				local defpls

				-- First, some special hacks based on the feminine singular.
				if not fem_like_lemma and not args.sp and not lemma:find(" ") then
					for _, f in ipairs(feminines) do
						if f.term:find("ssa$") then
							-- If the feminine ends in -ssa, assume that the -ss- is also in the
							-- masculine plural form
							defpls = {rsub(f.term, "a$", "os")}
							break
						elseif f.term == lemma .. "na" then
							defpls = {lemma .. "ns"}
							break
						elseif lemma:find("ig$") and f.term:find("ja$") then
							-- Adjectives in -ig have two masculine plural forms, one derived from
							-- the m.sg. and the other derived from the f.sg.
							defpls = {lemma .. "s", rsub(f.term, "ja$", "jos")}
							break
						end
					end
				end

				defpls = defpls or com.make_plural(lemma, "m", args.sp)
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
				-- First, some special hacks based on the feminine singular.
				if fem_like_lemma and not args.sp and not lemma:find(" ") and lemma:find("[çx]$") then
					-- Adjectives ending in -ç or -x behave as mf-type in the singular, but
					-- regular type in the plural.
					local defpls = com.make_plural(lemma .. "a", "f")
					if not defpls then
						error("Unable to generate default plural of '" .. lemma .. "a'")
					end
					local fquals = fetch_qualifiers(args.fpl_qual[i])
					for _, defpl in ipairs(defpls) do
						table.insert(feminine_plurals, {term = defpl, q = fquals})
					end
				else
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
				end
			else
				fpl = replace_hash_with_lemma(fpl, lemma)
				table.insert(feminine_plurals, {term = fpl, q = fetch_qualifiers(args.fpl_qual[i])})
			end
		end

		check_all_missing(data, feminines, plpos)
		check_all_missing(data, masculine_plurals, plpos)
		check_all_missing(data, feminine_plurals, plpos)

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
			else
				data.genders = {"mf"}
			end

			if fem_pl_like_masc_pl then
				insert_inflection(masculine_plurals, "masculine and feminine plural", "p")
			else
				insert_inflection(masculine_plurals, "masculine plural", "m|p")
				insert_inflection(feminine_plurals, "feminine plural", "f|p")
			end
		end
	end

	if args.irreg and is_superlative then
		table.insert(data.categories, langname .. " irregular superlative " .. plpos)
	end
end

local function get_adjective_params(adjtype)
	local params = {
		["sp"] = {}, -- special indicator: "first", "first-last", etc.
		["f"] = {list = true}, --feminine form(s)
		[1] = {alias_of = "f"},
		["f_qual"] = {list = "f=_qual", allow_holes = true},
		["pl"] = {list = true}, --plural override(s)
		["pl_qual"] = {list = "pl=_qual", allow_holes = true},
		["mpl"] = {list = true}, --masculine plural override(s)
		["mpl_qual"] = {list = "mpl=_qual", allow_holes = true},
		["fpl"] = {list = true}, --feminine plural override(s)
		["fpl_qual"] = {list = "fpl=_qual", allow_holes = true},
	}
	if adjtype == "base" then
		params["comp"] = {list = true} --comparative(s)
		params["comp_qual"] = {list = "comp=_qual", allow_holes = true}
		params["sup"] = {list = true} --superlative(s)
		params["sup_qual"] = {list = "sup=_qual", allow_holes = true}
		params["dim"] = {list = true} --diminutive(s)
		params["dim_qual"] = {list = "dim=_qual", allow_holes = true}
		params["aug"] = {list = true} --augmentative(s)
		params["aug_qual"] = {list = "aug=_qual", allow_holes = true}
		params["fonly"] = {type = "boolean"} -- feminine only
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
	func = function(args, data, is_suffix)
		do_adjective(args, data, "adjective", is_suffix)
	end,
}

pos_functions["past participles"] = {
	params = get_adjective_params("part"),
	func = function(args, data, is_suffix)
		do_adjective(args, data, "participle", is_suffix)
		data.pos_category = "past participles"
	end,
}

pos_functions["determiners"] = {
	params = get_adjective_params("det"),
	func = function(args, data, is_suffix)
		do_adjective(args, data, "determiner", is_suffix)
	end,
}

pos_functions["pronouns"] = {
	params = get_adjective_params("pron"),
	func = function(args, data, is_suffix)
		do_adjective(args, data, "pronoun", is_suffix)
	end,
}

-----------------------------------------------------------------------------------------
--                                          Nouns                                      --
-----------------------------------------------------------------------------------------

local allowed_genders = m_table.listToSet(
	{"m", "f", "mf", "mfbysense", "n", "m-p", "f-p", "mf-p", "mfbysense-p", "n-p", "?", "?-p"}
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

local function do_noun(args, data, pos, is_suffix, is_proper)
	local is_plurale_tantum = false
	local has_singular = false
	if is_suffix then
		pos = "suffix"
	end
	local plpos = require("Module:string utilities").pluralize(pos)

	data.genders = {}
	local saw_m = false
	local saw_f = false
	local gender_for_default_plural, gender_for_irreg_ending
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
		end
	end
	if saw_m and saw_f then
		gender_for_default_plural = "m"
		gender_for_irreg_ending = "mf"
	elseif saw_f then
		gender_for_default_plural = "f"
		gender_for_irreg_ending = "f"
	else
		gender_for_default_plural = "m"
		gender_for_irreg_ending = "m"
	end

	local lemma = data.pagename

	local function insert_inflection(list, term, accel, qualifiers, no_inv)
		local infl = {q = qualifiers, accel = accel}
		--if term == lemma and not no_inv then
		--	infl.label = glossary_link("invariable")
		--else
			infl.term = term
		--end
		infl.term_for_further_inflection = term
		table.insert(list, infl)
	end

	-- Plural
	local plurals = {}
	local args_mpl = args.mpl
	local args_fpl = args.fpl
	local args_pl = args[2]

	if is_plurale_tantum and not has_singular then
		if #args_pl > 0 then
			error("Can't specify plurals of plurale tantum " .. pos)
		end
		table.insert(data.inflections, {label = glossary_link("plural only")})
	else
		if is_plurale_tantum then
			-- both singular and plural
			table.insert(data.inflections, {label = "sometimes " .. glossary_link("plural only") .. ", in variation"})
		end
		-- If no plurals, use the default plural if not a proper noun.
		if #args_pl == 0 and not is_proper then
			args_pl = {"+"}
		end
		-- If only ~ given (countable and uncountable), add the default plural after it.
		if #args_pl == 1 and args_pl[1] == "~" then
			args_pl = {"~", "+"}
		end
		-- Gather plurals, handling requests for default plurals
		for i, pl in ipairs(args_pl) do
			local function insert_pl(term)
				local quals = fetch_qualifiers(args.pl_qual[i])
				if term == lemma and i == 1 and #args_pl == 1 then
					table.insert(data.inflections, {label = glossary_link("invariable"), q = quals})
					table.insert(data.categories, langname .. " indeclinable " .. plpos)
				else
					insert_inflection(plurals, term, nil, quals)
				end
				table.insert(data.categories, langname .. " countable " .. plpos)
			end
			local function make_plural_and_insert(form, special)
				local pls = com.make_plural(lemma, gender_for_default_plural, special)
				if pls then
					for _, pl in ipairs(pls) do
						insert_pl(pl)
					end
				end
			end

			if pl == "+" then
				make_plural_and_insert(lemma)
			elseif pl:find("^%+") then
				pl = require(romut_module).get_special_indicator(pl)
				make_plural_and_insert(lemma, pl)
			elseif pl == "?" or pl == "!" then
				if i > 1 or #args_pl > 1 then
					error("Can't specify ? or ! with other plurals")
				end
				if pl == "?" then
					-- Plural is unknown
					-- Better not to display anything
					-- table.insert(data.inflections, {label = "plural unknown or uncertain"})
					table.insert(data.categories, langname .. " " .. plpos .. " with unknown or uncertain plurals")
				else
					-- Plural is not attested
					table.insert(data.inflections, {label = "plural not attested"})
					table.insert(data.categories, langname .. " " .. plpos .. " with unattested plurals")
				end
			elseif pl == "-" then
				if i > 1 then
					error("Plural specifier - must be first")
				end
				-- Uncountable noun; may occasionally have a plural
				table.insert(data.categories, langname .. " uncountable " .. plpos)

				-- If plural forms were given explicitly, then show "usually"
				if #args_pl > 1 then
					table.insert(data.inflections, {label = "usually " .. glossary_link("uncountable")})
					table.insert(data.categories, langname .. " countable " .. plpos)
				else
					table.insert(data.inflections, {label = glossary_link("uncountable")})
				end
			elseif pl == "~" then
				if i > 1 then
					error("Plural specifier ~ must be first")
				end
				-- Countable and uncountable noun; will have a plural
				table.insert(data.categories, langname .. " countable " .. plpos)
				table.insert(data.categories, langname .. " uncountable " .. plpos)
				table.insert(data.inflections, {label = glossary_link("countable") .. " and " .. glossary_link("uncountable")})
			else
				insert_pl(replace_hash_with_lemma(pl, lemma))
			end
		end
	end

	if #plurals > 1 then
		table.insert(data.categories, langname .. " " .. plpos .. " with multiple plurals")
	end

	-- Gather masculines/feminines.
	local function handle_mf(mfs, qualifiers, inflect)
		local retval = {}
		for i, mf in ipairs(mfs) do
			local function insert_infl(list, term, accel, existing_qualifiers)
				insert_inflection(list, term, accel, fetch_qualifiers(qualifiers[i], existing_qualifiers), "no inv")
			end
			local function call_inflect(special)
				if inflect then
					-- Generate default feminine.
					return inflect(lemma, special)
				else
					-- FIXME
					error("Can't generate default masculine currently")
				end
			end

			if mf == "+" then
				mf = call_inflect()
			else
				mf = replace_hash_with_lemma(mf, lemma)
			end
			local special = require(romut_module).get_special_indicator(mf)
			if special then
				mf = call_inflect(special)
			end
			insert_infl(retval, mf)
		end
		return retval
	end

	local feminines = handle_mf(args.f, args.f_qual, com.make_feminine)
	-- FIXME, write make_masculine()
	local masculines = handle_mf(args.m, args.m_qual)

	check_all_missing(data, plurals, plpos)
	check_all_missing(data, feminines, plpos)

	if #plurals > 0 then
		plurals.label = "plural"
		plurals.accel = {form = "p"}
		table.insert(data.inflections, plurals)
	end

	if #masculines > 0 then
		masculines.label = "masculine"
		table.insert(data.inflections, masculines)
	end

	if #feminines > 0 then
		feminines.label = "feminine"
		feminines.accel = {form = "f"}
		table.insert(data.inflections, feminines)
	end

	-- Is this a noun with an unexpected ending (for its gender)?
	-- Only check if the term is one word (there are no spaces in the term).
	local irreg_gender_lemma = rsub(lemma, " .*", "") -- only look at first word
	if (gender_for_irreg_ending == "m" or gender_for_irreg_ending == "mf") and irreg_gender_lemma:find("a$") then
		table.insert(data.categories, langname .. " masculine " .. plpos .. " ending in -a")
	elseif (gender_for_irreg_ending == "f" or gender_for_irreg_ending == "mf") and not (
		irreg_gender_lemma:find("a$") or irreg_gender_lemma:find("ió$") or irreg_gender_lemma:find("tat$") or
		irreg_gender_lemma:find("tud$") or irreg_gender_lemma:find("[dt]riu$")) then
		table.insert(data.categories, langname .. " feminine " .. plpos .. " with no feminine ending")
	end
end

local function get_noun_params()
	return {
		[1] = {list = "g", required = true, default = "?"},
		[2] = {list = "pl"},
		["g_qual"] = {list = "g=_qual", allow_holes = true},
		["pl_qual"] = {list = "pl=_qual", allow_holes = true},
		["m"] = {list = true},
		["m_qual"] = {list = "m=_qual", allow_holes = true},
		["f"] = {list = true},
		["f_qual"] = {list = "f=_qual", allow_holes = true},
		["mpl"] = {list = true},
		["mpl_qual"] = {list = "mpl=_qual", allow_holes = true},
		["fpl"] = {list = true},
		["fpl_qual"] = {list = "fpl=_qual", allow_holes = true},
	}
end

pos_functions["nouns"] = {
	params = get_noun_params(),
	func = function(args, data, is_suffix)
		do_noun(args, data, "noun", is_suffix)
	end,
}

pos_functions["proper nouns"] = {
	params = get_noun_params(),
	func = function(args, data, is_suffix)
		do_noun(args, data, "noun", is_suffix, "is proper")
	end,
}

-----------------------------------------------------------------------------------------
--                                         Verbs                                       --
-----------------------------------------------------------------------------------------

pos_functions["verbs"] = {
	params = {
		[1] = {},
		["pres"] = {list = true}, --present
		["pres_qual"] = {list = "pres=_qual", allow_holes = true},
		["pres3s"] = {list = true}, --third-singular present
		["pres3s_qual"] = {list = "pres3s=_qual", allow_holes = true},
		["pret"] = {list = true}, --preterite
		["pret_qual"] = {list = "pret=_qual", allow_holes = true},
		["part"] = {list = true}, --participle
		["part_qual"] = {list = "part=_qual", allow_holes = true},
		["short_part"] = {list = true}, --short participle
		["short_part_qual"] = {list = "short_part=_qual", allow_holes = true},
		["noautolinktext"] = {type = "boolean"},
		["noautolinkverb"] = {type = "boolean"},
		["attn"] = {type = "boolean"},
		["pres_1_sg"] = {}, -- accept any ignore old-style param
		["past_part"] = {}, -- accept any ignore old-style param
		["root"] = {}, -- FIXME: Implement root-stressed vowel quality
	},
	func = function(args, data, tracking_categories, frame)
		local preses, preses_3s, prets, parts, short_parts

		if args.attn then
			table.insert(tracking_categories, "Requests for attention concerning " .. langname)
			return
		end

		local ca_verb = require(ca_verb_module)
		local alternant_multiword_spec = ca_verb.do_generate_forms(args, "ca-verb", data.heads[1])

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
				}, true
			elseif has_3s then
				return {
					slot = slot_tense .. "_3s",
					label = ("third-person singular %s"):format(label_tense),
				}, false
			else
				return {
					slot = slot_tense .. "_3p",
					label = ("third-person plural %s"):format(label_tense),
				}, false
			end
		end

		local did_pres_1s
		preses, did_pres_1s = do_finite("pres", "present")
		preses_3s = {
			slot = "pres_3s",
			label = "third-person singular present",
		}
		prets = do_finite("pret", "preterite")
		parts = {
			slot = "pp_ms",
			label = "past participle",
		}
		short_parts = {
			slot = "short_pp_ms",
			label = "short past participle",
		}

		if #args.pres > 0 or #args.pres3s > 0 or #args.pret > 0 or #args.part > 0 or #args.short_part > 0 then
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
						form = com.add_links(form)
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
					-- FIXME: For now, don't include accelerators. We should use the new {{ca-verb form of}}.
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
		local has_vowel_alt
		if alternant_multiword_spec.vowel_alt then
			for _, vowel_alt in ipairs(alternant_multiword_spec.vowel_alt) do
				if vowel_alt ~= "+" and vowel_alt ~= "í" and vowel_alt ~= "ú" then
					has_vowel_alt = true
					break
				end
			end
		end

		local function expand_footnotes_and_references(footnotes)
			if not footnotes then
				return nil
			end
			return require("Module:inflection utilities").fetch_headword_qualifiers_and_references(footnotes)
		end

		do_verb_form(args.pres, args.pres_qual, preses, skip_pres_if_empty)
		-- We want to include both the pres_1s and pres_3s if there is a vowel alternation in the present singular. But we
		-- don't want to redundantly include the pres_3s if we already included it.
		if did_pres_1s and has_vowel_alt then
			do_verb_form(args.pres3s, args.pres3s_qual, preses_3s, skip_pres_if_empty)
		end
		do_verb_form(args.pret, args.pret_qual, prets)
		do_verb_form(args.part, args.part_qual, parts)
		do_verb_form(args.short_part, args.short_part_qual, short_parts, "skip if empty")

		-- Add categories.
		for _, cat in ipairs(alternant_multiword_spec.categories) do
			table.insert(data.categories, cat)
		end

		-- If the user didn't explicitly specify head=, or specified exactly one head (not 2+) and we were able to
		-- incorporate any links in that head into the 1= specification, use the infinitive generated by
		-- [[Module:ca-verb]] in place of the user-specified or auto-generated head. This was copied from
		-- [[Module:it-headword]], where doing this gets accents marked on the verb(s). We don't have accents marked on
		-- the verb but by doing this we do get any footnotes on the infinitive propagated here. Don't do this if the
		-- user gave multiple heads or gave a head with a multiword-linked verbal expression such as Italian
		-- '[[dare esca]] [[al]] [[fuoco]]' (FIXME: give Catalan equivalent).
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
--                                        Numerals                                     --
-----------------------------------------------------------------------------------------

-- Display additional inflection information for a numeral
pos_functions["numerals"] = {
	params = {
		[1] = {},
		[2] = {},
		},
	func = function(args, data, is_suffix)
		local feminine = args[1]
		local noun_form = args[2]
		
		if feminine then
			table.insert(data.genders, "m")
			table.insert(data.inflections, {label = "feminine", feminine})
			
			if noun_form then
				table.insert(data.inflections, {label = "noun form", noun_form})
			end
		else
			table.insert(data.genders, "m")
			table.insert(data.genders, "f")
		end
	end
}

-----------------------------------------------------------------------------------------
--                                       Phrases                                       --
-----------------------------------------------------------------------------------------

pos_functions["phrases"] = {
	params = {
		["g"] = {list = true},
		["g_qual"] = {list = "g=_qual", allow_holes = true},
		["m"] = {list = true},
		["m_qual"] = {list = "m=_qual", allow_holes = true},
		["f"] = {list = true},
		["f_qual"] = {list = "f=_qual", allow_holes = true},
	},
	func = function(args, data, is_suffix)
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
		["g_qual"] = {list = "g=_qual", allow_holes = true},
	},
	func = function(args, data, is_suffix)
		data.genders = {}
		process_genders(data, args.g, args.g_qual)
		local suffix_type = {}
		for _, typ in ipairs(args[1]) do
			table.insert(suffix_type, typ .. "-forming suffix")
		end
		table.insert(data.inflections, {label = "non-lemma form of " .. m_table.serialCommaJoin(suffix_type, {conj = "or"})})
	end,
}

return export
