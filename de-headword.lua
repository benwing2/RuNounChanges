local export = {}
local pos_functions = {}

local lang = require("Module:languages").getByCode("de")

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

local function ine(val)
	if val == "" then return nil else return val end
end


local function glossary_link(entry, text)
	text = text or entry
	return "[[Appendix:Glossary#" .. entry .. "|" .. text .. "]]"
end


local function track(page)
	require("Module:debug").track("de-headword/" .. page)
	return true
end


-- The main entry point.
-- This is the only function that can be invoked from a template.
function export.show(frame)
	local args = frame:getParent().args
	PAGENAME = mw.title.getCurrentTitle().text

	local poscat = frame.args[1] or error("Part of speech has not been specified. Please pass parameter 1 to the module invocation.")
	local class = frame.args[2]; if class == "" then class = nil end

	local data = {lang = lang, pos_category = poscat, categories = {}, heads = {}, genders = {}, inflections = {}}

	if pos_functions[poscat] then
		pos_functions[poscat](class, args, data)
	end

	return
		require("Module:headword").full_headword(data)
end

local function old_adjectives(class, args, data)
	track("de-adj-old")
	local params = {
		[1] = {list = "comp"},
		[2] = {list = "sup"},
		["head"] = {list = true},
	}
	local args = require("Module:parameters").process(args, params)
	data.heads = args["head"]

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
		track("de-adj lacking comparative")
	end
	args[1].label = glossary_link("comparative")
	table.insert(data.inflections, args[1])

	if #args[2] > 0 then
		for i, form in ipairs(args[2]) do
			args[2][i] = {
				term = "am [[" ..  ((form == "st" or form == "sten") and PAGENAME .. "sten" or (form == "est" or form == "esten") and PAGENAME .. "esten" or form) .. "]]",
				accel = {form = "superlative"}}
		end
	else
		args[2] = {request = true}
		track("de-adj lacking superlative")
	end
	args[2].label = glossary_link("superlative")
	table.insert(data.inflections, args[2])
end


pos_functions.adjectives = function(class, args, data, proper)
	-- Compatibility with old calling convention, either if old= is given or any arg no longer supported is given.
	if ine(args.old) or ine(args[2]) or ine(args.comp1) or ine(args.comp2) or ine(args.comp3) or
		ine(args.sup1) or ine(args.sup2) or ine(args.sup3) or args[1] == "-" then
		return old_adjectives(class, args, data)
	else
		-- Remove this code once we convert to the new format.
		track("de-adj-need-old")
	end
	-- FIXME, delete this once we are ready to convert to the new format.
	if not ine(args.new) then
		return old_adjectives(class, args, data)
	end

	local alternant_multiword_spec = require("Module:de-adjective").do_generate_forms(args, nil, "from headword")
	data.heads = alternant_multiword_spec.args.head
	data.id = alternant_multiword_spec.args.id
	data.sort = alternant_multiword_spec.args.sort

	local function do_adj_form(slot, label, should_be_present, accel_form)
		local forms = alternant_multiword_spec.forms[slot]
		local retval
		if not forms then
			if not should_be_present then
				return
			end
			retval = {label = "no " .. label}
		else
			retval = {label = label, accel = accel_form and {form = accel_form} or nil}
			local prev_footnotes
			for _, form in ipairs(forms) do
				local footnotes = form.footnotes
				if footnotes and prev_footnotes and require("Module:table").deepEquals(footnotes, prev_footnotes) then
					footnotes = nil
				end
				prev_footnotes = form.footnotes
				local quals, refs = require("Module:inflection utilities").fetch_headword_qualifiers_and_references(footnotes)
				local term = form.form
				table.insert(retval, {term = term, qualifiers = quals, refs = refs, genders = genders})
			end
		end

		table.insert(data.inflections, retval)
	end

	if alternant_multiword_spec.props.indecl then
		table.insert(data.inflections, {label = glossary_link("indeclinable")})
		if alternant_multiword_spec.props.predonly then
			table.insert(data.inflections, {label = "predicative only"})
		elseif alternant_multiword_spec.props.nopred then
			table.insert(data.inflections, {label = "no predicative form"})
		end
	else
		if alternant_multiword_spec.props.nopred then
			table.insert(data.inflections, {label = "no predicative form"})
		end
		do_adj_form("str_nom_m", "strong nominative masculine singular", true)
		local should_comp_sup =
			alternant_multiword_spec.forms.comp_pred or alternant_multiword_spec.forms.sup_pred or
			alternant_multiword_spec.forms.comp_str_nom_m or alternant_multiword_spec.forms.sup_str_nom_m
		if not should_comp_sup then
			table.insert(data.inflections, {label = "not comparable"})
		else
			-- If there is no predicative comparative, but there is an attributive comparative, include it;
			-- otherwise, include the predicative comparative (if any). If there is no comparative but a superlative,
			-- this will display "no comparative".
			if not alternant_multiword_spec.forms.comp_pred and alternant_multiword_spec.forms.comp_str_nom_m then
				do_adj_form("comp_str_nom_m", "strong comparative nominative masculine singular", true)
			else
				do_adj_form("comp_pred", glossary_link("comparative"), true, "comparative")
			end
			-- Same as above, for the superlative.
			if not alternant_multiword_spec.forms.sup_pred and alternant_multiword_spec.forms.sup_str_nom_m then
				do_adj_form("sup_str_nom_m", "strong superlative nominative masculine singular", true)
			else
				do_adj_form("sup_pred", glossary_link("superlative"), true, "superlative")
			end
		end
	end

	-- Add categories.
	for _, cat in ipairs(alternant_multiword_spec.categories) do
		table.insert(data.categories, cat)
	end

	-- Use the "linked" form of the lemma as the head if no head= explicitly given.
	if #data.heads == 0 then
		data.heads = {}
		local lemmas = alternant_multiword_spec.forms.the_lemma or {}
		for _, lemma_obj in ipairs(lemmas) do
			local head = alternant_multiword_spec.args.nolinkhead and lemma_obj.form or
				require("Module:headword utilities").add_lemma_links(lemma_obj.form, alternant_multiword_spec.args.splithyph)
			table.insert(data.heads, head)
			-- FIXME, can't yet specify qualifiers or references for heads
			-- local quals, refs = require("Module:inflection utilities").fetch_headword_qualifiers_and_references(lemma_obj.footnotes)
			-- table.insert(data.heads, {term = head, qualifiers = quals, refs = refs})
		end
	end
end

local function old_nouns(class, args, data)
	track("de-noun-old")
	local params = {
		[1] = {list = "g", default = "?"},
		[2] = {list = "gen"},
		[3] = {list = "pl"},
		[4] = {list = "dim"},
		["head"] = {list = true},
		["m"] = {list = true},
		["f"] = {list = true},
		["old"] = {type = "boolean"},
	}

	local args = require("Module:parameters").process(args, params)
	data.heads = args["head"]

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


pos_functions.nouns = function(class, args, data, proper)
	-- Compatibility with old calling convention, either if old= is given or any arg no longer supported is given.
	if ine(args.old) or ine(args[2]) or ine(args[3]) or ine(args[4]) or ine(args.g1) or ine(args.g2) or ine(args.g3) or
		ine(args.gen1) or ine(args.gen2) or ine(args.gen3) or ine(args.pl1) or ine(args.pl2) or ine(args.pl3) then
		return old_nouns(class, args, data)
	end

	local m_de_noun = require("Module:de-noun")
	local alternant_multiword_spec = m_de_noun.do_generate_forms(args, nil, "from headword", proper)
	data.heads = alternant_multiword_spec.args.head
	data.genders = alternant_multiword_spec.genders
	data.id = alternant_multiword_spec.args.id
	data.sort = alternant_multiword_spec.args.sort
	if not proper then
		data.pos_category = alternant_multiword_spec.pos
		if alternant_multiword_spec.pos == "suffixes" then
			table.insert(data.categories, "German noun-forming suffixes")
		end
	end

	local function get_nom_articles(alternant_multiword_spec)
		local articles = {}
		local m_table = require("Module:table")
		if alternant_multiword_spec.number == "pl" then
			m_table.insertIfNot(articles, "[[die]]")
		else
			for _, gender in ipairs(alternant_multiword_spec.genders) do
				if gender.spec == "m" then
					m_table.insertIfNot(articles, "[[der]]")
				elseif gender.spec == "f" then
					m_table.insertIfNot(articles, "[[die]]")
				elseif gender.spec == "n" then
					m_table.insertIfNot(articles, "[[das]]")
				else
					error("Internal error: Unrecognized gender '" .. gender.spec .. "'")
				end
			end
		end
		return table.concat(articles, "/")
	end

	local function get_gen_s_articles(alternant_multiword_spec)
		local articles = {}
		local m_table = require("Module:table")
		if alternant_multiword_spec.number == "pl" then
			error("Internal error: Should not be called on plural-only nouns")
		else
			for _, gender in ipairs(alternant_multiword_spec.genders) do
				if gender.spec == "m" or gender.spec == "n" then
					m_table.insertIfNot(articles, "[[des]]")
				elseif gender.spec == "f" then
					m_table.insertIfNot(articles, "[[der]]")
				else
					error("Internal error: Unrecognized gender '" .. gender.spec .. "'")
				end
			end
		end
		return table.concat(articles, "/")
	end

	local function do_noun_form(slot, label, should_be_present, accel_form, genders, prefix)
		local forms = alternant_multiword_spec.forms[slot]
		local retval
		if not forms then
			if not should_be_present then
				return
			end
			retval = {label = "no " .. label}
		else
			retval = {label = label, accel = accel_form and {form = accel_form} or nil}
			local prev_footnotes
			for _, form in ipairs(forms) do
				local footnotes = form.footnotes
				if footnotes and prev_footnotes and require("Module:table").deepEquals(footnotes, prev_footnotes) then
					footnotes = nil
				end
				prev_footnotes = form.footnotes
				local quals, refs = require("Module:inflection utilities").fetch_headword_qualifiers_and_references(footnotes)
				local term = form.form
				if prefix then
					if not term:find("[%[%]]") then
						term = "[[" .. term .. "]]"
					end
					term = prefix .. " " .. term
				end
				table.insert(retval, {term = term, qualifiers = quals, refs = refs, genders = genders})
			end
		end

		table.insert(data.inflections, retval)
	end

	if proper then
		table.insert(data.inflections, {label = glossary_link("proper noun")})
	end
	local weakprop = alternant_multiword_spec.props.weak 
	if weakprop and not (#weakprop == 1 and weakprop[1] == false) then
		local weakdesc = {}
		for _, is_weak in ipairs(alternant_multiword_spec.props.weak) do
			if is_weak then
				table.insert(weakdesc, glossary_link("weak declension", "weak"))
			else
				table.insert(weakdesc, glossary_link("strong declension", "strong"))
			end
		end
		table.insert(data.inflections, {label = table.concat(weakdesc, " or ")})
	end
	local overall_adj = alternant_multiword_spec.props.overall_adj
	local article = alternant_multiword_spec.props.article
	local surname = alternant_multiword_spec.props.surname
	local langname = alternant_multiword_spec.props.langname
	local saw_f = false
	local saw_mn = false
	for _, gender in ipairs(alternant_multiword_spec.genders) do
		if gender.spec == "f" then
			saw_f = true
		elseif gender.spec == "m" or gender.spec == "n" then
			saw_mn = true
		end
	end
	local fem_sg_only = not saw_mn and alternant_multiword_spec.number ~= "pl"
	if not alternant_multiword_spec.first_noun and alternant_multiword_spec.first_adj then
		table.insert(data.inflections, {label = "adjectival"})
	end
	if surname then
		table.insert(data.inflections, {label = "surname"})
	end
	if langname then
		table.insert(data.inflections, {label = "langname name"})
	end
	if alternant_multiword_spec.number == "pl" then
		table.insert(data.inflections, {label = glossary_link("plural only")})
	end
	if article then
		table.insert(data.inflections, {label = "usually definite"})
	end
	if alternant_multiword_spec.number == "pl" then
		if overall_adj then
			do_noun_form("wk_nom_p", "definite plural", nil, nil, nil, "[[die]]")
		end
	elseif surname then
		do_noun_form("gen_m_s", "masculine genitive", true)
		do_noun_form("gen_f_s", "feminine genitive", true)
		do_noun_form("nom_p", "plural", true)
	elseif langname then
		do_noun_form("nom_s_alt", "alternative nominative (used with the definite article)", true)
		do_noun_form("gen_s", "genitive", true)
		do_noun_form("gen_s_alt", "alternative genitive", true)
		-- There should be no plural; this will trigger the display of 'no plural'.
		do_noun_form("nom_p", "plural", true)
	elseif overall_adj then
		if article then
			if not fem_sg_only then
				do_noun_form("wk_nom_s", "definite nominative", nil, nil, nil, get_nom_articles(alternant_multiword_spec))
			end
			do_noun_form("wk_gen_s", "definite genitive", nil, nil, nil, get_gen_s_articles(alternant_multiword_spec))
			do_noun_form("wk_nom_p", "definite plural", nil, nil, nil, "[[die]]")
		else
			do_noun_form("wk_nom_s", "definite nominative", nil, nil, nil, get_nom_articles(alternant_multiword_spec))
			do_noun_form("str_gen_s", "genitive", true, nil, nil, not saw_f and "([[des]])" or nil)
			if saw_f then
				do_noun_form("wk_gen_s", "definite genitive", nil, nil, nil, get_gen_s_articles(alternant_multiword_spec))
			end
			do_noun_form("str_nom_p", "plural", not proper)
			do_noun_form("wk_nom_p", "definite plural", nil, nil, nil, "[[die]]")
		end
	else
		if article then
			do_noun_form("gen_s", "definite genitive", nil, nil, nil, get_gen_s_articles(alternant_multiword_spec))
			do_noun_form("nom_p", "definite plural", not proper, nil, nil, "[[die]]")
		else
			do_noun_form("gen_s", "genitive")
			do_noun_form("nom_p", "plural", not proper)
		end
	end
	-- FIXME: Should we include the article in the singular equivalent if .article is given? I have no examples to go by.
	do_noun_form("sg", "singular")
	do_noun_form("dim", "diminutive", nil, "diminutive", {"n"}, article and "[[das]]" or nil)
	do_noun_form("m", "masculine", nil, nil, nil, article and "[[der]]" or nil)
	do_noun_form("f", "feminine", nil, "feminine", nil, article and "[[die]]" or nil)
	do_noun_form("n", "neuter", nil, "neuter", nil, article and "[[das]]" or nil)

	-- Add categories.
	for _, cat in ipairs(alternant_multiword_spec.categories) do
		table.insert(data.categories, cat)
	end

	-- Use the "linked" form of the lemma as the head if no head= explicitly given.
	if #data.heads == 0 then
		data.heads = {}
		local lemmas = m_de_noun.get_lemmas(alternant_multiword_spec, "linked variant")
		for _, lemma_obj in ipairs(lemmas) do
			local head = alternant_multiword_spec.args.nolinkhead and lemma_obj.form or
				require("Module:headword utilities").add_lemma_links(lemma_obj.form, alternant_multiword_spec.args.splithyph)
			if article and (not overall_adj or fem_sg_only) then
				table.insert(data.heads, get_nom_articles(alternant_multiword_spec) .. " " .. head)
			else
				table.insert(data.heads, head)
			end
			-- FIXME, can't yet specify qualifiers or references for heads
			-- local quals, refs = expand_footnotes_and_references(lemma_obj.footnotes)
			-- table.insert(data.heads, {term = head, qualifiers = quals, refs = refs})
		end
	end
end

pos_functions["proper nouns"] = function(class, args, data)
	return pos_functions.nouns(class, args, data, "proper noun")
end

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
