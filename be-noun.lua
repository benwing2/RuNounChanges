local export = {}


--[=[

Authorship: Ben Wing <benwing2>

]=]

--[=[

TERMINOLOGY:

-- "slot" = A particular combination of case/number.
	 Example slot names for nouns are "gen_" (genitive singular) and
	 "voc_p" (vocative plural). Each slot is filled with zero or more forms.

-- "form" = The declined Belarusian form representing the value of a given slot.

-- "lemma" = The dictionary form of a given Belarusian term. Generally the nominative
     masculine singular, but may occasionally be another form if the nominative
	 masculine singular is missing.
]=]

local lang = require("Module:languages").getByCode("be")
local m_table = require("Module:table")
local m_links = require("Module:links")
local m_string_utilities = require("Module:string utilities")
local iut = require("Module:inflection utilities")
local m_para = require("Module:parameters")
local com = require("Module:be-common")
local m_be_translit = require("Module:be-translit")

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
local ulower = mw.ustring.lower

local AC = u(0x0301) -- acute =  ́
local CFLEX = u(0x0302) -- circumflex =  ̂
local DOTABOVE = u(0x0307) -- dot above =  ̇
local accents = AC .. DOTABOVE
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
	count = "count|form",
}


local output_noun_slots_with_linked = m_table.shallowcopy(output_noun_slots)
output_noun_slots_with_linked["nom_s_linked"] = "nom|s"
output_noun_slots_with_linked["nom_p_linked"] = "nom|p"

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
	["count"] = "count",
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
	["count"] = "count",
}


local cases = {
	nom = true,
	gen = true,
	dat = true,
	acc = true,
	ins = true,
	loc = true,
	voc = true,
	count = true,
}


local accented_cases = {
	["nóm"] = "nom",
	["gén"] = "gen",
	["dát"] = "dat",
	["ácc"] = "acc",
	["íns"] = "ins",
	["lóc"] = "loc",
	["cóunt"] = "count",
}


-- Stress patterns indicate where the stress goes for forms of each possible slot.
-- "-" means stem stress, "+" means ending stress. The field "stress" indicates
-- where to put the stem stress if the lemma doesn't include it. It applies primarily
-- to types d and f and variants of them. For example, lemma галава́ (type d) has
-- plural гало́вы (last-syllable stress), but lemma старана́ (type f) has plural
-- сто́раны (first-syllable stress).
local stress_patterns = {}

stress_patterns["a"] = {
	nom_s="-", gen_s="-", dat_s="-", acc_s="-", ins_s="-", loc_s="-", count = "-",
	nom_p="-", gen_p="-", dat_p="-",            ins_p="-", loc_p="-",
	stress = nil,
}

stress_patterns["b"] = {
	nom_s="+", gen_s="+", dat_s="+", acc_s="+", ins_s="+", loc_s="+", count = "+",
	nom_p="+", gen_p="+", dat_p="+",            ins_p="+", loc_p="+",
	stress = "last",
}

stress_patterns["c"] = {
	nom_s="-", gen_s="-", dat_s="-", acc_s="-", ins_s="-", loc_s="-", count = "-",
	nom_p="+", gen_p="+", dat_p="+",            ins_p="+", loc_p="+",
	stress = nil,
}

stress_patterns["d"] = {
	nom_s="+", gen_s="+", dat_s="+", acc_s="+", ins_s="+", loc_s="+", count = "+",
	nom_p="-", gen_p="-", dat_p="-",            ins_p="-", loc_p="-",
	stress = "last",
}

stress_patterns["e"] = {
	nom_s="-", gen_s="-", dat_s="-", acc_s="-", ins_s="-", loc_s="-", count = "-",
	nom_p="-", gen_p="+", dat_p="+",            ins_p="+", loc_p="+",
	stress = nil,
}

stress_patterns["f"] = {
	nom_s="+", gen_s="+", dat_s="+", acc_s="+", ins_s="+", loc_s="+", count = "+",
	nom_p="-", gen_p="+", dat_p="+",            ins_p="+", loc_p="+",
	stress = "first",
}


local count_footnote_msg = "[used with the numbers 2, 3, 4 and higher numbers after 20 ending in 2, 3, and 4]"


-- Maybe modify the stem and/or ending in certain special cases:
-- * Final -е in dative/locative singular triggers second palatalization.
local function apply_special_cases(base, slot, stem, ending)
	if (slot == "dat_s" or slot == "loc_s") and rfind(ending, "^е" .. accents_c .. "?$") then
		stem = com.apply_second_palatalization(stem)
		if rfind(stem, "ц$") then
			-- Original к -> ц but this requires a hard ending. This ending is -э́ if stressed
			-- (e.g. дачка́ "daughter" dat/loc sg. дачцэ́, рака́ "river" dat/loc sg. рацэ́, same
			-- for рука́ "hand", шчака́ "cheek" etc.), but otherwise -ы (іго́лка "needle"
			-- dat/loc sg. іго́лцы, аве́чка "sheep" dat.loc sg. аве́чцы, etc.). For whatever
			-- reason this doesn't apply to originally hard endings, e.g. ігра́ "game"
			-- dat/log sg. ігры́.
			ending = ending == "е́" and "э́" or "ы"
		end
	end
	return stem, ending
end


local function skip_slot(number, slot)
	return number == "sg" and (slot == "count" or rfind(slot, "_p$")) or
		number == "pl" and (slot == "count" or rfind(slot, "_s$"))
end


local function add(base, slot, stress, endings, footnotes, explicit_stem)
	if not endings then
		return
	end
	if skip_slot(base.number, slot) then
		return
	end
	footnotes = iut.combine_footnotes(iut.combine_footnotes(base.footnotes, stress.footnotes), footnotes)
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
		if base.animacy == "inan" then
			stress_for_slot = stress_pattern_set.nom_p
		else
			stress_for_slot = stress_pattern_set.gen_p
		end
	else
		stress_for_slot = stress_pattern_set[slot]
		if not stress_for_slot then
			error("Internal error: Don't know stress for pattern " .. stress.stress .. ", slot " .. slot)
		end
	end
	for _, ending in ipairs(endings) do
		local stem
		if explicit_stem then
			stem = explicit_stem
		else
			if rfind(ending, "^ь?" .. com.vowel_c) then
				stem = slot_is_plural and stress.pl_vowel_stem or stress.vowel_stem
			else
				stem = slot_is_plural and stress.pl_nonvowel_stem or stress.nonvowel_stem
			end
		end
		
		-- If end stress is called for, add it to the ending if possible,
		-- otherwise if we're in the genitive plural, go ahead and stress the
		-- last syllable of the stem. This is required, for example, with
		-- старана́ "side" of type f, where the plural stem is сто́рон-. The nom pl
		-- calls for stem stress and you correctly get сто́раны after destressing.
		-- However, the gen pl calls for ending stress but is a null ending,
		-- so we need this extra logic to get the correct form старо́н rather than
		-- #сто́ран. Only do this for the genitive plural; otherwise we'll mess up
		-- e.g. the nom sg of ву́гал "angle, corner" and ву́зел "knot", which are of
		-- type b.
		local function accent_ending_or_stem_end()
			if rfind(ending, com.vowel_c) then
				ending = com.maybe_accent_initial_syllable(ending)
			elseif slot == "gen_p" then
				stem = com.remove_accents(stem)
				stem = com.maybe_accent_final_syllable(stem)
			end
		end
			
		if rfind(ending, DOTABOVE) then
			-- DOTABOVE indicates stem stress in all cases
			ending = rsub(ending, DOTABOVE, "")
		
		elseif slot == "gen_p" and stress.genpl_reversed then
			if stress_for_slot ~= "+" then
				accent_ending_or_stem_end()
			end
		elseif stress_for_slot == "+" then
			accent_ending_or_stem_end()
		end
		if com.is_nonsyllabic(stem) then
			-- If stem is nonsyllabic, the ending must receive stress.
			ending = com.maybe_accent_initial_syllable(ending)
		end
		stem, ending = apply_special_cases(base, slot, stem, ending)
		ending = iut.generate_form(ending, footnotes)
		iut.add_forms(base.forms, slot, stem, ending,
			com.combine_stem_ending_into_external_form)
	end
end


local function process_slot_overrides(base, do_slot)
	for slot, overrides in pairs(base.overrides) do
		if skip_slot(base.number, slot) then
			error("Override specified for invalid slot '" .. slot .. "' due to '" .. base.number .. "' number restriction")
		end
		if do_slot(slot) then
			base.forms[slot] = nil
			for _, override in ipairs(overrides) do
				for _, value in ipairs(override.values) do
					local form = value.form
					local combined_notes = iut.combine_footnotes(base.footnotes, value.footnotes)
					if override.full then
						if form ~= "" then
							iut.insert_form(base.forms, slot, {form = form, footnotes = combined_notes})
						end
					else
						if override.stemstressed then
							-- Signal not to add a stress to the ending even if the stress pattern
							-- calls for it.
							form = form .. DOTABOVE
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
	nom_s, gen_s, dat_s, acc_s, ins_s, loc_s, count,
	nom_p, gen_p, dat_p, ins_p, loc_p, footnotes
)
	add(base, "nom_s", stress, nom_s, footnotes)
	add(base, "gen_s", stress, gen_s, footnotes)
	add(base, "dat_s", stress, dat_s, footnotes)
	add(base, "acc_s", stress, acc_s, footnotes)
	add(base, "ins_s", stress, ins_s, footnotes)
	add(base, "loc_s", stress, loc_s, footnotes)
	local count_footnotes = {count_footnote_msg}
	add(base, "count", stress, count, iut.combine_footnotes(count_footnotes, footnotes))
	add(base, "nom_p", stress, nom_p, footnotes)
	add(base, "gen_p", stress, gen_p, footnotes)
	add(base, "dat_p", stress, dat_p, footnotes)
	add(base, "ins_p", stress, ins_p, footnotes)
	add(base, "loc_p", stress, loc_p, footnotes)
end


local function handle_derived_slots_and_overrides(base)
	local function is_non_derived_slot(slot)
		return slot ~= "acc_s" and slot ~= "acc_p"
	end

	local function is_derived_slot(slot)
		return not is_non_derived_slot(slot)
	end

	-- Handle overrides for the non-derived slots. Do this before generating the derived
	-- slots so overrides of the source slots (e.g. nom_p) propagate to the derived slots.
	process_slot_overrides(base, is_non_derived_slot)

	-- Generate the remaining slots that are derived from other slots.
	if not base.forms["acc_s"] and (rfind(base.decl, "%-m$") or base.gender == "M" and base.decl == "adj") then
		iut.insert_forms(base.forms, "acc_s", base.forms[base.animacy == "inan" and "nom_s" or "gen_s"])
	end
	if base.animacy == "inan" then
		iut.insert_forms(base.forms, "acc_p", base.forms["nom_p"])
	else
		assert(base.animacy == "pr" or base.animacy == "anml")
		iut.insert_forms(base.forms, "acc_p", base.forms["gen_p"])
	end

	-- Handle overrides for derived slots, to allow them to be overridden.
	process_slot_overrides(base, is_derived_slot)

	-- Compute linked versions of potential lemma slots, for use in {{be-noun}}.
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


local decls = {}
local declprops = {}

local function default_genitive_u(base)
	return base.number == "sg" and not rfind(base.lemma, "^%u")
end

local function add_soft_sign(nonvowel_stem)
	return com.ends_in_vowel(nonvowel_stem) and "й" or
	rfind(nonvowel_stem, "й$") and "" or "ь"
end

local function genitive_pl_ending(stress, default_ending, is_soft)
	local ending = stress.genpl_ending or default_ending
	if ending == "null" then
		return is_soft and add_soft_sign(stress.pl_nonvowel_stem) or ""
	elseif ending == "w" then
		-- circumflex above means it irregularly turns into -яў when unstressed
		return is_soft and "ё̂ў" or "оў"
	elseif ending == "j" then
		-- If is_soft, use -ей after ц, not -эй.
		return (com.ends_always_hard_or_ts(stress.pl_vowel_stem) and not is_soft) and "эй" or "ей"
	else
		error("Internal error: Unrecognized ending spec: " .. (ending or "nil"))
	end
end

-- Add standard plural endings. `normal_type` should be "soft" or "hard" indicating
-- the default type of endings, if not overridden by the codes 'plsoft' or 'plhard'.
-- `gen_p_type` indicates the default type of genitive plural endings ("null", "w" or "j").
-- `nom_p`, if given, overrides the normal nominative plural ending when the ending type
-- isn't changed by `plsoft` or `plhard`.
local function add_plural(base, stress, normal_type, gen_p_type, nom_p)
	local ending_type = base.plsoft and "soft" or base.plhard and "hard" or normal_type
	local normal_nom_p =
		(ending_type == "soft" or com.ends_in_velar(stress.pl_vowel_stem)) and "і" or "ы"
	nom_p = ending_type == normal_type and nom_p or normal_nom_p
	local gen_p = genitive_pl_ending(stress, gen_p_type, ending_type == "soft")
	if ending_type == "soft" then
		add_decl(base, stress, nil, nil, nil, nil, nil, nil, nil,
			nom_p, gen_p, "ям", "ямі", "ях")
	else
		add_decl(base, stress, nil, nil, nil, nil, nil, nil, nil,
			nom_p, gen_p, "ам", "амі", "ах")
	end
end

	
decls["hard-m"] = function(base, stress)
	local velar_sg = com.ends_in_velar(stress.vowel_stem)
	local always_hard_or_ts = com.ends_always_hard_or_ts(stress.vowel_stem)
	local gen_s = default_genitive_u(base) and "у" or "а" -- may be overridden
	local loc_s =
		velar_sg and "у" or
		always_hard_or_ts and base.animacy == "pr" and "у" or
		always_hard_or_ts and "ы" or
		"е"
	local count = velar_sg and "і" or "ы"
	add_decl(base, stress, "", gen_s, "у", nil, "ом", loc_s, count)
	local special_nom_p = 
		base.remove_in and com.ends_always_hard_or_ts(stress.pl_vowel_stem) and "ы" or
		base.remove_in and "е" or
		nil
	local gen_p_type = base.remove_in and "null" or "w"
	add_plural(base, stress, "hard", gen_p_type, special_nom_p)
end

local function get_stem_type(stress, short)
	if com.ends_in_velar(stress.vowel_stem) then
		return short and "velar" or "velar-stem"
	else
		return "hard"
	end
end

declprops["hard-m"] = {
	desc = function(base, stress)
		return get_stem_type(stress, "short") .. " masc-form"
	end,
	cat = function(base, stress)
		return get_stem_type(stress) .. " masculine-form"
	end
}


decls["soft-m"] = function(base, stress)
	local nom_s = add_soft_sign(stress.nonvowel_stem)
	local gen_s = default_genitive_u(base) and "ю" or "я" -- may be overridden
	local loc_s = base.animacy == "pr" and "ю" or "і"
	add_decl(base, stress, nom_s, gen_s, "ю", nil, "ём", loc_s, "і")
	add_plural(base, stress, "soft", "w")
end

declprops["soft-m"] = {
	desc = "soft masc-form",
	cat = "soft masculine-form",
}


decls["a-m"] = function(base, stress)
	local velar_sg = com.ends_in_velar(stress.vowel_stem)
	local always_hard_or_ts = com.ends_always_hard_or_ts(stress.vowel_stem)
	local gen_s = velar_sg and "і" or "ы"
	local loc_s =
		velar_sg and "у" or
		always_hard_or_ts and base.animacy == "pr" and "у" or
		-- This is a guess based on hard-m. I don't have any examples of animal or
		-- inanimate masculines in -а.
		always_hard_or_ts and "ы" or
		"е"
	add_decl(base, stress, "о", gen_s, "у", "у", "ом", loc_s, gen_s)
	add_plural(base, stress, "hard", "w")
end

local function a_m_desc(base, stress)
	return get_stem_type(stress, "short") .. " masc in -а"
end

local function a_m_cat(base, stress)
	local stem_type = get_stem_type(stress)
	local cats = {}
	table.insert(cats, stem_type .. " masculine nouns in -а")
	table.insert(cats, stem_type .. " masculine ~ nouns in -а")
	return cats
end

declprops["a-m"] = {
	desc = a_m_desc,
	cat = a_m_cat,
}


local function maybe_tag_ins_s_with_variant(base, ins_s_endings)
	if base.multiword then
		assert(type(ins_s_endings) == "table")
		assert(#ins_s_endings == 2)
		local ending1, ending2 = unpack(ins_s_endings)
		return {ending1 .. com.VAR1, ending2 .. com.VAR2}
	else
		return ins_s_endings
	end
end

decls["hard-f"] = function(base, stress)
	local always_hard_or_ts = com.ends_always_hard_or_ts(stress.vowel_stem)
	local gen_s = com.ends_in_velar(stress.vowel_stem) and "і" or "ы"
	-- This -е will trigger second palatalization (see apply_special_cases()),
	-- and if after final -к will be transformed into stressed -э́ or unstressed -ы.
	local dat_loc_s = always_hard_or_ts and "ы" or "е"
	local ins_s = maybe_tag_ins_s_with_variant(base, {"ой", "ою"})
	add_decl(base, stress, "а", gen_s, dat_loc_s, "у", ins_s, dat_loc_s, gen_s)
	add_plural(base, stress, "hard", base.plsoft and "j" or "null")
end

declprops["hard-f"] = {
	desc = function(base, stress)
		return get_stem_type(stress, "short") .. " fem-form"
	end,
	cat = function(base, stress)
		return get_stem_type(stress) .. " feminine-form"
	end
}


decls["soft-f"] = function(base, stress)
	local ins_s = maybe_tag_ins_s_with_variant(base, {"ё̂й", "ё̂ю"})
	add_decl(base, stress, "я", "і", "і", "ю", ins_s, "і", "і")
	add_plural(base, stress, "soft", "null")
end

declprops["soft-f"] = {
	desc = "soft fem-form",
	cat = "soft feminine-form",
}


decls["hard-third-f"] = function(base, stress)
	add_decl(base, stress, "", "ы", "ы", "", nil, "ы", "ы")
	add_plural(base, stress, "hard", "j")
	local ins_s_stem = stress.nonvowel_stem
	local ins_s
	local pre_stem, final_cons = rmatch(ins_s_stem, "^(.*)([чшжц])$")
	if pre_stem then
		if com.ends_in_vowel(pre_stem) then
			-- vowel + doublable cons; double the cons:
			-- мыш "mouse", ins sg. мы́шшу, etc.
			ins_s_stem = ins_s_stem .. final_cons
		end
		ins_s = "у"
		-- if non-vowel + doublable cons, don't change stem
		-- FIXME, need example
	else
		-- шыр "wide-open space" ins sg. шы́р'ю
		ins_s_stem = ins_s_stem .. "'"
		ins_s = "ю"
	end
	-- See comment below in soft-third-f about DOTABOVE.
	add(base, "ins_s", stress, ins_s .. DOTABOVE, nil, ins_s_stem)
end

declprops["hard-third-f"] = {
	desc = "hard 3rd-decl fem-form",
	cat = "hard third-declension feminine-form",
}


decls["soft-third-f"] = function(base, stress)
	local nom_s = rfind(stress.nonvowel_stem, "ў$") and "" or
		add_soft_sign(stress.pl_nonvowel_stem)
	add_decl(base, stress, nom_s, "і", "і", nom_s, nil, "і", "і")
	add_plural(base, stress, "soft", "j")
	local ins_s_stem = stress.nonvowel_stem
	local pre_stem, final_cons = rmatch(ins_s_stem, "^(.*)(дз)$")
	if pre_stem and com.ends_in_vowel(pre_stem) then
		-- медзь "copper", ins sg. ме́ддзю; мо́ладзь "youth", ins sg. мо́ладдзю, etc.
		ins_s_stem = pre_stem .. "ддз"
	else
		pre_stem, final_cons = rmatch(ins_s_stem, "^(.*)([^ў])$")
		if pre_stem and com.ends_in_vowel(pre_stem) then
			-- vowel + doublable cons; double the cons:
			-- гусь "goose", ins sg. гу́ссю; дало́нь "palm", ins sg. дало́нню etc.
			ins_s_stem = ins_s_stem .. final_cons
		end
	end
	-- If non-vowel + cons, don't change stem; жоўць "bile", ins sg. жо́ўцю, etc.
	-- Use DOTABOVE because ins_s needs to be stem-stressed even if remaining
	-- forms are unstressed (e.g. любо́ў, gen sg. любві́, ins sg. любо́ўю).
	add(base, "ins_s", stress, "ю" .. DOTABOVE, nil, ins_s_stem)
end

declprops["soft-third-f"] = {
	desc = "soft 3rd-decl fem-form",
	cat = "soft third-declension feminine-form",
}


decls["hard-n"] = function(base, stress)
	local velar_sg = com.ends_in_velar(stress.vowel_stem)
	local always_hard_or_ts = com.ends_always_hard_or_ts(stress.vowel_stem)
	local acc_s = base.animacy ~= "inan" and "а" or "о"
	local loc_s =
		velar_sg and "у" or
		always_hard_or_ts and base.animacy == "pr" and "у" or
		always_hard_or_ts and "ы" or
		"е"
	local count = velar_sg and "і" or "ы"
	add_decl(base, stress, "о", "а", "у", acc_s, "ом", loc_s, count)
	-- plsoft: кале́на "knee" pl. кале́ні; дно "bottom" alt pl. до́нья
	add_plural(base, stress, "hard", "w")
end

declprops["hard-n"] = {
	desc = function(base, stress)
		if com.ends_in_velar(stress.vowel_stem) then
			return "velar neut-form"
		else
			return "hard neut-form"
		end
	end,
	cat = function(base, stress)
		if com.ends_in_velar(stress.vowel_stem) then
			return "velar-stem neuter-form"
		else
			return "hard neuter-form"
		end
	end
}


local function soft_or_fourth_n(base, stress, nom_s)
	add_decl(base, stress, nom_s, "я", "ю", nom_s, "ём", "і", "і")
	-- plhard: зе́рне alt pl. зерня́ты
	add_plural(base, stress, "soft", "w")
end

decls["soft-n"] = function(base, stress)
	soft_or_fourth_n(base, stress, "ё")
end

declprops["soft-n"] = {
	desc = "soft neut-form",
	cat = "soft neuter-form",
}


decls["fourth-n"] = function(base, stress)
	soft_or_fourth_n(base, stress, "я")
end

declprops["fourth-n"] = {
	desc = "4th-decl neut-form",
	cat = "fourth-declension neuter-form",
}


decls["n-n"] = function(base, stress)
	local gen_p = genitive_pl_ending(stress, "null")
	-- FIXME, do we need to support plsoft, and if so, how?
	add_decl(base, stress, "я", "ені", "ені", "я", "енем", "ені", "ені",
		"ёны", "ён" .. gen_p, "ёнам", "ёнамі", "ёнах")
end

declprops["n-n"] = {
	desc = "n-stem neut-form",
	cat = "n-stem neuter-form",
}


decls["t-n"] = function(base, stress)
	-- FIXME, t-stem in -ця́ definitely occurs (e.g. дзіця́); can t-stem in ца́
	-- occur?
	local always_hard = com.ends_always_hard(stress.vowel_stem)
	local v = always_hard and "а" or "я"
	local ins_s = always_hard and "ом" or "ём"
	local gen_p = genitive_pl_ending(stress, "null")
	-- FIXME, do we need to support plsoft, and if so, how?
	add_decl(base, stress, v, v .. "ці", v .. "ці", v, ins_s, v .. "ці", v .. "ці",
		v .. "ты", v .. "т" .. gen_p, v .. "там", v .. "тамі", v .. "тах")
end

declprops["t-n"] = {
	desc = "t-stem neut-form",
	cat = "t-stem neuter-form",
}


decls["adj"] = function(base, stress)
	local props = {}
	if base.valt then
		table.insert(props, base.valt)
	end
	if base.surname then
		table.insert(props, "surname")
	end
	local propspec = table.concat(props, ".")
	if propspec ~= "" then
		propspec = "<" .. propspec .. ">"
	end
	-- If multiword, add variant codes to feminine adjectival instrumental
	-- singular forms so we only get adjective -й endings with noun -й endings
	-- and adjective -ю endings with noun -ю endings.
	local adj_alternant_spec = require("Module:be-adjective").do_generate_forms(
		{base.lemma .. propspec}, nil, nil, nil, base.multiword
	)
	local function copy(from_slot, to_slot)
		-- Copy forms from the origin adjective slot to the destination noun slot.
		-- The adjective code doesn't currently call mark_stressed_vowels_in_unstressed_syllables
		-- or its inverse, so we need to call the inverse function to remove extra
		-- added marks (e.g. accent marks over ё and DOTBELOW marks under vowels
		-- not to be destressed).
		base.forms[to_slot] = iut.map_forms(adj_alternant_spec.forms[from_slot],
			com.undo_mark_stressed_vowels_in_unstressed_syllables)
	end
	if base.number ~= "pl" then
		if base.gender == "M" then
			copy("nom_m", "nom_s")
			copy("gen_m", "gen_s")
			copy("dat_m", "dat_s")
			copy("ins_m", "ins_s")
			copy("loc_m", "loc_s")
			copy("gen_m", "count")
		elseif base.gender == "F" then
			copy("nom_f", "nom_s")
			copy("gen_f", "gen_s")
			copy("dat_f", "dat_s")
			copy("acc_f", "acc_s")
			copy("ins_f", "ins_s")
			copy("loc_f", "loc_s")
			copy("gen_f", "count")
		elseif base.gender == "N" then
			copy("nom_n", "nom_s")
			copy("gen_m", "gen_s")
			copy("dat_m", "dat_s")
			copy("acc_n", "acc_s")
			copy("ins_m", "ins_s")
			copy("loc_m", "loc_s")
			copy("gen_n", "count")
		else
			error("Internal error: Unrecognized gender: " .. base.gender)
		end
	end
	if base.number ~= "sg" then
		copy("nom_p", "nom_p")
		copy("gen_p", "gen_p")
		copy("dat_p", "dat_p")
		copy("ins_p", "ins_p")
		copy("loc_p", "loc_p")
	end
end

declprops["adj"] = {
	desc = function(base, stress)
		if base.number == "pl" then
			return "adj"
		elseif base.gender == "M" then
			return "adj masc"
		elseif base.gender == "F" then
			return "adj fem"
		elseif base.gender == "N" then
			return "adj neut"
		else
			error("Internal error: Unrecognized gender: " .. base.gender)
		end
	end,
	cat = function(base, stress)
		local gender
		if base.number == "pl" then
			gender = "plural-only"
		elseif base.gender == "M" then
			gender = "masculine"
		elseif base.gender == "F" then
			gender = "feminine"
		elseif base.gender == "N" then
			gender = "neuter"
		else
			error("Internal error: Unrecognized gender: " .. base.gender)
		end
		local stemtype
		if rfind(base.lemma, "ци́?й$") then
			stemtype = "c-stem"
		elseif rfind(base.lemma, "и́?й$") then
			stemtype = "hard"
		elseif rfind(base.lemma, "і́?й$") then
			stemtype = "soft"
		elseif rfind(base.lemma, "ї́?й$") then
			stemtype = "j-stem"
		elseif base.surname then
			stemtype = "surname"
		else
			stemtype = "possessive"
		end

		return {"adjectival nouns", stemtype .. " " .. gender .. " adjectival ~ nouns"}
	end,
}


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

--[=[
Parse a single override spec (e.g. 'loci:ú' or 'datpl:чо́ботам:чобо́тям[rare]') and return
two values: the slot the override applies to, and an object describing the override spec.
The input is actually a list where the footnotes have been separated out; for example,
given the spec 'inspl:чо́ботамі:чобо́тямі[rare]:чобітьми́[archaic]', the input will be a list
{"inspl:чо́ботамі:чобо́тямі", "[rare]", ":чобітьми́", "[archaic]", ""}. The object returned
for 'datpl:чо́ботам:чобо́тям[rare]' looks like this:

{
  full = true,
  values = {
    {
      form = "чо́ботам"
    },
    {
      form = "чобо́тям",
      footnotes = {"[rare]"}
    }
  }
}

The object returned for 'lócji:jú' looks like this:

{
  stemstressed = true,
  values = {
    {
      form = "ї",
    },
    {
      form = "ю́",
    }
  }
}

Note that all forms (full or partial) are reverse-transliterated, and full forms are
normalized by adding an accent to monosyllabic forms.
]=]
local function parse_override(segments)
	local retval = {values = {}}
	local part = segments[1]
	local offset = 4
	local case = usub(part, 1, 3)
	if cases[case] then
		-- ok
	elseif accented_cases[case] then
		case = accented_cases[case]
		retval.stemstressed = true
	elseif rfind(part, "^count") then
		case = "count"
		offset = 6
	elseif rfind(part, "^cóunt") then
		case = "count"
		offset = 6
		retval.stemstressed = true
	else
		error("Internal error: unrecognized case in override: '" .. table.concat(segments) .. "'")
	end
	local rest = usub(part, offset)
	local slot
	if case == "count" then
		slot = "count"
	elseif rfind(rest, "^pl") then
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
			value.form = m_be_translit.reverse_tr(form)
			if retval.full then
				value.form = com.add_monosyllabic_accent(value.form)
				if com.needs_accents(value.form) then
					error("Override '" .. value.form .. "' for slot '" .. slot .. "' missing an accent")
				end
			end
		end
		value.footnotes = fetch_footnotes(colon_separated_group)
		table.insert(retval.values, value)
	end
	return slot, retval
end


--[=[
Parse an indicator spec (text consisting of angle brackets and zero or more
dot-separated indicators within them). Return value is an object of the form

{
  overrides = {
    SLOT = {OVERRIDE, OVERRIDE, ...}, -- as returned by parse_override()
	...
  },
  forms = {}, -- forms for a single spec alternant; see `forms` below
  footnotes = {"FOOTNOTE", "FOOTNOTE", ...}, -- may be missing
  stresses = { -- may be missing
	{
	  stress = "STRESS", -- "a", "b", etc.
	  reducible = TRUE_OR_FALSE,
	  genpl_reversed = TRUE_OR_FALSE,
	  footnotes = {"FOOTNOTE", "FOOTNOTE", ...}, -- may be missing
	  -- The following fields are filled in by determine_stress_and_stems()
	  vowel_stem = "STEM",
	  nonvowel_stem = "STEM",
	  pl_vowel_stem = "STEM",
	  pl_nonvowel_stem = "STEM",
	},
	...
  },
  explicit_gender = "GENDER", -- "M", "F", "N", "MF"; may be missing
  number = "NUMBER", -- "sg", "pl"; may be missing
  animacy = "ANIMACY", -- "inan", "pr", "anml"; may be missing
  valt = {"VOWEL_ALTERNATION", ...} -- "ae", "ao", "yo", "oy", etc.; may be missing
  neutertype = "NEUTERTYPE", -- "t", "n"; may be missing
  plsoft = true, -- may be missing
  plhard = true, -- may be missing
  remove_in = true, -- may be missing
  thirddecl = true, -- may be missing
  surname = true, -- may be missing
  adj = true, -- may be missing
  stem = "STEM", -- may be missing
  plstem = "PLSTEM", -- may be missing

  -- The following additional fields are added by other functions:
  orig_lemma = "ORIGINAL-LEMMA", -- as given by the user
  orig_lemma_no_links = "ORIGINAL-LEMMA-NO-LINKS", -- links removed, monosyllabic stress added
  lemma = "LEMMA", -- `orig_lemma_no_links`, converted to singular form if plural
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
  decl = "DECL", -- declension, e.g. "hard-m"
  vowel_stem = "VOWEL-STEM", -- derived from vowel-ending lemmas
  nonvowel_stem = "NONVOWEL-STEM", -- derived from non-vowel-ending lemmas
}
]=]
local function parse_indicator_spec(angle_bracket_spec)
	local inside = rmatch(angle_bracket_spec, "^<(.*)>$")
	assert(inside)
	local base = {overrides = {}, forms = {}}
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
			elseif rfind(part, "^[a-f][*#()ўй%-]*$") or rfind(part, "^[a-f][*#()ўй%-]*,") or
				rfind(part, "^[*#()ўй%-]*$") or rfind(part, "^[*#()ўй%-]*,") then
				if base.stresses then
					error("Can't specify stress pattern indicator twice: '" .. inside .. "'")
				end
				local comma_separated_groups = iut.split_alternating_runs(dot_separated_group, ",")
				local patterns = {}
				for i, comma_separated_group in ipairs(comma_separated_groups) do
					local pattern = comma_separated_group[1]
					local pat, reducible = rsubb(pattern, "%*", "")
					local genpl_reversed, genpl_ending_null, genpl_ending_w, genpl_ending_j
					pat, genpl_reversed = rsubb(pat, "#", "")
					pat, genpl_ending_null = rsubb(pat, "%(%-%)", "")
					pat, genpl_ending_w = rsubb(pat, "%(ў%)", "")
					pat, genpl_ending_j = rsubb(pat, "%(й%)", "")
					if genpl_ending_null and genpl_ending_w then
						error("Can't specify both (-) and (ў) in the same stress pattern indicator: '" .. inside .. "'")
					end
					if genpl_ending_null and genpl_ending_j then
						error("Can't specify both (-) and (й) in the same stress pattern indicator: '" .. inside .. "'")
					end
					if genpl_ending_w and genpl_ending_j then
						error("Can't specify both (ў) and (й) in the same stress pattern indicator: '" .. inside .. "'")
					end
					local genpl_ending =
						genpl_ending_null and "null" or
						genpl_ending_w and "w" or
						genpl_ending_j and "j" or
						nil
					if pat == "" then
						pat = nil
					end
					if pat and not stress_patterns[pat] then
						error("Unrecognized stress pattern '" .. pat .. "': '" .. inside .. "'")
					end
					table.insert(patterns, {
						stress = pat, reducible = reducible, genpl_reversed = genpl_reversed,
						genpl_ending = genpl_ending, footnotes = fetch_footnotes(comma_separated_group)
					})
				end
				base.stresses = patterns
			elseif #dot_separated_group > 1 then
				error("Footnotes only allowed with slot overrides, stress patterns or by themselves: '" .. table.concat(dot_separated_group) .. "'")
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
			elseif part == "inan" or part == "pr" or part == "anml" then
				if base.animacy then
					error("Can't specify animacy twice: '" .. inside .. "'")
				end
				base.animacy = part
			elseif rfind(part, "^a[eo][23]?$") or rfind(part, "^avo[23]?$") or rfind(part, "yo[23]?$") or
				part == "oy" or part == "voa" then
				base.valt = base.valt or {}
				table.insert(base.valt, part)
			elseif part == "t" or part == "n" then
				if base.neutertype then
					error("Can't specify neuter indicator ('t' or 'n') more than once: '" .. inside .. "'")
				end
				base.neutertype = part
			elseif part == "plsoft" then
				if base.plsoft then
					error("Can't specify 'plsoft' twice: '" .. inside .. "'")
				end
				base.plsoft = true
			elseif part == "plhard" then
				if base.plhard then
					error("Can't specify 'plhard' twice: '" .. inside .. "'")
				end
				base.plhard = true
			elseif part == "in-" then
				if base.remove_in then
					error("Can't specify 'in-' twice: '" .. inside .. "'")
				end
				base.remove_in = true
			elseif part == "3rd" then
				if base.thirddecl then
					error("Can't specify '3rd' twice: '" .. inside .. "'")
				end
				base.thirddecl = true
			elseif part == "surname" then
				if base.surname then
					error("Can't specify 'surname' twice: '" .. inside .. "'")
				end
				base.surname = true
			elseif part == "+" then
				if base.adj then
					error("Can't specify '+' twice: '" .. inside .. "'")
				end
				base.adj = true
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


local function add_stress_for_pattern(stress, stem)
	local where_stress = stress_patterns[stress.stress].stress
	if where_stress == "last" then
		return com.maybe_accent_final_syllable(stem)
	elseif where_stress == "first" then
		return com.maybe_accent_initial_syllable(stem)
	elseif not com.is_stressed(stem) then
		error("Something wrong: Stress pattern " .. stress.stress .. " but stem '" .. stem .. "' doesn't have stress")
	else
		return stem
	end
end


local function set_defaults_and_check_bad_indicators(base)
	-- Set default values.
	if not base.adj then
		base.number = base.number or "both"
		base.animacy = base.animacy or base.surname and "pr" or
			base.neutertype == "t" and "anml" or
			"inan"
	end
	base.gender = base.explicit_gender

	-- Set some further defaults and check for certain bad indicator/number/gender combinations.
	if base.thirddecl then
		if base.number ~= "pl" then
			error("'3rd' can only be specified along with 'pl'")
		end
		if base.gender and base.gender ~= "F" then
			error("'3rd' can't specified with non-feminine gender indicator '" .. base.gender .. "'")
		end
		base.gender = "F"
	end
	if base.neutertype then
		if base.gender and base.gender ~= "N" then
			error("Neuter-type indicator '" .. base.neutertype .. "' can't specified with non-neuter gender indicator '" .. base.gender .. "'")
		end
		base.gender = "N"
	end
end


local function undo_vowel_alternation(base, stem)
	-- FIXME! Implement me.
	return stem
end


-- For a plural-only lemma, synthesize a likely singular lemma. It doesn't have to be
-- theoretically correct as long as it generates all the correct plural forms (which mostly
-- means the nominative and genitive plural as the remainder are either derived or the same
-- for all declensions, modulo soft vs. hard).
local function synthesize_singular_lemma(base)
	local stem, ac
	while true do
		-- Check for t-type endings.
		if base.neutertype == "t" then
			stem, ac = rmatch(base.lemma, "^(.*[яа])(́)ты$")
			if stem then
				base.lemma = stem .. ac
				break
			end
			error("Unrecognized lemma for 't' indicator: '" .. base.lemma .. "'")
		end
		-- Handle lemmas in -ы.
		stem, ac = rmatch(base.lemma, "^(.*)ы(́?)$")
		if stem then
			if not base.gender then
				error("For plural-only lemma, need to specify the gender: '" .. base.lemma .. "'")
			end
			if base.gender == "M" then
				stem = rsub(stem, "в$", "ў")
				base.lemma = undo_vowel_alternation(base, stem)
			elseif base.gender == "F" then
				if base.thirddecl then
					if not com.ends_always_hard_or_ts(stem) then
						error("For 3rd-decl plural-only lemma in -ы, stem must end in an always-hard consonant or ц: '" .. base.lemma .. "'")
					else
						base.lemma = stem
					end
					base.lemma = undo_vowel_alternation(base, base.lemma)
				else
					base.lemma = stem .. "а" .. ac
				end
			elseif base.gender == "MF" then
				if ac == "" then
					-- This is because masculine in unstressed -а and feminine in
					-- unstressed -а have different declensions.
					error("For plural-only lemma in unstressed -ы, gender MF not allowed: '" .. base.lemma .. "'")
				else
					base.lemma = stem .. "а́"
				end
			else
				assert(base.gender == "N")
				if ac == "" then
					base.lemma = stem .. "а"
				else
					base.lemma = stem .. "о́"
				end
			end
			break
		end
		-- Handle lemmas in -і.
		stem, ac = rmatch(base.lemma, "^(.*)і(́?)$")
		if stem then
			if not base.gender then
				error("For plural-only lemma, need to specify the gender: '" .. base.lemma .. "'")
			end
			local velar = com.ends_in_velar(stem)
			local vowel = com.ends_in_vowel(stem)
			if base.gender == "M" then
				if velar then
					base.lemma = stem
				elseif vowel then
					base.lemma = stem .. "й"
				else
					base.lemma = stem .. "ь"
				end
				base.lemma = undo_vowel_alternation(base, base.lemma)
			elseif base.gender == "F" then
				if base.thirddecl then
					if rfind(stem, "в$") then
						base.lemma = rsub(stem, "в$", "ў")
					else
						base.lemma = stem .. "ь"
					end
					base.lemma = undo_vowel_alternation(base, base.lemma)
				elseif velar then
					base.lemma = stem .. "а" .. ac
				else
					base.lemma = stem .. "я" .. ac
				end
			elseif base.gender == "MF" then
				if velar then
					if ac == "" then
						-- This is because masculine in unstressed -а and feminine in
						-- unstressed -а have different declensions.
						error("For plural-only lemma in velar + unstressed -і, gender MF not allowed: '" .. base.lemma .. "'")
					end
					base.lemma = stem .. "а́"
				else
					base.lemma = stem .. "я" .. ac
				end
			else
				assert(base.gender == "N")
				if ac == "" then
					base.lemma = stem .. (velar and "а" or "е")
				else
					base.lemma = stem .. (velar and "о́" or "ё")
				end
			end
			break
		end
		error("Don't recognize ending of lemma '" .. base.lemma .. "'")
	end

	-- Now set the stress pattern if not given.
	if not base.stresses then
		base.stresses = {{reducible = false, genpl_reversed = false}}
	end
	for _, stress in ipairs(base.stresses) do
		if not stress.stress then
			if ac == AC then
				stress.stress = "b"
			else
				stress.stress = "a"
			end
		end
	end
end


-- For an adjectival lemma, synthesize the masc singular form.
local function synthesize_adj_lemma(base)
	local stem, vowel, ac
	local gender, number
	while true do
		-- Masculine
		stem, ac = rmatch(base.lemma, "^(.*)[ыі](́?)$")
		if stem then
			gender = "M"
			break
		end
		stem, ac = rmatch(base.lemma, "^(.*[аоеё]́?в)$")
		if stem then
			gender = "M"
			break
		end
		stem, ac = rmatch(base.lemma, "^(.*[ыі]́?н)$")
		if stem then
			gender = "M"
			break
		end
		-- Feminine
		stem, vowel, ac = rmatch(base.lemma, "^(.*)([ая])(́?)я$")
		if stem then
			if com.ends_in_velar(stem) or vowel == "я" then
				base.lemma = stem .. "і" .. ac
			else
				base.lemma = stem .. "ы" .. ac
			end
			gender = "F"
			break
		end
		-- Neuter
		stem, vowel, ac = rmatch(base.lemma, "^(.*)([аоя])(́?)е$")
		if stem then
			if com.ends_in_velar(stem) or vowel == "я" then
				base.lemma = stem .. "і" .. ac
			else
				base.lemma = stem .. "ы" .. ac
			end
			gender = "N"
			break
		end
		-- Plural
		stem, vowel, ac = rmatch(base.lemma, "^(.*)([ыі])(́?)я$")
		if stem then
			base.lemma = stem .. vowel .. ac
			number = "pl"
			break
		end
		error("Don't recognize ending of adjectival lemma '" .. base.lemma .. "'")
	end
	if gender then
		if base.gender and base.gender ~= gender then
			error("Explicit gender '" .. base.gender .. "' disagrees with detected gender '" .. gender .. "'")
		end
		base.gender = gender
	end
	if number then
		if base.number and base.number ~= number then
			error("Explicit number '" .. base.number .. "' disagrees with detected number '" .. number .. "'")
		end
		base.number = number
	end

	-- Now set the stress pattern if not given.
	if not base.stresses then
		base.stresses = {{reducible = false, genpl_reversed = false}}
	end
	for _, stress in ipairs(base.stresses) do
		if not stress.stress then
			if ac == AC then
				stress.stress = "b"
			else
				stress.stress = "a"
			end
		end
		-- Set the stems.
		stress.vowel_stem = stem
		stress.nonvowel_stem = stem
		stress.pl_vowel_stem = stem
		stress.pl_nonvowel_stem = stem
	end
	base.decl = "adj"
end


local function check_indicators_match_lemma(base)
	-- Check for indicators that don't make sense given the context.
	if base.remove_in and not rfind(base.lemma, "[іы]́?н$") then
		error("'in-' can only be specified with a lemma ending in -ін or -ын")
	end
	if base.neutertype then
		if not rfind(base.lemma, "я́?$") and not rfind(base.lemma, com.always_hard_or_ts_c .. "а́?$") then
			error("Neuter-type indicator '" .. base.neutertype .. "' can only be specified with a lemma ending in -я or always-hard/ц + -а")
		end
		if base.neutertype == "n" and not rfind(base.lemma, "мя́?$") then
			error("Neuter-type indicator 'n' can only be specified with a lemma ending in -мя")
		end
	end
end


-- Determine the declension based on the lemma and whatever gender has been already given,
-- and set the gender to a default if not given. The declension is set in base.decl.
-- In the process, we set either base.vowel_stem (if the lemma ends in a vowel) or
-- base.nonvowel_stem (if the lemma does not end in a vowel), which is used by
-- determine_stress_and_stems().
local function determine_declension_and_gender(base)
	-- Determine declension and set gender
	local stem, ac
	stem = rmatch(base.lemma, "^(.*)ь$")
	if stem then
		if not base.gender then
			if rfind(base.lemma, "асць$") then
				base.gender = "F"
			else
				error("For lemma ending in -ь other than -асць, gender M or F must be given")
			end
		end
		if base.gender == "N" or base.gender == "MF" then
			error("For lemma ending in -ь, gender " .. base.gender .. " not allowed")
		elseif base.gender == "M" then
			base.decl = "soft-m"
		else
			base.decl = "soft-third-f"
		end
		base.nonvowel_stem = stem
		return
	end
	stem = rmatch(base.lemma, "^(.*)й$")
	if stem then
		base.decl = "soft-m"
		if base.gender and base.gender ~= "M" then
			error("For lemma ending in -й, gender " .. base.gender .. " not allowed")
		end
		base.gender = "M"
		base.nonvowel_stem = stem
		base.stem_for_reduce = base.lemma
		return
	end
	stem, ac = rmatch(base.lemma, "^(.*)а(́?)$")
	if stem then
		if ac == "" then
			if not base.gender and rfind(base.lemma, "[сц]тва$") then
				base.gender = "N"
			end
			if base.gender == "M" then
				-- ба́цька, мужчы́на, прамо́ўца, пту́шка, саба́ка, све́дка, etc.
				base.decl = "a-m"
			elseif base.gender == "N" then
				base.decl = "hard-n"
			elseif base.gender == "MF" then
				error("For lemma ending in unstressed -а, gender MF not allowed")
			else
				base.gender = "F"
				base.decl = "hard-f"
			end
		elseif base.gender == "N" then
			error("For lemma ending in -а́, gender N not allowed")
		else
			-- Nouns in -а́ decline like feminines even if masculine (e.g. сатана́).
			base.gender = base.gender or "F"
			base.decl = "hard-f"
		end
		base.vowel_stem = stem
		return
	end
	stem = rmatch(base.lemma, "^(.*)я́?$")
	if stem then
		if base.neutertype == "n" then
			base.decl = "n-n"
		elseif base.neutertype == "t" then
			base.decl = "t-n"
		elseif base.gender == "N" then
			base.decl = "fourth-n"
		elseif not base.gender and rfind(stem, "м$") then
			base.decl = "fourth-n"
			base.gender = "N"
		else
			base.decl = "soft-f"
			base.gender = base.gender or "F"
		end
		base.vowel_stem = stem
		return
	end
	stem = rmatch(base.lemma, "^(.*)о́$")
	if stem then
		base.decl = "hard-n"
		if base.gender == "F" or base.gender == "MF" then
			error("For lemma ending in -о́, gender " .. base.gender .. " not allowed")
		end
		base.gender = base.gender or "N"
		base.vowel_stem = stem
		return
	end
	local vowel
	stem, ac = rmatch(base.lemma, "^(.*)([её])(́?)$")
	if stem then
		base.decl = "soft-n"
		if base.gender and base.gender ~= "N" then
			error("For lemma ending in -е or -ё, gender " .. base.gender .. " not allowed")
		end
		base.gender = "N"
		if vowel == "е" and ac == AC or vowel == "ё" and ac == "" then
			error("Neuter lemma in stressed -е́ or unstressed -ё not allowed: '" .. base.lemma .. "'")
		end
		base.vowel_stem = stem
		return
	end
	stem = rmatch(base.lemma, "^(.*" .. com.cons_c .. ")$")
	if stem then
		if base.gender == "N" or base.gender == "MF" then
			error("For lemma ending in a consonant, gender " .. base.gender .. " not allowed")
		elseif base.gender == "F" then
			if rfind(stem, "ў$") then
				base.decl = "soft-third-f"
			else
				base.decl = "hard-third-f"
			end
		else
			base.decl = "hard-m"
		end
		base.gender = base.gender or "M"
		base.nonvowel_stem = stem
		return
	end
	error("Unrecognized ending for lemma: '" .. base.lemma .. "'")
end


-- Determine the stress pattern(s) if not explicitly given, as well as the stems
-- to use for each specified stress pattern: vowel and nonvowel stems, for singular
-- and plural. We assume that one of base.vowel_stem or base.nonvowel_stem has been
-- set in determine_declension_and_gender(), depending on whether the lemma ends in
-- a vowel. We construct all the rest given the stress pattern, reducibility, and
-- any explicit stems given. We store the determined stems inside of the stress objects
-- in `base.stresses`, meaning that if the user gave multiple stress patterns, we
-- will compute multiple sets of stems. The reason is that the stems may vary depending
-- on the stress pattern and reducibility. The dependency on reducibility should be
-- obvious but there is also dependency on the stress pattern in that in stress patterns
-- d and f the lemma is given in end-stressed form but some other forms need to
-- be stem-stressed. We make the stems stressed on the last syllable for pattern d
-- (галава́ pl. гало́вы) but but on the first syllable for pattern f (старана́ pl. сто́раны).
local function determine_stress_and_stems(base)
	if not base.stresses then
		base.stresses = {{reducible = false, genpl_reversed = false}}
	end
	if base.stem then
		base.stem = com.mark_stressed_vowels_in_unstressed_syllables(base.stem)
	end
	if base.plstem then
		base.plstem = com.mark_stressed_vowels_in_unstressed_syllables(base.plstem)
	end
	local end_stressed_lemma = rfind(base.lemma, AC .. "$")
	for _, stress in ipairs(base.stresses) do
		local function dereduce(stem)
			local epenthetic_stress = stress_patterns[stress.stress].gen_p == "+"
			if stress.genpl_reversed then
				epenthetic_stress = not epenthetic_stress
			end
			local dereduced_stem = com.dereduce(stem, epenthetic_stress)
			if not dereduced_stem then
				error("Unable to dereduce stem '" .. stem .. "'")
			end
			return dereduced_stem
		end
		if not stress.stress then
			if stress.reducible and rfind(base.lemma, "[еоэаё]́" .. com.cons_c .. "ь?$") then
				-- reducible with stress on the reducible vowel
				stress.stress = "b"
			elseif base.neutertype == "t" then
				stress.stress = "b"
			elseif base.neutertype == "n" then
				stress.stress = "c"
			elseif end_stressed_lemma then
				stress.stress = "d"
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
		local lemma_is_vowel_stem = not not base.vowel_stem
		if base.vowel_stem then
			if end_stressed_lemma and stress_patterns[stress.stress].nom_s ~= "+" then
				error("Stress pattern " .. stress.stress .. " requires a stem-stressed lemma, not end-stressed: '" .. base.lemma .. "'")
			elseif not end_stressed_lemma and stress_patterns[stress.stress].nom_s == "+" then
				error("Stress pattern " .. stress.stress .. " requires an end-stressed lemma, not stem-stressed: '" .. base.lemma .. "'")
			end
			if base.stem then
				error("Can't specify 'stem:' with lemma ending in a vowel")
			end
			stress.vowel_stem = add_stress_for_pattern(stress, base.vowel_stem)
			stress.nonvowel_stem = stress.vowel_stem
			if stress.reducible then
				stress.nonvowel_stem = dereduce(stress.nonvowel_stem)
			end
			stress.nonvowel_stem = rsub(stress.nonvowel_stem, "в$", "ў")
		else
			stress.nonvowel_stem = add_stress_for_pattern(stress, base.nonvowel_stem)
			stress.vowel_stem = stress.reducible and base.stem_for_reduce or base.nonvowel_stem
			-- Convert -ў to -в before reducing; otherwise reduced stem салаў- from
			-- салаве́й "nightingale" gets wrongly converted to салав-.
			stress.vowel_stem = rsub(stress.vowel_stem, "ў$", "в")
			if stress.reducible then
				local reduced_stem = com.reduce(stress.vowel_stem)
				if not reduced_stem then
					error("Unable to reduce stem '" .. stress.vowel_stem .. "'")
				end
				stress.vowel_stem = reduced_stem
			end
			if base.stem and base.stem ~= stress.vowel_stem then
				stress.irregular_stem = true
				stress.vowel_stem = base.stem
			end
			stress.vowel_stem = add_stress_for_pattern(stress, stress.vowel_stem)
		end
		if base.remove_in then
			stress.pl_vowel_stem = com.maybe_accent_final_syllable(rsub(stress.vowel_stem, "[іы]́?н$", ""))
			stress.pl_nonvowel_stem = stress.pl_vowel_stem
		else
			stress.pl_vowel_stem = stress.vowel_stem
			stress.pl_nonvowel_stem = stress.nonvowel_stem
		end
		if base.plstem then
			local stressed_plstem = add_stress_for_pattern(stress, base.plstem)
			if stressed_plstem ~= stress.pl_vowel_stem then
				stress.irregular_plstem = true
			end
			stress.pl_vowel_stem = stressed_plstem
			stress.pl_nonvowel_stem = stressed_plstem
			if lemma_is_vowel_stem and stress.reducible then
				stress.pl_nonvowel_stem = dereduce(stress.pl_nonvowel_stem)
			end
		end
	end
end


local function detect_indicator_spec(base)
	set_defaults_and_check_bad_indicators(base)
	if base.adj then
		synthesize_adj_lemma(base)
	else
		if base.number == "pl" then
			synthesize_singular_lemma(base)
		end
		check_indicators_match_lemma(base)
		determine_declension_and_gender(base)
		determine_stress_and_stems(base)
	end
end


local function detect_all_indicator_specs(alternant_multiword_spec)
	local is_multiword = #alternant_multiword_spec.alternant_or_word_specs > 1
	iut.map_word_specs(alternant_multiword_spec, function(base)
		detect_indicator_spec(base)
		base.multiword = is_multiword
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
			is_nounal = not word_specs[i].adj
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
Propagate `property` (one of "animacy", "gender" or "number") from nouns to adjacent
adjectives. We proceed as follows:
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


local function determine_noun_status(alternant_multiword_spec)
	for i, alternant_or_word_spec in ipairs(alternant_multiword_spec.alternant_or_word_specs) do
		if alternant_or_word_spec.alternants then
			local is_noun = false
			for _, multiword_spec in ipairs(alternant_or_word_spec.alternants) do
				for j, word_spec in ipairs(multiword_spec.word_specs) do
					if not word_spec.adj then
						multiword_spec.first_noun = j
						is_noun = true
						break
					end
				end
			end
			if is_noun then
				alternant_multiword_spec.first_noun = i
			end
		elseif not alternant_or_word_spec.adj then
			alternant_multiword_spec.first_noun = i
			return
		end
	end
end


-- Check that multisyllabic lemmas have stress, and add stress to monosyllabic
-- lemmas if needed.
local function normalize_all_lemmas(alternant_multiword_spec)
	iut.map_word_specs(alternant_multiword_spec, function(base)
		base.orig_lemma = base.lemma
		base.orig_lemma_no_links = com.add_monosyllabic_accent(m_links.remove_links(base.lemma))
		base.lemma = base.orig_lemma_no_links
		base.lemma = com.mark_stressed_vowels_in_unstressed_syllables(base.lemma)
		base.lemma = com.apply_vowel_alternation(base.lemma, base.valt)
	end)
end


local function decline_noun(base)
	for _, stress in ipairs(base.stresses) do
		if not decls[base.decl] then
			error("Internal error: Unrecognized declension type '" .. base.decl .. "'")
		end
		decls[base.decl](base, stress)
	end
	handle_derived_slots_and_overrides(base)
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
				local footnotes = slot == "count" and {count_footnote_msg} or nil
				for _, form in ipairs(rsplit(args[param], "%s*,%s*")) do
					if com.is_multi_stressed(form) then
						error("Multi-stressed form '" .. form .. "' in slot '" .. slot .. "' not allowed; use singly-stressed forms separated by commas")
					end
					if not unknown_stress and not rfind(form, "^%-") and com.needs_accents(form) then
						error("Stress required in multisyllabic form '" .. form .. "' in slot '" .. slot .. "'; if stress is truly unknown, use unknown_stress=1")
					end
					iut.insert_form(forms, slot, {form=form, footnotes=footnotes})
				end
			end
		end
	end
end


-- Compute the categories to add the noun to, as well as the annotation to display in the
-- declension title bar. We combine the code to do these functions as both categories and
-- title bar contain similar information.
local function compute_categories_and_annotation(alternant_multiword_spec)
	local cats = {}
	local function insert(cattype)
		m_table.insertIfNot(cats, "Belarusian " .. cattype)
	end
	if alternant_multiword_spec.number == "sg" then
		insert("uncountable nouns")
	elseif alternant_multiword_spec.number == "pl" then
		insert("pluralia tantum")
	end
	local annotation
	if alternant_multiword_spec.manual then
		alternant_multiword_spec.annotation =
			alternant_multiword_spec.number == "sg" and "sg-only" or
			alternant_multiword_spec.number == "pl" and "pl-only" or
			""
	else
		local annparts = {}
		local animacies = {}
		local decldescs = {}
		local patterns = {}
		local vowelalts = {}
		local irregs = {}
		local stems = {}
		local reducible = nil
		local function do_word_spec(base)
			if base.animacy == "inan" then
				m_table.insertIfNot(animacies, "inan")
			elseif base.animacy == "pr" then
				m_table.insertIfNot(animacies, "pr")
			else
				assert(base.animacy == "anml")
				m_table.insertIfNot(animacies, "anml")
			end
			for _, stress in ipairs(base.stresses) do
				local props = declprops[base.decl]
				local desc = props.desc
				if type(desc) == "function" then
					desc = desc(base, stress)
				end
				m_table.insertIfNot(decldescs, desc)
				local cats = props.cat
				if type(cats) == "function" then
					cats = cats(base, stress)
				end
				if type(cats) == "string" then
					cats = {cats .. " nouns", cats .. " ~ nouns"}
				end
				for _, cat in ipairs(cats) do
					cat = rsub(cat, "~", "accent-" .. stress.stress)
					insert(cat)
				end
				m_table.insertIfNot(patterns, stress.stress)
				insert("nouns with accent pattern " .. stress.stress)
				if base.valt then
					for _, valt in ipairs(base.valt) do
						local vowelalt
						if rfind(valt, "^ae") then
							vowelalt = "а-е"
						elseif rfind(valt, "^ao") then
							vowelalt = "а-о"
						elseif rfind(valt, "^avo") then
							vowelalt = "а-во"
						elseif rfind(valt, "^yo") then
							vowelalt = "ы-о"
						elseif valt == "oy" then
							vowelalt = "о-ы"
						elseif valt == "voa" then
							vowelalt = "во-а"
						else
							error("Internal error: Unrecognized vowel alternation: " .. valt)
						end
						m_table.insertIfNot(vowelalts, vowelalt)
						insert("nouns with " .. vowelalt .. " alternation")
					end
				end
				if reducible == nil then
					reducible = stress.reducible
				elseif reducible ~= stress.reducible then
					reducible = "mixed"
				end
				if stress.reducible then
					insert("nouns with reducible stem")
				end
				if stress.irregular_stem then
					m_table.insertIfNot(irregs, "irreg-stem")
					insert("nouns with irregular stem")
				end
				if stress.irregular_plstem then
					m_table.insertIfNot(irregs, "irreg-plstem")
					insert("nouns with irregular plural stem")
				end
				m_table.insertIfNot(stems, stress.vowel_stem)
			end
		end
		local key_entry = alternant_multiword_spec.first_noun or 1
		if #alternant_multiword_spec.alternant_or_word_specs >= key_entry then
			local alternant_or_word_spec = alternant_multiword_spec.alternant_or_word_specs[key_entry]
			if alternant_or_word_spec.alternants then
				for _, multiword_spec in ipairs(alternant_or_word_spec.alternants) do
					key_entry = multiword_spec.first_noun or 1
					if #multiword_spec.word_specs >= key_entry then
						do_word_spec(multiword_spec.word_specs[key_entry])
					end
				end
			else
				do_word_spec(alternant_or_word_spec)
			end
		end
		if #animacies > 0 then
			table.insert(annparts, table.concat(animacies, "/"))
		end
		if alternant_multiword_spec.number ~= "both" then
			table.insert(annparts, alternant_multiword_spec.number == "sg" and "sg-only" or "pl-only")
		end
		if #decldescs == 0 then
			table.insert(annparts, "indecl")
		else
			table.insert(annparts, table.concat(decldescs, " // "))
		end
		if #patterns > 0 then
			table.insert(annparts, "accent-" .. table.concat(patterns, "/"))
		end
		if #vowelalts > 0 then
			table.insert(annparts, table.concat(vowelalts, "/"))
		end
		if reducible == "mixed" then
			table.insert(annparts, "mixed-reduc")
		elseif reducible then
			table.insert(annparts, "reduc")
		end
		if #irregs > 0 then
			table.insert(annparts, table.concat(irregs, " // "))
		end
		alternant_multiword_spec.annotation = table.concat(annparts, " ")
		if #patterns > 1 then
			insert("nouns with multiple accent patterns")
		end
		if #stems > 1 then
			insert("nouns with multiple stems")
		end
	end
	alternant_multiword_spec.categories = cats
end


local function show_forms(alternant_multiword_spec)
	local lemmas = {}
	if alternant_multiword_spec.forms.nom_s then
		for _, nom_s in ipairs(alternant_multiword_spec.forms.nom_s) do
			table.insert(lemmas, com.remove_monosyllabic_accents(nom_s.form))
		end
	elseif alternant_multiword_spec.forms.nom_p then
		for _, nom_p in ipairs(alternant_multiword_spec.forms.nom_p) do
			table.insert(lemmas, com.remove_monosyllabic_accents(nom_p.form))
		end
	end
	local props = {
		lang = lang,
		canonicalize = function(form)
			return com.remove_variant_codes(com.remove_monosyllabic_accents(form))
		end,
	}
	iut.show_forms_with_translit(alternant_multiword_spec.forms, lemmas,
		output_noun_slots_with_linked, props, alternant_multiword_spec.footnotes,
		"allow footnote symbols")
end


local function make_table(alternant_multiword_spec)
	local forms = alternant_multiword_spec.forms

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
| {loc_p}{voc_clause}{count_clause}
|{\cl}{notes_clause}</div></div>]=]

	local voc_clause_both = [=[

|-
!style="background:#eff7ff"|vocative
| {voc_s}
| {voc_p}]=]

	local count_clause_both = [=[

|-
!style="background:#eff7ff"|count form
| —
| {count}]=]

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
| {loc_s}{voc_clause}
|{\cl}{notes_clause}</div></div>]=]

	local voc_clause_sg = [=[

|-
!style="background:#eff7ff"|vocative
| {voc_s}]=]

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
| {loc_p}{voc_clause}{count_clause}
|{\cl}{notes_clause}</div></div>]=]

	local voc_clause_pl = [=[

|-
!style="background:#eff7ff"|vocative
| {voc_p}]=]

	local count_clause_pl = [=[

|-
!style="background:#eff7ff"|count form
| {count}]=]

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
	local voc_clause =
		alternant_multiword_spec.number == "sg" and forms.voc_s and forms.voc_s ~= "—" and
			voc_clause_sg or
		alternant_multiword_spec.number == "pl" and forms.voc_p and forms.voc_p ~= "—" and
			voc_clause_pl or
		alternant_multiword_spec.number == "both" and (
			forms.voc_s and forms.voc_s ~= "—" or forms.voc_p and forms.voc_p ~= "—"
		) and voc_clause_both
	forms.voc_clause = voc_clause and m_string_utilities.format(voc_clause, forms) or ""
	local count_clause =
		alternant_multiword_spec.number == "pl" and forms.count and forms.count ~= "—" and
			count_clause_pl or
		alternant_multiword_spec.number == "both" and forms.count and forms.count ~= "—" and
			count_clause_both
	forms.count_clause = count_clause and m_string_utilities.format(count_clause, forms) or ""
	forms.notes_clause = forms.footnote ~= "" and
		m_string_utilities.format(notes_template, forms) or ""
	return m_string_utilities.format(table_spec, forms)
end


local function compute_headword_genders(alternant_multiword_spec)
	local genders = {}
	local number
	if alternant_multiword_spec.number == "pl" then
		number = "-p"
	else
		number = ""
	end
	iut.map_word_specs(alternant_multiword_spec, function(base)
		local animacy = base.animacy
		if animacy == "inan" then
			animacy = "in"
		end
		if base.gender == "MF" then
			m_table.insertIfNot(genders, "m-" .. animacy .. number)
			m_table.insertIfNot(genders, "f-" .. animacy .. number)
		elseif base.gender == "M" then
			m_table.insertIfNot(genders, "m-" .. animacy .. number)
		elseif base.gender == "F" then
			m_table.insertIfNot(genders, "f-" .. animacy .. number)
		elseif base.gender == "N" then
			m_table.insertIfNot(genders, "n-" .. animacy .. number)
		else
			error("Internal error: Unrecognized gender '" ..
				(base.gender or "nil") .. "'")
		end
	end)
	return genders
end


local stem_expl = {
	["hard"] = "a hard consonant",
	["velar-stem"] = "a velar (-к, -г or -х)",
	["soft"] = "a soft consonant",
	["n-stem"] = "-м (with -ен- or -ён- in some forms)",
	["t-stem"] = "-я or -а (with -т- or -ц- in most forms)",
	["possessive"] = "-ов, -ав, -ев, -ёв, -ін or -ын",
	["surname"] = "-ов, -ав, -ев, -ёв, -ін or -ын",
}

local stem_to_declension = {
	["hard third-declension"] = "third",
	["soft third-declension"] = "third",
	["fourth-declension"] = "fourth",
	["t-stem"] = "fourth",
	["n-stem"] = "fourth",
}

local stem_gender_endings = {
    masculine = {
		["hard"]              = {"a hard consonant", "-ы"},
		["velar-stem"]        = {"a velar", "-і"},
		["soft"]              = {"-ь", "-і"},
	},
    feminine = {
		["hard"]              = {"-а", "-ы"},
		["velar-stem"]        = {"a velar", "-і"},
		["soft"]              = {"-я", "-і"},
		["hard third-declension"]  = {"-р or a hushing consonant", "-ы"},
		["soft third-declension"]  = {"-ь or -ў", "-і"},
	},
    neuter = {
		["hard"]              = {"-а or -о", "-ы"},
		["velar-stem"]        = {"-а or -о", "-і"},
		["soft"]              = {"-е or -ё", "-і"},
		["fourth-declension"] = {"-я", "-і"},
		["t-stem"]            = {"-я or -а", "-ты"},
		["n-stem"]            = {"-я", "-ёны"},
	},
}

local vowel_alternation_expl = {
	["а-е"] = "unstressed -а- in the lemma and stressed -э- in some remaining forms, or unstressed -я- in the lemma and stressed or unstressed -е- in some remaining forms",
	["а-о"] = "unstressed -а- in the lemma and stressed -о- in some remaining forms, or unstressed -я- in the lemma and stressed -ё- in some remaining forms",
	["а-во"] = "unstressed (usually word-initial) а- in the lemma and stressed во- in some remaining forms",
	["во-а"] = "stressed (usually word-initial) во- in the lemma and unstressed а- in some remaining forms",
	["о-ы"] = "stressed -о- in the lemma and unstressed -ы- in some remaining forms",
	["ы-о"] = "unstressed -ы- in the lemma and stressed -о- in some remaining forms",
}

-- Implementation of template 'be-noun cat'.
function export.catboiler(frame)
	local SUBPAGENAME = mw.title.getCurrentTitle().subpageText
	local params = {
		[1] = {},
	}
	local args = m_para.process(frame:getParent().args, params)

	local function get_stem_gender_text(stem, genderspec)
		local gender = genderspec
		gender = rsub(gender, " in %-[ао]$", "")
		if not stem_gender_endings[gender] then
			error("Invalid gender '" .. gender .. "'")
		end
		local endings = stem_gender_endings[gender][stem]
		if not endings then
			error("Invalid stem type '" .. stem .. "'")
		end
		local sgending, plending = endings[1], endings[2]
		local stemtext = stem_expl[stem] and " The stem ends in " .. stem_expl[stem] .. "." or ""
		local decltext =
			rfind(stem, "declension") and "" or
			" This is traditionally considered to belong to the " .. (
				stem_to_declension[stem] or gender == "feminine" and "first" or "second"
			) .. " declension."
		local genderdesc
		if rfind(genderspec, "in %-[ао]$") then
			genderdesc = rsub(genderspec, "in (%-[ао])$", "~ ending in %1")
		else
			genderdesc = "usually " .. gender .. " ~"
		end
		return stem .. ", " .. genderdesc .. ", normally ending in " .. sgending .. " in the nominative singular " ..
			" and " .. plending .. " in the nominative plural." .. stemtext .. decltext
	end

	local function get_pos()
		local pos = rmatch(SUBPAGENAME, "^Belarusian.- ([^ ]*)s ")
		if not pos then
			pos = rmatch(SUBPAGENAME, "^Belarusian.- ([^ ]*)s$")
		end
		if not pos then
			error("Invalid category name, should be e.g. \"Belarusian nouns with ...\" or \"Belarusian ... nouns\"")
		end
		return pos
	end

	local function get_sort_key()
		local pos, sort_key = rmatch(SUBPAGENAME, "^Belarusian.- ([^ ]*)s with (.*)$")
		if sort_key then
			return sort_key
		end
		pos, sort_key = rmatch(SUBPAGENAME, "^Belarusian ([^ ]*)s (.*)$")
		if sort_key then
			return sort_key
		end
		return rsub(SUBPAGENAME, "^Belarusian ", "")
	end

	local cats = {}, pos

	-- Insert the category CAT (a string) into the categories. String will
	-- have "Belarusian " prepended and ~ substituted for the plural part of speech.
	local function insert(cat, atbeg)
		local fullcat = "Belarusian " .. rsub(cat, "~", pos .. "s")
		if atbeg then
			table.insert(cats, 1, fullcat)
		else
			table.insert(cats, fullcat)
		end
	end

	local maintext
	local stem, gender, stress, ending
	while true do
		if args[1] then
			maintext = "~ " .. args[1]
			pos = get_pos()
			break
		end
		-- First group is .* to capture e.g. "hard third-declension".
		stem, gender, stress, pos = rmatch(SUBPAGENAME, "^Belarusian (.*) (.-)%-form accent%-(.-) (.*)s$")
		if not stem then
			-- check for e.g. 'Belarusian hard masculine accent-a nouns in -а'
			stem, gender, stress, pos, ending = rmatch(SUBPAGENAME, "^Belarusian (.-) ([a-z]+ine) accent%-(.-) (.*)s in %-([ао])$")
			if stem then
				gender = gender .. " in -" .. ending
			end
		end
		if stem then
			local stem_gender_text = get_stem_gender_text(stem, gender)
			local accent_text = " This " .. pos .. " is stressed according to accent pattern " ..
				rsub(stress, "'", "&#39;") .. " (see [[Template:be-ndecl]])."
			maintext = stem_gender_text .. accent_text
			insert("~ by stem type, gender and accent pattern|" .. get_sort_key())
			break
		end
		pos = rmatch(SUBPAGENAME, "^Belarusian indeclinable (.*)s$")
		if pos then
			maintext = "indeclinable ~, which normally have the same form for all cases and numbers."
			break
		end
		-- First group is .* to capture e.g. "hard third-declension".
		stem, gender, pos = rmatch(SUBPAGENAME, "^Belarusian (.*) (.-)%-form (.*)s$")
		if not stem then
			-- check for e.g. 'Belarusian hard masculine nouns in -а'
			stem, gender, pos, ending = rmatch(SUBPAGENAME, "^Belarusian (.-) ([a-z]+ine) (.*)s in %-([ао])$")
			if stem then
				gender = gender .. " in -" .. ending
			end
		end
		if stem then
			maintext = get_stem_gender_text(stem, gender)
			insert("~ by stem type and gender|" .. get_sort_key())
			break
		end
		stem, gender, stress, pos = rmatch(SUBPAGENAME, "^Belarusian (.*) (.-) adjectival accent%-(.-) (.*)s$")
		if not stem then
			stem, gender, pos = rmatch(SUBPAGENAME, "^Belarusian (.*) (.-) adjectival (.*)s$")
		end
		if stem then
			local adj_decl_endings = require("Module:be-adjective").adj_decl_endings
			if not stem_expl[stem] then
				error("Invalid stem type '" .. stem .. "'")
			end
			local stemtext = " The stem ends in " .. stem_expl[stem] .. "."
			local stresstext = stress == "a" and
				"This " .. pos .. " is stressed according to accent pattern a (stress on the stem)." or
				stress == "b" and
				"This " .. pos .. " is stressed according to accent pattern b (stress on the ending)." or
				"All ~ of this class are stressed according to accent pattern a (stress on the stem)."
			local stemspec
			if stem == "hard" then
				stemspec = stress == "a" and "hard stem-stressed" or "hard ending-stressed"
			else
				stemspec = stem
			end
			local endings = adj_decl_endings[stemspec]
			if not endings then
				error("Invalid stem spec '" .. stem .. "'")
			end
			local m, f, n, pl = unpack(endings)
			local sg =
				gender == "masculine" and m or
				gender == "feminine" and f or
				gender == "neuter" and n or
				nil
			maintext = stem .. " " .. gender .. " ~, with adjectival endings, ending in " ..
				(sg and sg .. " in the nominative singular and " or "") ..
				pl .. " in the nominative plural." .. stemtext .. " " .. stresstext
			insert("~ by stem type, gender and accent pattern|" .. get_sort_key())
			break
		end
		local stress
		pos, stress = rmatch(SUBPAGENAME, "^Belarusian (.*)s with accent pattern (.*)$")
		if stress then
			maintext = "~ with accent pattern " .. rsub(stress, "'", "&#39;") ..
				" (see [[Template:be-ndecl]])."
			insert("~ by accent pattern|" .. stress)
			break
		end
		local alternation
		pos, alternation = rmatch(SUBPAGENAME, "^Belarusian (.*)s with (.*%-.*) alternation$")
		if alternation then
			if not vowel_alternation_expl[alternation] then
				error("Invalid vowel alternation '" .. alternation .. "'")
			end
			maintext = "~ with vowel alternation between " .. vowel_alternation_expl[alternation] .. "."
			insert("~ by vowel alternation|" .. alternation)
			break
		end
		error("Unrecognized Belarusian noun category name")
	end

	insert("~|" .. get_sort_key(), "at beginning")

	local categories = {}
	for _, cat in ipairs(cats) do
		table.insert(categories, "[[Category:" .. cat .. "]]")
	end

	return "This category contains Belarusian " .. rsub(maintext, "~", pos .. "s")
		.. "\n" ..
		mw.getCurrentFrame():expandTemplate{title="be-categoryTOC", args={}}
		.. table.concat(categories, "")
end

-- Externally callable function to parse and decline a noun given user-specified arguments.
-- Return value is WORD_SPEC, an object where the declined forms are in `WORD_SPEC.forms`
-- for each slot. If there are no values for a slot, the slot key will be missing. The value
-- for a given slot is a list of objects {form=FORM, footnotes=FOOTNOTES}.
function export.do_generate_forms(parent_args, pos, from_headword, def)
	local params = {
		[1] = {required = true, default = "чало́<ao>"},
		footnote = {list = true},
		title = {},
	}

	if from_headword then
		params["lemma"] = {list = true}
		params["g"] = {list = true}
		params["f"] = {list = true}
		params["m"] = {list = true}
		params["adj"] = {list = true}
		params["dim"] = {list = true}
		params["id"] = {}
	end

	local args = m_para.process(parent_args, params)
	local alternant_multiword_spec = iut.parse_alternant_multiword_spec(args[1], parse_indicator_spec)
	alternant_multiword_spec.title = args.title
	alternant_multiword_spec.footnotes = args.footnote
	alternant_multiword_spec.args = args
	normalize_all_lemmas(alternant_multiword_spec)
	detect_all_indicator_specs(alternant_multiword_spec)
	propagate_properties(alternant_multiword_spec, "animacy", "inan", "mixed")
	propagate_properties(alternant_multiword_spec, "number", "both", "both")
	-- The default of "M" should apply only to plural adjectives, where it doesn't matter.
	propagate_properties(alternant_multiword_spec, "gender", "M", "mixed")
	determine_noun_status(alternant_multiword_spec)
	local decline_props = {
		skip_slot = function(slot)
			return skip_slot(alternant_multiword_spec.number, slot)
		end,
		slot_table = output_noun_slots_with_linked,
		get_variants = com.get_variants,
		decline_word_spec = decline_noun,
	}
	iut.decline_multiword_or_alternant_multiword_spec(alternant_multiword_spec, decline_props)
	compute_categories_and_annotation(alternant_multiword_spec)
	alternant_multiword_spec.genders = compute_headword_genders(alternant_multiword_spec)
	return alternant_multiword_spec
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
		params[1] = {required = true, default = "бог"}
		params[2] = {required = true, default = "багі́"}
		params[3] = {required = true, default = "бо́га"}
		params[4] = {required = true, default = "баго́ў"}
		params[5] = {required = true, default = "бо́гу"}
		params[6] = {required = true, default = "бага́м"}
		params[7] = {required = true, default = "бо́га"}
		params[8] = {required = true, default = "баго́ў"}
		params[9] = {required = true, default = "бо́гам"}
		params[10] = {required = true, default = "бага́мі"}
		params[11] = {required = true, default = "бо́дзе"}
		params[12] = {required = true, default = "бага́х"}
		params[14] = {}
		if NAMESPACE == "Template" then
			params[13] = {default = "бо́жа"}
			params["count"] = {default = "бо́гі"}
		else
			params[13] = {}
			params["count"] = {}
		end			
	elseif number == "sg" then
		params[1] = {required = true, default = "кроў"}
		params[2] = {required = true, default = "крыві́"}
		params[3] = {required = true, default = "крыві́"}
		params[4] = {required = true, default = "кроў"}
		params[5] = {required = true, default = "кро́ўю, крывёй"}
		params[6] = {required = true, default = "крыві́"}
		params[7] = {}
	else
		params[1] = {required = true, default = "дзве́ры"}
		params[2] = {required = true, default = "дзвярэ́й"}
		params[3] = {required = true, default = "дзвяра́м"}
		params[4] = {required = true, default = "дзве́ры"}
		params[5] = {required = true, default = "дзвяра́мі, дзвяры́ма, дзвярмі́"}
		params[6] = {required = true, default = "дзвяра́х"}
		params[7] = {}
		params["count"] = {}
	end


	local args = m_para.process(parent_args, params)
	local alternant_spec = {
		title = args.title,
		footnotes = args.footnote,
		forms = {},
		number = number,
		manual = true,
	}
	process_manual_overrides(alternant_spec.forms, args, alternant_spec.number, args.unknown_stress)
	compute_categories_and_annotation(alternant_spec)
	return alternant_spec
end


-- Entry point for {{be-ndecl}}. Template-callable function to parse and decline a noun given
-- user-specified arguments and generate a displayable table of the declined forms.
function export.show(frame)
	local parent_args = frame:getParent().args
	local alternant_multiword_spec = export.do_generate_forms(parent_args)
	show_forms(alternant_multiword_spec)
	return make_table(alternant_multiword_spec) .. require("Module:utilities").format_categories(alternant_multiword_spec.categories, lang)
end


-- Entry point for {{be-ndecl-manual}}, {{be-ndecl-manual-sg}} and {{be-ndecl-manual-pl}}.
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
-- additional properties (currently, g= for headword genders). This is for use by bots.
local function concat_forms(alternant_spec, include_props)
	local ins_text = {}
	for slot, _ in pairs(output_noun_slots_with_linked) do
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
-- the forms as a string "SLOT=FORM,FORM,...|SLOT=FORM,FORM,...|...". Embedded pipe symbols (as might
-- occur in embedded links) are converted to <!>. If |include_props=1 is given, also include
-- additional properties (currently, none). This is for use by bots.
function export.generate_forms(frame)
	local include_props = frame.args["include_props"]
	local parent_args = frame:getParent().args
	local alternant_spec = export.do_generate_forms(parent_args)
	return concat_forms(alternant_spec, include_props)
end

--[=[

Example of use:

{{subst:be-nazdecl|НВ вяхі́р, вехіра́, вехіру́, вехіро́м, вехіры́; мн. НВ вехіры́, вехіро́ў, вехіра́м, вехіра́мі, вехіра́х}}
{{subst:be-nazdecl|НВ бяскра́йнасць, РДМ бяскра́йнасці, бяскра́йнасцю}}

]=]
function export.nazdecl(frame)
	local params = {
		[1] = {required = true}
	}
	local parargs = frame:getParent().args
	local args = require("Module:parameters").process(parargs, params)
	local forms = args[1]
	local function get_orig()
		return "original follows: {{temp|be-nazdecl|" .. args[1] .. "}}"
	end
	local function normalize_caseform(caseform)
		-- Check for cases like "сіні́цай (-аю)". In such a situation,
		-- try to match the first letter of the suffix with the last
		-- occurrence of the same letter in the base form.
		local form, suffix = rmatch(caseform, "(.-) %(%-(.*)%)$")
		if form then
			local firstletter = usub(suffix, 1, 1)
			for i=ulen(form),1,-1 do
				if usub(form, i, i) == firstletter then
					return form .. ", " .. usub(form, 1, i - 1) .. suffix
				end
			end
			return form .. ", " .. form .. suffix
		end
		return rsub(caseform, " %((.-)%)", ", %1")
	end
	local function process_sg_or_pl(forms_to_parse)
		forms_to_parse = rsplit(forms_to_parse, " *, *")
		local slots = {
			["Н"] = 1,
			["Р"] = 2,
			["Д"] = 3,
			["В"] = 4,
			["Т"] = 5,
			["М"] = 6,
		}
		local forms = {}
		for _, form in ipairs(forms_to_parse) do
			if rfind(form, "^[НВРДТМ]+ ") then
				local cases, caseform = rmatch(form, "^([НВРДТМ]+) (.*)$")
				for _, case in ipairs(rsplit(cases, "")) do
					-- assert(not forms[slots[case]])
					forms[slots[case]] = normalize_caseform(caseform)
				end
			else
				for i=1,6 do
					if not forms[i] then
						forms[i] = normalize_caseform(form)
						break
					end
				end
			end
		end
		return forms
	end
	if rfind(forms, ";") then
		local sg_and_pl = rsplit(forms, " *; *")
		if #sg_and_pl ~= 2 then
			return "Saw too many semicolons, expected only one; " .. get_orig()
		end
		local sg, pl = unpack(sg_and_pl)
		pl = rsub(pl, "^мн%. *", "")
		sg = process_sg_or_pl(sg)
		pl = process_sg_or_pl(pl)
		local parts = {}
		table.insert(parts, "{{be-decl-noun\n")
		for i=1,6 do
			if not sg[i] then
				return "Not enough singular parts; " .. get_orig()
			elseif not pl[i] then
				return "Not enough plural parts; " .. get_orig()
			end
			table.insert(parts, "|" .. sg[i] .. "|" .. pl[i] .. "\n")
		end
		table.insert(parts, "}}")
		return table.concat(parts)
	else
		local sg = process_sg_or_pl(forms)
		for i=1,6 do
			if not sg[i] then
				return "Not enough parts; " .. get_orig()
			end
		end
		return "{{be-decl-noun-unc|" .. table.concat(sg, "|") .. "}}"
	end
end

return export
