local export = {}

local lang, langcode, langname
local com
local iut = require("Module:inflection utilities")
local m_links = require("Module:links")
local m_string_utilities = require("Module:string utilities")
local m_table = require("Module:table")

local rfind = mw.ustring.find


local pos_functions = {}


local function track(page)
	require("Module:debug").track(langcode .. "-headword/" .. page)
	return true
end


local function check_if_accents_needed(list, data)
	for _, val in ipairs(list) do
		val = m_links.remove_links(val)
		if com.needs_accents(val) then
			if langcode == "uk" and not data.unknown_stress then
				error("Stress must be supplied using an acute accent: '" .. val .. "' (use unknown_stress=1 if stress is truly unknown)")
			end
			local pos = m_string_utilities.singularize(data.pos_category)
			table.insert(data.categories, "Requests for accents in " .. langname .. " " .. pos .. " entries")
		end
		if com.is_multi_stressed(val) then
			error("Multi-stressed form '" .. val .. "' not allowed")
		end
	end
end


-- The main entry point.
-- This is the only function that can be invoked from a template.
function export.show(frame)
	local args = frame:getParent().args
	local PAGENAME = mw.loadData("Module:headword/data").pagename

	local iparams = {
		[1] = {required = true},
		["lang"] = {required = true},
	}

	local iargs = require("Module:parameters").process(frame.args, iparams)
	local poscat = iargs[1]
	langcode = iargs.lang
	if langcode ~= "uk" and langcode ~= "be" then
		error("This module currently only works for lang=uk and lang=be")
	end
	lang = require("Module:languages").getByCode(langcode)
	langname = langcode == "uk" and "Ukrainian" or "Belarusian"
	com = langcode == "uk" and require("Module:uk-common") or require("Module:be-common")

	local data = {lang = lang, pos_category = poscat, categories = {}, genders = {}, inflections = {}}

	local params = {
		[1] = {list = "head"},
		["tr"] = {list = true, allow_holes = true},
		["unknown_stress"] = {type = "boolean"},
	}

	if pos_functions[poscat] then
		for key, val in pairs(pos_functions[poscat].params) do
			params[key] = val
		end
	end

	local parargs = frame:getParent().args
	local args = require("Module:parameters").process(parargs, params)

	local heads = args[1]
	if #heads == 0 then
		heads = {PAGENAME}
	end

	data.heads = heads
	data.translits = args.tr
	data.unknown_stress = args.unknown_stress
	data.frame = frame

	if args.unknown_stress then
		table.insert(data.inflections, {label = "unknown stress"})
	end

	if pos_functions[poscat] and not pos_functions[poscat].no_check_head_accents then
		check_if_accents_needed(heads, data)
	end

	if pos_functions[poscat] then
		pos_functions[poscat].func(args, data)
	end

	return require("Module:headword").full_headword(data) .. (data.extra_text or "")
end


local function make_gloss_text(text)
	return '<span class="gloss-brac">(</span>' ..
		'<span class="gloss-content">' .. text ..
		'</span><span class="gloss-brac">)</span>'
end


local function get_noun_pos(is_proper)
	return {
		params = {
			[2] = {alias_of = "g"},
			[3] = {list = "gen"},
			[4] = {list = "pl"},
			[5] = {list = "genpl"},
			["lemma"] = {list = true},
			["g"] = {list = true},
			["m"] = {list = true},
			["f"] = {list = true},
			["adj"] = {list = true},
			["dim"] = {list = true},
			["aug"] = {list = true},
			["pej"] = {list = true},
			["dem"] = {list = true},
			["fdem"] = {list = true},
			["unknown_gender"] = {type = "boolean"},
			["unknown_animacy"] = {type = "boolean"},
			["id"] = {},
		},
		-- set this to avoid problems with cases like {{uk-noun|((ґандж<>,ґандж<F>))}},
		-- which will otherwise throw an error
		no_check_head_accents = true,
		func = function(args, data)
			local genitives, plurals, genitive_plurals
			if rfind(data.heads[1], "<") then
				local parargs = data.frame:getParent().args
				local alternant_spec = require("Module:" .. langcode .. "-noun").do_generate_forms(parargs, nil, true)
				args = alternant_spec.args
				local footnote_obj

				local function get_raw_forms(forms)
					local raw_forms = {}
					if forms then
						for _, form in ipairs(forms) do
							local text =
								langcode == "uk" and com.remove_monosyllabic_stress(form.form) or
								com.remove_monosyllabic_accents(form.form)
							if form.footnotes then
								if not footnote_obj then
									footnote_obj = iut.create_footnote_obj()
								end
								local footnote_text = iut.get_footnote_text(form, footnote_obj)
								if rfind(text, "%[%[") then
									text = text .. footnote_text
								else
									text = "[[" .. text .. "]]" .. footnote_text
								end
							end
							table.insert(raw_forms, text)
						end
					end
					if #raw_forms == 0 then
						raw_forms = {"-"}
					end
					return raw_forms
				end

				if alternant_spec.number == "pl" then
					data.heads = #args.lemma > 0 and args.lemma or get_raw_forms(alternant_spec.forms.nom_p_linked)
					genitives = get_raw_forms(alternant_spec.forms.gen_p)
					plurals = {"-"}
					genitive_plurals = {"-"}
				else
					data.heads = #args.lemma > 0 and args.lemma or get_raw_forms(alternant_spec.forms.nom_s_linked)
					genitives = get_raw_forms(alternant_spec.forms.gen_s)
					if alternant_spec.number == "sg" then
						plurals = {"-"}
						genitive_plurals = {"-"}
					else
						plurals = get_raw_forms(alternant_spec.forms.nom_p)
						genitive_plurals = get_raw_forms(alternant_spec.forms.gen_p)
					end
				end
				if #args.g > 0 then
					data.genders = args.g
				else
					data.genders = alternant_spec.genders
				end

				local notes_segments = {}
				if footnote_obj then
					for _, note in ipairs(footnote_obj.notes) do
						table.insert(notes_segments, " " .. make_gloss_text(note))
					end
				end
				data.extra_text = table.concat(notes_segments, "")
			else
				check_if_accents_needed(data.heads, data)
				data.genders = args.g
				if #data.genders == 0 then
					if mw.title.getCurrentTitle().nsText ~= "Template" then
						error("Gender must be specified")
					else
						table.insert(data.genders, "m-in")
					end
				end

				genitives = args[3]
				plurals = args[4]
				genitive_plurals = args[5]

				if genitives[1] ~= "-" then
					-- don't track for indeclinables, which legitimately use the old-style syntax
					track(langcode .. "-noun-old-style")
				end
			end

			-- Process the genders
			local singular_genders = {}
			local plural_genders = {}

			local allowed_genders = {"m", "f", "n", "mf", "mfbysense"}
			if langcode == "be" or args.unknown_gender then
				table.insert(allowed_genders, "?")
			end
			local allowed_animacies = {"pr", "anml", "in"}
			if langcode == "be" or args.unknown_animacy then
				table.insert(allowed_animacies, "?")
			end
			
			for _, gender in ipairs(allowed_genders) do
				for _, animacy in ipairs(allowed_animacies) do
					singular_genders[gender .. "-" .. animacy] = true
					plural_genders[gender .. "-" .. animacy .. "-p"] = true
				end
			end
			
			if langcode == "be" then
				singular_genders["?"] = true
				plural_genders["?-p"] = true
			end

			local seen_gender = nil
			local seen_animacy = nil

			for i, g in ipairs(data.genders) do
				if not singular_genders[g] and not plural_genders[g] then
					if g:match("%-an%-") or g:match("%-an$") then
						error("Invalid animacy 'an'; use 'pr' for people, 'anml' for animals: " .. g)
					end
					error("Unrecognized gender: " .. g .. " (should be e.g. 'm-pr' for masculine personal, 'f-anml-p' for feminine animal plural, or 'n-in' for neuter inanimate)")
				end

				data.genders[i] = g
			end

			-- Add the genitive forms
			if genitives[1] == "-" then
				table.insert(data.inflections, {label = "[[Appendix:Glossary#indeclinable|indeclinable]]"})
				table.insert(data.categories, langname .. " indeclinable nouns")
			else
				genitives.label = "genitive"
				genitives.request = true
				check_if_accents_needed(genitives, data)
				table.insert(data.inflections, genitives)
			end

			-- Add the plural forms
			-- If the noun is plural only, then ignore the 4th and 5th parameters altogether
			if genitives[1] == "-" then
				-- do nothing
			elseif plural_genders[data.genders[1]] then
				table.insert(data.inflections, {label = "[[Appendix:Glossary#plural only|plural only]]"})
			elseif plurals[1] == "-" then
				table.insert(data.inflections, {label = "[[Appendix:Glossary#uncountable|uncountable]]"})
				table.insert(data.categories, langname .. " uncountable nouns")
			else
				plurals.label = "nominative plural"
				plurals.request = true
				check_if_accents_needed(plurals, data)
				table.insert(data.inflections, plurals)
				if #genitive_plurals > 0 then
					-- allow the genitive plural to be unsupplied; formerly there
					-- was no genitive plural param
					if genitive_plurals[1] == "-" then
						-- handle case where there's no genitive plural (e.g. ага́)
						table.insert(data.inflections, {label = "no genitive plural"})
					else
						genitive_plurals.label = "genitive plural"
						check_if_accents_needed(genitive_plurals, data)
						table.insert(data.inflections, genitive_plurals)
					end
				end
			end

			local function handle_infl(arg, label)
				local vals = args[arg]
				if #vals > 0 then
					vals.label = label
					check_if_accents_needed(vals, data)
					table.insert(data.inflections, vals)
				end
			end

			handle_infl("m", "masculine")
			handle_infl("f", "feminine")
			handle_infl("adj", "relational adjective")
			handle_infl("dim", "diminutive")
			handle_infl("aug", "augmentative")
			handle_infl("pej", "pejorative")
			handle_infl("dem", "demonym")
			handle_infl("fdem", "female demonym")

			data.id = args.id
		end
	}
end


pos_functions["proper nouns"] = get_noun_pos(true)
pos_functions["nouns"] = get_noun_pos(false)


pos_functions["verbs"] = {
	params = {
		[2] = {default = "?"},
		["pf"] = {list = true},
		["impf"] = {list = true},
	},
	func = function(args, data)
		-- Aspect
		local aspect = args[2]

		if aspect == "both" then
			aspect = "biasp"
		elseif aspect ~= "pf" and aspect ~= "impf" and aspect ~= "biasp" and aspect ~= "?" then
			error("Unrecognized aspect: '" .. aspect .. "'")
		end
		table.insert(data.genders, aspect)

		-- Get the imperfective parameters
		local imperfectives = args["impf"]
		-- Get the perfective parameters
		local perfectives = args["pf"]

		check_if_accents_needed(imperfectives, data)
		check_if_accents_needed(perfectives, data)

		-- Add the imperfective forms
		if #imperfectives > 0 then
			if aspect == "impf" then
				error("Can't specify imperfective counterparts for an imperfective verb")
			end
			imperfectives.label = "imperfective"
			table.insert(data.inflections, imperfectives)
		end

		-- Add the perfective forms
		if #perfectives > 0 then
			if aspect == "pf" then
				error("Can't specify perfective counterparts for a perfective verb")
			end
			perfectives.label = "perfective"
			table.insert(data.inflections, perfectives)
		end
	end
}

pos_functions["adjectives"] = {
	params = {
		[2] = {list = "comp"},
		[3] = {list = "sup"},
		["adv"] = {list = true},
		["absn"] = {list = true},
		["dim"] = {list = true},
		["indecl"] = {type = "boolean"},
	},
	func = function(args, data)
		local comps = args[2]
		local sups = args[3]
		local adverbs = args["adv"]
		local abstract_nouns = args["absn"]
		local diminutives = args["dim"]

		if args.indecl then	
			table.insert(data.inflections, {label = "indeclinable"})
			table.insert(data.categories, langname .. " indeclinable adjectives")
		end
		
		if #comps > 0 then
			if comps[1] == "-" then
				table.insert(data.inflections, {label = "no comparative"})
			else
				check_if_accents_needed(comps, data)
				comps.label = "comparative"
				table.insert(data.inflections, comps)
			end
			
		end
	
		if #sups > 0 then
			check_if_accents_needed(sups, data)
			sups.label = "superlative"
			table.insert(data.inflections, sups)
		end

		if #adverbs > 0 then
			check_if_accents_needed(adverbs, data)
			adverbs.label = "adverb"
			table.insert(data.inflections, adverbs)
		end
	
		if #abstract_nouns > 0 then
			check_if_accents_needed(abstract_nouns, data)
			abstract_nouns.label = "abstract noun"
			table.insert(data.inflections, abstract_nouns)
		end

		if #diminutives > 0 then
			check_if_accents_needed(diminutives, data)
			diminutives.label = "diminutive"
			table.insert(data.inflections, diminutives)
		end
	end
}

pos_functions["adverbs"] = {
	params = {
		[2] = {list = "comp"},
		[3] = {list = "sup"},
		["dim"] = {list = true},
	},
	func = function(args, data)
		local comps = args[2]
		local sups = args[3]
		local diminutives = args["dim"]
		
		if #comps > 0 then
			if comps[1] == "-" then
				table.insert(data.inflections, {label = "no comparative"})
			else
				check_if_accents_needed(comps, data)
				comps.label = "comparative"
				table.insert(data.inflections, comps)
			end
			
		end
	
		if #sups > 0 then
			check_if_accents_needed(sups, data)
			sups.label = "superlative"
			table.insert(data.inflections, sups)
		end

		if #diminutives > 0 then
			check_if_accents_needed(diminutives, data)
			diminutives.label = "diminutive"
			table.insert(data.inflections, diminutives)
		end
	end
}

return export
