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
local EM = E .. M
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
	["जा"] = "गय",
	["ले"] = "ली",
	["दे"] = "दी",
	["हो"] = "हु",
}

local irreg_subj = {
	["दे"] = "द",
	["ले"] = "ल",
	["पी"] = "पिय",
}

local irreg_fam_imp = {
	["ले"] = "लो",
	["दे"] = "दो",
	["पी"] = "पियो",
}

local irreg_polite_imp = {
	["कर"] = "कीज",
	["ले"] = "लीज",
	["दे"] = "दीज",
	["पी"] = "पीज",
}

local verb_slots = {
	stem = "stem",
	conj = "conj|form",
	prog = "prog|form",
}

local function add_slot_gendered(slot_prefix, tag_suffix)
	verb_slots[slot_prefix .. "_ms"] = tag_suffix == "-" and "-" or "dir|m|s|" .. tag_suffix
	verb_slots[slot_prefix .. "_mp"] = tag_suffix == "-" and "-" or "obl|m|s|" .. tag_suffix .. "|;|m|p|" .. tag_suffix
	verb_slots[slot_prefix .. "_fs"] = tag_suffix == "-" and "-" or "dir|f|s|" .. tag_suffix
	verb_slots[slot_prefix .. "_fp"] = tag_suffix == "-" and "-" or "obl|f|s|" .. tag_suffix .. "|;|f|p|" .. tag_suffix
end

local function add_slot_personal(slot_prefix, tag_suffix)
	for _, num in ipairs({"s", "p"}) do
		for _, pers in ipairs({"1", "2", "3"}) do
			verb_slots[slot_prefix .. "_" .. pers .. num] = tag_suffix == "-" and "-" or pers .. "|" .. num .. "|" .. tag_suffix
		end
	end
end

local function add_slot_gendered_personal(slot_prefix, tag_suffix)
	for _, num in ipairs({"s", "p"}) do
		for _, pers in ipairs({"1", "2", "3"}) do
			for _, gender in ipairs({"m", "f"}) do
				verb_slots[slot_prefix .. "_" .. pers .. num .. gender] =
					tag_suffix == "-" and "-" or pers .. "|" .. num .. "|" .. gender .. "|" .. tag_suffix
			end
		end
	end
end

add_slot_gendered("inf", "inf")
add_slot_gendered("hab", "hab|part")
add_slot_gendered("pfv", "pfv|part")
add_slot_gendered("agent", "agentive|part")
add_slot_gendered("adj", "-")

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

local verb_slots_with_linked = m_table.shallowcopy(verb_slots)
verb_slots_with_linked["inf_ms_linked"] = verb_slots["inf_ms"]


local function tag_text(text)
    return m_script_utilities.tag_text(text, lang)
end


local function add(base, stem, translit_stem, slot, ending, footnotes)
	local function doadd(new_stem, new_translit_stem, new_ending)
		com.add_form(base, new_stem or stem, new_translit_stem or translit_stem, slot, new_ending or ending, footnotes, "link words")
	end
	if ending then
		if rfind(stem, "[" .. II .. I .. "]$") then
			-- Implement sandhi changes after stem ending in -ī or -i.
			local stem_butlast, translit_stem_butlast = com.strip_ending_from_stem(stem, translit_stem,
				rfind(stem, II .. "$") and II or I)
			local ending_first = usub(ending, 1, 1)
			if ending_first == AA or ending_first == E then
				-- FIXME: Should this happen before all vowels? E.g. 1sg subj सिऊँ or सियूँ?
				doadd(stem_butlast .. I, translit_stem_butlast .. "i")
				doadd(stem_butlast .. I .. "य", translit_stem_butlast .. "iy")
				return
			elseif ending_first == II then
				doadd(stem_butlast, translit_stem_butlast)
				return
			elseif rfind(ending_first, "[" .. com.vowels .. "]") then
				doadd(stem_butlast .. I, translit_stem_butlast .. "i")
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
				doadd(stem_butlast .. U, translit_stem_butlast .. "u")
				return
			end
		elseif rfind(stem, "[" .. AA .. O .. "आऔ]$") and rfind(ending, "^" .. AA) then
			-- Implement sandhi changes after stem ending in -ā or -o.
			doadd(stem .. "य", translit_stem .. "y")
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
		iut.insert_forms(base.forms, slot .. "_linked", iut.map_forms(base.forms[slot], function(form)
			if form == base.orig_lemma_no_links and rfind(base.orig_lemma, "%[%[") then
				return base.orig_lemma
			else
				return form
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
			local trstem = lang:transliterate(stem)
			return stem, trstem
		else
			return base.stem, base.stem_translit
		end
	end

	local perf, trperf = fetch_irreg(irreg_perf)
	local subj, trsubj = fetch_irreg(irreg_subj)
	local polite_imp, tr_polite_imp = fetch_irreg(irreg_polite_imp)

	-- Undeclined forms
	add(base, base.stem, base.stem_translit, "stem", "")
	add(base, base.stem, base.stem_translit, "conj", "कर")
	add(base, base.stem, base.stem_translit, "conj", "के")
	add(base, base.stem, base.stem_translit, "prog", "ते")

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
			"हूँगा", "होगा ", "होगा", "होंगे", "होगे", "होंगे", 
			"हूँगी", "होगी ", "होगी ", "होंगी", "होगी", "होंगी")
		add_conj_gendered_personal(base, "presum", "", "",
			"हूँगा", "होगा ", "होगा", "होंगे", "होगे", "होंगे", 
			"हूँगी", "होगी ", "होगी ", "होंगी", "होगी", "होंगी")
		add_conj_personal(base, "ind_pres", "", "", "हूँ", "है", "है", "हैं", "हो", "हैं")
		add_conj_gendered(base, "ind_impf", "थ", "th", AA, E, II, IIN)
		add_conj_personal(base, "subj_pres", "", "", "हूँ", "हो", "हो", "हों", "हो", "हों")
		add_conj_personal(base, "subj_fut", nil, nil, UUM, E, E, EM, O, EM)
	else
		add_conj_personal(base, "subj", subj, trsubj, UUM, E, E, EM, O, EM)
	end
	add_conj_gendered(base, "cfact", nil, nil, "ता", "ते", "ती", "तीं")
	local defective_imp = subj ~= base.stem -- लेना, देना, पीना
	if defective_imp then
		add_conj_personal(base, "imp_pres", nil, nil, nil, "")
		add_conj_personal(base, "imp_pres", subj, trsubj, nil, nil, nil, nil, O)
	else
		add_conj_personal(base, "imp_pres", nil, nil, nil, "", E, nil, O, EM)
	end
	add_conj_personal(base, "imp_pres", polite_imp, tr_polite_imp, nil, nil, nil, nil, nil, I .. "ये")
	add_conj_personal(base, "imp_pres", polite_imp, tr_polite_imp, nil, nil, nil, nil, nil, I .. "ए")
	if polite_imp ~= base.stem then
		add_conj_personal(base, "imp_pres", polite_imp, tr_polite_imp, nil, nil, nil, nil, nil, I .. "येगा")
		add_conj_personal(base, "imp_pres", polite_imp, tr_polite_imp, nil, nil, nil, nil, nil, I .. "एगा")
	end
	if not defective_imp then
		add_conj_personal(base, "imp_fut", nil, nil, nil, I .. "यो", E, nil, "ना", EM)
		add_conj_personal(base, "imp_fut", nil, nil, nil, nil, nil, nil, nil, I .. "येगा")
		add_conj_personal(base, "imp_fut", nil, nil, nil, nil, nil, nil, nil, I .. "एगा")
	end

	-- Habitual
	add_conj_gendered_personal(base, "hab_ind_pres", nil, nil,
		"ता हूँ", "ता है", "ता है", "ते हैं", "ते हो", "ते हैं",
		"ती हूँ", "ती है", "ती है", "ती हैं", "ती हो", "ती हैं")
	add_conj_gendered(base, "hab_ind_past", nil, nil, "ता था", "ते थे", "ती थी", "ती थीं")
	add_conj_gendered_personal(base, "hab_presum", nil, nil,
		"ता हूँगा", "ता होगा", "ता होगा", "ते होंगे", "ते होगे", "ते होंगे",
		"ती हूँगी", "ती होगी", "ती होगी", "ती होंगीं", "ती होगी", "ती होंगी")
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


conjs["invar"] = function(base)
	error("Implement me")
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
  invar = true, -- may be missing
  unmarked = true, -- may be missing
  iya = true, -- may be missing
  plstem = "PLSTEM", -- may be missing
  pl_phon_stem = "PLSTEM-PHONETIC-RESPELLING", -- as specified by the user; may be missing
  pl_translit_stem = "PLSTEM-TRANSLIT", -- translit of pl_phon_stem (if present) or plstem; may be missing

  -- The following additional fields are added by other functions:
  orig_lemma = "ORIGINAL-LEMMA", -- as given by the user or taken from pagename
  orig_lemma_no_links = "ORIGINAL-LEMMA-NO-LINKS", -- links removed
  lemma = "LEMMA", -- `orig_lemma_no_links`, converted to singular form if plural
  phon_lemma = "LEMMA-PHONETIC-RESPELLING", -- as specified by the user; may be missing
  lemma_translit = "LEMMA-TRANSLIT", -- translit of phon_lemma (if present) or lemma
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
			local part = dot_separated_group[1]
			if part == "" then
				if #dot_separated_group == 1 then
					error("Blank indicator: '" .. inside .. "'")
				end
				base.footnotes = fetch_footnotes(dot_separated_group)
			elseif #dot_separated_group > 1 then
				error("Footnotes only allowed with slot overrides or by themselves: '" .. table.concat(dot_separated_group) .. "'")
			elseif part == "$" then
				if base.invar then
					error("Can't specify '$' twice: '" .. inside .. "'")
				end
				base.invar = true
			else
				error("Unrecognized indicator '" .. part .. "': '" .. inside .. "'")
			end
		end
	end
	return base
end


local function set_defaults_and_check_bad_indicators(base)
	-- Nothing here currently.
end


local function detect_indicator_spec(base)
	set_defaults_and_check_bad_indicators(base)
	if base.invar then
		base.conj = "invar"
	else
		base.conj = "normal"
	end
	base.stem, base.stem_translit = com.strip_ending(base, "ना")
end


local function detect_all_indicator_specs(alternant_multiword_spec)
	local is_multiword = #alternant_multiword_spec.alternant_or_word_specs > 1
	iut.map_word_specs(alternant_multiword_spec, function(base)
		detect_indicator_spec(base)
	end)
end


local function conjugate_verb(base)
	if not conjs[base.conj] then
		error("Internal error: Unrecognized conjugation type '" .. base.conj .. "'")
	end
	conjs[base.conj](base)
	handle_derived_slots_and_overrides(base)
end


local function compute_category_and_desc(base)
	local props = conjprops[base.conj]
	if props then
		return props.cat, props.desc
	end
	local rest, gender = rmatch(base.conj, "^(.+)%-([mf])$")
	if not gender then
		error("Internal error: Don't know how to parse conj '" .. base.conj .. "'")
	end
	local cat_gender = gender == "m" and "masculine" or "feminine"
	local desc_gender = gender == "m" and "masc" or "fem"
	local ind, stem = rmatch(rest, "^(ind%-)(.*)$")
	if not ind then
		stem = rest
	end
	stem = rsub(stem, "n$", TILDE)
	if ind then
		return cat_gender .. " independent " .. stem .. "-stem ~", desc_gender .. " ind " .. stem .. "-stem"
	else
		return cat_gender .. " " .. stem .. "-stem ~", desc_gender .. " " .. stem .. "-stem"
	end
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
			if lang:transliterate(base.lemma) ~= base.lemma_translit then
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
	local lemmas = alternant_multiword_spec.forms.dir_s or alternant_multiword_spec.forms.dir_p or {}
	local props = {
		lang = lang,
	}
	iut.show_forms_with_translit(alternant_multiword_spec.forms, lemmas,
		verb_slots_with_linked, props, alternant_multiword_spec.footnotes,
		"allow footnote symbols")
end


local function make_table(alternant_multiword_spec)
	local table_spec_impersonal = [=[
{| class="inflection-table vsSwitcher" data-toggle-category="inflection" style="background:#F9F9F9; text-align:center; border: 1px solid #CCC; min-width: 20em"
|- style="background: #d9ebff;"
! class="vsToggleElement" style="text-align: left;" colspan="100%" | Impersonal forms of {inf_raw}
|- class="vsHide"
| style="width: 5em; background: #E6F2FF;" rowspan=1 colspan=100% | ''Undeclined''
|- class="vsHide"
| style="width: 5em; background: #E6F2FF;" rowspan=1 colspan=2 | ''Stem''
| colspan="100%" | {stem}
|- class="vsHide"
| style="width: 5em; background: #E6F2FF;" rowspan=1 colspan=2 | ''Conjunctive''
| colspan="100%" | {conj}
|- class="vsHide"
| style="width: 5em; background: #E6F2FF;" rowspan=1 colspan=2 | ''Progressive''
| colspan="100%" | {prog}
|- class="vsHide"
| style="width: 5em; background: #E6F2FF;" rowspan=1 colspan=100% | ''Participles''
|- class="vsHide"
|- class="vsHide"
| style="background:#E6F2FF" colspan=2 |
| style="background: #D4D4D4;" | {m} {s}
| style="background: #D4D4D4;" | {m} {p}
| style="background: #D4D4D4;" | {f} {s}
| style="background: #D4D4D4;" | {f} {p}
|- class="vsHide"
| style="width: 5em; background: #E6F2FF;" rowspan=1 colspan=2 | ''Infinitive''
| {inf_ms}
| {inf_mp}
| {inf_fs}
| {inf_fp}
|- class="vsHide"
| style="width: 5em; background: #E6F2FF;" rowspan=1 colspan=2 | ''Habitual''
| {hab_ms}
| {hab_mp}
| {hab_fs}
| {hab_fp}
|- class="vsHide"
| style="width: 5em; background: #E6F2FF;" rowspan=1 colspan=2 | ''Perfective''
| {pfv_ms}
| {pfv_mp}
| {pfv_fs}
| {pfv_fp}
|- class="vsHide"
| style="width: 5em; background: #E6F2FF;" rowspan=1 colspan=2 | ''Prospective<br>Agentive''
| {agent_ms}
| {agent_mp}
| {agent_fs}
| {agent_fp}
|- class="vsHide"
| style="width: 5em; background: #E6F2FF;" rowspan=1 colspan=2 | ''Adjectival''
| {adj_ms}
| {adj_mp}
| {adj_fs}
| {adj_fp}
|{\cl}
]=]

	local table_spec_personal = [=[
{| class="inflection-table vsSwitcher" data-toggle-category="inflection" style="background:#F9F9F9; text-align:center; border: 1px solid #CCC; min-width: 20em"
|- style="background: #d9ebff;"
! class="vsToggleElement" style="text-align: left;" colspan="100%" | Personal forms of {inf_raw}
|- class="vsHide" style="background: #DFEEFF;"
| rowspan=2 |
| rowspan=2 |
| rowspan=2 |
| colspan=3 | '''Singular'''
| colspan=3 | '''Plural'''
|- class="vsHide" style="background: #DFEEFF;"
| '''1<sup>st</sup>'''<br><span lang="hi" class="Deva">[[मैं]]</span>
| '''2<sup>nd</sup>'''<br><span lang="hi" class="Deva">[[तू]]</span>
| '''3<sup>rd</sup>'''<br><span lang="hi" class="Deva">[[यह]]/[[वह]]</span>
| '''1<sup>st</sup>'''<br><span lang="hi" class="Deva">[[हम]]</span>
| '''2<sup>nd</sup>'''<br><span lang="hi" class="Deva">[[तुम]]</span>
| '''3<sup>rd</sup>'''<br><span lang="hi" class="Deva">[[ये]]/[[वे]]/[[आप]]</span>
|- class="vsHide"
| style="width: 5em; background: #E6F2FF;" rowspan=1 colspan=100% | ''Non-Aspectual''
|- class="vsHide"
{pres_impf_table}| style="width: 5em; background: #E6F2FF;" rowspan=2 colspan=1 | {PERF}
| style="width: 1em; background: #D4D4D4;" | {m}
| colspan=3 | {ind_perf_ms}
| colspan=3 | {ind_perf_mp}
|- class="vsHide"
| style="width: 1em; background: #D4D4D4;" | {f}
| colspan=3 | {ind_perf_fs}
| colspan=3 | {ind_perf_fp}
|- class="vsHide"
| style="width: 5em; background: #E6F2FF;" rowspan=2 colspan=1 | {FUT}
| style="width: 1em; background: #D4D4D4;" | {m}
| {ind_fut_1sm}
| {ind_fut_2sm}
| {ind_fut_3sm}
| {ind_fut_1pm}
| {ind_fut_2pm}
| {ind_fut_3pm}
|- class="vsHide"
| style="width: 1em; background: #D4D4D4;" | {f}
| {ind_fut_1sf}
| {ind_fut_2sf}
| {ind_fut_3sf}
| {ind_fut_1pf}
| {ind_fut_2pf}
| {ind_fut_3pf}
{subj_table}
|- class="vsHide"
| style="width: 5em; background: #E6F2FF;" rowspan=2 colspan=1 | ''Contrafactual''
| style="width: 5em; background: #E6F2FF;" rowspan=2 colspan=1 | {PRS_PST}
| style="width: 1em; background: #D4D4D4;" | {m}
| colspan=3 | {cfact_ms}
| colspan=3 | {cfact_mp}
|- class="vsHide"
| style="width: 1em; background: #D4D4D4;" | {f}
| colspan=3 | {cfact_fs}
| colspan=3 | {cfact_fp}
|- class="vsHide"
| style="width: 5em; background: #E6F2FF;" rowspan=2 colspan=1 | ''Imperative''
| style="width: 5em; background: #E6F2FF;" rowspan=1 colspan=2 | {PRS}
|
| {imp_pres_2s}
| {imp_pres_3s}
|
| {imp_pres_2p}
| {imp_pres_3p}
{imp_fut_table}|- class="vsHide"
| style="width: 5em; background: #E6F2FF;" rowspan=1 colspan=100% | ''Habitual''
|- class="vsHide"
| style="width: 5em; background: #E6F2FF;" rowspan=4 colspan=1 | ''Indicative''
| style="width: 5em; background: #E6F2FF;" rowspan=2 colspan=1 | {PRS}
| style="width: 1em; background: #D4D4D4;" | {m}
| {hab_ind_pres_1sm}
| {hab_ind_pres_2sm}
| {hab_ind_pres_3sm}
| {hab_ind_pres_1pm}
| {hab_ind_pres_2pm}
| {hab_ind_pres_3pm}
|- class="vsHide"
| style="width: 1em; background: #D4D4D4;" | {f}
| {hab_ind_pres_1sf}
| {hab_ind_pres_2sf}
| {hab_ind_pres_3sf}
| {hab_ind_pres_1pf}
| {hab_ind_pres_2pf}
| {hab_ind_pres_3pf}
|- class="vsHide"
| style="width: 5em; background: #E6F2FF;" rowspan=2 colspan=1 | {PST}
| style="width: 1em; background: #D4D4D4;" | {m}
| colspan=3 | {hab_ind_past_ms}
| colspan=3 | {hab_ind_past_mp}
|- class="vsHide"
| style="width: 1em; background: #D4D4D4;" | {f}
| colspan=3 | {hab_ind_past_fs}
| colspan=3 | {hab_ind_past_fp}
|- class="vsHide"
| style="width: 5em; background: #E6F2FF;" rowspan=2 colspan=1 | ''Presumptive''
| style="width: 5em; background: #E6F2FF;" rowspan=2 colspan=1 | {PRS_PST}
| style="width: 1em; background: #D4D4D4;" | {m}
| {hab_presum_1sm}
| {hab_presum_2sm}
| {hab_presum_3sm}
| {hab_presum_1pm}
| {hab_presum_2pm}
| {hab_presum_3pm}
|- class="vsHide"
| style="width: 1em; background: #D4D4D4;" | {f}
| {hab_presum_1sf}
| {hab_presum_2sf}
| {hab_presum_3sf}
| {hab_presum_1pf}
| {hab_presum_2pf}
| {hab_presum_3pf}
|- class="vsHide"
| style="width: 5em; background: #E6F2FF;" rowspan=2 colspan=1 | ''Subjunctive''
| style="width: 5em; background: #E6F2FF;" rowspan=2 colspan=1 | {PRS}
| style="width: 1em; background: #D4D4D4;" | {m}
| {hab_subj_1sm}
| {hab_subj_2sm}
| {hab_subj_3sm}
| {hab_subj_1pm}
| {hab_subj_2pm}
| {hab_subj_3pm}
|- class="vsHide"
| style="width: 1em; background: #D4D4D4;" | {f}
| {hab_subj_1sf}
| {hab_subj_2sf}
| {hab_subj_3sf}
| {hab_subj_1pf}
| {hab_subj_2pf}
| {hab_subj_3pf}
|- class="vsHide"
| style="width: 5em; background: #E6F2FF;" rowspan=2 colspan=1 | ''Contrafactual''
| style="width: 5em; background: #E6F2FF;" rowspan=2 colspan=1 | {PRS_PST}
| style="width: 1em; background: #D4D4D4;" | {m}
| colspan=3 | {hab_cfact_ms}
| colspan=3 | {hab_cfact_mp}
|- class="vsHide"
| style="width: 1em; background: #D4D4D4;" | {f}
| colspan=3 | {hab_cfact_fs}
| colspan=3 | {hab_cfact_fp}
|- class="vsHide"
| style="width: 5em; background: #E6F2FF;" rowspan=1 colspan=100% | ''Perfective''
|- class="vsHide"
| style="width: 5em; background: #E6F2FF;" rowspan=6 colspan=1 | ''Indicative''
| style="width: 5em; background: #E6F2FF;" rowspan=2 colspan=1 | {PRS}
| style="width: 1em; background: #D4D4D4;" | {m}
| {pfv_ind_pres_1sm}
| {pfv_ind_pres_2sm}
| {pfv_ind_pres_3sm}
| {pfv_ind_pres_1pm}
| {pfv_ind_pres_2pm}
| {pfv_ind_pres_3pm}
|- class="vsHide"
| style="width: 1em; background: #D4D4D4;" | {f}
| {pfv_ind_pres_1sf}
| {pfv_ind_pres_2sf}
| {pfv_ind_pres_3sf}
| {pfv_ind_pres_1pf}
| {pfv_ind_pres_2pf}
| {pfv_ind_pres_3pf}
|- class="vsHide"
| style="width: 5em; background: #E6F2FF;" rowspan=2 colspan=1 | {PST}
| style="width: 1em; background: #D4D4D4;" | {m}
| colspan=3 | {pfv_ind_past_ms}
| colspan=3 | {pfv_ind_past_mp}
|- class="vsHide"
| style="width: 1em; background: #D4D4D4;" | {f}
| colspan=3 | {pfv_ind_past_fs}
| colspan=3 | {pfv_ind_past_fp}
|- class="vsHide"
| style="width: 5em; background: #E6F2FF;" rowspan=2 colspan=1 | {FUT}
| style="width: 1em; background: #D4D4D4;" | {m}
| {pfv_ind_fut_1sm}
| {pfv_ind_fut_2sm}
| {pfv_ind_fut_3sm}
| {pfv_ind_fut_1pm}
| {pfv_ind_fut_2pm}
| {pfv_ind_fut_3pm}
|- class="vsHide"
| style="width: 1em; background: #D4D4D4;" | {f}
| {pfv_ind_fut_1sf}
| {pfv_ind_fut_2sf}
| {pfv_ind_fut_3sf}
| {pfv_ind_fut_1pf}
| {pfv_ind_fut_2pf}
| {pfv_ind_fut_3pf}
|- class="vsHide"
| style="width: 5em; background: #E6F2FF;" rowspan=2 colspan=1 | ''Presumptive''
| style="width: 5em; background: #E6F2FF;" rowspan=2 colspan=1 | {PRS_PST}
| style="width: 1em; background: #D4D4D4;" | {m}
| {pfv_presum_1sm}
| {pfv_presum_2sm}
| {pfv_presum_3sm}
| {pfv_presum_1pm}
| {pfv_presum_2pm}
| {pfv_presum_3pm}
|- class="vsHide"
| style="width: 1em; background: #D4D4D4;" | {f}
| {pfv_presum_1sf}
| {pfv_presum_2sf}
| {pfv_presum_3sf}
| {pfv_presum_1pf}
| {pfv_presum_2pf}
| {pfv_presum_3pf}
|- class="vsHide"
| style="width: 5em; background: #E6F2FF;" rowspan=4 colspan=1 | ''Subjunctive''
| style="width: 5em; background: #E6F2FF;" rowspan=2 colspan=1 | {PRS}
| style="width: 1em; background: #D4D4D4;" | {m}
| {pfv_subj_pres_1sm}
| {pfv_subj_pres_2sm}
| {pfv_subj_pres_3sm}
| {pfv_subj_pres_1pm}
| {pfv_subj_pres_2pm}
| {pfv_subj_pres_3pm}
|- class="vsHide"
| style="width: 1em; background: #D4D4D4;" | {f}
| {pfv_subj_pres_1sf}
| {pfv_subj_pres_2sf}
| {pfv_subj_pres_3sf}
| {pfv_subj_pres_1pf}
| {pfv_subj_pres_2pf}
| {pfv_subj_pres_3pf}
|- class="vsHide"
| style="width: 5em; background: #E6F2FF;" rowspan=2 colspan=1 | {FUT}
| style="width: 1em; background: #D4D4D4;" | {m}
| {pfv_subj_fut_1sm}
| {pfv_subj_fut_2sm}
| {pfv_subj_fut_3sm}
| {pfv_subj_fut_1pm}
| {pfv_subj_fut_2pm}
| {pfv_subj_fut_3pm}
|- class="vsHide"
| style="width: 1em; background: #D4D4D4;" | {f}
| {pfv_subj_fut_1sf}
| {pfv_subj_fut_2sf}
| {pfv_subj_fut_3sf}
| {pfv_subj_fut_1pf}
| {pfv_subj_fut_2pf}
| {pfv_subj_fut_3pf}
|- class="vsHide"
| style="width: 5em; background: #E6F2FF;" rowspan=2 colspan=1 | ''Contrafactual''
| style="width: 5em; background: #E6F2FF;" rowspan=2 colspan=1 | {PRS_PST}
| style="width: 1em; background: #D4D4D4;" | {m}
| colspan=3 | {pfv_cfact_ms}
| colspan=3 | {pfv_cfact_mp}
|- class="vsHide"
| style="width: 1em; background: #D4D4D4;" | {f}
| colspan=3 | {pfv_cfact_fs}
| colspan=3 | {pfv_cfact_fp}
|- class="vsHide"
| style="width: 5em; background: #E6F2FF;" rowspan=1 colspan=100% | ''Progressive''
|- class="vsHide"
| style="width: 5em; background: #E6F2FF;" rowspan=6 colspan=1 | ''Indicative''
| style="width: 5em; background: #E6F2FF;" rowspan=2 colspan=1 | {PRS}
| style="width: 1em; background: #D4D4D4;" | {m}
| {prog_ind_pres_1sm}
| {prog_ind_pres_2sm}
| {prog_ind_pres_3sm}
| {prog_ind_pres_1pm}
| {prog_ind_pres_2pm}
| {prog_ind_pres_3pm}
|- class="vsHide"
| style="width: 1em; background: #D4D4D4;" | {f}
| {prog_ind_pres_1sf}
| {prog_ind_pres_2sf}
| {prog_ind_pres_3sf}
| {prog_ind_pres_1pf}
| {prog_ind_pres_2pf}
| {prog_ind_pres_3pf}
|- class="vsHide"
| style="width: 5em; background: #E6F2FF;" rowspan=2 colspan=1 | {PST}
| style="width: 1em; background: #D4D4D4;" | {m}
| colspan=3 | {prog_ind_past_ms}
| colspan=3 | {prog_ind_past_mp}
|- class="vsHide"
| style="width: 1em; background: #D4D4D4;" | {f}
| colspan=3 | {prog_ind_past_fs}
| colspan=3 | {prog_ind_past_fp}
|- class="vsHide"
| style="width: 5em; background: #E6F2FF;" rowspan=2 colspan=1 | {FUT}
| style="width: 1em; background: #D4D4D4;" | {m}
| {prog_ind_fut_1sm}
| {prog_ind_fut_2sm}
| {prog_ind_fut_3sm}
| {prog_ind_fut_1pm}
| {prog_ind_fut_2pm}
| {prog_ind_fut_3pm}
|- class="vsHide"
| style="width: 1em; background: #D4D4D4;" | {f}
| {prog_ind_fut_1sf}
| {prog_ind_fut_2sf}
| {prog_ind_fut_3sf}
| {prog_ind_fut_1pf}
| {prog_ind_fut_2pf}
| {prog_ind_fut_3pf}
|- class="vsHide"
| style="width: 5em; background: #E6F2FF;" rowspan=2 colspan=1 | ''Presumptive''
| style="width: 5em; background: #E6F2FF;" rowspan=2 colspan=1 | {PRS_PST}
| style="width: 1em; background: #D4D4D4;" | {m}
| {prog_presum_1sm}
| {prog_presum_2sm}
| {prog_presum_3sm}
| {prog_presum_1pm}
| {prog_presum_2pm}
| {prog_presum_3pm}
|- class="vsHide"
| style="width: 1em; background: #D4D4D4;" | {f}
| {prog_presum_1sf}
| {prog_presum_2sf}
| {prog_presum_3sf}
| {prog_presum_1pf}
| {prog_presum_2pf}
| {prog_presum_3pf}
|- class="vsHide"
| style="width: 5em; background: #E6F2FF;" rowspan=4 colspan=1 | ''Subjunctive''
| style="width: 5em; background: #E6F2FF;" rowspan=2 colspan=1 | {PRS}
| style="width: 1em; background: #D4D4D4;" | {m}
| {prog_subj_pres_1sm}
| {prog_subj_pres_2sm}
| {prog_subj_pres_3sm}
| {prog_subj_pres_1pm}
| {prog_subj_pres_2pm}
| {prog_subj_pres_3pm}
|- class="vsHide"
| style="width: 1em; background: #D4D4D4;" | {f}
| {prog_subj_pres_1sf}
| {prog_subj_pres_2sf}
| {prog_subj_pres_3sf}
| {prog_subj_pres_1pf}
| {prog_subj_pres_2pf}
| {prog_subj_pres_3pf}
|- class="vsHide"
| style="width: 5em; background: #E6F2FF;" rowspan=2 colspan=1 | {FUT}
| style="width: 1em; background: #D4D4D4;" | {m}
| {prog_subj_fut_1sm}
| {prog_subj_fut_2sm}
| {prog_subj_fut_3sm}
| {prog_subj_fut_1pm}
| {prog_subj_fut_2pm}
| {prog_subj_fut_3pm}
|- class="vsHide"
| style="width: 1em; background: #D4D4D4;" | {f}
| {prog_subj_fut_1sf}
| {prog_subj_fut_2sf}
| {prog_subj_fut_3sf}
| {prog_subj_fut_1pf}
| {prog_subj_fut_2pf}
| {prog_subj_fut_3pf}
|- class="vsHide"
| style="width: 5em; background: #E6F2FF;" rowspan=2 colspan=1 | ''Contrafactual''
| style="width: 5em; background: #E6F2FF;" rowspan=2 colspan=1 | {PRS_PST}
| style="width: 1em; background: #D4D4D4;" | {m}
| colspan=3 | {prog_cfact_ms}
| colspan=3 | {prog_cfact_mp}
|- class="vsHide"
| style="width: 1em; background: #D4D4D4;" | {f}
| colspan=3 | {prog_cfact_fs}
| colspan=3 | {prog_cfact_fp}
|{\cl}]=]
	-- FIXME: Figure out how to add notes clause

	local pres_impf_table = [=[
| style="width: 5em; background: #E6F2FF;" rowspan=7 colspan=1 | ''Indicative''
| style="width: 5em; background: #E6F2FF;" rowspan=1 colspan=2 | {PRS}
| {ind_pres_1s}
| {ind_pres_2s}
| {ind_pres_3s}
| {ind_pres_1p}
| {ind_pres_2p}
| {ind_pres_3p}
|- class="vsHide"
| style="width: 5em; background: #E6F2FF;" rowspan=2 colspan=1 | {IMPF}
| style="width: 1em; background: #D4D4D4;" | {m}
| colspan=3 | {ind_impf_ms}
| colspan=3 | {ind_impf_mp}
|- class="vsHide"
| style="width: 1em; background: #D4D4D4;" | {f}
| colspan=3 | {ind_impf_fs}
| colspan=3 | {ind_impf_fp}
|- class="vsHide"
]=]

	local pres_impf_table_missing = [=[
| style="width: 5em; background: #E6F2FF;" rowspan=4 colspan=1 | ''Indicative''
]=]

	local combined_subj = [=[
|- class="vsHide"
| style="width: 5em; background: #E6F2FF;" rowspan=1 colspan=1 | ''Subjunctive''
| style="width: 5em; background: #E6F2FF;" rowspan=1 colspan=2 | {PRS_FUT}
| {subj_1s}
| {subj_2s}
| {subj_3s}
| {subj_1p}
| {subj_2p}
| {subj_3p}]=]

	local split_subj = [=[
|- class="vsHide"
| style="width: 5em; background: #E6F2FF;" rowspan=2 colspan=1 | ''Subjunctive''
| style="width: 5em; background: #E6F2FF;" rowspan=1 colspan=2 | {PRS}
| {subj_pres_1s}
| {subj_pres_2s}
| {subj_pres_3s}
| {subj_pres_1p}
| {subj_pres_2p}
| {subj_pres_3p}
|- class="vsHide"
| style="width: 5em; background: #E6F2FF;" rowspan=1 colspan=2 | {FUT}
| {subj_fut_1s}
| {subj_fut_2s}
| {subj_fut_3s}
| {subj_fut_1p}
| {subj_fut_2p}
| {subj_fut_3p}]=]

	local imp_fut_table = [=[
|- class="vsHide"
| style="width: 5em; background: #E6F2FF;" rowspan=1 colspan=2 | {FUT}
|
| {imp_fut_2s}
| {imp_fut_3s}
|
| {imp_fut_2p}
| {imp_fut_3p}
]=]

	local notes_template = [===[
<div style="width:100%;text-align:left;background:#d9ebff">
<div style="display:inline-block;text-align:left;padding-left:1em;padding-right:1em">
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

	local table_spec = table_spec_impersonal .. table_spec_personal
	forms.notes_clause = forms.footnote ~= "" and
		m_string_utilities.format(notes_template, forms) or ""
	if forms.ind_pres_1s ~= "—" then
		forms.subj_table = m_string_utilities.format(split_subj, forms)
		forms.pres_impf_table = m_string_utilities.format(pres_impf_table, forms)
	else
		forms.subj_table = m_string_utilities.format(combined_subj, forms)
		forms.pres_impf_table = pres_impf_table_missing
	end
	if forms.imp_fut_2sg ~= "—" then
		forms.imp_fut_table = m_string_utilities.format(imp_fut_table, forms)
	else
		forms.imp_fut_table = ""
	end
	return m_string_utilities.format(table_spec, forms)
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
	local stem, gender, stress, ending
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
		[1] = {required = true, default = "करना"},
		footnote = {list = true},
		title = {},
	}

	if from_headword then
		params["lemma"] = {list = true}
		params["id"] = {}
	end

	local args = m_para.process(parent_args, params)
	local alternant_multiword_spec = iut.parse_alternant_multiword_spec(args[1], parse_indicator_spec,
		"allow default indicator", "allow blank lemma")
	alternant_multiword_spec.title = args.title
	alternant_multiword_spec.footnotes = args.footnote
	alternant_multiword_spec.pos = pos or "verbs"
	alternant_multiword_spec.args = args
	com.normalize_all_lemmas(alternant_multiword_spec)
	detect_all_indicator_specs(alternant_multiword_spec)
	local inflect_props = {
		skip_slot = function(slot) return false end,
		slot_table = verb_slots_with_linked,
		lang = lang,
		inflect_word_spec = conjugate_verb,
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
