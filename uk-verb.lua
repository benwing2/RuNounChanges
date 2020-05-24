local export = {}


--[=[

Authorship: Ben Wing <benwing2>

]=]

--[=[

TERMINOLOGY:

-- "slot" = A particular combination of tense/mood/person/number/gender/etc.
	 Example slot names for nouns are "pres_1sg" (present first singular) and
	 "past_pasv_part_impers" (impersonal past passive participle).
	 Each slot is filled with zero or more forms.

-- "form" = The conjugated Ukrainian form representing the value of a given slot.

-- "lemma" = The dictionary form of a given Ukrainian term. Generally the infinitive,
	 but may occasionally be another form if the infinitive is missing.
]=]

local lang = require("Module:languages").getByCode("uk")
local m_links = require("Module:links")
local m_table_tools = require("Module:table tools")
local m_string_utilities = require("Module:string utilities")
local m_script_utilities = require("Module:script utilities")
local iut = require("Module:inflection utilities")
local m_para = require("Module:parameters")
local com = require("Module:User:Benwing2/uk-common")

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


local output_verb_slots = {
	["infinitive"] = "inf",
	["pres_actv_part"] = "pres|act|part",
	["past_actv_part"] = "past|act|part",
	["past_pasv_part"] = "past|pass|part",
	["pres_adv_part"] = "pres|adv|part",
	["past_pasv_part_impers"] = "impers|past|pass|part",
	["past_adv_part"] = "past|adv|part",
	["pres_1sg"] = "1|s|pres|ind",
	["pres_2sg"] = "2|s|pres|ind",
	["pres_3sg"] = "3|s|pres|ind",
	["pres_1pl"] = "1|p|pres|ind",
	["pres_2pl"] = "2|p|pres|ind",
	["pres_3pl"] = "3|p|pres|ind",
	["futr_1sg"] = "1|s|fut|ind",
	["futr_2sg"] = "2|s|fut|ind",
	["futr_3sg"] = "3|s|fut|ind",
	["futr_1pl"] = "1|p|fut|ind",
	["futr_2pl"] = "2|p|fut|ind",
	["futr_3pl"] = "3|p|fut|ind",
	["impr_2sg"] = "2|s|imp",
	["impr_1pl"] = "1|p|imp",
	["impr_2pl"] = "2|p|imp",
	["past_m"] = "m|s|past|ind",
	["past_f"] = "f|s|past|ind",
	["past_n"] = "n|s|past|ind",
	["past_pl"] = "p|past|ind",
}


local input_verb_slots = {}
for slot, _ in pairs(output_verb_slots) do
	if rfind(slot, "^pres_[123]") then
		table.insert(input_verb_slots, rsub(slot, "^pres_", "pres_futr_"))
	elseif not rfind(slot, "^futr_") then
		table.insert(input_verb_slots, slot)
	end
end


local futr_suffixes = {
	["1sg"] = "му",
	["2sg"] = "меш",
	["3sg"] = "ме",
	["1pl"] = {"мемо", "мем"},
	["2pl"] = "мете",
	["3pl"] = "муть",
}


local futr_refl_suffixes = {
	["1sg"] = {"мусь", "муся"},
	["2sg"] = "мешся",
	["3sg"] = "меться",
	["1pl"] = {"мемось", "мемося", "мемся"},
	["2pl"] = {"метесь", "метеся"},
	["3pl"] = "муться",
}


local budu_forms = {
	["1sg"] = "бу́ду",
	["2sg"] = "бу́деш",
	["3sg"] = "бу́де",
	["1pl"] = "бу́демо",
	["2pl"] = "бу́дете",
	["3pl"] = "бу́дуть",
}


local function stress_ending(ending)
	if type(ending) == "string" then
		return com.maybe_stress_final_syllable(ending)
	else
		for i, e in ipairs(ending) do
			ending[i] = com.maybe_stress_final_syllable(e)
		end
		return ending
	end
end


local function combine_stem_ending(stem, ending)
	if stem == "?" then
		return "?"
	else
		return stem .. ending
	end
end


local function convert_to_general_form(word_or_words)
	if type(word_or_words) == "string" then
		return {{form = word_or_words}}
	elseif word_or_words.form then
		return {word_or_words}
	else
		local retval = {}
		for _, form in ipairs(word_or_words) do
			if type(form) == "string" then
				table.insert(retval, {form = form})
			else
				table.insert(retval, form)
			end
		end
		return retval
	end
end


local function is_table_of_strings(forms)
	for _, form in ipairs(forms) do
		if type(form) ~= "string" then
			return false
		end
	end
	return true
end


local function add(forms, slot, stems, endings)
	if stems == nil then
		return
	end
	if type(stems) == "string" and type(endings) == "string" then
		iut.insert_form(forms, slot, {form = combine_stem_ending(stems, endings)})
	elseif type(stems) == "string" and is_table_of_strings(endings) then
		for _, ending in ipairs(endings) do
			iut.insert_form(forms, slot, {form = combine_stem_ending(stems, ending)})
		end
	else
		stems = convert_to_general_form(stems)
		endings = convert_to_general_form(endings)
		for _, stem in ipairs(stems) do
			for _, ending in ipairs(endings) do
				local footnotes = nil
				if stem.footnotes and ending.footnotes then
					footnotes = m_table.shallowcopy(stem.footnotes)
					for _, footnote in ipairs(ending.footnotes) do
						m_table.insertIfNot(footnotes, footnote)
					end
				elseif stem.footnotes then
					footnotes = stem.footnotes
				elseif ending.footnotes then
					footnotes = ending.footnotes
				end
				iut.insert_form(forms, slot, {form = combine_stem_ending(stem.form, ending.form), footnotes = footnotes})
			end
		end
	end
end


local function add_pres_futr(base, stem, sg1, sg2, sg3, pl1, pl2, pl3)
	add(base.forms, "pres_futr_1sg", stem, sg1)
	add(base.forms, "pres_futr_2sg", stem, sg2)
	add(base.forms, "pres_futr_3sg", stem, sg3)
	add(base.forms, "pres_futr_1pl", stem, pl1)
	add(base.forms, "pres_futr_2pl", stem, pl2)
	add(base.forms, "pres_futr_3pl", stem, pl3)
	-- Do the present adverbial participle, which is based on the third plural present.
	if base.aspect ~= "pf" and type(pl3) == "string" then
		local pl3base = rmatch(pl3, "^(.-)ть$")
		if not pl3base then
			error("Invalid third-plural ending, doesn't end in -ть: '" .. pl3 .. "'")
		end
		local ending = "чи"
		if com.is_stressed(pl3base) then
			pl3base = com.remove_stress(pl3base)
			ending = "чи́"
		end
		add(base.forms, "pres_adv_part", stem, pl3base .. ending)
	end
end


local function stress_present_endings_per_accent(endings, accent)
	if accent == "b" then
		for i, ending in ipairs(endings) do
			endings[i] = stress_ending(ending)
		end
	elseif accent == "c" then
		endings[1] = stress_ending(endings[1])
	end
	return endings
end


local function add_present_e(base, stem, accent, use_y_endings)
	local endings
	if use_y_endings == "all" or rfind(stem, com.vowel_c .. AC .. "?$") then
		endings = {"ю", "єш", base.is_refl and "єть" or "є", {"єм", "ємо"}, "єте", "ють"}
	elseif use_y_endings == "1sg3pl" and not rfind(stem, com.hushing_c .. "$") then
		endings = {"ю", "еш", base.is_refl and "еть" or "е", {"ем", "емо"}, "ете", "ють"}
	else
		endings = {"у", "еш", base.is_refl and "еть" or "е", {"ем", "емо"}, "ете", "уть"}
	end
	endings = stress_present_endings_per_accent(endings, accent)
	add_pres_futr(base, stem, unpack(endings))
end


local function add_present_i(base, stem, accent)
	local endings
	local iotated_type
	if rfind(stem, com.vowel_c .. AC .. "?$") then
		endings = {"ю", "їш", "їть", {"їм", "їмо"}, "їте", "ять"}
		iotated_type = "none"
	else
		local iotated_stem = com.iotate(stem)
		endings = {rfind(iotated_stem, com.hushing_c .. "$") and "у" or "ю", "иш", "ить",
			{"им", "имо"}, "ите", rfind(stem, com.hushing_c .. "$") and "ать" or "ять"}
		if stem == iotated_stem then
			iotated_type = "none"
		elseif rfind(iotated_stem, "л$") then
			iotated_type = "1sg3pl"
		else
			iotated_type = "1sg"
		end
	end
	endings = stress_present_endings_per_accent(endings, accent)
	local s1, s2, s3, p1, p2, p3 = unpack(endings)
	if iotated_type == "none" then
		add_pres_futr(base, stem, s1, s2, s3, p1, p2, p3)
	elseif iotated_type == "1sg" then
		add_pres_futr(base, iotated_stem, s1, {}, {}, {}, {}, {})
		add_pres_futr(base, stem, {}, s2, s3, p1, p2, p3)
	else
		add_pres_futr(base, iotated_stem, s1, {}, {}, {}, {}, p3)
		add_pres_futr(base, stem, {}, s2, s3, p1, p2, {})
	end
end


local function add_past(base, msgstem, reststem, accent)
	add(base.forms, "past_m", msgstem, "")
	add(base.forms, "past_f", reststem, accent == "b" and "а́" or "а")
	add(base.forms, "past_n", reststem, accent == "b" and "о́" or "о")
	add(base.forms, "past_pl", reststem, accent == "b" and "и́" or "и")
	add(base.forms, "past_adv_part", msgstem, "ши")
end


local function add_default_past(base, stem)
	add_past(base, stem .. "в", stem .. "л", "a")
end


local function add_imperative(base, sg2)
	add(base.forms, "impr_2sg", sg2, "")
	local stem, ac = rmatch(sg2, "^(.-)и(" .. AC .. "?)$")
	if stem then
		local vowel = "і" .. ac
		add(base.forms, "impr_1pl", stem, {vowel .. "м", vowel .. "мо"})
		add(base.forms, "impr_2pl", stem, {vowel .. "ть"})
	elseif rfind(sg2, com.vowel_c .. AC .. "?$") then
		error("Invalid 2sg imperative, ends in vowel other than -и: '" .. sg2 .. "'")
	else
		add(base.forms, "impr_1pl", sg2, "мо")
		add(base.forms, "impr_2pl", sg2, "те")
	end
end


local function add_moving_ppp(base, stem)
	local stembase, last_syl = rmatch(stem, "^(.-)(" .. com.vowel_c .. AC .. "?[нт])$")
	if not stembase then
		error("Unrecognized stem for past passive participle: '" .. stem .. "'")
	end
	if com.is_stressed(last_syl) and not com.is_nonsyllabic(stembase) then
		stembase = com.maybe_stress_final_syllable(stembase)
		last_syl = com.remove_stress(last_syl)
		stem = stembase .. last_syl
	end
	add(base.forms, "past_pasv_part", stem, "ий")
	add(base.forms, "past_pasv_part_impers", stem, "о")
end


local conjs = {}


conjs["1a"] = function(base, lemma)
	local stem = rmatch(lemma, "^(.*[аяі]́?)ти$")
	if not stem then
		error("Unrecognized lemma for class 1a: '" .. lemma .. "'")
	end
	add_present_e(base, stem, "a")
	add_default_past(base, stem)
	add_imperative(base, stem .. "й")
	add_moving_ppp(base, stem .. "н")
end


local function parse_indicator_and_form_spec(angle_bracket_spec)
	local inside = rmatch(angle_bracket_spec, "^<(.*)>$")
	assert(inside)
	local base = {}
	local parts = rsplit(inside, ".", true)
	local conjarg = parts[1]
	local conj, past_accent = rmatch(conjarg, "^(.*)/(.*)$")
	if past_accent then
		if past_accent ~= "a" and past_accent ~= "b" then
			error("Unrecognized past-tense accent in conjugation spec '" .. conjarg .. "', should be 'a' or 'b': '" .. past_accent .. "'")
		end
		base.past_accent = past_accent
	else
		conj = conjarg
	end
	if conj ~= "irreg" then
		conj, base.conj_star = rsubb(conj, "%*", "")
		if not rfind(conj, "^[0-9]+°?[abc]$") then
			error("Invalid format for conjugation, should be e.g. '1a', '4b' or '6°c': '" .. conj .. "'")
		end
		if not conjs[conj] then
			error("Unrecognized conjugation: '" .. conj .. "'")
		end
	end
	base.conj = conj
	for i=2,#parts do
		local part = parts[i]
		if part == "impf" or part == "pf" then
			if base.aspect then
				error("Can't specify aspect twice: '" .. inside .. "'")
			end
			base.aspect = part
		elseif part == "tr" or part == "intr" then
			if base.trans then
				error("Can't specify transitivity twice: " .. inside .. "'")
			end
			base.trans = part
		elseif part == "-ppp" then
			if base.no_ppp then
				error("Can't specify '-ppp' twice: " .. inside .. "'")
			end
			base.no_ppp = true
		elseif part == "impers" then
			if base.impers then
				error("Can't specify 'impers' twice: " .. inside .. "'")
			end
			base.impers = true
		elseif part == "с" or part == "д" or part == "т" or part == "ст" or part == "в" then
			if not rfind(conj, "^7") then
				error("Specification '" .. part .. "' can only be specified for class 7")
			end
			if base.cons then
				error("Can't specify class-7 consonant twice: " .. inside .. "'")
			end
			base.cons = part
		elseif part == "м" or part == "н" then
			if not rfind(conj, "^14") then
				error("Specification '" .. part .. "' can only be specified for class 14")
			end
			if base.cons then
				error("Can't specify class-14 consonant twice: " .. inside .. "'")
			end
			base.cons = part
		elseif part == "-і" then
			if not rfind(conj, "^7") then
				error("Specification '-і' can only be specified for class 7")
			end
			if base.no_i then
				error("Can't specify '-і' twice: " .. inside .. "'")
			end
			base.no_i = true
		else
			error("Unrecognized indicator '" .. part .. "': '" .. inside .. "'")
		end
	end
	return base
end


-- Separate out reflexive suffix, check that multisyllabic lemmas have stress, and add stress
-- to monosyllabic lemmas if needed.
local function normalize_lemma(base, lemma)
	base.orig_lemma = lemma
	lemma = com.add_monosyllabic_stress(lemma)
	if not rfind(lemma, AC) then
		error("Multisyllabic lemma '" .. base.orig_lemma .. "' needs an accent")
	end
	local active_verb, refl = rmatch(lemma, "^(.*)(с[яь])$")
	if active_verb then
		base.is_refl = true
		lemma = active_verb
	end
	if rfind(lemma, "ть$") then
		if refl == "сь" then
			error("Reflexive infinitive lemma in -тьсь not possible, use -тися, -тись or ться: '" .. base.orig_lemma)
		end
		lemma = rsub(lemma, "ть$", "ти")
	end
	return lemma
end


local function detect_indicator_and_form_spec(base, lemma)
	if not base.aspect then
		error("Aspect of 'pf' or 'impf' must be specified")
	end
	if base.is_refl then
		if base.trans then
			error("Can't specify transitivity with reflexive verb, they're always intransitive: '" .. base.orig_lemma .. "'")
		end
	elseif not base.trans then
		error("Transitivity of 'tr' or 'intr' must be specified")
	end
	if base.no_ppp then
		if base.trans ~= "tr" then
			error("Can only specify '-ppp' with transitive verbs")
		end
	end
end


local function parse_word_spec(text)
	local segments = iut.parse_balanced_segment_run(text, "<", ">")
	if #segments ~= 3 or segments[3] ~= "" then
		error("Verb spec must be of the form 'LEMMA<CONJ.SPECS>': '" .. text .. "'")
	end
	local lemma = segments[1]
	local base = parse_indicator_and_form_spec(segments[2])
	return base, lemma
end


local function add_reflexive_suffix(base)
	-- FIXME: Implement me
end


local function process_overrides(forms, args)
	for _, slot in ipairs(input_verb_slots) do
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


local function add_alt_infinitive(base)
	local newinf = {}
	local forms = base.forms
	if forms.infinitive then
		forms.infinitive = iut.flatmap_forms(forms.infinitive, function(inf)
			inf = com.add_monosyllabic_stress(inf)
			if rfind(inf, com.vowel_c .. AC .. "?ти$") then
				return {inf, rsub(inf, "ти$", "ть")}
			elseif rfind(inf, com.vowel_c .. AC .. "?тис[яь]$") then
				return {inf, rsub(inf, "тис[яь]$", "ться")}
			else
				return {inf}
			end
		end)
	end
end


local function set_reflexive_flag(base)
	if base.forms.infinitive then
		for _, inf in ipairs(base.forms.infinitive) do
			if rfind(inf.form, "с[яь]$") then
				base.is_refl = true
			end
		end
	end
end


local function set_present_future(base)
	local forms = base.forms
	if base.aspect == "pf" then
		for suffix, _ in pairs(futr_suffixes) do
			forms["futr_" .. suffix] = forms["pres_futr_" .. suffix]
		end
	else
		for suffix, _ in pairs(futr_suffixes) do
			forms["pres_" .. suffix] = forms["pres_futr_" .. suffix]
		end
		-- Do the periphrastic future with бу́ду
		if forms.infinitive then
			for _, inf in ipairs(forms.infinitive) do
				for slot_suffix, _ in pairs(futr_suffixes) do
					local futrslot = "futr_" .. slot_suffix
					iut.insert_form(forms, futrslot, {
						form = "[[" .. budu_forms[slot_suffix] .. "]] [[" ..
							com.initial_alternation(inf.form, budu_forms[slot_suffix]) .. "]]",
						no_accel = true,
					})
				end
			end
		end
		-- Do the synthetic future
		if forms.infinitive then
			for _, inf in ipairs(forms.infinitive) do
				local futr_sufs
				local infstem = rmatch(inf.form, "^(.-)с[яь]$")
				if infstem then
					futr_sufs = futr_refl_suffixes
				else
					futr_sufs = futr_suffixes
					infstem = inf.form
				end
				for slot_suffix, futr_suffix in pairs(futr_sufs) do
					local futrslot = "futr_" .. slot_suffix
					if rfind(infstem, "ти́?$") then
						if type(futr_suffix) ~= "table" then
							futr_suffix = {futr_suffix}
						end
						for _, fs in ipairs(futr_suffix) do
							iut.insert_form(forms, futrslot, {
								form = infstem .. fs
							})
						end
					end
				end
			end
		end
	end
end


-- Remove impersonal, non-3rd-person, and/or imperfective-only forms.
local function remove_nonexistent_forms(base)
	-- FIXME: Implement me
end


local function add_categories(base)
	base.categories = {}
	if base.aspect == "impf" then
		table.insert(base.categories, "Ukrainian imperfective verbs")
	elseif base.aspect == "pf" then
		table.insert(base.categories, "Ukrainian perfective verbs")
	else
		assert(base.aspect == "both")
		table.insert(base.categories, "Ukrainian imperfective verbs")
		table.insert(base.categories, "Ukrainian perfective verbs")
		table.insert(base.categories, "Ukrainian biaspectual verbs")
	end
	if base.is_refl then
		table.insert(base.categories, "Ukrainian reflexive verbs")
	end
end


local function show_forms(base)
	local forms = base.forms
	local lemmas = {}
	if forms.infinitive then
		for _, inf in ipairs(forms.infinitive) do
			table.insert(lemmas, com.remove_monosyllabic_stress(inf.form))
		end
	end
	local accel_lemma = lemmas[1]
	forms.lemma = #lemmas > 0 and table.concat(lemmas, ", ") or PAGENAME

	for slot, accel_form in pairs(output_verb_slots) do
		local formvals = forms[slot]
		if formvals then
			local uk_spans = {}
			local tr_spans = {}
			for i, form in ipairs(formvals) do
				-- FIXME, this doesn't necessarily work correctly if there is an
				-- embedded link in form.form.
				local uk_text = com.remove_monosyllabic_stress(form.form)
				local link, tr
				if form.form == "—" or form.form == "?" then
					link = uk_text
				else
					local accel_obj
					if accel_lemma and not form.no_accel then
						accel_obj = {
							form = accel_form,
							lemma = accel_lemma,
						}
					end
					local ukentry, uknotes = m_table_tools.get_notes(uk_text)
					link = m_links.full_link{lang = lang, term = ukentry,
						tr = "-", accel = accel_obj} .. uknotes
				end
				tr = com.translit_no_links(uk_text)
				local trentry, trnotes = m_table_tools.get_notes(tr)
				tr = require("Module:script utilities").tag_translit(trentry, lang, "default", " style=\"color: #888;\"") .. trnotes
				table.insert(uk_spans, link)
				table.insert(tr_spans, tr)
			end
			local uk_span = table.concat(uk_spans, ", ")
			local tr_span = table.concat(tr_spans, ", ")
			forms[slot] = uk_span .. "<br />" .. tr_span
		else
			forms[slot] = "—"
		end
	end

	local all_notes = {}
	for _, note in ipairs(base.footnotes) do
		local symbol, entry = m_table_tools.get_initial_notes(note)
		table.insert(all_notes, symbol .. entry)
	end
	forms.footnote = table.concat(all_notes, "<br />")
end


local function make_table(base)
	local forms = base.forms

	local table_spec = [=[
<div class="NavFrame" style="width:60em">
<div class="NavHead" style="text-align:left; background:#e0e0ff;">{title}{annotation}</div>
<div class="NavContent">
{\op}| class="inflection-table inflection inflection-uk inflection-verb"
|+ For declension of participles, see their entries. Adverbial participles are indeclinable.
|- class="rowgroup"
! colspan="3" | {aspect_indicator}
|-
! [[infinitive]]
| colspan="2" | {infinitive}
|- class="rowgroup"
! [[participles]]
! [[present tense]]
! [[past tense]]
|-
! [[active]]
| {pres_actv_part}
| {past_actv_part}
|-
! [[passive]]
| &mdash;<!--absent-->
| {past_pasv_part}{past_pasv_part_impers}
|-
! [[adverbial]]
| {pres_adv_part}
| {past_adv_part}
|- class="rowgroup"
! 
! [[present tense]]
! [[future tense]]
|-
! [[first-person singular|1st singular]]<br />{ya}
| {pres_1sg}
| {futr_1sg}
|-
! [[second-person singular|2nd singular]]<br />{ty}
| {pres_2sg}
| {futr_2sg}
|-
! [[third-person singular|3rd singular]]<br />{vin_vona_vono}
| {pres_3sg}
| {futr_3sg}
|-
! [[first-person plural|1st plural]]<br />{my}
| {pres_1pl}
| {futr_1pl}
|-
! [[second-person plural|2nd plural]]<br />{vy}
| {pres_2pl}
| {futr_2pl}
|-
! [[third-person plural|3rd plural]]<br />{vony}
| {pres_3pl}
| {futr_3pl}
|- class="rowgroup"
! [[imperative]]
! [[singular]]
! [[plural]]
|-
! first-person
| —
| {impr_1pl}
|-
! second-person
| {impr_2sg}
| {impr_2pl}
|- class="rowgroup"
! [[past tense]]
! [[singular]]
! [[plural]]<br />{my_vy_vony}
|-
! [[masculine]]<br />{ya_ty_vin}
| {past_m}
| rowspan="3" | {past_pl}
|-
! [[feminine]]<br />{ya_ty_vona}
| {past_f}
|- 
! [[neuter]]<br />{vono}
| {past_n}
|{\cl}{notes_clause}</div></div>]=]

	local notes_template = [===[
<div style="width:100%;text-align:left;background:#d9ebff">
<div style="display:inline-block;text-align:left;padding-left:1em;padding-right:1em">
{footnote}
</div></div>
]===]

	if base.title then
		forms.title = base.title
	else
		forms.title = 'Conjugation of <i lang="uk" class="Cyrl">' .. forms.lemma .. '</i>'
	end
	if forms.past_pasv_part_impers == "—" then
		forms.past_pasv_part_impers = ""
	else
		forms.past_pasv_part_impers = "<br />impersonal: " .. forms.past_pasv_part_impers
	end

	local ann_parts = {}
	table.insert(ann_parts,
		base.aspect == "impf" and "imperfective" or
		base.aspect == "pf" and "perfective" or
		"biaspectual")
	if base.is_refl then
		table.insert(ann_parts, "reflexive")
	end
	forms.annotation = " (" .. table.concat(ann_parts, ", ") .. ")"

	-- pronouns used in the table
	forms.ya = tag_text("я")
	forms.ty = tag_text("ти")
	forms.vin_vona_vono = tag_text("він / вона / воно")
	forms.my = tag_text("ми")
	forms.vy = tag_text("ви")
	forms.vony = tag_text("вони")
	forms.my_vy_vony = tag_text("ми / ви / вони")
	forms.ya_ty_vin = tag_text("я / ти / він")
	forms.ya_ty_vona = tag_text("я / ти / вона")
	forms.vono = tag_text("воно")

	if base.aspect == "pf" then
		forms.aspect_indicator = "[[perfective aspect]]"
	else
		forms.aspect_indicator = "[[imperfective aspect]]"
	end

	forms.notes_clause = forms.footnote ~= "" and
		m_string_utilities.format(notes_template, forms) or ""
	return m_string_utilities.format(table_spec, forms)
end


-- Externally callable function to parse and decline a verb given user-specified arguments.
-- Return value is WORD_SPEC, an object where the declined forms are in `WORD_SPEC.forms`
-- for each slot. If there are no values for a slot, the slot key will be missing. The value
-- for a given slot is a list of objects {form=FORM, footnotes=FOOTNOTES}.
function export.do_generate_forms(parent_args, pos, from_headword, def)
	local params = {
		[1] = {required = true, default = "чита́ти"},
		footnote = {list = true},
		title = {},
	}
	for _, slot in ipairs(input_verb_slots) do
		params[slot] = {}
	end

	local args = m_para.process(parent_args, params)
	local base, lemma = parse_word_spec(args[1])
	base.title = args.title
	base.footnotes = args.footnote
	base.forms = {}
	lemma = normalize_lemma(base, lemma)
	detect_indicator_and_form_spec(base, lemma)
	conjs[base.conj](base, lemma)
	if base.is_refl then
		add_reflexive_suffix(base)
	end
	process_overrides(base.forms, args)
	set_present_future(base)
	remove_nonexistent_forms(base)
	add_categories(base)
	return base
end


-- Externally callable function to parse and decline a verb given user-specified arguments.
-- Return value is WORD_SPEC, an object where the declined forms are in `WORD_SPEC.forms`
-- for each slot. If there are no values for a slot, the slot key will be missing. The value
-- for a given slot is a list of objects {form=FORM, footnotes=FOOTNOTES}.
function export.do_generate_forms_manual(parent_args, pos, from_headword, def)
	local params = {
		footnote = {list = true},
		title = {},
		aspect = {required = true, default = "impf"},
	}
	for _, slot in ipairs(input_verb_slots) do
		params[slot] = {}
	end

	local args = m_para.process(parent_args, params)
	if args.aspect ~= "pf" and args.aspect ~= "impf" then
		error("Aspect '" .. args.aspect .. "' must be 'pf' or 'impf'")
	end
	local base = {
		aspect = args.aspect,
		title = args.title,
		footnotes = args.footnote,
		forms = {}
	}
	process_overrides(base.forms, args)
	add_alt_infinitive(base)
	set_reflexive_flag(base)
	set_present_future(base)
	add_categories(base)
	return base
end


-- Entry point for {{uk-conj}}. Template-callable function to parse and conjugate a verb given
-- user-specified arguments and generate a displayable table of the conjugated forms.
function export.show(frame)
	local parent_args = frame:getParent().args
	local base = export.do_generate_forms(parent_args)
	show_forms(base)
	return make_table(base) .. require("Module:utilities").format_categories(base.categories, lang)
end


-- Entry point for {{uk-conj-table}}. Template-callable function to parse and conjugate a verb given
-- manually-specified inflections and generate a displayable table of the conjugated forms.
function export.show_manual(frame)
	local parent_args = frame:getParent().args
	local base = export.do_generate_forms_manual(parent_args)
	show_forms(base)
	return make_table(base) .. require("Module:utilities").format_categories(base.categories, lang)
end


-- Concatenate all forms of all slots into a single string of the form
-- "SLOT=FORM,FORM,...|SLOT=FORM,FORM,...|...". Embedded pipe symbols (as might occur
-- in embedded links) are converted to <!>. If INCLUDE_PROPS is given, also include
-- additional properties (currently, only "|aspect=ASPECT"). This is for use by bots.
local function concat_forms(base, include_props)
	local ins_text = {}
	for slot, _ in pairs(output_verb_slots) do
		local formtext = com.concat_forms_in_slot(base.forms[slot])
		if formtext then
			table.insert(ins_text, slot .. "=" .. formtext)
		end
	end
	if include_props then
		table.insert(ins_text, "aspect=" .. base.aspect)
	end
	return table.concat(ins_text, "|")
end

-- Template-callable function to parse and decline a noun given user-specified arguments and return
-- the forms as a string "SLOT=FORM,FORM,...|SLOT=FORM,FORM,...|...". Embedded pipe symbols (as might
-- occur in embedded links) are converted to <!>. If |include_props=1 is given, also include
-- additional properties (currently, only "|aspect=ASPECT"). This is for use by bots.
function export.generate_forms(frame)
	local include_props = frame.args["include_props"]
	local parent_args = frame:getParent().args
	local base = export.do_generate_forms(parent_args)
	return concat_forms(base, include_props)
end


return export
