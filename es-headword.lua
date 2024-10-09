local export = {}
local pos_functions = {}

local force_cat = false -- for testing; if true, categories appear in non-mainspace pages

local rfind = mw.ustring.find
local rmatch = mw.ustring.match
local require_when_needed = require("Module:utilities/require when needed")

local m_table = require("Module:table")
local com = require("Module:es-common")
local inflection_utilities_module = "Module:inflection utilities"
local headword_module = "Module:headword"
local m_headword_utilities = require_when_needed("Module:headword utilities")
local glossary_link = require_when_needed("Module:headword utilities", "glossary_link")
local m_string_utilities = require_when_needed("Module:string utilities")
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

local list_param = {list = true, disallow_holes = true}
local boolean_param = {type = "boolean"}

-- The main entry point.
-- This is the only function that can be invoked from a template.
function export.show(frame)
	local poscat = frame.args[1]
		or error("Part of speech has not been specified. Please pass parameter 1 to the module invocation.")

	local parargs = frame:getParent().args

	local params = {
		["head"] = list_param,
		["id"] = {},
		["splithyph"] = boolean_param,
		["nolinkhead"] = boolean_param,
		["json"] = boolean_param,
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
		local singular_poscat = m_string_utilities.singularize(poscat)
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

local function replace_hash_with_lemma(term, lemma)
	-- If there is a % sign in the lemma, we have to replace it with %% so it doesn't get interpreted as a capture
	-- replace expression.
	lemma = m_string_utilities.replacement_escape(lemma)
	return (term:gsub("#", lemma)) -- discard second retval
end


local function check_all_missing(data, forms, plpos)
	for _, form in ipairs(forms) do
		if type(form) == "table" then
			form = form.term
		end
		if form then
			local title = mw.title.new(form)
			if title and not title:getContent() then
				table.insert(data.categories, langname .. " " .. plpos .. " with red links in their headword lines")
			end
		end
	end
end


-- Insert an "ancillary" inflection (one that doesn't require additional processing) into `data.inflections`.
-- The raw arguments come from `args[field]`, which is parsed for inline modifiers. If there is a corresponding
-- qualifier field `FIELD_qual`, qualifiers may additionally come from there. `label` is the label that the inflections
-- are given, which is linked to the glossary unless preceded by * (which is removed). `plpos` is the plural part of
-- speech, used in [[Category:LANGNAME PLPOS with red links in their headword lines]].
local function insert_ancillary_inflection(data, args, field, label, plpos)
	local forms = args[field]
	local quals = args[field .. "_qual"]
	if forms and forms[1] then
		local terms = m_headword_utilities.parse_term_list_with_modifiers {
			paramname = field,
			list = forms,
			qualparams = quals,
		}
		check_all_missing(data, terms, plpos)
		if label:find("^%*") then
			terms.label = label:gsub("^%*", "")
		else
			terms.label = glossary_link(label)
		end
		table.insert(data.inflections, terms)
	end
end


-- Insert default plurals generated when a given plural had the value of + and default plurals were fetched as a result.
-- `plobj` is the parsed object whose `term` field is "+". `defpls` is the list of default plurals. `dest` is the list
-- into which the plurals are inserted (which inherit their qualifiers and labels from `plobj`).
local function insert_defpls(defpls, plobj, dest)
	if #defpls == 1 then
		plobj.term = defpls[1]
		table.insert(dest, plobj)
	else
		for _, defpl in ipairs(defpls) do
			local newplobj = m_table.shallowcopy(plobj)
			newplobj.term = defpl
			table.insert(dest, newplobj)
		end
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
	local plpos = m_string_utilities.pluralize(pos)

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

	local function fetch_inflections(field, default)
		local retval = m_headword_utilities.parse_term_list_with_modifiers {
			paramname = field,
			list = args[field],
			qualparams = args[field .. "_qual"],
		}
		if not retval[1] and default then
			return {{term = default}}
		end
		return retval
	end

	local function insert_inflection(forms, label, accel)
		if forms[1] then
			if forms[1].term == "-" then
				table.insert(data.inflections, {label = "no " .. label})
			else
				check_all_missing(data, forms, plpos)
				forms.label = label
				if accel then
					forms.accel = {form = accel}
				end
				table.insert(data.inflections, forms)
			end
		end
	end

	if args.inv then
		-- invariable adjective
		table.insert(data.inflections, {label = glossary_link("invariable")})
		table.insert(data.categories, langname .. " indeclinable " .. plpos)
		if args.sp or args.f[1] or args.pl[1] or args.mpl[1] or args.fpl[1] then
			error("Can't specify inflections with an invariable " .. pos)
		end
	elseif args.fonly then
		-- feminine-only
		if args.f[1] then
			error("Can't specify explicit feminines with feminine-only " .. pos)
		end
		if args.pl[1] then
			error("Can't specify explicit plurals with feminine-only " .. pos .. ", use fpl=")
		end
		if args.mpl[1] then
			error("Can't specify explicit masculine plurals with feminine-only " .. pos)
		end
		local argsfpl = fetch_inflections("fpl", "+")
		for _, fpl in ipairs(argsfpl) do
			if fpl.term == "+" then
				-- Generate default feminine plural.
				local defpls = com.make_plural(lemma, "f", args.sp)
				if not defpls then
					error("Unable to generate default plural of '" .. lemma .. "'")
				end
				insert_defpls(defpls, fpl, feminine_plurals)
			else
				fpl.term = replace_hash_with_lemma(fpl.term, lemma)
				table.insert(feminine_plurals, fpl)
			end
		end

		table.insert(data.inflections, {label = "feminine-only"})
		insert_inflection(feminine_plurals, "feminine plural", "f|p")
	else
		-- Gather feminines.
		for _, f in ipairs(fetch_inflections("f", "+")) do
			if f.term == "+" then
				-- Generate default feminine.
				f.term = com.make_feminine(lemma, args.sp)
			else
				f.term = replace_hash_with_lemma(f.term, lemma)
			end
			table.insert(feminines, f)
		end

		local fem_like_lemma = #feminines == 1 and feminines[1].term == lemma and
			not m_headword_utilities.termobj_has_qualifiers_or_labels(feminines[1])
		if fem_like_lemma then
			table.insert(data.categories, langname .. " epicene " .. plpos)
		end

		local mpl_field = "mpl"
		local fpl_field = "fpl"
		if args.pl[1] then
			if args.mpl[1] or args.fpl[1] or args.mpl_qual.maxindex > 0 or args.fpl_qual.maxindex > 0 then
				error("Can't specify both pl= and mpl=/fpl=")
			end
			mpl_field = "pl"
			fpl_field = "pl"
		end
		local argsmpl = fetch_inflections(mpl_field, "+")
		local argsfpl = fetch_inflections(fpl_field, "+")

		for _, mpl in ipairs(argsmpl) do
			if mpl.term == "+" then
				-- Generate default masculine plural.
				local defpls = com.make_plural(lemma, "m", args.sp)
				if not defpls then
					error("Unable to generate default plural of '" .. lemma .. "'")
				end
				insert_defpls(defpls, mpl, masculine_plurals)
			else
				mpl.term = replace_hash_with_lemma(mpl.term, lemma)
				table.insert(masculine_plurals, mpl)
			end
		end

		for _, fpl in ipairs(argsfpl) do
			if fpl.term == "+" then
				for _, f in ipairs(feminines) do
					-- Generate default feminine plural; f is a table.
					local defpls = com.make_plural(f.term, "f", args.sp)
					if not defpls then
						error("Unable to generate default plural of '" .. f.term .. "'")
					end
					for _, defpl in ipairs(defpls) do
						local fplobj = m_table.shallowcopy(fpl)
						fplobj.term = defpl
						m_headword_utilities.combine_termobj_qualifiers_labels(fplobj, f)
						table.insert(feminine_plurals, fplobj)
					end
				end
			else
				fpl.term = replace_hash_with_lemma(fpl.term, lemma)
				table.insert(feminine_plurals, fpl)
			end
		end

		insert_ancillary_inflection(data, args, "mapoc", "*masculine singular before a noun", plpos)

		local fem_pl_like_masc_pl = masculine_plurals[1] and feminine_plurals[1] and
			m_table.deepEquals(masculine_plurals, feminine_plurals)
		local masc_pl_like_lemma = #masculine_plurals == 1 and masculine_plurals[1].term == lemma and
			not m_headword_utilities.termobj_has_qualifiers_or_labels(masculine_plurals[1])
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

	insert_ancillary_inflection(data, args, "comp", "comparative", plpos)
	insert_ancillary_inflection(data, args, "sup", "superlative", plpos)
	insert_ancillary_inflection(data, args, "dim", "diminutive", plpos)
	insert_ancillary_inflection(data, args, "aug", "augmentative", plpos)

	if args.irreg and is_superlative then
		table.insert(data.categories, langname .. " irregular superlative " .. plpos)
	end
end


local function get_adjective_params(adjtype)
	local params = {
		["inv"] = boolean_param, --invariable
		["sp"] = {}, -- special indicator: "first", "first-last", etc.
	}
	local function ins_infl(field)
		params[field] = list_param --feminine form(s)
		params[field .. "_qual"] = {list = field .. "\1_qual", allow_holes = true}
	end

	ins_infl("f") -- feminine form(s)
	ins_infl("pl") -- plural override(s)
	ins_infl("mpl") -- masculine plural override(s)
	ins_infl("fpl") -- feminine plural override(s)

	if adjtype == "base" then
		ins_infl("mapoc") --masculine apocopated (before a noun)
		ins_infl("comp") --comparative(s)
		ins_infl("sup") --superlative(s)
		ins_infl("dim") --diminutive(s)
		ins_infl("aug") --augmentative(s)
		params["fonly"] = boolean_param -- feminine only
		params["gneut"] = boolean_param -- gender-neutral adjective e.g. [[latine]]
		params["hascomp"] = {} -- has comparative
	end
	if adjtype == "sup" then
		params["irreg"] = boolean_param
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
		["sup"] = list_param, --superlative(s)
	},
	func = function(args, data)
		insert_ancillary_inflection(data, args, "sup", "superlative", "adverbs")
	end,
}

-----------------------------------------------------------------------------------------
--                                        Numerals                                     --
-----------------------------------------------------------------------------------------

pos_functions["cardinal numbers"] = {
	params = {
		["f"] = list_param, --feminine(s)
		["mapoc"] = list_param, --masculine apocopated form(s)
	},
	func = function(args, data)
		local plpos = "numerals"
		data.pos_category = plpos
		table.insert(data.categories, 1, langname .. " cardinal numbers")

		if args.f[1] then
			table.insert(data.genders, "m")
			insert_ancillary_inflection(data, args, "f", "feminine", plpos)
		end
		insert_ancillary_inflection(data, args, "mapoc", "*masculine before a noun", plpos)
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
	local plpos = m_string_utilities.pluralize(pos)

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
		if args[2][1] then
			error("Can't specify plurals of plurale tantum " .. pos)
		end
		table.insert(data.inflections, {label = glossary_link("plural only")})
	else
		local plurals = m_headword_utilities.parse_term_list_with_modifiers {
			paramname = {2, "pl"},
			list = args.pl,
		}
		-- Check for special plural signals
		local mode = nil

		local pl1 = plurals[1]
		if pl1 and #pl1.term == 1 then
			mode = pl1.term
			if mode == "?" or mode == "!" or mode == "-" or mode == "~" then
				pl1.term = nil
				if next(pl1) then
					error(("Can't specify inline modifiers with plural code '%s'"):format(mode))
				end
				table.remove(plurals, 1)  -- Remove the mode parameter
			else
				error(("Unexpected plural code '%s'"):format(mode))
			end
		end

		if mode == "?" then
			-- Plural is unknown
			table.insert(data.categories, langname .. " " .. plpos .. " with unknown or uncertain plurals")
		elseif mode == "!" then
			-- Plural is not attested
			table.insert(data.inflections, {label = "plural not attested"})
			table.insert(data.categories, langname .. " " .. plpos .. " with unattested plurals")
			if plurals[1] then
				error("Can't specify any plurals along with unattested plural code '!'")
			end
		elseif mode == "-" then
			-- Uncountable noun; may occasionally have a plural
			table.insert(data.categories, langname .. " uncountable " .. plpos)

			-- If plural forms were given explicitly, then show "usually"
			if plurals[1] then
				table.insert(data.inflections, {label = "usually " .. glossary_link("uncountable")})
				table.insert(data.categories, langname .. " countable " .. plpos)
			else
				table.insert(data.inflections, {label = glossary_link("uncountable")})
			end
		else
			-- Countable or mixed countable/uncountable
			if not plurals[1] then
				plurals[1] = {term = "+"}
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

		-- Gather plurals, handling requests for default plurals.
		local has_default = false
		for _, pl in ipairs(plurals) do
			if pl.term:find("^%+") then
				has_default = true
				break
			end
		end
		if has_default then
			local newpls = {}
			for _, pl in ipairs(plurals) do
				if pl.term == "+" then
					local default_pls = com.make_plural(lemma, gender_for_make_plural)
					insert_defpls(default_pls, pl, newpls)
				elseif pl.term:find("^%+") then
					pl.term = require(romut_module).get_special_indicator(pl.term)
					local default_pls = com.make_plural(lemma, gender_for_make_plural, pl.term)
					insert_defpls(default_pls, pl, newpls)
				else
					pl.term = replace_hash_with_lemma(pl.term, lemma)
					table.insert(newpls, pl)
				end
			end
			plurals = newpls
		end
	end

	if #plurals > 1 then
		table.insert(data.categories, langname .. " " .. plpos .. " with multiple plurals")
	end

	-- Gather masculines/feminines. For each one, generate the corresponding plural(s).
	local function handle_mf(field, gender, inflect, default_plurals)
		local mfs = m_headword_utilities.parse_term_list_with_modifiers {
			paramname = field,
			list = args[field],
		}
		local retval = {}
		for _, mf in ipairs(mfs) do
			if mf.term == "+" then
				-- Generate default feminine.
				mf.term = inflect(lemma)
			else
				mf.term = replace_hash_with_lemma(mf.term, lemma)
			end
			local special = require(romut_module).get_special_indicator(mf.term)
			if special then
				mf.term = inflect(lemma, special)
			end
			table.insert(retval, mf)
			local mfpls = com.make_plural(mf.term, gender, special)
			if mfpls then
				for _, mfpl in ipairs(mfpls) do
					local plobj = m_table.shallowcopy(mf)
					plobj.term = mfpl
					-- Add an accelerator for each masculine/feminine plural whose lemma
					-- is the corresponding singular, so that the accelerated entry
					-- that is generated has a definition that looks like
					-- # {{plural of|es|MFSING}}
					plobj.accel = {form = "p", lemma = mf.term}
					table.insert(default_plurals, plobj)
				end
			end
		end
		return retval
	end

	local feminine_plurals = {}
	local feminines = handle_mf("f", "f", com.make_feminine, feminine_plurals)
	local masculine_plurals = {}
	local masculines = handle_mf("m", "m", com.make_masculine, masculine_plurals)

	local function handle_mf_plural(mfplfield, gender, default_plurals, singulars)
		local mfpl = args[mfplfield]
		local new_mfpls = {}
		local saw_plus
		for i, mfpl in ipairs(mfpl) do
			local accel
			if #mfpl == #singulars then
				-- If same number of overriding masculine/feminine plurals as singulars,
				-- assume each plural goes with the corresponding singular
				-- and use each corresponding singular as the lemma in the accelerator.
				-- The generated entry will have # {{plural of|es|SINGULAR}} as the
				-- definition.
				accel = {form = "p", lemma = singulars[i].term}
			else
				accel = nil
			end
			if mfpl.term == "+" then
				-- We should never see + twice. If we do, it will lead to problems since we overwrite the values of
				-- default_plurals the first time around.
				if saw_plus then
					error(("Saw + twice when handling %s="):format(mfplfield))
				end
				saw_plus = true
				for _, defpl in ipairs(default_plurals) do
					-- defpl is already a table and has an accel field
					m_headword_utilities.combine_termobj_qualifiers_labels(defpl, mf)
					table.insert(new_mfpls, defpl)
				end
			elseif mfpl.term:find("^%+") then
				mfpl.term = require(romut_module).get_special_indicator(mfpl.term)
				for _, mf in ipairs(singulars) do
					local default_mfpls = com.make_plural(mf.term, gender, mfpl.term)
					for _, defp in ipairs(default_mfpls) do
						local mfplobj = m_table.shallowcopy(mfpl)
						mfplobj.term = defp
						mfplobj.accel = accel
						m_headword_utilities.combine_termobj_qualifiers_labels(mfplobj, mf)
						table.insert(new_mfpls, mfplobj)
					end
				end
			else
				mfpl.accel = accel
				mfpl.term = replace_hash_with_lemma(mfpl.term, lemma)
				table.insert(new_mfpls, mfpl)
			end
		end
		return new_mfpls
	end

	if args.fpl[1] then
		-- Override any existing feminine plurals.
		feminine_plurals = handle_mf_plural("fpl", "f", feminine_plurals, feminines)
	end

	if args.mpl[1] then
		-- Override any existing masculine plurals.
		masculine_plurals = handle_mf_plural("mpl", "m", masculine_plurals, masculines)
	end

	local function insert_inflection(forms, label, accel)
		check_all_missing(data, forms, plpos)
		if forms[1] then
			forms.label = label
			if accel then
				forms.accel = {form = accel}
			end
			table.insert(data.inflections, forms)
		end
	end

	insert_inflection(plurals, "plural", "p")
	insert_inflection(feminines, "feminine", "f")
	insert_inflection(feminine_plurals, "feminine plural")
	insert_inflection(masculines, "masculine")
	insert_inflection(masculine_plurals, "masculine plural")
	insert_ancillary_inflection(data, args, "dim", "diminutive", plpos)
	insert_ancillary_inflection(data, args, "aug", "augmentative", plpos)
	insert_ancillary_inflection(data, args, "pej", "pejorative", plpos)

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
		["f"] = list_param, --feminine form(s)
		["m"] = list_param, --masculine form(s)
		["fpl"] = list_param, --feminine plural override(s)
		["mpl"] = list_param, --masculine plural override(s)
		["dim"] = list_param, --diminutive(s)
		["aug"] = list_param, --diminutive(s)
		["pej"] = list_param, --pejorative(s)
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
		["pres"] = list_param, --present
		["pres_qual"] = {list = "pres\1_qual", allow_holes = true},
		["pret"] = list_param, --preterite
		["pret_qual"] = {list = "pret\1_qual", allow_holes = true},
		["part"] = list_param, --participle
		["part_qual"] = {list = "part\1_qual", allow_holes = true},
		["pagename"] = {}, -- for testing
		["noautolinktext"] = boolean_param,
		["noautolinkverb"] = boolean_param,
		["attn"] = boolean_param,
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
			return specforms[slot] and specforms[slot][1]
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

		if args.pres[1] or args.pret[1] or args.part[1] then
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
				local quals, refs = require(inflection_utilities_module).
					convert_footnotes_to_qualifiers_and_references(lemma_obj.footnotes)
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
		["g"] = list_param,
		["g_qual"] = {list = "g\1_qual", allow_holes = true},
		["m"] = list_param,
		["m_qual"] = {list = "m\1_qual", allow_holes = true},
		["f"] = list_param,
		["f_qual"] = {list = "f\1_qual", allow_holes = true},
	},
	func = function(args, data)
		data.genders = {}
		process_genders(data, args.g, args.g_qual)
		local plpos = "phrases"
		insert_ancillary_inflection(data, args, "m", "masculine", plpos)
		insert_ancillary_inflection(data, args, "f", "feminine", plpos)
	end,
}

-----------------------------------------------------------------------------------------
--                                    Suffix forms                                     --
-----------------------------------------------------------------------------------------

pos_functions["suffix forms"] = {
	params = {
		[1] = {required = true, list = true, disallow_holes = true},
		["g"] = list_param,
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
