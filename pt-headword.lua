local export = {}
local pos_functions = {}
local rfind = mw.ustring.find
local rmatch = mw.ustring.match
local rsplit = mw.text.split

local m_links = require("Module:links")
local m_table = require("Module:table")
local com = require("Module:pt-common")
local romut_module = "Module:romance utilities"
local lang = require("Module:languages").getByCode("pt")
local langname = lang:getCanonicalName()

local suffix_categories = {
	["adjectives"] = true,
	["adverbs"] = true,
	["nouns"] = true,
	["verbs"] = true,
	["prepositional phrases"] = true,
}

-- When followed by a hyphen in a hyphenated compound, the hyphen will be included with the prefix when linked.
local include_hyphen_prefixes = m_table.listToSet {
	"ab",
	"afro",
	"anarco",
	"anglo",
	"ântero",
	"anti",
	"auto",
	"contra",
	"ex",
	"franco",
	"hiper",
	"infra",
	"inter",
	"intra",
	"macro",
	"micro",
	"neo",
	"pan",
	"pós",
	"pré",
	"pró",
	"proto",
	"sobre",
	"sub",
	"super",
	"vice",
}

local function track(page)
	require("Module:debug/track")("pt-headword/" .. page)
	return true
end

local function glossary_link(entry, text)
	text = text or entry
	return "[[Appendix:Glossary#" .. entry .. "|" .. text .. "]]"
end

local metaphonic_label = "[[Appendix:Portuguese pronunciation#Metaphony|metaphonic]]"

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
		local auto_linked_head = require(romut_module).add_lemma_links(pagename, args.splithyph, nil,
			include_hyphen_prefixes)
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

	local is_suffix = false
	if pagename:find("^%-") and suffix_categories[poscat] then
		is_suffix = true
		data.pos_category = "suffixes"
		local singular_poscat = poscat:gsub("s$", "")
		table.insert(data.categories, langname .. " " .. singular_poscat .. "-forming suffixes")
		table.insert(data.inflections, {label = singular_poscat .. "-forming suffix"})
	end

	local tracking_categories = {}

	if pos_functions[poscat] then
		pos_functions[poscat].func(args, data, tracking_categories, frame, is_suffix)
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


local function replace_hash_with_lemma(term, lemma)
	-- If there is a % sign in the lemma, we have to replace it with %% so it doesn't get interpreted as a capture replace
	-- expression.
	lemma = lemma:gsub("%%", "%%%%")
	-- Assign to a variable to discard second return value.
	term = term:gsub("#", lemma)
	return term
end

local function is_metaphonic(args, lemma)
	if args.nometa then
		return false
	end
	if args.meta then
		return true
	end
	-- Anything in -oso with a preceding vowel (e.g. [[gostoso]], [[curioso]]) is normally metaphonic.
	return rfind(lemma, com.V .. ".*oso$")
end


-----------------------------------------------------------------------------------------
--                                          Nouns                                      --
-----------------------------------------------------------------------------------------

local allowed_genders = m_table.listToSet(
	{"m", "f", "mf", "mfbysense", "m-p", "f-p", "mf-p", "mfbysense-p", "?", "?-p", "n", "n-p"}
)

local function do_noun(args, data, tracking_categories, pos, is_suffix, is_proper)
	local is_plurale_tantum = false
	local has_singular = false
	if is_suffix then
		pos = "suffix"
	end
	local plpos = require("Module:string utilities").pluralize(pos)

	data.genders = {}
	local saw_m = false
	local saw_f = false
	local gender_for_default_plural = args[1][1]
	for i, g in ipairs(args[1]) do
		if not allowed_genders[g] then
			error("Unrecognized gender: " .. g)
		end
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
		if args.g_qual[i] then
			table.insert(data.genders, {spec = g, qualifiers = {args.g_qual[i]}})
		else
			table.insert(data.genders, g)
		end
	end
	if saw_m and saw_f then
		gender_for_default_plural = "mf"
	end

	local lemma = m_links.remove_links(data.heads[1]) -- should always be specified

	local function insert_inflection(list, term, accel, qualifiers, no_inv)
		local infl = {qualifiers = qualifiers, accel = accel}
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
					table.insert(data.inflections, {label = glossary_link("invariable"), qualifiers = quals})
					table.insert(data.categories, langname .. " indeclinable " .. plpos)
				else
					insert_inflection(plurals, term, nil, quals)
				end
				table.insert(data.categories, langname .. " countable " .. plpos)
			end
			local function make_plural_and_insert(form, special)
				local pl = com.make_plural(lemma, special)
				if pl then
					insert_pl(pl)
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

	-- Gather masculines/feminines. For each one, generate the corresponding plural(s).
	local function handle_mf(mfs, qualifiers, inflect, default_plurals)
		local retval = {}
		for i, mf in ipairs(mfs) do
			local function insert_infl(list, term, accel, existing_qualifiers)
				insert_inflection(list, term, accel, fetch_qualifiers(qualifiers[i], existing_qualifiers), "no inv")
			end
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
			insert_infl(retval, mf)
			local mfpl = com.make_plural(mf, special)
			if mfpl then
				-- Add an accelerator for each masculine/feminine plural whose lemma
				-- is the corresponding singular, so that the accelerated entry
				-- that is generated has a definition that looks like
				-- # {{plural of|pt|MFSING}}
				insert_infl(default_plurals, mfpl, {form = "p", lemma = mf})
			end
		end
		return retval
	end

	local feminine_plurals = {}
	local feminines = handle_mf(args.f, args.f_qual, com.make_feminine, feminine_plurals)
	local masculine_plurals = {}
	local masculines = handle_mf(args.m, args.m_qual, com.make_masculine, masculine_plurals)

	local function handle_mf_plural(mfpl, qualifiers, default_plurals, singulars)
		local new_mfpls = {}
		for i, mfpl in ipairs(mfpl) do
			local function insert_infl(term, accel, existing_qualifiers, no_inv)
				insert_inflection(new_mfpls, term, accel, fetch_qualifiers(qualifiers[i], existing_qualifiers), no_inv)
			end
			local accel
			if #mfpl == #singulars then
				-- If same number of overriding masculine/feminine plurals as singulars,
				-- assume each plural goes with the corresponding singular
				-- and use each corresponding singular as the lemma in the accelerator.
				-- The generated entry will have # {{plural of|pt|SINGULAR}} as the
				-- definition.
				accel = {form = "p", lemma = singulars[i].term}
			else
				accel = nil
			end
			if mfpl == "+" then
				if #default_plurals > 0 then
					for _, defpl in ipairs(default_plurals) do
						-- defpl is a table
						-- don't use "invariable" because the plural is not with respect to the lemma but
						-- with respect to the masc/fem singular
						insert_infl(defpl.term_for_further_inflection, defpl.accel, defpl.qualifiers, "no inv")
					end
				else
					-- mf is a table
					local default_mfpl = com.make_plural(lemma)
					if default_mfpl then
						insert_infl(default_mfpl, accel)
					end
				end
			elseif mfpl:find("^%+") then
				mfpl = require(romut_module).get_special_indicator(mfpl)
				if #singulars > 0 then
					for _, mf in ipairs(singulars) do
						-- mf is a table
						local default_mfpl = com.make_plural(mf.term_for_further_inflection, mfpl)
						if default_mfpl then
							-- don't use "invariable" because the plural is not with respect to the lemma but
							-- with respect to the masc/fem singular
							insert_infl(default_mfpl, accel, mf.qualifiers, "no inv")
						end
					end
				else
					local default_mfpl = com.make_plural(lemma, mfpl)
					if default_mfpl then
						insert_infl(default_mfpl, accel)
					end
				end
			else
				mfpl = replace_hash_with_lemma(mfpl, lemma)
				-- don't use "invariable" if masc/fem singular present because the plural is not with respect to
				-- the lemma but with respect to the masc/fem singular
				insert_infl(mfpl, accel, nil, #singulars > 0)
			end
		end
		return new_mfpls
	end

	if #args_fpl > 0 then
		-- Override feminine plurals.
		feminine_plurals = handle_mf_plural(args_fpl, args.fpl_qual, feminine_plurals, feminines)
	end

	if #args_mpl > 0 then
		-- Override masculine plurals.
		masculine_plurals = handle_mf_plural(args_mpl, args.mpl_qual, masculine_plurals, masculines)
	end

	check_all_missing(plurals, plpos, tracking_categories)
	check_all_missing(feminines, plpos, tracking_categories)
	check_all_missing(feminine_plurals, plpos, tracking_categories)
	check_all_missing(masculines, plpos, tracking_categories)
	check_all_missing(masculine_plurals, plpos, tracking_categories)

	local function redundant_plural(pl)
		for _, p in ipairs(plurals) do
			if p.term_for_further_inflection == pl.term_for_further_inflection then
				return true
			end
		end
		return false
	end

	for _, mpl in ipairs(masculine_plurals) do
		if redundant_plural(mpl) then
			track("noun-redundant-mpl")
		end
	end

	for _, fpl in ipairs(feminine_plurals) do
		if redundant_plural(fpl) then
			track("noun-redundant-fpl")
		end
	end

	if #plurals > 0 then
		plurals.label = "plural"
		plurals.accel = {form = "p"}
		table.insert(data.inflections, plurals)
	end

	if #masculines > 0 then
		masculines.label = "masculine"
		table.insert(data.inflections, masculines)
	end

	if #masculine_plurals > 0 then
		masculine_plurals.label = "masculine plural"
		table.insert(data.inflections, masculine_plurals)
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

	if is_metaphonic(args, lemma) then
		table.insert(data.inflections, {label = metaphonic_label})
		table.insert(data.categories, langname .. " " .. plpos .. " with metaphony")
	end

	-- Maybe add category 'Portuguese nouns with irregular gender' (or similar)
	local irreg_gender_lemma = com.rsub(lemma, " .*", "") -- only look at first word
	if (rfind(irreg_gender_lemma, "[^ã]o$") and (gender_for_default_plural == "f" or gender_for_default_plural == "mf"
		or gender_for_default_plural == "mfbysense")) or
		(irreg_gender_lemma:find("a$") and (gender_for_default_plural == "m" or gender_for_default_plural == "mf"
		or gender_for_default_plural == "mfbysense")) then
		table.insert(data.categories, langname .. " " .. plpos .. " with irregular gender")
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
		["meta"] = {type = "boolean"}, -- metaphonic
		["nometa"] = {type = "boolean"}, -- explicitly not metaphonic
	}
end

pos_functions["nouns"] = {
	params = get_noun_params(),
	func = function(args, data, tracking_categories, frame, is_suffix)
		do_noun(args, data, tracking_categories, "noun", is_suffix)
	end,
}

pos_functions["proper nouns"] = {
	params = get_noun_params(),
	func = function(args, data, tracking_categories, frame, is_suffix)
		do_noun(args, data, tracking_categories, "proper noun", is_suffix, "is proper noun")
	end,
}


-----------------------------------------------------------------------------------------
--                                        Pronouns                                     --
-----------------------------------------------------------------------------------------

local function do_pronoun(args, data, tracking_categories, pos, is_suffix)
	if is_suffix then
		pos = "suffix"
	end
	local plpos = require("Module:string utilities").pluralize(pos)

	if not is_suffix then
		data.pos_category = plpos
	end

	local lemma = m_links.remove_links(data.heads[1]) -- should always be specified

	data.genders = {}
	for i, g in ipairs(args[1]) do
		if g ~= "n" and g ~= "n-p" and not allowed_genders[g] then
			error("Unrecognized gender: " .. g)
		end
		if args.g_qual[i] then
			table.insert(data.genders, {spec = g, qualifiers = {args.g_qual[i]}})
		else
			table.insert(data.genders, g)
		end
	end

	local function do_inflection(forms, quals, label)
		if #forms > 0 then
			local terms = process_terms_with_qualifiers(forms, quals)
			check_all_missing(terms, plpos, tracking_categories)
			terms.label = label
			table.insert(data.inflections, terms)
		end
	end

	do_inflection(args.m, args.m_qual, "masculine")
	do_inflection(args.f, args.f_qual, "feminine")
	do_inflection(args.sg, args.sg_qual, "singular")
	do_inflection(args.pl, args.pl_qual, "plural")
	do_inflection(args.mpl, args.mpl_qual, "masculine plural")
	do_inflection(args.fpl, args.fpl_qual, "feminine plural")
	do_inflection(args.n, args.n_qual, "neuter")
end

local function get_pronoun_params()
	local params = {
		[1] = {list = "g"}, --gender(s)
		["g_qual"] = {list = "g=_qual", allow_holes = true},
		["m"] = {list = true}, --masculine form(s)
		["m_qual"] = {list = "m=_qual", allow_holes = true},
		["f"] = {list = true}, --feminine form(s)
		["f_qual"] = {list = "f=_qual", allow_holes = true},
		["sg"] = {list = true}, --singular form(s)
		["sg_qual"] = {list = "sg=_qual", allow_holes = true},
		["pl"] = {list = true}, --plural form(s)
		["pl_qual"] = {list = "pl=_qual", allow_holes = true},
		["mpl"] = {list = true}, --masculine plural form(s)
		["mpl_qual"] = {list = "mpl=_qual", allow_holes = true},
		["fpl"] = {list = true}, --feminine plural form(s)
		["fpl_qual"] = {list = "fpl=_qual", allow_holes = true},
		["n"] = {list = true}, --neuter form(s)
		["n_qual"] = {list = "n=_qual", allow_holes = true},
	}
	return params
end

pos_functions["pronouns"] = {
	params = get_pronoun_params(),
	func = function(args, data, tracking_categories, frame, is_suffix)
		do_pronoun(args, data, tracking_categories, "pronoun", is_suffix)
	end,
}


-----------------------------------------------------------------------------------------
--                                       Adjectives                                    --
-----------------------------------------------------------------------------------------

local function insert_ancillary_inflection(data, forms, quals, label, plpos, tracking_categories)
	if forms and #forms > 0 then
		local terms = process_terms_with_qualifiers(forms, quals)
		check_all_missing(terms, plpos, tracking_categories)
		terms.label = label
		table.insert(data.inflections, terms)
	end
end

-- Handle comparatives and superlatives for adjectives and adverbs, including user-specified comparatives and
-- superlatives, default-requested comparatives/superlatives using '+', autogenerated comparatives/superlatives,
-- and hascomp=. Code is the same for adjectives and adverbs.
local function handle_adj_adv_comp(args, data, plpos, is_adv, tracking_categories)
	local lemma = m_links.remove_links(data.heads[1]) -- should always be specified
	local stem

	if is_adv then
		stem = com.rsub(lemma, "mente$", "")
	else
		stem = lemma
	end

	local function make_absolute_superlative(special)
		if is_adv then
			return com.make_adverbial_absolute_superlative(stem, special)
		else
			return com.make_absolute_superlative(stem, special)
		end
	end

	-- Maybe autogenerate default comparative/superlative.
	if args.comp and args.sup then-- comp= and sup= were given as options to the user
		-- If no comp, but a non-default sup given, then add the default comparative/superlative.
		-- This is useful when an absolute superlative is given.
		local saw_sup_plus = false
		if #args.comp == 0 and #args.sup > 0 then
			for i, supval in ipairs(args.sup) do
				if supval == "+" then
					saw_sup_plus = true
				end
			end
			if not saw_sup_plus then
				args.comp = {"+"}
				table.insert(args.sup, 1, "+")
			end
		end

		-- If comp=+, use default comparative 'mais ...', and set a default superlative if unspecified.
		local saw_comp_plus = false
		for i, compval in ipairs(args.comp) do
			if compval == "+" then
				saw_comp_plus = true
				args.comp[i] = "[[mais]] [[" .. lemma .. "]]"
			end
		end
		if saw_comp_plus and #args.sup == 0 then
			args.sup = {"+"}
		end
		-- If sup=+ (possibly from comp=+), use default superlative 'o mais ...'. Also handle absolute superlatives.
		for i, supval in ipairs(args.sup) do
			if supval == "+" then
				args.sup[i] = "[[o]] [[mais]] [[" .. lemma .. "]]"
			elseif supval == "+abs" then
				args.sup[i] = make_absolute_superlative()
			elseif rfind(supval, "^%+abs:") then
				local sp = rmatch(supval, "^%+abs:(.*)$")
				args.sup[i] = make_absolute_superlative(sp)
			end
		end
	end

	if args.hascomp then
		if args.hascomp == "both" then
			table.insert(data.inflections, {label = "sometimes " .. glossary_link("comparable")})
			table.insert(data.categories, langname .. " comparable " .. plpos)
			table.insert(data.categories, langname .. " uncomparable " .. plpos)
		else
			local hascomp = require("Module:yesno")(args.hascomp)
			if hascomp == true then
				table.insert(data.inflections, {label = glossary_link("comparable")})
				table.insert(data.categories, langname .. " comparable " .. plpos)
			elseif hascomp == false then
				table.insert(data.inflections, {label = "not " .. glossary_link("comparable")})
				table.insert(data.categories, langname .. " uncomparable " .. plpos)
			else
				error("Unrecognized value for hascomp=: " .. args.hascomp)
			end
		end
	elseif args.comp and #args.comp > 0 or args.sup and #args.sup > 0 then
		table.insert(data.inflections, {label = glossary_link("comparable")})
		table.insert(data.categories, langname .. " comparable " .. plpos)
	end

	insert_ancillary_inflection(data, args.comp, args.comp_qual, "comparative", plpos, tracking_categories)
	insert_ancillary_inflection(data, args.sup, args.sup_qual, "superlative", plpos, tracking_categories)
end

local function do_adjective(args, data, tracking_categories, pos, is_suffix, is_superlative)
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
			if fpl == "+" then
				local defpl = com.make_plural(lemma, args.sp)
				if not defpl then
					error("Unable to generate default plural of '" .. lemma .. "'")
				end
				fpl = defpl
			else
				fpl = replace_hash_with_lemma(fpl, lemma)
			end
			table.insert(feminine_plurals, {term = fpl, qualifiers = fetch_qualifiers(args.fpl_qual[i])})
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
			else
				f = replace_hash_with_lemma(f, lemma)
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
			else
				mpl = replace_hash_with_lemma(mpl, lemma)
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
			else
				fpl = replace_hash_with_lemma(fpl, lemma)
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

	insert_ancillary_inflection(data, args.n, args.n_qual, "neuter", plpos, tracking_categories)

	handle_adj_adv_comp(args, data, plpos, false, tracking_categories)

	-- Handle requests for default diminutive.
	if args.dim then
		for i, dim in ipairs(args.dim) do
			if dim == "+" then
				args.dim[i] = com.make_diminutive(lemma)
			elseif dim:find("^%+") then
				dim = require(romut_module).get_special_indicator(dim)
				args.dim[i] = com.make_diminutive(lemma, dim)
			end
		end
	end

	-- Handle requests for default augmentative.
	if args.aug then
		for i, aug in ipairs(args.aug) do
			if aug == "+" then
				args.aug[i] = com.make_augmentative(lemma)
			elseif aug:find("^%+") then
				aug = require(romut_module).get_special_indicator(aug)
				args.aug[i] = com.make_augmentative(lemma, aug)
			end
		end
	end

	insert_ancillary_inflection(data, args.dim, args.dim_qual, "diminutive", plpos, tracking_categories)
	insert_ancillary_inflection(data, args.aug, args.aug_qual, "augmentative", plpos, tracking_categories)

	if is_metaphonic(args, lemma) then
		table.insert(data.inflections, {label = metaphonic_label})
		table.insert(data.categories, langname .. " " .. plpos .. " with metaphony")
	end

	if args.irreg and is_superlative then
		table.insert(data.categories, langname .. " irregular superlative " .. plpos)
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
		["meta"] = {type = "boolean"}, -- metaphonic
		["nometa"] = {type = "boolean"}, -- explicitly not metaphonic
	}
	if adjtype == "base" or adjtype == "part" or adjtype == "det" then
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
	if adjtype == "pron" or adjtype == "contr" then
		params["n"] = {list = true} --neuter form(s)
		params["n_qual"] = {list = "n=_qual", allow_holes = true}
	end
	return params
end

pos_functions["adjectives"] = {
	params = get_adjective_params("base"),
	func = function(args, data, tracking_categories, frame, is_suffix)
		do_adjective(args, data, tracking_categories, "adjective", is_suffix)
	end,
}

pos_functions["comparative adjectives"] = {
	params = get_adjective_params("comp"),
	func = function(args, data, tracking_categories, frame, is_suffix)
		do_adjective(args, data, tracking_categories, "adjective", is_suffix)
	end,
}

pos_functions["superlative adjectives"] = {
	params = get_adjective_params("sup"),
	func = function(args, data, tracking_categories, frame, is_suffix)
		do_adjective(args, data, tracking_categories, "adjective", is_suffix, "is superlative")
	end,
}

pos_functions["past participles"] = {
	params = get_adjective_params("part"),
	func = function(args, data, tracking_categories, frame, is_suffix)
		do_adjective(args, data, tracking_categories, "participle", is_suffix)
		data.pos_category = "past participles"
	end,
}

pos_functions["determiners"] = {
	params = get_adjective_params("det"),
	func = function(args, data, tracking_categories, frame, is_suffix)
		do_adjective(args, data, tracking_categories, "determiner", is_suffix)
	end,
}

pos_functions["adjective-like pronouns"] = {
	params = get_adjective_params("pron"),
	func = function(args, data, tracking_categories, frame, is_suffix)
		do_adjective(args, data, tracking_categories, "pronoun", is_suffix)
	end,
}

pos_functions["adjective-like contractions"] = {
	params = get_adjective_params("contr"),
	func = function(args, data, tracking_categories, frame, is_suffix)
		do_adjective(args, data, tracking_categories, "contraction", is_suffix)
	end,
}


-----------------------------------------------------------------------------------------
--                                        Adverbs                                      --
-----------------------------------------------------------------------------------------

local function do_adverb(args, data, tracking_categories, pos, is_suffix)
	if is_suffix then
		pos = "suffix"
	end
	local plpos = require("Module:string utilities").pluralize(pos)

	if not is_suffix then
		data.pos_category = plpos
	end

	handle_adj_adv_comp(args, data, plpos, "is adv", tracking_categories)
end

local function get_adverb_params(advtype)
	local params = {}
	if advtype == "base" then
		params["comp"] = {list = true} --comparative(s)
		params["comp_qual"] = {list = "comp=_qual", allow_holes = true}
		params["sup"] = {list = true} --superlative(s)
		params["sup_qual"] = {list = "sup=_qual", allow_holes = true}
		params["hascomp"] = {} -- has comparative
	end
	return params
end

pos_functions["adverbs"] = {
	params = get_adverb_params("base"),
	func = function(args, data, tracking_categories, frame, is_suffix)
		do_adverb(args, data, tracking_categories, "adverb", is_suffix)
	end,
}

pos_functions["comparative adverbs"] = {
	params = get_adverb_params("comp"),
	func = function(args, data, tracking_categories, frame, is_suffix)
		do_adverb(args, data, tracking_categories, "adverb", is_suffix)
	end,
}

pos_functions["superlative adverbs"] = {
	params = get_adverb_params("sup"),
	func = function(args, data, tracking_categories, frame, is_suffix)
		do_adverb(args, data, tracking_categories, "adverb", is_suffix)
	end,
}

return export
