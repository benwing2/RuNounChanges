local export = {}


--[=[

Authorship: Ben Wing <benwing2>

]=]

--[=[

TERMINOLOGY:

-- "slot" = A particular combination of case/gender/number.
	 Example slot names for adjectives are "gen_f" (genitive feminine singular) and
	 "loc_p" (locative plural). Each slot is filled with zero or more forms.

-- "form" = The declined Belarusian form representing the value of a given slot.

-- "lemma" = The dictionary form of a given Belarusian term. Generally the nominative
     masculine singular, but may occasionally be another form if the nominative
	 masculine singular is missing.
]=]

local lang = require("Module:languages").getByCode("be")
local m_links = require("Module:links")
local m_table = require("Module:table")
local m_string_utilities = require("Module:string utilities")
local iut = require("Module:inflection utilities")
local m_para = require("Module:parameters")
local com = require("Module:be-common")

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
	short_m = "short|m|s",
	short_f = "short|f|s",
	short_n = "short|n|s",
	short_p = "short|p",
}

local output_adjective_slots_with_linked = m_table.shallowcopy(output_adjective_slots)
output_adjective_slots_with_linked["nom_m_linked"] = "nom|m|s"


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
}

local output_adjective_slots_surname_with_linked = m_table.shallowcopy(output_adjective_slots_surname)
output_adjective_slots_surname_with_linked["nom_m_linked"] = "nom|m|s"


local input_adjective_slots = {}
for slot, _ in pairs(output_adjective_slots) do
	if not rfind(slot, "_[ai]n$") then
		table.insert(input_adjective_slots, slot)
	end
end


local function get_output_adjective_slots(base, with_linked)
	if base.surname then
		return with_linked and output_adjective_slots_surname_with_linked or output_adjective_slots_surname
	else
		return with_linked and output_adjective_slots_with_linked or output_adjective_slots
	end
end


local function combine_stem_ending(stem, ending)
	if stem == "?" then
		return "?"
	else
		return stem .. ending
	end
end


local function add(base, slot, stems, endings)
	if get_output_adjective_slots(base)[slot] then
		-- Here, just add the stem and ending, in case the stem has unstressed
		-- ё or э in it.
		iut.add_forms(base.forms, slot, stems, endings, combine_stem_ending)
	end
end


local function add_normal_decl(base, stem,
	nom_m, nom_f, nom_n, nom_p, gen_m, gen_f, gen_p,
	dat_m, dat_f, dat_p, acc_f,
	ins_m, ins_f, ins_p, loc_m, loc_f, loc_p,
	footnote)
	stem = iut.generate_form(stem, footnote)
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


local function destress_ending(ending)
	if type(ending) == "string" then
		return com.make_unstressed(ending)
	else
		for i, e in ipairs(ending) do
			ending[i] = destress_ending(e)
		end
		return ending
	end
end

local function maybe_destress_endings(suffix, endings)
	if not com.is_stressed(suffix) then
		for i, e in ipairs(endings) do
			endings[i] = destress_ending(e)
		end
	end
end


local function y_to_i(ending)
	if type(ending) == "string" then
		return rsub(ending, "ы", "і")
	else
		for i, e in ipairs(ending) do
			ending[i] = y_to_i(e)
		end
		return ending
	end
end

local function y_to_i_endings(endings)
	for i, e in ipairs(endings) do
		endings[i] = y_to_i(e)
	end
end


-- See documentation for `use_variant_codes` in do_generate_forms().
local function maybe_tag_ins_s_with_variant(base, ins_s_endings)
	if base.use_variant_codes then
		assert(type(ins_s_endings) == "table")
		assert(#ins_s_endings == 2)
		local ending1, ending2 = unpack(ins_s_endings)
		return {ending1 .. com.VAR1, ending2 .. com.VAR2}
	else
		return ins_s_endings
	end
end


local decls = {}

decls["normal"] = function(base)
	local normal_endings, old_endings
	local stem, suffix

	local function add_endings()
		maybe_destress_endings(suffix, normal_endings)
		if rfind(stem, com.velar_c .. "$") then
			y_to_i_endings(normal_endings)
		end
		add_normal_decl(base, stem, unpack(normal_endings))
	end

	-- hard in -ы (including velar in -і)
	stem, suffix = rmatch(base.lemma, "^(.*" .. com.velar_c .. ")(і́?)$")
	if not stem then
		stem, suffix = rmatch(base.lemma, "^(.*)(ы́?)$")
	end
	if stem then
		normal_endings = {
			"ы́", "а́я", "о́е", "ы́я", --nom
			"о́га", "о́й", "ы́х", --gen
			"о́му", "о́й", "ы́м", --dat
			"у́ю", --acc
			"ы́м", maybe_tag_ins_s_with_variant(base, {"о́й", "о́ю"}), "ы́мі", --ins
			"ы́м", "о́й", "ы́х", --loc
		}
		add_endings()
		return
	end

	-- soft in -і
	stem, suffix = rmatch(base.lemma, "^(.*)(і́?)$")
	if stem then
		normal_endings = {
			-- This isn't quite right, maybe should be "ё́я" etc.; but
			-- stressed variants of these endings never occur.
			"і́", "я́я", "я́е", "і́я", --nom
			"я́га", "я́й", "і́х", --gen
			"я́му", "я́й", "і́м", --dat
			"ю́ю", --acc
			"і́м", maybe_tag_ins_s_with_variant(base, {"я́й", "я́ю"}), "і́мі", --ins
			"і́м", "я́й", "і́х", --loc
		}
		add_endings()
		return
	end

	error("Unrecognized adjective lemma, should end in '-ы' or '-і': '" .. base.lemma .. "'")
end


local function get_possessive_stem_suffix_ending_prefix(lemma, adjtype)
	local stem, suffix, ending_prefix
	while true do
		stem, suffix = rmatch(lemma, "^(.*)([аеё]ў)$")
		if stem then
			ending_prefix = rsub(suffix, "ў$", "в")
			break
		end
		stem, suffix = rmatch(lemma, "^(.*)([ое]́ў)$")
		if stem then
			ending_prefix = rsub(suffix, "ў$", "в")
			break
		end
		stem, suffix = rmatch(lemma, "^(.*)([ыі]́?н)$")
		if stem then
			ending_prefix = suffix
			break
		end
		error("Unrecognized " .. adjtype .. " lemma, should end in '-аў', '-о́ў', '-еў', '-ёў', '-ын' or '-ін': '" .. lemma .. "'")
	end
	return stem, suffix, ending_prefix
end


decls["poss"] = function(base)
	local stem, suffix, ending_prefix =
		get_possessive_stem_suffix_ending_prefix(base.lemma, "possessive adjective")

	local endings = {
		"а", "а", "ы", --nom
		"ага", "ай", "ых", --gen
		"аму", "ай", "ым", --dat
		"у", --acc
		"ым", maybe_tag_ins_s_with_variant(base, {"ай", "аю"}), "ымі", --ins
		"ым", "ай", "ых", --loc
	}
	-- Do the nominative singular separately from the rest, which may have
	-- a different stem ending (e.g. -аў vs. -ав).
	add_normal_decl(base, stem, suffix)
	add_normal_decl(base, stem .. ending_prefix, nil, unpack(endings))
end


decls["surname"] = function(base)
	local stem, suffix, ending_prefix =
		get_possessive_stem_suffix_ending_prefix(base.lemma, "possessive surname")

	local endings = {
		"а", nil, "ы", --nom
		"а", "ай", "ых", --gen
		"у", "ай", "ым", --dat
		"у", --acc
		"ым", maybe_tag_ins_s_with_variant(base, {"ай", "аю"}), "ымі", --ins
		"е", "ай", "ых", --loc
	}
	-- Do the nominative singular separately from the rest, which may have
	-- a different stem ending (e.g. -аў vs. -ав).
	add_normal_decl(base, stem, suffix)
	add_normal_decl(base, stem .. ending_prefix, nil, unpack(endings))
end


local function parse_indicator_spec(angle_bracket_spec)
	local inside = rmatch(angle_bracket_spec, "^<(.*)>$")
	assert(inside)
	local base = {forms = {}}
	if inside ~= "" then
		local parts = rsplit(inside, ".", true)
		for _, part in ipairs(parts) do
			if part == "surname" then
				if base.surname then
					error("Can't specify 'surname' twice: '" .. inside .. "'")
				end
				base.surname = true
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
		if not com.is_stressed(base.lemma) then
			error("Multisyllabic lemma '" .. base.orig_lemma .. "' needs an accent")
		end
	end)
end


local function detect_indicator_spec(base)
	if rfind(base.lemma, "[ыі]́?$") then
		base.decl = "normal"
	elseif rfind(base.lemma, "[ўн]$") then
		if base.surname then
			base.decl = "surname"
		else
			base.decl = "poss"
		end
	else
		error("Unrecognized adjective lemma: '" .. base.lemma .. "'")
	end
end


local function detect_all_indicator_specs(alternant_multiword_spec, use_variant_codes)
	iut.map_word_specs(alternant_multiword_spec, function(base)
		detect_indicator_spec(base)
		if alternant_multiword_spec.surname == nil then
			alternant_multiword_spec.surname = base.surname or false
		elseif alternant_multiword_spec.surname ~= (base.surname or false) then
			error("If 'surname' is specified in one alternant, it must be specified in all of them")
		end
		base.use_variant_codes = use_variant_codes
	end)
end


local function decline_adjective(base)
	if not decls[base.decl] then
		error("Internal error: Unrecognized declension type '" .. base.decl .. "'")
	end
	decls[base.decl](base)
	-- handle_derived_slots_and_overrides(base)
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


local function set_accusative(alternant_multiword_spec)
	local forms = alternant_multiword_spec.forms
	if alternant_multiword_spec.surname then
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


local function add_categories(alternant_multiword_spec)
	local cats = {}
	local function insert(cattype)
		table.insert(cats, "Belarusian " .. cattype .. " adjectives")
	end
	if not alternant_multiword_spec.manual then
		iut.map_word_specs(alternant_multiword_spec, function(base)
			if base.decl == "poss" then
				insert("possessive")
			elseif rfind(base.lemma, "ы$") then
				insert("hard stem-stressed")
			elseif rfind(base.lemma, "ы́$") then
				insert("hard ending-stressed")
			elseif rfind(base.lemma, com.velar_c .. "і$") then
				insert("velar-stem stem-stressed")
			elseif rfind(base.lemma, com.velar_c .. "і́$") then
				insert("velar-stem ending-stressed")
			elseif rfind(base.lemma, "і$") then
				insert("soft")
			end
		end)
	end
	alternant_multiword_spec.categories = cats
end


local function show_forms(alternant_multiword_spec)
	local lemmas = {}
	if alternant_multiword_spec.forms.nom_m then
		for _, nom_m in ipairs(alternant_multiword_spec.forms.nom_m) do
			table.insert(lemmas, com.remove_monosyllabic_accents(nom_m.form))
		end
	end
	props = {
		lang = lang,
		canonicalize = function(form)
			return com.remove_variant_codes(com.remove_monosyllabic_accents(form))
		end,
	}
	iut.show_forms_with_translit(alternant_multiword_spec.forms, lemmas,
		get_output_adjective_slots(alternant_multiword_spec), props,
		alternant_multiword_spec.footnotes, "allow footnote symbols")
end


local function make_table(alternant_multiword_spec)
	local forms = alternant_multiword_spec.forms

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
| {loc_p}
|{\cl}{notes_clause}</div></div></div>]=]

	local short_form_template = [=[

|-
! style="height:0.2em;background:#d9ebff" colspan="6" |
|-
! style="background:#eff7ff" colspan="2" | short form
| {short_m}
| {short_n}
| {short_f}
| {short_p}]=]

	local notes_template = [===[
<div style="width:100%;text-align:left;background:#d9ebff">
<div style="display:inline-block;text-align:left;padding-left:1em;padding-right:1em">
{footnote}
</div></div>
]===]

	if alternant_multiword_spec.title then
		forms.title = alternant_multiword_spec.title
	else
		forms.title = 'Declension of <i lang="be" class="Cyrl">' .. forms.lemma .. '</i>'
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
			elseif rfind(base.lemma, "ы́?$") then
				m_table.insertIfNot(decls, "hard")
			elseif rfind(base.lemma, com.velar_c .. "і́?$") then
				m_table.insertIfNot(decls, "velar")
			else
				m_table.insertIfNot(decls, "soft")
			end
		end)
		table.insert(ann_parts, table.concat(decls, " // "))
		forms.annotation = " (" .. table.concat(ann_parts, ", ") .. ")"
	end

	forms.notes_clause = forms.footnote ~= "" and
		m_string_utilities.format(notes_template, forms) or ""
	forms.short_clause = forms.short_m and forms.short_m ~= "—" and
		m_string_utilities.format(short_form_template, forms) or ""
	return m_string_utilities.format(
		alternant_multiword_spec.surname and table_spec_surname or table_spec, forms
	)
end


local stem_expl = {
	["soft"] = "a soft consonant",
	["hard"] = "a hard consonant other than a velar",
	["velar-stem"] = "a velar consonant",
	["possessive"] = "-ов, -ев, -ын or -ін",
}


export.adj_decl_endings = {
	["hard stem-stressed"] = {"-ы", "-ая", "-ае", "-ыя"},
	["hard ending-stressed"] = {"-ы́", "-а́я", "-о́е", "-ы́я"},
	["velar-stem stem-stressed"] = {"-і", "-ая", "-ае", "-ія"},
	["velar-stem ending-stressed"] = {"-і́", "-а́я", "-о́е", "-і́я"},
	["soft"] = {"-і", "-яя", "-яе", "-ія"},
	-- FIXME, not sure the rest are correct
	["possessive"] = {"-", "-а", "-а", "-і"},
	["surname"] = {"-", "-а", "(nil)", "-і"},
}


-- Implementation of template 'be-adj cat'.
function export.catboiler(frame)
	local SUBPAGENAME = mw.title.getCurrentTitle().subpageText
	local params = {
		[1] = {},
	}

	local parent_args = frame:getParent().args
	local args = m_para.process(parent_args, params)

	local cats = {}

	local function insert(cat)
	    table.insert(cats, "Belarusian " .. rsub(cat, "~", "adjectives"))
	end

	local maintext, misctext
	while true do
		if args[1] then
			misctext = args[1]
			local sort_key = rmatch(SUBPAGENAME, "^Belarusian adjectives with (.*)")
			if not sort_key then
				sort_key = rmatch(SUBPAGENAME, "^Belarusian adjectives by (.*)")
			end
			if not sort_key then
				sort_key = rmatch(SUBPAGENAME, "^Belarusian adjectives (.*)")
			end
			if not sort_key then
				sort_key = rmatch(SUBPAGENAME, "^Belarusian (.*)")
			end
			if not sort_key then
				error("Invalid category name, should begin with \"Belarusian\": " .. SUBPAGENAME)
			end
			insert("~|" .. sort_key)
			break
		end

		local stem, stress = rmatch(SUBPAGENAME, "^Belarusian ([^ ]*) ([^ *]*)-stressed adjectives")
		local endings_key
		if stem then
			endings_key = stem .. " " .. stress .. "-stressed"
		else
			stem = rmatch(SUBPAGENAME, "^Belarusian ([^ ]*) adjectives")
			stress = ""
			endings_key = stem
		end
		if stem then
			if not export.adj_decl_endings[endings_key] then
				error("Unrecognized stem or stress in category name")
			end
			local m, f, n, p = unpack(export.adj_decl_endings[endings_key])
			local stresstext = stress == "stem" and
				"The adjectives in this category have stress on the stem." or
				stress == "ending" and
				"The adjectives in this category have stress on the endings." or
				"All adjectives of this type have stress on the stem."
			local endingtext = "ending in the nominative in masculine singular " .. m .. ", feminine singular " .. f .. ", neuter singular " .. n .. " and plural " .. p .. "."
			local stemtext
			if not stem_expl[stem] then
				error("Invalid stem type " .. stem)
			end
			stemtext = " The stem ends in " .. stem_expl[stem] .. "."

			maintext = stem .. " ~, " .. endingtext .. stemtext .. " " .. stresstext
			insert("~ by stem type and stress|" .. stem .. " " .. stress)
			break
		end

		local irregularity = rmatch(SUBPAGENAME, "^Belarusian adjectives with irregular (.*)")
		if irregularity then
			maintext = "~ with irregular " .. irregularity .. " (possibly along with other cases)."
			insert("~ by irregularity|" .. irregularity)
			break
		end

		error("Unrecognized category: " .. SUBPAGENAME)
	end

	return (misctext or "This category contains Belarusian " .. rsub(maintext, "~", "adjectives"))
		.. "\n" ..
		mw.getCurrentFrame():expandTemplate{title="be-categoryTOC", args={}}
		.. require("Module:utilities").format_categories(cats, lang, nil, nil, "force")
end

-- Externally callable function to parse and decline an adjective given
-- user-specified arguments. Return value is ALTERNANT_MULTIWORD_SPEC, an
-- object where the declined forms are in `ALTERNANT_MULTIWORD_SPEC.forms` for
-- each slot. If there are no values for a slot, the slot key will be missing.
-- The value for a given slot is a list of objects {form=FORM, footnotes=FOOTNOTES}.
--
-- If `use_variant_codes` is given, add VAR1 (Unicode 0xFFF0) to feminine
-- instrumental singular endings in -й and VAR2 (Unicode 0xFFF1) to
-- corresponding endings in -ю. The same additions will be made to corresponding
-- noun endings, which will ensure that adjectival forms in -й are attached
-- only to nominal forms in -й and vice-versa.
function export.do_generate_forms(parent_args, pos, from_headword, def, use_variant_codes)
	local params = {
		[1] = {required = true, default = def or "сі́ні"},
		footnote = {list = true},
		title = {},
	}
	for _, slot in ipairs(input_adjective_slots) do
		params[slot] = {}
	end

	local args = m_para.process(parent_args, params)
	local alternant_multiword_spec = iut.parse_alternant_multiword_spec(args[1],
		parse_indicator_spec, "allow default indicator")
	alternant_multiword_spec.title = args.title
	alternant_multiword_spec.footnotes = args.footnote
	alternant_multiword_spec.forms = {}
	normalize_all_lemmas(alternant_multiword_spec)
	detect_all_indicator_specs(alternant_multiword_spec, use_variant_codes)
	local decline_props = {
		skip_slot = function(slot)
			return false
		end,
		slot_table = get_output_adjective_slots(alternant_multiword_spec, "with linked"),
		-- See documentation for `use_variant_codes` in do_generate_forms().
		get_variants = com.get_variants,
		decline_word_spec = decline_adjective,
	}
	iut.decline_multiword_or_alternant_multiword_spec(alternant_multiword_spec, decline_props)
	process_overrides(alternant_multiword_spec.forms, args)
	set_accusative(alternant_multiword_spec)
	add_categories(alternant_multiword_spec)
	return alternant_multiword_spec
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


-- Entry point for {{be-adecl}}. Template-callable function to parse and decline 
-- an adjective given user-specified arguments and generate a displayable table
-- of the declined forms.
function export.show(frame)
	local parent_args = frame:getParent().args
	local alternant_spec = export.do_generate_forms(parent_args)
	show_forms(alternant_spec)
	return make_table(alternant_spec) .. require("Module:utilities").format_categories(alternant_spec.categories, lang)
end


-- Entry point for {{be-adecl-manual}}. Template-callable function to parse and
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
