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
4. Support adjectival nouns and adjective-noun combinations.
5. Allow period and comma in forms e.g. for [[Eigent.-Whg.]], [[Eigt.-Whg.]] (using a backslash). (DONE)
6. Allow embedded links in genitive/plural/feminine/diminutive/masculine specs, e.g. 'f=![[weiblich]]er Geschäftspartner'.
7. Add 'prop' indicator to indicate proper nouns and suppress the indefinite article.
]=]

local lang = require("Module:languages").getByCode("de")
local m_table = require("Module:table")
local m_links = require("Module:links")
local m_string_utilities = require("Module:string utilities")
local iut = require("Module:inflection utilities")
local com = require("Module:de-common")

local pretend_from_headword = true -- may be set during debugging
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


local noun_slots = {
	nom_s = "nom|s",
	gen_s = "gen|s",
	dat_s = "dat|s",
	acc_s = "acc|s",
	abl_s = "abl|s",
	voc_s = "voc|s",
	nom_p = "nom|p",
	gen_p = "gen|p",
	dat_p = "dat|p",
	acc_p = "acc|p",
}


local noun_slots_with_linked = m_table.shallowcopy(noun_slots)
noun_slots_with_linked["nom_s_linked"] = "nom|s"
noun_slots_with_linked["nom_p_linked"] = "nom|p"


local cases = {
	nom = true,
	gen = true,
	dat = true,
	acc = true,
	abl = true,
	voc = true,
}


local noun_slots_with_linked_and_articles = m_table.shallowcopy(noun_slots_with_linked)
for case, _ in pairs(cases) do
	noun_slots_with_linked_and_articles["art_ind_" .. case .. "_s"] = "-"
	noun_slots_with_linked_and_articles["art_def_" .. case .. "_s"] = "-"
	noun_slots_with_linked_and_articles["art_def_" .. case .. "_p"] = "-"
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


local function add(base, slot, stem, ending, footnotes, process_combined_stem_ending)
	if not ending or skip_slot(base.number, slot) then
		return
	end

	local function do_combine_stem_ending(stem, ending)
		local retval = combine_stem_ending(base.props, stem, ending)
		if process_combined_stem_ending then
			retval = process_combined_stem_ending(retval)
		end
		return retval
	end

	footnotes = iut.combine_footnotes(base.footnotes, footnotes)
	local ending_obj = iut.combine_form_and_footnotes(ending, footnotes)
	iut.add_forms(base.forms, slot, stem or base.lemma, ending_obj, do_combine_stem_ending)
end


local function process_spec(endings, default, footnotes, desc, process)
	for _, ending in ipairs(endings) do
		local function sub_form(form)
			return {form = form, footnotes = ending.footnotes}
		end

		if ending.form == "--" then
			-- do nothing
		elseif ending.form == "+" then
			if not default then
				-- Could happen if e.g. gen is given as -- and then a gen_s override with + is specified.
				error("Form '+' found for " .. desc .. " but no default is available")
			end
			process_spec(iut.convert_to_general_list_form(default, ending.footnotes), nil, footnotes, desc, process)
		else
			local full_eform
			if rfind(ending.form, "^" .. com.CAP) then
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


local function add_spec(base, slot, endings, default, footnotes, process_combined_stem_ending)
	local function do_add(stem, ending)
		add(base, slot, stem, ending, footnotes, process_combined_stem_ending)
	end
	process_spec(endings, default, footnotes, "slot '" .. slot .. "'", do_add)
end


local function process_slot_overrides(base)
	for slot, overrides in pairs(base.overrides) do
		if skip_slot(base.number, slot) then
			error("Override specified for invalid slot '" .. slot .. "' due to '" .. base.number .. "' number restriction")
		end
		local origforms = base.forms[slot]
		base.forms[slot] = nil
		add_spec(base, slot, overrides, origforms)
	end
end


local function add_dative_plural(base, specs, def_pl)
	local function process_combined_stem_ending(stem_ending)
		if base.props.nodatpln then
			return stem_ending
		elseif rfind(stem_ending, "e[lr]?$") or rfind(stem_ending, "erl$") then
			return stem_ending .. "n"
		else
			return stem_ending
		end
	end
	add_spec(base, "dat_p", specs, def_pl, nil, process_combined_stem_ending)
end


local function add_archaic_dative_singular(base, def_gen)
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
		end
		if dat_ending then
			add(base, "dat_s", nil, dat_ending, iut.combine_footnotes(ending.footnotes, {archaic_dative_note}))
		end
	end
end


local function get_n_ending(stem)
	if rfind(stem, "e$") or rfind(stem, "e[lr]$") and not rfind(stem, com.NV .. "[ei]e[lr]$") then
		-- [[Kammer]], [[Feier]], [[Leier]], but not [[Spur]], [[Beer]], [[Manier]], [[Schmier]] or [[Vier]]
		-- similarly, [[Achsel]], [[Gabel]], [[Tafel]], etc. but not [[Ziel]]
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
		return get_n_ending(base.lemma)
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
	elseif gender == "f" or base.props.weak or rfind(base.lemma, "e$") then
		return get_n_ending(base.lemma)
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


local function decline_plural(base, def_pl)
	add_spec(base, "nom_p", base.pls, def_pl)
	add_spec(base, "gen_p", base.pls, def_pl)
	add_dative_plural(base, base.pls, def_pl)
	add_spec(base, "acc_p", base.pls, def_pl)
end


local function decline_singular_and_plural(base, gender, def_gen, def_pl)
	add(base, "nom_s", nil, "")
	add_spec(base, "gen_s", base.gens, def_gen)
	if base.props.weak then
		local ending = get_n_ending(base.lemma)
		add(base, "dat_s", nil, ending)
		add(base, "acc_s", nil, gender == "m" and ending or "")
	else
		add(base, "dat_s", nil, "")
		add_archaic_dative_singular(base, def_gen)
		add(base, "acc_s", nil, "")
	end
	decline_plural(base, def_pl)
end


local function decline(base)
	if base.number == "pl" then
		decline_plural(base, "")
	else
		for _, genderspec in ipairs(base.genders) do
			local gender = genderspec.form
			decline_singular_and_plural(base, gender, get_default_gen(base, gender), get_default_pl(base, gender))
		end
	end
end


local function handle_derived_slots_and_overrides(base)
	process_slot_overrides(base)

	-- Compute linked versions of potential lemma slots, for use in {{de-noun}}.
	-- We substitute the original lemma (before removing links) for forms that
	-- are the same as the lemma, if the original lemma has links.
	for _, slot in ipairs({"nom_s", "nom_p"}) do
		iut.insert_forms(base.forms, slot .. "_linked", iut.map_forms(base.forms[slot], function(form)
			if form == base.orig_lemma_no_links and rfind(base.orig_lemma, "%[%[") then
				return base.orig_lemma
			else
				return form
			end
		end))
	end
end


--[=[
decls["adj"] = function(base, stress)
	local adj_alternant_spec = require("Module:de-adjective").do_generate_forms(
		{base.lemma}
	)
	local function copy(from_slot, to_slot)
		base.forms[to_slot] = adj_alternant_spec.forms[from_slot]
	end
	if base.number ~= "pl" then
		copy("dir_m_s", "dir_s")
		copy("obl_m_s", "obl_s")
		copy("voc_m_s", "voc_s")
	end
	if base.number ~= "sg" then
		copy("dir_m_p", "dir_p")
		copy("obl_m_p", "obl_p")
		copy("voc_m_p", "voc_p")
	end
end
]=]


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
		if not cases[case] then
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
		if not noun_slots[slot] then
			parse_err("Unrecognized slot indicator '" .. indicator .. "': '" .. table.concat(segments) .. "'")
		end
		segments[1] = rest
		return slot, indicator, com.fetch_specs(iut, segments, ":", "override", nil, parse_err)
	end

	if inside ~= "" then
		local segments = iut.parse_balanced_segment_run(inside, "[", "]")
		local dot_separated_groups = split_alternating_runs_with_escapes(segments, "%.")
		for i, dot_separated_group in ipairs(dot_separated_groups) do
			local part = dot_separated_group[1]
			if i == 1 then
				local comma_separated_groups = split_alternating_runs_with_escapes(dot_separated_group, ",")
				base.genders = com.fetch_specs(iut, comma_separated_groups[1], ":", "gender", nil, parse_err)
				local saw_sg = false
				local saw_pl = false
				local saw_mn = false
				for _, genderspec in ipairs(base.genders) do
					local g = genderspec.form
					if g == "m" or g == "n" then
						saw_mn = true
						saw_sg = true
					elseif g == "f" then
						saw_sg = true
					elseif g == "p" then
						saw_pl = true
					else
						parse_err("Unrecognized gender spec '" .. g .. "'")
					end
				end
				if saw_sg and saw_pl then
					parse_err("Can't specify both singular and plural gender specs")
				end
				local pl_index = saw_mn and 3 or saw_pl and 1 or 2
				if #comma_separated_groups > 1 and saw_mn then
					base.gens = com.fetch_specs(iut, comma_separated_groups[2], ":", "genitive", "allow blank", parse_err)
				end
				if #comma_separated_groups >= pl_index and not saw_pl then
					base.pls = com.fetch_specs(iut, comma_separated_groups[pl_index], ":", "plural", "allow blank", parse_err)
				end
				if #comma_separated_groups > pl_index then
					if saw_pl then
						parse_err("Can't specify plurals with plural-only nouns")
					elseif saw_mn then
						parse_err("Can specify at most three comma-separated specs when the gender is masculine or "
							.. "neuter (gender, genitive, plural)")
					else
						parse_err("Can specify at most two comma-separated specs when then gender is feminine "
							.. "(gender, plural)")
					end
				end
				if saw_pl then
					if #base.genders > 1 then
						parse_err("Internal error: More than one gender spec when gender spec is plural")
					elseif base.genders[1].footnotes then
						parse_err("Can't specify footnotes with 'pl' gender spec")
					else
						base.genders = {}
						base.number = "pl"
					end
				end
			elseif part == "" then
				if #dot_separated_group == 1 then
					parse_err("Blank indicator")
				end
				base.footnotes = com.fetch_footnotes(dot_separated_group, parse_err)
			elseif part:find(":") then
				-- override
				local case_prefix = usub(part, 1, 3)
				if cases[case_prefix] then
					local slot, slot_indicator, override = parse_override(dot_separated_group)
					if base.overrides[slot] then
						parse_err("Can't specify override twice for slot '" .. slot_indicator .. "'")
					else
						base.overrides[slot] = override
					end
				else
				parse_err("Unrecognized indicator '" .. part .. "'")
				end
			elseif #dot_separated_group > 1 then
				parse_err("Footnotes only allowed with slot overrides or by themselves: '" .. table.concat(dot_separated_group) .. "'")
			elseif part == "sg" or part == "both" then
				if base.number then
					if base.number ~= part then
						parse_err("Can't specify '" .. part .. "' along with '" .. base.number .. "'")
					else
						parse_err("Can't specify '" .. part .. "' twice")
					end
				end
				base.number = part
			elseif part == "+" then
				if base.props.adj then
					parse_err("Can't specify '+' twice")
				end
				base.props.adj = true
			elseif part == "weak" or part == "ss" or part == "nodatpln" then
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


local function detect_indicator_spec(alternant_multiword_spec, base)
	-- Set default values.
	if not base.props.adj then
		base.number = base.number or base.pls and "both" or alternant_multiword_spec.is_proper and "sg" or "both"
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
	if base.props.adj then
		synthesize_adj_lemma(base)
	end
end


local function detect_all_indicator_specs(alternant_multiword_spec)
	iut.map_word_specs(alternant_multiword_spec, function(base)
		detect_indicator_spec(alternant_multiword_spec, base)
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
Propagate `property` ("gender" or "number") from nouns to adjacent adjectives. We proceed as follows:
1. We assume the properties in question are already set on all nouns. This should happen
   in set_defaults_and_check_bad_indicators().
2. We first propagate properties upwards and sideways. We recurse downwards from the top.
   When we encounter a multiword spec, we proceed left to right looking for a noun.
   When we find a noun, we fetch its property (recursing if the noun is an alternant),
   and propagate it to any adjectives to its left, up to the next noun to the left.
   When we have processed the last noun, we also propagate its property value to any
   adjectives to the right (to handle e.g. [[пустальга звычайная]] "common kestrel", where
   the adjective польовий should inherit the 'animal' animacy of лунь). Finally, we set
   the property value for the multiword spec itself by combining all the non-nil
   properties of the individual elements. If all non-nil properties have the same value,
   the result is that value, otherwise it is `mixed_value` (which is "mixed" for animacy
   and gender, but "both" for number).
3. When we encounter an alternant spec in this process, we recursively process each
   alternant (which is a multiword spec) using the previous step, and combine any
   non-nil properties we encounter the same way as for multiword specs.
4. The effect of steps 2 and 3 is to set the property of each alternant and multiword
   spec based on its children or its neighbors.
]=]
local function propagate_properties(alternant_multiword_spec, property, default_propval, mixed_value)
	propagate_multiword_properties(alternant_multiword_spec, property, mixed_value, "nouns only")
	propagate_multiword_properties(alternant_multiword_spec, property, mixed_value, false)
	propagate_properties_downward(alternant_multiword_spec, property, default_propval)
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


local function decline_noun(base)
	decline(base)
	handle_derived_slots_and_overrides(base)
end


-- Set the overall articles. We can't do this using the normal inflection code as it will produce e.g.
-- '[[der]] [[und]] [[der]]' for conjoined nouns.
local function compute_articles(alternant_multiword_spec)
	iut.map_word_specs(alternant_multiword_spec, function(base)
		for _, genderspec in ipairs(base.genders) do
			for case, _ in pairs(cases) do
				iut.insert_form(alternant_multiword_spec.forms, "art_ind_" .. case .. "_s",
					{form = com.articles[genderspec.form]["ind_" .. case]})
				iut.insert_form(alternant_multiword_spec.forms, "art_def_" .. case .. "_s",
					{form = com.articles[genderspec.form]["def_" .. case]})
			end
		end
	end)
	for case, _ in pairs(cases) do
		iut.insert_form(alternant_multiword_spec.forms, "art_def_" .. case .. "_p",
			{form = com.articles.p["def_" .. case]})
	end
end


-- Compute the categories to add the noun to, as well as the annotation to display in the
-- declension title bar. We combine the code to do these functions as both categories and
-- title bar contain similar information.
local function compute_categories_and_annotation(alternant_multiword_spec)
	alternant_multiword_spec.categories = {}
	alternant_multiword_spec.props = {}

	local function insert(cattype)
		cattype = rsub(cattype, "~", alternant_multiword_spec.pos)
		m_table.insertIfNot(alternant_multiword_spec.categories, "German " .. cattype)
	end
	if not alternant_multiword_spec.is_proper and alternant_multiword_spec.number == "sg" then
		insert("uncountable ~")
	elseif alternant_multiword_spec.number == "pl" then
		insert("pluralia tantum")
	end
	local annotation
	local annparts = {}
	local genderdescs = {}
	local decldescs = {}
	local function do_word_spec(base)
		local saw_m_or_n = false
		for _, gender in ipairs(base.genders) do
			if gender.form == "m" then
				m_table.insertIfNot(genderdescs, "masc")
				saw_m_or_n = true
			elseif gender.form == "f" then
				m_table.insertIfNot(genderdescs, "fem")
			elseif gender.form == "n" then
				m_table.insertIfNot(genderdescs, "neut")
				saw_m_or_n = true
			else
				error("Internal error: Unrecognized gender '" .. gender.form .. "'")
			end
		end
		if saw_m_or_n then
			if base.props.weak then
				insert("weak ~")
				m_table.insertIfNot(decldescs, "weak")
			else
				m_table.insertIfNot(decldescs, "strong")
			end
			-- Compute overall weakness for use in headword.
			if alternant_multiword_spec.props.weak == nil then
				alternant_multiword_spec.props.weak = base.props.weak
			elseif alternant_multiword_spec.props.weak ~= base.props.weak then
				alternant_multiword_spec.props.weak = "both"
			end
		end
	end
	local key_entry = alternant_multiword_spec.first_noun or alternant_multiword_spec.first_adj or 1
	if #alternant_multiword_spec.alternant_or_word_specs >= key_entry then
		local alternant_or_word_spec = alternant_multiword_spec.alternant_or_word_specs[key_entry]
		if alternant_or_word_spec.alternants then
			for _, multiword_spec in ipairs(alternant_or_word_spec.alternants) do
				key_entry = multiword_spec.first_noun or multiword_spec.first_adj or 1
				if #multiword_spec.word_specs >= key_entry then
					do_word_spec(multiword_spec.word_specs[key_entry])
				end
			end
		else
			do_word_spec(alternant_or_word_spec)
		end
	end
	if alternant_multiword_spec.number ~= "both" then
		table.insert(annparts, alternant_multiword_spec.number == "sg" and "sg-only" or "pl-only")
	end
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
	alternant_multiword_spec.annotation = table.concat(annparts, " ")
end


local function process_dim_m_f(alternant_multiword_spec, arg_specs, default, slot, desc)
	local lemmas = alternant_multiword_spec.forms.nom_s or alternant_multiword_spec.forms.nom_p or {}
	lemmas = iut.map_forms(lemmas, function(form)
		return rsub(form, "e$", "")
	end)

	for _, spec in ipairs(arg_specs) do
		local function parse_err(msg)
			error(msg .. ": " .. spec)
		end
		local segments = iut.parse_balanced_segment_run(spec, "[", "]")
		local ending_specs = com.fetch_specs(iut, segments, ",", desc, nil, parse_err)

		-- FIXME, this should propagate the 'ss' property upwards
		local props = {}
		local function do_combine_stem_ending(stem, ending)
			return combine_stem_ending(props, stem, ending)
		end

		local function process(stem, ending)
			iut.add_forms(alternant_multiword_spec.forms, slot, stem or lemmas, ending, do_combine_stem_ending)
		end

		process_spec(ending_specs, default, nil, desc, process)
	end
end


local function show_forms(alternant_multiword_spec)
	local lemmas = alternant_multiword_spec.forms.nom_s or alternant_multiword_spec.forms.nom_p or {}
	local props = {
		lang = lang,
		lemmas = lemmas,
		slot_table = noun_slots_with_linked_and_articles,
	}
	iut.show_forms(alternant_multiword_spec.forms, props)
end


local table_spec_both = [=[
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


local table_spec_abl_voc = [=[

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


local table_spec_sg = [=[
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


local table_spec_pl = [=[
<div class="NavFrame" style="width:61%">
<div class="NavHead">{title}{annotation}</div>
<div class="NavContent">
{| border="1px solid #505050" style="border-collapse:collapse; background:#FAFAFA; text-align:center; width:100%" class="inflection-table inflection-table-de inflection-table-de-{decl_type}"
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
		forms.annotation = " (<span style=\"font-size: smaller;\">" .. annotation .. "</span>)"
	end

	local table_spec =
		alternant_multiword_spec.number == "sg" and table_spec_sg or
		alternant_multiword_spec.number == "pl" and table_spec_pl or
		table_spec_both
	if forms.abl_s ~= "—" or forms.voc_s ~= "—" then
		forms.abl_voc_clause = m_string_utilities.format(table_spec_abl_voc, forms)
	else
		forms.abl_voc_clause = ""
	end
	forms.notes_clause = forms.footnote ~= "" and
		m_string_utilities.format(notes_template, forms) or ""
	return m_string_utilities.format(table_spec, forms)
end


local function compute_headword_genders(alternant_multiword_spec)
	local genders = {}
	if alternant_multiword_spec.number == "pl" then
		return {spec = "p"}
	end
	iut.map_word_specs(alternant_multiword_spec, function(base)
		for _, genderspec in ipairs(base.genders) do
			-- Create the new spec to insert.
			local spec = {spec = genderspec.form}
			if genderspec.footnotes then
				local qualifiers = {}
				for _, footnote in ipairs(genderspec.footnotes) do
					m_table.insertIfNot(qualifiers, iut.expand_footnote_or_references(footnote, "return raw", "no parse refs"))
				end
				spec.qualifiers = qualifiers
			end
			-- See if the gender of the spec is already present; if so, combine qualifiers.
			local saw_existing = false
			for _, existing_spec in ipairs(genders) do
				if existing_spec.spec == spec.spec then
					existing_spec.qualifiers = iut.combine_footnotes(existing_spec.qualifiers, spec.qualifiers)
					saw_existing = true
					break
				end
			end
			-- If not, add gender.
			if not saw_existing then
				table.insert(genders, spec)
			end
		end
	end)
	return genders
end


-- Externally callable function to parse and decline a noun given user-specified arguments.
-- Return value is WORD_SPEC, an object where the declined forms are in `WORD_SPEC.forms`
-- for each slot. If there are no values for a slot, the slot key will be missing. The value
-- for a given slot is a list of objects {form=FORM, footnotes=FOOTNOTES}.
function export.do_generate_forms(parent_args, pos, from_headword, is_proper, def)
	local params = {
		[1] = {required = true, default = "Haus<n,es,^er>"},
		pagename = {},
	}

	if from_headword or pretend_from_headword then
		params["head"] = {list = true}
		params["f"] = {list = true}
		params["m"] = {list = true}
		params["dim"] = {list = true}
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

	local function do_parse_indicator_spec(angle_bracket_spec, lemma)
		local pagename = args.pagename or mw.title.getCurrentTitle().text
		return parse_indicator_spec(angle_bracket_spec, lemma, pagename)
	end

	local parse_props = {
		parse_indicator_spec = do_parse_indicator_spec,
		allow_default_indicator = true,
		allow_blank_lemma = true,
	}
	local alternant_multiword_spec = iut.parse_inflected_text(arg1, parse_props)
	alternant_multiword_spec.pos = pos or "nouns"
	alternant_multiword_spec.args = args
	alternant_multiword_spec.is_proper = is_proper
	detect_all_indicator_specs(alternant_multiword_spec)
	propagate_properties(alternant_multiword_spec, "number", "both", "both")
	-- The default of "M" should apply only to plural adjectives, where it doesn't matter.
	-- FIXME: This may be wrong for German.
	-- propagate_properties(alternant_multiword_spec, "gender", "M", "mixed")
	determine_noun_status(alternant_multiword_spec)
	local inflect_props = {
		skip_slot = function(slot)
			return skip_slot(alternant_multiword_spec.number, slot)
		end,
		slot_table = noun_slots_with_linked,
		inflect_word_spec = decline_noun,
	}
	iut.inflect_multiword_or_alternant_multiword_spec(alternant_multiword_spec, inflect_props)
	compute_articles(alternant_multiword_spec)
	compute_categories_and_annotation(alternant_multiword_spec)
	alternant_multiword_spec.genders = compute_headword_genders(alternant_multiword_spec)
	process_dim_m_f(alternant_multiword_spec, args.dim, nil, "dim", "diminutive")
	process_dim_m_f(alternant_multiword_spec, args.f, nil, "f", "feminine equivalent")
	process_dim_m_f(alternant_multiword_spec, args.m, nil, "m", "masculine equivalent")
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
local function concat_forms(alternant_spec, include_props)
	local ins_text = {}
	for slot, _ in pairs(noun_slots_with_linked) do
		local formtext = iut.concat_forms_in_slot(alternant_spec.forms[slot])
		if formtext then
			table.insert(ins_text, slot .. "=" .. formtext)
		end
	end
	if include_props then
		table.insert(ins_text, "g=" .. table.concat(alternant_spec.genders, ","))
	end
	return table.concat(ins_text, "|")
end


-- Template-callable function to parse and decline a noun given user-specified arguments and return
-- the forms as a string of the same form as documented in concat_forms() above.
function export.generate_forms(frame)
	local include_props = frame.args["include_props"]
	local parent_args = frame:getParent().args
	local alternant_spec = export.do_generate_forms(parent_args)
	return concat_forms(alternant_spec, include_props)
end

return export
