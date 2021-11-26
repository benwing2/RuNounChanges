-- This module contains code for Italian headword templates.
-- Templates covered are:
-- * {{it-noun}}, {{it-proper noun}};
-- * {{it-verb}};
-- * {{it-adj}}, {{it-adj-comp}}, {{it-adj-sup}};
-- * {{it-det}};
-- * {{it-pron-adj}};
-- * {{it-pp}};
-- * {{it-card-noun}}, {{it-card-adj}}, {{it-card-inv}};
-- * {{it-adv}}.
-- See [[Module:it-conj]] for Italian conjugation templates.
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
local TEMP_QU = u(0xFFF1)
local TEMP_GU = u(0xFFF2)
local TEMP_U_IN_AU = u(0xFFF3)
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

local function process_comp_sup(compsup, quals)
	local infls = {}
	for i, cs in ipairs(compsup) do
		table.insert(infls, {term = cs, qualifiers = fetch_qualifiers(quals[i])})
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
		local comps = process_comp_sup(args.comp, args.comp_qual)
		check_all_missing(comps, plpos, tracking_categories)
		comps.label = "comparative"
		table.insert(data.inflections, comps)
	end

	if args.sup and #args.sup > 0 then
		local sups = process_comp_sup(args.sup, args.sup_qual)
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
			local comps = process_comp_sup(args.comp, args.comp_qual)
			check_all_missing(comps, "adverbs", tracking_categories)
			comps.label = "comparative"
			table.insert(data.inflections, comps)
		end

		if args.sup and #args.sup > 0 then
			local sups = process_comp_sup(args.sup, args.sup_qual)
			check_all_missing(sups, "adverbs", tracking_categories)
			sups.label = "superlative"
			table.insert(data.inflections, sups)
		end
	end,
}


local function analyze_verb(lemma)
	local is_pronominal = false
	local is_reflexive = false
	-- The particles that can go after a verb are:
	-- * la, le
	-- * ne
	-- * ci, vi (sometimes in the form ce, ve)
	-- * si (sometimes in the form se)
	-- Observed combinations:
	--   * ce + la: [[avercela]] "to be angry (at someone)", [[farcela]] "to make it, to succeed",
	--              [[mettercela tutta]] "to put everything (into something)"
	--   * se + la: [[sbrigarsela]] "to deal with", [[bersela]] "to naively believe in",
	--              [[sentirsela]] "to have the courage to face (a difficult situation)",
	--              [[spassarsela]] "to live it up", [[svignarsela]] "to scurry away",
	--              [[squagliarsela]] "to vamoose, to clear off", [[cercarsela]] "to be looking for (trouble etc.)",
	--              [[contarsela]] "to have a distortedly positive self-image; to chat at length",
	--              [[dormirsela]] "to be fast asleep", [[filarsela]] "to slip away, to scram",
	--              [[giostrarsela]] "to get away with; to turn a situation to one's advantage",
	--              [[cavarsela]] "to get away with; to get out of (trouble); to make the best of; to manage (to do); to be good at",
	--              [[meritarsela]] "to get one's comeuppance", [[passarsela]] "to fare (well, badly)",
	--              [[rifarsela]] "to take revenge", [[sbirbarsela]] "to slide by (in life)",
	--              [[farsela]]/[[intendersela]] "to have a secret affair or relationship with",
	--              [[farsela addosso]] "to shit oneself", [[prendersela]] "to take offense at; to blame",
	--              [[prendersela comoda]] "to take one's time", [[sbrigarsela]] "to finish up; to get out of (a difficult situation)",
	--              [[tirarsela]] "to lord it over", [[godersela]] "to enjoy", [[vedersela]] "to see (something) through",
	--              [[vedersela brutta]] "to have a hard time with; to be in a bad situation",
	--              [[aversela]] "to pick on (someone)", [[battersela]] "to run away, to sneak away",
	--              [[darsela a gambe]] "to run away", [[fumarsela]] "to sneak away",
	--              [[giocarsela]] "to behave (a certain way); to strategize; to play"
	--   * se + ne: [[andarsene]] "to take leave", [[approfittarsene]] "to take advantage of",
	--              [[fottersene]]/[[strafottersene]] "to not give a fuck",
	--              [[fregarsene]]/[[strafregarsene]] "to not give a damn",
	--              [[guardarsene]] "to beware; to think twice", [[impiparsene]] "to not give a damn",
	--              [[morirsene]] "to fade away; to die a lingering death", [[ridersene]] "to laugh at; to not give a damn",
	--              [[ritornarsene]] "to return to", [[sbattersene]]/[[strabattersene]] "to not give a damn",
	--              [[infischiarsene]] "to not give a damn", [[stropicciarsene]] "to not give a damn",
	--              [[sbarazzarsene]] "to get rid of, to bump off", [[andarsene in acqua]] "to be diluted; to decay",
	--              [[nutrirsene]] "to feed oneself", [[curarsene]] "to take care of",
	--              [[intendersene]] "to be an expert (in)", [[tornarsene]] "to return, to go back",
	--              [[starsene]] "to stay", [[farsene]] "to matter; to (not) consider; to use",
	--              [[farsene una ragione]] "to resign; to give up; to come to terms with; to settle (a dispute)",
	--              [[riuscirsene]] "to repeat (something annoying)", [[venirsene]] "to arrive slowly; to leave"
	--   * ci + si: [[trovarcisi]] "to find oneself in a happy situation",
	--              [[vedercisi]] "to imagine oneself (in a situation)", [[sentircisi]] "to feel at ease"
	--   * vi + si: [[recarvisi]] "to go there"
	--
	local ret = {}
	local linked_suf, finite_pref, finite_pref_ho
	local clitic_to_finite = {ce = "ce", ve = "ve", se = "me"}
	local verb, clitic, clitic2 = rmatch(lemma, "^(.-)([cvs]e)(l[ae])$")
	if verb then
		linked_suf = "[[" .. clitic .. "]][[" .. clitic2 .. "]]"
		finite_pref = "[[" .. clitic_to_finite[clitic] .. "]] [[" .. clitic2 .. "]] "
		finite_pref_ho = "[[" .. clitic_to_finite[clitic] .. "]] [[l']]"
		is_pronominal = true
		is_reflexive = clitic == "se"
	end
	if not verb then
		verb, clitic = rmatch(lemma, "^(.-)([cvs]e)ne$")
		if verb then
			linked_suf = "[[" .. clitic .. "]][[ne]]"
			finite_pref = "[[" .. clitic_to_finite[clitic] .. "]] [[ne]] "
			finite_pref_ho = "[[" .. clitic_to_finite[clitic] .. "]] [[n']]"
			is_pronominal = true
			is_reflexive = clitic == "se"
		end
	end
	if not verb then
		verb, clitic = rmatch(lemma, "^(.-)([cv]i)si$")
		if verb then
			linked_suf = "[[" .. clitic .. "]][[si]]"
			finite_pref = "[[mi]] [[" .. clitic .. "]] "
			if clitic == "vi" then
				finite_pref_ho = "[[mi]] [[v']]"
			else
				finite_pref_ho = "[[mi]] [[ci]] "
			end
			is_pronominal = true
			is_reflexive = true
		end
	end
	if not verb then
		verb, clitic = rmatch(lemma, "^(.-)([cv]i)$")
		if verb then
			linked_suf = "[[" .. clitic .. "]]"
			finite_pref = "[[" .. clitic .. "]] "
			if clitic == "vi" then
				finite_pref_ho = "[[v']]"
			else
				finite_pref_ho = "[[ci]] "
			end
			is_pronominal = true
		end
	end
	if not verb then
		verb = rmatch(lemma, "^(.-)si$")
		if verb then
			linked_suf = "[[si]]"
			finite_pref = "[[mi]] "
			finite_pref_ho = "[[m']]"
			-- not pronominal
			is_reflexive = true
		end
	end
	if not verb then
		verb = rmatch(lemma, "^(.-)ne$")
		if verb then
			linked_suf = "[[ne]]"
			finite_pref = "[[ne]] "
			finite_pref_ho = "[[n']]"
			is_pronominal = true
		end
	end
	if not verb then
		verb, clitic = rmatch(lemma, "^(.-)(l[ae])$")
		if verb then
			linked_suf = "[[" .. clitic .. "]]"
			finite_pref = "[[" .. clitic .. "]] "
			finite_pref_ho = "[[l']]"
			is_pronominal = true
		end
	end
	if not verb then
		verb = lemma
		linked_suf = ""
		finite_pref = ""
		finite_pref_ho = ""
		-- not pronominal
	end

	ret.raw_verb = verb
	ret.linked_suf = linked_suf
	ret.finite_pref = finite_pref
	ret.finite_pref_ho = finite_pref_ho
	ret.is_pronominal = is_pronominal
	ret.is_reflexive = is_reflexive
	return ret
end

local function add_default_verb_forms(base)
	local ret = base.verb
	local raw_verb = ret.raw_verb
	local stem, conj_vowel = rmatch(raw_verb, "^(.-)([aeiour])re?$")
	if not stem then
		error("Unrecognized verb '" .. raw_verb .. "', doesn't end in -are, -ere, -ire, -rre, -ar, -er, -ir, -or or -ur")
	end
	if rfind(raw_verb, "r$") then
		if rfind(raw_verb, "[ou]r$") or base.rre then
			ret.verb = raw_verb .. "re"
		else
			ret.verb = raw_verb .. "e"
		end
	else
		ret.verb = raw_verb
	end

	if not rfind(conj_vowel, "^[aei]$") then
		-- Can't generate defaults for verbs in -rre
		return
	end

	if base.third then
		ret.pres = conj_vowel == "a" and stem .. "a" or stem .. "e"
	else
		ret.pres = stem .. "o"
	end
	if conj_vowel == "i" then
		ret.isc_pres = stem .. "ìsco"
	end
	if conj_vowel == "a" then
		ret.past = stem .. (base.third and "ò" or "ài")
	elseif conj_vowel == "e" then
		ret.past = {stem .. (base.third and "é" or "éi"), stem .. (base.third and "ètte" or "ètti")}
	else
		ret.past = stem .. (base.third and "ì" or "ìi")
	end
	if conj_vowel == "a" then
		ret.pp = stem .. "àto"
	elseif conj_vowel == "e" then
		ret.pp = rfind(stem, "[cg]$") and stem .. "iùto" or stem .. "ùto"
	else
		ret.pp = stem .. "ìto"
	end
end

-- Add links around words. If multiword_only, do it only in multiword forms.
local function add_links(form, multiword_only)
	if form == "" or form == " " then
		return form
	end
	if not form:find("%[%[") then
		if rfind(form, "[%s%p]") then --optimization to avoid loading [[Module:headword]] on single-word forms
			local m_headword = require("Module:headword")
			if m_headword.head_is_multiword(form) then
				form = m_headword.add_multiword_links(form)
			end
		end
		if not multiword_only and not form:find("%[%[") then
			form = "[[" .. form .. "]]"
		end
	end
	return form
end

local function strip_spaces(text)
	return text:gsub("^%s*(.-)%s*", "%1")
end

local function check_not_null(base, form)
	if form == nil then
		error("Default forms cannot be derived from '" .. base.lemma .. "'")
	end
end

-- Given an unaccented stem, pull out the last two vowels as well as the in-between stuff, and return
-- before, v1, between, v2, after as 5 return values. You must undo the TEMP_QU, TEMP_GU and TEMP_U_IN_AU
-- substitutions made in before/between/after if you want to use them. `unaccented` is the full verb and
-- `unaccented_desc` a description of where the verb came from; used only in error messages.
local function analyze_stem_for_last_two_vowels(unaccented_stem, unaccented, unaccented_desc)
	unaccented_stem = rsub(unaccented_stem, "qu", TEMP_QU)
	unaccented_stem = rsub(unaccented_stem, "gu(" .. V .. ")", TEMP_GU .. "%1")
	unaccented_stem = rsub(unaccented_stem, "au(" .. NV .. "*" .. V .. NV .. "*)$", "a" .. TEMP_U_IN_AU .. "%1")
	local before, v1, between, v2, after = rmatch(unaccented_stem, "^(.*)(" .. V .. ")(" .. NV .. "*)(" .. V .. ")(" .. NV .. "*)$")
	if not before then
		before, v1 = "", ""
		between, v2, after = rmatch(unaccented_stem, "^(.*)(" .. V .. ")(" .. NV .. "*)$")
	end
	if not between then
		error("No vowel in " .. unaccented_desc .. " '" .. unaccented .. "' to match")
	end
	return before, v1, between, v2, after
end

-- Apply a single-vowel spec in `form`, e.g. é+, to `unaccented_stem`. `unaccented` is the full verb and
-- `unaccented_desc` a description of where the verb came from; used only in error messages.
local function apply_vowel_spec(unaccented_stem, unaccented, unaccented_desc, form)
	local before, v1, between, v2, after = analyze_stem_for_last_two_vowels(unaccented_stem, unaccented, unaccented_desc)
	if v1 == v2 then
		local form_vowel, first_second = rmatch(form, "^(.)([+-])$")
		if not form_vowel then
			error("Last two stem vowels of " .. unaccented_desc .. " '" .. unaccented ..
				"' are the same; you must specify + (second vowel) or - (first vowel) after the vowel spec '" ..
				form .. "'")
		end
		local raw_form_vowel = usub(unfd(form_vowel), 1, 1)
		if raw_form_vowel ~= v1 then
			error("Vowel spec '" .. form .. "' doesn't match vowel of " .. unaccented_desc .. " '" .. unaccented .. "'")
		end
		if first_second == "-" then
			form = before .. form_vowel .. between .. v2 .. after
		else
			form = before .. v1 .. between .. form_vowel .. after
		end
	else
		if rfind(form, "[+-]$") then
			error("Last two stem vowels of " .. unaccented_desc .. " '" .. unaccented ..
				"' are different; specify just an accented vowel, without a following + or -: '" .. form .. "'")
		end
		local raw_form_vowel = usub(unfd(form), 1, 1)
		if raw_form_vowel == v1 then
			form = before .. form .. between .. v2 .. after
		elseif raw_form_vowel == v2 then
			form = before .. v1 .. between .. form .. after
		elseif before == "" then
			error("Vowel spec '" .. form .. "' doesn't match vowel of " .. unaccented_desc .. " '" .. unaccented .. "'")
		else
			error("Vowel spec '" .. form .. "' doesn't match either of the last two vowels of " .. unaccented_desc ..
				" '" .. unaccented .. "'")
		end
	end
	form = rsub(form, TEMP_QU, "qu")
	form = rsub(form, TEMP_GU, "gu")
	form = rsub(form, TEMP_U_IN_AU, "u")
	return form
end

local function do_ending_stressed_inf(iut, base)
	if rfind(base.verb.verb, "rre$") then
		error("Use \\ not / with -rre verbs")
	end
	-- Add acute accent to -ere, grave accent to -are/-ire.
	local accented = rsub(base.verb.verb, "ere$", "ére")
	accented = unfc(rsub(accented, "([ai])re$", "%1" .. GR .. "re"))
	-- If there is a clitic suffix like -la or -sene, truncate final -e.
	if base.verb.linked_suf ~= "" then
		accented = rsub(accented, "e$", "")
	end
	local linked = "[[" .. base.verb.verb .. "|" .. accented .. "]]" .. base.verb.linked_suf
	iut.insert_form(base.forms, "lemma_linked", {form = linked})
end

local function do_root_stressed_inf(iut, base, specs)
	for _, spec in ipairs(specs) do
		if spec.form == "-" then
			error("Spec '-' not allowed as root-stressed infinitive spec")
		end
		local this_specs
		if spec.form == "+" then
			-- do_root_stressed_inf is used for verbs in -ere and -rre. If the root-stressed vowel isn't explicitly
			-- given and the verb ends in -arre, -irre or -urre, derive it from the infinitive since there's only
			-- one possibility.. If the verb ends in -erre or -orre, this won't work because we have both
			-- scérre (= [[scegliere]]) and disvèrre (= [[disvellere]]), as well as pórre and tòrre (= [[togliere]]).
			local rre_vowel = rmatch(base.verb.verb, "([aiu])rre$")
			if rre_vowel then
				local before, v1, between, v2, after = analyze_stem_for_last_two_vowels(
					rsub(base.verb.verb, "re$", ""), base.verb.verb, "root-stressed infinitive")
				local vowel_spec = unfc(rre_vowel .. GR)
				if v1 == v2 then
					vowel_spec = vowel_spec .. "+"
				end
				this_specs = {{form = vowel_spec}}
			else
				-- Combine current footnotes into present-tense footnotes.
				this_specs = iut.convert_to_general_list_form(base.pres, spec.footnotes)
				for _, this_spec in ipairs(this_specs) do
					if not rfind(this_spec.form, "^" .. AV .. "[+-]?$") then
						error("When defaulting root-stressed infinitive vowel to present, present spec must be a single-vowel spec, but saw '"
							.. this_spec.form .. "'")
					end
				end
			end
		else
			this_specs = {spec}
		end
		local verb_stem, verb_suffix = rmatch(base.verb.verb, "^(.-)([er]re)$")
		if not verb_stem then
			error("Verb '" .. base.verb.verb .. "' must end in -ere or -rre to use \\ notation")
		end
		-- If there is a clitic suffix like -la or -sene, truncate final -(r)e.
		if base.verb.linked_suf ~= "" then
			verb_suffix = verb_suffix == "ere" and "er" or "r"
		end
		for _, this_spec in ipairs(this_specs) do
			if not rfind(this_spec.form, "^" .. AV .. "[+-]?$") then
				error("Explicit root-stressed infinitive spec '" .. this_spec.form .. "' should be a single-vowel spec")
			end

			local expanded = apply_vowel_spec(verb_stem, base.verb.verb, "root-stressed infinitive", this_spec.form) ..
				verb_suffix
			local linked = "[[" .. base.verb.verb .. "|" .. expanded .. "]]" .. base.verb.linked_suf
			iut.insert_form(base.forms, "lemma_linked", {form = linked, footnotes = this_spec.footnotes})
		end
	end
end

local function pres_special_case(base, form)
	if form == "+" then
		check_not_null(base, base.verb.pres)
		return base.verb.pres
	elseif form == "+isc" then
		check_not_null(base, base.verb.isc_pres)
		return base.verb.isc_pres
	elseif form == "-" then
		return form
	elseif rfind(form, "^" .. AV .. "[+-]?$") then
		check_not_null(base, base.verb.pres)
		local pres, final_vowel = rmatch(base.verb.pres, "^(.*)([oae])$")
		if not pres then
			error("Internal error: Default present '" .. base.verb.pres .. "' doesn't end in -o, -a or -e")
		end
		return apply_vowel_spec(pres, base.verb.pres, "default present", form) .. final_vowel
	elseif not base.third and not rfind(form, "[oò]$") then
		error("Present first-person singular form '" .. form .. "' should end in -o")
	elseif base.third and not rfind(form, "[aàeè]") then
		error("Present third-person singular form '" .. form .. "' should end in -a or -e")
	else
		return form
	end
end

local function past_special_case(base, form)
	if form == "+" then
		check_not_null(base, base.verb.past)
		return base.verb.past
	elseif form ~= "-" and not base.third and not rfind(form, "i$") then
		error("Past historic form '" .. form .. "' should end in -i")
	else
		return form
	end
end

local function pp_special_case(base, form)
	if form == "+" then
		check_not_null(base, base.verb.pp)
		return base.verb.pp
	elseif form ~= "-" and not rfind(form, "o$") then
		error("Past participle form '" .. form .. "' should end in -o")
	else
		return form
	end
end

local irreg_forms = { "imperf", "fut", "sub", "impsub", "imp" }

pos_functions["verbs"] = {
	params = {
		[1] = {},
		["noautolinktext"] = {type = "boolean"},
		["noautolinkverb"] = {type = "boolean"},
	},
	func = function(args, data, tracking_categories, frame)
		if args[1] then
			local iut = require("Module:inflection utilities")

			local arg1 = args[1]
			local need_surrounding_angle_brackets = true
			-- Check whether we need to add <...> around the argument. If the
			-- argument has no < in it, we definitely do. Otherwise, we need to
			-- parse the balanced [...] and <...> and add <...> only if there isn't
			-- a top-level <...>. We check for [...] because there might be angle
			-- brackets inside of them (HTML tags in qualifiers or <<name:...>> and
			-- such in references).
			if arg1:find("<") then
				local segments = iut.parse_multi_delimiter_balanced_segment_run(arg1,
					{{"<", ">"}, {"[", "]"}})
				for i = 2, #segments, 2 do
					if segments[i]:find("^<.*>$") then
						need_surrounding_angle_brackets = false
						break
					end
				end
			end
			if need_surrounding_angle_brackets then
				arg1 = "<" .. arg1 .. ">"
			end

			-- (1) Parse the indicator specs inside of angle brackets.

			local function parse_indicator_spec(angle_bracket_spec, lemma)
				local base = {forms = {}, irreg_forms = {}}
				local function parse_err(msg)
					error(msg .. ": " .. angle_bracket_spec)
				end

				local function parse_qualifiers(separated_group)
					local qualifiers
					for j = 2, #separated_group - 1, 2 do
						if separated_group[j + 1] ~= "" then
							parse_err("Extraneous text after bracketed qualifiers: '" .. table.concat(separated_group) .. "'")
						end
						if not qualifiers then
							qualifiers = {}
						end
						table.insert(qualifiers, separated_group[j])
					end
					return qualifiers
				end

				local function fetch_specs(comma_separated_group, allow_blank)
					local colon_separated_groups = iut.split_alternating_runs(comma_separated_group, ":")
					if allow_blank and #colon_separated_groups == 1 and #colon_separated_groups[1] == 1 and
						colon_separated_groups[1][1] == "" then
						return nil
					end
					local specs = {}
					for _, colon_separated_group in ipairs(colon_separated_groups) do
						local form = colon_separated_group[1]
						if form == "" then
							parse_err("Blank form not allowed here, but saw '" ..
								table.concat(comma_separated_group) .. "'")
						end
						local new_spec = {form = form, footnotes = parse_qualifiers(colon_separated_group)}
						for _, existing_spec in ipairs(specs) do
							if m_table.deepEquals(existing_spec, new_spec) then
								parse_err("Duplicate spec '" .. table.concat(colon_separated_group) .. "'")
							end
						end
						table.insert(specs, new_spec)
					end
					return specs
				end

				if lemma == "" then
					lemma = data.pagename
				end
				base.lemma = m_links.remove_links(lemma)
				base.verb = analyze_verb(lemma)

				local inside = angle_bracket_spec:match("^<(.*)>$")
				assert(inside)

				local segments = iut.parse_balanced_segment_run(inside, "[", "]")
				local dot_separated_groups = iut.split_alternating_runs(segments, "%s*%.%s*")
				for i, dot_separated_group in ipairs(dot_separated_groups) do
					local first_element = dot_separated_group[1]
					if first_element == "only3s" or first_element == "only3sp" or first_element == "rre" then
						if #dot_separated_group > 1 then
							parse_err("No footnotes allowed with '" .. first_element .. "' spec")
						end
						base[first_element] = true
					else
						local saw_irreg = false
						for _, irreg_form in ipairs(irreg_forms) do
							local first_element_minus_prefix = rmatch(first_element, "^" .. irreg_form .. ":(.*)$")
							if first_element_minus_prefix then
								dot_separated_group[1] = first_element_minus_prefix
								base.irreg_forms[irreg_form] = fetch_specs(dot_separated_group)
								saw_irreg = true
								break
							end
						end
						if not saw_irreg then
							local comma_separated_groups = iut.split_alternating_runs(dot_separated_group, "%s*[,\\/]%s*", "preserve splitchar")
							local presind = 1
							local first_separator = #comma_separated_groups > 1 and
								strip_spaces(comma_separated_groups[2][1])
							if base.verb.is_reflexive then
								if #comma_separated_groups > 1 and first_separator ~= "," then
									presind = 3
									-- Fetch root-stressed infinitive, if given.
									local specs = fetch_specs(comma_separated_groups[1], "allow blank")
									if first_separator == "\\" then
										-- For verbs like [[scegliersi]] and [[proporsi]], allow either 'é\scélgo' or '\é\scélgo'
										-- and similarly either 'ó+\propóngo' or '\ó+\propóngo'.
										if specs == nil then
											if #comma_separated_groups > 3 and strip_spaces(comma_separated_groups[4][1]) == "\\" then
												base.root_stressed_inf = fetch_specs(comma_separated_groups[3])
												presind = 5
											else
												base.root_stressed_inf = {{form = "+"}}
											end
										else
											base.root_stressed_inf = specs
										end
									elseif specs ~= nil then
										parse_err("With reflexive verb, can't specify anything before initial slash, but saw '"
											.. table.concat(comma_separated_groups[1]))
									end
								end
								base.aux = {{form = "essere"}}
							else -- non-reflexive
								if #comma_separated_groups == 1 or first_separator == "," then
									parse_err("With non-reflexive verb, use a spec like AUX/PRES, AUX\\PRES, AUX/PRES,PAST,PP or similar")
								end
								presind = 3
								-- Fetch auxiliary or auxiliaries.
								local colon_separated_groups = iut.split_alternating_runs(comma_separated_groups[1], ":")
								for _, colon_separated_group in ipairs(colon_separated_groups) do
									local aux = colon_separated_group[1]
									if aux == "a" then
										aux = "avere"
									elseif aux == "e" then
										aux = "essere"
									elseif aux == "-" then
										if #colon_separated_group > 1 then
											parse_err("No footnotes allowed with '-' spec for auxiliary")
										end
										aux = nil
									else
										parse_err("Unrecognized auxiliary '" .. aux ..
											"', should be 'a' (for [[avere]]), 'e' (for [[essere]]), or '-' if no past participle")
									end
									if aux then
										if base.aux then
											for _, existing_aux in ipairs(base.aux) do
												if existing_aux.form == aux then
													parse_err("Auxiliary '" .. aux .. "' specified twice")
												end
											end
										else
											base.aux = {}
										end
										table.insert(base.aux, {form = aux, footnotes = parse_qualifiers(colon_separated_group)})
									end
								end

								-- Fetch root-stressed infinitive, if given.
								if first_separator == "\\" then
									if #comma_separated_groups > 3 and strip_spaces(comma_separated_groups[4][1]) == "\\" then
										base.root_stressed_inf = fetch_specs(comma_separated_groups[3])
										presind = 5
									else
										base.root_stressed_inf = {{form = "+"}}
									end
								end
							end

							-- Parse present
							base.pres = fetch_specs(comma_separated_groups[presind])

							-- Parse past historic
							if #comma_separated_groups > presind then
								if strip_spaces(comma_separated_groups[presind + 1][1]) ~= "," then
									parse_err("Use a comma not slash to separate present from past historic")
								end
								base.past = fetch_specs(comma_separated_groups[presind + 2])
							end

							-- Parse past participle
							if #comma_separated_groups > presind + 2 then
								if strip_spaces(comma_separated_groups[presind + 3][1]) ~= "," then
									parse_err("Use a comma not slash to separate past historic from past participle")
								end
								base.pp = fetch_specs(comma_separated_groups[presind + 4])
							end

							if #comma_separated_groups > presind + 4 then
								parse_err("Extraneous text after past participle")
							end
						end
					end
				end
				return base
			end

			local parse_props = {
				parse_indicator_spec = parse_indicator_spec,
				allow_blank_lemma = true,
			}
			local alternant_multiword_spec = iut.parse_inflected_text(arg1, parse_props)

			-- (2) Add links to all before and after text.

			if not args.noautolinktext then
				alternant_multiword_spec.post_text = add_links(alternant_multiword_spec.post_text)
				for _, alternant_or_word_spec in ipairs(alternant_multiword_spec.alternant_or_word_specs) do
					alternant_or_word_spec.before_text = add_links(alternant_or_word_spec.before_text)
					if alternant_or_word_spec.alternants then
						for _, multiword_spec in ipairs(alternant_or_word_spec.alternants) do
							multiword_spec.post_text = add_links(multiword_spec.post_text)
							for _, word_spec in ipairs(multiword_spec.word_specs) do
								word_spec.before_text = add_links(word_spec.before_text)
							end
						end
					end
				end
			end

			-- (3) Do any global checks.

			iut.map_word_specs(alternant_multiword_spec, function(base)
				-- Handling of only3s and only3p.
				if base.only3s and base.only3sp then
					error("'only3s' and 'only3sp' cannot both be specified")
				end
				base.third = base.only3s or base.only3sp
				if alternant_multiword_spec.only3s == nil then
					alternant_multiword_spec.only3s = base.only3s
				elseif alternant_multiword_spec.only3s ~= base.only3s then
					error("If some alternants specify 'only3s', all must")
				end
				if alternant_multiword_spec.only3sp == nil then
					alternant_multiword_spec.only3sp = base.only3sp
				elseif alternant_multiword_spec.only3sp ~= base.only3sp then
					error("If some alternants specify 'only3sp', all must")
				end
				
				-- Check for missing past participle -> missing auxiliary.
				if not base.verb.is_reflexive then
					local pp_is_missing = base.pp and #base.pp == 1 and base.pp[1].form == "-"
					local aux_is_missing = not base.aux
					if pp_is_missing and not aux_is_missing then
						error("If past participle given as '-', auxiliary must be explicitly specified as '-'")
					end
				end
			end)
			alternant_multiword_spec.third = alternant_multiword_spec.only3s or alternant_multiword_spec.only3sp

			-- (4) Conjugate the verbs according to the indicator specs parsed above.

			local sing_accel = alternant_multiword_spec.third and "3|s" or "1|s"
			local sing_label = alternant_multiword_spec.third and "third-person singular" or "first-person singular"
			local all_verb_slots = {
				lemma = "infinitive",
				lemma_linked = "infinitive",
				pres_form = sing_accel .. "|pres|ind",
				past_form = sing_accel .. "|phis",
				pp_form = "m|s|past|part",
				imperf_form = sing_accel .. "|impf|ind",
				fut_form = sing_accel .. "|fut|ind",
				sub_form = sing_accel .. "|pres|sub",
				impsub_form = sing_accel .. "|impf|sub",
				imp_form = "2|s|imp",
				-- aux should not be here. It doesn't have an accelerator and isn't "conjugated" normally.
			}
			local all_verb_slot_labels = {
				lemma = "infinitive",
				lemma_linked = "infinitive",
				pres_form = sing_label .. " present",
				past_form = sing_label .. " past historic",
				pp_form = "past participle",
				imperf_form = sing_label .. " imperfect",
				fut_form = sing_label .. " future",
				sub_form = sing_label .. " present subjunctive",
				impsub_form = sing_label .. " imperfect subjunctive",
				imp_form = "second-person singular imperative",
				aux = "auxiliary",
			}

			local function conjugate_verb(base)
				add_default_verb_forms(base)
				if base.verb.is_pronominal then
					alternant_multiword_spec.is_pronominal = true
				end

				local function process_specs(slot, specs, is_finite, special_case)
					specs = specs or {{form = "+"}}
					for _, spec in ipairs(specs) do
						local decorated_form = spec.form
						local prespec, form, syntactic_gemination =
							rmatch(decorated_form, "^([*!#]*)(.-)(%**)$")
						local forms = special_case(base, form)
						forms = iut.convert_to_general_list_form(forms, spec.footnotes)
						for _, formobj in ipairs(forms) do
							local qualifiers = formobj.footnotes
							local form = formobj.form
							-- If the form is -, insert it directly, unlinked; we handle this specially
							-- below, turning it into special labels like "no past participle".
							if form ~= "-" then
								if prespec:find("!!") then
									qualifiers = iut.combine_footnotes({"[elevated style]"}, qualifiers)
									prespec = prespec:gsub("!!", "")
								end
								if prespec:find("!") then
									qualifiers = iut.combine_footnotes({"[careful style]"}, qualifiers)
									prespec = prespec:gsub("!", "")
								end
								if prespec:find("#") then
									qualifiers = iut.combine_footnotes({"[traditional]"}, qualifiers)
									prespec = prespec:gsub("#", "")
								end
								local preserve_monosyllabic_accent
								if prespec:find("%*") then
									preserve_monosyllabic_accent = true
									prespec = prespec:gsub("%*", "")
								end
								local unaccented_form
								if rfind(form, "^.*" .. V .. ".*" .. AV .. "$") then
									-- final accented vowel with preceding vowel; keep accent
									unaccented_form = form
								elseif rfind(form, AV .. "$") and preserve_monosyllabic_accent then
									unaccented_form = form
									qualifiers = iut.combine_footnotes(qualifiers, {"[with written accent]"})
								else
									unaccented_form = rsub(form, AV, function(v) return usub(unfd(v), 1, 1) end)
								end
								if syntactic_gemination == "*" then
									qualifiers = iut.combine_footnotes(qualifiers, {"[with following syntactic gemination]"})
								elseif syntactic_gemination == "**" then
									qualifiers = iut.combine_footnotes(qualifiers, {"[with optional following syntactic gemination]"})
								elseif syntactic_gemination ~= "" then
									error("Decorated form '" .. decorated_form .. "' has too many asterisks after it, use '*' for syntactic gemination and '**' for optional syntactic gemination")
								end
								form = "[[" .. unaccented_form .. "|" .. form .. "]]"
								if is_finite then
									if unaccented_form == "ho" then
										form = base.verb.finite_pref_ho .. form
									else
										form = base.verb.finite_pref .. form
									end
								end
							end
							iut.insert_form(base.forms, slot, {form = form, footnotes = qualifiers})
						end
					end
				end

				process_specs("pres_form", base.pres, "finite", pres_special_case)
				process_specs("past_form", base.past, "finite", past_special_case)
				process_specs("pp_form", base.pp, false, pp_special_case)

				local function irreg_special_case(base, form, def)
					return form
				end

				for _, irreg_form in ipairs(irreg_forms) do
					if base.irreg_forms[irreg_form] then
						process_specs(irreg_form .. "_form", base.irreg_forms[irreg_form], irreg_form ~= "imp",
							irreg_special_case)
					end
				end

				iut.insert_form(base.forms, "lemma", {form = base.lemma})
				-- Add linked version of lemma for use in head=.
				if base.root_stressed_inf then
					do_root_stressed_inf(iut, base, base.root_stressed_inf)
				else
					do_ending_stressed_inf(iut, base)
				end
			end

			local inflect_props = {
				slot_table = all_verb_slots,
				inflect_word_spec = conjugate_verb,
				-- We add links around the generated verbal forms rather than allow the entire multiword
				-- expression to be a link, so ensure that user-specified links get included as well.
				include_user_specified_links = true,
			}
			iut.inflect_multiword_or_alternant_multiword_spec(alternant_multiword_spec, inflect_props)

			-- Set the overall auxiliary or auxiliaries. We can't do this using the normal inflection
			-- code as it will produce e.g. '[[avere]] e [[avere]]' for conjoined verbs.
			iut.map_word_specs(alternant_multiword_spec, function(base)
				iut.insert_forms(alternant_multiword_spec.forms, "aux", base.aux)
			end)

			-- (5) Fetch the forms and put the conjugated lemmas in data.heads if not explicitly given.

			local function strip_brackets(qualifiers)
				if not qualifiers then
					return nil
				end
				local quals, refs
				for _, qualifier in ipairs(qualifiers) do
					local stripped_refs = qualifier:match("^%[ref:(.*)%]$")
					if stripped_refs then
						local parsed_refs = require("Module:references").parse_references(stripped_refs)
						if not refs then
							refs = parsed_refs
						else
							for _, ref in ipairs(parsed_refs) do
								table.insert(refs, ref)
							end
						end
					else
						local stripped_qualifier = qualifier:match("^%[(.*)%]$")
						if not stripped_qualifier then
							error("Internal error: Qualifier should be surrounded by brackets at this stage: " .. qualifier)
						end
						if not quals then
							quals = {stripped_qualifier}
						else
							table.insert(quals, stripped_qualifier)
						end
					end
				end
				return quals, refs
			end

			local function do_verb_form(slot, label)
				local forms = alternant_multiword_spec.forms[slot]
				if not forms or #forms == 0 then
					-- This will happen with unspecified irregular forms.
					return
				end

				-- Disable accelerators for now because we don't want the added accents going into the headwords.
				-- FIXME: Add support to [[Module:accel]] so we can add the accelerators back with a param to
				-- avoid the accents.
				local accel_form = nil -- all_verb_slots[slot]
				local label = all_verb_slot_labels[slot]
				local retval
				if forms[1].form == "-" then
					retval = {label = "no " .. label}
				else
					retval = {label = label, accel = accel_form and {form = accel_form} or nil}
					for _, form in ipairs(forms) do
						local quals, refs = strip_brackets(form.footnotes)
						table.insert(retval, {term = form.form, qualifiers = quals, refs = refs})
					end
				end
				table.insert(data.inflections, retval)
			end

			if alternant_multiword_spec.is_pronominal then
				table.insert(data.inflections, {label = glossary_link("pronominal")})
			end
			if alternant_multiword_spec.only3s then
				table.insert(data.inflections, {label = glossary_link("impersonal")})
			end
			if alternant_multiword_spec.only3sp then
				table.insert(data.inflections, {label = "third-person only"})
			end
			
			do_verb_form("pres_form")
			do_verb_form("past_form")
			do_verb_form("pp_form")
			for _, irreg_form in ipairs(irreg_forms) do
				do_verb_form(irreg_form .. "_form")
			end
			do_verb_form("aux")
			-- If there is a past participle but no auxiliary (e.g. [[malfare]]), explicitly add
			-- "no auxiliary". In cases where there's no past participle and no auxiliary (e.g.
			-- [[irrompere]]), we don't do this as we already get "no past participle" displayed.
			if not alternant_multiword_spec.forms.aux and alternant_multiword_spec.forms.pp_form[1].form ~= "-" then
				table.insert(data.inflections, {label = "no auxiliary"})
			end

			-- Add categories.
			if alternant_multiword_spec.forms.aux then
				for _, form in ipairs(alternant_multiword_spec.forms.aux) do
					table.insert(data.categories, langname .. " verbs taking " .. form.form .. " as auxiliary")
				end
			end
			if alternant_multiword_spec.is_pronominal then
				table.insert(data.categories, langname .. " pronominal verbs")
			end

			-- Use the "linked" form of the lemma as the head if no head= explicitly given.
			if #data.user_specified_heads == 0 then
				data.heads = {}
				for _, lemma_obj in ipairs(alternant_multiword_spec.forms.lemma_linked) do
					local lemma = lemma_obj.form
					-- FIXME, can't yet specify qualifiers or references for heads
					table.insert(data.heads, lemma_obj.form)
					-- local quals, refs = strip_brackets(lemma_obj.footnotes)
					-- table.insert(data.heads, {term = lemma_obj.form, qualifiers = quals, refs = refs})
				end
			end
		end
	end
}

return export
