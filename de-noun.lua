local export = {}


--[=[

Authorship: <benwing2>

]=]

--[=[

TERMINOLOGY:

-- "slot" = A particular combination of case/number.
	 Example slot names for nouns are "voc_s" (vocative singular) and
	 "gen_p" (genitive plural). Each slot is filled with zero or more forms.

-- "form" = The declined German form representing the value of a given slot.

-- "lemma" = The dictionary form of a given German term. Generally the nominative
     masculine singular, but may occasionally be another form if the nominative
	 masculine singular is missing.
]=]

--[=[
FIXME:

1. Qualifiers in genders should appear as footnotes on the articles.
2. Support notation like <g:f> on feminine/diminutive/masculine, e.g. used for [[Gespons]] (neuter with the meaning
   "wife", masculine with the meaning "husband").
3. Fix CSS gender-specific class in table.
4. Support adjectival nouns and adjective-noun combinations. (DONE)
5. Allow period and comma in forms e.g. for [[Eigent.-Whg.]], [[Eigt.-Whg.]] (using a backslash). (DONE)
6. Allow embedded links in genitive/plural/feminine/diminutive/masculine specs, e.g. 'f=![[weiblich]]er Geschäftspartner'.
7. Add 'prop' indicator to indicate proper nouns and suppress the indefinite article.
8. Add 'surname' indicator to indicate surnames, decline appropriately and include both masc and fem variants in the table. (DONE)
9. Add 'langname' indicator to indicate langnames and decline appropriately with its own table with two alternatives. (DONE)
]=]

local lang = require("Module:languages").getByCode("de")
local m_table = require("Module:table")
local m_links = require("Module:links")
local m_string_utilities = require("Module:string utilities")
local iut = require("Module:inflection utilities")
local com = require("Module:de-common")

local pretend_from_headword = false -- may be set during debugging
local force_cat = false -- may be set during debugging

local u = mw.ustring.char
local rsplit = mw.text.split
local rfind = mw.ustring.find
local rmatch = mw.ustring.match
local rgmatch = mw.ustring.gmatch
local rsubn = mw.ustring.gsub
local ulen = mw.ustring.len
local usub = mw.ustring.sub
local uupper = mw.ustring.upper
local ulower = mw.ustring.lower

local SUB_ESCAPED_PERIOD = u(0xFFF0)
local SUB_ESCAPED_COMMA = u(0xFFF1)

local archaic_dative_note = "[now uncommon, [[Wiktionary:About German#Dative_singular_-e_in_noun_declension|see notes]]]"


-- version of rsubn() that discards all but the first return value
local function rsub(term, foo, bar)
	local retval = rsubn(term, foo, bar)
	return retval
end


-- version of rsubn() that returns a 2nd argument boolean indicating whether
-- a substitution was made.
local function rsubb(term, foo, bar)
	local retval, nsubs = rsubn(term, foo, bar)
	return retval, nsubs > 0
end


local function track(page)
	require("Module:debug").track("de-noun/" .. page)
	return true
end


local states = { "str", "wk", "mix" }
local definitenesses = { "ind", "def" }
local cases_with_abl_voc = { "nom", "gen", "dat", "acc", "abl", "voc" }
local basic_cases = { "nom", "gen", "dat", "acc" }
local numbers = { "s", "p" }
local gender_spec_to_full_gender = {
	m = "masculine",
	f = "feminine",
	n = "neuter",
}

local case_set_with_abl_voc = m_table.listToSet(cases_with_abl_voc)


local function add_equiv(slot_list)
	table.insert(slot_list, {"m_equiv", "-"}) -- masculine equivalent of a feminine or neuter noun
	table.insert(slot_list, {"f_equiv", "-"}) -- feminine equivalent of a masculine or neuter noun
	table.insert(slot_list, {"n_equiv", "-"}) -- neuter equivalent of a masculine or feminine noun
end


local special_proper_nouns = {
	["surname"] = {
		has_gen_slot = true, -- FIXME, change this
		has_default_pl = true,
		default_gender = {"m", "f"},
		display = "surname",
	},
	["toponym"] = {
		has_gen_slot = true, -- FIXME, change this
		default_gender = "n",
		display = "toponym",
		no_indef = true,
	},
	["langname"] = {
		default_gender = "n",
		display = "language name",
		no_indef = true,
	},
	["mgiven"] = {
		has_default_pl = true,
		default_gender = "m",
		display = "given name",
	},
	["fgiven"] = {
		has_default_pl = true,
		default_gender = "f",
		display = "given name",
	},
	["mname"] = {
		default_gender = "m",
		display = "name",
		no_indef = true,
	},
	["fname"] = {
		default_gender = "f",
		display = "name",
		no_indef = true,
	},
	["nname"] = {
		default_gender = "n",
		display = "name",
		no_indef = true,
	},
}

-- Construct noun slots.

local noun_slot_list = {}
add_equiv(noun_slot_list)
local noun_slot_set = {}
for _, number in ipairs(numbers) do
	for _, case in ipairs(number == "s" and cases_with_abl_voc or basic_cases) do
		local slot = case .. "_" .. number
		local accel = case .. "|" .. number
		table.insert(noun_slot_list, {slot, accel})
		noun_slot_set[slot] = true
	end
end


-- Construct noun surname slots.

local surname_slot_list = {
}
local surname_slot_set = {}
local surname_endings = {
	{"m_s", "m|s"},
	{"f_s", "f|s"},
	{"p", "p"},
}
for _, case in ipairs(basic_cases) do
	for _, ending_and_accel in ipairs(surname_endings) do
		local ending, ending_accel = unpack(ending_and_accel)
		local slot = case .. "_" .. ending
		local accel = case .. "|" .. ending_accel
		table.insert(surname_slot_list, {slot, accel})
		surname_slot_set[slot] = true
	end
end


-- Construct noun langname slots.

local langname_slot_list = {
}
local langname_slot_set = {}
for _, case in ipairs(basic_cases) do
	for _, number in ipairs(numbers) do
		for _, is_alt in ipairs { false, true } do
			local slot = case .. "_" .. number .. (is_alt and "_alt" or "")
			-- FIXME: We should add accelerators for the alternative forms, but this requires hacking the accelerator
			-- code in [[Module:inflection utilities]] to specify the alternative lemma; e.g. genitive singular
			-- ''Deutschen'' needs to have lemma [[Deutsche]] not [[Deutsch]].
			local accel = is_alt and "-" or case .. "|" .. number
			table.insert(langname_slot_list, {slot, accel})
			langname_slot_set[slot] = true
		end
	end
end


-- Construct adjectival slots.

local adjectival_slot_list = {}
add_equiv(adjectival_slot_list)
local adjectival_slot_set = {}
for _, state in ipairs(states) do
	for _, case in ipairs(basic_cases) do
		for _, number in ipairs(numbers) do
			local slot = state .. "_" .. case .. "_" .. number
			local accel = state .. "|" .. case .. "|" .. number
			table.insert(adjectival_slot_list, {slot, accel})
			adjectival_slot_set[slot] = true
		end
	end
end


-- Construct expanded slot lists including linked variants.

local noun_slot_list_with_linked = m_table.shallowcopy(noun_slot_list)
table.insert(noun_slot_list_with_linked, {"nom_s_linked", "nom|s"})
table.insert(noun_slot_list_with_linked, {"nom_p_linked", "nom|p"})

local surname_slot_list_with_linked = m_table.shallowcopy(surname_slot_list)
table.insert(surname_slot_list_with_linked, {"nom_m_s_linked", "nom|m|s"})

local langname_slot_list_with_linked = m_table.shallowcopy(langname_slot_list)
table.insert(langname_slot_list_with_linked, {"nom_s_linked", "nom|s"})

local adjectival_slot_list_with_linked = m_table.shallowcopy(adjectival_slot_list)
table.insert(adjectival_slot_list_with_linked, {"str_nom_s_linked", "str|nom|s"})
table.insert(adjectival_slot_list_with_linked, {"str_nom_p_linked", "str|nom|p"})


-- Construct expanded slot lists including linked variants and articles.

local function add_slot_articles(slot_list, cases, numbers)
	for _, case in ipairs(cases) do
		for _, number in ipairs(numbers) do
			for _, def in ipairs(definitenesses) do
				local slotaccel = {"art_" .. def .. "_" .. case .. "_" .. number, "-"}
				table.insert(slot_list, slotaccel)
			end
		end
	end
end

local noun_slot_list_with_linked_and_articles = m_table.shallowcopy(noun_slot_list_with_linked)
add_slot_articles(noun_slot_list_with_linked_and_articles, cases_with_abl_voc, numbers)

local surname_slot_list_with_linked_and_articles = m_table.shallowcopy(surname_slot_list_with_linked)
add_slot_articles(surname_slot_list_with_linked_and_articles, basic_cases, {"m_s", "f_s", "p"})

local langname_slot_list_with_linked_and_articles = m_table.shallowcopy(langname_slot_list_with_linked)
add_slot_articles(langname_slot_list_with_linked_and_articles, basic_cases, {"s"})

local adjectival_slot_list_with_linked_and_articles = m_table.shallowcopy(adjectival_slot_list_with_linked)
add_slot_articles(adjectival_slot_list_with_linked_and_articles, basic_cases, numbers)


-- Return true if `prop` is a recognized indicator that can be specified on adjectives in [[Module:de-adjective]].
local function is_adjectival_decl_indicator(prop)
	return prop == "ss" or prop == "sync_n" or prop == "sync_mn" or prop == "sync_mns"
end


local function skip_slot(number, slot)
	return number == "sg" and rfind(slot, "_p$") or
		number == "pl" and rfind(slot, "_s$")
end


local function combine_stem_ending(props, stem, ending)
	if ending:find("^%^") then
		-- Umlaut requested
		ending = rsub(ending, "^%^", "")
		stem = com.apply_umlaut(stem)
	end
	if props.ss and stem:find("ß$") and rfind(ending, "^" .. com.V) then
		stem = rsub(stem, "ß$", "ss")
	end
	return stem .. ending
end


-- Add a form (a combination of `stem` and `ending`, where either may be a single string, a list of strings, or a
-- list of objects of the form {form=FORM, footnotes=FOOTNOTES}, where FOOTNOTES can be nil or a list of strings)
-- to the given slot `slot`. `gender` specifies the gender of the resulting form ("m", "f" or "n") or nil. (This is
-- used to ensure that the correct article is attached to the form when there are multiple forms with differing
-- genders. If `gender` is nil, articles of all relevant genders will be included. `gender` should only be nil
-- when the slot is plural or when the gender cannot be determined, e.g. in overrides.) `footnotes` specifies
-- any extra footnotes to add to the resulting form, and should be either nil or a list of strings.
-- `process_combined_stem_ending` is a function to process the resulting form before it is inserted. (This is used
-- currently to add an -n to the dative plural.)
local function add(base, slot, stem, ending, gender, footnotes, process_combined_stem_ending)
	if not ending or skip_slot(base.number, slot) then
		return
	end

	local function do_combine_stem_ending(stem, ending)
		local retval = combine_stem_ending(base.props, stem, ending)
		if process_combined_stem_ending then
			retval = process_combined_stem_ending(retval)
		end
		-- For now, don't do this.
		-- If gender specified, add a special character to the beginning of the value to indicate the
		-- gender. This gets propagated to the end and used in [[Module:de-headword]].
		-- if gender then
		--	retval = gender_to_gender_char[gender] .. retval
		-- end
		return retval
	end

	footnotes = iut.combine_footnotes(base.footnotes, footnotes)
	local ending_obj = iut.combine_form_and_footnotes(ending, footnotes)
	-- If we're declining an adjectival noun or adjective-noun combination, and the slot is a noun slot, convert it to
	-- the equivalent adjective slots (e.g. gen_s -> str_gen_s/wk_gen_s/mix_gen_s). But don't do that for "m_equiv",
	-- "f_equiv", "n_equiv", which are the same in nouns and adjectives.
	if base.props.overall_adj and noun_slot_set[slot] and not rfind(slot, "equiv$") then
		for _, state in ipairs(states) do
			iut.add_forms(base.forms, state .. "_" .. slot, stem or base.lemma, ending_obj, do_combine_stem_ending)
		end
	else
		iut.add_forms(base.forms, slot, stem or base.lemma, ending_obj, do_combine_stem_ending)
	end
end


-- Process an ending spec such as "s", "(e)s", "^er", "^lein", "!Pizzen", etc. as might be found in the genitive,
-- plural, an override, the value of dim=/m=/f=/n=, etc. `endings` is a list of such specs, where each entry of the
-- list is of the form {form=FORM, footnotes=FOOTNOTES} where FOOTNOTES is either nil or {FOOTNOTE, FOOTNOTE, ...}. If
-- `literal_endings` is given, the FORM values should be interpreted literally (i.e. as full forms) rather than as
-- ending specs. `default` is what to substitute if an ending spec is "+", and should be either in the same format as
-- `endings` or something that can be converted to that format, e.g. a string. `literal_default`, if given, indicates
-- that the FORM values in `default` should be interpreted literally, similar to `literal_endings`. `desc` is an
-- English description of what kind of spec is being processed, for error messages. `process` is called for each
-- generated form and is a function of two arguments, STEM and ENDING. If the spec is a full form, STEM will be that
-- form (in the form of an object {form=FORM, footnotes=FOOTNOTES}) and ENDING will be an empty string; otherwise, STEM
-- will be nil and ENDING will be the the ending to process in the form {form=FORM, footnotes=FOOTNOTES}. Note that
-- umlauts are not handled in process_spec(); if the spec passed in specifies an umlaut, e.g. "^chen", process()
-- will be called with a FORM beginning with "^", and must handle the umlaut itself. (Umlauts are properly handled
-- inside of add().)
local function process_spec(endings, literal_endings, default, literal_default, desc, process)
	for _, ending in ipairs(endings) do
		local function sub_form(form)
			return {form = form, footnotes = ending.footnotes}
		end

		if ending.form == "--" then
			-- do nothing
		elseif ending.form == "+" then
			if not default then
				-- Could happen if e.g. gen is given as -- and then a gen_s override with + is specified, or with n= for neuter,
				-- where no default is available.
				error("Form '+' found for " .. desc .. " but no default is available")
			end
			process_spec(iut.convert_to_general_list_form(default, ending.footnotes), literal_default, nil, nil, desc, process)
		else
			local full_eform
			if literal_endings or rfind(ending.form, "^" .. com.CAP) then
				full_eform = true
			elseif rfind(ending.form, "^!") then
				full_eform = true
				ending = sub_form(rsub(ending.form, "^!", ""))
			end
			if full_eform then
				process(ending, "")
			else
				local expanded_endings
				local umlaut = rmatch(ending.form, "^(%^?)%(e%)s$" )
				if umlaut then
					expanded_endings = {"es", "s"}
				end
				if not umlaut then
					umlaut = rmatch(ending.form, "^(%^?)%(s%)$")
					if umlaut then
						expanded_endings = {"s", ""}
					end
				end
				if not umlaut then
					umlaut = rmatch(ending.form, "^(%^?)%(es%)$")
					if umlaut then
						expanded_endings = {"es", ""}
					end
				end
				if expanded_endings then
					local new_endings = {}
					for _, expanded_ending in ipairs(expanded_endings) do
						table.insert(new_endings, sub_form(umlaut .. expanded_ending))
					end
					process(nil, new_endings)
				else
					if ending.form == "-" then
						ending = sub_form("")
					end
					process(nil, ending)
				end
			end
		end
	end
end


-- Add an ending spec such as "s", "(e)s", "^er", "^lein", "!Pizzen", etc. as might be found in the genitive, plural,
-- an override, the value of dim=/m=/f=/n=, etc., to the slot `slot` (e.g. "gen_s"). `endings` is a list of such specs,
-- where each entry of the list is of the form {form=FORM, footnotes=FOOTNOTES} where FOOTNOTES is either nil or
-- {FOOTNOTE, FOOTNOTE, ...}. For the meaning of `gender`, `footnotes` and `process_combined_stem_ending`, see add().
-- For the meaning of `default` and `literal_default`, see process_spec().
local function add_spec(base, slot, endings, gender, default, literal_default, footnotes, process_combined_stem_ending)
	local function do_add(stem, ending)
		add(base, slot, stem, ending, gender, footnotes, process_combined_stem_ending)
	end
	process_spec(endings, nil, default, literal_default, "slot '" .. slot .. "'", do_add)
end


local function process_slot_overrides(base)
	for slot, overrides in pairs(base.overrides) do
		if skip_slot(base.number, slot) then
			error("Override specified for invalid slot '" .. slot .. "' due to '" .. base.number .. "' number restriction")
		end
		local origforms = base.forms[slot]
		base.forms[slot] = nil
		-- Gender is not given by the user.
		add_spec(base, slot, overrides, nil, origforms, "literal default")
	end
end


local function add_archaic_dative_singular(base, gender, def_gen)
	for _, ending in ipairs(base.gens) do
		local dat_ending
		local ending_form = ending.form
		if ending_form == "+" then
			ending_form = def_gen
		end
		if ending_form == "es" or ending_form == "(e)s" then
			dat_ending = "e"
		elseif ending_form == "ses" then
			dat_ending = "se"
		elseif base.props.dat_with_e then
			dat_ending = "e"
		end
		if dat_ending then
			add(base, "dat_s", nil, dat_ending, gender, iut.combine_footnotes(ending.footnotes, {archaic_dative_note}))
		end
	end
end


local function get_n_ending(base, stem, is_sg)
	if rfind(stem, "e$") then
		-- typical feminine or weak masculine in -e
		return "n"
	elseif rfind(stem, "e[lr]$") and not rfind(stem, com.NV .. "[ei]e[lr]$") then
		-- [[Kammer]], [[Feier]], [[Leier]], but not [[Spur]], [[Beer]], [[Manier]], [[Schmier]] or [[Vier]]
		-- similarly, [[Achsel]], [[Gabel]], [[Tafel]], etc. but not [[Ziel]]
		return "n"
	elseif base.props.weak_n then
		-- ''des Nachbarn'', ''des Herrn'', ''des Satyrn'', etc.
		return "n"
	elseif rfind(stem, "[^aeAE]in$") then
		-- [[Chinesin]], [[Doktorin]], etc.; but not words in -ein or -ain such as [[Pein]]
		return "nen"
	else
		return "en"
	end
end


local function get_default_gen(base, gender)
	if gender == "f" then
		return ""
	elseif base.props.weak then
		return get_n_ending(base, base.lemma, "is singular")
	elseif rfind(base.lemma, "nis$") then
		-- neuter like [[Erlebnis]], [[Geheimnis]] or occasional masculine like [[Firnis]], [[Penis]]
		return "ses"
	elseif rfind(base.lemma, com.NV .. "us$") then
		-- [[Euphemismus]], [[Exitus]], [[Exodus]], etc.
		return ""
	elseif rfind(base.lemma, "[sßxz]$") then
		return "es"
	else
		return "s"
	end
end


local function get_default_pl(base, gender)
	if rfind(base.lemma, "nis$") then
		-- neuter like [[Erlebnis]], [[Geheimnis]] or feminine like [[Kenntnis]], [[Wildnis]],
		-- or occasional masculine like [[Firnis]], [[Penis]]
		return "se"
	elseif gender == "f" or base.props.weak then
		return get_n_ending(base, base.lemma)
	elseif rfind(base.lemma, "e$") then
		track("default-pl-e-not-f-or-weak")
		-- FIXME: This should return "s"
		return get_n_ending(base, base.lemma)
	elseif gender == "n" and rfind(base.lemma, "lein$") then
		-- Diminutives in -lein (those in -chen will automatically get a null ending from -en below)
		return ""
	elseif gender == "n" and rfind(base.lemma, "um$") then
		-- [[Museum]] -> [[Museen]], [[Vakuum]] -> [[Vakuen]]; not masculine [[Baum]] (plural [[Bäume]])
		-- or [[Reichtum]] (plural [[Reichtümer]])
		return "!" .. rsub(base.lemma, "um$", "en")
	elseif rfind(base.lemma, "mus$") then
		-- Algorithmus -> Algorithmen, Aphorismus -> Aphorismen
		return "!" .. rsub(base.lemma, "us$", "en")
	elseif rfind(base.lemma, com.NV .. "us$") then
		-- [[Abakus]] -> [[Abakusse]], [[Zirkus]] -> [[Zirkusse]], [[Autobus]] -> [[Autobusse]];
		-- not [[Applaus]] (plural [[Applause]])
		return "se"
	elseif rfind(base.lemma, "e[lmnr]$") and not rfind(base.lemma, com.NV .. "[ei]e[lnmr]$") then
		-- check for weak ending -el, -em, -en, -er, e.g. [[Adler]], [[Meier]], [[Riedel]]; but exclude [[Heer]],
		-- [[Bier]], [[Ziel]], which take -e by default
		return ""
	else
		return "e"
	end
end


local function decline_singular(base, gender, def_gen)
	add(base, "nom_s", nil, "", gender)
	add_spec(base, "gen_s", base.gens, gender, def_gen)
	if base.props.weak then
		local ending = get_n_ending(base, base.lemma, "is singular")
		add(base, "dat_s", nil, ending, gender)
		add(base, "acc_s", nil, gender == "m" and ending or "", gender)
	else
		add(base, "dat_s", nil, "", gender)
		add_archaic_dative_singular(base, gender, def_gen)
		add(base, "acc_s", nil, "", gender)
	end
end


local function decline_plural(base, def_pl)
	base.decl_type = {}
	local function process_nom_pl_for_decl_type(stem_ending)
		if base.props.saw_mn then
			if base.props.weak then
				m_table.insertIfNot(base.decl_type, "weak")
			elseif stem_ending == base.lemma .. "n" or stem_ending == base.lemma .. "en" then
				m_table.insertIfNot(base.decl_type, "mixed")
			else
				m_table.insertIfNot(base.decl_type, "strong")
			end
		end
		return stem_ending
	end

	local function process_dat_pl_to_add_n(stem_ending)
		if base.props.nodatpln then
			return stem_ending
		elseif rfind(stem_ending, "e[lr]?$") or rfind(stem_ending, "erl$") then
			return stem_ending .. "n"
		else
			return stem_ending
		end
	end

	add_spec(base, "nom_p", base.pls, nil, def_pl, nil, nil, process_nom_pl_for_decl_type)
	add_spec(base, "gen_p", base.pls, nil, def_pl)
	add_spec(base, "dat_p", base.pls, nil, def_pl, nil, nil, process_dat_pl_to_add_n)
	add_spec(base, "acc_p", base.pls, nil, def_pl)
end


local function decline_noun(base)
	if base.number == "pl" then
		decline_plural(base, "")
		if rfind(base.lemma, "innen$") then
			--- Ends in -innen, likely feminine. Chop off, and convert e.g. Chinesinnen -> Chinesen.
			local masc = rsub(base.lemma, "innen$", "")
			if rfind(masc, "es$") then
				masc = masc .. "en"
			end
			-- No need to specify gender for *_equiv; will be handled correctly in [[Module:de-headword]].
			add(base, "m_equiv", masc, "")
		else
			-- Likely masculine. Try to convert Chinesen -> Chinesinnen, and -er -> -erinnen.
			local femstem = rsub(base.lemma, "en$", "")
			add(base, "f_equiv", femstem, "innen")
		end
	else
		for _, genderspec in ipairs(base.genders) do
			local gender = genderspec.form
			decline_singular(base, gender, get_default_gen(base, gender))
			decline_plural(base, get_default_pl(base, gender))
			if gender == "m" then
				add(base, "f_equiv", rsub(base.lemma, "e$", ""), "in") -- feminine
			elseif gender == "f" then
				-- Try (sort of) to get the masculine. Remove final -in, and if the result ends in -es, convert to -ese
				-- (e.g. Chinesin -> Chinese).
				local masc = rsub(base.lemma, "in$", "")
				if rfind(masc, "es$") then
					masc = masc .. "e"
				end
				add(base, "m_equiv", masc, "")
			end -- do nothing for neuter
		end
	end
end


local function decline_surname(base)
	-- We don't specify gender here. There are always two genders, m and f, which will be handled correctly in
	-- [[Module:de-headword]].
	add(base, "nom_m_s", nil, "")
	add(base, "nom_f_s", nil, "")
	local gen_m_s
	if rfind(base.lemma, "[sxzß]$") or rfind(base.lemma, "ce$") then
		-- [[Marx]], [[Engels]], [[Weiß]], [[Schulz]]
		-- also names with silent -s or -x like [[Delacroix]]
		gen_m_s = "'"
	else
		gen_m_s = "s"
	end
	add_spec(base, "gen_m_s", base.gens, nil, gen_m_s)
	add(base, "gen_m_s", nil, "", nil, {"[with an article]"})
	add(base, "gen_f_s", nil, "")
	add(base, "dat_m_s", nil, "")
	add(base, "dat_f_s", nil, "")
	add(base, "acc_m_s", nil, "")
	add(base, "acc_f_s", nil, "")
	local pl_ending
	if rfind(base.lemma, "[sxß]$") then
		-- [[Marx]], [[Engels]], [[Weiß]]
		pl_ending = {"", "ens"}
	elseif rfind(base.lemma, "z$") then
		-- [[Schulz]], [[Schmitz]]
		pl_ending = {"", "es", "ens"}
	elseif rfind(base.lemma, "ce$") then
		pl_ending = {"", "ns"}
	elseif rfind(base.lemma, "e[nlr]?$") then
		-- [[Müller]], [[Goethe]], [[Dürer]], [[Schlegel]], [[Münchhausen]]
		pl_ending = {"s", ""}
	else
		-- [[Schmidt]], [[Bergmann]], [[Brentano]]
		pl_ending = {"s"}
	end
	add_spec(base, "nom_p", base.pls, nil, pl_ending)
	add_spec(base, "gen_p", base.pls, nil, pl_ending)
	add_spec(base, "dat_p", base.pls, nil, pl_ending)
	add_spec(base, "acc_p", base.pls, nil, pl_ending)
end


local function decline_toponym_mgiven(base)
	-- We don't specify gender here, which is always fixed.
	add(base, "nom_s", nil, "")
	local gen_s
	local null_footnote
	if rfind(base.lemma, "[sxzß]$") then
		gen_s = "'"
		null_footnote = "[with an article]"
	else
		gen_s = "s"
		null_footnote = "[optionally with an article]"
	end
	add_spec(base, "gen_s", base.gens, nil, gen_s)
	add(base, "gen_s", nil, "", nil, {null_footnote})
	add(base, "dat_s", nil, "")
	add(base, "acc_s", nil, "")
	if base.number == "both" then
		-- only with explicitly given plural
		add_spec(base, "nom_p", base.pls)
		add_spec(base, "gen_p", base.pls)
		add_spec(base, "dat_p", base.pls)
		add_spec(base, "acc_p", base.pls)
	end
end


local function decline_langname(base)
	-- We don't specify gender here, which is always neuter.
	add(base, "nom_s", nil, "")
	add(base, "gen_s", nil, "")
	-- If explicit genitive singular given, add it (in addition to the null genitive singular), otherwise default to -s.
	add_spec(base, "gen_s", base.gens, nil, "s")
	add(base, "dat_s", nil, "")
	add(base, "acc_s", nil, "")
	add(base, "nom_s_alt", nil, "e")
	add(base, "gen_s_alt", nil, "en")
	add(base, "dat_s_alt", nil, "en")
	add(base, "acc_s_alt", nil, "e")
end


local function decline_adjective(base)
	-- Construct an equivalent call to {{de-adecl}} based on the adjective indicators we fetched.
	local adj_spec_parts = {}
	local function ins(val)
		table.insert(adj_spec_parts, val)
	end
	local function ins_dot()
		if #adj_spec_parts > 0 then
			ins(".")
		end
	end
	local function insert_footnotes(footnotes)
		if footnotes then
			for _, footnote in ipairs(footnotes) do
				ins(footnote)
			end
		end
	end
	if base.adj_stem then
		ins("stem")
		for _, stem in ipairs(base.adj_stem) do
			ins(":")
			ins(stem.form)
			insert_footnotes(stem.footnotes)
		end
	end
	if base.adj_suppress then
		ins_dot()
		ins("suppress:")
		ins(base.adj_suppress)
	end
	if base.footnotes then
		ins_dot()
		insert_footnotes(base.footnotes)
	end
	for prop, _ in pairs(base.props) do
		if is_adjectival_decl_indicator(prop) then
			ins_dot()
			ins(prop)
		end
	end
	local adj_alternant_multiword_spec = require("Module:de-adjective").do_generate_forms(
		{base.lemma .. "<" .. table.concat(adj_spec_parts) .. ">"}
	)
	local function copy(from_slot, to_slot)
		base.forms[to_slot] = adj_alternant_multiword_spec.forms[from_slot]
	end
	local function copy_gender_forms(gender)
		local number = gender == "p" and "p" or "s"
		for _, state in ipairs(states) do
			for _, case in ipairs(basic_cases) do
				copy(state .. "_" .. case .. "_" .. gender, state .. "_" .. case .. "_" .. number)
			end
		end
	end

	if base.number == "pl" then
		copy_gender_forms("p")
		-- No need to specify gender for *_equiv; will be handled correctly in [[Module:de-headword]].
		add(base, "m_equiv", base.lemma, "e")
		add(base, "f_equiv", base.lemma, "e")
		add(base, "n_equiv", base.lemma, "e")
	else
		-- Normally there should be only one gender.
		for _, genderspec in ipairs(base.genders) do
			local gender = genderspec.form
			copy_gender_forms(gender)
			-- No need to specify gender for *_equiv; will be handled correctly in [[Module:de-headword]].
			add(base, "m_equiv", base.lemma, "er") -- masculine
			add(base, "f_equiv", base.lemma, "e") -- feminine
			add(base, "n_equiv", base.lemma, "es") -- neuter
		end
		if base.number ~= "sg" then
			copy_gender_forms("p")
		end
	end
end


-- Return the slots that may contain a lemma, in the order they should be checked. `props` is a property table,
-- coming either from `base` or `alternant_multiword_spec`.
local function get_lemma_slots(props)
	if props.surname then
		return {"nom_m_s"}
	elseif props.overall_adj then
		return {"str_nom_s", "str_nom_p"}
	else
		return {"nom_s", "nom_p"}
	end
end


-- Return the lemmas for this term. The return value is a list of {form = FORM, footnotes = FOOTNOTES}.
-- If `linked_variant` is given, return the linked variants (with embedded links if specified that way by the user),
-- otherwies return variants with any embedded links removed.
function export.get_lemmas(alternant_multiword_spec, linked_variant)
	local slots_to_fetch = get_lemma_slots(alternant_multiword_spec.props)
	local linked_suf = linked_variant and "_linked" or ""
	for _, slot in ipairs(slots_to_fetch) do
		if alternant_multiword_spec.forms[slot .. linked_suf] then
			return alternant_multiword_spec.forms[slot .. linked_suf]
		end
	end
	return {}
end


local function handle_derived_slots_and_overrides(base)
	process_slot_overrides(base)

	-- Compute linked versions of potential lemma slots, for use in {{de-noun}}.
	-- We substitute the original lemma (before removing links) for forms that
	-- are the same as the lemma, if the original lemma has links.
	for _, slot in ipairs(get_lemma_slots(base.props)) do
		iut.insert_forms(base.forms, slot .. "_linked", iut.map_forms(base.forms[slot], function(form)
			if form == base.orig_lemma_no_links and rfind(base.orig_lemma, "%[%[") then
				return base.orig_lemma
			else
				return form
			end
		end))
	end
end


-- Like iut.split_alternating_runs_and_strip_spaces(), but ensure that backslash-escaped commas and periods are not
-- treated as separators.
local function split_alternating_runs_with_escapes(segments, splitchar)
	for i, segment in ipairs(segments) do
		segments[i] = rsub(segment, "\\,", SUB_ESCAPED_COMMA)
		segments[i] = rsub(segment, "\\%.", SUB_ESCAPED_PERIOD)
	end
	local separated_groups = iut.split_alternating_runs_and_strip_spaces(segments, splitchar)
	for _, separated_group in ipairs(separated_groups) do
		for i, segment in ipairs(separated_group) do
			separated_group[i] = rsub(segment, SUB_ESCAPED_COMMA, ",")
			separated_group[i] = rsub(segment, SUB_ESCAPED_PERIOD, ".")
		end
	end
	return separated_groups
end


--[=[
Parse an indicator spec (text consisting of angle brackets and zero or more dot-separated indicators within them).
Return value is an object of the form

{
  overrides = {
	SLOT = {OVERRIDE, OVERRIDE, ...},
	...
  }, -- where OVERRIDE is {form = FORM, footnotes = FOOTNOTES}; same as `forms` table; FORM can be a full form (only if
		beginning with a capital letter or !), otherwise an ending; "-" for an ending means a null ending, while
		"--" suppresses the slot entirely, i.e. it is defective
  gens = {GEN_SG_SPEC, GEN_SG_SPEC, ...}, same form as OVERRIDE above
  pls = {PL_SPEC, PL_SPEC, ...}, same form as OVERRIDE above
  forms = {}, -- forms for a single spec alternant; see `forms` below
  props = {
	PROP = true,
	PROP = true,
    ...
  }, -- misc Boolean properties: "weak" (weak noun); "adj" (adjectival noun; set using "+");
		"ss" (lemma in -ß changes to -ss- before endings beginning with a vowel; pre-1996 spelling);
		"nodatpln" (suppress automatic addition of 'n' in the dative plural after '-e', '-er', '-el')
  number = "NUMBER", -- "sg", "pl", "both"; may be missing
  adj = true, -- may be missing

  -- The following additional fields are added by other functions:
  orig_lemma = "ORIGINAL-LEMMA", -- as given by the user or taken from pagename
  orig_lemma_no_links = "ORIGINAL-LEMMA-NO-LINKS", -- links removed
  lemma = "LEMMA", -- `orig_lemma_no_links`,
  forms = {
	SLOT = {
	  {
		form = "FORM",
		footnotes = {"FOOTNOTE", "FOOTNOTE", ...} -- may be missing
	  },
	  ...
	},
	...
  },
}
]=]
local function parse_indicator_spec(angle_bracket_spec, lemma, pagename, proper_noun)
	if lemma == "" then
		lemma = pagename
	end
	local base = {forms = {}, overrides = {}, props = {prop = proper_noun}}
	base.orig_lemma = lemma
	base.orig_lemma_no_links = m_links.remove_links(lemma)
	base.lemma = base.orig_lemma_no_links
	local inside = rmatch(angle_bracket_spec, "^<(.*)>$")
	assert(inside)

	local function parse_err(msg)
		error(msg .. ": <" .. inside .. ">")
	end

	--[=[
	Parse a single override spec and return three values: the slot the override applies to, the original indicator
	spec used to specify the slot, and the override specs. The input is a list where the footnotes have been separated
	out. For example, given the spec 'dat:-[referring to a card suit, as a term of endearment, and generally in speech]:en[in most cases in writing]',
	the input will be a list {"dat:-", "[referring to a card suit, as a term of endearment, and generally in speech]", ":en",
		"[in most cases in writing]", ""}
	]=]
	local function parse_override(segments)
		local part = segments[1]
		local offset = 4
		local case = usub(part, 1, 3)
		if not case_set_with_abl_voc[case] then
			parse_err("Internal error: unrecognized case in override: '" .. table.concat(segments) .. "'")
		end
		local indicator = case
		local rest = usub(part, offset)
		local slot
		if rfind(rest, "^pl") then
			rest = rsub(rest, "^pl", "")
			slot = case .. "_p"
			indicator = indicator .. "pl"
		else
			slot = case .. "_s"
		end
		if rfind(rest, "^:") then
			rest = rsub(rest, "^:", "")
		else
			parse_err("Slot indicator '" .. indicator .. "' must be followed by a colon: '" .. table.concat(segments) .. "'")
		end
		if not noun_slot_set[slot] then
			parse_err("Unrecognized slot indicator '" .. indicator .. "': '" .. table.concat(segments) .. "'")
		end
		segments[1] = rest
		return slot, indicator, com.fetch_specs(iut, segments, ":", "override", nil, parse_err)
	end

	if inside ~= "" then
		local segments = iut.parse_balanced_segment_run(inside, "[", "]")
		local dot_separated_groups = split_alternating_runs_with_escapes(segments, "%.")
		local special_proper = nil
		for i, dot_separated_group in ipairs(dot_separated_groups) do
			local part = dot_separated_group[1]
			if i == 1 then
				local comma_separated_groups = split_alternating_runs_with_escapes(dot_separated_group, ",")
				base.genders = com.fetch_specs(iut, comma_separated_groups[1], ":", "gender", nil, parse_err)
				local saw_sg = false
				local saw_pl = false
				local saw_gendered_pl = false
				local saw_non_gendered_pl = false
				local saw_adj = false
				for _, genderspec in ipairs(base.genders) do
					local g = genderspec.form
					if g == "m" or g == "n" then
						-- Set this on `base.props` as it's used in various other places.
						base.props.saw_mn = true
						saw_sg = true
					elseif g == "f" then
						saw_sg = true
					elseif g == "p" then
						saw_pl = true
						saw_non_gendered_pl = true
					elseif rfind(g, "^[mfn]p$") then
						saw_pl = true
						saw_gendered_pl = true
					elseif g == "+" or g == "p+" or g == "+p" then
						if #base.genders > 1 then
							parse_err("Can't specify multiple genders with adjectival declension")
						end
						saw_adj = true
						if g ~= "+" then
							saw_pl = true
						end
					elseif special_proper[g] then
						if #base.genders > 1 then
							parse_err("Can't specify multiple genders with " .. g .. " declension")
						end
						special_proper = g
					else
						parse_err("Unrecognized gender spec '" .. g .. "'")
					end
				end
				if saw_sg and saw_pl then
					parse_err("Can't specify both singular and plural gender specs")
				end
				if saw_gendered_pl and saw_non_gendered_pl then
					parse_err("Can't specify both 'p' and gendered plural specs")
				end
				local gen_index = (base.props.saw_mn or special_proper) and 2 or 1
				local pl_index =
					(saw_adj or saw_pl) and 1 or
					(base.props.saw_mn or special_proper_nouns[special_proper].has_gen_slot) and 3 or
					2
				if #comma_separated_groups > pl_index then
					if saw_adj then
						parse_err("Can't specify plurals or genitives with adjectival declension")
					elseif saw_pl then
						parse_err("Can't specify plurals or genitives with plural-only nouns")
					elseif base.props.saw_mn then
						parse_err("Can specify at most three comma-separated specs when the gender is masculine or "
							.. "neuter (gender, genitive, plural)")
					elseif special_proper_nouns[special_proper].has_gen_slot then
						parse_err("Can specify at most three comma-separated specs with '" .. special_proper .. "' "
							.. "nouns ('" .. special_proper .. "', genitive, plural)")
					elseif special_proper then
						parse_err("Can specify at most two comma-separated specs with '" .. special_proper .. "' "
							.. "nouns ('" .. special_proper .. "', plural)")
					else
						parse_err("Can specify at most two comma-separated specs when the gender is feminine "
							.. "(gender, plural)")
					end
				end
				if #comma_separated_groups >= gen_index and gen_index > 1 then
					base.gens = com.fetch_specs(iut, comma_separated_groups[gen_index], ":", "genitive", "allow blank", parse_err)
				end
				if #comma_separated_groups >= pl_index and pl_index > gen_index then
					base.pls = com.fetch_specs(iut, comma_separated_groups[pl_index], ":", "plural", "allow blank", parse_err)
				end
				if special_proper then
					if #base.genders > 1 then
						parse_err("Internal error: More than one gender spec for '" .. special_proper .. "'")
					else
						base.props[special_proper] = true
						if special_proper == "surname" then
							-- FIXME, does it make sense to put the footnotes on the feminine gender (they appear after the gender)?
							base.genders = {{form = "m"}, {form = "f", footnotes = base.genders[1].footnotes}}
						elseif special_proper == "mgiven" then
							base.genders = {{form = "m", footnotes = base.genders[1].footnotes}}
						elseif special_proper == "fgiven" then
							base.genders = {{form = "f", footnotes = base.genders[1].footnotes}}
						else
							base.genders = {{form = "n", footnotes = base.genders[1].footnotes}}
						end
					end
				elseif saw_adj then
					if #base.genders > 1 then
						parse_err("Internal error: More than one gender spec for adjectival declension")
					else
						base.props.adj = true
						if saw_pl then
							base.number = "pl"
							base.genders = {{form = "p", footnotes = base.genders[1].footnotes}}
						else
							-- Stash the footnotes into `adj_footnotes`; we will put them onto the autodetected gender
							-- in determine_adjectival_genders(), which will set base.genders appropriately.
							base.adj_footnotes = base.genders[1].footnotes
							base.genders = {}
						end
					end
				elseif saw_pl then
					-- Convert 'mp' to 'm-p', 'fp' to 'f-p', etc. as that's what [[Module:gender and number]] expects.
					for _, genderspec in ipairs(base.genders) do
						local gender = rmatch(genderspec.form, "^([mfn])p$")
						if gender then
							genderspec.form = gender .. "-p"
						end
					end
					base.number = "pl"
				end
			elseif base.props.adj and part:find("^stem:") then
				dot_separated_group[1] = rsub(part, "^stem:", "")
				base.adj_stem = com.fetch_specs(iut, dot_separated_group, ":", "adjectival stem", nil, parse_err)
			elseif base.props.adj and part:find("^suppress:") then
				if #dot_separated_group > 1 then
					parse_err("Can't specify footnotes with suppress: '" .. table.concat(dot_separated_group) .. "'")
				end
				-- No need to parse or validate more. Will happen in [[Module:de-adjective]].
				base.adj_suppress = rsub(part, "suppress:", "")
			elseif part == "" then
				if #dot_separated_group == 1 then
					parse_err("Blank indicator")
				end
				base.footnotes = com.fetch_footnotes(dot_separated_group, parse_err)
			elseif part:find(":") then
				local indicator, rest = rmatch(part, "^([^:]*):(.*)$")
				if not indicator then
					parse_err("Internal error: Can't parse indicator and remainder: " .. part)
				end
				if indicator == "noartgen" or indicator == "optartgen" or indicator == "artgen" then
					if not special_proper then
						parse_err("Indicator '" .. indicator .."' can only be used with special proper-noun variants")
					else
						dot_separated_group[1] = rest
						local desc =
							indicator == "noartgen" and "no-article genitive" or
							indicator == "optartgen" and "optional-article genitive" or
							"with-article genitive"
						base[indicator] = com.fetch_specs(iut, dot_separated_group, ":", desc, nil, parse_err)
				else
					-- override
					-- FIXME: Handle adjectival overrides
					local case_prefix = usub(part, 1, 3)
					if case_set_with_abl_voc[case_prefix] then
						local slot, slot_indicator, override = parse_override(dot_separated_group)
						if base.overrides[slot] then
							parse_err("Can't specify override twice for slot '" .. slot_indicator .. "'")
						else
							base.overrides[slot] = override
						end
					else
					parse_err("Unrecognized indicator '" .. part .. "'")
					end
				end
			elseif #dot_separated_group > 1 then
				local errmsg
				if base.props.adj then
					errmsg = "Footnotes only allowed with slot overrides, 'stem:' or by themselves"
				else
					errmsg = "Footnotes only allowed with genitive, plural, slot overrides or by themselves"
				end
				parse_err(errmsg .. ": '" .. table.concat(dot_separated_group) .. "'")
			elseif part == "sg" or part == "both" then
				if base.number then
					if base.number ~= part then
						parse_err("Can't specify '" .. part .. "' along with '" .. base.number .. "'")
					else
						parse_err("Can't specify '" .. part .. "' twice")
					end
				end
				base.number = part
			elseif not base.props.adj and (part == "weak" or part == "weak_n" or part == "ss" or part == "nodatpln" or part == "article" or part == "dat_with_e") then
				if base.props[part] then
					parse_err("Can't specify '" .. part .. "' twice")
				end
				base.props[part] = true
				if part == "weak_n" then
					-- weak_n implies weak
					base.props.weak = true
				end
			elseif base.props.adj and (part == "article" or is_adjectival_decl_indicator(part)) then
				if base.props[part] then
					parse_err("Can't specify '" .. part .. "' twice")
				end
				base.props[part] = true
			else
				parse_err("Unrecognized indicator '" .. part .. "'")
			end
		end
	end
	return base
end


-- For an adjectival lemma, synthesize the predicative (lemma) form. It doesn't have to be perfect in that the
-- predicative form itself isn't used, so we don't have to try to convert -abler -> -abel or anything like that.
local function synthesize_adj_lemma(base)
	local stem, ending = rmatch(base.lemma, "^(.*)(e[rs]?)$")
	if not stem then
		error("Unrecognized adjectival lemma, should end in '-er', '-e' or '-es': '" .. base.lemma .. "'")
	end
	base.lemma = stem
	-- Will be ignored if number == "pl"
	if ending == "er" then
		base.autodetected_gender = "m"
	elseif ending == "e" then
		base.autodetected_gender = "f"
	else
		base.autodetected_gender = "n"
	end
end


local function get_default_number(alternant_multiword_spec, base)
	return
		base.pls and "both" or
		base.special_proper and not specs[base.special_proper].has_default_pl and "sg" or
		alternant_multiword_spec.props.is_proper and "sg" or
		"both"
end


local function detect_indicator_spec(alternant_multiword_spec, base)
	if base.props.article then
		alternant_multiword_spec.props.article = true
	end
	if base.props.adj then
		alternant_multiword_spec.props.overall_adj = true
		synthesize_adj_lemma(base)
	else
		if base.special_proper then
			if alternant_multiword_spec.special_proper == nil then
				alternant_multiword_spec.special_proper = base.special_proper
			elseif alternant_multiword_spec.special_proper ~= base.special_proper then
				-- We do this because we have a special table with its own slots for each of these special variants.
				-- FIXME: This might be too strong of a restriction.
				-- FIXME: Consider supporting adjectives with these variants. That requires that we copy the adjectival
				-- declensions to the appropriate per-variant slots.
				error("If some alternants set '" .. base.special_proper .. "', all must do so")
			end
		end
		-- Set default values.
		base.number = base.number or get_default_number(alternant_multiword_spec, base)
		-- Compute overall weakness for use in headword.
		if alternant_multiword_spec.props.weak == nil then
			alternant_multiword_spec.props.weak = {base.props.weak or false}
		else
			m_table.insertIfNot(alternant_multiword_spec.props.weak, base.props.weak or false)
		end
		if base.number == "pl" then
			if base.gens then
				error("Internal error: With plural-only noun, no genitive singular specs should be allowed")
			end
			if base.pls then
				error("Internal error: With plural-only noun, no plural specs should be allowed")
			end
		end
		if base.pls and base.number == "sg" then
			error("Can't specify explicit plural specs along with explicit '.sg'")
		end
		base.gens = base.gens or {{form = "+"}}
		base.pls = base.pls or {{form = "+"}}
	end
end


local function detect_all_indicator_specs(alternant_multiword_spec)
	iut.map_word_specs(alternant_multiword_spec, function(base)
		detect_indicator_spec(alternant_multiword_spec, base)
	end)
	-- Now propagate some properties downwards.
	iut.map_word_specs(alternant_multiword_spec, function(base)
		base.props.overall_adj = alternant_multiword_spec.props.overall_adj
		if not base.props.adj and alternant_multiword_spec.special_proper ~= base.special_proper then
			-- See above.
			error("If some alternants set '" .. alternant_multiword_spec.special_proper .. "', all must do so")
		end
	end)
end


local propagate_multiword_properties


local function propagate_alternant_properties(alternant_spec, property, mixed_value, nouns_only)
	local seen_property
	for _, multiword_spec in ipairs(alternant_spec.alternants) do
		propagate_multiword_properties(multiword_spec, property, mixed_value, nouns_only)
		if seen_property == nil then
			seen_property = multiword_spec[property]
		elseif multiword_spec[property] and seen_property ~= multiword_spec[property] then
			seen_property = mixed_value
		end
	end
	alternant_spec[property] = seen_property
end


propagate_multiword_properties = function(multiword_spec, property, mixed_value, nouns_only)
	local seen_property = nil
	local last_seen_nounal_pos = 0
	local word_specs = multiword_spec.alternant_or_word_specs or multiword_spec.word_specs
	for i = 1, #word_specs do
		local is_nounal
		if word_specs[i].alternants then
			propagate_alternant_properties(word_specs[i], property, mixed_value)
			is_nounal = not not word_specs[i][property]
		elseif nouns_only then
			is_nounal = not word_specs[i].props.adj
		else
			is_nounal = not not word_specs[i][property]
		end
		if is_nounal then
			if not word_specs[i][property] then
				error("Internal error: noun-type word spec without " .. property .. " set")
			end
			for j = last_seen_nounal_pos + 1, i - 1 do
				word_specs[j][property] = word_specs[j][property] or word_specs[i][property]
			end
			last_seen_nounal_pos = i
			if seen_property == nil then
				seen_property = word_specs[i][property]
			elseif seen_property ~= word_specs[i][property] then
				seen_property = mixed_value
			end
		end
	end
	if last_seen_nounal_pos > 0 then
		for i = last_seen_nounal_pos + 1, #word_specs do
			word_specs[i][property] = word_specs[i][property] or word_specs[last_seen_nounal_pos][property]
		end
	end
	multiword_spec[property] = seen_property
end


local function propagate_properties_downward(alternant_multiword_spec, property, default_propval)
	local propval1 = alternant_multiword_spec[property] or default_propval
	alternant_multiword_spec[property] = propval1
	for _, alternant_or_word_spec in ipairs(alternant_multiword_spec.alternant_or_word_specs) do
		local propval2 = alternant_or_word_spec[property] or propval1
		if alternant_or_word_spec.alternants then
			for _, multiword_spec in ipairs(alternant_or_word_spec.alternants) do
				local propval3 = multiword_spec[property] or propval2
				for _, word_spec in ipairs(multiword_spec.word_specs) do
					local propval4 = word_spec[property] or propval3
					if propval4 == "mixed" then
						error("Attempt to assign mixed " .. property .. " to word")
					end
					word_spec[property] = propval4
				end
			end
		else
			if propval2 == "mixed" then
				error("Attempt to assign mixed " .. property .. " to word")
			end
			alternant_or_word_spec[property] = propval2
		end
	end
end


--[=[
Propagate `property` ("genders" or "number") from nouns to adjacent adjectives. We proceed as follows:
1. We assume the properties in question are already set on all nouns. This should happen in parse_indicator_spec().
2. We first propagate properties upwards and sideways. We recurse downwards from the top. When we encounter a
   multiword spec, we proceed left to right looking for a noun. When we find a noun, we fetch its property
   (recursing if the noun is an alternant), and propagate it to any adjectives to its left, up to the next noun
   to the left. When we have processed the last noun, we also propagate its property value to any adjectives to the
   right. Finally, we set the property value for the multiword spec itself by combining all the non-nil properties of
   the individual elements. If all non-nil properties have the same value, the result is that value, otherwise it is
   `mixed_value` (which is "mixed" gender, but "both" for number).
3. When we encounter an alternant spec in this process, we recursively process each alternant (which is a multiword
   spec) using the previous step, and combine any non-nil properties we encounter the same way as for multiword specs.
4. The effect of steps 2 and 3 is to set the property of each alternant and multiword spec based on its children or its
   neighbors.
]=]
local function propagate_properties(alternant_multiword_spec, property, default_propval, mixed_value)
	propagate_multiword_properties(alternant_multiword_spec, property, mixed_value, "nouns only")
	propagate_multiword_properties(alternant_multiword_spec, property, mixed_value, false)
	propagate_properties_downward(alternant_multiword_spec, property, default_propval)
end


-- Set the gender of adjectives and adjectival nouns to the gender autodetected during synthesize_adj_lemma(),
-- unless the form is plural. We don't just set the gender directly in synthesize_adj_lemma() because we don't know
-- until later (i.e. when propagate_properties() is called) whether an adjectival form in -e is feminine or plural.
-- We set the footnotes (i.e. qualifiers) of the gender to the footnotes (if any) specified directly after '+'.
local function determine_adjectival_genders(alternant_multiword_spec)
	iut.map_word_specs(alternant_multiword_spec, function(base)
		if base.props.adj and #base.genders == 0 then
			base.genders = {{form = base.number == "pl" and "p" or base.autodetected_gender, footnotes = base.adj_footnotes}}
		end
	end)
end


-- Find the first noun in a multiword expression and set alternant_multiword_spec.first_noun
-- to the index of that noun. Also find the first adjective and set alternant_multiword_spec.first_adj
-- similarly. If there is a first noun, we use its properties to determine the overall expression's
-- properties; otherwise we use the first adjective's properties, otherwise the first word's properties.
-- If the "word" located this way is not an alternant spec, we just use its properties directly, otherwise
-- we use the properties of the first noun (or failing that the first adjective, or failing that the
-- first word) in each alternative alternant in the alternant spec. For this reason, we need to set the
-- the .first_noun of and .first_adj of each multiword expression embedded in the first noun alternant spec,
-- and the .first_adj of each multiword expression in each adjective alternant spec leading up to the
-- first noun alternant spec.
local function determine_noun_status(alternant_multiword_spec)
	for i, alternant_or_word_spec in ipairs(alternant_multiword_spec.alternant_or_word_specs) do
		if alternant_or_word_spec.alternants then
			local alternant_type
			for _, multiword_spec in ipairs(alternant_or_word_spec.alternants) do
				for j, word_spec in ipairs(multiword_spec.word_specs) do
					if not word_spec.props.adj then
						multiword_spec.first_noun = j
						alternant_type = "noun"
						break
					elseif not multiword_spec.first_adj then
						multiword_spec.first_adj = j
						if not alternant_type then
							alternant_type = "adj"
						end
					end
				end
			end
			if alternant_type == "noun" then
				alternant_multiword_spec.first_noun = i
				return
			elseif alternant_type == "adj" and not alternant_multiword_spec.first_adj then
				alternant_multiword_spec.first_adj = i
			end
		else
			if not alternant_or_word_spec.props.adj then
				alternant_multiword_spec.first_noun = i
				return
			elseif not alternant_multiword_spec.first_adj then
				alternant_multiword_spec.first_adj = i
			end
		end
	end
end


local function decline_noun_or_adjective(base)
	if base.props.surname then
		decline_surname(base)
	elseif base.props.toponym then
		decline_toponym(base)
	elseif base.props.langname then
		decline_langname(base)
	elseif base.props.adj then
		decline_adjective(base)
	else
		decline_noun(base)
	end
	handle_derived_slots_and_overrides(base)
end


-- Set the overall articles. We can't do this using the normal inflection code as it will produce e.g.
-- '[[der]] [[und]] [[der]]' for conjoined nouns.
local function compute_non_surname_articles(alternant_multiword_spec)
	if alternant_multiword_spec.number ~=  "pl" then
		iut.map_word_specs(alternant_multiword_spec, function(base)
			for _, genderspec in ipairs(base.genders) do
				for _, case in ipairs(cases_with_abl_voc) do
					for _, def in ipairs(definitenesses) do
						iut.insert_form(alternant_multiword_spec.forms, "art_" .. def .. "_" .. case .. "_s",
							{form = com.articles[genderspec.form][def .. "_" .. case]})
					end
				end
			end
		end)
	end
	for _, case in ipairs(basic_cases) do
		for _, def in ipairs(definitenesses) do
			iut.insert_form(alternant_multiword_spec.forms, "art_" .. def .. "_" .. case .. "_p",
				{form = com.articles.p[def .. "_" .. case]})
		end
	end
end


-- Set the overall surname articles. We can't do this using the normal inflection code as it will produce e.g.
-- '[[der]] [[und]] [[der]]' for conjoined nouns.
local function compute_surname_articles(alternant_multiword_spec)
	for _, gender in ipairs {"m", "f"} do
		for _, case in ipairs(basic_cases) do
			for _, def in ipairs(definitenesses) do
				iut.insert_form(alternant_multiword_spec.forms, "art_" .. def .. "_" .. case .. "_" .. gender .. "_s",
					{form = "([[" .. com.articles[gender][def .. "_" .. case] .. "]])"})
			end
		end
	end
	for _, case in ipairs(basic_cases) do
		iut.insert_form(alternant_multiword_spec.forms, "art_def_" .. case .. "_p",
			{form = "([[" .. com.articles.p["def_" .. case] .. "]])"})
	end
end


local function compute_articles(alternant_multiword_spec)
	if alternant_multiword_spec.props.surname then
		compute_surname_articles(alternant_multiword_spec)
	else
		compute_non_surname_articles(alternant_multiword_spec)
	end
end


-- Call a function `fun` over the first noun in the `alternant_multiword_spec`, or over the first noun in each
-- alternant if there is more than one alternant. If there are no nouns, use the first adjective (in the case of an
-- adjectival noun).
local function map_first_noun(alternant_multiword_spec, fun)
	local key_entry = alternant_multiword_spec.first_noun or alternant_multiword_spec.first_adj or 1
	if #alternant_multiword_spec.alternant_or_word_specs >= key_entry then
		local alternant_or_word_spec = alternant_multiword_spec.alternant_or_word_specs[key_entry]
		if alternant_or_word_spec.alternants then
			for _, multiword_spec in ipairs(alternant_or_word_spec.alternants) do
				key_entry = multiword_spec.first_noun or multiword_spec.first_adj or 1
				if #multiword_spec.word_specs >= key_entry then
					fun(multiword_spec.word_specs[key_entry])
				end
			end
		else
			fun(alternant_or_word_spec)
		end
	end
end


-- Compute the categories to add the noun to, as well as the annotation to display in the
-- declension title bar. We combine the code to do these functions as both categories and
-- title bar contain similar information.
local function compute_categories_and_annotation(alternant_multiword_spec)
	alternant_multiword_spec.categories = {}

	local function insert(cattype)
		cattype = rsub(cattype, "~", alternant_multiword_spec.pos)
		m_table.insertIfNot(alternant_multiword_spec.categories, "German " .. cattype)
	end
	if not alternant_multiword_spec.props.is_proper and alternant_multiword_spec.number == "sg" then
		insert("uncountable ~")
	elseif alternant_multiword_spec.number == "pl" then
		insert("pluralia tantum")
	end
	local annotation
	local annparts = {}
	local genderdescs = {}
	local decldescs = {}

	if alternant_multiword_spec.number == "sg" then
		table.insert(annparts, "sg-only")
	elseif alternant_multiword_spec.number == "pl" and alternant_multiword_spec.genders[1].spec ~= "p" then
		-- If the gender is just 'p', we use "pl-only" below as a substitute for the gender and hook any qualifiers
		-- onto it. Note that when 'p' is the gender, there can be only one gender.
		table.insert(annparts, "pl-only")
	end

	for i, genderspec in ipairs(alternant_multiword_spec.genders) do
		local genderdesc_parts = {}
		local gender = genderspec.spec
		if gender == "p" then
			table.insert(genderdesc_parts, "pl-only")
		else
			gender = rsub(gender, "%-p$", "")
			table.insert(genderdesc_parts, gender_spec_to_full_gender[gender])
		end
		if genderspec.qualifiers then
			table.insert(genderdesc_parts, " ''(")
			table.insert(genderdesc_parts, table.concat(genderspec.qualifiers, ", "))
			table.insert(genderdesc_parts, ")''")
		end
		table.insert(genderdescs, table.concat(genderdesc_parts))
	end

	local function do_word_spec(base)
		if base.special_proper then
			m_table.insertIfNot(decldescs, special_proper_nouns[special_proper].display)
		elseif base.decl_type then
			-- strong/weak/mixed declension type; should only be present on masculine or neuter nouns with a plural
			for _, decl_type in ipairs(base.decl_type) do
				if decl_type == "weak" then
					insert("weak ~")
				elseif decl_type == "mixed" then
					insert("mixed ~")
				end
				m_table.insertIfNot(decldescs, decl_type)
			end
		elseif base.props.saw_mn then
			-- For singular-only masculine or neuter nouns, we can still classify as strong or weak.
			-- We don't try to classify plural-only nouns. Even for nouns in -n or -en, we have no idea if they are
			-- strong (-en is part of the stem), mixed or weak.
			if base.props.weak then
				insert("weak ~")
				m_table.insertIfNot(decldescs, "weak")
			else
				m_table.insertIfNot(decldescs, "strong")
			end
		end
	end

	-- Use the special proper/weak/strong properties of the noun(s).
	map_first_noun(alternant_multiword_spec, do_word_spec)

	if #genderdescs > 0 then
		table.insert(annparts, table.concat(genderdescs, " // "))
	end
	if #decldescs > 0 then
		table.insert(annparts, table.concat(decldescs, " // "))
	end
	if not alternant_multiword_spec.first_noun and alternant_multiword_spec.first_adj then
		insert("adjectival ~")
		table.insert(annparts, "adjectival")
	end
	if alternant_multiword_spec.props.langname then
		insert("specially-declined language names")
	end
	alternant_multiword_spec.annotation = table.concat(annparts, ", ")
end


local function compute_headword_genders(alternant_multiword_spec)
	alternant_multiword_spec.genders = {}
	-- Compute the genders based on the nouns. We don't want to use the adjectives in adjective-noun combinations
	-- because that will cause issues in plural-only expressions like [[Kanarische Inseln]], where ''Inseln'' may be
	-- 'f-p' but ''Kanarische'' will be just 'p', and we'd end up with both genders.
	map_first_noun(alternant_multiword_spec, function(base)
		for _, genderspec in ipairs(base.genders) do
			-- Create the new spec to insert.
			local spec = {spec = genderspec.form, qualifiers = genderspec.footnotes}
			-- See if the gender of the spec is already present; if so, combine qualifiers.
			local saw_existing = false
			for _, existing_spec in ipairs(alternant_multiword_spec.genders) do
				if existing_spec.spec == spec.spec then
					existing_spec.qualifiers = iut.combine_footnotes(existing_spec.qualifiers, spec.qualifiers)
					saw_existing = true
					break
				end
			end
			-- If not, add gender.
			if not saw_existing then
				table.insert(alternant_multiword_spec.genders, spec)
			end
		end
	end)
	-- Now convert the footnotes in the gender specs to qualifiers. This involves removing brackets and expanding any
	-- footnote abbreviations.
	for _, genderspec in ipairs(alternant_multiword_spec.genders) do
		if genderspec.qualifiers then
			local processed_qualifiers = {}
			for _, qualifier in ipairs(genderspec.qualifiers) do
				m_table.insertIfNot(processed_qualifiers,
					iut.expand_footnote_or_references(qualifier, "return raw", "no parse refs"))
			end
			genderspec.qualifiers = processed_qualifiers
		end
	end
end


local function process_dim_m_f_n(alternant_multiword_spec, arg_specs, default, literal_default, slot, desc)
	local lemmas = export.get_lemmas(alternant_multiword_spec)
	lemmas = iut.map_forms(lemmas, function(form)
		return rsub(form, "e$", "")
	end)

	for _, spec in ipairs(arg_specs) do
		local function parse_err(msg)
			error(msg .. ": " .. spec)
		end
		local segments = iut.parse_balanced_segment_run(spec, "[", "]")
		-- Allow comma (preferred) or colon as separator.
		local ending_specs = com.fetch_specs(iut, segments, "[,:]", desc, nil, parse_err)

		-- FIXME, this should propagate the 'ss' property upwards
		local props = {}
		local function do_combine_stem_ending(stem, ending)
			return combine_stem_ending(props, stem, ending)
		end

		local function process(stem, ending)
			iut.add_forms(alternant_multiword_spec.forms, slot, stem or lemmas, ending, do_combine_stem_ending)
		end

		process_spec(ending_specs, nil, default, literal_default, desc, process)
	end
end


local function show_forms(alternant_multiword_spec)
	local lemmas = export.get_lemmas(alternant_multiword_spec)
	local props = {
		lang = lang,
		lemmas = lemmas,
		slot_list = alternant_multiword_spec.props.surname and surname_slot_list_with_linked_and_articles
			or alternant_multiword_spec.props.langname and langname_slot_list_with_linked_and_articles
			or alternant_multiword_spec.props.overall_adj and adjectival_slot_list_with_linked_and_articles
			or noun_slot_list_with_linked_and_articles,
	}
	iut.show_forms(alternant_multiword_spec.forms, props)
end


local noun_template_both = [=[
<div class="NavFrame">
<div class="NavHead">{title}{annotation}</div>
<div class="NavContent">
{\op}| border="1px solid #505050" style="border-collapse:collapse; background:#FAFAFA; text-align:center; width:100%" class="inflection-table inflection-table-de inflection-table-de-{decl_type}"
! style="background:#AAB8C0;width:15%" |
! colspan="3" style="background:#AAB8C0;width:46%" | singular
! colspan="2" style="background:#AAB8C0;width:39%" | plural
|-
! style="background:#BBC9D0" |
! style="background:#BBC9D0;width:7%" | [[indefinite article|indef.]]
! style="background:#BBC9D0;width:7%" | [[definite article|def.]]
! style="background:#BBC9D0;width:32%" | noun
! style="background:#BBC9D0;width:7%" | [[definite article|def.]]
! style="background:#BBC9D0;width:32%" | noun
|-
! style="background:#BBC9D0" | nominative
| style="background:#EEEEEE" | {art_ind_nom_s}
| style="background:#EEEEEE" | {art_def_nom_s}
| {nom_s}
| style="background:#EEEEEE" | {art_def_nom_p}
| {nom_p}
|-
! style="background:#BBC9D0" | genitive
| style="background:#EEEEEE" | {art_ind_gen_s}
| style="background:#EEEEEE" | {art_def_gen_s}
| {gen_s}
| style="background:#EEEEEE" | {art_def_gen_p}
| {gen_p}
|-
! style="background:#BBC9D0" | dative
| style="background:#EEEEEE" | {art_ind_dat_s}
| style="background:#EEEEEE" | {art_def_dat_s}
| {dat_s}
| style="background:#EEEEEE" | {art_def_dat_p}
| {dat_p}
|-
! style="background:#BBC9D0" | accusative
| style="background:#EEEEEE" | {art_ind_acc_s}
| style="background:#EEEEEE" | {art_def_acc_s}
| {acc_s}
| style="background:#EEEEEE" | {art_def_acc_p}
| {acc_p}
|{\cl}{notes_clause}</div></div>]=]


local noun_template_both_no_indef = [=[
<div class="NavFrame" style="width:93%">
<div class="NavHead">{title}{annotation}</div>
<div class="NavContent">
{\op}| border="1px solid #505050" style="border-collapse:collapse; background:#FAFAFA; text-align:center; width:100%" class="inflection-table inflection-table-de inflection-table-de-{decl_type}"
! style="background:#AAB8C0;width:15%" |
! colspan="2" style="background:#AAB8C0;width:39%" | singular
! colspan="2" style="background:#AAB8C0;width:39%" | plural
|-
! style="background:#BBC9D0" |
! style="background:#BBC9D0;width:7%" | [[definite article|def.]]
! style="background:#BBC9D0;width:32%" | noun
! style="background:#BBC9D0;width:7%" | [[definite article|def.]]
! style="background:#BBC9D0;width:32%" | noun
|-
! style="background:#BBC9D0" | nominative
| style="background:#EEEEEE" | {art_def_nom_s}
| {nom_s}
| style="background:#EEEEEE" | {art_def_nom_p}
| {nom_p}
|-
! style="background:#BBC9D0" | genitive
| style="background:#EEEEEE" | {art_def_gen_s}
| {gen_s}
| style="background:#EEEEEE" | {art_def_gen_p}
| {gen_p}
|-
! style="background:#BBC9D0" | dative
| style="background:#EEEEEE" | {art_def_dat_s}
| {dat_s}
| style="background:#EEEEEE" | {art_def_dat_p}
| {dat_p}
|-
! style="background:#BBC9D0" | accusative
| style="background:#EEEEEE" | {art_def_acc_s}
| {acc_s}
| style="background:#EEEEEE" | {art_def_acc_p}
| {acc_p}
|{\cl}{notes_clause}</div></div>]=]


local noun_template_abl_voc = [=[

|-
! style="background:#BBC9D0" | ablative
| style="background:#EEEEEE" | {art_ind_abl_s}
| style="background:#EEEEEE" | {art_def_abl_s}
| {abl_s}
|-
! style="background:#BBC9D0" | vocative
| style="background:#EEEEEE" | {art_ind_voc_s}
| style="background:#EEEEEE" | {art_def_voc_s}
| {voc_s}]=]


local noun_template_sg = [=[
<div class="NavFrame" style="width:61%">
<div class="NavHead">{title}{annotation}</div>
<div class="NavContent">
{\op}| border="1px solid #505050" style="border-collapse:collapse; background:#FAFAFA; text-align:center; width:100%" class="inflection-table inflection-table-de inflection-table-de-{decl_type}"
! style="background:#AAB8C0;width:24.6%" |
! colspan="3" style="background:#AAB8C0;" | singular
|-
! style="background:#BBC9D0" |
! style="background:#BBC9D0;width:11.5%" | [[indefinite article|indef.]]
! style="background:#BBC9D0;width:11.5%" | [[definite article|def.]]
! style="background:#BBC9D0;width:52.5%" | noun
|-
! style="background:#BBC9D0" | nominative
| style="background:#EEEEEE" | {art_ind_nom_s}
| style="background:#EEEEEE" | {art_def_nom_s}
| {nom_s}
|-
! style="background:#BBC9D0" | genitive
| style="background:#EEEEEE" | {art_ind_gen_s}
| style="background:#EEEEEE" | {art_def_gen_s}
| {gen_s}
|-
! style="background:#BBC9D0" | dative
| style="background:#EEEEEE" | {art_ind_dat_s}
| style="background:#EEEEEE" | {art_def_dat_s}
| {dat_s}
|-
! style="background:#BBC9D0" | accusative
| style="background:#EEEEEE" | {art_ind_acc_s}
| style="background:#EEEEEE" | {art_def_acc_s}
| {acc_s}{abl_voc_clause}
|{\cl}{notes_clause}</div></div>]=]


local noun_template_sg_no_indef = [=[
<div class="NavFrame" style="width:50%">
<div class="NavHead">{title}{annotation}</div>
<div class="NavContent">
{\op}| border="1px solid #505050" style="border-collapse:collapse; background:#FAFAFA; text-align:center; width:100%" class="inflection-table inflection-table-de inflection-table-de-{decl_type}"
! style="background:#AAB8C0;width:24.6%" |
! colspan="2" style="background:#AAB8C0;" | singular
|-
! style="background:#BBC9D0" |
! style="background:#BBC9D0;width:11.5%" | [[definite article|def.]]
! style="background:#BBC9D0;width:52.5%" | noun
|-
! style="background:#BBC9D0" | nominative
| style="background:#EEEEEE" | {art_def_nom_s}
| {nom_s}
|-
! style="background:#BBC9D0" | genitive
| style="background:#EEEEEE" | {art_def_gen_s}
| {gen_s}
|-
! style="background:#BBC9D0" | dative
| style="background:#EEEEEE" | {art_def_dat_s}
| {dat_s}
|-
! style="background:#BBC9D0" | accusative
| style="background:#EEEEEE" | {art_def_acc_s}
| {acc_s}{abl_voc_clause}
|{\cl}{notes_clause}</div></div>]=]


local noun_template_pl = [=[
<div class="NavFrame" style="width:61%">
<div class="NavHead">{title}{annotation}</div>
<div class="NavContent">
{\op}| border="1px solid #505050" style="border-collapse:collapse; background:#FAFAFA; text-align:center; width:100%" class="inflection-table inflection-table-de inflection-table-de-{decl_type}"
! style="background:#AAB8C0;width:24.6%" |
! colspan="2" style="background:#AAB8C0;" | plural
|-
! style="background:#BBC9D0" |
! style="background:#BBC9D0;width:11.5%" | [[definite article|def.]]
! style="background:#BBC9D0;width:52.5%" | noun
|-
! style="background:#BBC9D0" | nominative
| style="background:#EEEEEE" | {art_def_nom_p}
| {nom_p}
|-
! style="background:#BBC9D0" | genitive
| style="background:#EEEEEE" | {art_def_gen_p}
| {gen_p}
|-
! style="background:#BBC9D0" | dative
| style="background:#EEEEEE" | {art_def_dat_p}
| {dat_p}
|-
! style="background:#BBC9D0" | accusative
| style="background:#EEEEEE" | {art_def_acc_p}
| {acc_p}
|{\cl}{notes_clause}</div></div>]=]


local noun_template_surname = [=[
<div class="NavFrame">
<div class="NavHead">{title}{annotation}</div>
<div class="NavContent">
{\op}| border="1px solid #505050" style="border-collapse:collapse; background:#FAFAFA; text-align:center; width:100%" class="inflection-table inflection-table-de inflection-table-de-{decl_type}"
! rowspan="2" style="background:#AAB8C0;width:11%" |
! colspan="6" style="background:#AAB8C0" | singular
! colspan="2" rowspan="2" style="background:#AAB8C0" | plural
|-
! colspan="3" style="background:#AAB8C0" | masculine
! colspan="3" style="background:#AAB8C0" | feminine
|-
! style="background:#BBC9D0" |
! style="background:#BBC9D0;width:4%" | [[indefinite article|indef.]]
! style="background:#BBC9D0;width:4%" | [[definite article|def.]]
! style="background:#BBC9D0;width:23%" | noun
! style="background:#BBC9D0;width:4%" | [[indefinite article|indef.]]
! style="background:#BBC9D0;width:4%" | [[definite article|def.]]
! style="background:#BBC9D0;width:23%" | noun
! style="background:#BBC9D0;width:4%" | [[definite article|def.]]
! style="background:#BBC9D0;width:23%" | noun
|-
! style="background:#BBC9D0" | nominative
| style="background:#EEEEEE" | {art_ind_nom_m_s}
| style="background:#EEEEEE" | {art_def_nom_m_s}
| {nom_m_s}
| style="background:#EEEEEE" | {art_ind_nom_f_s}
| style="background:#EEEEEE" | {art_def_nom_f_s}
| {nom_f_s}
| style="background:#EEEEEE" | {art_def_nom_p}
| {nom_p}
|-
! style="background:#BBC9D0" | genitive
| style="background:#EEEEEE" | {art_ind_gen_m_s}
| style="background:#EEEEEE" | {art_def_gen_m_s}
| {gen_m_s}
| style="background:#EEEEEE" | {art_ind_gen_f_s}
| style="background:#EEEEEE" | {art_def_gen_f_s}
| {gen_f_s}
| style="background:#EEEEEE" | {art_def_gen_p}
| {gen_p}
|-
! style="background:#BBC9D0" | dative
| style="background:#EEEEEE" | {art_ind_dat_m_s}
| style="background:#EEEEEE" | {art_def_dat_m_s}
| {dat_m_s}
| style="background:#EEEEEE" | {art_ind_dat_f_s}
| style="background:#EEEEEE" | {art_def_dat_f_s}
| {dat_f_s}
| style="background:#EEEEEE" | {art_def_dat_p}
| {dat_p}
|-
! style="background:#BBC9D0" | accusative
| style="background:#EEEEEE" | {art_ind_acc_m_s}
| style="background:#EEEEEE" | {art_def_acc_m_s}
| {acc_m_s}
| style="background:#EEEEEE" | {art_ind_acc_f_s}
| style="background:#EEEEEE" | {art_def_acc_f_s}
| {acc_f_s}
| style="background:#EEEEEE" | {art_def_acc_p}
| {acc_p}
|{\cl}{notes_clause}</div></div>]=]


local noun_template_langname = [=[
<div class="NavFrame" style="width:100%">
<div class="NavHead">{title}{annotation}</div>
<div class="NavContent">
{\op}| border="1px solid #505050" style="border-collapse:collapse; background:#FAFAFA; text-align:center; width:100%" class="inflection-table inflection-table-de inflection-table-de-langname"
! style="background:#AAB8C0;width:15%" | 
! colspan="5" style="background:#AAB8C0;width:85%" | singular &nbsp; ''([[Wiktionary:About German#Declension of language names|explanation of the use and meaning of the forms]])''
|-
! style="background:#BBC9D0" |
! style="background:#BBC9D0;width:14%" | (usually without article)
! style="background:#BBC9D0;width:32%" | noun
! style="background:#BBC9D0;width:7%" | [[definite article|def.]]
! style="background:#BBC9D0;width:32%" | noun
|-
! style="background:#BBC9D0" | nominative
| style="background:#EEEEEE" | ({art_def_nom_s})
| {nom_s}
| style="background:#EEEEEE" | {art_def_nom_s}
| {nom_s_alt}
|-
! style="background:#BBC9D0" | genitive
| style="background:#EEEEEE" | ({art_def_gen_s})
| {gen_s}
| style="background:#EEEEEE" | {art_def_gen_s}
| {gen_s_alt}
|-
! style="background:#BBC9D0" | dative
| style="background:#EEEEEE" | ({art_def_dat_s})
| {dat_s}
| style="background:#EEEEEE" | {art_def_dat_s}
| {dat_s_alt}
|-
! style="background:#BBC9D0" | accusative
| style="background:#EEEEEE" | ({art_def_acc_s})
| {acc_s}
| style="background:#EEEEEE" | {art_def_acc_s}
| {acc_s_alt}
|{\cl}{notes_clause}</div></div>]=]


local adjectival_template_both = [=[
<div class="NavFrame">
<div class="NavHead">{title}{annotation}</div>
<div class="NavContent">
{\op}| border="1px solid #505050" style="border-collapse:collapse; background:#FAFAFA; text-align:center; width:100%" class="inflection-table"
! style="background:#BBC9D0;width:15%" |
! colspan="2" style="background:#BBC9D0" | singular
! colspan="2" style="background:#BBC9D0" | plural
|-
! style="background:#AAB8C0" | {gender}
! colspan="4" style="background:#AAB8C0" | strong declension
|-
! style="background:#BBC9D0" | nominative
| colspan="2" | {str_nom_s}
| colspan="2" | {str_nom_p}
|-
! style="background:#BBC9D0" | genitive
| colspan="2" | {str_gen_s}
| colspan="2" | {str_gen_p}
|-
! style="background:#BBC9D0" | dative
| colspan="2" | {str_dat_s}
| colspan="2" | {str_dat_p}
|-
! style="background:#BBC9D0" | accusative
| colspan="2" | {str_acc_s}
| colspan="2" | {str_acc_p}
|-
! style="background:#AAB8C0" |
! colspan="4" style="background:#AAB8C0" | weak declension
|-
! style="background:#BBC9D0" | nominative
| style="background:#EEEEEE;width:5em" | {art_def_nom_s}
| {wk_nom_s}
| style="background:#EEEEEE;width:5em" | {art_def_nom_p}
| {wk_nom_p}
|-
! style="background:#BBC9D0" | genitive
| style="background:#EEEEEE;width:5em" | {art_def_gen_s}
| {wk_gen_s}
| style="background:#EEEEEE;width:5em" | {art_def_gen_p}
| {wk_gen_p}
|-
! style="background:#BBC9D0" | dative
| style="background:#EEEEEE;width:5em" | {art_def_dat_s}
| {wk_dat_s}
| style="background:#EEEEEE;width:5em" | {art_def_dat_p}
| {wk_dat_p}
|-
! style="background:#BBC9D0" | accusative
| style="background:#EEEEEE;width:5em" | {art_def_acc_s}
| {wk_acc_s}
| style="background:#EEEEEE;width:5em" | {art_def_acc_p}
| {wk_acc_p}
|-
! style="background:#AAB8C0" |
! colspan="4" style="background:#AAB8C0" | mixed declension
|-
! style="background:#BBC9D0" | nominative
| style="background:#EEEEEE;width:5em" | {art_ind_nom_s}
| {mix_nom_s}
| style="background:#EEEEEE;width:5em" | {art_ind_nom_p}
| {mix_nom_p}
|-
! style="background:#BBC9D0" | genitive
| style="background:#EEEEEE;width:5em" | {art_ind_gen_s}
| {mix_gen_s}
| style="background:#EEEEEE;width:5em" | {art_ind_gen_p}
| {mix_gen_p}
|-
! style="background:#BBC9D0" | dative
| style="background:#EEEEEE;width:5em" | {art_ind_dat_s}
| {mix_dat_s}
| style="background:#EEEEEE;width:5em" | {art_ind_dat_p}
| {mix_dat_p}
|-
! style="background:#BBC9D0" | accusative
| style="background:#EEEEEE;width:5em" | {art_ind_acc_s}
| {mix_acc_s}
| style="background:#EEEEEE;width:5em" | {art_ind_acc_p}
| {mix_acc_p}
|{\cl}{notes_clause}</div></div>]=]


local adjectival_template_sg = [=[
<div class="NavFrame" style="width:500px">
<div class="NavHead">{title}{annotation}</div>
<div class="NavContent">
{| border="1px solid #505050" style="border-collapse:collapse; background:#FAFAFA; text-align:center; width:100%" class="inflection-table"
! style="background:#BBC9D0;width:15%" |
! colspan="2" style="background:#BBC9D0" | singular
|-
! style="background:#AAB8C0" | {gender}
! colspan="2" style="background:#AAB8C0" | strong declension
|-
! style="background:#BBC9D0" | nominative
| colspan="2" | {str_nom_s}
|-
! style="background:#BBC9D0" | genitive
| colspan="2" | {str_gen_s}
|-
! style="background:#BBC9D0" | dative
| colspan="2" | {str_dat_s}
|-
! style="background:#BBC9D0" | accusative
| colspan="2" | {str_acc_s}
|-
! style="background:#AAB8C0" |
! colspan="2" style="background:#AAB8C0" | weak declension
|-
! style="background:#BBC9D0" | nominative
| style="background:#EEEEEE;width:5em" | {art_def_nom_s}
| {wk_nom_s}
|-
! style="background:#BBC9D0" | genitive
| style="background:#EEEEEE;width:5em" | {art_def_gen_s}
| {wk_gen_s}
|-
! style="background:#BBC9D0" | dative
| style="background:#EEEEEE;width:5em" | {art_def_dat_s}
| {wk_dat_s}
|-
! style="background:#BBC9D0" | accusative
| style="background:#EEEEEE;width:5em" | {art_def_acc_s}
| {wk_acc_s}
|-
! style="background:#AAB8C0" |
! colspan="2" style="background:#AAB8C0" | mixed declension
|-
! style="background:#BBC9D0" | nominative
| style="background:#EEEEEE;width:5em" | {art_ind_nom_s}
| {mix_nom_s}
|-
! style="background:#BBC9D0" | genitive
| style="background:#EEEEEE;width:5em" | {art_ind_gen_s}
| {mix_gen_s}
|-
! style="background:#BBC9D0" | dative
| style="background:#EEEEEE;width:5em" | {art_ind_dat_s}
| {mix_dat_s}
|-
! style="background:#BBC9D0" | accusative
| style="background:#EEEEEE;width:5em" | {art_ind_acc_s}
| {mix_acc_s}
|{\cl}{notes_clause}</div></div>]=]


local notes_template = [===[
<div style="width:100%;text-align:left;background:#d9ebff">
<div style="display:inline-block;text-align:left;padding-left:1em;padding-right:1em">
{footnote}
</div></div>
]===]


local function make_table(alternant_multiword_spec)
	local forms = alternant_multiword_spec.forms

	if alternant_multiword_spec.title then
		forms.title = alternant_multiword_spec.title
	else
		forms.title = 'Declension of <i lang="de" class="Latn">' .. forms.lemma .. '</i>'
	end

	local annotation = alternant_multiword_spec.annotation
	if annotation == "" then
		forms.annotation = ""
	else
		forms.annotation = " [<span style=\"font-size: smaller;\">" .. annotation .. "</span>]"
	end

	local table_spec
	if alternant_multiword_spec.props.surname then
		table_spec = noun_template_surname
	elseif alternant_multiword_spec.props.langname then
		table_spec = noun_template_langname
	elseif alternant_multiword_spec.props.overall_adj then
		table_spec =
			alternant_multiword_spec.number == "sg" and adjectival_template_sg or
			alternant_multiword_spec.number == "pl" and rsub(rsub(adjectival_template_sg, "singular", "plural"), "_s}", "_p}") or
			adjectival_template_both
		if alternant_multiword_spec.number == "pl" then
			forms.gender = ""
		else
			local genderdesc_parts = {}
			for _, gender in ipairs(alternant_multiword_spec.genders) do
				table.insert(genderdesc_parts, gender_spec_to_full_gender[gender.spec])
			end
			forms.gender = "''" .. table.concat(genderdesc_parts, " or ") .. " gender ''"
		end
	else
		local no_indef =
			alternant_multiword_spec.special_proper and special_proper_nouns[alternant_multiword_spec.special_proper].no_indef
			or alternant_multiword_spec.props.article
		table_spec =
			alternant_multiword_spec.number == "sg" and (no_indef and noun_template_sg_no_indef or noun_template_sg) or
			alternant_multiword_spec.number == "pl" and noun_template_pl or
			(no_indef and noun_template_both_no_indef or noun_template_both)
		if forms.abl_s ~= "—" or forms.voc_s ~= "—" then
			forms.abl_voc_clause = m_string_utilities.format(noun_template_abl_voc, forms)
		else
			forms.abl_voc_clause = ""
		end
	end
	forms.notes_clause = forms.footnote ~= "" and
		m_string_utilities.format(notes_template, forms) or ""
	return m_string_utilities.format(table_spec, forms)
end


-- Externally callable function to parse and decline a noun given user-specified arguments. Return value is
-- ALTERNANT_MULTIWORD_SPEC, an object where the declined forms are in `ALTERNANT_MULTIWORD_SPEC.forms` for each slot.
-- If there are no values for a slot, the slot key will be missing. The value for a given slot is a list of objects
-- {form=FORM, footnotes=FOOTNOTES}.
function export.do_generate_forms(parent_args, pos, from_headword, is_proper, def)
	local params = {
		[1] = {required = true, default = "Haus<n,es,^er>"},
		pagename = {},
	}

	if from_headword or pretend_from_headword then
		params["head"] = {list = true}
		params["f"] = {list = true}
		params["m"] = {list = true}
		params["n"] = {list = true}
		params["dim"] = {list = true}
		params["sg"] = {list = true}
		params["id"] = {}
		params["sort"] = {}
		params["splithyph"] = {type = "boolean"}
		params["nolinkhead"] = {type = "boolean"}
	end

	local args = require("Module:parameters").process(parent_args, params)

	local arg1 = args[1]
	local need_surrounding_angle_brackets = true
	-- Check whether we need to add <...> around the argument. If the
	-- argument has no < in it, we definitely do. Otherwise, we need to
	-- parse the balanced [...] and <...> and add <...> only if there isn't
	-- a top-level <...>. We check for [...] because there might be angle
	-- brackets inside of them (HTML tags in qualifiers or <<name:...>> and
	-- such in references).
	if arg1:find("<") then
		local segments = iut.parse_multi_delimiter_balanced_segment_run(arg1, {{"<", ">"}, {"[", "]"}})
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

	local pagename = args.pagename or mw.title.getCurrentTitle().text

	local function do_parse_indicator_spec(angle_bracket_spec, lemma)
		return parse_indicator_spec(angle_bracket_spec, lemma, pagename)
	end

	local parse_props = {
		parse_indicator_spec = do_parse_indicator_spec,
		allow_default_indicator = true,
		allow_blank_lemma = true,
	}
	local alternant_multiword_spec = iut.parse_inflected_text(arg1, parse_props)
	alternant_multiword_spec.args = args
	alternant_multiword_spec.props = {}
	alternant_multiword_spec.props.is_proper = is_proper
	detect_all_indicator_specs(alternant_multiword_spec)
	local default_number = get_default_number(alternant_multiword_spec, nil)
	propagate_properties(alternant_multiword_spec, "number", default_number, "both")
	-- FIXME, maybe should check that noun genders match adjective genders
	determine_adjectival_genders(alternant_multiword_spec)
	determine_noun_status(alternant_multiword_spec)
	local inflect_props = {
		skip_slot = function(slot)
			return skip_slot(alternant_multiword_spec.number, slot)
		end,
		slot_list = alternant_multiword_spec.props.surname and surname_slot_list_with_linked
			or alternant_multiword_spec.props.langname and langname_slot_list_with_linked
			or alternant_multiword_spec.props.overall_adj and adjectival_slot_list_with_linked
			or noun_slot_list_with_linked,
		inflect_word_spec = decline_noun_or_adjective,
	}
	iut.inflect_multiword_or_alternant_multiword_spec(alternant_multiword_spec, inflect_props)
	compute_articles(alternant_multiword_spec)
	compute_headword_genders(alternant_multiword_spec)
	if not pos then
		-- Compute part of speech for categories. Fetch the first lemma, or failing that (which would only happen
		-- if the user overrides the nom_sg and nom_p to be missing) the pagename. If it begins with a hyphen,
		-- it's a suffix, else a noun (proper nouns get categorized like nouns).
		local lemmas = export.get_lemmas(alternant_multiword_spec)
		local first_lemma = #lemmas > 0 and lemmas[1].form or pagename
		pos = rfind(first_lemma, "^%-") and "suffixes" or "nouns"
	end
	alternant_multiword_spec.pos = pos
	compute_categories_and_annotation(alternant_multiword_spec)
	if from_headword or pretend_from_headword then
		process_dim_m_f_n(alternant_multiword_spec, args.dim, "^chen", nil, "dim", "diminutive")
		process_dim_m_f_n(alternant_multiword_spec, args.f, alternant_multiword_spec.forms.f_equiv,
			"literal default", "f", "feminine equivalent")
		process_dim_m_f_n(alternant_multiword_spec, args.m, alternant_multiword_spec.forms.m_equiv,
			"literal default", "m", "masculine equivalent")
		process_dim_m_f_n(alternant_multiword_spec, args.n, alternant_multiword_spec.forms.n_equiv,
			"literal default", "n", "neuter equivalent")
		process_dim_m_f_n(alternant_multiword_spec, args.sg, nil, nil, "sg", "singular")
	end
	return alternant_multiword_spec
end


-- Entry point for {{de-ndecl}}. Template-callable function to parse and decline a noun given
-- user-specified arguments and generate a displayable table of the declined forms.
function export.show(frame)
	local parent_args = frame:getParent().args
	local alternant_multiword_spec = export.do_generate_forms(parent_args)
	show_forms(alternant_multiword_spec)
	-- FIXME!
	alternant_multiword_spec.forms.decl_type = "foo"
	return make_table(alternant_multiword_spec) .. require("Module:utilities").format_categories(
		alternant_multiword_spec.categories, lang, nil, nil, force_cat)
end


-- Concatenate all forms of all slots into a single string of the form "SLOT=FORM,FORM,...|SLOT=FORM,FORM,...|...".
-- Embedded pipe symbols (as might occur in embedded links) are converted to <!>. If INCLUDE_PROPS is given, also
-- include additional properties (currently, g= for headword genders). This is for use by bots.
local function concat_forms(alternant_multiword_spec, include_props)
	local ins_text = {}
	for _, slotaccel in ipairs(
		alternant_multiword_spec.props.surname and surname_slot_list_with_linked or
		alternant_multiword_spec.props.langname and langname_slot_list_with_linked or
		alternant_multiword_spec.props.overall_adj and adjectival_slot_list_with_linked or
		noun_slot_list_with_linked
	) do
		local slot, accel = unpack(slotaccel)
		local formtext = iut.concat_forms_in_slot(alternant_multiword_spec.forms[slot])
		if formtext then
			table.insert(ins_text, slot .. "=" .. formtext)
		end
	end
	if include_props then
		table.insert(ins_text, "g=" .. table.concat(alternant_multiword_spec.genders, ","))
	end
	return table.concat(ins_text, "|")
end


-- Template-callable function to parse and decline a noun given user-specified arguments and return
-- the forms as a string of the same form as documented in concat_forms() above.
function export.generate_forms(frame)
	local include_props = frame.args["include_props"]
	local parent_args = frame:getParent().args
	local alternant_multiword_spec = export.do_generate_forms(parent_args)
	return concat_forms(alternant_multiword_spec, include_props)
end

return export
