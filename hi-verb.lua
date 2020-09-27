local export = {}


--[=[

Authorship: Ben Wing <benwing2>

]=]

--[=[

TERMINOLOGY:

-- "slot" = A particular combination of person/number/gender/tense/etc.
	 Example slot names for verbs are "inf_mp" (masculine plural infinitive),
	 "prog" (undeclined progressive form), "pfv_ind_fut_2sm" (second-person singular
	 masculine perfective indicative future). Each slot is filled with zero or
	 more forms.

-- "form" = The conjugated Hindi form representing the value of a given slot.

-- "lemma" = The dictionary form of a given Hindi term. Generally the direct
     masculine singular infinitive, but may occasionally be another form if
	 that form is missing.
]=]

--[=[

FIXME:

1. (DONE) If rearrangement for syncretism stays, need to change accelerators.
2. (DONE) In add_slot_gendered(), for participles, potentially put back obl|m|s for -e form accelerators.
3. (DONE) Split adjectival participle into perfective and habitual.
4. (DONE) Some errors in future intimate imperatives of पीना, देना, लेना.
5. Stop generating 3s and 3p forms (same as 2s and 1p forms, respectively) except for imperatives;
    rename 3s -> 23s and 1p -> 13p.
6. (DONE) Add alternative (regular) perfective participle of जाना; footnote that
   it only works with auxiliary जाना and occasionally करना in the habitual.
7. (DONE) Fix forms listed in imperative footnote for verbs like सीना, छूना.
8. (DONE) Remove fut2 forms (= to presumptive) from होना.
9. (DONE) Contrafactual -> PST only.
10. (DONE) In verbs like हिलना-डुलना, suffixes -गा and -वाला should occur only once.
11. (DONE) Indicative future of छूना should be छुऊँगा (maybe along with छूँगा?).
12. Merge cases where Devanagari spelling occurs twice with different translits.
13. (DONE) Add "rare" footnote for हूजिए.
14. (DONE) Add future tense to presumptive forms for non-aspectual and progressive.
15. (DONE) Remove first -गा in 3p fut imp of हिलना-डुलना.
16. (DONE) What is the progressive of हिलना-डुलना? Currently I have हिलते-हिलते-दुलते-दुलते.
    (It's just हिलते-डलते; fixed.)
17. (DONE) Do verbs like खाना have alternative perfective participles खाये, खायी, खायीं?
    (Yes, made the default with a y-footnote.)
18. (DONE) Should 2pl pres imperative in -o be -yo after -i? If so, is -o an alternative form?
    (Yes and yes, but the -y- is normally pronounced, so alternative form not listed.)
19. (DONE) Should we change the label of non-होना non-aspectual subjunctives to FUT only not PRES/FUT?
    (Yes. Done.)

FIXES NEEDING DISCUSSING:

2. Should we remove subjunctive forms of imperatives and convert them to a footnote?
6. Are forms like पिइयो (पीना) and जिइयो (जीना) are correct, and should forms
   like पियो and जियो be used instead or as alternatives?
7. Should we have distinct colors for masc/fem/combined rows or should they be a single color?
]=]

local lang = require("Module:languages").getByCode("hi")
local m_table = require("Module:table")
local m_links = require("Module:links")
local m_string_utilities = require("Module:string utilities")
local m_script_utilities = require("Module:script utilities")
local iut = require("Module:inflection utilities")
local m_para = require("Module:parameters")
local com = require("Module:hi-common")

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
local AA = u(0x093e)
local AI = u(0x0948)
local AU = u(0x094c)
local E = u(0x0947)
local EN = E .. N
local I = u(0x093f)
local II = u(0x0940)
local IIN = II .. N
local O = u(0x094b)
local U = u(0x0941)
local UU = u(0x0942)
local UUM = UU .. M
local R = u(0x0943)
local VIRAMA = u(0x094d)
local TILDE = u(0x0303)

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


local function term_link(hi, tr)
    return m_links.full_link({term = hi, tr = tr, lang = lang}, "term")
end


local irreg_perf = {
	["कर"] = "की",
	["जा"] = "ग*", --  this is a special sign to request independent endings in some cases
	["ले"] = "ली",
	["दे"] = "दी",
	["हो"] = "हु",
}

local irreg_subj = {
	["दे"] = "द",
	["ले"] = "ल",
}

local irreg_polite_imp = {
	["कर"] = {"कीज", "कर"},
	["ले"] = "लीज",
	["दे"] = "दीज",
	["पी"] = "पीज",
	["हो"] = {"हो", {form = "हूज", footnotes = {"[rare]"}}},
}

local verb_slots_impers = {
	inf = "inf",
	inf_obl = "obl|inf",
	stem = "stem",
	conj = "conj|form",
	prog = "prog|form",
}

local verb_slots_pers = {
}

-- Add entries for a slot with only gender/number variants.
-- `slot_prefix` is the prefix of the slot, typically specifying the tense/aspect;
-- `tag_suffix` is the set of inflection tags to add after the gender/number tags,
-- or "-" to use "-" as the inflection tags (which indicates that no accelerator entry
-- should be generated); and `verb_slots` is the table (personal or impersonal) to
-- add the entries to.
local function add_slot_gendered(slot_prefix, tag_suffix, verb_slots)
	verb_slots = verb_slots or verb_slots_pers
	verb_slots[slot_prefix .. "_ms"] = tag_suffix == "-" and "-" or "m|s|" .. tag_suffix
	verb_slots[slot_prefix .. "_mp"] = tag_suffix == "-" and "-" or "m|p|" .. tag_suffix
	verb_slots[slot_prefix .. "_fs"] = tag_suffix == "-" and "-" or "f|s|" .. tag_suffix
	verb_slots[slot_prefix .. "_fp"] = tag_suffix == "-" and "-" or "f|p|" .. tag_suffix
end

-- Same as add_slot_gendered() but specifically for participles. This changes the inflection
-- tags used, because the masculine singular entry is really only for direct masculine singular,
-- and the masculine plural entry is also for oblique masculine singular.
local function add_slot_gendered_part(slot_prefix, tag_suffix, verb_slots)
	verb_slots = verb_slots or verb_slots_pers
	verb_slots[slot_prefix .. "_ms"] = tag_suffix == "-" and "-" or "dir|m|s|" .. tag_suffix
	verb_slots[slot_prefix .. "_mp"] = tag_suffix == "-" and "-" or "m|p|" .. tag_suffix .. "|;|obl|m|s|" .. tag_suffix
	verb_slots[slot_prefix .. "_fs"] = tag_suffix == "-" and "-" or "f|s|" .. tag_suffix
	verb_slots[slot_prefix .. "_fp"] = tag_suffix == "-" and "-" or "f|p|" .. tag_suffix
end

-- Compute the inflection tags associated with a given person/number/gender combination.
local function personal_tags(slot_prefix, tag_suffix, persnum, gender)
	gender = gender and gender .. "|" or ""
	local suffix = gender .. tag_suffix
	if persnum == "2s" then -- only for imperatives
		return "2|s|intim|" .. suffix
	elseif persnum == "23s" then
		return "2|s|intim|" .. suffix .. "|;|3|s|" .. suffix
	elseif persnum == "13p" then
		return "13|p|" .. suffix .. "|;|2|formal|" .. suffix
	elseif persnum == "2p" then
		return "2|fam|" .. suffix
	elseif persnum == "3p" then -- only for imperatives
		return "3|p|" .. suffix .. "|;|2|formal|" .. suffix
	else
		-- 1s, 3s or 1p
		return persnum:gsub("^(.)(.)$", "%1|%2") .. "|" .. suffix
	end
end

-- Return the possible person/number combinations given the slot prefix.
local function persnum_values(slot_prefix)
	if slot_prefix:find("^imp_") then
		return {"2s", "3s", "2p", "3p"}
	else
		return {"1s", "23s", "13p", "2p"}
	end
end

-- Add entries for a slot with only person/number variants. See `add_slot_gendered()`.
local function add_slot_personal(slot_prefix, tag_suffix, verb_slots)
	verb_slots = verb_slots or verb_slots_pers
	for _, persnum in ipairs(persnum_values(slot_prefix)) do
		local slot = slot_prefix .. "_" .. persnum
		if tag_suffix == "-" then
			verb_slots[slot] = "-"
		else
			verb_slots[slot] = personal_tags(slot_prefix, tag_suffix, persnum)
		end
	end
end

-- Add entries for a slot with person/number/gender variants. See `add_slot_gendered()`.
local function add_slot_gendered_personal(slot_prefix, tag_suffix, verb_slots)
	verb_slots = verb_slots or verb_slots_pers
	for _, persnum in ipairs(persnum_values(slot_prefix)) do
		for _, gender in ipairs({"m", "f"}) do
			local slot = slot_prefix .. "_" .. persnum .. gender
			if tag_suffix == "-" then
				verb_slots[slot] = "-"
			else
				verb_slots[slot] = personal_tags(slot_prefix, tag_suffix, persnum, gender)
			end
		end
	end
end

add_slot_gendered_part("inf", "inf|part", verb_slots_impers)
add_slot_gendered_part("hab", "hab|part", verb_slots_impers)
add_slot_gendered_part("pfv", "pfv|part", verb_slots_impers)
add_slot_gendered_part("agent", "prospective//agentive|part", verb_slots_impers)
add_slot_gendered_part("adj_pfv", "-", verb_slots_impers)
add_slot_gendered_part("adj_hab", "-", verb_slots_impers)

add_slot_personal("ind_pres", "pres|ind") -- only for होना
add_slot_gendered("ind_impf", "impf|ind") -- only for होना
add_slot_gendered("ind_perf", "perf|ind")
add_slot_gendered_personal("ind_fut", "fut|ind")
add_slot_gendered_personal("presum", "presumptive")
add_slot_personal("subj_pres", "pres|subj") -- only for होना
add_slot_personal("subj_fut", "fut|subj")
add_slot_gendered("cfact", "cfact")
add_slot_personal("imp_pres", "pres|imp")
add_slot_personal("imp_fut", "fut|imp")

add_slot_gendered_personal("hab_ind_pres", "-")
add_slot_gendered("hab_ind_past", "-")
add_slot_gendered_personal("hab_presum", "-")
add_slot_gendered_personal("hab_subj", "-")
add_slot_gendered("hab_cfact", "-")

for _, mood in ipairs({"pfv", "prog"}) do
	add_slot_gendered_personal(mood .. "_ind_pres", "-")
	add_slot_gendered(mood .. "_ind_past", "-")
	add_slot_gendered_personal(mood .. "_ind_fut", "-")
	add_slot_gendered_personal(mood .. "_presum", "-")
	add_slot_gendered_personal(mood .. "_subj_pres", "-")
	add_slot_gendered_personal(mood .. "_subj_fut", "-")
	add_slot_gendered(mood .. "_cfact", "-")
end

verb_slots_impers["inf_ms_linked"] = verb_slots_impers["inf_ms"]

local all_verb_slots = {}
for k, v in pairs(verb_slots_impers) do
	all_verb_slots[k] = v
end
for k, v in pairs(verb_slots_pers) do
	all_verb_slots[k] = v
end


local function fut_subj_ye_note(slot, link, ending)
	if rfind(slot, "^ind_fut") then
		return {"[the forms " .. link("येगा") .. ", " .. link("येंगे") .. ", " ..
			link("येगी") .. " and " .. link("येंगी") .. " can also be spelled without the ''y'': " ..
			link("एगा") .. ", " .. link("एँगे") .. ", " .. link("एगी") .. " and " .. link("एँगी") .. "]"}
	elseif rfind(slot, "^subj") then
		return {"[the forms " .. link("ये") .. " and " .. link("यें") ..
		" can also be spelled without the ''y'': " .. link("ए") .. " and " .. link("एँ") .. "]"}
	else
		error("Internal error: Don't know what to do with ending " .. ending .. " for slot " .. slot)
	end
end

local function pfv_ye_yi_note(link)
	return {"[the participles " .. link("ये") .. ", " .. link("यी") .. " and " .. link("यीं") ..
		" can also be spelled without the ''y'': " .. link("ए") .. ", " .. link("ई") ..
		" and " .. link("ईं") .. "]"}
end

-- Add one inflected form to `base.forms`, specifically to the list of forms associated with
-- the slot `slot` in the table in `base.forms`. Each element of the list is an object of the
-- form {form=FORM, translit=TRANSLIT, footnotes=FOOTNOTES}, where TRANSLIT is missing if no
-- manual translit needs to be given and FOOTNOTES is missing if there aren't any footnotes.
-- If FOOTNOTES is present it is a list of footnotes, where each footnote is e.g. "[rare or archaic]",
-- i.e. surrounded by brackets, with the first character lowercase and no final period.
-- (The brackets are automatically removed, the first character capitalized and a final period added.)
--
-- `stem` is the Devanagari stem to add the ending to.
-- `translit_stem` is the transliteration of `stem`, or nil to use the default transliteration.
-- `ending` is the Devanagari ending to add to the stem, possibly with sandhi changes to the
-- stem or ending.
-- `footnotes` is a list of associated footnotes in the same format as FOOTNOTES above, or nil.
-- `double_word` if given causes the resulting form to be doubled with a hyphen in between the two
-- parts, for use with the progressive form (e.g. करते-करते of verb करना).
local function add(base, stem, translit_stem, slot, ending, footnotes, double_word)
	local function doadd(new_stem, new_translit_stem, new_ending, slot_footnotes)
		new_ending = new_ending or ending
		if new_ending and base.notlast then
			-- If we're not the last verb in a multiword expression, chop off
			-- anything after a space. This is to handle verbs like [[हिलना-डुलना]],
			-- which have e.g. nonaspectual subjunctive 1sg masc हिलूँ-डुलूँ
			-- but perfective future indicative 1sg masc हिला-डुला हूँगा. Also, there
			-- are some special cases:
			-- (1) the conjunctive form should be e.g. हिल-डुलकर or हिल-डुलके
			-- (2) the future indicative should be e.g. 1sg हिलूँ-डुलूँगा
			-- (3) the future imperative 3pl should be e.g. हिलिये-डुलियेगा
			-- (4) the agentive should be e.g. हिलने-डुलनेवाला
			if slot == "conj" then
				new_ending = ""
			elseif slot:find("^ind_fut") then
				new_ending = rsub(new_ending, "ग.$", "") -- गा, गे or गी
			elseif slot == "imp_fut_3p" then
				new_ending = rsub(new_ending, "गा$", "")
			elseif slot:find("^agent") then
				new_ending = rsub(new_ending, "वाल." .. N .. "?$", "") -- वाला, वाले, वाली, वालीं
			else
				new_ending = rsub(new_ending, " .*", "")
			end
		end
		com.add_form(base, new_stem or stem, new_translit_stem or translit_stem, slot,
			new_ending, iut.combine_footnotes(slot_footnotes, footnotes), "link words", double_word)
	end
	if ending then
		if rfind(stem, "[" .. II .. I .. "ईइ]$") then
			-- Implement sandhi changes after stem ending in -ī or -i.
			local stem_butlast, translit_stem_butlast =
				com.strip_ending_from_stem(stem, translit_stem, rfind(stem, II .. "$") and II or I)
			local ending_first = usub(ending, 1, 1)
			if ending_first == E then
				local form_stem = stem_butlast .. I
				local form_tr = translit_stem_butlast and translit_stem_butlast .. "i"
				local function link(form_ending)
					return term_link(form_stem .. form_ending, form_tr and form_tr .. lang:transliterate(form_ending))
				end
				local y_footnote
				if slot:find("pfv") or slot:find("perf") then
					y_footnote = {"[the participle " .. link("ये") ..
						" can also be spelled without the ''y'': " .. link("ए") .. "]"}
				else
					y_footnote = fut_subj_ye_note(slot, link, ending)
				end
				doadd(form_stem .. "य", form_tr and form_tr .. "y", nil, y_footnote)
				return
			elseif ending_first == II then
				doadd(stem_butlast, translit_stem_butlast)
				return
			elseif rfind(ending_first, "[" .. com.vowels .. "]") then
				doadd(stem_butlast .. I .. "य", translit_stem_butlast and translit_stem_butlast .. "iy")
				return
			end
		elseif rfind(stem, "[" .. UU .. U .. "ऊउ]$") then
			-- Implement sandhi changes after stem ending in -ū or -u.
			local stem_butlast, translit_stem_butlast = com.strip_ending_from_stem(stem, translit_stem,
				rfind(stem, UU .. "$") and UU or U)
			local ending_first = usub(ending, 1, 1)
			if rfind(ending_first, "[" .. com.vowels .. "]") then
				doadd(stem_butlast .. U, translit_stem_butlast and translit_stem_butlast .. "u")
				return
			end
		elseif rfind(stem, "[" .. AA .. O .. "आऔ]$") and rfind(ending, "^" .. AA) then
			-- Implement sandhi changes after stem ending in -ā or -o and an ending beginning in -ā (always a
			-- perfective participle).
			doadd(stem .. "य", translit_stem and translit_stem .. "y")
			return
		elseif rfind(stem, "[" .. AA .. "आ]$") then
			local function link(form_ending)
				return term_link(stem .. form_ending, translit_stem and translit_stem .. lang:transliterate(form_ending))
			end
			local y_footnote
			-- Implement sandhi changes after stem ending in -ā and a perfective participle ending beginning in
			-- -e, -ī or -ī̃, or a future or subjunctive form beginning in -e.
			if slot:find("pfv") or slot:find("perf") then
				y_footnote = pfv_ye_yi_note(link)
			elseif rfind(ending, "^" .. E) then
				y_footnote = fut_subj_ye_note(slot, link, ending)
			end
			if y_footnote then
				doadd(stem .. "य", translit_stem and translit_stem .. "y", nil, y_footnote)
				return
			end
		elseif rfind(stem, "[" .. E .. "ए]$") then
			-- Implement sandhi changes after stem ending in -e and a perfective participle ending beginning in
			-- -ā, -e, -ī or -ī̃.
			if slot:find("pfv") or slot:find("perf") then
				local function link(form_ending)
					return term_link(stem .. form_ending, translit_stem and translit_stem .. lang:transliterate(form_ending))
				end
				local y_footnote = {"[the participles " .. link("या") .. ", " .. link("ये") .. ", " .. link("यी") ..
					" and " .. link("यीं") ..  " can also be spelled without the ''y'': " ..
					link("आ") .. ", " .. link("ए") .. ", " .. link("ई") .. " and " .. link("ईं") .. "]"}
				doadd(stem .. "य", translit_stem and translit_stem .. "y", nil, y_footnote)
				return
			end
		elseif rfind(stem, "%*$") then
			-- Special hacks for ग(य)-, perfective stem of जाना.
			local stem_butlast, translit_stem_butlast =
				com.strip_ending_from_stem(stem, translit_stem, "%*")
			if ending:find("^" .. E) or ending:find("^" .. II) then
				local function link(form_ending)
					return term_link(stem_butlast .. form_ending,
						translit_stem and translit_stem .. lang:transliterate(form_ending))
				end
				local y_footnote = pfv_ye_yi_note(link)
				-- Use full translit_stem rather than stripping off the final 'a' that should be there.
				-- Need to specify independent endings (diacritic endings get converted to independent ones after
				-- an explicit vowel, but here there is no explicit vowel).
				doadd(stem_butlast, translit_stem,
					ending:find("^" .. E) and rsub(ending, "^" .. E, "ए") or rsub(ending, "^" .. II, "ई"),
					y_footnote)
				-- doadd(stem_butlast .. "य", translit_stem and translit_stem .. "y")
			else
				doadd(stem_butlast .. "य", translit_stem and translit_stem .. "y")
			end
			return
		end
	end

	doadd()
end


-- Add the conjugation for a tense/aspect row with gender/number variants only.
local function add_conj_gendered(base, slot_prefix, stem, translit_stem, m_s, m_p, f_s, f_p, footnotes)
	if not stem then
		stem = base.stem
		translit_stem = base.stem_translit
	end
	add(base, stem, translit_stem, slot_prefix .. "_ms", m_s, footnotes)
	add(base, stem, translit_stem, slot_prefix .. "_mp", m_p, footnotes)
	add(base, stem, translit_stem, slot_prefix .. "_fs", f_s, footnotes)
	add(base, stem, translit_stem, slot_prefix .. "_fp", f_p, footnotes)
end


-- Add the conjugation for a tense/aspect row with person/number variants only.
local function add_conj_personal(base, slot_prefix, stem, translit_stem, s1, s23, p13, p2, footnotes)
	if not stem then
		stem = base.stem
		translit_stem = base.stem_translit
	end
	add(base, stem, translit_stem, slot_prefix .. "_1s", s1, footnotes)
	add(base, stem, translit_stem, slot_prefix .. "_23s", s23, footnotes)
	add(base, stem, translit_stem, slot_prefix .. "_13p", p13, footnotes)
	add(base, stem, translit_stem, slot_prefix .. "_2p", p2, footnotes)
end

-- Add the conjugation for a tense/aspect row with person/number/gender variants.
local function add_conj_gendered_personal(base, slot_prefix, stem, translit_stem,
	s1m, s23m, p13m, p2m, s1f, s23f, p13f, p2f, footnotes)
	if not stem then
		stem = base.stem
		translit_stem = base.stem_translit
	end
	add(base, stem, translit_stem, slot_prefix .. "_1sm", s1m, footnotes)
	add(base, stem, translit_stem, slot_prefix .. "_23sm", s23m, footnotes)
	add(base, stem, translit_stem, slot_prefix .. "_13pm", p13m, footnotes)
	add(base, stem, translit_stem, slot_prefix .. "_2pm", p2m, footnotes)
	add(base, stem, translit_stem, slot_prefix .. "_1sf", s1f, footnotes)
	add(base, stem, translit_stem, slot_prefix .. "_23sf", s23f, footnotes)
	add(base, stem, translit_stem, slot_prefix .. "_13pf", p13f, footnotes)
	add(base, stem, translit_stem, slot_prefix .. "_2pf", p2f, footnotes)
end

local function handle_derived_slots_and_overrides(base)
	-- No overrides implemented currently.
	-- process_slot_overrides(base)

	-- Compute linked versions of potential lemma slots, for use in {{hi-verb}}.
	-- We substitute the original lemma (before removing links) for forms that
	-- are the same as the lemma, if the original lemma has links.
	-- (NOTE: Not currently used by {{hi-verb}}.)
	for _, slot in ipairs({"inf_ms"}) do
		iut.insert_forms(base.forms, slot .. "_linked", iut.map_forms(base.forms[slot], function(form, translit)
			if form == base.orig_lemma_no_links and translit == base.lemma_translit
				and rfind(base.orig_lemma, "%[%[") then
				return base.orig_lemma, base.lemma_translit
			else
				return form, translit
			end
		end))
	end
end


local conjs = {}
local conjprops = {}

conjs["normal"] = function(base)
	local function fetch_irreg(irreg_table)
		if irreg_table[base.stem] then
			local stem = irreg_table[base.stem]
			return stem, nil
		else
			return base.stem, base.stem_translit
		end
	end

	local perf, trperf = fetch_irreg(irreg_perf)
	local subj, trsubj = fetch_irreg(irreg_subj)
	local polite_imp, tr_polite_imp = fetch_irreg(irreg_polite_imp)

	-- Undeclined forms
	add(base, base.stem, base.stem_translit, "stem", "")
	add(base, base.stem, base.stem_translit, "inf", "ना")
	add(base, base.stem, base.stem_translit, "inf_obl", "ने")
	add(base, base.stem, base.stem_translit, "conj", "कर")
	add(base, base.stem, base.stem_translit, "conj", "के")
	-- Normally progressive form is doubled (e.g. करते-करते), but not in multiword
	-- expressions like हिलना-डुलना.
	add(base, base.stem, base.stem_translit, "prog", "ते", nil, not base.multiword)

	-- Participles
	add_conj_gendered(base, "inf", nil, nil, "ना", "ने", "नी", "नीं")
	add_conj_gendered(base, "hab", nil, nil, "ता", "ते", "ती", "तीं")
	add_conj_gendered(base, "pfv", perf, trperf, AA, E, II, IIN)
	if base.stem == "जा" then
		add_conj_gendered(base, "pfv", "जा", nil, AA, E, II, IIN,
			{"[only with the copula " .. term_link("जाना") ..
				" and (in the habitual aspect only) with the auxiliary verb " .. term_link("करना") .. "]"})
	end
	add_conj_gendered(base, "agent", nil, nil, "नेवाला", "नेवाले", "नेवाली", "नेवालीं")
	add_conj_gendered(base, "adj_pfv", perf, trperf, AA .. " हुआ", E .. " हुए", II .. " हुई", II .. " हुईं")
	add_conj_gendered(base, "adj_hab", nil, nil, "ता हुआ", "ते हुए", "ती हुई", "ती हुईं")

	-- Non-aspectual
	add_conj_gendered(base, "ind_perf", perf, trperf, AA, E, II, IIN)
	add_conj_gendered_personal(base, "ind_fut", subj, trsubj,
		UUM .. "गा", E .. "गा", EN .. "गे", O .. "गे",
		UUM .. "गी", E .. "गी", EN .. "गी", O .. "गी")
	if base.stem == "हो" then
		add_conj_gendered_personal(base, "presum", "", "",
			"हूँगा", "होगा", "होंगे", "होगे",
			"हूँगी", "होगी", "होंगी", "होगी")
		add_conj_personal(base, "ind_pres", "", "", "हूँ", "है", "हैं", "हो")
		add_conj_gendered(base, "ind_impf", "थ", "th", AA, E, II, IIN)
		add_conj_personal(base, "subj_pres", "", "", "हूँ", "हो", "हों", "हो")
	end
	add_conj_personal(base, "subj_fut", subj, trsubj, UUM, E, EN, O)
	add_conj_gendered(base, "cfact", nil, nil, "ता", "ते", "ती", "तीं")

	add(base, base.stem, base.stem_translit, "imp_pres_2s", "")
	add(base, subj, trsubj, "imp_pres_2p", O)
	add(base, subj, trsubj, "imp_fut_2s", I .. "यो")
	add(base, base.stem, base.stem_translit, "imp_fut_2p", "ना")
	-- There may be more than one possible polite imperative stem, particularly for
	-- irregular verbs. Loop over them.
	if type(polite_imp) ~= "table" or polite_imp.form then
		polite_imp = {polite_imp}
	end
	if tr_polite_imp and type(tr_polite_imp) ~= "table" then
		tr_polite_imp = {tr_polite_imp}
	end
	for i, polimp in ipairs(polite_imp) do
		local tr_polimp = tr_polite_imp and tr_polite_imp[i]
		local imp_footnote
		if polimp.form then
			imp_footnote = polimp.footnotes
			polimp = polimp.form
		end
		-- Implement sandhi changes after stem ending in -ī or -ū, before ending in i-.
		-- FIXME: Merge these with the sandhi code in add().
		local sandhi_polimp, sandhi_tr_polimp
		if rfind(polimp, II .. "$") then
			sandhi_polimp, sandhi_tr_polimp = com.strip_ending_from_stem(polimp, tr_polimp, II)
			sandhi_polimp = sandhi_polimp .. I
			sandhi_tr_polimp = sandhi_tr_polimp and sandhi_tr_polimp .. "i" or nil
		elseif rfind(polimp, UU .. "$") then
			sandhi_polimp, sandhi_tr_polimp = com.strip_ending_from_stem(polimp, tr_polimp, UU)
			sandhi_polimp = sandhi_polimp .. U
			sandhi_tr_polimp = sandhi_tr_polimp and sandhi_tr_polimp .. "u" or nil
		else
			sandhi_polimp, sandhi_tr_polimp = polimp, tr_polimp
		end
		local function link_i(form_ending)
			return term_link(sandhi_polimp .. I .. form_ending,
				sandhi_tr_polimp and sandhi_tr_polimp .. "i" .. lang:transliterate(form_ending))
		end
		local y_footnote = {
			"[the forms " .. link_i("ये") .. " and " .. link_i("येगा") .. " can also be spelled without the ''y'': " ..
			link_i("ए") .. " and " .. link_i("एगा") .. "]"}
		local all_footnotes = iut.combine_footnotes(imp_footnote, y_footnote)
		add(base, polimp, tr_polimp, "imp_pres_3p", I .. "ये", all_footnotes)
		add(base, polimp, tr_polimp, "imp_fut_3p", I .. "येगा", all_footnotes)
	end

	-- Habitual
	add_conj_gendered_personal(base, "hab_ind_pres", nil, nil,
		"ता हूँ", "ता है", "ते हैं", "ते हो",
		"ती हूँ", "ती है", "ती हैं", "ती हो")
	add_conj_gendered(base, "hab_ind_past", nil, nil, "ता था", "ते थे", "ती थी", "ती थीं")
	add_conj_gendered_personal(base, "hab_presum", nil, nil,
		"ता हूँगा", "ता होगा", "ते होंगे", "ते होगे",
		"ती हूँगी", "ती होगी", "ती होंगी", "ती होगी")
	add_conj_gendered_personal(base, "hab_subj", nil, nil,
		"ता हूँ", "ता हो", "ते हों", "ते हो",
		"ती हूँ", "ती हो", "ती हों", "ती हो")
	add_conj_gendered(base, "hab_cfact", nil, nil,
		"ता होता", "ते होते", "ती होती", "ती होतीं")

	-- Perfective
	add_conj_gendered_personal(base, "pfv_ind_pres", perf, trperf,
		AA .. " हूँ", AA .. " है", E .. " हैं", E .. " हो",
		II .. " हूँ", II .. " है", II .. " हैं", II .. " हो")
	add_conj_gendered(base, "pfv_ind_past", perf, trperf,
		AA .. " था", E .. " थे", II .. " थी", II .. " थीं")
	add_conj_gendered_personal(base, "pfv_ind_fut", perf, trperf,
		AA .. " हूँगा", AA .. " होगा", E .. " होंगे", E .. " होगे",
		II .. " हूँगी", II .. " होगी", II .. " होंगी", II .. " होगी")
	add_conj_gendered_personal(base, "pfv_presum", perf, trperf,
		AA .. " हूँगा", AA .. " होगा", E .. " होंगे", E .. " होगे",
		II .. " हूँगी", II .. " होगी", II .. " होंगी", II .. " होगी")
	add_conj_gendered_personal(base, "pfv_subj_pres", perf, trperf,
		AA .. " हूँ", AA .. " हो", E .. " हों", E .. " हो",
		II .. " हूँ", II .. " हो", II .. " हों", II .. " हो")
	add_conj_gendered_personal(base, "pfv_subj_fut", perf, trperf,
		AA .. " होऊँ", AA .. " होए", E .. " होएँ", E .. " होओ",
		II .. " होऊँ", II .. " होए", II .. " होएँ", II .. " होओ")
	add_conj_gendered(base, "pfv_cfact", perf, trperf, AA .. " होता", E .. " होते", II .. " होती", II .. " होतीं")

	-- Progressive
	add_conj_gendered_personal(base, "prog_ind_pres", nil, nil,
		" रहा हूँ", " रहा है", " रहे हैं", " रहे हो",
		" रही हूँ", " रही है", " रही हैं", " रही हो")
	add_conj_gendered(base, "prog_ind_past", nil, nil,
		" रहा था", " रहे थे", " रही थी", " रही थीं")
	add_conj_gendered_personal(base, "prog_ind_fut", nil, nil,
		" रहा हूँगा", " रहा होगा", " रहे होंगे", " रहे होगे",
		" रही हूँगी", " रही होगी", " रही होंगी", " रही होगी")
	add_conj_gendered_personal(base, "prog_presum", nil, nil,
		" रहा हूँगा", " रहा होगा", " रहे होंगे", " रहे होगे",
		" रही हूँगी", " रही होगी", " रही होंगी", " रही होगी")
	add_conj_gendered_personal(base, "prog_subj_pres", nil, nil,
		" रहा हूँ", " रहा हो", " रहे हों", " रहे हो",
		" रही हूँ", " रही हो", " रही हों", " रही हो")
	add_conj_gendered_personal(base, "prog_subj_fut", nil, nil,
		" रहा होऊँ", " रहा होए", " रहे होएँ", " रहे होओ",
		" रही होऊँ", " रही होए", " रही होएँ", " रही होओ")
	add_conj_gendered(base, "prog_cfact", nil, nil, " रहा होता", " रहे होते", " रही होती", " रही होतीं")
end


--[=[
Parse an indicator spec (text consisting of angle brackets and zero or more
dot-separated indicators within them). Return value is an object of the form

{
  forms = {}, -- forms for a single spec alternant; see `forms` below

  -- The following additional fields are added by other functions:
  orig_lemma = "ORIGINAL-LEMMA", -- as given by the user or taken from pagename
  orig_lemma_no_links = "ORIGINAL-LEMMA-NO-LINKS", -- links removed
  lemma = "LEMMA", -- `orig_lemma_no_links`, converted to singular form if plural
  phon_lemma = "LEMMA-PHONETIC-RESPELLING", -- as specified by the user; may be missing
  lemma_translit = "LEMMA-TRANSLIT", -- translit of phon_lemma (if present)
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
  conj = "CONJ", -- declension, e.g. "normal" (the only one currently implemented)
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
			-- No indicators allowed currently.
			local part = dot_separated_group[1]
			error("Unrecognized indicator '" .. part .. "': '" .. inside .. "'")
		end
	end
	return base
end


local function detect_indicator_spec(base)
	base.conj = "normal"
	base.stem, base.stem_translit = com.strip_ending(base, "ना")
end


local function detect_all_indicator_specs(alternant_multiword_spec)
	iut.map_word_specs(alternant_multiword_spec, function(base)
		detect_indicator_spec(base)
	end)

	-- Set notlast=true on verbs that aren't the last one in a multiword expression, and
	-- multiword=true on all verbs in multiword expressions (as well as at top level), so
	-- we can properly handle verbs like [[हिलना-डुलना]].
	for i, alternant_or_word_spec in ipairs(alternant_multiword_spec.alternant_or_word_specs) do
		if alternant_or_word_spec.alternants then
			for _, multiword_spec in ipairs(alternant_or_word_spec.alternants) do
				for j, word_spec in ipairs(multiword_spec.word_specs) do
					if j < #multiword_spec.word_specs then
						word_spec.notlast = true
					end
					if #multiword_spec.word_specs > 1 then
						word_spec.multiword = true
						alternant_multiword_spec.multiword = true
					end
				end
			end
		else
			if i < #alternant_multiword_spec.alternant_or_word_specs then
				alternant_or_word_spec.notlast = true
			end
			if #alternant_multiword_spec.alternant_or_word_specs > 1 then
				alternant_or_word_spec.multiword = true
				alternant_multiword_spec.multiword = true
			end
		end
	end
end


local function conjugate_verb(base)
	if not conjs[base.conj] then
		error("Internal error: Unrecognized conjugation type '" .. base.conj .. "'")
	end
	conjs[base.conj](base)
	if base.multiword then
		-- See comment in add_variant_codes() for the purpose of this.
		com.add_variant_codes(base)
	end
	handle_derived_slots_and_overrides(base)
end


-- Compute the categories to add the verb to, as well as the annotation to display in the
-- conjugation title bar. We combine the code to do these functions as both categories and
-- title bar contain similar information.
local function compute_categories_and_annotation(alternant_multiword_spec)
	local cats = {}
	local function insert(cattype)
		cattype = rsub(cattype, "~", alternant_multiword_spec.pos)
		m_table.insertIfNot(cats, "Hindi " .. cattype)
	end
	local annotation
	if alternant_multiword_spec.manual then
		alternant_multiword_spec.annotation = ""
	else
		local function do_word_spec(base)
			if base.lemma_translit and lang:transliterate(base.lemma) ~= base.lemma_translit then
				insert("~ with phonetic respelling")
			end
		end
		iut.map_word_specs(alternant_multiword_spec, function(base)
			do_word_spec(base)
		end)
	end
	alternant_multiword_spec.categories = cats
end


-- Convert forms from their list/object form (see the comments to add() for how this works)
-- to strings that can be directly filled into the table. Approximately, each form is converted
-- to a formatted link with accelerators and the results are concatenated, followed by an newline
-- and then the formatted transliterations.
local function show_forms(alternant_multiword_spec)
	local lemmas = alternant_multiword_spec.forms.inf_ms or {}
	local props = {
		lang = lang,
	}
	if alternant_multiword_spec.multiword then
		-- Remove variant codes that were added to ensure only parallel variants in
		-- multiword expressions like [[हिलना-डुलना]] get generated. See com.add_variant_codes()
		-- for more information.
		props.canonicalize = function(form)
			return com.remove_variant_codes(form)
		end
	end
	iut.show_forms_with_translit(alternant_multiword_spec.forms, lemmas,
		verb_slots_impers, props, alternant_multiword_spec.footnotes_impers)
	alternant_multiword_spec.forms.footnote_impers = alternant_multiword_spec.forms.footnote
	iut.show_forms_with_translit(alternant_multiword_spec.forms, lemmas,
		verb_slots_pers, props, alternant_multiword_spec.footnotes_pers)
	alternant_multiword_spec.forms.footnote_pers = alternant_multiword_spec.forms.footnote
end


-- Generate the conjugation table. This should be called after show_forms() has converted
-- each form to a formatted string.
local function make_table(alternant_multiword_spec)
	local table_spec_impersonal = [=[
<div class="NavFrame" style="display: table;">
<div class="NavHead hi-table-title" style="background: #d9ebff;">Impersonal forms of {inf_raw}</div>
<div class="NavContent">
{\op}| class="inflection-table inflection-hi inflection-verb" data-toggle-category="inflection"
|-
| class="hi-tense-aspect-cell"colspan=100% | ''Undeclined''
|-
| class="hi-tense-aspect-cell" colspan=2 | ''Stem''
| colspan="100%" | {stem}
|-
| class="hi-tense-aspect-cell" colspan=2 | ''Infinitive''
| colspan="100%" | {inf}
|-
| class="hi-tense-aspect-cell" colspan=2 | ''Oblique Infinitive''
| colspan="100%" | {inf_obl}
|-
| class="hi-tense-aspect-cell" colspan=2 | ''Conjunctive''
| colspan="100%" | {conj}
|-
| class="hi-tense-aspect-cell" colspan=2 | ''Progressive''
| colspan="100%" | {prog}
|-
| class="hi-tense-aspect-cell" colspan=100% | ''Participles''
|-
|- class="hi-part-gender-number-header"
| class="hi-tense-aspect-cell" colspan=2 |
| {dir} {m} {s}
| {m} {p}<br />{obl} {m} {s}
| {f} {s}
| {f} {p}
|-
| class="hi-tense-aspect-cell" colspan=2 | ''Infinitive''
| {inf_ms}
| {inf_mp}
| {inf_fs}
| {inf_fp}
|-
| class="hi-tense-aspect-cell" colspan=2 | ''Habitual''
| {hab_ms}
| {hab_mp}
| {hab_fs}
| {hab_fp}
|-
| class="hi-tense-aspect-cell" colspan=2 | ''Perfective''
| {pfv_ms}
| {pfv_mp}
| {pfv_fs}
| {pfv_fp}
|-
| class="hi-tense-aspect-cell" colspan=2 | ''Prospective<br>Agentive''
| {agent_ms}
| {agent_mp}
| {agent_fs}
| {agent_fp}
|-
| class="hi-tense-aspect-cell" rowspan=2 | ''Adjectival''
| class="hi-tense-aspect-cell" | ''Perfective''
| {adj_pfv_ms}
| {adj_pfv_mp}
| {adj_pfv_fs}
| {adj_pfv_fp}
|-
| class="hi-tense-aspect-cell" | ''Habitual''
| {adj_hab_ms}
| {adj_hab_mp}
| {adj_hab_fs}
| {adj_hab_fp}
|{\cl}{notes_clause}</div></div>]=]

	local person_number_header_two_row = [=[
|- class="hi-table-header"
| rowspan=2 |
| rowspan=2 |
| class="hi-mf-cell" rowspan=2 |
]=]

	local person_number_header_sg_pl_headers = [=[
| colspan=3 | '''Singular'''
| colspan=1 | '''Singular/Plural'''
| colspan=2 | '''Plural/Formal'''
]=]

	local person_number_header_table_div = [=[
|- class="hi-table-header"
]=]

	local person_number_header_pers_num_headers = [=[
| '''1<sup>st</sup>'''<br><span lang="hi" class="Deva">[[मैं]]</span>
| '''2<sup>nd</sup> intimate'''<br><span lang="hi" class="Deva">[[तू]]</span>
| '''3<sup>rd</sup>'''<br><span lang="hi" class="Deva">[[यह]]/[[वह]]</span>
| '''2<sup>nd</sup> familiar'''<br><span lang="hi" class="Deva">[[तुम]]</span>
| '''1<sup>st</sup>'''<br><span lang="hi" class="Deva">[[हम]]</span>
| '''2<sup>nd</sup> formal, 3<sup>rd</sup>'''<br><span lang="hi" class="Deva">[[ये]]/[[वे]]/[[आप]]</span>
]=]

	-- Regular person-number header used at the top of the table and in the middle.
	local person_number_header =
		person_number_header_table_div .. person_number_header_two_row .. person_number_header_sg_pl_headers ..
		person_number_header_table_div .. person_number_header_pers_num_headers
	-- Reversed person-number header used at the bottom of the table. "Reversed" means that
	-- the two rows are in reversed order; but internally we can't switch the order of everything
	-- (e.g. the double-row cells at the left side), so we need to break up the header into multiple
	-- parts and only reverse certain parts.
	local reversed_person_number_header =
		person_number_header_table_div .. person_number_header_two_row .. person_number_header_pers_num_headers ..
		person_number_header_table_div .. person_number_header_sg_pl_headers

	local table_spec_personal = [=[
<div class="NavFrame" style="display: table;>
<div class="NavHead hi-table-title" style="background: #d9ebff;">Personal forms of {inf_raw}</div>
<div class="NavContent">
{\op}| class="inflection-table inflection-hi inflection-verb" data-toggle-category="inflection"
|-
| class="hi-sec-div" rowspan=1 colspan=100% | ''Non-Aspectual''
{person_number_header}{pres_impf_table}| class="hi-tense-aspect-cell" rowspan=2 colspan=1 | {PERF}
| class="hi-mf-cell" | {m}
| colspan=3 | {ind_perf_ms}
| colspan=3 | {ind_perf_mp}
|- class="hi-row-f"
| class="hi-mf-cell" | {f}
| colspan=4 | {ind_perf_fs}
| colspan=2 | {ind_perf_fp}
|- class="hi-row-m"
| class="hi-tense-aspect-cell" rowspan=2 colspan=1 | {FUT}
| class="hi-mf-cell" | {m}
| {ind_fut_1sm}
| colspan=2 | {ind_fut_23sm}
| {ind_fut_2pm}
| colspan=2 | {ind_fut_13pm}
|- class="hi-row-f"
| class="hi-mf-cell" | {f}
| {ind_fut_1sf}
| colspan=2 | {ind_fut_23sf}
| {ind_fut_2pf}
| colspan=2 | {ind_fut_13pf}
{presum_table}{subj_table}
|- class="hi-row-m"
| class="hi-tense-aspect-cell" rowspan=2 colspan=1 | ''Contrafactual''
| class="hi-tense-aspect-cell" rowspan=2 colspan=1 | {PST}
| class="hi-mf-cell" | {m}
| colspan=3 | {cfact_ms}
| colspan=3 | {cfact_mp}
|- class="hi-row-f"
| class="hi-mf-cell" | {f}
| colspan=4 | {cfact_fs}
| colspan=2 | {cfact_fp}
|-
| class="hi-tense-aspect-cell" rowspan=2 colspan=1 | ''Imperative''
| class="hi-tense-aspect-cell" rowspan=1 colspan=1 | {PRS}
| class="hi-mf-cell" | {mf}
|
| {imp_pres_2s}
| {imp_pres_3s}
| {imp_pres_2p}
|
| {imp_pres_3p}
|-
| class="hi-tense-aspect-cell" rowspan=1 colspan=1 | {FUT}
| class="hi-mf-cell" | {mf}
|
| {imp_fut_2s}
| {imp_fut_3s}
| {imp_fut_2p}
|
| {imp_fut_3p}
|-
| class="hi-sec-div" rowspan=1 colspan=100% | ''Habitual''
|- class="hi-row-m"
| class="hi-tense-aspect-cell" rowspan=4 colspan=1 | ''Indicative''
| class="hi-tense-aspect-cell" rowspan=2 colspan=1 | {PRS}
| class="hi-mf-cell" | {m}
| {hab_ind_pres_1sm}
| colspan=2 | {hab_ind_pres_23sm}
| {hab_ind_pres_2pm}
| colspan=2 | {hab_ind_pres_13pm}
|- class="hi-row-f"
| class="hi-mf-cell" | {f}
| {hab_ind_pres_1sf}
| colspan=2 | {hab_ind_pres_23sf}
| {hab_ind_pres_2pf}
| colspan=2 | {hab_ind_pres_13pf}
|- class="hi-row-m"
| class="hi-tense-aspect-cell" rowspan=2 colspan=1 | {PST}
| class="hi-mf-cell" | {m}
| colspan=3 | {hab_ind_past_ms}
| colspan=3 | {hab_ind_past_mp}
|- class="hi-row-f"
| class="hi-mf-cell" | {f}
| colspan=4 | {hab_ind_past_fs}
| colspan=2 | {hab_ind_past_fp}
|- class="hi-row-m"
| class="hi-tense-aspect-cell" rowspan=2 colspan=1 | ''Presumptive''
| class="hi-tense-aspect-cell" rowspan=2 colspan=1 | {PRS_PST}
| class="hi-mf-cell" | {m}
| {hab_presum_1sm}
| colspan=2 | {hab_presum_23sm}
| {hab_presum_2pm}
| colspan=2 | {hab_presum_13pm}
|- class="hi-row-f"
| class="hi-mf-cell" | {f}
| {hab_presum_1sf}
| colspan=2 | {hab_presum_23sf}
| {hab_presum_2pf}
| colspan=2 | {hab_presum_13pf}
|- class="hi-row-m"
| class="hi-tense-aspect-cell" rowspan=2 colspan=1 | ''Subjunctive''
| class="hi-tense-aspect-cell" rowspan=2 colspan=1 | {PRS}
| class="hi-mf-cell" | {m}
| {hab_subj_1sm}
| colspan=2 | {hab_subj_23sm}
| {hab_subj_2pm}
| colspan=2 | {hab_subj_13pm}
|- class="hi-row-f"
| class="hi-mf-cell" | {f}
| {hab_subj_1sf}
| colspan=2 | {hab_subj_23sf}
| {hab_subj_2pf}
| colspan=2 | {hab_subj_13pf}
|- class="hi-row-m"
| class="hi-tense-aspect-cell" rowspan=2 colspan=1 | ''Contrafactual''
| class="hi-tense-aspect-cell" rowspan=2 colspan=1 | {PST}
| class="hi-mf-cell" | {m}
| colspan=3 | {hab_cfact_ms}
| colspan=3 | {hab_cfact_mp}
|- class="hi-row-f"
| class="hi-mf-cell" | {f}
| colspan=4 | {hab_cfact_fs}
| colspan=2 | {hab_cfact_fp}
|-
| class="hi-sec-div" rowspan=1 colspan=100% | ''Perfective''
{person_number_header}|- class="hi-row-m"
| class="hi-tense-aspect-cell" rowspan=6 colspan=1 | ''Indicative''
| class="hi-tense-aspect-cell" rowspan=2 colspan=1 | {PRS}
| class="hi-mf-cell" | {m}
| {pfv_ind_pres_1sm}
| colspan=2 | {pfv_ind_pres_23sm}
| {pfv_ind_pres_2pm}
| colspan=2 | {pfv_ind_pres_13pm}
|- class="hi-row-f"
| class="hi-mf-cell" | {f}
| {pfv_ind_pres_1sf}
| colspan=2 | {pfv_ind_pres_23sf}
| {pfv_ind_pres_2pf}
| colspan=2 | {pfv_ind_pres_13pf}
|- class="hi-row-m"
| class="hi-tense-aspect-cell" rowspan=2 colspan=1 | {PST}
| class="hi-mf-cell" | {m}
| colspan=3 | {pfv_ind_past_ms}
| colspan=3 | {pfv_ind_past_mp}
|- class="hi-row-f"
| class="hi-mf-cell" | {f}
| colspan=4 | {pfv_ind_past_fs}
| colspan=2 | {pfv_ind_past_fp}
|- class="hi-row-m"
| class="hi-tense-aspect-cell" rowspan=2 colspan=1 | {FUT}
| class="hi-mf-cell" | {m}
| {pfv_ind_fut_1sm}
| colspan=2 | {pfv_ind_fut_23sm}
| {pfv_ind_fut_2pm}
| colspan=2 | {pfv_ind_fut_13pm}
|- class="hi-row-f"
| class="hi-mf-cell" | {f}
| {pfv_ind_fut_1sf}
| colspan=2 | {pfv_ind_fut_23sf}
| {pfv_ind_fut_2pf}
| colspan=2 | {pfv_ind_fut_13pf}
|- class="hi-row-m"
| class="hi-tense-aspect-cell" rowspan=2 colspan=1 | ''Presumptive''
| class="hi-tense-aspect-cell" rowspan=2 colspan=1 | {PRS_PST}
| class="hi-mf-cell" | {m}
| {pfv_presum_1sm}
| colspan=2 | {pfv_presum_23sm}
| {pfv_presum_2pm}
| colspan=2 | {pfv_presum_13pm}
|- class="hi-row-f"
| class="hi-mf-cell" | {f}
| {pfv_presum_1sf}
| colspan=2 | {pfv_presum_23sf}
| {pfv_presum_2pf}
| colspan=2 | {pfv_presum_13pf}
|- class="hi-row-m"
| class="hi-tense-aspect-cell" rowspan=4 colspan=1 | ''Subjunctive''
| class="hi-tense-aspect-cell" rowspan=2 colspan=1 | {PRS}
| class="hi-mf-cell" | {m}
| {pfv_subj_pres_1sm}
| colspan=2 | {pfv_subj_pres_23sm}
| {pfv_subj_pres_2pm}
| colspan=2 | {pfv_subj_pres_13pm}
|- class="hi-row-f"
| class="hi-mf-cell" | {f}
| {pfv_subj_pres_1sf}
| colspan=2 | {pfv_subj_pres_23sf}
| {pfv_subj_pres_2pf}
| colspan=2 | {pfv_subj_pres_13pf}
|- class="hi-row-m"
| class="hi-tense-aspect-cell" rowspan=2 colspan=1 | {FUT}
| class="hi-mf-cell" | {m}
| {pfv_subj_fut_1sm}
| colspan=2 | {pfv_subj_fut_23sm}
| {pfv_subj_fut_2pm}
| colspan=2 | {pfv_subj_fut_13pm}
|- class="hi-row-f"
| class="hi-mf-cell" | {f}
| {pfv_subj_fut_1sf}
| colspan=2 | {pfv_subj_fut_23sf}
| {pfv_subj_fut_2pf}
| colspan=2 | {pfv_subj_fut_13pf}
|- class="hi-row-m"
| class="hi-tense-aspect-cell" rowspan=2 colspan=1 | ''Contrafactual''
| class="hi-tense-aspect-cell" rowspan=2 colspan=1 | {PST}
| class="hi-mf-cell" | {m}
| colspan=3 | {pfv_cfact_ms}
| colspan=3 | {pfv_cfact_mp}
|- class="hi-row-f"
| class="hi-mf-cell" | {f}
| colspan=4 | {pfv_cfact_fs}
| colspan=2 | {pfv_cfact_fp}
|-
| class="hi-sec-div" rowspan=1 colspan=100% | ''Progressive''
|- class="hi-row-m"
| class="hi-tense-aspect-cell" rowspan=6 colspan=1 | ''Indicative''
| class="hi-tense-aspect-cell" rowspan=2 colspan=1 | {PRS}
| class="hi-mf-cell" | {m}
| {prog_ind_pres_1sm}
| colspan=2 | {prog_ind_pres_23sm}
| {prog_ind_pres_2pm}
| colspan=2 | {prog_ind_pres_13pm}
|- class="hi-row-f"
| class="hi-mf-cell" | {f}
| {prog_ind_pres_1sf}
| colspan=2 | {prog_ind_pres_23sf}
| {prog_ind_pres_2pf}
| colspan=2 | {prog_ind_pres_13pf}
|- class="hi-row-m"
| class="hi-tense-aspect-cell" rowspan=2 colspan=1 | {PST}
| class="hi-mf-cell" | {m}
| colspan=3 | {prog_ind_past_ms}
| colspan=3 | {prog_ind_past_mp}
|- class="hi-row-f"
| class="hi-mf-cell" | {f}
| colspan=4 | {prog_ind_past_fs}
| colspan=2 | {prog_ind_past_fp}
|- class="hi-row-m"
| class="hi-tense-aspect-cell" rowspan=2 colspan=1 | {FUT}
| class="hi-mf-cell" | {m}
| {prog_ind_fut_1sm}
| colspan=2 | {prog_ind_fut_23sm}
| {prog_ind_fut_2pm}
| colspan=2 | {prog_ind_fut_13pm}
|- class="hi-row-f"
| class="hi-mf-cell" | {f}
| {prog_ind_fut_1sf}
| colspan=2 | {prog_ind_fut_23sf}
| {prog_ind_fut_2pf}
| colspan=2 | {prog_ind_fut_13pf}
|- class="hi-row-m"
| class="hi-tense-aspect-cell" rowspan=2 colspan=1 | ''Presumptive''
| class="hi-tense-aspect-cell" rowspan=2 colspan=1 | {PRS_PST_FUT}
| class="hi-mf-cell" | {m}
| {prog_presum_1sm}
| colspan=2 | {prog_presum_23sm}
| {prog_presum_2pm}
| colspan=2 | {prog_presum_13pm}
|- class="hi-row-f"
| class="hi-mf-cell" | {f}
| {prog_presum_1sf}
| colspan=2 | {prog_presum_23sf}
| {prog_presum_2pf}
| colspan=2 | {prog_presum_13pf}
|- class="hi-row-m"
| class="hi-tense-aspect-cell" rowspan=4 colspan=1 | ''Subjunctive''
| class="hi-tense-aspect-cell" rowspan=2 colspan=1 | {PRS}
| class="hi-mf-cell" | {m}
| {prog_subj_pres_1sm}
| colspan=2 | {prog_subj_pres_23sm}
| {prog_subj_pres_2pm}
| colspan=2 | {prog_subj_pres_13pm}
|- class="hi-row-f"
| class="hi-mf-cell" | {f}
| {prog_subj_pres_1sf}
| colspan=2 | {prog_subj_pres_23sf}
| {prog_subj_pres_2pf}
| colspan=2 | {prog_subj_pres_13pf}
|- class="hi-row-m"
| class="hi-tense-aspect-cell" rowspan=2 colspan=1 | {FUT}
| class="hi-mf-cell" | {m}
| {prog_subj_fut_1sm}
| colspan=2 | {prog_subj_fut_23sm}
| {prog_subj_fut_2pm}
| colspan=2 | {prog_subj_fut_13pm}
|- class="hi-row-f"
| class="hi-mf-cell" | {f}
| {prog_subj_fut_1sf}
| colspan=2 | {prog_subj_fut_23sf}
| {prog_subj_fut_2pf}
| colspan=2 | {prog_subj_fut_13pf}
|- class="hi-row-m"
| class="hi-tense-aspect-cell" rowspan=2 colspan=1 | ''Contrafactual''
| class="hi-tense-aspect-cell" rowspan=2 colspan=1 | {PST}
| class="hi-mf-cell" | {m}
| colspan=3 | {prog_cfact_ms}
| colspan=3 | {prog_cfact_mp}
|- class="hi-row-f"
| class="hi-mf-cell" | {f}
| colspan=4 | {prog_cfact_fs}
| colspan=2 | {prog_cfact_fp}
{reversed_person_number_header}|{\cl}{notes_clause}</div></div>]=]

	local pres_impf_table = [=[
|-
| class="hi-tense-aspect-cell" rowspan=7 colspan=1 | ''Indicative''
| class="hi-tense-aspect-cell" rowspan=1 colspan=1 | {PRS}
| class="hi-mf-cell" | {mf}
| {ind_pres_1s}
| colspan=2 | {ind_pres_23s}
| {ind_pres_2p}
| colspan=2 | {ind_pres_13p}
|- class="hi-row-m"
| class="hi-tense-aspect-cell" rowspan=2 colspan=1 | {IMPF}
| class="hi-mf-cell" | {m}
| colspan=3 | {ind_impf_ms}
| colspan=3 | {ind_impf_mp}
|- class="hi-row-f"
| class="hi-mf-cell" | {f}
| colspan=4 | {ind_impf_fs}
| colspan=2 | {ind_impf_fp}
|- class="hi-row-m"
]=]

	local pres_impf_table_missing = [=[
|- class="hi-row-m"
| class="hi-tense-aspect-cell" rowspan=4 colspan=1 | ''Indicative''
]=]

	local presum_table = [=[
|- class="hi-row-m"
| class="hi-tense-aspect-cell" rowspan=2 colspan=1 | ''Presumptive''
| class="hi-tense-aspect-cell" rowspan=2 colspan=1 | {PRS_PST_FUT}
| class="hi-mf-cell" | {m}
| {presum_1sm}
| colspan=2 | {presum_23sm}
| {presum_2pm}
| colspan=2 | {presum_13pm}
|- class="hi-row-f"
| class="hi-mf-cell" | {f}
| {presum_1sf}
| colspan=2 | {presum_23sf}
| {presum_2pf}
| colspan=2 | {presum_13pf}
]=]

	local combined_subj = [=[
|-
| class="hi-tense-aspect-cell" rowspan=1 colspan=1 | ''Subjunctive''
| class="hi-tense-aspect-cell" rowspan=1 colspan=1 | {FUT}
| class="hi-mf-cell" | {mf}
| {subj_fut_1s}
| colspan=2 | {subj_fut_23s}
| {subj_fut_2p}
| colspan=2 | {subj_fut_13p}]=]

	local split_subj = [=[
|-
| class="hi-tense-aspect-cell" rowspan=2 colspan=1 | ''Subjunctive''
| class="hi-tense-aspect-cell" rowspan=1 colspan=1 | {PRS}
| class="hi-mf-cell" | {mf}
| {subj_pres_1s}
| colspan=2 | {subj_pres_23s}
| {subj_pres_2p}
| colspan=2 | {subj_pres_13p}
|-
| class="hi-tense-aspect-cell" rowspan=1 colspan=1 | {FUT}
| class="hi-mf-cell" | {mf}
| {subj_fut_1s}
| colspan=2 | {subj_fut_23s}
| {subj_fut_2p}
| colspan=2 | {subj_fut_13p}]=]

	local notes_template = [===[
<div class="hi-footnote-outer-div">
<div class="hi-footnote-inner-div">
{footnote}
</div></div>
]===]

	local forms = alternant_multiword_spec.forms

	local function make_gender_abbr(title, text)
		return '<span class="gender"><abbr title="' .. title .. '">' .. text .. '</abbr></span>'
	end
	local function make_tense_aspect_abbr(title, text)
		local template = [=[
''<abbr style="font-variant: small-caps; text-transform: lowercase;" title="{title}">{text}</abbr>'']=]
		return m_string_utilities.format(template, {title = title, text = text})
	end
	forms.m = make_gender_abbr("masculine gender", "m")
	forms.f = make_gender_abbr("feminine gender", "f")
	forms.mf = forms.m .. "<br />" .. forms.f
	forms.s = make_gender_abbr("singular number", "s")
	forms.p = make_gender_abbr("plural number", "p")
	forms.dir = make_gender_abbr("direct", "dir")
	forms.obl = make_gender_abbr("oblique", "obl")
	forms.PERF = make_tense_aspect_abbr("Perfect", "PERF")
	forms.IMPF = make_tense_aspect_abbr("Imperfect", "IMPF")
	forms.PST = make_tense_aspect_abbr("Past", "PST")
	forms.FUT = make_tense_aspect_abbr("Future", "FUT")
	forms.PRS = make_tense_aspect_abbr("Present", "PRS")
	forms.PRS_FUT = make_tense_aspect_abbr("Present/Future", "PRS<br />FUT")
	forms.PRS_PST = make_tense_aspect_abbr("Present/Past", "PRS<br />PST")
	forms.PRS_PST_FUT = make_tense_aspect_abbr("Present/Past/Future", "PRS<br />PST<br />FUT")
	forms.inf_raw = tag_text(forms.lemma)

	-- Now format the impersonal table.
	forms.footnote = forms.footnote_impers
	forms.notes_clause = forms.footnote ~= "" and
		m_string_utilities.format(notes_template, forms) or ""
	local formatted_table_impers = m_string_utilities.format(table_spec_impersonal, forms)

	-- Now format the personal table.
	forms.footnote = forms.footnote_pers
	forms.notes_clause = forms.footnote ~= "" and
		m_string_utilities.format(notes_template, forms) or ""
	if forms.ind_pres_1s ~= "—" then -- होना
		forms.subj_table = m_string_utilities.format(split_subj, forms)
		forms.pres_impf_table = m_string_utilities.format(pres_impf_table, forms)
		forms.presum_table = m_string_utilities.format(presum_table, forms)
	else
		forms.subj_table = m_string_utilities.format(combined_subj, forms)
		forms.pres_impf_table = pres_impf_table_missing
		forms.presum_table = ""
	end
	forms.person_number_header = person_number_header
	forms.reversed_person_number_header = reversed_person_number_header
	local formatted_table_pers = m_string_utilities.format(table_spec_personal, forms)

	-- Concatenate both.
	return require("Module:TemplateStyles")("Module:hi-verb/style.css") .. formatted_table_impers .. formatted_table_pers
end


-- Implementation of template 'hi-verb cat'.
-- NOTE: Not currently used.
function export.catboiler(frame)
	local SUBPAGENAME = mw.title.getCurrentTitle().subpageText
	local params = {
		[1] = {},
	}
	local args = m_para.process(frame:getParent().args, params)

	local function get_pos()
		local pos = rmatch(SUBPAGENAME, "^Hindi.- ([^ ]*)s ")
		if not pos then
			pos = rmatch(SUBPAGENAME, "^Hindi.- ([^ ]*)s$")
		end
		if not pos then
			error("Invalid category name, should be e.g. \"Hindi verbs with ...\" or \"Hindi ... verbs\"")
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
	while true do
		if args[1] then
			maintext = "~ " .. args[1]
			pos = get_pos()
			break
		end

		error("Unrecognized Hindi verb category name")
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

-- Externally callable function to parse and conjugate a verb given user-specified arguments.
-- Return value is WORD_SPEC, an object where the conjugated forms are in `WORD_SPEC.forms`
-- for each slot. If there are no values for a slot, the slot key will be missing. The value
-- for a given slot is a list of objects {form=FORM, translit=TRANSLIT, footnotes=FOOTNOTES}.
function export.do_generate_forms(parent_args, pos, from_headword, def)
	local params = {
		[1] = {},
		footnote_impers = {list = true},
		footnote_pers = {list = true},
		title = {},
	}

	if from_headword then
		params["lemma"] = {list = true}
		params["id"] = {}
	end

	local args = m_para.process(parent_args, params)
	local PAGENAME = mw.title.getCurrentTitle().text

	if not args[1] then
		if PAGENAME == "hi-conj" then
			args[1] = def or "करना"
		else
			args[1] = PAGENAME
			-- If pagename has spaces in it, add links around each word
			if args[1]:find(" ") then
				args[1] = "[[" .. rsub(args[1], " ", "]] [[") .. "]]"
			end
		end
	end
	local parse_props = {
		parse_indicator_spec = parse_indicator_spec,
		lang = lang,
		transliterate_respelling = com.transliterate_respelling,
		allow_default_indicator = true,
		allow_blank_lemma = true,
	}
	local alternant_multiword_spec = iut.parse_inflected_text(args[1], parse_props)
	alternant_multiword_spec.title = args.title
	alternant_multiword_spec.footnotes_impers = args.footnote_impers
	alternant_multiword_spec.footnotes_pers = args.footnote_pers
	alternant_multiword_spec.pos = pos or "verbs"
	alternant_multiword_spec.args = args
	com.normalize_all_lemmas(alternant_multiword_spec)
	detect_all_indicator_specs(alternant_multiword_spec)
	local inflect_props = {
		slot_table = all_verb_slots,
		lang = lang,
		inflect_word_spec = conjugate_verb,
		-- Return the variant code that was added to ensure only parallel variants in
		-- multiword expressions like [[हिलना-डुलना]] get generated. See com.add_variant_codes()
		-- for more information.
		get_variants = alternant_multiword_spec.multiword and com.get_variants or nil,
		-- We add links around the generated verbal forms rather than allow the entire multiword
		-- expression to be a link, so ensure that user-specified links get included as well.
		include_user_specified_links = true,
	}
	iut.inflect_multiword_or_alternant_multiword_spec(alternant_multiword_spec, inflect_props)
	compute_categories_and_annotation(alternant_multiword_spec)
	return alternant_multiword_spec
end


-- Entry point for {{hi-conj}}. Template-callable function to parse and conjugate a verb given
-- user-specified arguments and generate a displayable table of the conjugated forms.
function export.show(frame)
	local parent_args = frame:getParent().args
	local alternant_multiword_spec = export.do_generate_forms(parent_args)
	show_forms(alternant_multiword_spec)
	return make_table(alternant_multiword_spec) .. require("Module:utilities").format_categories(alternant_multiword_spec.categories, lang)
end


-- Concatenate all forms of all slots into a single string of the form
-- "SLOT=FORM,FORM,...|SLOT=FORM,FORM,...|...". Each FORM is either a string in Devanagari or
-- (if manual translit is present) a specification of the form "FORM//TRANSLIT" where FORM is the
-- Devanagari representation of the form and TRANSLIT its manual transliteration. Embedded pipe symbols
-- (as might occur in embedded links) are converted to <!>. If INCLUDE_PROPS is given, also include
-- additional properties (currently, none). This is for use by bots.
local function concat_forms(alternant_spec, include_props)
	local ins_text = {}
	for slot, _ in pairs(verb_slots_with_linked) do
		local formtext = iut.concat_forms_in_slot(alternant_spec.forms[slot])
		if formtext then
			table.insert(ins_text, slot .. "=" .. formtext)
		end
	end
	return table.concat(ins_text, "|")
end


-- Template-callable function to parse and conjugate a verb given user-specified arguments and return
-- the forms as a string of the same form as documented in concat_forms() above.
function export.generate_forms(frame)
	local include_props = frame.args["include_props"]
	local parent_args = frame:getParent().args
	local alternant_spec = export.do_generate_forms(parent_args)
	return concat_forms(alternant_spec, include_props)
end

return export
