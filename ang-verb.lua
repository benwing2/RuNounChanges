local m_links = require("Module:links")
local m_utilities = require("Module:utilities")
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

local params_to_slots = {
	[1] = "infinitive",
	[2] = "infinitive2",
	[3] = "1sg_pres_indc",
	[4] = "2sg_pres_indc",
	[5] = "3sg_pres_indc",
	[6] = "pl_pres_indc",
	[7] = "sg_pres_subj",
	[8] = "pl_pres_subj",
	[9] = "1sg_past_indc",
	[10] = "2sg_past_indc",
	[11] = "3sg_past_indc",
	[12] = "pl_past_indc",
	[13] = "sg_past_subj",
	[14] = "pl_past_subj",
	[15] = "sg_impr",
	[16] = "pl_impr",
	[17] = "pres_ptc",
	[18] = "past_ptc",
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

local function make_table(forms)
	local title = forms.title
	local accel_lemma = m_links.remove_links(forms.infinitive[1] or mw.title.getCurrentTitle().text)
	local function typetext()
		local typ = forms["type"]
		local class = forms["class"]
		if typ == "strong" then
			return "[[Appendix:Old English verbs|strong" .. (class and " class " .. class or "") .. "]]"
		elseif typ == "weak" then
			return "[[Appendix:Old English verbs|weak" .. (class and " class " .. class or "") .. "]]"
		elseif typ == "pretpres" then
			return "[[Appendix:Old English verbs|preterite-present]]"
		elseif typ == "irreg" or typ == "anomalous" then
			return "[[Appendix:Old English verbs|irregular]]"
		else
			error("Unrecognized verb type: " .. typ)
		end
	end
	if not title then
		title = "Conjugation of " .. m_links.full_link({lang = lang, alt = accel_lemma}, "term")
		if forms["type"] then
			title = title .. "&nbsp;(" .. typetext() .. ")"
		end
	end
	local table_args = {
		title = title,
		style = forms.style == "right" and "float:right; clear:right;" or "",
		width = forms.width or "30",
	}
	for slot, accel_form in pairs(slots_and_accel) do
		local table_arg = {}
		local slotforms = forms[slot] and #forms[slot] > 0 and forms[slot] or {"—"}
		for _, form in ipairs(slotforms) do
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
				return gsub(stem, "s[dt]$", "st")
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

local function add_form_to_slot(args, slot, form)
	if not args[slot] then
		args[slot] = {}
	end
	if type(form) == "string" then
		ut.insert_if_not(args[slot], form)
	else
		for _, f in ipairs(form) do
			ut.insert_if_not(args[slot], f)
		end
	end
end

local function add_ending_with_prefix(args, slot, pref, stems, ending, construct_stem_ending)
	construct_stem_ending = construct_stem_ending or default_construct_stem_ending
	if type(stems) ~= "table" then
		stems = {stems}
	end
	for _, stem in ipairs(stems) do
		local form = construct_stem_ending(pref and pref .. stem or stem, ending)
		add_form_to_slot(args, slot, form)
	end
end

local function add_ending(args, slot, stems, ending, construct_stem_ending)
	add_ending_with_prefix(args, slot, nil, stems, ending, construct_stem_ending)
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

local function make_strong_past(args, pref, pastsg, pastpl)
	add_ending(args, "1sg_past_indc", pref, pastsg, "")
	add_ending(args, "2sg_past_indc", pref, pastpl, "e")
	add_ending(args, "3sg_past_indc", pref, pastsg, "")
	add_ending(args, "pl_past_indc", pref, pastpl, "on")
	add_ending(args, "sg_past_subj", pref, pastpl, "e")
	add_ending(args, "pl_past_subj", pref, pastpl, "en")
end

local function make_strong(presa, prese, pres23, impsg, pastsg, pastpl, pp, with_ge)
	local args = {}
	make_non_past(args, presa, prese, pres23, impsg, pp, with_ge)
	make_strong_past(args, nil, pastsg, pastpl)
	return args
end

local function make_weak_past(args, pref, past)
	add_ending_with_prefix(args, "1sg_past_indc", pref, past, "e")
	add_ending_with_prefix(args, "2sg_past_indc", pref, past, "est")
	add_ending_with_prefix(args, "3sg_past_indc", pref, past, "e")
	add_ending_with_prefix(args, "pl_past_indc", pref, past, "on")
	add_ending_with_prefix(args, "sg_past_subj", pref, past, "e")
	add_ending_with_prefix(args, "pl_past_subj", pref, past, "en")
end

local function make_weak(presa, prese, pres23, impsg, past, pp, with_ge)
	local args = {}
	make_non_past(args, presa, prese, pres23, impsg, pp, with_ge)
	make_weak_past(args, nil, past)
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
		if suf == "g" then
			-- stīgan "ascend" (stāg/stāh, stigon, stiġen) [stāg/stāh altenation handled
			-- by default_construct_stem_ending]
			data.impsg = pref .. "īġ"
		else
			data.impsg = data.pres23
		end
		-- ġīnan "yawn" (gān, ġinon, ġinen)
		data.pastsg = depalatalize_final_cons(pref) .. "ā" .. suf
		-- snīþan "cut" -> snidon; sċrīþan "go, proceed" -> sċridon
		-- (but not mīþan "avoid", wrīþan "twist")
		data.pastpl = pref .. "i" .. vernerize_cons(suf, data.verner)
		if suf == "g" then
			data.pp = pref .. "iġen"
		else
			data.pp = data.pastpl .. "en"
		end
		return
	end
	pref = rmatch(data.inf, "^(.-)[ēī]on$")
	if pref then
		-- tēon/tīon "accuse" < *tīhanan, similarly lēon "lend" < *līhwanan,
		-- sēon "strain" < *sīhwanan, þēon "thrive" < *þinhanan (originally strong 3),
		-- wrēon < *wrīhanan. Beware of homonyms e.g. tēon "pull, draw" (strong 2) < *teuhanan,
		-- tēon "make, create" (weak) ?< *tīhanan (strong);
		-- þēon/þēowan/þȳ(g)(a)n "press" (weak) < *þunhijanan;
		-- sēon "see" (strong 5) < *sehwanan
		data.pres23 = pref .. "īeh"
		data.impsg = gsub(data.inf, "n$", "h")
		data.pastsg = pref .. "āh"
		if pref:find("[þð]$") then
			-- þēon "thrive", has remnant strong 3 parts
			data.pastpl = {"ig", "ung"}
			data.pp = {"iġen", "ungen"}
		else
			data.pastpl = pref .. "ig"
			if pref:find("s$") then
				-- sēon "strain" alt past part siwen
				data.pp = {pref .. "iġen", pref .. "iwen"}
			else
				data.pp = pref .. "iġen"
			end
		end
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
	local pref, suf = rmatch(data.inf, "^(.-)ū(" .. cons_c .. "+)an$")
	if pref then
		-- brūcan "use", sċūfan "shove"
		if suf == "g" then
			-- būgan "bend" (bēag/bēah handled by default_construct_stem_ending)
			data.pres23 = pref .. "ȳġ"
		else
			data.pres23 = pref .. "ȳ" .. suf
		end
		data.impsg = pref .. "ū" .. suf
		-- could have palatalization here, but no known examples
		data.pastsg = pref .. "ēa" .. suf
		-- no known examples of Vernerization, but just in case
		local pastsuf = vernerize_cons(suf, data.verner)
		data.pastpl = pref .. "u" .. pastsuf
		data.pp = pref .. "o" .. pastsuf .. "en"
		return
	end
	local pref = rmatch(data.inf, "^(.-)ēon$")
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
		-- onġinnan "begin" (ongann, ongunnon, ongunnen), ċimban "join"
		local pastpref = depalatalize_final_cons(pref)
		-- no Verner alternation here; expected #fīþan, #fōþ, #fundon <
		-- *finþanan, *fanþ, *fundund regularized into findan, fand, fundon
		data.pastsg = pastpref .. "a" .. suf
		data.pastpl = pastpref .. "u" .. suf
		data.pp = pastpref .. "o" .. pastsuf .. "en"
		return
	end
	local pref, vowel, suf = rmatch(data.inf, "^(.-)(i?e)(l" .. cons_c .. "+)an$")
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
	local pref = rmatch(data.inf, "^(.-)eġdan$")
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
	local pref, suf = rmatch(data.inf, "^(.-)(ie?rn)an$")
	if pref then
		-- biernan/birnan "burn" < *brinnanan (þū biernst, barn/born/bearn, burnon, burnen)
		-- iernan/irnan "run" < *rinnan (like biernan)
		data.pres23 = pref .. suf
		data.impsg = data.pres23
		data.pastsg = {pref .. "arn", pref .. "orn", pref .. "earn"}
		data.pastpl = pref .. "urn"
		data.pp = pref .. "urnen"
		return
	end
	local pref, vowel = rmatch(data.inf, "^(.-)([ou])rnan$")
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
	local pref, suf = rmatch(data.inf, "^(.-)e(r" .. cons_c .. "+)an$")
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
	local pref = rmatch(data.inf, "^(.-)friġnan$")
	if pref then
		-- friġnan "ask"
		data.pres23 = pref .. "friġne"
		data.impsg = pref .. "friġn"
		data.pastsg = pref .. "fræġn"
		data.pastpl = pref .. "frugn"
		data.pp = pref .. "frugnen"
		return
	end
	local pref = rmatch(data.inf, "^(.-)fēolan$")
	if pref then
		-- fēolan "enter, penetrate"
		data.pres23 = {pref .. "fielh", pref .. "filh"}
		data.impsg = pref .. "feolh"
		data.pastsg = pref .. "fealh"
		data.pastpl = {pref .. "fǣl", pref .. "fulg", pref .. "fūl"}
		data.pp = {pref .. "folgen", pref .. "fōlen"}
		return
	end
end

strong_verbs["4"] = function(data)
	local pref, suf = rmatch(data.inf, "^(.-)ie(" .. cons_c .. ")an$")
	if pref then
		-- sċieran "shear"
		data.pres23 = {pref .. "ie" .. suf .. "e", pref .. "ie" .. suf}
		data.impsg = pref .. "ie" .. suf
		-- no Verner alternation or depalatalization here
		data.pastsg = pref .. "ea" .. suf
		data.pastpl = pref .. "ēa" .. suf
		data.pp = pref .. "o" .. suf .. "en"
		return
	end
	local pref, suf = rmatch(data.inf, "^(.-)e(" .. cons_c .. ")an$")
	if pref then
		-- beran "bear, carry", cwelan "die", brecan "break", etc.
		if suf == "r" or suf == "l" then
			data.pres23 = {pref .. "i" .. suf .. "e", pref .. "i" .. suf}
		else
			data.pres23 = pref .. "i" .. suf
		end
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
		data.pres23 = {pref .. "cyme", pref .. "cym"}
		data.impsg = pref .. "cum"
		data.pastsg = {pref .. "cōm", pref .. "cwōm"}
		data.pastpl = data.pastsg
		data.pp = {pref .. "cumen", pref .. "cymen"}
		return
	end
	local pref = rmatch(data.inf, "^(.-)niman$")
	if pref then
		-- niman "take"
		data.pres23 = {pref .. "nime", pref .. "nim"}
		data.impsg = pref .. "nim"
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
		if suf == "t" and not pref:find("m$") and not pref:find("ġ$") then
			-- etan "eat", fretan "devour", compounds; exclude metan "measure",
			-- ġetan (potential variant of ġietan)
			data.pastsg = pref .. "ǣ" .. suf
		else
			data.pastsg = pref .. "æ" .. suf
		end
		-- cweþan "say" -> cwǣdon, wesan "be" -> wǣron
		-- (but not ġenesan "be saved", lesan "collect, gather")
		local pastsuf = vernerize_cons(suf, data.verner)
		data.pastpl = pref .. "ǣ" .. pastsuf
		if data.inf:find("drepan$") then
			-- Special-case drepan "strike, slay"; Wright lists brecan here with
			-- pp only brocen, but that just makes it a strong-4 verb and that's
			-- where it's normally listed in dictionaries
			data.pp = {pref .. "epen", pref .. "open"}
		else
			data.pp = pref .. "e" .. pastsuf .. "en"
		end
		return
	end
	local pref, last_cons = rmatch(data.inf, "^(.-)i([dt])%2an$")
	if pref then
		-- biddan "pray", sittan "sit"
		data.pres23 = pref .. "i" .. last_cons
		data.impsg = data.pres23 .. "e"
		data.pastsg = pref .. "æ" .. last_cons
		data.pastpl = pref .. "ǣ" .. last_cons
		data.pp = pref .. "e" .. last_cons .. "en"
		return
	end
	local pref = rmatch(data.inf, "^(.-)iċġe?an$")
	if pref then
		-- liċġan "lie down", þiċġan "receive", friċġan "ask, inquire"
		-- If the infinitive was e.g. liċġean, default prese=liċġee, which is wrong
		data.prese = pref .. "iċġe"
		data.pres23 = pref .. "iġ"
		data.impsg = data.pres23 .. "e"
		if data.inf:find("þiċġe?an$") then
			data.pastsg = {pref .. "eah", pref .. "ah"}
		else
			data.pastsg = pref .. "æġ"
		end
		data.pastpl = {pref .. "ǣg", pref .. "āg"}
		if data.inf:find("friċġe?an$") then
			data.pp = {pref .. "iġen", pref .. "ugen"}
		else
			data.pp = pref .. "eġen"
		return
	end
	local pref = rmatch(data.inf, "^(.-)ēon$")
	if pref then
		-- sēon "see" < *sehwanan, ġefēon "rejoice" < *gafehanan, plēon "risk" < *plehanan
		data.pres23 = pref .. "ieh"
		data.impsg = pref .. "eoh"
		data.pastsg = pref .. "eah"
		if pref:find("s$") then
			-- sēon "see"
			data.pastpl = {pref .. "āw", pref .. "ǣg"}
			data.pp = {pref .. "ewen", pref .. "awen", pref .. "eġen"}
		else
			data.pastpl = pref .. "ǣg"
			data.pp = pref .. "eġen"
		end
		return
	end
end

strong_verbs["6"] = function(data)
	local pref, suf = rmatch(data.inf, "^(.-)ea(" .. cons_c .. "+)an$")
	if pref then
		-- sċ(e)acan "shake", sċ(e)afan "shave, scrape"
		data.pres23 = pref .. "ea" .. suf
		data.impsg = {pref .. "a" .. suf, data.pres23}
		data.pastsg = {pref .. "ō" .. suf, pref .. "eō" .. suf}
		data.pastpl = data.pastsg
		data.pp = {pref .. "a" .. suf .. "en", pref .. "ea" .. suf .. "en"}
		return
	end
	local pref, vowel, suf = rmatch(data.inf, "^(.-)(a)(" .. cons_c .. "+)an$")
	if not pref then
		pref, vowel, suf = rmatch(data.inf, "^(.-)(o)(n" .. cons_c .. "*)an$")
	end
	if suf == "g" then
		-- gnagan "gnaw", dragan "draw"
		data.pres23 = pref .. "æġ"
		data.impsg = pref .. "ag"
		data.pastsg = pref .. "ōg"
		data.pastpl = data.pastsg
		data.pp = {pref .. "æġen", pref .. "agen"}
		return
	elseif suf == "nd" and pref:find("st$") then
		-- standan/stondan "stand"
		data.pres23 = pref .. "end"
		data.impsg = pref .. vowel .. "nd"
		data.pastsg = pref .. "ōd"
		data.pastpl = data.pastsg
		data.pp = pref .. vowel .. "nden"
	elseif suf == "n" and pref:find("sp$") then
		-- spanon/sponan "allure"
		data.pres23 = {pref .. "ene", pref .. "en"}
		data.impsg = pref .. vowel .. "n"
		data.pastsg = {pref .. "ōn", pref .. "ēon"} -- has alt class VII past
		data.pastpl = data.pastsg
		data.pp = pref .. vowel .. "nen"
	elseif pref then
		-- faran "go", alan "grow", bacan "bake", hladan "lade", wasċan "wash", etc.
		if suf == "r" or suf == "l" then
			data.pres23 = {pref .. "æ" .. suf .. "e", pref .. "æ" .. suf}
		else
			data.pres23 = pref .. "æ" .. suf
		end
		data.impsg = pref .. "a" .. suf
		data.pastsg = pref .. "ō" .. suf
		-- Apparently no Verner variation here
		data.pastpl = data.pastsg
		data.pp = {pref .. "æ" .. suf .. "en", pref .. "a" .. suf .. "en"}
		end
		return
	end
	local pref = rmatch(data.inf, "^(.-)ēan$")
	if pref then
		-- slēan "strike", flēan "flay", lēan "blame", þwēan "wash"
		data.prese = pref .. "ēa"
		data.pres23 = pref .. "ieh"
		data.impsg = pref .. "eah"
		data.pastsg = pref .. "ōg" -- also slōh etc., which will get automatically added
		data.pastpl = data.pastsg
		data.pp = {pref .. "æġen", pref .. "agen", pref .. "eġen"}
		return
	end
	local pref, last_cons = rmatch(data.inf, "^(.-)i([dt])%2an$")
	-- All the j-present verbs have to be handled individually as each has
	-- idiosyncrasies.
	local pref, last_cons = rmatch(data.inf, "^(.-)hebban$")
	if pref then
		-- hebban "raise"
		data.pres23 = pref .. "hefe"
		data.impsg = data.pres23
		data.pastsg = pref .. "hōf"
		data.pastpl = data.pastsg
		data.pp = {pref .. "hæfen", pref .. "hafen", pref .. "hefen"}
		return
	end
	local pref, vowel = rmatch(data.inf, "^(.-)hl([iy]?e?)hhan$")
	if pref then
		-- hliehhan "laugh"
		data.pres23 = pref .. "hl" .. vowel .. "he"
		data.impsg = data.pres23
		data.pastsg = pref .. "hlōg"
		data.pastpl = data.pastsg
		-- The basic verb doesn't seem to have a past part, but compounds
		-- āhliehhan and behliehhan do.
		data.pp = {pref .. "hleahen", pref .. "hlahen"}
		return
	end
	local pref, cons = rmatch(data.inf, "^(.-)sċe([þð])%2an$")
	if pref then
		-- sċeþþan "injure" (for some reason, expected #sċieþþan doesn't occur)
		data.pres23 = pref .. "sċe" .. cons .. "e"
		data.impsg = data.pres23
		data.pastsg = {pref .. "sċōd", pref .. "sċeōd"}
		data.pastpl = data.pastsg
		-- No past part listed in Wright and none I can find in Bosworth-Toller,
		-- either for sċeþþan or ġesċeþþan. Unclear if the past part would be
		-- sċ(e)aþen or sċ(e)aden.
		data.pp = {}
		return
	end
	local pref, vowel = rmatch(data.inf, "^(.-)sċ([iy]?e?)ppan$")
	if pref then
		-- sċieppan "create"
		data.pres23 = pref .. "sċ" .. vowel .. "pe"
		data.impsg = data.pres23
		data.pastsg = {pref .. "sċōp", pref .. "sċeōp"}
		data.pastpl = data.pastsg
		data.pp = {pref .. "sċeapen", pref .. "sċapen"}
		return
	end
	local pref, vowel = rmatch(data.inf, "^(.-)st([æe])ppan$")
	if pref then
		-- stæppan "step, go"
		data.pres23 = pref .. "st" .. vowel .. "pe"
		data.impsg = data.pres23
		data.pastsg = pref .. "stōp"
		data.pastpl = data.pastsg
		data.pp = {pref .. "stæpen", pref .. "stapen"}
		return
	end
	local pref = rmatch(data.inf, "^(.-)swerian$")
	if pref then
		-- swerian "swear"
		data.pres23 = pref .. "swere"
		data.impsg = data.pres23
		data.pastsg = pref .. "swōr"
		data.pastpl = data.pastsg
		data.pp = pref .. "sworen" -- on the analogy of class IV verbs like beran
		return
	end
end

strong_verbs["7"] = function(data)
	-- Type (7a) verbs
	local pref = rmatch(data.inf, "^(.-)hātan$")
	if pref then
		-- hātan "call"
		data.pres23 = pref .. "hǣt"
		data.impsg = pref .. "hāt"
		data.pastsg = {pref .. "hēt", pref .. "hēht"} -- FIXME, indicate latter as poetic
		data.pastpl = data.pastsg
		data.pp = pref .. "hāten"
		return
	end
	local pref = rmatch(data.inf, "^(.-)lācan$")
	if pref then
		-- lācan "play"
		data.pres23 = pref .. "lǣc"
		data.impsg = pref .. "lāc"
		data.pastsg = {pref .. "lēc", pref .. "leolc"} -- FIXME, indicate latter as poetic
		data.pastpl = data.pastsg
		data.pp = pref .. "lācen"
		return
	end
	local pref, vowel = rmatch(data.inf, "^(.-)sċ(e?ā)dan$")
	if pref then
		-- sċ(e)ādan "separate"
		data.pres23 = pref .. "sċēad"
		data.impsg = pref .. "sċ" .. vowel .. "d"
		data.pastsg = {pref .. "sċēd", pref .. "sċēad"}
		data.pastpl = data.pastsg
		data.pp = pref .. "sċ" .. vowel .. "den"
		return
	end
	local pref, vowel = rmatch(data.inf, "^(.-)lǣtan$")
	if pref then
		-- lǣtan "let, allow"
		data.pres23 = pref .. "lǣt"
		data.impsg = pref .. "lǣt"
		data.pastsg = {pref .. "lēt", pref .. "leort"} -- FIXME, indicate latter as poetic
		data.pastpl = data.pastsg
		data.pp = pref .. "lǣten"
		return
	end
	local pref, vowel = rmatch(data.inf, "^(.-)ondrǣdan$")
	if pref then
		-- ondrǣdan "dread, fear"
		data.pres23 = pref .. "ondrǣd"
		data.impsg = pref .. "ondrǣd"
		data.pastsg = {pref .. "ondrēd", pref .. "ondreord"} -- FIXME, indicate latter as poetic
		data.pastpl = data.pastsg
		make_weak_past(data.extraforms, pref, "ondrǣdd")
		data.pp = pref .. "ondrǣden"
		return
	end
	local pref, vowel = rmatch(data.inf, "^(.-)rǣdan$")
	if pref then
		-- rǣdan "advise"
		data.pres23 = pref .. "rǣd"
		data.impsg = pref .. "rǣd"
		-- NOTE: Also (mostly) has weak past rǣdde and pp (ġe)rǣdd; can be handled
		-- by declaring the verb as both weak 1b and strong 7.
		data.pastsg = {pref .. "rēd", pref .. "reord"} -- FIXME, indicate latter as poetic
		data.pastpl = data.pastsg
		data.pp = pref .. "rǣden"
		return
	end
	local pref, vowel = rmatch(data.inf, "^(.-)slǣpan$")
	if pref then
		-- slǣpan "sleep"
		data.pres23 = pref .. "slǣp"
		data.impsg = pref .. "slǣp"
		data.pastsg = pref .. "slēp"
		data.pastpl = data.pastsg
		make_weak_past(data.extraforms, pref, "slǣpt")
		data.pp = pref .. "slǣpen"
		return
	end
	local pref = rmatch(data.inf, "^(.-)blandan$")
	if pref then
		-- blandan "mix"
		data.pres23 = pref .. "blend"
		data.impsg = pref .. "bland"
		data.pastsg = pref .. "blēnd"
		data.pastpl = data.pastsg
		data.pp = pref .. "blanden"
		return
	end
	local pref = rmatch(data.inf, "^(.-)ōn$")
	if pref then
		-- fōn "seize", hōn "hang"
		data.prese = pref .. "ō"
		data.pres23 = pref .. "ēh"
		data.impsg = pref .. "ōh"
		data.pastsg = pref .. "ēng"
		data.pastpl = data.pastsg
		data.pp = {pref .. "angen"}
		return
	end
	-- Type (7b) verbs
	local pref = rmatch(data.inf, "^(.-)annan$")
	if pref then
		-- bannan "summon", spannan "join, clasp"
		data.pres23 = pref .. "enn"
		data.impsg = pref .. "ann"
		data.pastsg = {pref .. "ēonn", pref .. "ēon"}
		data.pastpl = data.pastsg
		data.pp = pref .. "annen"
		return
	end
	local pref = rmatch(data.inf, "^(.-)gangan$")
	if pref then
		-- gangan "go"
		data.pres23 = pref .. "geng"
		data.impsg = pref .. "gang"
		data.pastsg = {pref .. "ġēng", pref .. "ġīeng"}
		data.pastpl = data.pastsg
		data.pp = pref .. "gangen"
		return
	end
	local pref, suf = rmatch(data.inf, "^(.-)ea(" .. cons_c .. "+)an$")
	if pref then
		-- fealdan "fold", feallan "fall", healdan "hold", stealdan "possess",
		-- wealcan "roll", wealdan "rule", weallan "boil", weaxan "grow"
		data.pres23 = pref .. "ie" .. suf
		data.impsg = pref .. "ea" .. suf
		data.pastsg = pref .. "ēo" .. suf
		data.pastpl = data.pastsg
		data.pp = pref .. "ea" .. suf .. "en"
		return
	end
	local pref, suf = rmatch(data.inf, "^(.-)ā(" .. cons_c .. "+)an$")
	if pref then
		-- blāwan "blow", cnāwan "know", crāwan "crow", māwan "mow", sāwan "sow",
		-- swāpan "sweep", þrāwan "turn, twist", wāwan "blow"
		data.pres23 = pref .. "ǣ" .. suf
		data.impsg = pref .. "ā" .. suf
		data.pastsg = pref .. "ēo" .. suf
		data.pastpl = data.pastsg
		data.pp = pref .. "ā" .. suf .. "en"
		return
	end
	local pref, suf = rmatch(data.inf, "^(.-)ēa(" .. cons_c .. "+)an$")
	if pref then
		-- bēatan "beat", āhnēapan "pluck off", hēawan "hew", hlēapan "leap"
		data.pres23 = pref .. "īe" .. suf
		data.impsg = pref .. "ēa" .. suf
		data.pastsg = pref .. "ēo" .. suf
		data.pastpl = data.pastsg
		data.pp = pref .. "ēa" .. suf .. "en"
		return
	end
	local pref, suf = rmatch(data.inf, "^(.-)ō(" .. cons_c .. "+)an$")
	if pref then
		if suf == "g" and pref:find("sw$") then
			-- swōgan "sound"
			data.pres23 = pref .. "ēġ"
			data.impsg = pref .. "ōg"
			data.pastsg = {} -- no preterite
			data.pastpl = {}
			data.pp = pref .. "ōgen"
			return
		end
		if suf == "c" and pref:find("fl$") or suf == "t" and pref:find("wr$") then
			-- flōcan "clap, strike", wrōtan "root up"
			data.pres23 = pref .. "ē" .. suf
			data.impsg = pref .. "ō" .. suf
			data.pastsg = {} -- no preterite
			data.pastpl = {}
			data.pp = pref .. "ō" .. suf .. "en"
			return
		end
		-- blōtan "sacrifice", blōwan "bloom, blossom", hrōpan "shout",
		-- hwōpan "threaten", flōwan "flow", grōwan "grow", hlōwan "low, bellow",
		-- spōwan "succeed"; also rōwan "row", which has alt pret pl rēon
		data.pres23 = pref .. "ē" .. suf
		data.impsg = pref .. "ō" .. suf
		data.pastsg = pref .. "ēo" .. suf
		data.pastpl = data.pastsg
		data.pp = pref .. "ō" .. suf .. "en"
		if suf == "w" and pref:find("r$") and not pref:find("gr$") then
			-- rōwan "row"
			data.extraforms["pl_past_indc"] = {pref .. "ēon"}
		end
		return
	end
	local pref = rmatch(data.inf, "^(.-)wēpan$")
	if pref then
		-- wēpan "weep"; j-present
		data.pres23 = pref .. "wēp"
		data.impsg = pref .. "wēp"
		data.pastsg = pref .. "wēop"
		data.pastpl = data.pastsg
		data.pp = pref .. "wōpen"
		return
	end
end

local weak_verbs = {}

weak_verbs["1a"] = function(data)
	local pref = rmatch(data.inf, "^(.-)ian$")
	if pref then
		data.pres23 = pref .. "e"
		data.impsg = data.pres23
		data.past = data.pres23 .. "d"
		data.pp = data.past
		return
	end
	local pref, last_cons = rmatch(data.inf, "^(.-)([dt])%2an$")
	if pref then
		data.pres23 = pref .. last_cons
		data.impsg = data.pres23 .. "e"
		data.past = data.pres23 .. last_cons
		data.pp = {data.pres23 .. "ed", data.past, data.pres23}
		return
	end
	local pref = rmatch(data.inf, "^(.-)ċġe?an$")
	if pref then
		-- If the infinitive was e.g. leċġean, default prese=leċġee, which is wrong
		data.prese = pref .. "ċġe"
		data.pres23 = pref .. "ġ"
		data.impsg = data.pres23 .. "e"
		data.past = data.pres23 .. "d"
		data.pp = {data.pres23 .. "ed", data.past}
		return
	end
	local pref, last_cons = rmatch(data.inf, "^(.-)(.)%2an$")
	if pref then
		data.pres23 = pref .. last_cons .. "e"
		data.impsg = data.pres23
		data.past = data.pres23 .. "d"
		data.pp = data.past
		return
	end
end

weak_verbs["1b"] = function(data)
	local pref = rmatch(data.inf, "^(.-[rl])wan$")
	if pref then
		-- ġierwan, hierwan, nierwan, sierwan, smierwan, wielwan (?)
		data.pres23 = pref .. "e"
		data.impsg = data.pres23
		data.past = data.pres23 .. "d"
		data.pp = {pref .. "wed", pref .. "ed"}
		return
	end
	local pref = rmatch(data.inf, "^(.-" .. cons_c .. "[rlmnw])an$")
	if pref and not pref:find("[rl][mn]$") and not pref:find("rl$") and not rfind(pref, "(" .. cons_c .. ")%1$") then
		-- hyngran, dīeglan, bīecnan, þrysman, etc.
		data.pres23 = pref .. "e"
		data.impsg = data.pres23
		data.past = data.pres23 .. "d"
		data.pp = data.past
		return
	end
	if data.inf:find("ēan$") or rfind(data.inf, vowel_c .. "n$") and not data.inf:find("an$") then
		-- contracted verb, e.g. hēan, þēon, tȳn, rȳn, þȳn
		-- FIXME, verify in Campbell that all of the following are correct
		data.prese = data.presa
		data.pres23 = data.presa
		data.impsg = data.presa
		data.past = data.presa .. "d"
		data.pp = data.past
		return
	end
	local pref = rmatch(data.inf, "^(.-)an$")
	if pref then
		data.pres23 = {pref .. "e", pref}
		data.impsg = pref
		data.past = construct_cons_stem_ending(pref, "d")
		data.pp = pref .. "ed"
		return
	end
end

weak_verbs["1"] = function(data)
	local weaktype
	if data.inf:find("ian$") then
		weaktype = "1a"
	elseif rfind(data.inf, "(" .. cons_c .. ")%1an$") or data.inf:find("cgan$") or data.inf:find("ċġan$") then
		local prev = rmatch(data.inf, "^(.-)....$")
		if rfind(prev, vowel_c .. "$") and not ends_in_long_vowel(prev) then
			weaktype = "1a"
		else
			weaktype = "1b"
		end
	else
		weaktype = "1b"
	end
	weak_verbs[weaktype](data)
end

weak_verbs["2"] = function(data)
	local pref = rmatch(data.inf, "^(.-)ian$")
	if pref then
		data.pres23 = pref .. "a"
		data.impsg = data.pres23
		data.past = pref .. "od"
		data.pp = data.past
		return
	end
	local pref = rmatch(data.inf, "^(.-)ġe?an$")
	if pref then
		-- twēoġan, smēaġ(e)an
		-- If the infinitive was e.g. smēaġean, default prese=smēaġee, which is wrong
		data.prese = pref .. "ġe"
		data.pres23 = pref
		data.impsg = data.pres23
		data.past = data.pres23 .. "d"
		data.pp = data.past
		return
	end
end

weak_verbs["3"] = function(data)
	local pref = rmatch(data.inf, "^(.-)abban$")
	if pref then
		data.prese = pref .. "æbbe"
		data.pres23 = {pref .. "afa", pref .. "æf"}
		data.impsg = pref .. "afa"
		data.past = pref .. "æfd"
		data.pp = data.past
		return
	end
	local pref = rmatch(data.inf, "^(.-)libban$")
	if pref then
		-- libban, compounds
		data.prese = pref .. "libbe"
		data.pres23 = {pref .. "liofa", pref .. "leofa", pref .. "lifa"}
		data.impsg = data.pres23
		data.past = pref .. "lifd"
		data.pp = data.past
		return
	end
	local pref = rmatch(data.inf, "^(.-)seċġe?an$")
	if pref then
		-- seċġan, compounds
		data.prese = pref .. "seċġe"
		data.pres23 = {pref .. "saga", pref .. "sæġ"}
		data.impsg = {pref .. "saga", pref .. "sæġe"}
		data.past = pref .. "sæġd"
		data.pp = data.past
		return
	end
	local pref = rmatch(data.inf, "^(.-)hyċġe?an$")
	if pref then
		-- hyċġan, compounds
		data.prese = pref .. "hyċġe"
		data.pres23 = {pref .. "hoga", pref .. "hyġ", pref .. "hyġe"}
		data.impsg = {pref .. "hoga", pref .. "hyġe"}
		data.past = pref .. "hogd"
		data.pp = pref .. "hogod"
		return
	end
end

local function make_irregular_non_past(args, inf, pref, pres1, pres2, pres3, prespl,
	presp, subj, impsg, imppl, pp, with_ge)
	add_ending(args, "infinitive", inf, "")
	add_ending_with_prefix(args, "infinitive2", pref, presp, "ne")
	add_ending_with_prefix(args, "1sg_pres_indc", pref, pres1, "")
	add_ending_with_prefix(args, "2sg_pres_indc", pref, pres2, "")
	add_ending_with_prefix(args, "3sg_pres_indc", pref, pres3, "")
	add_ending_with_prefix(args, "pl_pres_indc", pref, prespl, "")
	add_ending_with_prefix(args, "sg_pres_subj", pref, subj, "")
	add_ending_with_prefix(args, "pl_pres_subj", pref, subj, "n")
	add_ending_with_prefix(args, "sg_impr", pref, impsg, "")
	add_ending_with_prefix(args, "pl_impr", pref, imppl, "")
	add_ending_with_prefix(args, "pres_ptc", pref, presp, "de")
	if with_ge then
		add_ending_with_prefix(args, "past_ptc", pref, pp, "", construct_optional_ge_stem_ending)
	else
		add_ending_with_prefix(args, "past_ptc", pref, pp, "")
	end
end

-- Construct all preterite-present forms. Each of the arguments can be a single string or list.
-- If a given argument is missing, supply an empty list {}.
-- Arguments:
-- INF: Infinitive.
-- PREF: Prefix to add to all forms other than the infinitive.
-- PRES13: 1st/3rd singular present form.
-- PRES2: 2nd singular present form.
-- PRESPL: Plural present form.
-- PRESP: Present participle stem (up through -en, missing final -de; also used to construct
--        second infinitive by adding -ne)
-- SUBJ: Singular present subjunctive form (also used to construct plural subjunctive by adding -n)
-- IMPSG: 2nd singular imperative form.
-- IMPPL: 2nd plural imperative form.
-- PAST: Stem of past tense.
-- PP: Past participle.
local function make_preterite_present_forms(inf, pref, pres13, pres2, prespl,
	presp, subj, impsg, imppl, past, pp)
	local args = {}
	make_irregular_non_past(args, inf, pref, pres13, pres2, pres13, prespl, presp, subj, impsg, imppl, pp)
	make_weak_past(args, pref, past)
	return args
end

local function make_preterite_present(inf)
	local pref, vowel = rmatch(inf, "^(.-[wƿn])([iy])[oe]?tan$")
	if pref then
		return make_preterite_present_forms(
			inf, pref, "āt", "āst", {vowel .. "ton", "iotun", "ietun", "uton"}, vowel .. "ten",
			vowel .. "te", vowel .. "te", vowel .. "taþ", {vowel .. "ss", vowel .. "st"}, vowel .. "ten")
	end
	local pref = rmatch(inf, "^(.-)dugan$")
	if pref then
		return make_preterite_present_forms(
			inf, pref, "dēag", {}, "dugon", "dugen", {"duge", "dyġe"}, {}, {}, {}, {})
	end
	local pref = rmatch(inf, "^(.-)cunnan$")
	if pref then
		return make_preterite_present_forms(
			inf, pref, {"cann", "conn", "can", "con"}, {"canst", "const"}, "cunnon", {}, "cunne", {}, {}, "cūþ", "cunnen")
	end
	local pref = rmatch(inf, "^(.-)unnan$")
	if pref then
		return make_preterite_present_forms(
			inf, pref, {"ann", "onn", "an", "on"}, {}, "unnon", {}, "unne", "unne", {}, "ūþ", {})
	end
	local pref = rmatch(inf, "^(.-[þð])urfan$")
	if pref then
		return make_preterite_present_forms(
			inf, pref, "earf", "earft", "urfon", "earfen", {"urfe", "yrfe"}, {}, {}, "orft", {})
	end
	local pref = rmatch(inf, "^(.-)durran$")
	if pref then
		return make_preterite_present_forms(
			"*" .. inf, pref, {"dear", "dearr"}, "dearst", "durron", {}, {"durre", "dyrre"}, {}, {}, "dorst", {})
	end
	local pref = rmatch(inf, "^(.-)sċulan$")
	if not pref then
		pref = rmatch(inf, "^(.-)sċeolan$")
	end
	if pref then
		return make_preterite_present_forms(
			inf, pref, "sċeal", "sċealt", {"sċulon", "sċeolon"}, {}, {"sċule", "sċeole", "sċyle"}, {}, {}, "sċeold", {})
	end
	local pref = rmatch(inf, "^(.-)munan$")
	if pref then
		return make_preterite_present_forms(
			inf, pref, {"man", "mon"}, {"manst", "monst"}, "munon", "munen", {"mune", "myne"}, {"mun", "myne", "mune"}, {}, "mund", "munen")
	end
	local pref = rmatch(inf, "^(.-)magan$")
	if pref then
		return make_preterite_present_forms(
			inf, pref, "mæġ", {"meaht", "miht"}, "magon", "magen", "mæġe", {}, {}, {"meaht", "meht"}, {})
	end
	local pref = rmatch(inf, "^(.-)nugan$")
	if pref then
		return make_preterite_present_forms(
			"*" .. inf, pref, "neah", {}, "nugon", {}, "nuge", {}, {}, "noht", {})
	end
	local pref = rmatch(inf, "^(.-)mōtan$")
	if pref then
		return make_preterite_present_forms(
			"*" .. inf, pref, "mōt", "mōst", "mōton", {}, "mōte", {}, {}, "mōst", {})
	end
	local pref = rmatch(inf, "^(.-)āgan$")
	if pref then
		return make_preterite_present_forms(
			inf, pref, "āg", "āhst", "āgon", {}, "āge", "āge", {}, "āht", {"āgen", "ǣġen"})
	end
	error("Unrecognized preterite-present verb: " .. inf)
end

local function make_irregular(inf)
	local args = {}
	local pref, cons = rmatch(inf, "^(.-)([wƿ])esan$")
	if pref then
		make_irregular_non_past(args, inf, pref, "eom", "eart", "is", {"sint", "sindon", "sindun"},
			cons .. "esen", {"sīe", "sī"}, cons .. "es", cons .. "esaþ", {})
		make_strong_past(args, pref, cons .. "æs", cons .. "ǣr")
		return args
	end
	local pref = rmatch(inf, "^(.-)nesan$")
	if pref then
		make_irregular_non_past(args, inf, pref, "neom", "neart", "nis", {"ne sint", "ne sindon", "ne sindun"},
			"nesen", {"ne sīe", "ne sī"}, "nes", "nesaþ", {})
		make_strong_past(args, pref, "næs", "nǣr")
		return args
	end
	local pref, vowel = rmatch(inf, "^(.-)b([īē]o)n$")
	if pref then
		make_irregular_non_past(args, inf, pref, "b" .. vowel, "bist", "biþ", "b" .. vowel .. "þ",
			"b" .. vowel .. "n", "b" .. vowel, "b" .. vowel, "b" .. vowel .. "þ", {})
		return args
	end
	local pref = rmatch(inf, "^(.-)dōn$")
	if pref then
		make_irregular_non_past(args, inf, pref, "dō", "dēst", "dēþ", "dōþ", "dōn",
			"dō", "dō", "dōþ", "dōn")
		make_weak_past(args, pref, "dyd")
		return args
	end
	local pref = rmatch(inf, "^(.-)gān$")
	if pref then
		make_irregular_non_past(args, inf, pref, "gā", "gǣst", "gǣþ", "gāþ", {},
			"gā", "gā", "gāþ", "gān")
		make_weak_past(args, pref, "ēod")
		return args
	end
	local pref = rmatch(inf, "^(.-[wƿ])illan$")
	if pref then
		make_irregular_non_past(args, inf, pref, "ille", "ilt", {"ile", "ille"}, "illaþ", "illen",
			{"ille", "ile"}, {}, {}, {})
		make_weak_past(args, pref, "old")
		return args
	end
	local pref, vowel = rmatch(inf, "^(.-)n([eiy])llan$")
	if pref then
		make_irregular_non_past(args, inf, pref, "n" .. vowel .. "lle", "n" .. vowel .. "lt",
			{"n" .. vowel .. "le", "n" .. vowel .. "lle"}, "n" .. vowel .. "llaþ",
			"n" .. vowel .. "llen", {"n" .. vowel .. "lle", "n" .. vowel .. "le"}, {}, {}, {})
		make_weak_past(args, pref, "nold")
		return args
	end
	error("Unrecognized irregular verb: " .. inf)
end

local function set_categories(typ, class)
	local cats = {}
	local classtext = class and "class " .. class .. " " or ""
	if typ == "strong" then
		table.insert(cats, "Old English " .. classtext .. "strong verbs")
	elseif typ == "weak" then
		table.insert(cats, "Old English " .. classtext .. "weak verbs")
	elseif typ == "pretpres" then
		table.insert(cats, "Old English preterite-present verbs")
	elseif typ == "irreg" or typ == "anomalous" then
		table.insert(cats, "Old English irregular verbs")
	else
		error("Unrecognized verb type: " .. typ)
	end
	return cats
end

local function show_old(frame)
	local parent_args = frame:getParent().args
	local params = {
		[1] = {},
		[2] = {},
		[3] = {},
		[4] = {},
		[5] = {},
		[6] = {},
		[7] = {},
		[8] = {},
		[9] = {},
		[10] = {},
		[11] = {},
		[12] = {},
		[13] = {},
		[14] = {},
		[15] = {},
		[16] = {},
		[17] = {},
		[18] = {},
		["type"] = {},
		["class"] = {},
		["style"] = {},
		["width"] = {},
		["title"] = {},
	}
	local args = require("Module:parameters").process(parent_args, params)

	local forms = {}
	for i=1,18 do
		forms[params_to_slots[i]] = rsplit(args[i], ", *")
	end
	forms["type"] = args["type"]
	forms["class"] = args["class"]
	forms["style"] = args["style"]
	forms["width"] = args["width"]
	forms["title"] = args["title"]
	local table = make_table(forms)
	local cats = set_categories(args["type"], args["class"])
	return table .. m_utilities.format_categories(cats, lang)
end

function export.show(frame)
	local parent_args = frame:getParent().args
	if parent_args[1] and not parent_args[1]:find("<") then
		return show_old(frame)
	end
	local params = {
		[1] = {required = true, list = true, default = "beran<s4>"},
	}
	for slot, _ in pairs(slots_and_accel) do
		params[slot] = {}
	end
	local args = require("Module:parameters").process(parent_args, params)
	local allforms
	local allcats = {}
	for _, infspec in ipairs(args[1]) do
		local inf, spec = rmatch(infspec, "^(.-)<(.*)>$")
		if not inf then
			error("Verb spec should look like e.g. 'beran<s4>' or 'dēman<w1>': " .. infspec)
		end
		local specs = rsplit(spec, "/")
		local class = specs[1]
		local verner = rfind(class, "v")
		class = gsub(class, "v", "")
		local presa = gsub(inf, "n$", "")
		data = {
			inf = inf,
			presa = presa,
			prese = gsub(presa, "a$", "e"),
			verner = verner,
			extraforms = {},
		}
		local typ
		if class:find("^s") then
			typ = "strong"
			class = gsub(class, "^s", "")
			if strong_verbs[class] then
				strong_verbs[class](data)
			else
				error("Unrecognized strong class: " .. class)
			end
		elseif class:find("^w") then
			typ = "weak"
			class = gsub(class, "^w", "")
			if weak_verbs[class] then
				weak_verbs[class](data)
			else
				error("Unrecognized weak class: " .. class)
			end
		elseif class == "pp" then
			typ = "pretpres"
		elseif class == "i" then
			typ = "irreg"
		else
			error("Unrecognized verb class: " .. class)
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
				local splitv = rsplit(v, ", *")
				if slots_and_accel[k] then
					overrides[k] = splitv
				elseif typ == "weak" or typ == "strong" then
					if k == "pres" then
						data.presa = splitv
						data.prese = splitv
						data.pres23 = splitv
						data.impsg = splitv
					elseif k == "pres1456" then
						data.presa = splitv
						data.prese = splitv
					elseif k == "pres23" then
						data.pres23 = splitv
					elseif k == "presa" then
						data.presa = splitv
					elseif k == "prese" then
						data.prese = splitv
					elseif typ == "strong" and k == "past" then
						data.pastsg = splitv
						data.pastpl = splitv
					elseif typ == "weak" and k == "past" then
						data.past = splitv
					elseif typ == "strong" and k == "pastsg" then
						data.pastsg = splitv
					elseif typ == "strong" and k == "pastpl" then
						data.pastpl = splitv
					elseif k == "impsg" then
						data.impsg = splitv
					elseif k == "pp" then
						data.pp = splitv
					elseif typ == "weak" and k == "papp" then
						data.past = splitv
						data.pp = splitv
					elseif k == "ge" then
						data.with_ge = require("Module:yesno")(v)
					else
						error("Unrecognized spec key '" .. k .. "' (value '" .. v .. "')")
					end
				else
					error("Unrecognized spec key '" .. k .. "' (value '" .. v .. "')")
				end
			end
		end

		if typ == "weak" or typ == "strong" then
			local missing_fields = {}
			local fields_to_check =
				typ == "weak" and {"presa", "prese", "pres23", "impsg", "past", "pp"} or
				{"presa", "prese", "pres23", "impsg", "pastsg", "pastpl", "pp"}
			for _, field in ipairs(fields_to_check) do
				if not data[field] then
					table.insert(missing_fields, field)
				end
			end
			if #missing_fields > 0 then
				error("Required spec(s) " .. table.concat(missing_fields, ",") ..
					" missing, i.e. the form of the infinitive '" .. inf ..
					"' was not recognized as a " .. typ .. " class-" .. class .. " verb and the " ..
					"overriding specs weren't (all) supplied")
			end
		end
		local forms
		if typ == "strong" then
			forms = make_strong(data.presa, data.prese, data.pres23, data.impsg, data.pastsg,
				data.pastpl, data.pp, data.with_ge)
		elseif typ == "weak" then
			forms = make_weak(data.presa, data.prese, data.pres23, data.impsg, data.past,
				data.pp, data.with_ge)
		elseif typ == "pretpres" then
			forms = make_preterite_present(inf)
		elseif typ == "irreg" then
			forms = make_irregular(inf)
		else
			error("Internal error: Unrecognized verb type: " .. typ)
		end
		for k, v in pairs(data.extraforms) do
			add_form_to_slot(forms, k, v)
		end
		for k, v in pairs(overrides) do
			forms[k] = rsplit(v, ", *")
		end
		class = rsub(class, "[a-z]", "")
		if class == "" then
			class = nil
		end
		if not allforms then
			allforms = forms
			allforms["type"] = typ
			allforms["class"] = class
		else
			for k, v in pairs(forms) do
				for _, form in ipairs(v) do
					ut.insert_if_not(allforms[k], form)
				end
			end
		end
		local cats = set_categories(typ, class)
		for _, cat in ipairs(cats) do
			ut.insert_if_not(allcats, cat)
		end
	end
	local table = make_table(allforms)
	return table .. m_utilities.format_categories(allcats, lang)
end

return export
