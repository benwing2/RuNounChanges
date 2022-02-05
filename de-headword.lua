local export = {}
local pos_functions = {}

local legal_gender = {
	["m"] = true,
	["f"] = true,
	["n"] = true,
	["p"] = true,
}

local gender_names = {
	["m"] = "masculine",
	["f"] = "feminine",
	["n"] = "neuter",
}

local legal_verb_classes = {
	["1"] = true,
	["2"] = true,
	["3"] = true,
	["4"] = true,
	["5"] = true,
	["6"] = true,
	["7"] = true,
}

local lang = require("Module:languages").getByCode("de")

-- The main entry point.
-- This is the only function that can be invoked from a template.
function export.show(frame)
	local args = frame:getParent().args
	PAGENAME = mw.title.getCurrentTitle().text
	
	local head = args["head"]; if head == "" then head = nil end
	
	local poscat = frame.args[1] or error("Part of speech has not been specified. Please pass parameter 1 to the module invocation.")
	local class = frame.args[2]; if class == "" then class = nil end
	
	local data = {lang = lang, pos_category = poscat, categories = {}, heads = {head}, genders = {}, inflections = {}}
	
	if pos_functions[poscat] then
		pos_functions[poscat](class, args, data)
	end
	
	return
		require("Module:headword").full_headword(data)
end

pos_functions.adjectives = function(class, args, data)
	local params = {
		[1] = {list = "comp"},
		[2] = {list = "sup"},
		["head"] = {},
	}
	local args = require("Module:parameters").process(args, params)
	data.heads = {args["head"]}
	
	if args[1][1] == "-" then
		table.insert(data.inflections, {label = "not comparable"})
		table.insert(data.categories, "German uncomparable adjectives")
		return
	end
	
	if #args[1] > 0 then
		for i, form in ipairs(args[1]) do
			args[1][i] = {term = (form == "er" and PAGENAME .. "er" or form),
				accel = {form = "comparative"}}
		end
	else
		args[1] = {request = true}
		table.insert(data.categories, "de-adj lacking comparative")
	end
	args[1].label = "[[Appendix:Glossary#comparative|comparative]]"
	table.insert(data.inflections, args[1])
	
	if #args[2] > 0 then
		for i, form in ipairs(args[2]) do
			args[2][i] = {
				term = "am [[" ..  ((form == "st" or form == "sten") and PAGENAME .. "sten" or (form == "est" or form == "esten") and PAGENAME .. "esten" or form) .. "]]",
				accel = {form = "superlative"}}
		end
	else
		args[2] = {request = true}
		table.insert(data.categories, "de-adj lacking superlative")
	end
	args[2].label = "[[Appendix:Glossary#superlative|superlative]]"
	table.insert(data.inflections, args[2])
end

pos_functions.nouns = function(class, args, data)
	local params = {
		[1] = {list = "g", default = "?"},
		[2] = {list = "gen"},
		[3] = {list = "pl"},
		[4] = {list = "dim"},
		["head"] = {},
		["m"] = {list = true},
		["f"] = {list = true},
	}
	
	local args = require("Module:parameters").process(args, params)
	data.heads = {args["head"]}
	
	-- Gender
	for _, g in ipairs(args[1]) do
		if legal_gender[g] then
			table.insert(data.genders, g)
			
			if g == "p" then
				table.insert(data.categories, "German pluralia tantum")
			else
				table.insert(data.categories, "German " .. gender_names[g] .. " nouns")
			end
		else
			if g == "m-s" or g == "f-s" or g == "n-s" or g == "m-p" or g == "f-p" or g == "n-p" then
				require("Module:debug").track("de-headword/genders")
			end
			
			table.insert(data.genders, "?")
		end
	end
	
	if args[1][1] ~= "p" then
		-- Genitive
		if not args[2][1] then
			if args[1][1] == "m" or args[1][1] == "n" then
				table.insert(args[2], PAGENAME .. "s")
			else
				table.insert(args[2], PAGENAME)
			end
		elseif #args[2] == 1 then
			-- TODO: instead of this duplication use [[Module:de-noun]]
			if args[2][1] == "s" then
				args[2][1] = PAGENAME .. "s"
			elseif args[2][1] == "(s)" then	
				args[2][1] = PAGENAME .. "s"
				table.insert(args[2], PAGENAME)
			elseif args[2][1] == "es" then
				args[2][1] = PAGENAME .. "es"
			elseif args[2][1] == "(es)" then
				args[2][1] = PAGENAME .. "es"
				table.insert(args[2], PAGENAME)
			elseif args[2][1] == "(e)s" then
				args[2][1] = PAGENAME .. "es"
				table.insert(args[2], PAGENAME .. "s")
			elseif args[2][1] == "ses" then
				args[2][1] = PAGENAME .. "ses"
			elseif args[2][1] == "en" then
				args[2][1] = PAGENAME .. "en"
			elseif args[2][1] == "n" then
				args[2][1] = PAGENAME .. "n"
			elseif args[2][1] == "ns" then
				args[2][1] = PAGENAME .. "ns"
			end
		end
		
		for i, form in ipairs(args[2]) do
			args[2][i] = {term = form}
		end
		
		args[2].accel = {form = "gen|s"}
		args[2].label = "genitive"
		table.insert(data.inflections, args[2])
		
		-- Plural
		if not args[3][1] and data.pos_category == "nouns" then
			table.insert(args[3], PAGENAME .. "en")
		elseif #args[3] == 1 then
			-- TODO: instead of this duplication use [[Module:de-noun]]
			if args[3][1] == "n" then
				args[3][1] = PAGENAME .. "n"
			elseif args[3][1] == "en" then
				args[3][1] = PAGENAME .. "en"
			elseif args[3][1] == "nen" then
				args[3][1] = PAGENAME .. "nen"
			elseif args[3][1] == "e" then
				args[3][1] = PAGENAME .. "e"
			elseif args[3][1] == "se" then
				args[3][1] = PAGENAME .. "se"
			elseif args[3][1] == "s" then
				args[3][1] = PAGENAME .. "s"
			end
		end
		
		if args[3][1] == "-" then
			table.insert(data.inflections, {label = "no plural"})
			table.insert(data.categories, "German uncountable nouns")
		elseif #args[3] > 0 then
			for i, form in ipairs(args[3]) do
				args[3][i] = {term = form}
			end
			
			args[3].accel = {form = "p"}
			args[3].label = "plural"
			table.insert(data.inflections, args[3])
		end
	end
	
	-- Diminutive
	if #args[4] > 0 then
		for i, form in ipairs(args[4]) do
			args[4][i] = {term = form, genders = {"n"}}
		end
		
		args[4].accel = {form = "diminutive", gender = "n"}
		args[4].label = "diminutive"
		table.insert(data.inflections, args[4])
	end
	
	-- Other gender
	if #args.f > 0 then
		args.f.label = "female"
		if args.f[1] == "in" then
			args.f[1] = PAGENAME .. "in"
		end
		if args.f[1] == PAGENAME .. "in" then
			args.f.accel = {form = "feminine", gender = "f"}
			args.f.label = "feminine"
		end
		table.insert(data.inflections, args.f)
	end
	
	if #args.m > 0 then
		args.m.label = "male"
		table.insert(data.inflections, args.m)
	end
end

pos_functions["proper nouns"] = pos_functions.nouns

pos_functions.verbs = function(class, args, data)
	if args[2] then -- old-style
		local params = {
			[1] = {list = "pres", required = true},
			["pres_qual"] = {list = "pres=_qual", allow_holes = true},
			[2] = {list = "past", required = true},
			["past_qual"] = {list = "past=_qual", allow_holes = true},
			[3] = {list = "pp", required = true},
			["pp_qual"] = {list = "pp=_qual", allow_holes = true},
			[4] = {list = "pastsubj"},
			["pastsubj_qual"] = {list = "pastsubj=_qual", allow_holes = true},
			["aux"] = {list = true},
			["aux_qual"] = {list = "aux=_qual", allow_holes = true},
			["head"] = {list = true},
			["class"] = {list = true},
		}

		local args = require("Module:parameters").process(args, params)
		data.heads = args["head"]

		local function collect_forms(label, accel_form, forms, qualifiers)
			if forms[1] == "-" then
				return {label = "no " .. label}
			else
				local into_table = accel_form and {label = label, accel = {form = accel_form}} or {label = label}
				for i, form in ipairs(forms) do
					table.insert(into_table, {term = form, qualifiers = qualifiers[i] and {qualifiers[i]} or nil})
				end
				return into_table
			end
		end

		if #args.class > 0 then
			local class_descs, cats = require("Module:de-verb").process_verb_classes(args.class)
			for _, cats in ipairs(cats) do
				table.insert(data.categories, cats)
			end
			table.insert(data.inflections, {label = require("Module:table").serialCommaJoin(class_descs, {conj = "or"})})
		end
		table.insert(data.inflections, collect_forms("third-person singular present", "3|s|pres", args[1], args.pres_qual))
		table.insert(data.inflections, collect_forms("past tense", "1//3|s|pret", args[2], args.past_qual))
		table.insert(data.inflections, collect_forms("past participle", "perf|part", args[3], args.pp_qual))
		if #args[4] > 0 then
			table.insert(data.inflections, collect_forms("past subjunctive", "1//3|s|sub|II", args[4], args.pastsubj_qual))
		end
		if #args.aux > 0 then
			table.insert(data.inflections, collect_forms("auxiliary", nil, args.aux, args.aux_qual))
		end
		return
	end

	local function get_headword_inflection(forms, label, accel_form)
		if forms then
			local inflection = accel_form and {label = label, accel = {form = accel_form}} or {label = label}
			for _, form in ipairs(forms) do
				local qualifiers
				if form.footnotes then
					qualifiers = {}
					for _, footnote in ipairs(form.footnotes) do
						footnote = footnote:gsub("^%[(.*)%]$", "%1")
						table.insert(qualifiers, footnote)
					end
				end
				table.insert(inflection, {term = form.form, qualifiers = qualifiers})
			end
			return inflection
		elseif label then
			return {label = "no " .. label}
		else
			return {}
		end
	end

	local alternant_multiword_spec = require("Module:de-verb").do_generate_forms(args, "from headword")
	for _, cat in ipairs(alternant_multiword_spec.categories) do
		table.insert(data.categories, cat)
	end
	table.insert(data.inflections, {label = table.concat(alternant_multiword_spec.verb_types, " or ")})

	if #data.heads == 0 then
		for _, head in ipairs(alternant_multiword_spec.forms.infinitive_linked) do
			table.insert(data.heads, head.form)
		end
	end
	table.insert(data.inflections, get_headword_inflection(alternant_multiword_spec.forms.pres_3s,
		"third-person singular present", "3|s|pres"))
	local pret_3s = alternant_multiword_spec.forms.pret_3s
	table.insert(data.inflections, get_headword_inflection(pret_3s, "past tense", "1//3|s|pret"))
	table.insert(data.inflections, get_headword_inflection(alternant_multiword_spec.forms.perf_part,
		"past participle", "perf|part"))
	-- See if we need the past subjunctive, i.e. there exist past subjunctive forms whose stem is not the
	-- same as some past tense form. To facilitate comparison, we truncate final -e in both preterite 3s
	-- and past subjunctive 3s, to handle cases like subjunctive 'ginge aus' vs. preterite 'ging aus'.
	-- We need to compare 3s forms (and not e.g. 3p forms, where the issue with truncating -e doesn't
	-- occur) so we work correctly with impersonal verbs.
	local need_past_subj
	local truncated_pret_3s_forms = {}
	if pret_3s then
		for _, form in ipairs(pret_3s) do
			local truncated_form = form.form:gsub("e$", ""):gsub("e ", " ") -- discard 2nd retval
			table.insert(truncated_pret_3s_forms, truncated_form)
		end
	end
	local subii_3s = alternant_multiword_spec.forms.subii_3s
	local truncated_subii_3s_forms = {}
	if subii_3s then
		for _, form in ipairs(subii_3s) do
			local truncated_form = form.form:gsub("e$", ""):gsub("e ", " ") -- discard 2nd retval
			table.insert(truncated_subii_3s_forms, truncated_form)
		end
	end
	for _, past_subj_form in ipairs(truncated_subii_3s_forms) do
		local saw_same = false
		for _, pret_3s_form in ipairs(truncated_pret_3s_forms) do
			if past_subj_form == pret_3s_form then
				saw_same = true
				break
			end
		end
		if not saw_same then
			need_past_subj = true
			break
		end
	end
	if need_past_subj then
		table.insert(data.inflections, get_headword_inflection(subii_3s, "past subjunctive", "1//3|s|sub|II"))
	end

	local auxes = alternant_multiword_spec.forms.aux
	table.insert(data.inflections, get_headword_inflection(auxes, "auxiliary"))
end

return export
