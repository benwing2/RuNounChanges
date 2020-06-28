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


local function tag_text(text)
	return m_script_utilities.tag_text(text, lang)
end


local output_adjective_slots = {
	-- used with all variants
	nom_m = "nom|m|s",
	nom_f = "nom|f|s",
	nom_n = "nom|n|s",
	-- not used with special
	nom_p = "nom|p",
	-- the following two only used with special
	nom_mp = "nom|m//n|p",
	nom_fp = "nom|f|p",
	-- the following 10 used with all variants
	gen_m = "gen|m//n|s",
	gen_f = "gen|f|s",
	gen_p = "gen|p",
	dat_m = "dat|m//n|s",
	dat_f = "dat|f|s",
	dat_p = "dat|p",
	acc_m_an = "an|acc|m|s",
	acc_m_in = "in|acc|m|s",
	acc_f = "acc|f|s",
	acc_n = "acc|n|s",
	-- the following two not used with special == "dva"
	acc_p_an = "an|acc|p",
	acc_p_in = "in|acc|p",
	-- the following four only used with special == "dva"
	acc_mp_an = "an|acc|m//n|p",
	acc_mp_in = "in|acc|m//n|p",
	acc_fp_an = "an|acc|f|p",
	acc_fp_in = "in|acc|f|p",
	-- the following two gendered plurals are only used with special == "cdva"
	acc_mp = "acc|m//n|p",
	acc_fp = "acc|f|p",
	-- the next six are used with all variants
	ins_m = "ins|m//n|s",
	ins_f = "ins|f|s",
	ins_p = "ins|p",
	loc_m = "loc|m//n|s",
	loc_f = "loc|f|s",
	loc_p = "loc|p",
	short = "short|form",
}


local output_adjective_slots_surname = {
	nom_m = "nom|m|s",
	nom_f = "nom|f|s",
	nom_p = "nom|p",
	gen_m = "gen|m|s",
	gen_f = "gen|f|s",
	gen_p = "gen|p",
	dat_m = "dat|m|s",
	dat_f = "dat|f|s",
	dat_p = "dat|p",
	acc_m = "acc|m|s",
	acc_f = "acc|f|s",
	acc_p = "acc|p",
	ins_m = "ins|m|s",
	ins_f = "ins|f|s",
	ins_p = "ins|p",
	loc_m = "loc|m|s",
	loc_f = "loc|f|s",
	loc_p = "loc|p",
	voc_m = "voc|m|s",
	voc_f = "voc|f|s",
	voc_p = "voc|p",
}


local input_adjective_slots = {}
for slot, _ in pairs(output_adjective_slots) do
	if not rfind(slot, "_[ai]n$") then
		table.insert(input_adjective_slots, slot)
	end
end


local function get_output_adjective_slots(base)
	if base.surname then
		return output_adjective_slots_surname
	else
		return output_adjective_slots
	end
end


local function add(base, slot, stems, endings)
	if get_output_adjective_slots(base)[slot] then
		iut.add_forms(base.forms, slot, stems, endings, com.combine_stem_ending)
	end
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

decls["normal"] = function(base, lemma)
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
	stem, suffix = rmatch(lemma, "^(.*ц)(и́?й)$")
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
	stem, suffix = rmatch(lemma, "^(.*)(и́?й)$")
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
	stem, suffix = rmatch(lemma, "^(.*)(і́?й)$")
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
	stem, suffix = rmatch(lemma, "^(.*)(ї́?й)$")
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

	error("Unrecognized adjective lemma, should end in '-ий', '-ій' or '-їй': '" .. lemma .. "'")
end

decls["poss"] = function(base, lemma)
	local ending_prefix
	local stem, suffix

	while true do
		stem, suffix = rmatch(lemma, "^(.*)(і́?в)$")
		if stem then
			ending_prefix = "ов"
			break
		end
		stem, suffix = rmatch(lemma, "^(.*)(ї́?в)$")
		if stem then
			ending_prefix = "єв"
			break
		end
		stem, suffix = rmatch(lemma, "^(.*)([иї]́?н)$")
		if stem then
			ending_prefix = suffix
			break
		end
		error("Unrecognized possessive adjective lemma, should end in '-ів', '-їв', '-ин' or '-їн': '" .. lemma .. "'")
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


decls["surname"] = function(base, lemma)
	local ending_prefix
	local stem, suffix

	while true do
		stem, suffix = rmatch(lemma, "^(.*)([ії]́?в)$")
		if stem then
			ending_prefix = com.apply_vowel_alternation(base.ialt, suffix)
			break
		end
		stem, suffix = rmatch(lemma, "^(.*)(о́?в)$")
		if stem then
			ending_prefix = suffix
			break
		end
		stem, suffix = rmatch(lemma, "^(.*)([иії]́?н)$")
		if stem then
			ending_prefix = suffix
			break
		end
		error("Unrecognized possessive surname lemma, should end in '-ів', '-їв', '-ов', '-ин', '-ін' or '-їн': '" .. lemma .. "'")
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
	local base = {}
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
			elseif part == "io" or part == "ie" then
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
local function normalize_lemma(base)
	base.orig_lemma = base.lemma
	base.lemma = com.add_monosyllabic_stress(base.lemma)
	if not rfind(base.lemma, AC) then
		error("Multisyllabic lemma '" .. base.orig_lemma .. "' needs an accent")
	end
end


local function detect_indicator_spec(base)
	if base.ialt and not base.surname then
		error("Vowel alternation spec '" .. base.ialt .. "' can only be specified with 'surname'")
	end
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
end


local function detect_all_indicator_specs(alternant_spec)
	for _, base in ipairs(alternant_spec.alternants) do
		detect_indicator_spec(base)
		if alternant_spec.surname == nil then
			alternant_spec.surname = base.surname or false
		elseif alternant_spec.surname ~= (base.surname or false) then
			error("If 'surname' is specified in one alternant, it must be specified in all of them")
		end
	end
end


local function parse_word_spec(segments)
	local indicator_spec
	if #segments == 1 then
		indicator_spec = "<>"
	elseif #segments ~= 3 or segments[3] ~= "" then
		error("Adjective spec must be of the form 'LEMMA' or 'LEMMA<SPECS>': '" .. table.concat(segments) .. "'")
	else
		indicator_spec = segments[2]
	end
	local lemma = segments[1]
	local base = parse_indicator_spec(indicator_spec)
	base.lemma = lemma
	return base
end


-- Parse an alternant, e.g. "((родо́вий,родови́й))". The return value is a table of the form
-- {
--   alternants = {WORD_SPEC, WORD_SPEC, ...}
-- }
--
-- where WORD_SPEC describes a given alternant and is as returned by parse_word_spec().
local function parse_alternant(alternant)
	local parsed_alternants = {}
	local alternant_text = rmatch(alternant, "^%(%((.*)%)%)$")
	local segments = iut.parse_balanced_segment_run(alternant_text, "<", ">")
	local comma_separated_groups = iut.split_alternating_runs(segments, ",")
	local alternant_spec = {alternants = {}}
	for _, comma_separated_group in ipairs(comma_separated_groups) do
		table.insert(alternant_spec.alternants, parse_word_spec(comma_separated_group))
	end
	return alternant_spec
end


local function parse_alternant_or_word_spec(text)
	if rfind(text, "^%(%((.*)%)%)$") then
		return parse_alternant(text)
	else
		local segments = iut.parse_balanced_segment_run(text, "<", ">")
		return {alternants = {parse_word_spec(segments)}}
	end
end


local function process_overrides(forms, args)
	for _, slot in ipairs(input_adjective_slots) do
		if args[slot] then
			forms[slot] = nil
			if args[slot] ~= "-" and args[slot] ~= "—" then
				for _, form in ipairs(rsplit(args[slot], "%s*,%s*")) do
					iut.insert_form(forms, slot, {form=form})
				end
			end
		end
	end
end


local function set_accusative(alternant_spec)
	local forms = alternant_spec.forms
	if alternant_spec.surname then
		iut.insert_forms(forms, "acc_m", forms["gen_m"])
		iut.insert_forms(forms, "acc_p", forms["gen_p"])
	else
		iut.insert_forms(forms, "acc_n", forms["nom_n"])
		iut.insert_forms(forms, "acc_m_an", forms["gen_m"])
		iut.insert_forms(forms, "acc_m_in", forms["nom_m"])
		iut.insert_forms(forms, "acc_p_an", forms["gen_p"])
		iut.insert_forms(forms, "acc_p_in", forms["nom_p"])
	end
end


local function add_categories(alternant_spec)
	local cats = {}
	local function insert(cattype)
		table.insert(cats, "Ukrainian " .. cattype .. " adjectives")
	end
	if alternant_spec.alternants then -- not when manual
		for _, base in ipairs(alternant_spec.alternants) do
			if base.conj == "poss" then
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
		end
	end
	alternant_spec.categories = cats
end


local function show_forms(alternant_spec)
	local lemmas = {}
	if alternant_spec.forms.nom_m then
		for _, nom_m in ipairs(alternant_spec.forms.nom_m) do
			table.insert(lemmas, com.remove_monosyllabic_stress(nom_m.form))
		end
	end
	com.show_forms(alternant_spec.forms, lemmas, alternant_spec.footnotes,
		get_output_adjective_slots(alternant_spec)
	)
end


local function make_table(alternant_spec)
	local forms = alternant_spec.forms

	local table_spec = [=[
<div>
<div class="NavFrame" style="display: inline-block; min-width: 70em">
<div class="NavHead" style="background:#eff7ff">{title}{annotation}</div>
<div class="NavContent">
{\op}| border="1px solid #000000" style="border-collapse:collapse;background:#F9F9F9;text-align:center; min-width:70em" class="inflection-table"
|-
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
|{\cl}{notes_clause}</div></div></div>]=]

	local table_spec_surname = [=[
<div>
<div class="NavFrame" style="display: inline-block; min-width: 55em">
<div class="NavHead" style="background:#eff7ff">{title}{annotation}</div>
<div class="NavContent">
{\op}| border="1px solid #000000" style="border-collapse:collapse;background:#F9F9F9;text-align:center; min-width:55em" class="inflection-table"
|-
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
|{\cl}{notes_clause}</div></div></div>]=]

	local vocative_template = [=[

|-
! style="background:#eff7ff" | vocative
| {voc_m}
| {voc_f}
| {voc_p}]=]

	local short_form_template = [=[

|-
! style="height:0.2em;background:#d9ebff" colspan="6" |
|-
! style="background:#eff7ff" colspan="2" | short form
| colspan="4" | {short}]=]

	local notes_template = [===[
<div style="width:100%;text-align:left;background:#d9ebff">
<div style="display:inline-block;text-align:left;padding-left:1em;padding-right:1em">
{footnote}
</div></div>
]===]

	if alternant_spec.title then
		forms.title = alternant_spec.title
	else
		forms.title = 'Declension of <i lang="uk" class="Cyrl">' .. forms.lemma .. '</i>'
	end

	if alternant_spec.manual then
		forms.annotation = ""
	else
		local ann_parts = {}
		local decls = {}
		for _, base in ipairs(alternant_spec.alternants) do
			if base.decl == "surname" then
				m_table.insertIfNot(decls, "surname")
			elseif base.decl == "poss" then
				m_table.insertIfNot(decls, "possessive")
			elseif rfind(base.lemma, "и́?й$") then
				m_table.insertIfNot(decls, "hard")
			else
				m_table.insertIfNot(decls, "soft")
			end
		end
		table.insert(ann_parts, table.concat(decls, " // "))
		forms.annotation = " (" .. table.concat(ann_parts, ", ") .. ")"
	end

	forms.notes_clause = forms.footnote ~= "" and
		m_string_utilities.format(notes_template, forms) or ""
	forms.vocative_clause = forms.voc_m and forms.voc_m ~= "—" and
		m_string_utilities.format(vocative_template, forms) or ""
	forms.short_clause = forms.short and forms.short ~= "—" and
		m_string_utilities.format(short_form_template, forms) or ""
	return m_string_utilities.format(
		alternant_spec.surname and table_spec_surname or table_spec, forms
	)
end


local stem_expl = {
	["ц-stem"] = "-ц",
	["vowel-stem"] = "a vowel, or -й or -ь",
	["soft-stem"] = "a soft consonant",
	["hard-stem"] = "a hard consonant",
	["possessive"] = "-ов, -єв, -ин or -їн",
}


export.adj_decl_endings = {
	["hard stem-stressed"] = {"-ий", "-а", "-е", "-і"},
	["hard ending-stressed"] = {"-и́й", "-а́", "-е́", "-і́"},
	["soft"] = {"-ій", "-я", "-є", "-і"},
	["c-stem"] = {"-ий", "-я", "-е", "-і"},
	["j-stem"] = {"-їй", "-я", "-є", "-ї"},
	["possessive"] = {"-", "-а", "-е", "-і"},
	["surname"] = {"-", "-а", "(nil)", "-и"},
}


-- Implementation of template 'ruadjcatboiler'.
function export.catboiler(frame)
	local SUBPAGENAME = mw.title.getCurrentTitle().subpageText
	local params = {
		[1] = {required = true},
		[2] = {required = true},
		[3] = {},
		[4] = {},
		[5] = {},
	}

	local parent_args = frame:getParent().args
	local args = m_para.process(parent_args, params)

	local cats = {}

	local function insert(cat)
	    table.insert(cats, "Ukrainian " .. rsub(cat, "~", "adjectives"))
	end

	local maintext, misctext
	if args[1] == "adj" then
		local stem, stress = rmatch(SUBPAGENAME, "^Ukrainian ([^ ]*) ([^ *]*)-stressed adjectives")
		if not stem then
			stem = rmatch(SUBPAGENAME, "^Ukrainian ([^ ]*) adjectives")
			stress = ""
		end
		if not stem then
			error("Invalid category name, should be e.g. \"Ukrainian hard-stem ending-stressed adjectives\"")
		end
		local stresstext = stress == "stem" and
			"The adjectives in this category have stress on the stem." or
			stress == "ending" and
			"The adjectives in this category have stress on the endings." or
			"All adjectives of this type have stress on the stem."
		local endingtext = "ending in the nominative in masculine singular " .. args[2] .. ", feminine singular " .. args[3] .. ", neuter singular " .. args[4] .. " and plural " .. args[5] .. "."
		local stemtext
		if not stem_expl[stem] then
			error("Invalid stem type " .. stem)
		end
		stemtext = " The stem ends in " .. stem_expl[stem] .. "."

		maintext = stem .. " ~, " .. endingtext .. stemtext .. " " .. stresstext
		insert("~ by stem type and stress|" .. stem .. " " .. stress)
	elseif args[1] == "irreg" then
		local irregularity = rmatch(SUBPAGENAME, "^Ukrainian adjectives with irregular (.*)")
		if not irregularity then
			error("Invalid category name, should be e.g. \"Ukrainian adjectives with irregular nominative masculine singular\"")
		end
		maintext = "~ with irregular " .. irregularity .. " (possibly along with other cases)."
		insert("~ by irregularity|" .. irregularity)
	elseif args[1] == "misc" then
		misctext = args[2]
		local sort_key = rmatch(SUBPAGENAME, "^Ukrainian adjectives with (.*)")
		if not sort_key then
			sort_key = rmatch(SUBPAGENAME, "^Ukrainian adjectives by (.*)")
		end
		if not sort_key then
			sort_key = rmatch(SUBPAGENAME, "^Ukrainian adjectives (.*)")
		end
		if not sort_key then
			sort_key = rmatch(SUBPAGENAME, "^Ukrainian (.*)")
		end
		if not sort_key then
			error("Invalid category name, should begin with \"Ukrainian\": " .. SUBPAGENAME)
		end
		insert("~|" .. sort_key)
	else
		error("Unknown 'uk-adj cat' type " .. (args[1] or "(empty)"))
	end

	return (misctext or "This category contains Ukrainian " .. rsub(maintext, "~", "adjectives"))
		.. "\n" ..
		mw.getCurrentFrame():expandTemplate{title="uk-categoryTOC", args={}}
		.. require("Module:utilities").format_categories(cats, lang, nil, nil, "force")
end

-- Externally callable function to parse and decline an adjective given
-- user-specified arguments. Return value is WORD_SPEC, an object where the
-- declined forms are in `WORD_SPEC.forms` for each slot. If there are no values
-- for a slot, the slot key will be missing. The value for a given slot is a
-- list of objects {form=FORM, footnotes=FOOTNOTES}.
function export.do_generate_forms(parent_args, pos, from_headword, def)
	local params = {
		[1] = {required = true, default = "си́ній"},
		footnote = {list = true},
		title = {},
	}
	for _, slot in ipairs(input_adjective_slots) do
		params[slot] = {}
	end

	local args = m_para.process(parent_args, params)
	local alternant_spec = parse_alternant_or_word_spec(args[1])
	alternant_spec.title = args.title
	alternant_spec.footnotes = args.footnote
	alternant_spec.forms = {}
	for _, base in ipairs(alternant_spec.alternants) do
		base.forms = alternant_spec.forms
		normalize_lemma(base)
	end
	detect_all_indicator_specs(alternant_spec)
	for _, base in ipairs(alternant_spec.alternants) do
		decls[base.decl](base, base.lemma)
	end
	process_overrides(alternant_spec.forms, args)
	set_accusative(alternant_spec)
	add_categories(alternant_spec)
	return alternant_spec
end


-- Externally callable function to parse and decline an adjective where all
-- forms are given manually. Return value is WORD_SPEC, an object where the
-- declined forms are in `WORD_SPEC.forms` for each slot. If there are no values
-- for a slot, the slot key will be missing. The value for a given slot is a
-- list of objects {form=FORM, footnotes=FOOTNOTES}.
function export.do_generate_forms_manual(parent_args, pos, from_headword, def)
	local params = {
		footnote = {list = true},
		title = {},
	}
	for _, slot in ipairs(input_adjective_slots) do
		params[slot] = {}
	end

	local args = m_para.process(parent_args, params)
	local alternant_spec = {
		title = args.title,
		footnotes = args.footnote,
		forms = {},
		manual = true,
	}
	process_overrides(alternant_spec.forms, args)
	set_accusative(alternant_spec)
	add_categories(alternant_spec)
	return alternant_spec
end


-- Entry point for {{uk-adecl}}. Template-callable function to parse and decline 
-- an adjective given user-specified arguments and generate a displayable table
-- of the declined forms.
function export.show(frame)
	local parent_args = frame:getParent().args
	local alternant_spec = export.do_generate_forms(parent_args)
	show_forms(alternant_spec)
	return make_table(alternant_spec) .. require("Module:utilities").format_categories(alternant_spec.categories, lang)
end


-- Entry point for {{uk-adecl-manual}}. Template-callable function to parse and
-- decline an adjective given manually-specified inflections and generate a
-- displayable table of the declined forms.
function export.show_manual(frame)
	local parent_args = frame:getParent().args
	local alternant_spec = export.do_generate_forms_manual(parent_args)
	show_forms(alternant_spec)
	return make_table(alternant_spec) .. require("Module:utilities").format_categories(alternant_spec.categories, lang)
end


-- Concatenate all forms of all slots into a single string of the form
-- "SLOT=FORM,FORM,...|SLOT=FORM,FORM,...|...". Embedded pipe symbols (as might
-- occur in embedded links) are converted to <!>. If INCLUDE_PROPS is given,
-- also include additional properties (currently, none). This is for use by
-- bots.
local function concat_forms(alternant_spec, include_props)
	local ins_text = {}
	for slot, _ in pairs(get_output_adjective_slots(alternant_spec)) do
		local formtext = com.concat_forms_in_slot(alternant_spec.forms[slot])
		if formtext then
			table.insert(ins_text, slot .. "=" .. formtext)
		end
	end
	return table.concat(ins_text, "|")
end

-- Template-callable function to parse and decline an adjective given
-- user-specified arguments and return the forms as a string
-- "SLOT=FORM,FORM,...|SLOT=FORM,FORM,...|...". Embedded pipe symbols (as might
-- occur in embedded links) are converted to <!>. If |include_props=1 is given,
-- also include additional properties (currently, none). This is for use by
-- bots.
function export.generate_forms(frame)
	local include_props = frame.args["include_props"]
	local parent_args = frame:getParent().args
	local alternant_spec = export.do_generate_forms(parent_args)
	return concat_forms(alternant_spec, include_props)
end


return export
