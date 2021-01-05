local export = {}


--[=[

Authorship: Ben Wing <benwing2>

]=]

--[=[

TERMINOLOGY:

-- "slot" = A particular combination of tense/mood/person/number/etc.
	 Example slot names for verbs are "pres_1s" (present first singular) and
	 "subc_subii_3p" (subordinate-clause subjunctive II third plural).
	 Each slot is filled with zero or more forms.

-- "form" = The conjugated German form representing the value of a given slot.

-- "lemma" = The dictionary form of a given German term. For German, always the infinitive.
]=]

local lang = require("Module:languages").getByCode("de")
local m_string_utilities = require("Module:string utilities")
local m_links = require("Module:links")
local m_table = require("Module:table")
local iut = require("Module:inflection utilities")

local rsplit = mw.text.split


local inseparable_prefixes = {
	-- use of empf- is intentional so other emp- words don't get flagged
	"be", "empf", "ent", "er", "ge", "miss", "miß", "ver", "zer",
	-- can also be separable
	"durch", "hinter", "über", "um", "unter", "voll", "wider", "wieder",
}

local past_subjunctive_footnote = "[rare in the spoken language]"

local all_persons_numbers = {
	["1s"] = "1|s",
	["2s"] = "2|s",
	["3s"] = "3|s",
	["1p"] = "1|p",
	["2p"] = "2|p",
	["3p"] = "3|p",
}

local verb_slots_basic = {
	["infinitive"] = "inf",
	["zu_infinitive"] = "zu", -- will be handled specially by [[Module:accel/de]]
	["pres_part"] = "pres|part",
	["perf_part"] = "perf|part",
	["imp_2s"] = "s|imp",
	["imp_2p"] = "p|imp",
}

local verb_slots_subordinate_clause = {
}

local verb_slots_composed = {
	["futi_inf"] = "-",
	["futii_inf"] = "-",
}

-- Add entries for a slot with person/number variants.
-- `verb_slots` is the table to add to.
-- `slot_prefix` is the prefix of the slot, typically specifying the tense/aspect.
-- `tag_suffix` is the set of inflection tags to add after the person/number tags,
-- or "-" to use "-" as the inflection tags (which indicates that no accelerator entry
-- should be generated).
local function add_slot_personal(verb_slots, slot_prefix, tag_suffix)
	for persnum, persnum_tag in pairs(all_persons_numbers) do
		local slot = slot_prefix .. "_" .. persnum
		if tag_suffix == "-" then
			verb_slots[slot] = "-"
		else
			verb_slots[slot] = persnum_tag .. "|" .. tag_suffix
		end
	end
end

add_slot_personal(verb_slots_basic, "pres", "pres")
add_slot_personal(verb_slots_basic, "subi", "sub|I")
add_slot_personal(verb_slots_basic, "subii", "sub|II")
add_slot_personal(verb_slots_basic, "pret", "pret")
add_slot_personal(verb_slots_subordinate_clause, "subc_pres", "dep|pres")
add_slot_personal(verb_slots_subordinate_clause, "subc_subi", "dep|sub|I")
add_slot_personal(verb_slots_subordinate_clause, "subc_subii", "dep|sub|II")
add_slot_personal(verb_slots_subordinate_clause, "subc_pret", "dep|pret")
add_slot_personal(verb_slots_composed, "perf_ind", "-")
add_slot_personal(verb_slots_composed, "perf_sub", "-")
add_slot_personal(verb_slots_composed, "plup_ind", "-")
add_slot_personal(verb_slots_composed, "plup_sub", "-")
add_slot_personal(verb_slots_composed, "futi_ind", "-")
add_slot_personal(verb_slots_composed, "futi_subi", "-")
add_slot_personal(verb_slots_composed, "futi_subii", "-")
add_slot_personal(verb_slots_composed, "futii_ind", "-")
add_slot_personal(verb_slots_composed, "futii_subi", "-")
add_slot_personal(verb_slots_composed, "futii_subii", "-")


local all_verb_slots = {}
for k, v in pairs(verb_slots_basic) do
	all_verb_slots[k] = v
end
for k, v in pairs(verb_slots_subordinate_clause) do
	all_verb_slots[k] = v
end
for k, v in pairs(verb_slots_composed) do
	all_verb_slots[k] = v
end


local function skip_slot(base, slot)
	return false
end


local function combine_stem_ending(stem, ending)
	if ending:find("^s") and rfind(stem, "[sxzß]$") then
		ending = ending:gsub("^s", "")
	end
	return stem .. ending
end


local function add(base, slot, stems, endings, footnotes)
	if skip_slot(base, slot) then
		return
	end
	iut.add_forms(base.forms, slot, stems, endings, combine_stem_ending, nil, nil, footnotes)
end


local pronouns = {
	["1s"] = "ich",
	["2s"] = "du",
	["3s"] = "er",
	["1p"] = "wir",
	["2p"] = "ihr",
	["3p"] = "sie",
}

local haben_forms = {
	["ind"] = {
		["1s"] = "habe",
		["2s"] = "hast",
		["3s"] = "hat",
		["1p"] = "haben",
		["2p"] = "habt",
		["3p"] = "haben",
	},
	["pret"] = {
		["1s"] = "hatte",
		["2s"] = "hattest",
		["3s"] = "hatte",
		["1p"] = "hatten",
		["2p"] = "hattet",
		["3p"] = "hatten",
	},
	["subi"] = {
		["1s"] = "habe",
		["2s"] = "habest",
		["3s"] = "habe",
		["1p"] = "haben",
		["2p"] = "habet",
		["3p"] = "haben",
	},
	["subii"] = {
		["1s"] = "hätte",
		["2s"] = "hättest",
		["3s"] = "hätte",
		["1p"] = "hätten",
		["2p"] = "hättet",
		["3p"] = "hätten",
	},
}

local sein_forms = {
	["ind"] = {
		["1s"] = "bin",
		["2s"] = "bist",
		["3s"] = "ist",
		["1p"] = "sind",
		["2p"] = "seid",
		["3p"] = "sind",
	},
	["pret"] = {
		["1s"] = "war",
		["2s"] = "warst",
		["3s"] = "war",
		["1p"] = "waren",
		["2p"] = "wart",
		["3p"] = "waren",
	},
	["subi"] = {
		["1s"] = "sei",
		["2s"] = "seist",
		["3s"] = "sei",
		["1p"] = "seien",
		["2p"] = "seiet",
		["3p"] = "seien",
	},
	["subii"] = {
		["1s"] = "wäre",
		["2s"] = {"wärst", "wärest"},
		["3s"] = "wäre",
		["1p"] = "wären",
		["2p"] = {"wärt", "wäret"},
		["3p"] = "wären",
	},
}

local werden_forms = {
	["ind"] = {
		["1s"] = "werde",
		["2s"] = "wirst",
		["3s"] = "wird",
		["1p"] = "werden",
		["2p"] = "werdet",
		["3p"] = "werden",
	},
	-- ["pret"] = "wurde", etc.; not used as auxiliaries
	["subi"] = {
		["1s"] = "werde",
		["2s"] = "werdest",
		["3s"] = "werde",
		["1p"] = "werden",
		["2p"] = "werdet",
		["3p"] = "werden",
	},
	["subii"] = {
		["1s"] = "würde",
		["2s"] = "würdest",
		["3s"] = "würde",
		["1p"] = "würden",
		["2p"] = "würdet",
		["3p"] = "würden",
	},
}


local function add_present(base)
	local stems = base.parts.infstem
	local stems23 = base.parts.pres_23 or stems

	local function doadd(slot_pref, form_pref)
		for _, stemform in ipairs(stems) do
			local prefixed_stem = form_pref .. stemform.form
			local syncopated_stem = base.unstressed_el_er and prefixed_stem:gsub("e([lr])$", "%1")

			local function addit(slot, stem, ending)
				add(base, slot_pref .. slot, stem, ending .. base.post_pref, stemform.footnotes)
			end
			-- present indicative
			if base.unstressed_el_er then
				addit("pres_1s", syncopated_stem, "e")
				addit("pres_1s", prefixed_stem, "e")
				addit("pres_1s", prefixed_stem, "")
			else
				addit("pres_1s", prefixed_stem, "e")
			end
			-- Three cases:
			-- (1) no -e- in 23s or 2p (most verbs).
			-- (2) -e- in 2p but not 23s (treten, gelten, ...); all these verbs are strong with a stem in -d or -t
			--     and have a special stem in 23s (tritt, gilt, etc.).
			-- (3) -e- in both 2p and 23s (bitten, atmen, ...). These are either strong verbs in -d or -t without
			--     a special stem in 23s, or weak verbs either in -d/-t or in two+ consonants that can't end a word
			--     (these must be indicated specially, set in `unstressed_e_infix`).
			local e_in_2p = prefixed_stem:find("[dt]$") or base.unstressed_e_infix
			if e_in_2p then
				addit("pres_2p", prefixed_stem, "et")
			else
				addit("pres_2p", prefixed_stem, "t")
			end
			addit("pres_1p", prefixed_stem, "en")
			addit("pres_3p", prefixed_stem, "en")

			-- subjunctive I
			addit("subi_1s", prefixed_stem, "e")
			addit("subi_2s", prefixed_stem, "est")
			addit("subi_3s", prefixed_stem, "e")
			addit("subi_2p", prefixed_stem, "et")
			if base.unstressed_el_er then
				addit("subi_1s", syncopated_stem, "e")
				addit("subi_2s", syncopated_stem, "est")
				addit("subi_3s", syncopated_stem, "e")
				addit("subi_2p", syncopated_stem, "et")
			end
			addit("subi_1p", prefixed_stem, "en")
			addit("subi_3p", prefixed_stem, "en")

			-- imperative plural
			if slot_pref == "" then
				if e_in_2p then
					addit("imp_2p", prefixed_stem, "et")
				else
					addit("imp_2p", prefixed_stem, "t")
				end
			end
		end

		for _, stem23form in ipairs(stems23) do
			local prefixed_stem23 = form_pref .. stem23form.form

			local function addit(slot, stem, ending)
				add(base, slot_pref .. slot, stem, ending .. base.post_pref, stem23form.footnotes)
			end

			local stem23_is_same_as_stem
			for _, stemform in ipairs(stems) do
				if stemform.form == stem23form.form then
					stem23_is_same_as_stem = true
					break
				end
			end

			-- present 2/3 singular
			local e_in_23s = base.unstressed_e_infix or stem23_is_same_as_stem and prefixed_stem23:find("[dt]$")
			if e_in_23s then
				addit("pres_2s", prefixed_stem23, "est")
				addit("pres_3s", prefixed_stem23, "et")
			else
				addit("pres_2s", prefixed_stem23, "st")
				addit("pres_3s", prefixed_stem23, "t")
			end

			-- imperative singular
			if slot_pref == "" then
				if e_in_23s then
					addit("imp_2s", prefixed_stem23, "e")
				elseif not stem23_is_same_as_stem or base.no_e_in_imp_2s then
					addit("imp_2s", prefixed_stem23, "")
				else
					addit("imp_2s", prefixed_stem23, "")
					addit("imp_2s", prefixed_stem23, "e")
				end
			end
		end
	end

	-- Do the basic forms
	doadd("", "")
	-- Also do the subordinate clause forms if any alternants have a prefix.
	if base.any_pre_pref then
		doadd("subc_", base.pre_pref)
	end
end


-- Add the past forms and/or subjunctive II forms. `stem` should include the -t suffix already
-- for the weak past.
local function add_past_or_subii(base, slot_pref, stem, is_strong)
	local function doadd(full_slot_pref, form_pref)
		for _, stemform in ipairs(stems) do
			local prefixed_stem = form_pref .. stemform.form
			local ends_in_dt = prefixed_stem:find("[dt]$")

			local function addit(slot, ending)
				add(base, full_slot_pref .. slot, prefixed_stem, ending .. base.post_pref, stemform.footnotes)
			end

			if is_strong then
				addit("1s", "")
				addit("3s", "")
				if not ends_in_dt then
					addit("2s", "st")
					addit("2p", "t")
				else
					addit("2s", "est")
					addit("2p", "et")
				end
			else
				-- Weak past and past subjunctive have same endings when ending in -d or -t (always the case for weak past).
				addit("1s", "e")
				addit("3s", "e")
				if not ends_in_dt then
					addit("2s", "st")
					addit("2p", "t")
				end
				addit("2s", "est")
				addit("2p", "et")
			end

			-- Both pasts, as well as past subjunctive, have same endings in 1p and 3p.
			addit("1p", "en")
			addit("3p", "en")
		end

	-- Do the basic forms
	doadd(slot_pref, "")
	-- Also do the subordinate clause forms if any alternants have a prefix.
	if base.any_pre_pref then
		doadd("subc_" .. slot_pref, base.pre_pref)
	end
end


local conjs = {}
local conjprops = {}

conjs["strong"] = function(base)
	add_present(base)
	add_past_or_subii(base, "pret_", base.parts.past, "strong")
	add_past_or_subii(base, "subii_", base.parts.past_sub or base.parts.past)
end


conjs["weak"] = function(base)
	add_present(base)
	...
end


local function add_composed_forms(base)
	local forms = base.forms

	local linked_infs = iut.map_forms(base.forms.infinitive, function(form) return "[[" .. form .. "]]" end)
	local linked_pps = iut.map_forms(base.forms.perf_part, function(form) return "[[" .. form .. "]]" end)
	local linked_pps_haben = iut.map_forms(base.forms.perf_part, function(form) return "[[" .. form .. "]] [[haben]]" end)
	local linked_pps_sein = iut.map_forms(base.forms.perf_part, function(form) return "[[" .. form .. "]] [[sein]]" end)

	local function add_composed(tense_mood, persnum, auxforms, participles)
		local pers_auxforms = auxforms[persnum]
		if type(pers_auxforms) ~= "table" then
			pers_auxforms = {pers_auxforms}
		end
		for _, pers_auxform in ipairs(pers_auxforms) do
			add(base, tense_mood .. "_" .. persnum, "[[" .. pers_auxform .. "]] ", participles)
		end
	end

	local function add_composed_perf(tense_mood, persnum, haben_auxforms, sein_auxforms, haben_pps, sein_pps)
		if base.aux == "h" or base.aux == "hs" or base.aux == "sh" then
			add_composed(tense_mood, persnum, haben_auxforms, haben_pps)
		end
		if base.aux == "s" or base.aux == "hs" or base.aux == "sh" then
			add_composed(tense_mood, persnum, sein_auxforms, sein_pps)
		end
	end

	for persnum, _ in pairs(all_persons_numbers) do
		add_composed_perf("perf_ind", persnum, haben_forms["ind"], sein_forms["ind"], linked_pps, linked_pps)
		add_composed_perf("perf_sub", persnum, haben_forms["subi"], sein_forms["subi"], linked_pps, linked_pps)
		add_composed_perf("plup_ind", persnum, haben_forms["pret"], sein_forms["pret"], linked_pps, linked_pps)
		add_composed_perf("plup_sub", persnum, haben_forms["subii"], sein_forms["subii"], linked_pps, linked_pps)
		for _, mood in ipairs({"ind", "subi", "subii"}) do
			add_composed("futi_" .. mood, persnum, werden_forms[mood], linked_infs)
			add_composed_perf("futii_" .. mood, persnum, werden_forms[mood], werden_forms[mood], linked_pps_haben, linked_pps_sein)
		end
	end

	add(base, "futi_inf", linked_infs, " [[werden]]")
	if base.aux == "h" or base.aux == "hs" or base.aux == "sh" then
		add(base, "futii_inf", linked_infs, " [[haben]] [[werden]]")
	end
	if base.aux == "s" or base.aux == "hs" or base.aux == "sh" then
		add(base, "futii_inf", linked_infs," [[sein]] [[werden]]")
	end
end


local function add_subii_footnotes(base)
	local subii_footnotes = {past_subjunctive_footnote}
	for slot, forms in pairs(base) do
		if slot:find("subii") then
			local footnoted_forms = {}
			for _, form in ipairs(forms) do
				form = m_table.shallowcopy(form)
				form.footnotes = iut.combine_footnotes(form.footnotes, subii_footnotes)
				table.insert(footnoted_forms, form)
			end
			forms[slot] = footnoted_forms
		end
	end
end


local function conjugate_verb(base)
	if not conjs[base.conj] then
		error("Internal error: Unrecognized conjugation type '" .. base.conj .. "'")
	end
	conjs[base.conj](base)
	add_composed_forms(base)
	add_subii_footnotes(base)
end


local function strip_spaces(text)
	return text:gsub("^%s*(.-)%s*", "%1")
end


local function parse_indicator_spec(angle_bracket_spec)
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

	local function fetch_specs(comma_separated_group)
		if not comma_separated_group then
			return {{}}
		end
		local specs = {}
		
		local colon_separated_groups = iut.split_alternating_runs(comma_separated_group, ":")
		for _, colon_separated_group in ipairs(colon_separated_groups) do
			local form = colon_separated_group[1]
			table.insert(specs, {form = form, footnotes = fetch_footnotes(colon_separated_group)})
		end
		return specs
	end

	local inside = angle_bracket_spec:match("^<(.*)>$")
	assert(inside)
	local segments = iut.parse_balanced_segment_run(inside, "[", "]")
	local dot_separated_groups = iut.split_alternating_runs(segments, "%.")
	for i, dot_separated_group in ipairs(dot_separated_groups) do
		-- FIXME
		local comma_separated_groups = iut.split_alternating_runs(dot_separated_group, "%s*[,#]%s*", "preserve splitchar")
		if comma_separated_groups[1][1] == "haben" or comma_separated_groups[1][1] == "sein" then
			-- FIXME, handle auxiliaries, including with footnotes
		elseif #comma_separated_groups > 1 then
			-- principal parts specified
			if base.parts then
				error("Can't specify principal parts twice: " .. angle_bracket_spec)
			end
			local parts = {}
			assert(#comma_separated_groups[2] == 1)
			local past_index
			local first_separator = strip_spaces(comma_separated_groups[2][1])
			if first_separator == "#" then
				-- present 3rd singular specified
				parts.pres_3sg = fetch_specs(comma_separated_groups[1])
				past_index = 3
			else
				past_index = 1
			end
			parts.past = fetch_specs(comma_separated_groups[past_index])
			if #comma_separated_groups < past_index + 2 then
				error("Missing past participle spec: " .. angle_bracket_spec)
			end
			assert(#comma_separated_groups[past_index + 1] == 1)
			if strip_spaces(comma_separated_groups[past_index + 1][1]) ~= "," then
				error("Only first separator can be a #: " .. angle_bracket_spec)
			end
			parts.pp = fetch_specs(comma_separated_groups[past_index + 2])
			if #comma_separated_groups > past_index + 2 then
				assert(#comma_separated_groups[past_index + 3] == 1)
				if strip_spaces(comma_separated_groups[past_index + 3][1]) ~= "," then
					error("Only first separator can be a #: " .. angle_bracket_spec)
				end
				parts.past_sub = fetch_specs(comma_separated_groups[past_index + 4])
				if #comma_separated_groups > past_index + 4 then
					error("Too many specs given: " .. angle_bracket_spec)
				end
			end
			base.parts = parts
		else
			-- FIXME
		end
	end
	-- FIXME
end


-- Normalize all lemmas, splitting off separable prefixes and substituting the pagename for blank lemmas.
local function normalize_all_lemmas(alternant_multiword_spec)
	local any_pre_pref
	iut.map_word_specs(alternant_multiword_spec, function(base)
		if base.lemma == "" then
			base.lemma = PAGENAME
		end
		base.orig_lemma = base.lemma
		base.orig_lemma_no_links = m_links.remove_links(base.lemma)
		base.lemma = base.orig_lemma_no_links
		base.pre_pref, base.post_pref = "", ""
		local prefix, verb = base.lemma:match("^(.*)_(.-)$")
		if prefix then
			prefix = prefix:gsub("_", " ") -- in case of multiple preceding words
			base.pre_pref = base.pre_pref .. prefix .. " "
			base.post_pref = base.post_pref .. " " .. prefix
		else
			verb = base.lemma
		end
		prefix, verb = verb:match("^(.*)%.(.-)$")
		if prefix then
			-- There may be multiple separable prefixes (e.g. [[wiedergutmachen]], ich mache wieder gut)
			base.pre_pref = base.pre_pref .. prefix:gsub("%.", "")
			base.post_pref = base.post_pref .. " " .. prefix:gsub("%.", " ")
		end
		if base.pre_pref then
			any_pre_pref = true
		end
	end)
	if any_pre_pref then
		iut.map_word_specs(alternant_multiword_spec, function(base)
			base.any_pre_pref = true
		end)
	end
end


local function add_categories(base)
	local cats = {}
	for slot, _ in pairs(all_verb_slots) do
		local forms = base.forms[slot]
		local must_break = false
		if forms then
			for _, form in ipairs(forms) do
				if not form.form:find("%[%[") then
					local title = mw.title.new(form.form)
					if title and not title.exists then
						table.insert(cats, "German verbs with red links in their inflection tables")
						must_break = true
						break
					end
				end
			end
		end
		if must_break then
			break
		end
	end

	base.categories = cats
end


local function link_term(term)
	return m_links.full_link { lang = lang, term = term }
end


local function show_forms(base)
	local lemmas = base.forms.infinitive
	base.lemmas = lemmas -- save for later use in make_table()
	local linked_pronouns = {}
	for persnum, pronoun in pairs(pronouns) do
		linked_pronouns[persnum] = link_term(pronoun)
	end
	dass = link_term("dass") .. " "
	local function add_pronouns(slot, link)
		local persnum = slot:match("^imp_(2[sp])$")
		if persnum then
			link = link .. " (" .. linked_pronouns[persnum] .. ")"
		else
			persnum = slot:match("^.*_([123][sp])$")
			if persnum then
				link = linked_pronouns[persnum] .. " " .. link
			end
			if slot:find("^subc_") then
				link = dass .. link
			end
		end
		return link
	end
	local function join_spans(slot, spans)
		return table.concat(spans, "<br />")
	end
	local props = {
		lang = lang,
		transform_link = add_pronouns,
		join_spans = join_spans,
	}
	iut.show_forms(base.forms, lemmas, verb_slots_basic, props)
	base.footnote_basic = base.forms.footnote
	iut.show_forms(base.forms, lemmas, verb_slots_subordinate_clause, props)
	base.footnote_subordinate_clause = base.forms.footnote
	iut.show_forms(base.forms, lemmas, verb_slots_composed, props)
	base.footnote_composed = base.forms.footnote
end


local notes_template = [=[
<div style="width:100%;text-align:left;background:#d9ebff">
<div style="display:inline-block;text-align:left;padding-left:1em;padding-right:1em">
{footnote}
</div></div>
]=]

local zu_infinitive_table = [=[
|-
! colspan="2" style="background:#d0d0d0" | zu-infinitive
| colspan="4" | {zu_infinitive}
]=]

local basic_table = [=[
<div class="NavFrame" style="">
<div class="NavHead" style="">Conjugation of {pagename}</div>
<div class="NavContent">
{\op}| border="1px solid #000000" style="border-collapse:collapse; background:#fafafa; text-align:center; width:100%" class="inflection-table"
|-
! colspan="2" style="background:#d0d0d0" | <span title="Infinitiv">infinitive</span>
| colspan="4" | {infinitive}
|-
! colspan="2" style="background:#d0d0d0" | <span title="Partizip I (Partizip Präsens)">present participle</span>
| colspan="4" | {pres_part}
|-
! colspan="2" style="background:#d0d0d0" | <span title="Partizip II (Partizip Perfekt)">past participle</span>
| colspan="4" | {perf_part}
{zu_infinitive_table}|-
! colspan="2" style="background:#d0d0d0" | <span title="Hilfsverb">auxiliary</span>
| colspan="4" | {aux}
|-
| style="background:#a0ade3" |
! colspan="2" style="background:#a0ade3" | <span title="Indikativ">indicative</span>
| style="background:#a0ade3" |
! colspan="2" style="background:#a0ade3" | <span title="Konjunktiv">subjunctive</span>
|-
! rowspan="3" style="background:#c0cfe4; width:7em" | <span title="Präsens">present</span>
| {pres_1s}
| {pres_1p}
! rowspan="3" style="background:#c0cfe4; width:7em" | <span title="Konjunktiv I (Konjunktiv Präsens)">i</span>
| {subi_1s}
| {subi_1p}
|-
| {pres_2s}
| {pres_2p}
| {subi_2s}
| {subi_2p}
|-
| {pres_3s}
| {pres_3p}
| {subi_3s}
| {subi_3p}
|-
| colspan="6" style="background:#d5d5d5; height: .25em" | 
|-
! rowspan="3" style="background:#c0cfe4" | <span title="Präteritum">preterite</span>
| {pret_1s}
| {pret_1p}
! rowspan="3" style="background:#c0cfe4" | <span title="Konjunktiv II (Konjunktiv Präteritum)">ii</span>
| {subii_1s}
| {subii_1p}
|-
| {pret_2s}
| {pret_2p}
| {subii_2s}
| {subii_2p}
|-
| {pret_3s}
| {pret_3p}
| {subii_3s}
| {subii_3p}
|-
| colspan="6" style="background:#d5d5d5; height: .25em" | 
|-
! style="background:#c0cfe4" | <span title="Imperativ">imperative</span>
| {imp_2s}
| {imp_2p}
| colspan="3" style="background:#e0e0e0" |
|{\cl}{notes_clause}</div></div>
]=]

local subordinate_clause_table = [=[
<div class="NavFrame" style="">
<div class="NavHead" style="">Subordinate-clause forms of {pagename}</div>
<div class="NavContent">
{\op}| border="1px solid #000000" style="border-collapse:collapse; background:#fafafa; text-align:center; width:100%" class="inflection-table"
|-
| style="background:#a0ade3" |
! colspan="2" style="background:#a0ade3" | <span title="Indikativ">indicative</span>
| style="background:#a0ade3" |
! colspan="2" style="background:#a0ade3" | <span title="Konjunktiv">subjunctive</span>
|-
! rowspan="3" style="background:#c0cfe4; width:7em" | <span title="Präsens">present</span>
| {subc_pres_1s}
| {subc_pres_1p}
! rowspan="3" style="background:#c0cfe4; width:7em" | <span title="Konjunktiv I (Konjunktiv Präsens)">i</span> 
| {subc_subi_1s}
| {subc_subi_1p}
|-
| {subc_pres_2s}
| {subc_pres_2p}
| {subc_subi_2s}
| {subc_subi_2p}
|-
| {subc_pres_3s}
| {subc_pres_3p}
| {subc_subi_3s}
| {subc_subi_3p}
|-
| colspan="6" style="background:#d5d5d5; height: .25em" | 
|-
! rowspan="3" style="background:#c0cfe4" | <span title="Präteritum">preterite</span>
| {subc_pret_1s}
| {subc_pret_1p}
! rowspan="3" style="background:#c0cfe4" | <span title="Konjunktiv II (Konjunktiv Präteritum)">ii</span>
| {subc_subii_1s}
| {subc_subii_1p}
|-
| {subc_pret_2s}
| {subc_pret_2p}
| {subc_subii_2s}
| {subc_subii_2p}
|-
| {subc_pret_3s}
| {subc_pret_3p}
| {subc_subii_3s}
| {subc_subii_3p}
|{\cl}{notes_clause}</div></div>
]=]

local composed_table = [=[
<div class="NavFrame" style="">
<div class="NavHead" style="">Composed forms of {pagename}</div>
<div class="NavContent">
{\op}| border="1px solid #000000" style="border-collapse:collapse; background:#fafafa; text-align:center; width:100%" class="inflection-table"
|-
! colspan="6" style="background:#99cc99" | <span title="Perfekt">perfect</span>
|-
! rowspan="3" style="background:#cfedcc; width:7em" | <span title="Indikativ">indicative</span>
| {perf_ind_1s}
| {perf_ind_1p}
! rowspan="3" style="background:#cfedcc; width:7em" | <span title="Konjunktiv">subjunctive</span>
| {perf_sub_1s}
| {perf_sub_1p}
|-
| {perf_ind_2s}
| {perf_ind_2p}
| {perf_sub_2s}
| {perf_sub_2p}
|-
| {perf_ind_3s}
| {perf_ind_3p}
| {perf_sub_3s}
| {perf_sub_3p}
|-
! colspan="6" style="background:#99CC99" | <span title="Plusquamperfekt">pluperfect</span>
|-
! rowspan="3" style="background:#cfedcc" | <span title="Indikativ">indicative</span>
| {plup_ind_1s}
| {plup_ind_1p}
! rowspan="3" style="background:#cfedcc" | <span title="Konjunktiv">subjunctive</span>
| {plup_sub_1s}
| {plup_sub_1p}
|-
| {plup_ind_2s}
| {plup_ind_2p}
| {plup_sub_2s}
| {plup_sub_2p}
|-
| {plup_ind_3s}
| {plup_ind_3p}
| {plup_sub_3s}
| {plup_sub_3p}
|-
! colspan="6" style="background:#9999DF" | <span title="Futur I">future i</span>
|-
! rowspan="3" style="background:#ccccff" | <span title="Infinitiv">infinitive</span>
| rowspan="3" colspan="2" | {futi_inf}
! rowspan="3" style="background:#ccccff" | <span title="Konjunktiv I (Konjunktiv Präsens)">subjunctive i</span>
| {futi_subi_1s}
| {futi_subi_1p}
|-
| {futi_subi_2s}
| {futi_subi_2p}
|-
| {futi_subi_3s}
| {futi_subi_3p}
|-
! colspan="6" style="background:#d5d5d5; height: .25em" |
|-
! rowspan="3" style="background:#ccccff" | <span title="Indikativ">indicative</span>
| {futi_ind_1s}
| {futi_ind_1p}
! rowspan="3" style="background:#ccccff" | <span title="Konjunktiv II (Konjunktiv Präteritum)">subjunctive ii</span>
| {futi_subii_1s}
| {futi_subii_1p}
|-
| {futi_ind_2s}
| {futi_ind_2p}
| {futi_subii_2s}
| {futi_subii_2p}
|-
| {futi_ind_3s}
| {futi_ind_3p}
| {futi_subii_3s}
| {futi_subii_3p}
|-
! colspan="6" style="background:#9999DF" | <span title="Futur II">future ii</span>
|-
! rowspan="3" style="background:#ccccff" | <span title="Infinitiv">infinitive</span>
| rowspan="3" colspan="2" | {futii_inf}
! rowspan="3" style="background:#ccccff" | <span title="Konjunktiv I (Konjunktiv Präsens)">subjunctive i</span>
| {futii_subi_1s}
| {futii_subi_1p}
|-
| {futii_subi_2s}
| {futii_subi_2p}
|-
| {futii_subi_3s}
| {futii_subi_3p}
|-
! colspan="6" style="background:#d5d5d5; height: .25em" |
|-
! rowspan="3" style="background:#ccccff" | <span title="Indikativ">indicative</span>
| {futii_ind_1s}
| {futii_ind_1p}
! rowspan="3" style="background:#ccccff" | <span title="Konjunktiv II (Konjunktiv Präteritum)">subjunctive ii</span>
| {futii_subii_1s}
| {futii_subii_1p}
|-
| {futii_ind_2s}
| {futii_ind_2p}
| {futii_subii_2s}
| {futii_subii_2p}
|-
| {futii_ind_3s}
| {futii_ind_3p}
| {futii_subii_3s}
| {futii_subii_3p}
|{\cl}{notes_clause}</div></div>]=]


local function make_table(base)
	local forms = base.forms

	forms.pagename = m_links.full_link({lang = lang, term = base.lemmas[1].form}, "term", "allow self link")
	forms.aux =
		base.aux == "h" and link_term("haben") or
		base.aux == "s" and link_term("sein") or
		(base.aux == "hs" or base.aux == "sh") and link_term("haben") .. " or " .. link_term("sein") or
		error("Unrecognized auxiliary aux=" .. (base.aux or "nil"))

	-- Maybe format the subordinate clause table.
	local formatted_subordinate_clause_table
	if forms.subc_pres_1s ~= "—" then
		forms.zu_infinitive_table = m_string_utilities.format(zu_infinitive_table, forms)
		forms.footnote = base.footnote_subordinate_clause
		forms.notes_clause = forms.footnote ~= "" and m_string_utilities.format(notes_template, forms) or ""
		formatted_subordinate_clause_table = m_string_utilities.format(subordinate_clause_table, forms)
	else
		forms.zu_infinitive_table = ""
		formatted_subordinate_clause_table = ""
	end

	-- Format the basic table.
	forms.footnote = base.footnote_basic
	forms.notes_clause = forms.footnote ~= "" and m_string_utilities.format(notes_template, forms) or ""
	local formatted_basic_table = m_string_utilities.format(basic_table, forms)

	-- Format the composed table.
	forms.footnote = base.footnote_composed
	forms.notes_clause = forms.footnote ~= "" and m_string_utilities.format(notes_template, forms) or ""
	local formatted_composed_table = m_string_utilities.format(composed_table, forms)

	-- Paste them together.
	return formatted_basic_table .. formatted_subordinate_clause_table .. formatted_composed_table
end


-- Externally callable function to parse and conjugate a verb given user-specified arguments.
-- Return value is WORD_SPEC, an object where the conjugated forms are in `WORD_SPEC.forms`
-- for each slot. If there are no values for a slot, the slot key will be missing. The value
-- for a given slot is a list of objects {form=FORM, footnotes=FOOTNOTES}.
function export.do_generate_forms(parent_args, pos, from_headword, def)
	local params = {
		[1] = {},
	}

	if from_headword then
		params["lemma"] = {list = true}
		params["id"] = {}
	end

	local args = m_para.process(parent_args, params)
	local PAGENAME = mw.title.getCurrentTitle().text

	if not args[1] then
		if PAGENAME == "de-conj" then
			args[1] = def or "aus.fahren<fährt#fuhr,gefahren,führe.haben,sein>"
		else
			args[1] = PAGENAME
			-- If pagename has spaces in it, add links around each word
			if args[1]:find(" ") then
				args[1] = "[[" .. args[1]:gsub(" ", "]] [[") .. "]]"
			end
		end
	end
	local parse_props = {
		parse_indicator_spec = parse_indicator_spec,
		lang = lang,
		allow_default_indicator = true,
		allow_blank_lemma = true,
	}
	local alternant_multiword_spec = iut.parse_inflected_text(args[1], parse_props)
	alternant_multiword_spec.pos = pos or "verbs"
	alternant_multiword_spec.args = args
	normalize_all_lemmas(alternant_multiword_spec)
	detect_all_indicator_specs(alternant_multiword_spec)
	local inflect_props = {
		slot_table = all_verb_slots,
		lang = lang,
		inflect_word_spec = conjugate_verb,
		-- We add links around the generated verbal forms rather than allow the entire multiword
		-- expression to be a link, so ensure that user-specified links get included as well.
		include_user_specified_links = true,
	}
	iut.inflect_multiword_or_alternant_multiword_spec(alternant_multiword_spec, inflect_props)
	compute_categories_and_annotation(alternant_multiword_spec)
	return alternant_multiword_spec
end


local numbered_params = {
	-- required params
	[1] = "infinitive",
	[2] = "pres_part",
	[3] = "perf_part",
	[4] = "aux",
	[5] = "pres_1s",
	[6] = "pres_2s",
	[7] = "pres_3s",
	[8] = "pres_1p",
	[9] = "pres_2p",
	[10] = "pres_3p",
	[11] = "pret_1s",
	[12] = "pret_2s",
	[13] = "pret_3s",
	[14] = "pret_1p",
	[15] = "pret_2p",
	[16] = "pret_3p",
	[17] = "subi_1s",
	[18] = "subi_2s",
	[19] = "subi_3s",
	[20] = "subi_1p",
	[21] = "subi_2p",
	[22] = "subi_3p",
	[23] = "subii_1s",
	[24] = "subii_2s",
	[25] = "subii_3s",
	[26] = "subii_1p",
	[27] = "subii_2p",
	[28] = "subii_3p",
	[29] = "imp_2s",
	[30] = "imp_2p",
	-- [31] formerly the 2nd variant of imp_2s; now no longer allowed (use comma-separated 29=)
	-- [32] formerly indicated whether the 2nd variant of imp_2s was present
	-- optional params
	[33] = "subc_pres_1s",
	[34] = "subc_pres_2s",
	[35] = "subc_pres_3s",
	[36] = "subc_pres_1p",
	[37] = "subc_pres_2p",
	[38] = "subc_pres_3p",
	[39] = "subc_pret_1s",
	[40] = "subc_pret_2s",
	[41] = "subc_pret_3s",
	[42] = "subc_pret_1p",
	[43] = "subc_pret_2p",
	[44] = "subc_pret_3p",
	[45] = "subc_subi_1s",
	[46] = "subc_subi_2s",
	[47] = "subc_subi_3s",
	[48] = "subc_subi_1p",
	[49] = "subc_subi_2p",
	[50] = "subc_subi_3p",
	[51] = "subc_subii_1s",
	[52] = "subc_subii_2s",
	[53] = "subc_subii_3s",
	[54] = "subc_subii_1p",
	[55] = "subc_subii_2p",
	[56] = "subc_subii_3p",
	[57] = "zu_infinitive",
}

local max_required_param = 30



-- Externally callable function to parse and conjugate a verb where all forms are given manually.
-- Return value is WORD_SPEC, an object where the conjugated forms are in `WORD_SPEC.forms`
-- for each slot. If there are no values for a slot, the slot key will be missing. The value
-- for a given slot is a list of objects {form=FORM, footnotes=FOOTNOTES}.
function export.do_generate_forms_manual(parent_args)
	local params = {
	}
	for paramnum, _ in pairs(numbered_params) do
		params[paramnum] = {required = paramnum <= max_required_param}
	end

	local args = require("Module:parameters").process(parent_args, params)

	local base = {
		forms = {},
		manual = true,
	}
	for paramnum, _ in pairs(numbered_params) do
		local argval = args[paramnum]
		if argval and argval ~= "-" then
			local split_vals = rsplit(argval, "%s*,%s*")
			if paramnum == 4 then
				base.aux = argval
			end
			for _, val in ipairs(split_vals) do
				-- FIXME! This won't work with commas or brackets in footnotes.
				-- To fix this, use functions from [[Module:inflection utilities]].
				local form, footnote = val:match("^(.-)%s*(%[[^%]%[]-%])$")
				local formobj
				if form then
					formobj = {form = form, footnotes = {footnote}}
				else
					formobj = {form = val}
				end
				iut.insert_form(base.forms, numbered_params[paramnum], formobj)
			end
		end
	end

	add_composed_forms(base)
	add_subii_footnotes(base)
	add_categories(base)
	return base
end


-- Entry point for {{de-conj-table}}. Template-callable function to parse and conjugate a verb given
-- manually-specified inflections and generate a displayable table of the conjugated forms.
function export.show_manual(frame)
	local parent_args = frame:getParent().args
	local base = export.do_generate_forms_manual(parent_args)
	show_forms(base)
	return make_table(base) .. require("Module:utilities").format_categories(base.categories, lang)
end


--[=[ not until we have automatic conjugation.

-- Concatenate all forms of all slots into a single string of the form
-- "SLOT=FORM,FORM,...|SLOT=FORM,FORM,...|...". Embedded pipe symbols (as might occur
-- in embedded links) are converted to <!>. If INCLUDE_PROPS is given, also include
-- additional properties (currently, none). This is for use by bots.
local function concat_forms(base, include_props)
	local ins_text = {}
	for slot, _ in pairs(all_verb_slots) do
		local formtext = iut.concat_forms_in_slot(base.forms[slot])
		if formtext then
			table.insert(ins_text, slot .. "=" .. formtext)
		end
	end
	return table.concat(ins_text, "|")
end

-- Template-callable function to parse and conjugate a verb given user-specified arguments and return
-- the forms as a string "SLOT=FORM,FORM,...|SLOT=FORM,FORM,...|...". Embedded pipe symbols (as might
-- occur in embedded links) are converted to <!>. If |include_props=1 is given, also include
-- additional properties (currently, only "|aspect=ASPECT"). This is for use by bots.
function export.generate_forms(frame)
	local include_props = frame.args["include_props"]
	local parent_args = frame:getParent().args
	local base = export.do_generate_forms(parent_args)
	return concat_forms(base, include_props)
end

]=]

return export
