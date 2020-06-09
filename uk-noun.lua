local export = {}


--[=[

Authorship: Ben Wing <benwing2>

]=]

--[=[

TERMINOLOGY:

-- "slot" = A particular combination of case/number.
	 Example slot names for nouns are "gen_" (genitive singular) and
	 "voc_p" (vocative plural). Each slot is filled with zero or more forms.

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
local com = require("Module:User:Benwing2/uk-common")
local m_uk_translit = require("Module:User:Benwing2/uk-translit")

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
local usub = mw.ustring.sub
local uupper = mw.ustring.upper

local AC = u(0x0301) -- acute =  ́
local DOTUNDER = u(0x0323) -- dotunder =  ̣
local accents = AC .. DOTUNDER
local accents_c = "[" .. accents .. "]"


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


local output_noun_slots = {
	nom_s = "nom|s",
	gen_s = "gen|s",
	dat_s = "dat|s",
	acc_s = "acc|s",
	ins_s = "ins|s",
	loc_s = "loc|s",
	voc_s = "voc|s",
	nom_p = "nom|p",
	gen_p = "gen|p",
	dat_p = "dat|p",
	acc_p = "acc|p",
	ins_p = "ins|p",
	loc_p = "loc|p",
	voc_p = "voc|p",
}


local input_params_to_slots_both = {
	[1] = "nom_s",
	[2] = "nom_p",
	[3] = "gen_s",
	[4] = "gen_p",
	[5] = "dat_s",
	[6] = "dat_p",
	[7] = "acc_s",
	[8] = "acc_p",
	[9] = "ins_s",
	[10] = "ins_p",
	[11] = "loc_s",
	[12] = "loc_p",
	[13] = "voc_s",
	[14] = "voc_p",
}


local input_params_to_slots_sg = {
	[1] = "nom_s",
	[2] = "gen_s",
	[3] = "dat_s",
	[4] = "acc_s",
	[5] = "ins_s",
	[6] = "loc_s",
	[7] = "voc_s",
}


local input_params_to_slots_pl = {
	[1] = "nom_p",
	[2] = "gen_p",
	[3] = "dat_p",
	[4] = "acc_p",
	[5] = "ins_p",
	[6] = "loc_p",
	[7] = "voc_p",
}


local cases = {
	nom = true,
	gen = true,
	dat = true,
	acc = true,
	ins = true,
	loc = true,
	voc = true,
}


local accented_cases = {
	["nóm"] = "nom",
	["gén"] = "gen",
	["dát"] = "dat",
	["ácc"] = "acc",
	["íns"] = "ins",
	["lóc"] = "loc",
	["vóc"] = "voc",
}


-- Stress patterns indicate where the stress goes for forms of each possible slot.
-- "-" means stem stress, "+" means ending stress. The field "stress" indicates
-- where to put the stem stress if the lemma doesn't include it. It applies primarily
-- to types d and f and variants of them. For example, lemma множина́ (type d) has
-- plural множи́ни (last-syllable stress), but lemma борода́ (type d') has plural
-- бо́роди (first-syllable stress).
local stress_patterns = {}

stress_patterns["a"] = {
	nom_s="-", gen_s="-", dat_s="-", acc_s="-", ins_s="-", loc_s="-", voc_s="-",
	nom_p="-", gen_p="-", dat_p="-",            ins_p="-", loc_p="-", voc_p="-",
	stress = nil,
}

stress_patterns["b"] = {
	nom_s="+", gen_s="+", dat_s="+", acc_s="+", ins_s="+", loc_s="+", voc_s="+",
	nom_p="+", gen_p="+", dat_p="+",            ins_p="+", loc_p="+", voc_p="+",
	stress = "last",
}

stress_patterns["b'"] = {
	nom_s="+", gen_s="+", dat_s="+", acc_s="+", ins_s="-", loc_s="+", voc_s="+",
	nom_p="+", gen_p="+", dat_p="+",            ins_p="+", loc_p="+", voc_p="+",
	stress = "last",
}

stress_patterns["c"] = {
	nom_s="-", gen_s="-", dat_s="-", acc_s="-", ins_s="-", loc_s="-", voc_s="-",
	nom_p="+", gen_p="+", dat_p="+",            ins_p="+", loc_p="+", voc_p="-",
	stress = nil,
}

stress_patterns["d"] = {
	nom_s="+", gen_s="+", dat_s="+", acc_s="+", ins_s="+", loc_s="+", voc_s="+",
	nom_p="-", gen_p="-", dat_p="-",            ins_p="-", loc_p="-", voc_p="+",
	stress = "last",
}

stress_patterns["d'"] = {
	nom_s="+", gen_s="+", dat_s="+", acc_s="-", ins_s="+", loc_s="+", voc_s="+",
	nom_p="-", gen_p="-", dat_p="-",            ins_p="-", loc_p="-", voc_p="+",
	stress = "first",
}

stress_patterns["e"] = {
	nom_s="-", gen_s="-", dat_s="-", acc_s="-", ins_s="-", loc_s="-", voc_s="-",
	nom_p="-", gen_p="+", dat_p="+",            ins_p="+", loc_p="+", voc_p="-",
	stress = nil,
}

stress_patterns["f"] = {
	nom_s="+", gen_s="+", dat_s="+", acc_s="+", ins_s="+", loc_s="+", voc_s="+",
	nom_p="-", gen_p="+", dat_p="+",            ins_p="+", loc_p="+", voc_p="+",
	stress = "first",
}

stress_patterns["f'"] = {
	nom_s="+", gen_s="+", dat_s="+", acc_s="-", ins_s="+", loc_s="+", voc_s="+",
	nom_p="-", gen_p="+", dat_p="+",            ins_p="+", loc_p="+", voc_p="+",
	stress = "first",
}

stress_patterns["f''"] = {
	nom_s="+", gen_s="+", dat_s="+", acc_s="+", ins_s="-", loc_s="+", voc_s="+",
	nom_p="-", gen_p="+", dat_p="+",            ins_p="+", loc_p="+", voc_p="+",
	stress = "first",
}


local function combine_footnotes(notes1, notes2)
	if not notes1 and not notes2 then
		return nil
	end
	if not notes1 then
		return notes2
	end
	if not notes2 then
		return notes1
	end
	local combined = m_table.shallowcopy(notes1)
	for _, note in ipairs(notes2) do
		m_table.insertIfNot(combined, note)
	end
	return combined
end


-- Maybe modify the stem and/or ending in certain special cases:
-- 1. Final -е in vocative singular triggers first palatalization of the stem and causes
--    accent retraction.
-- 2. Final -і in dative/locative singular triggers second palatalization.
local function apply_special_cases(slot, stem, ending)
	if slot == "voc_s" and rfind(ending, "^е" .. accents_c .. "?$") then
		stem = com.apply_first_palatalization(stem)
		if ending == "е" then
			ending = ending .. DOTUNDER
		end
	elseif (slot == "dat_s" or slot == "loc_s") and rfind(ending, "^і" .. accents_c .. "?$") then
		stem = com.apply_second_palatalization(stem)
	end
	return stem, ending
end


local function add(base, slot, stress, endings, footnotes)
	if not endings then
		return
	end
	footnotes = combine_footnotes(base.footnotes, footnotes)
	if type(endings) == "string" then
		endings = {endings}
	end
	local slot_is_plural = rfind(slot, "_p$")
	local stress_for_slot
	local stress_pattern_set = stress_patterns[stress.stress]
	if not stress_pattern_set then
		error("Internal error: Unrecognized stress pattern " .. stress.stress)
	end
	local stress_for_slot
	if slot == "acc_p" then
		-- This only applies when an override of acc_p is given.
		if base.animacy == "in" then
			stress_for_slot = stress_pattern_set.nom_p
		elseif base.animacy == "pr" then
			stress_for_slot = stress_pattern_set.gen_p
		elseif stress_pattern_set.nom_p == stress_pattern_set.gen_p then
			stress_for_slot = stress_pattern_set.nom_p
		else
			for _, ending in ipairs(endings) do
				if not rfind(ending, AC) and not rfind(ending, DOTUNDER) then
					error("For animacy 'anml' and stress pattern " .. stress.stress .. ", must explicitly specify stress of override")
				end
			end
			-- All endings have explicit stress, so it doesn't matter.
			stress_for_slot = stress_pattern_set.nom_p
		end
	else
		stress_for_slot = stress_pattern_set[slot]
		if not stress_for_slot then
			error("Internal error: Don't know stress for pattern " .. stress.stress .. ", slot " .. slot)
		end
	end
	for _, ending in ipairs(endings) do
		local stem
		if rfind(ending, "^ь?" .. com.vowel_c) then
			stem = slot_is_plural and stress.pl_vowel_stem or stress.vowel_stem
		else
			stem = slot_is_plural and stress.pl_nonvowel_stem or stress.nonvowel_stem
		end
		stem, ending = apply_special_cases(slot, stem, ending)
		if rfind(ending, DOTUNDER) then
			-- DOTUNDER indicates stem stress in all cases
			ending = rsub(ending, DOTUNDER, "")
		elseif stress_for_slot == "+" then
			ending = com.maybe_stress_initial_syllable(ending)
		end
		ending = com.generate_form(ending, footnotes)
		iut.add_forms(base.this_forms, slot, stem, ending, com.combine_stem_ending)
	end
end


local function process_slot_overrides(base, do_slot)
	for slot, overrides in pairs(base.overrides) do
		if do_slot(slot) then
			base.this_forms[slot] = nil
			local slot_is_plural = rfind(slot, "_p$")
			for _, override in ipairs(overrides) do
				for _, value in ipairs(override.values) do
					local form = value.form
					local combined_notes = combine_footnotes(base.footnotes, value.footnotes)
					if override.full then
						if form:find("~") then
							local stem
							local ending = rsub(form, ".*~+", "")
							if rfind(ending, "^ь?" .. com.vowel_c) then
								stem = slot_is_plural and stress.pl_vowel_stem or stress.vowel_stem
							else
								stem = slot_is_plural and stress.pl_nonvowel_stem or stress.nonvowel_stem
							end
							if com.is_stressed(ending) then
								stem = com.remove_stress(stem)
							end
							form = rsub(value, "~~~", com.apply_second_palatalization(stem))
							form = rsub(value, "~~", com.apply_first_palatalization(stem))
							form = rsub(value, "~", stem)
						end
						iut.insert_form(base.this_forms, slot, {form = form, footnotes = combined_notes})
					else
						if override.stemstressed then
							-- Signal not to add a stress to the ending even if the stress pattern
							-- calls for it.
							form = form .. DOTUNDER
						end
						for _, stress in ipairs(base.stresses) do
							add(base, slot, stress, form, combined_notes)
						end
					end
				end
			end
		end
	end
end


local function add_decl(base, stress,
	nom_s, gen_s, dat_s, acc_s, ins_s, loc_s, voc_s,
	nom_p, gen_p, dat_p, ins_p, loc_p, footnotes
)
	add(base, "nom_s", stress, nom_s, footnotes)
	add(base, "gen_s", stress, gen_s, footnotes)
	add(base, "dat_s", stress, dat_s, footnotes)
	add(base, "acc_s", stress, acc_s, footnotes)
	add(base, "ins_s", stress, ins_s, footnotes)
	add(base, "loc_s", stress, loc_s, footnotes)
	add(base, "voc_s", stress, voc_s, footnotes)
	add(base, "nom_p", stress, nom_p, footnotes)
	add(base, "gen_p", stress, gen_p, footnotes)
	add(base, "dat_p", stress, dat_p, footnotes)
	add(base, "ins_p", stress, ins_p, footnotes)
	add(base, "loc_p", stress, loc_p, footnotes)
end


local function handle_derived_slots_and_overrides(base)
	local function is_non_derived_slot(slot)
		return slot ~= "voc_p" and slot ~= "acc_s" and slot ~= "acc_p"
	end

	local function is_derived_slot(slot)
		return not is_non_derived_slot(slot)
	end

	-- Handle overrides for the non-derived slots. Do this before generating the derived
	-- slots so overrides of the source slots (e.g. nom_p) propagate to the derived slots.
	process_slot_overrides(base, is_non_derived_slot)

	-- Generate the remaining slots that are derived from other slots.
	iut.insert_forms(base.this_forms, "voc_p", base.this_forms["nom_p"])
	if rfind(base.decl, "%-m$") then
		iut.insert_forms(base.this_forms, "acc_s", base.this_forms[base.animacy == "in" and "nom_s" or "gen_s"])
	elseif rfind(base.decl, "%-n$") then
		iut.insert_forms(base.this_forms, "acc_s", base.this_forms["nom_s"])
	end
	if base.animacy == "in" or base.animacy == "anml" then
		iut.insert_forms(base.this_forms, "acc_p", base.this_forms["nom_p"])
	end
	if base.animacy == "pr" or base.animacy == "anml" then
		iut.insert_forms(base.this_forms, "acc_p", base.this_forms["gen_p"])
	end

	-- Handle overrides for derived slots, to allow them to be overridden.
	process_slot_overrides(base, is_derived_slot)

	for slot, _ in pairs(output_noun_slots) do
		iut.insert_forms(base.forms, slot, base.this_forms[slot])
	end
end


local decls = {}
local declprops = {}


decls["hard-m"] = function(base, stress)
	local velar = rfind(stress.vowel_stem, com.velar_c .. "$")
	local gen_s = base.number == "sg" and "у" or "а" -- may be overridden
	local loc_s =
		-- these conditions seem weird but it's what I observed
		velar and (base.animacy ~= "in" or stress.reducible) and {"ові", "у"} or
		velar and "у" or
		base.animacy ~= "in" and {"ові", "і"} or
		base.number == "sg" and {"у", "і"} or
		"і"
	local voc_s =
		-- these conditions also seem weird but it's what I observed
		velar and base.animacy == "anml" and stress.stress == "b" and "е" or
		velar and "у" or
		"е"
	local gen_p = base.remove_in and "" or "ів"
	add_decl(base, stress, "", gen_s, {"ові", "у"}, nil, "ом", loc_s, voc_s,
		base.plsoft and "і" or "и", gen_p, base.plsoft and "ям" or "ам",
		base.plsoft and "ями" or "ами", base.plsoft and "ях" or "ах")
end

declprops["hard-m"] = {desc = "hard masc-form"}


decls["semisoft-m"] = function(base, stress)
	local gen_s = base.number == "sg" and "у" or "а" -- may be overridden
	local loc_s = base.animacy ~= "in" and {"еві", "у", "і"} or {"у", "і"}
	-- FIXME: Should vocative singular in -у be end-stressed if reducible, parallel
	-- to soft nouns? I don't have any examples of reducible nouns in -ч, ш or щ.
	local voc_s = rfind(stress.vowel_stem, "ж$") and "е" or "у̣" -- dot underneath у
	add_decl(base, stress, "", gen_s, {"еві", "у"}, nil, "ем", loc_s, voc_s,
		"і", "ів", "ам", "ами", "ах")
end

declprops["semisoft-m"] = {desc = "semisoft masc-form"}


decls["soft-m"] = function(base, stress)
	local nom_s = rfind(stress.nonvowel_stem, "р$") and "" or "ь"
	local gen_s = base.number == "sg" and "ю" or "я" -- may be overridden
	local loc_s = base.animacy ~= "in" and {"еві", "ю", "і"} or {"ю", "і"}
	-- More weird conditions: vocative singular in accent b is end-stressed if
	-- reducible or ending in -інь (from Proto-Slavic nouns in -y), stem-stressed
	-- otherwise.
	local voc_s = (stress.reducible or rfind(stress.vowel_stem, "і́?нь$")) and "ю" or "ю̣"
	add_decl(base, stress, nom_s, gen_s, {"еві", "ю"}, nil, "ем", loc_s, voc_s,
		"і", "ів", "ям", "ями", "ях")
end

declprops["soft-m"] = {desc = "soft masc-form"}


decls["j-m"] = function(base, stress)
	local gen_s = base.number == "sg" and "ю" or "я" -- may be overridden
	local loc_s = base.animacy ~= "in" and {"єві", "ю", "ї"} or {"ю", "ї"}
	-- As with soft nouns, vocative singular in accent b is end-stressed if
	-- reducible, stem-stressed otherwise.
	local voc_s = stress.reducible and "ю" or "ю̣"
	add_decl(base, stress, "й", gen_s, {"єві", "ю"}, nil, "єм", loc_s, voc_s,
		"ї", "їв", "ям", "ями", "ях")
end

declprops["j-m"] = {desc = "j-stem masc-form"}


decls["hard-f"] = function(base, stress)
	add_decl(base, stress, "а", "и", "і", "у", "ою", "і", "о̣",
		"и", "", "ам", "ами", "ах")
end

declprops["hard-f"] = {desc = "hard fem-form"}


decls["semisoft-f"] = function(base, stress)
	add_decl(base, stress, "а", "і", "і", "у", "ею", "і", "е",
		"і", "", "ам", "ами", "ах")
end

declprops["semisoft-f"] = {desc = "semisoft fem-form"}


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


local function parse_override(segments)
	local retval = {values = {}}
	local part = segments[1]
	local case = usub(part, 1, 3)
	if cases[case] then
		-- ok
	elseif accented_cases[case] then
		case = accented_cases[case]
		retval.stemstressed = true
	else
		error("Internal error: unrecognized case in override: '" .. table.concat(segments) .. "'")
	end
	local rest = usub(part, 4)
	local slot
	if rfind(rest, "^pl") then
		rest = rsub(rest, "^pl", "")
		slot = case .. "_p"
	else
		slot = case .. "_s"
	end
	if rfind(rest, "^:") then
		retval.full = true
		rest = rsub(rest, "^:", "")
	end
	segments[1] = rest
	local colon_separated_groups = iut.split_alternating_runs(segments, ":")
	for i, colon_separated_group in ipairs(colon_separated_groups) do
		local value = {}
		local form = colon_separated_group[1]
		if form == "" then
			error("Use - to indicate an empty ending for slot '" .. slot .. "': '" .. table.concat(segments .. "'"))
		elseif form == "-" then
			value.form = ""
		else
			value.form = m_uk_translit.reverse_tr(form)
		end
		value.footnotes = fetch_footnotes(colon_separated_group)
		table.insert(retval.values, value)
	end
	return slot, retval
end


local function parse_indicator_spec(angle_bracket_spec)
	local inside = rmatch(angle_bracket_spec, "^<(.*)>$")
	assert(inside)
	local base = {overrides = {}, this_forms = {}}
	if inside ~= "" then
		local segments = iut.parse_balanced_segment_run(inside, "[", "]")
		local dot_separated_groups = iut.split_alternating_runs(segments, "%.")
		for i, dot_separated_group in ipairs(dot_separated_groups) do
			local part = dot_separated_group[1]
			local case_prefix = usub(part, 1, 3)
			if cases[case_prefix] or accented_cases[case_prefix] then
				local slot, override = parse_override(dot_separated_group)
				if base.overrides[slot] then
					table.insert(base.overrides[slot], override)
				else
					base.overrides[slot] = {override}
				end
			elseif part == "" then
				if #dot_separated_group == 1 then
					error("Blank indicator: '" .. inside .. "'")
				end
				base.footnotes = fetch_footnotes(dot_separated_group)
			elseif #dot_separated_group > 1 then
				error("Footnotes only allowed with slot overrides or by themselves: '" .. table.concat(dot_separated_group) .. "'")
			elseif part == "M" or part == "MF" or part == "F" or part == "N" then
				if base.explicit_gender then
					error("Can't specify gender twice: '" .. inside .. "'")
				end
				base.explicit_gender = part
			elseif part == "sg" or part == "pl" then
				if base.number then
					error("Can't specify number twice: '" .. inside .. "'")
				end
				base.number = part
			elseif part == "pr" or part == "anml" then
				if base.animacy then
					error("Can't specify animacy twice: '" .. inside .. "'")
				end
				base.animacy = part
			elseif part == "i" or part == "io" or part == "ie" then
				if base.ialt then
					error("Can't specify і-alternation indicator twice: '" .. inside .. "'")
				end
				base.ialt = part
			elseif rfind(part, "^[a-f]'*%*?$") or rfind(part, "^[a-f]'*%*?,") or
				rfind(part, "^%*$") or rfind(part, "^%*,") then
				if base.stresses then 
					error("Can't specify stress pattern indicator twice: '" .. inside .. "'")
				end
				local patterns = rsplit(part, ",")
				for i, pattern in ipairs(patterns) do
					local pat, reducible = rsubb(pattern, "%*", "")
					if pat == "" then
						pat = nil
					end
					if pat and not stress_patterns[pat] then
						error("Unrecognized stress pattern '" .. pat .. "': '" .. inside .. "'")
					end
					patterns[i] = {stress = pat, reducible = reducible}
				end
				base.stresses = patterns
			elseif part == "soft" or part == "semisoft" then
				if base.rtype then
					error("Can't specify 'р' type ('soft' or 'semisoft') more than once: '" .. inside .. "'")
				end
				base.rtype = part
			elseif part == "t" or part == "en" then
				if base.rtype then
					error("Can't specify neuter indicator ('t' or 'en') more than once: '" .. inside .. "'")
				end
				base.neutertype = part
			elseif part == "plsoft" then
				if base.plsoft then
					error("Can't specify 'plsoft' twice: '" .. inside .. "'")
				end
				base.plsoft = true
			elseif part == "in" then
				if base.remove_in then
					error("Can't specify 'in' twice: '" .. inside .. "'")
				end
				base.remove_in = true
			elseif rfind(part, "^stem:") then
				if base.stem then
					error("Can't specify stem twice: '" .. inside .. "'")
				end
				base.stem = rsub(part, "^stem:", "")
			elseif rfind(part, "^plstem:") then
				if base.plstem then
					error("Can't specify plural stem twice: '" .. inside .. "'")
				end
				base.plstem = rsub(part, "^plstem:", "")
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


local function apply_vowel_alternation(base, stem)
	if base.ialt == "io" or base.ialt == "ie" then
		local modstem = rsub(stem, "(.)і(́?" .. com.cons_c .. "*)$",
			function(pre, post)
				if base.ialt == "io" and (pre == "л" or pre == "Л") then
					-- ко́лір, gen sg. ко́льору; вертолі́т, gen sg. вертольо́та
					return pre .. "ьо" .. post
				elseif base.ialt == "io" then
					return pre .. "о" .. post
				else
					return pre .. "е" .. post
				end
			end
		)
		if modstem == stem then
			error("Indicator '" .. base.ialt .. "' can't be applied because stem '" .. stem .. "' doesn't have an і as its last vowel")
		end
		return modstem
	elseif base.ialt == "i" then
		local modstem = rsub(stem, "ь?[ое](́?" .. com.cons_c .. "*)$", "і%1")
		if modstem == stem then
			error("Indicator 'i' can't be applied because stem '" .. stem .. "' doesn't have an о or е as its last vowel")
		end
		return modstem
	else
		return stem
	end
end


local function add_stress_for_pattern(stress, stem)
	local where_stress = stress_patterns[stress.stress].stress
	if where_stress == "last" then
		return com.maybe_stress_final_syllable(stem)
	elseif where_stress == "first" then
		return com.maybe_stress_initial_syllable(stem)
	elseif not com.is_stressed(stem) then
		error("Something wrong: Stress pattern " .. stress.stress .. " but stem '" .. stem .. "' doesn't have stress")
	else
		return stem
	end
end


local function detect_indicator_spec(base)
	-- Set default values.
	base.number = base.number or "both"
	base.animacy = base.animacy or "in"
	base.gender = base.explicit_gender

	-- Check for indicators that don't make sense given the context.
	if base.rtype and not rfind(base.lemma, "р$") then
		error("'р' type indicator '" .. base.rtype .. "' can only be specified with a lemma ending in -р")
	end
	if base.remove_in and not rfind(base.lemma, "и́?н$") then
		error("'in' can only be specified with a lemma ending in -ин")
	end
	if base.neutertype then
		if not rfind(base.lemma, "я́?$") then
			error("Neuter-type indicator '" .. base.neutertype .. "' can only be specified with a lemma ending in -я")
		end
		if base.neutertype == "en" and not rfind(base.lemma, "м'я́?$") then
			error("Neuter-type indicator 'en' can only be specified with a lemma ending in -м'я")
		end
		if base.gender and base.gender ~= "N" then
			error("Neuter-type indicator '" .. base.neutertype .. "' can't specified with non-neuter gender indicator '" .. base.gender .. "'")
		end
		base.gender = "N"
	end

	-- Determine declension
	local stem, ac
	while true do
		stem = rmatch(base.lemma, "^(.*)ь$")
		if stem then
			if not base.gender then
				if rfind(base.lemma, "[еє]́?ць$") then
					base.gender = "M"
				elseif rfind(base.lemma, "тель$") then
					base.gender = "M"
				elseif rfind(base.lemma, "ість$") then
					base.gender = "F"
				else
					error("For lemma ending in -ь other than -ець/-єць/-тель/-ість, gender M or F must be given")
				end
			end
			if base.gender == "N" or base.gender == "MF" then
				error("For lemma ending in -ь, gender " .. base.gender .. " not allowed")
			elseif base.gender == "M" then
				base.decl = "soft-m"
			else
				base.decl = "third-f"
			end
			base.nonvowel_stem = stem
			break
		end
		stem = rmatch(base.lemma, "^(.*)й$")
		if stem then
			base.decl = "j-m"
			base.gender = base.gender or "M"
			base.nonvowel_stem = stem
			base.stem_for_reduce = base.lemma
			break
		end
		stem = rmatch(base.lemma, "^(.*" .. com.hushing_c .. ")$")
		if stem then
			if base.gender == "N" or base.gender == "MF" then
				error("For lemma ending in a hushing consonant, gender " .. base.gender .. " not allowed")
			elseif base.gender == "F" then
				base.decl = "third-f"
			else
				base.gender = "M"
				base.decl = "semisoft-m"
			end
			base.nonvowel_stem = stem
			break
		end
		stem, ac = rmatch(base.lemma, "^(.*" .. com.hushing_c .. ")а(́?)$")
		if stem then
			base.decl = "semisoft-f"
			base.gender = base.gender or "F"
			base.vowel_stem = stem
			break
		end
		stem, ac = rmatch(base.lemma, "^(.*)а(́?)$")
		if stem then
			base.decl = "hard-f"
			base.gender = base.gender or "F"
			base.vowel_stem = stem
			break
		end
		stem, ac = rmatch(base.lemma, "^(.*)я(́?)$")
		if stem then
			if base.gender == "M" or base.gender == "F" or base.gender == "MF" then
				base.decl = "soft-f"
			elseif base.gender == "N" then
				base.decl = "fourth-n"
			elseif rfind(stem, "'я$") or rfind(stem, "(.)%1я$") then
				base.decl = "fourth-n"
				base.gender = "N"
			else
				base.decl = "soft-f"
				base.gender = "F"
			end
			base.vowel_stem = stem
			break
		end
		stem, ac = rmatch(base.lemma, "^(.*)о(́?)$")
		if stem then
			if base.gender == "M" then
				base.decl = "o-m"
			elseif base.gender == "F" or base.gender == "MF" then
				error("For lemma ending in -о, gender " .. base.gender .. " not allowed")
			else
				base.decl = "hard-n"
				base.gender = "N"
			end
			base.vowel_stem = stem
		end
		stem, ac = rmatch(base.lemma, "^(.*)е(́?)$")
		if stem then
			base.decl = "soft-n"
			base.gender = base.gender or "N"
			base.vowel_stem = stem
		end
		stem = rmatch(base.lemma, "^(.*" .. com.cons_c .. ")$")
		if stem then
			if base.gender == "N" or base.gender == "MF" then
				error("For lemma ending in a consonant, gender " .. base.gender .. " not allowed")
			elseif base.gender == "F" then
				base.decl = "third-f"
			elseif base.rtype == "soft" then
				base.decl = "soft-m"
			elseif base.rtype == "semisoft" then
				base.decl = "semisoft-m"
			else
				base.decl = "hard-m"
			end
			base.gender = base.gender or "M"
			base.nonvowel_stem = stem
			break
		end
		error("Unrecognized ending for lemma: '" .. base.lemma .. "'")
	end

	-- Determine stress and stems
	if not base.stresses then
		if ac == AC then
			base.stresses = {{stress = "d", reducible = false}}
		else
			base.stresses = {{stress = "a", reducible = false}}
		end
	end
	if base.stem then
		base.stem = com.add_monosyllabic_stress(base.stem)
	end
	if base.plstem then
		base.plstem = com.add_monosyllabic_stress(base.plstem)
	end
	for _, stress in ipairs(base.stresses) do
		local function dereduce(stem)
			local dereduced_stem = com.dereduce(stem, stress_patterns[stress.stress].gen_p == "+")
			if not dereduced_stem then
				error("Unable to dereduce stem '" .. stem .. "'")
			end
			if rfind(base.lemma, "я́?$") then
				dereduced_stem = dereduced_stem .. "ь"
			end
			return dereduced_stem
		end
		if not stress.stress then
			if ac == AC then
				stress.stress = "d"
			elseif stress.reducible and rfind(base.lemma, "[еоєі]́" .. com.cons_c .. "ь?$") then
				-- reducible with stress on the reducible vowel
				stress.stress = "b"
			else
				stress.stress = "a"
			end
		end
		if stress.stress ~= "b" then
			if base.stem and com.needs_accents(base.stem) then
				error("Explicit stem needs an accent with stress pattern " .. stress.stress .. ": '" .. base.stem .. "'")
			end
			if base.plstem and com.needs_accents(base.plstem) then
				error("Explicit plural stem needs an accent with stress pattern " .. stress.stress .. ": '" .. base.plstem .. "'")
			end
		end
		if base.vowel_stem then
			if ac == "AC" and stress_patterns[stress.stress].nom_sg ~= "+" then
				error("Stress pattern " .. stress.stress .. " requires a stem-stressed lemma, not end-stressed: '" .. base.lemma .. "'")
			elseif ac ~= "AC" and stress_patterns[stress.stress].nom_sg == "+" then
				error("Stress pattern " .. stress.stress .. " requires an end-stressed lemma, not stem-stressed: '" .. base.lemma .. "'")
			end
			if base.stem then
				error("Can't specify 'stem:' with lemma ending in a vowel")
			end
			stress.vowel_stem = base.vowel_stem
			-- Apply vowel alternation first in cases like війна́ -> во́єн;
			-- apply_vowel_alternation() will throw an error if the vowel being
			-- modified isn't the last vowel in the stem.
			stress.nonvowel_stem = apply_vowel_alternation(base, base.vowel_stem) 
			if stress.reducible then
				stress.nonvowel_stem = dereduce(stress.nonvowel_stem)
			end
		else
			stress.nonvowel_stem = base.nonvowel_stem
			if base.stem then
				stress.vowel_stem = base.stem
			elseif stress.reducible then
				local stem_to_reduce = base.stem_for_reduce or base.nonvowel_stem
				stress.vowel_stem = com.reduce(stem_to_reduce)
				if not stress.vowel_stem then
					error("Unable to reduce stem '" .. stem_to_reduce .. "'")
				end
			else
				stress.vowel_stem = base.nonvowel_stem
			end
			stress.vowel_stem = apply_vowel_alternation(base, stress.vowel_stem)
		end
		if base.plstem then
			stress.pl_vowel_stem = base.plstem
			if base.reducible then
				stress.pl_nonvowel_stem = dereduce(base.plstem)
			else
				stress.pl_nonvowel_stem = base.plstem
			end
		elseif base.remove_in then
			stress.pl_vowel_stem = com.maybe_stress_final_syllable(rsub(stress.vowel_stem, "и́?н$", ""))
			stress.pl_nonvowel_stem = stress.pl_vowel_stem
		else
			stress.pl_vowel_stem = stress.vowel_stem
			stress.pl_nonvowel_stem = stress.nonvowel_stem
		end
		stress.vowel_stem = add_stress_for_pattern(stress, stress.vowel_stem)
		stress.nonvowel_stem = add_stress_for_pattern(stress, stress.nonvowel_stem)
		stress.pl_vowel_stem = add_stress_for_pattern(stress, stress.pl_vowel_stem)
		stress.pl_nonvowel_stem = add_stress_for_pattern(stress, stress.pl_nonvowel_stem)
	end
end


local function detect_all_indicator_specs(alternant_spec)
	for _, base in ipairs(alternant_spec.alternants) do
		detect_indicator_spec(base)
		if not alternant_spec.number then
			alternant_spec.number = base.number
		elseif alternant_spec.number ~= base.number then
			alternant_spec.number = "both"
		end
	end
end


local function parse_word_spec(segments)
	local indicator_spec
	if #segments ~= 3 or segments[3] ~= "" then
		error("Noun spec must be of the form 'LEMMA<SPECS>': '" .. table.concat(segments) .. "'")
	else
		indicator_spec = segments[2]
	end
	local lemma = segments[1]
	local base = parse_indicator_spec(indicator_spec)
	base.lemma = lemma
	return base
end


-- Parse an alternant, e.g. "((ру́син<pr>,руси́н<b.pr>))". The return value is a table of the form
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


local function process_manual_overrides(forms, args, number, unknown_stress)
	local params_to_slots_map =
		number == "sg" and input_params_to_slots_sg or
		number == "pl" and input_params_to_slots_pl or
		input_params_to_slots_both
	for param, slot in pairs(params_to_slots_map) do
		if args[param] then
			forms[slot] = nil
			if args[param] ~= "-" and args[param] ~= "—" then
				for _, form in ipairs(rsplit(args[param], "%s*,%s*")) do
					if com.is_multi_stressed(form) then
						error("Multi-stressed form '" .. form .. "' in slot '" .. slot .. "' not allowed; use singly-stressed forms separated by commas")
					end
					if not unknown_stress and not rfind(form, "^%-") and com.needs_accents(form) then
						error("Stress required in multisyllabic form '" .. form .. "' in slot '" .. slot .. "'; if stress is truly unknown, use unknown_stress=1")
					end
					iut.insert_form(forms, slot, {form=form})
				end
			end
		end
	end
end


local function add_categories(alternant_spec)
	local cats = {}
	local function insert(cattype)
		table.insert(cats, "Ukrainian " .. cattype)
	end
	if alternant_spec.number == "sg" then
		insert("uncountable nouns")
	elseif alternant_spec.number == "pl" then
		insert("pluralia tantum")
	end
	alternant_spec.categories = cats
end


local function show_forms(alternant_spec)
	local lemmas = {}
	if alternant_spec.forms.nom_s then
		for _, nom_s in ipairs(alternant_spec.forms.nom_s) do
			table.insert(lemmas, com.remove_monosyllabic_stress(nom_s.form))
		end
	elseif alternant_spec.forms.nom_p then
		for _, nom_p in ipairs(alternant_spec.forms.nom_p) do
			table.insert(lemmas, com.remove_monosyllabic_stress(nom_p.form))
		end
	end
	com.show_forms(alternant_spec.forms, lemmas, alternant_spec.footnotes, output_noun_slots)
end


local function make_table(alternant_spec)
	local forms = alternant_spec.forms

	local table_spec_both = [=[
<div class="NavFrame" style="display: inline-block;min-width: 45em">
<div class="NavHead" style="background:#eff7ff" >{title}{annotation}</div>
<div class="NavContent">
{\op}| style="background:#F9F9F9;text-align:center;min-width:45em" class="inflection-table"
|-
! style="width:33%;background:#d9ebff" | 
! style="background:#d9ebff" | singular
! style="background:#d9ebff" | plural
|-
!style="background:#eff7ff"|nominative
| {nom_s}
| {nom_p}
|-
!style="background:#eff7ff"|genitive
| {gen_s}
| {gen_p}
|-
!style="background:#eff7ff"|dative
| {dat_s}
| {dat_p}
|-
!style="background:#eff7ff"|accusative
| {acc_s}
| {acc_p}
|-
!style="background:#eff7ff"|instrumental
| {ins_s}
| {ins_p}
|-
!style="background:#eff7ff"|locative
| {loc_s}
| {loc_p}
|-
!style="background:#eff7ff"|vocative
| {voc_s}
| {voc_p}
|{\cl}{notes_clause}</div></div>]=]

	local table_spec_sg = [=[
<div class="NavFrame" style="width:30em">
<div class="NavHead" style="background:#eff7ff">{title}{annotation}</div>
<div class="NavContent">
{\op}| style="background:#F9F9F9;text-align:center;width:30em" class="inflection-table"
|-
! style="width:33%;background:#d9ebff" | 
! style="background:#d9ebff" | singular
|-
!style="background:#eff7ff"|nominative
| {nom_s}
|-
!style="background:#eff7ff"|genitive
| {gen_s}
|-
!style="background:#eff7ff"|dative
| {dat_s}
|-
!style="background:#eff7ff"|accusative
| {acc_s}
|-
!style="background:#eff7ff"|instrumental
| {ins_s}
|-
!style="background:#eff7ff"|locative
| {loc_s}
|-
!style="background:#eff7ff"|vocative
| {voc_s}
|{\cl}{notes_clause}</div></div>]=]

	local table_spec_pl = [=[
<div class="NavFrame" style="width:30em">
<div class="NavHead" style="background:#eff7ff">{title}{annotation}</div>
<div class="NavContent">
{\op}| style="background:#F9F9F9;text-align:center;width:30em" class="inflection-table"
|-
! style="width:33%;background:#d9ebff" | 
! style="background:#d9ebff" | plural
|-
!style="background:#eff7ff"|nominative
| {nom_p}
|-
!style="background:#eff7ff"|genitive
| {gen_p}
|-
!style="background:#eff7ff"|dative
| {dat_p}
|-
!style="background:#eff7ff"|accusative
| {acc_p}
|-
!style="background:#eff7ff"|instrumental
| {ins_p}
|-
!style="background:#eff7ff"|locative
| {loc_p}
|-
!style="background:#eff7ff"|vocative
| {voc_p}
|{\cl}{notes_clause}</div></div>]=]

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

	local annotation
	if alternant_spec.manual then
		annotation = alternant_spec.number == "sg" and "sg-only" or
			alternant_spec.number == "pl" and "pl-only" or
			""
	else
		local annparts = {}
		local animacies = {}
		local decldescs = {}
		local patterns = {}
		local reducible = nil
		for _, base in ipairs(alternant_spec.alternants) do
			if base.animacy == "in" then
				m_table.insertIfNot(animacies, "inan")
			elseif base.animacy == "anml" then
				m_table.insertIfNot(animacies, "animal")
			else
				assert(base.animacy == "pr")
				m_table.insertIfNot(animacies, "pers")
			end
			m_table.insertIfNot(decldescs, declprops[base.decl].desc)
			for _, stress in ipairs(base.stresses) do
				if reducible == nil then
					reducible = stress.reducible
				elseif reducible ~= stress.reducible then
					reducible = "mixed"
				end
				m_table.insertIfNot(patterns, stress.stress)
			end
		end
		table.insert(annparts, table.concat(animacies, "/"))
		if alternant_spec.number ~= "both" then
			table.insert(annparts, alternant_spec.number == "sg" and "sg-only" or "pl-only")
		end
		table.insert(annparts, table.concat(decldescs, " // "))
		table.insert(annparts, "accent-" .. table.concat(patterns, "/"))
		if reducible == "mixed" then
			table.insert(annparts, "mixed-reduc")
		elseif reducible then
			table.insert(annparts, "reduc")
		end
		annotation = table.concat(annparts, " ")
	end
	if annotation == "" then
		forms.annotation = ""
	else
		forms.annotation = " (<span style=\"font-size: smaller;\">" .. annotation .. "</span>)"
	end

	local table_spec =
		alternant_spec.number == "sg" and table_spec_sg or
		alternant_spec.number == "pl" and table_spec_pl or
		table_spec_both
	forms.notes_clause = forms.footnote ~= "" and
		m_string_utilities.format(notes_template, forms) or ""
	return m_string_utilities.format(table_spec, forms)
end


-- Externally callable function to parse and decline a noun given user-specified arguments.
-- Return value is WORD_SPEC, an object where the declined forms are in `WORD_SPEC.forms`
-- for each slot. If there are no values for a slot, the slot key will be missing. The value
-- for a given slot is a list of objects {form=FORM, footnotes=FOOTNOTES}.
function export.do_generate_forms(parent_args, pos, from_headword, def)
	local params = {
		[1] = {required = true, default = "віз<c.io>"},
		footnote = {list = true},
		title = {},
	}

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
		for _, stress in ipairs(base.stresses) do
			if not decls[base.decl] then
				error("Internal error: Unrecognized declension type '" .. base.decl .. "'")
			end
			decls[base.decl](base, stress)
		end
		handle_derived_slots_and_overrides(base)
	end
	add_categories(alternant_spec)
	return alternant_spec
end


-- Externally callable function to parse and decline a noun where all forms
-- are given manually. Return value is WORD_SPEC, an object where the declined
-- forms are in `WORD_SPEC.forms` for each slot. If there are no values for a
-- slot, the slot key will be missing. The value for a given slot is a list of
-- objects {form=FORM, footnotes=FOOTNOTES}.
function export.do_generate_forms_manual(parent_args, number, pos, from_headword, def)
	if number ~= "sg" and number ~= "pl" and number ~= "both" then
		error("Internal error: number (arg 1) must be 'sg', 'pl' or 'both': '" .. number .. "'")
	end

	local params = {
		footnote = {list = true},
		title = {},
		unknown_stress = {type = "boolean"},
	}
	if number == "both" then
		params[1] = {required = true, default = "жук"}
		params[2] = {required = true, default = "жуки́"}
		params[3] = {required = true, default = "жука́"}
		params[4] = {required = true, default = "жукі́в"}
		params[5] = {required = true, default = "жуко́ві, жуку́"}
		params[6] = {required = true, default = "жука́м"}
		params[7] = {required = true, default = "жука́"}
		params[8] = {required = true, default = "жуки́, жукі́в"}
		params[9] = {required = true, default = "жуко́м"}
		params[10] = {required = true, default = "жука́ми"}
		params[11] = {required = true, default = "жуко́ві, жуку́"}
		params[12] = {required = true, default = "жука́х"}
		params[13] = {required = true, default = "жу́че"}
		params[14] = {required = true, default = "жуки́"}
	elseif number == "sg" then
		params[1] = {required = true, default = "лист"}
		params[2] = {required = true, default = "ли́сту"}
		params[3] = {required = true, default = "ли́сту, ли́стові"}
		params[4] = {required = true, default = "лист"}
		params[5] = {required = true, default = "ли́стом"}
		params[6] = {required = true, default = "ли́сті, ли́сту"}
		params[7] = {required = true, default = "ли́сте"}
	else
		params[1] = {required = true, default = "две́рі"}
		params[2] = {required = true, default = "двере́й"}
		params[3] = {required = true, default = "две́рям"}
		params[4] = {required = true, default = "две́рі"}
		params[5] = {required = true, default = "дверми́, двери́ма"}
		params[6] = {required = true, default = "две́рях"}
		params[7] = {required = true, default = "две́рі"}
	end

	local args = m_para.process(parent_args, params)
	local alternant_spec = {
		title = args.title,
		footnotes = args.footnote,
		forms = {},
		number = number,
		manual = true,
	}
	process_overrides(alternant_spec.forms, args, alternant_spec.number, args.unknown_stress)
	add_categories(alternant_spec)
	return alternant_spec
end


-- Entry point for {{uk-ndecl}}. Template-callable function to parse and decline a noun given
-- user-specified arguments and generate a displayable table of the declined forms.
function export.show(frame)
	local parent_args = frame:getParent().args
	local alternant_spec = export.do_generate_forms(parent_args)
	show_forms(alternant_spec)
	return make_table(alternant_spec) .. require("Module:utilities").format_categories(alternant_spec.categories, lang)
end


-- Entry point for {{uk-decl-noun}}, {{uk-decl-noun-unc}} and {{uk-decl-noun-pl}}.
-- Template-callable function to parse and decline a noun given manually-specified inflections
-- and generate a displayable table of the declined forms.
function export.show_manual(frame)
	local iparams = {
		[1] = {required = true},
	}
	local iargs = m_para.process(frame.args, iparams)
	local parent_args = frame:getParent().args
	local alternant_spec = export.do_generate_forms_manual(parent_args, iargs[1])
	show_forms(alternant_spec)
	return make_table(alternant_spec) .. require("Module:utilities").format_categories(alternant_spec.categories, lang)
end


-- Concatenate all forms of all slots into a single string of the form
-- "SLOT=FORM,FORM,...|SLOT=FORM,FORM,...|...". Embedded pipe symbols (as might occur
-- in embedded links) are converted to <!>. If INCLUDE_PROPS is given, also include
-- additional properties (currently, none). This is for use by bots.
local function concat_forms(alternant_spec, include_props)
	local ins_text = {}
	for slot, _ in pairs(output_noun_slots) do
		local formtext = com.concat_forms_in_slot(alternant_spec.forms[slot])
		if formtext then
			table.insert(ins_text, slot .. "=" .. formtext)
		end
	end
	return table.concat(ins_text, "|")
end

-- Template-callable function to parse and decline a noun given user-specified arguments and return
-- the forms as a string "SLOT=FORM,FORM,...|SLOT=FORM,FORM,...|...". Embedded pipe symbols (as might
-- occur in embedded links) are converted to <!>. If |include_props=1 is given, also include
-- additional properties (currently, none). This is for use by bots.
function export.generate_forms(frame)
	local iparams = {
		[1] = {required = true},
	}
	local iargs = m_para.process(frame.args, iparams)
	local include_props = frame.args["include_props"]
	local parent_args = frame:getParent().args
	local alternant_spec = export.do_generate_forms(parent_args, iargs[1])
	return concat_forms(alternant_spec, include_props)
end


return export
