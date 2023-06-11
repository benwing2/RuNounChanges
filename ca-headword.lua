local export = {}
local pos_functions = {}

local force_cat = false -- for testing; if true, categories appear in non-mainspace pages

local m_com = require("Module:ca-common")
local m_table = require("Module:table")
local romut_module = "Module:romance utilities"

local lang = require("Module:languages").getByCode("ca")
local langname = lang:getCanonicalName()

local rfind = mw.ustring.find
local rmatch = mw.ustring.match
local rsubn = mw.ustring.gsub
local usub = mw.ustring.sub

local unaccented_vowel = "aeiou"
local accented_vowel = "àèéíòóú"
local vowel = unaccented_vowel .. accented_vowel

local V = "[" .. vowel .. "]"
local UV = "[" .. unaccented_vowel .. "]"
local AV = "[" .. accented_vowel .. "]"
local C = "[^" .. vowel .. "]"

-- Used when forming the feminine of adjectives in -i. Those with the stressed vowel 'e' or 'o' always seem to have è, ò.
local accent_vowel = {
	["a"] = "à",
	["e"] = "è",
	["i"] = "í",
	["o"] = "ò",
	["u"] = "ù",
}

local prepositions = {
	-- a + optional article (including salat)
	"al?s? ",
	-- de + optional article (including salat)
	"del?s? ",
	"d'",
	-- ca + optional article (including salat and [[en]])
	"can? ",
	"cal?s? ",
	-- per + optional article
	"per ",
	"pels? ",
	-- others
	"en ",
	"amb ",
	"cap ",
	"com ",
	"entre ",
	"sense ",
	"sobre ",
}

-- version of rsubn() that discards all but the first return value
local function rsub(term, foo, bar)
	local retval = rsubn(term, foo, bar)
	return retval
end

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

local function track(page)
	require("Module:debug/track")("ca-headword/" .. page)
	return true
end

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
--                                  Inflection functions                               --
-----------------------------------------------------------------------------------------

-- Given a term `term`, if the term is multiword (either through spaces or hyphens), handle inflection of the term by
-- calling handle_multiword() in [[Module:romance utilities]]. `special` indicates which parts of the multiword term to
-- inflect, and `inflect` is a function of one argument to inflect the individual parts of the term. As an optimization,
-- if the term is not multiword and `special` is not given, do nothing.
local function call_handle_multiword(term, special, inflect, allow_multiple)
	if not special and not term:find("[ %-]") then
		return nil
	end
	local retval = require(romut_module).handle_multiword(term, special, inflect, prepositions)
	if retval and #retval > 0 then
		if allow_multiple then
			return retval
		end
		if #retval ~= 1 then
			error("Internal error: Should have only one return value from inflection function: " .. table.concat(retval, ","))
		end
		return retval[1]
	end
	return nil
end

local function make_feminine(base, special)
	local retval = call_handle_multiword(base, special, make_feminine)
	if retval then
		return retval
	end

	-- special cases
	-- -able, -ible, -uble
	if base:find("ble$") or
		-- stressed -al/-ar in a multisyllabic word (not [[gal]], [[anòmal]], or [[car]], [[clar]], [[rar]], [[var]],
		-- [[isòbar]], [[èuscar]], [[búlgar]], [[tàrtar]]/[[tàtar]], [[càtar]], [[àvar]])
		(rfind(base, V .. "[^ ]*a[lr]$") and not rfind(base, AV .. "[^ ]*a[lr]$")) or
		-- -ant in a multisyllabic word (not [[mant]], [[tant]], also [[quant]] but that needs manual handling)
		-- -ent in a multisyllabic word (not [[lent]]; some other words in -lent have feminine in -a but not all)
		rfind(base, V .. "[^ ]*[ae]nt$") or
		-- Words in -aç, -iç, -oç (not [[descalç]], [[dolç]], [[agredolç]]; [[balbuç]] has -a and needs manual handling)
		rfind(base, V .. "ç$") or
		-- Words in -il including when non-stressed ([[hàbil]], [[dèbil]], [[mòbil]], [[fàcil]], [[símil]], [[tàmil]],
		-- etc.); but not words in -òfil, -èfil, etc.
		base:find("[^f]il$") then
		return base
	end

	-- final vowel -> -a
	if base:find("a$") then return base end
	if base:find("o$") then return (base:gsub("o$", "a")) end	
	if base:find("e$") then return m_com.front_to_back(base:gsub("e$", "")) .. "a" end
	
	-- -u -> -va
	if base:find(UV .. "u$") then return (base:gsub("u$", "v") .. "a") end
	
	-- accented vowel -> -na
	if rfind(base, AV .. "$") then return m_com.remove_accents(base) .. "na" end
	
	-- accented vowel + -s -> -sa
	if rfind(base, AV .. "s$") then return m_com.remove_accents(base) .. "a" end
	
	-- vowel + consonant(s) + i -> accent the first vowel, add -a
	local prev, first_vowel, cons = rmatch(base, "^(.*)([aeo])i(" .. C .. "+)i$")
	if first_vowel then
		-- At least [[malaisi]]
		return prev .. accent_vowel[first_vowel] .. "i" .. cons .. "ia"
	end
	local prev, first_vowel, cons = rmatch(base, "^(.*)(" .. UV .. ")(" .. C .. "+)i$")
	if first_vowel then
		return prev .. accent_vowel[first_vowel] .. cons .. "ia"
	end

	-- multisyllabic -at/-it/-ut (also -ït/-üt) with stress on the final vowel -> -ada/-ida/-uda
	local mod_base = rsub(base, "([gq])u(" .. UV .. ")", "%1w%2") -- hack so we don't treat the u in qu/gu as a vowel
	if (rfind(mod_base, V .. "[^ ]*[aiu]t$") and not rfind(mod_base, AV .. "[^ ]*[aiu]t$") and
		not rfind(mod_base, "[aeo][iu]t$")) or rfind(mod_base, "[ïü]t$") then
		return rsub(base, "t$", "da")
	end

	return base .. "a"
end

local function make_plural(base, gender, special)
	local retval = call_handle_multiword(base, special, function(term) return make_plural(term, gender) end, "allow multiple")
	if retval then
		return retval
	end

	-- a -> es
	if base:find("a$") then return {m_com.back_to_front(base:gsub("a$", "")) .. "es"} end
	
	-- accented vowel -> -ns
	if rfind(base, AV .. "$") then
		return {m_com.remove_accents(base) .. "ns"}
	end
	
	if gender == "m" then
		if rfind(base, AV .. "s$") then
			return {m_com.remove_accents(base) .. "os"}
		end

		if rfind(base, "[sçxz]$") then
			return {base .. "os"}
		end

		if base:find("sc$") or base:find("[sx]t$") then
			return {base .. "s", base .. "os"}
		end
	end
	
	if gender == "f" then
		if base:find("s$") then return {base} end

		if base:find("sc$") or base:find("[sx]t$") then
			return {base .. "s", base .. "es"}
		end
	end

	if base:find("eig$") then
		return {base .. "s", rsub(base, "ig$", "jos")}
	end

	return {base .. "s"}
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
				local defpls = make_plural(lemma, "f", args.sp)
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
				f = make_feminine(lemma, args.sp)
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

				defpls = defpls or make_plural(lemma, "m", args.sp)
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
					local defpls = make_plural(lemma .. "a", "f")
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
						local defpls = make_plural(f.term, "f", args.sp)
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
				local pls = make_plural(lemma, gender_for_default_plural, special)
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

	local feminines = handle_mf(args.f, args.f_qual, make_feminine)
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
--                                          Verbs                                      --
-----------------------------------------------------------------------------------------

-- Display additional inflection information for a verb
pos_functions["verbs"] = {
	params = {
		["pres_1_sg"] = {},
		["past_part"] = {},
		},
	func = function(args, data, is_suffix)
		-- Does this verb end in a recognised verb ending (possibly reflexive)?
		if not data.pagename:find(" ") and (data.pagename:find("re?$") or data.pagename:find("r%-se$") or data.pagename:find("re's$")) then
			local base = data.pagename:gsub("r%-se$", "r"):gsub("re's$", "re")
			local pres_1_sg
			local past_part
			
			-- Generate inflected forms.
			-- The 2nd conjugation is generally irregular
			-- so generate nothing for that, explicit parameters are required.
			
			-- 1st conjugation
			if base:find("ar$") then
				local stem = base:gsub("ar$", "")
				pres_1_sg = stem .. "o"
				past_part = stem .. "at"
			-- 3rd conjugation (except -tenir/-venir)
			elseif base:find("ir$") and not base:find("[tv]enir$") then
				local stem = base:gsub("ir$", "")
				pres_1_sg = stem .. "eixo"
				
				if stem:find("[aeiou]$") and not stem:find("[gq]u$") then
					past_part = stem .. "ït"
				else
					past_part = stem .. "it"
				end
			end
			
			-- Overridden forms
			pres_1_sg = {label = "first-person singular present", request = true, args["pres_1_sg"] or pres_1_sg}
			past_part = {label = "past participle", request = true, args["past_part"] or past_part}
			
			table.insert(data.inflections, pres_1_sg)
			table.insert(data.inflections, past_part)
		end
	end
}

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
--                                      Phrases                                        --
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
