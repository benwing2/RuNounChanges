local export = {}


--[=[

Authorship: Ben Wing <benwing2>

]=]

--[=[

TERMINOLOGY:

-- "slot" = A particular combination of case/number.
	 Example slot names for nouns are "gen_s" (genitive singular) and
	 "voc_p" (vocative plural). Each slot is filled with zero or more forms.

-- "form" = The declined Polish form representing the value of a given slot.

-- "lemma" = The dictionary form of a given Polish term. Generally the nominative
	 masculine singular, but may occasionally be another form if the nominative
	 masculine singular is missing.
]=]


--[=[

FIXME:

]=]

local lang = require("Module:languages").getByCode("pl")
local m_table = require("Module:table")
local m_links = require("Module:links")
local m_string_utilities = require("Module:string utilities")
local iut = require("Module:inflection utilities")
local parse_utilities_module = "Module:parse utilities"
local m_para = require("Module:parameters")
local com = require("Module:pl-common")

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

local force_cat = false -- set to true to make categories appear in non-mainspace pages, for testing

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


local function track(track_id)
	require("Module:debug/track")("pl-noun/" .. track_id)
	return true
end


local output_noun_slots = {
	nom_s = "nom|s",
	nom_s_linked = "nom|s",
	gen_s = "gen|s",
	gen_s_linked = "gen|s",
	clitic_gen_s = "clitic|gen|s",
	dat_s = "dat|s",
	clitic_dat_s = "clitic|dat|s",
	acc_s = "acc|s",
	clitic_acc_s = "clitic|acc|s",
	ins_s = "ins|s",
	loc_s = "loc|s",
	voc_s = "voc|s",
	nom_p = "nom|p",
	nom_p_depr = "deprecative|nom|p",
	nom_p_linked = "nom|p",
	gen_p = "gen|p",
	gen_p_fneut = "-",
	gen_p_fchar = "-",
	dat_p = "dat|p",
	acc_p = "acc|p",
	ins_p = "ins|p",
	loc_p = "loc|p",
	voc_p = "voc|p",
}


local function get_output_noun_slots(alternant_multiword_spec)
	-- FIXME: To save memory we modify the table in-place. This won't work if we ever end up with multiple calls to
	-- this module in the same Lua invocation, and we would need to clone the table.
	if alternant_multiword_spec.actual_number ~= "both" then
		for slot, accel_form in pairs(output_noun_slots) do
			output_noun_slots[slot] = accel_form:gsub("|[sp]$", "")
		end
	end
	return output_noun_slots
end


local potential_lemma_slots = {"nom_s", "nom_p", "gen_s"}


local cases = {
	nom = true,
	gen = true,
	dat = true,
	acc = true,
	ins = true,
	loc = true,
	voc = true,
}


local clitic_cases = {
	gen = true,
	dat = true,
	acc = true,
}


local function dereduce(base, stem)
	local dereduced_stem = com.dereduce(base, stem)
	if not dereduced_stem then
		error("Unable to dereduce stem '" .. stem .. "'")
	end
	return dereduced_stem
end


--[=[

Maybe modify the stem and/or ending in certain special cases:
1. Final -e in vocative singular triggers first palatalization of the stem in some cases (e.g. hard masc).
2. Endings beginning with ě, i, í trigger second palatalization, as does -e in the loc_s.

NOTE: Correctly handling -e vs. -ě and -tdn/-ťďň alternations is tricky. We have to deal with the following:
1. Soft-stem and t-stem neuters can have either -e or -ě. With coronals we have both [[poledne]] "noon" with /n/ and
   [[kutě]] "bed" with /ť/. We also have soft-stem neuter [[Labe]] with /b/ vs. t-stem neuter [[hříbě]] with /bj/.
2. Underlying palatal coronals maintain their nature before back vowels and when not followed by a vowel, e.g. [[štěně]]
   "puppy" becomes 'štěňata' in the nom/acc/voc plural and [[přítelkyně]] "girlfriend" becomes 'přítelkyň' in the gen
   plural, but underlying palatal labials become non-palatal, e.g. [[hříbě]] "foal" becomes 'hříbata' in the nom/acc/voc
   plural.
3. There are at least four types of endings beginning with '-e':
   a. "maintaining" endings, e.g. instrumental singular '-em', which do not change the nature of the consonant, e.g.
      [[zákon]] "law" becomes 'zákonem' while [[vězeň]] "prisoner" becomes 'vězeněm';
   b. "palatalizing" endings, e.g. locative singular '-e', which palatalizes t/d/n (and more generally applies the
      Slavic second palatalization, e.g. k -> c, r -> ř), e.g. [[žena]] "woman" becomes 'ženě';
   c. "depalatalizing" endings, e.g. feminine i-stem dative plural '-em', which actively depalatalize ť/ď/ň, e.g.
      [[oběť]] "sacrifice, victim" becomes 'obětem';
   d. vocative singular '-e' of hard-stem masculines, which applies the Slavic first palatalization in some
      circumstances (e.g. k -> č, Cr -> Cř, sometimes c -> č).
The way we handle this as follows:
1. We maintain the underlying stems always in their "pronounced" form, i.e. if the last consonant is pronounced ť/ď/ň
   we maintain the stem in that form, but if pronounced t/d/n, we use those consonants. Hence neuter [[poledne]] "noon"
   has stem 'poledn-' but neuter [[štěně]] "puppy" has stem 'štěň'. If the stem ends in labial + /j/, we use a special
   TEMP_SOFT_LABIAL character after the labial (rather than 'j', in case of stems that actually have a written 'j' in
   them such as [[banjo]]).
2. We signal types (a), (b) and (c) above using respectively 'e', 'ě' and 'E'. Type (d) uses 'e' and sets
   `base.palatalize_voc`.
3. In combine_stem_ending(), we convert the stem back to the written form before adding the ending. If the ending begins
   with -e, this may entail converting -e to -ě, and in all cases -E is converted to -e. "Converting to the written
   form" converts ť/ď/ň to plain equivalents and deletes TEMP_SOFT_LABIAL before -e, converting -e to -ě with such
   consonants. The same conversions happen before other front consonants -ě/-é/-i/-í, which don't allow ť/ď/ň to
   precede, and in all cases with TEMP_SOFT_LABIAL, which is not an actual consonant.
4. If the ending is specified using -ě, this is maintained after plain coronals and labials in combine_stem_ending(),
   and converted to -e in other cases.
5. Applying the first and second palatalization happens below in apply_special_cases().
]=]
local function apply_special_cases(base, slot, stem, ending)
	local palatalize_voc
	if base.c_as_k and rfind(ending, "^[aouyáóúůý]") then
		local k_stem = rsub(stem, "c$", "k")
		stem = {stem, k_stem}
	elseif slot == "voc_s" and ending == "e" and base.palatalize_voc and not base["-velar"] then
		-- Don't palatalize words like [[hadíth]] with silent -h.
		local palstem = com.apply_first_palatalization(stem)
		-- According to IJP, nouns ending in -Cr palatalize in the vocative, but those in -Vr don't. In reality,
		-- though, it's more complex. It appears that animate nouns in -Cr tend to palatalize but inanimate nouns
		-- do it optionally. Specifics:
		-- -- Inanimate nouns with optional palatalization (ř listed second): [[alabastr]], [[amfiteátr]], [[barometr]],
		--	[[centilitr]], [[centrimetr]], [[decilitr]], [[decimetr]], [[Dněstr]], [[filtr]], [[galvanometr]],
		--	[[hektolitr]], [[kalorimetr]], [[litr]], [[lustr]], [[manometr]], [[manšestr]], [[metr]] (NOTE: is both
		--	animate and inanimate), [[mikrometr]], [[miliampérmetr]], [[mililitr]], [[nanometr]], [[orchestr]],
		--	[[parametr]], [[piastr]], [[půllitr]], [[radiometr]], [[registr]], [[rotmistr]], [[semestr]], [[skútr]],
		--	[[spirometr]], [[svetr]], [[šutr]], [[tachometr]], [[titr]], [[vítr]] (NOTE: has í-ě alternation),
		--	[[voltmetr]]; [[bagr]], [[bunkr]], [[cedr]], [[Dněpr]], [[fofr]], [[habr]] (NOTE: ř listed first), [[hadr]]
		--	(NOTE: ř listed first), [[hamr]], [[kafr]], [[kepr]], [[kopr]], [[koriandr]], [[krekr]], [[kufr]],
		--	[[Kypr]], [[lágr]], [[lógr]], [[manévr]], [[masakr]], [[okr]], [[oleandr]], [[pulovr]], [[šlágr]],
		--	[[vichr]] (NOTE: ř listed first), [[žánr]]
		--
		-- -- Inanimate nouns that don't palatalize: [[ampérmetr]], [[anemometr]], [[sfygmomanometr]], [[sfygmometr]];
		--	[[dodekaedr]], [[Hamr]], [[ikozaedr]], [[kvádr]], [[sandr]], [[torr]]
		--
		-- -- Animate nouns that palatalize: [[arbitr]], [[bratr]], [[ekonometr]], [[foniatr]], [[fotr]], [[geometr]],
		--	[[kmotr]], [[lotr]], [[magistr]], [[metr]] (NOTE: is both animate and inanimate), [[ministr]], [[mistr]],
		--	[[pediatr]], [[Petr]], [[psychiatr]], [[purkmistr]], [[setr]], [[šamstr]]; [[bobr]], [[fajnšmekr]],
		--	[[humr]], [[hypochondr]], [[kapr]], [[lídr]], [[negr]], [[obr]], [[salamandr]], [[sólokapr]], [[švagr]],
		--	[[tygr]], [[zlobr]], [[zubr]]
		--
		-- -- Animate nouns with optional palatalization (ř listed first): [[Silvestr]]; [[Alexandr]], [[snajpr]]
		--
		-- Note the inconsistencies, e.g. [[sfygmomanometr]] and [[ampérmetr]] don't palatalize but [[manometr]] and
		-- [[miliampérmetr]] do it optionally. In reality, inanimate vocatives are extremely rare so this may not be the
		-- final word.
		if base.animacy == "inan" and rfind(stem, com.cons_c .. "r$") and not rfind(stem, "rr$") then
			-- optional r -> ř
			stem = {stem, palstem}
		else
			stem = palstem
		end
	elseif rfind(ending, "e") and (slot == "dat_s" or slot == "loc_s") then
		-- loc_s of hard masculines is sometimes -e with palatalization; the user might indicate this as -e, which we
		-- should handle correctly
		stem = com.soften_fem_dat_sg(stem)
		ending = ""
	end
	return stem, ending
end


local function skip_slot(number, slot)
	return number == "sg" and rfind(slot, "_p$") or
		number == "pl" and rfind(slot, "_s$")
end


-- Basic function to combine stem(s) and ending(s) and insert the result into the appropriate slot. `stems` is either
-- the `stems` object passed into the declension functions (containing the various stems; see below) or a string to
-- override the stem. (NOTE: If you pass a string in as `stems`, you should pass the value of `stems.footnotes` as the
-- value of `footnotes` as it will be lost otherwise. If you need to supply your own footnote in addition, use
-- iut.combine_footnotes() to combine any user-specified footnote(s) with your footnote(s).) `endings` is either a
-- string specifying a single ending or a list of endings. If `endings` is nil, no forms are inserted. If an ending is
-- "-", the value of `stems` is ignored and the lemma is used instead as the stem; this is important in case the user
-- used `decllemma:` to specify a declension lemma different from the actual lemma, or specified '.foreign' (which has
-- a similar effect).
local function add(base, slot, stems, endings, footnotes)
	if not endings then
		return
	end
	-- Call skip_slot() based on the declined number; if the actual number is different, we correct this in
	-- decline_noun() at the end.
	if skip_slot(base.number, slot) then
		return
	end
	local stems_footnotes = type(stems) == "table" and stems.footnotes or nil
	footnotes = iut.combine_footnotes(iut.combine_footnotes(base.footnotes, stems_footnotes), footnotes)
	if type(endings) == "string" then
		endings = {endings}
	end
	for _, ending in ipairs(endings) do
		-- Compute the stem. If ending is "-", use the lemma regardless. Otherwise if `stems` is a string, use it.
		-- Otherwise `stems` is an object containing four stems (vowel-vs-non-vowel cross regular-vs-oblique);
		-- compute the appropriate stem based on the slot and whether the ending begins with a vowel.
		local stem
		if ending == "-" then
			stem = base.actual_lemma
			ending = ""
		elseif type(stems) == "string" then
			stem = stems
		else
			local is_vowel_ending = rfind(ending, "^" .. com.vowel_c)
			if stems.oblique_slots == "all" or
				(stems.oblique_slots == "gen_p" or stems.oblique_slots == "all-oblique") and slot == "gen_p" or
				stems.oblique_slots == "all-oblique" and (slot == "ins_s" or slot == "dat_p" or slot == "ins_p" or slot == "loc_p") then
				if is_vowel_ending then
					stem = stems.oblique_vowel_stem
				else
					stem = stems.oblique_nonvowel_stem
				end
			elseif is_vowel_ending then
				stem = stems.vowel_stem
			else
				stem = stems.nonvowel_stem
			end
		end
		-- Maybe apply the first or second Slavic palatalization.
		stem, ending = apply_special_cases(base, slot, stem, ending)
		ending = iut.combine_form_and_footnotes(ending, footnotes)
		local function combine_stem_ending(stem, ending)
			return com.combine_stem_ending(base, slot, stem, ending)
		end
		iut.add_forms(base.forms, slot, stem, ending, combine_stem_ending)
	end
end


local function process_slot_overrides(base, do_slot)
	for slot, overrides in pairs(base.overrides) do
		-- Call skip_slot() based on the declined number; if the actual number is different, we correct this in
		-- decline_noun() at the end.
		if skip_slot(base.number, slot) then
			error("Override specified for invalid slot '" .. slot .. "' due to '" .. base.number .. "' number restriction")
		end
		if do_slot(slot) then
			base.slot_overridden[slot] = true
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
						-- Convert a null ending to "-" in the acc/voc sg slots so that e.g. [[Kerberos]] declared as
						-- <m.sg.foreign.gena:u.acc-:a> works correctly and generates accusative 'Kerberos/Kerbera' not
						-- #'Kerber/Kerbera'.
						if (slot == "acc_s" or slot == "voc_s") and form == "" then
							form = "-"
						end
						for _, stems in ipairs(base.stem_sets) do
							add(base, slot, stems, form, combined_notes)
						end
					end
				end
			end
		end
	end
end


local function add_decl(base, stems,
	gen_s, dat_s, acc_s, ins_s, loc_s, voc_s,
	nom_p, gen_p, dat_p, acc_p, ins_p, loc_p, footnotes
)
	add(base, "nom_s", stems, "-", footnotes)
	add(base, "gen_s", stems, gen_s, footnotes)
	add(base, "dat_s", stems, dat_s, footnotes)
	add(base, "acc_s", stems, acc_s, footnotes)
	add(base, "ins_s", stems, ins_s, footnotes)
	add(base, "loc_s", stems, loc_s, footnotes)
	add(base, "voc_s", stems, voc_s, footnotes)
	if base.number == "pl" then
		-- If this is a plurale tantum noun and we're processing the nominative plural, use the user-specified lemma
		-- rather than generating the plural from the synthesized singular, which may not match the specified lemma
		-- (e.g. [[tvargle]] "Olomouc cheese" using <m.pl.mixed> would try to generate 'tvargle/tvargly', and [[peníze]]
		-- "money" using <m.pl.#ě.genpl-> would try to generate 'peněze').
		local acc_p_like_nom = m_table.deepEquals(nom_p, acc_p)
		nom_p = "-"
		if acc_p_like_nom then
			acc_p = "-"
		end
	end
	add(base, "nom_p", stems, nom_p, footnotes)
	add(base, "gen_p", stems, gen_p, footnotes)
	add(base, "dat_p", stems, dat_p, footnotes)
	add(base, "acc_p", stems, acc_p, footnotes)
	add(base, "ins_p", stems, ins_p, footnotes)
	add(base, "loc_p", stems, loc_p, footnotes)
end

local function add_sg_decl(base, stems,
	gen_s, dat_s, acc_s, ins_s, loc_s, voc_s, footnotes
)
	add_decl(base, stems, gen_s, dat_s, acc_s, ins_s, loc_s, voc_s,
		nil, nil, nil, nil, nil, nil, footnotes)
end

local function add_pl_only_decl(base, stems,
	gen_p, dat_p, acc_p, ins_p, loc_p, footnotes
)
	add_decl(base, stems, nil, nil, nil, nil, nil, nil, 
		"-", gen_p, dat_p, acc_p, ins_p, loc_p, footnotes)
end

local function add_sg_decl_with_clitic(base, stems,
	gen_s, clitic_gen_s, dat_s, clitic_dat_s, acc_s, clitic_acc_s, ins_s, loc_s, voc_s, footnotes, no_nom_s
)
	if not no_nom_s then
		add(base, "nom_s", stems, "-", footnotes)
	end
	add(base, "gen_s", stems, gen_s, footnotes)
	add(base, "clitic_gen_s", stems, clitic_gen_s, footnotes)
	add(base, "dat_s", stems, dat_s, footnotes)
	add(base, "clitic_dat_s", stems, clitic_dat_s, footnotes)
	add(base, "acc_s", stems, acc_s, footnotes)
	add(base, "clitic_acc_s", stems, clitic_acc_s, footnotes)
	add(base, "ins_s", stems, ins_s, footnotes)
	add(base, "loc_s", stems, loc_s, footnotes)
	add(base, "voc_s", stems, voc_s, footnotes)
end


local function handle_derived_slots_and_overrides(base)
	local function is_non_derived_slot(slot)
		return slot ~= "voc_p" and slot ~= "acc_s" and slot ~= "clitic_acc_s"
	end

	local function is_derived_slot(slot)
		return not is_non_derived_slot(slot)
	end

	base.slot_overridden = {}
	-- Handle overrides for the non-derived slots. Do this before generating the derived
	-- slots so overrides of the source slots (e.g. nom_p) propagate to the derived slots.
	process_slot_overrides(base, is_non_derived_slot)

	-- Generate the remaining slots that are derived from other slots.
	if not base.pron and not base.det then
		-- Pronouns don't have a vocative (singular or plural).
		iut.insert_forms(base.forms, "voc_p", base.forms.nom_p)
	end
	if not base.forms.acc_s and not base.slot_overridden.acc_s then
		iut.insert_forms(base.forms, "acc_s", base.forms[base.animacy == "inan" and "nom_s" or "gen_s"])
	end
	if not base.forms.clitic_acc_s and not base.slot_overridden.clitic_acc_s then
		iut.insert_forms(base.forms, "clitic_acc_s", base.forms[base.animacy == "inan" and "nom_s" or "clitic_gen_s"])
	end

	-- Handle overrides for derived slots, to allow them to be overridden.
	process_slot_overrides(base, is_derived_slot)

	-- Compute linked versions of potential lemma slots, for use in {{pl-noun}}.
	-- We substitute the original lemma (before removing links) for forms that
	-- are the same as the lemma, if the original lemma has links.
	for _, slot in ipairs(potential_lemma_slots) do
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
Table mapping declension types to functions to decline the noun. The function takes two arguments, `base` and `stems`;
the latter specifies the computed stems (vowel vs. non-vowel, singular vs. plural) and whether the noun is reducible
and/or has vowel alternations in the stem. Most of the specifics of determining which stem to use and how to modify it
for the given ending are handled in add_decl() or functions called by it; the declension functions just need to generate
the appropriate endings. Specifically:

Alternations between -ś/-si, -ń/ni etc. handled in combine_stem_ending(); the stems in `stems` are in the
consonant-final state (using -ś/-ń/etc. and with soft labials stored with TEMP_SOFT_LABIAL after them), which
is converted to the pre-vowel state there. This also handles alternations between -iami/-ami after different sorts
of soft consonants.

Alternations between -i/-y handled in combine_stem_ending() as well, as is dropping of j before -i.

Palatalization in the dat/loc sg before -e (which may change to -i or -y in the process), in the voc sg of masculine
nouns before -i and in the nom pl of masculine personal nouns before -i is handled in apply_special_cases(). 

Stem variations due to the "fleeting e" in the nom sg and/or gen pl (which we refer to as "reducibility" for
consistency with East Slavic languages) is handled in determine_stems(), which sets vowel_stem and nonvowel_stem
differently (controlled by * or -* indicators, with the default handled in determine_default_reducible()). The actual
construction of the reduced stem (i.e. removal of a fleeting e) or dereduced stem (i.e. addition of a fleeting e) is
handled in reduce() and/or dereduce() in [[Module:pl-common]].

"Quantitative" vowel alternations between ó/o and ą/ę handled in apply_vowel_alternation() (controlled by the #
indicator).

Defaults are provided for cases where the ending varies between different nouns in a given declension, but some
variations are unpredictable and need to be handled through overrides. Note that overrides can specify just the ending or
the entire form; in the former case, an overridden ending may trigger changes to the stem or even the ending itself, in
the same way that such modifications happen when endings are specified using add_decl(). For example, specifying '-e' as
the locative singular ending will automatically trigger palatalization according to the usual rules. Usually these
changes are helpful and avoid the need for a lot of full-form overrides, but in the cases where they cause problems,
a full-form override should be used.
]=]
local decls = {}
-- Table specifying additional properties for declension types. Every declension type must have such a table, which
-- specifies which category or categories to add and what annotation to show in the title bar of the declension table.
--
-- * Only the `cat` property of this table is mandatory; there is also a `desc` property to specify the annotation, but
--   this can be omitted and the annotation will then be computed from the `cat` property. The `cat` property is either
--   a string, a list of strings or a function (of two arguments, `base` and `stems` as above) returning a string or
--   list of strings. The string can contain the keywords GENDER to substitute the gender (and animacy for masculine
--   nouns) and POS (to substitute the pluralized part of speech). The keyword GENPOS is equivalent to 'GENDER POS'. If
--   no keyword is present, ' GENPOS' is added onto the end. If only GENDER is present, ' POS' is added onto the end.
--   In all cases, the language name is added onto the beginning to form the full category name.
-- * The `desc` property is of the same form as the `cat` property and specifies the annotation to display in the title
--   bar (which may have the same format as the category minus the part of speech, or may be abbreviated). The value
--   may not be a list of strings, as only one annotation is displayed. If omitted, it is derived from the category
--   spec(s) by taking the last category (if more than one is given) and removing ' POS' before keyword substitution.
local declprops = {}

-- Return the default masculine animate nominative plural ending(s) given `base` and `stems`. This is called for hard
-- and soft masculines ending in a consonant, but not for nouns ending in a vowel, which have their own defaults
-- (particularly nouns in -a, where -ista/-ita/-asta behave differently from other nouns in -a).
local function default_masc_animate_nom_pl(base, stems)
	return
		-- [monosyllabic words: Dánové, Irové, králové, mágové, Rusové, sokové, synové, špehové, zběhové, zeťové, manové, danové
		-- (but Žid → Židé, Čech → Češi).] -- There are too many exceptions to this to make a special rule. It is better to use
		-- the overall default of -i and require that cases with -ove, -ove/-i, -i/-ove, etc. use overrides.
		-- com.is_monosyllabic(base.lemma) and "ové" or
		-- reducible terms in -Cek; order of -ové vs. -i sometimes varies:
		-- [[fracek]] (ové/i), [[klacek]] (i/ové), [[macek]] (ové/i), [[nácek]] (i/ové), [[prcek]] (ové/i), [[racek]] (ové/i);
		-- [[bazilišek]] (i/ové), [[černoušek]] (i/ové), [[drahoušek]] (ové/i), [[fanoušek]] (i/ové), [[františek]] (an/inan,
		-- ends in -i/-y but not -ové), [[koloušek]] (-i only), [[kulíšek]] (i/ové), [[oříšek]] (i/ové), [[papoušek]] (-i only),
		-- [[prášek]] (i/ové), [[šašek]] (i/ové).
		-- make sure to check `stems` as we don't want to include non-reducible words in -Cek (but do want to include
		-- [[quarterback]], with -i/-ové)
		rfind(stems.vowel_stem, "^" .. com.lowercase_c .. ".*" .. com.cons_c .. "k$") and {"i", "ové"} or
		-- [[stoik]], [[neurotik]], [[logik]], [[fyzik]], etc.
		rfind(base.lemma, "^" .. com.lowercase_c .. ".ik$") and {"i", "ové"} or
		-- barmani, gentlemani, jazzmani, kameramani, narkomani, ombudsmani, pivotmani, rekordmani, showmani, supermani, toxikomani
		rfind(base.lemma, "^" .. com.lowercase_c .. ".*man$") and "i" or
		-- terms ending in -an after a palatal or a consonant that doesn't change when palatalized, i.e. labial or l (but -man
		-- forms -mani unless in a proper noun): Brňan → Brňané, křesťan → křesťané, měšťan → měšťané, Moravan → Moravané,
		-- občan → občané, ostrovan → ostrované, Pražan → Pražané, Slovan → Slované, svatebčan → svatebčané, venkovan → venkované,
		-- Australan → Australané; also s, because there are many demonyms in -san e.g. [[Andalusan]], [[Barbadosan]], [[Oděsan]],
		-- and few proper nouns in -san; similarly z because of [[Belizan]], [[Gazan]], [[Kavkazan]], etc.; also w, which isn't a
		-- normal consonant in Polish but occurs in [[Glasgowan]] and [[Zimbabwan]]; NOTE: a few misc words like [[pohan]] also
		-- work this way but need manual overrides
		rfind(base.lemma, "[" .. com.inherently_soft .. com.labial .. "wlsz]an$") and {"é", "i"} or -- most now can also take -i
		-- proper names: Baťové, Novákové, Petrové, Tomášové, Vláďové; exclude demonyms (but include surnames)
		rfind(base.lemma, "^" .. com.uppercase_c) and (base.surname or not rfind(base.lemma, "[eě]c$")) and "ové" or
		-- demonyms: [[Albánec]], [[Gruzínec]], [[Izraelec]], [[Korejec]], [[Libyjec]], [[Litevec]], [[Němec]], [[Portugalec]]
		rfind(base.lemma, "^" .. com.uppercase_c .. ".*[eě]c$") and "i" or
		-- From here on down, we're dealing only with lowercase terms.
		-- buditelé, budovatelé, čekatelé, činitelé, hostitelé, jmenovatelé, pisatelé, ručitelé, velitelé, živitelé
		rfind(base.lemma, ".*tel$") and "é" or
		-- nouns in -j: čaroděj → čarodějové, lokaj → lokajové, patricij → patricijové, plebej → plebejové, šohaj → šohajové, žokej → žokejové
		-- nouns in -l: apoštol → apoštolové, břídil → břídilové, fňukal → fňukalové, hýřil → hýřilové, kutil → kutilové,
		--   loudal → loudalové, mazal → mazalové, škrabal → škrabalové, škudlil → škudlilové, vyvrhel → vyvrhelové, žvanil → žvanilové
		--   (we excluded those in -tel above)
		rfind(base.lemma, ".*[jl]$") and "ové" or
		-- archeolog → archeologové, biolog → biologové, geolog → geologové, meteorolog → meteorologové
		rfind(base.lemma, ".*log$") and "ové" or
		-- dramaturg → dramaturgové, chirurg → chirurgové
		rfind(base.lemma, ".*urg$") and "ové" or
		-- fotograf → fotografové, geograf → geografové, lexikograf → lexikografové
		rfind(base.lemma, ".*graf$") and "ové" or
		-- bibliofil → bibliofilové, germanofil → germanofilové
		rfind(base.lemma, ".*fil$") and "ové" or
		-- rusofob → rusofobové
		rfind(base.lemma, ".*fob$") and "ové" or
		-- agronom → agronomové, ekonom → ekonomové
		rfind(base.lemma, ".*nom$") and "ové" or
		"i"
end


--[=[
Examples:


Personal:

meaning		nom_sg		gen_sg		dat_sg		loc_sg		voc_sg		nom_pl_1	nom_pl_2	gen_pl		ins_pl
Russian		Rosjanin	Rosjanina	Rosjaninowi	Rosjaninie	Rosjaninie	Rosjanie	Rosjany		Rosjan		Rosjanami
Hispanic	Hiszpan		Hiszpana	Hiszpanowi	Hiszpanie	Hiszpanie	Hiszpanie	Hiszpany	Hiszpanów	Hiszpanami
African		Afrykanin	Afrykanina	Afrykaninowi Afrykaninie Afrykaninie Afrykanie	Afrykany	Afrykanów	Afrykanami
guy			facet		faceta		facetowi	facecie		facecie		faceci		facety		facetów		facetami
Hutsul		Hucuł		Hucuła		Hucułowi	Hucule		Hucule		Huculi		Hucuły		Hucułów		Hucułami
clown		błazen		błazna		błaznowi	błaźnie		błaźnie		błaźni		błaźny		błaznów		błaznami
Arab		Arab		Araba		Arabowi		Arabie		Arabie		Arabowie	Araby		Arabów		Arabami
apostle		apostoł		apostoła	apostołowi	apostole	apostole	apostolowie	apostoły	apostołów	apostołami
engineer	inżynier	inżyniera	inżynierowi	inżynierze	inżynierze	inżynierowie inżyniery	inżynierów	inżynierami
loafer		nierób		nieroba		nierobowi	nierobie	nierobie	-			nieroby		nierobów	nierobami
?			Głód		Głoda		Głodowi		Głodzie		Głodzie		Głodowie	Głody		Głodów		Głodami
glutton		głodomór	głodomora	głodomorowi	głodomorze	głodomorze	-			głodomory	głodomorów	głodomorami
Sejm_member	poseł		posła		posłowi		posle		posle		posłowie	posły		posłów		posłami
master		majster		majstra		majstrowi	majstrze	majstrze	majstrowie	majstry		majstrów	majstrami
fool		kiep		kpa			kpowi		kpie		kpie		-			kpy			kpów		kpami
dwarf		karzeł		karła		karłowi		karle		karle		karłowie	karły		karłów		karłami
brother-in-law szwagier	szwagra		szwagrowi	szwagrze	szwagrze	szwagrowie	szwagry		szwagrów	szwagrami
jackass		osioł		osła		osłowi		ośle		ośle		osłowie		osły		osłów		osłami
angel		anioł		anioła		aniołowi	aniele		aniele		aniołowie	anioły		aniołów		aniołami
fidgeter?	pędziwiatr	pędziwiatra	pędziwiatrowi pędziwiatrze pędziwiatrze -		pędziwiatry	pędziwiatrów pędziwiatrami
leader		lider		lidera		liderowi	liderze		liderze		liderzy		lidery		liderów		liderami
arbiter		arbiter		arbitra		arbitrowi	arbitrze	arbitrze	arbitrzy	arbitry		arbitrów	arbitrami
Hungarian	Węgier		Węgra		Węgrowi		Węgrze		Węgrze		Węgrzy		Węgry		Węgrów		Węgrami
young_man	młodzieniec	młodzieńca	młodzieńcowi młodzieńcu	młodzieńcze	młodzieńcy	młodzieńce	młodzieńców	młodzieńcami
old_man		starzec		starca		starcowi	starcu		starcze		starcy		starce		starców		starcami
friend		przyjaciel	przyjaciela	przyjacielowi przyjacielu przyjacielu przyjaciele przyjaciele przyjaciół przyjaciółmi dat_pl: przyjaciołom; loc_pl: przyjaciołach
lazybones	leń			lenia		leniowi		leniu		lenie		lenie		lenie		leni		leniami
thief		złodziej	złodzieja	złodziejowi	złodzieju	złodzieju	złodzieje	złodzieje	złodziei	złodziejami
smith		kowal		kowala		kowalowi	kowalu		kowalu		kowale		kowale		kowali		kowalami
dogcatcher	hycel		hycla		hyclowi		hyclu		hyclu		hycle		hycle		hycli		hyclami
guest		gość		gościa		gościowi	gościu		gościu		goście		goście		gości		gośćmi		loc_pl: gościom
people		-			-			-			-			-			ludzie		ludzie		ludzi		ludźmi		loc_pl: ludziach
knez		kniaź		kniazia		kniaziowi	kniaziu		kniaziu		kniazie		kniazie		kniaziów	kniaziami
brigand		zbój		zbója		zbójowi		zbóju		zbóju		zbóje		zbóje		zbójów		zbójami
gawker		gap			gapia		gapiowi		gapiu		gapiu		gapie		gapie		gapiów		gapiami
model		model		modela		modelowi	modelu		modelu		modele		modele		modelów		modelami
watchman	stróż		stróża		stróżowi	stróżu		stróżu		stróże		stróże		stróżów		stróżami
parent		rodzic		rodzica		rodzicowi	rodzicu		rodzicu		rodzice		rodzice		rodziców	rodzicami
brat		gnój		gnoja		gnojowi		gnoju		gnoju		gnoje		gnoje		gnojów		gnojami
rascal		urwipołeć	urwipołcia	urwipołciowi urwipołciu	urwipołciu	urwipołcie	urwipołcie	urwipołciów	urwipołciami
passer-by	przechodzień przechodnia przechodniowi przechodniu przechodniu przechodnie przechodnie przechodniów przechodniami
doctor		lekarz		lekarza		lekarzowi	lekarzu		lekarzu		lekarze		lekarze		lekarzy		lekarzami
Italian		Włoch		Włocha		Włochowi	Włochu		Włochu		Włosi		Włochy		Włochów		Włochami
father-in-law teść		teśćia		teśćiowi	teśćiu		teśćiu		teśćiowie	teśćie		teśćiów		teśćiami
maternal_uncle wuj		wuja		wujowi		wuju		wuju		wujowie		wuje		wujów		wujami
king		król		króla		królowi		królu		królu		królowie	króle		królów		królami
spectator	widz		widza		widzowi		widzu		widzu		widzowie	widze		widzów		widzami
husband		mąż			męża		mężowi		mężu		mężu		mężowie		męże		mężów		mężami
student		uczeń		ucznia		uczniowi	uczniu		uczniu		uczniowie	ucznie		uczniów		uczniami
[surname]	Nobel		Nobla		Noblowi		Noblu		Noblu		Noblowie	Noble		Noblów		Nobliami
[surname]	Stępień		Stępnia		Stępniowi	Stępniu		Stępniu		Stępniowie	Stępnie		Stępniów	Stępniami
sheik		szejk		szejka		szejkowi	szejku		szejku		szejkowie	szejki		szejków		szejkami	ins_sg: szejkiem
enemy		wróg		wroga		wrogowi		wrogu		wrogu		wrogowie	wrogi		wrogów		wrogami		ins_sg: wrogiem
grandfather	dziadek		dziadka		dziadkowi	dziadku		dziadku		dziadkowie	dziadki		dziadków	dziadkami	ins_sg: dziadkiem
son			syn			syna		synowi		synu		synu		synowie		syny		synów		synami
friend		druh		druha		druhowi		druhu		druhu		druhowie	druhy		druhów		druhami
shoemaker	szewc		szewca		szewcowi	szewcu		szewcu		szewcy		szewce		szewców		szewcami
captive		jeniec		jeńca		jeńcowi		jeńcu		jeńcu		jeńcy		jeńce		jeńców		jeńcami
male		samiec		samca		samcowi		samcu		samcu		samcy		samce		samców		samcami
Pole		Polak		Polaka		Polakowi	Polaku		Polaku		Polacy		Polaki		Polaków		Polakami	ins_sg: Polakiem
person		człowiek	człowieka	człowiekowi	człowieku	człowieku/człowiecze -	-			-			-			ins_sg: człowiekiem
Turk		Turek		Turka		Turkowi		Turku		Turku		Turcy		Turki		Turków		Turkami		ins_sg: Turkiem
brother		brat		brata		bratu		bracie		bracie		bracia		braty		braci		braćmi		loc_pl: braciach
farmer		chłop		chłopa		chłopu		chłopie		chłopie		chłopi		chłopy		chłopów		chłopami
devil		diabeł		diabła		diabłu		diable		diable		diabli		diabły		diabłów		diabłami
priest		ksiądz		księdza		księdzu		księdzu		księże		księża		księża		księży		księżmi		loc_pl: księżach
father		ojciec		ojca		ojcu		ojcu		ojcze		ojcowie		ojce		ojców		ocjami
person		człek		człeka		człeku		człeku		człecze		człekowie	człeki		człeków		człekami	ins_sg: człekiem
god			bóg			boga		bogu		bogu		boże		bogowie		bogi		bogów		bogami		ins_sg: bogiem
gentleman	pan			pana		panu		panu		panie		panowie		pany		panów		panami
boy			chłopiec	chłopca		chłopcu		chłopcu		chłopcze	chłopcy		chłopce		chłopców	chłopcami


Personal declined like consonant-stem feminine nouns:

meaning		nom_sg		gen_sg		dat_sg		loc_sg		voc_sg		nom_pl_1	nom_pl_2	gen_pl		ins_pl
majesty		mość		mości		mości		mości		mości		moście		moście		mościów		mościami
?			waszeć		waszeci		waszeci		waszeci		waszeci		waszeciowie	waszecie	waszeciów	waszeciami


Personal declined like feminine nouns in -a:

meaning		nom_sg		gen_sg		dat_sg		loc_sg		voc_sg		nom_pl_1	nom_pl_2	gen_pl		ins_pl
Inca		Inka		Inki		Ince		Ince		Inko		Inkowie		Inki		Inków		Inkami
servant		sługa		sługi		słudze		słudze		sługo		słudzy		sługi		sług		sługami
companion	kolega		kolegi		koledze		koledze		kolego		koledzy		kolegi		kolegów		kolegami
carpenter	cieśla		cieśli		cieśli		cieśli		cieślo		cieśle		cieśle		cieśli		cieślami
preacher	kaznodzieja	kaznodziei	kaznodziei	kaznodziei	kaznodziejo	kaznodzieje	kaznodzieje	kaznodziejów kaznodziejami
Mayan		Maja		Mai			Mai			Mai			Majo		Majowie		Maje		Majów		Majami
Aryan?		Aria		Arii		Arii		Arii		Ario		Ariowie		Arie		Ariów		Ariami
grandpa?	dziadzia	dziadzi		dziadzi		dziadzi		dziadziu	dziadziowie	dziadzie	dziadziów	dziadziami
man			mężczyzna	mężczyzny	mężczyźnie	mężczyźnie	mężczyzno	mężczyźni	mężczyzny	mężczyzn	mężczyznami
artist		artysta		artysty		artyście	artyście	artysto		artyści		artysty		artystów	artystami
Camaldolese_monk kameduła kameduły	kamedule	kamedule	kameduło	kameduli	kameduły	kamedułów	kamedułami
best_man	drużba		drużby		drużbie		drużbie		drużbo		drużbowie	drużby		drużbów		drużbami
mullah		mułła		mułły		mulle		mulle		mułło		mułłowie	mułły		mułłów		mułłami
[mythical_giant] waligóra waligóry	waligórze	waligórze	waligóro	waligórowie	waligóry	waligórów	waligórami
monarch		monarcha	monarchy	monarsze	monarsze	monarcho	monarchowie	monarchy	monarchów	monarchami
psychiatrist psychiatra	psychiatry	psychiatrze	psychiatrze	psychiatro	psychiatrzy	psychiatry	psychiatrów	psychiatrami
Yeshua?		Jeszua		Jeszuy		Jeszui		Jeszui		Jeszuo		Jeszuowie	Jeszuy		Jeszuów		Jeszuami
noble?		wielmoża	wielmoży	wielmoży	wielmoży	wielmożo	wielmoże	wielmoże	wielmożów	wielmożami
Karpaty_shepherd baca	bacy		bacy		bacy		baco		bacowie		bace		baców		bacami
hunter		łowca		łowcy		łowcy		łowcy		łowco		łowcy		łowce		łowców		łowcami


Personal declined like feminine nouns in -o:

meaning		nom_sg		gen_sg		dat_sg		loc_sg		voc_sg		nom_pl_1	nom_pl_2	gen_pl		ins_pl
[surname]	Kościuszko	Kościuszki	Kościusce	Kościusce	Kościuszko	Kościuszkowie Kościuszki Kościuszków Kościuszkami
dad			tato		taty		tacie		tacie		tato		tatowie		taty		tatów		tatami
[surname]	Jagiełło	Jagiełły	Jagielle	Jagielle	Jagiełło	Jagiełłowie	Jagiełły	Jagiełłów	Jagiełłami
[surname]	Fredro		Fredry		Fredrze		Fredrze		Fredro		Fredrowie	Fredry		Fredrów		Fredrami
[surname]	Trapszo		Trapszy		Trapszy		Trapszy		Trapszo		Trapszowie	Trapsze		Trapszów	Trapszami


Personal declined like adjectival nouns:

meaning		nom_sg		gen_sg		dat_sg		loc_sg		voc_sg		nom_pl_1	nom_pl_2	gen_pl		ins_pl
judge		sędzia		sędziego	sędziemu	sędzim/sędzi sędzio		sędziowie	sędzie		sędziów		sędziami
count		hrabia		hrabiego	hrabiemu	hrabim/hrabi hrabio		hrabiowie	hrabie		hrabiów		hrabiami
[surname]	Linde		Lindego		Lindemu		Lindem		Linde		Lindowie	Linde		Lindów		Lindami
fellow_man	bliźni		bliźniego	bliźniemu	bliźnim		bliźni		bliźni		bliźnie		bliźnich	bliźnimi
hajji		hadżi		hadżiego	hadżiemu	hadżim		hadżi		hadżi		hadżie		hadżich		hadżimi
zombie		zombi		zombiego	zombiemu	zombim		zombi		zombi		zombie		zombich		zombimi
[deputy]	podstarości	podstarościego podstarościemu podstarościm podstarości podstarościowie podstaroście podstarościch podstarościmi
effendi		efendi		efendiego	efendiemu	efendim		efendi		efendiowie	efendie		efendich	efendimi
rabbi		rabbi		rabbiego	rabbiemu	rabbim		rabbi		rabbiowie	rabbie		rabbich		rabbimi
[court_official] podstoli podstolego podstolemu	podstolim	podstoli	podstolowie	podstole	podstolich	podstolimi
loved_one	bliski		bliskiego	bliskiemu	bliskim		bliski		bliscy		bliskie		bliskich	bliskimi
hunter		myśliwy		myśliwego	myśliwemu	myśliwym	myśliwy		myśliwi		myśliwe		myśliwych	myśliwymi
-			-			-			-			-			obecni		obecne		obecnych	obecymi
expert_witness biegły	biegłego	biegłemu	biegłym		biegły		biegli		biegłe		biegłych	biegłymi
scholar		uczony		uczonego	uczonemu	uczonym		uczony		uczeni		uczone		uczonych	uczonymi
divorcé		rozwiedziony rozwiedzionego rozwiedzionemu rozwiedzionym rozwiedziony rozwiedzeni rozwiedzione rozwiedzionych rozwiedzionymi
Chorąży		chorąży		chorążego	chorążemu	chorążym	chorąży		chorążowie	chorąże		chorążych	chorążymi
servant		służący		służącego	służącemu	służącym	służący		służący		służące		służących	służącymi
sick_person	chory		chorego		choremu		chorym		chory		chorzy		chore		chorych		chorymi
some[people] -			-			-			-			-			niektórzy	niektóre	niektórych	niektórymi


Personal declined like neuter t-stem nouns:

meaning		nom_sg		gen_sg		dat_sg		loc_sg		voc_sg		nom_pl_1	nom_pl_2	gen_pl		ins_pl
prince		książę		księcia		księciu		księciu		książę		książęta	książęta	książąt		książętami


Personal in -o:

meaning		nom_sg		gen_sg		dat_sg		loc_sg		voc_sg		nom_pl_1	nom_pl_2	gen_pl		ins_pl
mafioso		mafiozo		mafioza		mafiozowi	mafiozie	mafiozo		mafiozi		mafiozy		mafiozów	mafiozami
mikado		mikado		mikada		mikadowi	mikadzie	mikado		mikadowie	mikada		mikadów		mikadami
maestro		maestro		maestra		maestrowi	maestrze	maestro		maestrowie	maestra		maestrów	maestrami
Apollo		Apollo		Apollina	Apollinowi	Apollinie	Apollo/Apollinie Apollinowie Apolliny Apollinów	Apollinami
[given_name] Iwo		Iwona		Iwonowi		Iwonie		Iwo/Iwonie	Iwonowie	Iwony		Iwonów		Iwonami
?			synalo		synala		synalowi	synalu		synalo		synale		synale		synalów		synalami
gaucho		gauczo		gaucza		gauczowi	gauczu		gauczo		gauczowie	gaucze		gauczów		gauczami
[dim_name]	Zdzicho		Zdzicha		Zdzichowi	Zdzichu		Zdzichu		Zdzichowie	Zdzicha		Zdzichów	Zdzichami
madman		wariatuncio	wariatuncia	wariatunciowi wariatunciu wariatunciu wariatunciowie wariatuncie wariatunciów wariatunciami
grandpa		dziadzio	dziadzia	dziadziowi	dziadziu	dziadziu	dziadziowie	dziadzie	dziadziów	dziadziami
maternal_uncle wujo		wuja		wujowi		wuju		wujo		wujowie		wuje		wujów		wujami
[given_name] Mieszko	Mieszka		Mieszkowi	Mieszku		Mieszko		Mieszkowie	Mieszki		Mieszków	Mieszkami	ins_sg: Mieszkiem


Personal declined in the plural like a singular neuter noun:

meaning		nom_sg		gen_sg		dat_sg		loc_sg		voc_sg		nom_pl_1	nom_pl_2	gen_pl		ins_pl
Mr._and_Mrs. -			-			-			-			-			państwo		państwo		państwa		państwem	loc/dat_pl: państwu


Animal (voc_sg like loc_sg unless otherwise indicated):

meaning		nom_sg		gen_sg		dat_sg		loc_sg		nom_pl		gen_pl		ins_pl
contra_dance kontredans	kontredansa	kontredansowi kontredansie kontredanse kontredansów kontredansami
reptile		gad			gada		gadowi		gadzie		gady		gadów		gadami
mule		muł			muła		mułowi		mule		muły		mułów		mułami
aurochs		tur			tura		turowi		turze		tury		turów		turami
osprey		rybołów		rybołowa	rybołowowi	rybołowie	rybołowy	rybołowów	rybołowami
falcon		sokół		sokoła		sokołowi	sokole		sokoły		sokołów		sokołami
ghost		upiór		upiora		upiorowi	upiorze		upiory		upiorów		upiorami
gopher		suseł		susła		susłowi		suśle		susły		susłów		susłami
hummingbird	koliber		kolibra		kolibrowi	kolibrze	kolibry		kolibrów	kolibrami
gadfly		giez		gza			gzowi		gzie		gzy			gzów		gzami
eagle		orzeł		orła		orłowi		orle		orły		orłów		orłami
cysticercus	wągier		wągra		wągrowi		wągrze		wągry		wągrów		wągrami
billygoat	kozioł		kozła		kozłowi		koźle		kozły		kozłów		kozłami
elephant	słoń		słonia		słoniowi	słoniu		słonie		słoni		słoniami
turtle		żółw		żółwia		żółwiowi	żółwiu		żółwie		żółwi		żółwiami
gorilla		goryl		goryla		gorylowi	gorylu		goryle		goryli		gorylami
pigeon		gołąb		gołębia		gołębiowi	gołębiu		gołębie		gołębi		gołębiami
moth		mól			mola		molowi		molu		mole		moli		molami
drone		truteń		trutnia		trutniowi	trutniu		trutnie		trutni		trutniami
ruble		rubel		rubla		rublowi		rublu		ruble		rubli		rublami
echinoderm	szkarłupień	szkarłupnia	szkarłupniowi szkarłupniu szkarłupnie szkarłupni szkarłupniami
nuthatch	bargiel		bargla		barglowi	barglu		bargle		bargli		barglami
horse		koń			konia		koniowi		koniu		konie		koni		końmi		loc_pl: koniach
bear		miś			misia		misiowi		misiu		misie		misiów		misiami
myriapod	wij			wija		wijowi		wiju		wije		wijów		wijami
saffron_milk_cap rydz	rydza		rydzowi		rydzu		rydze		rydzów		rydzami
nightjar	kozodój		kozodoja	kozodojowi	kozodoju	kozodoje	kozodojów	kozodojami
arctic_fox	piesiec		pieśca		pieścowi	pieścu		pieśce		pieśców		pieścami
tapeworm	tasiemiec	tasiemca	tasiemcowi	tasiemcu	tasiemce	tasiemców	tasiemcami
eel			węgorz		węgorza		węgorzowi	węgorzu		węgorze		węgorzy		węgorzami
snake		wąż			węża		wężowi		wężu		węże		węży		wężami
hare		zając		zająca		zającowi	zającu		zające		zajęcy		zającami
bird		ptak		ptaka		ptakowi		ptaku		ptaki		ptaków		ptakami		ins_sg: ptakiem
saker_falcon raróg		raroga		rarogowi	rarogu		rarogi		rarogów		rarogami	ins_sg: rarogiem
kitty		kotek		kotka		kotkowi		kotku		kotki		kotków		kotkami		ins_sg: kotkiem
ghost		duch		ducha		duchowi		duchu		duchy		duchów		duchami
cat			kot			kota		kotu		kocie		koty		kotów		kotami
lion		lew			lwa			lwu			lwie		lwy			lwów		lwami
dog			pies		psa			psu			psie		psy			psów		psami
ox			wół			wołu		wołowi		wołe		woły		wołów		wołami


"Animal" (?) - feminine abstract nouns referring to (normally) male people

meaning		nom_sg		gen_sg		dat_sg		loc_sg		voc_sg		nom_pl		gen_pl		ins_pl
saintliness	świątobliwość świątobliwości świątobliwości świątobliwości świątobliwośc świątobliwości świątobliwości świątobliwościami
eminence	eminencja	eminencji	eminencji	eminencji	eminencjo	eminencje	eminencji	eminencjami


"Animal" (?) - masculine nouns in -a

meaning		nom_sg		gen_sg		dat_sg		loc_sg		voc_sg		nom_pl		gen_pl		ins_pl
satellite	satelita	satelity	satelicie	satelicie	satelito	satelity	satelitów	satelitami


"Animal" (?) - masculine nouns in -o

meaning		nom_sg		gen_sg		dat_sg		loc_sg		voc_sg		nom_pl		gen_pl		ins_pl
[dog_name]	Reksio		Reksia		Reksiowi	Reksiu		Reksiu		Reksie		Reksiów		Reksiami


"Animal" (?) - adjectivally declined nouns: voc_sg like nom_sg

meaning		nom_sg		gen_sg		dat_sg		loc_sg		nom_pl		gen_pl		ins_pl
robber's_dance zbójnicki zbójnickiego zbójnickiemu zbójnickim zbójnickie zbójnickich zbójnickimi
polonaise	chodzony	chodzonego	chodzonemu	chodzonym	chodzone	chodzonych	chodzonymi


Inanimate (voc_sg like loc_sg unless otherwise indicated):

meaning		nom_sg		gen_sg		dat_sg		loc_sg		nom_pl		gen_pl		ins_pl
whip		bat			bata		batowi		bacie		baty		batów		batami
holiday		-			-			-			-			wczasy		wczasów		wczasami
top			chochoł		chochoła	chochołowi	chochole	chochoły	chochołów	chochołami
[village]	-			-			-			-			Orły		Orłów		Orłami
cheese		ser			sera		serowi		serze		sery		serów		serami
truancy		-			-			-			-			wagary		wagarów		wagarami
tooth		ząb			zęba		zębowi		zębie		zęby		zębów		zębami
[town]		Kikół		Kikoła		Kikołowi	Kikole		Kikoły		Kikołów		Kikołami
large_bag	wór			wora		worowi		worze		wory		worów		worami
drum		bęben		bębna		bębnowi		bębnie		bębny		bębnów		bębnami
knot		węzeł		węzła		węzłowi		węźle		węzły		węzłów		węzłami
sweater		sweter		swetra		swetrowi	swetrze		swetry		swetrów		swetrami
oat			owies		owsa		owsowi		owsie		owsy		owsów		owsami
fang		kieł		kła			kłowi		kle			kły			kłów		kłami
blackhead	wągier		wągra		wągrowi		wągrze		wągry		wągrów		wągrami
cauldron	kocioł		kotła		kotłowi		kotle		kotły		kotłów		kotłami
church		kościół		kościoła	kościołowi	kościele	kościoły	kościołów	kościołami
shadow		cień		cienia		cieniowi	cieniu		cienie		cieni		cieniami
larch		modrzew		modrzewia	modrzewiowi	modrzewiu	modrzewie	modrzewi	modrzewiami
log?		bal			bala		balowi		balu		bale		bali		balami
nail		gwóźdź		gwoździa	gwoździowi	gwoździu	gwoździe	gwoździ		gwoździami
torso		tułów		tułowia		tułowiowi	tułowiu		tułowie		tułowi		tułowiami
muscle		mięsień		mięśnia		mięśniowi	mięśniu		mięśnie		mięśni		mięśniami
piece_of_furniture mebel mebla		meblowi		meblu		meble		mebli		meblami
trunk		pień		pnia		pniowi		pniu		pnie		pni			pniami
coal		węgiel		węgla		węglowi		węglu		węgle		węgli		węglami
eve			przeddzień	-			-			przededniu	-			-			-			only nom/loc_sg
week		tydzień		tygodnia	tygodniowi	tygodniu	tygodnie	tygodni		tygodniami
leaf		liść		liścia		liściowi	liściu		liście		liści		liśćmi		loc_pl: liściach
prison/clink kić		kicia		kiciowi		kiciu		kicie		kiciów		kiciami
May			maj			maja		majowi		maju		maje		majów		majami
history		-			-			-			-			dzieje		dziejów		dziejami
ship		korab		korabia		korabiowi	korabiu		korabie		korabiów	korabiami
blanket		koc			koca		kocowi		kocu		koce		koców		kocami
reins		-			-			-			-			lejce		lejców		lejcami
tree_ring	słój		słoja		słojowi		słoju		słoje		słojów		słojami
[gmina]		Racibórz	Raciborza	Raciborzowi	Raciborzu	Raciborze	Raciborzów	Raciborzami
January		styczeń		stycznia	styczniowi	styczniu	stycznie	styczniów	styczniami
end			koniec		końca		końcowi		końcu		końce		końców		końcami
December	grudzień	grudnia		grudniowi	grudniu		grudnie		grudniów	grudniami
July		lipiec		lipca		lipcowi		lipcu		lipce		lipców		lipcami
[plant]		bniec	bieńca		bieńcowi	bieńcu		bieńce		bieńców		bieńcami
poem		wiersz		wiersza		wierszowi	wierszu		wiersze		wierszy		wierszami
knife		nóż			noża		nożowi		nożu		noże		noży		nożami
month		miesiąc		miesiąca	miesiącowi	miesiącu	miesiące	miesięcy	miesiącami
money		pieniądz	pieniądza	pieniądzowi	pieniądzu	pieniądze	pieniędzy	pieniędzmi	loc_pl: pieniądzach
piece_of_trash śmieć	śmiecia		śmieciowi	śmieciu		śmieci		śmieci		śmieciami
day			dzień		dnia		dniowi		dniu		dni			dni			dniami
canoe		kajak		kajaka		kajakowi	kajaku		kajaki		kajaków		kajakami	ins_sg: kajakiem
pliers		-			-			-			-			obcęgi		obcęgów		obcęgami
[village]	Tworóg		Tworoga		Tworogowi	Tworogu		Tworogi		Tworogów	Tworogami	ins_sg: Tworogiem
hammer		młotek		młotka		młotkowi	młotku		młotki		młotków		młotkami	ins_sg: młotkiem
bellows		miech		miecha		miechowi	miechu		miechy		miechów		miechami
[city]		-			-			-			-			Tychy		Tychów		Tychami
animal_head	łeb			łba			łbu			łbie		łby			łbów		łbami
world		świat		świata		światu		świecie		światy		światów		światami
miracle		cud			cudu		cudowi		cudzie		cuda		cudów		cudami
epeisodion	epejsodion	epejsodionu	epejsodionowi epejsodionie epejsodia epejsodiów	epejsodiami
séance		seans		seansu		seansowi	seansie		seanse		seansów		seansami
orchard		sad			sadu		sadowi		sadzie		sady		sadów		sadami
shaft		wał			wału		wałowi		wale		wały		wałów		wałami
wall		mur			muru		murowi		murze		mury		murów		murami
oak			dąb			dębu		dębowi		dębie		dęby		dębów		dębami
bottom		dół			dołu		dołowi		dole		doły		dołów		dołami
conifer_forest bór		boru		borowi		borze		bory		borów		borami
dream		sen			snu			snowi		śnie		sny			snów		snami
glue		klajster	klajstru	klajstrowi	klajstrze	klajstry	klajstrów	klajstrami
sugar		cukier		cukru		cukrowi		cukrze		cukry		cukrów		cukrami
baptism		chrzest		chrztu		chrztowi	chrzcie		chrzty		chrztów		chrztami
flower		kwiat		kwiatu		kwiatowi	kwiecie		kwiaty		kwiatów		kwiatami
wind		wiatr		wiatru		wiatrowi	wietrze		wiatry		wiatrów		wiatrami
ash			popiół		popiołu		popiołowi	popiele		popioły		popiołów	popiołami
people		lud			ludu		ludowi		ludzie		ludy		ludów		ludami
tobacco		tytoń		tytoniu		tytoniowi	tytoniu		tytonie		tytoni		tytoniami
Altaj		Ałtaj		Ałtaju		Ałtajowi	Ałtaju		-			-			-
dock/sorrel	szczaw		szczawiu	szczawiowi	szczawiu	szczawie	szczawi		szczawiami
rented_room	lokal		lokalu		lokalowi	lokalu		lokale		lokali		lokalami
room		pokój		pokoju		pokojowi	pokoju		pokoje		pokoi		pokojami
new_moon	nów			nowiu		nowiowi		nowiu		nowie		nowi		nowiami
fusel_oil	fuzel		fuzlu		fuzlowi		fuzlu		fuzle		fuzli		fuzlami
tar			dziegieć	dziegciu	dziegciowi	dziegciu	dziegcie	dziegci		dziegciami
[rock]		margiel		marglu		marglowi	marglu		margle		margli		marglami
grove		gaj			gaju		gajowi		gaju		gaje		gajów		gajami
dance,log,bale? bal		balu		balowi		balu		bale		balów		balami
fruit		owoc		owocu		owocowi		owocu		owoce		owoców		owocami
swarm		rój			roju		rojowi		roju		roje		rojów		rojami
ore			kruszec		kruszcu		kruszcowi	kruszcu		kruszce		kruszców	kruszcami
nickel		nikiel		niklu		niklowi		niklu		nikle		niklów		niklami
luggage		bagaż		bagażu		bagażowi	bagażu		bagaże		bagaży		bagażami
shore,edge	brzeg		brzegu		brzegowi	brzegu		brzegi		brzegów		brzegami	ins_sg: brzegiem
year		rok			roku		rokowi		roku		lata		lat			latami		ins_sg: rokiem
threshold	próg		progu		progowi		progu		progi		progów		progami		ins_sg: progiem
ship		statek		statku		statkowi	statku		statki		statków		statkami	ins_sg: statkiem
house		dom			domu		domowi		domu		domy		domów		domami
roof		dach		dachu		dachowi		dachu		dachy		dachów		dachami
moss		mech		mchu		mchowi		mchu		mchy		mchów		mchami


Inanimate in -o (voc_sg like loc_sg unless otherwise indicated):

meaning		nom_sg		gen_sg		dat_sg		loc_sg		nom_pl		gen_pl		ins_pl
little_belly brzusio	brzusia		brzusiowi	brzusiu		brzusie		brzusiów	brzusiami


Inanimate - adjectivally declined nouns: voc_sg like nom_sg

meaning		nom_sg		gen_sg		dat_sg		loc_sg		nom_pl		gen_pl		ins_pl
Polish		polski		polskiego	polskiemu	polskim		polskie		polskich	polskimi
February	luty		lutego		lutemu		lutym		lute		lutych		lutymi
some[things] -			-			-			-			niektóre	niektórych	niektórymi
]=]

--[=[
Counts from SGJP:

Type		e.g.		count	ending		gensg		locsg		nompl		nompl2		genpl		indicator		notes
...
B1/m1		Zerubabel	1		-			-a			-u			-owie		-e			-ów			
B1/m2		falafel		2		-			-a			-u			*			-e			-ów							falafel/karambol
B1/p3		saturnalie	3		-e			*			*			*			-e			-ów							bachanalie/saturnalie/subselie
B1+'/m2		scrabble	3		-			-'a			-'u			*			-'e			-'i			  				chippendale/scrabble/branle
B1+'/m3		joule		2		-			-'a			-'u			*			-'e			-'i			  				joule/Google
B1bą/m2		gołąb		2		-ąb			-ębia		-ębiu		*			-ębie		-ębi		  				gołąb/jastrząb
B1bą/m3		Gołąb		4		-ąb			-ębia		-ębiu		*			-ębie		-ębi		  				Gołąb/Kodrąb/Jarząb/Jastrząb
B1bą+w(ów)/m1 Gołąb		2		-ąb			-ębia		-ębiu		-ębiowie	-ębie		-ębiów		  				Gołąb/Jastrząb
B1bą+w(ów)/m3 jarząb	1		-ąb			-ębia		-ębiu		-ębiowie	-ębie		-ębiów		
B1bó+u/m3	drób		1		-ób			-obiu		-obiu		*			-obie		-obi		
B1c+w/m1	Giedroyc	1		-c			-cia		-ciu		-ciowie		-cie		-ciów		
B1ć/m1		śmieć		3		-ć			-cia		-ciu		-cie		-cie		-ci			
B1ć/m2		berbeć		7		-ć			-cia		-ciu		*			-cie		-ci			
B1ć/m3		Brześć		17		-ć			-cia		-ciu		*			-cie		-ci			
B1ć/p1		ichmoście	1		-cie		*			*			-cie		-cie		-ci			
B1će/m1		kapeć		2		-eć			-cia		-ciu		-cie		-cie		-ci			
B1će/m2		pypeć		2		-eć			-cia		-ciu		*			-cie		-ci			
B1će/m3		kopeć		16		-eć			-cia		-ciu		*			-cie		-ci			
B1ćei/m2	paznokieć	1		-ieć		-cia		-ciu		*			-cie		-ci			
B1ćei/m3	łokieć		6		-ieć		-cia		-ciu		*			-cie		-ci			
B1ćei+(ów)/m3 knykieć	2		-ieć		-cia		-ciu		*			-cie		-ciów		
B1ćei+u/m3	dziegieć	1		-ieć		-ciu		-ciu		*			-cie		-ci/ciów	
B1ćei+w/m1	Łokieć		3		-ieć		-cia		-ciu		-ciowie		-cie		-ciów		
B1će+(ów)/m1 pępeć		2		-eć			-cia		-ciu		-cie		-cie		-ciów		
B1će+(ów)/m2 pypeć		2		-eć			-cia		-ciu		*			-cie		-ciów		
B1će+(ów)/m3 ciapeć		2		-eć			-cia		-ciu		*			-cie		-ciów		
B1će+u/m3	kopeć		1		-eć			-ciu		-ciu		*			-cie		-ciów		
B1će+w/m1	Kopeć		9		-eć			-cia		-ciu		-ciowie		-cie		-ciów
B1ć+i/m3	śmieć		1		-ć			-cia		-ciu		*			-ci			-ci
B1ć+(mi)/m1	liść		2		-ć			-cia		-ciu		-cie		-cie		-ci							ins_pl -ćmi
B1ć+(mi)/m3	trójliść	4		-ć			-cia		-ciu		*			-cie		-ci							ins_pl -ćmi
B1ć+(ów)/m1	cieć		2		-ć			-cia		-ciu		-cie		-cie		-ciów
B1ć+(ów)/m2	turkuć		2		-ć			-cia		-ciu		*			-cie		-ciów
B1ć+(ów)/m3	kić			7		-ć			-cia		-ciu		*			-cie		-ciów
B1ć+(ów)/p1	ichmoście	1		-cie		*			*			-cie		-cie		-ciów
B1ć+w(ów)/m1 zięć		142		-ć			-cia		-ciu		-ciowie		-cie		-ciów
B1ć+w(ów)/p1 ichmościowie 2		-cie		*			*			-ciowie		-cie		-ciów
B1(el)/m3	ensemble	1		-e			-u			-u			*			-e			-i/ów
B1i/m1		żółw		4		-			-ia			-iu			-ie			-ie			-i
B1i/m2		czerw		16		-			-ia			-iu			*			-ie			-i
B1i/m3		modrzew		165		-			-ia			-iu			*			-ie			-i
B1i/p2:p3	Kurpie		58		-ie			*			*			*			-ie			-i
B1i+(ów)/m1	Kurp		4		-			-ia			-iu			-ie			-ie			-iów
B1i+(ów)/m2	wab			5		-			-ia			-iu			*			-ie			-iów
B1i+(ów)/m3	korab		151		-			-ia			-iu			*			-ie			-iów
B1i+(ów)/p2:p3 Kurpie	9		-ie			*			*			*			-ie			-iów
B1i+u/m3	szczaw		6		-			-iu			-iu			*			-ie			-i
B1i+u(ów)/m3 szczaw		4		-			-iu			-iu			*			-ie			-iów
B1i+w(ów)/m1 Korab		11		-			-ia			-iu			-iowie		-ie			-iów
B1j/m1		złodziej	19		-j			-ja			-ju			-je			-je			-i
B1j/p2:p3	Podcabaje	14		-je			*			*			*			-je			-i
B1jó/m1		gnój		2		-ój			-oja		-oju		-oje		-oje		-oi
B1jó/m2		podwój		1		-ój			-oja		-oju		*			-oje		-oi
B1jó/m3		słój		1		-ój			-oja		-oju		*			-oje		-oi
B1jó+(ów)/m1 opój		8		-ój			-oja		-oju		-oje		-oje		-ojów
B1jó+(ów)/m2 kozodój	2		-ój			-oja		-oju		*			-oje		-ojów
B1jó+(ów)/m3 słój		4		-ój			-oja		-oju		*			-oje		-ojów
B1jó+u/m3	pokój		33		-ój			-oju		-oju		*			-oje		-oi
B1jó+u(ów)/m3 ustrój	91		-ój			-oju		-oju		*			-oje		-ojów
B1jó+w(ów)/m1 Sędziwój	27		-ój			-oja		-oju		-ojowie		-oje		-ojów
B1j+u/m3	tramwaj		44		-j			-ju			-ju			-jowie		-je			-i
B1j+w/m1	didżej		4		-j			-ja			-ju			-jowie		-je			-i
B1j+w/m2	lej			4		-j			-ja			-ju			*			-je			-i
B1j+w/m3	liszaj		23		-j			-ja			-ju			*			-je			-i
B1l/m1		szuszwol	344		-			-a			-u			-e			-e			-i
B1l/m2		aksolotl	126		-			-a			-u			*			-e			-i
B1l/m3		szrapnel	281		-			-a			-u			*			-e			-i
B1l/p3		żele		4		-e			*			*			*			-e			-i
B1l+0/m3	promil		1		-			-a			-u			-e			-[count]	-[count]
B1le/m1		Abel		22		-el			-la			-lu			-le			-le			-li
B1le/m2		puzzel		30		-el			-la			-lu			*			-le			-li
B1le/m3		sopel		149		-el			-la			-lu			*			-le			-li
B1le+0/m1	przyjaciel	2		-el			-ela		-elu		-ele		-ele		-ół			?				ins_pl -ółmi; loc_pl -olach
B1lei/m1	singiel		1		-iel		-la			-lu			-le			-le			-li
B1lei/m2	bargiel		7		-iel		-la			-lu			*			-le			-li
B1lei/m3	żagiel		70		-iel		-la			-lu			*			-le			-li
B1lei+u/m3	margiel		12		-iel		-lu			-lu			*			-le			-li
B1lei+w/m1	Frenkiel	1		-iel		-la			-lu			-lowie		-le			-li
B1lei+w(ów)/m1 Węgiel	67		-iel		-la			-lu			-lowie		-le			-lów
B1lei+w(ów)/m2 Węgiel	6		-iel		-la			-lu			*			-le			-lów
B1lei+w(ów)/m3 rygiel	24		-iel		-la			-lu			*			-le			-lów
B1le+(ów)/m1 bedel		16		-el			-la			-lu			-le			-le			-lów
B1le+(ów)/m2 ferbel		15		-el			-la			-lu			*			-le			-lów
B1le+(ów)/m3 sznycel	63		-el			-la			-lu			*			-le			-lów
B1le+u/m3	handel		14		-el			-lu			-lu			*			-le			-li
B1le+u(ów)/m3 kaszel	5		-el			-lu			-lu			*			-le			-lów
B1le+w(ów)/m1 Goetel	441		-el			-la			-lu			-lowie		-le			-lów
B1le+w(ów)/m3 Kowel		4		-el			-la			-lu			*			-le			-lów
B1ló+w/m2	soból		2		-ól			-ola		-olu		-olowie		-ole		-oli
B1ló+w/m3	Soból		1		-ól			-ola		-olu		*			-ole		-oli
B1L+-(ów)/m2 SGML,HTML	3		-			--a			--u			*			--e			--ów
B1ló+w(ów)/m1 Soból		11		-ól			-ola		-olu		-olowie		-ole		-olów
B1L+-u/m3	HTML,MKOl	31		-			--u			--u			*			--e			--i
B1ń/m1		arcyleń		14		-ń			-nia		-niu		-nie		-nie		-ni
B1ń/m2		boleń		33		-ń			-nia		-niu		*			-nie		-ni
B1ń/m3		strumień	330		-ń			-nia		-niu		*			-nie		-ni
B1ń+dzień/m3 przeddzień	1		-dzień		-ednia		-edniu		*			-ednie		-edni
B1ńe/m1		dureń		1		-eń			-nia		-niu		-nie		-nie		-ni
B1ńe/m2		truteń		1		-eń			-nia		-niu		*			-nie		-ni
B1ńe/m3		sążeń		21		-eń			-nia		-niu		*			-nie		-ni
B1ńei/m2	szkarłupień	3		-ień		-nia		-niu		-nie		-nie		-ni
B1ńei/m3	pień		20		-ień		-nia		-niu		*			-nie		-ni
B1ńeic/m2	trucień		1		-cień		-tnia		-tniu		*			-tnie		-tni
B1ńeic/m3	przewiercień 3		-cień		-tnia		-tniu		*			-tnie		-tni
B1ńeic+(ów)/m1 Kwiecień 1		-cień		-tnia		-tniu		-tniowie	-tnie		-tniów
B1ńeic+(ów)/m3 kwiecień 2		-cień		-tnia		-tniu		*			-tnie		-tniów
B1ńei+(ów)/m1 skupień	3		-ień		-nia		-niu		-nie		-nie		-niów
B1ńei+(ów)/m2 topień	1		-ień		-nia		-niu		*			-nie		-niów
B1ńei+(ów)/m3 ogień		3		-ień		-nia		-niu		*			-nie		-niów
B1ńeip+w(ów)/m1 Skupień	10		-ień		-nia		-niu		-niowie		-nie		-niów
B1ńeis/m2	włosień		1		-sień		-śnia		-śniu		*			-śnie		-śni
B1ńeis/m3	mięsień		6		-sień		-śnia		-śniu		*			-śnie		-śni
B1ńeis+w(ów)/m1 Wrzesień 1		-sień		-śnia		-śniu		-śniowie	-śnie		-śniów
B1ńeis+w(ów)/m3 wrzesień 1		-sień		-śnia		-śniu		*			-śnie		-śniów
B1ńeiz/m1	przychodzień 4		-dzień		-dnia		-dniu		-dnie		-dnie		-dniów
B1ńeiz/m3	grudzień	4		-dzień		-dnia		-dniu		*			-dnie		-dniów
B1ńeiz+i/m3	dzień		1		-dzień		-dnia		-dniu		*			-dni		-dni
B1ńeiz+i/p3	suchedni	1		-dni		*			*			*			-dni		-dni
B1ńeiz+(ów)/m1 przechodzień	4	-dzień		-dnia		-dniu		-dnie		-dnie		-dniów
B1ńeiz+w/m1 więzień		2		-zień		-źnia		-źniu		-źniowie/źnie[dated] -źnie -źniów
B1ńeiz+w(ów)/m1 Grudzień 2		-dzień		-dnia		-dniu		-niowie		-nie		-niów
B1ńeiz+w(ów)/m3 przewodzień 2	-dzień		-dnia		-dniu		*			-nie		-niów
B1ńe+(ów)/m1 leżeń		4		-eń			-nia		-niu		-nie		-nie		-niów
B1ńe+(ów)/m2 dureń		1		-eń			-nia		-niu		*			-nie		-niów
B1ńe+(ów)/m3 Wiedeń		7		-eń			-nia		-niu		*			-nie		-niów
B1ńe+w/m1	uczeń		2		-eń			-nia		-niu		-niowie		-nie		-ni
B1ńe+w(ów)/m1 uczeń		11		-eń			-nia		-niu		-niowie		-nie		-niów
B1ń+godzień/m3 tydzień	1		-dzień		-godnia		-godniu		*			-godnie		-godni
B1ń+i/p3	pielmieni	1		-ni			*			*			*			-ni			-ni
B1ń+(mi)/m2	koń			4		-ń			-nia		-niu		*			-nie		-ni							ins_pl -ńmi
B1ń+(ów)/m1	lizuń		14		-ń			-nia		-niu		-nie		-nie		-niów
B1ń+(ów)/m2	diugoń		4		-ń			-nia		-niu		*			-nie		-niów
B1ń+(ów)/m3	cierń		152		-ń			-nia		-niu		*			-nie		-niów
B1ń+u/m3	tytoń		7		-ń			-niu		-niu		*			-nie		-ni
B1ń+u(ów)/m3 tytoń		6		-ń			-niu		-niu		*			-nie		-niów
B1ń+w(ów)/m1 Sadłoń		449		-ń			-nia		-niu		-niowie		-nie		-niów
B1o+!/m1	Romeo		3		-o			-a			-o			-owie		-a			-ów							voc in -o; VERIFY loc in -o
B1ol+w/m1	pikolo		2		-o			-a			-u			-owie		-e			-i							voc in -o
B1ol+w(ów)/m1 pikolo	3		-o			-a			-u			-e			-e			-ów							voc in -o
B1(o)+!w/m1	impresario	133		-o			-a			-u			-owie		-e			-ów							voc in -o
B1(o)+w/m1	apollo		108		-o			-a			-u			-owie		-e			-ów
B1(o)+w/m2	pysio		10		-o			-a			-u			*			-e			-ów
B1(o)+w/m3	brzusio		3		-o			-a			-u			*			-e			-ów
B1+-(ów)/m1	DJ			1		-			--a			--u			--e			--e			--ów
B1ś/m1		abbuś		9		-ś			-sia		-siu		-sie		-sie		-si
B1ś/m2		ptyś		20		-ś			-sia		-siu		*			-sie		-si
B1ś/m3		pyś			7		-ś			-sia		-siu		*			-sie		-si
B1ś+(ów)/m1	centuś		593		-ś			-sia		-siu		-sie		-sie		-siów
B1ś+(ów)/m2	buś			18		-ś			-sia		-siu		*			-sie		-siów
B1ś+(ów)/m3	chlebuś		17		-ś			-sia		-siu		*			-sie		-siów
B1ś+w/m1	tatuś		533		-ś			-sia		-siu		-siówie		-sie		-siów
B1+u/m3		spektakl	486		-			-u			-u			*			-e			-i
B1+'u/m3	siècle		2		-			-'u			-'u			*			-'e			-'i
B1+-u/m3	GUC,BOŚ		6		-			--u			--u			*			-e			-ów
B1wó/m3		śródtułów	8		-ów			-owia		-owiu		*			-owie		-owi
B1wó+(u)/m3	ołów		4		-ów			-owiu		-owiu		*			-owie		-owiów/owi
B1+'w(ów)/m1 Gaulle		18		-			-'a			-'u			-'owie		-'e			-'ów
B1+'w(ów)/m2 dodge		2		-			-'a			-'u			*			-'e			-'ów
B1+'w(ów)/m3 ensemble	4		-			-'a			-'u			*			-'e			-'ów
B1y/m1		cowboy		2		-y			-ya			-yu			-ye			-ye			-i							cowboy/jockey
B1ź/m1		witeź		2		-ź			-zia		-ziu		-zie		-zie		-zi
B1ź/m2		hyź			7		-ź			-zia		-ziu		*			-zie		-zi
B1ź/m3		fontaź		8		-ź			-zia		-ziu		*			-zie		-zi
B1źdą/m2	żołądź		1		-ądź		-ędzia		-ędziu		*			-ędzie		-ędzi
B1źdą/m3	żołądź		1		-ądź		-ędzia		-ędziu		*			-ędzie		-ędzi
B1źdźó/m2	gwóźdź		1		-óźdź		-oździa		-oździu		*			-oździe		-oździ
B1źdźó/m3	gwóźdź		1		-óźdź		-oździa		-oździu		*			-oździe		-oździ
B1źdźó+(mi)/m3 gwóźdź	1		-óźdź		-oździa		-oździu		*			-oździe		-oździ						ins_pl (gw)oźdźmi
B1ź+(ów)/m1	kniaź		6		-ź			-zia		-ziu		-zie		-zie		-ziów
B1ź+(ów)/m2	hyź			2		-ź			-zia		-ziu		*			-zie		-ziów
B1ź+(ów)/m3	fontaź		1		-ź			-zia		-ziu		*			-zie		-ziów
B1ź+w(ów)/m1 kniaź		40		-ź			-zia		-ziu		-ziowie		-zie		-ziów
B2cą+(y)/m2	tysiąc		2		-ąc			-ąca		-ącu		-ące		-ące		-ęcy
B2cą+(y)/m3	półmiesiąc	4		-ąc			-ąca		-ącu		*			-ące		-ęcy
B2ce/m1		Zaporożec	51		-ec			-ca			-cu			-cy			-ce			-ców
B2ce/m2		cielec		39		-ec			-ca			-cu			*			-ce			-ców
B2ce/m3		kolec		135		-ec			-ca			-cu			*			-ce			-ców
B2ce/p2		kolce		2		-ce			*			*			*			-ce			-ców
B2ce+!/m1	chudzielec	47		-ec			-ca			-cu			-cy			-ce			-ców						voc -cze
B2cei/m1	bankowiec	529		-iec		-ca			-cu			-cy			-ce			-ców
B2cei/m2	borowiec	424		-iec		-ca			-cu			*			-ce			-ców
B2cei/m3	hufiec		721		-iec		-ca			-cu			*			-ce			-ców
B2cei/p3	manowce		1		-ce			*			*			*			-ce			-ców
B2cei+!/m1	głupiec		483		-iec		-ca			-cu			-cy			-ce			-ców						voc -cze
B2cei+!/m2	latawiec	1		-iec		-ca			-cu			*			-ce			-ców						voc -cze
B2cei+!/m3	patrolowiec	2		-iec		-ca			-cu			*			-ce			-ców						voc -cze
B2ceic/m1	ociec		2		-ciec		-ćca		-ćcu		-ćcowie		-ćce		-ćców
B2ceic/m2	kiściec		4		-ciec		-ćca		-ćcu		*			-ćce		-ćców
B2ceic/m3	gościec		11		-ciec		-ćca		-ćcu		*			-ćce		-ćców
B2ceic+!?/m1 samoiściec 1		-ciec		-ćca		-ćcu		-ćcy		-ćce		-ćców						voc -ćcze/ćcu
B2ceicś!/m1 iściec		1		-ściec		-stca		-stcu		-stcy		-stce		-stców						voc -stcze/stcu
B2ceic+(u)!w/m1 ociec	2		-ciec		-ćca		-ćcu		-ćcowie		-ćce		-ćców						dat -ćcu/ćcowi; voc -ćcze
B2cein/m1	Amerykaniec	177		-niec		-ńca		-ńcu		-ńcy		-ńce		-ńców
B2cein/m2	biedrzeniec	42		-niec		-ńca		-ńcu		*			-ńce		-ńców
B2cein/m3	kaganiec	302		-niec		-ńca		-ńcu		*			-ńce		-ńców
B2cein/p1	oblubieńcy	2		-ńcy		*			*			-ńcy		-ńce		-ńców
B2cein/p3	kłańce		2		-ńce		*			*			*			-ńce		-ńców
B2cein+!/m1	goniec		70		-niec		-ńca		-ńcu		-ńcy		-ńce		-ńców						voc -ńcze
B2ceinb/m3	bniec		1		-bniec		-bieńca		-bieńcu		-bieńcy		-bieńce		-bieńców
B2cein+(ów)/m1 odrapaniec 6		-niec		-ńca		-ńcu		-ńce		-ńce		-ńców
B2cein+u/m3 robroniec	1		-niec		-ńcu		-ńcu		*			-ńce		-ńców
B2cein+w/m1 Daniec		125		-niec		-ńca		-ńcu		-ńcowie		-ńce		-ńców
B2ceis+!?/m1 kosiec		1		-siec		-śca		-ścu		-ścy		-śce		-śców						voc -ścze/-ścu
B2ceis+w/m1	Kosiec		6		-siec		-śca		-ścu		-ścowie		-śce		-śców
B2ceis+w/m2	osiec		2		-siec		-śca		-ścu		*			-śce		-śców
B2ceis+w/m3	krztusiec	14		-siec		-śca		-ścu		*			-śce		-śców
B2cei+(u)!/m1 chłopiec	1		-iec		-ca			-cu			-cy			-ce			-ców						dat -cu; voc -cze
B2cei+!w/m1	ojciec		3		-ciec		-ca			-cu			-cowie		-ce			-ców						dat -cu; voc -cze
B2cei+!w/p1	ojcowie		1		-cowie		*			*			-cowie		-ce			-ców
B2cei+w/m1	Dziadkowiec	168		-iec		-ca			-cu			-cowie		-ce			-ców
B2cei+(y)/m3 garniec	2		-iec		-ca			-cu			-cy			-ce			-cy
B2ceiz/m1	chudziec	4		-ziec		-źca		-źcu		-źcy		-źce		-źców
B2ceiz/m2	brodziec	7		-ziec		-źca		-źcu		*			-źce		-źców
B2ceiz/m3	bodziec		19		-ziec		-źca		-źcu		*			-źce		-źców
B2ceiz+!/m1	jeździec	4		-ziec		-źca		-źcu		-źcy		-źce		-źców						voc -źcze
B2ceiz+!?/m1 mołodziec	1		-dziec		-dca		-dcu		-dcy		-dce		-dców						voc -dcze/-dcu
B2ceiz+w/m1	Dudziec		7		-ziec		-źca		-źcu		-źcowie		-źce		-źców
B2ce+u/m3	kruszec		4		-ec			-cu			-cu			*			-ce			-ców
B2ce+w/m1	Michalec	91		-ec			-ca			-cu			-cowie		-ce			-ców
B2cez/m1	Czarnogórzec 13		-rzec		-rca		-cu			-cy			-ce			-ców
B2cez/m2	dwuparzec	2		-rzec		-rca		-cu			*			-ce			-ców
B2cez/m3	dworzec		31		-rzec		-rca		-cu			*			-ce			-ców
B2cez/p3	igrce		1		-rce		*			*			*			-ce			-ców
B2cez+!		mędrzec		13		-rzec		-rca		-cu			-cy			-ce			-ców						voc -rcze
B2cez+w/m1	Marzec		12		-rzec		-rca		-cu			-cowie		-ce			-ców
B2cez+(y)/m3 korzec		2		-rzec		-rca		-cu			-cowie		-ce			-ców
B2+e(ów)/m1	kibic		5746	-			-a			-u			-e			-e			-ów
B2+e(ów)/m2	kusacz		5		-			-a			-u			-e			-e			-ów
B2+e(ów)/m3	decybel		12		-			-a			-u			-e			-e			-ów
B2+e(ów)/p1	rodzice		1		-e			*			*			-e			-e			-ów
B2+e(ów)/p2	rajce		2		-e			*			*			*			-e			-ów
B2+'u/m3	image		12		-			-'u			-'u						-'e			-'ów
B2+u(ów)/m3	wiec		753		-			-u			-u			*			-e			-ów
B2+u(y)/m3	pilotaż		278		-			-u			-u			*			-e			-y
B2+'u(y)/m3	collage		4		-			-'u			-'u			*			-'e			-'y
B2+w(ów)/m1	kloc		6743	-			-a			-u			-owie		-e			-ów
B2+w(ów)/m2	borodziej	302		-			-a			-u			*			-e			-ów
B2+w(ów)/m3	antydaktyl	1408	-			-a			-u			*			-e			-ów
B2+w(ów)/p2	Gorce		7		-e			*			*			*			-e			-ów
B2+w(ów)/p3	harce		11		-e			*			*			*			-e			-ów
B2+w(y)/m1	czausz		13		-			-a			-u			-owie		-e			-y
B2+w(y)/m2	biegacz		161		-			-a			-u			*			-e			-y
B2+w(y)/m3	kalosz		1135	-			-a			-u			*			-e			-y
B2+w(y)/m3	kalosz		1135	-			-a			-u			*			-e			-y
B2+w(y)/p3	klawisze	2		-			*			*			*			-e			-y
B2+!y/m1	szewc		1		-			-a			-u			-y			-e			-ów							voc -(c)u/(c)ze
B2+(y)/m1	tancerz		1532	-			-a			-u			-e			-e			-y
B2+(y)/m2	kusacz		3		-			-a			-u			*			-e			-y
B2+(y)/m3	Wodacz		3		-			-a			-u			*			-e			-y
B2zce/m3	Chodecz		6		-ecz		-cza		-czu		-cze		-cze		-czów
B2zcs/m3	deszcz		1		-eszcz		-żdżu		-żdżu		*			-żdże		-żdżów
B2zdą+(y)/m3 pieniądz	2		-ądz		-ądza		-ądzu		*			-ądze		-ędzy						ins_pl -ędzmi
B2zdę/m1	ksiądz		1		-ądz		-ędza		-ędzu		-ęża		-ędze[rare]	-ęży						dat -ęszu; voc -ęże; ins_pl -ężmi; dat_pl -ężom; loc_pl -ężach
B2zdó/m1	Inowłódz	1		-ódz		-odza		-odzu		-odze		-odze		-odzów
B2zdó+w/m1	wódz		2		-ódz		-odza		-odzu		-odzowie	-odze		-odzów
B2zre/m3	Chroberz	1		-erz		-rza		-rzu		-rze		-rze		-rzów
B2zrei/m3	kierz		6		-ierz		-rza		-rzu		-rze		-rze		-rzów
B2zró+(y)/m3 Myślibórz	42		-órz		-orza		-orzu		*			-orze		-orzy
B2żą+w/m1	mąż			1		-ąż			-ęża		-ężu		-ężowie		-ęże		-ężów
B2żą+w/m2	wąż			1		-ąż			-ęża		-ężu		*			-ęże		-ężów
B2żą+w/m3	wąż			2		-ąż			-ęża		-ężu		*			-ęże		-ężów
B2żą+w(y)/m2 wąż		2		-ąż			-ęża		-ężu		-ężowie		-ęże		-ęży
B2żą+w(y)/m3 Witowąż	1		-ąż			-ęża		-ężu		*			-ęże		-ęży
B2żó+(y)/m3 nóż			9		-óż			-oża		-ożu		*			-oże		-oży
B3(co)+w/m1	Angelico	5		-co			-ca			-cu			-cowie		-ki			-ców						ins -kiem; voc -co
B3(cq)+w/m1	Gracq		1		-cq			-cqa		-cqu		-cqowie		-ki			-cqów						ins -kiem
B3c+u/m3	Quebec		9		-c			-cu			-cu			*			-ki			-ców						ins -kiem
B3c+w/m1	Balzac		94		-c			-ca			-cu			-cowie		-ki			-ców						ins -kiem
B3c+w/m2	cadillac	5		-c			-ca			-cu			*			-ki			-ców						ins -kiem
B3c+w/m3	panasonic	6		-c			-ca			-cu			*			-ki			-ców						ins -kiem
B3g/m1		szpieg/-log	277		-g			-ga			-gu			-dzy		-gi			-gów
B3gą+u/m3	krąg		23		-ąg			-ęgu		-ęgu		*			-ęgi		-ęgów
B3gą+w/m3	pałąg		2		-ąg			-ęga		-ęgu		-ęgowie		-ęgi		-ęgów
B3gó+uw/m3	stóg		31		-óg			-ogu		-ogu		*			-ogi		-ogów
B3gó+!w/m1	bóg			1		-óg			-oga		-ogu		-ogowie		-ogi		-ogów						voc -oże
B3gó+w/m1	wróg		40		-óg			-oga		-ogu		-ogowie		-ogi		-ogów
B3gó+w/m2	brzuchonóg	37		-óg			-oga		-ogu		*			-ogi		-ogów
B3gó+w/m3	pieróg		17		-óg			-oga		-ogu		*			-ogi		-ogów
B3gró/m3	mórg		1		-órg		-orga		-orgu		-orgowie	-orgi		-orgów
B3gró+u/m3	bórg		1		-órg		-orgu		-orgu		*			-orgi		-orgów
B3(gues)+w/m1 Desargues	1		-ues		-ues'a		-ues'u		-ues'owie	-i			-ues'ów						ins -iem
B3(gu)+w/m1	Doumergue	1		-ue			-ue'a		-ue'u		-ue'owie	-i			-ue'ów						ins -iem
B3k/m1		rybak		1662	-k			-ka			-ku			-cy			-ki			-ków
B3k/m2		czternastak	33		-k			-ka			-ku			*			-ki			-ków
B3k/m3		poprzednik	41		-k			-ka			-ku			*			-ki			-ków
B3k+!/m1	człek		2		-k			-ka			-ku			-cy			-ki			-ków						voc -cze
B3K+-/m1	y			1		-			--a			--u			--owie		--i			--ów
B3K+-/m2	CMYK		2		-			--a			--u			*			--i			--ów
B3K+-/m3	y			4		-			--a			--u			*			--i			--ów
B3K+człowiek/m1 praczłowiek 6	-człowiek	-człowieka	-człowieku	-ludzie		-ludzie		-ludzi						ins_pl -ludźmi
B3K+człowiek/p1 podludzie 1		-ludzie		*			*			-ludzie		-ludzie		-ludzi						ins_pl -ludźmi
B3K+człowiek+!/m1 człowiek 1	-człowiek	-człowieka	-człowieku	-ludzie		-ludzie		-ludzi						voc -człowiecze; ins_pl -ludźmi
B3ke/m1		Turek		4		-ek			-ka			-ku			-cy			-ki			-ków
B3keic+w/m1	Maciek		11		-ciek		-ćka		-ćku		-ćkowie		-ćki		-ćków
B3keic+w/m2	bociek		3		-ciek		-ćka		-ćku		*			-ćki		-ćków
B3kein+w/m1	Heniek		25		-niek		-ńka		-ńku		-ńkowie		-ńki		-ńków
B3kein+w/m2	kleniek		5		-niek		-ńka		-ńku		-ńkowie		-ńki		-ńków
B3kein+w/m3	pieniek		6		-niek		-ńka		-ńku		-ńkowie		-ńki		-ńków
B3keis+w/m1	Czesiek		41		-siek		-śka		-śku		-śkowie		-śki		-śków
B3keis+w/m2	bysiek		3		-siek		-śka		-śku		-śkowie		-śki		-śków
B3keis+w/m3	jasiek		2		-siek		-śka		-śku		-śkowie		-śki		-śków
B3keiz+w/m1	Dziudziek	3		-ziek		-źka		-źku		-źkowie		-źki		-źków
B3ke+latka/m3 roczek	1		-roczek		-roczku		-roczku		*			-latka		-latek
B3(ke)+u/m3	remake		1		-e			-e'u		-e'u		*			-i			-e'ów						ins -iem
B3ke+u/m3	śnieżek		662		-ek			-ku			-ku			*			-ki			-ków
B3(ke)+'w/m1 Blake		5		-e			-e'a		-e'u		-e'owie		-i			-e'ów						ins -iem
B3ke+w/m1	pionek		2969	-ek			-ka			-ku			-kowie		-ki			-ków
B3ke+w/m2	amorek		573		-ek			-ka			-ku			*			-ki			-ków
B3ke+w/m3	stożek		2209	-ek			-ka			-ku			*			-ki			-ków
B3ke+w/p1	pradziadkowie 2		-kowie		*			*			-kowie		-ki			-ków
B3ke+w/p2	korki		1		-ki			*			*			*			-ki			-ków
B3ke+w/p3	portaski	1		-ki			*			*			*			-ki			-ków
B3ko/m3		Akademgorodok 1		-ok			-ka			-ku			*			-ki			-ków
B3(ko)+w/m1	Mieszko		35		-o			-a			-u			-owie		-i			-ów
B3(ko)+w/m2	guanako		3		-o			-a			-u			*			-i			-ów
B3K+-u/m3	NIK			13		-			--u			--u			*			--i			--ów
B3K+ystok/m3 Białystok	5		-ystok		-egostoku	-ymstoku	*			-estoki		-ychstoków					voc -ystoku
B3+lata/m3	rok			1		-rok		-roku		-roku		*			-lata		-lat						ins_pl -latami/laty[obsolete]
B3q/m1		Haq			1		-q			-qa			-qu			-qowie		-ki			-qów						ins -kiem
B3(ques)+w/m1 Jacques	1		-cques		-cques'a	-cques'u	-cques'owie	-ki			-cques'ów					ins -kiem
B3(que)+u/m3 boutique	1		-que		-que'u		-que'u		*			-ki			-que'ów						ins -kiem
B3(que)+w/m1 Remarque	1		-que		-que'a		-que'u		-que'owie	-ki			-que'ów						ins -kiem
B3(qu)+w/m1 Jaques		1		-ques		-ques'a		-ques'u		-ques'owie	-ki			-ques'ów					ins -kiem
B3+u/m3		ślizg		1742	-			-u			-u			*			-i			-ów
B3+w/m1		kurpik		7558	-			-a			-u			-owie		-i			-ów
B3+w/m2		bakteriofag	901		-			-a			-u			*			-i			-ów
B3+w/m3		storczyk	2802	-			-a			-u			*			-i			-ów
B3+w/p1		małżonkowie	4		-owie		*			*			-owie		-i			-ów
B3+w/p2		żłóbczaki	372		-i			*			*			*			-i			-ów
B3+w/p3		baraszki	537		-i			*			*			*			-i			-ów
B4/m1		acan		4476	-			-a			-ie			-owie		-y			-ów
B4/m2		pion		658		-			-a			-ie			*			-y			-ów
B4/m3		chleb		2415	-			-a			-ie			*			-y			-ów
B4/p2		plecy		408		-y			*			*			*			-y			-ów
B4/p3		androny		647		-y			*			*			*			-y			-ów
B4+!/m1		skurwysyn	1		-			-a			-ie/u		-i			-y			-ów							voc -u
B4+-/m1		z			1		-			--a			-ecie		--owie		--y			--ów
B4+-/m2		z			1		-			--a			-ecie		*			--y			--ów
B4+-/m3		z			1		-			--a			-ecie		*			--y			--ów
B4+0/m3		gram		1		-			-a			-ie			-owie		-y			-[count]
B4+a/m3		ekspens		7		-			-u			-ie			*			-a			-ów							organ/wolumen/wolumin/sekstern/interes/ekspens/sukurs
B4bą+u/m3	dąb			29		-ąb			-ębu		-ębie		*			-ęby		-ębów
B4bą+w/m1	dziewosłąb	3		-ąb			-ęba		-ębie		-ębowie		-ęby		-ębów
B4bą+w/m2	jarząb		6		-ąb			-ęba		-ębie		*			-ęby		-ębów
B4bą+w/m3	ząb			6		-ąb			-ęba		-ębie		*			-ęby		-ębów
B4bą+w/p1	dziewosłęby	1		-ęby		*			*			*			-ęby		-ębów
B4be+(u)/m2	łeb			1		-eb			-ba			-bie		-bowie		-by			-bów
B4be+(u)/m3	łeb			1		-eb			-ba			-bie		*			-by			-bów
B4be+w/m1	wichrzyłeb	1		-eb			-ba			-bie		-bowie		-by			-bów
B4bó/m1		chleborób	12		-ób			-oba		-obie		-obi/obowie	-oby		-obów
B4bó/m2		brzytwodziób 8		-ób			-oba		-obie		*			-oby		-obów
B4bó/m3		dziób		2		-ób			-oba		-obie		*			-oby		-obów
B4bó+u/m3	grób		13		-ób			-obu		-obie		*			-oby		-obów
B4bó+w/m1	Sposób		4		-ób			-oba		-obie		-obowie		-oby		-obów
B4(ce)+'/m1	Wallace		6		-ce			-ce'a		-sie		-ce'owie	-ce'y		-ce'ów
B4(ce)+'/m2	breakdance	6		-ce			-ce'a		-sie		*			-ce'y		-ce'ów
B4(ce)+'u/m3 interface	3		-ce			-ce'u		-sie		*			-ce'y		-ce'ów
B4+ćpan/m1	imćpan		1		-ćpan		-cipana		-cipanu		-ćpanowie	-cipany		-cipanów					voc -cipanie
B4d+a/m3	cud			1		-			-u			-(d)zie		*			-a			-ów
B4da/m3		obiad		2		-ad			-adu		-edzie		*			-ady		-adów
B4dą+u/m3	wzgląd		12		-ąd			-ędu		-ędzie		*			-ędy		-ędów
B4de/m1		sąsiad		2		-ad			-ada		-edzie		-edzi		-ady		-adów
B4de+u/m3	przód		1		-ód			-odu		-edzie		*			-ody		-odów
B4d+i/m1	chasyd		77		-			-a			-(d)zie		-(d)zi		-(d)y		-(d)ów
B4dó+u/m3	dowód		114		-ód			-odu		-odzie		*			-ody		-odów
B4dó+u/p3	podchody	2		-ody		*			*			*			-ody		-odów
B4dó+w/m1	koniowód	21		-ód			-oda		-odzie		-odowie		-ody		-odów
B4dó+w/m2	grzbietoród	5		-ód			-oda		-odzie		*			-ody		-odów
B4d+u/m3	zakład		545		-			-u			-(d)zie		*			-(d)y		-(d)ów
B4d+u/p3	Z-dy		2		-y			*			*			*			-(d)y		-(d)ów
B4d+u!/m3	lud			1		-			-u			-(d)zie		*			-(d)y		-(d)ów						voc -u
B4D+-u/m3	ZBOWiD,CAD	4		-u			--u			--zie		*			--y			--ów
B4d+!w/m1	dziad		1		-			-a			-(d)zie		-(d)owie	-(d)y		-(d)ów						voc -u
B4d+w/m1	Herald		311		-			-a			-(d)zie		-(d)owie	-(d)y		-(d)ów
B4d+w/m2	almand		87		-			-a			-(d)zie		*			-(d)y		-(d)ów
B4d+w/m3	listopad	53		-			-a			-(d)zie		*			-(d)y		-(d)ów
B4d+w/p2	Niderlandy	66		-y			*			*			*			-(d)y		-(d)ów
B4d+w/p3	bokobrody	101		-y			*			*			*			-(d)y		-(d)ów
B4D+-w/m3	CAD,BERD	2		-			--a			--zie		--owie		--y			--ów
B4dza/m3	zjazd		17		-azd		-azdu		-eździe		*			-azdy		-azdów
B4dzó/m3	Gózd		2		-ózd		-ozdu		-oździe		*			-ozdy		-ozdów
B4dz+u/m3	gwizd		6		-zd			-zdu		-ździe		*			-zdy		-zdów
B4dz+w/m1	Gorazd		9		-zd			-zda		-ździe		-zdowie		-zdy		-zdów
B4dz+w/m3	drozd		1		-zd			-zda		-ździe		*			-zdy		-zdów
B4+e/m2		kontredans	3		-			-a			-ie			*			-e			-ów
B4+e/m3		kwadrans	2		-			-a			-ie			*			-e			-ów
B4+e/p2		Tyszowce	104		-			*			*			*			-e			-ów
B4+e/p3		sztućce		138		-			*			*			*			-e			-ów
B4ed+'u/m3	offside		3		-e			-e'u		-zie		*			-e'y		-e'ów
B4ed+'w/m1	Claude		7		-e			-e'a		-zie		-e'owie		-e'y		-e'ów
B4ed+'w/m2	allemande	1		-e			-e'a		-zie		*			-e'y		-e'ów
B4e+i/m1	cicerone	1		-e			-a			-ie			-owie/i		-y			-ów
B4ens+'w/m1	Daisne		1		-sne		-sne'a		-śnie		-sne'owie	-sne'y		-sne'ów
B4(es)+'/m1	Gennes		2		-es			-es'a		-ie			-es'owie	-es'y		-es'ów
B4e+'u/m3	regime		10		-e			-e'u		-ie			*			-e'y		-e'ów
B4e+'!w/m1	Marlowe		4		-			-'a			-			-'owie		-'y			-'ów						voc as nom/loc
B4e+'w/m1	Larousse	22		-e			-e'a		-ie			-e'owie		-e'y		-e'ów
B4e+'w/m2	anglaise	5		-e			-e'a		-ie			*			-e'y		-e'ów
B4e+'w/m3	Danone		5		-e			-e'a		-ie			*			-e'y		-e'ów
B4F+-u/m3	AWF,ABS		217		-			--u			--ie		*			--y			--ów
B4g+w/m1	d'Estaing	1		-g			-ga			-ie			-gowie		-gy			-gów						voc as nom
B4h/m1		mnich,Czech	6		-ch			-cha		-chu		-si			-chy		-chów
B4H+-/m3	PIH			4		-			--u			--u			*			--y			--ów
B4hced/m3	dech		1		-dech		-tchu		-tchu		*			-tchy		-tchów
B4hce+u/m3	mech		1		-ech		-chu		-chu		*			-chy		-chów
B4hce+w/m1	Mniszech	1		-ech		-cha		-chu		-chowie		-chy		-chów
B4hd+w/m1	Lundegårdh	1		-h			-ha			-(d)zie		-howie		-hy			-hów
B4hn+u/m3	Minh		1		-h			-hu			-(n)ie		*			-hy			-hów
B4hn+w/m1	Minh		1		-h			-ha			-(n)ie		-howie		-hy			-hów
B4hp+w/m1	Joseph		1		-ph			-pha		-fie		-phowie		-phy		-phów
B4h+u/m3	sztych		183		-			-u			-u			*			-y			-ów
B4h+w/m1	lizuch		959		-			-a			-u			-owie		-y			-ów
B4h+w/m2	Moloch		50		-			-a			-u			*			-y			-ów
B4h+w/m3	brzuch		118		-			-a			-u			*			-y			-ów
B4h+w/p2	Tychy		13		-y			*			*			*			-y			-ów
B4h+w/p3	Tychy		14		-y			*			*			*			-y			-ów
B4+i/m1		intruz		969		-			-a			-ie			-i			-y			-ów
B4+(ie)/m1	cygan		13		-			-a			-ie			-ie			-y			-ów
B4+(ie)0/m1	zakrystian	1		-			-a			-ie			-ie			-y			-
B4le/m3		kościół		2		-ół			-oła		-ele		-ołowie		-oły		-ołów
B4le+u/m3	popioł		1		-ół			-ołu		-ele		*			-oły		-ołów
B4łeic/m3	kocieł		1		-cieł		-tła		-tle		-tłowie		-tły		-tłów
B4łei+w/m1	Szczygieł	2		-ieł		-ła			-le			-łowie		-ły			-łów
B4łei+w/m2	bargieł		3		-ieł		-ła			-le			*			-ły			-łów
B4łei+w/m3	kieł,węgieł	5		-ieł		-ła			-le			*			-ły			-łów						in -[gk]ieł except Kozieł (gen Kozła, loc/voc Kozle)
B4łeiz/m2	kozieł		1		-zieł		-zła		-źle		-złowie		-zły		-złów
B4łes+w/m1	poseł		6		-seł		-sła		-śle		-słowie		-sły		-słów
B4łes+w/m2	suseł		1		-seł		-sła		-śle		*			-sły		-słów
B4łe+(u)i/m1 diabeł		1		-eł			-ła			-le			-li			-ły			-łów						dat -łu
B4łe+(u)i/m2 diabeł		1		-eł			-ła			-le			*			-ły			-łów						dat -łu
B4łe+w/m1	Gaweł		20		-eł			-ła			-le			-łowie		-ły			-łów
B4łe+w/m2	wyżeł		1		-eł			-ła			-le			*			-ły			-łów
B4łe+w/m3	supeł		5		-eł			-ła			-le			*			-ły			-łów
B4łezr+w/m1	orzeł		4		-rzeł		-rła		-rle		-rłowie		-rły		-rłów
B4łezr+w/m2	podkarzeł	4		-rzeł		-rła		-rle		*			-rły		-rłów
B4łezr+w/m3	Orzeł		1		-rzeł		-rła		-rle		*			-rły		-rłów
B4łez+(u)w/m1 orzeł		1		-rzeł		-rła		-rle		-rłowie		-rły		-rłów						dat -rłu
B4łez+(u)w/m2 orzeł		1		-rzeł		-rła		-rle		*			-rły		-rłów						dat -rłu
B4łez+w/m1	Gruzeł		4		-zeł		-zła		-źle		-złowie		-zły		-złów
B4łez+w/m2	Węzeł		1		-zeł		-zła		-źle		*			-zły		-złów
B4łez+w/m3	węzeł		5		-zeł		-zła		-źle		*			-zły		-złów
B4ł+i/m1	Hucuł		4		-ł			-ła			-le			-li			-ły			-łów
B4łł+w/m1	Radziwiłł	3		-łł			-łła		-lle		-łłowie		-łły		-łłów
B4ło+i/m1	anioł		4		-oł			-oła		-ele		-eli/ołowie	-oły		-ołów
B4łoic/m3	kocioł		1		-cioł		-tła		-tle		-tłowie		-tły		-tłów
B4łoic/p3	kotły		1		-tły		*			*			*			-tły		-tłów
B4łois+(u)w/m2 osioł	3		-sioł		-sła		-śle		-słowie		-sły		-słów						dat -słu
B4łois+w/m1 osioł		1		-sioł		-sła		-śle		-słowie		-sły		-słów
B4łois+w/m2 półosioł	2		-sioł		-sła		-śle		*			-sły		-słów
B4łoiz+w/m1 kozioł		2		-zioł		-zła		-źle		-złowie		-zły		-złów
B4łoiz+w/m2 kozioł		1		-zioł		-zła		-źle		*			-zły		-złów
B4łoiz+w/m3 kozioł		2		-zioł		-zła		-źle		*			-zły		-złów
B4łó+i/m1	sokół		1		-ół			-oła		-ole		-oli		-oły		-ołów
B4łó+u/m2	piżmowół	3		-ół			-ołu		-ole		*			-oły		-ołów
B4łó+u/m3	zespół		48		-ół			-ołu		-ole		*			-oły		-ołów
B4łó+w/m1	kopidół		18		-ół			-oła		-ole		-ołowie		-oły		-ołów
B4łó+w/m2	dół			5		-ół			-oła		-ole		*			-oły		-ołów
B4łó+w/m3	kół			7		-ół			-oła		-ole		*			-oły		-ołów
B4łs+u/m3	niedomysł	11		-sł			-słu		-śle		*			-sły		-słów
B4łs+w/m1	Przemysł	16		-sł			-sła		-śle		-słowie		-sły		-słów
B4ł+u/m3	kanał		304		-ł			-łu			-le			*			-ły			-łów
B4ł+w/m1	nielegał	324		-ł			-ła			-le			-łowie		-ły			-łów
B4ł+w/m2	bucefał		30		-ł			-ła			-le			*			-ły			-łów
B4ł+w/m3	sandał		21		-ł			-ła			-le			*			-ły			-łów
B4me+u/m3	najem		4		-em			-mu			-mie		*			-my			-mów
B4me+w/m1	Najem		1		-em			-ma			-mie		-mowie		-my			-mów
B4nes+u/m3	sen			3		-sen		-snu		-śnie		*			-sny		-snów
B4ne+u/m3	len			2		-en			-nu			-nie		*			-ny			-nów
B4ne+w/m1	Bęben		3		-en			-na			-nie		-nowie		-ny			-nów
B4ne+w/m2	bęben		1		-en			-na			-nie		*			-ny			-nów
B4ne+w/m3	bochen		1		-en			-na			-nie		*			-ny			-nów
B4nez+i/m1	błazen		1		-zen		-zna		-źnie		-źni		-zny		-znów
B4nez+w/m1	błazen		1		-zen		-zna		-źnie		-znowie		-zny		-znów
B4ni/m1		muzułmanin	56		-in			-ina		-inie		-ie			-y			-ów
B4ni+0/m1	krakowianin	2140	-in			-ina		-inie		-ie			-y			-
B4ni+w/m1	Germanin	2		-in			-ina		-inie		-owie		-y			-ów
B4+(num.)/m3 raz		1		-			-a[count]/-u -ie		*			-y			-y[count]/ów
B4od+w/m1	Alfredo		47		-o			-a			-(d)zie		-(d)owie	-(d)y		-(d)ów
B4od+w/m2	kupido		4		-o			-a			-(d)zie		*			-(d)y		-(d)ów
B4o+i/m1	mafioso		2		-o			-a			-ie			-i			-a			-ów
B4o+(in)/m1	Apollo		1		-o			-ina		-inie		-inowie		-iny		-inów
B4o+(on)/m1	Cycero		9		-o			-ona		-onie		-onowie		-ony		-onów						voc -o/onie
B4or+w/m1	maestro		27		-ro			-ra			-rze		-rowie		-ry			-rów						voc -ro
B4or+w/m3	pampero		1		-ro			-ra			-rze		*			-ry			-rów						voc -ro
B4ot+w/m1	Canaletto	20		-to			-ta			-cie		-towie		-ty			-tów						voc -to
B4ot+w/m2	putto		20		-to			-ta			-cie		*			-ty			-tów						voc -to
B4o+!w/m1	Picasso		44		-o			-a			-ie			-owie		-y			-ów							voc -o
B4o+w/m1	Zdzicho		2		-o			-a			-u			-owie		-y			-ów
B4pei+w/m1	kiep		1		-iep		-pa			-pie		-powie[rare] -py		-pów
B4pei+w/m3	kiep		1		-iep		-pa			-pie		*			-py			-pów
B4pe+w/m3	półwysep	4		-ep			-pu			-pie		*			-py			-pów
B4(phe)+'/m1 Christophe	1		-phe		-phe'a		-fie		-phe'owie	-phe'y		-phe'ów
B4R+-/m2	TIR,STAR	2		-			--a			--ze		--owie		--y			--ów
B4rbó+u/m3	Bóbr		1		-óbr		-obru		-obrze		*			-obry		-obrów
B4rbó+w/m2	bóbr		1		-óbr		-obra		-obrze		-obrowie	-obry		-obrów
B4rec/m3	amfimacer	2		-cer		-kra		-krze		*			-kry		-krów
B4rec+u/m3	amfimacer	2		-cer		-kru		-krze		*			-kry		-krów
B4rei+u/m3	cukier		13		-ier		-ru			-rze		*			-ry			-rów
B4rei+w/m1	junkier		11		-ier		-ra			-rze		-rowie		-ry			-rów
B4rei+w/m2	wągier		4		-ier		-ra			-rze		*			-ry			-rów
B4rei+w/m3	ablegier	11		-ier		-ra			-rze		*			-ry			-rów
B4rei+y/m1	Węgier		7		-ier		-ra			-rze		-rzy		-ry			-rów
B4r(es)+'w/m1 Ingres	1		-res		-res'a		-rze		-res'owie	-res'y		-res'ów
B4r(e)+'u/m3 software	10		-re			-re'u		-rze		*			-re'y		-re'ów
B4re+u/m3	wicher		39		-er			-ru			-rze		*			-ry			-rów
B4r(e)+'w/m1 Astaire	12		-re			-re'a		-rze		-re'owie	-re'y		-re'ów
B4r(e)+'w/m3 brumaire	2		-re			-re'a		-rze		*			-re'y		-re'ów
B4re+w/m1	Aleksander	78		-er			-ra			-rze		-rowie		-ry			-rów
B4re+w/m2	Skamander	14		-er			-ra			-rze		*			-ry			-rów
B4re+w/m3	świder		70		-er			-ra			-rze		*			-ry			-rów
B4re+y/m1	Holender	52		-er			-ra			-rze		-rzy		-ry			-rów
B4r(h)+u/m3	Aligarh		1		-rh			-rhu		-rze		*			-rhy		-rhów
B4r(o)+y/m1	banderillero 2		-ro			-ra			-rze		-rzy		-ry			-rów
B4ró+u/m3	zbiór		120		-ór			-oru		-orze		*			-ory		-orów
B4ró+w/m1	rymotwór	44		-ór			-ora		-orze		-orowie		-ory		-orów
B4ró+w/m2	białozór	11		-ór			-ora		-orze		*			-ory		-orów
B4ró+w/m3	topór		13		-ór			-ora		-orze		*			-ory		-orów
B4ró+y/m1	doktór		4		-ór			-ora		-orze		-orzy		-ory		-orów
B4r(re)+w/m1 Pierre		4		-rre		-rre'a		-rze		-rre'owie	-rre'y		-rre'ów
B4r(ro)+w/m1 Pizarro	2		-rro		-rra		-rze		-rrowie		-rry		-rrów						voc -rro
B4rr+w/m1	Starr		2		-rr			-rra		-rze		-rrowie		-rry		-rrów
B4rr+w/m2	birr		2		-rr			-rra		-rze		*			-rry		-rrów
B4rr+w/m3	parr		2		-rr			-rra		-rze		*			-rry		-rrów
B4r(s)+u/m3	parcours	1		-rs			-rsu		-rze		*			-rsy		-rsów
B4rta+u/m3	wiatr		4		-atr		-atru		-etrze		*			-atry		-atrów
B4r+u/m3	browar		931		-r			-ru			-rze		*			-ry			-rów
B4r+u/p3	moczary		1		-ry			*			*			*			-ry			-rów
B4R+-u/m3	BOR			39		-			--u			--ze		*			--y			--ów
B4r+w/m1	Adenauer	2106	-r			-ra			-rze		-rowie		-ry			-rów
B4r+w/m2	amur		243		-r			-ra			-rze		*			-ry			-rów
B4r+w/m3	litr		243		-r			-ra			-rze		*			-ry			-rów
B4r+w/p3	labry		1		-ry			*			*			*			-ry			-rów
B4r+y/m1	zecer		1010	-r			-ra			-rze		-rzy		-ry			-rów
B4r+y/m3	manipulator	3		-r			-ra			-rze		*			-ry			-rów
B4s+'/p3	cornflakes	1		-s			*			*			*			-s			-'ów
B4S+-/m1	VIP			2		-			--a			--ie		--owie		--y			--ów
B4S+-/m2	AIDS,UNIX	7		-			--a			--ie		*			--y			--ów
B4S+-/m3	x			3		-			--a			--ie		*			--y			--ów
B4s+0/p3	cornflakes	1		-s			*			*			*			-s			-sów
B4sa+u/m3	las			19		-as			-asu		-esie		*			-asy		-asów
B4są/m3		otrząs		1		-ąs			-ęsu		-ęsie		*			-ęsy		-ęsów
B4sei+(u)/m1 pies		1		-ies		-sa			-sie		-sowie		-sy			-sów						dat -su
B4sei+(u)/m2 pies		2		-ies		-sa			-sie		*			-sy			-sów						dat -su
B4sei+w/m1	Owies		1		-ies		-sa			-sie		-sowie		-sy			-sów
B4sei+w/m3	owies		1		-ies		-sa			-sie		*			-sy			-sów
B4s+!w/m1	Jezus		1		-s			-sa			-sie		-sowie		-sy			-sów						voc -
B4T+-/m3	WAT,KRRiT	14		-T			-T-u		--cie		*			-T-y		-T-ów
B4t+0/m3	procent		3		-t			-ta[count]/t[count] -cie *			-t[count]	-t[count]
B4t+a/m1	brat		4		-t			-ta			-cie		-cia		-ty			-ci							dat -tu; ins_pl -ćmi; dat_pl -ciom; loc_pl -ciach
B4t+a/p1	b-cia		1		-cia		*			*			-cia		-ty			-ci							ins_pl -ćmi; dat_pl -ciom; loc_pl -ciach
B4ta/m3		wszechświat	1		-at			-ata		-ecie		*			-aty		-atów
B4TA+-/m3	VAT,DAT		6		-AT			-AT-u		-acie		*			-AT-y		-AT-ów
B4ta+(u)/m3	świat		11		-at			-ata		-ecie		*			-aty		-atów						dat -atu
B4ta+u/m3	kwiat		19		-at			-atu		-ecie		*			-aty		-atów
B4tą+u/m3	szcząt		1		-ąt			-ętu		-ęcie		*			-ęty		-ętów
B4tc+w/m3	compact		1		-ct			-ctu		-kcie		-ctowie		-cty		-ctów
B4(tes)/m1	Descartes	1		-tes		-tes'a		-cie		-tes'owie	-tes'y		-tes'ów
B4tes+u/m3	oset		1		-set		-stu		-ście		*			-sty		-stów
B4tes+w/m1	Oset		1		-set		-sta		-ście		-stowie		-sty		-stów
B4T+-(etu)/m3 BZ		19		-			--etu		--ecie		*			--ety		--etów
B4te+u/m3	ocet		2		-et			-tu			-cie		*			-ty			-tów
B4t(e)+'w/m1 Bellonte	8		-te			-te'a		-cie		-te'owie	-te'y		-te'ów
B4t(e)+'w/m2 courante	1		-te			-te'a		-cie		*			-te'y		-te'ów
B4te+w/m1	Ocet		1		-et			-tu			-cie		-towie		-ty			-tów
B4t(hes)+w/m1 Barthes	1		-thes		-thes'a		-cie		-thes'owie	-thes'y		-thes'ów
B4t(he)+w/m1 Forsythe	2		-the		-the'a		-cie		-the'owie	-the'y		-the'ów
B4t(h)+!w/m1 Smith,Keith 8		-th			-tha		-sie/cie	-thowie		-thy		-thów
B4t(h)+w/m1	Hindemith	25		-th			-tha		-cie		-thowie		-thy		-thów
B4t(h)+w/m3	plymouth	1		-th			-tha		-cie		*			-thy		-thów
B4t+i/m1	konkurent	582		-t			-ta			-cie		-ci			-ty			-tów
B4t+i/p1	Parcelanci	1		-ci			*			*			-ci			-ty			-tów
B4TI+-/m3	PIT			4		-IT			-IT-u		-icie		*			-IT-y		-IT-ów
B4TiRR+-/m3	KRRiT		1		-RRiT		-RRiT-u		-rricie		*			-RRiT-y		-RRiT-ów
B4TO+-/m3	LOT			2		-OT			-OT-u		-ocie		*			-OT-y		-OT-ów
B4T+-(otu)/m3 PTJ		5		-			--otu		--ocie		*			--oty		--otów
B4tó+u/m3	powrót		15		-ót			-otu		-ocie		*			-oty		-otów
B4tó+w/m1	Nawrót		5		-ót			-ota		-ocie		-otowie		-oty		-otów
B4tó+w/m2	Wywrót		1		-ót			-ota		-ocie		*			-oty		-otów
B4tó+w/m3	kołowrót	1		-ót			-ota		-ocie		*			-oty		-otów
B4tó+w/m3	PAGART		1		-AGART		-AGART-u	-agarcie	*			-AGART-y	-AGART-ów
B4ts(es)+w/m1 Costes	1		-stes		-stes'a		-ście		-stes'owie	-stes'y		-stes'ów
B4tse+u/m3	chrzest		2		-est		-tu			-cie		*			-ty			-tów
B4ts(e)+w/m1 Benveniste	1		-ste		-ste'a		-ście		-ste'owie	-ste'y		-ste'ów
B4ts+i/m1	oszust		4		-st			-sta		-ście		-ści		-sty		-stów
B4ts(o)/m1	Mefisto		3		-sto		-sta		-ście		-stowie		-sty		-stów
B4ts+u/m3	agrest		196		-st			-stu		-ście		*			-sty		-stów
B4ts+ua/m3	gust		4		-st			-stu		-ście		*			-sta		-stów
B4ts+w/m1	August		113		-st			-sta		-ście		-stowie		-sty		-stów
B4ts+w/m2	chłyst		9		-st			-sta		-ście		*			-sty		-stów
B4ts+w/m3	pancerfaust	8		-st			-sta		-ście		*			-sty		-stów
B4tt+w/m1	Czeczott	22		-tt			-tta		-cie		-ttowie		-tty		-ttów
B4t+u/m3	kłopot		2294	-t			-tu			-cie		*			-ty			-tów
B4T+-u/m3	MSZ,BZ		15		-			--u			--ecie		*			--y			--ów
B4t+(u)a/m1	psubrat		1		-t			-ta			-cie		-cia		-ty			-tów						dat -tu
B4t+ua/m3	grunt		18		-t			-tu			-cie		*			-ta			-tów
B4t+(u)i/m1	czart,kat	2		-t			-ta			-cie		-ci			-ty			-tów						dat -towi/tu
B4t+(u)w/m1	sukinkot	2		-t			-ta			-cie		-towie		-ty			-tów						dat -tu
B4t+(u)w/m2	kot,czart	4		-t			-ta			-cie		*			-ty			-tów						dat -tu
B4t+w/m1	Blériot		1115	-t			-ta			-cie		-towie		-ty			-tów
B4t+w/m2	abisobiont	231		-t			-ta			-cie		*			-ty			-tów
B4t+w/m3	młot		217		-t			-ta			-cie		*			-ty			-tów
B4t+w/p3	panty		2		-ty			*			*			*			-ty			-tów
B4t+u/m3	skarb		5351	-			-u			-ie			*			-y			-ów
B4t+u/n2	opus		1		-			-u			-ie			*			-y			-ów							(NOTE: voc and nom_pl correct per SGJP despite being a neuter; need to check elsewhere)
B4t+u/p2	Zięby		29		-y			*			*			*			-y			-ów
B4t+u/p3	wyływy		30		-y			*			*			*			-y			-ów
B4t+u!/m3	dom			1		-			-u			-u			*			-y			-ów							voc -ie
B4t+(u)/m1	chłop		3		-			-a			-ie			-i			-y			-ów							dat -u
B4t+(u)/m2	babochłop	1		-			-a			-ie			*			-y			-ów							dat -u
B4+ua/m3	regestr		1		-r			-ru			-rze		*			-ra			-rów
B4+ue/m3	dysonans	27		-			-u			-ie			*			-e			-ów
B4(us)/m3	ablatiwus	22		-us			-u			-ie			*			-y			-ów
B4+(u)!w/m1	pan			18		-			-a			-u			*			-y			-ów							voc -ie; dat -u
B4+u(y?)/m3	czas		1		-			-u			-ie			*			-y			-ów							ins_pl -ami/y[dated]
B4+w/m1		sampan		1		-			-a			-u			-owie		-y			-ów							voc -ie
B4+!w/m1	Arrow,Shaw	38		-			-a			-			-owie		-y			-ów
B4we/m3		szew		1		-ew			-wa			-wie		*			-wy			-wów
B4we+(u)/m2	lew			3		-ew			-wa			-wie		*			-wy			-wów
B4we+(u?)/m1 Lew		1		-ew			-wa			-wie		-wowie		-wy			-wów						dat -wu/wowi[rare]
B4we+u/m3	pozew		3		-ew			-wu			-wie		*			-wy			-wów
B4we+ystaw/m3 Krasnystaw 1		-ystaw		-egostawu	-ymstawie	*			-estawy		-ychstawów					voc -ystawie
B4wó+(u)/m3	Berdyczów	2270	-ów			-owa		-owie		*			-owy		-owów						dat -owu[archaic (only in "ku")]
B4wó+u/m3	cudzysłów	28		-ów			-owu		-owie		*			-owy		-owów
B4wó+w/m1	pustogłów	118		-ów			-owa		-owie		-owowie		-owy		-owów
B4wó+w/m2	kolcogłów	10		-ów			-owa		-owie		*			-owy		-owów
B4wó+w/m3	wygwizdów	2276	-ów			-owa		-owie		*			-owy		-owów
B4x/m1		Max			9		-x			-ksa		-ksie		-ksowie		-ksy		-ksów
B4x/m2		melex		5		-x			-ksa		-ksie		*			-ksy		-ksów
B4x/m3		Fenix		3		-x			-ksa		-ksie		*			-ksy		-ksów
B4x+u/m3	appendix	24		-x			-ksu		-ksie		*			-ksy		-ksów
B4x+w/m1	Merckx		1		-x			-sa			-sie		-sowie		-sy			-sów
B4zą/m3		pawąz		1		-ąz			-ęza		-ęzie		-ęzowie		-ęzy		-ęzów
B4zą+u/m3	grąz		2		-ąz			-ęzu		-ęzie		*			-ęzy		-ęzów
B4ze/m3		Łobez		1		-ez			-za			-zie		-zowie		-zy			-zów
B4zei/m2	giez		1		-iez		-za			-zie		-zowie		-zy			-zów
B4zei+u/m3	bez			1		-ez			-zu			-zie		*			-zy			-zów
B4zó+u/m3	obóz		46		-óz			-ozu		-ozie		*			-ozy		-ozów
B4zó+w/m1	smarowóz	5		-óz			-oza		-ozie		-ozowie		-ozy		-ozów
B4zó+w/m2	Przewóz		1		-óz			-oza		-ozie		*			-ozy		-ozów
B4zó+w/m3	powróz		4		-óz			-oza		-ozie		*			-ozy		-ozów
]=]



decls["hard-m"] = function(base, stems)
	-- Nouns ending in hard -c, e.g. [[hec]] "joke", [[kibuc]] "kibbutz", don't palatalize.
	base.palatalize_voc = not rfind(stems.vowel_stem, "c$")
	base.hard_c = true
	local velar = base.velar or not base["-velar"] and rfind(stems.vowel_stem, com.velar_c .. "$")
	-- See [https://prirucka.ujc.cas.cz/en/?id=360] on declension of toponyms.
	local toponym = base.animacy == "inan" and rfind(base.lemma, "^" .. com.uppercase_c)
	-- Some toponyms take -a in the genitive singular, e.g. toponyms in -ín ([[Zlín]], [[Jičín]], [[Berlín]]);
	-- -ýn ([[Hostýn]], [[Londýn]]); -ov ([[Havířov]]); and -ev ([[Bezdrev]]), as do some others, e.g. domestic
	-- [[Beroun]], [[Brandýs]], [[Náchod]], [[Tábor]] and foreign [[Betlém]] "Bethlehem", [[Egypt]],
	-- [[Jeruzalém]] "Jerusalem", [[Milán]] "Milan", [[Řím]] "Rome", [[Rýn]] "Rhine". Also some transferred from
	-- common nouns e.g. ([[Nový]]) [[Kostel]], ([[Starý]]) [[Rybník]].
	local toponym_gen_a = toponym and (rfind(base.lemma, "[íý]n$") or rfind(base.lemma, "[oe]v$"))
	-- Toponyms in -ík (Mělník, Braník, Rakovník, Lipník) seem to fluctuate between gen -a and -u. Also some in
	-- ‑štejn, ‑berg, ‑perk, ‑burk, ‑purk (Rabštejn, Heidelberg, Kašperk, Hamburk, Prešpurk) and some others:
	-- Zbiroh, Kamýk, Příbor, Zábřeh, Žebrák, Praděd.
	local toponym_gen_a_u = toponym and rfind(base.lemma, "ík$")
	-- Toponyms that take -a in the genitive singular tend to take -ě in the locative singular; so do those in
	-- -štejn (Rabštejn), -hrad (Petrohrad), -grad (Volgograd).
	local toponym_loc_e = toponym and (toponym_gen_a or rfind(base.lemma, "štejn$") or rfind(base.lemma, "[gh]rad$"))
	-- Toponyms in -ík seem to fluctuate between loc -ě and -u.
	local toponym_loc_e_u = toponym_gen_a_u
	-- Inanimate gen_s in -a other than toponyms in -ín/-ýn/-ev/-ov (e.g. [[zákon]] "law", [[oběd]] "lunch", [[kostel]] "church",
	-- [[dnešek]] "today", [[leden]] "January", [[trujúhelník]] "triangle") needs to be given manually, using '<gena>'.
	local gen_s = toponym_gen_a and "a" or toponym_gen_a_u and {"a", "u"} or base.animacy == "inan" and "u" or "a"
	-- Animates with dat_s only in -u (e.g. [[člověk]] "person", [[Bůh]] "God") need to give this manually,
	-- using '<datu>'.
	local dat_s = base.animacy == "inan" and "u" or base.surname and "ovi" or {"ovi", "u"}
	-- Inanimates with loc_s in -e/ě other than certain toponyms (see above) need to give this manually, using <locě>, but
	-- it will trigger the second palatalization automatically.
	local loc_s = toponym_loc_e and "ě" or toponym_loc_e_u and {"ě", "u"} or dat_s
	-- Velar-stem animates with voc_s in -e (e.g. [[Bůh]] "God", voc_s 'Bože'; [[člověk]] "person", voc_s 'člověče')
	-- need to give this manually using <voce>; it will trigger the first palatalization automatically.
	local voc_s = velar and "u" or "e" -- 'e' will trigger first palatalization in apply_special_cases()
	-- Nom_p in -i will trigger second palatalization in apply_special_cases().
	local nom_p = base.animacy == "inan" and "y" or default_masc_animate_nom_pl(base, stems)
	-- Per IJP and Janda and Townsend:
	-- * loc_p in -ích is currently the default for velars but not otherwise; it will automatically trigger the second
	--   palatalization (e.g. [[práh]] "threshold", loc_p 'prazích'). Otherwise, -ích needs to be given manually using
	--   <locplích>, e.g. [[les]] "forest"; [[hotel]] "hotel"; likewise for loc_p in -ách (e.g. [[plech]]
	--   "metal plate"), using <locplách>.
	-- * Inanimate hard nouns in -c normally have -ech: [[hec]] "joke", [[tác]] "tray", [[truc]], [[kec]], [[frc]],
	--   [[flanc]], [[kibuc]] "kibbutz", [[pokec]] "chat".
	-- In the IJP tables, inanimate reducible nouns in -ček (and most in -cek, although there are many fewer; also some
	-- in -žek, but in this case it's too inconsistent to make the default) regularly have both -ích and -ách in the
	-- locative plural, while similar animate nouns only have -ích. This applies even to nouns like [[háček]] and
	-- [[koníček]] that can be either animate or inanimate. Make sure to exclude nouns in -ck such as [[comeback]] and
	-- [[joystick]], which have only -ích.
	local loc_p =
		base.animacy == "inan" and rfind(base.lemma, "[cč]ek$") and rfind(stems.vowel_stem, "[cč]k$") and {"ích", "ách"} or
		velar and "ích" or "ech"
	add_decl(base, stems, gen_s, dat_s, nil, voc_s, loc_s, "em",
		-- loc_p in -ích not after velar stems (e.g. [[les]] "forest"; [[hotel]] "hotel") needs to be given manually
		-- using <locplích>; it will automatically trigger the second palatalization; loc_p in -ách (e.g. [[plech]]
		-- "metal plate") also needs to be given manually using <locplách>
		nom_p, "ů", "ům", "y", loc_p, "y")
end

declprops["hard-m"] = {
	desc = function(base, stems)
		if base.velar or not base["-velar"] and rfind(stems.vowel_stem, com.velar_c .. "$") then
			return "velar GENDER"
		else
			return "hard GENDER"
		end
	end,
	cat = function(base, stems)
		if base.velar or not base["-velar"] and rfind(stems.vowel_stem, com.velar_c .. "$") then
			return "velar-stem"
		else
			return "hard"
		end
	end
}


decls["semisoft-m"] = function(base, stems)
	-- Examples:
	-- * Animate in -ius: génius, nuncius, nonius (breed of horse), notárius, ordinárius, patricius, primárius,
	--   pronuncius, various names
	-- * Animate in -eus: farizeus, basileus, pygmeus ([[skarabeus]] inflects hard in the plural), various names
	-- * Inanimate in -ius: nonius (measuring device), rádius, sestercius
	-- NOTE: Inanimate nouns in -eus (nukleus, choreus) inflect hard in the plural
	local dat_s = base.animacy == "inan" and "u" or base.surname and "ovi" or {"ovi", "u"}
	local loc_s = dat_s
	local nom_p = base.animacy == "inan" and "e" or "ové"
	add_decl(base, stems, "a", dat_s, nil, "e", loc_s, "em",
		nom_p, "ů", "ům", "e", "ích", "i")
end

declprops["semisoft-m"] = {
	cat = "semisoft"
}


decls["soft-m"] = function(base, stems)
	base.palatalize_voc = true
	-- animates with dat_s only in -i need to give this manually, using '<dati>'
	local dat_s = base.animacy == "inan" and "i" or base.surname and "ovi" or {"ovi", "i"}
	local loc_s = dat_s
	-- Per IJP, the vast majority of soft masculine animates take -i in the voc_s, but those in -ec/-ěc take -e with first
	-- palatalization to -če, e.g. [[otec]] "father", [[lovec]] "hunter", [[blbec]] "fool, idiot", [[horolezec]]
	-- "mountaineer", [[znalec]] "expert", [[chlapec]] "boy", [[nadšenec]] "enthusiast", [[luněc]] (type of bird).
	-- Demonyms but not surnames ending in -ec but beginning with a capital letter take either -e or -i (only the former
	-- triggers the first palatalization). Examples: [[Portugalec]], [[Slovinec]] "Slovenian", [[Japonec]], [[Vietnamec]].
	-- Not [[Kadlec]] (surname).
	local voc_s = base.animacy == "an" and rfind(base.lemma, "[eě]c$") and stems.reducible and
		(not base.surname and rfind(base.lemma, "^" .. com.uppercase_c) and {"e", "i"} or "e") or "i"
	local nom_p = base.animacy == "inan" and "e" or default_masc_animate_nom_pl(base, stems)
	-- nouns with loc_p in -ech (e.g. [[cíl]] "goal") need to give this manually, using <locplech>
	add_decl(base, stems, "e", dat_s, nil, voc_s, loc_s, "em",
		nom_p, "ů", "ům", "e", "ích", "i")
end

declprops["soft-m"] = {
	cat = "soft"
}


decls["mixed-m"] = function(base, stems)
	-- NOTE: IJP tends to list the soft endings first, but per their section on this
	-- (https://prirucka.ujc.cas.cz/en/?id=220), the hard endings tend to predominate in modern use, so we list them
	-- first.
	if base.animacy == "an" then
		if rfind(base.lemma, "l$") then
			-- [[anděl]] "angel", [[manžel]] "husband", [[strašpytel]] "coward"; 'strašpytel' has a different declension
			-- from the other two, with more soft forms. [[manžel]] has plural in -é or -ové and needs an override.
			local dat_s = base.surname and "ovi" or {"ovi", "u"}
			local loc_s = dat_s
			add_decl(base, stems, "a", dat_s, nil, "i", loc_s, "em",
				"é", "ů", "ům", {"y", "e"}, {"ech", "ích"}, {"y", "i"})
		else
			-- -s/-z: rorýs, platýs, pilous, markýz, všekaz, stávkokaz, penězokaz, listokaz, dřevokaz, zrnokaz, boss.
			-- Others recently moving towards this declension: primas, karas, kalous, konipas, ibis, chabrus, chuďas,
			-- kakabus, kliďas, kandrdas, morous, vágus.
			-- Some names: Alois, Mánes.
			-- Both hard and soft endings throughout. Most have -i and -ové in the nominative plural.
			local dat_s = base.surname and "ovi" or {"u", "i", "ovi"}
			local loc_s = dat_s
			add_decl(base, stems, {"a", "e"}, dat_s, nil, {"e", "i"}, loc_s, "em",
				{"i", "ové"}, "ů", "ům", {"y", "e"}, {"ech", "ích"}, {"y", "i"})
		end
	else
		-- Given in IJP: burel, hnědel, chmel, krevel, kužel, námel, plevel, tmel, zádrhel, apríl, artikul, koukol, rubl,
		-- úběl, plus reducible nouns cumel, chrchel, [[kotel]] "cauldron", sopel, uhel. Also [[městys]]. Many of them are listed in the
		-- IJP tables with only hard or with fewer soft forms, so need to be investigated individually.
		if rfind(base.lemma, "[ls]$") then
			add_decl(base, stems, {"u", "e"}, {"u", "i"}, nil, {"e", "i"}, {"u", "e", "i"}, "em",
				{"y", "e"}, "ů", "ům", {"y", "e"}, {"ech", "ích"}, {"y", "i"})
		else
			-- -n/-t; hard in the plural: hřeben, ječmen, [[kámen]] "stone", kmen, kořen, křemen, plamen,
			-- [[pramen]] "source", [[řemen]] "strap", den, týden, [[loket]] "elbow".
			-- There may be deviations (e.g. soft plural forms for [[den]]), so need to be investigated individually.
			add_decl(base, stems, {"u", "e"}, {"u", "i"}, nil, "i", {"u", "i"}, "em",
				"y", "ů", "ům", "y", "ech", "y")
		end
	end
end

declprops["mixed-m"] = {
	cat = "mixed"
}


decls["a-m"] = function(base, stems)
	-- husita → husité, izraelita → izraelité, jezuita → jezuité, kosmopolita → kosmopolité, táborita → táborité
	-- fašista → fašisté, filatelista → filatelisté, fotbalista → fotbalisté, kapitalista → kapitalisté,
	-- marxista → marxisté, šachista → šachisté, terorista → teroristé. NOTE: most these words actually appear in
	-- the IJP tables with -é/-i, so we go accordingly.
	--
	-- gymnasta → gymnasté, fantasta → fantasté; also chiliasta, orgiasta, scholiasta, entuziasta, dynasta, ochlasta,
	-- sarkasta, vymasta; NOTE: Only 'gymnasta' actually given with just -é; 'fantasta' with -ové/-é, 'dynasta' and
	-- 'ochlasta' with just -ové, vymasta not in IJP (no plural given in SSJC), and the rest with -é/-i. So we go
	-- accordingly.
	local it_ist = rfind(stems.vowel_stem, "is?t$") or rfind(stems.vowel_stem, "ast$")
	-- Velar nouns (e.g. [[sluha]] "servant") have -ích in the loc_p (which triggers the second palatalization)
	-- instead of -ech. Nouns whose stem ends in a soft consonant ([[rikša]], [[paša]], [[bača]], [[mahárádža]],
	-- [[paňáca]], etc.) behave likewise.
	-- FIXME: [[pária]] "pariah", [[Maria]] etc.
	local loc_p =
		(base.velar or not base["-velar"] and rfind(stems.vowel_stem, com.velar_c .. "$") or rfind(stems.vowel_stem, com.inherently_soft_c .. "$")) and
		"ích" or "ech"
	add_decl(base, stems, "y", "ovi", "u", "o", "ovi", "ou",
		it_ist and {"é", "i"} or "ové", "ů", "ům", "y", loc_p, "y")
end

declprops["a-m"] = {
	cat = "GENPOS in -a"
}


decls["e-m"] = function(base, stems)
	-- [[zachránce]] "savior"; [[soudce]] "judge"; etc.
	-- At least two inanimates: [[průvodce]] "guide, guidebook; computing wizard"; [[správce]] "manager (software program), configuration program"
	local dat_s = base.animacy == "inan" and "i" or base.surname and "ovi" or {"ovi", "i"}
	local loc_s = dat_s
	add_decl(base, stems, "e", dat_s, nil, "-", loc_s, "em",
		-- nouns with -ové as well (e.g. [[soudce]] "judge") will need to specify that manually, e.g. <nompli:ové>
		base.animacy == "inan" and "e" or "i", "ů", "ům", "e", "ích", "i")
end

declprops["e-m"] = {
	cat = "GENPOS in -e"
}


decls["i-m"] = function(base, stems)
	-- [[kivi]] "kiwi (bird)"; [[kuli]] "coolie"; [[lori]] "lory, lorikeet (bird)" (loc_pl 'loriech/loriích/lorich');
	-- [[vini]] "parrot of the genus Vini"; [[yetti]]/[[yeti]] "yeti". other examples: [[aguti]], [[efendi]], [[hadži]],
	-- [[pekari]], [[regenschori]], [[yetti]]/[[yeti]].
	--
	-- [[grizzly]]/[[grizly]] "grizzly bear"; [[pony]] "pony"; [[husky]] "husky"; [[dandy]] "dandy"; [[Billy]] "billy".
	--
	-- NOTE: Some nouns in -y are regular soft stems, e.g. [[gay]] "gay person"; [[gray]] "gray (unit of absorbed
	--   radiation)"; [[Nagy]] (surname).
	--
	-- NOTE: The stem ends in -i/-y.
	add_decl(base, stems, "ho", "mu", nil, "-", "m", "m",
		-- ins_pl 'kivii/kivimi'
		{"ové", ""}, {"ů", "ch"}, {"ům", "m"}, {"e", ""}, {"ích", "ch"}, {"i", "mi"})
end

declprops["i-m"] = {
	cat = "GENPOS in -i/-y"
}


decls["í-m"] = function(base, stems)
	-- [[kádí]] "qadi (Islamic judge)", [[mahdí]] "Mahdi (Islamic prophet)", [[muftí]] "mufti (Islamic scholar)",
	-- [[sipáhí]] "sipahi (Algerian cavalryman in the French army)"
	--
	-- No obvious examples in -ý, but the support is there.
	--
	-- NOTE: The stem ends in -í/-ý.
	add_decl(base, stems, "ho", "mu", nil, "-", "m", "m",
		{"ové", ""}, {"ů", "ch"}, {"ům", "m"}, {"e", ""}, "ích", "mi")
end

declprops["í-m"] = {
	cat = "GENPOS in -í/-ý"
}


decls["ie-m"] = function(base, stems)
	-- [[zombie]] "zombie" (also fem/neut), [[hippie]] "hippie", [[yuppie]] "yuppie", [[rowdie]] "rowdy/hooligan"
	--
	-- NOTE: The stem ends in -i (not -ie, because of the plural).
	add_decl(base, stems, "eho", "emu", nil, "-", "em", "em",
		{"ové", "es"}, {"ů", "es"}, {"ům", "es"}, {"e", "es"}, {"ích", "es"}, {"i", "es"})
end

declprops["ie-m"] = {
	cat = "GENPOS in -ie"
}


decls["ee-m"] = function(base, stems)
	-- [[Yankee]] "Yankee"
	--
	-- NOTE: The stem ends in -ee.
	add_decl(base, stems, "ho", "mu", nil, "-", "m", "m",
		"ové", "ů", "ům", "e", "ích", "i")
end

declprops["ee-m"] = {
	cat = "GENPOS in -ee"
}


decls["o-m"] = function(base, stems)
	-- [[kápo]] "head, leader"; [[lamželezo]] "strongman"; [[torero]] "bullfighter"; [[žako]] "African gray parrot";
	-- [[dingo]] "dingo"; [[kakapo]] "kakapo" (given in Wiktionary with dat_s/loc_s in -ovi only not -ovi/-u; probably
	-- wrong but not in IJP); [[maestro]] "maestro"; [[Bruno]] "Bruno", [[Hugo]] "Hugo"; [[Ivo]] "Yves" (these names
	-- are singular-only per IJP); [[Kvido]] "Guido, Guy" (per IJP has accusative in -a or -ona); [[Oto]] "Otto" (per
	-- IJP also declinable like virile -a masculines; singular-only); [[Kuřátko]] (a surname; how declined?);
	-- [[Picasso]] (surname; how declined?); [[Pluto]] "Pluto (God)", also "Pluto (planet)", which is inanimate;
	-- [[Samo]]/[[Sámo]] "Samo (7th century Slavic ruler)" (dat_s/loc_s only in -ovi, needs override); [[Tomio]]
	-- "Tomio (Japanese male given name)" (how declined?); [[nemakačenko]] "idler, loafer" (given in Wiktionary with
	-- dat_s/loc_s in -ovi only, as for [[kakapo]]); [[nefachčenko]] "idler, loafer"; note also [[gadžo]] "gadjo",
	-- which has a unique declension.
	--
	-- Velar nouns ([[žako]], [[dingo]], etc.) have -ích in the loc_p (which triggers the second palatalization)
	-- instead of -ech.
	local velar = base.velar or not base["-velar"] and rfind(stems.vowel_stem, com.velar_c .. "$")
	-- inanimates e.g. [[Pluto]] (planet) have -u only, like for normal hard masculines.
	local dat_s = base.animacy == "inan" and "u" or base.surname and "ovi"or {"ovi", "u"}
	local loc_s = dat_s
	local loc_p = velar and "ích" or "ech"
	add_decl(base, stems, "a", dat_s, nil, "-", loc_s, "em",
		"ové", "ů", "ům", "y", loc_p, "y")
end

declprops["o-m"] = {
	cat = "GENPOS in -o"
}


decls["u-m"] = function(base, stems)
	-- [[emu]] "emu", [[guru]] "guru", [[kakadu]] "cockatoo", [[marabu]] "marabou" (declined the same way)
	-- [[Osamu]] "Osamu (Japanese male given name)" [how declined?]
	-- [[Višnu]] "Vishnu" (declined like [[guru]] but singular-only)
	-- [[budižkničemu]] "good-for-nothing, ne'er-do-well" (indeclinable in the singular, declinable as masculine hard stem
	-- budižkničemové etc. in the plural, declinable as feminine hard stem budižkničemy etc. in the plural when feminine).
	--
	-- NOTE: The stem ends in -u.
	add_decl(base, stems, "a", "ovi", nil, "-", "ovi", "em",
		"ové", "ů", "ům", "y", "ech", "y")
end

declprops["u-m"] = {
	cat = "GENPOS in -u"
}


decls["tstem-m"] = function(base, stems)
	-- E.g. [[kníže]] "prince", [[hrabě]] "earl", [[markrabě]] "margrave".
	add_decl(base, stems, "ete", "eti", "ete", "-", "eti", "etem",
		"ata", "at", "atům", "ata", "atech", "aty")
end

declprops["tstem-m"] = {
	cat = "t-stem"
}


--[=[
Examples:

In -a:

meaning		nom_sg		gen_sg		dat_sg		voc_sg		nom_pl		gen_pl		ins_pl
arm,hand	[[ręka]]	ręki		ręce		ręko		ręce		rąk			rękami
pharmacy	[[apteka]]	apteki		aptece		apteko		apteki		aptek		aptekami
[village]	-			-			-			-			Kluki		Kluk		Klukami
road		[[droga]]	drogi		drodze		drogo		drogi		dróg		drogami
mother		[[matka]]	matki		matce		matko		matki		matek		matkami
sled		-			-			-			-			sanki		sanek		sankami
mommy		[[mamuśka]]	mamuśki		mamuśce		mamuśku		mamuśki		mamusiek	mamuśkami
pig			[[świnia]]	świni		świni		świnio		świnie		świń		świniami
sleigh		-			-			-			-			sanie		sań			saniami
neck		[[szyja]]	szyi		szyi		szyjo		szyje		szyj		szyjami
slops		-			-			-			-			pomyje		pomyj		pomyjami
earth,land	[[ziemia]]	ziemi		ziemi		ziemio		ziemie		ziem		ziemiami
wave		[[fala]]	fali		fali		falo		fale		fal			falami
role		[[rola]]	roli		roli		rolo		role		ról			rolami
seashell	[[muszla]]	muszli		muszli		muszlo		muszle		muszel		muszlami
stable		[[stajnia]]	stajni		stajni		stajnio		stajnie		stajen		stajniami
dress		[[suknia]]	sukni		sukni		suknio		suknie		sukien		sukniami
catkin		[[bazia]]	bazi		bazi		bazio		bazie		bazi		baziami
pants		-			-			-			-			spodnie		spodni		spodniami
armour		[[zbroja]]	zbroi		zbroi		zbrojo		zbroje		zbroi		zbrojami
lily		[[lilia]]	lilii		lilii		lilio		lilie		lilii		liliami
winter_vacation -		-			-			-			ferie		ferii		feriami
option		[[opcja]]	opcji		opcji		opcjo		opcje		opcji		opcjami
depth		[[głębia]]	głębi		głębi		głębio		głębie		głębi		głębiami
rake		-			-			-			-			grabie		grabi		grabiami
cylinder	[[butla]]	butli		butli		butlo		butle		butli		butlami
gusle		-			-			-			-			gęśle		gęśli		gęślami
idea		[[idea]]	idei		idei		ideo		idee		idei		ideami
Annie		[[Ania]]	Ani			Ani			Aniu		Anie		Ań			Aniami
Maya		[[Maja]]	Mai			Mai			Maju		Maje		Maj			Majami
[dim_name]	[[Ola]]		Oli			Oli			Olu			Ole			Ol			Olami
granddaughter [[wnusia]] wnusi		wnusi		wnusiu		wnusie		wnusi		wnusiami
chance		[[szansa]]	szansy		szansie		szanso		szanse		szans		szansami
woman		[[kobieta]]	kobiety		kobiecie	kobieto		kobiety		kobiet		kobietami
Prussia		-			-			-			-			Prusy		Prus		Prusami
strength	[[siła]]	siły		sile		siło		siły		sił			siłami
tow,hemp	-			-			-			-			pakuły		pakuł		pakułami
den			[[nora]]	nory		norze		noro		nory		nor			norami
[village]	-			-			-			-			Czastary	Czastar		Czastarami
fly			[[mucha]]	muchy		musze		mucho		muchy		much		muchami
Czech_Republic -		-			-			-			Czechy		Czech		Czechami
day,era		[[doba]]	doby		dobie		dobo		doby		dób			dobami
[village]	-			-			-			-			Ciepłowody	Ciepłowód	Ciepłowodami
school		[[szkoła]]	szkoły		szkole		szkoło		szkoły		szkół		szkołami
sister		[[siostra]]	siostry		siostrze	siostro		siostry		sióstr		siostrami
moth		[[ćma]]		ćmy			ćmie		ćmo			ćmy			ciem		ćmami
broom		[[miotła]]	miotły		miotle		miotło		miotły		mioteł		miotłami
pitchfork	-			-			-			-			widły		wideł		widłami
duvet		[[kołdra]]	kołdry		kołdrze		kołdro		kołdry		kołder		kołdrami
[village]	-			-			-			-			Suchożebry	Suchożeber	Suchożebrami
unmarried_woman [[panna]] panny		pannie		panno		panny		panien		pannami
needle		[[igła]]	igły		igle		igło		igły		igieł		igłami
game		[[gra]]		gry			grze		gro			gry			gier		grami
star		[[gwiazda]]	gwiazdy		gwieździe	gwiazdo		gwiazdy		gwiazd		gwiazdami
belief		[[wiara]]	wiary		wierze		wiaro		wiary		wiar		wiarami
Italy		-			-			-			-			Włochy		Włoch		Włochami		loc_pl: Włoszech
Hungary		-			-			-			-			Węgry		Węgier		Węgrami			loc_pl: Węgrzech
Germany		-			-			-			-			Niemcy		Niemiec		Niemcami		loc_pl: Niemczech
boredom		[[nuda]]	nudy		nudzie		nudo		nudy		nudów		nudami
statue		[[statua]]	statuy/statui statui	statuo		statuy		statui		statuami
street		[[ulica]]	ulicy		ulicy		ulico		ulice		ulic		ulicami
[city]		-			-			-			-			Kielce		Kielc		Kielcami
dawn		[[zorza]]	zorzy		zorzy		zorzo		zorze		zórz		zorzami
[town]		-			-			-			-			Strzelce	Strzelec	Strzelcami
sheep		[[owca]]	owcy		owcy		owco		owce		owiec		owcami
forceps		-			-			-			-			szczypce	szczypiec	szczypcami
soot		[[sadza]]	sadzy		sadzy		sadzo		sadze		sadzy		sadzami
stretcher	-			-			-			-			nosze		noszy		noszami


Adjectival in -a:

meaning		nom_sg		gen_sg		dat_sg		voc_sg		nom_pl		gen_pl		ins_pl
[village]	[[Plaska]]	Plaskiej	Plaskiej	Plaska		Plaskie		Plaskich	Plaskimi
midwife		[[położna]]	położnej	położnej	położna		położne		położnych	położnymi
perm		[[trwała]]	trwałej		trwałej		trwała		trwałe		trwałych	trwałymi
[surname]	[[Dobra]]	Dobrej		Dobrej		Dobra		Dobre		Dobrych		Dobrymi
[village]	[[Sucha]]	Suchej		Suchej		Sucha		Suche		Suchych		Suchymi
maidservant	[[służąca]]	służącej	służącej	służąca		służące		służących	służącymi
queen		[[królowa]]	królowej	królowej	królowo		królowe		królowych	królowymi


In -ni:

meaning		nom_sg		gen_sg		dat_sg		acc_sg		nom_pl		gen_pl		ins_pl
woman,Mrs.	[[pani]]	pani		pani		panią		panie		pań			paniami
goddess		[[bogini]]	bogini		bogini		boginię		boginie		bogiń		boginiami


In a consonant:

meaning		nom_sg		gen_sg		voc_sg		nom_pl		ins_pl
daughter	[[córuś]]	córusi		córuś		córusie		córusiami
axis		[[oś]]		osi			osi			osie		osiami
train		[[kolej]]	kolei		kolei		koleje		kolejami
[town,lake]	[[Gołdap]]	Gołdapi		Gołdapi		Gołdapie	Gołdapiami
bath		[[kąpiel]]	kąpieli		kąpieli		kąpiele		kąpielami
boat		[[łódź]]	łodzi		łodzi		łodzie		łodziami
depth		[[gląb]]	glębi		glębi		glębie		glębiami
salt		[[sól]]		soli		soli		sole		solami
gender		[[płeć]]	płci		płci		płcie		płciami
jug			[[konew]]	konwi		konwi		konwie		konwiami
village		[[wieś]]	wsi			wsi			wsie		wsiami
torch		[[żagiew]]	żagwi		żagwi		żagwie		żagwiami
palm_of_hand [[dłoń]]	dłoni		dłoni		dłonie		dłońmi
net			[[sieć]]	sieci		sieci		sieci		sieciami
guts		-			-			-			wnętrzności	wnętrznościami
door		-			-			-			drzwi		drzwiami
thought		[[myśl]]	myśli		myśli		myśli		myślami
eyebrow		[[brew]]	brwi		brwi		brwi		brwiami
respect		[[cześć]]	czci		czci		czci		czciami
bone		[[kość]]	kości		kości		kości		kośćmi
night		[[noc]]		nocy		nocy		noce		nocami
harness		[[uprząż]]	uprzęży		uprzęży		uprzęże		uprzężami
mouse		[[mysz]]	myszy		myszy		myszy		myszami
louse		[[wesz]]	wszy		wszy		wszy		wszami
]=]

--[=[
Issues for feminine-type nouns:

1. What are the various types and subtypes?
* Type D1 (soft): stem ends in a phonetically soft consonant, with the following subtypes:
  (1a) in [-jly]a; those in -ja are preceded by a vowel;
  (1b) in -ia where -i- just indicates palatalization after [cnsz];
  (1c) in -ia where -i- indicates palatalization of the preceding consonant + /j/ and the dative is in -i, specifically
	   after a labial [bfmpvw];
  (1d) in -ia where -i- indicates palatalization of the preceding consonant + /j/ (or sometimes /i/) and the dative is
	   in -ii; specifically after a labial [bfmpvw], a velar (k/g/ch), or [ln]; rarely in -cia (only [[Garcia]], pron
	   [Garcija]), rarely in -czia (only [[glediczia]], [[welwiczia]]), rarely in -dżia (only [[feredżia]], [[lodżia]]);
	   none in -[drts]ia;
  (1e) in -ia where -i- indicates /j/ following a hard consonant, specifically after [drt]; rarely in -cia: only
       [[dacia]] (pron [daczja]), [[felicia]] (pron [felicja]), [[lancia]] (pron [lanczja]);
  (1f) in -ja where -j- indicates /j/ following a hard consonant, specifically after [csz];
  (1g) in -ua;
  (1h) in -ni.
* Type D2 (hardened soft): stem ends in a "functionally soft" but phonetically hard consonant: c/ż/cz/dz/rz/sz.
* Type D3 (velar): stem ends in k or g (not ch, which is phonetically velar but best treated as a hard consonant).
* Type D4 (hard): stem ends in a hard consonant.

2. How to distinguish the different types and subtypes?
* Types D2, D3 and D4 are immediately distinguishable by the ending, as are types D1a, D1f, D1g and D1h. The remaining
  subtypes all end in -ia, though.
* Types D1b and D1c have dative in -i while types D1d and D1e have dative in -ii, indicating that the stem was
  originally in /ij/.
* Type D1b occurs only after [cnsz]; type D1c occurs only after a labial [bfmpvw]; type D1e occurs almost exclusively
  after [drt] (and rarely after c). Occurrences of these consonant groups can be used to identify these types. Type D1d
  occurs after velar k/g/ch, after l and rarely after cz and dż (all of which can be used to identify this type), but
  also after a labial [bfmpvw] (which overlaps with type D1c), after n (which overlaps with type D1b) and rarely after c
  (which overlaps with type D1b). This means that -[bfmpvw]ia can be either type D3 or D4; -nia can be either type D1b
  or D1d; and -cia can be D1b or rarely D1d or D1e. We use the indicator <stemij> to indicate type D1d, and could
  potentially use <stemyj> to indicate type D1e; but the fact that this latter indicator is rare and occurs only in
  words with nonstandard pronunciations suggests maybe a different approach would be better.

3. What is the default nom_pl for feminine nouns?
* Type D1 (soft): in -e.
* Type D2 (hardened soft): in -e except for [[berceuse]] (should be treated as hard-stem based on pronun).
* Type D3 (velar): in -i.
* Type D4 (hard): in -y except for ansa/romansa/szansa in -e (note, no palatalization).

4. What is the default gen_pl?
* For type D1 (soft), there are three possibilities for gen_pl: [a] -i ending only ("neutral"); [b] null ending only
  ("characterized"); [c] both. For the various subtypes above:
  * Irrespective of what's written below, if the noun is reducible, it can only be of type [b] or [c] (almost always of
    type [c]). Likewise, if the noun has an o/ó alternation in the gen pl, it can only be of type [b] or [c] (easiest
	to assume type [c] here by default).
  * Subtype (1a) in -Vja is mostly type [c] (both endings). Subtype (1a) in -la seems split among types [a] and [c],
    where those in -Cla (C other than l and r) are mostly type [a]. Those in -rla seem of type [c] if they can also
	occur as gender m1 (i.e. they are surnames?); they represent the majority. The minority that can occur only feminine
	are all of type [a]. Like for -rla, those in -lla are of type [c] if they can also occur as gender m1; otherwise
	they are split among types [a] and [c].
  * Subtype (1b) seems split among types [a] and [c]. Those in -Cnia (C other than l or r) are mostly type [a]. Those in
    -Vnia, -lnia and especially -rnia are mostly type [c]. Those in -[csz]ia seem to favor type [c] with voc in -u.
  * Subtype (1c) seems exclusively type [a] except for [[ziemia]].
  * Subtype (1d) seems of type [c], but the null-ending variant in -ij is archaic as well as characterized/marked.
  * Subtype (1e) seems of type [c], but the null-ending variant in -yj is archaic as well as characterized/marked.
  * Subtype (1f) is like subtype (1e).
  * Subtype (1g) has gen sg in -i or -y and is of type [a].
  * Subtype (1h) is always type [b]. The acc is in -ę (like other feminine nouns) except those ending in -pani, where
    the acc is in -ą.
* Type D2 (hardened soft): three possibilities: [a] -y only ("neutral"); [b] null ending only ("characterized");
  [c] both. Type [b] seems most common, particularly for those in -ca (hardly any of type [a] or [c]), but those
  in [cdrs]z/ż seem distributed among all three types with no obvious patterns.
* Type D3 (velar): in null ending, sometimes dereduced or with o -> ó.
* Type D4 (hard): in null ending, sometimes dereduced or with o -> ó.
* IMO the best way to handle this is to internally distinguish slots gen_p_fneut and gen_p_fchar for the neutral and
  characterized forms, but (probably) merge them upon output into a single slot. If both occur, add a footnote
  indicating that the characterized form is "characterized" or "marked". This way, the user can override one or the
  other without having to worry about adding the appropriate footnote. There should also be indicators <-fneut>,
  <+fneut>, <-fchar> and <+fchar> to enable or disable the neutral and/or characterized form. By default:
  * Types D3 and D4 should default to [b] (null ending).
  * Types D2 in -ca should default to [b], but other endings should default to [c].
  * For type D1:
  ** Default to [c] if reducible or has o/ó alternation.
  ** Subtypes (1a) and (1b) in -V[jln]a and -[lr][jln]a should default to [c], whose those in other -C[jln]a should
     default to [a]. Subtype (1b) in [csz]ia should default to [c] with voc in -u.
  ** Subtype (1c) should default to [a].
  ** Subtypes (1d), (1e) and (1f) should default to [c], but the null ending is archaic.
  ** Subtype (1g) should default to [a].
  ** Subtype (1h) should default to [b].

5. How to handle "neutral" vs. "marked/characterized" gen_pl?
* See under 4. above.

6. Do we need a different declension for non-native -ia nouns, and if so how do we detect them?
* Detection is discussed under 2. above. I don't think we need a different declension; if so, it should be hard vs.
  soft rather than native vs. non-native, but there are too many edge cases.

7. How to handle foreign nouns? (a more general issue)
* This refers to things like [[berceuse]] and [[Kayah]] with silent letters and [[carioca]] and [[loggia]] with
  unexpected pronunciations that cause deformations in the declension. Needs more thought.

8. How to handle archaic gen_pl in -yj for words in -Cj like [[gracja]], [[torsja]]?
* This refers to how this is implemented internally. Needs more thought.
]=]

--[=[
Counts from SGJP:

Feminine nouns:

Type		e.g.		count	ending		datsg		nompl		genpl		indicator		notes
A1jŻ		moja		2		-ja			-jej		-je			-ich						moja/twoja
A1Ż			bliźnia		17		-ia			-iej		-ie			-ich		
A1Ż/p2:p3	Moście		3		-ie			*			-ie			-ich		
A3Ż			puszczalska	12660	-a			-kiej		-ie			-ich						in -[gk]a
A4+o		królowa		111		-a			-ej			-e			-ych						voc in -o
A4t+(rzecz)	rzeczpospolita 1	-pospolita -ypospolitej -ypospolite -ypospolitych rzecz<f>pospolita<+>
A4Ż			chora		1559	-a			-ej			-e			-ych		
D1			fobia		1861	-a			-i			-e			-i/j[arch]					all in -ia except idea, Odya [pron Odja]; none in -[cdrt]ia except Garcia; lots like anhedonia in -nia that could be a different decl; none in -sia or -zia
D1/p3		egzekwie	4		-e			*			-e			-i/j[arch]					bakalie/luperkalie/ceremonie/egzekwie
D1+!		Aniela		38		-la			-li			-le			-li/l[char]					voc in -u; all in -[eilouy]la, all proper names except ciotula/mamula/matula; all proper names take voc -o or -u
D1A+-(-fchar) IKEA		1		-A			--i			--e			 --i						lowercase case endings with preceding hyphen
D1c			ciuchcia	8		-cia		-ci			-cie		-ci/ć[char]					no proper names
D1c/p2		Degucie		4		-cie		*			-cie		-ci/ć[char]	
D1c/p3		krocie		5		-cie		*			-cie		-ci/ć[char]	
D1c+!		ciocia		63		-cia		-ci			-cie		-ci/ć[char]					voc in -u; ~50% proper names
D1+(-fchar)	trufla		291		-a			-i			-e			-i							most in -la and -ea; also Nauzykaa and 10 proper names in -ia; all terms in -la are -Cla (including several in -lla) except koala, mądrala, ~20 in -ela, campanila, tequila, ~80 in -ola, aula, Depaula, szynszyla
D1+(-fchar)/p2 grable	90		-a			*			-e			-i							also Jaglie/Kolonie/korepetycje
D1+(-fchar)/p3 bambetle	116		-a			*			-e			-i							also Jaglie/Kolonie/komicje/korepetycje/Dionizje/afrodyzje
D1+!(-fneut) Ela		30		-a			-i			-e			-							voc in -u; all in -[aeiou]la, all proper names except babula/żonula/czarnula; some proper names + żonula/czarnula take voc -o or -u
D1+(-fneut)	ziemia		2		-mia		-mi			-mie		-m							only ziemia/Ziemia
D1i+(-fchar) chełbia	806		-ia			-i			-ie			-i							24 in -bia (only 6 common); 23 in -cia (all proper except bracia); 18 in -mia (only 4 common); 10 in -pia (4 common); 5 in -sia (all proper); 12 in -wia (3 common); 29 in -zia (only 2 common); all the rest in -nia
D1i+(-fchar)/p2 grabie	8		-ie			-i			-ie			-i			
D1i+(-fchar)/p3 drabie	18		-ie			-i			-ie			-i			
D1in		gospodyni	177		-ni			-ni			-nie		-ń							acc in -ę; most end in -czyni, 6 in -ani (none in -pani), ksieni, 23 in -ini, 2 in -dyni
D1in+ą		pani		10		-ni			-ni			-nie		-ń							acc in -ą; all end in -pani
D1j			baja		194		-ja			-i			-je			-i/j[char]					all in -Vja; ~75% proper names
D1j+!		Maja		5		-ja			-i			-je			-i/j[char]					voc in -o or -u
D1j+(-fchar) nadzieja	45		-ja			-i			-je			-i							~50% proper names
D1j+(-fchar)/p3 gronostaje 5	-je			*			-je			-i							all except wierzeje can also be masc with gen_pl -jów
D1j+(-fneut) dwója		10		-ja			-i			-je			-j							mostly common nouns
D1jo		zbroja		1		-oja		-oi			-oje		-oi/ój[char]	
D1jo/p2:p3	Odoje		2		-oje		-oi			-oje		-oi/ój[char]	
D1j+(yj)	funkcja		2592	-ja			-ji			-je			-ji/yj[arch]				all in -[csz]ja
D1j+(yj)/p2	korepetycje	1		-ja			*			-je			-ji/yj[arch]	
D1j+(yj)/p3	antecedencje 26		-ja			*			-je			-ji/yj[arch]	
D1le		grobla		13		-la			-li			-le			-li/el[char]	
D1le/p2		Jeszkotle	4		-le			*			-le			-li/el[char]	
D1le/p3		Groble		4		-le			*			-le			-li/el[char]	
D1lei		brykla		1		-kla		-kli		-kle		-kli/kiel[char] 
D1ló		topola		2		-ola		-oli		-ole		-oli/ól[char] 				also dola
D1ló+(-fneut) rola		3		-ola		-oli		-ole		-ól			
D1ló+(-fneut)/p2:p3 Gole 2		-ole		*			-ole		-ól			
D1n			łania		686		-nia		-ni			-nie		-ni/ń[char]	
D1n+!		kawunia		58		-nia		-ni			-nie		-ni[rare]/ń[char]			voc in -u; 1/3 proper names in -unia, 103 common in -unia, 1/3 proper in -[aeioy]nia
D1ne		stajnia		2		-nia		-ni			-nie		-ni/en[arch]				stajnia/kuchnia
D1nei		suknia		6		-nia		-ni			-nie		-ni/ien[char] 				all in -[kgw]nia
D1neiz		studnia		1		-dnia		-ni			-dnie		-dni/dzien[char] 
D1neiz/p2:p3 Studnie	1		-dnie		*			-dnie		-dni/dzien[char] 
D1n+(-fneut) dynia		26		-nia		-ni			-nie		-ń							all in -ynia or -[kw]inia
D1n+(-fneut)/p2:p3 sanie 89		-nie		*			-nie		-ń							in both -Vnie and -Cnie
D1nś		wiśnia		5		-śnia		-śni		-śnie		-śni/sien[char]				wiśnia/workowiśnia/laurowiśnia/sośnia/Mięsośnia
D1ńe		lutnia		3		-nia		-ni			-nie		-ni/eń[char] 				wisznia/Wisznia/lutnia
D1+(ów)		fala		322		-a			-i			-e			-i/-[char]					all in -[Vl]la except pudźa
D1+(ów)/p3	stalle		1		-e			-i			-e			-i/-[char]	
D1s			paczusia	6		-sia		-si			-sie		-si[rare]/ś[char] 			all common nouns in -usia, voc in -u or -o
D1s/p2:p3	Basie		3		-sie		*			-sie		-si[rare]/ś[char] 
D1s+!		samosia		104		-sia		-si			-sie		-si[rare]/ś[char] 			voc in -u; ~75% proper names
D1+w		antresola	544		-a			-i			-e			-i/-[char]					all proper, both in -Vla and -Cla
D1wei		stągwia		1		-gwia		-gwi		-gwie		-giew		
D1+y		statua		11		-a			-i			-y			-i							gen in -i/y; kwinoa/stoa/tamandua/Pardua/Managua/Nikaragua/genua/Genua/Papua/statua/Mantua
D1y(ah)		Kayah		1		-yah		-i			-ye			-i			
D1+(yj)		parodia		672		-ia			-ii			-ie			-ii/yj[arch]				all in -[cdrt]ia
D1+(yj)/p2	Indie		1		-ie			*			-ie			-ii/yj[arch]	
D1+(yj)/p3	brewerie	8		-ie			*			-ie			-ii/yj[arch]				Indie/fanaberie/ferie/peryferie/filakterie/eleuterie/brewerie/perypetie
D1y+(ów)	Goya		1		-ya			-i			-ye			-i							[pron Goja]
D1z			buzia		11		-zia		-zi			-zie		-zi/ź[char]	
D1z/p2:p3	Kiezie		1		-zie		*			-zie		-zi/ź[char]	
D1z+!		pindzia		32		-zia		-zi			-zie		-zi/ź[char]					voc in -u; ~75% proper names
D2			Hańcza		136		-a			-y			-e			-y/-[char]					in -c/[cdrs]z/ż; only bejca in -ca
D2ce/p2:p3	Siedlce		15		-ce			*			-ce			-ec							in -[jlż]ce + Węgrzce
D2cei		owca		1		-ca			-cy			-ce			-iec		
D2cei/p2:p3	skrzypce	85		-ce			*			-ce			-iec						in -[bmpw]ce + Zamojsce
D2+(-fchar)	msza		75		-a			-y			-e			-y							in -c/[cdrs]z/ż + cha-cha; only Żernica in -ca
D2+(-fchar)/p2 dżwierze 98		-e			*			-e			-y							in -c/[cdrs]z/ż; 6 in -ce
D2+(-fchar)/p3 Karkonosze 109	-e			*			-e			-y							in -c/[cdrs]z/ż; 7 in -ce; subsumes all in p2
D2+(-fneut)	óslica		2342	-a			-y			-e			-							in -c/[cdrs]z/ż; most in -ica/yca
D2+(-fneut)/p2 grabice	2650	-a			*			-e			-			
D2+(-fneut)/p3 Gardzienice 2659	-a			*			-e			-							in -[cjlż]/[cdrs]z except Skuze/Chotyze/Parypse; all proper names except maybe grabice/prace; most in -ice/yce
D2(se)		berceuse	1		-se			-zie		-zy			-z			
D2zdo		grodza		1		-odza		-odzy		-odze		-odzy/-ódz[char] 
D2zdo/p2:p3	Ochodze		1		-odze		*			-odze		-odzy/-ódz[char] 
Dzzro		zorza		1		-orza		-orzy		-orze		-órz		
D2że		komża		1		-ża			-ży			-że			-ży/-eż[char] 
D2żo		rogoża		3		-oża		-oży		-oże		-oży/-óż[char] 				rogoża/Ochoża/rohoża
D2żo+(-fneut) loża		1		-oża		-oży		-oże		-óż			
D3(ca)		carioca		4		-ca			-ce			-ki			-c							Fonseca/carioca/Jessica/coca; gen/nom_pl -ki, otherwise in -c-
D3(ca)e		Athabasca	3		-ca			-ce			-ki			-ec							Athabasca/nesca/villanesca; gen/nom_pl -ki, otherwise in -c-
D3g			wilga		662		-ga			-dze		-gi			-g			
D3g/p2		sarangi		37		-gi			*			-gi			-g							most are proper names also p3
D3g/p3		figi		41		-gi			*			-gi			-g							most are proper names also p2
D3g+0		wyga		1		-ga			-dze		-gi			-g			
D3ge		rózga		2		-ga			-dze		-gi			-eg							drzazga/rózga; both have gen_pl -g:-eg
D3gę		księga		5		-ęga		-ędze		-ęgi		-ąg			
D3gę/p2:p3	Kręgi		2		-ęgi		*			-ęgi		-ąg							Kręgi/Mortęgi
D3go		załoga		47		-oga		-odze		-ogi		-óg			
D3go/p2		Nałogi		7		-ogi		*			-ogi		-óg			
D3go/p3		drogi		8		-ogi		*			-ogi		-óg			
D3gro		morga		1		-orga		-ordze		-orgi		-órg		
D3k			sroka		940		-ka			-ce			-ki			-k							all in -Vka except mekka/Mekka/alka/kalka/walka/flanka/arka/Turka/łaska/niełaska/neska/klęska/odaliska/Polska/Wielkopolska/Małopolska/troska/beztroska
D3k/p2		Duszniki	361		-ki			*			-ki			-k			
D3k/p3		Duszniki	364		-ki			*			-ki			-k			
D3kć		paćka		13		-ćka		-ćce		-ćki		-ciek		
D3kć/p2:p3	Boćki		6		-ćki		*			-ćki		-ciek		
D3ke		babka		12817	-ka			-ce			-ki			-ek							all in -Cka; none in -kka; lots in -lka/rka/ska
D3ke/p2		grabelki	1181	-ki			*			-ki			-ek			
D3ke/p3		Koluszki	1284	-ki			*			-ki			-ek			
D3kein		bańka		75		-ńka		-ńce		-ńki		-niek		
D3kein/p2	Mońki		11		-ńki		*			-ńki		-niek		
D3kein/p2	sierszeńki	13		-ńki		*			-ńki		-niek		
D3kę		męka		1		-ęka		-ęce		-ęki		-ąk			
D3kę/p3		męki		1		-ęki		*			-ęki		-ąk			
D3kę+c		ręka		1		-ęka		-ęce		-ęce		-ąk			
D3kś		ośka		55		-śka		-śce		-śki		-siek		
D3kś/p2		Jaśki		5		-śki		*			-śki		-siek		
D3kś/p3		siuśki		5		-śki		*			-śki		-siek		
D3kś+!		mamuśka		2		-śka		-śce		-śki		-siek						voc in -u
D3k+w		Dejnaka		173		-ka			-ce			-ki			-k							all proper in -Vka
D3kź		buźka		6		-źka		-źce		-źki		-ziek		
D3kź/p2:p3	Idźki		2		-źki		*			-źki		-ziek		
D4			baba		5760	-a			-ie			-y			-							in -[bfmnpsvwz]a
D4/p2		sanczyny	1593	-y			*			-y			-							in -[bfmnpsvwz]y
D4/p3		annuity		1745	-y			*			-y			-							in -[bfmnpsvwz]y
D4(A)		NASA		9		-A			--ie		--y			-							ABBA/UEFA/FIFA/FAMA/SABENA/NEMA/APA/NASA/ANSA; hyphen before non-null case endings
D4be		torba		1		-ba			-bie		-by			-eb			
D4be/p2:p3	Izdby		1		-by			*			-by			-eb			
D4bę		gęba		2		-ęba		-ębie		-ęby		-ąb			
D4bę/p2		Wilczogęby	1		-ęby		*			-ęby		-ąb			
D4bę/p3		otręby		2		-ęby		*			-ęby		-ąb			
D4bó		choroba		19		-oba		-obie		-oby		-ób			
D4bśo		prośba		1		-ośba		-ośbie		-ośby		-ósb		
D4bźo		groźba		3		-oźba		-oźbie		-oźby		-óźb		
D4d			banda		1112	-da			-dzie		-dy			-d			
D4d/p3		drakonidy	2		-dy			*			-dy			-d			
D4de		Gwda		2		-da			-dzie		-dy			-ed			
D4(dha)		Sargodha	1		-dha		-dzie		-dhy		-dh			
D4dó		nagroda		139		-oda		-odzie		-ody		-ód			
D4dó/p2:p3	Ciepłowody	16		-ody		*			-ody		-ód			
D4d+(-pl:gen) Brda		1		-da			-dzie		-dy			*			
D4dz		uzda		31		-zda		-ździe		-zdy		-zd			
D4dza		gwiazda		10		-azda		-eździe		-azdy		-azd						gwiazda+compounds, jazda/Objazda/pojazda
D4(e)		Kaliope		1		-e			-pie		-y			-							reg except nom
D4+e		szansa		3		-a			-ie			-e			-							ansa/romansa/szansa
D4hc		mucha		439		-cha		-sze		-chy		-ch			
D4hc/p2:p3	Włochy		23		-chy		*			-chy		-ch			
D4hc+(ech)/p2:p3 Włochy	1		-chy		*			-chy		-ch							loc_pl Włoszech
D4h+(dz)	Praha		1		-ha			-dze		-hy			-h			
D4h+(sz)	yamaha		11		-ha			-sze		-hy			-h			
D4h+(ż)		braha		10		-ha			-że			-hy			-h			
D4ł			mogiła		829		-ła			-le			-ły			-ł			
D4łe		jodła,kapła	18		-ła			-le			-ły			-eł			
D4łe/p2		widły		12		-ły			*			-ły			-eł			
D4łe/p3		kudły		13		-ły			*			-ły			-eł			
D4łei		igła		12		-ła			-le			-ły			-ieł		
D4łei/p2:p3	Cegły		4		-ły			*			-ły			-ieł		
D4łł		Jagiełła	23		-łła		-lle		-łły		-łł			
D4łó		szkoła		13		-oła		-ole		-oły		-ół			
D4łó/p2		Baboły		6		-oły		-ole		-oły		-ół			
D4łó/p3		pierdoły	7		-oły		-ole		-oły		-ół			
D4łs		ciosła		7		-sła		-śle		-sły		-seł		
D4łz		gruzła		2		-zła		-źle		-zły		-zeł		
D4mć		ćma			1		-ćma		-ćmie		-ćmy		-ciem		
D4me		karczma		5		-ma			-mie		-my			-em			
D4ne		druhna		58		-na			-nie		-ny			-en							in -[dhjłrż]na/chna/szna
D4nei		trumna		84		-na			-nie		-ny			-ien						in -[gmnw]na
D4nei/p2:p3	Stegny		4		-ny			*			-ny			-ien						in -gny
D4neis		ciosna		3		-sna		-śnie		-ny			-sn/sen						ciosna/Ciosna/Wiosna
D4nes		sosna		18		-sna		-śnie		-sny		-sen		
D4nz		blizna		456		-zna		-źnie		-zny		-zn			
D4nz+w		Puścizna	6		-zna		-źnie		-zny		-zn			
D4nź		kneźna		1		-źna		-źnie		-źny		-zien		
D4pó		stopa		2		-opa		-opie		-opy		-óp			
D4r			góra		850		-ra			-rze		-ry			-r							20 in -bra, lycra, 38 in -dra, cyfra, 10 in -gra, 3 in -chra, 2 in -hra, 3 in -jra, 10 in -kra, 2 in -mra, 4 in -pra, 41 in -tra, 7 in -wra, 2 in -żra, rest in -Vra
D4ra		ofiara		5		-ara		*			-ary		-ar			
D4re		kołdra		33		-ra			-rze		-ry			-er							3 in -bra (all 3 are optionally reducible), 22 in -dra (red: Hadra,nadra,flądra,kołdra,afelandra,salamandra,Aleksandra,bindra,odra,Odra,łachudra,miazdra,klabzdra,mizdra; opt red: fladra,cynadra,zadra,szołdra,kalandra,kasandra,Kasandra,wydra), czochra (opt red), klamra (red), 6 in -tra (red: litra,hajstra,olstra,mustra,Brahmaputra; opt red: mutra)
D4re/p2		Zadry		5		-ry			-rze		-ry			-er			
D4re/p3		cynadry		5		-ry			-rze		-ry			-er			
D4rei		gra			10		-ra			-rze		-ry			-ier						in -[kg]ra
D4rei/p2:p3	Wigry		5		-ry			*			-ry			-ier						in -[kg]ra
D4ro		obora		29		-ora		-orze		-ory		-ór			
D4ro/p2:p3	Obory		3		-ory		*			-ory		-ór			
D4(rr)		Canberra	14		-rra		-rze		-rry		-rr							no r before dative
D4rtsó		siostra		2		-ostra		-ostrze		-ostry		-óstr		
D4r+w		Stachura	669		-ra			-rze		-ry			-r			
D4r+w/p3	maniery		2		-ry			*			-ry			-r			
D4t			minuta		1302	-ta			-cie		-ty			-t			
D4t/p3		panty		1		-ty			*			-ty			-t			
D4t(ha)		Hertha		3		-tha		-cie		-thy		-th			
D4to		robota		8		-ota		-ocie		-oty		-ót			
D4to/p2:p3	roboty		1		-oty		*			-oty		-ót			
D4t+(-pl:gen) krzta		1		-ta			-cie		-ty			*			
D4ts		langusta	107		-sta		-ście		-sty		-st			
D4tsa		niewiasta	1		-asta		-eście		-asty		-ast		
D4t(TA)		EFTA		6		-TA			--cie		-T-y		-T							ETA/NAFTA/EFTA/CEFTA/ELTA/LETTA; all except LETTA can be indeclinable; hyphen before non-null case endings
D4we		łyżwa		21		-wa			-wie		-wy			-ew			
D4we/p2:p3	Mątwy		2		-wy			*			-wy			-ew			
D4wei		pluskwa		2		-wa			-wie		-wy			-iew						in -[kg]wa
D4wei/p2:p3	Łagwy		2		-wy			*			-wy			-iew						in -[kg]wy
D4wó		połowa		122		-owa		-owie		-owy		-ów			
D4wó/p2		Charzykowy	64		-owy		*			-owy		-ów			
D4wó/p3		okowy		66		-owy		*			-owy		-ów			
D4wó+agłowa	białagłowa	1		-agłowa		ejgłowie	-egłowy		-ychgłów	biała<+>głowa<>
D4x+w		Dixa		3		-xa			-ksie		-xy			-x			
D4ze		łza			1		-za			-zie		-zy			-ez			
D4zei		gza			1		-za			-zie		-zy			-iez		
D4zó		poza		12		-oza		-ozie		-ozy		-óz			
D4zó/p2:p3	Płozy		4		-ozy		-ozie		-ozy		-óz			




Masculine nouns:

Type		e.g.		count	ending		datsg		nompl		nompl2		genpl		indicator		notes
D1/m1		Garcia		23		-a			-i			-owie		-e			-ów							Garcia/Aria/Zamaria/paria/Beria, otherwise none in -[cdrt]ia; also Ilja/ninja/Mantegna [pron Mantenja]/Odya [pron Odja]/Zápolya [pron Zápoja/Zápojo with initial stress] not in -ia
D1/m2		kanalia		1		-a			-i			*			-e			-ów		((kanalia<m>,kanalia<>)) can be masc or fem
D1c/m1		ciamcia		2		-cia		-ci			-cie		-cie		-ciów		
D1c+!/m1	ciamcia		2		-cia		-ci			-cie		-cie		-ciów						voc in -u
D1+(-fchar)/m1 bibliopola 2		-a			-i			-e			-e			-i							gen_pl not in -lów; bibliopola/cieśla (but both terms have alternate gen_pl in -ów)
D1+(-fchar)/m2 papla	7		-a			-i			*			-e			-i							j not suppressed before -i; magnificencja/ekscelencja/eminencja/koala/ebola/papla/zgadula
D1i+!/m1	dziadzia	5		-ia			-i			-iowie		-ie			-iów						Kościa/ojczunia/dziadzia/dziamdzia/dziumdzia
D1i+(-fchar)/m1 Gołdynia 163		-ia		-i			-iowie		-ie			-iów		
D1j/m1		Maja		111		-ja			-i			-jowie		-je			-jów						all in -Vja; all proper names except raja
D1j+(-fneut)/m1 zawedyja 6		-ja			-i			-je			-je			-jów		
D1n+!/m2	niunia		1		-nia		-ni			*			-nie		-niów						voc in -u
D1o+!/m1	Puzio		1		-o			-			-owie		-e			-ów		
D1+(ów)/m1	bidula		6		-a			-i			-e			-e			-ów							all in -Vla except ninja/cieśla
D1+(ów)/m2	ninja		1		-a			-i			*			-e			-ów			
D1+w/m1		Kaligula	554		-a			-i			-owie		-e			-ów							all in -la except Mathea
D1+y/m1		Gargantua	6		-a			-i			-owie		-y			-ów							gen in -i/y; all proper in -ua
D1y+(ów)/m1	Goya		2		-ya			-i			-yowie		-ye			-yów						Goya [pron Goja], Tuleya [pron Tuleja]
D2/m1		znawca		460		-a			-y			-y			-e			-ów							all in -ca
D2+(-fchar)/m1 hulajdusza 11	-a			-y			-e			-e			-ów							in -c/[cs]z/ż; 4 in -ca
D2+(-fchar)/m2 nindża	1		-a			-y			*			-e			-ów			
D2+(-fneut)/m1 Gruca	339		-a			-y			-owie		-e			-ów							in -c/[cdrs]z/ż except Fritza
D2+(-fneut)/m2 gońca	3		-a			-y			*			-e			-ów							gońca/zabawca/poprawca
D2(o)m1		Trapszo		12		-o			-y			-owie		-e			-ów		
D3(ca)/m1	Fonseca		4		-ca			-ce			-cowie		-ki			-ców						Fonseca/Sica/Tezcatlipoca/Lorca; gen/nom_pl_depr -ki, otherwise in -c-
D3g/m1		drandryga	22		-ga			-dze		-dzy		-gi			-gów		
D3g/m2		murga		2		-ga			-dze		*			-gi			-gów						murga/drandryga
D3g+0/m1	sługa		1		-ga			-dze		-dzy		-gi			-g							gen_pl sług:sługów
D3ge/m1		auriga		371		-ga			-dze		-gowie		-gi			-gów		
D3g(ha)+w/m1 Agha		1		-gha		-dze		-ghowie		-ghi		-ghów	
D3k/m1		judoka		26		-ka			-ce			-cy			-ki			-ków		
D3k/m2		sika		1		-ka			-ce			*			-ki			-ków		
D3ke/m1		tatka		9		-ka			-ce			-kowie		-ki			-ek							gen_pl not in -ków but all such terms also have gen_pl in -ków
D3ke/m2		szpicbródka	1		-ka			-ce			*			-ki			-ek							also fem; gen_pl not in -ków
D3kein/m1	Mateńka		1		-ńka		-ńce		-ńkowie		-ńki		-ńków	
D3k(o)+w/m1	Doroszeńko	1027	-ko			-ce			-kowie		-ki			-ków		
D3k+w/m1	papinka		1593	-ka			-ce			-kowie		-ki			-ków		
D3k+w/m2	meszka		1		-ka			-ce			*			-ki			-ków		
D3kź/m1		Buźka		1		-źka		-źce		-źkowie		-źki		-źkow	
D4/m1		Bereza		1439	-a			-ie			-owie		-y			-ów							in -[bfmnpsvwz]a
D4/m2		bucina		30		-a			-ie			*			-y			-ów							in -[bfmnpsvwz]a
D4+0/m2		glina		1		-a			-ie			-i[rare]	-y			-ów			
D4(ah)/m1	Bramah		1		-ah			-ie			-owie		-y			-ów		
D4bę/m1		moczygęba	2		-ęba		-ębie		-ębowie		-ęby		-ębów	
D4d/m1		aojda		583		-da			-dzie		-dowie		-dy			-dów		
D4d/m2		przybłęda	2		-da			-dzie		*			-dy			-dów		
D4d(o)/m1	Szwedo		38		-do			-dzie		-dowie		-dy			-dów		
D4d+(ów)/m1	inwalida	15		-da			-dzie		-dzi		-dy			-dów		
D4dz/m1		skoczybruzda 27		-zda		-ździe		-zdowie		-zdy		-zdów	
D4dza/m1	Gwiazda		1		-azda		-eździe		-azdowie	-azdy		-azdów						alt dat in -aździe (considered separate pattern)
D4dz(o)/m1	Hnizdo		1		-zdo		-ździe		-zdowie		-zdy		-zdów	
D4(ha)/m1	Saldanha	1		-ha			-ie			-howie		-hy			-hów		
D4hc/m1		autarcha	237		-cha		-sze		-chowie		-chy		-chów	
D4hc/m2		marcha		3		-cha		-sze		*			-chy		-chów		
D4hc(o)+w/m1 Mikłucho	4		-cho		-sze		-chowie		-chy		-chów	
D4hc+w/m1	klecha		1		-cha		-sze		-chowie		-chy		-ch							gen_pl not in -chów
D4h(o)+w/m1	Weryho		3		-ho			-sze		-howie		-hy			-hów		
D4h+(sz)/m1	Taha		2		-ha			-sze		-howie		-hy			-hów		
D4h+(ż)/m1	Sapieha		3		-ha			-że			-howie		-hy			-hów		
D4+i/m1		ortodoksa	78		-a			-ie			-i			-y			-ów							in -na except Kaszuba/ortodoksa/Jehowa
D4ł/m1		Drzymała	712		-ła			-le			-łowie		-ły			-łów		
D4łł/m1		mułła		3		-łła		-lle		-łłowie		-łły		-łłów	
D4łł(o)+w/m1 Jundziłło	12		-łło		-lle		-łłowie		-łły		-łłów	
D4ł(o)+w/m1 popychajło	217		-ło			-le			-łowie		-ły			-łów		
D4ł(o)+wa/m1 czuryło	8		-ło			-le			-łowie		-ła			-łów		
D4łs/m1		Zawisła		3		-sła		-śle		-słowie		-sły		-słow	
D4łs(o)+w/m1 Porosło	18		-sło		-śle		-słowie		-sły		-słów	
D4ł+w/m1	kameduła	1		-ła			-le			-li			-ły			-łów		
D4łz/m1		Wizła		1		-zła		-źle		-złowie		-ły			-złów	
D4łz(o)+w/m1 Oślizło	5		-zło		-źle		-złowie		-ły			-złów	
D4nes/m1	Sosna		3		-sna		-śnie		-snowie		-sny		-snów	
D4ns(o)/m1	Kosno		1		-sno		-śnie		-snowie		-sny		-snów	
D4nz/m1		mężczyzna	1		-zna		-źnie		-źni		-zny		-zn							gen_pl not in -znów
D4nz(o)		Tryzno/m1	1		-zno		-źnie		-znowie		-zny		-znów	
D4nz+w/m1	Tryzna		6		-zna		-źnie		-znowie		-zny		-znów						SGJP says -źnowie but that seems a mistake
D4(o)/m1	Michno		76		-o			-ie			-owie		-y			-ów							in -[bmnpswz]o, preceded by V or C
D4r/m1		pediatra	27		-ra			-rze		-rzy		-ry			-rów						13 in -tra, rest in -Vra
D4r(ha)/m1	Cerha		1		-rha		-rze		-rhowie		-rhy		-rhów						no h before dative
D4r(o)+w/m1	Fredro		56		-ro			-rze		-rowie		-ry			-rów		
D4(rr)/m1	Carra		6		-rra		-rze		-rrowie		-rry		-rrów						no r before dative
D4r+w/m1	Pazura		692		-ra			-rze		-rowie		-ry			-rów		
D4r+w/m2	lisiura		3		-ra			-rze		*			-ry			-rów		
D4t/m1		Galata		500		-ta			-cie		-towie		-ty			-tów		
D4t/m2		argonauta	10		-ta			-cie		*			-ty			-tów		
D4t(ha)/m1	Botha		2		-tha		-cie		-thowie		-thy		-thów	
D4t+i/m1	poeta		233		-ta			-cie		-ci			-ty			-tów		
D4t+i/m2	przechrzta	2		-ta			-cie		*			-ty			-tów		
D4t(o)/m1	tato		38		-to			-cie		-towie		-ty			-tów		
D4ts/m1		podstarosta	49		-sta		-ście		-stowie		-sty		-stów						all proper names except podesta/starosta/podstarosta/wicestarosta; 5 in -asta, 8 in -esta, 18 in -ista, 2 in -msta, 7 in -osta, 6 in -usta, 3 in -ysta
D4ts/m2		antagonista	1		-sta		-ście		*			-sty		-stów		
D4ts+i/m1	cyklista	1076	-sta		-ście		-ści		-sty		-stów						16 in -asta, podesta, 3 in -osta (diagnosta/farmakognosta/prognosta), all the rest in -ista/-ysta; no proper names AFAICT
D4ts(o)/m1	Kusto		3		-sto		-ście		-stowie		-sty		-stów	
D4wó/m1		trzęsigłowa	1		-owa		-owie		-owowie[rare] -owy		-owów 
D4x+w/m1	Jaxa		3		-xa			-ksie		-xowie		-xy			-xów		
]=]

decls["hard-f"] = function(base, stems)
	-- See comment above definition of 'local decls' for where stem and ending alternations are handled.
	local soft_cons = com.ends_in_soft(base.vowel_stem) or com.ends_in_hardened_soft_cons(base.vowel_stem)
	local nom_p = soft_cons and "e" or "y" -- converted to i after k/g
	-- Words in -Cj ([[gracja]], [[torsja]]) and -Cl ([[hodowla]], [[grobla]], [[bernikla]]) have -i (FIXME: inherited
	-- from the old module; check if this needs to be generalized). Check the non-vowel stem so that we don't do this
	-- for reducible nouns.
	local gen_p = (
		rfind(base.nonvowel_stem, com.cons_c .. "[jl]$") or com.ends_in_soft_requiring_i_glide(base.nonvowel_stem)
	) and "i" or ""
	add_decl(base, stems, "y", "e", "ę", "ą", "e", "o",
		nom_p, gen_p, "om", nom_p, "ami", "ach")
end

declprops["hard-f"] = {
	cat = "hard"
}


decls["soft-f"] = function(base, stems)
	-- This also includes feminines in -ie, e.g. [[belarie]], [[signorie]], [[uncie]], and feminines in -oe, e.g.
	-- [[kánoe]], [[aloe]] and medical terms like [[dyspnoe]], [[apnoe]], [[hemoptoe]], [[kalanchoe]].

	-- Nouns in -ice like [[ulice]] "street" have null genitive plural e.g. 'ulic'; nouns in -yně e.g. [[přítelkyně]]
	-- "girlfriend" have gen_pl 'přítelkyň' or 'přítelkyní' with two possible endings; otherwise -í. (Alternation between
	-- -ň and -n and between -e and -ě handled automatically by combine_stem_ending().)
	local gen_p = rfind(base.lemma, "ice$") and "" or rfind(base.lemma, "yně$") and {"", "í"} or "í"
	-- Vocative really ends in -e, not just a copy of the nominative; cf. [[sinfonia]], which is soft-f except for
	-- the nominative and has -e in the vocative singular.
	add_decl(base, stems, "e", "i", "i", "e", "i", "í",
		"e", gen_p, "ím", "e", "ích", "emi")
end

declprops["soft-f"] = {
	cat = "soft"
}


decls["mixed-f"] = function(base, stems)
	-- Lowercase nouns in -ňa (e.g. bárišňa/báryšňa, doňa, dueňa, piraňa, vikuňa) and -ja (e.g. maracuja, papája, sója).
	-- Also non-personal proper nouns in -ňa (e.g. [[Keňa]] "Kenya") and -ja (e.g. [[Troja]]/[[Trója]] "Troy",
	-- [[Amudarja]] "Amu Darya"). Does not appear to apply to personal proper nouns (e.g. [[Táňa]] "Tanya", [[Darja]] "Daria"),
	-- which usually decline like [[gejša]], [[dača]], [[skica]]).
	add_decl(base, stems, {"i", "e"}, {"e", "i"}, "u", "o", {"e", "i"}, "ou",
			{"i", "e"}, {"", "í"}, {"ám", "ím"}, {"i", "e"}, {"ách", "ích"}, {"ami", "emi"})
end

declprops["mixed-f"] = {
	cat = "mixed"
}

--[=[
Counts from SGJP:

Type		e.g.		count	ending		gensg		nompl		indicator		notes
D10			gardziel	68		-			-i			-e			<f>				all in -l, mostly in -el and -śl
D10+i		myśl		5		-i			-i			-i			<f.nompli>		all in -l; Trzebiel/Rygol/Supraśl/myśl/Teklimyśl
D1bą0		gląb		1		-ąb			-ębi		-ębie		<f.#>			ą/ę alternation
D1ć0		płoć		67		-ć			-ci			-cie		<f>
D1ć0+e/m1	waszmość	8		-ć			-ci			-cie		?				masc gender
D1ć0+i		ość			64650	-ć			-ci			-ci			<>				nouns in -ość will default to feminine
D1ć0+i/p2	pyszności	25		-ći			*			-ci			<pl>
D1ć0+i(mi)	nić,kość	3		-ć			-ci			-ci			<insplmi>		ins_pl in -ćmi
D1ć0+i(mi)/p3 kośći		2		-ć			-ci			-ci			<f.pl.insplmi>	ins_pl in -ćmi
D1ć0(mi)	kiść		2		-ć			-ci			-cie		<insplmi>		ins_pl in -ćmi
D1ć0+w/m1	waszeć		5		-ć			-ci			-ciowie/-cie[depr] ?		masc gender
D1će0		płeć		2		-eć			-ci			-cie		<f.*>
D1ćó0		uwróć		1		-óć			-oci		-ocie		<f.#>			ó/o alternation
D1ćśe0		cześć		1		-eść		-ci			-ci			<f.*.decllemma:czeć> cześć -> czci-
D1i0		chełb		7		-			-i			-ie			<f>				in -[bmp]
D1i0+i		głasnost	2		-			-i			-i			<f.nompli>		głasnost/Ob
D1j0		kolej		4		-j			-i			-je			<f>
D1lei0		magiel		1		-iel		-li			-le			<f.*>
D1ló0		sól			5		-ól			-oli		-ole		<f.#>			ó/o alternation
D1ń0		otchłań		109		-ń			-ni			-nie		<f>
D1ń0+i		pieśń		2		-ń			-ni			-ni			<f.nompli>		baśń/pieśń
D1ń0+(mi)	dłoń		3		-ń			-ni			-nie		<f.insplmi>		ins_pl in -ńmi; dań/dłoń/skroń
D1ń0+(mi)/p2:p3 sanie	3		-nie		*			-nie		<f.pl.insplmi>	ins_pl in -ńmi; sanie/aerosanie/autosanie
D1ńe0		bezdeń		1		-eń			-ni			-ni			<f.*.nompli>
Dińei0		rówień		1		-ień		-ni			-nie		<f.*>
D1ś0		Ruś			10		-ś			-si			-sie		<f>
D1ś0+!		córuś		3		-ś			-si			-sie		<f.voc->		voc_sg in - instead of -i
Diś0+i		pierś		5		-ś			-si			-si			<f.nompli.insplami:mi> gęś/Gęś/nurogęś/pierś/połpierś
D1ś0+i(mi)	gęś			2		-ś			-si			-si			[same as above]	ins_pl in -śmi; gęś/nurogęś
D1śei0		wieś		7		-ieś		-si			-sie		<f.*.nomple:i[obsolete]> wieś and compounds including toponyms
D1śei0+i	wieś		7		-ieś		-si			-si			[same as above; obsolete]
D1we0		Narew		28		-ew			-wi			-wie		<f.*>
D1we0+i		brew		1		-ew			-wi			-wi			<f.*.nompli>
D1we0+i/p2	drzwi		2		-wi			*			-wi			<f.*.pl.nompli>	drzwi/odrzwi
D1wei0		cerkiew		25		-iew		-wi			-wie		<f.*>
D1wó0		Ostrów		1		-ów			-owi		-owie		<f.#>			ó/o alternation
D1ź0		maź			37		-ź			-zi			-zie		<f>
D1ź0+i		spowiedź	16		-ź			-zi			-zi			<f.nompli>
D1ź0+i/p3	zapowiedzi	1		-zi			*			-zi			<f.pl.nompli>
D1źą0		gałąź		1		-ąź			-ęzi		-ęzie		<f.#.insplami:mi> ą/ę alternation
D1źą0+(mi)	gałąź		1		-ąź			-ęzi		-ęzie		[same as above]	ą/ę alternation; ins_pl in -ęźmi
D1źdą0		żołądź		2		-ądź		-ędzi		-ędzie		<f.#>			ą/ę alternation; other one is also żołądź [different meaning, has multiple declensions]
D1źdó0		łódź		9		-ódź		-odzi		-odzie		<f.#>			ó/o alternation
D1źó0		zamróź		1		-óź			-ozi		-ozie		<f.#>			ó/o alternation
D20			noc			178		-			-y			-e			<f>				in -[cż]/[crs]z
D20+anoc	Wielkanoc	2		-anoc		-iejnocy	-ienoce		((Wielkanoc<f>,Wielka<+>noc<f.[rare]>)) other one is also Wielkanoc [different meaning, both meanings have multiple declensions]
D20+y		rzecz		4		-			-y			-y			<f.nomply>		in -[cż]/[crs]z
D2zse0		wesz		1		-esz		-szy		-szy		<f.*.nomply>
D2żą0		uprząż		2		-ąż			-ęży		-ęże		<f.#>			ą/ę alternation
D2że0		reż			2		-eż			-ży			-że			<f.*>
D2żó0		podłóż		1		-óż			-oży		-oże		<f.#>			ó/o alternation
]=]

decls["cons-f"] = function(base, stems)
	-- See comment above definition of 'local decls' for where stem and ending alternations are handled.
	add_decl(base, stems, "y", "y", "-", "ą", "y", "y",
		"e", "y", "om", "e", "ami", "ach")
end

declprops["cons-f"] = {
	cat = "soft zero-ending"
}


decls["istem-f"] = function(base, stems)
	add_decl(base, stems, "i", "i", "-", "i", "i", "í",
		-- See above under apply_special_cases(); -E causes depalatalization of ť/ď/ň.
		"i", "í", "Em", "i", "Ech", "mi")
end

declprops["istem-f"] = {
	cat = "i-stem"
}


decls["mixed-istem-f"] = function(base, stems)
	local gen_s, nom_p, dat_p, ins_p, loc_p
	-- Use of ě vs E below is intentional. Contrast [[oběť]] dat_pl 'obětem' (depalatalizing) with [[nit]] ins_pl
	-- 'nitěmi' (palatalizing). See comment above under apply_special_cases().
	if base.mixedistem == "pěst" then
		-- pěst, past, mast, lest [reducible; ins_pl 'lstmi'], pelest, propust, plst, oběť, zeď [reducible; ins_pl
		-- 'zdmi'], paměť [ins_pl 'pamětmi/paměťmi]
		gen_s, nom_p, dat_p, ins_p, loc_p = "i", "i", {"ím", "Em"}, "mi", {"ích", "Ech"}
	elseif base.mixedistem == "moc" then
		-- moc, nemoc, pomoc, velmoc; NOTE: pravomoc has -i/-e alternation in gen_s, nom_p
		gen_s, nom_p, dat_p, ins_p, loc_p = "i", "i", {"Em", "ím"}, "ěmi", {"Ech", "ích"}
	elseif base.mixedistem == "myš" then
		-- myš, veš [reducible, ins_pl vešmi], hruď, měď, pleť, spleť, směs, smrt, step, odpověď [ins_pl 'odpověď'mi/odpovědmi'], šeď,
		-- závěť [ins_pl 'závěťmi/závětmi'], plsť [ins_pl 'plstmi']
		gen_s, nom_p, dat_p, ins_p, loc_p = "i", "i", "ím", "mi", "ích"
	elseif base.mixedistem == "noc" then
		-- lež [reducible], noc, mosaz, rez [reducible], ves [reducible], mysl, sůl, běl, žluť
		gen_s, nom_p, dat_p, ins_p, loc_p = "i", "i", "ím", "ěmi", "ích"
	elseif base.mixedistem == "žluč" then
		-- žluč, moč, modř, čeleď, kapraď, záď, žerď, čtvrť/čtvrt, drť, huť, chuť, nit, pečeť, závrať, pouť, stať, ocel
		gen_s, nom_p, dat_p, ins_p, loc_p = {"i", "ě"}, {"i", "ě"}, "ím", "ěmi", "ích"
	elseif base.mixedistem == "loď" then
		-- loď, suť
		gen_s, nom_p, dat_p, ins_p, loc_p = {"i", "ě"}, {"i", "ě"}, {"ěmi", "mi"}, "ím", "ích"
	else
		error(("Unrecognized value '%s' for 'mixedistem', should be one of 'pěst', 'moc', 'myš', 'noc', 'žluč' or 'loď'"):
			format(base.mixedistem))
	end
	add_decl(base, stems, gen_s, "i", "-", "í", "i", "i",
		nom_p, "í", dat_p, nom_p, ins_p, loc_p)
end

declprops["mixed-istem-f"] = {
	-- Include subtype in the table description but not in the category to avoid too many categories.
	desc = function(base, stems)
		return ("mixed i-stem [type '%s'] GENDER"):format(base.mixedistem)
	end,
	cat = function(base, stems)
		return {"mixed i-stem", ("mixed i-stem GENPOS (type '%s')"):format(base.mixedistem)}
	end,
}


decls["i-f"] = function(base, stems)
	-- [[máti]] "mother" (singular-only), [[pramáti]] "foremother"; very similar to the 'noc' mixed i-stem type
	add_decl(base, stems, "i", "i", "-", "i", "i", "í",
		"i", "í", "ím", "i", "ích", "ěmi")
end

declprops["i-f"] = {
	cat = "GENPOS in -i"
}


decls["ea-f"] = function(base, stems)
	-- Stem ends in -e.
	if base.tech then
		-- diarea, gonorea, chorea, nauzea, paleogea, seborea, trachea
		add_decl(base, stems, "y", "i", "u", "o", "i", "ou",
			"y", "í", {"ám", "ím"}, "y", {"ách", "ích"}, "ami")
	elseif base.persname then
		-- Medea, Andrea, etc.
		add_decl(base, stems, {"y", "je", "ji"}, {"e", "je", "ji"}, "u", "o", {"e", "je", "ji"}, "ou",
			-- this is a guess, based on the same as below; plural of personal names not attested in IJP
			{"y", "je"}, "jí", {"ám", "jím"}, {"y", "je"}, {"ách", "jích"}, {"ami", "jemi"})
	else
		-- idea, odysea ("wandering pilgrimage"), orchidea, palea, spirea
		-- proper names Galilea, Judea, Caesarea, Korea, Odyssea ("epic poem")
		add_decl(base, stems, {"y", "je"}, "ji", "u", "o", "ji", {"ou", "jí"},
			{"y", "je"}, "jí", {"ám", "jím"}, {"y", "je"}, {"ách", "jích"}, {"ami", "jemi"})
	end
end

declprops["ea-f"] = {
	cat = function(base, stems)
		if base.tech then
			return {"GENPOS in -ea", "technical GENPOS in -ea"}
		else
			return "GENPOS in -ea"
		end
	end
}


decls["oa-f"] = function(base, stems)
	-- Stem ends in -o/-u.
	-- stoa, kongrua; proper names Samoa, Managua, Nikaragua, Capua
	add_decl(base, stems, "y", "i", "u", "o", "i", "ou",
		"y", "í", "ám", "y", "ách", "ami")
end

declprops["oa-f"] = {
	cat = "GENPOS in -oa/-ua"
}


decls["ia-f"] = function(base, stems)
	-- Stem ends in -i.
	-- belaria, signoria, uncia; paranoia, sinfonia;
	-- proper names Alexandria, Alexia, Livia, Monrovia, Olympia, Sofia
	-- Identical to soft declension except for nom_sg.
	decls["soft-f"](base, stems)
end

declprops["ia-f"] = {
	cat = "GENPOS in -ia"
}

--[=[
Examples:


In -o:

meaning		nom_sg		gen_sg		loc_sg		nom_pl		gen_pl		ins_pl
thigh		udo			uda			udzie		uda			ud			udami
mouth		-			-			-			usta		ust			ustami
gun			działo		działa		dziale		działa		dział		działami
zero		zero		zera		zerze		zera		zer			zerami
sky			niebo		nieba		niebie		niebosa/nieba niebios	niebiosami
word		słowo		słowa		słowie		słowa		słów		słowami
gate		-			-			-			wrota		wrót		wrotami
circle,wheel koło		koła		kole		koła		kół			kołami
bottom		dno			dna			dnie		dna			den			dnami
firewood	-			-			-			drwa		drew		drwami
background	tło			tła			tle			tła			teł			tłami
witchcraft	-			-			-			gusła		guseł		gusłami
rib			żebro		żebra		żebrze		żebra		żeber		żebrami
window		okno		okna		oknie		okna		okien		oknami
glass		szkło		szkła		szkle		szkła		szkieł		szkłami
nest		gniazdo		gniazda		gnieździe	gniazda		gniazd		gniazdami
body		ciało		ciała		ciele		ciała		ciał		ciałami
light		światło		światła		świetle		światła		świateł		światłami
boonies		wygwizdowo	wygwizdowa	wygwizdowie	wygwizdowa	wygwizdowów	wygwizdowami
marvel		cudo		cuda		cudzie		cuda		cudów		cudami
echo		echo		echa		echu		echa		ech			echami
army		wojsko		wojska		wojsku		wojska		wojsk		wojskami	ins_sg: wojskiem
[gmina]		-			-			-			Łaziska		Łazisk		Łaziskami
egg			jajo		jaja		jaju		jaja		jaj			jajami
pier		molo		mola		molu		mola		mol			molami
lung		płuco		płuca		płucu		płuca		płuc		płucami
good		dobro		dobra		dobru		dobra		dóbr		dobrami
evil		zło			zła			złu			zła			zeł			złami
apple		jabłko		jabłka		jabłku		jabłka		jabłek		jabłkami	ins_sg: jabłkiem
crèche		-			-			-			jasełka		jasełek		jasełkami
tall_man	chłopisko	chłopiska	chłopisku	chłopiska	chłopisków	chłopiskami	ins_sg: chłopiskiem
muzzle,mug	pysio		pysia		pysiu		pysia		pysiów		pysiami
studio		studio		studia		studiu		studia		studiów		studiami
ranch		ranczo		rancza		ranczu		rancza		ranczów		ranczami
child		dziecko		dziecka		dziecku		dzieci		dzieci		dziećmi		loc_pl: dzieciach
ear			ucho		ucha		uchu		uszy		uszu		uszami
eye			oko			oka			oku			oczy		oczu		oczami		ins_sg: okiem
votive_offering wotum	wotum		wotum		wota		wotów		wotami		indecl in_sg
Polish_artifacts -		-			-			polonika	poloników	polonikami
realia		-			-			-			realia		realiów		realiami
miscellanea	-			-			-			miscellanea	miscellaneów miscellaneami


In -e:

meaning		nom_sg		gen_sg		loc_sg		nom_pl		gen_pl		ins_pl
course/dish	danie		dania		daniu		dania		dań			daniami
[unit_of_length] staje	staja		staju		staja		staj		stajami
[wedding_reception] wesele wesela	weselu		wesela		wesel		weselami
sun			słońce		słońca		słońcu		słońca		słońc		słońcami
seed		nasienie	nasienia	nasieniu	nasiona		nasion		nasionami
proverb		przysłowie	przysłowia	przysłowiu	przysłowia	przysłów	przysłowiami
field		pole		pola		polu		pola		pól			polami
sea			morze		morza		morzu		morza		mórz		morzami
herb		ziele		ziela		zielu		zioła		ziół		ziołami
tool		narzędzie	narzędzia	narzędziu	narzędzia	narzędzi	narzędziami
intestines	-			-			-			trzewia		trzewi		trzewiami
crop/craw	wole		wola		wolu		wola		woli		wolami
animal_eye	ślepie		ślepia		ślepiu		ślepia		ślepiów		ślepiami
vine		pnącze		pnącza		pnączu		pnącza		pnączy		pnączami
[Krakow_district] -		-			-			Krowodrza	Krowodrzy	Krowodrzami
[state_monopoly] regale	regale		regale		regalia		regaliów	regaliami		indecl in_sg


Adjectival in -e:

meaning		nom_sg		gen_sg		loc_sg		nom_pl		gen_pl		ins_pl
[Warsaw_street] Krakowskie Krakowskiego Krakowskiem -			-			-
[town]		-			-			-			Końskie		Końskich	Końskimi
[town]		Zakopane	Zakopanego	Zakopanem	-			-			-
[village]	Białe		Białego		Białem		-			-			-
[village]	Dobre		Dobrego		Dobrem		-			-			-
[manorial_land] pańskie	pańskiego	pańskim		pańskie		pańskich	pańskimi
cub			młode		młodego		młodym		młode		młodych		młodymi


In -ę (n-stem):

meaning		nom_sg		gen_sg		loc_sg		nom_pl		gen_pl		ins_pl
name		imię		imienia		imieniu		imiona		imion		imionami


In -ę (t-stem):

meaning		nom_sg		gen_sg		loc_sg		nom_pl		gen_pl		ins_pl
eyes		-			-			-			oczęta		ocząt		oczętami
calf_of_cow	cielę		cielęcia	cielęciu	cielęta		cieląt		cielętami
]=]

--[=[
Counts from SGJP (defaults to /n2):

Type		e.g.		count	ending		gensg		locsg		nompl		genpl		indicator		notes
A1jN		moje		3		-je			-jego		-im			-je			-ich						moje/swoje/twoje
A1N			wdowie		8		-ie			-iego		-im			-ie			-ich						polskie/pańskie/szampańskie/reńskie/psiarskie/dworskie/ostatnie/wdowie
A3k+(em)	Głębokie	163		-ie			-iego		-iem		-ie			-ich						all toponyms in -[bgkns]ie
A3N			drugie		1		-gie		-giego		-gim		-gie		-gich		
A4+(em)		Zakopane	233		-e			-ego		-em			-e			-ych						all toponyms in -[błnprstwzż]e/{ch,cz,rs,sz}e
A4+(em)/p2:p3 Żółte		29		-e			*			*			-e			-ych						all toponyms in -[błnprstwzż]e/{ch,cz,rs,sz}e
A4N/n1		małe		1		-e			-ego		-ym			-e			-ych		
A4N			czesne		189		-e			-ego		-ym			-e			-ych		
A4N/p3		berberysowate 280	-e			*			*			-e			-ych						~75% in -owate
C1c			nacięcie	2432	-cie		-cia		-ciu		-cia		-ć			
C1c/p2		zajęcia		1		-cia		*			*			-cia		-ć			
C1c/p3		objęcia		3		-cia		*			*			-cia		-ć			
C1ę+(en)/n1	imię		1		-ę			-enia		-eniu		-ona		-on			
C1ę+(en)	plemię		17		-ę			-enia		-eniu		-ona		-on			
C1ę+(ęc)/m1	książę		2		-ę			księcia/	księciu/	-ęta		-ąt			
									-ęcia:dated -ęciu:dated
C1ę+(ęc)/n1	źrebię		99		-ę			-ęcia		-ęciu		-ęta		-ąt			
C1ę+(ęc)	lalczę		3		-ę			-ęcia		-ęciu		-ęta		-ąt			
C1ę+(ęc)/p2	Bliźnięta	30		-ęta		*			*			-ęta		-ąt			
C1ę+(ęc)/p3	bucięta		46		-ęta		*			*			-ęta		-ąt			
C1+(i)		osiedle		157		-e			-a			-u			-a			-i			
C1+(i)/p2	Izwiestia	1		-a			*			*			-a			-i			
C1+(i)/p3	Izwiestia	1		-a			*			*			-a			-i			
Cile		ziele		3		-ele		-ela		-elu		-oła		-ół							ziele/trójziele/zimoziele
C1ló		pole		5		-ole		-ola		-olu		-ola		-ól			
C1ló/p2:p3	Pola		1		-ola		*			*			-ola		-ól			
C1n			mieszkanie	29553	-nie		-nia		-niu		-nia		-ń			
C1n/p3		rokowania	13		-nia		*			*			-nia		-ń			
C1ne		nasienie	1		-enie		-enia		-eniu		-ona		-on			
C1ne+0		imienie		1		-enie		-enia/ona	-eniu		-enia		-eni/on		
C1(o)+(i)	pikolo		5		-o			-a			-u			-a			-i							pueblo/diabolo/piccolo/pikolo/tremolo
C1+(ów)		studio		33		-o			-a			-u			-a			-ów							all in -io or -eo (video/wideo/rodeo) except gorąco/leporello/leczo/intermezzo
C1wo		przysłowie	1		-owie		-owia		-owiu		-owia		-ów			
C1żą+(ęt)	książę		2		-ążę		-ęcia		-ęciu		-ążęta		ążąt		
C2			serce		604		-e			-a			-u			-a			-			
C2cei		żelazce		2		-ce			-ca			-cu			-ca			-iec						żelazce/żelezce
C2ceiz		żeleźce		1		-źce		-źca		-źcu		-źca		-ziec		
C2ce(i)		jajco		1		-co			-ca			-cu			-ca			-ec			
C2ce(i)/p3	jajca		1		-ca			*			*			-ca			-ec							jajca/jelca
C2+(ów)		drzewce		8		-e			-a			-u			-a			-ów			
C2+(ów)/p2	errata		1		-a			*			*			-a			-ów			
C2+(ów)/p3	aktualia	121		-a			*			*			-a			-ów							~50% in -ia, 4 in -ea, the rest in -Ca
C2+(y)/n1	nozdrze		1		-e			-a			-u			-a			-y			
C2+(y)		naręcze		443		-e			-a			-u			-a			-y			
C2+(y)/p3	przestworza	1		-a			*			*			-a			-y			
Czzro		morze		2		-orze		-orza		-orzu		-orza		-órz						morze/zorze
Czzro/p2:p3	Borza		1		-orza		*			*			-orza		-órz		
C2żó		zboże		3		-oże		-oża		-ożu		-oża		-óż							zboże/łoże/złoże	
C3			skupisko	984		-o			-a			-u			-a			-							ins -iem; in -go/-ko esp. -isko/-ysko
C3			pludrzyska	1		-a			*			*			-a			-			
C3(cco)		sirocco		1		-cco		-cca		-ccu		-cca		-cc							ins -kkiem
C3(cco)/m3	sirocco		1		-cco		-cca		-ccu		-cca		-cc						
C3(cko)/n1	dziecko		1		-cko		-cka		-cku		-ci			-ci							ins -ckiem; dat_pl -ciom; ins_pl -ćmi; loc_pl -ciach
C3(cko)/n2	półdziecko	1		-cko		-cka		-cku		-ci			-ci							ins -ckiem; dat_pl -ciom; ins_pl -ćmi; loc_pl -ciach
C3(cko)/p2:p3 Zdzieci	1		-ci			*			*			-ci			-ci							ins -ckiem; dat_pl -ciom; ins_pl -ćmi; loc_pl -ciach
C3(co)		Servisco	3		-co			-ca			-cu			-ca			-c							ins -kiem; lastrico/rococo/Servisco
C3+(ełyko)	wilczełyko	1		-ełyko		-egołyka	-ymłyku		-ełyka		-ychłyk		wilcze<+>łyko<>
C3+(eoczko)	woleoczko	1		-eoczko		-egooczka	-imoczku	-eoczka		-ichoczek	wole<+>oczko<>
C3h			ciacho		36		-o			-a			-u			-a			-			
C3ke		serduszko	733		-ko			-ka			-ku			-ka			-ek							ins -kiem
C3ke/p2		usteczka	6		-ka			*			*			-ka			-ek			
C3ke/p3		jasełeczka	11		-ka			*			*			-ka			-ek			
C3kein		kazańko		14		-ńko		-ńka		-ńku		-ńka		-niek						ins -ńkiem
C3kein/p2	wroteńka	1		-ńka		*			*			-ńka		-niek		
C3ok		oko			1		-oko		-oka		-oku		-oczy		-oczów/ócz:dated_rare 		ins -okiem
C3+(owi)/m1	konisko		1		-o			-a			-u			-a			-ów							ins -iem; dat -owi
C3+(ów)		papierosisko 59		-o			-a			-u			-a			-ów							ins -iem
C3+(ów)/m1	biedaczysko 18		-o			-a			-u			-a			-ów							ins -iem
C3+(ów)/p3	pludrzyska	1		-a			*			*			-a			-ów			
C4			bielmo		5139	-o			-a			-ie			-a			-							in -[bmnsvwz]o esp. -owo/-ctwo/-stwo
C4/p2		odedrzwia	156		-a			*			*			-a			-			
C4/p3		portczyska	165		-a			*			*			-a			-			
C4d			stado		34		-o			-a			-zie		-a			-			
C4d+(ów)	cudo		2		-o			-a			-zie		-a			-ów							cudo/awokado
C4dza		gniazdo		1		-azdo		-azda		-eździe		-azda		-azd		
C4hcu		ucho		1		-cho		-cha		-chu		-szy		-szy/szów:rare 
C4l			kakao		3		-o			-a			-le			-a			-ł							macao/kakao/makao
C4le		czoło		1		-oło		-oła		-ele		-oła		-ół			
C4ł			działo		10		-ło			-ła			-le			-ła			-ł			
C4ła		ciało		4		-ało		-ała		-ele		-ała		-ał							ciało/przeciwciało/autoprzeciwciało/antyciało
C4łe		wiertło		221		-ło			-ła			-le			-ła			-eł							mostly in -dło
C4łe/p2		widła		18		-ła			*			*			-ła			-eł			
C4łe/p3		gusła		26		-ła			*			*			-ła			-eł			
C4łei		sprzęgło	15		-ło			-ła			-le			-ła			-ieł						in -[kg]ło
C4łei/p2	Niepiekła	1		-ła			*			*			-ła			-ieł		
C4łei/p3	szkła		2		-ła			*			*			-ła			-ieł						Niepiekła/szkła
C4łes		hasło		14		-sło		-sła		-śle		-sła		-seł		
C4łe+(u)	zło			2		-ło			-ła			-łu			-ła			-eł							zło/wszechzło
C4łez		giezło		2		-zło		-zła		-źle		-zła		-zeł						giezło/gzło
C4ło		koło		7		-oło		-oła		-ole		-oła		-ół			
C4ło/p3		koła		1		-oła		*			*			-oła		-ół			
C4łs		rzemiosło	3		-sło		-sła		-śle		-sła		-sł							rzemiesło/rzemiosło/trzósło
C4łta		światło		3		-atło		-atła		-etle		-atła		-ateł						światło/półświatło/dwuświatło
C4łz		giezło		1		-zło		-zła		-źle		-zła		-zł			
C4me		jarzmo		4		-mo			-ma			-mie		-ma			-em							pasmo/powismo/karzmo/krzyżmo
C5ms		pismo		12		-smo		-sma		-śmie		-sma		-sm							pasmo and pismo+compounds
C4ne		dno			44		-no			-na			-nie		-na			-en							in -[djlłr]no/-chno/-czno
C4ne/p2		Próchna		2		-na			*			*			-na			-en			
C4ne/p3		żarna		3		-na			*			*			-na			-en			
C4nei		drewno		66		-no			-na			-nie		-na			-ien						in -[gkmpw]no
C4neic		płótno		7		-tno		-tna		-tnie		-tna		-cien						Kłótno/płótno/półpłótno/Krytno/Korytno/Szczytno/Żytno
C4neis		krosno		5		-sno		-sno		-śnie		-sna		-sien						Olesno/Chrosno/krosno/Krosno/Prosno
C4nez		kiełzno		1		-zno		-zno		-źnie		-zna		-zen		
C4nś		krośno		21		-śno		-śno		-śnie		-śna		-sien		
C4nz		kiełzno		5		-zno		-zno		-źnie		-zna		-zn							Gniezno/Drezno/Brzezno/Pilzno/kiełzno
C4+(ów)		Szczepanowo	1551	-o			-a			-ie			-a			-ów							concertino (gen_pl -nów/-n), awizo (gen_pl -zów/z), + 1549 proper names (toponyms) in -owo (gen_pl -ow/owów/ów)
C4r			bajoro		30		-ro			-ra			-rze		-ra			-r							allegro/makro/mokro/szatro/metro/piętro/bistro/jutro/Rytro + the rest in -Vro
C4rbo		dobro		1		-obro		-obra		-obru		-obra		-óbr		
C4rbo/p2	Dobra		1		-obra		*			*			-obra		-óbr		
C4rbo/p3	dobra		2		-obra		*			*			-obra		-óbr						dobra/Dobra
C4re		futro		20		-ro			-ra			-rze		-ra			-er							4 in -bro, 9 in -dro, chuchro, 6 in -tro
C4re+(ów)	olstro		3		-ro			-ra			-rze		-ra			-rów						cicero/cycero/olstro
C4se+ech	niebiosa	1		-osa		*			*			-osa		-os							loc_pl niebiesiech
C4t			dłuto		75		-to			-ta			-cie		-ta			-t			
C4ta		lato		1		-ato		-ata		-ecie		-ata		-at			
C4t(e)		andante		1		-te			-ta			-cie		-ta			t			
C4tę		święto		1		-ęto		-ęta		-ęcie		-ęta		-ąt			
C4to		wrota/p2	1		-ota		*			*			-ota		-ót			
C4t+(ów)	divertimento 4		-to			-ta			-cie		-ta			-tów						pizzicato/sfumato/sgraffito/divertimento
C4tsa		miasto		5		-asto		-asta		-eście		-asta		-ast						ciasto/miasto/Miasto/trójmiasto/Trójmiasto
C4we/p3		drwa		1		-wa			*			*			-wa			-ew			
C4wo		Legionowo	1548	-owo		-owa		-owie		-owa		-ów							all proper names in -owo (gen_pl -ow/owów/ów)
C4wo+(y?)	słowo		1		-owo		-owa		-owie		-owa		-ów							ins_pl słowami/słowy:dated
C4+(y?)/p2	usta		1		-a			*			*			-a			-							ins_pl ustami/usty:obsolete
C5i			facsimile	5		-e			-e			-e			-ia			-iów						indecl in sg; regale/ekstemporale/uniwersale/facsimile/faksymile
C5mu		muzeum		445		-um			-um			-um			-a			-ów							indecl in sg
[C5no+ua]/m3 epeisodion	[masc type]
C5t			poema		8		-			-			-			-ta			-tów						Greek neut in -ma; indecl in sg; drama/dylema/poema/systema/apoftegma/klima/dilemma/aksjoma
]=]
decls["hard-n"] = function(base, stems)
	local velar = base.velar or not base["-velar"] and rfind(stems.vowel_stem, com.velar_c .. "$")
	-- NOTE: Per IJP it appears the meaning of the preceding preposition makes a difference: 'o' = "about" takes
	-- '-u' or '-ě', while 'na/v' = "in, on" normally takes '-ě'.
	local loc_s =
		-- Exceptions: [[mléko]] "milk" ('mléku' or 'mléce'), [[břicho]] "belly" ('břiše' or (less often) 'břichu'),
		-- [[roucho]] ('na rouchu' or 'v rouše'; why the difference in preposition?).
		velar and "u" or
		-- IJP says nouns in -dlo take only -e but the declension tables show otherwise. It appears -u is possible
		-- but significantly less common. Other nouns in -lo usually take just -e ([[čelo]] "forehead",
		-- [[kolo]] "wheel", [[křeslo]] "armchair", [[máslo]] "butter", [[peklo]] "hell", [[sklo]] "glass",
		-- [[světlo]] "light", [[tělo]] "body"; but [[číslo]] "number' with -e/-u; [[zlo]] "evil" and [[kouzlo]] "spell"
		-- with -u/-e).
		rfind(base.lemma, "dlo$") and {"ě", "u"} or
		rfind(base.lemma, "lo$") and "ě" or
		(rfind(base.lemma, "[sc]tvo$") or rfind(base.lemma, "ivo$")) and "u" or
		-- Per IJP: Borrowed words and abstracts take -u (e.g. [[banjo]]/[[bendžo]]/[[benžo]] "banjo", [[depo]] "depot",
		-- [[chladno]] "cold", [[mokro]] "damp, dampness", [[právo]] "law, right", [[šeru]] "twilight?",
		-- [[temno]] "dark, darkness", [[tempo]] "rate, tempo", [[ticho]] "quiet, silence", [[vedro]] "heat") and others
		-- often take -ě/-u. Formerly we defaulted to -ě/-u but it seems better to default to just -u, similarly to hard
		-- masculines.
		-- {"ě", "u"}
		"u"
	local loc_p =
		-- Note, lemmas in -isko also have mixed-reducible as default, handled in determine_default_reducible().
		-- Note also, ending -ích triggers the second palatalization.
		rfind(base.lemma, "isko$") and {"ích", "ách"} or
		-- Diminutives in -ko, -čko, -tko; also [[lýtko]], [[děcko]], [[vrátka]], [[dvířka]], [[jho]], [[roucho]],
		-- [[tango]], [[mango]], [[sucho]], [[blaho]], [[víko]], [[echo]], [[embargo]], [[largo]], [[jericho]] (from
		-- IJP). Also foreign nouns in -kum: [[antibiotikum]], [[narkotikum]], [[afrodiziakum]], [[analgetikum]], etc.
		-- [[jablko]] "apple" has '-ách' or '-ích' and needs an override; likewise for [[vojsko]] "troop"; [[riziko]]
		-- "risk" normally has '-ích' and needs and override.
		velar and "ách" or
		"ech"
	add_decl(base, stems, "a", "u", "-", "-", loc_s, "em",
		"a", "", "ům", "a", loc_p, "y")
	-- FIXME: paired body parts e.g. [[rameno]] "shoulder" (gen_p/loc_p 'ramenou/ramen'), [[koleno]] "knee"
	-- (gen_p/loc_p 'kolenou/kolen'), [[prsa]] "chest, breasts" (plurale tantum; gen_p/loc_p 'prsou').
	-- FIXME: Nouns with both neuter and feminine forms in the plural, e.g. [[lýtko]] "calf (of the leg)",
	-- [[bedro]] "hip", [[vrátka]] "gate".
end

declprops["hard-n"] = {
	desc = function(base, stems)
		if base.velar or not base["-velar"] and rfind(stems.vowel_stem, com.velar_c .. "$") then
			return "velar GENDER"
		else
			return "hard GENDER"
		end
	end,
	cat = function(base, stems)
		if base.velar or not base["-velar"] and rfind(stems.vowel_stem, com.velar_c .. "$") then
			return "velar-stem"
		else
			return "hard"
		end
	end
}


decls["semisoft-n"] = function(base, stems)
	-- Examples:
	-- * In -ao: [[kakao]] "cacao", [[makao]] "Macao (gambling card game, see Wikipedia)", [[curaçao]] "curaçao (liqueur)"
	--   (IJP gives gen_pl 'curaç' but ASSC [https://slovnikcestiny.cz/heslo/cura%C3%A7ao/0/9967] says 'curaçí' as expected),
	--   [[farao]] "faro (card game)"; also [[Makao]], [[Pathet Lao]], but these are sg-only
	-- * In -eo: [[stereo]], [[rodeo]], [[video]], [[solideo]]; also [[Borneo]], [[Montevideo]], but these are sg-only
	-- * In -io: [[rádio]] "radio", [[gramorádio]], [[studio]], [[scenário]], [[trio]], [[ážio]] (also spelled [[agio]]),
	--   [[disážio]], [[folio]], [[vibrio]]; also [[arpeggio]], [[adagio]], [[capriccio]], [[solfeggio]] although
	--   pronounced the Italian way without /i/; also [[Ohio]], [[Ontario]], [[Tokio]], but these are sg-only
	-- * In -uo: only [[duo]]
	-- * In -yo: only [[embryo]]
	-- * In -eum: [[muzeum]], [[lyceum]], [[linoleum]], [[ileum]], etc.
	-- * In -ium: [[atrium]] "atrium", most chemical elements, etc.
	-- * In -uum: [[individuum]], [[kontinuum]], [[premenstruum]], [[residuum]], [[vakuum]]/[[vacuum]]
	-- * In -yum: only [[baryum]] "barium" (none others in SSJC)
	-- * In -ion: [[enkómion]] "encomium", [[eufonion]] (variant of [[eufonium]]), [[amnion]], [[ganglion]], [[gymnasion]],
	--   [[scholion]], [[kritérion]] (rare for [[kritérium]]), [[onomatopoion]] (variant of [[onomatopoie]]),
	--   [[symposion]], [[synedrion]]; also [[Byzantion]], but this is sg-only; most words in -ion are masculine
	-- Hard in the singular, mostly soft in the plural. Those in -eo and -uo have alternative hard endings in the
	-- dat/ins/loc_pl, but not those in -eum or -uum. Those in -ao have only hard endings except in the gen_pl. (There are
	-- apparently no neuters in -eon; those in -eon or -yon e.g. [[akordeon]], [[neon]], [[nukleon]], [[karyon]], [[Lyon]]
	-- are masculine.)
	local dat_p, ins_p, loc_p
	if rfind(base.actual_lemma, "ao$") then
		dat_p, ins_p, loc_p = "ům", "ech", "y"
	elseif rfind(base.actual_lemma, "[eu]o$") then
		dat_p, ins_p, loc_p = {"ím", "ům"}, {"ích", "ech"}, {"i", "y"}
	else
		dat_p, ins_p, loc_p = "ím", "ích", "i"
	end
	add_decl(base, stems, "a", "u", "-", "-", "u", "em",
		"a", "í", dat_p, "a", ins_p, loc_p)
end

declprops["semisoft-n"] = {
	cat = "semisoft"
}


decls["soft-n"] = function(base, stems)
	-- Examples: [[moře]] "sea", [[slunce]] "sun", [[srdce]] "heart", [[citoslovce]] "interjection", 
	-- [[dopoledne]] "late morning", [[odpoledne]] "afternoon", [[hoře]] "sorrow, grief" (archaic or literary),
	-- [[inhalace]] "inhalation", [[kafe]] "coffee", [[kanape]] "sofa", [[kutě]] "bed", [[Labe]] "Elbe (singular only)",
	-- [[líce]] "cheek", [[lože]] "bed", [[nebe]] "sky; heaven", [[ovoce]] "fruit", [[pole]] "field", [[poledne]]
	-- "noon", [[příslovce]] "adverb", [[pukrle]] "curtsey" (also t-n), [[vejce]] "egg" (NOTE: gen_pl 'vajec').
	--
	-- Many nouns in -iště, with null genitive plural.
	local gen_p = rfind(base.vowel_stem, "išť$") and "" or "í"
	add_decl(base, stems, "e", "i", "-", "-", "i", "em",
		"e", gen_p, "ím", "e", "ích", "i")
	-- NOTE: Some neuter words in -e indeclinable, e.g. [[Belize]], [[Chile]], [[garde]] "chaperone", [[karaoke]],
	-- [[karate]], [[re]] "double raise (card games)", [[ukulele]], [[Zimbabwe]], [[zombie]] (pl. 'zombie' or
	-- 'zombies')
	-- some nearly indeclinable, e.g. [[finále]], [[chucpe]]; see mostly-indecl below
end

declprops["soft-n"] = {
	cat = "soft"
}


decls["í-n"] = function(base, stems)
	-- [[nábřeží]] "waterfront" and a zillion others; also [[úterý]] "Tuesday".
	-- NOTE: The stem ends in -í/-ý.
	add_decl(base, stems, "", "", "-", "-", "", "m",
		"", "", "m", "", "ch", "mi")
end

declprops["í-n"] = {
	cat = "GENPOS in -í/-ý"
}


decls["n-n"] = function(base, stems)
	-- E.g. [[břemeno]] "burden" (also [[břímě]], use 'decllemma:'); [[písmeno]] "letter"; [[plemeno]] "breed";
	-- [[rameno]] "shoulder" (also [[rámě]], use 'decllemma:'); [[semeno]] "seed" (also [[sémě]], [[símě]], use
	-- 'decllemma:'); [[temeno]] "crown (of the head)"; [[vemeno]] "udder"
	add_decl(base, stems, {"a", "e"}, {"i", "u"}, "-", "-", {"ě", "i", "u"}, "em",
		"a", "", "ům", "a", "ech", "y")
end

declprops["n-n"] = {
	cat = "n-stem"
}


decls["tstem-n"] = function(base, stems)
	-- E.g. [[batole]] "toddler", [[čuně]] "pig", [[daňče]] "fallow deer fawn", [[děvče]] "girl", [[ďouče]] "girl"
	-- (dialectal), [[dítě]] "child" (NOTE: feminine in the plural [[děti]], declined as a feminine i-stem), [[dvojče]]
	-- "twin", [[hádě]] "young snake", [[house]] "gosling", [[hříbě]] "foal" (pl. hříbata), [[jehně]] "lamb", [[kavče]]
	-- "young jackdaw; chough", [[káče]] "duckling", [[káně]] "buzzard chick" (NOTE: also feminine meaning "buzzard"),
	-- [[klíště]] "tick", [[kose]] "blackbird chick" (rare), [[kuře]] "chick (young chicken)", [[kůzle]]
	-- "kid (young goat)", [[lišče]] "fox cub", [[lvíče]] "lion cub", [[medvídě]] "bear cub", [[mládě]] "baby animal",
	-- [[morče]] "guinea pig", [[mrně]] "toddler", [[nemluvně]] "infant", [[novorozeně]] "newborn", [[orle]] "eaglet",
	-- [[osle]] "donkey foal", [[pachole]] "boy (obsolete); page, squire", [[páže]] "page, squire", [[podsvinče]]
	-- "suckling pig", [[prase]] "pig", [[prtě]] "toddler", [[ptáče]] "chick (young bird)",
	-- [[robě]] "baby, small child", [[saranče]] "locust" (NOTE: also feminine), [[sele]] "piglet",
	-- [[slůně]] "baby elephant", [[škvrně]] "toddler", [[štěně]] "puppy", [[tele]] "calf", [[velbloudě]] "camel colt",
	-- [[vlče]] "wolf cub", [[vnouče]] "grandchild", [[vyžle]] "small hunting dog; slender person",
	-- [[zvíře]] "animal, beast".
	--
	-- Some referring to inanimates, e.g. [[doupě]] "lair" (pl. doupata), [[koště]]/[[chvoště]] "broom", [[paraple]]
	-- "umbrella", [[poupě]] "bud", [[pukrle]] "curtsey" (also soft-n), [[rajče]] "tomato", [[šuple]] "drawer",
	-- [[varle]] "testicle", [[vole]] "craw (of a bird); goiter".
	add_decl(base, stems, "ete", "eti", "-", "-", "eti", "etem",
		"ata", "at", "atům", "ata", "atech", "aty")
end

declprops["tstem-n"] = {
	cat = "t-stem"
}


decls["ma-n"] = function(base, stems)
	-- E.g. [[drama]] "drama", [[dogma]] "dogma", [[aneurysma]]/[[aneuryzma]] "aneurysm", [[dilema]] "dilemma",
	-- [[gumma]] "gumma" (non-cancerous syphilitic growth), [[klima]] "climate", [[kóma]] "coma", [[lemma]] "lemma",
	-- [[melisma]] "melisma", [[paradigma]] "paradigm", [[plasma]]/[[plazma]] "plasma [partly ionized gas]"
	-- (note [[plasma]]/[[plazma]] "blood plasma" is feminine), [[revma]] "rheumatism", [[schéma]] "schema, diagram",
	-- [[schisma]]/[[schizma]] "schism", [[smegma]] "smegma", [[sofisma]]/[[sofizma]] "sophism", [[sperma]] "sperm",
	-- [[stigma]] "stigma", [[téma]] "theme", [[trauma]] "trauma", [[trilema]] "trilemma", [[zeugma]] "zeugma".
	add_decl(base, stems, "atu", "atu", "-", "-", "atu", "atem",
		"ata", "at", "atům", "ata", "atech", "aty")
end

declprops["ma-n"] = {
	cat = "ma-stem"
}


decls["adj"] = function(base, stems)
	local props = {}
	local propspec = table.concat(props, ".")
	if propspec ~= "" then
		propspec = "<" .. propspec .. ">"
	end
	local adj_alternant_multiword_spec = require("Module:pl-adjective").do_generate_forms({base.lemma .. propspec})
	local function copy(from_slot, to_slot)
		base.forms[to_slot] = adj_alternant_multiword_spec.forms[from_slot]
	end
	if base.number ~= "pl" then
		if base.gender == "m" then
			copy("nom_m", "nom_s")
			copy("gen_mn", "gen_s")
			copy("dat_mn", "dat_s")
			copy("ins_mn", "ins_s")
			copy("loc_mn", "loc_s")
		elseif base.gender == "f" then
			copy("nom_f", "nom_s")
			copy("gen_f", "gen_s")
			copy("dat_f", "dat_s")
			copy("acc_f", "acc_s")
			copy("ins_f", "ins_s")
			copy("loc_f", "loc_s")
		else
			copy("nom_n", "nom_s")
			copy("gen_mn", "gen_s")
			copy("dat_mn", "dat_s")
			copy("acc_n", "acc_s")
			copy("ins_mn", "ins_s")
			copy("loc_mn", "loc_s")
		end
		if not base.forms.voc_s then
			iut.insert_forms(base.forms, "voc_s", base.forms.nom_s)
		end
	end
	if base.number ~= "sg" then
		if base.gender == "m" then
			if base.animacy == "an" then
				copy("nom_mp_an", "nom_p")
			else
				copy("nom_fp", "nom_p")
			end
			copy("acc_mfp", "acc_p")
		elseif base.gender == "f" then
			copy("nom_fp", "nom_p")
			copy("acc_mfp", "acc_p")
		else
			copy("nom_np", "nom_p")
			copy("acc_np", "acc_p")
		end
		copy("gen_p", "gen_p")
		copy("dat_p", "dat_p")
		copy("ins_p", "ins_p")
		copy("loc_p", "loc_p")
	end
end

local function get_stemtype(base)
	if rfind(base.lemma, "ý$") then
		return "hard"
	elseif rfind(base.lemma, "í$") then
		return "soft"
	else
		return "possessive"
	end
end

declprops["adj"] = {
	cat = function(base, stems)
		return {"adjectival POS", get_stemtype(base) .. " GENDER adjectival POS"}
	end,
}


decls["mostly-indecl"] = function(base, stems)
	-- Several neuters: E.g. [[finále]] "final (sports)", [[čtvrtfinále]] "quarterfinal", [[chucpe]] "chutzpah",
	-- [[penále]] "fine, penalty", [[promile]] "" (NOTE: loc pl also promilech), [[rande]] "rendezvous", [[semifinále]]
	-- "semifinal", [[skóre]] "score".
	-- At least one masculine animate: [[kamikaze]]/[[kamikadze]], where IJP says only -m in the ins sg.
	local ins_s = base.gender == "m" and "m" or {"-", "m"}
	add_decl(base, stems, "-", "-", "-", "-", "-", ins_s,
		"-", "-", "-", "-", "-", "-")
end

declprops["mostly-indecl"] = {
	cat = "mostly indeclinable"
}


decls["indecl"] = function(base, stems)
	-- Indeclinable. Note that fully indeclinable nouns should not have a table at all rather than one all of whose forms
	-- are the same; but having an indeclinable declension is useful for nouns that may or may not be indeclinable, e.g.
	-- [[desatero]] "group of ten" or the plural of [[peso]], which may be indeclinable 'pesos'.
	add_decl(base, stems, "-", "-", "-", "-", "-", "-",
		"-", "-", "-", "-", "-", "-")
end

declprops["indecl"] = {
	cat = function(base, stems)
		if base.adj then
			return {"adjectival POS", "indeclinable adjectival POS", "indeclinable GENDER adjectival POS"}
		else
			return {"indeclinable POS", "indeclinable GENPOS"}
		end
	end
}


decls["manual"] = function(base, stems)
	-- Anything declined manually using overrides. We don't set any declensions except the nom_s (or nom_p if plurale
	-- tantum).
	add(base, base.number == "pl" and "nom_p" or "nom_s", stems, "-")
end

declprops["manual"] = {
	desc = "GENDER",
	cat = {},
}


local function set_pron_defaults(base)
	if base.gender or base.lemma ~= "ona" and base.number or base.animacy then
		error("Can't specify gender, number or animacy for pronouns")
	end

	local function pron_props()
		-- Return values are GENDER, NUMBER, ANIMACY, HAS_CLITIC.
		if base.lemma == "kdo" then
			return "none", "sg", "an", false
		elseif base.lemma == "co" then
			return "none", "sg", "inan", false
		elseif base.lemma == "já" or base.lemma == "ty" then
			return "none", "sg", "an", true
		elseif base.lemma == "my" or base.lemma == "vy" then
			return "none", "pl", "an", false
		elseif base.lemma == "on" then
			return "m", "sg", "none", true
		elseif base.lemma == "ono" then
			return "n", "sg", "inan", true
		elseif base.lemma == "oni" then
			return "m", "pl", "an", false
		elseif base.lemma == "ony" then
			return "none", "pl", "none", false
		elseif base.lemma == "ona" then
			if base.number ~= "sg" and base.number ~= "pl" then
				error("Must specify '.sg' or '.pl' with lemma 'ona'")
			end
			if base.number == "sg" then
				return "f", "sg", "none", false
			else
				return "n", "pl", "inan", false
			end
		elseif base.lemma == "sebe" then
			return "none", "none", "none", true
		else
			error(("Unrecognized pronoun '%s'"):format(base.lemma))
		end
	end

	local gender, number, animacy, has_clitic = pron_props()
	base.gender = gender
	base.actual_gender = gender
	base.number = number
	base.actual_number = number
	base.animacy = animacy
	base.actual_animacy = animacy
	base.has_clitic = has_clitic
end


local function determine_pronoun_stems(base)
	if base.stem_sets then
		error("Reducible and vowel alternation specs cannot be given with pronouns")
	end
	base.stem_sets = {{reducible = false, vowel_stem = "", nonvowel_stem = ""}}
	base.decl = "pron"
end


decls["pron"] = function(base, stems)
	local after_prep_footnote =	"[after a preposition]"
	local animate_footnote = "[animate]"
	if base.lemma == "kdo" then
		add_decl(base, stems, "koho", "komu", nil, nil, "kom", "kým")
	elseif base.lemma == "co" then
		add_decl(base, stems, "čeho", "čemu", nil, nil, "čem", "čím")
	elseif base.lemma == "já" then
		add_sg_decl_with_clitic(base, stems, "mne", "mě", "mně", "mi", nil, nil, nil, "mně", "mnou")
	elseif base.lemma == "ty" then
		add_sg_decl_with_clitic(base, stems, "tebe", "tě", "tobě", "ti", nil, nil, nil, "tobě", "tebou")
	elseif base.lemma == "my" then
		add_pl_only_decl(base, stems, "nás", "nám", "nás", "nás", "námi")
	elseif base.lemma == "vy" then
		add_pl_only_decl(base, stems, "vás", "vám", "vás", "vás", "vámi")
	elseif base.lemma == "on" or base.lemma == "ono" then
		local acc_s = base.lemma == "on" and "jej" or {"jej", "je"}
		local clitic_acc_s = base.lemma == "on" and {"jej", "ho"} or {"jej", "ho", "je"}
		local prep_acc_s = base.lemma == "on" and "něj" or {"něj", "ně"}
		local prep_clitic_acc_s = base.lemma == "on" and "-ň" or nil
		add_sg_decl_with_clitic(base, stems, {"jeho", "jej"}, {"ho", "jej"}, "jemu", "mu", acc_s, clitic_acc_s, nil, nil, "jím")
		add_sg_decl_with_clitic(base, stems, {"něho", "něj"}, nil, "němu", nil, prep_acc_s, prep_clitic_acc_s, nil, "něm", "ním",
			after_prep_footnote)
		if base.lemma == "on" then
		add_sg_decl_with_clitic(base, stems, nil, nil, nil, nil, "jeho", nil, nil, nil, nil,
			animate_footnote)
		add_sg_decl_with_clitic(base, stems, nil, nil, nil, nil, "něho", nil, nil, nil, nil,
			after_prep_footnote and animate_footnote)
		end
	elseif base.lemma == "ona" and base.number == "sg" then
		add_sg_decl(base, stems, "jí", "jí", "ji", nil, nil, "jí")
		add_sg_decl(base, stems, "ní", "ní", "ni", nil, "ní", "ní", after_prep_footnote)
	elseif base.lemma == "oni" or base.lemma == "ony" or base.lemma == "ona" then
		add_pl_only_decl(base, stems, "jich", "jim", "je", nil, "jimi")
		add_pl_only_decl(base, stems, "nich", "nim", "ně", "nich", "nimi", after_prep_footnote)
	elseif base.lemma == "sebe" then
		-- Underlyingly we handle [[sebe]]'s slots as singular.
		add_sg_decl_with_clitic(base, stems, "sebe", "sebe", "sobě", "si", "sebe", "se", nil, "sobě", "sebou",
			nil, "no nom_s")
	else
		error(("Internal error: Unrecognized pronoun lemma '%s'"):format(base.lemma))
	end
end

declprops["pron"] = {
	desc = "GENDER pronoun",
	cat = {},
}


local function set_num_defaults(base)
	if base.gender or base.number or base.animacy then
		error("Can't specify gender, number or animacy for numeral")
	end

	local function num_props()
		-- Return values are GENDER, NUMBER, ANIMACY, HAS_CLITIC.
		return "none", "pl", "none", false
	end

	local gender, number, animacy, has_clitic = num_props()
	base.gender = gender
	base.actual_gender = gender
	base.number = number
	base.actual_number = number
	base.animacy = animacy
	base.actual_animacy = animacy
	base.has_clitic = has_clitic
end


local function determine_numeral_stems(base)
	if base.stem_sets then
		error("Reducible and vowel alternation specs cannot be given with numerals")
	end
	local stem = rmatch(base.lemma, "^(.*)" .. com.vowel_c .. "$") or base.lemma
	base.stem_sets = {{reducible = false, vowel_stem = stem, nonvowel_stem = stem}}
	base.decl = "num"
end


decls["num"] = function(base, stems)
	local after_prep_footnote =	"[after a preposition]"
	if base.lemma == "dva" or base.lemma == "dvě" then
		-- in compound numbers; stem is dv-
		add_pl_only_decl(base, stems, "ou", "ěma", "-", "ou", "ěma")
	elseif base.lemma == "tři" or base.lemma == "čtyři" then
		-- stem is without -i
		local is_three = base.lemma == "tři"
		add_pl_only_decl(base, stems, is_three and "í" or "", "em", "-", "ech", is_three and "emi" or "mi")
		add_pl_only_decl(base, stems, "ech", nil, nil, nil, nil, "[colloquial]")
		add_pl_only_decl(base, stems, nil, nil, nil, nil, is_three and "ema" or "ma",
			"[when modifying a form ending in ''-ma'']")
	elseif base.lemma == "devět" then
		add_pl_only_decl(base, "", "devíti", "devíti", "-", "devíti", "devíti", stems.footnotes)
	elseif base.lemma == "sta" or base.lemma == "stě" or base.lemma == "set" then
		add_pl_only_decl(base, "", "set", "stům", "-", "stech", "sty", stems.footnotes)
	elseif rfind(base.lemma, "[pl]et$") then
		-- [[deset]] and all numbers ending in -cet ([[dvacet]], [[třicet]], [[čtyřicet]] and inverted compound
		-- numerals such as [[pětadvacet]] "25" and [[dvaatřicet]] "32")
		local begin = rmatch(base.lemma, "^(.*)et$")
		add_pl_only_decl(base, stems, "i", "i", "-", "i", "i")
		add_pl_only_decl(base, begin, "íti", "íti", "-", "íti", "íti", stems.footnotes)
	elseif rfind(base.lemma, "oje$") then
		-- [[dvoje]], [[troje]]
		-- stem is without -e
		add_pl_only_decl(base, stems, "ích", "ím", "-", "ích", "ími")
	elseif rfind(base.lemma, "ery$") then
		-- [[čtvery]], [[patery]], [[šestery]], [[sedmery]], [[osmery]], [[devatery]], [[desatery]]
		-- stem is without -y
		add_pl_only_decl(base, stems, "ých", "ým", "-", "ých", "ými")
	else
		add_pl_only_decl(base, stems, "i", "i", "-", "i", "i")
	end
end

declprops["num"] = {
	desc = "GENDER numeral",
	cat = {},
}


local function set_det_defaults(base)
	if base.gender or base.number or base.animacy then
		error("Can't specify gender, number or animacy for determiner")
	end

	local function det_props()
		-- Return values are GENDER, NUMBER, ANIMACY, HAS_CLITIC.
		return "none", "none", "none", false
	end

	local gender, number, animacy, has_clitic = det_props()
	base.gender = gender
	base.actual_gender = gender
	base.number = number
	base.actual_number = number
	base.animacy = animacy
	base.actual_animacy = animacy
	base.has_clitic = has_clitic
end


local function determine_determiner_stems(base)
	if base.stem_sets then
		error("Reducible and vowel alternation specs cannot be given with determiners")
	end
	local stem = rmatch(base.lemma, "^(.*)" .. com.vowel_c .. "$") or base.lemma
	base.stem_sets = {{reducible = false, vowel_stem = stem, nonvowel_stem = stem}}
	base.decl = "det"
end


decls["det"] = function(base, stems)
	add_sg_decl(base, stems, "a", "a", "-", nil, "a", "a")
end

declprops["det"] = {
	desc = "GENDER determiner",
	cat = {},
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
Parse a single override spec (e.g. 'nomplé:ové' or 'ins:autodráhou:autodrahou[rare]') and return
two values: the slot(s) the override applies to, and an object describing the override spec.
The input is actually a list where the footnotes have been separated out; for example,
given the spec 'inspl:čobotami:čobotámi[rare]:čobitmi[archaic]', the input will be a list
{"inspl:čobotami:čobotámi", "[rare]", ":čobitmi", "[archaic]", ""}. The object returned
for 'ins:autodráhou:autodrahou[rare]' looks like this:

{
  full = true,
  values = {
	{
	  form = "autodráhou"
	},
	{
	  form = "autodrahou",
	  footnotes = {"[rare]"}
	}
  }
}

The object returned for 'nomplé:ové' looks like this:

{
  values = {
	{
	  form = "é",
	},
	{
	  form = "ové",
	}
  }
}
]=]
local function parse_override(segments)
	local retval = {values = {}}
	local part = segments[1]
	local slots = {}
	while true do
		local case = usub(part, 1, 3)
		if cases[case] then
			-- ok
		else
			error(("Unrecognized case '%s' in override: '%s'"):format(case, table.concat(segments)))
		end
		part = usub(part, 4)
		local slot
		if rfind(part, "^pl") then
			part = usub(part, 3)
			slot = case .. "_p"
		elseif rfind(part, "^cl") then
			-- No plural clitic cases at this point.
			part = usub(part, 3)
			if clitic_cases[case] then
				slot = "clitic_" .. case .. "_s"
			else
				error(("Unrecognized clitic case '%s' in override: '%s'"):format(case, table.concat(segments)))
			end
		else
			slot = case .. "_s"
		end
		table.insert(slots, slot)
		if rfind(part, "^%+") then
			part = usub(part, 2)
		else
			break
		end
	end
	if rfind(part, "^:") then
		retval.full = true
		part = usub(part, 2)
	end
	segments[1] = part
	local colon_separated_groups = iut.split_alternating_runs_and_strip_spaces(segments, ":")
	for i, colon_separated_group in ipairs(colon_separated_groups) do
		local value = {}
		local form = colon_separated_group[1]
		if form == "" then
			error(("Use - to indicate an empty ending for slot%s '%s': '%s'"):format(#slots > 1 and "s" or "", table.concat(slots), table.concat(segments)))
		elseif form == "-" then
			value.form = ""
		else
			value.form = form
		end
		value.footnotes = fetch_footnotes(colon_separated_group)
		table.insert(retval.values, value)
	end
	return slots, retval
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
  stems = { -- may be missing
	{
	  reducible = TRUE_OR_FALSE or "pal" or "depal",
	  quant_alt = TRUE_OR_FALSE,
	  umlaut = TRUE_OR_FALSE,
	  footnotes = {"FOOTNOTE", "FOOTNOTE", ...}, -- may be missing
	  -- The following fields are filled in by determine_stems()
	  vowel_stem = "STEM",
	  nonvowel_stem = "STEM",
	  umlauted_vowel_stem = "STEM" or nil (defaults to vowel_stem),
	},
	...
  },
  gender = "GENDER", -- "m", "f", "n"; may be missing
  number = "NUMBER", -- "sg", "pl"; may be missing
  animacy = "ANIMACY", -- "inan", "anml", "pr"; may be missing
  hard = true, -- may be missing
  soft = true, -- may be missing
  mixed = true, -- may be missing
  surname = true, -- may be missing
  istem = true, -- may be missing
  ["-istem"] = true, -- may be missing
  tstem = true, -- may be missing
  nstem = true, -- may be missing
  tech = true, -- may be missing
  foreign = true, -- may be missing
  mostlyindecl = true, -- may be missing
  indecl = true, -- may be missing
  manual = true, -- may be missing
  adj = true, -- may be missing
  decllemma = "DECLENSION-LEMMA", -- may be missing
  declgender = "DECLENSION-GENDER", -- may be missing
  declnumber = "DECLENSION-NUMBER", -- may be missing

  -- The following additional fields are added by other functions:
  orig_lemma = "ORIGINAL-LEMMA", -- as given by the user
  orig_lemma_no_links = "ORIGINAL-LEMMA-NO-LINKS", -- links removed
  lemma = "LEMMA", -- `orig_lemma_no_links`, converted to singular form if plural and lowercase if all-uppercase
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
		local dot_separated_groups = iut.split_alternating_runs_and_strip_spaces(segments, "%.")
		for i, dot_separated_group in ipairs(dot_separated_groups) do
			local function parse_err(txt)
				error(("%s: '%s'"):format(txt, require(parse_utilities_module).escape_wikicode(table.concat(
					dot_separated_group))))
			end
			local part = dot_separated_group[1]
			local case_prefix = usub(part, 1, 3)
			local reducible_alternant_pattern = "[-*#~p]+"
			if cases[case_prefix] then
				local slots, override = parse_override(dot_separated_group)
				for _, slot in ipairs(slots) do
					if base.overrides[slot] then
						parse_err(("Two overrides specified for slot '%s'"):format(slot))
					else
						base.overrides[slot] = {override}
					end
				end
			elseif part == "" then
				if #dot_separated_group == 1 then
					parse_err("Blank indicator")
				end
				base.footnotes = fetch_footnotes(dot_separated_group)
			elseif rfind(part, "^" .. reducible_alternant_pattern .. "$") or
				rfind(part, "^" .. reducible_alternant_pattern .. ",") then
				if base.stem_sets then
					parse_err("Can't specify reducible/vowel-alternant indicator twice")
				end
				local comma_separated_groups = iut.split_alternating_runs_and_strip_spaces(dot_separated_group, ",")
				local stem_sets = {}
				for i, comma_separated_group in ipairs(comma_separated_groups) do
					local pattern = comma_separated_group[1]
					local orig_pattern = pattern
					local reducible, quant_alt, umlaut, oblique_slots
					if pattern == "-" then
						-- default reducible, no vowel alt
					else
						local before, after
						before, quant_ant, after = rmatch(pattern, "^(.-)(#)(.-)$")
						if before then
							pattern = before .. after
						end
						before, umlaut, after = rmatch(pattern, "^(.-)(~)(.-)$")
						if before then
							pattern = before .. after
						end
						if pattern == "" then
							-- default reducible
						elseif pattern == "-*" then
							-- non-reducible
							reducible = false
						elseif pattern == "*" then
							-- reducible
							reducible = true
						elseif pattern == "*p" then
							-- reducible with palatalization of first cons
							reducible = "pal"
						elseif pattern == "*-p" then
							-- reducible with depalatalization of first cons
							reducible = "depal"
						else
							parse_err(("Unrecognized reducible pattern '%s', should be one of *, -*, *p or *-p"):format(
								pattern))
						end
					end
					table.insert(stem_sets, {
						reducible = reducible,
						quant_alt = quant_alt,
						umlaut = umlaut,
						footnotes = fetch_footnotes(comma_separated_group)
					})
				end
				base.stem_sets = stem_sets
			elseif #dot_separated_group > 1 then
				parse_err("Footnotes only allowed with slot overrides, reducible or vowel alternation specs or by themselves")
			elseif part == "m" or part == "f" or part == "n" then
				if base.gender then
					parse_err("Can't specify gender twice")
				end
				base.gender = part
			elseif part == "sg" or part == "pl" then
				if base.number then
					parse_err("Can't specify number twice")
				end
				base.number = part
			elseif part == "pr" or part == "anml" or part == "inan" then
				if base.animacy then
					parse_err("Can't specify animacy twice")
				end
				base.animacy = part
			elseif part == "hard" or part == "soft" or part == "mixed" or part == "surname" or part == "istem" or
				part == "-istem" or part == "tstem" or part == "nstem" or part == "tech" or part == "foreign" or
				part == "mostlyindecl" or part == "indecl" or part == "pron" or part == "det" or part == "num" or
				-- Use 'velar' with words like [[petanque]] and [[Braque]] that end with a pronounced velar (and hence are declined
				-- like velars) but not with a spelled velar; use '-velar' with words like [[hadíth]] that end with a spelled but
				-- silent velar.
				part == "collapse_ee" or part == "persname" or part == "c_as_k" or part == "velar" or part == "-velar" then
				if base[part] then
					parse_err("Can't specify '" .. part .. "' twice")
				end
				base[part] = true
				-- Allow 'hard' to signal that -y is allowed after -c, as in hard masculine nouns such as [[hec]]
				-- "joke", and also feminines in -ca where the c is pronounced as /k/, e.g. [[ayahuasca]], [[pororoca]],
				-- [[Petrarca]], [[Mallorca]], [[Casablanca]]. (Contrast [[mangalica]], [[Kusturica]], [[Bjelica]],
				-- where the c is pronounced as /ts/ and -y is disallowed.)
				if part == "hard" then
					base.hard_c = true
				end
			elseif part == "+" then
				if base.adj then
					parse_err("Can't specify '+' twice")
				end
				base.adj = true
			elseif part == "!" then
				if base.manual then
					parse_err("Can't specify '!' twice")
				end
				base.manual = true
			elseif rfind(part, "^decllemma:") then
				if base.decllemma then
					parse_err("Can't specify 'decllemma:' twice")
				end
				base.decllemma = rsub(part, "^decllemma:", "")
			elseif rfind(part, "^declgender:") then
				if base.declgender then
					parse_err("Can't specify 'declgender:' twice")
				end
				base.declgender = rsub(part, "^declgender:", "")
			elseif rfind(part, "^declnumber:") then
				if base.declnumber then
					parse_err("Can't specify 'declnumber:' twice")
				end
				base.declnumber = rsub(part, "^declnumber:", "")
			else
				parse_err("Unrecognized indicator '" .. part .. "'")
			end
		end
	end
	return base
end


local function is_regular_noun(base)
	return not base.adj and not base.pron and not base.det and not base.num
end


local function process_declnumber(base)
	base.actual_number = base.number
	if base.declnumber then
		if base.declnumber == "sg" or base.declnumber == "pl" then
			base.number = base.declnumber
		else
			error(("Unrecognized value '%s' for 'declnumber', should be 'sg' or 'pl'"):format(base.declnumber))
		end
	end
end


local function set_defaults_and_check_bad_indicators(base)
	-- Set default values.
	local regular_noun = is_regular_noun(base)
	if base.pron then
		set_pron_defaults(base)
	elseif base.det then
		set_det_defaults(base)
	elseif base.num then
		set_num_defaults(base)
	elseif not base.adj then
		if not base.gender then
			if base.manual then
				base.gender = "none"
			else
				error("For nouns, gender must be specified")
			end
		end
		base.number = base.number or "both"
		process_declnumber(base)
		base.animacy = base.animacy or "inan"
		base.actual_gender = base.gender
		base.actual_animacy = base.animacy
		if base.declgender then
			if base.declgender == "m-an" then
				base.gender = "m"
				base.animacy = "an"
			elseif base.declgender == "m-in" then
				base.gender = "m"
				base.animacy = "inan"
			elseif base.declgender == "f" or base.declgender == "n" then
				base.gender = base.declgender
			else
				error(("Unrecognized value '%s' for 'declgender', should be 'm-an', 'm-in', 'f' or 'n'"):format(base.declgender))
			end
		end
	end
	-- Check for bad indicator combinations.
	if (base.hard and 1 or 0) + (base.soft and 1 or 0) + (base.mixed and 1 or 0) > 1 then
		error("At most one of 'hard', 'soft' and 'mixed' can be specified")
	end
	if base.istem and base["-istem"] then
		error("'istem' and '-istem' cannot be specified together")
	end
	if (base.istem or base["-istem"]) then
		if base.gender ~= "f" then
			error("'istem' and '-istem' can only be specified with the feminine gender")
		end
		if not regular_noun then
			error("'istem' and '-istem' can only be specified with regular nouns")
		end
	end
	if base.declgender and not regular_noun then
		error("'declgender' can only be specified with regular nouns")
	end
end


local function set_all_defaults_and_check_bad_indicators(alternant_multiword_spec)
	local is_multiword = #alternant_multiword_spec.alternant_or_word_specs > 1
	iut.map_word_specs(alternant_multiword_spec, function(base)
		set_defaults_and_check_bad_indicators(base)
		base.multiword = is_multiword -- FIXME: not currently used; consider deleting
		alternant_multiword_spec.has_clitic = alternant_multiword_spec.has_clitic or base.has_clitic
		if base.pron then
			alternant_multiword_spec.saw_pron = true
		else
			alternant_multiword_spec.saw_non_pron = true
		end
		if base.det then
			alternant_multiword_spec.saw_det = true
		else
			alternant_multiword_spec.saw_non_det = true
		end
		if base.num then
			alternant_multiword_spec.saw_num = true
		else
			alternant_multiword_spec.saw_non_num = true
		end
	end)
end


local function undo_second_palatalization(base, word, is_adjective)
	local function try(from, to)
		local stem = rmatch(word, "^(.*)" .. from .. "$")
		if stem then
			return stem .. to
		end
		return nil
	end
	return is_adjective and try("št", "sk") or
		is_adjective and try("čt", "ck") or
		try("c", "k") or -- FIXME, this could be wrong and c correct
		try("ř", "r") or
		try("z", "h") or -- FIXME, this could be wrong and z or g correct
		try("š", "ch") or
		word
end


-- For a plural-only lemma, synthesize a likely singular lemma. It doesn't have to be
-- theoretically correct as long as it generates all the correct plural forms.
local function synthesize_singular_lemma(base)
	if not base.stem_sets then
		base.stem_sets = {{}}
	end

	local lemma_determined
	-- Loop over all stem sets in case the user specified multiple ones (e.g. '*,-*'). If we try to reconstruct
	-- different lemmas for different stem sets, we'll throw an error below.
	for _, stems in ipairs(base.stem_sets) do
		local stem, lemma
		while true do
			if base.indecl then
				-- If specified as indeclinable, leave it alone; e.g. 'pesos' indeclinable plural of [[peso]].
				lemma = base.lemma
				break
			elseif base.gender == "m" then
				if base.animacy == "an" then
					stem = rmatch(base.lemma, "^(.*)i$")
					if stem then
						if base.soft then
							-- [[Blíženci]] "Gemini"
							-- Since the nominative singular has no ending.
							lemma = com.convert_paired_plain_to_palatal(stem, ending)
						else
							lemma = undo_second_palatalization(base, stem)
						end
					else
						stem = rmatch(base.lemma, "^(.*)ové$") or rmatch(base.lemma, "^(.*)é$")
						if stem then
							-- [[manželé]] "married couple", [[Velšané]] "Welsh people"
							lemma = stem
						else
							error(("Animate masculine plural-only lemma '%s' should end in -i, -ové or -é"):format(base.lemma))
						end
					end
				else
					stem = rmatch(base.lemma, "^(.*)y$")
					if stem then
						-- [[droby]] "giblets"; [[tvarůžky]] "Olomouc cheese"; [[alimenty]] "alimony"; etc.
						lemma = stem
					else
						local ending
						stem, ending = rmatch(base.lemma, "^(.*)([eě])$")
						if stem then
							-- [[peníze]] "money", [[tvargle]] "Olomouc cheese" (mixed declension), [[údaje]] "data",
							-- [[Lazce]] (a village), [[lováče]] "money", [[Krkonoše]] "Giant Mountains", [[kříže]] "clubs"
							lemma = com.convert_paired_plain_to_palatal(stem, ending)
							if not base.mixed then
								base.soft = true
							end
						else
							error(("Inanimate masculine plural-only lemma '%s' should end in -y, -e or -ě"):format(base.lemma))
						end
					end
				end
				if stems.reducible == nil then
					if rfind(lemma, com.cons_c .. "[ck]$") and not com.is_monosyllabic(base.lemma) then
						stems.reducible = true
					end
					if stems.reducible then
						lemma = dereduce(base, lemma)
					end
				end
				break
			elseif base.gender == "f" then
				stem = rmatch(base.lemma, "^(.*)y$")
				if stem then
					lemma = stem .. "a"
					break
				end
				stem = rmatch(base.lemma, "^(.*)[eě]$")
				if stem then
					-- Singular like the plural. Cons-stem feminines like [[dlaň]] "palm (of the hand)" have identical
					-- plurals to soft-stem feminines like [[růže]] (modulo e/ě differences), so we don't need to
					-- reconstruct the former type.
					lemma = base.lemma
					break
				end
				stem = rmatch(base.lemma, "^(.*)i$")
				if stem then
					-- i-stems.
					lemma = stem
					base.istem = true
					break
				end
				error(("Feminine plural-only lemma '%s' should end in -y, -ě, -e or -i"):format(base.lemma))
			elseif base.gender == "n" then
				-- -ata nouns like [[slůně]] "baby elephant" nom pl 'slůňata' are declined in the plural same as if
				-- the singular were 'slůňato' so we don't have to worry about them.
				stem = rmatch(base.lemma, "^(.*)a$")
				if stem then
					lemma = stem .. "o"
					break
				end
				stem = rmatch(base.lemma, "^(.*)[eěí]$")
				if stem then
					-- singular lemma also in -e, -ě or -í; e.g. [[věčná loviště]] "[[happy hunting ground]]"
					lemma = base.lemma
					break
				end
				error(("Neuter plural-only lemma '%s' should end in -a, -í, -ě or -e"):format(base.lemma))
			else
				error(("Internal error: Unrecognized gender '%s'"):format(base.gender))
			end
		end
		if lemma_determined and lemma_determined ~= lemma then
			error(("Attempt to set two different singular lemmas '%s' and '%s'"):format(lemma_determined, lemma))
		end
		lemma_determined = lemma
	end
	base.lemma = lemma_determined
end


-- For an adjectival lemma, synthesize the masc singular form. In the process, autodetect the gender.
local function synthesize_adj_lemma(base)
	local stem
	local gender, animacy

	-- Convert a stem to the lemma form. `stem` is the stem as extracted from the non-lemma form by removing the
	-- ending. `soft_no_i_class` is a Lua pattern character class matching the letters that are "soft" (require -i in
	-- the lemma) but don't have an -i- after them in the stem. Otherwise, if the stem ends in -i, the lemma is assumed
	-- soft (ends in -i), otherwise hard (ends in -y).
	local function convert_to_lemma(stem, soft_no_i_class)
		if stem:find(soft_no_i_class .. "$") then
			-- This will drop the j between vowel and i.
			return com.combine_stem_ending(base, "nom_s", stem, "i")
		elseif stem:find("i$") then
			-- -cia or other soft consonant + -ia
			return stem
		else
			return stem .. "y"
		end
	end

	while true do
		if base.number == "pl" then
			if base.lemma:find("[iy]$") then
				gender = "m"
				animacy = "pr"
				bas
				if base.gender == "m" and base.animacy == "pr" then
					if base.lemma:find("[iy]$") then
						base.lemma = com.unsoften_adj_masc_pers_pl(base, base.lemma)
						break
					else
						error(("Masculine personal plural-only adjectival lemma '%s' should end in -i or -y"):format(
							base.lemma))
					end
		else -- singular
			-- Masculine
			stem = rmatch(base.lemma, "^(.*)[iy]$")
			if stem then
				gender = "m"
				break
			end
			-- Feminine
			stem = rmatch(base.lemma, "^(.*)a$")
			if stem then
				gender == "f"
				base.lemma = convert_to_lemma(stem, "[jlgk]")
				break
			end
			-- Neuter
			stem = rmatch(base.lemma, "^(.*)e$")
			if stem then
				gender == "n"
				base.lemma = convert_to_lemma(stem, "[jl]")
				break
			end
			error("Don't recognize ending of singular adjectival lemma '" .. base.lemma .. "'")
		end

		-- Plural
		stem = rmatch(base.lemma, "^(.*ц)і(́?)$")
		if stem then
			base.lemma = stem .. "и" .. ac .. "й"
			number = "pl"
			break
		end
		stem = rmatch(base.lemma, "^(.*" .. com.vowel .. AC .. "?)ї(́?)$")
		if stem then
			base.lemma = stem .. "ї" .. ac .. "й"
			number = "pl"
			break
		end
		stem = rmatch(base.lemma, "^(.*)і(́?)$")
		if stem then
			if base.soft then
				base.lemma = stem .. "і" .. ac .. "й"
			else
				base.lemma = stem .. "и" .. ac .. "й"
			end
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
	end
	base.decl = "adj"
end


-- For an adjectival lemma, synthesize the masc singular form.
local function synthesize_adj_lemma(base)
	local stem
	if base.indecl then
		base.decl = "indecl"
		stem = base.lemma
	else
		local gender, number
		while true do
			if base.number == "pl" then
				if base.gender == "m" and base.animacy == "pr" then
					if base.lemma:find("[iy]$") then
						base.lemma = com.unsoften_adj_masc_pers_pl(base, base.lemma)
						break
					else
						error(("Masculine personal plural-only adjectival lemma '%s' should end in -i or -y"):format(
							base.lemma))
					end
				else
					stem = rmatch(base.lemma, "^(.*)e$")
					if not stem then
						error(("Non-masculine-personal plural-only adjectival lemma '%s' should end in -e"):format(
							base.lemma))
					end
					if stem:find("[lj]$") then
						-- This will drop the j between vowel and i.
						base.lemma = com.combine_stem_ending(base, "nom_s", stem, "i")
					elseif stem:find("i$") then
						-- -kie, -gie, -cie or other soft consonant + -ie
						base.lemma = stem
					elseif stem:find("en$") then
						-- FIXME: There is no current way of requesting ene -> eny. Only known example of an adjective
						-- in -eny is [[jeny]] (regional variant of [[inny]]). If this ever comes up, we need another
						-- indicator (or possibly `decllemma` will work).
						base.lemma = stem:gsub("en$", "ony$")
					else
						base.lemma = stem .. "y"
					end
					break
				end
			else
				if base.gender == "m" then
					if not base.lemma:find("[yi]$") then
						error(("Masculine adjectival lemma '%s' should end in -y or -i"):format(base.lemma))
					end
				elseif base.gender == "f" then
					stem = rmatch(base.lemma, "^(.*)a$")
					if not stem then
						error(("Feminine adjectival lemma '%s' should end in -a"):format(base.lemma))
					end
					if stem:find("[ljkg]$") then
						-- This will drop the j between vowel and i.
						base.lemma = com.combine_stem_ending(base, "nom_s", stem, "i")
					elseif stem:find("i$") then
						-- -cia or other soft consonant + -ia
						base.lemma = stem
					else
						base.lemma = stem .. "y"
					end
				else
					stem = rmatch(base.lemma, "^(.*)e$")
					if not stem then
						error(("Neuter adjectival lemma '%s' should end in -e"):format(base.lemma))
					end
					if stem:find("[lj]$") then
						-- This will drop the j between vowel and i.
						base.lemma = com.combine_stem_ending(base, "nom_s", stem, "i")
					elseif stem:find("i$") then
						-- -kie, -gie, -cie or other soft consonant + -ie
						base.lemma = stem
					else
						base.lemma = stem .. "y"
					end
				end
			end
		end
		base.decl = "adj"
	end

	-- Now set the stem sets if not given.
	if not base.stem_sets then
		base.stem_sets = {{reducible = false}}
	end
	for _, stems in ipairs(base.stem_sets) do
		-- Set the stems.
		stems.vowel_stem = stem
		stems.nonvowel_stem = stem
	end
end


-- Determine the gender based on the lemma and other settings.
local function determine_gender(base)
	if rmatch(base.lemma, "a$") then
		base.gender = "f"
	elseif rmatch(base.lemma, "[oe]$") then
		base.gender = "n"
	else
		-- FIXME
		...
	end
end


-- Determine the declension based on the lemma, gender and number. The declension is set in base.decl. In the process,
-- we set either base.vowel_stem (if the lemma ends in a vowel) or base.nonvowel_stem (if the lemma does not end in a
-- vowel), which is used by determine_stems(). In some cases (specifically with certain foreign nouns), we set
-- base.lemma to a new value; this is as if the user specified 'decllemma:'.
local function determine_declension(base)
	if base.mostlyindecl then
		base.decl = "mostly-indecl"
		base.nonvowel_stem = base.lemma
		return
	end
	if base.indecl then
		base.decl = "indecl"
		base.nonvowel_stem = base.lemma
		return
	end
	-- Determine declension
	stem = rmatch(base.lemma, "^(.*)a$")
	if stem then
		if base.gender == "m" then
			if base.animacy ~= "an" then
				error("Masculine lemma in -a must be animate")
			end
			base.decl = "a-m"
		elseif base.gender == "f" then
			if base.hard then
				-- e.g. [[doňa]], which seems not to have soft alternates as [[piraňa]] does (despite IJP; but see the note at the
				-- bottom)
				base.decl = "hard-f"
			elseif rfind(stem, "e$") then
				-- [[idea]], [[diarea]] (subtype '.tech'), [[Korea]], etc.
				base.decl = "ea-f"
			elseif rfind(stem, "i$") then
				-- [[signoria]], [[sinfonia]], [[paranoia]], etc.
				base.decl = "ia-f"
			elseif rfind(stem, "[ou]$") then
				-- [[stoa]], [[kongrua]], [[Samoa]], [[Nikaragua]], etc.
				base.decl = "oa-f"
			elseif not base.persname and rfind(stem, "^.*[ňj]$") then
				-- [[maracuja]], [[papája]], [[sója]]; [[piraňa]] etc. Also [[Keňa]], [[Troja]]/[[Trója]], [[Amudarja]].
				-- Not [[Táňa]], [[Darja]], which decline like [[gejša]], [[skica]], etc. (subtype of hard feminines).
				base.decl = "mixed-f"
			else
				base.decl = "hard-f"
			end
		elseif base.gender == "n" then
			if rfind(stem, "m$") then
				base.decl = "ma-n"
			else
				error("Lemma ending in -a and neuter must end in -ma")
			end
		end
		base.vowel_stem = stem
		return
	end
	local ending
	stem, ending = rmatch(base.lemma, "^(.*)([eě])$")
	if stem then
		if ending == "ě" then
			stem = com.convert_paired_plain_to_palatal(stem)
		end
		if base.gender == "m" then
			if base.foreign then
				-- [[software]] and similar English-derived nouns with silent -e; set the lemma here as if decllemma: were given
				base.lemma = stem
				base.nonvowel_stem = stem
				base.decl = "hard-m"
				return
			end
			if base.hard then
				-- -e be damned; e.g. [[Sofokles]] with hard stem 'Sofokle-' (genitive 'Sofoklea', dative 'Sofokleovi', etc.)
				base.nonvowel_stem = base.lemma
				base.decl = "hard-m"
				return
			end
			if base.tstem then
				if base.animacy ~= "an" then
					error("T-stem masculine lemma in -e must be animate")
				end
				base.decl = "tstem-m"
			elseif rfind(stem, "i$") then
				-- [[zombie]], [[hippie]], [[yuppie]], [[rowdie]]
				base.decl = "ie-m"
			elseif rfind(stem, "e$") then
				-- [[Yankee]]
				base.nonvowel_stem = base.lemma
				base.decl = "ee-m"
				return
			else
				base.decl = "e-m"
			end
		elseif base.gender == "f" then
			base.decl = "soft-f"
		else
			if base.tstem then
				base.decl = "tstem-n"
			else
				base.decl = "soft-n"
			end
		end
		base.vowel_stem = stem
		return
	end
	stem = rmatch(base.lemma, "^(.*)o$")
	if stem then
		if base.gender == "m" then
			-- Cf. [[maestro]] m.
			base.decl = "o-m"
		elseif base.gender == "f" then
			-- [[zoo]]; [[Žemaitsko]]?
			error("Feminine nouns in -o are indeclinable; use '.indecl' if needed")
		elseif base.nstem then
			base.decl = "n-n"
		elseif base.hard then
			base.decl = "hard-n"
		elseif rfind(stem, "[aeiuy]$") then
			-- These have gen pl in -í and often other soft plural endings.
			base.decl = "semisoft-n"
		else
			base.decl = "hard-n"
		end
		base.vowel_stem = stem
		return
	end
	stem = rmatch(base.lemma, "^(.*[iy])$")
	if stem then
		if base.gender == "m" then
			if base.soft then
				-- [[gay]] "gay man", [[gray]] "gray (scientific unit)", [[Nagy]] (surname)
				base.decl = "soft-m"
			else
				-- Cf. [[kivi]] "kiwi (bird)", [[husky]] "kusky", etc.
				base.decl = "i-m"
			end
		elseif base.gender == "f" then
			if base.soft then
				-- [[Uruguay]], [[Paraguay]]
				base.decl = "soft-f"
			else
				-- [[máti]], [[pramáti]]; note also indeclinable [[tsunami]]/[[cunami]], [[okapi]]
				base.decl = "i-f"
				if stem:find("i$") then
					stem = stem:gsub("i$", "")
				else
					error("Feminine nouns in -y are either soft or indeclinable; use '.soft' or '.indecl' as needed")
				end
			end
		else
			error("Neuter nouns in -i are indeclinable; use '.indecl' if needed")
		end
		base.vowel_stem = stem
		return
	end
	stem = rmatch(base.lemma, "^(.*u)$")
	if stem then
		if base.gender == "m" then
			-- Cf. [[emu]], [[guru]], etc.
			base.decl = "u-m"
		elseif base.gender == "f" then
			-- Only one I know is [[budižkničemu]], which is indeclinable in the singular and declines in the plural as
			-- if written 'budižkničema'.
			error("Feminine nouns in -u are indeclinable; use '.indecl' if needed")
		else
			error("Neuter nouns in -u are indeclinable; use '.indecl' if needed")
		end
		base.vowel_stem = stem
		return
	end
	stem = rmatch(base.lemma, "^(.*[íý])$")
	if stem then
		if base.gender == "m" then
			base.decl = "í-m"
		elseif base.gender == "f" then
			-- FIXME: Do any exist? If not, update this message.
			error("Support for non-adjectival non-indeclinable feminine nouns in -í/-ý not yet implemented")
		else
			base.decl = "í-n"
		end
		base.vowel_stem = stem
		return
	end
	stem = rmatch(base.lemma, "^(.*" .. com.cons_c .. ")$")
	if stem then
		if base.gender == "m" then
			if base.foreign then
				-- [[komunismus]] "communism", [[kosmos]] "cosmos", [[hádes]] "Hades"
				stem = rmatch(base.lemma, "^(.*)[ueoaéá]s$")
				if not stem then
					error("Unrecognized masculine foreign ending, should be -us, -es, -os, -as, -és or -ás")
				end
				if not base.hard and (rfind(stem, "[ei]$") and base.animacy == "an" or
					rfind(stem, "i$") and base.animacy == "inan") then
					-- [[genius]], [[basileus]], [[rádius]]; not [[nukleus]], [[choreus]] (inanimate); not
					-- [[skarabeus]] (animate), which should specify 'hard'
					base.decl = "semisoft-m"
				else
					base.decl = "hard-m"
				end
				-- set the lemma here as if decllemma: were given
				base.lemma = stem
			elseif base.hard then
				base.decl = "hard-m"
			elseif base.soft then
				base.decl = "soft-m"
			elseif base.mixed then
				base.decl = "mixed-m"
			elseif rfind(base.lemma, com.inherently_soft_c .. "$") or rfind(base.lemma, "tel$") then
				base.decl = "soft-m"
			else
				base.decl = "hard-m"
			end
		elseif base.gender == "f" then
			if base.mixedistem then
				base.decl = "mixed-istem-f"
			elseif base.istem then
				base.decl = "istem-f"
			elseif base["-istem"] then
				base.decl = "cons-f"
			elseif rfind(base.lemma, "st$") then
				-- Numerous abstracts in -ost; also [[kost]], [[část]], [[srst]], [[bolest]]
				base.decl = "istem-f"
			else
				base.decl = "cons-f"
			end
		elseif base.gender == "n" then
			if base.foreign then
				stem = rmatch(base.lemma, "^(.*)um$") or rmatch(base.lemma, "^(.*)on$")
				if not stem then
					error("Unrecognized neuter foreign ending, should be -um or -on")
				end
				if base.hard then
					base.decl = "hard-n"
				elseif rfind(stem, "[eiuy]$") then
					base.decl = "semisoft-n"
				else
					base.decl = "hard-n"
				end
				-- set the lemma here as if decllemma: were given
				base.lemma = stem .. "o"
				base.vowel_stem = stem
				return
			else
				error("Neuter nouns ending in a consonant should use '.foreign' or '.decllemma:...'")
			end
		end
		base.nonvowel_stem = stem
		return
	end
	error("Unrecognized ending for lemma: '" .. base.lemma .. "'")
end


--[=[
Determine the default value for the 'reducible' flag:
1 For nouns in a consonant (masculines and consonant-stem feminines):
* Nouns in -eć seem mostly reducible (~40; but not berbeć/cieć/kmieć/śmiec/rupieć/Budwieć/Międzyświeć).
* Nouns in -el seem mostly reducible but with lots of exceptions; excluding nouns in -ciel gets down to ~40 exceptions.
* Nouns in -eń, lots both ways.
* Nouns in -ec seem mostly reducible; lots of them.
* Nouns in -ek seem mostly reducible; lots of them, with relatively few exceptions.
* Nouns in -e- seem mostly reducible, with some exceptions (all proper names).
* Nouns in -er, lots both ways.
* Feminine nouns in -ew seem mostly reducible.
2. For nouns in -CCa:
2a. second C = soft:
* Nouns in -Cja (C = [csz]; ~2600 terms): reducible because they have archaic gen_pl in -yj.
* Nouns in -Cla: 12 common nouns, all reducible except those in -lla; lots of proper nouns, split between reducible and
  non-reducible.
* Nouns in -Cca: common nouns mostly non-reducible; proper nouns split. But 3 nouns in -sca /ska/ are reducible
2b. second C = hardened soft consonant: Only komża is reducible.
2c. second C = velar: the vast majority are, but ~20 are not.
2d. second C = hard consonant: Too varied to generalize; more appear to not be.
3. For nouns in CCo: Most in -Cko where C is not [cs] are reducible; only [[manko]] and [[Kłodzko]] are not. Most nouns
   in -Cło are also reducible. Otherwise too varied to generalize, or mostly not reducible.
]=]
local function determine_default_reducible(base)
	-- Nouns in vowels other than -a/o as well as masculine nouns ending in all vowels don't have null endings so not
	-- reducible. Note, we are never called on adjectival nouns.
	if rfind(base.lemma, "[iyuíeě]$") or base.gender == "m" and rfind(base.lemma, "[ao]$") or base.tstem then
		base.default_reducible = false
		return
	end

	local stem
	stem = rmatch(base.lemma, "^(.*" .. com.cons_c .. ")$")
	if stem then
		-- When analyzing existing manual declensions in -ec and -ek, 290 were reducible vs. 23 non-reducible. Of these
		-- 23, 15 were monosyllabic (and none of the 290 reducible nouns were monosyllabic) -- and two of these were
		-- actually reducible but irregularly: [[švec]] "shoemaker" (gen sg 'ševce') and [[žnec]] "reaper (person)"
		-- (gen sg. 'žence'). Of the remaining 8 multisyllabic non-reducible words, two were actually reducible but
		-- irregularly: [[stařec]] "old man" (gen sg 'starce') and [[tkadlec]] "weaver" (gen sg 'tkalce'). The remaining
		-- six consisted of 5 compounds of monosyllabic words: [[dotek]], [[oblek]], [[kramflek]], [[pucflek]],
		-- [[pokec]], plus [[česnek]], which should be reducible but would lead to an impossible consonant cluster.
		if base.gender == "m" and rfind(stem, "[eě][ck]$") and not com.is_monosyllabic(stem) then
			base.default_reducible = true
		elseif base.gender == "f" and rfind(stem, "[eě]ň$") then
			-- [[pochodeň]] "torch", [[píseň]] "leather", [[žeň]] "harvest"; not [[reveň]] "rhubarb" or [[dřeň]] "pulp",
			-- which need an override.
			base.default_reducible = true
		else
			base.default_reducible = false
		end
		return
	end
	if base.number == "sg" then
		base.default_reducible = false
		return
	end
	if rfind(base.lemma, "isko$") then
		-- e.g. [[středisko]]
		base.default_reducible = "mixed"
		return
	end
	stem = rmatch(base.lemma, "^(.*)" .. com.vowel_c .. "$")
	if not stem then
		error(("Internal error: Something wrong, lemma '%s' doesn't end in consonant or vowel"):format(base.lemma))
	end
	-- Substitute 'ch' with a single character to make the following code simpler.
	stem = stem:gsub("ch", com.TEMP_CH)
	if rfind(stem, com.cons_c .. "[lr]" .. com.cons_c .. "$") then
		-- [[vrba]], [[vlha]]; not reducible. (But note [[jablko]], reducible; needs override.)
		base.default_reducible = false
	elseif not base.foreign and (rfind(stem, com.cons_c .. "[bkhlrmnv]$") or base.c_as_k and rfind(stem, com.cons_c .. "c$")) then
		-- [[ayahuasca]] has gen pl 'ayahuasek'
		base.default_reducible = true
	elseif base.foreign and rfind(stem, com.cons_c .. "r$") then
		-- Foreign nouns in -CCum seem generally non-reducible in the gen pl except for those in -Crum like [[centrum]],
		-- Examples: [[album]], [[verbum]], [[signum]], [[interregnum]], [[sternum]]. [[infernum]] has gen pl 'infern/inferen'.
		base.default_reducible = true
	else
		base.default_reducible = false
	end
end


-- Determine the stems to use for each stem set: vowel and nonvowel stems, for singular
-- and plural. We assume that one of base.vowel_stem or base.nonvowel_stem has been
-- set in determine_declension(), depending on whether the lemma ends in
-- a vowel. We construct all the rest given the reducibility, vowel alternation spec and
-- any explicit stems given. We store the determined stems inside of the stem-set objects
-- in `base.stem_sets`, meaning that if the user gave multiple reducible or vowel-alternation
-- patterns, we will compute multiple sets of stems. The reason is that the stems may vary
-- depending on the reducibility and vowel alternation.
local function determine_stems(base)
	if not base.stem_sets then
		base.stem_sets = {{}}
	end
	-- Set default reducible and check for default mixed reducible, which needs to be expanded into two entries.
	local default_mixed_reducible = false
	for _, stems in ipairs(base.stem_sets) do
		if stems.reducible == nil then
			stems.reducible = base.default_reducible
		end
		if stems.reducible == "mixed" then
			default_mixed_reducible = true
		end
	end
	if default_mixed_reducible then
		local new_stem_sets = {}
		for _, stems in ipairs(base.stem_sets) do
			if stems.reducible == "mixed" then
				local non_reducible_copy = m_table.shallowcopy(stems)
				non_reducible_copy.reducible = false
				stems.reducible = true
				table.insert(new_stem_sets, stems)
				table.insert(new_stem_sets, non_reducible_copy)
			else
				table.insert(new_stem_sets, stems)
			end
		end
		base.stem_sets = new_stem_sets
	end

	-- Now determine all the stems for each stem set.
	for _, stems in ipairs(base.stem_sets) do
		local lemma_is_vowel_stem = not not base.vowel_stem
		if base.vowel_stem then
			stems.vowel_stem = base.vowel_stem
			stems.nonvowel_stem = stems.vowel_stem
			-- Apply vowel alternation first in cases like jádro -> jader; apply_vowel_alternation() will throw an error
			-- if the vowel being modified isn't the last vowel in the stem.
			stems.oblique_nonvowel_stem = com.apply_vowel_alternation(stems.vowelalt, stems.nonvowel_stem)
			if stems.reducible then
				stems.nonvowel_stem = dereduce(base, stems.nonvowel_stem)
				stems.oblique_nonvowel_stem = dereduce(base, stems.oblique_nonvowel_stem)
			end
		else
			stems.nonvowel_stem = base.nonvowel_stem
			-- The user specified #, #ě, ## or ##ě and we're dealing with a term like masculine [[bůh]] or feminine
			-- [[sůl]] that ends in a consonant. In this case, all slots except the nom_s and maybe acc_s have vowel
			-- alternation.
			if stems.oblique_slots then
				stems.oblique_slots = "all"
			end
			stems.oblique_nonvowel_stem = com.apply_vowel_alternation(stems.vowelalt, stems.nonvowel_stem)
			if stems.reducible then
				stems.vowel_stem = com.reduce(base.nonvowel_stem)
				if not stems.vowel_stem then
					error("Unable to reduce stem '" .. base.nonvowel_stem .. "'")
				end
			else
				stems.vowel_stem = base.nonvowel_stem
			end
		end
		stems.oblique_vowel_stem = com.apply_vowel_alternation(stems.vowelalt, stems.vowel_stem)
	end
end


local function detect_indicator_spec(base)
	if base.pron then
		determine_pronoun_stems(base)
	elseif base.det then
		determine_determiner_stems(base)
	elseif base.num then
		determine_numeral_stems(base)
	elseif base.adj then
		process_declnumber(base)
		synthesize_adj_lemma(base)
	elseif base.manual then
		if base.stem_sets then
			-- FIXME, maybe this should be allowed?
			error("Reducible and vowel alternation specs cannot be given with manual declensions")
		end
		base.stem_sets = {{reducible = false, vowel_stem = "", nonvowel_stem = ""}}
		base.decl = "manual"
	else
		if base.number == "pl" then
			synthesize_singular_lemma(base)
		end
		if not base.gender then
			determine_gender(base)
		end
		determine_declension(base)
		determine_default_reducible(base)
		determine_stems(base)
	end
end


local function detect_all_indicator_specs(alternant_multiword_spec)
	-- Keep track of all genders seen in the singular and plural so we can determine whether to add the term to
	-- [[:Category:Polish nouns that change gender in the plural]].
	alternant_multiword_spec.sg_genders = {}
	alternant_multiword_spec.pl_genders = {}
	iut.map_word_specs(alternant_multiword_spec, function(base)
		detect_indicator_spec(base)
		if base.number ~= "pl" then
			alternant_multiword_spec.sg_genders[base.actual_gender] = true
		end
		if base.number ~= "sg" then
			-- All t-stem masculines are neuter in the plural.
			local plgender
			if base.decl == "tstem-m" then
				plgender = "n"
			else
				plgender = base.actual_gender
			end
			alternant_multiword_spec.pl_genders[plgender] = true
		end
	end)
	if (alternant_multiword_spec.saw_pron and 1 or 0) + (alternant_multiword_spec.saw_det and 1 or 0) + (alternant_multiword_spec.saw_num and 1 or 0) > 1 then
		error("Can't combine pronouns, determiners and/or numerals")
	end
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
			is_nounal = is_regular_noun(word_specs[i])
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
	local function set_and_fetch(obj, default)
		local retval
		if obj[property] then
			retval = obj[property]
		else
			obj[property] = default
			retval = default
		end
		if not obj["actual_" .. property] then
			obj["actual_" .. property] = retval
		end
		return retval
	end
	local propval1 = set_and_fetch(alternant_multiword_spec, default_propval)
	for _, alternant_or_word_spec in ipairs(alternant_multiword_spec.alternant_or_word_specs) do
		local propval2 = set_and_fetch(alternant_or_word_spec, propval1)
		if alternant_or_word_spec.alternants then
			for _, multiword_spec in ipairs(alternant_or_word_spec.alternants) do
				local propval3 = set_and_fetch(multiword_spec, propval2)
				for _, word_spec in ipairs(multiword_spec.word_specs) do
					local propval4 = set_and_fetch(word_spec, propval3)
					if propval4 == "mixed" then
						-- FIXME, use clearer error message.
						error("Attempt to assign mixed " .. property .. " to word")
					end
					set_and_fetch(word_spec, propval4)
				end
			end
		else
			if propval2 == "mixed" then
				-- FIXME, use clearer error message.
				error("Attempt to assign mixed " .. property .. " to word")
			end
			set_and_fetch(alternant_or_word_spec, propval2)
		end
	end
end


--[=[
Propagate `property` (one of "animacy", "gender" or "number") from nouns to adjacent
adjectives. We proceed as follows:
1. We assume the properties in question are already set on all nouns. This should happen in
   set_defaults_and_check_bad_indicators().
2. We first propagate properties upwards and sideways. We recurse downwards from the top. When we encounter a multiword
   spec, we proceed left to right looking for a noun. When we find a noun, we fetch its property (recursing if the noun
   is an alternant), and propagate it to any adjectives to its left, up to the next noun to the left. When we have
   processed the last noun, we also propagate its property value to any adjectives to the right (to handle e.g.
   [[anděl strážný]] "guardian angel", where the adjective [[strážný]] should inherit the 'masculine' and 'animate'
   properties of [[anděl]]). Finally, we set the property value for the multiword spec itself by combining all the
   non-nil properties of the individual elements. If all non-nil properties have the same value, the result is that
   value, otherwise it is `mixed_value` (which is "mixed" for animacy and gender, but "both" for number).
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


local function determine_noun_status(alternant_multiword_spec)
	for i, alternant_or_word_spec in ipairs(alternant_multiword_spec.alternant_or_word_specs) do
		if alternant_or_word_spec.alternants then
			local is_noun = false
			for _, multiword_spec in ipairs(alternant_or_word_spec.alternants) do
				for j, word_spec in ipairs(multiword_spec.word_specs) do
					if is_regular_noun(word_spec) then
						multiword_spec.first_noun = j
						is_noun = true
						break
					end
				end
			end
			if is_noun then
				alternant_multiword_spec.first_noun = i
			end
		elseif is_regular_noun(alternant_or_word_spec) then
			alternant_multiword_spec.first_noun = i
			return
		end
	end
end


-- Set the part of speech based on properties of the individual words.
local function set_pos(alternant_multiword_spec)
	if alternant_multiword_spec.args.pos then
		alternant_multiword_spec.pos = alternant_multiword_spec.args.pos
	elseif alternant_multiword_spec.saw_pron and not alternant_multiword_spec.saw_non_pron then
		alternant_multiword_spec.pos = "pronoun"
	elseif alternant_multiword_spec.saw_det and not alternant_multiword_spec.saw_non_det then
		alternant_multiword_spec.pos = "determiner"
	elseif alternant_multiword_spec.saw_num and not alternant_multiword_spec.saw_non_num then
		alternant_multiword_spec.pos = "numeral"
	else
		alternant_multiword_spec.pos = "noun"
	end
	alternant_multiword_spec.plpos = require("Module:string utilities").pluralize(alternant_multiword_spec.pos)
end


local function normalize_all_lemmas(alternant_multiword_spec, pagename)
	iut.map_word_specs(alternant_multiword_spec, function(base)
		if base.lemma == "" then
			base.lemma = pagename
		end
		base.orig_lemma = base.lemma
		base.orig_lemma_no_links = m_links.remove_links(base.lemma)
		local lemma = base.orig_lemma_no_links
		-- If the lemma is all-uppercase, lowercase it but note this, so that later in combine_stem_ending() we convert it
		-- back to uppercase. This allows us to handle all-uppercase acronyms without a lot of extra complexity.
		-- FIXME: This may not make sense at all.
		if uupper(lemma) == lemma then
			base.all_uppercase = true
			lemma = ulower(lemma)
		end
		base.actual_lemma = lemma
		base.lemma = base.decllemma or lemma
	end)
end


local function decline_noun(base)
	for _, stems in ipairs(base.stem_sets) do
		if not decls[base.decl] then
			error("Internal error: Unrecognized declension type '" .. base.decl .. "'")
		end
		decls[base.decl](base, stems)
	end
	handle_derived_slots_and_overrides(base)
	local function copy(from_slot, to_slot)
		base.forms[to_slot] = base.forms[from_slot]
	end
	if base.actual_number ~= base.number then
		local source_num = base.number == "sg" and "_s" or "_p"
		local dest_num = base.number == "sg" and "_p" or "_s"
		for case, _ in pairs(cases) do
			copy(case .. source_num, case .. dest_num)
			copy("nom" .. source_num .. "_linked", "nom" .. dest_num .. "_linked")
		end
		if base.actual_number ~= "both" then
			local erase_num = base.actual_number == "sg" and "_p" or "_s"
			for case, _ in pairs(cases) do
				base.forms[case .. erase_num] = nil
			end
			base.forms["nom" .. erase_num .. "_linked"] = nil
		end
	end
end


local function get_variants(form)
	return nil
	--[=[
	FIXME
	return
		form:find(com.VAR1) and "var1" or
		form:find(com.VAR2) and "var2" or
		form:find(com.VAR3) and "var3" or
		nil
	]=]
end


-- Compute the categories to add the noun to, as well as the annotation to display in the
-- declension title bar. We combine the code to do these functions as both categories and
-- title bar contain similar information.
local function compute_categories_and_annotation(alternant_multiword_spec)
	local all_cats = {}
	local function insert(cattype)
		m_table.insertIfNot(all_cats, "Polish " .. cattype)
	end
	if alternant_multiword_spec.pos == "noun" then
		if alternant_multiword_spec.actual_number == "sg" then
			insert("uncountable nouns")
		elseif alternant_multiword_spec.actual_number == "pl" then
			insert("pluralia tantum")
		end
	end
	local annotation
	local annparts = {}
	local decldescs = {}
	local vowelalts = {}
	local foreign = {}
	local irregs = {}
	local stemspecs = {}
	local reducible = nil
	local function get_genanim(gender, animacy)
		local gender_code_to_desc = {
			m = "masculine",
			f = "feminine",
			n = "neuter",
			none = nil,
		}
		local animacy_code_to_desc = {
			an = "animate",
			inan = "inanimate",
			none = nil,
		}
		local descs = {}
		table.insert(descs, gender_code_to_desc[gender])
		if gender ~= "f" and gender ~= "n" then
			-- masculine or "none" (e.g. certain pronouns and numerals)
			table.insert(descs, animacy_code_to_desc[animacy])
		end
		return table.concat(descs, " ")
	end

	local function trim(text)
		text = text:gsub(" +", " ")
		return mw.text.trim(text)
	end

	local function do_word_spec(base)
		local actual_genanim = get_genanim(base.actual_gender, base.actual_animacy)
		local declined_genanim = get_genanim(base.gender, base.animacy)
		local genanim
		if actual_genanim ~= declined_genanim then
			genanim = ("%s (declined as %s)"):format(actual_genanim, declined_genanim)
			insert("nouns with actual gender different from declined gender")
		else
			genanim = actual_genanim
		end
		if base.actual_gender == "m" then
			-- Insert a category for 'Polish masculine animate nouns' or 'Polish masculine inanimate nouns'; the base categories
			-- [[:Category:Polish masculine nouns]], [[:Polish animate nouns]] are auto-inserted.
			insert(actual_genanim .. " " .. alternant_multiword_spec.plpos)
		end
		for _, stems in ipairs(base.stem_sets) do
			local props = declprops[base.decl]
			local cats = props.cat
			if type(cats) == "function" then
				cats = cats(base, stems)
			end
			if type(cats) == "string" then
				cats = {cats}
			end
			local default_desc
			for i, cat in ipairs(cats) do
				if not cat:find("GENDER") and not cat:find("GENPOS") and not cat:find("POS") then
					cat = cat .. " GENPOS"
				end
				cat = cat:gsub("GENPOS", "GENDER POS")
				if not cat:find("POS") then
					cat = cat .. " POS"
				end
				if i == #cats then
					default_desc = cat:gsub(" POS", "")
				end
				cat = cat:gsub("GENDER", actual_genanim)
				cat = cat:gsub("POS", alternant_multiword_spec.plpos)
				-- Need to trim `cat` because actual_genanim may be an empty string.
				insert(trim(cat))
			end

			local desc = props.desc
			if type(desc) == "function" then
				desc = desc(base, stems)
			end
			desc = desc or default_desc
			desc = desc:gsub("GENDER", genanim)
			-- Need to trim `desc` because genanim may be an empty string.
			m_table.insertIfNot(decldescs, trim(desc))

			local vowelalt
			if stems.vowelalt == "quant" then
				vowelalt = "quant-alt"
				insert("nouns with quantitative vowel alternation")
			elseif stems.vowelalt == "quant-ě" then
				vowelalt = "í-ě-alt"
				insert("nouns with í-ě alternation")
			end
			if vowelalt then
				m_table.insertIfNot(vowelalts, vowelalt)
			end
			if reducible == nil then
				reducible = stems.reducible
			elseif reducible ~= stems.reducible then
				reducible = "mixed"
			end
			if stems.reducible then
				insert("nouns with reducible stem")
			end
			if base.foreign then
				m_table.insertIfNot(foreign, "foreign")
				if not base.decllemma then
					-- NOTE: there are nouns that use both 'foreign' and 'decllemma', e.g. [[Zeus]].
					insert("nouns with regular foreign declension")
				end
			end
			-- User-specified 'decllemma:' indicates irregular stem. Don't consider foreign nouns in -us/-os/-es, -um/-on or
			-- silent -e (e.g. [[software]]) where this ending is simply dropped in oblique and plural forms as irregular;
			-- there are too many of these and they are already categorized above as 'nouns with regular foreign declension'.
			if base.decllemma then
				m_table.insertIfNot(irregs, "irreg-stem")
				insert("nouns with irregular stem")
			end
			m_table.insertIfNot(stemspecs, stems.vowel_stem)
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
	if alternant_multiword_spec.actual_number == "sg" or alternant_multiword_spec.actual_number == "pl" then
		-- not "both" or "none" (for [[sebe]])
		table.insert(annparts, alternant_multiword_spec.actual_number == "sg" and "sg-only" or "pl-only")
	end
	if #decldescs == 0 then
		table.insert(annparts, "indecl")
	else
		table.insert(annparts, table.concat(decldescs, " // "))
	end
	if #vowelalts > 0 then
		table.insert(annparts, table.concat(vowelalts, "/"))
	end
	if reducible == "mixed" then
		table.insert(annparts, "mixed-reducible")
	elseif reducible then
		table.insert(annparts, "reducible")
	end
	if #foreign > 0 then
		table.insert(annparts, table.concat(foreign, " // "))
	end
	if #irregs > 0 then
		table.insert(annparts, table.concat(irregs, " // "))
	end
	alternant_multiword_spec.annotation = table.concat(annparts, " ")
	if #stemspecs > 1 then
		insert("nouns with multiple stems")
	end
	if alternant_multiword_spec.actual_number == "both" and not m_table.deepEquals(alternant_multiword_spec.sg_genders, alternant_multiword_spec.pl_genders) then
		insert("nouns that change gender in the plural")
	end
	alternant_multiword_spec.categories = all_cats
end


local function show_forms(alternant_multiword_spec)
	local lemmas = {}
	for _, slot in ipairs(potential_lemma_slots) do
		if alternant_multiword_spec.forms[slot] then
			for _, formobj in ipairs(alternant_multiword_spec.forms[slot]) do
				-- FIXME, now can support footnotes as qualifiers in headwords?
				table.insert(lemmas, formobj.form)
			end
			break
		end
	end
	local props = {
		lemmas = lemmas,
		slot_table = alternant_multiword_spec.output_noun_slots,
		lang = lang,
		canonicalize = function(form)
			-- return com.remove_variant_codes(form)
			return form
		end,
	}
	iut.show_forms(alternant_multiword_spec.forms, props)
end


local function make_table(alternant_multiword_spec)
	local forms = alternant_multiword_spec.forms

	local function template_prelude(min_width)
		return rsub([=[
<div>
<div class="NavFrame" style="display: inline-block; min-width: MINWIDTHem">
<div class="NavHead" style="background:#eff7ff">{title}{annotation}</div>
<div class="NavContent">
{\op}| style="background:#F9F9F9;text-align:center;min-width:MINWIDTHem" class="inflection-table"
|-
]=], "MINWIDTH", min_width)
	end

	local function template_postlude()
		return [=[
|{\cl}{notes_clause}</div></div></div>]=]
	end

	local table_spec_both = template_prelude("45") .. [=[
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
]=] .. template_postlude()

	local function get_table_spec_one_number(number, numcode)
		local table_spec_one_number = [=[
! style="width:33%;background:#d9ebff" |
! style="background:#d9ebff" | NUMBER
|-
!style="background:#eff7ff"|nominative
| {nom_CODE}
|-
!style="background:#eff7ff"|genitive
| {gen_CODE}
|-
!style="background:#eff7ff"|dative
| {dat_CODE}
|-
!style="background:#eff7ff"|accusative
| {acc_CODE}
|-
!style="background:#eff7ff"|instrumental
| {ins_CODE}
|-
!style="background:#eff7ff"|locative
| {loc_CODE}
|-
!style="background:#eff7ff"|vocative
| {voc_CODE}
]=]
		return template_prelude("30") .. table_spec_one_number:gsub("NUMBER", number):gsub("CODE", numcode) ..
			template_postlude()
	end

	local function get_table_spec_one_number_clitic(number, numcode)
		local table_spec_one_number_clitic = [=[
! rowspan=2 style="width:33%;background:#d9ebff"|
! colspan=2 style="background:#d9ebff" | NUMBER
|-
! style="width:33%;background:#d9ebff" | stressed
! style="background:#d9ebff" | clitic
|-
!style="background:#eff7ff"|nominative
| colspan=2 | {nom_CODE}
|-
!style="background:#eff7ff"|genitive
| {gen_CODE}
| {clitic_gen_CODE}
|-
!style="background:#eff7ff"|dative
| {dat_CODE}
| {clitic_dat_CODE}
|-
!style="background:#eff7ff"|accusative
| {acc_CODE}
| {clitic_acc_CODE}
|-
!style="background:#eff7ff"|instrumental
| colspan=2 | {ins_CODE}
|-
!style="background:#eff7ff"|locative
| colspan=2 | {loc_CODE}
|-
!style="background:#eff7ff"|vocative
| colspan=2 | {voc_CODE}
]=]
		return template_prelude("40") .. table_spec_one_number_clitic:gsub("NUMBER", number):gsub("CODE", numcode) ..
			template_postlude()
	end

	local notes_template = [=[
<div style="width:100%;text-align:left;background:#d9ebff">
<div style="display:inline-block;text-align:left;padding-left:1em;padding-right:1em">
{footnote}
</div></div>
]=]

	if alternant_multiword_spec.title then
		forms.title = alternant_multiword_spec.title
	else
		forms.title = 'Declension of <i lang="pl">' .. forms.lemma .. '</i>'
	end

	local annotation = alternant_multiword_spec.annotation
	if annotation == "" then
		forms.annotation = ""
	else
		forms.annotation = " (<span style=\"font-size: smaller;\">" .. annotation .. "</span>)"
	end

	local number, numcode
	if alternant_multiword_spec.actual_number == "sg" then
		number, numcode = "singular", "s"
	elseif alternant_multiword_spec.actual_number == "pl" then
		number, numcode = "plural", "p"
	elseif alternant_multiword_spec.actual_number == "none" then -- used for [[sebe]]
		number, numcode = "", "s"
	end

	local table_spec =
		alternant_multiword_spec.actual_number == "both" and table_spec_both or
		alternant_multiword_spec.has_clitic and get_table_spec_one_number_clitic(number, numcode) or
		get_table_spec_one_number(number, numcode)
	forms.notes_clause = forms.footnote ~= "" and
		m_string_utilities.format(notes_template, forms) or ""
	return m_string_utilities.format(table_spec, forms)
end


local function compute_headword_genders(alternant_multiword_spec)
	local genders = {}
	local number
	if alternant_multiword_spec.actual_number == "pl" then
		number = "-p"
	else
		number = ""
	end
	iut.map_word_specs(alternant_multiword_spec, function(base)
		local animacy = base.animacy
		if animacy == "inan" then
			animacy = "in"
		end
		m_table.insertIfNot(genders, base.gender .. "-" .. animacy .. number)
	end)
	return genders
end


-- Externally callable function to parse and decline a noun given user-specified arguments.
-- Return value is ALTERNANT_MULTIWORD_SPEC, an object where the declined forms are in
-- `ALTERNANT_MULTIWORD_SPEC.forms` for each slot. If there are no values for a slot, the
-- slot key will be missing. The value for a given slot is a list of objects
-- {form=FORM, footnotes=FOOTNOTES}.
function export.do_generate_forms(parent_args, from_headword)
	local params = {
		[1] = {required = true, default = "bůh<m.an.#.voce>"},
		title = {},
		pagename = {},
		json = {type = "boolean"},
		pos = {},
	}

	if from_headword then
		params["head"] = {list = true}
		params["lemma"] = {list = true}
		params["g"] = {list = true}
		params["f"] = {list = true}
		params["m"] = {list = true}
		params["adj"] = {list = true}
		params["dim"] = {list = true}
		params["id"] = {}
	end

	local args = m_para.process(parent_args, params)
	local parse_props = {
		parse_indicator_spec = parse_indicator_spec,
		angle_brackets_omittable = true,
		allow_blank_lemma = true,
	}
	local alternant_multiword_spec = iut.parse_inflected_text(args[1], parse_props)
	alternant_multiword_spec.title = args.title
	alternant_multiword_spec.args = args
	local pagename = args.pagename or from_headword and args.head[1] or mw.title.getCurrentTitle().subpageText
	normalize_all_lemmas(alternant_multiword_spec, pagename)
	set_all_defaults_and_check_bad_indicators(alternant_multiword_spec)
	-- These need to happen before detect_all_indicator_specs() so that adjectives get their genders and numbers set
	-- appropriately, which are needed to correctly synthesize the adjective lemma.
	propagate_properties(alternant_multiword_spec, "animacy", "inan", "mixed")
	propagate_properties(alternant_multiword_spec, "number", "both", "both")
	-- FIXME, the default value (third param) used to be 'm' with a comment indicating that this applied only to
	-- plural adjectives, where it didn't matter; but in Polish, plural adjectives are distinguished for gender and
	-- animacy. Make sure 'mixed' works.
	propagate_properties(alternant_multiword_spec, "gender", "mixed", "mixed")
	detect_all_indicator_specs(alternant_multiword_spec)
	-- Propagate 'actual_number' after calling detect_all_indicator_specs(), which sets 'actual_number' for adjectives.
	propagate_properties(alternant_multiword_spec, "actual_number", "both", "both")
	determine_noun_status(alternant_multiword_spec)
	set_pos(alternant_multiword_spec)
	alternant_multiword_spec.output_noun_slots = get_output_noun_slots(alternant_multiword_spec)
	local inflect_props = {
		skip_slot = function(slot)
			return skip_slot(alternant_multiword_spec.actual_number, slot)
		end,
		slot_table = alternant_multiword_spec.output_noun_slots,
		get_variants = get_variants,
		inflect_word_spec = decline_noun,
	}
	iut.inflect_multiword_or_alternant_multiword_spec(alternant_multiword_spec, inflect_props)
	compute_categories_and_annotation(alternant_multiword_spec)
	alternant_multiword_spec.genders = compute_headword_genders(alternant_multiword_spec)
	if args.json then
		alternant_multiword_spec.args = nil
		return require("Module:JSON").toJSON(alternant_multiword_spec)
	end
	return alternant_multiword_spec
end


-- Entry point for {{pl-ndecl}}. Template-callable function to parse and decline a noun given
-- user-specified arguments and generate a displayable table of the declined forms.
function export.show(frame)
	local parent_args = frame:getParent().args
	local alternant_multiword_spec = export.do_generate_forms(parent_args)
	if type(alternant_multiword_spec) == "string" then
		-- JSON return value
		return alternant_multiword_spec
	end
	show_forms(alternant_multiword_spec)
	return make_table(alternant_multiword_spec) ..
		require("Module:utilities").format_categories(alternant_multiword_spec.categories, lang, nil, nil, force_cat)
end


return export
