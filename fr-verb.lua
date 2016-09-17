--[=[

Author: Kc kennylau; significant rewriting by Benwing

This implements {{fr-conj-auto}}. It uses the following submodules:
* [[Module:fr-verb/core]] (helper for generating conjugations)
* [[Module:fr-verb/pron]] (helper for generating pronunciations of conjugations)
* [[Module:fr-conj]] (for constructing the table wikicode given the forms)
* [[Module:fr-pron]] (for generating pronunciations of stems)

FIXME:

1. Use ‿ to join reflexive pronouns.
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
8. Copy notes from {{fr-conj-ir}} to our conj["ir"].
9. Lots of other conjugations needed. Consider generalizing existing code
   so a minimal number of principal parts can be given and all the conjugation
   and pronunciation derived.
10. Convert remaining use of old templates to use {{fr-conj-auto}}.
11. (DONE) Figure out what the COMBINING flag in [[Module:fr-pron]] does and
    remove it, including all calls from this module.
12. (ALREADY DONE) Support sevrer, two-stem e/è verb.
13. Autodetect e-er verbs including eCer as well as eCler and eCrer verbs
    like sevrer, and eguer/equer (if they exist). Make sure there aren't
	verbs of this form that aren't e-er by looking for them in the list of
	fr-conj-auto verbs that have an empty typ arg (possibly enough to look
	at all fr-conj-auto verbs).
14. Check if overriding pronunciation of ppr 'pleuvant' is correct.
15. Check if -er-type conjugations of -aillir, -cueillir, braire are correct.
16. Fix notes for prefixed croitre/croître verbs, based on the old-style
	templates.
17. (DONE) Implement impersonal and only-third verbs, including impers=
    and onlythird=.
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
-- Table of data describing a given verb and its forms.
local data = {}

-- If enabled, compare this module with new version of module to make
-- sure all conjugations and pronunciations are the same.
local test_new_fr_verb_module = false

local m_core = require("Module:fr-verb/core")
local m_pron = require("Module:fr-verb/pron")
local m_links = require("Module:links")
local m_conj = require("Module:fr-conj")
local m_fr_pron = require("Module:fr-pron")
local lang = require("Module:languages").getByCode("fr")
local ut = require("Module:utils")
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

local written_cons_c = "[^aàâeéèêiîoôuûäëïöüÿ]"

-- version of rsubn() that discards all but the first return value
local function rsub(term, foo, bar)
	local retval = rsubn(term, foo, bar)
	return retval
end

local function map(seq, fun)
	if type(seq) == "table" then
		local ret = {}
		for _, s in ipairs(seq) do
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
	end)
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
	"alterner",
	"apparaître",
	"arriver",
	"décéder",
	"entrer", "rentrer",
	"mourir",
	"naitre", "naître", "renaitre", "renaître",
	"partir", "départir",
	"rester",
	"surmener",
	"tomber", "retomber",
	"venir", "advenir", "bienvenir", "devenir", "intervenir", "parvenir", "provenir", "redevenir", "revenir", "survenir"
}

for _,key in ipairs(etre) do
	etre[key] = true
end

-- List of verbs that can be conjugated using either 'avoir' or 'être' in the
-- passé composé. FIXME: This should be in the template, not here.
local avoir_or_etre = {
	"abdiquer", "abonnir","absconder","abuser","abâtardir","accommoder","acculturer","adapter","adhærer","admirer","aguerrir","aider","aliter","alourdir","alphabétiser","amerrir","anémier","apparenter","aspirer","attrouper","ausculter",
	"balbutier","barbeler","batailler","bloguer","bosseler","bouillir","bouturer","buer",
	"cagouler","candir","cartonner","cascader","caserner","cauchemarder","ceindre","cintrer","circuler","coincer","commercer","commémorer","comparaître","confectionner","connaitre","consentir","conspuer","consterner","constituer","contorsionner","contrister","convoyer","couver","couvrir","crever",
	"demeurer","déchoir","descendre","diplômer","disparaitre","disparaître","dormir","déborder","décapitaliser","déceler","découvrir","déficeler","défier","dégeler","déglutir","délaver","délecter","démanteler","démasquer","dénationaliser","dénoncer","dépendre","dépuceler","déshabituer","désister","déstabiliser","détériorer","dévaler","dévitaliser",
	"effoirer","emmener","encabaner","encapsuler","encaquer","encartonner","encartoucher","encaster","encommencer","endetter","endormir","enferrer","engrisailler","enlever","enserrer","envier","envoiler",
	"fasciner","ferrer","filigraner","fouetter","fourmiller","fringuer","fucker","fureter",
	"gargariser","gascher","gausser","geler","gnoquer","grincer","gémir",
	"haleter","harasser","hâter","hæsiter","hésiter",
	"identifier","impartir","inquieter","insonoriser",
	"larder","larmoyer","lemmatiser","lever","lier",
	"malmener","marketer","marteler","matter","maugréer","mener","mentir","microprogrammer","mincir","modeler","modéliser","monitorer","monter","muloter","multiplier","méconnaître",
	"niveler","obvenir","omettre","orner",
	"pailler","paraitre","paraître","parfumer","parjurer","parsemer","passer","permettre","perpétuer","peser","poiler","promettre","præsumer","prætendre","prélever","préserver",
	"qualifier","rainurer","ramener","rebattre","reboiser","reclasser","recoiffer","recoller","recomparaître","redormir","redécouvrir","refusionner","regeler","relancer","relever","relier","remonter","rendormir","repartir","repasser","repatrier","repentir","respitier","ressentir","ressortir","ressouvenir","restaurer","restreindre","restructurer","retourner","retransmettre","retweeter","réagir","réapparaitre","réapparaître","réentendre","référencer",
	"savourer","sentir","siffler","simplifier","sortir","soupeser","spammer","subvenir","suspecter","synchroniser",
	"taire","tiédir",
	"volleyer","ædifier",
	"élancer","élever","éloigner","étriver"
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
			error("Internal error: expected pronunciation '" .. val ..
				"' to end with '" .. ending .. "'")
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
			error("Expected respelling '" .. val .. "' to end with '" ..
				ending "'")
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
		error("Expected respelling '" .. pron .. "' to begin with '" .. beginning "'")
	end
	return rsub(pron, "^" .. beginning, "")
end

-- Construct the pronunciation of all forms of an -er verb. PRONSTEM is the
-- pronunciation respelling of the stem (minus -er). If PRONSTEM_FINAL_FUT is
-- given, it is used in place of PRONSTEM for the forms without a pronounced
-- ending (i.e. 1s/2s/3s/3p present) and for the future and conditional; this
-- is used with two-stem verbs such as mener (with stems 'men' and 'mèn') and
-- céder (with stems 'céd' and 'cèd'). FIXME: Rewrite to work with tables as
-- stem values.
local function construct_er_pron(data, pronstem, pronstem_final_fut)
	pronstem_final_fut = pronstem_final_fut or pronstem
	pronstem = data.pronstem .. pronstem
	pronstem_final_fut = data.pronstem .. pronstem_final_fut
	-- In pronstem_final_fut, convert é+C in the last syllable to è even if
	-- the caller didn't do it. This is principally useful with pron=
	-- specifications, so that e.g. pron=blésser,blèsser works.
	pronstem_final_fut = rsub(pronstem_final_fut,
		"é(" .. written_cons_c .. "+)$", "è%1")
	pronstem_final_fut = rsub(pronstem_final_fut, "é([gq]u)$", "è%1")
	local stem_final = pron(pronstem_final_fut .. "e")
	local stem_nonfinal = strip_pron_ending(pron(pronstem .. "ez"), "e")
	local stem_nonfinal_i = strip_pron_ending(pron(pronstem .. "iez"), "je")
	local stem_fut = strip_pron_ending(pron(pronstem_final_fut .. "erez"), "ʁe")
	local stem_fut_i = strip_pron_ending(pron(pronstem_final_fut .. "eriez"), "ʁje")
	return m_pron.er(data, stem_final, stem_nonfinal, stem_nonfinal_i,
		stem_fut, stem_fut_i)
end

-- Construct the conjugation and pronunciation of all forms of a non-er verb.
-- DATA holds the forms and pronunciations. The remaining args are stems:
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
-- Any of the stem arguments may actually be a table of stems.
local function construct_non_er_conj(data, pres_sg_stem, pres_12p_stem,
	pres_3p_stem, past_stem, fut_stem, pp, pres_subj_stem,
	pres_subj_nonfinal_stem)
	data = m_core.make_ind_p(data, pres_sg_stem, pres_12p_stem, pres_3p_stem)
	data = m_core.make_ind_ps(data, past_stem)
	if not fut_stem then
		fut_stem = rsub(data.forms.inf, "e$", "")
	end
	data = m_core.make_ind_f(data, fut_stem)

	-- Most of the time it works to add 's' to produce the 1sg (it doesn't
	-- always work to use the stem directly, cf. apparais vs. apparai). But
	-- this fails with stems ending in -er, e.g 'resser-' from 'resservir',
	-- because the 'r' will be silent. In that case, we add 't' to produce
	-- the 3sg. We can't always add 't' because that will fail with e.g.
	-- 'ressen-' from 'ressentir', where the resulting '-ent' will be silent.
	if pres_sg_stem ~= "—" then
		local pres_sg_stem_pron = map(pres_sg_stem, function(stem)
			return rmatch(data.pronstem .. stem, "er$") and dopron(data, stem, "t") or dopron(data, stem, "s")
		end)
		local pres_12p_stem_pron = strip_pron_ending(dopron(data, pres_12p_stem, "ez"), "e")
		local pres_3p_stem_pron = dopron(data, pres_3p_stem, "e")
		data = m_pron.ind_p(data, pres_sg_stem_pron, pres_12p_stem_pron, pres_3p_stem_pron)
	end
	if past_stem ~= "—" then
		local past_stem_pron = dopron(data, past_stem)
		data = m_pron.ind_ps(data, past_stem_pron)
	end
	if fut_stem ~= "—" then
		local fut_stem_pron = strip_pron_ending(dopron(data, fut_stem, "ez"), "ʁe")
		data = m_pron.ind_f(data, fut_stem_pron)
	end

	if pp then
		data.forms.pp = pp
		if pp ~= "—" then
			data.prons.pp = dopron(data, pp)
		end
	end

	if pres_subj_stem then
		data = m_core.make_sub_p(data, pres_subj_stem)
		if pres_subj_stem ~= "—" then
			local pres_subj_pron1 = dopron(data, pres_subj_stem, "e")
			local pres_subj_pron2 = strip_pron_ending(dopron(data, pres_subj_nonfinal_stem or pres_subj_stem, "iez"), "je")
			data = m_pron.sub_p(data, pres_subj_pron1, pres_subj_pron2)
		end
	end
end

local function copy_ind_pron_to_imp(data)
	data.prons.imp_p_2s = data.prons.ind_p_2s
	data.prons.imp_p_1p = data.prons.ind_p_1p
	data.prons.imp_p_2p = data.prons.ind_p_2p
end

local function generate_imp_pron_from_forms(data)
	data.prons.imp_p_2s = dopron(data, data.forms.imp_p_2s)
	data.prons.imp_p_1p = dopron(data, data.prons.imp_p_1p)
	data.prons.imp_p_2p = dopron(data, data.prons.imp_p_2p)
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

conj["er"] = function()
	if data.stem == "all" then
		data.stem = ""
		data.pronstem = strip_respelling_ending(data.pron, "aller") or data.stem
		conj["irreg-aller"]()
		data.forms.inf = "aller"

		data.category = "aller"

		data.typ = "suppletive"
	else
		data = m_core.make_ind_p_e(data, "")
		data = construct_er_pron(data, "")
		data.category = "-er"
	end
end

conj["cer"] = function()
	data = m_core.make_ind_p_e(data, "c", "ç")

	data.notes = "This verb is part of a group of " .. link("-er") .. " verbs for which ‘c’ is softened to a ‘ç’ before the vowels ‘a’ and ‘o’."
	data = construct_er_pron(data, "c")
	data.category = "-cer"
end

conj["ger"] = function()
	data = m_core.make_ind_p_e(data, "g", "ge")

	data.notes = "This is a regular " .. link("-er") .. " verb, but the stem is written ''{stem}ge-'' before endings that begin with ''-a-'' or ''-o-'' "
	data.notes = data.notes .. "(to indicate that the ''-g-'' is a “soft” " .. IPA("/ʒ/") .. " and not a “hard” " .. IPA("/ɡ/") .. "). "
	data.notes = data.notes .. "This spelling-change occurs in all verbs in ''-ger'', such as "
	data.notes = data.notes .. link(data.stem == "nei" and "bouger" or "neiger") .. " and "
	data.notes = data.notes .. link(data.stem == "man" and "ranger" or "manger") .. "."

	data = construct_er_pron(data, "g")
	data.category = "-ger"
end

conj["ayer"] = function()
	data = m_core.make_ind_p_e(data, {"ay", "ai"}, "ay", "ay")

	local root = dopron(data, "a")
	root = rsub(root,".$","")

	local stem = root .. "ɛ"
	local stem2 = root .. "ɛj"
	local stem3 = root .. "e.j"
	local stem4 = root .. "ej."
	local stem5 = root .. "e"

	data.prons.ppr = stem3 .. "ɑ̃"
	data.prons.pp = stem3 .. "e"

	data = m_pron.er(data, {stem2, stem}, stem3)
	data = m_pron.ind_f(data, {stem3 .. "ə.", stem5 .. "."})

	data.category = "-ayer"
end

conj["eyer"] = function()
	data = m_core.make_ind_p_e(data, "ey")

	local root = dopron(data, "i")
	root = rsub(root,".$","")

	local stem = root .. "ɛj"
	local stem2 = root .. "e.j"
	local stem3 = root .. "ej"

	data = m_pron.er(data, stem, stem2)
	data = m_pron.ind_f(data, stem3 .. ".")

	data.category = "-eyer"
end

conj["yer"] = function()
	data = m_core.make_ind_p_e(data, "i", "y", "y")

	local stem = dopron(data, "i")

	data = m_pron.er(data, stem, stem..".j")

	data.category = "-yer"
end

conj["xxer"] = function(consonant)
	data.notes = "With the exception of " .. (stem == "appel" and "''appeler''" or link("appeler")) .. ", "
	data.notes = data.notes .. (stem == "jet" and "''jeter''" or link("jeter")) .. " and their derived verbs, "
	data.notes = data.notes .. "all verbs that used to double the consonants can also now be conjugated like " .. link("amener") .. "."

	data = m_core.make_ind_p_e(data, consonant..consonant, consonant, consonant)
	data = construct_er_pron(data, consonant, consonant .. consonant)
	data.category = "-xxer"
end

conj["e-er"] = function(consonant)
	local stem = 'e' .. consonant
	local stem2 = 'è' .. consonant

	data.notes = "This verb is conjugated mostly like the regular " .. link("-er") .. " verbs (" .. link("parler") .. " and " .. link("chanter") .. " and so on), "
	data.notes = data.notes .. "but the ''-e-'' " .. IPA("/ə/") .. " of the second-to-last syllable becomes ''-è-'' " .. IPA("/ɛ/") .. " when the next vowel is a silent or schwa ''-e-''. "
	data.notes = data.notes .. "For example, in the third-person singular present indicative, we have ''il {stem}" .. stem2 .. "e'' rather than *''il {stem}" .. stem .. "e''. "
	data.notes = data.notes .. "Other verbs conjugated this way include " .. link(stem == "lev" and "acheter" or "lever") .. " and " .. link(stem == "men" and "acheter" or "mener") .. ". "
	data.notes = data.notes .. "Related but distinct conjugations include those of " .. link("appeler") .. " and " .. link("préférer") .. "."

	data = m_core.make_ind_p_e(data, stem2, stem, stem)
	data = construct_er_pron(data, stem, stem2)
	data.category = "-e-er"
end

conj["ecer"] = function()
	data = m_core.make_ind_p_e(data, "èc", "eç", "ec")
	data = construct_er_pron(data, "ec", "èc")
	data.category = "-e-er"
end

conj["eger"] = function()
	data = m_core.make_ind_p_e(data, "èg", "ege", "eg")
	data = construct_er_pron(data, "eg", "èg")
	data.category = "-e-er"
end

conj["é-er"] = function(consonant)
	local stem = 'é' .. consonant
	local stem2 = 'è' .. consonant

	data.notes = "This verb is conjugated like "
	if data.stem .. stem == "céd" then
		data.notes = data.notes .. link("espérer")
	else
		data.notes = data.notes .. link("céder")
	end
	data.notes = data.notes .. ". It is a regular " .. link("-er") .. " verb, "
	data.notes = data.notes .. "except that its last stem vowel alternates between " .. IPA("/e/") .. " (written ‘é’) and "
	data.notes = data.notes .. IPA("/ɛ/") .. " (written ‘è’), with the latter being used before mute ‘e’.\n"
	data.notes = data.notes .. "One special case is the future stem, used in the future and the conditional. "
	data.notes = data.notes .. "Before 1990, the future stem of such verbs was written ''{stem}" .. stem .. "er-'', "
	data.notes = data.notes .. "reflecting the historic pronunciation " .. IPA("/e/") .. ". "
	data.notes = data.notes .. "In 1990, the French Academy recommended that it be written ''{stem}" .. stem2 .. "er-'', "
	data.notes = data.notes .. "reflecting the now common pronunciation " .. IPA("/ɛ/") .. ", "
	data.notes = data.notes .. "thereby making this distinction consistent throughout the conjugation "
	data.notes = data.notes .. "(and also matching in this regard the conjugations of verbs like " .. link("lever") .. " and " .. link("jeter") .. "). "
	data.notes = data.notes .. "Both spellings are in use today, and both are therefore given here."

	data = m_core.make_ind_p_e(data, stem2, stem, stem)
	data = m_core.make_ind_f(data, {stem2 .. "er", stem .. "er"})
	data = construct_er_pron(data, stem, stem2)
	data.category = "-é-er"
end

conj["écer"] = function()
	data.notes = "This verb is conjugated like " .. link("rapiécer") .. ". It has both the spelling irregularities of other verbs in ''<span lang=\"fr\">-cer</span>'' "
	data.notes = data.notes .. "(such as " .. link("pincer") .. ", where a silent ‘e’ is inserted before ‘a’ and ‘o’ endings (to indicate the " .. IPA("/s/") .. " sound), "
	data.notes = data.notes .. "and the spelling and pronunciation irregularities of other verbs in ''<span lang=\"fr\">-é-er</span>'' (such as " .. link("céder") .. ", "
	data.notes = data.notes .. "where the last stem vowel alternates between " .. IPA("/e/") .. " (written ‘é’) and " .. IPA("/ɛ/") .. " (written ‘è’)."

	data = m_core.make_ind_p_e(data, "èc", "éç", "éc")
	data = m_core.make_ind_f(data, {"écer", "ècer"})
	data = construct_er_pron(data, "éc", "èc")
	data.category = "-é-er"
end

conj["éger"] = function()
	data.notes = "This verb is conjugated like "
	if data.stem == "prot" then
		data.notes = data.notes .. link("assiéger")
	else
		data.notes = data.notes .. link("protéger")
	end
	data.notes = data.notes .. ". It has both the spelling irregularities of other verbs in ''-ger'' (such as " .. link("manger") .. ", "
	data.notes = data.notes .. "where a silent ‘e’ is inserted before ‘a’ and ‘o’ endings (to indicate the " .. IPA("/ʒ/") .. " sound), "
	data.notes = data.notes .. "and the spelling and pronunciation irregularities of other verbs in ''-é-er'' (such as " .. link("céder") .. "), "
	data.notes = data.notes .. "where the last stem vowel alternates between " .. IPA("/e/") .. " (written ‘é’) and " .. IPA("/ɛ/") .. " (written ‘è’)."

	data = m_core.make_ind_p_e(data, "èg", "ége", "ég")
	data = m_core.make_ind_f(data, {"éger", "èger"})
	data = construct_er_pron(data, "ég", "èg")
	data.category = "-é-er"
end

conj["ir-s"] = function()
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
	data.category = "-ir"
end

conj["ir-reg"] = function()
	-- if ir-reg explicitly used in type argument (e.g. ressortir), inf will
	-- be ir-reg by default with messed-up future
	data.forms.inf = "ir"
	construct_non_er_conj(data, "i", "iss", "iss", "i")
	data.category = "-ir"
end

conj["ir"] = function()
	if ir_s[data.stem.."ir"] then
		conj["ir-s"]()
	else
		conj["ir-reg"]()
	end
end

conj["ïr"] = function()
	construct_non_er_conj(data, "ï", "ïss", "ïss", "ï")
	data.category = "-ïr"
end

conj["haïr"] = function()
	data.notes = "This verb is spelled as if conjugated like " .. link("finir") .. ", but has a [[diaeresis]] throughout its conjugation "
	data.notes = data.notes .. "(including where the circumflex would normally be used) except in the singular indicative present, "
	data.notes = data.notes .. "whose forms are pronounced " .. IPA("/ɛ/") .. " in Standard French instead of " .. IPA("/ai/") .. ", "
	data.notes = data.notes .. "a pronunciation nonetheless often found in informal speech."

	construct_non_er_conj(data, "hai", "haïss", "haïss", "haï")
	data.category = "haïr"
	data.typ = "irregular"
end

conj["ouïr"] = function()
	data.notes = "The forms beginning with ''oi-'', ''oy-'', or ''orr-'' are archaic."

	construct_non_er_conj(data, {"ouï", "oi"}, {"ouïss", "oy"},
		{"ouïss", "oi"}, "ouï", {"ouïr", "oir", "orr"})
	data.category = "ouïr"
	data.typ = "irregular"
end

conj["asseoir"] = function()
	data.notes = "The verb " .. link("asseoir") .. " (and its derivative " .. link("rasseoir") .. ") has 2 distinct conjugations."

	construct_non_er_conj(data, {"assoi", "assied"}, {"assoy", "assey"},
		{"assoi", "assey"}, "assi", {"assoir", "assiér"}, "assis")
	data.forms.ind_p_3s[2] = "assied"
	data.category = "seoir"
	data.typ = "irregular"
end

conj["surseoir"] = function()
	construct_non_er_conj(data, "sursoi", "sursoy", "sursoi", "sursi", nil,
		"sursis")
	-- Pronunciation in future/cond as if written sursoir- not surseoir-
	data = m_pron.ind_f(data, dopron(data, "sursoir"))
	data.category = "seoir"
	data.typ = "irregular"
end

conj["seoir"] = function()
	data.notes = "This is a defective verb, only conjugated in the third person."

	construct_non_er_conj(data, "sied", "sey", "sié", "—", "siér")
	only_third_verb(data)
	setform(data, "ppr", {"séant","seyant"})
	data.category = "seoir"
	data.typ = "irregular"
end

conj["bouillir"] = function()
	construct_non_er_conj(data, "bou", "bouill", "bouill", "bouilli")
	data.category = "bouillir"
	data.typ = "irregular"
end

conj["enir"] = function()
	construct_non_er_conj(data, "ien", "en", "ienn", "in", "iendr", "enu")

	if usub(data.stem,-1) == "t" then
		data.category = "tenir"
	else
		data.category = "venir"
	end
	data.typ = "irregular"
end

local function ouvrir_ffrir(rir_prefix)
	data.stem = data.stem .. rir_prefix
	data.pronstem = data.pronstem .. rir_prefix
	data.forms.inf = "rir"

	data.notes = "This verb is conjugated like " .. link(data.stem == "ouv" and "couvrir" or "ouvrir")
	data.notes = data.notes .. " and " .. link(data.stem == "off" and "souffrir" or "offrir") .. ". "
	data.notes = data.notes .. "It is conjugated like a regular " .. link("-er") .. " verb in the present and imperfect indicative, present subjunctive, "
	data.notes = data.notes .. "imperative, and present participle; it is conjugated like a regular " .. link("-ir") .. " verb in the infinitive, "
	data.notes = data.notes .. "future indicative, conditional, past historic, and imperfect subjunctive; "
	data.notes = data.notes .. "and its past participle " .. link("{stem}ert") .. " is irregular."

	data = m_core.make_ind_p_e(data, "r")
	data = m_core.make_ind_ps(data, "ri")
	data = m_core.make_ind_f(data, "rir")
	data.forms.pp = "ert"

	local root = dopron(data, "e")
	local root2 = strip_pron_ending(dopron(data, "a"), "a")

	local stem = root .. "ʁ"
	local stem2 = root2 .. "ʁ"
	local stem3 = root2 .. "ʁi"
	local stem4 = root2 .. "ʁi."

	data = m_pron.er(data, stem, stem2)
	data = m_pron.ind_ps(data, stem3)
	data = m_pron.ind_f(data, stem4)
	data.prons.pp = root2 .. "ɛʁ"
end

conj["ouvrir"] = function()
	ouvrir_ffrir("ouv")
end

conj["ffrir"] = function()
	ouvrir_ffrir("ff")
end

conj["quérir"] = function()
	construct_non_er_conj(data, "quier", "quér", "quièr", "qui", "querr", "quis")
end

conj["aillir"] = function()
	-- FIXME, is the following correct?
	data = m_core.make_ind_p_e(data, "aill")
	data = m_core.make_ind_ps(data, "ailli")
	data = m_core.make_ind_f(data, "aillir")

	local root = dopron(data, "a")

	local stem = root .. "j"
	local stem2 = root .. ".j"
	local stem3 = root .. ".ji"
	local stem4 = root .. ".ji."

	data = m_pron.er(data, stem, stem2)
	data = m_pron.ind_ps(data, stem3)
	data = m_pron.ind_f(data, stem4)
end

conj["chauvir"] = function()
	data.notes = "The forms without -iss- are recommended by the [[w:Académie française|French Academy]], although their usage is not common."

	construct_non_er_conj(data, "chauvi", {"chauv", "chauviss"},
		{"chauv", "chauviss"}, "chauvi")
end

conj["choir"] = function()
	construct_non_er_conj(data, "choi", "choy", "choi", "chu",
		data.stem == "é" and "choir" or {"choir", "cherr"})
	m_core.clear_imp(data)
	data.forms.ppr = "—"

	if data.stem == "" then
		data.notes = "This is a [[defective]] verb, only conjugated in certain tenses."
		-- FIXME! frwikt says 1p 2p of pres indic is rare, and likewise
		-- all of the pres subj.
		data = m_core.make_ind_i(data, "—")
		-- FIXME! frwikt says future in cherr- is archaic, and archaic
		-- conditional forms in cherr- exist as well.
		data = m_core.make_cond_p(data, "choir")
		data = m_pron.cond_p(data, dopron(data, "choi"))
		data = m_core.make_sub_p(data, "—")
		-- FIXME! frwikt does not say subjunctive past is missing other than
		-- 3s.
		data = m_core.make_sub_pa(data, "—")
		data.forms.sub_pa_3s = "chût"
	elseif data.stem == "dé" then
		data.notes = "This verb is [[defective]] in that it is not conjugated in certain tenses. It has no indicative imperfect form, no imperative form and no present participle."
		data = m_core.make_ind_i(data, "—")
		-- FIXME! frwikt does not indicate 'chet' as an alternative. Based on
		-- échoir, we'd expect 'chettent' as alternative as well.
		setform(data, "ind_p_3s", {"choit", "chet"})
		-- FIXME! frwikt lists rare ppr déchoyant.
	elseif data.stem == "é" then
		data.notes = "This verb is defective and is only conjugated in the third-person."
		only_third_verb(data)
		setform(data, "ind_p_3s", {"choit", "chet"})
		-- FIXME! frwikt gives both échettent and échéent as alternatives,
		-- but gives the pronunciation only of the first.
		setform(data, "ind_p_3p", {"choient", "chettent"})
		setform(data, "ppr", "chéant")
	end
end

conj["cueillir"] = function()
	-- FIXME, is the following correct?
	data = m_core.make_ind_p_e(data, "cueill")
	data = m_core.make_ind_ps(data, "cueilli")
	data = m_core.make_ind_f(data, "cueiller")
	data.forms.pp = "cueilli"

	local root = rsub(dopron(data, "cueille"),"j$","")

	local stem = root .. "j"
	local stem2 = root .. ".j"
	local stem3 = root .. ".ji"
	local stem4 = root .. ".ji."

	data = m_pron.er(data, stem, stem2)
	data = m_pron.ind_ps(data, stem3)
	data = m_pron.ind_f(data, stem4)
	data.prons.pp = stem3
end

conj["courir"] = function()
	data.notes = "This verb is conjugated like other regular " .. link("-ir") .. " verbs, "
	data.notes = data.notes .. "except that in the conditional and future tenses an extra ‘r’ is added to the end of the stem "
	data.notes = data.notes .. "and the past participle ends in ''-u''. All verb ending in ''-courir'' are conjugated this way."

	construct_non_er_conj(data, "cour", "cour", "cour", "couru", "courr")
end

conj["falloir"] = function()
	data.notes = "This verb is defective, only conjugated in the third-person singular."
	construct_non_er_conj(data, "fau", "fall", "fall", "fallu", "faudr", nil,
		"faill")
	impersonal_verb(data)
end

conj["férir"] = function()
	data.notes = "This verb is defective and is virtually never conjugated in Modern French, except in a few set phrases or as a mark of extreme archaism. "
	data.notes = data.notes .. "Most of its uses stem from variations on " .. link("sans coup férir") .. "."

	construct_non_er_conj(data, "—", "—", "—", "—", "—", "féru")
end

conj["fuir"] = function()
	construct_non_er_conj(data, "fui", "fuy", "fui", "fui")
end

conj["gésir"] = function()
	data.notes = "This is a [[defective]] verb, and is only conjugated in the present and imperfect indicative."
	construct_non_er_conj(data, "gi", "gis", "gis", "—", "—", "—", "—")
	data.forms.ind_p_3s = "gît"
	m_core.clear_imp(data)
end

conj["re"] = function()
	construct_non_er_conj(data, "", "", "", "i", nil, "u")
	data.forms.ind_p_3s = ""
end

conj["cre"] = function()
	data.notes = "This verb "
	if data.stem ~= "vain" then
		data.notes = data.notes .. "is conjugated like " .. link("vaincre") .. ". That means it "
	end
	data.notes = data.notes .. "is conjugated like " .. link("vendre") .. ", except that its usual stem ''{stem}qu-'' becomes ''{stem}c-'' when either there is no ending, "
	data.notes = data.notes .. "or the ending starts with ''-u-'' or a written consonant. "
	data.notes = data.notes .. "Additionally, when inverted the third person singular in the present adds the infix " .. link("t","-t-") .. ": ''{stem}c-t-il?'' "
	data.notes = data.notes .. "These are strictly spelling changes; pronunciation-wise, the verb is conjugated exactly like " .. link("vendre") .. "."

	construct_non_er_conj(data, "c", "qu", "qu", "qui", nil, "cu")
	data.forms.ind_p_3s = "c"
end

conj["pre"] = function()
	data.notes = "This verb "
	if data.stem ~= "rom" then
		data.notes = data.notes .. "is conjugated like " .. link("rompre") .. ". That means it "
	end
	data.notes = data.notes .. "is conjugated like " .. link("vendre") .. ", except that it adds an extra ''-t'' in the third-person singular form of the present indicative: ''il " .. link(data.stem .. "pt") .. "'', not ''*il {stem}p''. "
	data.notes = data.notes .. "This is strictly a spelling change; pronunciation-wise, the verb is conjugated exactly like " .. link("vendre") .. "."

	construct_non_er_conj(data, "p", "p", "p", "pi", nil, "pu")
end

conj["crire"] = function()
	construct_non_er_conj(data, "cri", "criv", "criv", "crivi", nil, "crit")
end

conj["uire"] = function()
	construct_non_er_conj(data, "ui", "uis", "uis", "uisi", nil, "uit")
end

conj["aitre"] = function()
	data.notes = "This verb is one of a fairly small group of " .. link("-re") .. " verbs, that are all conjugated the same way. They are conjugated the same as the alternative spelling, which has a [[circumflex]] over the ‘i’, except that the circumflex is dropped here."

	-- future stem must be nil here because we are called from conj["aître"]
	construct_non_er_conj(data, "ai", "aiss", "aiss", "u", nil, "u")
end

conj["aître"] = function()
	conj["aitre"]()
	data.notes = "This verb is one of a fairly small group of " .. link("-re") .. " verbs, that are all conjugated the same way. They are unlike other verb groups in that the ‘i’ is given a circumflex before a ‘t’."
	data.forms.ind_p_3s = "aît"
end

conj["oître"] = function()
	data.notes = "This verb is one of a fairly small group of " .. link("-re") .. " verbs, that are all conjugated the same way. They are unlike other verb groups in that the ‘i’ is given a circumflex before a ‘t’. This conjugation pattern is no longer in use and has been replaced by -aître."

	data = m_core.make_ind_p(data, "oi", "oiss")
	data.forms.ind_p_3s = "oît"
	data = m_core.make_ind_ps(data, "u")

	local stem = dopron(data, "ais")
	local stem2 = stem .. ".s"
	local stem3 = stem .. "s"
	local stem4 = dopron(data, "u")

	data = m_pron.ind_p(data, stem, stem2, stem3)
	data = m_pron.ind_ps(data, stem4)
	data = m_pron.ind_f(data, stem .. ".t")
end

conj["indre"] = function()
	construct_non_er_conj(data, "in", "ign", "ign", "igni", nil, "int")
end

conj["clure"] = function()
	local pp
	if data.stem == "in" or data.stem == "trans" or data.stem == "oc" then
		pp = "clus"
		data.notes = "This verb is one of a few verbs in ''-clure'' where the past participle is in ''-us(e)'' instead of ''-u(e)''."
	end

	construct_non_er_conj(data, "clu", "clu", "clu", "clu", nil, pp)
end

conj["braire"] = function()
	data = m_core.make_ind_p(data, "brai", "bray", "brai")
	-- FIXME, is the following really correct?
	data = m_core.make_ind_ps_a(data, "bray")

	local stem = dopron(data, "brais")
	data.forms.pp = "brait"

	local stem2 = stem .. ".j"
	local stem3 = stem .. "."

	data = m_pron.ind_p(data, stem, stem2)
	data = m_pron.ind_ps_a(data, stem2)
	data = m_pron.ind_f(data, stem3)
	data.prons.pp = stem
end

conj["clore"] = function()
	data.notes = "This verb is not conjugated in certain tenses."

	data = m_core.make_ind_p(data, "clo", "clos")
	data.forms.ind_p_3s = "clôt"
	data = m_core.make_ind_i(data, "—")
	data = m_core.make_ind_ps(data, "—")
	data.forms.ppr = "closant"
	data.forms.pp = "clos"

	local stem = dopron(data, "clo")
	local stem2 = stem .. ".z"
	local stem3 = stem .. "z"
	local stem4 = dopron(data, "clɔ") .. "."

	data = m_pron.ind_p(data, stem, stem2, stem3)
	data = m_pron.ind_f(data, stem4)
	data.prons.pp = stem
end

conj["confire"] = function()
	construct_non_er_conj(data, "confi", "confis", "confis", "confi", nil)
end

conj["coudre"] = function()
	data.notes = "This verb "
	if data.stem ~= "" then
		data.notes = data.notes .. "is conjugated like " .. link("coudre") .. ". That means it"
	end
	data.notes = data.notes .. " is conjugated like " .. link("rendre") .. ", except that its stem is ''{stem}coud-'' in only part of the conjugation. "
	data.notes = data.notes .. "Before endings that begin with vowels, the stem ''{stem}cous-'' (with a " .. IPA("/-z-/") .. " sound) is used instead; "
	data.notes = data.notes .. "for example, ''nous'' " .. link("{stem}cousons") .. ", not ''*nous {stem}coudons''."

	construct_non_er_conj(data, "coud", "cous", "cous", "cousi", nil, "cousu")
	data.forms.ind_p_3s = "coud"
end

conj["croire"] = function()
	construct_non_er_conj(data, "croi", "croy", "croi", "cru")
end

conj["croitre"] = function()
	if data.stem == "" then
		data.notes = "This verb takes an especially irregular conjugation, taking circumflexes in many forms, so as to distinguish from the forms of the verb " .. link("croire") .. "."
		construct_non_er_conj(data, "croî", "croiss", "croiss", "crû")
		data.forms.ind_ps_1p = "crûmes"
		data.forms.ind_ps_2p = "crûtes"
		data.forms.sub_pa_3s = "crût"
	else
		-- FIXME
		data.notes = "This verb is conjugated like " .. link("croitre") ..
			" except that it does not take circumflexes like that verb does."
		construct_non_er_conj(data, "croi", "croiss", "croiss", "cru")
	end
end

conj["croître"] = function()
	if data.stem == "" then
		data.notes = "This verb takes an especially irregular conjugation, taking circumflexes in many forms, so as to distinguish from the forms of the verb " .. link("croire") .. "."
		construct_non_er_conj(data, "croî", "croiss", "croiss", "crû")
	else
		-- FIXME
		data.notes = "This verb is conjugated like " .. link("croître") ..
			" except that it takes fewer circumflexes than that verb does."
		construct_non_er_conj(data, "croi", "croiss", "croiss", "crû")
		data.forms.ind_p_3s = "croît"
	end
	data.forms.ind_ps_1p = "crûmes"
	data.forms.ind_ps_2p = "crûtes"
	data.forms.sub_pa_3s = "crût"
end

conj["foutre"] = function()
	construct_non_er_conj(data, "fou", "fout", "fout", "fouti", nil,
		"foutu")
end

conj["soudre"] = function()
	construct_non_er_conj(data, "sou", "solv", "solv", "solu", nil, "sous")
	data = m_core.make_sub_pa(data, "—")
end

conj["voir"] = function()
	construct_non_er_conj(data, "voi", "voy", "voi", "vi", "verr", "vu")
end

conj["cevoir"] = function()
	construct_non_er_conj(data, "çoi", "cev", "çoiv", "çu", "cevr")
end

conj["battre"] = function()
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
	data.forms.ind_p_3s = "bat"
end

conj["circoncire"] = function()
	construct_non_er_conj(data, "circonci", "circoncis", "circoncis",
		"circonci", nil, "circoncis")
end

conj["lire"] = function()
	construct_non_er_conj(data, "li", "lis", "lis", "lu")
end

conj["luire"] = function()
	construct_non_er_conj(data, "lui", "luis", "luis", {"lui", "luisi"},
		nil, "lui")
	data = m_core.make_sub_pa(data, "luisi")
	data = m_pron.sub_pa(data, dopron(data, "luisi"))
	setform(data, "ind_ps_3s", "luit")
end

conj["maudire"] = function()
	data.notes = "This is ''almost'' a regular verb of the second conjugation, like " .. link("finir") .. ", " .. link("choisir") .. ", "
	data.notes = data.notes .. "and most other verbs with infinitives ending in " .. link("-ir") .. ". Its only irregularities are in the past participle, "
	data.notes = data.notes .. "which is " .. link("maudit","maudit(e)(s)") .. " rather than *''maudi(e)(s)'', and in the infinitive, "
	data.notes = data.notes .. "which is ''maudire'' rather than *''maudir''."

	construct_non_er_conj(data, "maudi", "maudiss", "maudiss", "maudi",
		nil, "maudit")
end

conj["mettre"] = function()
	if data.stem ~= "" then
		data.notes = "This verb is conjugated like " .. link("mettre") .. ". That means it "
	else
		data.notes = "This verb "
	end
	data.notes = data.notes .. "is conjugated like " .. link("battre") .. " except that its past participle is " .. link("{stem}mis") .. ", "
	data.notes = data.notes .. "not *''{stem}mettu'', and its past historic and imperfect subjunctive "
	data.notes = data.notes .. "are formed with ''{stem}mi-'', not *''{stem}metti-''."

	construct_non_er_conj(data, "met", "mett", "mett", "mi", nil, "mis")
	data.forms.ind_p_3s = "met"
end

conj["moudre"] = function()
	construct_non_er_conj(data, "moud", "moul", "moul", "moulu")
	data.forms.ind_p_3s = "moud"
end

conj["mouvoir"] = function()
	construct_non_er_conj(data, "meu", "mouv", "meuv", "mu", "mouvr")
	if data.stem == "" then
		data.forms.pp = "mû"
	end
end

conj["paitre"] = function()
	data.notes = "This verb is not conjugated in certain tenses."
	construct_non_er_conj(data, "pai", "paiss", "paiss", "—")
end

conj["paître"] = function()
	conj["paitre"]()
	data.forms.ind_p_3s = "paît"
end

conj["pleuvoir"] = function()
	data.notes = "This is a [[defective]] verb, only conjugated in the [[third-person]]. The [[third-person plural]] forms are only used figuratively."

	construct_non_er_conj(data, "pleu", "pleuv", "pleuv", "plu", "pleuvr")
	only_third_verb(data)
	-- FIXME, check if this is correct
	data.prons.ppr = "plø.vɑ̃"
	data.typ = "irregular"
end

conj["pourvoir"] = function()
	data.notes = "''Pourvoir'' and its derived verbs conjugate like " .. link("voir") .. ", except that their past historic indicative and imperfect subjunctive are in ''-vu-'' instead of ''-vi-''."

	construct_non_er_conj(data, "pourvoi", "pourvoy", "pourvoi", "pourvu")
end

conj["prendre"] = function()
	if data.stem ~= "" then
		data.notes = "This verb is conjugated on the model of " .. link("prendre") .. ". That means it is quite irregular, with the following patterns:\n"
	else
		data.notes = "This verb is quite irregular, with the following patterns:\n"
	end
	data.notes = data.notes .. "*In the infinitive, in the singular forms of the present indicative, and in the future and the conditional, it is conjugated like " .. link("rendre") .. ", " .. link("perdre") .. ", etc. (sometimes called the regular " .. link("-re") .. " verbs).\n"
	data.notes = data.notes .. "*In the plural forms of the present indicative and imperative, in the imperfect indicative, in the present subjunctive, and in the present participle, it is conjugated like " .. link("appeler") .. " or " .. link("jeter") .. ", using the stem ''{stem}prenn-'' before mute ‘e’ and the stem ''{stem}pren-'' elsewhere.\n"
	data.notes = data.notes .. "*In the past participle, and in the past historic and the imperfect subjunctive, its conjugation resembles that of " .. link("mettre") .. "."

	construct_non_er_conj(data, "prend", "pren", "prenn", "pri", nil, "pris")
	data.forms.ind_p_3s = "prend"
end

conj["faire"] = function()
	construct_non_er_conj(data, "fai", "fais", "fais", "fi", "fer", "fait",
		"fass")
	-- Need to override the present indicative 2p and 3p, the imperative 2p,
	-- and the pronunciations of these forms as well as all forms in fais-.
	setform(data, "ind_p_2p", "faites")
	setform(data, "ind_p_3p", "font")
	data.prons.ind_p_1p = dopron(data, "fesons")
	data.imp_p_2p = "faites"
	copy_ind_pron_to_imp(data)
	data = m_pron.ind_i(data, strip_pron_ending(dopron(data, "fesez"), "e"))
	data.prons.ppr = dopron(data, "fesant")
end

conj["boire"] = function()
	construct_non_er_conj(data, "boi", "buv", "boiv", "bu")
end

conj["devoir"] = function()
	construct_non_er_conj(data, "doi", "dev", "doiv", "du", "devr")
	if data.stem == "" then
		data.forms.pp = "dû"
	end
end

conj["avoir"] = function()
	data = m_core.make_ind_p(data, "a", "av")
	data.forms.ind_p_1s = "ai"
	data.forms.ind_p_3s = "a"
	data.forms.ind_p_3p = "ont"
	data = m_core.make_ind_ps(data, "eu")
	data = m_core.make_ind_f(data, "aur")
	data = m_core.make_sub_p(data, "ai")
	data.forms.sub_p_3s = "ait"
	data.forms.sub_p_1p = "ayons"
	data.forms.sub_p_2p = "ayez"
	data = m_core.make_imp_p_sub(data)
	data.forms.ppr = "ayant"

	local root = rsub(dopron(data, "a"),"a$","")

	local stem = root .. "a"
	local stem2 = root .. "a.v"
	local stem3 = root .. "y"
	local stem4 = root .. "o."
	local stem5 = root .. "ɛ"
	local stem6 = root .. "ɛ."

	data = m_pron.ind_p(data, stem, stem2)
	data.prons.ind_p_1s = root .. "e"
	data.prons.ind_p_3p = root .. "ɔ̃"
	data = m_pron.ind_ps(data, stem3)
	data = m_pron.ind_f(data, stem4)
	data = m_pron.sub_p(data, stem5, stem6)
	generate_imp_pron_from_forms(data)
	data.prons.ppr = stem6 .. "jɑ̃"
end

conj["être"] = function()
	data.forms.ind_p_1s = "suis"
	data.forms.ind_p_2s = "es"
	data.forms.ind_p_3s = "est"
	data.forms.ind_p_1p = "sommes"
	data.forms.ind_p_2p = "êtes"
	data.forms.ind_p_3p = "sont"

	data = m_core.make_ind_i(data, "ét")
	data = m_core.make_ind_ps(data, "fu")
	data = m_core.make_ind_f(data, "ser")

	data.forms.sub_p_1s = "sois"
	data.forms.sub_p_2s = "sois"
	data.forms.sub_p_3s = "soit"
	data.forms.sub_p_1p = "soyons"
	data.forms.sub_p_2p = "soyez"
	data.forms.sub_p_3p = "soient"

	data = m_core.make_imp_p_sub(data)
	data.forms.pp = "été"
	data.forms.ppr = "étant"

	local root_s = rsub(dopron(data, "sa"),"sa$","")
	local root_e = rsub(dopron(data, "é"),"e$","")
	local root_f = rsub(dopron(data, "fa"),"fa$","")

	local stem = root_e .. "ɛ"
	local stem2 = root_e .. "e.t"
	local stem3 = root_f .. "fy"
	local stem4 = root_s .. "sə."
	local stem5 = root_s .. "swa"
	local stem6 = root_s .. "swa."

	data.prons.ind_p_1s = root_s .. "sɥi"
	data.prons.ind_p_2s = stem
	data.prons.ind_p_3s = stem
	data.prons.ind_p_1p = root_s .. "sɔm"
	data.prons.ind_p_2p = stem .. "t"
	data.prons.ind_p_3p = root_s .. "sɔ̃"
	data = m_pron.ind_i(data, stem2)
	data = m_pron.ind_ps(data, stem3)
	data = m_pron.ind_f(data, stem4)
	data = m_pron.sub_p(data, stem5, stem6)

	data.prons.imp_p_2s = stem5
	data.prons.imp_p_1p = stem6 .. "jɔ̃"
	data.prons.imp_p_2p = stem6 .. "je"
	data.prons.ppr = stem2 .. "ɑ̃"
	data.prons.pp = stem2 .. "e"
end

conj["estre"] = function()
	conj["être"]()

	for key,val in pairs(data.forms) do
		data.forms[key] = rsub(val, "[éê]", "es")
		data.forms[key] = rsub(data.forms[key], "û", "us")
		data.forms[key] = rsub(data.forms[key], "ai", "oi")
	end

	data.forms.ind_ps_1p = "fumes"
	data.forms.sub_pa_3s = "fust"
	data.forms.pp = "esté"
end

conj["naitre"] = function()
	-- future stem must be nil here because we are called from conj["naître"]
	construct_non_er_conj(data, "nai", "naiss", "naiss", "naqui", nil, "né")
end

conj["naître"] = function()
	conj["naitre"]()
	data.forms.ind_p_3s = "naît"
end

conj["envoyer"] = function()
	data.notes = "This verb is is one a few verbs that conjugate like " .. link("noyer") .. ", except in the future and conditional, where they conjugate like " .. link("voir") .. "."

	data = m_core.make_ind_p_e(data, "envoi", "envoy", "envoy")
	data = m_core.make_ind_f(data, "enverr")

	local stem = dopron(data, "envoi")
	local stem2 = stem .. ".j"
	local stem3 = dopron(data, "envè") .. "."

	data = m_pron.er(data, stem, stem2)
	data = m_pron.ind_f(data, stem3)
end

conj["irreg-aller"] = function()
	data.notes = "The verb ''{stem}aller'' has a unique and highly irregular conjugation. The second-person singular imperative ''[[va]]'' additionally combines with ''[[y]]'' to form ''[[vas-y]]'' instead of the expected ''va-y''."

	data = m_core.make_ind_p_e(data, "all")
	setform(data, "ind_p_1s", "vais")
	setform(data, "ind_p_2s", "vas")
	setform(data, "ind_p_3s", "va")
	setform(data, "ind_p_3p", "vont")
	data = m_core.make_ind_f(data, "ir")
	data = m_core.make_sub_p(data, "aill")
	setform(data, "imp_p_2s", "va")

	local stem = dopron(data, "a")
	local stem2 = dopron(data, "i")

	data = m_pron.er(data, stem .. "l", stem .. ".l")
	data = m_pron.ind_f(data, stem2)
	data = m_pron.sub_p(data, stem .. "j", stem .. "j.")
end

conj["dire"] = function()
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

conj["vivre"] = function()
	construct_non_er_conj(data, "vi", "viv", "viv", "vécu")
end

conj["mourir"] = function()
	construct_non_er_conj(data, "meur", "mour", "meur", "mouru", "mourr",
		"mort")
end

conj["savoir"] = function()
	construct_non_er_conj(data, "sai", "sav", "sav", "su", "saur", nil,
		"sach")
	m_core.make_imp_p_sub(data)
	generate_imp_pron_from_forms(data)
end

conj["pouvoir"] = function()
	construct_non_er_conj(data, "peu", "pouv", "peuv", "pu", "pourr", nil,
		"puiss")
	data.prons.ind_p_1s = "peux"
	data.prons.ind_p_2s = "peux"
	m_core.clear_imp(data)
end

conj["vouloir"] = function()
	construct_non_er_conj(data, "veu", "voul", "veul", "voulu", "voudr", nil,
		"veuill", "voul")
	data.prons.ind_p_1s = "veux"
	data.prons.ind_p_2s = "veux"
	m_core.clear_imp(data)
end

conj["bruire"] = function()
	construct_non_er_conj(data, "bruis", "bruiss", "bruiss", "brui")
end

conj["frire"] = function()
	data.notes = "This verb is defective and it is not conjugated in certain"
		.. " tenses and plural persons. Using " .. link("faire") ..
		" '''frire''' is recommended."
	construct_non_er_conj(data, "fris", "fris", "fris", "fri", nil, "frit")
	-- clear subjunctive present and past
	data = m_core.make_sub_pa(data, "—")
	data = m_core.make_sub_p(data, "—")
	-- clear plural forms
	for _, k in ipairs(all_verb_props) do
		if rmatch(k, "[123]p") then
			data.forms[k] = "—"
		end
	end
end

local function call_conj(conjtyp, arg)
	local ending = data.forms.inf
	data.pronstem = strip_respelling_ending(data.pron, ending) or data.stem
	conj[conjtyp](arg)
end

-- Conjugate the verb according to the TYPE, which is either explicitly
-- specified by the caller of {{fr-conj-auto}} or derived automatically.
-- NOTE FIXME: Currently, verbs of of type 'xxer' (i.e. 'appeler', 'jeter'
-- and derivatives) and of type 'e-er' (e.g. 'mener') need to have their type
-- explicitly specified should be:
-- * 'ler' for 'appeler' and derivatives
-- * 'ter' for 'jeter' and derivatives
-- * the last four letters for verbs of type 'e-er', e.g.
--
-- appeler: {{fr-conj-auto|appe|ler}}
-- mener: {{fr-conj-auto|m|ener}}
--
-- This isn't necessary for verbs in ecer, -eger, -eyer, and shouldn't be
-- necessary for the other verbs either (FIXME). Also, verbs in -éyer look
-- to be broken, missing a conj[] entry (FIXME).
local function conjugate(typ)
	data.forms.inf = typ
	local future_stem = rsub(data.forms.inf, "e$", "")
	data = m_core.make_ind_f(data, future_stem)

	if rfind(typ,"^[^aeéiou]er$") and typ ~= "cer" and typ ~= "ger"  and typ ~= "yer" then
		call_conj("xxer", rsub(typ,"er$",""))
	elseif rfind(typ,"^e[^aeiou]+er$") and typ ~= "ecer" and typ ~= "eger"  and typ ~= "eyer" then
		call_conj("e-er", rsub(typ,"^e(.+)er$","%1"))
	elseif rfind(data.stem .. typ,"é" .. written_cons_c .. "+er$") and typ ~= "écer" and typ ~= "éger"  and typ ~= "éyer" then
		local root = data.stem .. typ
		data.stem = rsub(root, "é" .. written_cons_c .. "+er$", "")
		data.forms.inf = rmatch(root, "(é" .. written_cons_c .. "+er)$")
		call_conj("é-er", rsub(data.forms.inf,"^é(.+)er$","%1"))
	elseif rfind(data.stem .. typ,"é[gq]uer$") then --alléguer, disséquer, etc.
		local root = data.stem .. typ
		data.stem = rsub(root, "é[gq]uer$", "")
		data.forms.inf = rmatch(root, "(é[gq]uer)$")
		call_conj("é-er", rsub(data.forms.inf,"^é([gq]u)er$","%1"))
	elseif alias[typ] then
		data.stem = data.stem .. rsub(typ, alias[typ], "")
		data.forms.inf = alias[typ]
		call_conj(alias[typ], nil)
	elseif conj[typ] then
		call_conj(typ, nil)
	elseif typ ~= "" then
		error('The type "' .. typ .. '" is not recognized')
	end
end

-- Split the infinitive into "stem" and conjugation type, where the conjugation
-- type is the longest suffix of the infinitive for which there's an entry
-- in conj[], and stem is the preceding text. (As an exception, certain
-- longer suffixes are mapped to the conjugation type of shorter suffixes
-- using alias[]. An example is 'connaitre', which conjugates like '-aitre'
-- verbs rather than like 'naitre' and its derivatives.) Note that for many
-- irregular verbs, the "stem" is actually the prefix, or empty if the verb
-- has no prefix.
local function auto(pagename)
	local stem = ""
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

-- This is meant to be invoked by the module itself, or possibly by a
-- different version of the module (for comparing changes to see whether
-- they have an effect on conjugations or pronunciations).
function export.do_generate_forms(args)
	local stem = args[1] or ""
	local typ = args[2] or ""
	local argspron = args.pron
	local refl = false
	if typ == "" then typ = stem; stem = ""; end

	local PAGENAME = mw.title.getCurrentTitle().text

	if stem == "" and typ == "" then
		-- most common situation, {{fr-conj-auto}}
		stem, typ = auto(PAGENAME)
	elseif stem == "" and rfind(PAGENAME, typ, 1, true) == 1 and typ ~= PAGENAME then
		track("type-case2")
		-- FIXME: when does this happen?
		stem = typ
		typ = usub(PAGENAME, ulen(typ) + 1)
	elseif stem == "" then
		-- explicitly specified stem, e.g. {{fr-conj-auto|aimer}} in userspace
		-- (NOTE: stem moved to typ above)
		stem, typ = auto(typ)
	-- else, explicitly specified stem and type, e.g. {{fr-conj-auto|appe|ler}}
	end

	-- autodetect reflexives
	if rfind(stem, "^s'") then
		stem = rsub(stem, "^s'", "")
		argspron = strip_respelling_beginning(argspron, "s'", "split")
		refl = true
	elseif rfind(stem, "^se ") then
		stem = rsub(stem, "^se ", "")
		argspron = strip_respelling_beginning(argspron, "se ", "split")
		refl = true
	end

	local pronargs = argspron and rsplit(argspron, ",") or {false}
	local all_forms, all_prons 
	for i = 1, #pronargs do
		local pronarg = pronargs[i]
		if pronarg == false then pronarg = nil end
		data = {
			refl = refl,
			stem = stem,
			aux = "avoir",
			pron = pronarg,
			forms = {},
			prons = {}
		}
		conjugate(typ)
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
	-- and data.typ as set/modified in the conjugation functions of the last
	-- iteration of the loop above. As it happens, this doesn't matter
	-- because we iterate over pronunciations keeping the stem and conjugation
	-- type the same, but might matter one day if we break this assumption.
	data = m_core.extract(data, args)

	if args.impers then
		impersonal_verb(data)
	elseif args.onlythird then
		only_third_verb(data)
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

	-- args.refl can override data.refl
	if args.refl == "n" or args.refl == "no" then
		data.refl = false
	elseif args.refl then
		data.refl = true
	end
	if data.refl then data = m_core.refl(data) end

	if etre[data.forms.inf] then
		data.aux = "être"
	elseif avoir_or_etre[data.forms.inf] then
		data.aux = "avoir or être"
	end
	if args.aux == "a" or args.aux == "avoir" then
		data.aux = "avoir"
	elseif args.aux == "e" or args.aux == "être" then
		data.aux = "être"
	elseif args.aux == "ae" or args.aux == "avoir,être" or args.aux == "avoir or être" then
		data.aux = "avoir or être"
	elseif args.aux then
		error("Unrecognized value for aux=, should be 'a', 'e', 'ae', 'avoir', 'être', or 'avoir,être'")
	end

	data.forms.inf_nolink = data.forms.inf_nolink or data.forms.inf
	data.forms.ppr_nolink = data.forms.ppr_nolink or data.forms.ppr
	data.forms.pp_nolink = data.forms.pp_nolink or data.forms.pp

	return data
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
					-- Uncomment this to display the particular case and
					-- differing forms.
					--error(arrayname .. "." .. prop .. " " .. (val and table.concat(val, ",") or "nil") .. " || " .. (newval and table.concat(newval, ",") or "nil"))
					difconj = true
					break
				end
			end
			if difconj then
				break
			end
		end
		track(difconj and "different-conj" or "same-conj")
	end

	data = m_core.link(data)

	local category = ""
	if data.aux == "être" then
		category = "[[Category:French verbs taking être as auxiliary]]"
	elseif data.aux == "avoir or être" then
		category = "[[Category:French verbs taking avoir or être as auxiliary]]"
	end
	if data.category then
		category = category .. "[[Category:French verbs with conjugation " .. data.category .. "]]"
	end
	if data.typ then
		category = category .. "[[Category:French " .. data.typ .. " verbs]]"
	end

	return m_conj.make_table(data) .. category
end

return export

-- For Vim, so we get 4-space tabs
-- vim: set ts=4 sw=4 noet:
