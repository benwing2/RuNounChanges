local export = {}


--[=[

Authorship: Ben Wing <benwing2>

]=]

--[=[

TERMINOLOGY:

-- "slot" = A particular combination of case/gender/number.
	 Example slot names for adjectives are "gen_f" (genitive feminine singular) and
	 "nom_mp_an" (animate nominative masculine plural). Each slot is filled with zero or more forms.

-- "form" = The declined Czech form representing the value of a given slot.

-- "lemma" = The dictionary form of a given Czech term. Generally the nominative
     masculine singular, but may occasionally be another form if the nominative
	 masculine singular is missing.
]=]

local lang = require("Module:languages").getByCode("cs")
local m_links = require("Module:links")
local m_table = require("Module:table")
local m_string_utilities = require("Module:string utilities")
local iut = require("Module:inflection utilities")
local com = require("Module:cs-common")

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


-- Construct the "reduced" version of a stem. This removes an е or ъ followed by a word-final
-- consonant, stresses the final syllable of the result if necessary, and converts бое́ц into бо́йц- and бо́як into бо́йк-.
-- An error is thrown if the stem can't be reduced.
local function reduce_stem(stem)
	local vowel_ending_stem, final_cons = rmatch(stem, "^(.*" .. com.vowel_c .. AC .. "?)[ея]́?(" .. com.cons_c .. ")$")
	if vowel_ending_stem then
		-- бое́ц etc.
		return com.maybe_stress_final_syllable(vowel_ending_stem .. "й" .. final_cons)
	end
	local initial_stem, final_cons = rmatch(stem, "^(.*)[еъ]́?(" .. com.cons_c .. ")$")
	if initial_stem then
		return com.maybe_stress_final_syllable(initial_stem .. final_cons)
	end
	error("Unable to reduce stem: '" .. stem .. "'")
end


-- All slots that are used by any of the different tables. The key is the slot and the value is a list of the tables
-- that use the slot. "" = regular, "plonly" = special=plonly in {{cs-adecl-manual}}, "dva" = special=dva in
-- {{cs-adecl-manual}}.
local input_adjective_slots = {
	nom_m = {""},
	nom_f = {""},
	nom_n = {""},
	nom_mp_an = {"", "plonly"},
	nom_fp = {"", "plonly"},
	nom_np = {"", "plonly"},
	nom_mp = {"dva"},
	nom_fnp = {"dva"},
	gen_mn = {""},
	gen_f = {""},
	gen_p = {"", "plonly", "dva"},
	dat_mn = {""},
	dat_f = {""},
	dat_p = {"", "plonly", "dva"},
	acc_m_an = {""},
	acc_m_in = {""},
	acc_f = {""},
	acc_n = {""},
	acc_mfp = {"", "plonly"},
	acc_np = {"", "plonly"},
	acc_mp = {"dva"},
	acc_fnp = {"dva"},
	ins_mn = {""},
	ins_f = {""},
	ins_p = {"", "plonly", "dva"},
	loc_mn = {""},
	loc_f = {""},
	loc_p = {"", "plonly", "dva"},
	short_m = {""},
	short_f = {""},
	short_n = {""},
	short_mp_an = {""},
	short_fp = {""},
	short_np = {""},
}


local output_adjective_slots = {
	nom_m = "nom|m|s",
	nom_m_linked = "nom|m|s", -- used in [[Module:cs-noun]]?
	nom_f = "nom|f|s",
	nom_n = "nom|n|s",
	nom_mp_an = "an|nom|m|p",
	nom_fp = "in|nom|m|p|;|nom|f|p",
	nom_np = "nom|n|p",
	nom_mp = "nom|m|p",
	nom_fnp = "nom|f//n|p",
	gen_mn = "gen|m//n|s",
	gen_f = "gen|f|s",
	gen_p = "gen|p",
	dat_mn = "dat|m//n|s",
	dat_f = "dat|f|s",
	dat_p = "dat|p",
	acc_m_an = "an|acc|m|s",
	acc_m_in = "in|acc|m|s",
	acc_f = "acc|f|s",
	acc_n = "acc|n|s",
	acc_mfp = "acc|m//f|p",
	acc_np = "acc|n|p",
	acc_mp = "acc|m|p",
	acc_fnp = "acc|f//n|p",
	ins_mn = "ins|m//n|s",
	ins_f = "ins|f|s",
	ins_p = "ins|p",
	loc_mn = "loc|m//n|s",
	loc_f = "loc|f|s",
	loc_p = "loc|p",
	short_m = "short|m|s",
	short_f = "short|f|s",
	short_n = "short|n|s",
	short_mp_an = "short|an|m|p",
	short_fp = "short|in|m|p|;|short|f|p",
	short_np = "short|n|p",
}


local function get_output_adjective_slots(alternant_multiword_spec)
	return output_adjective_slots
end


local function combine_stem_ending(stem, ending)
	if stem == "?" then
		return "?"
	else
		return stem .. ending
	end
end


local function add(base, slot, stems, endings, footnote)
	if stems then
		stems = iut.combine_form_and_footnotes(stems, footnote)
	end
	iut.add_forms(base.forms, slot, stems, endings, combine_stem_ending)
end


local function add_normal_decl(base, stems,
	ind_nom_m, def_nom_m, ind_nom_f, def_nom_f, ind_nom_n, def_nom_n,
	ind_nom_mp, def_nom_mp, ind_nom_fp, def_nom_fp, ind_nom_np, def_nom_np,
	ind_gen_mn, def_gen_mn, gen_f, gen_p,
	ind_dat_mn, def_dat_mn, dat_f, dat_p,
	ind_acc_f, def_acc_f, ind_acc_mp, def_acc_mp,
	ind_loc_mn, def_loc_mn, loc_f,
	ins_mn, ins_f,
	footnote)
	if stems then
		stems = iut.combine_form_and_footnotes(stems, footnote)
	end
	add(base, "ind_nom_m", stems, ind_nom_m)
	add(base, "def_nom_m", stems, def_nom_m)
	add(base, "ind_nom_f", stems, ind_nom_f)
	add(base, "def_nom_f", stems, def_nom_f)
	add(base, "ind_nom_n", stems, ind_nom_n)
	add(base, "def_nom_n", stems, def_nom_n)
	add(base, "ind_nom_mp", stems, ind_nom_mp)
	add(base, "def_nom_mp", stems, def_nom_mp)
	add(base, "ind_nom_fp", stems, ind_nom_fp)
	add(base, "def_nom_fp", stems, def_nom_fp)
	add(base, "ind_nom_np", stems, ind_nom_np)
	add(base, "def_nom_np", stems, def_nom_np)
	add(base, "ind_gen_mn", stems, ind_gen_mn)
	add(base, "def_gen_mn", stems, def_gen_mn)
	add(base, "gen_f", stems, gen_f)
	add(base, "gen_p", stems, gen_p)
	add(base, "ind_dat_mn", stems, ind_dat_mn)
	add(base, "def_dat_mn", stems, def_dat_mn)
	add(base, "dat_f", stems, dat_f)
	add(base, "dat_p", stems, dat_p)
	add(base, "acc_f", stems, acc_f)
	add(base, "ind_loc_mn", stems, ind_loc_mn)
	add(base, "def_loc_mn", stems, def_loc_mn)
	add(base, "loc_f", stems, loc_f)
	add(base, "ins_mn", stems, ins_mn)
	add(base, "ins_f", stems, ins_f)
end

local decls = {}

		add_normal_decl(base, base.lemma, "")
		add_normal_decl(base, stem,
			-- nom sg
			{}, "ӣ", "а", "а̄", soft and "е" or "о", soft and "е̄" or "о̄",
			-- nom pl
			"и", "ӣ", "е", "е̄", "а", "а̄",
			-- gen
			"а", soft and {"е̄г", "е̄га"} or {"о̄г", "о̄га"}, "е̄", "ӣх",
			-- dat
			"у", soft and {"е̄м", "е̄му"} or {"о̄м", "о̄му", {form = "о̄ме", footnotes = "not usually in Croatia"}}, "о̄ј", {"ӣм", "ӣма"},
			-- acc
			"у", "ӯ",
			-- loc
			"у", {"о̄м", "о̄му"}, "о̄ј",
			-- ins
			"ӣм", "о̄м",
		)
{{sh-decl-adj-1
|title=positive indefinite forms
|nsm={{PAGENAME}}
|nsf={{ #ifeq: {{{sc}}} | Cyrl | {{{1}}}а | {{{1}}}a}}
|nsn={{ #ifeq: {{{sc}}} | Cyrl | {{{1}}}{{#ifeq: {{{2|о}}}|о|о|е}} | {{{1}}}{{#ifeq: {{{2|o}}}|o|o|e}}}}
|gsm={{ #ifeq: {{{sc}}} | Cyrl | {{{1}}}а | {{{1}}}a}}
|gsn={{ #ifeq: {{{sc}}} | Cyrl | {{{1}}}а | {{{1}}}a}}
|gsf={{ #ifeq: {{{sc}}} | Cyrl | {{{1}}}е | {{{1}}}e}}
|dsm={{ #ifeq: {{{sc}}} | Cyrl | {{{1}}}у | {{{1}}}u}}
|dsn={{ #ifeq: {{{sc}}} | Cyrl | {{{1}}}у | {{{1}}}u}}
|dsf={{ #ifeq: {{{sc}}} | Cyrl | {{{1}}}ој | {{{1}}}oj}}
|asm={{ #ifeq: {{{sc}}} | Cyrl | {{PAGENAME}}<br>{{{1}}}а | {{PAGENAME}}<br>{{{1}}}a}}
|asn={{ #ifeq: {{{sc}}} | Cyrl | {{{1}}}{{#ifeq: {{{2|о}}}|о|о|е}} | {{{1}}}{{#ifeq: {{{2|o}}}|o|o|e}}}}
|asf={{ #ifeq: {{{sc}}} | Cyrl | {{{1}}}у | {{{1}}}u}}
|vsm={{PAGENAME}}
|vsf={{ #ifeq: {{{sc}}} | Cyrl | {{{1}}}а | {{{1}}}a}}
|vsn={{ #ifeq: {{{sc}}} | Cyrl | {{{1}}}{{#ifeq: {{{2|о}}}|о|о|е}} | {{{1}}}{{#ifeq: {{{2|o}}}|o|o|e}}}}
|lsm={{ #ifeq: {{{sc}}} | Cyrl | {{{1}}}у | {{{1}}}u}}
|lsn={{ #ifeq: {{{sc}}} | Cyrl | {{{1}}}у | {{{1}}}u}}
|lsf={{ #ifeq: {{{sc}}} | Cyrl | {{{1}}}ој | {{{1}}}oj}}
|ism={{ #ifeq: {{{sc}}} | Cyrl | {{{1}}}им | {{{1}}}im}}
|isn={{ #ifeq: {{{sc}}} | Cyrl | {{{1}}}им | {{{1}}}im}}
|isf={{ #ifeq: {{{sc}}} | Cyrl | {{{1}}}ом | {{{1}}}om}}
|npm={{ #ifeq: {{{sc}}} | Cyrl | {{{1}}}и | {{{1}}}i}}
|npf={{ #ifeq: {{{sc}}} | Cyrl | {{{1}}}е | {{{1}}}e}}
|npn={{ #ifeq: {{{sc}}} | Cyrl | {{{1}}}а | {{{1}}}a}}
|gpm={{ #ifeq: {{{sc}}} | Cyrl | {{{1}}}их | {{{1}}}ih}}
|gpf={{ #ifeq: {{{sc}}} | Cyrl | {{{1}}}их | {{{1}}}ih}}
|gpn={{ #ifeq: {{{sc}}} | Cyrl | {{{1}}}их | {{{1}}}ih}}
|dpm={{ #ifeq: {{{sc}}} | Cyrl | {{{1}}}им(а) | {{{1}}}im(a)}}
|dpf={{ #ifeq: {{{sc}}} | Cyrl | {{{1}}}им(а) | {{{1}}}im(a)}}
|dpn={{ #ifeq: {{{sc}}} | Cyrl | {{{1}}}им(а) | {{{1}}}im(a)}}
|apm={{ #ifeq: {{{sc}}} | Cyrl | {{{1}}}е | {{{1}}}e}}
|apf={{ #ifeq: {{{sc}}} | Cyrl | {{{1}}}е | {{{1}}}e}}
|apn={{ #ifeq: {{{sc}}} | Cyrl | {{{1}}}а | {{{1}}}a}}
|vpm={{ #ifeq: {{{sc}}} | Cyrl | {{{1}}}и | {{{1}}}i}}
|vpf={{ #ifeq: {{{sc}}} | Cyrl | {{{1}}}е | {{{1}}}e}}
|vpn={{ #ifeq: {{{sc}}} | Cyrl | {{{1}}}а | {{{1}}}a}}
|lpm={{ #ifeq: {{{sc}}} | Cyrl | {{{1}}}им(а) | {{{1}}}im(a)}}
|lpf={{ #ifeq: {{{sc}}} | Cyrl | {{{1}}}им(а) | {{{1}}}im(a)}}
|lpn={{ #ifeq: {{{sc}}} | Cyrl | {{{1}}}им(а) | {{{1}}}im(a)}}
|ipm={{ #ifeq: {{{sc}}} | Cyrl | {{{1}}}им(а) | {{{1}}}im(a)}}
|ipf={{ #ifeq: {{{sc}}} | Cyrl | {{{1}}}им(а) | {{{1}}}im(a)}}
|ipn={{ #ifeq: {{{sc}}} | Cyrl | {{{1}}}им(а) | {{{1}}}im(a)}}
|sc={{{sc|Latn}}}
}}
{{sh-decl-adj-1
|title=positive definite forms
|nsm={{ #ifeq: {{{sc}}} | Cyrl | {{{1}}}и | {{{1}}}i}}
|nsf={{ #ifeq: {{{sc}}} | Cyrl | {{{1}}}а | {{{1}}}a}}
|nsn={{ #ifeq: {{{sc}}} | Cyrl | {{{1}}}{{#ifeq: {{{2|о}}}|о|о|е}} | {{{1}}}{{#ifeq: {{{2|o}}}|o|o|e}}}}
|gsm={{ #ifeq: {{{sc}}} | Cyrl | {{{1}}}{{#ifeq: {{{2|о}}}|о|о|е}}г(а) | {{{1}}}{{#ifeq: {{{2|o}}}|o|o|e}}g(a)}}
|gsn={{ #ifeq: {{{sc}}} | Cyrl | {{{1}}}{{#ifeq: {{{2|о}}}|о|о|е}}г(а) | {{{1}}}{{#ifeq: {{{2|o}}}|o|o|e}}g(a)}}
|gsf={{ #ifeq: {{{sc}}} | Cyrl | {{{1}}}е | {{{1}}}e}}
|dsm={{ #ifeq: {{{sc}}} | Cyrl | {{{1}}}{{#ifeq: {{{2|о}}}|о|о|е}}м(у{{#ifeq: {{{2}}}|о|/е|}}) | {{{1}}}{{#ifeq: {{{2|o}}}|o|o|e}}m(u{{#ifeq:{{{2}}}|o|/e|}})}}
|dsn={{ #ifeq: {{{sc}}} | Cyrl | {{{1}}}{{#ifeq: {{{2|о}}}|о|о|е}}м(у{{#ifeq:{{{2}}}|о|/е|}}) | {{{1}}}{{#ifeq: {{{2|o}}}|o|o|e}}m(u{{ #ifeq:{{{2}}}|o|/e|}})}}
|dsf={{ #ifeq: {{{sc}}} | Cyrl | {{{1}}}ој | {{{1}}}oj}}
|asm={{ #ifeq: {{{sc}}} | Cyrl | {{{1}}}и<br>{{{1}}}{{#ifeq: {{{2|о}}}|о|о|е}}г(а) | {{{1}}}i<br>{{{1}}}{{#ifeq: {{{2|o}}}|o|o|e}}g(a)}}
|asn={{ #ifeq: {{{sc}}} | Cyrl | {{{1}}}{{#ifeq: {{{2|о}}}|о|о|е}} | {{{1}}}{{#ifeq: {{{2|o}}}|o|o|e}}}}
|asf={{ #ifeq: {{{sc}}} | Cyrl | {{{1}}}у | {{{1}}}u}}
|vsm={{ #ifeq: {{{sc}}} | Cyrl | {{{1}}}и | {{{1}}}i}}
|vsf={{ #ifeq: {{{sc}}} | Cyrl | {{{1}}}а | {{{1}}}a}}
|vsn={{ #ifeq: {{{sc}}} | Cyrl | {{{1}}}{{#ifeq: {{{2|о}}}|о|о|е}} | {{{1}}}{{#ifeq: {{{2|o}}}|o|o|e}}}}
|lsm={{ #ifeq: {{{sc}}} | Cyrl | {{{1}}}{{#ifeq: {{{2|о}}}|о|о|е}}м({{#ifeq:{{{2}}}|о|е/|}}у) | {{{1}}}{{#ifeq: {{{2|o}}}|o|o|e}}m({{#ifeq:{{{2}}}|o|e/|}}u)}}
|lsn={{ #ifeq: {{{sc}}} | Cyrl | {{{1}}}{{#ifeq: {{{2|о}}}|о|о|е}}м({{#ifeq:{{{2}}}|о|е/|}}у) | {{{1}}}{{#ifeq: {{{2|o}}}|o|o|e}}m({{ #ifeq: {{{2}}} | o | e/ | }}u)}}
|lsf={{ #ifeq: {{{sc}}} | Cyrl | {{{1}}}ој | {{{1}}}oj}}
|ism={{ #ifeq: {{{sc}}} | Cyrl | {{{1}}}им | {{{1}}}im}}
|isn={{ #ifeq: {{{sc}}} | Cyrl | {{{1}}}им | {{{1}}}im}}
|isf={{ #ifeq: {{{sc}}} | Cyrl | {{{1}}}ом | {{{1}}}om}}
|npm={{ #ifeq: {{{sc}}} | Cyrl | {{{1}}}и | {{{1}}}i}}
|npf={{ #ifeq: {{{sc}}} | Cyrl | {{{1}}}е | {{{1}}}e}}
|npn={{ #ifeq: {{{sc}}} | Cyrl | {{{1}}}а | {{{1}}}a}}
|gpm={{ #ifeq: {{{sc}}} | Cyrl | {{{1}}}их | {{{1}}}ih}}
|gpf={{ #ifeq: {{{sc}}} | Cyrl | {{{1}}}их | {{{1}}}ih}}
|gpn={{ #ifeq: {{{sc}}} | Cyrl | {{{1}}}их | {{{1}}}ih}}
|dpm={{ #ifeq: {{{sc}}} | Cyrl | {{{1}}}им(а) | {{{1}}}im(a)}}
|dpf={{ #ifeq: {{{sc}}} | Cyrl | {{{1}}}им(а) | {{{1}}}im(a)}}
|dpn={{ #ifeq: {{{sc}}} | Cyrl | {{{1}}}им(а) | {{{1}}}im(a)}}
|apm={{ #ifeq: {{{sc}}} | Cyrl | {{{1}}}е | {{{1}}}e}}
|apf={{ #ifeq: {{{sc}}} | Cyrl | {{{1}}}е | {{{1}}}e}}
|apn={{ #ifeq: {{{sc}}} | Cyrl | {{{1}}}а | {{{1}}}a}}
|vpm={{ #ifeq: {{{sc}}} | Cyrl | {{{1}}}и | {{{1}}}i}}
|vpf={{ #ifeq: {{{sc}}} | Cyrl | {{{1}}}е | {{{1}}}e}}
|vpn={{ #ifeq: {{{sc}}} | Cyrl | {{{1}}}а | {{{1}}}a}}
|lpm={{ #ifeq: {{{sc}}} | Cyrl | {{{1}}}им(а) | {{{1}}}im(a)}}
|lpf={{ #ifeq: {{{sc}}} | Cyrl | {{{1}}}им(а) | {{{1}}}im(a)}}
|lpn={{ #ifeq: {{{sc}}} | Cyrl | {{{1}}}им(а) | {{{1}}}im(a)}}
|ipm={{ #ifeq: {{{sc}}} | Cyrl | {{{1}}}им(а) | {{{1}}}im(a)}}
|ipf={{ #ifeq: {{{sc}}} | Cyrl | {{{1}}}им(а) | {{{1}}}im(a)}}
|ipn={{ #ifeq: {{{sc}}} | Cyrl | {{{1}}}им(а) | {{{1}}}im(a)}}
|sc={{{sc|Latn}}}
}}
{{sh-decl-adj-1
|title=comparative forms
|nsm={{ #ifeq: {{{sc}}} | Cyrl | {{{3}}}и | {{{3}}}i}}
|nsf={{ #ifeq: {{{sc}}} | Cyrl | {{{3}}}а | {{{3}}}a}}
|nsn={{ #ifeq: {{{sc}}} | Cyrl | {{{3}}}{{#ifeq: {{{4|о}}}|о|о|е}} | {{{3}}}{{#ifeq: {{{4|o}}}|o|o|e}}}}
|gsm={{ #ifeq: {{{sc}}} | Cyrl | {{{3}}}{{#ifeq: {{{4|о}}}|о|о|е}}г(а) | {{{3}}}{{#ifeq: {{{4|o}}}|o|o|e}}g(a)}}
|gsn={{ #ifeq: {{{sc}}} | Cyrl | {{{3}}}{{#ifeq: {{{4|о}}}|о|о|е}}г(а) | {{{3}}}{{#ifeq: {{{4|o}}}|o|o|e}}g(a)}}
|gsf={{ #ifeq: {{{sc}}} | Cyrl | {{{3}}}е | {{{3}}}e}}
|dsm={{ #ifeq: {{{sc}}} | Cyrl | {{{3}}}{{#ifeq: {{{4|о}}}|о|о|е}}м(у{{#ifeq: {{{4}}}|о|/е|}}) | {{{3}}}{{#ifeq: {{{4|o}}}|o|o|e}}m(u{{#ifeq:{{{4}}}|o|/e|}})}}
|dsn={{ #ifeq: {{{sc}}} | Cyrl | {{{3}}}{{#ifeq: {{{4|о}}}|о|о|е}}м(у{{#ifeq:{{{4}}}|о|/е|}}) | {{{3}}}{{#ifeq: {{{4|o}}}|o|o|e}}m(u{{ #ifeq:{{{4}}}|o|/e|}})}}
|dsf={{ #ifeq: {{{sc}}} | Cyrl | {{{3}}}ој | {{{3}}}oj}}
|asm={{ #ifeq: {{{sc}}} | Cyrl | {{{3}}}и<br>{{{3}}}{{#ifeq: {{{4|о}}}|о|о|е}}г(а) | {{{3}}}i<br>{{{3}}}{{#ifeq: {{{4|o}}}|o|o|e}}g(a)}}
|asn={{ #ifeq: {{{sc}}} | Cyrl | {{{3}}}{{#ifeq: {{{4|о}}}|о|о|е}} | {{{3}}}{{#ifeq: {{{4|o}}}|o|o|e}}}}
|asf={{ #ifeq: {{{sc}}} | Cyrl | {{{3}}}у | {{{3}}}u}}
|vsm={{ #ifeq: {{{sc}}} | Cyrl | {{{3}}}и | {{{3}}}i}}
|vsf={{ #ifeq: {{{sc}}} | Cyrl | {{{3}}}а | {{{3}}}a}}
|vsn={{ #ifeq: {{{sc}}} | Cyrl | {{{3}}}{{#ifeq: {{{4|о}}}|о|о|е}} | {{{3}}}{{#ifeq: {{{4|o}}}|o|o|e}}}}
|lsm={{ #ifeq: {{{sc}}} | Cyrl | {{{3}}}{{#ifeq: {{{4|о}}}|о|о|е}}м({{#ifeq:{{{4}}}|о|е/|}}у) | {{{3}}}{{#ifeq: {{{4|o}}}|o|o|e}}m({{#ifeq:{{{4}}}|o|e/|}}u)}}
|lsn={{ #ifeq: {{{sc}}} | Cyrl | {{{3}}}{{#ifeq: {{{4|о}}}|о|о|е}}м({{#ifeq:{{{4}}}|о|е/|}}у) | {{{3}}}{{#ifeq: {{{4|o}}}|o|o|e}}m({{ #ifeq: {{{4}}} | o | e/ | }}u)}}
|lsf={{ #ifeq: {{{sc}}} | Cyrl | {{{3}}}ој | {{{3}}}oj}}
|ism={{ #ifeq: {{{sc}}} | Cyrl | {{{3}}}им | {{{3}}}im}}
|isn={{ #ifeq: {{{sc}}} | Cyrl | {{{3}}}им | {{{3}}}im}}
|isf={{ #ifeq: {{{sc}}} | Cyrl | {{{3}}}ом | {{{3}}}om}}
|npm={{ #ifeq: {{{sc}}} | Cyrl | {{{3}}}и | {{{3}}}i}}
|npf={{ #ifeq: {{{sc}}} | Cyrl | {{{3}}}е | {{{3}}}e}}
|npn={{ #ifeq: {{{sc}}} | Cyrl | {{{3}}}а | {{{3}}}a}}
|gpm={{ #ifeq: {{{sc}}} | Cyrl | {{{3}}}их | {{{3}}}ih}}
|gpf={{ #ifeq: {{{sc}}} | Cyrl | {{{3}}}их | {{{3}}}ih}}
|gpn={{ #ifeq: {{{sc}}} | Cyrl | {{{3}}}их | {{{3}}}ih}}
|dpm={{ #ifeq: {{{sc}}} | Cyrl | {{{3}}}им(а) | {{{3}}}im(a)}}
|dpf={{ #ifeq: {{{sc}}} | Cyrl | {{{3}}}им(а) | {{{3}}}im(a)}}
|dpn={{ #ifeq: {{{sc}}} | Cyrl | {{{3}}}им(а) | {{{3}}}im(a)}}
|apm={{ #ifeq: {{{sc}}} | Cyrl | {{{3}}}е | {{{3}}}e}}
|apf={{ #ifeq: {{{sc}}} | Cyrl | {{{3}}}е | {{{3}}}e}}
|apn={{ #ifeq: {{{sc}}} | Cyrl | {{{3}}}а | {{{3}}}a}}
|vpm={{ #ifeq: {{{sc}}} | Cyrl | {{{3}}}и | {{{3}}}i}}
|vpf={{ #ifeq: {{{sc}}} | Cyrl | {{{3}}}е | {{{3}}}e}}
|vpn={{ #ifeq: {{{sc}}} | Cyrl | {{{3}}}а | {{{3}}}a}}
|lpm={{ #ifeq: {{{sc}}} | Cyrl | {{{3}}}им(а) | {{{3}}}im(a)}}
|lpf={{ #ifeq: {{{sc}}} | Cyrl | {{{3}}}им(а) | {{{3}}}im(a)}}
|lpn={{ #ifeq: {{{sc}}} | Cyrl | {{{3}}}им(а) | {{{3}}}im(a)}}
|ipm={{ #ifeq: {{{sc}}} | Cyrl | {{{3}}}им(а) | {{{3}}}im(a)}}
|ipf={{ #ifeq: {{{sc}}} | Cyrl | {{{3}}}им(а) | {{{3}}}im(a)}}
|ipn={{ #ifeq: {{{sc}}} | Cyrl | {{{3}}}им(а) | {{{3}}}im(a)}}
|sc={{{sc|Latn}}}
}}
{{sh-decl-adj-1
|title=superlative forms
|nsm={{ #ifeq: {{{sc}}} | Cyrl | нај{{{3}}}и | naj{{{3}}}i}}
|nsf={{ #ifeq: {{{sc}}} | Cyrl | нај{{{3}}}а | naj{{{3}}}a}}
|nsn={{ #ifeq: {{{sc}}} | Cyrl | нај{{{3}}}{{#ifeq: {{{4|о}}}|о|о|е}} | naj{{{3}}}{{#ifeq: {{{4|o}}}|o|o|e}}}}
|gsm={{ #ifeq: {{{sc}}} | Cyrl | нај{{{3}}}{{#ifeq: {{{4|о}}}|о|о|е}}г(а) | naj{{{3}}}{{#ifeq: {{{4|o}}}|o|o|e}}g(a)}}
|gsn={{ #ifeq: {{{sc}}} | Cyrl | нај{{{3}}}{{#ifeq: {{{4|о}}}|о|о|е}}г(а) | naj{{{3}}}{{#ifeq: {{{4|o}}}|o|o|e}}g(a)}}
|gsf={{ #ifeq: {{{sc}}} | Cyrl | нај{{{3}}}е | naj{{{3}}}e}}
|dsm={{ #ifeq: {{{sc}}} | Cyrl | нај{{{3}}}{{#ifeq: {{{4|о}}}|о|о|е}}м(у{{#ifeq: {{{4}}}|о|/е|}}) | naj{{{3}}}{{#ifeq: {{{4|o}}}|o|o|e}}m(u{{#ifeq:{{{4}}}|o|/e|}})}}
|dsn={{ #ifeq: {{{sc}}} | Cyrl | нај{{{3}}}{{#ifeq: {{{4|о}}}|о|о|е}}м(у{{#ifeq:{{{4}}}|о|/е|}}) | naj{{{3}}}{{#ifeq: {{{4|o}}}|o|o|e}}m(u{{ #ifeq:{{{4}}}|o|/e|}})}}
|dsf={{ #ifeq: {{{sc}}} | Cyrl | нај{{{3}}}ој | naj{{{3}}}oj}}
|asm={{ #ifeq: {{{sc}}} | Cyrl | нај{{{3}}}и<br>нај{{{3}}}{{#ifeq: {{{4|о}}}|о|о|е}}г(а) | naj{{{3}}}i<br>naj{{{3}}}{{#ifeq: {{{4|o}}}|o|o|e}}g(a)}}
|asn={{ #ifeq: {{{sc}}} | Cyrl | нај{{{3}}}{{#ifeq: {{{4|о}}}|о|о|е}} | naj{{{3}}}{{#ifeq: {{{4|o}}}|o|o|e}}}}
|asf={{ #ifeq: {{{sc}}} | Cyrl | нај{{{3}}}у | naj{{{3}}}u}}
|vsm={{ #ifeq: {{{sc}}} | Cyrl | нај{{{3}}}и | naj{{{3}}}i}}
|vsf={{ #ifeq: {{{sc}}} | Cyrl | нај{{{3}}}а | naj{{{3}}}a}}
|vsn={{ #ifeq: {{{sc}}} | Cyrl | нај{{{3}}}{{#ifeq: {{{4|о}}}|о|о|е}} | naj{{{3}}}{{#ifeq: {{{4|o}}}|o|o|e}}}}
|lsm={{ #ifeq: {{{sc}}} | Cyrl | нај{{{3}}}{{#ifeq: {{{4|о}}}|о|о|е}}м({{#ifeq:{{{4}}}|о|е/|}}у) | naj{{{3}}}{{#ifeq: {{{4|o}}}|o|o|e}}m({{#ifeq:{{{4}}}|o|e/|}}u)}}
|lsn={{ #ifeq: {{{sc}}} | Cyrl | нај{{{3}}}{{#ifeq: {{{4|о}}}|о|о|е}}м({{#ifeq:{{{4}}}|о|е/|}}у) | naj{{{3}}}{{#ifeq: {{{4|o}}}|o|o|e}}m({{ #ifeq: {{{4}}} | o | e/ | }}u)}}
|lsf={{ #ifeq: {{{sc}}} | Cyrl | нај{{{3}}}ој | naj{{{3}}}oj}}
|ism={{ #ifeq: {{{sc}}} | Cyrl | нај{{{3}}}им | naj{{{3}}}im}}
|isn={{ #ifeq: {{{sc}}} | Cyrl | нај{{{3}}}им | naj{{{3}}}im}}
|isf={{ #ifeq: {{{sc}}} | Cyrl | нај{{{3}}}ом | naj{{{3}}}om}}
|npm={{ #ifeq: {{{sc}}} | Cyrl | нај{{{3}}}и | naj{{{3}}}i}}
|npf={{ #ifeq: {{{sc}}} | Cyrl | нај{{{3}}}е | naj{{{3}}}e}}
|npn={{ #ifeq: {{{sc}}} | Cyrl | нај{{{3}}}а | naj{{{3}}}a}}
|gpm={{ #ifeq: {{{sc}}} | Cyrl | нај{{{3}}}их | naj{{{3}}}ih}}
|gpf={{ #ifeq: {{{sc}}} | Cyrl | нај{{{3}}}их | naj{{{3}}}ih}}
|gpn={{ #ifeq: {{{sc}}} | Cyrl | нај{{{3}}}их | naj{{{3}}}ih}}
|dpm={{ #ifeq: {{{sc}}} | Cyrl | нај{{{3}}}им(а) | naj{{{3}}}im(a)}}
|dpf={{ #ifeq: {{{sc}}} | Cyrl | нај{{{3}}}им(а) | naj{{{3}}}im(a)}}
|dpn={{ #ifeq: {{{sc}}} | Cyrl | нај{{{3}}}им(а) | naj{{{3}}}im(a)}}
|apm={{ #ifeq: {{{sc}}} | Cyrl | нај{{{3}}}е | naj{{{3}}}e}}
|apf={{ #ifeq: {{{sc}}} | Cyrl | нај{{{3}}}е | naj{{{3}}}e}}
|apn={{ #ifeq: {{{sc}}} | Cyrl | нај{{{3}}}а | naj{{{3}}}a}}
|vpm={{ #ifeq: {{{sc}}} | Cyrl | нај{{{3}}}и | naj{{{3}}}i}}
|vpf={{ #ifeq: {{{sc}}} | Cyrl | нај{{{3}}}е | naj{{{3}}}e}}
|vpn={{ #ifeq: {{{sc}}} | Cyrl | нај{{{3}}}а | naj{{{3}}}a}}
|lpm={{ #ifeq: {{{sc}}} | Cyrl | нај{{{3}}}им(а) | naj{{{3}}}im(a)}}
|lpf={{ #ifeq: {{{sc}}} | Cyrl | нај{{{3}}}им(а) | naj{{{3}}}im(a)}}
|lpn={{ #ifeq: {{{sc}}} | Cyrl | нај{{{3}}}им(а) | naj{{{3}}}im(a)}}
|ipm={{ #ifeq: {{{sc}}} | Cyrl | нај{{{3}}}им(а) | naj{{{3}}}im(a)}}
|ipf={{ #ifeq: {{{sc}}} | Cyrl | нај{{{3}}}им(а) | naj{{{3}}}im(a)}}
|ipn={{ #ifeq: {{{sc}}} | Cyrl | нај{{{3}}}им(а) | naj{{{3}}}im(a)}}
|sc={{{sc|Latn}}}
}}<noinclude>
[[Category:Serbo-Croatian adjective inflection-table templates|adj]]</noinclude>

decls["normal"] = function(base)
	local stem, suffix

	stem, suffix = rmatch(base.lemma, "^(.*)(ý)$")
	if stem then
		add_normal_decl(base, stem,
			"ý", "á", "é", {}, "é", "á",
			"ého", "é", "ých",
			"ému", "é", "ým",
			"ou",
			"ém", "é", "ých",
			"ým", "ou", "ými"
		)
		-- Do the nominative masculine animate plural separately since it may have a different stem (with the second
		-- palatalization applied).
		add_normal_decl(base, com.apply_second_palatalization(stem, "is adj"), nil, nil, nil, "í")
		if base.short then
			-- Examples of short adjectives:
			-- bledý "pale" -> bled
			-- bosý "barefoot" -> bos
			-- pilný "hardworking, diligent" -> pilen (reducible)
			-- veselý "funny, jolly" -> vesel
			-- jistý "certain, sure" -> jist
			-- vinný "guilty" -> vinen (reducible)
			-- živý "alive, living" -> živ
			-- tichý "quiet" -> tich; mp_an = tiši
			-- vědomý "conscious, aware" -> vědom
			-- rád "glad" (short only)
			-- chudý "poor" -> chud
			-- nevinný "innocent" -> nevinen (reducible)
			-- silný "strong" -> silen (reducible)
			-- známý "known" -> znám
			-- mladý "young" -> mlád (note length); other forms have mlád- or mlad-
			-- starý "old" -> stár (note length); other forms have stár- or star-; mp_an = stáři, staři
			-- slabý "weak" -> sláb (note length); other forms only have sláb- (FIXME: check against a grammar)
			-- zdravý "healthy" -> zdráv (note length); other forms only have zdráv- (FIXME: check against a grammar)
			-- nemocný "ill" -> nemocen (reducible)
			-- plný "full" -> pln
			-- schopný "able, capable" -> schopen (reducible)
			-- vděčný "grateful" -> vděčen (reducible)
			-- věrný "faithful" -> věren (reducible)
			-- šťastný "happy" -> šťasten (reducible)
			-- křepký "strong" -> křepek (reducible); mp_an = křepci
			-- hotový "ready, finished" -> hotov
			-- němý "mute" -> něma
			-- smutný "sad" -> smuten (reducible)
			-- samotný "lonely" -> samoten (reducible)
			-- bohatý "rich" -> bohat
			-- chladný "cold" -> chladen (reducible)
			-- dlužný "necessary?" -> dlužen (reducible)
			-- povinný "mandatory" -> povinen (reducible)
			-- zodpovědný "responsible" -> zodpověden (reducible)
			-- udatný "brave" -> udaten (reducible)
			-- náchylný "susceptible" -> náchylen (reducible)
			for _, short_stem_obj in ipairs(base.short) do
				add_short_decl(base, short_stem_obj.base, "")
				add_short_decl(base, short_stem_obj.stem, nil, "a", "o", nil, "y", "a")
				add_short_decl(base, com.apply_second_palatalization(short_stem_obj.stem.form, "is adj"), nil, nil, nil, "i",
					short_stem_obj.stem.footnotes)
			end
		end
		return
	end

	-- soft in -í
	stem, suffix = rmatch(base.lemma, "^(.*)(í)$")
	if stem then
		add_normal_decl(base, stem,
			"í", "í", "í", "í", "í", "í",
			"ího", "í", "ích",
			"ímu", "í", "ím",
			"í",
			"ím", "í", "ích",
			"ím", "í", "ími"
		)
		return
	end

	-- possessive in -ův
	stem, suffix = rmatch(base.lemma, "^(.*)(ův)$")
	if stem then
		add_normal_decl(base, stem,
			"ův", "ova", "ovo", "ovi", "ovy", "ova",
			"ova", "ovy", "ových",
			"ovu", "ově", "ovým",
			"ovu",
			{"ově", "ovu"}, "ově", "ových",
			"ovým", "ovou", "ovými"
		)
		return
	end

	-- possessive in -in
	stem, suffix = rmatch(base.lemma, "^(.*)(in)$")
	if stem then
		add_normal_decl(base, stem,
			"in", "ina", "ino", "ini", "iny", "ina",
			"ina", "iny", "iných",
			"inu", "ině", "iným",
			"inu",
			{"ině", "inu"}, "ině", "iných",
			"iným", "inou", "inými"
		)
		return
	end

	error("Unrecognized adjective lemma, should end in '-ý', '-í', '-ův' or '-in': '" .. base.lemma .. "'")
end


decls["irreg"] = function(base)
	local stem, suffix

	-- determiner like můj
	stem, suffix = rmatch(base.lemma, "^(.*)(ůj)$")
	if stem then
		add_normal_decl(base, stem,
			"ůj", {"á", "oje"}, {"é", "oje"}, {"í", "oji"}, {"é", "oje"}, {"á", "oje"},
			"ého", {"é", "ojí"}, "ých",
			"ému", {"é", "ojí"}, "ým",
			{"ou", "oji"},
			"ém", {"é", "ojí"}, "ých",
			"ým", {"ou", "ojí"}, "ými"
		)
		return
	end

	if base.lemma == "všechen" then
		add_normal_decl(base, "",
			"všechen", "všechna", {"všechno", "vše"}, "všichni", "všechny", "všechna",
			"všeho", "vší", "všech",
			"všemu", "vší", "všem",
			{"všechnu", "vši"},
			"všem", "vší", "všech",
			"vším", "vší", "všemi"
		)
		return
	end

	if base.lemma == "všecek" then
		add_normal_decl(base, "",
			"všecek", "všecka", {"všecko", "vše"}, "všicci", "všecky", "všecka",
			"všeho", "vší", "všech",
			"všemu", "vší", "všem",
			{"všecku", "vši"},
			"všem", "vší", "všech",
			"vším", "vší", "všemi"
		)
		return
	end

	if base.lemma == "všecken" then
		add_normal_decl(base, "",
			"všecken", "všeckna", {"všeckno", "vše"}, "všickni", "všeckny", "všeckna",
			"všeho", "vší", "všech",
			"všemu", "vší", "všem",
			{"všecknu", "vši"},
			"všem", "vší", "všech",
			"vším", "vší", "všemi"
		)
		return
	end

	-- determiner like [[ten]], [[tamten]], [[tamhleten]], [[tuten]], [[jeden]], [[onen]]
	-- [[tento]] uses 'ten<irreg>to'
	-- [[tenhle]] uses 'ten<irreg>hle'
	-- [[tenhleten]] uses 'ten<irreg>hleten<irreg>'
	stem, suffix = rmatch(base.lemma, "^(.*)(en)$")
	if stem then
		local nom_stem = stem .. suffix
		if nom_stem == "jeden" then
			stem = "jedn"
		end
		add_normal_decl(base, nom_stem, "")
		add_normal_decl(base, stem,
			nil, "a", "o", "i", "y", "a",
			"oho", "é", "ěch",
			"omu", "é", "ěm",
			"u",
			"om", "é", "ěch",
			"ím", "ou", "ěmi"
		)
		return
	end

	-- [[náš]], [[váš]]
	stem, suffix = rmatch(base.lemma, "^(.*)(áš)$")
	if stem then
		local nom_stem = stem .. suffix
		stem = stem .. "aš"
		add_normal_decl(base, nom_stem, "")
		add_normal_decl(base, stem,
			nil, "e", "e", "i", "e", "e",
			"eho", "í", "ich",
			"emu", "í", "im",
			"i",
			"em", "í", "ich",
			"ím", "í", "imi"
		)
		return
	end

	if base.lemma == "jenž" then
		local preposition_footnote = "the leading letter ''j-'' is changed to ''n-'' when the pronoun is preceded by a preposition, e.g. {{m|cs|[[s]] [[nímž]]}}, {{m|cs|[[k]] [[němuž]]}}, {{m|cs|[[bez]] [[níž]]}}"
		preposition_footnote = "[" .. mw.getCurrentFrame():preprocess(preposition_footnote) .. "]"
		-- Add the non-prepositional forms.
		add_normal_decl(base, "",
			"jenž", "jež", "jež", "již", "jež", "jež",
			{"jehož", "jejž"}, "jíž", "jichž",
			"jemuž", "jíž", "jimž",
			"již",
			nil, nil, nil,
			"jímž", "jíž", "jimiž"
		)
		-- Add the prepositional forms. (FIXME: Maybe should go in a separate column in a special table.)
		add_normal_decl(base, "",
			nil, nil, nil, nil, nil, nil,
			{"něhož", "nějž"}, "níž", "nichž",
			"němuž", "níž", "nimž",
			"niž",
			"němž", "níž", "nichž",
			"nímž", "níž", "nimiž",
			preposition_footnote
		)
		-- Unusually, the accusative masculine animate singular is not the same as the genitive masculine singular,
		-- and the accusative masculine inanimate singular is not the same as the nominative masculine singular.
		add(base, "acc_m_an", "", {"jejž", "jehož"})
		add(base, "acc_m_an", "", {"nějž", "něhož"}, preposition_footnote)
		add(base, "acc_m_in", "", "jejž")
		add(base, "acc_m_in", "", "nějž", preposition_footnote)
		return
	end

	if base.lemma == "tentýž" then
		add_normal_decl(base, "",
			"tentýž", "tatáž", "totéž", "titíž", "tytéž", "tatáž",
			"téhož", "téže", "týchž",
			{"témuž", "tomutéž"}, "téže", "týmž",
			"tutéž",
			"tomtéž", "téže", "týchž",
			"tímtéž", "toutéž", "týmiž"
		)
		return
	end

	if base.lemma == "týž" then
		add_normal_decl(base, "",
			"týž", "táž", nil, "tíž", nil, "tatáž",
			"téhož", "téže", "týchž",
			"témuž", "téže", "týmž",
			"touž",
			"témž", "téže", "týchž",
			"týmž", "touž", "týmiž"
		)
		return
	end

	if base.lemma == "sám" then
		-- This mixes long and short endings.
		add_normal_decl(base, "sám", "")
		add_normal_decl(base, "sam",
			nil, "a", "o", "i", "y", "a",
			"ého", "é", "ých",
			"ému", "é", "ým",
			"u",
			"ém", "é", "ých",
			"ým", "ou", "ými"
		)
		-- Unusually, the accusative masculine animate singular is not the same as the genitive masculine singular.
		add(base, "acc_m_an", "sam", {"a", "ého"})
		return
	end

	if base.lemma == "jejíž" then
		add_normal_decl(base, "jej",
			"íž", "íž", "íž", "íž", "íž", "íž",
			"íhož", "íž", "íchž",
			"ímuz", "íž", "ímž",
			"íž",
			"ímž", "íž", "íchž",
			"ímž", "íž", "ímiž"
		)
		return
	end

	error("Unrecognized irregular lemma '" .. base.lemma .. "'")
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


local function parse_indicator_spec(angle_bracket_spec)
	local inside = rmatch(angle_bracket_spec, "^<(.*)>$")
	assert(inside)
	local base = {forms = {}}
	if inside ~= "" then
		local parts = rsplit(inside, ".", true)
		for _, part in ipairs(parts) do
			if part == "irreg" then
				base.irreg = true
			elseif part == "short" then
				base.short = {{
					base = {
						form = "+",
					},
					stem = {
						form = "+",
					}
				}}
			elseif rfind(part, "^short:") then
				part = rsub(part, "^short:%s*", "")
				base.short = {}
				local segments = iut.parse_balanced_segment_run(part, "[", "]")
				local comma_separated_groups = iut.split_alternating_runs(segments, "%s*,%s*")
				for _, comma_separated_group in ipairs(comma_separated_groups) do
					if comma_separated_group[1] == "*" then
						-- reducible
						table.insert(base.short, {
							base = {
								form = "*",
								footnotes = fetch_footnotes(comma_separated_group),
							},
							stem = {
								form = "*",
								footnotes = fetch_footnotes(comma_separated_group),
							}
						})
					else
						local slash_separated_groups = iut.split_alternating_runs(comma_separated_group, "%s*/%s*")
						if #slash_separated_groups > 2 then
							error("Too many slash-separated stems: '" .. inside .. "'")
						end
						local short_base = slash_separated_groups[1]
						local short_stem = slash_separated_groups[2]
						local short_base_obj = {
							form = short_base[1],
							footnotes = fetch_footnotes(short_base),
						}
						local short_stem_obj
						if short_stem then
							short_stem_obj = {
								form = short_stem[1],
								footnotes = fetch_footnotes(short_stem),
							}
						end
						table.insert(base.short, {
							base = short_base_obj,
							stem = short_stem_obj,
						})
					end
					iut.insert_form(forms, slot, formobj)
				end
			else
				error("Unrecognized indicator '" .. part .. "': '" .. inside .. "'")
			end
		end
	end
	return base
end


local function normalize_all_lemmas(alternant_multiword_spec, pagename)
	iut.map_word_specs(alternant_multiword_spec, function(base)
		if base.lemma == "" then
			base.lemma = pagename
		end
		base.orig_lemma = base.lemma
		base.orig_lemma_no_links = m_links.remove_links(base.lemma)
		base.lemma = base.orig_lemma_no_links
	end)
end


local function detect_indicator_spec(base)
	if base.short then
		if not base.lemma:find("ý$") then
			error("Short forms can only be specified for lemmas ending in -ý, but saw '" .. base.lemma .. "'")
		end
		local stem = rmatch(base.lemma, "^(.*)ý$")
		for _, short_spec in ipairs(base.short) do
			if short_spec.base.form == "+" then
				short_spec.base.form = stem
			elseif short_spec.base.form == "*" then
				short_spec.base.form = com.dereduce(base, stem)
				if not short_spec.base.form then
					error("Unable to construct non-reduced variant of stem '" .. stem .. "'")
				end
			end
			if not short_spec.stem then
				short_spec.stem = {
					form = short_spec.base.form,
					footnotes = short_spec.base.footnotes
				}
			end
			if short_spec.stem.form == "+" or short_spec.stem.form == "*" then
				short_spec.stem.form = stem
			end
		end
	end

	if base.irreg then
		base.decl = "irreg"
	else
		base.decl = "normal"
	end
end


local function detect_all_indicator_specs(alternant_multiword_spec)
	iut.map_word_specs(alternant_multiword_spec, function(base)
		detect_indicator_spec(base)
	end)
end


local function decline_adjective(base)
	if not decls[base.decl] then
		error("Internal error: Unrecognized declension type '" .. base.decl .. "'")
	end
	decls[base.decl](base)
	-- handle_derived_slots_and_overrides(base)
end


-- Process override for the arguments in `args`, storing the results into `forms`. If `do_acc`, only do accusative
-- slots; otherwise, don't do accusative slots.
local function process_overrides(forms, args, do_acc)
	for slot, _ in pairs(input_adjective_slots) do
		if args[slot] and not not do_acc == not not slot:find("^acc") then
			forms[slot] = nil
			if args[slot] ~= "-" and args[slot] ~= "—" then
				local segments = iut.parse_balanced_segment_run(args[slot], "[", "]")
				local comma_separated_groups = iut.split_alternating_runs(segments, "%s*,%s*")
				for _, comma_separated_group in ipairs(comma_separated_groups) do
					local formobj = {
						form = comma_separated_group[1],
						footnotes = fetch_footnotes(comma_separated_group),
					}
					iut.insert_form(forms, slot, formobj)
				end
			end
		end
	end
end


local function check_allowed_overrides(alternant_multiword_spec, args)
	local special = alternant_multiword_spec.special or alternant_multiword_spec.surname and "surname" or ""
	for slot, types in pairs(input_adjective_slots) do
		if args[slot] then
			local allowed = false
			for _, typ in ipairs(types) do
				if typ == special then
					allowed = true
					break
				end
			end
			if not allowed then
				error(("Override %s= not allowed for %s"):format(slot, special == "" and "regular declension" or
					"special=" .. special))
			end
		end
	end
end


local function set_accusative(alternant_multiword_spec)
	local forms = alternant_multiword_spec.forms
	local function copy_if(from_slot, to_slot)
		if not forms[to_slot] then
			iut.insert_forms(forms, to_slot, forms[from_slot])
		end
	end

	copy_if("nom_n", "acc_n")
	copy_if("gen_mn", "acc_m_an")
	copy_if("nom_m", "acc_m_in")
	copy_if("nom_fp", "acc_mfp")
	copy_if("nom_np", "acc_np")
end


local function add_categories(alternant_multiword_spec)
	local cats = {}
	local plpos = m_string_utilities.pluralize(alternant_multiword_spec.pos or "adjective")
	local function insert(cattype)
		m_table.insertIfNot(cats, "Czech " .. cattype .. " " .. plpos)
	end
	if not alternant_multiword_spec.manual then
		iut.map_word_specs(alternant_multiword_spec, function(base)
			if base.decl == "irreg" then
				insert("irregular")
			elseif rfind(base.lemma, "ý$") then
				insert("hard")
			elseif rfind(base.lemma, "í$") then
				insert("soft")
			else
				insert("possessive")
			end
			if base.short then
				table.insert(cats, "Czech " .. plpos .. " with short forms")
			end
		end)
	end
	alternant_multiword_spec.categories = cats
end


local function show_forms(alternant_multiword_spec)
	local lemmas = {}
	local lemmaform = alternant_multiword_spec.forms.nom_m or alternant_multiword_spec.forms.nom_mp or
		alternant_multiword_spec.forms.nom_mp_an
	if lemmaform then
		for _, form in ipairs(lemmaform) do
			table.insert(lemmas, form.form)
		end
	end
	local props = {
		lemmas = lemmas,
		slot_table = get_output_adjective_slots(alternant_multiword_spec),
		lang = lang,
	}
	iut.show_forms(alternant_multiword_spec.forms, props)
end


local function make_table(alternant_multiword_spec)
	local forms = alternant_multiword_spec.forms

	local function template_prelude(min_width)
		return rsub([===[
<div>
<div class="NavFrame" style="display: inline-block; min-width: MINWIDTHem">
<div class="NavHead" style="background:#eff7ff">{title}{annotation}</div>
<div class="NavContent">
{\op}| border="1px solid #000000" style="border-collapse:collapse;background:#F9F9F9;text-align:center; min-width:MINWIDTHem" class="inflection-table"
|-
]===], "MINWIDTH", min_width)
	end

	local function template_postlude()
		return [=[
|{\cl}{notes_clause}</div></div></div>]=]
	end

	local table_spec_sg = [=[
! style="background:#d9ebff" colspan=5 | singular
|-
! style="background:#d9ebff" |
! style="background:#d9ebff" | masculine animate
! style="background:#d9ebff" | masculine inanimate
! style="background:#d9ebff" | feminine
! style="background:#d9ebff" | neuter
|-
! style="background:#eff7ff" | nominative
| colspan=2 | {nom_m}
| {nom_f}
| {nom_n}
|-
! style="background:#eff7ff" | genitive
| colspan=2 | {gen_mn}
| {gen_f}
| {gen_mn}
|-
! style="background:#eff7ff" | dative
| colspan=2 | {dat_mn}
| {dat_f}
| {dat_mn}
|-
! style="background:#eff7ff" | accusative
| {acc_m_an}
| {acc_m_in}
| {acc_f}
| {acc_n}
|-
! style="background:#eff7ff" | locative
| colspan=2 | {loc_mn}
| {loc_f}
| {loc_mn}
|-
! style="background:#eff7ff" | instrumental
| colspan=2 | {ins_mn}
| {ins_f}
| {ins_mn}{short_sg_clause}
]=]

	local table_spec_pl = [=[
! style="background:#d9ebff" colspan=5 | plural
|-
! style="background:#d9ebff" | 
! style="background:#d9ebff" | masculine animate
! style="background:#d9ebff" | masculine inanimate
! style="background:#d9ebff" | feminine
! style="background:#d9ebff" | neuter
|-
! style="background:#eff7ff" | nominative
| {nom_mp_an}
| colspan=2 | {nom_fp}
| {nom_np}
|-
! style="background:#eff7ff" | genitive
| colspan=4 | {gen_p}
|-
! style="background:#eff7ff" | dative
| colspan=4 | {dat_p}
|-
! style="background:#eff7ff" | accusative
| colspan=3 | {acc_mfp}
| {acc_np}
|-
! style="background:#eff7ff" | locative
| colspan=4 | {loc_p}
|-
! style="background:#eff7ff" | instrumental
| colspan=4 | {ins_p}{short_pl_clause}
]=]

	local table_spec = template_prelude("55") .. table_spec_sg .. "|-\n" .. table_spec_pl .. template_postlude()

	local table_spec_plonly = template_prelude("55") .. table_spec_pl .. template_postlude()

	local table_spec_dva = template_prelude("40") .. [=[
! style="width:40%;background:#d9ebff" colspan="2" | 
! style="background:#d9ebff" colspan="2" | plural
|-
! style="width:40%;background:#d9ebff" colspan="2" | 
! style="background:#d9ebff" | masculine
! style="background:#d9ebff" | feminine/neuter
|-
! style="background:#eff7ff" colspan="2" | nominative
| {nom_mp}
| {nom_fnp}
|-
! style="background:#eff7ff" colspan="2" | genitive
| colspan="2" | {gen_p} 
|-
! style="background:#eff7ff" colspan="2" | dative
| colspan="2" | {dat_p} 
|-
! style="background:#eff7ff" colspan="2" | accusative
| {acc_mp}
| {acc_fnp}
|-
! style="background:#eff7ff" colspan="2" | locative
| colspan="2" | {loc_p} 
|-
! style="background:#eff7ff" colspan="2" | instrumental
| colspan="2" | {ins_p} 
]=] .. template_postlude()

	local short_sg_template = [=[

|-
! style="background:#eff7ff" | short
| colspan=2 | {short_m}
| {short_f}
| {short_n}
]=]

	local short_pl_template = [=[

|-
! style="background:#eff7ff" | short
| {short_mp_an}
| colspan=2 | {short_fp}
| {short_np}]=]

	local notes_template = [===[
<div style="width:100%;text-align:left;background:#d9ebff">
<div style="display:inline-block;text-align:left;padding-left:1em;padding-right:1em">
{footnote}
</div></div>
]===]

	if alternant_multiword_spec.title then
		forms.title = alternant_multiword_spec.title
	else
		forms.title = 'Declension of <i lang="cs">' .. forms.lemma .. '</i>'
	end

	if alternant_multiword_spec.manual then
		forms.annotation = ""
	else
		local ann_parts = {}
		local decls = {}
		iut.map_word_specs(alternant_multiword_spec, function(base)
			if base.decl == "irreg" then
				m_table.insertIfNot(decls, "irregular")
			elseif rfind(base.lemma, "ý$") then
				m_table.insertIfNot(decls, "hard")
			elseif rfind(base.lemma, "í$") then
				m_table.insertIfNot(decls, "soft")
			else
				m_table.insertIfNot(decls, "possessive")
			end
		end)
		table.insert(ann_parts, table.concat(decls, " // "))
		forms.annotation = " (" .. table.concat(ann_parts, ", ") .. ")"
	end

	forms.notes_clause = forms.footnote ~= "" and
		m_string_utilities.format(notes_template, forms) or ""
	forms.short_sg_clause = forms.short_m and forms.short_m ~= "—" and
		m_string_utilities.format(short_sg_template, forms) or ""
	forms.short_pl_clause = forms.short_mp_an and forms.short_mp_an ~= "—" and
		m_string_utilities.format(short_pl_template, forms) or ""
	return m_string_utilities.format(
		alternant_multiword_spec.special == "plonly" and table_spec_plonly or
		alternant_multiword_spec.special == "dva" and table_spec_dva or
		table_spec, forms
	)
end

-- Externally callable function to parse and decline an adjective given
-- user-specified arguments. Return value is WORD_SPEC, an object where the
-- declined forms are in `WORD_SPEC.forms` for each slot. If there are no values
-- for a slot, the slot key will be missing. The value for a given slot is a
-- list of objects {form=FORM, footnotes=FOOTNOTES}.
function export.do_generate_forms(parent_args, pos, from_headword, def)
	local params = {
		[1] = {},
		pos = {},
		json = {type = "boolean"}, -- for use with bots
		title = {},
		pagename = {},
	}
	for slot, _ in pairs(input_adjective_slots) do
		params[slot] = {}
	end

	-- Only default param 1 when displaying the template.
	local args = require("Module:parameters").process(parent_args, params)
	local SUBPAGE = mw.title.getCurrentTitle().subpageText
	local pagename = args.pagename or SUBPAGE
	if not args[1] then
		if SUBPAGE == "cs-adecl" then
			args[1] = "křepký<short:*>"
		else
			args[1] = pagename
		end
	end		
	local parse_props = {
		parse_indicator_spec = parse_indicator_spec,
		allow_default_indicator = true,
		allow_blank_lemma = true,
	}
	local alternant_multiword_spec = iut.parse_inflected_text(args[1], parse_props)
	alternant_multiword_spec.pos = args.pos
	alternant_multiword_spec.title = args.title
	alternant_multiword_spec.forms = {}
	normalize_all_lemmas(alternant_multiword_spec, pagename)
	detect_all_indicator_specs(alternant_multiword_spec)
	check_allowed_overrides(alternant_multiword_spec, args)
	local inflect_props = {
		slot_table = get_output_adjective_slots(alternant_multiword_spec),
		inflect_word_spec = decline_adjective,
	}
	iut.inflect_multiword_or_alternant_multiword_spec(alternant_multiword_spec, inflect_props)
	-- Do non-accusative overrides so they get copied to the accusative forms appropriately.
	process_overrides(alternant_multiword_spec.forms, args)
	set_accusative(alternant_multiword_spec)
	-- Do accusative overrides after copying the accusative forms.
	process_overrides(alternant_multiword_spec.forms, args, "do acc")
	add_categories(alternant_multiword_spec)
	if args.json and not from_headword then
		return require("Module:JSON").toJSON(alternant_multiword_spec)
	end
	return alternant_multiword_spec
end


-- Externally callable function to parse and decline an adjective where all
-- forms are given manually. Return value is WORD_SPEC, an object where the
-- declined forms are in `WORD_SPEC.forms` for each slot. If there are no values
-- for a slot, the slot key will be missing. The value for a given slot is a
-- list of objects {form=FORM, footnotes=FOOTNOTES}.
function export.do_generate_forms_manual(parent_args, pos, from_headword, def)
	local params = {
		pos = {},
		special = {},
		json = {type = "boolean"}, -- for use with bots
		title = {},
	}
	for slot, _ in pairs(input_adjective_slots) do
		params[slot] = {}
	end

	local args = require("Module:parameters").process(parent_args, params)
	local alternant_multiword_spec = {
		pos = args.pos,
		special = args.special,
		title = args.title, 
		forms = {},
		manual = true,
	}
	check_allowed_overrides(alternant_multiword_spec, args)
	-- Do non-accusative overrides so they get copied to the accusative forms appropriately.
	process_overrides(alternant_multiword_spec.forms, args)
	set_accusative(alternant_multiword_spec)
	-- Do accusative overrides after copying the accusative forms.
	process_overrides(alternant_multiword_spec.forms, args, "do acc")
	add_categories(alternant_multiword_spec)
	if args.json and not from_headword then
		return require("Module:JSON").toJSON(alternant_multiword_spec)
	end
	return alternant_multiword_spec
end


-- Entry point for {{cs-adecl}}. Template-callable function to parse and decline 
-- an adjective given user-specified arguments and generate a displayable table
-- of the declined forms.
function export.show(frame)
	local parent_args = frame:getParent().args
	local alternant_multiword_spec = export.do_generate_forms(parent_args)
	show_forms(alternant_multiword_spec)
	return make_table(alternant_multiword_spec) .. require("Module:utilities").format_categories(alternant_multiword_spec.categories, lang)
end


-- Entry point for {{cs-adecl-manual}}. Template-callable function to parse and
-- decline an adjective given manually-specified inflections and generate a
-- displayable table of the declined forms.
function export.show_manual(frame)
	local parent_args = frame:getParent().args
	local alternant_multiword_spec = export.do_generate_forms_manual(parent_args)
	show_forms(alternant_multiword_spec)
	return make_table(alternant_multiword_spec) .. require("Module:utilities").format_categories(alternant_multiword_spec.categories, lang)
end


return export
