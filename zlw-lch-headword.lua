local export = {}
local pos_functions = {}

local parse_utilities_module = "Module:parse utilities"

local rfind = mw.ustring.find
local rsplit = mw.text.split

local langs_supported = {
	["pl"] = {
		peri_comp = "bardziej",
		sup = "naj",
		-- participle endings
		act = {"ąc[yae]$"},  -- biegnący
		pass = {"[ntł][yae]$"},  -- otwarty, uwielbiany, legły
		cont_adv = {"ąc$"},
		ant_adv = {"szy$"},
	},
	["csb"] = {
		peri_comp = "barżi",
		sup = "nô",
		-- participle endings
		act = {"ący$"},
		pass = {"[ao]ny$", "ty$", "łi$"},
		cont_adv = {"ōnc$"},
		ant_adv = {"[wł]szë$"},
	},
	["szl"] = {
		peri_comp = "bardzij",
		sup = "noj",
		-- participle endings
		act = {"ōncy$"},
		pass = {"[aō]ny$", "[tł]y$"},
		cont_adv = {"ąc$"},
		ant_adv = false,
	},
	["zlw-mas"] = {
		peri_comp = "barżi",
		sup = "ná",
		-- participle endings
		act = {"óncÿ$"},
		pass = {"[aó]nÿ$", "[tł]i$"},
		cont_adv = {"ónc$"},
		ant_adv = {"[wł]sÿ$"},
	},
	["zlw-opl"] = {
		peri_comp = "barziej",
		sup = false,
		-- participle endings
		act = false,
		pass = false,
		cont_adv = false,
		ant_adv = false,
	},
	["pox"] = {
		peri_comp = false,
		sup = false,
		-- participle endings
		act = false,
		pass = false,
		cont_adv = false,
		ant_adv = false,
		has_dual = true,
	},
	["zlw-slv"] = {
		peri_comp = false,
		sup = false,
		-- participle endings
		act = false,
		pass = false,
		cont_adv = false,
		ant_adv = false,
		has_dual = true,
	},
}

----------------------------------------------- Utilities --------------------------------------------

local function track(page)
	require("Module:debug").track("zlw-lch-headword/" .. page)
	return true
end

local function glossary_link(entry, text)
	text = text or entry
	return "[[Appendix:Glossary#" .. entry .. "|" .. text .. "]]"
end

local param_mods = {
	g = {
		-- We need to store the <g:...> inline modifier into the "genders" key of the parsed part, because that is what
		-- [[Module:links]] expects.
		item_dest = "genders",
		convert = function(arg, parse_err)
			return rsplit(arg, ",")
		end,
	},
	id = {},
	q = {store = "insert"},
	qq = {store = "insert"},
}

-- Parse the inflections specified by the raw arguments in `infls`. `pagename` is the pagename, used to substitute
-- # in arguments. Parse inline modifiers attached to the raw arguments. Return `infls` if there are any inflections,
-- otherwise nil. WARNING: Destructively modifies `infls`.
local function parse_inflection(infls, pagename)
	local function generate_obj(term, parse_err)
		return {term = term:gsub("#", pagename)}
	end

	for i, infl in ipairs(infls) do
		-- Check for inline modifier, e.g. acetylenowo<q:rare>.
		if infl:find("<") then
			infl = require(parse_utilities_module).parse_inline_modifiers(infl, {
				param_mods = param_mods,
				generate_obj = generate_obj,
			})
		else
			infl = generate_obj(infl)
		end

		infls[i] = infl
	end
	if #infls > 0 then
		return infls
	else
		return nil
	end
end


-- Insert the parsed inflections in `infls` (as parsed by `parse_inflection`) into `data.inflections`, with label
-- `label` and optional accelerator spec `accel`.
local function insert_inflection(data, infls, label, accel)
	if infls and #infls > 0 then
		if #infls == 1 and (infls[1] == "-" or infls[1].term == "-") then
			if infls[1].q then
				error(("Can't specify qualifiers with the value '-' for %s"):format(label))
			end
			table.insert(data.inflections, {label = "no " .. label})
		else
			infls.label = label
			infls.accel = accel
			table.insert(data.inflections, infls)
		end
	end
end


----------------------------------------------- Main entry point --------------------------------------------

function export.show(frame)
	local iparams = {
		[1] = {required = true},
		["lang"] = {required = true},
	}

	local iargs = require("Module:parameters").process(frame.args, iparams)
	local poscat = iargs[1]
	langcode = iargs.lang
	if not langs_supported[langcode] then
		local langcodes_supported = {}
		for lang, _ in pairs(langs_supported) do
			table.insert(langcodes_supported, lang)
		end
		error("This module currently only works for lang=" .. table.concat(langcodes_supported, "/"))
	end
	local lang = require("Module:languages").getByCode(langcode)
	local langname = lang:getCanonicalName()

	local params = {
		["head"] = {list = true},
		["nolink"] = {type = "boolean"},
		["nolinkhead"] = {type = "boolean", alias_of = "nolink"},
		["suffix"] = {type = "boolean"},
		["nosuffix"] = {type = "boolean"},
		["json"] = {type = "boolean"},
		["abbr"] = {list = true},
		["pagename"] = {}, -- for testing
	}

	if pos_functions[poscat] then
		local posparams = pos_functions[poscat].params
		if type(posparams) == "function" then
			posparams = posparams(langcode)
		end
		for key, val in pairs(posparams) do
			params[key] = val
		end
	end

	local parargs = frame:getParent().args
	local args = require("Module:parameters").process(parargs, params)

	local pagename = args.pagename or mw.title.getCurrentTitle().subpageText

	local user_specified_heads = args.head
	local heads = user_specified_heads
	if args.nolink then
		if #heads == 0 then
			heads = {pagename}
		end
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
		genders = {},
		inflections = {},
		categories = {},
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
	end

	if pos_functions[poscat] then
		pos_functions[poscat].func(args, data)
	end

	local abbrs = parse_inflection(args.abbr, pagename)
	insert_inflection(data, abbrs, "abbreviation")

	if args.json then
		return require("Module:JSON").toJSON(data)
	end

	return require("Module:headword").full_headword(data)
end


----------------------------------------------- Nouns --------------------------------------------

local function get_noun_inflection_specs(langcode)
	local noun_inflection_specs = {
		{"gen", "genitive singular"},
	}
	if langs_supported[langcode].has_dual then
		table.insert(noun_inflection_specs, {"du", "nominative dual"})
	end
	for _, spec in ipairs {
		{"pl", "nominative plural"},
		{"genpl", "genitive plural"},
		{"f", "female equivalent"},
		{"m", "male equivalent"},
		{"n", "neuter equivalent"},
		{"dim", "diminutive"},
		{"pej", "pejorative"},
		{"aug", "augmentative"},
		{"adj", "related adjective"},
		{"poss", "possessive adjective"},
		{"dem", "demonym"},
		{"fdem", "female demonym"},
	} do
		table.insert(noun_inflection_specs, spec)
	end
	return noun_inflection_specs
end
	
local function get_noun_pos(is_proper)

	return {
		params = function(langcode)
			local params = {
				["indecl"] = {type = "boolean"},
				[1] = {list = "g"},
			}
			for _, spec in ipairs(get_noun_inflection_specs(langcode)) do
				local param, desc = unpack(spec)
				params[param] = {list = true, disallow_holes = true}
			end
			params["rel"] = {list = true, disallow_holes = true, alias_of = "adj"}
			return params
		end,
		func = function(args, data)
			-- Compute allowed genders, and map incomplete genders to specs with a "?" in them.
			local genders = {false, "m", "mf", "mfbysense", "f", "n", "g!"}
			local animacies = {false, "in", "anml", "pr", "an!"}
			local numbers = {false, "p", "num!"}
			local allowed_genders = {}
			
			for _, g in ipairs(genders) do
				for _, an in ipairs(animacies) do
					for _, num in ipairs(numbers) do
						local source_gender_parts = {}
						local dest_gender_parts = {}
						local function ins_part(part, partname)
							if part then
								table.insert(source_gender_parts, part)
								table.insert(dest_gender_parts, part)
							elseif partname == "g" and num == false or
								partname == "an" and g ~= "f" and g ~= "n" then
								-- allow incomplete gender plurale tantum nouns; also allow incomplete
								-- animacy for fem/neut, where it makes no difference for agreement
								-- purposes; otherwise insert a ? to indicate incomplete gender spec
								table.insert(dest_gender_parts, "?")
							end
						end
						ins_part(g, "g")
						ins_part(an, "an")
						ins_part(num, "num")
						if #source_gender_parts == 0 then
							allowed_genders["?"] = "?"
						else
							allowed_genders[table.concat(source_gender_parts, "-")] =
								table.concat(dest_gender_parts, "-")
						end
						-- "Virile" = masculine personal, allow in the plural and convert appropriately;
						-- "Nonvirile" = anything but masculine personal, allow in the plural;
						-- "Nonpersonal" = anything but personal, i.e. animal or inanimate; allow in the plural.
						allowed_genders["vr-p"] = "m-pr-p"
						allowed_genders["nv-p"] = "nv-p"
						allowed_genders["np-p"] = "np-p"
					end
				end
			end
			
			-- Gather, validate and canonicalize genders
			for _, gspec in ipairs(args[1]) do
				for _, g in ipairs(rsplit(gspec, ",")) do
					if not allowed_genders[g] then
						error("Unrecognized " .. data.langname .. " gender: " .. g)
					else
						table.insert(data.genders, allowed_genders[g])
					end
				end
			end

			if args.indecl then
				table.insert(data.inflections, {label = glossary_link("indeclinable")})
				table.insert(data.categories, data.langname .. " indeclinable nouns")
			end

			-- Process all inflections.
			for _, spec in ipairs(get_noun_inflection_specs(data.langcode)) do
				local param, desc = unpack(spec)
				local infls = parse_inflection(args[param], data.pagename)
				insert_inflection(data, infls, desc)
			end
		end
	}
end

pos_functions["nouns"] = get_noun_pos(false)

pos_functions["proper nouns"] = get_noun_pos(true)


----------------------------------------------- Verbs --------------------------------------------

local function get_verb_pos()
	local verb_inflection_specs = {
		-- order per old [[Module:pl-headword]]
		{"det", "imperfective determinate"},
		{"pf", "perfective"},
		{"impf", "imperfective"},
		{"indet", "indeterminate"},
		{"freq", "frequentative"},
	}
	
	local params = {
		[1] = {default = "?"},
		["def"] = {type = "boolean"},
	}
	for _, spec in ipairs(verb_inflection_specs) do
		local param, desc = unpack(spec)
		params[param] = {list = true, disallow_holes = true}
	end

	return {
		params = params,
		func = function(args, data)
			local allowed_aspects = require("Module:table/listToSet") {
				"pf", "impf", "biasp", "both", "impf-det", "impf-indet", "impf-freq", "?"
			}

			-- Gather aspects
			for _, a in ipairs(rsplit(args[1], ",")) do
				table.insert(data.genders, a)
			end

			local impf_allowed = true
			local pf_allowed = true
			local indet_allowed = true
			local det_allowed = true
			local freq_allowed = true
			local function insert_label_and_cat(typ)
				table.insert(data.inflections, {label = glossary_link(typ)})
				table.insert(data.categories, data.langname .. " " .. typ .. " verbs")
			end

			-- Validate and canonicalize aspects.
			for i, a in ipairs(data.genders) do
				if not allowed_aspects[a] then
					error("Unrecognized " .. data.langname .. " aspect: " .. a)
				elseif a == "both" then
					a = "biasp"
				elseif a == "impf-det" then
					a = "impf"
					insert_label_and_cat("determinate")
					det_allowed = false
				elseif a == "impf-indet" then
					a = "impf"
					insert_label_and_cat("indeterminate")
					indet_allowed = false
				elseif a == "impf-freq" then
					a = "impf"
					insert_label_and_cat("indeterminate")
					insert_label_and_cat("frequentative")
					indet_allowed = false
					freq_allowed = false
				elseif a == "pf" then
					pf_allowed = false
				elseif a == "impf" then
					impf_allowed = false
				end
				data.genders[i] = a
			end

			if args.def then
				insert_label_and_cat("defective")
			end

			-- Process all inflections.
			for _, spec in ipairs(verb_inflection_specs) do
				local param, desc = unpack(spec)
				local infls = parse_inflection(args[param], data.pagename)
				if infls then
					if param == "pf" and not pf_allowed then
						error("Aspectual-pair perfectives not allowed with perfective-only verb")
					end
					if param == "impf" and not impf_allowed then
						error("Aspectual-pair imperfectives not allowed with imperfective-only verb")
					end
					if param == "det" and not det_allowed then
						error("Aspectual-pair determinates not allowed with imperfective-only determinate verb")
					end
					if param == "indet" and not indet_allowed then
						error("Aspectual-pair indeterminates not allowed with imperfective-only indeterminate or frequentative verb")
					end
					if param == "freq" and not freq_allowed then
						error("Aspectual-pair frequentatives not allowed with imperfective-only frequentative verb")
					end
					insert_inflection(data, infls, desc)
				end
			end
		end
	}
end

pos_functions["verbs"] = get_verb_pos()


----------------------------------------------- Adjectives, Adverbs --------------------------------------------

local function get_adj_adv_pos(pos)
	return {
		params = function(langcode)
			local params = {
				[1] = {list = true, disallow_holes = true},
				["dim"] = {list = true, disallow_holes = true},
				["sup"] = {list = true, disallow_holes = true},
				["nodefsup"] = {type = "boolean"},
			}
			if pos == "adjective" then
				params["adv"] = {list = true, disallow_holes = true}
				params["indecl"] = {type = "boolean"}
			end
			if langcode == "pl" then
				params["mpcomp"] = {list = true, disallow_holes = true}
				params["mpsup"] = {list = true, disallow_holes = true}
			end
			return params
		end,
		func = function(args, data)
			local comps = parse_inflection(args[1], data.pagename)
			if comps then
				lang_data = langs_supported[data.langcode]
				if comps[1].term == "-" then
					if comps[1].q then
						error("Can't specify qualifiers with 1=-")
					end
					if #comps == 1 then
						table.insert(data.inflections, {label = "not " .. glossary_link("comparable")})
						table.insert(data.categories, data.langname .. " uncomparable " .. data.pos_category)
					else
						table.insert(data.inflections, {label = "not generally " .. glossary_link("comparable")})
					end
					table.remove(comps, 1)
				end
				local default_sups = {}
				for i, comp in ipairs(comps) do
					if comp.term == "peri" then
						if not lang_data.peri_comp then
							error("Don't know how to form periphrastic comparatives for " .. data.langname)
						end
						comp.term = ("[[%s]] [[%s]]"):format(lang_data.peri_comp, data.pagename)
						if lang_data.sup then
							table.insert(default_sups, {term = ("[[%s%s]] [[%s]]"):format(
								lang_data.sup, lang_data.peri_comp, data.pagename), q = comp.q, qq = comp.qq, id = comp.id})
						end
					elseif lang_data.sup then
						table.insert(default_sups, {term = ("%s%s"):format(lang_data.sup, comp.term), q = comp.q, qq = comp.qq,
							id = comp.id})
					end
				end
				local sups = parse_inflection(args.sup, data.pagename)
				if not sups then
					sups = args.nodefsup and {} or {{term = "+"}}
				end
				local combined_sups = {}
				local function combine_qualifiers(q1, q2)
					if not q1 then
						return q2
					end
					if not q2 then
						return q1
					end
					local combined = {}
					for _, q in ipairs(q1) do
						table.insert(combined, q)
					end
					for _, q in ipairs(q2) do
						table.insert(combined, q)
					end
					return combined
				end
				for _, sup in ipairs(sups) do
					if sup.term == "+" then
						for _, def_sup in ipairs(default_sups) do
							def_sup.q = combine_qualifiers(def_sup.q, sup.q)
							def_sup.qq = combine_qualifiers(def_sup.qq, sup.qq)
							def_sup.id = def_sup.id or sup.id
							table.insert(combined_sups, def_sup)
						end
					else
						table.insert(combined_sups, sup)
					end
				end
				insert_inflection(data, comps, "comparative", {form = "comparative"})
				insert_inflection(data, combined_sups, "superlative", {form = "superlative"})
				if data.langcode == "pl" then
					local mpcomp = parse_inflection(args.mpcomp, data.pagename)
					insert_inflection(data, mpcomp, "Middle Polish comparative")
					local mpsup = parse_inflection(args.mpsup, data.pagename)
					insert_inflection(data, mpsup, "Middle Polish superlative")
				end
			end
			if pos == "adjective" then
				if args.indecl then
					table.insert(data.inflections, {label = glossary_link("indeclinable")})
					table.insert(data.categories, data.langname .. " indeclinable adjectives")
				end
				local infls = parse_inflection(args.adv, data.pagename)
				insert_inflection(data, infls, "derived adverb")
			end
			local infls = parse_inflection(args.dim, data.pagename)
			insert_inflection(data, infls, "diminutive")
		end,
	}
end

pos_functions["adjectives"] = get_adj_adv_pos("adjective")
pos_functions["adverbs"] = get_adj_adv_pos("adverb")


----------------------------------------------- Participles --------------------------------------------

local function get_part_pos()
	local params = {
		[1] = {},
		["a"] = {list = true, disallow_holes = true},
	}

	return {
		params = params,
		func = function(args, data)
			if data.langcode ~= "pl" then
				error("Internal error: Unable to handle languages other than Polish for participles: " .. data.langname)
			end
			-- Compute allowed aspects, and map incomplete aspects to specs with a "?" in them.
			local allowed_aspects = require("Module:table/listToSet") {
				"pf", "impf", "biasp", "both", "pf-it", "pf-sem", "impf-it", "impf-dur", "?"
			}
			local allowed_types = require("Module:table/listToSet") {
				"pass", "act", "ant-adv", "cont-adv", "?"
			}

			-- Gather aspects
			data.genders = args.a

			local function insert_label_and_cat(label, nolink)
				if not nolink then
					label = glossary_link(label)
				end
				table.insert(data.inflections, {label = label})
				table.insert(data.categories, data.langname .. " " .. label .. " participles")
			end

			-- Validate and canonicalize aspects
			for i, g in ipairs(data.genders) do
				if not allowed_aspects[g] then
					error("Unrecognized " .. data.langname .. " participle aspect: " .. g)
				elseif g == "both" then
					g = "biasp"
				elseif g == "impf-it" then
					g = "impf"
					insert_label_and_cat("iterative")
				elseif g == "impf-dur" then
					g = "impf"
					insert_label_and_cat("durative")
				elseif g == "pf-it" then
					g = "pf"
					insert_label_and_cat("iterative")
				elseif g == "pf-sem" then
					g = "pf"
					insert_label_and_cat("semelfactive")
				end
				data.genders[i] = g
			end

			-- Validate or autodetect participle type.
			local function matches_parttype(typ)
				local endings = langs_supported[data.langcode][typ]
				if not endings then
					return false
				end
				for _, ending in ipairs(endings) do
					if rfind(data.pagename, ending) then
						return true
					end
				end
				return false
			end
			local ptype = args[1]
			if ptype then
				if not allowed_types[ptype] then
					error("Unrecognized " .. data.langname .. " participle type: " .. ptype)
				end
			elseif matches_parttype("act") then -- biegnący
				ptype = "act"			
			elseif matches_parttype("pass") then -- otwarty, uwielbiany, legły
				ptype = "pass"
			elseif matches_parttype("cont_adv") then
				ptype = "cont-adv"
			elseif matches_parttype("ant_adv") then
				ptype = "ant-adv"
			elseif (data.pagename:find("%-participle$") or data.pagename:find("%-part$")) and
				mw.title.getCurrentTitle().nsText == "Template" then
				ptype = "pass"
			else
				error(("Missing %s participle type and can't infer from pagename '%s'"):format(data.langname,
					data.pagename))
			end

			if ptype == "act" then
				insert_label_and_cat("active adjectival", true)
			elseif ptype == "pass" then
				insert_label_and_cat("passive adjectival", true)
			elseif ptype == "cont-adv" then
				insert_label_and_cat("contemporary adverbial", true)
			elseif ptype == "ant-adv" then
				insert_label_and_cat("anterior adverbial", true)
			end
		end
	}
end

pos_functions["participles"] = get_part_pos()


return export
