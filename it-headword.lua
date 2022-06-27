-- This module contains code for Italian headword templates.
-- Templates covered are:
-- * {{it-noun}}, {{it-proper noun}};
-- * {{it-verb}};
-- * {{it-adj}}, {{it-adj-comp}}, {{it-adj-sup}};
-- * {{it-det}};
-- * {{it-pron-adj}};
-- * {{it-pp}};
-- * {{it-presp}};
-- * {{it-card-noun}}, {{it-card-adj}}, {{it-card-inv}};
-- * {{it-adv}}.
-- See [[Module:it-verb]] for Italian conjugation templates.
-- See [[Module:it-conj]] for an older Italian conjugation module that is still widely used but will be going away.
local export = {}
local pos_functions = {}

local m_links = require("Module:links")
local m_table = require("Module:table")

local u = mw.ustring.char
local rfind = mw.ustring.find
local rsubn = mw.ustring.gsub
local rmatch = mw.ustring.match
local rsplit = mw.text.split
local ulower = mw.ustring.lower
local uupper = mw.ustring.upper
local usub = mw.ustring.sub
local ulen = mw.ustring.len
local unfd = mw.ustring.toNFD
local unfc = mw.ustring.toNFC

local lang = require("Module:languages").getByCode("it")
local langname = "Italian"

local force_cat = false -- for testing; if true, categories appear in non-mainspace pages

local GR = u(0x0300)
local V = "[aeiou]"
local NV = "[^aeiou]"
local AV = "[àèéìòóù]"

-- version of rsubn() that discards all but the first return value
local function rsub(term, foo, bar)
	local retval = rsubn(term, foo, bar)
	return retval
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

local suffix_categories = {
	["adjectives"] = true,
	["adverbs"] = true,
	["nouns"] = true,
	["verbs"] = true,
}

local prepositions = {
	-- a, da + optional article
	"d?al? ",
	"d?all[oae] ",
	"d?all'",
	"d?ai ",
	"d?agli ",
	-- di, in + optional article
	"di ",
	"d'",
	"in ",
	"[dn]el ",
	"[dn]ell[oae] ",
	"[dn]ell'",
	"[dn]ei ",
	"[dn]egli ",
	-- su + optional article
	"su ",
	"sul ",
	"sull[oae] ",
	"sull'",
	"sui ",
	"sugli ",
	-- others
	"come ",
	"con ",
	"per ",
	"tra ",
	"fra ",
}

-- The main entry point.
-- FIXME: Convert itprop to go through this.
function export.show(frame)
	local tracking_categories = {}

	local poscat = frame.args[1]
		or error("Part of speech has not been specified. Please pass parameter 1 to the module invocation.")

	local params = {
		["head"] = {list = true},
		["suff"] = {type = "boolean"},
		["id"] = {},
		["sort"] = {},
		["splithyph"] = {type = "boolean"},
		["pagename"] = {}, -- for testing
	}

	local parargs = frame:getParent().args

	if poscat == "verbs-old" then
		local m_headword_old = require("Module:it-headword/old")
		pos_functions = m_headword_old.pos_functions
		poscat = "verbs"
	end

	if pos_functions[poscat] then
		for key, val in pairs(pos_functions[poscat].params) do
			params[key] = val
		end
	end

	local args = require("Module:parameters").process(parargs, params)
	local user_specified_heads = args.head
	local heads = user_specified_heads
	local pagename = args.pagename or mw.title.getCurrentTitle().text
	if #heads == 0 then
		heads = {require("Module:romance utilities").add_lemma_links(pagename, args.splithyph)}
	end
		
	local data = {
		lang = lang,
		pos_category = poscat,
		categories = {},
		user_specified_heads = user_specified_heads,
		heads = heads,
		pagename = pagename,
		genders = {},
		inflections = {},
		id = args.id,
		sort_key = args.sort,
		force_cat_output = force_cat,
	}

	if args.suff then
		data.pos_category = "suffixes"

		if suffix_categories[poscat] then
			local singular_poscat = poscat:gsub("s$", "")
			table.insert(data.categories, langname .. " " .. singular_poscat .. "-forming suffixes")
		else
			error("No category exists for suffixes forming " .. poscat .. ".")
		end
	end

	if pos_functions[poscat] then
		pos_functions[poscat].func(args, data, tracking_categories, frame)
	end

	return require("Module:headword").full_headword(data)
		.. require("Module:utilities").format_categories(tracking_categories, lang, args.sort, nil, force_cat)
end

-- Generate a default plural form, which is correct for most regular nouns and adjectives.
local function make_plural(form, gender, special)
	local plspec
	if special == "cap*" or special == "cap*+" then
		plspec = special
		special = nil
	end
	local retval = require("Module:romance utilities").handle_multiword(form, special,
		function(form) return make_plural(form, gender, plspec) end, prepositions)
	if retval and #retval > 0 then
		if #retval ~= 1 then
			error("Internal error: Should have one return value for make_plural: " .. table.concat(retval, ","))
		end
		return retval[1]
	end

	local function check_no_mf()
		if gender == "mf" or gender == "mfbysense" or gender == "?" then
			error("With gender=" .. gender .. ", unable to pluralize form '" .. form .. "'"
				.. (special and " using special=" .. special or "") .. " because its plural is gender-specific")
		end
	end

	if plspec == "cap*" or plspec == "cap*+" then
		check_no_mf()
		if not form:find("^capo") then
			error("With special=" .. plspec .. ", form '" .. form .. "' must begin with capo-")
		end
		if gender == "m" then
			form = form:gsub("^capo", "capi")
		end
		if plspec == "cap*" then
			return form
		end
	end

	if form:find("io$") then
		form = form:gsub("io$", "i")
	elseif form:find("ologo$") then
		form = form:gsub("o$", "i")
	elseif form:find("[ia]co$") then
		form = form:gsub("o$", "i")
	-- Of adjectives in -co but not in -aco or -ico, there are several in -esco that take -eschi, and various
	-- others that take -chi: [[adunco]], [[anficerco]], [[azteco]], [[bacucco]], [[barocco]], [[basco]],
	-- [[bergamasco]], [[berlusco]], [[bianco]], [[bieco]], [[bisiacco]], [[bislacco]], [[bisulco]], [[brigasco]],
	-- [[brusco]], [[bustocco]], [[caduco]], [[ceco]], [[cecoslovacco]], [[cerco]], [[chiavennasco]], [[cieco]],
	-- [[ciucco]], [[comasco]], [[cosacco]], [[cremasco]], [[crucco]], [[dificerco]], [[dolco]], [[eterocerco]],
	-- [[etrusco]], [[falisco]], [[farlocco]], [[fiacco]], [[fioco]], [[fosco]], [[franco]], [[fuggiasco]], [[giucco]],
	-- [[glauco]], [[gnocco]], [[gnucco]], [[guatemalteco]], [[ipsiconco]], [[lasco]], [[livignasco]], [[losco]], 
	-- [[manco]], [[monco]], [[monegasco]], [[neobarocco]], [[olmeco]], [[parco]], [[pitocco]], [[pluriconco]], 
	-- [[poco]], [[polacco]], [[potamotoco]], [[prebarocco]], [[prisco]], [[protobarocco]], [[rauco]], [[ricco]], 
	-- [[risecco]], [[rivierasco]], [[roco]], [[roiasco]], [[sbieco]], [[sbilenco]], [[sciocco]], [[secco]],
	-- [[semisecco]], [[slovacco]], [[somasco]], [[sordocieco]], [[sporco]], [[stanco]], [[stracco]], [[staricco]],
	-- [[taggiasco]], [[tocco]], [[tosco]], [[triconco]], [[trisulco]], [[tronco]], [[turco]], [[usbeco]], [[uscocco]],
	-- [[uto-azteco]], [[uzbeco]], [[valacco]], [[vigliacco]], [[zapoteco]].
	--
	-- Only the following take -ci: [[biunivoco]], [[dieco]], [[equivoco]], [[estrinseco]], [[greco]], [[inequivoco]],
	-- [[intrinseco]], [[italigreco]], [[magnogreco]], [[meteco]], [[neogreco]], [[osco]] (either -ci or -chi),
	-- [[petulco]] (either -chi or -ci), [[plurivoco]], [[porco]], [[pregreco]], [[reciproco]], [[stenoeco]],
	-- [[tagicco]], [[univoco]], [[volsco]].
	elseif form:find("[cg]o$") then
		form = form:gsub("o$", "hi")
	elseif form:find("o$") then
		form = form:gsub("o$", "i")
	elseif form:find("[cg]a$") then
		check_no_mf()
		form = form:gsub("a$", (gender == "m" and "hi" or "he"))
	elseif form:find("logia$") then
		if gender ~= "f" then
			error("Form '" .. form .. "' ending in -logia should have gender=f if it is using the default plural")
		end
		form = form:gsub("a$", "e")
	elseif form:find("[cg]ia$") then
		check_no_mf()
		form = form:gsub("ia$", (gender == "m" and "i" or "e"))
	elseif form:find("a$") then
		check_no_mf()
		form = form:gsub("a$", (gender == "m" and "i" or "e"))
	elseif form:find("e$") then
		form = form:gsub("e$", "i")
	else
		return nil
	end
	return form
end

-- Generate a default feminine form.
local function make_feminine(form, special)
	local retval = require("Module:romance utilities").handle_multiword(form, special, make_feminine, prepositions)
	if retval then
		if #retval ~= 1 then
			error("Internal error: Should have one return value for make_feminine: " .. table.concat(retval, ","))
		end
		return retval[1]
	end

	-- Don't directly return gsub() because then there will be multiple return values.
	if form:find("o$") then
		form = form:gsub("o$", "a")
	elseif form:find("tore$") then
		form = form:gsub("tore$", "trice")
	elseif form:find("one$") then
		form = form:gsub("one$", "ona")
	end

	return form
end

-- Generate a default masculine form.
local function make_masculine(form, special)
	local retval = require("Module:romance utilities").handle_multiword(form, special, make_masculine, prepositions)
	if retval then
		if #retval ~= 1 then
			error("Internal error: Should have one return value for make_masculine: " .. table.concat(retval, ","))
		end
		return retval[1]
	end

	-- Don't directly return gsub() because then there will be multiple return values.
	if form:find("a$") then
		form = form:gsub("a$", "o")
	elseif form:find("trice$") then
		form = form:gsub("trice$", "tore")
	end

	return form
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

local allowed_genders = m_table.listToSet(
	{"m", "f", "mf", "mfbysense", "m-p", "f-p", "mf-p", "mfbysense-p", "?", "?-p"}
)

local function do_noun(args, data, tracking_categories, pos)
	local is_plurale_tantum = false
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

	local function insert_inflection(list, term, accel, qualifiers, genders, no_inv)
		if genders then
			for _, g in ipairs(genders) do
				if g == "m" and not saw_m or g == "f" and not saw_f then
					table.insert(data.categories, langname .. " " .. plpos .. " that change gender in the plural")
				end
			end
		end
					
		local infl = {qualifiers = qualifiers, accel = accel, genders = genders}
		if term == lemma and not no_inv then
			infl.label = glossary_link("invariable")
		else
			infl.term = term
		end
		infl.term_for_further_inflection = term
		table.insert(list, infl)
	end

	-- Plural
	local plurals = {}
	local args_mpl = args.mpl
	local args_fpl = args.fpl
	local args_pl = args[2]

	if is_plurale_tantum then
		if #args_pl > 0 then
			error("Can't specify plurals of plurale tantum " .. pos)
		end
		table.insert(data.inflections, {label = glossary_link("plural only")})
	elseif args.apoc then
		-- apocopated noun
		if #args_pl > 0 then
			error("Can't specify plurals of apocopated " .. pos)
		end
		table.insert(data.inflections, {label = glossary_link("apocopated")})
		data.pos_category = pos .. " forms"
	else
		-- If no plurals, use the default plural unless mpl= or fpl= explicitly given.
		if #args_pl == 0 and #args_mpl == 0 and #args_fpl == 0 then
			args_pl = {"+"}
		end
		-- If only ~ given (countable and uncountable), add the default plural after it.
		if #args_pl == 1 and args_pl[1] == "~" then
			args_pl = {"~", "+"}
		end
		-- Gather plurals, handling requests for default plurals
		for i, pl in ipairs(args_pl) do
			local function insert_pl(term)
				if term == lemma and i == 1 then
					-- Invariable
					-- If plural forms were given explicitly, then show "usually"
					if #args_pl > 1 then
						table.insert(data.inflections, {label = "usually " .. glossary_link("invariable")})
					else
						table.insert(data.inflections, {label = glossary_link("invariable")})
					end
					table.insert(data.categories, langname .. " indeclinable " .. plpos)
				else
					insert_inflection(plurals, term, nil, fetch_qualifiers(args.pl_qual[i]),
						args.pl_g[i] and rsplit(args.pl_g[i], "%s*,%s*") or nil)
				end
				table.insert(data.categories, langname .. " countable " .. plpos)
			end
			local function make_gendered_plural(form, gender, special)
				if gender == "mf" then
					local default_mpl = make_plural(lemma, "m", special)
					local default_fpl = make_plural(lemma, "f", special)
					if default_mpl then
						if default_mpl == default_fpl then
							insert_pl(default_mpl)
						else
							if #args_mpl > 0 or #args_fpl > 0 then
								error("Can't specify gendered plural spec '" .. (special or "+") .. "' along with gender=" .. gender
									.. " and also specify mpl= or fpl=")
							end
							args_mpl = {default_mpl}
							args_fpl = {default_fpl}
						end
					end
				else
					local pl = make_plural(lemma, gender, special)
					if pl then
						insert_pl(pl)
					end
				end
			end

			if pl == "cap*" or pl == "cap*+" then
				make_gendered_plural(lemma, gender_for_default_plural, pl)
			elseif pl == "+" then
				make_gendered_plural(lemma, gender_for_default_plural)
			elseif pl:find("^%+") then
				pl = require("Module:romance utilities").get_special_indicator(pl)
				make_gendered_plural(lemma, gender_for_default_plural, pl)
			elseif pl == "?" or pl == "!" then
				if i > 1 or #args_pl > 1 then
					error("Can't specify ? or ! with other plurals")
				end
				if pl == "?" then
					-- Plural is unknown
					table.insert(data.inflections, {label = "plural unknown or uncertain"})
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
				if pl == "#" then
					pl = lemma
				end
				insert_pl(pl)
			end
		end
	end
	
	if #plurals > 1 then
		table.insert(data.categories, langname .. " " .. plpos .. " with multiple plurals")
	end

	-- Gather masculines/feminines. For each one, generate the corresponding plural(s).
	local function handle_mf(mfs, qualifiers, gender, inflect, default_plurals)
		local retval = {}
		for i, mf in ipairs(mfs) do
			local function insert_infl(list, term, accel, existing_qualifiers)
				insert_inflection(list, term, accel, fetch_qualifiers(qualifiers[i], existing_qualifiers), nil, "no inv")
			end
			if mf == "+" then
				-- Generate default feminine.
				mf = inflect(lemma)
			elseif mf == "#" then
				mf = lemma
			end
			local special = require("Module:romance utilities").get_special_indicator(mf)
			if special then
				mf = inflect(lemma, special)
			end
			insert_infl(retval, mf)
			local mfpl = make_plural(mf, gender, special)
			if mfpl then
				-- Add an accelerator for each masculine/feminine plural whose lemma
				-- is the corresponding singular, so that the accelerated entry
				-- that is generated has a definition that looks like
				-- # {{plural of|es|MFSING}}
				insert_infl(default_plurals, mfpl, {form = "p", lemma = mf})
			end
		end
		return retval
	end

	local default_feminine_plurals = {}
	local feminine_plurals = {}
	local feminines = handle_mf(args.f, args.f_qual, "f", make_feminine, default_feminine_plurals)
	local default_masculine_plurals = {}
	local masculine_plurals = {}
	local masculines = handle_mf(args.m, args.m_qual, "m", make_masculine, default_masculine_plurals)

	local function handle_mf_plural(mfpl, qualifiers, gender, default_plurals, singulars)
		local new_mfpls = {}
		for i, mfpl in ipairs(mfpl) do
			local function insert_infl(term, accel, existing_qualifiers, no_inv)
				insert_inflection(new_mfpls, term, accel, fetch_qualifiers(qualifiers[i], existing_qualifiers), nil, no_inv)
			end
			local accel
			if #mfpl == #singulars then
				-- If same number of overriding masculine/feminine plurals as singulars,
				-- assume each plural goes with the corresponding singular
				-- and use each corresponding singular as the lemma in the accelerator.
				-- The generated entry will have # {{plural of|it|SINGULAR}} as the
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
					local default_mfpl = make_plural(lemma, gender)
					if default_mfpl then
						insert_infl(default_mfpl, accel)
					end
				end
			elseif mfpl == "#" then
				insert_infl(lemma, accel)
			elseif mfpl == "cap*" or mfpl == "cap*+" or mfpl:find("^%+") then
				if mfpl:find("^%+") then
					mfpl = require("Module:romance utilities").get_special_indicator(mfpl)
				end
				if #singulars > 0 then
					for _, mf in ipairs(singulars) do
						-- mf is a table
						local default_mfpl = make_plural(mf.term_for_further_inflection, gender, mfpl)
						if default_mfpl then
							-- don't use "invariable" because the plural is not with respect to the lemma but
							-- with respect to the masc/fem singular
							insert_infl(default_mfpl, accel, mf.qualifiers, "no inv")
						end
					end
				else
					local default_mfpl = make_plural(lemma, gender, mfpl)
					if default_mfpl then
						insert_infl(default_mfpl, accel)
					end
				end
			else
				-- don't use "invariable" if masc/fem singular present because the plural is not with respect to
				-- the lemma but with respect to the masc/fem singular
				insert_infl(mfpl, accel, nil, #singulars > 0)
			end
		end
		return new_mfpls
	end

	-- FIXME: We should generate feminine plurals by default from feminine singulars given, and vice-versa.
	-- To do that, eliminate the distinction between `default_feminine_plurals` and `feminine_plurals`,
	-- as in [[Module:es-headword]].
	if #args_fpl > 0 then
		-- Set feminine plurals.
		feminine_plurals = handle_mf_plural(args_fpl, args.fpl_qual, "f", default_feminine_plurals, feminines)
	end

	if #args_mpl > 0 then
		-- Set masculine plurals.
		masculine_plurals = handle_mf_plural(args_mpl, args.mpl_qual, "m", default_masculine_plurals, masculines)
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

	-- Maybe add category 'Italian nouns with irregular gender' (or similar)
	local irreg_gender_lemma = rsub(lemma, " .*", "") -- only look at first word
	if (irreg_gender_lemma:find("o$") and (gender_for_default_plural == "f" or gender_for_default_plural == "mf"
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
		["apoc"] = {type = "boolean"}, --apocopated
		["g_qual"] = {list = "g=_qual", allow_holes = true},
		["pl_qual"] = {list = "pl=_qual", allow_holes = true},
		["pl_g"] = {list = "pl=_g", allow_holes = true},
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
	func = function(args, data, tracking_categories)
		do_noun(args, data, tracking_categories, "noun")
	end,
}

pos_functions["cardinal nouns"] = {
	params = get_noun_params(),
	func = function(args, data, tracking_categories)
		do_noun(args, data, tracking_categories, "numeral")
		data.pos_category = "numerals"
		table.insert(data.categories, 1, langname .. " cardinal numbers")
	end,
}

function export.itprop(frame)
	local params = {
		[1] = {list = "g", default = "?"},

		["head"] = {list = true},
		["m"] = {list = true},
		["f"] = {list = true},
		["sort"] = {},
	}
	
	local args = require("Module:parameters").process(frame:getParent().args, params)
	
	local data = {
		lang = lang, pos_category = "proper nouns", categories = {}, sort_key = args.sort,
		heads = args.head, genders = args[1], inflections = {}
	}

	local is_plurale_tantum = false

	for _, g in ipairs(args[1]) do
		if not allowed_genders[g] then
			error("Unrecognized gender: " .. g)
		end
		if g:find("-p$") then
			is_plurale_tantum = true
		end
	end

	if is_plurale_tantum then
		table.insert(data.inflections, {label = glossary_link("plural only")})
	end

	-- Other gender
	if #args.f > 0 then
		args.f.label = "feminine"
		table.insert(data.inflections, args.f)
	end
	
	if #args.m > 0  then
		args.m.label = "masculine"
		table.insert(data.inflections, args.m)
	end

	return require("Module:headword").full_headword(data)
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
	end
	if args.apoc then
		-- apocopated adjective
		table.insert(data.inflections, {label = glossary_link("apocopated")})
		if args.sp or #args.f > 0 or #args.pl > 0 or #args.mpl > 0 or #args.fpl > 0 then
			error("Can't specify inflections with an apocopated adjective")
		end
		data.pos_category = pos .. " forms"
	end
	if args.inv or args.apoc then
		--
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
				local defpl = make_plural(lemma, "f", args.sp)
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
				f = make_feminine(lemma, args.sp)
			elseif f == "#" then
				f = lemma
			end
			table.insert(feminines, {term = f, qualifiers = fetch_qualifiers(args.f_qual[i])})
		end

		local argsmpl = args.mpl
		local argsfpl = args.fpl
		if #args.pl > 0 then
			if #argsmpl > 0 or #argsfpl > 0 then
				error("Can't specify both pl= and mpl=/fpl=")
			end
			argsmpl = args.pl
			argsfpl = args.pl
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
				local defpl = make_plural(lemma, "m", args.sp)
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
					local defpl = make_plural(f.term, "f", args.sp)
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

		-- Make sure there are feminines given and not same as lemma.
		if not (#feminines == 1 and feminines[1].term == lemma and not feminines[1].qualifiers) then
			insert_inflection(feminines, "feminine", "f|s")
		end

		if #masculine_plurals > 0 and #feminine_plurals > 0 and
			m_table.deepEquals(masculine_plurals, feminine_plurals) then
			insert_inflection(masculine_plurals, "plural", "p")
		else
			insert_inflection(masculine_plurals, "masculine plural", "m|p")
			insert_inflection(feminine_plurals, "feminine plural", "f|p")
		end
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
		["apoc"] = {type = "boolean"}, --apocopated
		["sp"] = {}, -- special indicator: "first", "first-last", etc.
		["f"] = {list = true}, --feminine form(s)
		["f_qual"] = {list = "f=_qual", allow_holes = true},
		["pl"] = {list = true}, --plural override(s)
		["pl_qual"] = {list = "pl=_qual", allow_holes = true},
		["fpl"] = {list = true}, --feminine plural override(s)
		["fpl_qual"] = {list = "fpl=_qual", allow_holes = true},
		["mpl"] = {list = true}, --masculine plural override(s)
		["mpl_qual"] = {list = "mpl=_qual", allow_holes = true},
	}
	if adjtype == "base" or adjtype == "part" or adjtype == "det" then
		params["comp"] = {list = true} --comparative(s)
		params["comp_qual"] = {list = "comp=_qual", allow_holes = true}
		params["sup"] = {list = true} --superlative(s)
		params["sup_qual"] = {list = "sup=_qual", allow_holes = true}
		params["fonly"] = {type = "boolean"} -- feminine only
	end
	if adjtype == "sup" then
		params["irreg"] = {type = "boolean"}
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

pos_functions["cardinal adjectives"] = {
	params = get_adjective_params("card"),
	func = function(args, data, tracking_categories)
		do_adjective(args, data, tracking_categories, "numeral")
		table.insert(data.categories, 1, langname .. " cardinal numbers")
	end,
}

pos_functions["past participles"] = {
	params = get_adjective_params("part"),
	func = function(args, data, tracking_categories)
		do_adjective(args, data, tracking_categories, "participle")
		data.pos_category = "past participles"
	end,
}

pos_functions["present participles"] = {
	params = get_adjective_params("part"),
	func = function(args, data, tracking_categories)
		do_adjective(args, data, tracking_categories, "participle")
		data.pos_category = "present participles"
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

pos_functions["cardinal invariable"] = {
	params = {
		["apoc"] = {type = "boolean"},
	},
	func = function(args, data, tracking_categories)
		data.pos_category = "numerals"
		table.insert(data.categories, langname .. " cardinal numbers")
		table.insert(data.categories, langname .. " indeclinable numerals")
		table.insert(data.inflections, {label = glossary_link("invariable")})
		if args.apoc then
			table.insert(data.inflections, {label = glossary_link("apocopated")})
			data.pos_category = "numeral forms"
		end
	end,
}

pos_functions["adverbs"] = {
	params = {
		["comp"] = {list = true}, --comparative(s)
		["comp_qual"] = {list = "comp=_qual", allow_holes = true},
		["sup"] = {list = true}, --superlative(s)
		["sup_qual"] = {list = "sup=_qual", allow_holes = true},
	},
	func = function(args, data, tracking_categories)
		if args.comp and #args.comp > 0 then
			local comps = process_terms_with_qualifiers(args.comp, args.comp_qual)
			check_all_missing(comps, "adverbs", tracking_categories)
			comps.label = "comparative"
			table.insert(data.inflections, comps)
		end

		if args.sup and #args.sup > 0 then
			local sups = process_terms_with_qualifiers(args.sup, args.sup_qual)
			check_all_missing(sups, "adverbs", tracking_categories)
			sups.label = "superlative"
			table.insert(data.inflections, sups)
		end
	end,
}


pos_functions["verbs"] = {
	params = {
		[1] = {},
		["noautolinktext"] = {type = "boolean"},
		["noautolinkverb"] = {type = "boolean"},
	},
	func = function(args, data, tracking_categories, frame)
		if args[1] then
			local preses, prets, parts
			local pagename = args.pagename or PAGENAME
			local def_forms

			local parargs = frame:getParent().args
			local alternant_multiword_spec = require("Module:it-verb").do_generate_forms(parargs, "from headword")

			local function expand_footnotes_and_references(footnotes)
				if not footnotes then
					return nil
				end
				local quals, refs
				for _, qualifier in ipairs(footnotes) do
					local this_footnote, this_refs =
						require("Module:inflection utilities").expand_footnote_or_references(qualifier, "return raw")
					if this_refs then
						if not refs then
							refs = this_refs
						else
							for _, ref in ipairs(this_refs) do
								table.insert(refs, ref)
							end
						end
					else
						if not quals then
							quals = {this_footnote}
						else
							table.insert(quals, this_footnote)
						end
					end
				end
				return quals, refs
			end

			local function do_verb_form(slot, label, rowslot, rowlabel)
				local forms = alternant_multiword_spec.forms[slot]
				local retval
				if rowslot and not alternant_multiword_spec.row_has_forms[rowslot] then
					if not alternant_multiword_spec.row_is_defective[rowslot] then
						-- No forms, but none expected; don't display anything
						return
					end
					retval = {label = "no " .. rowlabel}
				elseif not forms then
					retval = {label = "no " .. label}
				else
					-- Disable accelerators for now because we don't want the added accents going into the headwords.
					-- FIXME: We now have support in [[Module:accel]] to specify the target explicitly; we can use this
					-- so we can add the accelerators back with a param to avoid the accents.
					local accel_form = nil -- all_verb_slots[slot]
					retval = {label = label, accel = accel_form and {form = accel_form} or nil}
					local prev_footnotes = nil
					-- If the footnotes for this form are the same as the footnotes for the preceding form or
					-- contain the preceding footnotes, replace the footnotes that are the same with "ditto".
					-- This avoids repetition on pages like [[succedere]] where the form ''succedétti'' has a long
					-- footnote which gets repeated in the traditional form ''succedètti'' (which also has the
					-- footnote "[traditional]").
					for _, form in ipairs(forms) do
						local quals, refs = expand_footnotes_and_references(form.footnotes)
						local quals_with_ditto = quals
						if quals and prev_footnotes then
							local quals_contains_previous = true
							for _, qual in ipairs(prev_footnotes) do
								if not m_table.contains(quals, qual) then
									quals_contains_previous = false
									break
								end
							end
							if quals_contains_previous then
								local inserted_ditto = false
								quals_with_ditto = {}
								for _, qual in ipairs(quals) do
									if m_table.contains(prev_footnotes, qual) then
										if not inserted_ditto then
											table.insert(quals_with_ditto, "ditto")
											inserted_ditto = true
										end
									else
										table.insert(quals_with_ditto, qual)
									end
								end
							end
						end
						prev_footnotes = quals
						table.insert(retval, {term = form.form, qualifiers = quals_with_ditto, refs = refs})
					end
				end

				table.insert(data.inflections, retval)
			end

			if alternant_multiword_spec.props.is_pronominal then
				table.insert(data.inflections, {label = glossary_link("pronominal")})
			end
			if alternant_multiword_spec.props.only3s then
				table.insert(data.inflections, {label = glossary_link("impersonal")})
			end
			if alternant_multiword_spec.props.only3sp then
				table.insert(data.inflections, {label = "third-person only"})
			end
			
			local thirdonly = alternant_multiword_spec.props.only3s or alternant_multiword_spec.props.only3sp
			local sing_label = thirdonly and "third-person singular" or "first-person singular"
			for _, rowspec in ipairs {
				{"pres", "present", true},
				{"phis", "past historic", true},
				{"pp", "past participle", true},
				{"imperf", "imperfect"},
				{"fut", "future"},
				{"sub", "subjunctive"},
				{"impsub", "imperfect subjunctive"},
			} do
				local rowslot, desc, always_show = unpack(rowspec)
				local slot = rowslot .. (thirdonly and "3s" or "1s")
				local must_show = alternant_multiword_spec.is_irreg[slot]
				if always_show then
					must_show = true
				elseif rowslot == "imperf" and alternant_multiword_spec.props.has_explicit_stem_spec then
					-- If there is an explicit stem spec, make sure it gets displayed; the imperfect is a good way of
					-- showing this.
					must_show = true
				elseif not alternant_multiword_spec.forms[slot] then
					-- If the principal part is unexpectedly missing, make sure we show this.
					must_show = true
				end
				if must_show then
					if rowslot == "pp" then
						do_verb_form(rowslot, desc, rowslot, desc)
					else
						do_verb_form(slot, sing_label .. " " .. desc, rowslot, desc)
					end
				end
			end
			-- Also do the imperative, but not for third-only verbs, which are always missing the imperative.
			if not thirdonly and (alternant_multiword_spec.is_irreg.imp2s
				or not alternant_multiword_spec.forms.imp2s) then
				do_verb_form("imp2s", "second-person singular imperative", "imp", "imperative")
			end
			-- If there is a past participle but no auxiliary (e.g. [[malfare]]), explicitly add "no auxiliary". In
			-- cases where there's no past participle and no auxiliary (e.g. [[irrompere]]), we don't do this as we
			-- already get "no past participle" displayed. Don't display an auxiliary in any case if the lemma
			-- consists entirely of reflexive verbs (for which the auxiliary is always [[essere]]).
			if alternant_multiword_spec.props.is_non_reflexive and (
				alternant_multiword_spec.forms.aux or alternant_multiword_spec.forms.pp 
			) then
				do_verb_form("aux", "auxiliary")
			end

			-- Add categories.
			for _, cat in ipairs(alternant_multiword_spec.categories) do
				table.insert(data.categories, cat)
			end

			-- Use the "linked" form of the lemma as the head if no head= explicitly given.
			if #data.user_specified_heads == 0 then
				data.heads = {}
				for _, lemma_obj in ipairs(alternant_multiword_spec.forms.inf) do
					-- FIXME, can't yet specify qualifiers or references for heads
					table.insert(data.heads, lemma_obj.form)
					-- local quals, refs = expand_footnotes_and_references(lemma_obj.footnotes)
					-- table.insert(data.heads, {term = lemma_obj.form, qualifiers = quals, refs = refs})
				end
			end
		end
	end
}

return export
