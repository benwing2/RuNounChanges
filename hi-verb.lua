local export = {}


--[=[

Authorship: Ben Wing <benwing2>

]=]

--[=[

TERMINOLOGY:

-- "slot" = A particular combination of case/number.
	 Example slot names for nouns are "dir_s" (direct singular) and
	 "voc_p" (vocative plural). Each slot is filled with zero or more forms.

-- "form" = The declined Hindi form representing the value of a given slot.

-- "lemma" = The dictionary form of a given Hindi term. Generally the direct
     masculine singular, but may occasionally be another form if the direct
	 masculine singular is missing.
]=]

local lang = require("Module:languages").getByCode("hi")
local m_table = require("Module:table")
local m_links = require("Module:links")
local m_string_utilities = require("Module:string utilities")
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


local verb_slots = {
	stem = "stem",
	conj = "conj|form",
	prog = "prog|form",
}

local function add_slot_gendered(slot_prefix, tag_suffix)
	verb_slots[slot_prefix .. "_m_s"] = tag_suffix == "-" and "-" or "dir|m|s|" .. tag_suffix
	verb_slots[slot_prefix .. "_m_p"] = tag_suffix == "-" and "-" or "obl|m|s|" .. tag_suffix .. "|;|m|p|" .. tag_suffix
	verb_slots[slot_prefix .. "_f_s"] = tag_suffix == "-" and "-" or "dir|f|s|" .. tag_suffix
	verb_slots[slot_prefix .. "_f_p"] = tag_suffix == "-" and "-" or "obl|f|s|" .. tag_suffix .. "|;|f|p|" .. tag_suffix
end

local function add_slot_personal(slot_prefix, tag_suffix)
	for num in ipairs({"s", "p"}) do
		for pers in ipairs({"1", "2", "3"}) do
			verb_slots[slot_prefix .. "_" .. pers .. num] = tag_suffix == "-" and "-" or pers .. "|" .. num .. "|" .. tag_suffix
		end
	end
end

local function add_slot_gendered_personal(slot_prefix, tag_suffix)
	for num in ipairs({"s", "p"}) do
		for pers in ipairs({"1", "2", "3"}) do
			for gender in ipairs({"m", "f"}) do
				verb_slots[slot_prefix .. "_" .. pers .. num .. gender] =
					tag_suffix == "-" and "-" or pers .. "|" .. num .. "|" .. gender .. "|" .. tag_suffix
			end
		end
	end
end

add_slot_gendered("inf", "inf")
add_slot_gendered("hab", "hab|part")
add_slot_gendered("pfv", "pfv|part")
add_slot_gendered("agent", "agent|part")
add_slot_gendered("adj", "-")

add_slot_gendered("ind_perf", "pf|ind")
add_slot_gendered_personal("ind_fut", "fut|ind")
add_slot_personal("subj", "subj")
add_slot_gendered("cfact", "cfact")
add_slot_personal("imp_pres", "pres|imp")
add_slot_personal("imp_fut", "fut|imp")

add_slot_gendered_personal("hab_ind_pres", "-")
add_slot_gendered("hab_ind_past", "-")
add_slot_gendered_personal("hab_presumptive", "-")
add_slot_gendered_personal("hab_subj", "-")
add_slot_gendered("hab_cfact", "-")

for _, mood in ipairs({"pfv", "prog"}) do
	add_slot_gendered_personal(mood .. "_ind_pres", "-")
	add_slot_gendered(mood .. "_ind_past", "-")
	add_slot_gendered_personal(mood .. "_ind_fut", "-")
	add_slot_gendered_personal(mood .. "_presumptive", "-")
	add_slot_gendered_personal(mood .. "_subj_pres", "-")
	add_slot_gendered_personal(mood .. "_subj_fut", "-")
	add_slot_gendered(mood .. "_cfact", "-")
end

local adjective_slots_with_linked = m_table.shallowcopy(adjective_slots)
adjective_slots_with_linked["inf_m_s_linked"] = adjective_slots["inf_m_s"]


local function skip_slot(number, slot)
	return false
end


local function add(base, stem, translit_stem, slot, ending, footnotes)
	if skip_slot(base.number, slot) then
		return
	end

	com.add_form(base, stem, translit_stem, slot, ending, footnotes)
end


local function add_conj_gendered(base, slot_prefix, stem, translit_stem, m_s, m_p, f_s, f_p, footnotes)
	if not stem then
		stem = base.stem
		translit_stem = base.stem_translit
	end
	add(base, stem, translit_stem, slot_prefix .. "_m_s", m_s, footnotes)
	add(base, stem, translit_stem, slot_prefix .. "_m_p", m_p, footnotes)
	add(base, stem, translit_stem, slot_prefix .. "_f_s", f_s, footnotes)
	add(base, stem, translit_stem, slot_prefix .. "_f_p", f_p, footnotes)
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

local function process_slot_overrides(base)
	for slot, overrides in pairs(base.overrides) do
		if skip_slot(base.number, slot) then
			error("Override specified for invalid slot '" .. slot .. "' due to '" .. base.number .. "' number restriction")
		end
		base.forms[slot] = nil
		for _, override in ipairs(overrides) do
			for _, value in ipairs(override.values) do
				local form = value.form
				local tr = com.transliterate_respelling(value.phon_form)
				local combined_notes = iut.combine_footnotes(base.footnotes, value.footnotes)
				assert(override.full)
				if form ~= "" then
					iut.insert_form(base.forms, slot, {form = form, translit = tr, footnotes = combined_notes})
				end
			end
		end
	end
end


local function handle_derived_slots_and_overrides(base)
	process_slot_overrides(base)

	-- Compute linked versions of potential lemma slots, for use in {{hi-noun}}.
	-- We substitute the original lemma (before removing links) for forms that
	-- are the same as the lemma, if the original lemma has links.
	for _, slot in ipairs({"dir_s", "dir_p"}) do
		iut.insert_forms(base.forms, slot .. "_linked", iut.map_forms(base.forms[slot], function(form)
			if form == base.orig_lemma_no_links and rfind(base.orig_lemma, "%[%[") then
				return base.orig_lemma
			else
				return form
			end
		end))
	end
end


local function conjugate(base)
	-- Undeclined forms
	add(base, base.stem, base.stem_translit, "stem", "")
	add(base, base.stem, base.stem_translit, "conj", "कर")
	add(base, base.stem, base.stem_translit, "prog", "ते")

	-- Participles
	add_conj_gendered(base, "inf", nil, nil, "ना", "ने", "नी", "नीं")
	add_conj_gendered(base, "hab", nil, nil, "ता", "ते", "ती", "तीं")
	add_conj_gendered(base, "pfv", perf, trperf, AA, E, II, IIN)
	add_conj_gendered(base, "agent", nil, nil, "नेवाला", "नेवाले", "नेवाली", "नेवालीं")
	add_conj_gendered(base, "adj", perf, trperf, AA .. " हुआ", E .. " हुए", II .. " हुई", II .. " हुईं")

	-- Non-aspectual
	add_conj_gendered(base, "ind_perf", perf, trperf, AA, E, II, IIN)
	add_conj_gendered_personal("ind_fut", nil, nil,
		UUM .. "गा", E .. "गा", E .. "गा", EN .. "गे", O .. "गे", EN .. "गे",
		UUM .. "गी", E .. "गी", E .. "गी", EN .. "गी", O .. "गी", EN .. "गी")
	add_conj_personal("subj", nil, nil, UUM, E, E, EM, O, EM)
	add_conj_gendered("cfact", nil, nil, "ता", "ते", "ती", "तीं")
	add_conj_personal("imp_pres", nil, nil, nil, "", E, nil, O, I .. "ए")
	add_conj_personal("imp_fut", nil, nil, nil, I .. "यो", E, nil, "ना", I .. "एगा")

	-- Habitual
	add_conj_gendered_personal("hab_ind_pres", nil, nil,
		"ता हूँ", "ता है", "ता है", "ते हैं", "ते हो", "ते हैं",
		"ती हूँ", "ती है", "ती है", "ती हैं", "ती हो", "ती हैं")
	add_conj_gendered("hab_ind_past", nil, nil, "ता था", "ते थे", "ती थी", "ती थीं")
	add_conj_gendered_personal("hab_presumptive", nil, nil,
		"ता हूँगा", "ता होगा", "ता होगा", "ते होंगे", "ते होगे", "ते होंगे",
		"ती हूँगी", "ती होगी", "ती होगी", "ती होंगीं", "ती होगी", "ती होंगी")
	add_conj_gendered_personal("hab_subj", nil, nil,
		"ता हूँ", "ता हो", "ता हो", "ते हों", "ते हो", "ते हों",
		"ती हूँ", "ती हो", "ती हो", "ती हों", "ती हो", "ती हों")
	add_conj_gendered("hab_cfact", nil, nil,
		"ता होता", "ता होता", "ता होता", "ते होते", "ते होते", "ते होते",
		"ती होती", "ती होती", "ती होती", "ती होतीं", "ती होती", "ती होतीं")

	-- Perfective
	add_conj_gendered_personal("pfv_ind_pres", perf, trperf, 
		AA .. " हूँ", AA .. " है", AA .. " है", E .. " हैं", E .. " हो", E .. " हैं",
		II .. " हूँ", II .. " है", II .. " है", II .. " हैं", II .. " हो", II .. " हैं")
	add_conj_gendered_personal("pfv_ind_past", perf, trperf, 
		AA .. " था", AA .. " था", AA .. " था", E .. " थे", E .. " थे", E .. " थे",
		II .. " थी", II .. " थी", II .. " थी", II .. " थी", II .. " थी", II .. " थी")
	add_conj_gendered_personal("pfv_ind_fut", perf, trperf, 
		AA .. " हूँगा", AA .. " होगा", AA .. " होगा", E .. " होंगे", E .. " होगे", E .. " होंगे",
		II .. " हूँगी", II .. " होगी", II .. " होगी", II .. " होंगी", II .. " होगी", II .. " होंगी")
	add_conj_gendered_personal("pfv_presumptive", perf, trperf, 
		AA .. " हूँगा", AA .. " होगा", AA .. " होगा", E .. " होंगे", E .. " होगे", E .. " होंगे",
		II .. " हूँगी", II .. " होगी", II .. " होगी", II .. " होंगी", II .. " होगी", II .. " होंगी")
	add_conj_gendered_personal("pfv_subj_pres", perf, trperf, 
		AA .. " हूँ", AA .. " हो", AA .. " हो", E .. " हों", E .. " हो", E .. " हों",
		II .. " हूँ", II .. " हो", II .. " हो", II .. " हों", II .. " हो", II .. " हों")
	add_conj_gendered_personal("pfv_subj_fut", perf, trperf, 
		AA .. " होऊँ", AA .. " होए", AA .. " होए", E .. " होएँ", E .. " होओ", E .. " होएँ",
		II .. " होऊँ", II .. " होए", II .. " होए", II .. " होएँ", II .. " होओ", II .. " होएँ")
	add_conj_gendered("pfv_cfact", perf, trperf, AA .. " होता", E .. " होते", II .. " होती", II .. " होतीं")

	-- Progressive
	add_conj_gendered_personal("prog_ind_pres", nil, nil, 
		" रहा हूँ", " रहा है", " रहा है", " रहे हैं", " रहे हो", " रहे हैं",
		" रही हूँ", " रही है", " रही है", " रही हैं", " रही हो", " रही हैं")
	add_conj_gendered_personal("prog_ind_past", nil, nil, 
		" रहा था", " रहा था", " रहा था", " रहे थे", " रहे थे", " रहे थे",
		" रही थी", " रही थी", " रही थी", " रही थी", " रही थी", " रही थी")
	add_conj_gendered_personal("prog_ind_fut", nil, nil, 
		" रहा हूँगा", " रहा होगा", " रहा होगा", " रहे होंगे", " रहे होगे", " रहे होंगे",
		" रही हूँगी", " रही होगी", " रही होगी", " रही होंगी", " रही होगी", " रही होंगी")
	add_conj_gendered_personal("prog_presumptive", nil, nil, 
		" रहा हूँगा", " रहा होगा", " रहा होगा", " रहे होंगे", " रहे होगे", " रहे होंगे",
		" रही हूँगी", " रही होगी", " रही होगी", " रही होंगी", " रही होगी", " रही होंगी")
	add_conj_gendered_personal("prog_subj_pres", nil, nil, 
		" रहा हूँ", " रहा हो", " रहा हो", " रहे हों", " रहे हो", " रहे हों",
		" रही हूँ", " रही हो", " रही हो", " रही हों", " रही हो", " रही हों")
	add_conj_gendered_personal("prog_subj_fut", nil, nil, 
		" रहा होऊँ", " रहा होए", " रहा होए", " रहे होएँ", " रहे होओ", " रहे होएँ",
		" रही होऊँ", " रही होए", " रही होए", " रही होएँ", " रही होओ", " रही होएँ")
	add_conj_gendered("prog_cfact", nil, nil, " रहा होता", " रहे होते", " रही होती", " रही होतीं")
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
Parse a single override spec and return two values: the slot the override applies to,
and an object describing the override spec. The input is actually a list where the footnotes have been separated out. For example, given the spec 'oblpl:हज़ारों:हज़ारहा[rare]',
the input will be a list {"oblpl:हज़ारों:हज़ारहा", "[rare]", ""}. The object returned for
this example looks like this:

{
  full = true,
  values = {
    {
      form = "हज़ारों"
    },
    {
      form = "हज़ारहा",
      footnotes = {"[rare]"}
    }
  }
}
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
	else
		error("Suffix overrides not currently supported: " .. part)
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
			value.form, value.phon_form = com.split_term_respelling(form)
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
  indecl = true, -- may be missing
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
  decl = "DECL", -- declension, e.g. "ind-ūn-f"
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
			elseif part == "+" then
				if base.adj then
					error("Can't specify '+' twice: '" .. inside .. "'")
				end
				base.adj = true
				error("Adjectival declensions not implemented yet")
			elseif part == "$" then
				if base.indecl then
					error("Can't specify '$' twice: '" .. inside .. "'")
				end
				base.indecl = true
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
			elseif rfind(part, "^plstem:") then
				if base.plstem then
					error("Can't specify plural stem twice: '" .. inside .. "'")
				end
				base.plstem, base.pl_phon_stem = com.split_term_respelling(rsub(part, "^plstem:", ""))
				base.pl_translit_stem = com.transliterate_respelling(base.pl_phon_stem) or lang:transliterate(base.plstem)
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
	if base.iya then
		if base.adj then
			error("Can't specify both '+' and 'iya'")
		end
		if base.gender == "M" then
			error("Can't specify M gender with 'iyā' indicator")
		end
		if not rfind(base.lemma, I .. "याँ?$") then
			error("With 'iyā' indicator, lemma must end in " .. I .. "या or " .. I .. "याँ: " .. base.lemma)
		end
		base.gender = "F"
	end
	if base.unmarked then
		if base.adj then
			error("Can't specify both '+' and 'unmarked'")
		end
		if base.iya then
			error("Can't specify both 'iya' and 'unmarked'")
		end
		if base.gender == "F" then
			error("Can't specify F gender with 'unmarked' indicator")
		end
		base.gender = "M"
	end
	if rfind(base.lemma, "[" .. O .. H .. R .. "]$") then
		if base.gender == "F" then
			error("Can't specify F gender with lemma ending in " .. O .. ", " .. H .. " or " .. R .. ": " .. base.lemma)
		end
		base.gender = "M"
	end
	if not base.gender and not base.indecl then
		error("Unless lemma is in " .. O .. ", " .. H .. " or " .. R .. " or 'iya', 'unmarked' or '$' specified, gender must be given: " .. base.lemma)
	end
	if base.adj and base.indecl then
		error("Can't specify both '+' and '$' on the same lemma " .. base.lemma)
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
		determine_declension(base)
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
			is_nounal = not word_specs[i].adj and not word_specs[i].indecl
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


-- Find the first noun in a multiword expression and set alternant_multiword_spec.first_noun
-- to the index of that noun. Also find the first adjective and set alternant_multiword_spec.first_adj
-- similarly. If there is a first noun, we use its properties to determine the overall expression's
-- properties; otherwise we use the first adjective's properties, otherwise the first word's properties.
-- If the "word" located this way is not an alternant spec, we just use its properties directly, otherwise
-- we use the properties of the first noun (or failing that the first adjective, or failing that the
-- first word) in each alternative alternant in the alternant spec. For this reason, we need to set the
-- the .first_noun of and .first_adj of each multiword expression embedded in the first noun alternant spec,
-- and the .first_adj of each multiword expression in each adjective alternant spec leading up to the
-- first noun alternant spec.
local function determine_noun_status(alternant_multiword_spec)
	for i, alternant_or_word_spec in ipairs(alternant_multiword_spec.alternant_or_word_specs) do
		if alternant_or_word_spec.alternants then
			local alternant_type
			for _, multiword_spec in ipairs(alternant_or_word_spec.alternants) do
				for j, word_spec in ipairs(multiword_spec.word_specs) do
					if not word_spec.indecl then
						if not word_spec.adj then
							multiword_spec.first_noun = j
							alternant_type = "noun"
							break
						elseif not multiword_spec.first_adj then
							multiword_spec.first_adj = j
							if not alternant_type then
								alternant_type = "adj"
							end
						end
					end
				end
			end
			if alternant_type == "noun" then
				alternant_multiword_spec.first_noun = i
				return
			elseif alternant_type == "adj" and not alternant_multiword_spec.first_adj then
				alternant_multiword_spec.first_adj = i
			end
		elseif not alternant_or_word_spec.indecl then
			if not alternant_or_word_spec.adj then
				alternant_multiword_spec.first_noun = i
				return
			elseif not alternant_multiword_spec.first_adj then
				alternant_multiword_spec.first_adj = i
			end
		end
	end
end


local function decline_noun(base)
	if not decls[base.decl] then
		error("Internal error: Unrecognized declension type '" .. base.decl .. "'")
	end
	decls[base.decl](base)
	handle_derived_slots_and_overrides(base)
end


local function process_manual_overrides(forms, args, number)
	local params_to_slots_map =
		number == "sg" and input_params_to_slots_sg or
		number == "pl" and input_params_to_slots_pl or
		input_params_to_slots_both
	for param, slot in pairs(params_to_slots_map) do
		if args[param] then
			forms[slot] = nil
			if args[param] ~= "-" and args[param] ~= "—" then
				for _, form in ipairs(rsplit(args[param], "%s*,%s*")) do
					local hi, phon = com.split_term_respelling(form)
					local tr = phon and com.transliterate_respelling(phon) or nil
					iut.insert_form(forms, slot, {form=form, translit=tr})
				end
			end
		end
	end
end


local function compute_category_and_desc(base)
	local props = declprops[base.decl]
	if props then
		return props.cat, props.desc
	end
	local rest, gender = rmatch(base.decl, "^(.+)%-([mf])$")
	if not gender then
		error("Internal error: Don't know how to parse decl '" .. base.decl .. "'")
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


-- Compute the categories to add the noun to, as well as the annotation to display in the
-- declension title bar. We combine the code to do these functions as both categories and
-- title bar contain similar information.
local function compute_categories_and_annotation(alternant_multiword_spec)
	local cats = {}
	local function insert(cattype)
		cattype = rsub(cattype, "~", alternant_multiword_spec.pos)
		m_table.insertIfNot(cats, "Hindi " .. cattype)
	end
	if alternant_multiword_spec.number == "sg" then
		insert("uncountable ~")
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
		local decldescs = {}
		local function do_word_spec(base)
			local cat, desc = compute_category_and_desc(base)
			insert(cat)
			m_table.insertIfNot(decldescs, desc)
			if base.plstem then
				insert("~ with irregular plural stem")
			end
			if lang:transliterate(base.lemma) ~= base.lemma_translit then
				insert("~ with phonetic respelling")
			end
		end
		local key_entry = alternant_multiword_spec.first_noun or alternant_multiword_spec.first_adj or 1
		if #alternant_multiword_spec.alternant_or_word_specs >= key_entry then
			local alternant_or_word_spec = alternant_multiword_spec.alternant_or_word_specs[key_entry]
			if alternant_or_word_spec.alternants then
				for _, multiword_spec in ipairs(alternant_or_word_spec.alternants) do
					key_entry = multiword_spec.first_noun or multiword_spec.first_adj or 1
					if #multiword_spec.word_specs >= key_entry then
						do_word_spec(multiword_spec.word_specs[key_entry])
					end
				end
			else
				do_word_spec(alternant_or_word_spec)
			end
		end
		if alternant_multiword_spec.number ~= "both" then
			table.insert(annparts, alternant_multiword_spec.number == "sg" and "sg-only" or "pl-only")
		end
		if #decldescs == 0 then
			table.insert(annparts, "indecl")
		else
			table.insert(annparts, table.concat(decldescs, " // "))
		end
		alternant_multiword_spec.annotation = table.concat(annparts, " ")
		if #decldescs > 1 then
			insert("~ with multiple declensions")
		end
	end
	alternant_multiword_spec.categories = cats
end


local function show_forms(alternant_multiword_spec)
	local lemmas = alternant_multiword_spec.forms.dir_s or alternant_multiword_spec.forms.dir_p or {}
	local props = {
		lang = lang,
	}
	iut.show_forms_with_translit(alternant_multiword_spec.forms, lemmas,
		noun_slots_with_linked, props, alternant_multiword_spec.footnotes,
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
!style="background:#eff7ff" | direct
| {dir_s}
| {dir_p}
|-
!style="background:#eff7ff" | oblique
| {obl_s}
| {obl_p}
|-
!style="background:#eff7ff" | vocative
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
!style="background:#eff7ff" | direct
| {dir_s}
|-
!style="background:#eff7ff" | oblique
| {obl_s}
|-
!style="background:#eff7ff" | vocative
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
!style="background:#eff7ff" | direct
| {dir_p}
|-
!style="background:#eff7ff" | oblique
| {obl_p}
|-
!style="background:#eff7ff" | vocative
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
		if base.gender == "M" then
			m_table.insertIfNot(genders, "m" .. number)
		elseif base.gender == "F" then
			m_table.insertIfNot(genders, "f" .. number)
		else
			error("Internal error: Unrecognized gender '" ..
				(base.gender or "nil") .. "'")
		end
	end)
	return genders
end


-- Implementation of template 'hi-noun cat'.
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

		local gender, stem
		gender, stem, pos = rmatch(SUBPAGENAME, "^Hindi ([a-z]+ine) (independent unmarked [^ %-]*%-stem) (.*)s$")
		if not gender then
			gender, stem, pos = rmatch(SUBPAGENAME, "^Hindi ([a-z]+ine) (independent [^ %-]*%-stem) (.*)s$")
		end
		if not gender then
			gender, stem, pos = rmatch(SUBPAGENAME, "^Hindi ([a-z]+ine) (unmarked [^ %-]*%-stem) (.*)s$")
		end
		if not gender then
			gender, stem, pos = rmatch(SUBPAGENAME, "^Hindi ([a-z]+ine) ([^ %-]*%-stem) (.*)s$")
		end
		if gender then
			maintext = gender .. " " .. stem .. " ~."
			if rfind(stem, "independent") then
				maintext = maintext .. " Here, 'independent' means that the stem ending directly " ..
				"follows a vowel and so uses the independent Devanagari form of the vowel that begins the ending."
			end
			if rfind(stem, "unmarked") then
				maintext = maintext .. " Here, 'unmarked' means that the endings are added onto the full direct singular form " ..
				"without removing the stem ending (although final nasalization, if present, will move to the ending)."
			end
			insert("~ by gender and stem type|" .. rsub(rsub(stem, "independent ", ""), "unmarked ", ""))
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
-- for a given slot is a list of objects {form=FORM, translit=TRANSLIT, footnotes=FOOTNOTES}.
function export.do_generate_forms(parent_args, pos, from_headword, def)
	local params = {
		[1] = {required = true, default = "दुनिया<iyā>"},
		footnote = {list = true},
		title = {},
	}

	if from_headword then
		params["lemma"] = {list = true}
		params["g"] = {list = true}
		params["f"] = {list = true}
		params["m"] = {list = true}
		params["id"] = {}
	end

	local args = m_para.process(parent_args, params)
	local alternant_multiword_spec = iut.parse_alternant_multiword_spec(args[1], parse_indicator_spec,
		nil, "allow blank lemma")
	alternant_multiword_spec.title = args.title
	alternant_multiword_spec.footnotes = args.footnote
	alternant_multiword_spec.pos = pos or "nouns"
	alternant_multiword_spec.args = args
	com.normalize_all_lemmas(alternant_multiword_spec)
	detect_all_indicator_specs(alternant_multiword_spec)
	propagate_properties(alternant_multiword_spec, "number", "both", "both")
	-- The default of "M" should apply only to plural adjectives, where it doesn't matter.
	-- FIXME: This may be wrong for Hindi.
	propagate_properties(alternant_multiword_spec, "gender", "M", "mixed")
	determine_noun_status(alternant_multiword_spec)
	local decline_props = {
		skip_slot = function(slot)
			return skip_slot(alternant_multiword_spec.number, slot)
		end,
		slot_table = noun_slots_with_linked,
		lang = lang,
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
-- objects {form=FORM, translit=TRANSLIT, footnotes=FOOTNOTES}.
function export.do_generate_forms_manual(parent_args, number, pos, from_headword, def)
	if number ~= "sg" and number ~= "pl" and number ~= "both" then
		error("Internal error: number (arg 1) must be 'sg', 'pl' or 'both': '" .. number .. "'")
	end

	local params = {
		footnote = {list = true},
		title = {},
	}
	if number == "both" then
		params[1] = {required = true, default = "तारीख़"}
		params[2] = {required = true, default = "तवारीख़"}
		params[3] = {required = true, default = "तारीख़"}
		params[4] = {required = true, default = "तवारीख़ों"}
		params[5] = {required = true, default = "तारीख़"}
		params[6] = {required = true, default = "तवारीख़ो"}
	elseif number == "sg" then
		params[1] = {required = true, default = "अदला-बदला"}
		params[2] = {required = true, default = "अदले-बदले"}
		params[3] = {required = true, default = "अदले-बदले"}
	else
		params[1] = {required = true, default = "लोग"}
		params[2] = {required = true, default =	"लोगों"}
		params[3] = {required = true, default = "लोगो"}
	end


	local args = m_para.process(parent_args, params)
	local alternant_spec = {
		title = args.title,
		footnotes = args.footnote,
		forms = {},
		number = number,
		pos = pos or "nouns",
		manual = true,
	}
	process_manual_overrides(alternant_spec.forms, args, alternant_spec.number)
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
-- "SLOT=FORM,FORM,...|SLOT=FORM,FORM,...|...". Each FORM is either a string in Devanagari or
-- (if manual translit is present) a specification of the form "FORM//TRANSLIT" where FORM is the
-- Devanagari representation of the form and TRANSLIT its manual transliteration. Embedded pipe symbols
-- (as might occur in embedded links) are converted to <!>. If INCLUDE_PROPS is given, also include
-- additional properties (currently, g= for headword genders). This is for use by bots.
local function concat_forms(alternant_spec, include_props)
	local ins_text = {}
	for slot, _ in pairs(noun_slots_with_linked) do
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
-- the forms as a string of the same form as documented in concat_forms() above.
function export.generate_forms(frame)
	local include_props = frame.args["include_props"]
	local parent_args = frame:getParent().args
	local alternant_spec = export.do_generate_forms(parent_args)
	return concat_forms(alternant_spec, include_props)
end

return export
