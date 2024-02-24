local export = {}
local pos_functions = {}

local function track(page)
	require("Module:debug").track("lech-headword/" .. page)
	return true
end

local function glossary_link(entry, text)
	text = text or entry
	return "[[Appendix:Glossary#" .. entry .. "|" .. text .. "]]"
end

-- The main entry point.
-- This is the only function that can be invoked from a template.
function export.show(frame)
	local iparams = {
		[1] = {required = true},
		["lang"] = {required = true},
	}

	local iargs = require("Module:parameters").process(frame.args, iparams)
	local poscat = iargs[1]
	langcode = iargs.lang
	if langcode ~= "pl" and langcode ~= "szl" and langcode ~= "csb" and lanbcode ~= "zlw-mas" then
		error("This module currently only works for lang=pl/szl/csb/zlw-mas")
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
		["pagename"] = {}, -- for testing
	}

	if pos_functions[poscat] then
		for key, val in pairs(pos_functions[poscat].params) do
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

	if args.json then
		return require("Module:JSON").toJSON(data)
	end

	return require("Module:headword").full_headword(data)
end


----------------------------------------------- Utilities --------------------------------------------

local function fetch_inflection(infls, quals, frob, canonicalize_infl)
	for i, infl in ipairs(infls) do
		if frob then
			infl = frob(infl)
		end
		if quals[i] then
			infls[i] = {term = infl, q = {quals[i]}}
		elseif canonicalize_infl then
			infls[i] = {term = infl}
		end
	end
	if #infls > 0 then
		return infls
	else
		return nil
	end
end


local function insert_inflection(data, infls, label, accel)
	if infls and #infls > 0 then
		infls.label = label
		infls.accel = accel
		table.insert(data.inflections, infls)
	end
end


----------------------------------------------- Nouns --------------------------------------------

local function get_noun_pos(is_proper)
	local noun_inflection_specs = {
		{"gen", "genitive singular"},
		{"pl", "nominative plural"},
		{"genpl", "genitive plural"},
		{"f", "feminine"},
		{"m", "masculine"},
		{"dim", "diminutive"},
		{"pej", "pejorative"},
		{"aug", "augmentative"},
		{"adj", "related adjective"},
		{"dem", "demonym"},
		{"fdem", "female demonym"},
	}
	
	local params = {
		["indecl"] = {type = "boolean"},
		[1] = {list = "g"},
	}
	for _, spec in ipairs(noun_inflection_specs) do
		local param, desc = unpack(spec)
		params[param] = {list = true, disallow_holes = true}
		params[param .. "\1q"] = {list = true, allow_holes = true}
	end

	return {
		params = params,
		func = function(args, data)
			-- Compute allowed genders, and map incomplete genders to specs with a "?" in them.
			local genders = {false, "m", "mf", "mfbysense", "f", "n"}
			local animacies = {false, "in", "anml", "pr"}
			local numbers = {false, "p"}
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
			
			-- Gather genders
			data.genders = args[1]

			-- Validate and canonicalize genders
			for i, g in ipairs(data.genders) do
				if not allowed_genders[g] then
					error("Unrecognized " .. data.langname .. " gender: " .. g)
				else
					data.genders[i] = allowed_genders[g]
				end
			end

			if args.indecl then
				table.insert(data.inflections, {label = glossary_link("indeclinable")})
			end

			-- Process all inflections.
			for _, spec in ipairs(noun_inflection_specs) do
				local param, desc = unpack(spec)
				local infls = fetch_inflection(args[param], args[param .. "q"])
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
		[1] = {list = "g", default = "?"},
	}
	for _, spec in ipairs(verb_inflection_specs) do
		local param, desc = unpack(spec)
		params[param] = {list = true, disallow_holes = true}
		params[param .. "\1q"] = {list = true, allow_holes = true}
	end

	return {
		params = params,
		func = function(args, data)
			-- Compute allowed genders, and map incomplete genders to specs with a "?" in them.
			local allowed_genders require("table/listToSet") {
				"pf", "impf", "biasp", "both", "impf-det", "impf-indet", "impf-freq", "?"
			}

			-- Gather genders
			data.genders = args[1]

			local impf_allowed = true
			local pf_allowed = true
			local indet_allowed = true
			local det_allowed = true
			local freq_allowed = true
			local function insert_label_and_cat(typ)
				table.insert(data.inflections, {label = glossary_link(typ)})
				table.insert(data.categories, data.langname .. " " .. typ .. " verbs")
			end

			-- Validate and canonicalize genders
			for i, g in ipairs(data.genders) do
				if not allowed_genders[g] then
					error("Unrecognized " .. data.langname .. " gender: " .. g)
				elseif g == "both" then
					g = "biasp"
				elseif g == "impf-det" then
					g = "impf"
					insert_label_and_cat("determinate")
					det_allowed = false
				elseif g == "impf-indet" then
					g = "impf"
					insert_label_and_cat("indeterminate")
					indet_allowed = false
				elseif g == "impf-freq" then
					g = "impf"
					insert_label_and_cat("indeterminate")
					insert_label_and_cat("frequentative")
					indet_allowed = false
					freq_allowed = false
				end
				data.genders[i] = g
				if g == "pf" then
					pf_allowed = false
				elseif g == "impf" then
					impf_allowed = false
				end
			end

			-- Process all inflections.
			for _, spec in ipairs(verb_inflection_specs) do
				local param, desc = unpack(spec)
				local infls = fetch_inflection(args[param], args[param .. "q"])
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
	}
end

pos_functions["verbs"] = get_verb_pos()


----------------------------------------------- Adjectives, Adverbs --------------------------------------------

local function get_adj_adv_pos(pos)
	return {
		params = {
			[1] = {list = true, disallow_holes = true},
			["q"] = {list = true, allow_holes = true},
		}
		func = function(args, data)
			local comps = fetch_inflection(args[1], args.q, nil, "canonicalize infl")
			local comp_data = {
				["pl"] = {peri_comp = "bardziej", sup = "naj"},
				["zlw-mas"] = {peri_comp = "barżi", sup = "ná"},
				["csb"] = {peri_comp = "barżi", sup = "nô"},
				["szl"] = {peri_comp = "bardzij", sup = "noj"},
			}
			comp_data = comp_data[data.langcode]
			if comps[1].term == "-" then
				if comps[1].q then
					error("Can't specify qualifiers with 1=-")
				end
				if #comps == 1 then
					table.insert(data.inflections, {label = "not " .. glossary_link("comparable")})
					table.insert(data.categories, langname .. " uncomparable adjectives")
					return
				end
				table.insert(data.inflections, {label = "not generally " .. glossary_link("comparable")})
				table.remove(comps, 1)
			end
			local sups = {}
			for i, comp in ipairs(comps) do
				if comp.term == "+" or comp.term == "b" then
					comp.term = ("[[%s]] [[%s]]"):format(comp_data.peri_comp, data.pagename)
					table.insert(sups, {term = ("[[%s%s]] [[%s]]"):format(
						comp_data.sup, comp_data.peri_comp, data.pagename), q = comp.q})
				else
					table.insert(sups, {term = ("%s%s"):format(comp_data.sup, comp.term), q = comp.q})
				end
			end
			insert_inflection(data, comps, "comparative", {form = "comparative"})
			insert_inflection(data, sups, "superlative", {form = "superlative"})
		end,
	}
end

pos_functions["adjectives"] = get_adj_adv_pos("adjective")
pos_functions["adverbs"] = get_adj_adv_pos("adverb")


----------------------------------------------- Participles --------------------------------------------

local function get_part_pos()
	local part_inflection_specs = {
		-- order per old [[Module:pl-headword]]
		{"det", "imperfective determinate"},
		{"pf", "perfective"},
		{"impf", "imperfective"},
		{"indet", "indeterminate"},
		{"freq", "frequentative"},
	}
	
	local params = {
		[1] = {list = "g", default = "?"},
	}
	for _, spec in ipairs(part_inflection_specs) do
		local param, desc = unpack(spec)
		params[param] = {list = true, disallow_holes = true}
		params[param .. "\1q"] = {list = true, allow_holes = true}
	end

	return {
		params = params,
		func = function(args, data)
			-- Compute allowed genders, and map incomplete genders to specs with a "?" in them.
			local allowed_genders require("table/listToSet") {
				"pf", "impf", "biasp", "both", "impf-det", "impf-indet", "impf-freq", "?"
			}

			-- Gather genders
			data.genders = args[1]

			local impf_allowed = true
			local pf_allowed = true
			local indet_allowed = true
			local det_allowed = true
			local freq_allowed = true
			local function insert_label_and_cat(typ)
				table.insert(data.inflections, {label = glossary_link(typ)})
				table.insert(data.categories, data.langname .. " " .. typ .. " parts")
			end

			-- Validate and canonicalize genders
			for i, g in ipairs(data.genders) do
				if not allowed_genders[g] then
					error("Unrecognized " .. data.langname .. " gender: " .. g)
				elseif g == "both" then
					g = "biasp"
				elseif g == "impf-det" then
					g = "impf"
					insert_label_and_cat("determinate")
					det_allowed = false
				elseif g == "impf-indet" then
					g = "impf"
					insert_label_and_cat("indeterminate")
					indet_allowed = false
				elseif g == "impf-freq" then
					g = "impf"
					insert_label_and_cat("indeterminate")
					insert_label_and_cat("frequentative")
					indet_allowed = false
					freq_allowed = false
				end
				data.genders[i] = g
				if g == "pf" then
					pf_allowed = false
				elseif g == "impf" then
					impf_allowed = false
				end
			end

			-- Process all inflections.
			for _, spec in ipairs(part_inflection_specs) do
				local param, desc = unpack(spec)
				local infls = fetch_inflection(args[param], args[param .. "q"])
				if param == "pf" and not pf_allowed then
					error("Aspectual-pair perfectives not allowed with perfective-only part")
				end
				if param == "impf" and not impf_allowed then
					error("Aspectual-pair imperfectives not allowed with imperfective-only part")
				end
				if param == "det" and not det_allowed then
					error("Aspectual-pair determinates not allowed with imperfective-only determinate part")
				end
				if param == "indet" and not indet_allowed then
					error("Aspectual-pair indeterminates not allowed with imperfective-only indeterminate or frequentative part")
				end
				if param == "freq" and not freq_allowed then
					error("Aspectual-pair frequentatives not allowed with imperfective-only frequentative part")
				end
				insert_inflection(data, infls, desc)
			end
		end
	}
end

pos_functions["participles"] = get_part_pos()


return export
