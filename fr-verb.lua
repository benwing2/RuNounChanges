--[=[

Author: originally Kc kennylau; rewritten by Benwing

This implements {{fr-conj-auto}}. It uses the following submodules:
* [[Module:fr-verb/core]] (helper for generating conjugations)
* [[Module:fr-verb/pron]] (helper for generating pronunciations of conjugations)
* [[Module:fr-conj]] (for constructing the table wikicode given the forms)
* [[Module:fr-pron]] (for generating pronunciations of stems)

FIXME:

1. (DONE) Use ‿ to join reflexive pronouns.
2. montre-toi needs a schwa in it.
3. 'etre' and 'avoir_or_etre' tables should be moved to the template call.
3a. (DONE) Make sure aux= is supported at the template level.
4. Implement 'aspirated h'; not all vowel-initial verbs have elision with
   reflexive pronouns.
5. Document the various override arguments.
6. Implement conjugation for -éyer.
7. (MAYBE? MAYBE NOT NECESSARY, {{fr-conj-ir}} doesn't seem to use it,
   MAYBE ALREADY DONE IN THE HEADWORD CODE?) Implement sort= for sort key,
   and handle most cases automatically (e.g. chérir with sort=cherir).
8. (DONE) Copy notes from {{fr-conj-ir}} to our conj["ir"].
9. (DONE) Lots of other conjugations needed. Consider generalizing existing code
   so a minimal number of principal parts can be given and all the conjugation
   and pronunciation derived.
10. (DONE) Convert remaining use of old templates to use {{fr-conj-auto}}.
11. (DONE) Figure out what the COMBINING flag in [[Module:fr-pron]] does and
	remove it, including all calls from this module.
12. (ALREADY DONE) Support sevrer, two-stem e/è verb.
13. (DONE) Autodetect e-er verbs including eCer as well as eCler and eCrer verbs
	like sevrer, and eguer/equer (if they exist). Make sure there aren't
	verbs of this form that aren't e-er by looking for them in the list of
	fr-conj-auto verbs that have an empty typ arg (possibly enough to look
	at all fr-conj-auto verbs).
14. Check pronunciation of 'pleuvoir'. TLFi says /pløvwaʁ/, frwikt says /plœvwaʁ/.
15. (DONE) Check if -er-type conjugations of -aillir, -cueillir, braire are
	correct.
16. (DONE) Fix notes for prefixed croitre/croître verbs, based on the old-style
	templates.
17. (DONE) Implement impersonal and only-third verbs, including impers=
	and onlythird=.
18. (DONE) Fix schwa in -ayer, -eyer pronunciation and check other uses of
	ind_f() to see if they need a fut_stem_i.
19. Implement sort key in {{fr-verb}}. Should map accented letters to
	unaccented letters and rearrange "se regarded" to "regarded, se" and
	similarly for "s'infiltrer".
20. "se regarder" should have optional schwa in re-.

Remaining templates:

-- copier-coller: FIXME, eventually implement general support for verbs like this
--]=]

-- Table of exported functions.
local export = {}
-- Table of conjugation functions. The keys are verbal suffixes (e.g. "ir",
-- "iller") and the values are no-argument functions that apply to verbs whose
-- infinitive contains that suffix, unless the verb also matches a conjugation
-- corresponding to a longer suffix. The values take all info on the verb
-- from 'data' (see below) and set properties of 'data' to indicate the
-- verb forms and pronunciation.
local conj = {}

-- If not false, compare this module with new version of module to make
-- sure all conjugations and pronunciations are the same. If "error", issue
-- an error whenever they are different, with the contents of the error
-- indicating the different forms; otherwise, use the tracking category
-- [[Template:tracking/fr-verb/different-conj]] (see what links there to see
-- the differing verbs; there's also [[Template:tracking/fr-verb/same-conj]]
-- for the verbs that don't differ, which can be used to verify that all verbs
-- have been processed, as it takes awhile for this to happen).
local test_new_fr_verb_module = false

local m_core = require("Module:fr-verb/core")
local m_pron = require("Module:fr-verb/pron")
local m_links = require("Module:links")
local m_conj = require("Module:fr-conj")
local m_fr_pron = require("Module:fr-pron")
local lang = require("Module:languages").getByCode("fr")
local ut = require("Module:utils")
local m_utilities = require("Module:utilities")
local m_debug = require("Module:debug")

local u = mw.ustring.char
local rfind = mw.ustring.find
local rsubn = mw.ustring.gsub
local rmatch = mw.ustring.match
local rsplit = mw.text.split
local ulower = mw.ustring.lower
local uupper = mw.ustring.upper
local usub = mw.ustring.sub
local ulen = mw.ustring.len

local written_vowel = "aàâeéèêiîoôuûäëïöüÿ"
local written_cons_c = "[^%-" .. written_vowel .. "]"
local written_cons_no_cgy_c = "[^%-cgy" .. written_vowel .. "]"
local written_cons_no_cgyx_c = "[^%-cgyx" .. written_vowel .. "]"
local written_cons_no_lryx_c = "[^%-lryx" .. written_vowel .. "]"

-- version of rsubn() that discards all but the first return value
local function rsub(term, foo, bar)
	local retval = rsubn(term, foo, bar)
	return retval
end

-- Map a function over one of the following:
-- (1) a single string (return value will be FUN(STRING))
-- (2) a list of either strings or tables of the form {"STEM", RESPELLING="RESPELLING"};
--     the return value is a list of calls to FUN, with one element per element in SEQ;
--     if an element of SEQ is a string, the corresponding return value will be
--     FUN(STRING); if an element of SEQ is a table, the corresponding return value
--     will be FUN("STEM"), unless third arg USE_RESPELLING is given, in which case
--     the corresponding return value will be FUN("RESPELLING").
local function map(seq, fun, use_respelling)
	if type(seq) == "table" then
		local ret = {}
		for _, s in ipairs(seq) do
			local single_stem_or_respelling
			if type(s) == "table" then
				if use_respelling then
					assert(s.respelling)
					s = s.respelling
				else
					s = s[1]
				end
			end
			-- store in separate var in case fun() has multiple retvals
			local retval = fun(s)
			table.insert(ret, retval)
		end
		return ret
	else
		-- store in separate var in case fun() has multiple retvals
		local retval = fun(seq)
		return retval
	end
end

local function IPA(str)
	return require("Module:IPA").format_IPA(nil, str)
end

local function pron(str)
	return m_fr_pron.show(str, "v")
end

local function dopron(data, stem, suffix)
	suffix = suffix or ""
	return map(stem, function(s)
		return pron((data and data.pronstem or "") .. s .. suffix)
	end, "respelling")
end

local function setform(data, form, val)
	data.forms[form] = val
	data.prons[form] = dopron(data, val)
end

local all_verb_props = {
	"inf", "pp", "ppr",
	"inf_nolink", "pp_nolink", "ppr_nolink",
	"ind_p_1s", "ind_p_2s", "ind_p_3s", "ind_p_1p", "ind_p_2p", "ind_p_3p",
	"ind_i_1s", "ind_i_2s", "ind_i_3s", "ind_i_1p", "ind_i_2p", "ind_i_3p",
	"ind_ps_1s", "ind_ps_2s", "ind_ps_3s", "ind_ps_1p", "ind_ps_2p", "ind_ps_3p",
	"ind_f_1s", "ind_f_2s", "ind_f_3s", "ind_f_1p", "ind_f_2p", "ind_f_3p",
	"cond_p_1s", "cond_p_2s", "cond_p_3s", "cond_p_1p", "cond_p_2p", "cond_p_3p",
	"sub_p_1s", "sub_p_2s", "sub_p_3s", "sub_p_1p", "sub_p_2p", "sub_p_3p",
	"sub_pa_1s", "sub_pa_2s", "sub_pa_3s", "sub_pa_1p", "sub_pa_2p", "sub_pa_3p",
	"imp_p_2s", "imp_p_1p", "imp_p_2p"
}

-- List of verbs are conjugated using 'être' in the passé composé.
-- FIXME: This should be in the template, not here.
local etre = {
	"aller",
	"apparaitre", "apparaître",
	"arriver",
	"entrer",
	"mourir",
	"naitre", "naître", "renaitre", "renaître",
	"partir", "repartir",
	"repasser",
	"rester",
	"surmener",
	"retomber",
	"venir", "advenir", "bienvenir", "devenir", "intervenir", "obvenir", "parvenir", "provenir", "redevenir", "revenir", "survenir"
}

for _,key in ipairs(etre) do
	etre[key] = true
end

-- List of verbs that can be conjugated using either 'avoir' or 'être' in the
-- passé composé. FIXME: This should be in the template, not here.
local avoir_or_etre = {
	"descendre", "monter", "paraitre", "paraître", "passer",
	"rentrer", "repartir", "ressortir", "retourner", "réapparaitre", "réapparaître",
	"sortir", "tomber"
}

for _,key in ipairs(avoir_or_etre) do
	avoir_or_etre[key] = true
end

-- Table mapping verb suffixes to other verb suffixes that they are
-- conjugated the same as. Only required when there is a shorter-length
-- suffix of the verb that has a different conjugation (in this case,
-- 'naitre' and 'naître').
local alias = {
	["connaitre"] = "aitre",
	["connaître"] = "aître",
}

-- List of -ir verbs that do not take -iss- infix.
local ir_s = {
	"dormir", "endormir", "redormir", "rendormir",
	"partir", "départir", "repartir",
	"sortir", "ressortir",
	"sentir", "assentir", "consentir", "pressentir", "ressentir",
	"mentir", "démentir",
	"servir", "desservir", "resservir",
	"repentir"
}
for _,key in ipairs(ir_s) do
	ir_s[key] = true
end

local function link(term, alt)
	return m_links.full_link({lang = lang, term = term, alt = alt}, "term")
end

-- Clone parent's args while also assigning nil to empty strings.
local function clone_args(frame)
	local args = {}
	for pname, param in pairs(frame:getParent().args) do
		if param == "" then args[pname] = nil
		else args[pname] = param
		end
	end
	return args
end

local function track(page)
	m_debug.track("fr-verb/" .. page)
	return true
end

local function unsupported_pron(data)
	if data.pron then
		error("Pronunciation respelling (pron=) not supported for this verb")
	end
end

-- Remove the expected ending ENDING from IPA pronunciation PRON (possibly
-- nil); error if ending not present.
local function strip_pron_ending(pron, ending)
	if not pron then
		return nil
	end
	return map(pron, function(val)
		if not rfind(val, ending .. "$") then
			error('Internal error: expected pronunciation "' .. val .. '" to end with "' .. ending .. '"')
		end
		return rsub(val, ending .. "$", "")
	end)
end

-- Remove the expected ending ENDING from respelling pronunciation PRON
-- (possibly nil or a sequence); error if ending not present.
local function strip_respelling_ending(pron, ending)
	if not pron then
		return nil
	end
	return map(pron, function(val)
		if not rfind(val, ending .. "$") then
			error('Expected respelling "' .. val .. '" to end with "' .. ending .. '"')
		end
		return rsub(val, ending .. "$", "")
	end)
end

-- Remove the expected beginning BEGINNING from respelling pronunciation PRON
-- (possibly nil); error if beginning not present. If SPLIT, split the value
-- of PRON on comma, strip the beginning from each component, and paste
-- together.
local function strip_respelling_beginning(pron, beginning, split)
	if not pron then
		return nil
	end
	if split then
		local pronvals = rsplit(pron, ",")
		local stripped_pronvals = {}
		for _, pronval in ipairs(pronvals) do
			table.insert(stripped_pronvals, strip_respelling_beginning(pronval, beginning))
		end
		return table.concat(stripped_pronvals, ",")
	end
	if not rfind(pron, "^" .. beginning) then
		error('Expected respelling "' .. pron .. '" to begin with "' .. beginning .. '"')
	end
	return rsub(pron, "^" .. beginning, "")
end

-- Construct the pronunciation of all forms of an -er verb. PRONSTEM is the
-- pronunciation respelling of the stem (minus -er). If PRONSTEM_FINAL_FUT is
-- given, it is used in place of PRONSTEM for the forms without a pronounced
-- ending (i.e. 1s/2s/3s/3p present) and for the future and conditional; this
-- is used with two-stem verbs such as mener (with stems 'men' and 'mèn') and
-- céder (with stems 'céd' and 'cèd').
local function construct_er_pron(data, pronstem, pronstem_final_fut)
	pronstem_final_fut = pronstem_final_fut or pronstem
	pronstem = map(pronstem, function(stem) return data.pronstem .. stem end)
	pronstem_final_fut = map(pronstem_final_fut, function(stem)
		stem = data.pronstem .. stem
		-- In pronstem_final_fut, convert é+C in the last syllable to è even if
		-- the caller didn't do it. This is principally useful with pron=
		-- specifications, so that e.g. pron=blésser,blèsser works.
		stem = rsub(stem, "é(" .. written_cons_c .. "+)$", "è%1")
		return rsub(stem, "é([gq]u)$", "è%1")
	end)
	local stem_final = dopron(nil, pronstem_final_fut, "e")
	local stem_nonfinal = strip_pron_ending(dopron(nil, pronstem, "ez"), "e")
	local stem_nonfinal_i = strip_pron_ending(dopron(nil, pronstem, "iez"), "je")
	local stem_fut = strip_pron_ending(dopron(nil, pronstem_final_fut, "erez"), "e")
	local stem_fut_i = strip_pron_ending(dopron(nil, pronstem_final_fut, "eriez"), "je")
	return m_pron.er(data, stem_final, stem_nonfinal, stem_nonfinal_i,
		stem_fut, stem_fut_i)
end

-- Construct the conjugation and pronunciation of all forms of a non-er verb.
-- DATA holds the forms and pronunciations. The remaining args are stems:
--
-- * PRES_SG_STEM is used for pres indic/imper 1s/2s/3s;
-- * PRES_12P_STEM is used for pres indic/imper 1p/2p, the whole of the
--    imperfect, and the present participle;
-- * PRES_3P_STEM is used for pres indic 3p and the whole of the pres subj;
-- * PAST_STEM is used for the past historic and past participle;
-- * FUT_STEM (which should end with 'r') is used for the future and
--    conditional. If omitted, it is taken from the infinitive minus final -e.
-- * PP is the past participle. If omitted, if defaults to PAST_STEM.
-- * PRES_SUBJ_STEM if given overrides the present subjunctive stem.
-- * PRES_SUBJ_NONFINAL_STEM if given overrides the present subjunctive stem
--    specifically for 1p/2p, defaulting to PRES_SUBJ_STEM.
-- * ER_PRESENT, if true, specifies that the present singular follows an
--    -er type of conjugation (endings -e, -es, -e in place of -s, -s, -t).
--    In this case, PRES_12P_STEM and PRES_3P_STEM are currently ignored.
--    Normally, use construct_non_er_conj_er_present() in place of this arg.
--
-- Any of the stem arguments may actually be a table, where each element can be
-- a string (a stem) or a table of the form {"STEM", RESPELLING="RESPELLING"},
-- specifying a stem to use for constructing the verb forms and the corresponding
-- respelling to use when constructing the pronunciation. This is used, for
-- example, in mourir and courir.
local function construct_non_er_conj(data, pres_sg_stem, pres_12p_stem,
	pres_3p_stem, past_stem, fut_stem, pp, pres_subj_stem,
	pres_subj_nonfinal_stem, er_present)
	if er_present then
		m_core.make_ind_p_e(data, pres_sg_stem)
	else
		m_core.make_ind_p(data, pres_sg_stem, pres_12p_stem, pres_3p_stem)
	end
	m_core.make_ind_ps(data, past_stem)
	if not fut_stem then
		fut_stem = rsub(data.forms.inf, "e$", "")
	end
	m_core.make_ind_f(data, fut_stem)

	-- Most of the time it works to add 's' to produce the 1sg (it doesn't
	-- always work to use the stem directly, cf. apparais vs. apparai). But
	-- this fails with stems ending in -er, e.g 'resser-' from 'resservir',
	-- because the 'r' will be silent. In that case, we add 't' to produce
	-- the 3sg. We can't always add 't' because that will fail with e.g.
	-- 'ressen-' from 'ressentir', where the resulting '-ent' will be silent.
	if pres_sg_stem ~= "—" then
		if er_present then
			local stem_final_pron = dopron(data, pres_sg_stem, "e")
			local stem_nonfinal_pron = strip_pron_ending(dopron(data, pres_sg_stem, "ez"), "e")
			local stem_nonfinal_i_pron = strip_pron_ending(dopron(data, pres_sg_stem, "iez"), "je")
			m_pron.er(data, stem_final_pron, stem_nonfinal_pron,
				stem_nonfinal_i_pron)
		else
			local pres_sg_stem_pron = map(pres_sg_stem, function(stem)
				return rmatch(data.pronstem .. stem, "er$") and dopron(data, stem, "t") or dopron(data, stem, "s")
			end, "respelling")
			local pres_12p_stem_pron = strip_pron_ending(dopron(data, pres_12p_stem, "ez"), "e")
			local pres_3p_stem_pron = dopron(data, pres_3p_stem, "e")
			local pre_j_stem_pron = strip_pron_ending(dopron(data, pres_12p_stem, "iez"), "je")
			m_pron.ind_p(data, pres_sg_stem_pron, pres_12p_stem_pron, pres_3p_stem_pron, pre_j_stem_pron)
		end
	end
	if past_stem ~= "—" then
		local past_stem_pron = dopron(data, past_stem)
		m_pron.ind_ps(data, past_stem_pron)
	end
	if fut_stem ~= "—" then
		local fut_stem_pron = strip_pron_ending(dopron(data, fut_stem, "ez"), "e")
		-- If the future stem ends in -er, the schwa is optional in -erez but
		-- not in -eriez; examples are assaillir, cueillir, refaire, défaire,
		-- contrefaire, méfaire (the latter four have the future pronounced
		-- -fer-). Also, if the future stem ends in -Cr, there will be an
		-- extra syllable inserted before -ions, -iez.
		local fut_stem_pron_i = strip_pron_ending(dopron(data, fut_stem, "iez"), "je")
		m_pron.ind_f(data, fut_stem_pron, fut_stem_pron_i)
	end

	if pp then
		data.forms.pp = pp
		if pp ~= "—" then
			data.prons.pp = dopron(data, pp)
		end
	end

	if pres_subj_stem then
		m_core.make_sub_p(data, pres_subj_stem, pres_subj_nonfinal_stem)
		if pres_subj_stem ~= "—" then
			local pres_subj_pron1 = dopron(data, pres_subj_stem, "e")
			local pres_subj_pron2 = strip_pron_ending(dopron(data, pres_subj_nonfinal_stem or pres_subj_stem, "iez"), "je")
			m_pron.sub_p(data, pres_subj_pron1, pres_subj_pron2)
		end
	end
end

-- Construct the conjugation and pronunciation of all forms of a non-er verb
-- with an -er type of present (singular -e, -es, -e). DATA holds the forms
-- and pronunciations. The remaining args are stems:
--
-- * PRES_STEM is used for the whole of the present as well as the imperfect
--    indicative;
-- * PAST_STEM is used for the past historic and past participle;
-- * FUT_STEM (which should end with 'r') is used for the future and
--    conditional. If omitted, it is taken from the infinitive minus final -e.
-- * PP is the past participle. If omitted, if defaults to PAST_STEM.
-- * PRES_SUBJ_STEM if given overrides the present subjunctive stem.
-- * PRES_SUBJ_NONFINAL_STEM if given overrides the present subjunctive stem
--    specifically for 1p/2p, defaulting to PRES_SUBJ_STEM.
--
-- Any of the stem arguments may actually be a table of stems.
local function construct_non_er_conj_er_present(data, pres_stem, past_stem,
	fut_stem, pp, pres_subj_stem, pres_subj_nonfinal_stem)
	-- Specify the pp explicitly, explicitly defaulting to the past_stem,
	-- else if will end in -é.
	construct_non_er_conj(data, pres_stem, nil, nil, past_stem, fut_stem,
	pp or past_stem, pres_subj_stem, pres_subj_nonfinal_stem, "er-present")
end

local function copy_ind_pron_to_imp(data)
	data.prons.imp_p_2s = data.prons.ind_p_2s
	data.prons.imp_p_1p = data.prons.ind_p_1p
	data.prons.imp_p_2p = data.prons.ind_p_2p
end

local function generate_imp_pron_from_forms(data)
	data.prons.imp_p_2s = dopron(data, data.forms.imp_p_2s)
	data.prons.imp_p_1p = dopron(data, data.forms.imp_p_1p)
	data.prons.imp_p_2p = dopron(data, data.forms.imp_p_2p)
end

local function impersonal_verb(data)
	for _, k in ipairs(all_verb_props) do
		if rmatch(k, "[12]") or rmatch(k, "3p") then
			data.forms[k] = "—"
		end
	end
end

local function only_third_verb(data)
	for _, k in ipairs(all_verb_props) do
		if rmatch(k, "[12]") then
			data.forms[k] = "—"
		end
	end
end

conj["er"] = function(data)
	if data.stem == "all" then
		data.stem = ""
		data.pronstem = strip_respelling_ending(data.pron, "aller") or data.stem
		conj["irreg-aller"](data)
		data.forms.inf = "aller"

		data.conjcat = "aller"
		data.cat = "suppletive"
	else
		m_core.make_ind_p_e(data, "")
		construct_er_pron(data, "")
		data.group = 1
		data.conjcat = "-er"
	end
end

conj["cer"] = function(data)
	m_core.make_ind_p_e(data, "c", "ç")

	data.notes = "This verb is part of a group of " .. link("-er") .. " verbs for which 'c' is softened to a 'ç' before the vowels 'a' and 'o'."
	construct_er_pron(data, "c")
	data.group = 1
	data.conjcat = "-cer"
end

conj["ger"] = function(data)
	m_core.make_ind_p_e(data, "g", "ge")

	data.notes = "This is a regular " .. link("-er") .. " verb, but the stem is written ''{stem}ge-'' before endings that begin with ''-a-'' or ''-o-'' "
	data.notes = data.notes .. "(to indicate that the ''-g-'' is a \"soft\" " .. IPA("/ʒ/") .. " and not a \"hard\" " .. IPA("/ɡ/") .. "). "
	data.notes = data.notes .. "This spelling-change occurs in all verbs in ''-ger'', such as "
	data.notes = data.notes .. link(data.stem == "nei" and "bouger" or "neiger") .. " and "
	data.notes = data.notes .. link(data.stem == "man" and "ranger" or "manger") .. "."

	construct_er_pron(data, "g")
	data.group = 1
	data.conjcat = "-ger"
end

conj["ayer"] = function(data)
	data.notes = "This is a regular " .. link("-er") .. " verb as far as "
		.. "pronunciation is concerned, but as with other verbs in ''-ayer'' "
		.. "(such as " .. link(data.stem == "pay" and "essayer" or "payer")
		.. " and " .. link((data.stem == "pay" or data.stem == "essay") and "balayer" or "essayer")
		.. ", the &lt;y&gt; of its stem may optionally be written as &lt;i&gt; "
		.. "when it precedes a silent &lt;e&gt; (compare verbs in ''-eyer'', "
		.. "which never have this spelling change, and verbs in ''-oyer'' "
		.. "and ''-uyer'', which always have it; verbs in ''-ayer'' belong to "
		.. "either group, according to the writer's preference)."

	m_core.make_ind_p_e(data, {"ay", "ai"}, "ay", "ay")
	construct_er_pron(data, {"ay", "éy"}, {"ay", "ai"})
	data.group = 1
	data.conjcat = "-ayer"
end

conj["eyer"] = function(data)
	m_core.make_ind_p_e(data, "ey")
	construct_er_pron(data, {"ey", "éy"}, "ey")
	data.group = 1
	data.conjcat = "-eyer"
end

conj["yer"] = function(data)
	data.notes = "This verb is part of a large group of " .. link("-er")
		.. " verbs that conjugate like "
		.. link(data.stem == "no" and "employer" or "noyer") .. " or "
		.. link(data.stem == "ennu" and "appuyer" or "ennuyer") .. ". These "
		.. "verbs always replace the 'y' with an 'i' before a silent 'e'."

	m_core.make_ind_p_e(data, "i", "y", "y")
	construct_er_pron(data, "y", "i")
	data.group = 1
	data.conjcat = "-yer"
end

conj["xxer"] = function(data)
	local newstem, consonant = rmatch(data.stem, "^(.*)e(" .. written_cons_c .. ")$")
	if not consonant then
		error("Stem '" .. data.stem .. "' should end with -e- + consonant")
	end
	data.forms.inf = "e" .. consonant .. "er" -- not xxer
	local origstem = data.stem
	data.stem = newstem
	data.pronstem = strip_respelling_ending(data.pron, data.forms.inf) or data.stem

	data.notes = "With the exception of " .. (origstem == "appel" and "''appeler''" or link("appeler")) .. ", "
	data.notes = data.notes .. (origstem == "jet" and "''jeter''" or link("jeter")) .. " and their derived verbs, "
	data.notes = data.notes .. "all verbs that used to double the consonants can now also be conjugated like " .. link("amener") .. "."

	if rfind(origstem, "jet$") or rfind(origstem, "appel$") then
		m_core.make_ind_p_e(data, "e" .. consonant .. consonant,
			"e" .. consonant, "e" .. consonant)
	else
		m_core.make_ind_p_e(data, {"e" .. consonant .. consonant, "è" .. consonant},
			"e" .. consonant, "e" .. consonant)
	end
	construct_er_pron(data, "e" .. consonant, "e" .. consonant .. consonant)
	data.group = 1
	data.conjcat = "-xxer"
end

conj["e-er"] = function(data)
	local newstem, consonant = rmatch(data.stem, "^(.*)e(" .. written_cons_c .. "+)$")
	if not consonant then
		error("Stem '" .. data.stem .. "' should end with -e- + one or more consonants")
	end
	local stem = 'e' .. consonant
	local stem2 = 'è' .. consonant
	data.forms.inf = stem .. "er" -- not e-er
	local origstem = data.stem
	data.stem = newstem
	data.pronstem = strip_respelling_ending(data.pron, data.forms.inf) or data.stem

	data.notes = "This verb is conjugated mostly like the regular " .. link("-er") .. " verbs (" .. link("parler") .. " and " .. link("chanter") .. " and so on), "
	data.notes = data.notes .. "but the ''-e-'' " .. IPA("/ə/") .. " of the second-to-last syllable becomes ''-è-'' " .. IPA("/ɛ/") .. " when the next vowel is a silent or schwa ''-e-''. "
	data.notes = data.notes .. "For example, in the third-person singular present indicative, we have ''il {stem}" .. stem2 .. "e'' rather than *''il {stem}" .. stem .. "e''. "
	data.notes = data.notes .. "Other verbs conjugated this way include " .. link(origstem == "lev" and "acheter" or "lever") .. " and " .. link(origstem == "men" and "acheter" or "mener") .. ". "
	data.notes = data.notes .. "Related but distinct conjugations include those of " .. link("appeler") .. " and " .. link("préférer") .. "."

	m_core.make_ind_p_e(data, stem2, stem, stem)
	construct_er_pron(data, stem, stem2)
	data.group = 1
	data.conjcat = "-e-er"
end

conj["ecer"] = function(data)
	m_core.make_ind_p_e(data, "èc", "eç", "ec")
	construct_er_pron(data, "ec", "èc")
	data.group = 1
	data.conjcat = "-e-er"
end

conj["eger"] = function(data)
	m_core.make_ind_p_e(data, "èg", "ege", "eg")
	construct_er_pron(data, "eg", "èg")
	data.group = 1
	data.conjcat = "-e-er"
end

conj["é-er"] = function(data)
	local newstem, consonant = rmatch(data.stem, "^(.*)é(" .. written_cons_c .. "+)$")
	if not consonant then
		newstem, consonant = rmatch(data.stem, "^(.*)é([gq]u)$")
	end
	if not consonant then
		error("Stem '" .. data.stem .. "' should end with -e- + one or more consonants")
	end
	local stem = 'é' .. consonant
	local stem2 = 'è' .. consonant
	data.forms.inf = stem .. "er" -- not é-er
	local origstem = data.stem
	data.stem = newstem
	data.pronstem = strip_respelling_ending(data.pron, data.forms.inf) or data.stem

	data.notes = "This verb is conjugated like "
	if origstem == "céd" then
		data.notes = data.notes .. link("espérer")
	else
		data.notes = data.notes .. link("céder")
	end
	data.notes = data.notes .. ". It is a regular " .. link("-er") .. " verb, "
	data.notes = data.notes .. "except that its last stem vowel alternates between " .. IPA("/e/") .. " (written 'é') and "
	data.notes = data.notes .. IPA("/ɛ/") .. " (written 'è'), with the latter being used before mute 'e'.\n"
	data.notes = data.notes .. "One special case is the future stem, used in the future and the conditional. "
	data.notes = data.notes .. "Before 1990, the future stem of such verbs was written ''{stem}" .. stem .. "er-'', "
	data.notes = data.notes .. "reflecting the historic pronunciation " .. IPA("/e/") .. ". "
	data.notes = data.notes .. "In 1990, the French Academy recommended that it be written ''{stem}" .. stem2 .. "er-'', "
	data.notes = data.notes .. "reflecting the now common pronunciation " .. IPA("/ɛ/") .. ", "
	data.notes = data.notes .. "thereby making this distinction consistent throughout the conjugation "
	data.notes = data.notes .. "(and also matching in this regard the conjugations of verbs like " .. link("lever") .. " and " .. link("jeter") .. "). "
	data.notes = data.notes .. "Both spellings are in use today, and both are therefore given here."

	m_core.make_ind_p_e(data, stem2, stem, stem)
	m_core.make_ind_f(data, {stem2 .. "er", stem .. "er"})
	construct_er_pron(data, stem, stem2)
	data.group = 1
	data.conjcat = "-é-er"
end

conj["écer"] = function(data)
	data.notes = "This verb is conjugated like " .. link("rapiécer") .. ". It has both the spelling irregularities of other verbs in ''<span lang=\"fr\">-cer</span>'' "
	data.notes = data.notes .. "(such as " .. link("pincer") .. ", where a silent 'e' is inserted before 'a' and 'o' endings (to indicate the " .. IPA("/s/") .. " sound), "
	data.notes = data.notes .. "and the spelling and pronunciation irregularities of other verbs in ''<span lang=\"fr\">-é-er</span>'' (such as " .. link("céder") .. ", "
	data.notes = data.notes .. "where the last stem vowel alternates between " .. IPA("/e/") .. " (written 'é') and " .. IPA("/ɛ/") .. " (written 'è')."

	m_core.make_ind_p_e(data, "èc", "éç", "éc")
	m_core.make_ind_f(data, {"écer", "ècer"})
	construct_er_pron(data, "éc", "èc")
	data.group = 1
	data.conjcat = "-é-er"
end

conj["éger"] = function(data)
	data.notes = "This verb is conjugated like "
	if data.stem == "prot" then
		data.notes = data.notes .. link("assiéger")
	else
		data.notes = data.notes .. link("protéger")
	end
	data.notes = data.notes .. ". It has both the spelling irregularities of other verbs in ''-ger'' (such as " .. link("manger") .. ", "
	data.notes = data.notes .. "where a silent 'e' is inserted before 'a' and 'o' endings (to indicate the " .. IPA("/ʒ/") .. " sound), "
	data.notes = data.notes .. "and the spelling and pronunciation irregularities of other verbs in ''-é-er'' (such as " .. link("céder") .. "), "
	data.notes = data.notes .. "where the last stem vowel alternates between " .. IPA("/e/") .. " (written 'é') and " .. IPA("/ɛ/") .. " (written 'è')."

	m_core.make_ind_p_e(data, "èg", "ége", "ég")
	m_core.make_ind_f(data, {"éger", "èger"})
	construct_er_pron(data, "ég", "èg")
	data.group = 1
	data.conjcat = "-é-er"
end

conj["ir-s"] = function(data)
	local ending = usub(data.stem, -1, -1)
	data.stem = usub(data.stem, 1, -2)
	data.pronstem = strip_respelling_ending(data.pron, ending .. "ir") or data.stem

	data.notes = "This is one of a fairly large group of irregular " .. link("-ir") .. " verbs that are all conjugated the same way. "
	data.notes = data.notes .. "Other members of this group include "
	if data.stem..ending.."ir" == "sortir" then
		data.notes = data.notes .. link("partir")
	else
		data.notes = data.notes .. link("sortir")
	end
	data.notes = data.notes .. " and "
	if data.stem..ending.."ir" == "dormir" then
		data.notes = data.notes .. link("servir")
	else
		data.notes = data.notes .. link("dormir")
	end
	data.notes = data.notes .. ". The most significant difference between these verbs' conjugation and that of the regular ''-ir'' verbs is that "
	data.notes = data.notes .. "these verbs' conjugation does not use the infix " .. link("-iss-") .. ". "
	data.notes = data.notes .. "Further, this conjugation has the forms " .. link("{stem}s", "(je, tu) {stem}s") .. " and " .. link("{stem}t", "(il) {stem}t") .. " "
	data.notes = data.notes .. "in the present indicative and imperative, whereas a regular ''-ir'' verb would have ''*{stem}" .. ending .. "is'' and ''*{stem}" .. ending .. "it'' (as in the past historic)."

	data.forms.inf = ending .. "ir"
	construct_non_er_conj(data, "", ending, ending, ending .. "i")
	data.conjcat = "-ir"
end

conj["ir-reg"] = function(data)
	-- if ir-reg explicitly used in type argument (e.g. ressortir), inf will
	-- be ir-reg by default with messed-up future
	data.forms.inf = "ir"
	construct_non_er_conj(data, "i", "iss", "iss", "i")
	data.notes = "This is a regular verb of the second conjugation, like "
		.. (data.stem == "fin" and "nourrir" or "finir") .. ", "
		.. (data.stem == "chois" and "nourrir" or "choisir")
		.. ", and most other verbs with infinitives ending in " .. link("-ir")
		.. ". One salient feature of this conjugation is the repeated "
		.. "appearance of the infix " .. link("-iss-") .. "."
	data.group = 2
	data.conjcat = "-ir"
end

conj["ir"] = function(data)
	if ir_s[data.stem.."ir"] then
		conj["ir-s"](data)
	else
		conj["ir-reg"](data)
	end
end

conj["ïr"] = function(data)
	construct_non_er_conj(data, "ï", "ïss", "ïss", "ï")
	data.group = 2
	data.conjcat = "-ïr"
end

conj["haïr"] = function(data)
	data.notes = "This verb is spelled as if conjugated like " .. link("finir") .. ", but has a [[diaeresis]] throughout its conjugation "
	data.notes = data.notes .. "(including where the circumflex would normally be used) except in the singular indicative present, "
	data.notes = data.notes .. "whose forms are pronounced " .. IPA("/ɛ/") .. " in Standard French instead of " .. IPA("/ai/") .. ", "
	data.notes = data.notes .. "a pronunciation nonetheless often found in informal speech."

	construct_non_er_conj(data, "hai", "haïss", "haïss", "haï")
	data.conjcat = "haïr"
end

conj["ouïr"] = function(data)
	data.notes = "The forms beginning with ''oi-'', ''oy-'', or ''orr-'' are archaic."

	construct_non_er_conj(data, {"ouï", "oi"}, {"ouïss", "oy"},
		{"ouïss", "oi"}, "ouï", {"ouïr", "oir", "orr"})
	-- Need to override the pronunciations of all forms in oy-.
	data.prons.ind_p_1p = dopron(data, {"ouïssons", "oillons"})
	data.prons.ind_p_2p = dopron(data, {"ouïssez", "oillez"})
	copy_ind_pron_to_imp(data)
	m_pron.ind_i(data, strip_pron_ending(dopron(data, {"ouïssez", "oillez"}), "e"))
	m_pron.sub_p(data, dopron(data, {"ouïsse", "oie"}), strip_pron_ending(
		dopron(data, {"ouïssiez", "oilliez"}), "je"))
	data.prons.ppr = dopron(data, {"ouïssant", "oillant"})
	data.conjcat = "ouïr"
end

conj["asseoir"] = function(data)
	data.notes = "The verb " .. link("asseoir") .. " (and its derivative " .. link("rasseoir") .. ") has 2 distinct conjugations."

	construct_non_er_conj(data, {"assoi", "assied"}, {"assoy", "assey"},
		{"assoi", "assey"}, "assi", {"assoir", "assiér"}, "assis")
	data.conjcat = "seoir"
end

conj["surseoir"] = function(data)
	construct_non_er_conj(data, "sursoi", "sursoy", "sursoi", "sursi", nil,
		"sursis")
	-- Pronunciation in future/cond as if written sursoir- not surseoir-
	m_pron.ind_f(data, strip_pron_ending(dopron(data, "sursoirez"), "e"))
	data.conjcat = "seoir"
end

conj["seoir"] = function(data)
	data.notes = "This is a defective verb, only conjugated in the third person."

	construct_non_er_conj(data, "sied", "sey", "sié", "—", "siér")
	only_third_verb(data)
	setform(data, "ppr", {"séant","seyant"})
	data.conjcat = "seoir"
	data.cat = "defective"
end

conj["bouillir"] = function(data)
	construct_non_er_conj(data, "bou", "bouill", "bouill", "bouilli")
	data.conjcat = "bouillir"
end

conj["enir"] = function(data)
	construct_non_er_conj(data, "ien", "en", "ienn", "in", {{"iendr", respelling="iaindr"}}, "enu")

	if usub(data.stem,-1) == "t" then
		data.notes = "This is a verb in a group of " .. link("-ir")
			.. " verbs. All verbs ending in " .. "''-tenir'', such as "
			.. link(data.stem == "cont" and "retenir" or "contenir")
			.. " and " .. link(data.stem == "dét" and "retenir" or "détenir")
			.. ", are conjugated this way. Such verbs are the only verbs"
			.. " whose the past historic and subjunctive imperfect endings"
			.. " do not start in one of these thematic vowels (''-a-'', ''-i-'', ''-u-'')."
		data.conjcat = "tenir"
	else
		data.notes = "This is a verb in a group of " .. link("-ir")
			.. " verbs. All verbs ending in " .. "''-venir'', such as "
			.. link(data.stem == "conv" and "revenir" or "convenir")
			.. " and " .. link(data.stem == "dev" and "revenir" or "devenir")
			.. ", are conjugated this way. Such verbs are the only verbs"
			.. " whose the past historic and subjunctive imperfect endings"
			.. " do not start in one of these thematic vowels (''-a-'', ''-i-'', ''-u-'')."
		data.conjcat = "venir"
	end
end

local function ouvrir_ffrir(data, rir_prefix)
	data.stem = data.stem .. rir_prefix
	data.pronstem = data.pronstem .. rir_prefix
	data.forms.inf = "rir"

	data.notes = "This verb is conjugated like " .. link(data.stem == "ouv" and "couvrir" or "ouvrir")
		.. " and " .. link(data.stem == "off" and "souffrir" or "offrir") .. ". "
		.. "It is conjugated like a regular " .. link("-er") .. " verb in the present and imperfect indicative, present subjunctive, "
		.. "imperative, and present participle; it is conjugated like a regular " .. link("-ir") .. " verb in the infinitive, "
		.. "future indicative, conditional, past historic, and imperfect subjunctive; "
		.. "and its past participle " .. link("{stem}ert") .. " is irregular."

	construct_non_er_conj_er_present(data, "r", "ri", nil, "ert")
end

conj["ouvrir"] = function(data)
	ouvrir_ffrir(data, "ouv")
end

conj["ffrir"] = function(data)
	ouvrir_ffrir(data, "ff")
end

conj["quérir"] = function(data)
	construct_non_er_conj(data, "quier", "quér", "quièr", "qui", "querr", "quis")
end

conj["aillir"] = function(data)
	data.notes = "This verb is part of a small group of verbs in "
	.. link("-ir") .. " that conjugate in the indicative imperfect and "
	.. "present, the subjunctive present, and the present participle, as if "
	.. "they ended in " .. link("-er") .. ". They are sometimes written with "
	.. "an 'e' in the future and imperfect, like " .. link("cueillir")
	.. " and other verbs in ''-llir''."
	construct_non_er_conj_er_present(data, "aill", "ailli", {"aillir", "ailler"})
end

conj["chauvir"] = function(data)
	data.notes = "The forms without -iss- are recommended by the [[w:Académie française|French Academy]], although their usage is not common."

	construct_non_er_conj(data, "chauvi", {"chauv", "chauviss"},
		{"chauv", "chauviss"}, "chauvi")
	data.group = {2, 3}
end

conj["choir"] = function(data)
	construct_non_er_conj(data, "choi", "choy", "choi", "chu",
		data.stem == "é" and "choir" or {"choir", "cherr"})
	m_core.clear_imp(data)
	data.forms.ppr = "—"

	if data.stem == "" then
		data.notes = "This is a [[defective]] verb, only conjugated in certain tenses."
		-- FIXME! frwikt says 1p 2p of pres indic is rare, and likewise
		-- all of the pres subj.
		m_core.make_ind_i(data, "—")
		-- FIXME! frwikt says future in cherr- is archaic, and archaic
		-- conditional forms in cherr- exist as well.
		m_core.make_cond_p(data, "choir")
		m_pron.cond_p(data, dopron(data, "choir"))
		m_core.make_sub_p(data, "—")
		-- FIXME! frwikt does not say subjunctive past is missing other than
		-- 3s.
		m_core.make_sub_pa(data, "—")
		data.forms.sub_pa_3s = "chût"
	elseif data.stem == "dé" then
		data.notes = "This verb is [[defective]] in that it is not conjugated in certain tenses. It has no indicative imperfect form, no imperative form and no present participle."
		m_core.make_ind_i(data, "—")
		-- FIXME! frwikt does not indicate 'chet' as an alternative. Based on
		-- échoir, we'd expect 'chettent' as alternative as well.
		setform(data, "ind_p_3s", {"choit", "chet"})
		-- FIXME! frwikt lists rare ppr déchoyant.
	elseif data.stem == "é" then
		data.notes = "This verb is [[defective]] and is only conjugated in the third-person."
		only_third_verb(data)
		setform(data, "ind_p_3s", {"choit", "chet"})
		-- FIXME! frwikt gives both échettent and échéent as alternatives,
		-- but gives the pronunciation only of the first.
		setform(data, "ind_p_3p", {"choient", "chettent"})
		setform(data, "ppr", "chéant")
	end
	data.cat = "defective"
end

conj["cueillir"] = function(data)
	construct_non_er_conj_er_present(data, "cueill", "cueilli", {"cueillir", "cueiller"})
end

conj["courir"] = function(data)
	data.notes = "This verb is conjugated like other regular " .. link("-ir") .. " verbs, "
	data.notes = data.notes .. "except that in the conditional and future tenses an extra 'r' is added to the end of the stem "
	data.notes = data.notes .. "and the past participle ends in ''-u''. All verb ending in ''-courir'' are conjugated this way."

	construct_non_er_conj(data, "cour", "cour", "cour", "couru", {{"courr", respelling="cour_r"}})
end

conj["falloir"] = function(data)
	data.notes = "This verb is defective, only conjugated in the third-person singular."
	construct_non_er_conj(data, "fau", "fall", "fall", "fallu", "faudr", nil,
		"faill")
	impersonal_verb(data)
	data.cat = {"defective", "impersonal"}
end

conj["faillir"] = function(data)
	if data.stem == "" then
		data.notes = "This verb has two conjugations, one is older and irregular, "
			.. "but is in modern usage giving way to a conjugation like that of "
			.. link("finir") .. ". It is hardly used except in the infinitive, "
			.. "past historic, and the composed tenses. The third-person singular "
			.. "present indicative " .. link("faut") .. " is also found in "
			.. "certain set phrases."
		construct_non_er_conj(data, "fau", "faill", "faill", "failli",
			{"faudr", "faillir"})
		data.forms.ind_p_1s = "faux"
		data.forms.ind_p_2s = "faux"
		m_core.clear_imp(data)
		data.cat = "defective"
	else
		data.notes = "Verbs in ''-faillir'', with the exception of "
		.. link("faillir") .. " itself, conjugate similarly to other verbs in "
		.. "''-illir'', such as " .. link("assaillir") .. " and "
		.. link("cueillir") .. "."
		-- frwikt doesn't include forms like -faillerai
		construct_non_er_conj_er_present(data, "faill", "failli", "faillir")
	end
end

conj["férir"] = function(data)
	data.notes = "This verb is defective and is virtually never conjugated in Modern French, except in a few set phrases or as a mark of extreme archaism. "
	data.notes = data.notes .. "Most of its uses stem from variations on " .. link("sans coup férir") .. "."

	construct_non_er_conj(data, "—", "—", "—", "—", "—", "féru")
	data.cat = "defective"
end

conj["fuir"] = function(data)
	construct_non_er_conj(data, "fui", "fuy", "fui", "fui")
end

conj["gésir"] = function(data)
	data.notes = "This is a [[defective]] verb, and is only conjugated in the present and imperfect indicative."
	construct_non_er_conj(data, "gi", "gis", "gis", "—", "—", "—", "—")
	data.forms.ind_p_3s = "gît"
	m_core.clear_imp(data)
	data.cat = "defective"
end

conj["re"] = function(data)
	construct_non_er_conj(data, "", "", "", "i", nil, "u")
	data.forms.ind_p_3s = ""
	data.irregular = "no"
end

conj["cre"] = function(data)
	data.notes = "This verb "
	if data.stem ~= "vain" then
		data.notes = data.notes .. "is conjugated like " .. link("vaincre") .. ". That means it "
	end
	data.notes = data.notes .. "is conjugated like " .. link("vendre") .. ", except that its usual stem ''{stem}qu-'' becomes ''{stem}c-'' when either there is no ending, "
	data.notes = data.notes .. "or the ending starts with ''-u-'' or a written consonant. "
	data.notes = data.notes .. "Additionally, when inverted the third person singular in the present adds the infix " .. link("t","-t-") .. ": ''{stem}c-t-il?'' "
	data.notes = data.notes .. "These are strictly spelling changes; pronunciation-wise, the verb is conjugated exactly like " .. link("vendre") .. "."

	construct_non_er_conj(data, "c", "qu", "qu", "qui", nil, "cu")
end

conj["pre"] = function(data)
	data.notes = "This verb "
	if data.stem ~= "rom" then
		data.notes = data.notes .. "is conjugated like " .. link("rompre") .. ". That means it "
	end
	data.notes = data.notes .. "is conjugated like " .. link("vendre") .. ", except that it adds an extra ''-t'' in the third-person singular form of the present indicative: ''il " .. link(data.stem .. "pt") .. "'', not ''*il {stem}p''. "
	data.notes = data.notes .. "This is strictly a spelling change; pronunciation-wise, the verb is conjugated exactly like " .. link("vendre") .. "."

	construct_non_er_conj(data, "p", "p", "p", "pi", nil, "pu")
end

conj["crire"] = function(data)
	construct_non_er_conj(data, "cri", "criv", "criv", "crivi", nil, "crit")
end

conj["rire"] = function(data)
	construct_non_er_conj(data, "ri", "ri", "ri", "ri")
end

conj["uire"] = function(data)
	construct_non_er_conj(data, "ui", "uis", "uis", "uisi", nil, "uit")
end

conj["nuire"] = function(data)
	-- nuire has different pp from other -uire verbs
	construct_non_er_conj(data, "nui", "nuis", "nuis", "nuisi", nil, "nui")
end

conj["aitre"] = function(data)
	data.notes = "This verb is one of a fairly small group of " .. link("-re") .. " verbs, that are all conjugated the same way. They are conjugated the same as the alternative spelling, which has a [[circumflex]] over the 'i', except that the circumflex is dropped here."

	-- future stem must be nil here because we are called from conj["aître"]
	construct_non_er_conj(data, "ai", "aiss", "aiss", "u", nil, "u")
end

conj["aître"] = function(data)
	conj["aitre"](data)
	data.notes = "This verb is one of a fairly small group of " .. link("-re") .. " verbs, that are all conjugated the same way. They are unlike other verb groups in that the 'i' is given a circumflex before a 't'."
	data.forms.ind_p_3s = "aît"
end

conj["oître"] = function(data)
	data.notes = "This verb is one of a fairly small group of " .. link("-re") .. " verbs, that are all conjugated the same way. They are unlike other verb groups in that the 'i' is given a circumflex before a 't'. This conjugation pattern is no longer in use and has been replaced by -aître."

	m_core.make_ind_p(data, "oi", "oiss")
	data.forms.ind_p_3s = "oît"
	m_core.make_ind_ps(data, "u")

	local stem = dopron(data, "ais")
	local stem2 = stem .. ".s"
	local stem3 = stem .. "s"
	local stem4 = dopron(data, "u")

	m_pron.ind_p(data, stem, stem2, stem3)
	m_pron.ind_ps(data, stem4)
	m_pron.ind_f(data, stem .. ".tʁ", stem .. ".tʁi.")
end

conj["indre"] = function(data)
	data.notes = "This verb is conjugated like "
		.. link(data.stem == "pei" and "plaindre" or "peindre")
		.. ". It uses the same endings as " .. link("rendre") .. " or "
		.. link("vendre") .. ", but its ''-nd-'' becomes ''-gn-'' before a "
		.. "vowel, and its past participle ends in 't' instead of a vowel."
	construct_non_er_conj(data, "in", "ign", "ign", "igni", nil, "int")
end

conj["clure"] = function(data)
	local pp
	if data.stem == "in" or data.stem == "trans" or data.stem == "oc" then
		pp = "clus"
		data.notes = "This verb is one of a few verbs in ''-clure'' where the past participle is in ''-us(e)'' instead of ''-u(e)''."
	end

	construct_non_er_conj(data, "clu", "clu", "clu", "clu", nil, pp)
end

conj["raire"] = function(data) --braire, traire
	data.notes = "This verb traditionally has no past historic or imperfect "
		.. "subjunctive. They would be formed on a -{stem}ray- root: "
		.. "*je {stem}rayis, *que nous {stem}rayissions etc. Forms using "
		.. "the 'a' endings of verbs in -er are now used when there is an "
		.. "unavoidable need to use these forms.\n"
		.. "The root -{stem}rais- was used instead of -{stem}ray- in the "
		.. "18th century, and remains in Swiss and Savoy dialects."
	m_core.make_ind_p(data, "rai", "ray", "rai")
	m_core.make_ind_ps_a(data, "ray")

	local stem = dopron(data, "rais")
	data.forms.pp = "rait"

	local stem2 = stem .. ".j"
	local stem3 = stem .. ".ʁ"

	m_pron.ind_p(data, stem, stem2)
	m_pron.ind_ps_a(data, stem2)
	m_pron.ind_f(data, stem3)
	data.prons.pp = stem
end

conj["clore"] = function(data)
	data.notes = "This verb is not conjugated in certain tenses."

	m_core.make_ind_p(data, "clo", "clos")
	data.forms.ind_p_3s = "clôt"
	m_core.make_ind_i(data, "—")
	m_core.make_ind_ps(data, "—")
	data.forms.ppr = "closant"
	data.forms.pp = "clos"

	local stem = dopron(data, "clo")
	local stem2 = stem .. ".z"
	local stem3 = stem .. "z"
	local stem4 = dopron(data, "clɔ") .. ".ʁ"

	m_pron.ind_p(data, stem, stem2, stem3)
	m_pron.ind_f(data, stem4)
	data.prons.pp = stem
	data.cat = "defective"
end

conj["confire"] = function(data)
	construct_non_er_conj(data, "confi", "confis", "confis", "confi", nil, "confit")
end

conj["suffire"] = function(data)
	construct_non_er_conj(data, "suffi", "suffis", "suffis", "suffi")
end

conj["coudre"] = function(data)
	data.notes = "This verb "
	if data.stem ~= "" then
		data.notes = data.notes .. "is conjugated like " .. link("coudre") .. ". That means it"
	end
	data.notes = data.notes .. " is conjugated like " .. link("rendre") .. ", except that its stem is ''{stem}coud-'' in only part of the conjugation. "
	data.notes = data.notes .. "Before endings that begin with vowels, the stem ''{stem}cous-'' (with a " .. IPA("/-z-/") .. " sound) is used instead; "
	data.notes = data.notes .. "for example, ''nous'' " .. link("{stem}cousons") .. ", not ''*nous {stem}coudons''."

	construct_non_er_conj(data, "coud", "cous", "cous", "cousi", nil, "cousu")
end

conj["croire"] = function(data)
	construct_non_er_conj(data, "croi", "croy", "croi", "cru")
end

conj["croitre"] = function(data)
	if data.stem == "" then
		data.notes = "This verb takes an especially irregular conjugation, taking circumflexes in many forms, so as to distinguish from the forms of the verb " .. link("croire") .. "."
		construct_non_er_conj(data, "croî", "croiss", "croiss", "crû")
		data.forms.ind_ps_1p = "crûmes"
		data.forms.ind_ps_2p = "crûtes"
		data.forms.sub_pa_3s = "crût"
	else
		data.notes = "This verb is conjugated like " .. link("croitre") ..
			" except that it does not take circumflexes like that verb does."
		construct_non_er_conj(data, "croi", "croiss", "croiss", "cru")
	end
end

conj["croître"] = function(data)
	if data.stem == "" or data.stem == "re" then
		data.notes = "This verb takes an especially irregular conjugation, taking circumflexes in many forms, so as to distinguish from the forms of the verb " .. link(data.stem == "re" and "recroire" or "croire") .. "."
		construct_non_er_conj(data, "croî", "croiss", "croiss", "crû")
	else
		data.notes = "This verb is conjugated like " .. link("croître") ..
			" except that it takes fewer circumflexes than that verb does."
		construct_non_er_conj(data, "croi", "croiss", "croiss", "cru")
		data.forms.ind_p_3s = "croît"
	end
	data.forms.ind_ps_1p = "crûmes"
	data.forms.ind_ps_2p = "crûtes"
	data.forms.sub_pa_3s = "crût"
end

conj["foutre"] = function(data)
	construct_non_er_conj(data, "fou", "fout", "fout", "fouti", nil,
		"foutu")
end

conj["soudre"] = function(data)
	construct_non_er_conj(data, "sou", "solv", "solv", "solu", nil, "sous")
	m_core.make_sub_pa(data, "—")
	data.cat = "defective"
end

conj["résoudre"] = function(data)
	data.notes = "This verb also has a rare past participle "
		.. link("résous") .. " (feminine " .. link("résoute") .. ")."
	construct_non_er_conj(data, "résou", "résolv", "résolv", "résolu")
end

conj["voir"] = function(data)
	data.notes = "Verbs derived from " .. link("voir") .. " form their "
		.. "future and conditional forms using the root ''verr-'' instead of "
		.. "the ''vr-'' or ''voir-'' of other verbs."
	construct_non_er_conj(data, "voi", "voy", "voi", "vi", "verr", "vu")
end

conj["prévoir"] = function(data)
	construct_non_er_conj(data, "prévoi", "prévoy", "prévoi", "prévi", nil,
		"prévu")
end

conj["cevoir"] = function(data)
	construct_non_er_conj(data, "çoi", "cev", "çoiv", "çu", "cevr")
end

conj["battre"] = function(data)
	if data.stem ~= "" then
		data.notes = "This verb is conjugated like " .. link("battre") .. ". That means it "
	else
		data.notes = "This verb "
	end
	data.notes = data.notes .. "is conjugated like " .. link("vendre") .. ", " .. link("perdre") .. ", etc. (sometimes called the regular " .. link("-re") .. " verbs), "
	data.notes = data.notes .. "except that instead of *''{stem}batt'' and *''{stem}batts'', "
	data.notes = data.notes .. "it has the forms " .. link("{stem}bat") .. " and " .. link("{stem}bats") .. ". This is strictly a spelling change; "
	data.notes = data.notes .. "pronunciation-wise, the verb is conjugated exactly like " .. link("vendre") .. "."

	construct_non_er_conj(data, "bat", "batt", "batt", "batti", nil, "battu")
end

conj["circoncire"] = function(data)
	construct_non_er_conj(data, "circonci", "circoncis", "circoncis",
		"circonci", nil, "circoncis")
end

conj["lire"] = function(data)
	construct_non_er_conj(data, "li", "lis", "lis", "lu")
end

conj["luire"] = function(data)
	construct_non_er_conj(data, "lui", "luis", "luis", {"lui", "luisi"},
		nil, "lui")
	m_core.make_sub_pa(data, "luisi")
	m_pron.sub_pa(data, dopron(data, "luisi"))
	setform(data, "ind_ps_3s", "luit")
end

conj["maudire"] = function(data)
	data.notes = "This is ''almost'' a regular verb of the second conjugation, like " .. link("finir") .. ", " .. link("choisir") .. ", "
	data.notes = data.notes .. "and most other verbs with infinitives ending in " .. link("-ir") .. ". Its only irregularities are in the past participle, "
	data.notes = data.notes .. "which is " .. link("maudit","maudit(e)(s)") .. " rather than *''maudi(e)(s)'', and in the infinitive, "
	data.notes = data.notes .. "which is ''maudire'' rather than *''maudir''."

	construct_non_er_conj(data, "maudi", "maudiss", "maudiss", "maudi",
		nil, "maudit")
end

conj["mettre"] = function(data)
	if data.stem ~= "" then
		data.notes = "This verb is conjugated like " .. link("mettre") .. ". That means it "
	else
		data.notes = "This verb "
	end
	data.notes = data.notes .. "is conjugated like " .. link("battre") .. " except that its past participle is " .. link("{stem}mis") .. ", "
	data.notes = data.notes .. "not *''{stem}mettu'', and its past historic and imperfect subjunctive "
	data.notes = data.notes .. "are formed with ''{stem}mi-'', not *''{stem}metti-''."

	construct_non_er_conj(data, "met", "mett", "mett", "mi", nil, "mis")
end

conj["moudre"] = function(data)
	construct_non_er_conj(data, "moud", "moul", "moul", "moulu")
end

conj["mouvoir"] = function(data)
	construct_non_er_conj(data, "meu", "mouv", "meuv", "mu", "mouvr")
	if data.stem == "" then
		data.forms.pp = "mû"
	end
end

conj["paitre"] = function(data)
	data.notes = "This verb is not conjugated in certain tenses."
	construct_non_er_conj(data, "pai", "paiss", "paiss", "pu")
	--data.cat = "defective" -- FIXME: Not true with pu as past participle?
end

conj["paître"] = function(data)
	conj["paitre"](data)
	data.forms.ind_p_3s = "paît"
end

conj["pleuvoir"] = function(data)
	data.notes = "This is a [[defective]] verb, only conjugated in the "
	if data.stem == "re" then
		data.notes = data.notes .. "[[third-person]] singular."
	else
		data.notes = data.notes .. "[[third-person]]. The [[third-person plural]] forms are only used figuratively."
	end

	construct_non_er_conj(data, "pleu", "pleuv", "pleuv", "plu", "pleuvr")
	if data.stem == "re" then
		impersonal_verb(data)
		data.cat = {"defective", "impersonal"}
	else
		only_third_verb(data)
		data.cat = "defective"
	end
end

conj["pourvoir"] = function(data)
	data.notes = "''Pourvoir'' and its derived verbs conjugate like " .. link("voir") .. ", except that their past historic indicative and imperfect subjunctive are in ''-vu-'' instead of ''-vi-''."

	construct_non_er_conj(data, "pourvoi", "pourvoy", "pourvoi", "pourvu")
end

conj["prendre"] = function(data)
	if data.stem ~= "" then
		data.notes = "This verb is conjugated on the model of " .. link("prendre") .. ". That means it is quite irregular, with the following patterns:\n"
	else
		data.notes = "This verb is quite irregular, with the following patterns:\n"
	end
	data.notes = data.notes .. "*In the infinitive, in the singular forms of the present indicative, and in the future and the conditional, it is conjugated like " .. link("rendre") .. ", " .. link("perdre") .. ", etc. (sometimes called the regular " .. link("-re") .. " verbs).\n"
	data.notes = data.notes .. "*In the plural forms of the present indicative and imperative, in the imperfect indicative, in the present subjunctive, and in the present participle, it is conjugated like " .. link("appeler") .. " or " .. link("jeter") .. ", using the stem ''{stem}prenn-'' before mute 'e' and the stem ''{stem}pren-'' elsewhere.\n"
	data.notes = data.notes .. "*In the past participle, and in the past historic and the imperfect subjunctive, its conjugation resembles that of " .. link("mettre") .. "."

	construct_non_er_conj(data, "prend", "pren", "prenn", "pri", nil, "pris")
end

conj["faire"] = function(data)
	construct_non_er_conj(data, "fai", "fais", "fais", "fi", "fer", "fait",
		"fass")
	-- Need to override the present indicative 2p and 3p, the imperative 2p,
	-- and the pronunciations of these forms as well as all forms in fais-.
	setform(data, "ind_p_2p", "faites")
	setform(data, "ind_p_3p", "font")
	data.prons.ind_p_1p = dopron(data, "fesons")
	data.forms.imp_p_2p = "faites"
	copy_ind_pron_to_imp(data)
	m_pron.ind_i(data, strip_pron_ending(dopron(data, "fesez"), "e"))
	data.prons.ppr = dopron(data, "fesant")
end

conj["boire"] = function(data)
	construct_non_er_conj(data, "boi", "buv", "boiv", "bu")
end

conj["devoir"] = function(data)
	construct_non_er_conj(data, "doi", "dev", "doiv", "du", "devr")
	if data.stem == "" then
		data.forms.pp = "dû"
	end
end

conj["avoir"] = function(data)
	m_core.make_ind_p(data, "a", "av")
	data.forms.ind_p_1s = "ai"
	data.forms.ind_p_3s = "a"
	data.forms.ind_p_3p = "ont"
	m_core.make_ind_ps(data, "eu")
	m_core.make_ind_f(data, "aur")
	m_core.make_sub_p(data, "ai")
	data.forms.sub_p_3s = "ait"
	data.forms.sub_p_1p = "ayons"
	data.forms.sub_p_2p = "ayez"
	m_core.make_imp_p_sub(data)
	data.forms.ppr = "ayant"

	local root = rsub(dopron(data, "a"),"a$","")

	local stem = root .. "a"
	local stem2 = root .. "a.v"
	local stem3 = root .. "y"
	local stem4 = root .. "o.ʁ"
	local stem5 = root .. "ɛ"
	local stem6 = root .. "ɛ."

	m_pron.ind_p(data, stem, stem2)
	data.prons.ind_p_1s = root .. "e"
	data.prons.ind_p_3p = root .. "ɔ̃"
	m_pron.ind_ps(data, stem3)
	m_pron.ind_f(data, stem4)
	m_pron.sub_p(data, stem5, stem6)
	generate_imp_pron_from_forms(data)
	data.prons.ppr = stem6 .. "jɑ̃"
end

conj["être"] = function(data)
	data.forms.ind_p_1s = "suis"
	data.forms.ind_p_2s = "es"
	data.forms.ind_p_3s = "est"
	data.forms.ind_p_1p = "sommes"
	data.forms.ind_p_2p = "êtes"
	data.forms.ind_p_3p = "sont"

	m_core.make_ind_i(data, "ét")
	m_core.make_ind_ps(data, "fu")
	m_core.make_ind_f(data, "ser")

	data.forms.sub_p_1s = "sois"
	data.forms.sub_p_2s = "sois"
	data.forms.sub_p_3s = "soit"
	data.forms.sub_p_1p = "soyons"
	data.forms.sub_p_2p = "soyez"
	data.forms.sub_p_3p = "soient"

	m_core.make_imp_p_sub(data)
	data.forms.pp = "été"
	data.forms.ppr = "étant"

	local root_s = rsub(dopron(data, "sa"),"sa$","")
	local root_e = rsub(dopron(data, "é"),"e$","")
	local root_f = rsub(dopron(data, "fa"),"fa$","")

	local stem = root_e .. "ɛ"
	local stem2 = root_e .. "e.t"
	local stem3 = root_f .. "fy"
	local stem4 = root_s .. "sə.ʁ"
	local stem5 = root_s .. "swa"
	local stem6 = root_s .. "swa."

	data.prons.ind_p_1s = root_s .. "sɥi"
	data.prons.ind_p_2s = stem
	data.prons.ind_p_3s = stem
	data.prons.ind_p_1p = root_s .. "sɔm"
	data.prons.ind_p_2p = stem .. "t"
	data.prons.ind_p_3p = root_s .. "sɔ̃"
	m_pron.ind_i(data, stem2)
	m_pron.ind_ps(data, stem3)
	m_pron.ind_f(data, stem4)
	m_pron.sub_p(data, stem5, stem6)

	data.prons.imp_p_2s = stem5
	data.prons.imp_p_1p = stem6 .. "jɔ̃"
	data.prons.imp_p_2p = stem6 .. "je"
	data.prons.ppr = stem2 .. "ɑ̃"
	data.prons.pp = stem2 .. "e"

	data.cat = "defective"
end

conj["estre"] = function(data)
	conj["être"](data)

	for key,val in pairs(data.forms) do
		data.forms[key] = rsub(val, "[éê]", "es")
		data.forms[key] = rsub(data.forms[key], "û", "us")
		data.forms[key] = rsub(data.forms[key], "ai", "oi")
	end

	data.forms.ind_ps_1p = "fumes"
	data.forms.sub_pa_3s = "fust"
	data.forms.pp = "esté"
end

conj["naitre"] = function(data)
	-- future stem must be nil here because we are called from conj["naître"]
	construct_non_er_conj(data, "nai", "naiss", "naiss", "naqui", nil, "né")
end

conj["naître"] = function(data)
	conj["naitre"](data)
	data.forms.ind_p_3s = "naît"
end

conj["envoyer"] = function(data)
	data.notes = "This verb is one of a few verbs that conjugate like " .. link("noyer") .. ", except in the future and conditional, where they conjugate like " .. link("voir") .. "."

	m_core.make_ind_p_e(data, "envoi", "envoy", "envoy")
	m_core.make_ind_f(data, "enverr")

	local stem = dopron(data, "envoi")
	local stem2 = stem .. ".j"
	local stem3 = dopron(data, "envè") .. ".ʁ"

	m_pron.er(data, stem, stem2)
	m_pron.ind_f(data, stem3)
	data.group = 1
	data.irregular = "yes"
end

conj["irreg-aller"] = function(data)
	data.notes = "The verb ''{stem}aller'' has a unique and highly irregular conjugation. The second-person singular imperative ''[[va]]'' additionally combines with ''[[y]]'' to form ''[[vas-y]]'' instead of the expected ''va-y''."

	m_core.make_ind_p_e(data, "all")
	m_core.make_ind_f(data, "ir")
	m_core.make_sub_p(data, "aill", "all")

	local stem = dopron(data, "a")
	local stem2 = dopron(data, "i") .. ".ʁ"

	m_pron.er(data, stem .. "l", stem .. ".l")
	m_pron.ind_f(data, stem2)
	m_pron.sub_p(data, stem .. "j", stem .. ".l")

	setform(data, "ind_p_1s", "vais")
	setform(data, "ind_p_2s", "vas")
	setform(data, "ind_p_3s", "va")
	setform(data, "ind_p_3p", "vont")
	setform(data, "imp_p_2s", "va")
end

conj["dire"] = function(data)
	construct_non_er_conj(data, "di", "dis", "dis", "di", nil, "dit")

	if data.stem == "" or data.stem == "re" then
		setform(data, "ind_p_2p", "dites")
		setform(data, "imp_p_2p", "dites")
	else
		data.notes = "This verb is one of a group of " .. link("-re") .. " verbs all ending in ''-dire''. "
		data.notes = data.notes .. "They are conjugated exactly like " .. link("dire") .. ", "
		data.notes = data.notes .. "but with a different second-person plural indicative present (that is, like " .. link("confire") .. "). "
		data.notes = data.notes .. "Members of this group include " .. link(data.stem == "contre" and "dédire" or "contredire") .. " and "
		data.notes = data.notes .. link(data.stem == "inter" and "dédire" or "interdire") .. "."
	end
end

conj["vivre"] = function(data)
	construct_non_er_conj(data, "vi", "viv", "viv", "vécu")
end

conj["mourir"] = function(data)
	construct_non_er_conj(data, "meur", "mour", "meur", "mouru", {{"mourr", respelling="mour_r"}},
		"mort")
end

conj["savoir"] = function(data)
	construct_non_er_conj(data, "sai", "sav", "sav", "su", {{"saur", respelling="sor"}}, nil,
		"sach")
	m_core.make_imp_p_sub(data)
	setform(data, "ppr", "sachant")
	generate_imp_pron_from_forms(data)
end

conj["pouvoir"] = function(data)
	construct_non_er_conj(data, "peu", "pouv", "peuv", "pu", "pourr", nil,
		"puiss")
	data.forms.ind_p_1s = "peux"
	data.forms.ind_p_2s = "peux"
	m_core.clear_imp(data)
	data.cat = "defective"
end

conj["ouloir"] = function(data) -- vouloir, revouloir, douloir
	construct_non_er_conj(data, "eu", "oul", "eul", "oulu", "oudr", nil,
		"euill", "oul")
	data.forms.ind_p_1s = "eux"
	data.forms.ind_p_2s = "eux"
	if data.stem == "v" then -- irregular imperative for vouloir
		setform(data, "imp_p_2s", {"eux", "euille"})
		setform(data, "imp_p_1p", {"oulons", "euillons"})
		setform(data, "imp_p_2p", {"oulez", "euillez"})
	else
		data.forms.imp_p_2s = "eux"
	end
end

conj["bruire"] = function(data)
	construct_non_er_conj(data, "bruis", "bruiss", "bruiss", "brui")
end

conj["ensuivre"] = function(data)
	data.notes = "This verb is [[defective]], and is only used in the "
		.. "infinitive and the third-person singular and plural forms."
	construct_non_er_conj(data, "ensui", "ensuiv", "ensuiv", "ensuivi")
	only_third_verb(data)
	data.cat = "defective"
end

conj["frire"] = function(data)
	data.notes = "This verb is defective and it is not conjugated in certain"
		.. " tenses and plural persons. Using " .. link("faire") ..
		" '''frire''' is recommended."
	construct_non_er_conj(data, "fri", "fris", "fris", "fri", nil, "frit")
	-- clear subjunctive present and past
	m_core.make_sub_pa(data, "—")
	m_core.make_sub_p(data, "—")
	-- clear plural forms
	for _, k in ipairs(all_verb_props) do
		if rmatch(k, "[123]p") then
			data.forms[k] = "—"
		end
	end
	data.cat = "defective"
end

conj["plaire"] = function(data)
	data.notes = link("plaire") .. " and its derived verbs conjugate like "
		.. link("taire") .. ", except that the third person singular of the "
		.. "present indicative may take a circumflex on the 'i'."
	construct_non_er_conj(data, "plai", "plais", "plais", "plu")
	data.forms.ind_p_3s = {"plaît", "plait"}
end

conj["suivre"] = function(data)
	construct_non_er_conj(data, "sui", "suiv", "suiv", "suivi")
end

conj["taire"] = function(data)
	construct_non_er_conj(data, "tai", "tais", "tais", "tu")
end

conj["valoir"] = function(data)
	construct_non_er_conj(data, "vau", "val", "val", "valu", "vaudr", nil,
		data.stem == "pré" and "val" or "vaill", "val")
	data.forms.ind_p_1s = "vaux"
	data.forms.ind_p_2s = "vaux"
	m_core.clear_imp(data)
	data.cat = "defective"
end

conj["vêtir"] = function(data)
	data.notes = "This is an irregular verb of the third conjugation. "
		.. "Unlike regular -ir verbs, this conjugation does not include "
		.. "the infix " .. link("-iss-") .. "."
	construct_non_er_conj(data, "vêt", "vêt", "vêt", "vêti", nil, "vêtu")
end

local function call_conj(data, conjtyp, pronstem)
	data.pronstem = pronstem or strip_respelling_ending(data.pron, data.forms.inf) or data.stem
	conj[conjtyp](data)
end

-- Conjugate the verb according to the TYPE, which is either explicitly
-- specified by the caller of {{fr-conj-auto}} or derived automatically.
-- NOTE: Verbs of of type 'xxer' (i.e. 'appeler', 'jeter' and derivatives)
-- need to have their type explicitly specified, e.g.:
-- * 'ler' for 'appeler' and derivatives
-- * 'ter' for 'jeter' and derivatives
--
-- appeler: {{fr-conj-auto|appe|ler}}
-- jeter: {{fr-conj-auto|je|ter}}
local function conjugate(data, typ)
	data.forms.inf = typ
	local future_stem = rsub(data.forms.inf, "e$", "")
	m_core.make_ind_f(data, future_stem)

	local cons = rmatch(typ, "^(" .. written_cons_c .. ")er$")
	if cons and typ ~= "cer" and typ ~= "ger"  and typ ~= "yer" then
		data.stem = data.stem .. cons
		call_conj(data, "xxer", strip_respelling_ending(data.pron, "er"))
		return
	end
	local cons = rmatch(typ, "^e(" .. written_cons_c .. "+)er$")
	if cons and typ ~= "ecer" and typ ~= "eger" and typ ~= "eyer" then
		data.stem = data.stem .. "e" .. cons
		call_conj(data, "e-er", strip_respelling_ending(data.pron, "er"))
		return
	end
	local cons = rmatch(typ, "^é(" .. written_cons_c .. "+)er$")
	if cons and typ ~= "écer" and typ ~= "éger"  and typ ~= "éyer" then
		data.stem = data.stem .. "é" .. cons
		call_conj(data, "é-er", strip_respelling_ending(data.pron, "er"))
		return
	end
	local cons = rmatch(typ, "^é([gq]u)er$") -- alléguer, disséquer, etc.
	if cons then
		data.stem = data.stem .. "é" .. cons
		call_conj(data, "é-er", strip_respelling_ending(data.pron, "er"))
		return
	end
	if alias[typ] then
		data.stem = data.stem .. rsub(typ, alias[typ] .. "$", "")
		data.forms.inf = alias[typ]
		call_conj(data, alias[typ])
	elseif conj[typ] then
		call_conj(data, typ)
	elseif typ ~= "" then
		error('The type "' .. typ .. '" is not recognized')
	end
end

-- Autodetect the conjugation type and extract the preceding stem. We have
-- special handling for verbs in -éCer and -eCer for C = consonant. Otherwise,
-- the conjugation type is the longest suffix of the infinitive for which
-- there's an entry in conj[], and stem is the preceding text. (As an
-- exception, certain longer suffixes are mapped to the conjugation type of
-- shorter suffixes using alias[]. An example is 'connaitre', which conjugates
-- like '-aitre' verbs rather than like 'naitre' and its derivatives.) Note
-- that for many irregular verbs, the "stem" is actually the prefix, or empty
-- if the verb has no prefix.
local function auto(pagename)
	local stem
	-- check for espérer, céder, etc.; exclude -écer, -éger, -éyer
	stem = rmatch(pagename, "^(.*é" .. written_cons_c .. "*" .. written_cons_no_cgy_c .. ")er$")
	if stem then
		return stem, "é-er"
	end
	-- check for alléguer, disséquer, etc.
	stem = rmatch(pagename, "^(.*é[gq]u)er$")
	if stem then
		return stem, "é-er"
	end
	-- check for acheter, etc.; exclude -exer, -ecer, -eger, -eyer
	stem = rmatch(pagename, "^(.*e" .. written_cons_no_cgyx_c .. ")er$")
	if stem then
		return stem, "e-er"
	end
	-- check for sevrer, etc.; exclude -ller, -rrer, -rler (perler)
	stem = rmatch(pagename, "^(.*e" .. written_cons_no_lryx_c .. "[lr])er$")
	if stem then
		return stem, "e-er"
	end
	stem = ""
	local typ = pagename
	while typ ~= "" do
		if conj[typ] then break end
		if alias[typ] then
			stem = stem .. rsub(typ,alias[typ].."$","")
			typ = alias[typ]
			break
		end
		stem = stem .. rsub(typ,"^(.).*$","%1")
		typ = rsub(typ,"^.","")
	end
	if typ == "" then
		return "",""
	end
	return stem,typ
end

-- Append elements of TAB2 to the elements of TAB1, converting them to lists
-- as necessary.
local function append_tables(tab1, tab2)
	for k, values in pairs(tab2) do
		local t1 = tab1[k]
		if type(t1) ~= "table" then
			t1 = {t1}
		end
		if type(values) ~= "table" then
			values = {values}
		end
		for _, val in ipairs(values) do
			ut.insert_if_not(t1, val)
		end
		tab1[k] = t1
	end
end

local verb_prefix_to_type = {
	{"les y en ", "lesyen"},
	{"les en ", "lesen"},
	{"s[’']en ", "reflen"},
	{"se le ", "reflle"},
	{"se la ", "reflla"},
	{"se l[’']", "refll"},
	{"se les y ", "refllesy"},
	{"les y ", "lesy"},
	{"se les ", "reflles"},
	{"les ", "les"},
	{"se l[’']y ", "reflly"},
	{"l[’']y ", "l_y"},
	{"l[’']en ", "l_en"},
	{"l[’']", "l"},
	{"le ", "le"},
	{"la ", "la"},
	{"s[’']y en ", "reflyen"},
	{"y en ", "yen"},
	{"en ", "en"},
	{"s[’']y ", "refly"},
	{"y ", "y"},
	{"s[’']", "refl"},
	{"se ", "refl"},
}

-- This is meant to be invoked by the module itself, or possibly by a
-- different version of the module (for comparing changes to see whether
-- they have an effect on conjugations or pronunciations).
function export.do_generate_forms(args)
	local data
	local stem = args[1] or ""
	local typ = args[2] or ""
	local argspron = args.pron
	local prefix, preftype
	local pagename_from_args
	
	local PAGENAME = mw.title.getCurrentTitle().text

	if stem == "" and typ == "" then
		pagename_from_args = PAGENAME
	else
		pagename_from_args = stem .. typ
	end

	if typ == "" then typ = stem; stem = ""; end

	if stem == "" and typ == "" then
		-- most common situation, {{fr-conj-auto}}
		stem, typ = auto(PAGENAME)
	elseif stem == "" then
		-- explicitly specified stem, e.g. {{fr-conj-auto|aimer}} in userspace
		-- (NOTE: stem moved to typ above)
		stem, typ = auto(typ)
	-- else, explicitly specified stem and type, e.g. {{fr-conj-auto|appe|ler}}
	end

	-- expand + and [...] notations
	if argspron then
		local pronvals = rsplit(argspron, ",")
		local expanded_pronvals = {}
		for _, pronval in ipairs(pronvals) do
			table.insert(expanded_pronvals, m_fr_pron.canonicalize_pron(pronval, pagename_from_args))
		end
		argspron = table.concat(expanded_pronvals, ",")
	end

	-- autodetect prefixed verbs
	for _, pref_and_type in ipairs(verb_prefix_to_type) do
		local pref, prefty = pref_and_type[1], pref_and_type[2]
		if rfind(stem, "^" .. pref) then
			stem = rsub(stem, "^" .. pref, "")
			argspron = strip_respelling_beginning(argspron, pref, "split")
			prefix = pref
			preftype = prefty
			break
		end
	end

	local pronargs = argspron and rsplit(argspron, ",") or {false}
	local all_forms, all_prons 
	for i = 1, #pronargs do
		local pronarg = pronargs[i]
		if pronarg == false then pronarg = nil end
		data = {
			prefix = prefix,
			preftype = preftype,
			stem = stem,
			aux = "avoir",
			pron = pronarg,
			forms = {},
			prons = {},
			cat = {},
			group = 3
		}
		conjugate(data, typ)
		if type(data.cat) ~= "table" then
			data.cat = {data.cat}
		end
		if i == 1 then
			all_forms = data.forms
			all_prons = data.prons
		else
			append_tables(all_forms, data.forms)
			append_tables(all_prons, data.prons)
		end
	end
	data.forms = all_forms
	data.prons = all_prons

	-- FIXME! From here on out we use the value of data.notes, data.stem
	-- and data.cat as set/modified in the conjugation functions of the last
	-- iteration of the loop above. As it happens, this doesn't matter
	-- because we iterate over pronunciations keeping the stem and conjugation
	-- type the same, but might matter one day if we break this assumption.
	m_core.extract(data, args)

	if args.archaic then
		for k, v in pairs(data.forms) do
			data.forms[k] = map(v, function(val)
				val = rsub(val, "ai", "oi")
				val = rsub(val, "â", "as")
				return val end)
		end
	end

	if args.impers or args.onlythird then
		if data.notes then
			data.notes = data.notes .. "\n"
		else
			data.notes = ""
		end
		table.insert(data.cat, "defective")
	end
	if args.impers then
		data.notes = data.notes .. "This verb is impersonal and is conjugated only in the third-person singular."
		impersonal_verb(data)
		table.insert(data.cat, "impersonal")
	elseif args.onlythird then
		data.notes = data.notes .. "This verb is conjugated only in the third person."
		only_third_verb(data)
	end

	if args.note then
		if data.notes then
			data.notes = data.notes .. "\n"
		else
			data.notes = ""
		end
		data.notes = data.notes .. args.note
	end
	
	if data.notes then data.notes = rsub(data.notes, "{stem}", data.stem) end
	for key,val in pairs(data.forms) do
		if type(val) == "table" then
			for i,form in ipairs(val) do
				if form ~= "—" then
					data.forms[key][i] = data.stem .. form
				end
			end
		else
			if val ~= "—" then
				data.forms[key] = data.stem .. val
			end
		end
	end

	for _, pref_and_type in ipairs(verb_prefix_to_type) do
		local pref, prefty = pref_and_type[1], pref_and_type[2]
		if args[prefty] == "n" or args[prefty] == "no" then
			if data.preftype == prefty then
				data.preftype = nil
			end
		elseif args[prefty] then
			data.preftype = prefty
		end
	end

	if data.preftype then
		for key, val in pairs(data.forms) do
			m_core.pref_sufs[data.preftype](data, key, val)
		end
	end

	if etre[data.forms.inf] then
		data.aux = "être"
	elseif avoir_or_etre[data.forms.inf] then
		data.aux = "avoir or être"
	end
	local aux_prefix = data.prefix or ""
	aux_prefix = rsub(aux_prefix, "l[ae] $", "l'")
	if args.aux == "a" or args.aux == "avoir" then
		data.aux = aux_prefix .. "avoir"
	elseif args.aux == "e" or args.aux == "être" then
		data.aux = aux_prefix .. "être"
	elseif args.aux == "ae" or args.aux == "avoir,être" or args.aux == "avoir or être" then
		data.aux = aux_prefix .. "avoir or être"
	elseif args.aux then
		error("Unrecognized value for aux=, should be 'a', 'e', 'ae', 'avoir', 'être', or 'avoir,être'")
	end

	data.forms.inf_nolink = data.forms.inf_nolink or data.forms.inf
	data.forms.ppr_nolink = data.forms.ppr_nolink or data.forms.ppr
	data.forms.pp_nolink = data.forms.pp_nolink or data.forms.pp

	if not data.irregular then
		if data.group == 1 or data.group == 2 then
			data.irregular = "no"
		else
			data.irregular = "yes"
		end
	end

	return data
end

function export.generate_forms(frame)
	local args = clone_args(frame)
	local data = export.do_generate_forms(args)
	local retval = {}
	for arraytype = 1, 2 do
		local arrayname = arraytype == 1 and "forms" or "prons"
		local array = data[arrayname]
		for _, prop in ipairs(all_verb_props) do
			local val = array[prop]
			if type(val) ~= "table" then val = {val} end
			local newval = {}
			for _, form in ipairs(val) do
				if not rmatch(form, "—") then
					table.insert(newval, form)
				end
			end
			-- Ignore pronunciation if dash present in form.
			-- FIXME, we shouldn't generate the pronunciation at all in that
			-- case, so we can support both dash and another form.
			if arrayname == "prons" then
				local val = data.forms[prop]
				if type(val) == "string" then val = {val} end
				local found_dash = false
				for _, form in ipairs(val) do
					if rmatch(form, "—") then
						found_dash = true
						break
					end
				end
				if found_dash then
					newval = {}
				end
			end
			if #newval > 0 then
				table.insert(retval, arrayname .. "." .. prop .. "=" .. table.concat(newval, ","))
			end
		end
	end
	return table.concat(retval, "|")
end

-- The main entry point.
-- This is the only function that can be invoked from a template.
function export.show(frame)
	local args = clone_args(frame)
	local args_clone
	if test_new_fr_verb_module then
		-- clone in case export.do_generate_forms() modifies args
		-- (I don't think it does currently)
		args_clone = mw.clone(args)
	end

	local data = export.do_generate_forms(args)

	-- Test code to compare existing module to new one.
	if test_new_fr_verb_module then
		local m_new_fr_verb = require("Module:User:Benwing2/fr-verb")
		local newdata = m_new_fr_verb.do_generate_forms(args_clone)
		local difconj = false
		local difforms = {}
		for arraytype = 1, 2 do
			local arrayname = arraytype == 1 and "forms" or "prons"
			local array = data[arrayname]
			local newarray = newdata[arrayname]
			for _, prop in ipairs(all_verb_props) do
				local val = array[prop]
				local newval = newarray[prop]
				-- deal with possible impedance mismatch between plain string
				-- and list
				if type(val) == "string" then val = {val} end
				if type(newval) == "string" then newval = {newval} end
				if not ut.equals(val, newval) then
					if test_new_fr_verb_module == "error" then
						table.insert(difforms, arrayname .. "." .. prop .. " " .. (val and table.concat(val, ",") or "nil") .. " || " .. (newval and table.concat(newval, ",") or "nil"))
					end
					difconj = true
				end
			end
		end
		if #difforms > 0 then
			error(table.concat(difforms, "; "))
		end
		track(difconj and "different-conj" or "same-conj")
	end

	m_core.link(data)

	local categories = {}
	if data.aux == "être" then
		table.insert(categories, "French verbs taking être as auxiliary")
	elseif data.aux == "avoir or être" then
		table.insert(categories, "French verbs taking avoir or être as auxiliary")
	end
	if data.conjcat then
		table.insert(categories, "French verbs with conjugation " .. data.conjcat)
	end
	for _, cat in ipairs(data.cat) do
		table.insert(categories, "French " .. cat .. " verbs")
	end
	for _, group in ipairs(type(data.group) == "table" and data.group or {data.group}) do
		if group == 1 then
			table.insert(categories, "French first group verbs")
		elseif group == 2 then
			table.insert(categories, "French second group verbs")
		else
			table.insert(categories, "French third group verbs")
		end
	end
	if data.irregular == "yes" then
			table.insert(categories, "French irregular verbs")
	end

	return m_conj.make_table(data) .. m_utilities.format_categories(categories, lang)
end

return export
