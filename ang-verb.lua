local m_links = require("Module:links")
local strutils = require("Module:string utilities")
local ut = require("Module:utils")

local lang = require("Module:languages").getByCode("ang")

local rfind = mw.ustring.find
local rmatch = mw.ustring.match
local rsplit = mw.text.split
local rsubn = mw.ustring.gsub
local u = mw.ustring.char

-- version of rsubn() that discards all but the first return value
local function rsub(term, foo, bar, n)
	local retval = rsubn(term, foo, bar, n)
	return retval
end

-- like str:gsub() but discards all but the first return value
local function gsub(term, foo, bar, n)
	local retval = term:gsub(foo, bar, n)
	return retval
end

local export = {}

local MACRON = u(0x0304)

local long_vowel = "āēīōūȳǣ" .. MACRON -- No precomposed œ + macron
local short_vowel = "aeiouyæœ"
local short_vowel_c = "[" .. short_vowel .. "]"
local vowel = long_vowel .. short_vowel
local vowel_c = "[" .. vowel .. "]"
local long_vowel_c = "[" .. long_vowel .. "]"
local non_vowel_c = "[^" .. vowel .. "]"
local always_unvoiced_cons = "cċkptxz"
local always_unvoiced_cons_c = "[" .. always_unvoiced_cons .. "]"
local unvoiced_cons = always_unvoiced_cons .. "fsþð"
local unvoiced_cons_c = "[" .. unvoiced_cons .. "]"
local cons = "bcċdfgġhklmnprstwxzþðƿ"
local cons_c = "[" .. cons .. "]"

local slots_and_accel = {
	["infinitive"] = "",
	["infinitive2"] = "",
	["1sg_pres_indc"] = "1|s|pres|indc",
	["2sg_pres_indc"] = "2|s|pres|indc",
	["3sg_pres_indc"] = "3|s|pres|indc",
	["pl_pres_indc"] = "123|p|pres|indc",
	["sg_pres_subj"] = "123|s|pres|subj",
	["pl_pres_subj"] = "123|p|pres|subj",
	["1sg_past_indc"] = "1|s|past|indc",
	["2sg_past_indc"] = "2|s|past|indc",
	["3sg_past_indc"] = "3|s|past|indc",
	["pl_past_indc"] = "123|p|past|indc",
	["sg_past_subj"] = "123|s|past|subj",
	["pl_past_subj"] = "123|p|past|subj",
	["sg_impr"] = "2|s|impr",
	["pl_impr"] = "2|p|impr",
	["pres_ptc"] = "pres|part",
	["past_ptc"] = "past|part",
}

local function ends_in_long_vowel(word)
	if rfind(word, long_vowel_c .. "$") then
		return true
	elseif rfind(word, "ē[ao]$") then
		return true
	elseif rfind(word, "ī[eo]$") then
		return true
	else
		return false
	end
end

local function make_table(args)
	local title = args.title
	local accel_lemma = args.infinitive[1] or mw.title.getCurrentTitle().text
	if not title then
		local curtitle = mw.title.getCurrentTitle()
		title = "Conjugation of ''" .. accel_lemma
		if args["type"] then
			title = title .. "&nbsp;(" .. args["type"] .. ")"
		end
	end
	local table_args = {
		title = title,
		style = args.style == "right" and "float:right; clear:right;" or "",
		width = args.width or "30",
	}
	for slot, accel_form in pairs(slots_and_accel) do
		local table_arg = {}
		local forms = args[slot] and #args[slot] > 0 and args[slot] or {"—"}
		for _, form in ipairs(forms) do
			table.insert(table_arg, form == "—" and form or m_links.full_link{
				lang = lang, term = form, accel = {
					form = accel_form ~= "" and accel_form or nil,
					lemma = accel_lemma,
				}
			})
			table_args[slot] = table.concat(table_arg, ", ")
		end
	end
	local table = [=[
<div class="NavFrame" style="{style}width:{width}em">
<div class="NavHead" style="background: #EFF7FF" >{title}
</div>
<div class="NavContent">
{\op}| style="background:#F9F9F9;text-align:center;width:{width}em" class="inflection-table"
|-
! style="font-size:90%; background-color:#FFFFE0; text-align: left" | [[infinitive]]
| {infinitive}
| {infinitive2}
|-
! style="font-size:80%;" | [[indicative mood|indicative]]
! style="font-size:80%; background-color:#EFEFFF" | [[present tense|present]]
! style="font-size:80%; background-color:#EFEFFF" | [[past tense|past]]
|-
! style="font-size:90%; background-color:#FFFFE0; text-align: left" | [[first person|1st-person]] [[singular]]
| {1sg_pres_indc}
| {1sg_past_indc}
|-
! style="font-size:90%; background-color:#FFFFE0; text-align: left" | [[second person|2nd-person]] singular
| {2sg_pres_indc}
| {2sg_past_indc}
|-
! style="font-size:90%; background-color:#FFFFE0; text-align: left" | [[third person|3rd-person]] singular
| {3sg_pres_indc}
| {3sg_past_indc}
|-
! style="font-size:90%; background-color:#FFFFE0; text-align: left" | [[plural]]
| {pl_pres_indc}
| {pl_past_indc}
|-
! style="font-size:80%;" | [[subjunctive]]
! style="font-size:80%; background-color:#EFEFFF" | [[present tense|present]]
! style="font-size:80%; background-color:#EFEFFF" | [[past tense|past]]
|-
! style="font-size:90%; background-color:#FFFFE0; text-align: left" | singular
| {sg_pres_subj}
| {sg_past_subj}
|-
! style="font-size:90%; background-color:#FFFFE0; text-align: left" | plural
| {pl_pres_subj}
| {pl_past_subj}
|-
! style="font-size:80%;" | [[imperative]]
! style="font-size:80%; background-color:#EFEFFF" colspan="2" | 
|-
! style="font-size:90%; background-color:#FFFFE0; text-align: left" | singular
| colspan="2" | {sg_impr}
|-
! style="font-size:90%; background-color:#FFFFE0; text-align: left" | plural
| colspan="2" | {pl_impr}
|-
! style="font-size:80%;" |[[participle]]
! style="font-size:80%; background-color:#EFEFFF" | [[present]]
! style="font-size:80%; background-color:#EFEFFF" | [[past]]
|-
! style="font-size:90%; background-color:#FFFFE0; text-align: left" |
| {pres_ptc}
| {past_ptc}
|{\cl}</div></div>]=]
	return strutils.format(table, table_args)
end

function export.make_table(frame)
	local parent_args = frame:getParent().args
	local params = {
		["title"] = {default = "—"},
		["type"] = {},
		["width"] = {},
		["style"] = {},
	}
	for slot, _ in pairs(slots_and_accel) do
		params[slot] = {}
	end
	local args = require("Module:parameters").process(parent_args, params)
	return make_table(args)
end

-- Add an ending that begins with a consonant onto a stem, making adjustments
-- as necessary when two consonants come together. Currently recognizes only
-- the three endings "st", "þ" and "d".
local function construct_cons_stem_ending(stem, ending)
	-- If the stem ends in a geminate, reduce to single consonant
	-- (e.g. fyll-, sett-).
	local origstem = stem
	local base, final_geminated = rmatch(stem, "^(.-)(" .. non_vowel_c .. ")%2$")
	if base then
		stem = base .. final_geminated
	end
	stem = gsub(stem, "ċ$", "c")
	stem = gsub(stem, "nġ$", "ng")
	if ending == "st" then
		-- For 2sg:
		-- cyssan + -st -> cyst, tǣsan + -st -> tǣst
		-- settan + -st -> setst, myntan + -st -> myn(t)st (?), restan + -st -> restst/rest (?)
		-- bǣdan + -st -> bǣtst, sendan + -st -> sen(t)st
		-- cȳþan + -st -> cȳst, cwiþ- + -st -> cwist
		-- wiex- + -st -> wiext
		-- drenċan + -st -> drencst
		-- senġan + -st -> sengst
		if stem:find("s$") then
			return stem .. "t"
		elseif stem:find("[dt]$") then
			if rfind(stem, vowel_c .. "[dt]$") then
				return gsub(stem, "[dt]$", "tst")
			elseif rfind(stem, "s[dt]$") then
				return {gsub(stem, "[dt]$", "tst"), gsub(stem, "s[dt]$", "st")}
			else
				return {gsub(stem, "[dt]$", "st"), gsub(stem, "[dt]$", "tst")}
			end
		elseif stem:find("þ$") then
			return gsub(stem, "þ$", "st")
		elseif stem:find("x$") then
			return stem .. "t"
		else
			return stem .. "st"
		end
	elseif ending == "þ" then
		-- For 3sg:
		-- cyssan + -þ -> cyst, tǣsan + -þ -> tǣst
		-- settan + -þ -> set(t), myntan + -þ -> mynt, restan + -þ -> rest
		-- bǣdan + -þ -> bǣt(t), sendan + -þ -> sent
		-- cȳþan + -þ -> cȳþ(þ), cwiþ- + -þ -> cwiþ(þ)
		-- wiex- + -þ -> wiext
		-- drenċan + -þ -> drencþ
		-- senġan + -þ -> sengþ
		if rfind(stem, vowel_c .. "[dt]$") then
			return {gsub(stem, "[dt]$", "tt"), gsub(stem, "[dt]$", "t")}
		elseif stem:find("[dt]$") then
			return gsub(stem, "[dt]$", "t")
		elseif stem:find("[sx]$") then
			return stem .. "t"
		elseif stem:find("þ$") then
			return {stem .. "þ", stem}
		else
			return stem .. "þ"
		end
	elseif ending == "d" then
		-- For past:
		-- cyssan + -de -> cyste, tǣsan + -de -> tǣsde
		-- settan + -de -> sette, myntan + -de -> mynte, restan + -de -> reste, mētan + -de -> mētte
		-- bǣdan + -de -> bǣdde, sendan + -de -> sende, hreddan + -de -> hredde
		-- cȳþan + -de -> cȳþde (later cȳdde), ġeorwirþan + -de -> ġeorwirþde, sċeþþan + -de -> sċeþte
		--   (? Bosworth-Toller has only sċeþede, and has pæþde for *pæþte from pæþþan)
		-- līexan + -de -> līexte
		-- pyffan + -de -> pyfte, ġelīefan + -de -> ġelīefde
		-- drenċan + -de -> drencte
		-- senġan + -de -> sengde
		-- cīepan + -de -> cīepte, clyppan + -de -> clypte
		-- spillan + -de -> spilde, cierran + -de -> cierde, wemman + -de -> wemde, etc.
		if stem:find(vowel_c .. "t$") then
			return stem .. "t"
		elseif stem:find(vowel_c .. "d$") then
			return stem .. "d"
		elseif stem:find("[dt]$") then
			return stem
		elseif stem:find(always_unvoiced_cons_c .. "$") or rfind(origstem, unvoiced_cons_c .. "[sfþð]$") then
			return stem .. "t"
		else
			return stem .. "d"
		end
	else
		error("Unrecognized ending: '" .. ending .. "'")
	end
end

-- Default function for combining a stem and an ending. This makes no adjustments
-- to the result other than returning an optional variant ending in -h if the result
-- ends in -g. Example: stīgan preterite stāg or stāh. (Does not apply to a form
-- ending in -ġ.) If adjustments are necessary at the stem/ending boundary, use e.g.
-- construct_cons_stem_ending.
local function default_construct_stem_ending(stem, ending)
	local form = stem .. ending
	if form:find("g$") then
		return {form, gsub(form, "g$", "h")}
	else
		return form
	end
end

local function add_ending(args, slot, stems, ending, construct_stem_ending)
	local function append_stem_ending(stem, ending)
	end
	construct_stem_ending = construct_stem_ending or default_construct_stem_ending
	if type(stems) ~= "table" then
		stems = {stems}
	end
	if not args[slot] then
		args[slot] = {}
	end
	for _, stem in ipairs(stems) do
		local form = construct_stem_ending(stem, ending)
		if type(form) == "string" then
			ut.insert_if_not(args[slot], form)
		else
			for _, f in ipairs(form) do
				ut.insert_if_not(args[slot], f)
			end
		end
	end
end

local function construct_optional_ge_stem_ending(stem, ending)
	return "([[ge" .. stem .. ending .. "|ġe]])[[" .. stem .. ending .. "]]"
end

local function make_non_past(args, presa, prese, pres23, impsg, pp, with_ge)
	add_ending(args, "infinitive", presa, "n")
	add_ending(args, "infinitive2", prese, "nne")
	add_ending(args, "1sg_pres_indc", prese, "")
	add_ending(args, "2sg_pres_indc", pres23, "st", construct_cons_stem_ending)
	add_ending(args, "3sg_pres_indc", pres23, "þ", construct_cons_stem_ending)
	add_ending(args, "pl_pres_indc", presa, "þ")
	add_ending(args, "sg_pres_subj", prese, "")
	add_ending(args, "pl_pres_subj", prese, "n")
	add_ending(args, "sg_impr", impsg, "")
	add_ending(args, "pl_impr", presa, "þ")
	add_ending(args, "pres_ptc", prese, "nde")
	if with_ge then
		add_ending(args, "past_ptc", pp, "", construct_optional_ge_stem_ending)
	else
		add_ending(args, "past_ptc", pp, "")
	end
end


local function make_strong(presa, prese, pres23, impsg, pastsg, pastpl, pp, with_ge)
	local args = {}
	make_non_past(args, presa, prese, pres23, impsg, pp, with_ge)
	add_ending(args, "1sg_past_indc", pastsg, "")
	add_ending(args, "2sg_past_indc", pastpl, "e")
	add_ending(args, "3sg_past_indc", pastsg, "")
	add_ending(args, "pl_past_indc", pastpl, "on")
	add_ending(args, "sg_past_subj", pastpl, "e")
	add_ending(args, "pl_past_subj", pastpl, "en")
	return args
end

local function make_weak(presa, prese, pres23, impsg, past, pp, with_ge)
	local args = {}
	make_non_past(args, presa, prese, pres23, impsg, pp, with_ge)
	add_ending(args, "1sg_past_indc", past, "e")
	add_ending(args, "2sg_past_indc", past, "est")
	add_ending(args, "3sg_past_indc", past, "e")
	add_ending(args, "pl_past_indc", past, "on")
	add_ending(args, "sg_past_subj", past, "e")
	add_ending(args, "pl_past_subj", past, "en")
	return args
end

local function vernerize_cons(cons, verner)
	if not verner then
		return cons
	end
	if cons == "s" then
		return "r"
	elseif cons == "þ" or cons == "ð" then
		return "d"
	else
		return cons
	end
end

local function depalatalize_final_cons(word)
	if word:find("sċ$") then
		return word
	else
		return rsub(word, "([ċġ])$", { ["ċ"] = "c", ["ġ"] = "g" })
	end
end

local strong_verbs = {}

strong_verbs["1"] = function(data)
	local pref, suf = rmatch(data.inf, "^(.-)ī(" .. cons_c .. "+)an$")
	if pref then
		-- bīdan "await", ācwīnan "dwindle away", blīcan "shine", sċīnan "shine",
		-- spīwan "spew, spit", etc.
		data.pres23 = gsub(data.presa, "a$", "")
		data.impsg = data.pres23
		-- ġīnan "yawn" (gān, ġinon, ġinen)
		data.pastsg = depalatalize_final_cons(pref) .. "ā" .. suf
		-- snīþan "cut" -> snidon; sċrīþan "go, proceed" -> sċridon
		-- (but not mīþan "avoid", wrīþan "twist")
		data.pastpl = pref .. "i" .. vernerize_cons(suf, data.verner)
		-- stīgan "ascend" (stāg/stāh, stigon, stiġen) [stāg/stāh altenation handled
		-- by default_construct_stem_ending]
		data.pp = gsub(data.pastpl, "ig$", "iġ") .. "en"
		return
	end
	pref = rmatch(data.inf, "^(.-)[ēī]on$")
	if pref then
		-- tēon/tīon "accuse" < *tīhanan, similarly lēon "lend", sēon "strain",
		-- þēon "thrive" < *þinhanan (originally strong 3), wrēon.
		-- Beware of homonyms e.g. tēon "pull, draw" (strong 2) < *teuhanan,
		-- tēon "make, create" (weak) ?< *tīhan (strong);
		-- þēon/þēowan/þȳ(g)(a)n "press" (weak) < *þunhijanan;
		-- sēon "see" (strong 5) < *sehwanan
		data.pres23 = pref .. "īeh"
		data.impsg = gsub(data.inf, "n$", "h")
		data.pastsg = pref .. "āh"
		data.pastpl = pref .. "ig"
		data.pp = pref .. "iġen"
		return
	end
end

strong_verbs["2"] = function(data)
	local pref, suf = rmatch(data.inf, "^(.-)ēo(" .. cons_c .. "+)an$")
	if pref then
		-- bēodan "command", crēopan "creep", rēocan "smoke, reek",
		-- drēogan "endure" (drēag/drēah handled by default_construct_stem_ending)
		data.pres23 = pref .. "īe" .. suf
		data.impsg = pref .. "ēo" .. suf
		data.pastsg = pref .. "ēa" .. suf
		-- ġēotan "pour" (ġēat, guton, goten); ċēosan "choose" (ċēas, curon, coren)
		local pastpref = depalatalize_final_cons(pref)
		-- ċēosan "choose" -> curon; forlēosan "lose" -> forluron; sēoþan "boil" -> sudon
		-- (but not ābrēoþan "perish, ruin")
		local pastsuf = vernerize_cons(suf, data.verner)
		data.pastpl = pastpref .. "u" .. pastsuf
		data.pp = pastpref .. "o" .. pastsuf .. "en"
		return
	end
	pref, suf = rmatch(data.inf, "^(.-)ū(" .. cons_c .. "+)an$")
	if pref then
		-- brūcan "use", sċūfan "shove", būgan "bend" (bēag/bēah handled by
		-- default_construct_stem_ending)
		data.pres23 = pref .. "ȳ" .. suf
		data.impsg = pref .. "ū" .. suf
		-- could have palatalization here, but no known examples
		data.pastsg = pref .. "ēa" .. suf
		-- no known examples of Vernerization, but just in case
		local pastsuf = vernerize_cons(suf, data.verner)
		data.pastpl = pref .. "u" .. pastsuf
		data.pp = pref .. "o" .. pastsuf .. "en"
		return
	end
	pref = rmatch(data.inf, "^(.-)ēon$")
	if pref then
		-- tēon "pull, draw" < *teuhanan, flēon "flee"
		-- Beware of homonyms, e.g. tēon/tīon "accuse" (strong 1) < *tīhanan,
		-- tēon "make, create" (weak) ?< *tīhan (strong)
		data.pres23 = pref .. "īeh"
		data.impsg = gsub(data.inf, "n$", "h")
		data.pastsg = pref .. "ēah"
		-- no examples where depalatalization is needed
		data.pastpl = pref .. "ug"
		data.pp = pref .. "ogen"
		return
	end
end

strong_verbs["3"] = function(data)
	local pref, suf = rmatch(data.inf, "^(.-)i([mn]" .. cons_c .. "+)an$")
	if pref then
		-- bindan "bind", ācwincan "vanish", climban "climb", ġelimpan "happen",
		-- winnan "win", sincan "sink", swimman "swim", etc.
		data.pres23 = pref .. "i" .. suf
		data.impsg = data.pres23
		-- onġinnan (ongann, ongunnon, ongunnen)
		local pastpref = depalatalize_final_cons(pref)
		-- no Verner alternation here; expected #fīþan, #fōþ, #fundon <
		-- *finþanan, *fanþ, *fundund regularized into findan, fand, fundon
		data.pastsg = pastpref .. "a" .. suf
		data.pastpl = pastpref .. "u" .. suf
		data.pp = pastpref .. "o" .. pastsuf .. "en"
		return
	end
	local vowel
	pref, vowel, suf = rmatch(data.inf, "^(.-)(i?e)(l" .. cons_c .. "+)an$")
	if not pref then
		pref, vowel, suf = rmatch(data.inf, "^(.-)(eo)(" .. cons_c .. "+)an$")
	end
	if pref then
		-- helpan "help" (þū hilpst), belgan "swell with anger" (bealg/bealh handled by
		-- default_construct_stem_ending), bellan "bellow", beteldan "cover",
		-- delfan "dig", sweltan "die", etc.
		--
		-- ġieldan "yield, pay" (þū ġiel(t)st, hē ġieldeþ/ġielt, ġeald, guldon, golden),
		-- ġiellan "yell", ġielpan "boast"
		--
		-- weorpan "throw" (þū wierpst), āseolcan "languish", beorgan "protect" (bearg/bearh
		-- handled by default_construct_stem_ending), feohtan "fight", sċeorfan "gnaw"
		data.pres23 = pref .. (vowel == "e" and "i" or "ie") .. suf
		data.impsg = pref .. vowel .. suf
		data.pastsg = pref .. "ea" .. suf
		-- ġieldan etc. (see above)
		local pastpref = depalatalize_final_cons(pref)
		-- weorþan -> wurdon
		local pastsuf = vernerize_cons(suf, data.verner)
		data.pastpl = pastpref .. "u" .. pastsuf
		data.pp = pastpref .. "o" .. pastsuf .. "en"
		return
	end
	pref = rmatch(data.inf, "^(.-)eġdan$")
	if pref then
		-- breġdan "brandish" (þū breġdest, hē breġdeþ, bræġd/brǣd, brugdon, brogden)
		-- streġdan "strew" (like breġdan)
		data.pres23 = pref .. "eġde"
		data.impsg = pref .. "eġd"
		data.pastsg = {pref .. "æġd", pref .. "ǣd"}
		data.pastpl = pref .. "ugd"
		data.pp = pref .. "ogden"
		return
	end
	pref = rmatch(data.inf, "^(.-)iernan$")
	if pref then
		-- biernan "burn" < *brinnanan (þū biernst, barn/born/bearn, burnon, burnen)
		-- iernan "run" < *rinnan (like biernan)
		data.pres23 = pref .. "iern"
		data.impsg = data.pres23
		data.pastsg = {pref .. "arn", pref .. "orn", pref .. "earn"}
		data.pastpl = pref .. "urn"
		data.pp = pref .. "urnen"
		return
	end
	pref, vowel = rmatch(data.inf, "^(.-)([ou])rnan$")
	if pref then
		-- murnan "mourn" (þū myrnst, mearn, murnon, — but BT documents mornen)
		-- spurnan/spornan "spurn" (þū spyrnst, spearn, spurnon, spornen)
		data.pres23 = pref .. "yrn"
		data.impsg = pref .. vowel .. "rn"
		data.pastsg = pref .. "earn"
		data.pastpl = pref .. "urn"
		data.pp = pref .. "ornen"
		return
	end
	pref, suf = rmatch(data.inf, "^(.-)e(r" .. cons_c .. "+)an$")
	if pref then
		-- berstan "burst" < *brestanan (þū birst, hē birsteþ/birst, bærst, burston, borsten)
		-- þersċan "thrash, thresh" < *þreskanan (þū þirsċst, hē þirsċeþ, þærsċ, þursċon, þorsċen)
		data.pres23 = pref .. "i" .. suf
		data.impsg = pref .. "e" .. suf
		data.pastsg = pref .. "æ" .. suf
		data.pastpl = pref .. "u" .. suf
		data.pp = pref .. "o" .. suf .. "en"
		return
	end
	-- We treat the following as irregular, requiring that the stems be explicitly specified:
	--
	-- friġnan "ask" (þū friġnest, hē friġneþ, fræġn, frugnon, frugnen)
	-- fēolan "enter, penetrate" < *felhanan (fealh, fulgon/fǣlon/fūlon, folgen/fōlen)
end

strong_verbs["4"] = function(data)
	local pref, suf = rmatch(data.inf, "^(.-)ie(" .. cons_c .. ")an$")
	if pref then
		-- sċieran "shear"
		data.pres23 = pref .. "ie" .. suf
		data.impsg = data.pres23
		-- no Verner alternation or depalatalization here
		data.pastsg = pref .. "ea" .. suf
		data.pastpl = pref .. "ēa" .. suf
		data.pp = pref .. "o" .. suf .. "en"
		return
	end
	local pref, suf = rmatch(data.inf, "^(.-)e(" .. cons_c .. ")an$")
	if pref then
		-- beran "bear, carry", cwelan "die", brecan "break", etc.
		data.pres23 = pref .. "i" .. suf
		data.impsg = pref .. "e" .. suf
		-- no Verner alternation or depalatalization here
		data.pastsg = pref .. "æ" .. suf
		data.pastpl = pref .. "ǣ" .. suf
		data.pp = pref .. "o" .. suf .. "en"
		return
	end
	-- Next two are irregular but occur with so many prefixes that we special-case them here.
	local pref = rmatch(data.inf, "^(.-)cuman$")
	if pref then
		-- cuman "come"
		data.pres23 = pref .. "cym"
		data.impsg = pref .. "cum"
		data.pastsg = {pref .. "cōm", pref .. "cwōm"}
		data.pastpl = data.pastsg
		data.pp = {pref .. "cumen", pref .. "cymen"}
		return
	end
	local pref = rmatch(data.inf, "^(.-)niman$")
	if pref then
		-- niman "take"
		data.pres23 = pref .. "nim"
		data.impsg = data.pres23
		data.pastsg = pref .. "nōm"
		data.pastpl = data.pastsg
		data.pp = pref .. "numen"
		return
	end
end

strong_verbs["5"] = function(data)
	local pref, suf = rmatch(data.inf, "^(.-)ie(" .. cons_c .. ")an$")
	if pref then
		-- ġiefan "give", forġietan "forget"
		data.pres23 = pref .. "ie" .. suf
		data.impsg = data.pres23
		data.pastsg = pref .. "ea" .. suf
		data.pastpl = pref .. "ēa" .. suf
		data.pp = pref .. "e" .. suf .. "en"
		return
	end
	local pref, suf = rmatch(data.inf, "^(.-)e(" .. cons_c .. ")an$")
	if suf == "g" then
		-- wegan "carry"; special-case
		data.pres23 = pref .. "iġ"
		data.impsg = pref .. "eġ"
		data.pastsg = pref .. "æġ"
		data.pastpl = {pref .. "ǣg", pref .. "āg"}
		data.pp = pref .. "eġen"
		return
	elseif pref then
		-- metan "measure", sprecan "speak", cnedan "knead", wefan "weave", etc.
		data.pres23 = pref .. "i" .. suf
		data.impsg = pref .. "e" .. suf
		data.pastsg = pref .. "æ" .. suf
		-- cweþan "say" -> cwǣdon, wesan "be" -> wǣron
		-- (but not ġenesan "be saved", lesan "collect, gather")
		local pastsuf = vernerize_cons(suf, data.verner)
		data.pastpl = pref .. "ǣ" .. pastsuf
		if data.inf:find("drepan$") then
			-- Special-case drepan "strike, slay"; Wright lists brecan here with
			-- pp only brocen, but that just makes it a strong-4 verb and that's
			-- where it's normally listed in dictionaries
			data.pp = {pref .. "drepen", pref .. "dropen"}
		else
			data.pp = pref .. "e" .. pastsuf .. "en"
		end
		return
	end
	local pref, suf = rmatch(data.inf, "^(.-)i(" .. cons_c .. cons_c .. ")an$")
	if pref then
		-- biddan "pray", liċġan "lie down", sittan "sit", þiċġan "receive" (in poetry),
		-- friċġan "ask, inquire".
		data.pres23 = pref .. "īeh"
		data.impsg = gsub(data.inf, "n$", "h")
		data.pastsg = pref .. "āh"
		data.pastpl = pref .. "ig"
		data.pp = pref .. "iġen"
		return
	end
end

function export.show(frame)
	local parent_args = frame:getParent().args
	local params = {
		[1] = {required = true, list = true, default = "beran<s4>"},
	}
	for slot, _ in pairs(slots_and_accel) do
		params[slot] = {}
	end
	local args = require("Module:parameters").process(parent_args, params)
	local allforms
	for _, infspec in ipairs(args[1]) do
		local inf, spec = rmatch(infspec, "^(.-)<(.*)>$")
		if not inf then
			error("Verb spec should look like e.g. 'beran<s4>' or 'dēman<w1>': " .. infspec)
		end
		local specs = rsplit(spec, "/")
		local typ = specs[1]
		local verner = rfind(typ, "v")
		typ = gsub(typ, "v", "")
		local presa = gsub(inf, "n$", "")
		data = {
			inf = inf,
			presa = presa,
			prese = gsub(presa, "a$", "e"),
			verner = verner,
		}
		local verbtype
		if typ:find("^s") then
			verbtype = "strong"
			typ = gsub(typ, "^s", "")
			if strong_verbs[typ] then
				strong_verbs[typ](data)
			else
				error("Unrecognized strong class type: " .. typ)
			end
		elseif typ:find("^w") then
			verbtype = "weak"
			typ = gsub(typ, "^w", "")
			if weak_verbs[typ] then
				weak_verbs[typ](data)
			else
				error("Unrecognized weak class type: " .. typ)
			end
		else
			error("Unrecognized verb class type: " .. typ)
		end

		local overrides = {}
		for i, spec in ipairs(specs) do
			if i > 1 then
				local parts = rsplit(spec, ":")
				if #parts ~= 2 then
					error("Verb modified spec must be of the form 'KEY:VALUE': " .. spec)
				end
				local k = parts[1]
				local v = parts[2]
				if k == "pres" then
					data.presa = v
					data.prese = v
					data.pres23 = v
					data.impsg = v
				elseif k == "pres1456" then
					data.presa = v
					data.prese = v
				elseif k == "pres23" then
					data.pres23 = v
				elseif k == "presa" then
					data.presa = v
				elseif k == "prese" then
					data.prese = v
				elseif verbtype == "strong" and k == "past" then
					data.pastsg = v
					data.pastpl = v
				elseif verbtype == "weak" and k == "past" then
					data.past = v
				elseif verbtype == "strong" and k == "pastsg" then
					data.pastsg = v
				elseif verbtype == "strong" and k == "pastpl" then
					data.pastpl = v
				elseif k == "impsg" then
					data.impsg = v
				elseif k == "pp" then
					data.pp = v
				elseif k == "ge" then
					data.with_ge = require("Module:yesno")(v)
				elseif slots_and_accel[k] then
					overrides[k] = v
				else
					error("Unrecognized spec key '" .. k .. "' (value '" .. v .. "')")
				end
			end
		end

		local missing_fields = {}
		local fields_to_check =
			verbtype == "weak" and {"presa", "prese", "pres23", "impsg", "past", "pp"} or
			{"presa", "prese", "pres23", "impsg", "pastsg", "pastpl", "pp"}
		for _, field in ipairs(fields_to_check) do
			if not data[field] then
				table.insert(missing_fields, field)
			end
		end
		if #missing_fields > 0 then
			error("Required spec(s) " .. table.concat(missing_fields, ",") ..
				" missing, i.e. the form of the infinitive '" .. inf ..
				"' was not recognized as a " .. verbtype .. " type-" .. typ .. " verb and the " ..
				"overrriding specs weren't (all) supplied")
		end
		local forms
		if verbtype == "strong" then
			forms = make_strong(data.presa, data.prese, data.pres23, data.impsg, data.pastsg,
				data.pastpl, data.pp, data.with_ge)
		elseif verbtype == "weak" then
			forms = make_weak(data.presa, data.prese, data.pres23, data.impsg, data.past,
				data.pp, data.with_ge)
		else
			error("Internal error: Unrecognized verb type: " .. verbtype)
		end
		for k, v in pairs(overrides) do
			forms[k] = rsplit(v, ", *")
		end
		if not allforms then
			allforms = forms
		else
			for k, v in pairs(forms) do
				for _, form in ipairs(v) do
					ut.insert_if_not(allforms[k], form)
				end
			end
		end
	end
	return make_table(allforms)
end

function export.weak(frame)
	local parent_args = frame:getParent().args
	local params = {
		[1] = {required = true, default = "dēman"},
		[2] = {required = true, default = "1"},
	}
	for slot, _ in pairs(slots_and_accel) do
		params[slot] = {}
	end
	local args = require("Module:parameters").process(parent_args, params)
	local inf = args[1]
	local weaktype = args[2]
	if weaktype == "1" then
		if rfind(inf, "ian$") then
			weaktype = "1a"
		elseif rfind(inf, "(" .. non_vowel_c .. ")%1an$") or rfind(inf, "cgan$") or rfind(inf, "ċġan$") then
			local prev = rmatch(inf, "^(.-)....$")
			if rfind(prev, vowel_c .. "$") and not ends_in_long_vowel(prev) then
				weaktype = "1a"
			else
				weaktype = "1b"
			end
		else
			weaktype = "1b"
		end
	end

	local conjargs
	local presa = gsub(inf, "n$", "")
	local prese = gsub(presa, "a$", "e")
	local pres23, impsg, past, pp
	if weaktype == "1a" then
		if inf:find("ian$") then
			pres23 = gsub(inf, "ian$", "e")
			impsg = pres23
			past = pres23 .. "d"
			pp = past
		elseif inf:find("([dt])%1an$") then
			pres23 = gsub(inf, "...$", "")
			impsg = pres23 .. "e"
			past = gsub(inf, "..$", "")
			pp = {pres23 .. "ed", past, pres23}
		elseif inf:find("ċġe?an$") then
			pres23 = gsub(inf, "ċġe?an$", "ġ")
			impsg = pres23 .. "e"
			past = pres23 .. "d"
			pp = {pres23 .. "ed", past}
		elseif rfind(inf, "(.)%1an$") then
			pres23 = rsub(inf, "...$", "") .. "e"
			impsg = pres23
			past = pres23 .. "d"
			pp = past
		else
			error("Unrecognized infinitive for weak class 1a verb: " .. inf)
		end
	elseif weaktype == "1b" then
		if inf:find("[rl]wan$") then
			-- ġierwan, hierwan, nierwan, sierwan, smierwan, wielwan (?)
			pres23 = gsub(inf, "wan$", "e")
			impsg = pres23
			past = pres23 .. "d"
			pp = {gsub(inf, "an$", ""), pres23 .. "d"}
		elseif rfind(inf, non_vowel_c .. "[rlmnw]an$") and not inf:find("[rl][mn]an$")
			and not inf:find("rlan$") and not rfind(inf, "(" .. non_vowel_c .. ")%1an$") then
			-- hyngran, dīeglan, bīecnan, þrysman, etc.
			pres23 = gsub(inf, "an$", "e")
			impsg = pres23
			past = pres23 .. "d"
			pp = past
		elseif inf:find("ēan$") or rfind(inf, vowel_c .. "n$") and not inf:find("an$") then
			-- contracted verb, e.g. hēan, þēon, tȳn, rȳn, þȳn
			-- FIXME, verify in Campbell that all of the following are correct
			prese = presa
			pres23 = presa
			impsg = presa
			past = presa .. "d"
			pp = past
		elseif inf:find("an$") then
			local stem = rsub(inf, "an$", "")
			pres23 = {stem .. "e", stem}
			impsg = stem
			past = construct_cons_stem_ending(stem, "d")
			pp = stem .. "ed"
		else
			error("Unrecognized infinitive for weak class 1b verb: " .. inf)
		end
	elseif weaktype == "2" then
		if inf:find("ian$") then
			pres23 = gsub(inf, "ian$", "a")
			impsg = pres23
			past = gsub(inf, "ian$", "od")
			pp = past
		elseif inf:find("ġe?an$") then
			-- twēoġan, smēaġ(e)an
			-- If the infinitive was e.g. smēaġean, default pres=smēaġee, which is wrong
			prese = gsub(prese, "ee?$", "e")
			pres23 = gsub(inf, "ġe?an$", "")
			impsg = pres23
			past = pres23 .. "d"
			pp = past
		else
			error("Unrecognized infinitive for weak class 2 verb: " .. inf)
		end
	elseif weaktype == "3" then
		if inf:find("abban$") then
			-- habban, nabban, compounds
			local pref = gsub(inf, "abban$", "")
			prese = pref .. "æbbe"
			pres23 = {pref .. "afa", pref .. "æf"}
			impsg = pref .. "afa"
			past = pref .. "æfd"
			pp = past
		elseif inf:find("libban$") then
			-- libban, compounds
			local pref = gsub(inf, "libban$", "")
			prese = pref .. "libbe"
			pres23 = {pref .. "liofa", pref .. "leofa", pref .. "lifa"}
			impsg = pres23
			past = pref .. "lifd"
			pp = past
		elseif inf:find("seċġe?an$") then
			-- seċġan, compounds
			local pref = gsub(inf, "seċġe?an$", "")
			prese = pref .. "seċġe"
			pres23 = {pref .. "saga", pref .. "sæġ"}
			impsg = {pref .. "saga", pref .. "sæġe"}
			past = pref .. "sæġd"
			pp = past
		elseif inf:find("hyċġe?an$") then
			-- hyċġan, compounds
			local pref = gsub(inf, "hyċġe?an$", "")
			prese = pref .. "hyċġe"
			pres23 = {pref .. "hoga", pref .. "hyġ", pref .. "hyġe"}
			impsg = {pref .. "hoga", pref .. "hyġe"}
			past = pref .. "hogd"
			pp = pref .. "hogod"
		else
			error("Unrecognized infinitive for weak class 3 verb: " .. inf)
		end
	else
		error("Unrecognized weak verb type: " .. weaktype)
	end

	conjargs = make_weak(presa, prese, pres23, impsg, past, pp, with_ge)
	return make_table(conjargs)
end

return export
