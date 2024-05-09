-- This module contains code for Philippine-language headword templates.
-- Most languages use the following templates (e.g. for Waray-Waray):
-- * {{war-noun}}, {{war-proper noun}};
-- * {{war-verb}};
-- * {{war-adj}};
-- * {{war-adv}};
-- * {{war-head}}.
-- Tagalog uses the following additional templates:
-- * {{tl-num}};
-- * {{tl-pron}};
-- * {{tl-prep}}.
-- Cebuano uses the following additional templates:
-- * {{ceb-num}}.

local export = {}
local pos_functions = {}

local force_cat = false -- for testing; if true, categories appear in non-mainspace pages

local rmatch = mw.ustring.match
local rsplit = mw.text.split
local uupper = mw.ustring.upper
local ulower = mw.ustring.ulower

local template_parser_module = "Module:template parser"

local tl_conj_type_data = {
	["actor"] = 5,
	["actor indirect"] = 0,
	["actor 2nd indirect"] = 4,
	["object"] = 11,
	["locative"] = 2,
	["benefactive"] = 3,
	["instrument"] = 2,
	["reason"] = {4, {1,2,3}},
	["directional"] = 6,
	["reference"] = 0,
	["reciprocal"] = 2
}
local tl_conjugation_types = {}

for key, value in pairs(tl_conj_type_data) do
	local type_count = 0
	local alternates = {}
	if type(value) == "number" then
		type_count = value
	else
		type_count = value[1]
		alternates = value[2]
	end

	local roman_numeral
	if type_count == 0 then
		local trigger = {key, "trigger"}
		if key == "actor indirect" then
			trigger[1] = "indirect actor"
		end
		tl_conjugation_types[key] = table.concat(trigger, " ")
	else
		for i = 1, type_count do
			roman_numeral = require("Module:roman numerals").arabic_to_roman(tostring(i))
			local trigger = {require("Module:ordinal")._ordinal(tostring(i)), key, "trigger"}
			
			--These could be typos but putting back in to stay consistent
			if key == "actor 2nd indirect" then
				trigger[2] = "secondary indirect actor"
			end
			
			tl_conjugation_types[key .. " " .. roman_numeral] = table.concat(trigger, " ")
			
			if require("Module:table").contains(alternates, i) then
				roman_numeral = roman_numeral .. "A"
				trigger[1] = "alternate " .. trigger[1]
				tl_conjugation_types[key .. " " .. roman_numeral] = table.concat(trigger, " ")
			end
		end
	end
end

local ilo_conjugation_types = {
	["actor I"] = "1st actor trigger", -- um- or -um-
	["actor II"] = "2nd actor trigger", -- ag-
	["actor III"] = "3rd actor trigger", -- mang-
	["actor IV"] = "4th actor trigger", -- ma-
	["actor potentive I"] = "1st actor trigger potential mood", -- maka-
	["actor potential II"] = "2nd actor trigger potential mood", -- makapag-
	["actor causative I"] = "2nd actor trigger potential mood", -- agpa-
	["actor causative II"] = "2nd actor trigger potential mood", -- mangpa-
	["object"] = "object trigger", -- -en
	["object potential"] = "object trigger potential mood", -- ma-
	["object causative"] = "2nd actor trigger potential mood", -- ipai-
    ["comitative"] = "comitative trigger", -- ka-
	["comitative potential"] = "comitative trigger potential mood", -- maka-
    ["comitative causative I"] = "1st comitative trigger causative mood", -- makapa-
    ["comitative causative II"] = "2nd comitative trigger causative mood", -- makipa-
	["locative"] = "locative trigger",-- -an
	["locative potential"] = "locative trigger potential mood", -- ma- -an
	["locative causative"] = "locative trigger causative mood", -- pa- -an
    ["thematic"] = "thematic trigger", -- i-
    ["thematic potential"] = "thematic trigger potential mood", -- mai-
	["thematic causative"] = "thematic trigger causative mood", -- ipa-
	["benefactive"] = "benefactive trigger", -- i- -an
	["benefactive potential"] = "benefactive trigger potential mood", -- mai- -an
	["benefactive causative"] = "benefactive trigger causative mood", -- ipa- -an
	["instrument"] = "instrument trigger", -- pag-
	["instrument potential"] = "instrument trigger potential mood", -- mapag-
	["instrument causative"] = "1st instrument trigger causative mood", -- pagpa- -an
	["instrument causative II"] = "2nd instrument trigger causative mood", -- panagpa- 
}

local pag_conjugation_types = {
	["actor I"] = "1st actor trigger", -- on-/-on-
	["actor II"] = "2nd actor trigger", --man-
	["actor potentive I"] = "actor trigger potential mood", -- maka-
	["actor potentive II"] = "actor trigger potential mood", -- makapag-
	["object"] = "object trigger", -- -en
	["object potential"] = "object trigger potential mood", -- ma-
	["instrument"] = "instrument trigger", -- pag-
	["instrument potential"] = "instrument trigger potential mood", -- mapag-
	["instrument causative"] = "1st instrument trigger causative mood", -- pagpa- -an
	["instrument causative II"] = "2nd instrument trigger causative mood", -- panagpa-
}


-- FIXME: Are these various languages really so different in their verb inflections or is this just a case of
-- randomly picking a subset of the total inflections?
local tl_bcl_verb_inflections = {
	{"comp", {label = "complete", form = "comp", alias = {2}}},
	{"prog", {label = "progressive", form = "imp", alias = {3}}},
	{"cont", {label = "contemplative", form = "cont", alias = {4}}},
	{"vnoun", {label = "verbal noun", form = "vnoun", alias = {5}}},
}
local hil_krj_war_verb_inflections = {
	{"real", {label = "realis", form = "realis", alias = {2}}},
	{"imp", {label = "imperative", form = "imp", alias = {3}}},
	{"dim", {label = "diminutive"}},
	{"caus", {label = "causative"}},
	{"freq", {label = "frequentative"}},
}
local ilo_pag_verb_inflections = {
	{"perf", {label = "perfective", form = "pfv", alias = {2}}},
	{"imperf", {label = "imperfective", form = "impfv", alias = {3}}},
	{"past_imperf", {label = "past imperfective", form = "past|impfv", alias = {4}}},
	{"fut", {label = "future", form = "fut", alias = {5}}},
}
local hil_krj_war_noun_inflections = {
	{"dim", {label = "diminutive"}},
}
local hil_krj_war_adj_inflections = {
	{"dim", {label = "diminutive"}},
	{"caus", {label = "causative"}},
}

-- NOTE: Here and below, the template names need to be in their canonical form (not shortcuts).
local langs_supported = {
	["bcl"] = {
		native_script_name = "Basahan",
		convert_to_native_script = "bcl-basahan script",
		native_script_def = "bcl-basahan",
		pronun_templates_to_check = {"bcl-IPA"},
		has_pl_all_pos = true,
		has_intens_all_pos = true,
		verb_inflections = tl_bcl_verb_inflections,
	},
	["cbk"] = {
		pronun_templates_to_check = {"cbk-IPA"},
	},
	["ceb"] = {
		native_script_name = "Badlit",
		convert_to_native_script = "ceb-badlit script",
		native_script_def = "ceb-badlit",
		pronun_templates_to_check = {"ceb-IPA"},
		verb_inflections = {
			{"inch", {label = "inchoative", form = "realis", alias = {2}}},
			{"imp", {label = "imperative", form = "imp", alias = {3}}},
		},
	},
	["hil"] = {
		pronun_templates_to_check = {"hil-IPA"},
		verb_inflections = hil_krj_war_verb_inflections,
		noun_inflections = hil_krj_war_noun_inflections,
		adj_inflections = hil_krj_war_adj_inflections,
	},
	["ilo"] = {
		native_script_name = "Kur-itan",
		convert_to_native_script = "ilo-kur-itan script",
		native_script_def = "ilo-kur-itan",
		pronun_templates_to_check = {"ilo-IPA"},
		conjugation_types = ilo_conjugation_types,
		verb_inflections = ilo_pag_verb_inflections,
		adj_inflections = {
			{"comp", {label = "comparative", form = "comparative", alias = {2}}},
			{"mod", {label = "moderative", form = "moderative", alias = {3}}},
			{"comp_sup", {label = "comparative superlative", form = "comp|sup", alias = {4}}},
			{"abs_sup", {label = "absolutive superlative", form = "abs|sup", alias = {5}}},
			{"intens", {label = "intensive", alias = {6}}},
		},
	},
	["krj"] = {
		pronun_templates_to_check = {"krj-IPA"},
		verb_inflections = hil_krj_war_verb_inflections,
		noun_inflections = hil_krj_war_noun_inflections,
		adj_inflections = hil_krj_war_adj_inflections,
	},
	["mdh"] = {
		arabic_script_name = "Jawi",
		native_script_def = "mdh-Jawi",
		pronun_templates_to_check = {"mdh-IPA"},
	},
	["mrw"] = {
		arabic_script_name = "batang Arab",
	},
	["pag"] = {
		pronun_templates_to_check = {"pag-IPA"},
		conjugation_types = pag_conjugation_types,
		verb_inflections = ilo_pag_verb_inflections,
	},
	["pam"] = {
		pronun_templates_to_check = {"pam-IPA"},
		verb_inflections = {
			{"perf", {label = "perfective", form = "pfv", alias = {2}}}, -- Use with affixed verbs only.
			{"prog", {label = "progressive", form = "prog", alias = {3}}}, -- Use with affixed verbs only.
		},
	},
	["tl"] = {
		native_script_name = "Baybayin",
		convert_to_native_script = "tl-baybayin script",
		native_script_def = "tl-baybayin",
		pronun_templates_to_check = {"tl-pr", "tl-IPA"},
		conjugation_types = tl_conjugation_types,
		verb_inflections = tl_bcl_verb_inflections,
	},
	["tsg"] = {
	},
	["war"] = {
		pronun_templates_to_check = {"war-IPA"},
		verb_inflections = hil_krj_war_verb_inflections,
		noun_inflections = hil_krj_war_noun_inflections,
		adj_inflections = hil_krj_war_adj_inflections,
	},
}

----------------------------------------------- Utilities --------------------------------------------

local function track(page)
	require("Module:debug/track")("phi-headword/" .. page)
	return true
end

local function ine(val)
	if val == "" then return nil else return val end
end

local function do_inflection(data, forms, label, accel)
	if #forms > 0 then
		forms.label = label
		if accel then
			forms.accel = accel
		end
		table.insert(data.inflections, forms)
	end
end

local function add_params(params, params_spec)
	if not params_spec then
		return
	end
	for _, spec in ipairs(params_spec) do
		local arg, argspecs = unpack(spec)
		params[arg] = {list = true}
		if argspecs.alias then
			for _, al in ipairs(argspecs.alias) do
				params[al] = {alias_of = arg}
			end
		end
	end
end

local function do_inflections(args, data, params_spec)
	if not params_spec then
		return
	end
	for _, spec in ipairs(params_spec) do
		local arg, argspecs = unpack(spec)
		do_inflection(data, args[arg], argspecs.label, argspecs.form and {form = argspecs.form} or nil)
	end
end

----------------------------------------------- Main code --------------------------------------------

-- The main entry point.
-- This is the only function that can be invoked from a template.
function export.show(frame)
	local iparams = {
		[1] = {},
		["lang"] = {required = true},
	}

	local iargs = require("Module:parameters").process(frame.args, iparams)

	local parargs = frame:getParent().args
	local poscat = iargs[1]
	local langcode = iargs.lang
	if not langs_supported[langcode] then
		local langcodes_supported = {}
		for lang, _ in pairs(langs_supported) do
			table.insert(langcodes_supported, lang)
		end
		error("This module currently only works for lang=" .. table.concat(langcodes_supported, "/"))
	end
	local lang = require("Module:languages").getByCode(langcode)
	local langname = lang:getCanonicalName()
	local headarg
	if poscat then
		headarg = 1
	else
		headarg = 2
		poscat = ine(parargs[1]) or
			mw.title.getCurrentTitle().fullText == "Template:" .. langcode .. "-head" and "interjection" or
			error("Part of speech must be specified in 1=")
		poscat = require("Module:string utilities").pluralize(poscat)
	end

	local langprops = langs_supported[langcode]

	local params = {
		[headarg] = {list = "head", disallow_holes = true},
		["id"] = {},
		["nolink"] = {type = "boolean"},
		["nolinkhead"] = {type = "boolean", alias_of = "nolink"},
		["suffix"] = {type = "boolean"},
		["nosuffix"] = {type = "boolean"},
		["addlpos"] = {},
		["json"] = {type = "boolean"},
		["pagename"] = {}, -- for testing
	}
	if langprops.native_script_name then
		params["b"] = {list = true}
	end
	if langprops.arabic_script_name then
		params["j"] = {list = true}
	end
	local has_alt_script = langprops.native_script_name or langprops.arabic_script_name
	if has_alt_script then
		params["tr"] = {list = true, allow_holes = true}
	end
	if headarg == 2 then
		params[1] = {required = true} -- required but ignored as already processed above
	end

	if pos_functions[poscat] then
		for key, val in pairs(pos_functions[poscat].params(langcode)) do
			params[key] = val
		end
	end

	if langprops.has_pl_all_pos and not params.pl then
		-- Yuck, this should be POS-specific but it seems all POS's can be pluralized in Bikol Central?
		params["pl"] = {list = true}
		need_pl_handled = true
	end

	if langprops.has_intens_all_pos then
		params["intens"] = {list = true}
		if langprops.has_pl_all_pos then
			params["plintens"] = {list = true}
		end
	end

	local args = require("Module:parameters").process(parargs, params)

	local pagename = args.pagename or mw.title.getCurrentTitle().subpageText

	if has_alt_script and args.tr.maxindex > #args[headarg] then
		error("Too many translits specified; use '+' to indicate a default head")
	end

	local user_specified_heads = args[headarg]
	local heads = user_specified_heads
	if args.nolink then
		if #heads == 0 then
			heads = {pagename}
		end
	end

	for i, head in ipairs(heads) do
		if head == "+" then
			head = nil
		end
		heads[i] = {
			term = head,
			tr = langprops.has_alt_script and args.tr[i] or nil,
		}
	end

	local data = {
		lang = lang,
		langcode = langcode,
		langname = langname,
		pos_category = poscat,
		categories = {},
		heads = heads,
		user_specified_heads = user_specified_heads,
		no_redundant_head_cat = #user_specified_heads == 0,
		inflections = {},
		pagename = pagename,
		id = args.id,
		force_cat_output = force_cat,
	}

	data.is_suffix = false
	if args.suffix or (
		not args.nosuffix and pagename:find("^%-") and poscat ~= "suffixes" and poscat ~= "suffix forms"
	) then
		data.is_suffix = true
		data.pos_category = "suffixes"
		local singular_poscat = require("Module:string utilities").singularize(poscat)
		table.insert(data.categories, langname .. " " .. singular_poscat .. "-forming suffixes")
		table.insert(data.inflections, {label = singular_poscat .. "-forming suffix"})
		if args.addlpos then
			for _, addlpos in ipairs(rsplit(args.addlpos, "%s*,%s*")) do
				table.insert(data.categories, langname .. " " .. addlpos .. "-forming suffixes")
				table.insert(data.inflections, {label = addlpos .. "-forming suffix"})
			end
		end
	end

	if pos_functions[poscat] then
		pos_functions[poscat].func(args, data)
	end

	if need_pl_handled then
		do_inflection(data, args.pl, "plural", {form = "plural"})
	end
	if langprops.has_intens_all_pos then
		do_inflection(data, args.intens, "intensified")
		if langprops.has_pl_all_pos then
			do_inflection(data, args.plintens, "plural intensified")
		end
	end

	local pattern_escape = require("Module:string utilities").pattern_escape

	local script
	if has_alt_script then
		script = lang:findBestScript(pagename) -- Latn or Tglg
		-- Disable native-script spelling parameter if entry is already in native script.
		if script:getCode() == "Tglg" then
			args.b = {}
		end
		-- Disable Arabic-script spelling parameter if entry is already in Arabic script.
		if script:getCode() == "Arab" then
			args.j = {}
		end

		local function check_for_alt_script_entry(altscript, altscript_def)
			-- See if we need to add a tracking category for missing alt script entry.
			if not altscript_def then
				return false
			end
			local script_entry_present
			local title = mw.title.new(altscript)
			if title then
				local altscript_content = title:getContent()
				if altscript_content then
					for name, args, text, index in require(template_parser_module).findTemplates(altscript_content) do
						if name == altscript_def then
							for i = 1, 10 do
								if args[i] == pagename then
									script_entry_present = true
									break
								end
							end
						end
						if script_entry_present then
							break
						end
					end
				end
			end
			return script_entry_present
		end

		local function handle_alt_script(script_argname, script_code, script_name, convert_to_script, script_def)
			local script_arg = args[script_argname]
			if script_arg then
				for i, alt in ipairs(script_arg) do
					if alt == "+" then
						alt = pagename
					end
					local altsc = lang:findBestScript(alt)
					if altsc:getCode() == "Latn" then
						if convert_to_script then
							alt = frame:expandTemplate { title = convert_to_script, args = { alt }}
						else
							error(("Latin script for %s= not currently supported; supply proper script"):format(
								script_argname))
						end
					end
					script_arg[i] = {term = alt, sc = require("Module:scripts").getByCode(script_code) }

					if not check_for_alt_script_entry(alt, script_def) then
						table.insert(data.categories,
							("%s terms with missing %s script entries"):format(langname, script_name))
					end
				end
				if #script_arg > 0 then
					script_arg.label = script_name .. " spelling"
					table.insert(data.inflections, script_arg)
				end

				if script:getCode() == "Latn" then
					table.insert(data.categories, ("%s terms %s %s script"):format(
						langname, #script_arg > 0 and "with" or "without", script_name))
				elseif script:getCode() == script_code then
					table.insert(data.categories, ("%s terms in %s script"):format(langname, script_name))
				end
			end
		end

		if langprops.native_script_name then
			handle_alt_script("b", "Tglg", langprops.native_script_name, langprops.convert_to_native_script,
				langprops.native_script_def)
		end
		if langprops.arabic_script_name then
			handle_alt_script("j", "Arab", langprops.arabic_script_name, langprops.convert_to_arabic_script,
				langprops.arabic_script_def)
		end
	end

	if langprops.pronun_templates_to_check and (not has_alt_script or script:getCode() == "Latn") then
		-- See if we need to add a tracking category for missing {{tl-pr}}, {{tl-IPA}}, etc.
		local template_present
		local this_title = mw.title.new(pagename)
		if this_title then
			local content = this_title:getContent()
			if content then
				for name, args, text, index in require(template_parser_module).findTemplates(content) do
					for _, pronun_template in ipairs(langprops.pronun_templates_to_check) do
						if name == pronun_template then
							template_present = true
							break
						end
					end
					if template_present then
						break
					end
				end
			end
		end
		if not template_present then
			table.insert(data.categories, ("%s terms without pronunciation template"):format(langname, pronun_template))
		end
	end

	if args.json then
		return require("Module:JSON").toJSON(data)
	end

	return require("Module:headword").full_headword(data)
end


pos_functions["adjectives"] = {
    params = function(langcode)
		local params = {
			["f"] = {list = true},
			["m"] = {list = true},
			["pl"] = {list = true},
			["comp"] = {list = true},
			["sup"] = {list = true},
		}
		add_params(params, langs_supported[langcode].adj_inflections)
		return params
	end,
	func = function(args, data)
		do_inflection(data, args.f, "feminine")
		do_inflection(data, args.m, "masculine")
		do_inflection(data, args.pl, "plural", {form = "plural"})
		do_inflection(data, args.comp, "comparative")
		do_inflection(data, args.sup, "superlative")
		do_inflections(args, data, langs_supported[data.langcode].adj_inflections)
	end,
}


pos_functions["nouns"] = {
    params = function(langcode)
		local params = {
			["f"] = {list = true},
			["m"] = {list = true},
			["pl"] = {list = true},
			rootword = {type = "boolean"},
		}
		add_params(params, langs_supported[langcode].noun_inflections)
		return params
	end,
	func = function(args, data)
		do_inflection(data, args.f, "feminine")
		do_inflection(data, args.m, "masculine")
		do_inflection(data, args.pl, "plural", {form = "plural"})
		do_inflections(args, data, langs_supported[data.langcode].noun_inflections)

		if args.rootword then
			table.insert(data.infections, {label = "root word"})
			table.insert(data.categories, langname .. " roots")
		end
	end,
}

pos_functions["proper nouns"] = pos_functions["nouns"]


pos_functions["pronouns"] = {
    params = function(langcode)
	    return {
			["pl"] = {list = true},
		}
	end,
	func = function(args, data)
		do_inflection(data, args.pl, "plural", {form = "plural"})
	end,
}

pos_functions["prepositions"] = pos_functions["pronouns"]

pos_functions["verbs"] = {
    params = function(langcode)
		local params = {
			rootword = {type = "boolean"},
		}
		if langs_supported[langcode].conjugation_types then
			params.type = {list = true}
		end
		add_params(params, langs_supported[langcode].verb_inflections)
		return params
	end,
	func = function(args, data)
		do_inflections(args, data, langs_supported[data.langcode].verb_inflections)

		if args.rootword then
			table.insert(data.infections, {label = "root word"})
			table.insert(data.categories, data.langname .. " roots")
		end

		if args.type then
			-- Tag verb trigger
			local conjugation_types = langs_supported[data.langcode].conjugation_types
			for i, typ in ipairs(args.type) do
				if not conjugation_types[typ] then
					error(("Unrecognized %s verb conjugation type '%s'"):format(data.langname, typ))
				end
				local label = conjugation_types[typ]
				table.insert(data.inflections, {label = label})
				table.insert(data.categories, ("%s %s verbs"):format(data.langname, label))
			end
		end
	end,
}

pos_functions["letters"] = {
    params = function(langcode)
		local params = {
			["type"] = {},
			["upper"] = {},
			["lower"] = {},
			["mixed"] = {},
		}
		return {}
	end,
	func = function(args, data)
		if args.type then
			if args.type ~= "upper" and args.type ~= "lower" and args.type ~= "mixed" then
				error(("Unrecognized value for type '%s'; should be one of 'upper', 'lower' or 'mixed'"):format(
					args.type))
			end
		end
		local uppage = uupper(data.pagename)
		local lopage = ulower(data.pagename)
		if uppage == lopage then
			if args.type then
				error("Can't specify type= when letter has no case")
			end
			if args.upper or args.lower or args.mixed then
				error("Can't specify upper=, lower= or mixed= when letter has no case")
			end
			table.insert(data.inflections, {label = "no case"})
		elseif args.type == "upper" or pagename == uppage then
			if args.upper then
				error("Already uppercase; can't specify upper=")
			end
			table.insert(data.inflections, {label = "[[Appendix:Capital letter|upper case]]"})
			table.insert(data.inflections, {args.lower or lopage, label = "lower case"})
		elseif args.type == "lower" or pagename == lopage then
			if args.lower then
				error("Already uppercase; can't specify upper=")
			end
			table.insert(data.inflections, {label = "lower case"})
			table.insert(data.inflections, {args.upper or uppage, label = "upper case"})
		else
			table.insert(data.inflections, {label = "mixed case"})
			table.insert(data.inflections, {args.upper or uppage, label = "upper case"})
			table.insert(data.inflections, {args.lower or lopage, label = "lower case"})
		end
	end,
}

return export
