local export = {}


--[=[

Authorship: Ben Wing <benwing2>

]=]

--[=[

TERMINOLOGY:

-- "slot" = A particular combination of case/gender/number.
	 Example slot names for adjectives are "gen_f" (genitive feminine singular) and
	 "loc_p" (locative plural). Each slot is filled with zero or more forms.

-- "form" = The declined Ukrainian form representing the value of a given slot.

-- "lemma" = The dictionary form of a given Ukrainian term. Generally the nominative
     masculine singular, but may occasionally be another form if the nominative
	 masculine singular is missing.
]=]

local lang = require("Module:languages").getByCode("uk")
local m_links = require("Module:links")
local m_table = require("Module:table")
local m_string_utilities = require("Module:string utilities")
local iut = require("Module:inflection utilities")
local m_para = require("Module:parameters")
local com = require("Module:uk-common")

local current_title = mw.title.getCurrentTitle()
local NAMESPACE = current_title.nsText
local PAGENAME = current_title.text

local u = mw.ustring.char
local rsplit = mw.text.split
local rfind = mw.ustring.find
local rmatch = mw.ustring.match
local rgmatch = mw.ustring.gmatch
local rsubn = mw.ustring.gsub
local ulen = mw.ustring.len
local uupper = mw.ustring.upper

local AC = u(0x0301) -- acute =  ́


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


-- All slots that are used by any of the different tables. The key is the slot and the value is a list of the
-- tables that use the slot. "" = regular, "surname" = 'surname' indicator, "plonly" = special=plonly in
-- {{uk-adecl-manual}}, "dva" = special=dva in {{uk-adecl-manual}}. Note that the accelerators for some of the
-- below slots (gen_m, dat_m, ins_m, loc_m) are different for surnames vs. others, which we need to handle
-- specially when constructing the output slots.
local input_adjective_slots = {
	nom_m = {"", "surname"},
	nom_f = {"", "surname"},
	nom_n = {""},
	nom_p = {"", "surname", "plonly"},
	nom_mp = {"dva"},
	nom_fp = {"dva"},
	gen_m = {"", "surname"},
	gen_f = {"", "surname"},
	gen_p = {"", "surname", "plonly", "dva"},
	dat_m = {"", "surname"},
	dat_f = {"", "surname"},
	dat_p = {"", "surname", "plonly", "dva"},
	acc_m = {"surname"},
	acc_m_an = {""},
	acc_m_in = {""},
	acc_f = {"", "surname"},
	acc_n = {""},
	acc_p = {"surname"},
	acc_p_an = {"", "plonly", "dva"},
	acc_p_in = {"", "plonly"},
	acc_mp_in = {"dva"},
	acc_fp_in = {"dva"},
	ins_m = {"", "surname"},
	ins_f = {"", "surname"},
	ins_p = {"", "surname", "plonly", "dva"},
	loc_m = {"", "surname"},
	loc_f = {"", "surname"},
	loc_p = {"", "surname", "plonly", "dva"},
	voc_m = {"surname"},
	voc_f = {"surname"},
	voc_p = {"surname"},
	short = {""},
}


local output_adjective_slots = {
	nom_m = "nom|m|s",
	nom_m_linked = "nom|m|s", -- used in [[Module:uk-noun]]?
	nom_f = "nom|f|s",
	nom_n = "nom|n|s",
	nom_p = "nom|p",
	nom_mp = "nom|m//n|p",
	nom_fp = "nom|f|p",
	gen_m = "gen|m//n|s",
	gen_f = "gen|f|s",
	gen_p = "gen|p",
	dat_m = "dat|m//n|s",
	dat_f = "dat|f|s",
	dat_p = "dat|p",
	acc_m = "acc|m|s",
	acc_m_an = "an|acc|m|s",
	acc_m_in = "in|acc|m|s",
	acc_f = "acc|f|s",
	acc_n = "acc|n|s",
	acc_p = "acc|p",
	acc_p_an = "an|acc|p",
	acc_p_in = "in|acc|p",
	acc_mp_in = "in|acc|m//n|p",
	acc_fp_in = "in|acc|f|p",
	ins_m = "ins|m//n|s",
	ins_f = "ins|f|s",
	ins_p = "ins|p",
	loc_m = "loc|m//n|s",
	loc_f = "loc|f|s",
	loc_p = "loc|p",
	voc_m = "voc|m|s", --surname-only currently for the next three
	voc_f = "voc|f|s",
	voc_p = "voc|p",
	short = "short|form",
}


local function get_output_adjective_slots(alternant_multiword_spec)
	if alternant_multiword_spec.surname then
		output_adjective_slots.gen_m = "gen|m|s"
		output_adjective_slots.dat_m = "dat|m|s"
		output_adjective_slots.ins_m = "ins|m|s"
		output_adjective_slots.loc_m = "loc|m|s"
	end
	return output_adjective_slots
end


local function add(base, slot, stems, endings)
	iut.add_forms(base.forms, slot, stems, endings, com.combine_stem_ending)
end


local function add_normal_decl(base, stem,
	nom_m, nom_f, nom_n, nom_p, gen_m, gen_f, gen_p,
	dat_m, dat_f, dat_p, acc_f,
	ins_m, ins_f, ins_p, loc_m, loc_f, loc_p,
	footnote)
	stem = com.generate_form(stem, footnote)
	add(base, "nom_m", stem, nom_m)
	add(base, "nom_f", stem, nom_f)
	add(base, "nom_n", stem, nom_n)
	add(base, "nom_p", stem, nom_p)
	add(base, "gen_m", stem, gen_m)
	add(base, "gen_f", stem, gen_f)
	add(base, "gen_p", stem, gen_p)
	add(base, "dat_m", stem, dat_m)
	add(base, "dat_f", stem, dat_f)
	add(base, "dat_p", stem, dat_p)
	add(base, "acc_f", stem, acc_f)
	add(base, "ins_m", stem, ins_m)
	add(base, "ins_f", stem, ins_f)
	add(base, "ins_p", stem, ins_p)
	add(base, "loc_m", stem, loc_m)
	add(base, "loc_f", stem, loc_f)
	add(base, "loc_p", stem, loc_p)
end


local function add_vocative(base, stem, voc_m, voc_f, voc_p)
	add(base, "voc_m", stem, voc_m)
	add(base, "voc_f", stem, voc_f)
	add(base, "voc_p", stem, voc_p)
end


local function stress_ending(ending)
	if type(ending) == "string" then
		return com.maybe_stress_initial_syllable(ending)
	else
		for i, e in ipairs(ending) do
			ending[i] = com.maybe_stress_initial_syllable(e)
		end
		return ending
	end
end


local function maybe_stress_endings(suffix, endings)
	if com.is_stressed(suffix) then
		for i, e in ipairs(endings) do
			endings[i] = stress_ending(e)
		end
	end
end


local decls = {}

decls["normal"] = function(base)
	local normal_endings, old_endings
	local stem, suffix

	local function add_endings()
		maybe_stress_endings(suffix, normal_endings)
		add_normal_decl(base, stem, unpack(normal_endings))
		if base.old then
			maybe_stress_endings(suffix, old_endings)
			local nom_f, nom_n, nom_p, acc_f = unpack(old_endings)
			old_endings = {
				{}, nom_f, nom_n, nom_p, --nom
				{}, {}, {}, --gen
				{}, {}, {}, --dat
				acc_f, --acc
				{}, {}, {}, --ins
				{}, {}, {}, --loc
				"[dated or dialectal]",
			}
			add_normal_decl(base, stem, unpack(old_endings))
		end
	end

	-- semi-soft in -ций
	stem, suffix = rmatch(base.lemma, "^(.*ц)(и́?й)$")
	if stem then
		normal_endings = {
			"ий", "я", "е", "і", --nom
			"ього", "ьої", "их", --gen
			"ьому", "ій", "им", --dat
			"ю", --acc
			"им", "ьою", "ими", --ins
			{"ьому", "ім"}, "ій", "их", --loc
		}
		old_endings = {
			"яя", "еє", "ії", --nom
			"юю", --acc
		}
		add_endings()
		return
	end

	-- hard in -ий
	stem, suffix = rmatch(base.lemma, "^(.*)(и́?й)$")
	if stem then
		normal_endings = {
			"ий", "а", "е", "і", --nom
			"ого", "ої", "их", --gen
			"ому", "ій", "им", --dat
			"у", --acc
			"им", "ою", "ими", --ins
			{"ому", "ім"}, "ій", "их", --loc
		}
		old_endings = {
			"ая", "еє", "ії", --nom
			"ую", --acc
		}
		add_endings()
		return
	end

	-- soft in -ій
	stem, suffix = rmatch(base.lemma, "^(.*)(і́?й)$")
	if stem then
		normal_endings = {
			"ій", "я", "є", "і", --nom
			"ього", "ьої", "іх", --gen
			"ьому", "ій", "ім", --dat
			"ю", --acc
			"ім", "ьою", "іми", --ins
			{"ьому", "ім"}, "ій", "іх", --loc
		}
		old_endings = {
			"яя", "єє", "ії", --nom
			"юю", --acc
		}
		add_endings()
		return
	end

	-- soft-after-vowel in -їй
	stem, suffix = rmatch(base.lemma, "^(.*)(ї́?й)$")
	if stem then
		normal_endings = {
			"їй", "я", "є", "ї", --nom
			"його", "йої", "їх", --gen
			"йому", "їй", "їм", --dat
			"ю", --acc
			"їм", "йою", "їми", --ins
			{"йому", "їм"}, "їй", "їх", --loc
		}
		old_endings = {
			"яя", "єє", "її", --nom
			"юю", --acc
		}
		add_endings()
		return
	end

	error("Unrecognized adjective lemma, should end in '-ий', '-ій' or '-їй': '" .. base.lemma .. "'")
end

decls["poss"] = function(base)
	local ending_prefix
	local stem, suffix

	while true do
		stem, suffix = rmatch(base.lemma, "^(.*)([ії]́?в)$")
		if stem then
			ending_prefix = com.apply_vowel_alternation(base.ialt, suffix)
			break
		end
		stem, suffix = rmatch(base.lemma, "^(.*)([иї]́?н)$")
		if stem then
			ending_prefix = suffix
			break
		end
		error("Unrecognized possessive adjective lemma, should end in '-ів', '-їв', '-ин' or '-їн': '" .. base.lemma .. "'")
	end

	local endings = {
		"а", "е", "і", --nom
		"ого", "ої", "их", --gen
		"ому", "ій", "им", --dat
		"у", --acc
		"им", "ою", "ими", --ins
		{"ому", "ім"}, "ій", "их", --loc
	}
	if com.is_stressed(suffix) then
		ending_prefix = com.maybe_stress_initial_syllable(ending_prefix)
	end
	-- Do the nominative singular separately from the rest, which may have
	-- a different stem ending (e.g. -ов vs. -ів).
	add_normal_decl(base, stem, suffix)
	add_normal_decl(base, stem .. ending_prefix, nil, unpack(endings))
	-- FIXME: Are there 'old' endings here too?
end


decls["surname"] = function(base)
	local ending_prefix
	local stem, suffix

	while true do
		stem, suffix = rmatch(base.lemma, "^(.*)([ії]́?в)$")
		if stem then
			ending_prefix = com.apply_vowel_alternation(base.ialt, suffix)
			break
		end
		stem, suffix = rmatch(base.lemma, "^(.*)([оє]́?в)$")
		if stem then
			ending_prefix = suffix
			break
		end
		stem, suffix = rmatch(base.lemma, "^(.*)([иії]́?н)$")
		if stem then
			ending_prefix = suffix
			break
		end
		error("Unrecognized possessive surname lemma, should end in '-ів', '-їв', '-ов', '-єв', '-ин', '-ін' or '-їн': '" .. base.lemma .. "'")
	end

	local endings = {
		"а", nil, "и", --nom
		"а", "ої", "их", --gen
		"у", "ій", "им", --dat
		"у", --acc
		"им", "ою", "ими", --ins
		{"у", "і"}, "ій", "их", --loc
	}
	-- Do the nominative singular separately from the rest, which may have
	-- a different stem ending (e.g. -ов vs. -ів).
	add_normal_decl(base, stem, suffix)
	add_normal_decl(base, stem .. ending_prefix, nil, unpack(endings))
	add_vocative(base, stem, suffix)
	add_vocative(base, stem .. ending_prefix, "е", "а", "и")
	-- FIXME: Are there 'old' endings here too?
end


local function parse_indicator_spec(angle_bracket_spec)
	local inside = rmatch(angle_bracket_spec, "^<(.*)>$")
	assert(inside)
	local base = {forms = {}}
	if inside ~= "" then
		local parts = rsplit(inside, ".", true)
		for _, part in ipairs(parts) do
			if part == "old" then
				if base.old then
					error("Can't specify 'old' twice: '" .. inside .. "'")
				end
				base.old = true
			elseif part == "surname" then
				if base.surname then
					error("Can't specify 'surname' twice: '" .. inside .. "'")
				end
				base.surname = true
			elseif part == "io" or part == "ijo" or part == "ie" then
				if base.ialt then
					error("Can't specify і-alternation indicator twice: '" .. inside .. "'")
				end
				base.ialt = part
			else
				error("Unrecognized indicator '" .. part .. "': '" .. inside .. "'")
			end
		end
	end
	return base
end


-- Check that multisyllabic lemmas have stress, and add stress to monosyllabic
-- lemmas if needed.
local function normalize_all_lemmas(alternant_multiword_spec)
	iut.map_word_specs(alternant_multiword_spec, function(base)
		base.orig_lemma = base.lemma
		base.orig_lemma_no_links = com.add_monosyllabic_stress(m_links.remove_links(base.lemma))
		base.lemma = base.orig_lemma_no_links
		if not rfind(base.lemma, AC) then
			error("Multisyllabic lemma '" .. base.orig_lemma .. "' needs an accent")
		end
	end)
end


local function detect_indicator_spec(base)
	if rfind(base.lemma, "й$") then
		base.decl = "normal"
	elseif rfind(base.lemma, "[вн]$") then
		if base.surname then
			base.decl = "surname"
		else
			base.decl = "poss"
		end
	else
		error("Unrecognized adjective lemma: '" .. base.lemma .. "'")
	end
	if base.ialt and base.decl ~= "poss" and base.decl ~= "surname" then
		error("Vowel alternation spec '" .. base.ialt .. "' can only be specified with possessive/surname adjectives")
	end
end


local function detect_all_indicator_specs(alternant_multiword_spec)
	iut.map_word_specs(alternant_multiword_spec, function(base)
		detect_indicator_spec(base)
		if alternant_multiword_spec.surname == nil then
			alternant_multiword_spec.surname = base.surname or false
		elseif alternant_multiword_spec.surname ~= (base.surname or false) then
			error("If 'surname' is specified in one alternant, it must be specified in all of them")
		end
	end)
end


local function decline_adjective(base)
	if not decls[base.decl] then
		error("Internal error: Unrecognized declension type '" .. base.decl .. "'")
	end
	decls[base.decl](base)
	-- handle_derived_slots_and_overrides(base)
end


local function get_variants(form)
	return
		form:find(com.VAR1) and "var1" or
		form:find(com.VAR2) and "var2" or
		form:find(com.VAR3) and "var3" or
		nil
end


local function fetch_footnotes(separated_group)
	local footnotes
	for j = 2, #separated_group - 1, 2 do
		if separated_group[j + 1] ~= "" then
			error("Extraneous text after bracketed footnotes: '" .. table.concat(separated_group) .. "'")
		end
		if not footnotes then
			footnotes = {}
		end
		table.insert(footnotes, separated_group[j])
	end
	return footnotes
end


-- Process override for the arguments in `args`, storing the results into `forms`. If `do_acc`, only do accusative
-- slots; otherwise, don't do accusative slots.
local function process_overrides(forms, args, do_acc)
	for slot, _ in pairs(input_adjective_slots) do
		if args[slot] and not not do_acc == not not slot:find("^acc") then
			forms[slot] = nil
			if args[slot] ~= "-" and args[slot] ~= "—" then
				local segments = iut.parse_balanced_segment_run(args[slot], "[", "]")
				local comma_separated_groups = iut.split_alternating_runs(segments, "%s*,%s*")
				for _, comma_separated_group in ipairs(comma_separated_groups) do
					local formobj = {
						form = comma_separated_group[1],
						footnotes = fetch_footnotes(comma_separated_group),
					}
					iut.insert_form(forms, slot, formobj)
				end
			end
		end
	end
end


local function check_allowed_overrides(alternant_multiword_spec, args)
	local special = alternant_multiword_spec.special or alternant_multiword_spec.surname and "surname" or ""
	for slot, types in pairs(input_adjective_slots) do
		if args[slot] then
			local allowed = false
			for _, typ in ipairs(types) do
				if typ == special then
					allowed = true
					break
				end
			end
			if not allowed then
				error(("Override %s= not allowed for %s"):format(slot, special == "" and "regular declension" or
					"special=" .. special))
			end
		end
	end
end


local function set_accusative(alternant_multiword_spec)
	local forms = alternant_multiword_spec.forms
	if alternant_multiword_spec.surname then
		iut.insert_forms(forms, "acc_m", forms["gen_m"])
		iut.insert_forms(forms, "acc_p", forms["gen_p"])
	elseif alternant_multiword_spec.special == "dva" then
		iut.insert_forms(forms, "acc_p_an", forms["gen_p"])
		iut.insert_forms(forms, "acc_mp_in", forms["nom_mp"])
		iut.insert_forms(forms, "acc_fp_in", forms["nom_fp"])
	else
		iut.insert_forms(forms, "acc_n", forms["nom_n"])
		iut.insert_forms(forms, "acc_m_an", forms["gen_m"])
		iut.insert_forms(forms, "acc_m_in", forms["nom_m"])
		iut.insert_forms(forms, "acc_p_an", forms["gen_p"])
		iut.insert_forms(forms, "acc_p_in", forms["nom_p"])
	end
end


local function add_categories(alternant_multiword_spec)
	local cats = {}
	local function insert(cattype)
		table.insert(cats, "Ukrainian " .. cattype .. " adjectives")
	end
	if not alternant_multiword_spec.manual then
		iut.map_word_specs(alternant_multiword_spec, function(base)
			if base.decl == "poss" then
				insert("possessive")
			elseif rfind(base.lemma, "ци́?й$") then
				insert("ц-stem")
			elseif rfind(base.lemma, "ий$") then
				insert("hard-stem stem-stressed")
			elseif rfind(base.lemma, "и́й$") then
				insert("hard-stem ending-stressed")
			elseif rfind(base.lemma, "і́?й$") then
				insert("soft-stem")
			elseif rfind(base.lemma, "ї́?й$") then
				insert("vowel-stem")
			end
		end)
	end
	alternant_multiword_spec.categories = cats
end


local function show_forms(alternant_multiword_spec)
	local lemmas = {}
	local lemmaform = alternant_multiword_spec.forms.nom_m or alternant_multiword_spec.forms.nom_p or
		alternant_multiword_spec.forms.nom_mp
	if lemmaform then
		for _, form in ipairs(lemmaform) do
			table.insert(lemmas, com.remove_monosyllabic_stress(form.form))
		end
	end
	local props = {
		lemmas = lemmas,
		slot_table = get_output_adjective_slots(alternant_multiword_spec),
		lang = lang,
		canonicalize = function(form)
			return com.remove_variant_codes(com.remove_monosyllabic_stress(form))
		end,
		include_translit = true,
	}
	iut.show_forms(alternant_multiword_spec.forms, props)
end


local function make_table(alternant_multiword_spec)
	local forms = alternant_multiword_spec.forms

	local function template_prelude(min_width)
		return rsub([===[
<div>
<div class="NavFrame" style="display: inline-block; min-width: MINWIDTHem">
<div class="NavHead" style="background:#eff7ff">{title}{annotation}</div>
<div class="NavContent">
{\op}| border="1px solid #000000" style="border-collapse:collapse;background:#F9F9F9;text-align:center; min-width:MINWIDTHem" class="inflection-table"
|-
]===], "MINWIDTH", min_width)
	end

	local function template_postlude()
		return [=[
|{\cl}{notes_clause}</div></div></div>]=]
	end

	local table_spec = template_prelude("70") .. [=[
! style="width:20%;background:#d9ebff" colspan="2" | 
! style="background:#d9ebff" | masculine
! style="background:#d9ebff" | neuter
! style="background:#d9ebff" | feminine
! style="background:#d9ebff" | plural
|-
! style="background:#eff7ff" colspan="2" | nominative
| {nom_m}
| {nom_n}
| {nom_f}
| {nom_p}
|-
! style="background:#eff7ff" colspan="2" | genitive
| colspan="2" | {gen_m}
| {gen_f}
| {gen_p}
|-
! style="background:#eff7ff" colspan="2" | dative
| colspan="2" | {dat_m}
| {dat_f}
| {dat_p}
|-
! style="background:#eff7ff" rowspan="2" | accusative
! style="background:#eff7ff" | animate
| {acc_m_an}
| rowspan="2" | {acc_n}
| rowspan="2" | {acc_f}
| {acc_p_an}
|-
! style="background:#eff7ff" | inanimate
| {acc_m_in}
| {acc_p_in}
|-
! style="background:#eff7ff" colspan="2" | instrumental
| colspan="2" | {ins_m}
| {ins_f}
| {ins_p}
|-
! style="background:#eff7ff" colspan="2" | locative
| colspan="2" | {loc_m}
| {loc_f}
| {loc_p}{short_clause}
]=] .. template_postlude()

	local table_spec_surname = template_prelude("55") .. [=[
! style="background:#d9ebff" | 
! style="background:#d9ebff" | masculine
! style="background:#d9ebff" | feminine
! style="background:#d9ebff" | plural
|-
! style="background:#eff7ff" | nominative
| {nom_m}
| {nom_f}
| {nom_p}
|-
! style="background:#eff7ff" | genitive
| {gen_m}
| {gen_f}
| {gen_p}
|-
! style="background:#eff7ff" | dative
| {dat_m}
| {dat_f}
| {dat_p}
|-
! style="background:#eff7ff" | accusative
| {acc_m}
| {acc_f}
| {acc_p}
|-
! style="background:#eff7ff" | instrumental
| {ins_m}
| {ins_f}
| {ins_p}
|-
! style="background:#eff7ff" | locative
| {loc_m}
| {loc_f}
| {loc_p}{vocative_clause}
]=] .. template_postlude()

	local table_spec_plonly = template_prelude("25") .. [=[
! style="width:50%;background:#d9ebff" colspan="2" | 
! style="background:#d9ebff" | plural
|-
! style="background:#eff7ff" colspan="2" | nominative
| {nom_p}
|-
! style="background:#eff7ff" colspan="2" | genitive
| {gen_p}
|-
! style="background:#eff7ff" colspan="2" | dative
| {dat_p}
|-
! style="background:#eff7ff" rowspan="2" | accusative
! style="background:#eff7ff" | animate
| {acc_p_an}
|-
! style="background:#eff7ff" | inanimate
| {acc_p_in}
|-
! style="background:#eff7ff" colspan="2" | instrumental
| {ins_p}
|-
! style="background:#eff7ff" colspan="2" | locative
| {loc_p}{vocative_clause}
]=] .. template_postlude()

	local table_spec_dva = template_prelude("40") .. [=[
! style="width:40%;background:#d9ebff" colspan="2" | 
! style="background:#d9ebff" colspan="2" | plural
|-
! style="width:40%;background:#d9ebff" colspan="2" | 
! style="background:#d9ebff" | masculine/neuter
! style="background:#d9ebff" | feminine
|-
! style="background:#eff7ff" colspan="2" | nominative
| {nom_mp}
| {nom_fp}
|-
! style="background:#eff7ff" colspan="2" | genitive
| colspan="2" | {gen_p} 
|-
! style="background:#eff7ff" colspan="2" | dative
| colspan="2" | {dat_p} 
|-
! style="background:#eff7ff" rowspan="2" | accusative
! style="background:#eff7ff" | animate
| colspan="2" | {acc_p_an} 
|-
! style="background:#eff7ff" | inanimate
| {acc_mp_in}
| {acc_fp_in}
|-
! style="background:#eff7ff" colspan="2" | instrumental
| colspan="2" | {ins_p} 
|-
! style="background:#eff7ff" colspan="2" | locative
| colspan="2" | {loc_p} 
]=] .. template_postlude()

	local vocative_template = [=[

|-
! style="background:#eff7ff" | vocative
| {voc_m}
| {voc_f}
| {voc_p}]=]

	local vocative_plonly_template = [=[

|-
! style="background:#eff7ff" | vocative
| {voc_p}]=]

	local short_form_template = [=[

|-
! style="height:0.2em;background:#d9ebff" colspan="6" |
|-
! style="background:#eff7ff" colspan="2" | short form
| colspan="1" | {short}]=]

	local notes_template = [===[
<div style="width:100%;text-align:left;background:#d9ebff">
<div style="display:inline-block;text-align:left;padding-left:1em;padding-right:1em">
{footnote}
</div></div>
]===]

	if alternant_multiword_spec.title then
		forms.title = alternant_multiword_spec.title
	else
		forms.title = 'Declension of <i lang="uk" class="Cyrl">' .. forms.lemma .. '</i>'
	end

	if alternant_multiword_spec.manual then
		forms.annotation = ""
	else
		local ann_parts = {}
		local decls = {}
		iut.map_word_specs(alternant_multiword_spec, function(base)
			if base.decl == "surname" then
				m_table.insertIfNot(decls, "surname")
			elseif base.decl == "poss" then
				m_table.insertIfNot(decls, "possessive")
			elseif rfind(base.lemma, "и́?й$") then
				m_table.insertIfNot(decls, "hard")
			else
				m_table.insertIfNot(decls, "soft")
			end
		end)
		table.insert(ann_parts, table.concat(decls, " // "))
		forms.annotation = " (" .. table.concat(ann_parts, ", ") .. ")"
	end

	forms.notes_clause = forms.footnote ~= "" and
		m_string_utilities.format(notes_template, forms) or ""
	forms.vocative_clause =
		alternant_multiword_spec.special == "dva" and "" or
		alternant_multiword_spec.special ~= "plonly" and
		forms.voc_m and forms.voc_m ~= "—" and
		m_string_utilities.format(vocative_template, forms) or
		alternant_multiword_spec.special == "plonly" and
		forms.voc_p and forms.voc_p ~= "—" and
		m_string_utilities.format(vocative_plonly_template, forms) or
		""
	forms.short_clause = forms.short and forms.short ~= "—" and
		m_string_utilities.format(short_form_template, forms) or ""
	return m_string_utilities.format(
		alternant_multiword_spec.surname and table_spec_surname or
		alternant_multiword_spec.special == "plonly" and table_spec_plonly or
		alternant_multiword_spec.special == "dva" and table_spec_dva or
		table_spec, forms
	)
end

-- Externally callable function to parse and decline an adjective given
-- user-specified arguments. Return value is WORD_SPEC, an object where the
-- declined forms are in `WORD_SPEC.forms` for each slot. If there are no values
-- for a slot, the slot key will be missing. The value for a given slot is a
-- list of objects {form=FORM, footnotes=FOOTNOTES}.
function export.do_generate_forms(parent_args, pos, from_headword, def)
	local params = {
		[1] = {required = true, default = "си́ній"},
		json = {type = "boolean"}, -- for use with bots
		title = {},
	}
	for slot, _ in pairs(input_adjective_slots) do
		params[slot] = {}
	end

	local args = m_para.process(parent_args, params)
	local parse_props = {
		parse_indicator_spec = parse_indicator_spec,
		allow_default_indicator = true,
	}
	local alternant_multiword_spec = iut.parse_inflected_text(args[1], parse_props)
	alternant_multiword_spec.title = args.title
	alternant_multiword_spec.forms = {}
	normalize_all_lemmas(alternant_multiword_spec)
	detect_all_indicator_specs(alternant_multiword_spec)
	check_allowed_overrides(alternant_multiword_spec, args)
	local inflect_props = {
		slot_table = get_output_adjective_slots(alternant_multiword_spec),
		get_variants = get_variants,
		inflect_word_spec = decline_adjective,
	}
	iut.inflect_multiword_or_alternant_multiword_spec(alternant_multiword_spec, inflect_props)
	-- Do non-accusative overrides so they get copied to the accusative forms appropriately.
	process_overrides(alternant_multiword_spec.forms, args)
	set_accusative(alternant_multiword_spec)
	-- Do accusative overrides after copying the accusative forms.
	process_overrides(alternant_multiword_spec.forms, args, "do acc")
	add_categories(alternant_multiword_spec)
	if args.json and not from_headword then
		return require("Module:JSON").toJSON(alternant_multiword_spec)
	end
	return alternant_multiword_spec
end


-- Externally callable function to parse and decline an adjective where all
-- forms are given manually. Return value is WORD_SPEC, an object where the
-- declined forms are in `WORD_SPEC.forms` for each slot. If there are no values
-- for a slot, the slot key will be missing. The value for a given slot is a
-- list of objects {form=FORM, footnotes=FOOTNOTES}.
function export.do_generate_forms_manual(parent_args, pos, from_headword, def)
	local params = {
		special = {},
		json = {type = "boolean"}, -- for use with bots
		title = {},
	}
	for slot, _ in pairs(input_adjective_slots) do
		params[slot] = {}
	end

	local args = m_para.process(parent_args, params)
	local alternant_multiword_spec = {
		special = args.special,
		title = args.title,
		forms = {},
		manual = true,
	}
	check_allowed_overrides(alternant_multiword_spec, args)
	-- Do non-accusative overrides so they get copied to the accusative forms appropriately.
	process_overrides(alternant_multiword_spec.forms, args)
	set_accusative(alternant_multiword_spec)
	-- Do accusative overrides after copying the accusative forms.
	process_overrides(alternant_multiword_spec.forms, args, "do acc")
	add_categories(alternant_multiword_spec)
	if args.json and not from_headword then
		return require("Module:JSON").toJSON(alternant_multiword_spec)
	end
	return alternant_multiword_spec
end


-- Entry point for {{uk-adecl}}. Template-callable function to parse and decline 
-- an adjective given user-specified arguments and generate a displayable table
-- of the declined forms.
function export.show(frame)
	local parent_args = frame:getParent().args
	local alternant_multiword_spec = export.do_generate_forms(parent_args)
	show_forms(alternant_multiword_spec)
	return make_table(alternant_multiword_spec) .. require("Module:utilities").format_categories(alternant_multiword_spec.categories, lang)
end


-- Entry point for {{uk-adecl-manual}}. Template-callable function to parse and
-- decline an adjective given manually-specified inflections and generate a
-- displayable table of the declined forms.
function export.show_manual(frame)
	local parent_args = frame:getParent().args
	local alternant_multiword_spec = export.do_generate_forms_manual(parent_args)
	show_forms(alternant_multiword_spec)
	return make_table(alternant_multiword_spec) .. require("Module:utilities").format_categories(alternant_multiword_spec.categories, lang)
end


return export
