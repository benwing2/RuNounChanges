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
     masculine singular, but may occasionally be another form if the direct
	 masculine singular is missing.
]=]

local lang = require("Module:languages").getByCode("hi")
local m_table = require("Module:table")
local m_links = require("Module:links")
local m_string_utilities = require("Module:string utilities")
local m_script_utilities = require("Module:script utilities")
local iut = require("Module:User:Benwing2/inflection utilities")
local m_para = require("Module:parameters")
local com = require("Module:User:Benwing2/hi-common")

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
	["पी"] = "पिय",
}

local irreg_polite_imp = {
	["कर"] = {"कीज", "कर"},
	["ले"] = "लीज",
	["दे"] = "दीज",
	["पी"] = "पीज",
	["हो"] = {"हो", "हूज"},
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

local function add_slot_gendered(slot_prefix, tag_suffix, verb_slots)
	verb_slots = verb_slots or verb_slots_pers
	verb_slots[slot_prefix .. "_ms"] = tag_suffix == "-" and "-" or "m|s|" .. tag_suffix
	verb_slots[slot_prefix .. "_mp"] = tag_suffix == "-" and "-" or "m|p|" .. tag_suffix
	verb_slots[slot_prefix .. "_fs"] = tag_suffix == "-" and "-" or "f|s|" .. tag_suffix
	verb_slots[slot_prefix .. "_fp"] = tag_suffix == "-" and "-" or "f|p|" .. tag_suffix
end

local function add_slot_personal(slot_prefix, tag_suffix, verb_slots)
	verb_slots = verb_slots or verb_slots_pers
	for _, num in ipairs({"s", "p"}) do
		for _, pers in ipairs({"1", "2", "3"}) do
			verb_slots[slot_prefix .. "_" .. pers .. num] = tag_suffix == "-" and "-" or pers .. "|" .. num .. "|" .. tag_suffix
		end
	end
end

local function add_slot_gendered_personal(slot_prefix, tag_suffix, verb_slots)
	verb_slots = verb_slots or verb_slots_pers
	for _, num in ipairs({"s", "p"}) do
		for _, pers in ipairs({"1", "2", "3"}) do
			for _, gender in ipairs({"m", "f"}) do
				verb_slots[slot_prefix .. "_" .. pers .. num .. gender] =
					tag_suffix == "-" and "-" or pers .. "|" .. num .. "|" .. gender .. "|" .. tag_suffix
			end
		end
	end
end

add_slot_gendered("inf", "inf|part", verb_slots_impers)
add_slot_gendered("hab", "hab|part", verb_slots_impers)
add_slot_gendered("pfv", "pfv|part", verb_slots_impers)
add_slot_gendered("agent", "prospective//agentive|part", verb_slots_impers)
add_slot_gendered("adj", "-", verb_slots_impers)

add_slot_personal("ind_pres", "pres|ind") -- only for होना
add_slot_gendered("ind_impf", "impf|ind") -- only for होना
add_slot_gendered("ind_perf", "perf|ind")
add_slot_gendered_personal("ind_fut", "fut|ind")
add_slot_gendered_personal("presum", "presumptive")
add_slot_personal("subj", "subj") -- not for होना
add_slot_personal("subj_pres", "pres|subj") -- only for होना
add_slot_personal("subj_fut", "fut|subj") -- only for होना
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


local function tag_text(text)
    return m_script_utilities.tag_text(text, lang)
end


local function term_link(hi, tr)
    return m_links.full_link({term = hi, tr = tr, lang = lang}, "term")
end


local function add(base, stem, translit_stem, slot, ending, footnotes, double_word)
	local function doadd(new_stem, new_translit_stem, new_ending, slot_footnotes)
		new_ending = new_ending or ending
		if new_ending and base.notlast then
			-- If we're not the last verb in a multiword expression, chop off
			-- anything after a space. This is to handle verbs like [[हिलना-डुलना]],
			-- which have e.g. nonaspectual future indicative 1sg masc हिलूँगा-डुलूँगा
			-- but perfective future indicative 1sg masc हिला-डुला हूँगा. Also, as a
			-- special case, the conjunctive form should be e.g. हिल-डुलकर or हिल-डुलके,
			-- effectively with a null ending on the first verb.
			if slot == "conj" then
				new_ending = ""
			else
				new_ending = rsub(new_ending, " .*", "")
			end
		end
		com.add_form(base, new_stem or stem, new_translit_stem or translit_stem, slot,
			new_ending, iut.combine_footnotes(slot_footnotes, footnotes), "link words", double_word)
	end
	if ending then
		if rfind(stem, "[" .. II .. I .. "]$") then
			-- Implement sandhi changes after stem ending in -ī or -i.
			local stem_butlast, translit_stem_butlast =
				com.strip_ending_from_stem(stem, translit_stem, rfind(stem, II .. "$") and II or I)
			local ending_first = usub(ending, 1, 1)
			if ending_first == AA or ending_first == E then
				-- FIXME: Should this happen before all vowels? E.g. 1sg subj सिऊँ or सियूँ?
				local form_stem = stem_butlast .. I
				local form_tr = translit_stem_butlast and translit_stem_butlast .. "i"
				local function link(form_ending)
					return term_link(form_stem .. form_ending, form_tr and form_tr .. lang:transliterate(form_ending))
				end
				local aae_c = "[" .. AA .. E .. "]"
				local y_footnote
				if rfind(ending, "^" .. aae_c .. "$") or rfind(ending, "^" .. aae_c .. " ") then
					y_footnote = {"[the participles " .. link("या") .. " and " .. link("ये") ..
						" can also be spelled without the ''y'': " .. link("आ") .. " and " .. link("ए") .. "]"}
				elseif rfind(slot, "^ind_fut") then
					y_footnote = {"[the forms " .. link("येगा") .. ", " .. link("येंगे") .. ", " ..
						link("येगी") .. " and " .. link("येंगी") .. " can also be spelled without the ''y'': " ..
						link("एगा") .. ", " .. link("एँगे") .. ", " .. link("एगी") .. " and " .. link("एँगी") .. "]"}
				elseif rfind(slot, "^subj") then
					y_footnote = {"[the forms " .. link("ये") .. " and " .. link("यें") ..
					" can also be spelled without the ''y'': " .. link("ए") .. " and " .. link("एँ") .. "]"}
				else
					error("Internal error: Don't know what to do with ending " .. ending .. " for slot " .. slot)
				end
				doadd(form_stem .. "य", form_tr and form_tr .. "y", nil, y_footnote)
				-- doadd(form_stem, form_tr)
				return
			elseif ending_first == II then
				doadd(stem_butlast, translit_stem_butlast)
				return
			elseif rfind(ending_first, "[" .. com.vowels .. "]") then
				doadd(stem_butlast .. I, translit_stem_butlast and translit_stem_butlast .. "i")
				return
			end
		elseif rfind(stem, "[" .. UU .. U .. "]$") then
			-- Implement sandhi changes after stem ending in -ū or -u.
			local stem_butlast, translit_stem_butlast = com.strip_ending_from_stem(stem, translit_stem,
				rfind(stem, UU .. "$") and UU or U)
			local ending_first = usub(ending, 1, 1)
			if ending_first == UU then
				doadd(stem_butlast, translit_stem_butlast)
				return
			elseif rfind(ending_first, "[" .. com.vowels .. "]") then
				doadd(stem_butlast .. U, translit_stem_butlast and translit_stem_butlast .. "u")
				return
			end
		elseif rfind(stem, "[" .. AA .. O .. "आऔ]$") and rfind(ending, "^" .. AA) then
			-- Implement sandhi changes after stem ending in -ā or -o and ending beginning in -ā.
			doadd(stem .. "य", translit_stem and translit_stem .. "y")
			return
		elseif rfind(stem, "[" .. E .. "ए]$") and rfind(ending, "^" .. AA) then
			local function link(form_ending)
				return term_link(stem .. form_ending, translit_stem and translit_stem .. lang:transliterate(form_ending))
			end
			-- Implement sandhi changes after stem ending in -e and ending beginning in -ā.
			local y_footnote = {"[the participle " .. link("या") .. " can also be spelled without the ''y'': " ..
				link("आ") .. "]"}
			doadd(stem .. "य", translit_stem and translit_stem .. "y", nil, y_footnote)
			-- doadd()
			return
		elseif rfind(stem, "%*$") then -- special hacks for ग(य)-, perfective stem of जाना
			local stem_butlast, translit_stem_butlast =
				com.strip_ending_from_stem(stem, translit_stem, "%*")
			if rfind(ending, "^" .. E) then
				-- Use full translit_stem rather than stripping off the final 'a' that should be there
				doadd(stem_butlast, translit_stem, rsub(ending, "^" .. E, "ए"))
				doadd(stem_butlast .. "य", translit_stem and translit_stem .. "y")
			elseif rfind(ending, "^" .. II) then
				doadd(stem_butlast, translit_stem, rsub(ending, "^" .. II, "ई"))
				doadd(stem_butlast .. "य", translit_stem and translit_stem .. "y")
			else
				doadd(stem_butlast .. "य", translit_stem and translit_stem .. "y")
			end
			return
		end
	end

	doadd()
end


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


local function add_conj_personal(base, slot_prefix, stem, translit_stem, s1, s2, s3, p1, p2, p3, footnotes)
	if not stem then
		stem = base.stem
		translit_stem = base.stem_translit
	end
	add(base, stem, translit_stem, slot_prefix .. "_1s", s1, footnotes)
	add(base, stem, translit_stem, slot_prefix .. "_2s", s2, footnotes)
	add(base, stem, translit_stem, slot_prefix .. "_3s", s3, footnotes)
	add(base, stem, translit_stem, slot_prefix .. "_1p", p1, footnotes)
	add(base, stem, translit_stem, slot_prefix .. "_2p", p2, footnotes)
	add(base, stem, translit_stem, slot_prefix .. "_3p", p3, footnotes)
end

local function add_conj_gendered_personal(base, slot_prefix, stem, translit_stem,
	s1m, s2m, s3m, p1m, p2m, p3m, s1f, s2f, s3f, p1f, p2f, p3f, footnotes)
	if not stem then
		stem = base.stem
		translit_stem = base.stem_translit
	end
	add(base, stem, translit_stem, slot_prefix .. "_1sm", s1m, footnotes)
	add(base, stem, translit_stem, slot_prefix .. "_2sm", s2m, footnotes)
	add(base, stem, translit_stem, slot_prefix .. "_3sm", s3m, footnotes)
	add(base, stem, translit_stem, slot_prefix .. "_1pm", p1m, footnotes)
	add(base, stem, translit_stem, slot_prefix .. "_2pm", p2m, footnotes)
	add(base, stem, translit_stem, slot_prefix .. "_3pm", p3m, footnotes)
	add(base, stem, translit_stem, slot_prefix .. "_1sf", s1f, footnotes)
	add(base, stem, translit_stem, slot_prefix .. "_2sf", s2f, footnotes)
	add(base, stem, translit_stem, slot_prefix .. "_3sf", s3f, footnotes)
	add(base, stem, translit_stem, slot_prefix .. "_1pf", p1f, footnotes)
	add(base, stem, translit_stem, slot_prefix .. "_2pf", p2f, footnotes)
	add(base, stem, translit_stem, slot_prefix .. "_3pf", p3f, footnotes)
end

local function handle_derived_slots_and_overrides(base)
	-- No overrides implemented currently.
	-- process_slot_overrides(base)

	-- Compute linked versions of potential lemma slots, for use in {{hi-verb}}.
	-- We substitute the original lemma (before removing links) for forms that
	-- are the same as the lemma, if the original lemma has links.
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
	add(base, base.stem, base.stem_translit, "prog", "ते", nil, "double word")

	-- Participles
	add_conj_gendered(base, "inf", nil, nil, "ना", "ने", "नी", "नीं")
	add_conj_gendered(base, "hab", nil, nil, "ता", "ते", "ती", "तीं")
	add_conj_gendered(base, "pfv", perf, trperf, AA, E, II, IIN)
	add_conj_gendered(base, "agent", nil, nil, "नेवाला", "नेवाले", "नेवाली", "नेवालीं")
	add_conj_gendered(base, "adj", perf, trperf, AA .. " हुआ", E .. " हुए", II .. " हुई", II .. " हुईं")

	-- Non-aspectual
	add_conj_gendered(base, "ind_perf", perf, trperf, AA, E, II, IIN)
	add_conj_gendered_personal(base, "ind_fut", subj, trsubj,
		UUM .. "गा", E .. "गा", E .. "गा", EN .. "गे", O .. "गे", EN .. "गे",
		UUM .. "गी", E .. "गी", E .. "गी", EN .. "गी", O .. "गी", EN .. "गी")
	if base.stem == "हो" then
		add_conj_gendered_personal(base, "ind_fut", "", "",
			"हूँगा", "होगा", "होगा", "होंगे", "होगे", "होंगे",
			"हूँगी", "होगी", "होगी", "होंगी", "होगी", "होंगी")
		add_conj_gendered_personal(base, "presum", "", "",
			"हूँगा", "होगा", "होगा", "होंगे", "होगे", "होंगे",
			"हूँगी", "होगी", "होगी", "होंगी", "होगी", "होंगी")
		add_conj_personal(base, "ind_pres", "", "", "हूँ", "है", "है", "हैं", "हो", "हैं")
		add_conj_gendered(base, "ind_impf", "थ", "th", AA, E, II, IIN)
		add_conj_personal(base, "subj_pres", "", "", "हूँ", "हो", "हो", "हों", "हो", "हों")
		add_conj_personal(base, "subj_fut", nil, nil, UUM, E, E, EN, O, EN)
	else
		add_conj_personal(base, "subj", subj, trsubj, UUM, E, E, EN, O, EN)
	end
	add_conj_gendered(base, "cfact", nil, nil, "ता", "ते", "ती", "तीं")

	-- FIXME! These are likely wrong for देना, लेना, पीना.
	add_conj_personal(base, "imp_pres", nil, nil, nil, "")
	add_conj_personal(base, "imp_pres", subj, trsubj, nil, nil, E, nil, O)
	add_conj_personal(base, "imp_fut", nil, nil, nil, I .. "यो")
	add_conj_personal(base, "imp_fut", subj, trsubj, nil, nil, E)
	add_conj_personal(base, "imp_fut", nil, nil, nil, nil, nil, nil, "ना")
	-- There may be more than one possible polite imperative stem, particularly for
	-- irregular verbs. Loop over them.
	if type(polite_imp) ~= "table" then
		polite_imp = {polite_imp}
	end
	if tr_polite_imp and type(tr_polite_imp) ~= "table" then
		tr_polite_imp = {tr_polite_imp}
	end
	for i, polimp in ipairs(polite_imp) do
		local tr_polimp = tr_polite_imp and tr_polite_imp[i]
		local function link(form_ending)
			return term_link(polimp .. form_ending, tr_polimp and tr_polimp .. lang:transliterate(form_ending))
		end
		local y_footnote = {
			"[the forms " .. link(I .. "ये") .. " and " .. link(I .. "येगा") .. " can also be spelled without the ''y'': " ..
			link(I .. "ए") .. " and " .. link(I .. "एगा") .. "]"}
		add_conj_personal(base, "imp_pres", polimp, tr_polimp, nil, nil, nil, nil, nil, I .. "ये", y_footnote)
		add_conj_personal(base, "imp_fut", polimp, tr_polimp, nil, nil, nil, nil, nil, I .. "येगा", y_footnote)
	end

	-- Habitual
	add_conj_gendered_personal(base, "hab_ind_pres", nil, nil,
		"ता हूँ", "ता है", "ता है", "ते हैं", "ते हो", "ते हैं",
		"ती हूँ", "ती है", "ती है", "ती हैं", "ती हो", "ती हैं")
	add_conj_gendered(base, "hab_ind_past", nil, nil, "ता था", "ते थे", "ती थी", "ती थीं")
	add_conj_gendered_personal(base, "hab_presum", nil, nil,
		"ता हूँगा", "ता होगा", "ता होगा", "ते होंगे", "ते होगे", "ते होंगे",
		"ती हूँगी", "ती होगी", "ती होगी", "ती होंगी", "ती होगी", "ती होंगी")
	add_conj_gendered_personal(base, "hab_subj", nil, nil,
		"ता हूँ", "ता हो", "ता हो", "ते हों", "ते हो", "ते हों",
		"ती हूँ", "ती हो", "ती हो", "ती हों", "ती हो", "ती हों")
	add_conj_gendered(base, "hab_cfact", nil, nil,
		"ता होता", "ते होते", "ती होती", "ती होतीं")

	-- Perfective
	add_conj_gendered_personal(base, "pfv_ind_pres", perf, trperf,
		AA .. " हूँ", AA .. " है", AA .. " है", E .. " हैं", E .. " हो", E .. " हैं",
		II .. " हूँ", II .. " है", II .. " है", II .. " हैं", II .. " हो", II .. " हैं")
	add_conj_gendered(base, "pfv_ind_past", perf, trperf,
		AA .. " था", E .. " थे", II .. " थी", II .. " थीं")
	add_conj_gendered_personal(base, "pfv_ind_fut", perf, trperf,
		AA .. " हूँगा", AA .. " होगा", AA .. " होगा", E .. " होंगे", E .. " होगे", E .. " होंगे",
		II .. " हूँगी", II .. " होगी", II .. " होगी", II .. " होंगी", II .. " होगी", II .. " होंगी")
	add_conj_gendered_personal(base, "pfv_presum", perf, trperf,
		AA .. " हूँगा", AA .. " होगा", AA .. " होगा", E .. " होंगे", E .. " होगे", E .. " होंगे",
		II .. " हूँगी", II .. " होगी", II .. " होगी", II .. " होंगी", II .. " होगी", II .. " होंगी")
	add_conj_gendered_personal(base, "pfv_subj_pres", perf, trperf,
		AA .. " हूँ", AA .. " हो", AA .. " हो", E .. " हों", E .. " हो", E .. " हों",
		II .. " हूँ", II .. " हो", II .. " हो", II .. " हों", II .. " हो", II .. " हों")
	add_conj_gendered_personal(base, "pfv_subj_fut", perf, trperf,
		AA .. " होऊँ", AA .. " होए", AA .. " होए", E .. " होएँ", E .. " होओ", E .. " होएँ",
		II .. " होऊँ", II .. " होए", II .. " होए", II .. " होएँ", II .. " होओ", II .. " होएँ")
	add_conj_gendered(base, "pfv_cfact", perf, trperf, AA .. " होता", E .. " होते", II .. " होती", II .. " होतीं")

	-- Progressive
	add_conj_gendered_personal(base, "prog_ind_pres", nil, nil,
		" रहा हूँ", " रहा है", " रहा है", " रहे हैं", " रहे हो", " रहे हैं",
		" रही हूँ", " रही है", " रही है", " रही हैं", " रही हो", " रही हैं")
	add_conj_gendered(base, "prog_ind_past", nil, nil,
		" रहा था", " रहे थे", " रही थी", " रही थीं")
	add_conj_gendered_personal(base, "prog_ind_fut", nil, nil,
		" रहा हूँगा", " रहा होगा", " रहा होगा", " रहे होंगे", " रहे होगे", " रहे होंगे",
		" रही हूँगी", " रही होगी", " रही होगी", " रही होंगी", " रही होगी", " रही होंगी")
	add_conj_gendered_personal(base, "prog_presum", nil, nil,
		" रहा हूँगा", " रहा होगा", " रहा होगा", " रहे होंगे", " रहे होगे", " रहे होंगे",
		" रही हूँगी", " रही होगी", " रही होगी", " रही होंगी", " रही होगी", " रही होंगी")
	add_conj_gendered_personal(base, "prog_subj_pres", nil, nil,
		" रहा हूँ", " रहा हो", " रहा हो", " रहे हों", " रहे हो", " रहे हों",
		" रही हूँ", " रही हो", " रही हो", " रही हों", " रही हो", " रही हों")
	add_conj_gendered_personal(base, "prog_subj_fut", nil, nil,
		" रहा होऊँ", " रहा होए", " रहा होए", " रहे होएँ", " रहे होओ", " रहे होएँ",
		" रही होऊँ", " रही होए", " रही होए", " रही होएँ", " रही होओ", " रही होएँ")
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
  conj = "CONJ", -- declension, e.g. "normal"
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


local function make_table(alternant_multiword_spec)
	local table_spec_impersonal = [=[
<div class="NavFrame">
<div class="NavHead hi-table-title" style="background: #d9ebff;">Impersonal forms of {inf_raw}</div>
<div class="NavContent">
{\op}| class="inflection-table inflection-hi inflection-verb" data-toggle-category="inflection"
|-
| class="hi-tense-aspect-cell" rowspan=1 colspan=100% | ''Undeclined''
|-
| class="hi-tense-aspect-cell" rowspan=1 colspan=2 | ''Stem''
| colspan="100%" | {stem}
|-
| class="hi-tense-aspect-cell" rowspan=1 colspan=2 | ''Infinitive''
| colspan="100%" | {inf}
|-
| class="hi-tense-aspect-cell" rowspan=1 colspan=2 | ''Oblique Infinitive''
| colspan="100%" | {inf_obl}
|-
| class="hi-tense-aspect-cell" rowspan=1 colspan=2 | ''Conjunctive''
| colspan="100%" | {conj}
|-
| class="hi-tense-aspect-cell" rowspan=1 colspan=2 | ''Progressive''
| colspan="100%" | {prog}
|-
| class="hi-tense-aspect-cell" rowspan=1 colspan=100% | ''Participles''
|-
|- class="hi-part-gender-number-header"
| class="hi-tense-aspect-cell" colspan=2 |
| {m} {s}
| {m} {p}
| {f} {s}
| {f} {p}
|-
| class="hi-tense-aspect-cell" rowspan=1 colspan=2 | ''Infinitive''
| {inf_ms}
| {inf_mp}
| {inf_fs}
| {inf_fp}
|-
| class="hi-tense-aspect-cell" rowspan=1 colspan=2 | ''Habitual''
| {hab_ms}
| {hab_mp}
| {hab_fs}
| {hab_fp}
|-
| class="hi-tense-aspect-cell" rowspan=1 colspan=2 | ''Perfective''
| {pfv_ms}
| {pfv_mp}
| {pfv_fs}
| {pfv_fp}
|-
| class="hi-tense-aspect-cell" rowspan=1 colspan=2 | ''Prospective<br>Agentive''
| {agent_ms}
| {agent_mp}
| {agent_fs}
| {agent_fp}
|-
| class="hi-tense-aspect-cell" rowspan=1 colspan=2 | ''Adjectival''
| {adj_ms}
| {adj_mp}
| {adj_fs}
| {adj_fp}
|{\cl}{notes_clause}</div></div>]=]

	local table_spec_personal = [=[
<div class="NavFrame">
<div class="NavHead hi-table-title" style="background: #d9ebff;">Personal forms of {inf_raw}</div>
<div class="NavContent">
{\op}| class="inflection-table inflection-hi inflection-verb" data-toggle-category="inflection"
|- class="hi-table-header"
| rowspan=2 |
| rowspan=2 |
| rowspan=2 |
| colspan=3 | '''Singular'''
| colspan=3 | '''Plural'''
|- class="hi-table-header"
| '''1<sup>st</sup>'''<br><span lang="hi" class="Deva">[[मैं]]</span>
| '''2<sup>nd</sup>'''<br><span lang="hi" class="Deva">[[तू]]</span>
| '''3<sup>rd</sup>'''<br><span lang="hi" class="Deva">[[यह]]/[[वह]]</span>
| '''1<sup>st</sup>'''<br><span lang="hi" class="Deva">[[हम]]</span>
| '''2<sup>nd</sup>'''<br><span lang="hi" class="Deva">[[तुम]]</span>
| '''3<sup>rd</sup>'''<br><span lang="hi" class="Deva">[[ये]]/[[वे]]/[[आप]]</span>
|-
| class="hi-sec-div" rowspan=1 colspan=100% | ''Non-Aspectual''
{pres_impf_table}| class="hi-tense-aspect-cell" rowspan=2 colspan=1 | {PERF}
| class="hi-mf-cell" | {m}
| colspan=3 | {ind_perf_ms}
| colspan=3 | {ind_perf_mp}
|- class="hi-row-f"
| class="hi-mf-cell" | {f}
| colspan=3 | {ind_perf_fs}
| colspan=3 | {ind_perf_fp}
|- class="hi-row-m"
| class="hi-tense-aspect-cell" rowspan=2 colspan=1 | {FUT}
| class="hi-mf-cell" | {m}
| {ind_fut_1sm}
| {ind_fut_2sm}
| {ind_fut_3sm}
| {ind_fut_1pm}
| {ind_fut_2pm}
| {ind_fut_3pm}
|- class="hi-row-f"
| class="hi-mf-cell" | {f}
| {ind_fut_1sf}
| {ind_fut_2sf}
| {ind_fut_3sf}
| {ind_fut_1pf}
| {ind_fut_2pf}
| {ind_fut_3pf}
{presum_table}{subj_table}
|- class="hi-row-m"
| class="hi-tense-aspect-cell" rowspan=2 colspan=1 | ''Contrafactual''
| class="hi-tense-aspect-cell" rowspan=2 colspan=1 | {PRS_PST}
| class="hi-mf-cell" | {m}
| colspan=3 | {cfact_ms}
| colspan=3 | {cfact_mp}
|- class="hi-row-f"
| class="hi-mf-cell" | {f}
| colspan=3 | {cfact_fs}
| colspan=3 | {cfact_fp}
|-
| class="hi-tense-aspect-cell" rowspan=2 colspan=1 | ''Imperative''
| class="hi-tense-aspect-cell" rowspan=1 colspan=2 | {PRS}
|
| {imp_pres_2s}
| {imp_pres_3s}
|
| {imp_pres_2p}
| {imp_pres_3p}
|-
| class="hi-tense-aspect-cell" rowspan=1 colspan=2 | {FUT}
|
| {imp_fut_2s}
| {imp_fut_3s}
|
| {imp_fut_2p}
| {imp_fut_3p}
|-
| class="hi-sec-div" rowspan=1 colspan=100% | ''Habitual''
|- class="hi-row-m"
| class="hi-tense-aspect-cell" rowspan=4 colspan=1 | ''Indicative''
| class="hi-tense-aspect-cell" rowspan=2 colspan=1 | {PRS}
| class="hi-mf-cell" | {m}
| {hab_ind_pres_1sm}
| {hab_ind_pres_2sm}
| {hab_ind_pres_3sm}
| {hab_ind_pres_1pm}
| {hab_ind_pres_2pm}
| {hab_ind_pres_3pm}
|- class="hi-row-f"
| class="hi-mf-cell" | {f}
| {hab_ind_pres_1sf}
| {hab_ind_pres_2sf}
| {hab_ind_pres_3sf}
| {hab_ind_pres_1pf}
| {hab_ind_pres_2pf}
| {hab_ind_pres_3pf}
|- class="hi-row-m"
| class="hi-tense-aspect-cell" rowspan=2 colspan=1 | {PST}
| class="hi-mf-cell" | {m}
| colspan=3 | {hab_ind_past_ms}
| colspan=3 | {hab_ind_past_mp}
|- class="hi-row-f"
| class="hi-mf-cell" | {f}
| colspan=3 | {hab_ind_past_fs}
| colspan=3 | {hab_ind_past_fp}
|- class="hi-row-m"
| class="hi-tense-aspect-cell" rowspan=2 colspan=1 | ''Presumptive''
| class="hi-tense-aspect-cell" rowspan=2 colspan=1 | {PRS_PST}
| class="hi-mf-cell" | {m}
| {hab_presum_1sm}
| {hab_presum_2sm}
| {hab_presum_3sm}
| {hab_presum_1pm}
| {hab_presum_2pm}
| {hab_presum_3pm}
|- class="hi-row-f"
| class="hi-mf-cell" | {f}
| {hab_presum_1sf}
| {hab_presum_2sf}
| {hab_presum_3sf}
| {hab_presum_1pf}
| {hab_presum_2pf}
| {hab_presum_3pf}
|- class="hi-row-m"
| class="hi-tense-aspect-cell" rowspan=2 colspan=1 | ''Subjunctive''
| class="hi-tense-aspect-cell" rowspan=2 colspan=1 | {PRS}
| class="hi-mf-cell" | {m}
| {hab_subj_1sm}
| {hab_subj_2sm}
| {hab_subj_3sm}
| {hab_subj_1pm}
| {hab_subj_2pm}
| {hab_subj_3pm}
|- class="hi-row-f"
| class="hi-mf-cell" | {f}
| {hab_subj_1sf}
| {hab_subj_2sf}
| {hab_subj_3sf}
| {hab_subj_1pf}
| {hab_subj_2pf}
| {hab_subj_3pf}
|- class="hi-row-m"
| class="hi-tense-aspect-cell" rowspan=2 colspan=1 | ''Contrafactual''
| class="hi-tense-aspect-cell" rowspan=2 colspan=1 | {PRS_PST}
| class="hi-mf-cell" | {m}
| colspan=3 | {hab_cfact_ms}
| colspan=3 | {hab_cfact_mp}
|- class="hi-row-f"
| class="hi-mf-cell" | {f}
| colspan=3 | {hab_cfact_fs}
| colspan=3 | {hab_cfact_fp}
|-
| class="hi-sec-div" rowspan=1 colspan=100% | ''Perfective''
|- class="hi-row-m"
| class="hi-tense-aspect-cell" rowspan=6 colspan=1 | ''Indicative''
| class="hi-tense-aspect-cell" rowspan=2 colspan=1 | {PRS}
| class="hi-mf-cell" | {m}
| {pfv_ind_pres_1sm}
| {pfv_ind_pres_2sm}
| {pfv_ind_pres_3sm}
| {pfv_ind_pres_1pm}
| {pfv_ind_pres_2pm}
| {pfv_ind_pres_3pm}
|- class="hi-row-f"
| class="hi-mf-cell" | {f}
| {pfv_ind_pres_1sf}
| {pfv_ind_pres_2sf}
| {pfv_ind_pres_3sf}
| {pfv_ind_pres_1pf}
| {pfv_ind_pres_2pf}
| {pfv_ind_pres_3pf}
|- class="hi-row-m"
| class="hi-tense-aspect-cell" rowspan=2 colspan=1 | {PST}
| class="hi-mf-cell" | {m}
| colspan=3 | {pfv_ind_past_ms}
| colspan=3 | {pfv_ind_past_mp}
|- class="hi-row-f"
| class="hi-mf-cell" | {f}
| colspan=3 | {pfv_ind_past_fs}
| colspan=3 | {pfv_ind_past_fp}
|- class="hi-row-m"
| class="hi-tense-aspect-cell" rowspan=2 colspan=1 | {FUT}
| class="hi-mf-cell" | {m}
| {pfv_ind_fut_1sm}
| {pfv_ind_fut_2sm}
| {pfv_ind_fut_3sm}
| {pfv_ind_fut_1pm}
| {pfv_ind_fut_2pm}
| {pfv_ind_fut_3pm}
|- class="hi-row-f"
| class="hi-mf-cell" | {f}
| {pfv_ind_fut_1sf}
| {pfv_ind_fut_2sf}
| {pfv_ind_fut_3sf}
| {pfv_ind_fut_1pf}
| {pfv_ind_fut_2pf}
| {pfv_ind_fut_3pf}
|- class="hi-row-m"
| class="hi-tense-aspect-cell" rowspan=2 colspan=1 | ''Presumptive''
| class="hi-tense-aspect-cell" rowspan=2 colspan=1 | {PRS_PST}
| class="hi-mf-cell" | {m}
| {pfv_presum_1sm}
| {pfv_presum_2sm}
| {pfv_presum_3sm}
| {pfv_presum_1pm}
| {pfv_presum_2pm}
| {pfv_presum_3pm}
|- class="hi-row-f"
| class="hi-mf-cell" | {f}
| {pfv_presum_1sf}
| {pfv_presum_2sf}
| {pfv_presum_3sf}
| {pfv_presum_1pf}
| {pfv_presum_2pf}
| {pfv_presum_3pf}
|- class="hi-row-m"
| class="hi-tense-aspect-cell" rowspan=4 colspan=1 | ''Subjunctive''
| class="hi-tense-aspect-cell" rowspan=2 colspan=1 | {PRS}
| class="hi-mf-cell" | {m}
| {pfv_subj_pres_1sm}
| {pfv_subj_pres_2sm}
| {pfv_subj_pres_3sm}
| {pfv_subj_pres_1pm}
| {pfv_subj_pres_2pm}
| {pfv_subj_pres_3pm}
|- class="hi-row-f"
| class="hi-mf-cell" | {f}
| {pfv_subj_pres_1sf}
| {pfv_subj_pres_2sf}
| {pfv_subj_pres_3sf}
| {pfv_subj_pres_1pf}
| {pfv_subj_pres_2pf}
| {pfv_subj_pres_3pf}
|- class="hi-row-m"
| class="hi-tense-aspect-cell" rowspan=2 colspan=1 | {FUT}
| class="hi-mf-cell" | {m}
| {pfv_subj_fut_1sm}
| {pfv_subj_fut_2sm}
| {pfv_subj_fut_3sm}
| {pfv_subj_fut_1pm}
| {pfv_subj_fut_2pm}
| {pfv_subj_fut_3pm}
|- class="hi-row-f"
| class="hi-mf-cell" | {f}
| {pfv_subj_fut_1sf}
| {pfv_subj_fut_2sf}
| {pfv_subj_fut_3sf}
| {pfv_subj_fut_1pf}
| {pfv_subj_fut_2pf}
| {pfv_subj_fut_3pf}
|- class="hi-row-m"
| class="hi-tense-aspect-cell" rowspan=2 colspan=1 | ''Contrafactual''
| class="hi-tense-aspect-cell" rowspan=2 colspan=1 | {PRS_PST}
| class="hi-mf-cell" | {m}
| colspan=3 | {pfv_cfact_ms}
| colspan=3 | {pfv_cfact_mp}
|- class="hi-row-f"
| class="hi-mf-cell" | {f}
| colspan=3 | {pfv_cfact_fs}
| colspan=3 | {pfv_cfact_fp}
|-
| class="hi-sec-div" rowspan=1 colspan=100% | ''Progressive''
|- class="hi-row-m"
| class="hi-tense-aspect-cell" rowspan=6 colspan=1 | ''Indicative''
| class="hi-tense-aspect-cell" rowspan=2 colspan=1 | {PRS}
| class="hi-mf-cell" | {m}
| {prog_ind_pres_1sm}
| {prog_ind_pres_2sm}
| {prog_ind_pres_3sm}
| {prog_ind_pres_1pm}
| {prog_ind_pres_2pm}
| {prog_ind_pres_3pm}
|- class="hi-row-f"
| class="hi-mf-cell" | {f}
| {prog_ind_pres_1sf}
| {prog_ind_pres_2sf}
| {prog_ind_pres_3sf}
| {prog_ind_pres_1pf}
| {prog_ind_pres_2pf}
| {prog_ind_pres_3pf}
|- class="hi-row-m"
| class="hi-tense-aspect-cell" rowspan=2 colspan=1 | {PST}
| class="hi-mf-cell" | {m}
| colspan=3 | {prog_ind_past_ms}
| colspan=3 | {prog_ind_past_mp}
|- class="hi-row-f"
| class="hi-mf-cell" | {f}
| colspan=3 | {prog_ind_past_fs}
| colspan=3 | {prog_ind_past_fp}
|- class="hi-row-m"
| class="hi-tense-aspect-cell" rowspan=2 colspan=1 | {FUT}
| class="hi-mf-cell" | {m}
| {prog_ind_fut_1sm}
| {prog_ind_fut_2sm}
| {prog_ind_fut_3sm}
| {prog_ind_fut_1pm}
| {prog_ind_fut_2pm}
| {prog_ind_fut_3pm}
|- class="hi-row-f"
| class="hi-mf-cell" | {f}
| {prog_ind_fut_1sf}
| {prog_ind_fut_2sf}
| {prog_ind_fut_3sf}
| {prog_ind_fut_1pf}
| {prog_ind_fut_2pf}
| {prog_ind_fut_3pf}
|- class="hi-row-m"
| class="hi-tense-aspect-cell" rowspan=2 colspan=1 | ''Presumptive''
| class="hi-tense-aspect-cell" rowspan=2 colspan=1 | {PRS_PST}
| class="hi-mf-cell" | {m}
| {prog_presum_1sm}
| {prog_presum_2sm}
| {prog_presum_3sm}
| {prog_presum_1pm}
| {prog_presum_2pm}
| {prog_presum_3pm}
|- class="hi-row-f"
| class="hi-mf-cell" | {f}
| {prog_presum_1sf}
| {prog_presum_2sf}
| {prog_presum_3sf}
| {prog_presum_1pf}
| {prog_presum_2pf}
| {prog_presum_3pf}
|- class="hi-row-m"
| class="hi-tense-aspect-cell" rowspan=4 colspan=1 | ''Subjunctive''
| class="hi-tense-aspect-cell" rowspan=2 colspan=1 | {PRS}
| class="hi-mf-cell" | {m}
| {prog_subj_pres_1sm}
| {prog_subj_pres_2sm}
| {prog_subj_pres_3sm}
| {prog_subj_pres_1pm}
| {prog_subj_pres_2pm}
| {prog_subj_pres_3pm}
|- class="hi-row-f"
| class="hi-mf-cell" | {f}
| {prog_subj_pres_1sf}
| {prog_subj_pres_2sf}
| {prog_subj_pres_3sf}
| {prog_subj_pres_1pf}
| {prog_subj_pres_2pf}
| {prog_subj_pres_3pf}
|- class="hi-row-m"
| class="hi-tense-aspect-cell" rowspan=2 colspan=1 | {FUT}
| class="hi-mf-cell" | {m}
| {prog_subj_fut_1sm}
| {prog_subj_fut_2sm}
| {prog_subj_fut_3sm}
| {prog_subj_fut_1pm}
| {prog_subj_fut_2pm}
| {prog_subj_fut_3pm}
|- class="hi-row-f"
| class="hi-mf-cell" | {f}
| {prog_subj_fut_1sf}
| {prog_subj_fut_2sf}
| {prog_subj_fut_3sf}
| {prog_subj_fut_1pf}
| {prog_subj_fut_2pf}
| {prog_subj_fut_3pf}
|- class="hi-row-m"
| class="hi-tense-aspect-cell" rowspan=2 colspan=1 | ''Contrafactual''
| class="hi-tense-aspect-cell" rowspan=2 colspan=1 | {PRS_PST}
| class="hi-mf-cell" | {m}
| colspan=3 | {prog_cfact_ms}
| colspan=3 | {prog_cfact_mp}
|- class="hi-row-f"
| class="hi-mf-cell" | {f}
| colspan=3 | {prog_cfact_fs}
| colspan=3 | {prog_cfact_fp}
|{\cl}{notes_clause}</div></div>]=]

	local pres_impf_table = [=[
|-
| class="hi-tense-aspect-cell" rowspan=7 colspan=1 | ''Indicative''
| class="hi-tense-aspect-cell" rowspan=1 colspan=2 | {PRS}
| {ind_pres_1s}
| {ind_pres_2s}
| {ind_pres_3s}
| {ind_pres_1p}
| {ind_pres_2p}
| {ind_pres_3p}
|- class="hi-row-m"
| class="hi-tense-aspect-cell" rowspan=2 colspan=1 | {IMPF}
| class="hi-mf-cell" | {m}
| colspan=3 | {ind_impf_ms}
| colspan=3 | {ind_impf_mp}
|- class="hi-row-f"
| class="hi-mf-cell" | {f}
| colspan=3 | {ind_impf_fs}
| colspan=3 | {ind_impf_fp}
|- class="hi-row-m"
]=]

	local pres_impf_table_missing = [=[
|- class="hi-row-m"
| class="hi-tense-aspect-cell" rowspan=4 colspan=1 | ''Indicative''
]=]

	local presum_table = [=[
|- class="hi-row-m"
| class="hi-tense-aspect-cell" rowspan=2 colspan=1 | ''Presumptive''
| class="hi-tense-aspect-cell" rowspan=2 colspan=1 | {PRS_PST}
| class="hi-mf-cell" | {m}
| {presum_1sm}
| {presum_2sm}
| {presum_3sm}
| {presum_1pm}
| {presum_2pm}
| {presum_3pm}
|- class="hi-row-f"
| class="hi-mf-cell" | {f}
| {presum_1sf}
| {presum_2sf}
| {presum_3sf}
| {presum_1pf}
| {presum_2pf}
| {presum_3pf}
]=]

	local combined_subj = [=[
|-
| class="hi-tense-aspect-cell" rowspan=1 colspan=1 | ''Subjunctive''
| class="hi-tense-aspect-cell" rowspan=1 colspan=2 | {PRS_FUT}
| {subj_1s}
| {subj_2s}
| {subj_3s}
| {subj_1p}
| {subj_2p}
| {subj_3p}]=]

	local split_subj = [=[
|-
| class="hi-tense-aspect-cell" rowspan=2 colspan=1 | ''Subjunctive''
| class="hi-tense-aspect-cell" rowspan=1 colspan=2 | {PRS}
| {subj_pres_1s}
| {subj_pres_2s}
| {subj_pres_3s}
| {subj_pres_1p}
| {subj_pres_2p}
| {subj_pres_3p}
|-
| class="hi-tense-aspect-cell" rowspan=1 colspan=2 | {FUT}
| {subj_fut_1s}
| {subj_fut_2s}
| {subj_fut_3s}
| {subj_fut_1p}
| {subj_fut_2p}
| {subj_fut_3p}]=]

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
	forms.s = make_gender_abbr("singular number", "s")
	forms.p = make_gender_abbr("plural number", "p")
	forms.PERF = make_tense_aspect_abbr("Perfect", "PERF")
	forms.IMPF = make_tense_aspect_abbr("Imperfect", "IMPF")
	forms.PST = make_tense_aspect_abbr("Past", "PST")
	forms.FUT = make_tense_aspect_abbr("Future", "FUT")
	forms.PRS = make_tense_aspect_abbr("Present", "PRS")
	forms.PRS_FUT = make_tense_aspect_abbr("Present/Future", "PRS<br />FUT")
	forms.PRS_PST = make_tense_aspect_abbr("Present/Past", "PRS<br />PST")
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
	local formatted_table_pers = m_string_utilities.format(table_spec_personal, forms)

	-- Concatenate both.
	return require("Module:TemplateStyles")("Module:User:Benwing2/hi-verb/style.css") .. formatted_table_impers .. formatted_table_pers
end


-- Implementation of template 'hi-verb cat'.
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
-- additional properties (currently, g= for headword genders). This is for use by bots.
local function concat_forms(alternant_spec, include_props)
	local ins_text = {}
	for slot, _ in pairs(verb_slots_with_linked) do
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


-- Template-callable function to parse and conjugate a verb given user-specified arguments and return
-- the forms as a string of the same form as documented in concat_forms() above.
function export.generate_forms(frame)
	local include_props = frame.args["include_props"]
	local parent_args = frame:getParent().args
	local alternant_spec = export.do_generate_forms(parent_args)
	return concat_forms(alternant_spec, include_props)
end

return export
