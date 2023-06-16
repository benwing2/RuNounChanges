local export = {}
local pos_functions = {}

local force_cat = false -- for testing; if true, categories appear in non-mainspace pages

local u = mw.ustring.char
local rfind = mw.ustring.find
local rmatch = mw.ustring.match
local rsplit = mw.text.split

local m_links = require("Module:links")
local headword_module = "Module:headword"
local romut_module = "Module:romance utilities"
local com = require("Module:es-common")

local lang = require("Module:languages").getByCode("es")
local langname = lang:getCanonicalName()

local PAGENAME = mw.title.getCurrentTitle().text

local V = com.V -- vowel regex class
local AV = com.AV -- accented vowel regex class
local C = com.C -- consonant regex class

local rsub = com.rsub

-- Add links around words. If multiword_only, do it only in multiword forms.
local function add_links(form, multiword_only)
	if form == "" or form == " " then
		return form
	end
	if not form:find("%[%[") then
		if rfind(form, "[%s%p]") then --optimization to avoid loading [[Module:headword]] on single-word forms
			local m_headword = require(headword_module)
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

local function track(page)
	require("Module:debug").track("es-headword/" .. page)
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
	local poscat = frame.args[1]
		or error("Part of speech has not been specified. Please pass parameter 1 to the module invocation.")

	local parargs = frame:getParent().args

	local params = {
		["head"] = {list = true},
		["id"] = {},
		["json"] = {type = "boolean"},
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

	local tracking_categories = {}

	if pos_functions[poscat] then
		pos_functions[poscat].func(args, data, tracking_categories, frame, is_suffix)
	end

	if args.json then
		return require("Module:JSON").toJSON(data)
	end

	return require(headword_module).full_headword(data)
		.. (#tracking_categories > 0 and require("Module:utilities").format_categories(tracking_categories, lang, nil, nil, force_cat) or "")
end


local function do_adjective(args, data, tracking_categories, is_superlative)
	local feminines = {}
	local plurals = {}
	local masculine_plurals = {}
	local feminine_plurals = {}

	if args.sp and not require(romut_module).allowed_special_indicators[args.sp] then
		local indicators = {}
		for indic, _ in pairs(require(romut_module).allowed_special_indicators) do
			table.insert(indicators, "'" .. indic .. "'")
		end
		table.sort(indicators)
		error("Special inflection indicator beginning can only be " ..
			require("Module:table").serialCommaJoin(indicators, {dontTag = true}) .. ": " .. args.sp)
	end

	local argsf = args.f or {}
	local argspl = args.pl or {}
	local argsmpl = args.mpl or {}
	local argsfpl = args.fpl or {}

	if args.inv then
		-- invariable adjective
		table.insert(data.inflections, {label = "invariable"})
		table.insert(data.categories, langname .. " indeclinable adjectives")
		if args.sp or #argsf > 0 or #argspl > 0 or #argsmpl > 0 or #argsfpl > 0 then
			error("Can't specify inflections with an invariable adjective")
		end
	else
		local lemma = m_links.remove_links(data.heads[1] or PAGENAME)

		-- Gather feminines.
		if #argsf == 0 then
			argsf = {"+"}
		end
		for _, f in ipairs(argsf) do
			if f == "+" then
				-- Generate default feminine.
				f = com.make_feminine(lemma, args.sp)
			elseif f == "#" then
				f = lemma
			end
			table.insert(feminines, f)
		end

		if #argspl > 0 and (#argsmpl > 0 or #argsfpl > 0) then
			error("Can't specify both pl= and mpl=/fpl=")
		end
		if #feminines == 1 and feminines[1] == lemma then
			-- Feminine like the masculine; just generate a plural
			if #argspl == 0 then
				argspl = {"+"}
			end
		elseif #argspl == 0 then
			-- Distinct masculine and feminine plurals
			if #argsmpl == 0 then
				argsmpl = {"+"}
			end
			if #argsfpl == 0 then
				argsfpl = {"+"}
			end
		end

		for _, pl in ipairs(argspl) do
			if pl == "+" then
				-- Generate default plural.
				local defpls = com.make_plural(lemma, args.sp)
				if not defpls then
					error("Unable to generate default plural of '" .. lemma .. "'")
				end
				for _, defpl in ipairs(defpls) do
					table.insert(plurals, defpl)
				end
			elseif pl == "#" then
				table.insert(plurals, lemma)
			else
				table.insert(plurals, pl)
			end
		end

		for _, mpl in ipairs(argsmpl) do
			if mpl == "+" then
				-- Generate default masculine plural.
				local defpls = com.make_plural(lemma, args.sp)
				if not defpls then
					error("Unable to generate default plural of '" .. lemma .. "'")
				end
				for _, defpl in ipairs(defpls) do
					table.insert(masculine_plurals, defpl)
				end
			elseif mpl == "#" then
				table.insert(masculine_plurals, lemma)
			else
				table.insert(masculine_plurals, mpl)
			end
		end

		for _, fpl in ipairs(argsfpl) do
			if fpl == "+" then
				for _, f in ipairs(feminines) do
					-- Generate default feminine plural.
					local defpls = com.make_plural(f, args.sp)
					if not defpls then
						error("Unable to generate default plural of '" .. f .. "'")
					end
					for _, defpl in ipairs(defpls) do
						table.insert(feminine_plurals, defpl)
					end
				end
			elseif fpl == "#" then
				table.insert(feminine_plurals, lemma)
			else
				table.insert(feminine_plurals, fpl)
			end
		end

		if args.mapoc then
			check_all_missing(args.mapoc, "adjectives", tracking_categories)
		end
		check_all_missing(feminines, "adjectives", tracking_categories)
		check_all_missing(plurals, "adjectives", tracking_categories)
		check_all_missing(masculine_plurals, "adjectives", tracking_categories)
		check_all_missing(feminine_plurals, "adjectives", tracking_categories)

		if args.mapoc and #args.mapoc > 0 then
			args.mapoc.label = "masculine singular before a noun"
			table.insert(data.inflections, args.mapoc)
		end

		-- Make sure there are feminines given and not same as lemma.
		if #feminines > 0 and not (#feminines == 1 and feminines[1] == lemma) then
			feminines.label = "feminine"
			feminines.accel = {form = "f|s"}
			table.insert(data.inflections, feminines)
		end

		if #plurals > 0 then
			plurals.label = "plural"
			plurals.accel = {form = "p"}
			table.insert(data.inflections, plurals)
		end

		if #masculine_plurals > 0 then
			masculine_plurals.label = "masculine plural"
			masculine_plurals.accel = {form = "m|p"}
			table.insert(data.inflections, masculine_plurals)
		end

		if #feminine_plurals > 0 then
			feminine_plurals.label = "feminine plural"
			feminine_plurals.accel = {form = "f|p"}
			table.insert(data.inflections, feminine_plurals)
		end
	end

	if args.comp and #args.comp > 0 then
		check_all_missing(args.comp, "adjectives", tracking_categories)
		args.comp.label = "comparative"
		table.insert(data.inflections, args.comp)
	end

	if args.sup and #args.sup > 0 then
		check_all_missing(args.sup, "adjectives", tracking_categories)
		args.sup.label = "superlative"
		table.insert(data.inflections, args.sup)
	end

	if args.irreg and is_superlative then
		table.insert(data.categories, langname .. " irregular superlative adjectives")
	end
end


pos_functions["adjectives"] = {
	params = {
		["inv"] = {type = "boolean"}, --invariable
		["sp"] = {}, -- special indicator: "first", "first-last", etc.
		["f"] = {list = true}, --feminine form(s)
		["pl"] = {list = true}, --plural override(s)
		["fpl"] = {list = true}, --feminine plural override(s)
		["mpl"] = {list = true}, --masculine plural override(s)
		["mapoc"] = {list = true}, --masculine apocopated (before a noun)
		["comp"] = {list = true}, --comparative(s)
		["sup"] = {list = true}, --superlative(s)
	},
	func = function(args, data, tracking_categories)
		return do_adjective(args, data, tracking_categories, false)
	end
}

pos_functions["comparative adjectives"] = {
	params = {
		["inv"] = {type = "boolean"}, --invariable
		["sp"] = {}, -- special indicator: "first", "first-last", etc.
		["f"] = {list = true}, --feminine form(s)
		["pl"] = {list = true}, --plural override(s)
		["fpl"] = {list = true}, --feminine plural override(s)
		["mpl"] = {list = true}, --masculine plural override(s)
	},
	func = function(args, data, tracking_categories)
		return do_adjective(args, data, tracking_categories, false)
	end
}

pos_functions["superlative adjectives"] = {
	params = {
		["inv"] = {type = "boolean"}, --invariable
		["sp"] = {}, -- special indicator: "first", "first-last", etc.
		["f"] = {list = true}, --feminine form(s)
		["pl"] = {list = true}, --plural override(s)
		["fpl"] = {list = true}, --feminine plural override(s)
		["mpl"] = {list = true}, --masculine plural override(s)
		["irreg"] = {type = "boolean"},
	},
	func = function(args, data, tracking_categories)
		return do_adjective(args, data, tracking_categories, true)
	end
}


pos_functions["past participles"] = {
	params = {
		[1] = {}, --FIXME: ignore this until we've fixed the uses
		["inv"] = {type = "boolean"}, --invariable
		["sp"] = {}, -- special indicator: "first", "first-last", etc.
	},
	func = function(args, data, tracking_categories)
		return do_adjective(args, data, tracking_categories, false)
	end
}


pos_functions["adverbs"] = {
	params = {
		["sup"] = {list = true}, --superlative(s)
	},
	func = function(args, data, tracking_categories, frame)
		if #args.sup > 0 then
			check_all_missing(args.sup, "adverbs", tracking_categories)
			args.sup.label = "superlative"
			table.insert(data.inflections, args.sup)
		end
	end,
}


pos_functions["cardinal numbers"] = {
	params = {
		["f"] = {list = true}, --feminine(s)
		["mapoc"] = {list = true}, --masculine apocopated form(s)
	},
	func = function(args, data, tracking_categories, frame)
		data.pos_category = "numerals"
		table.insert(data.categories, 1, langname .. " cardinal numbers")

		if #args.f > 0 then
			table.insert(data.genders, "m")
			check_all_missing(args.f, "numerals", tracking_categories)
			args.f.label = "feminine"
			table.insert(data.inflections, args.f)
		end
		if #args.mapoc > 0 then
			check_all_missing(args.mapoc, "numerals", tracking_categories)
			args.mapoc.label = "masculine before a noun"
			table.insert(data.inflections, args.mapoc)
		end
	end,
}


local allowed_genders = require("Module:table/listToSet")(
	{"m", "f", "mf", "mfbysense", "mfequiv", "n", "m-p", "f-p", "mf-p", "mfbysense-p", "mfequiv-p", "n-p", "?", "?-p"}
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
	local gender_for_irreg_ending
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
		gender_for_irreg_ending = "mf"
	elseif saw_f then
		gender_for_irreg_ending = "f"
	else
		gender_for_irreg_ending = "m"
	end

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
				local default_pls = com.make_plural(lemma)
				for _, defp in ipairs(default_pls) do
					table.insert(plurals, defp)
				end
			elseif pl == "#" then
				table.insert(plurals, lemma)
			elseif pl:find("^%+") then
				pl = require(romut_module).get_special_indicator(pl)
				local default_pls = com.make_plural(lemma, pl)
				for _, defp in ipairs(default_pls) do
					table.insert(plurals, defp)
				end
			else
				table.insert(plurals, pl)
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
				local pls = com.make_plural(lemma)
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

	-- Gather masculines/feminines. For each one, generate the corresponding plural(s).
	local function handle_mf(mfs, inflect, default_plurals)
		local retval = {}
		for _, mf in ipairs(mfs) do
			if mf == "+" then
				-- Generate default feminine.
				mf = inflect(lemma)
			elseif mf == "#" then
				mf = lemma
			end
			local special = require(romut_module).get_special_indicator(mf)
			if special then
				mf = inflect(lemma, special)
			end
			table.insert(retval, mf)
			local mfpls = com.make_plural(mf, special)
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
	local feminines = handle_mf(args.f, com.make_feminine, feminine_plurals)
	local masculine_plurals = {}
	local masculines = handle_mf(args.m, com.make_masculine, masculine_plurals)

	local function handle_mf_plural(mfpl, default_plurals, singulars)
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
			elseif mfpl == "#" then
				table.insert(new_mfpls, {term = lemma, accel = accel})
			elseif mfpl:find("^%+") then
				mfpl = require(romut_module).get_special_indicator(mfpl)
				for _, mf in ipairs(singulars) do
					local default_mfpls = com.make_plural(mf, mfpl)
					for _, defp in ipairs(default_mfpls) do
						table.insert(new_mfpls, {term = defp, accel = accel})
					end
				end
			else
				table.insert(new_mfpls, {term = mfpl, accel = accel})
			end
		end
		return new_mfpls
	end

	if #args.fpl > 0 then
		-- Override any existing feminine plurals.
		feminine_plurals = handle_mf_plural(args.fpl, feminine_plurals, feminines)
	end

	if #args.mpl > 0 then
		-- Override any existing masculine plurals.
		masculine_plurals = handle_mf_plural(args.mpl, masculine_plurals, masculines)
	end

	check_all_missing(plurals, plpos, tracking_categories)
	check_all_missing(feminines, plpos, tracking_categories)
	check_all_missing(feminine_plurals, plpos, tracking_categories)
	check_all_missing(masculines, plpos, tracking_categories)
	check_all_missing(masculine_plurals, plpos, tracking_categories)
	check_all_missing(args.dim, plpos, tracking_categories)
	check_all_missing(args.aug, plpos, tracking_categories)
	check_all_missing(args.pej, plpos, tracking_categories)

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
		["g_qual"] = {list = "g=_qual", allow_holes = true},
		[2] = {list = "pl"}, --plural override(s)
		-- ["pl_qual"] = {list = "pl=_qual", allow_holes = true},
		["f"] = {list = true}, --feminine form(s)
		-- ["f_qual"] = {list = "f=_qual", allow_holes = true},
		["m"] = {list = true}, --masculine form(s)
		-- ["m_qual"] = {list = "m=_qual", allow_holes = true},
		["fpl"] = {list = true}, --feminine plural override(s)
		-- ["fpl_qual"] = {list = "fpl=_qual", allow_holes = true},
		["mpl"] = {list = true}, --masculine plural override(s)
		-- ["mpl_qual"] = {list = "mpl=_qual", allow_holes = true},
		["dim"] = {list = true}, --diminutive(s)
		-- ["dim_qual"] = {list = "dim=_qual", allow_holes = true},
		["aug"] = {list = true}, --diminutive(s)
		-- ["aug_qual"] = {list = "aug=_qual", allow_holes = true},
		["pej"] = {list = true}, --pejorative(s)
		-- ["pej_qual"] = {list = "pej=_qual", allow_holes = true},
	}
end

pos_functions["nouns"] = {
	params = get_noun_params(),
	func = function(args, data, tracking_categories, frame, is_suffix)
		do_noun(args, data, tracking_categories, "noun", is_suffix)
	end,
}

pos_functions["proper nouns"] = {
	params = get_noun_params("is proper"),
	func = function(args, data, tracking_categories, frame, is_suffix)
		do_noun(args, data, tracking_categories, "noun", is_suffix, "is proper")
	end,
}

pos_functions["verbs"] = {
	params = {
		[1] = {},
		["pres"] = {list = true}, --present
		["pres_qual"] = {list = "pres=_qual", allow_holes = true},
		["pret"] = {list = true}, --preterite
		["pret_qual"] = {list = "pret=_qual", allow_holes = true},
		["part"] = {list = true}, --participle
		["part_qual"] = {list = "part=_qual", allow_holes = true},
		["pagename"] = {}, -- for testing
		["noautolinktext"] = {type = "boolean"},
		["noautolinkverb"] = {type = "boolean"},
		["attn"] = {type = "boolean"},
		["new"] = {type = "boolean"},
	},
	func = function(args, data, tracking_categories, frame)
		local preses, prets, parts
		local pagename = args.pagename or PAGENAME
		local def_forms

		if args.attn then
			table.insert(tracking_categories, "Requests for attention concerning " .. langname)
			return
		end

		if mw.title.getCurrentTitle().nsText == "Template" and PAGENAME == "es-verb" and not args.pagename then
			pagename = "averiguar"
		end
		
		local parargs = frame:getParent().args
		local alternant_multiword_spec = require("Module:es-verb").do_generate_forms(parargs, "from headword")
		for _, cat in ipairs(alternant_multiword_spec.categories) do
			table.insert(data.categories, cat)
		end

		if #data.heads == 0 then
			data.no_redundant_head_cat = true
			for _, head in ipairs(alternant_multiword_spec.forms.infinitive_linked) do
				table.insert(data.heads, head.form)
			end
		end

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
					accel = ("1|s|%s|ind"):format(slot_tense),
				}
			elseif has_3s then
				return {
					slot = slot_tense .. "_3s",
					label = ("third-person singular %s"):format(label_tense),
					accel = ("3|s|%s|ind"):format(slot_tense),
				}
			else
				return {
					slot = slot_tense .. "_3p",
					label = ("third-person plural %s"):format(label_tense),
					accel = ("3|p|%s|ind"):format(slot_tense),
				}
			end
		end

		preses = do_finite("pres", "present")
		prets = do_finite("pret", "preterite")
		parts = {
			slot = "pp_ms",
			label = "past participle",
			accel = "m|s|past|part"
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

		local function do_verb_form(args, qualifiers, slot_desc)
			local forms

			if #args == 0 then
				forms = specforms[slot_desc.slot]
				if not forms or #forms == 0 then
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
						form = add_links(form)
					end
					table.insert(forms, {form = form, footnotes = qual})
				end
			end

			if forms[1].form == "-" then
				return {label = "no " .. slot_desc.label}
			else
				local into_table = {label = slot_desc.label}
				local accel = {form = slot_desc.accel}
				for _, form in ipairs(forms) do
					local qualifiers = strip_brackets(form.footnotes)
					-- Strip redundant brackets surrounding entire form. These may get generated e.g.
					-- if we use the angle bracket notation with a single word.
					local stripped_form = rmatch(form.form, "^%[%[([^%[%]]*)%]%]$") or form.form
					-- Don't include accelerators if brackets remain in form, as the result will be wrong.
					local this_accel = not stripped_form:find("%[%[") and accel or nil
					table.insert(into_table, {term = stripped_form, q = qualifiers, accel = this_accel})
				end
				return into_table
			end
		end

		if alternant_multiword_spec.only3s then
			table.insert(data.inflections, {label = glossary_link("impersonal")})
		elseif alternant_multiword_spec.only3sp then
			table.insert(data.inflections, {label = "third-person only"})
		elseif alternant_multiword_spec.only3p then
			table.insert(data.inflections, {label = "third-person plural only"})
		end
	
		table.insert(data.inflections, do_verb_form(args.pres, args.pres_qual, preses))
		table.insert(data.inflections, do_verb_form(args.pret, args.pret_qual, prets))
		table.insert(data.inflections, do_verb_form(args.part, args.part_qual, parts))
	end
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
		table.insert(data.inflections, {label = "non-lemma form of " .. require("Module:table").serialCommaJoin(suffix_type, {conj = "or"})})
	end,
}

return export
