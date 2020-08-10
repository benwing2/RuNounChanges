local export = {}


--[=[

Authorship: Ben Wing <benwing2>

]=]

--[=[

TERMINOLOGY:

-- "slot" = A particular combination of case/number.
	 Example slot names for nouns are "nom_s" (nominative singular) and
	 "voc_p" (vocative plural). Each slot is filled with zero or more forms.

-- "form" = The declined Hindi form representing the value of a given slot.

-- "lemma" = The dictionary form of a given Hindi term. Generally the nominative
     masculine singular, but may occasionally be another form if the nominative
	 masculine singular is missing.
]=]

local lang = require("Module:languages").getByCode("hi")
local m_table = require("Module:table")
local m_links = require("Module:links")
local m_string_utilities = require("Module:string utilities")
local iut = require("Module:inflection utilities")
local m_para = require("Module:parameters")
local com = require("Module:hi-common")
local m_hi_translit = require("Module:hi-translit")

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

-- vowel diacritics; don't display nicely on their own
local M = u(0x0901)
local N = u(0x0902)
local H = u(0x0903)
local AA = u(0x093e)
local E = u(0x0947)
local EN = E .. N
local I = u(0x093f)
local II = u(0x0940)
local O = u(0x094b)
local ON = O .. N
local U = u(0x0941)
local UU = u(0x0942)

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
	obl_s = "obl|s",
	voc_s = "voc|s",
	nom_p = "nom|p",
	obl_p = "obl|p",
	voc_p = "voc|p",
}


local noun_slots_with_linked = m_table.shallowcopy(output_noun_slots)
noun_slots_with_linked["nom_s_linked"] = "nom|s"
noun_slots_with_linked["nom_p_linked"] = "nom|p"

local input_params_to_slots_both = {
	[1] = "nom_s",
	[2] = "nom_p",
	[3] = "obl_s",
	[4] = "obl_p",
	[5] = "voc_s",
	[6] = "voc_p",
}


local input_params_to_slots_sg = {
	[1] = "nom_s",
	[2] = "obl_s",
	[3] = "voc_s",
}


local input_params_to_slots_pl = {
	[1] = "nom_p",
	[2] = "obl_p",
	[3] = "voc_p",
}


local cases = {
	nom = true,
	obl = true,
	voc = true,
}


local function skip_slot(number, slot)
	return number == "sg" and rfind(slot, "_p$") or
		number == "pl" and rfind(slot, "_s$")
end


local function combine_stem_ending(stem, ending)
	return stem .. ending
end


local function add(base, stem, phon_stem, ending, footnotes)
	if not ending then
		return
	end
	if skip_slot(base.number, slot) then
		return
	end
	footnotes = iut.combine_footnotes(base.footnotes, footnotes)
	ending = iut.generate_form(ending, footnotes)
	if phon_stem and stem ~= phon_stem then
		stem = {form = stem, translit = lang:transliterate(phon_stem)}
	end
	iut.add_forms(base.forms, slot, stem, ending, combine_stem_ending, lang,
		combine_stem_ending)
end


local function process_slot_overrides(base)
	for slot, overrides in pairs(base.overrides) do
		if skip_slot(base.number, slot) then
			error("Override specified for invalid slot '" .. slot .. "' due to '" .. base.number .. "' number restriction")
		end
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
					for _, stress in ipairs(base.stresses) do
						add(base, slot, stress, form, combined_notes)
					end
				end
			end
		end
	end
end


local function add_decl(base, nom_s, obl_s, voc_s, nom_p, obl_p, voc_p,
	footnotes
)
	local stem, phon_stem
	if type(base) == "table" then
		base, stem, phon_stem = unpack(base)
	else
		stem = base.stem
		phon_stem = base.phon_stem
	end
	add(base, stem, phon_stem, "nom_s", nom_s, footnotes)
	add(base, stem, phon_stem, "obl_s", obl_s, footnotes)
	add(base, stem, phon_stem, "voc_s", voc_s, footnotes)
	add(base, stem, phon_stem, "nom_p", nom_p, footnotes)
	add(base, stem, phon_stem, "obl_p", obl_p, footnotes)
	add(base, stem, phon_stem, "voc_p", voc_p, footnotes)
end


local function handle_derived_slots_and_overrides(base)
	process_slot_overrides(base)

	-- Compute linked versions of potential lemma slots, for use in {{hi-noun}}.
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

decls["c-m"] = function(base)
	add_decl(base, "", "", "", "", ON, O)
end

decls["c-f"] = function(base)
	add_decl(base, "", "", "", EN, ON, O)
end

decls["a-m"] = function(base)
	add_decl(base, "", "", "", "", ON, O)
end

decls["ā-m"] = function(base)
	local stem, phon_stem = strip_ending(base, AA)
	add_decl({base, stem, phon_stem}, AA, E, E, E, ON, O)
end

-- E.g. तेंदुआ "leopard"
decls["ind-ā-m"] = function(base)
	local stem, phon_stem = strip_ending(base, "आ")
	add_decl({base, stem, phon_stem}, "आ", "ए", "ए", "ए", "ओं", "ओ")
end

decls["unmarked-ā-m"] = function(base)
	add_decl(base, "", "", "", "", "ओं", "ओ")
end

-- E.g. ख़ानसामाँ "butler, cook"
decls["ān-m"] = function(base)
	local stem, phon_stem = strip_ending(base, AA .. M)
	add_decl({base, stem, phon_stem}, AA .. M, EN, EN, EN, ON, EN)
end

-- E.g. कुआँ "well"
decls["ind-ān-m"] = function(base)
	local stem, phon_stem = strip_ending(base, "आँ")
	add_decl({base, stem, phon_stem}, "आँ", "एँ", "एँ", "एँ", "ओं", "ओं")
end

decls["ā-f"] = function(base)
	add_decl(base, "", "", "", "एँ", "ओं", "ओ")
end

decls["i-m"] = function(base)
	add_decl(base, "", "", "", "", "यों", "यो")
end

decls["i-f"] = function(base)
	add_decl(base, "", "", "", "याँ", "यों", "यो")
end

-- E.g. प्रधान मंत्री "prime minister"
decls["ī-m"] = function(base)
	local stem, phon_stem = strip_ending(base, II)
	add({base, stem, phon_stem}, II, II, II, II, I .. "यों", I .. "यो")
end

-- E.g. भाई "brother"
decls["ind-ī-m"] = function(base)
	local stem, phon_stem = strip_ending(base, "ई")
	add({base, stem, phon_stem}, "ई", "ई", "ई", "ई", "इयों", "इयो")
end

decls["ī-f"] = function(base)
	local stem, phon_stem = strip_ending(base, II)
	add({base, stem, phon_stem}, II, II, II, I .. "याँ", I .. "यों", I .. "यो")
end

-- E.g. दवाई "medicine", डोई "wooden ladle", तेंदुई "female leopard", मिठाई "sweet, dessert"
decls["ind-ī-f"] = function(base)
	local stem, phon_stem = strip_ending(base, "ई")
	add({base, stem, phon_stem}, "ई", "ई", "ई", "इयाँ", "इयों", "इयो")
end

decls["iyā-f"] = function(base)
	local stem, phon_stem = strip_ending(base, "या")
	add_decl({base, stem, phon_stem}, "या ", "या ", "या ", "याँ", "यों", "यो")
end

decls["o-m"] = function(base)
	local stem, phon_stem = strip_ending(base, O)
	add_decl({base, stem, phon_stem}, O, O, O, O, ON, O)
end

decls["u-m"] = function(base)
	add_decl(base, "", "", "", "", "ओं", "ओ")
end

decls["u-f"] = function(base)
	add_decl(base, "", "", "", "एँ", "ओं", "ओ")
end

decls["ū-m"] = function(base)
	local stem, phon_stem = strip_ending(base, UU)
	add_decl({base, stem, phon_stem}, UU, UU, UU, UU, U .. "ओं", U .. "ओ")
end

decls["ū-f"] = function(base)
	add_decl(base, "", "", "", "एँ", "ओं", "ओ")
end

decls["r-m"] = function(base)
	add_decl(base, "", "", "", "", "ओं", "ओ")
end

-- E.g. प्रातः "morning"
decls["h-m"] = function(base)
	local stem, phon_stem = strip_ending(base, H)
	add_decl(base, H, H, H, H, ON, O)
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
	else
		error("Internal error: unrecognized case in override: '" .. table.concat(segments) .. "'")
	end
	local rest = usub(part, offset)
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
			value.form = m_hi_translit.reverse_tr(form)
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
  explicit_gender = "GENDER", -- "M", "F"; may be missing
  number = "NUMBER", -- "sg", "pl"; may be missing
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
			if cases[case_prefix] then
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
			elseif part == "M" or part == "F" then
				if base.explicit_gender then
					error("Can't specify gender twice: '" .. inside .. "'")
				end
				base.explicit_gender = part
			elseif part == "sg" or part == "pl" then
				if base.number then
					error("Can't specify number twice: '" .. inside .. "'")
				end
				base.number = part
			elseif part == "unmarked" then
				if base.unmarked then
					error("Can't specify 'unmarked' twice: '" .. inside .. "'")
				end
				base.unmarked = true
			elseif part == "iyā" then
				if base.iya then
					error("Can't specify 'iyā' twice: '" .. inside .. "'")
				end
				base.iya = true
			else
				error("Unrecognized indicator '" .. part .. "': '" .. inside .. "'")
			end
		end
	end
	return base
end


local function set_defaults_and_check_bad_indicators(base)
	-- Set default values.
	if not base.adj then
		base.number = base.number or "both"
	end
	base.gender = base.explicit_gender
	base.decl = base.explicit_decl
	if base.decl == "iyā" then
		if base.gender == "M" then
			error("Can't specify M gender with 'iyā' declension")
		end
		if not rfind(base.lemma, I .. "या") then
			error("With 'iyā' declension, lemma must end in " .. I .. "या: " .. base.lemma)
		end
		base.gender = "F"
	elseif base.decl == "ā-ā" then
		if base.gender == "F" then
			error("Can't specify F gender with 'ā-ā' declension")
		end
		if not rfind(base.lemma, AA) then
			error("With 'ā-ā' declension, lemma must end in " .. AA .. ": " .. base.lemma)
		end
		base.gender = "M"
	elseif rfind(base.lemma, O .. "$") then
		if base.gender == "F" then
			error("Can't specify F gender with lemma ending in " .. O .. ": " .. base.lemma)
		end
		base.gender = "M"
	elseif not base.gender then
		error("Unless lemma is in " .. O .. " or explicit declension given, gender must be given: " .. base.lemma)
	end
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


-- Determine the declension based on the lemma and whatever gender has been already given,
-- and set the gender to a default if not given. The declension is set in base.decl.
-- In the process, we set either base.vowel_stem (if the lemma ends in a vowel) or
-- base.nonvowel_stem (if the lemma does not end in a vowel), which is used by
-- determine_stress_and_stems().
local function determine_declension_and_gender(base)
	if base.decl then
		return
	end
	if base.gender == "M" then
		if rfind(base.lemma, AA .. "$") then
			if base.unmarked then
				base.decl = "unmarked-ā-m"
			else
				base.decl = "ā-m"
			end
		elseif rfind(base.lemma, "आँ") then
			base.decl = "ān-m"
		else
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
		m_table.insertIfNot(cats, "Hindi " .. cattype)
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
!style="background:#eff7ff"|oblique
| {obl_s}
| {obl_p}
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
!style="background:#eff7ff"|oblique
| {obl_s}
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
!style="background:#eff7ff"|oblique
| {obl_p}
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

	if alternant_multiword_spec.title then
		forms.title = alternant_multiword_spec.title
	else
		forms.title = 'Declension of <i lang="hi" class="Deva">' .. forms.lemma .. '</i>'
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

-- Implementation of template 'hi-noun cat'.
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
		local pos = rmatch(SUBPAGENAME, "^Hindi.- ([^ ]*)s ")
		if not pos then
			pos = rmatch(SUBPAGENAME, "^Hindi.- ([^ ]*)s$")
		end
		if not pos then
			error("Invalid category name, should be e.g. \"Hindi nouns with ...\" or \"Hindi ... nouns\"")
		end
		return pos
	end

	local function get_sort_key()
		local pos, sort_key = rmatch(SUBPAGENAME, "^Hindi.- ([^ ]*)s with (.*)$")
		if sort_key then
			return sort_key
		end
		pos, sort_key = rmatch(SUBPAGENAME, "^Hindi ([^ ]*)s (.*)$")
		if sort_key then
			return sort_key
		end
		return rsub(SUBPAGENAME, "^Hindi ", "")
	end

	local cats = {}, pos

	-- Insert the category CAT (a string) into the categories. String will
	-- have "Hindi " prepended and ~ substituted for the plural part of speech.
	local function insert(cat, atbeg)
		local fullcat = "Hindi " .. rsub(cat, "~", pos .. "s")
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
		stem, gender, stress, pos = rmatch(SUBPAGENAME, "^Hindi (.*) (.-)%-form accent%-(.-) (.*)s$")
		if not stem then
			-- check for e.g. 'Hindi hard masculine accent-a nouns in -а'
			stem, gender, stress, pos, ending = rmatch(SUBPAGENAME, "^Hindi (.-) ([a-z]+ine) accent%-(.-) (.*)s in %-([ао])$")
			if stem then
				gender = gender .. " in -" .. ending
			end
		end
		if stem then
			local stem_gender_text = get_stem_gender_text(stem, gender)
			local accent_text = " This " .. pos .. " is stressed according to accent pattern " ..
				rsub(stress, "'", "&#39;") .. " (see [[Template:hi-ndecl]])."
			maintext = stem_gender_text .. accent_text
			insert("~ by stem type, gender and accent pattern|" .. get_sort_key())
			break
		end
		pos = rmatch(SUBPAGENAME, "^Hindi indeclinable (.*)s$")
		if pos then
			maintext = "indeclinable ~, which normally have the same form for all cases and numbers."
			break
		end
		-- First group is .* to capture e.g. "hard third-declension".
		stem, gender, pos = rmatch(SUBPAGENAME, "^Hindi (.*) (.-)%-form (.*)s$")
		if not stem then
			-- check for e.g. 'Hindi hard masculine nouns in -а'
			stem, gender, pos, ending = rmatch(SUBPAGENAME, "^Hindi (.-) ([a-z]+ine) (.*)s in %-([ао])$")
			if stem then
				gender = gender .. " in -" .. ending
			end
		end
		if stem then
			maintext = get_stem_gender_text(stem, gender)
			insert("~ by stem type and gender|" .. get_sort_key())
			break
		end
		stem, gender, stress, pos = rmatch(SUBPAGENAME, "^Hindi (.*) (.-) adjectival accent%-(.-) (.*)s$")
		if not stem then
			stem, gender, pos = rmatch(SUBPAGENAME, "^Hindi (.*) (.-) adjectival (.*)s$")
		end
		if stem then
			local adj_decl_endings = require("Module:hi-adjective").adj_decl_endings
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
		pos, stress = rmatch(SUBPAGENAME, "^Hindi (.*)s with accent pattern (.*)$")
		if stress then
			maintext = "~ with accent pattern " .. rsub(stress, "'", "&#39;") ..
				" (see [[Template:hi-ndecl]])."
			insert("~ by accent pattern|" .. stress)
			break
		end
		local alternation
		pos, alternation = rmatch(SUBPAGENAME, "^Hindi (.*)s with (.*%-.*) alternation$")
		if alternation then
			if not vowel_alternation_expl[alternation] then
				error("Invalid vowel alternation '" .. alternation .. "'")
			end
			maintext = "~ with vowel alternation between " .. vowel_alternation_expl[alternation] .. "."
			insert("~ by vowel alternation|" .. alternation)
			break
		end
		error("Unrecognized Hindi noun category name")
	end

	insert("~|" .. get_sort_key(), "at beginning")

	local categories = {}
	for _, cat in ipairs(cats) do
		table.insert(categories, "[[Category:" .. cat .. "]]")
	end

	return "This category contains Hindi " .. rsub(maintext, "~", pos .. "s")
		.. "\n" ..
		mw.getCurrentFrame():expandTemplate{title="hi-categoryTOC", args={}}
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


-- Entry point for {{hi-ndecl}}. Template-callable function to parse and decline a noun given
-- user-specified arguments and generate a displayable table of the declined forms.
function export.show(frame)
	local parent_args = frame:getParent().args
	local alternant_multiword_spec = export.do_generate_forms(parent_args)
	show_forms(alternant_multiword_spec)
	return make_table(alternant_multiword_spec) .. require("Module:utilities").format_categories(alternant_multiword_spec.categories, lang)
end


-- Entry point for {{hi-ndecl-manual}}, {{hi-ndecl-manual-sg}} and {{hi-ndecl-manual-pl}}.
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

return export
