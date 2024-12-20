local export = {}
local pos_functions = {}

--[=[
Author: Benwing2

This module is eventually intended for all the headword templates of all North Germanic languages, especially the ones
that still maintain complex inflection systems (Icelandic, Faroese, Old Norse, Old Swedish, Elfdalian, etc.), but could
definitely be extended to support other North Germanic languages (Swedish, Danish, Norwegian *). Currently it only
supports Icelandic.
]=]

local force_cat = false -- for testing; if true, categories appear in non-mainspace pages

local rfind = mw.ustring.find

local require_when_needed = require("Module:utilities/require when needed")
local m_table = require("Module:table")
local headword_utilities_module = "Module:headword utilities"
local m_headword_utilities = require_when_needed(headword_utilities_module)
local glossary_link = require_when_needed(headword_utilities_module, "glossary_link")
local inflection_utilities_module = "Module:inflection utilities"
local m_inflection_utilities = require_when_needed(inflection_utilities_module)
local is_adjective_module = "Module:User:Benwing2/is-adjective"
local is_common_module = "Module:User:Benwing2/is-common"
local is_noun_module = "Module:User:Benwing2/is-noun"
local dump = mw.dumpObject

local list_param = {list = true, disallow_holes = true}

-- Table of all valid genders by language, mapping user-specified gender specs to canonicalized versions.
local valid_number_suffixes = {"", "-p"}
local valid_genders = {"m", "f", "n"}
local valid_gender_specs = {}

for _, gender in ipairs(valid_genders) do
	for _, number in ipairs(valid_number_suffixes) do
		local spec = gender .. number
		valid_gender_specs[spec] = spec
	end
end

local function track(track_id)
	require("Module:debug/track")("gmq-headword/" .. track_id)
	return true
end

-- The main entry point.
-- This is the only function that can be invoked from a template.
function export.show(frame)
	local iparams = {
		[1] = {required = true},
		["lang"] = {required = true},
		["def"] = {},
	}
	local iargs = require("Module:parameters").process(frame.args, iparams)
	local args = frame:getParent().args
	local poscat = iargs[1]
	local langcode = iargs.lang
	if langcode ~= "is" then
		error("This module currently only works for lang=is")
	end
	local lang = require("Module:languages").getByCode(langcode, true)
	local langname = lang:getCanonicalName()
	local def = iargs.def

	local parargs = frame:getParent().args

	local params = {
		["head"] = list_param,
		["id"] = {},
		["sort"] = {},
		["nolinkhead"] = {type = "boolean"},
		["json"] = {type = "boolean"},
		["pagename"] = {}, -- for testing
	}

	if pos_functions[poscat] then
		local posparams = pos_functions[poscat].params
		if type(posparams) == "function" then
			posparams = posparams(lang)
		end
		for key, val in pairs(posparams) do
			params[key] = val
		end
	end

    local args = require("Module:parameters").process(parargs, params)

	local pagename = args.pagename or mw.title.getCurrentTitle().text

	local data = {
		lang = lang,
		langname = langname,
		pos_category = poscat,
		categories = {},
		heads = args.head,
		genders = {},
		inflections = {},
		pagename = pagename,
		id = args.id,
		sort_key = args.sort,
		force_cat_output = force_cat,
		def = def,
		is_suffix = false,
	}

	if pagename:find("^%-") and poscat ~= "suffix forms" then
		data.is_suffix = true
		data.pos_category = "suffixes"
		local singular_poscat = require("Module:string utilities").singularize(poscat)
		table.insert(data.categories, langname .. " " .. singular_poscat .. "-forming suffixes")
		table.insert(data.inflections, {label = singular_poscat .. "-forming suffix"})
	end

	local multiple_data = nil
	if pos_functions[poscat] then
		multiple_data = pos_functions[poscat].func(args, data)
	end

	-- mw.ustring.toNFD performs decomposition, so letters that decompose
	-- to an ASCII vowel and a diacritic, such as é, are counted as vowels and
	-- do not need to be included in the pattern.
	if not pagename:find("[ %-]") and not rfind(mw.ustring.lower(mw.ustring.toNFD(pagename)), "[aeiouyæœø]") then
		local cat = langname .. " words without vowels"
		if multiple_data then
			table.insert(multiple_data[1].categories, cat)
		else
			table.insert(data.categories, cat)
		end
	end

	if multiple_data then
		if args.json then
			return require("Module:JSON").toJSON(multiple_data)
		end
		return pos_functions[poscat].process_multiple_headword_data(multiple_data)
	else
		if args.json then
			return require("Module:JSON").toJSON(data)
		end
		return require("Module:headword").full_headword(data)
	end
end

-- Parse user-specified arguments in 1=, 2=, etc. for @@ scraping specs. If found, look up the appropriate
-- inflection(s). Returns two values. If there is no scraping error, the first value is a list of declension
-- specs (either directly specified by the user or scraped if an @@ spec was given) and the second value is
-- nil. Otherwise, the first value is nil and the second value is a scraping-error data structure, which the
-- calling function should directly return upstream.
local function parse_noun_adj_scraping_specs(data, declspecs, infl_template, allow_empty_infl)
	if not declspecs[2] and declspecs[1]:find("^@@") then
		local declid
		if declspecs[1] ~= "@@" then
			declid = declspecs[1]:match("^@@%s*:%s*(.+)$")
			if not declid then
				error(("Syntax error in self-scraping spec '%s'"):format(declspecs[1]))
			end
		end
		local decls = require(is_common_module).find_inflection(data.pagename, "is-ndecl", false, false, declid)
		if type(decls) == "string" then
			data.alternant_multiword_spec = {scrape_errors = {decls}}
			return nil, {data}
		end
		for i, declobj in ipairs(decls) do
			decls[i] = declobj.decl
		end
		declspecs = decls
	end
	return declspecs, nil
end

local function do_noun_adj_form(this_data, alternant_multiword_spec, slot, label, label_for_not_present, accel_form)
	local forms = alternant_multiword_spec.forms[slot]
	local retval
	if not forms then
		if not label_for_not_present then
			return
		end
		retval = {label = "no " .. label_for_not_present}
	else
		retval = {label = label, accel = accel_form and {form = accel_form} or nil}
		local prev_footnotes
		for _, form in ipairs(forms) do
			local footnotes = form.footnotes
			if footnotes and prev_footnotes and m_table.deepEquals(footnotes, prev_footnotes) then
				footnotes = nil
			end
			prev_footnotes = form.footnotes
			local quals, refs
			if footnotes then
				quals, refs = m_inflection_utilities.fetch_headword_qualifiers_and_references(footnotes)
			end
			local term = form.form
			table.insert(retval, {term = term, q = quals, refs = refs})
		end
	end

	table.insert(this_data.inflections, retval)
end

local function insert_noun_adj_linked_lemma_if_needed(this_data, alternant_multiword_spec, infl_module_name)
	-- Use the "linked" form of the lemma as the head if no head= explicitly given.
	if #this_data.heads == 0 then
		this_data.heads = {}
		local lemmas = require(infl_module_name).get_lemmas(alternant_multiword_spec, "linked variant")
		for _, lemma_obj in ipairs(lemmas) do
			local head = lemma_obj.form
			--local head = alternant_multiword_spec.args.nolinkhead and lemma_obj.form or
			--	m_headword_utilities.add_lemma_links(lemma_obj.form, alternant_multiword_spec.args.splithyph)
			local quals, refs
			if lemma_obj.footnotes then
				quals, refs = m_inflection_utilities.fetch_headword_qualifiers_and_references(lemma_obj.footnotes)
			end
			table.insert(this_data.heads, {term = head, q = quals, refs = refs})
		end
	end
end

local function get_process_noun_adj_multiple_data(infl_template)
	return function(multiple_data)
		local parts = {}
		local function ins(txt)
			table.insert(parts, txt)
		end
		for i, data in ipairs(multiple_data) do
			local alternant_multiword_spec = data.alternant_multiword_spec
			if alternant_multiword_spec.header then
				ins(("'''%s:'''<br />"):format(alternant_multiword_spec.header))
			elseif alternant_multiword_spec.q then
				ins((" ''%s''<br />"):format(alternant_multiword_spec.q))
			elseif i > 1 then
				ins(" ''or''<br />")
			end
			if alternant_multiword_spec.scrape_errors then
				local errmsgs = {}
				for _, scrape_error in ipairs(alternant_multiword_spec.scrape_errors) do
					table.insert(errmsgs, '<span style="font-weight: bold; color: #CC2200;">' .. scrape_error .. "</span>")
				end
				ins(table.concat(errmsgs, "<br />"))
				ins(require("Module:utilities").format_categories(
					{("Icelandic scraping errors in Template:%s"):format(infl_template)}, data.lang, nil, nil,
					force_cat))
			else
				ins(require("Module:headword").full_headword(data))
			end
		end
		return table.concat(parts)
	end
end

local function get_manual_noun_params(lang, is_proper)
	return {
		[1] = {alias_of = "g"},
		["g"] = list_param,
		["g_qual"] = {list = "g\1_qual", allow_holes = true},
		["indecl"] = {type = "boolean"},
		["m"] = list_param,
		["f"] = list_param,
		["dim"] = list_param,
		["aug"] = list_param,
		["pej"] = list_param,
		["dem"] = list_param,
		["fdem"] = list_param,
		["gen"] = list_param,
		["pl"] = list_param,
	}
end

local function do_manual_nouns(is_proper, args, data)
	local specs = valid_gender_specs[data.lang:getCode()]
	for i, g in ipairs(args.g) do
		local canon_g = specs[g]
		if canon_g then
			g = canon_g
		else
			error("Unrecognized gender: '" .. g .. "'")
		end
		track("gender-" .. g)
		if args.g_qual[i] then
			table.insert(data.genders, {spec = g, qualifiers = {args.g_qual[i]}})
		else
			table.insert(data.genders, g)
		end
	end
	if #data.genders == 0 then
		table.insert(data.genders, "?")
	end
	if args.indecl then
		table.insert(data.inflections, {label = glossary_link("indeclinable")})
		table.insert(data.categories, data.langname .. " indeclinable nouns")
	end

	-- Parse and insert an inflection not requiring additional processing into `data.inflections`. The raw arguments
	-- come from `args[field]`, which is parsed for inline modifiers. If there is a corresponding qualifier field
	-- `FIELD_qual`, qualifiers may additionally come from there. `label` is the label that the inflections are given,
	-- which is linked to the glossary if surrounded by <<..>> (which is removed). `plpos` is the plural part of speech,
	-- used in [[Category:LANGNAME PLPOS with red links in their headword lines]]. `accel` is the accelerator form, or
	-- nil.
	local function handle_infl(field, label, frob)
		m_headword_utilities.parse_and_insert_inflection {
			headdata = data,
			forms = args[field],
			paramname = field,
			label = label,
			frob = frob,
		}
	end

	handle_infl("gen", "genitive singular")
	handle_infl("pl", "nominative plural")
	handle_infl("m", "male equivalent")
	handle_infl("f", "female equivalent")
	handle_infl("dim", "<<diminutive>>")
	handle_infl("aug", "<<augmentative>>")
	handle_infl("pej", "<<pejorative>>")
	handle_infl("dem", "<<demonym>>")
	handle_infl("fdem", "female <<demonym>>")
end

local function get_auto_noun_params(lang, is_proper)
	return {
        [1] = {required = true, list = true, default = "akur<m.#>"},
        ["pos"] = {},
		["m"] = list_param,
		["f"] = list_param,
		["dim"] = list_param,
		["aug"] = list_param,
		["pej"] = list_param,
		["dem"] = list_param,
		["fdem"] = list_param,
	}
end

local function do_auto_nouns(is_proper, args, data)
	if data.lang:getCode() ~= "is" then
		error("Internal error: Only Icelandic supported at the moment")
	end
	if args.pos then
		data.pos_category = args.pos
	end
	local m_is_noun = require(is_noun_module)
	local alternant_multiword_specs = {}
	local multiple_data = {}
	local all_genders = {}

	local declspecs, scrape_error_data = parse_noun_adj_scraping_specs(data, args[1], "is-ndecl", false)
	if scrape_error_data then
		return scrape_error_data
	end
	for i, declspec in ipairs(declspecs) do
		local alternant_multiword_spec =
			m_is_noun.do_generate_forms(args, declspec, is_proper and "is-proper noun" or "is-noun")
		alternant_multiword_specs[i] = alternant_multiword_spec
		local this_data
		if i < #declspecs then
			this_data = m_table.shallowCopy(data)
			this_data.categories = {}
			this_data.inflections = {}
			-- genders gets overwritten just below
		else
			-- for the last (or usually only) spec, save memory by not cloning
			this_data = data
		end
		multiple_data[i] = this_data
		this_data.alternant_multiword_spec = alternant_multiword_spec
		this_data.heads = args.head
		if not alternant_multiword_spec.scrape_errors then
			this_data.genders = alternant_multiword_spec.genders
			for _, gender in ipairs(this_data.genders) do
				m_table.insertIfNot(all_genders, gender)
			end

			local function do_noun_form(slot, label, label_for_not_present, accel_form)
				do_noun_adj_form(this_data, alternant_multiword_spec, slot, label, label_for_not_present, accel_form)
			end

			local function insert_label(label)
				table.insert(this_data.inflections, {label = label})
			end

			if is_proper then
				insert_label(glossary_link("proper noun"))
			end
			if not alternant_multiword_spec.first_noun and alternant_multiword_spec.first_adj then
				insert_label("adjectival")
			end
			local def_prefix
			if alternant_multiword_spec.definiteness == "def" then
				def_prefix = "def_"
				insert_label(glossary_link("definite") .. " only")
			else
				def_prefix = "ind_"
			end
			if alternant_multiword_spec.number == "pl" then
				insert_label(glossary_link("plural only"))
			end
			if alternant_multiword_spec.saw_indecl and not alternant_multiword_spec.saw_non_indecl then
				insert_label(glossary_link("indeclinable"))
			elseif alternant_multiword_spec.saw_unknown_decl and not alternant_multiword_spec.saw_non_unknown_decl then
				insert_label("unknown declension")
			elseif alternant_multiword_spec.number == "pl" then
				do_noun_form(def_prefix .. "gen_p", "genitive plural", "genitive plural")
			else
				do_noun_form(def_prefix .. "gen_s", "genitive singular", "genitive singular")
				do_noun_form(def_prefix .. "nom_p", "nominative plural", not is_proper and "plural" or nil)
			end

			if i == 1 then
				-- Parse and insert an inflection not requiring additional processing into `this_data.inflections`. The raw
				-- arguments come from `args[field]`, which is parsed for inline modifiers. If there is a corresponding
				-- qualifier field `FIELD_qual`, qualifiers may additionally come from there. `label` is the label that the
				-- inflections are given, which is linked to the glossary if surrounded by <<..>> (which is removed).
				-- `plpos` is the plural part of speech, used in [[Category:LANGNAME PLPOS with red links in their headword
				-- lines]]. `accel` is the accelerator form, or nil.
				local function handle_infl(field, label, frob)
					m_headword_utilities.parse_and_insert_inflection {
						headdata = this_data,
						forms = args[field],
						paramname = field,
						label = label,
						frob = frob,
					}
				end

				handle_infl("m", "male equivalent")
				handle_infl("f", "female equivalent")
				handle_infl("dim", "<<diminutive>>")
				handle_infl("aug", "<<augmentative>>")
				handle_infl("pej", "<<pejorative>>")
				handle_infl("dem", "<<demonym>>")
				handle_infl("fdem", "female <<demonym>>")
			end

			-- Add categories.
			for _, cat in ipairs(alternant_multiword_spec.categories) do
				table.insert(this_data.categories, cat)
			end

			insert_noun_adj_linked_lemma_if_needed(this_data, alternant_multiword_spec, is_noun_module)
		end
	end

	if #all_genders > 1 then
		table.insert(multiple_data[1].categories, data.langname .. " nouns with multiple genders")
	end

	return multiple_data
end

local function get_noun_pos_functions(is_proper)
	return {
		params = function(lang)
			if lang:getCode() == "is" then
				return get_auto_noun_params(lang, is_proper)
			else
				return get_manual_noun_params(lang, is_proper)
			end
		end,
		func = function(args, data)
			if data.lang:getCode() == "is" then
				return do_auto_nouns(is_proper, args, data)
			else
				return do_manual_nouns(is_proper, args, data)
			end
		end,
		process_multiple_headword_data = get_process_noun_adj_multiple_data("is-ndecl"),
	}
end

pos_functions["nouns"] = get_noun_pos_functions(false)
pos_functions["proper nouns"] = get_noun_pos_functions("proper noun")

local function do_comparative_superlative(args, data, plpos)
	if args[1][1] == "-" then
		table.insert(data.inflections, {label = "not " .. glossary_link("comparable")})
		table.insert(data.categories, data.langname .. " uncomparable " .. plpos)
	elseif args[1][1] or args[2][1] then
		local comp = m_headword_utilities.parse_term_list_with_modifiers {
			paramname = {1, "comp"},
			forms = args[1],
		}
		local sup = m_headword_utilities.parse_term_list_with_modifiers {
			paramname = {2, "sup"},
			forms = args[2],
		}
		if comp[1] then
			comp.label = glossary_link("comparative")
			-- comp.accel = {form = "comparative"}
			table.insert(data.inflections, comp)
		end
		if sup[1] then
			sup.label = glossary_link("superlative")
			-- sup.accel = {form = "superlative"}
			table.insert(data.inflections, sup)
		end
		table.insert(data.categories, data.langname .. " comparable " .. plpos)
	end
end

local function get_manual_adjective_params(lang)
	return {
		[1] = {list = "comp", disallow_holes = true},
		[2] = {list = "sup", disallow_holes = true},
		["adv"] = list_param,
		["indecl"] = {type = "boolean"},
	}
end

local function do_manual_adjectives(args, data)
	if args.indecl then
		table.insert(data.inflections, {label = glossary_link("indeclinable")})
		table.insert(data.categories, data.langname .. " indeclinable adjectives")
	end
	do_comparative_superlative(args, data, "adjectives")
	m_headword_utilities.parse_and_insert_inflection {
		headdata = data,
		forms = args.adv,
		paramname = "adv",
		label = "adverb",
	}
end

local function get_auto_adjective_params(lang)
	return {
        [1] = {required = true, list = true, default = "djúpur<comp:^>"},
        ["pos"] = {},
		["adv"] = list_param,
	}
end

local function do_auto_adjectives(args, data)
	if data.lang:getCode() ~= "is" then
		error("Internal error: Only Icelandic supported at the moment")
	end
	if args.pos then
		data.pos_category = args.pos
	end
	local m_is_adjective = require(is_adjective_module)
	local m_is_common = require(is_common_module)
	local alternant_multiword_specs = {}
	local multiple_data = {}
	local declspecs, scrape_error_data = parse_noun_adj_scraping_specs(data, args[1], "is-adecl", "allow empty infl")
	if scrape_error_data then
		return scrape_error_data
	end
	for i, declspec in ipairs(declspecs) do
		local alternant_multiword_spec = m_is_adjective.do_generate_forms(args, declspec, "is-adj")
		alternant_multiword_specs[i] = alternant_multiword_spec
		local this_data
		if i < #declspecs then
			this_data = m_table.shallowCopy(data)
			this_data.categories = {}
			this_data.inflections = {}
		else
			-- for the last (or usually only) spec, save memory by not cloning
			this_data = data
		end
		multiple_data[i] = this_data
		this_data.alternant_multiword_spec = alternant_multiword_spec
		this_data.heads = args.head
		if not alternant_multiword_spec.scrape_errors then
			local function do_adjective_form(slot, label, label_for_not_present, accel_form)
				do_noun_adj_form(this_data, alternant_multiword_spec, slot, label, label_for_not_present, accel_form)
			end

			local function insert_label(label)
				table.insert(this_data.inflections, {label = label})
			end

			if alternant_multiword_spec.saw_indecl and not alternant_multiword_spec.saw_non_indecl then
				insert_label(glossary_link("indeclinable"))
			elseif alternant_multiword_spec.saw_unknown_decl and not alternant_multiword_spec.saw_non_unknown_decl then
				insert_label("unknown declension")
			end

			local function do_superlative()
				do_adjective_form("sup_str_nom_m", glossary_link("superlative"), nil, "superlative")
			end

			if alternant_multiword_spec.haspos == "has" then
				if alternant_multiword_spec.number.pos == "sg" then
					insert_label(glossary_link("singular only"))
				elseif alternant_multiword_spec.number.pos == "pl" then
					insert_label(glossary_link("plural only"))
				end
				if alternant_multiword_spec.state.pos == "strong" or alternant_multiword_spec.state.pos == "weak" then
					-- not "both" or "none"
					insert_label(alternant_multiword_spec.state.pos .. " only")
				end
				if alternant_multiword_spec.hascomp == "has" then
					do_adjective_form("comp_wk_nom_m", glossary_link("comparative"), nil, "comparative")
					if alternant_multiword_spec.hassup == "has" then
						do_superlative()
					elseif alternant_multiword_spec.hassup == "hasnot" then
						insert_label("no " .. glossary_link("superlative"))
					end
				elseif alternant_multiword_spec.hascomp == "hasnot" then
					if alternant_multiword_spec.hassup == "has" then
						insert_label("no " .. glossary_link("comparative"))
						do_superlative()
					else
						insert_label("not " .. glossary_link("comparable"))
					end
				end
			elseif alternant_multiword_spec.hascomp == "has" then
				insert_label(glossary_link("comparative") .. " only")
				if alternant_multiword_spec.hassup == "has" then
					do_superlative()
				end
			else
				insert_label(glossary_link("superlative") .. " only")
			end

			if i == 1 then
				-- Parse and insert an inflection not requiring additional processing into `this_data.inflections`. The raw
				-- arguments come from `args[field]`, which is parsed for inline modifiers. If there is a corresponding
				-- qualifier field `FIELD_qual`, qualifiers may additionally come from there. `label` is the label that the
				-- inflections are given, which is linked to the glossary if surrounded by <<..>> (which is removed).
				-- `plpos` is the plural part of speech, used in [[Category:LANGNAME PLPOS with red links in their headword
				-- lines]]. `accel` is the accelerator form, or nil.
				local function handle_infl(field, label, frob)
					m_headword_utilities.parse_and_insert_inflection {
						headdata = this_data,
						forms = args[field],
						paramname = field,
						label = label,
						frob = frob,
					}
				end

				handle_infl("adv", "adverb")
			end

			-- Add categories.
			for _, cat in ipairs(alternant_multiword_spec.categories) do
				table.insert(this_data.categories, cat)
			end

			insert_noun_adj_linked_lemma_if_needed(this_data, alternant_multiword_spec, is_adjective_module)
		end
	end

	return multiple_data
end

local function get_adjective_pos_functions()
	return {
		params = function(lang)
			if lang:getCode() == "is" then
				return get_auto_adjective_params(lang)
			else
				return get_manual_adjective_params(lang)
			end
		end,
		func = function(args, data)
			if data.lang:getCode() == "is" then
				return do_auto_adjectives(args, data)
			else
				return do_manual_adjectives(args, data)
			end
		end,
		process_multiple_headword_data = get_process_noun_adj_multiple_data("is-adecl"),
	}
end

pos_functions["adjectives"] = get_adjective_pos_functions()

pos_functions["adverbs"] = {
	params = {
		[1] = {list = "comp", disallow_holes = true},
		[2] = {list = "sup", disallow_holes = true},
	},
	func = function(args, data)
		do_comparative_superlative(args, data, "adverbs")
	end,
}


return export
