local export = {}
local conj = {}
local pron = {}
local data = {}

local m_core = require("Module:fr-verb/core")
local m_pron = require("Module:fr-verb/pron")
local m_links = require("Module:links")
local m_conj = require("Module:fr-conj")
local m_fr_pron = require("Module:fr-pron")
local lang = require("Module:languages").getByCode("fr")
local IPA = function(str)
	return require("Module:IPA").format_IPA(nil,str)
end
local pron = function(str,combining)
	return m_fr_pron.show(str,"v",nil,combining)
end

PAGENAME = PAGENAME or mw.title.getCurrentTitle().text

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

local etre = {
	"aller",
	"alterner",
	"apparaître",
	"arriver",
	"décéder",
	"entrer", "rentrer",
	"mourir",
	"naitre", "naître", "renaitre", "renaître",
	"partir",
	"rester",
	"surmener",
	"tomber", "retomber",
	"venir", "advenir", "bienvenir", "devenir", "intervenir", "parvenir", "provenir", "redevenir", "revenir", "survenir"
}

for _,key in ipairs(etre) do
	etre[key] = true
end

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
	"qualifier","rainurer","ramener","rebattre","reboiser","reclasser","recoiffer","recoller","recomparaître","redormir","redécouvrir","refusionner","regeler","relancer","relever","relier","remonter","rendormir","repartir","repasser","repatrier","repentir","respitier","ressentir","ressouvenir","restaurer","restreindre","restructurer","retourner","retransmettre","retweeter","réagir","réapparaitre","réapparaître","réentendre","référencer",
	"savourer","sentir","siffler","simplifier","sortir","soupeser","spammer","subvenir","suspecter","synchroniser",
	"taire","tiédir",
	"volleyer","ædifier",
	"élancer","élever","éloigner","étriver"
}

for _,key in ipairs(avoir_or_etre) do
	avoir_or_etre[key] = true
end

local alias = {
	["connaitre"] = "aitre",
	["connaître"] = "aître",
}

local ir_s = {
	"assentir", "dormir", "partir", "mentir", "sentir", "sortir", "servir", "repartir", "endormir", "repentir", "consentir", "rendormir", "démentir", "resservir", "ressentir", "ressortir", "rebouillir", "pressentir", "desservir", "redormir", "départir"
}
for _,key in ipairs(ir_s) do
	ir_s[key] = true
end

local function link(term, alt)
	return m_links.full_link({lang = lang, term = term, alt = alt}, "term")
end

conj["er"] = function()
	if data.stem == "all" then
		data.stem = ""
		conj["irreg-aller"]()
		data.forms.inf = "aller"
		
		data.category = "aller"
		
		data.typ = "suppletive"
	else
		data = m_core.make_ind_p_e(data, "")
		
		local stem = pron((data.pronstem or data.stem) .. "e")
		local stem2 = pron((data.pronstem or data.stem) .. "i")
		
		stem2 = mw.ustring.gsub(stem2,".$","")
		
		data = m_pron.er(data, stem,stem2)
		
		data.category = "-er"
	end
end

conj["ier"] = function()
	data = m_core.make_ind_p_e(data, "i")
	
	local stem = pron((data.pronstem or data.stem) .. "i")
	local stem2 = pron((data.pronstem or data.stem) .. "ier")
	local stem3 = stem .. "."
	
	stem2 = mw.ustring.gsub(stem2,".$","")
	
	data = m_pron.er(data, stem, stem2)
	data = m_pron.ind_f(data, stem3)
	
	data.prons.ind_i_1p = stem .. ".jɔ̃"
	data.prons.ind_i_2p = stem .. ".je"
	data.prons.sub_p_1p = stem .. ".jɔ̃"
	data.prons.sub_p_2p = stem .. ".je"
	
	data.category = "-er"
end

conj["iller"] = function()
	data = m_core.make_ind_p_e(data, "ill")
	
	local stem = pron(data.pronstem or data.stem .. "ille")
	local stem2 = pron((data.pronstem or data.stem) .. "iller")
	
	stem2 = mw.ustring.gsub(stem2,".$","")
	
	data = m_pron.er(data, stem, stem2)
	
	data.category = "-er"
end

conj["uer"] = function()
	data = m_core.make_ind_p_e(data, "u")
	
	local stem = pron((data.pronstem or data.stem) .. "ue")
	local stem2 = pron((data.pronstem or data.stem) .. "uer")
	
	stem2 = mw.ustring.gsub(stem2,".$","")
	
	data = m_pron.er(data, stem, stem2)
	
	data.prons.ind_i_1p = stem .. ".jɔ̃"
	data.prons.ind_i_2p = stem .. ".je"
	data.prons.sub_p_1p = stem .. ".jɔ̃"
	data.prons.sub_p_2p = stem .. ".je"
	
	data = m_pron.ind_f(data, stem .. ".")
	
	data.category = "-er"
end

conj["éer"] = function()
	data = m_core.make_ind_p_e(data, "é")
	
	local stem = pron((data.pronstem or data.stem) .. "é")
	
	data = m_pron.er(data, stem, stem..".")
	
	data.prons.ind_i_1p = stem .. "j.jɔ̃"
	data.prons.ind_i_2p = stem .. "j.je"
	data.prons.sub_p_1p = stem .. "j.jɔ̃"
	data.prons.sub_p_2p = stem .. "j.je"
	
	data = m_pron.ind_f(data, stem..".")
	
	data.category = "-er"
end

conj["cer"] = function()
	data = m_core.make_ind_p_e(data, "c", "ç")
	
	data.notes = "This verb is part of a group of " .. link("-er") .. " verbs for which ‘c’ is softened to a ‘ç’ before the vowels ‘a’ and ‘o’."
	
	local stem = pron((data.pronstem or data.stem) .. "ce")
	local stem2 = pron((data.pronstem or data.stem) .. "ci")
	
	stem2 = mw.ustring.gsub(stem2,".$","")
	
	data = m_pron.er(data, stem, stem2)
	
	data.category = "-cer"
end

conj["ger"] = function()
	data = m_core.make_ind_p_e(data, "g", "ge")
	
	data.notes = "This is a regular " .. link("-er") .. " verb, but the stem is written ''{stem}ge-'' before endings that begin with ''-a-'' or ''-o-'' "
	data.notes = data.notes .. "(to indicate that the ''-g-'' is a “soft” " .. IPA("/ʒ/") .. " and not a “hard” " .. IPA("/ɡ/") .. "). "
	data.notes = data.notes .. "This spelling-change occurs in all verbs in ''-ger'', such as "
	data.notes = data.notes .. link(data.stem == "nei" and "bouger" or "neiger") .. " and "
	data.notes = data.notes .. link(data.stem == "man" and "ranger" or "manger") .. "."
	
	local stem = pron((data.pronstem or data.stem) .. "ge")
	local stem2 = pron((data.pronstem or data.stem) .. "gi")
	
	stem2 = mw.ustring.gsub(stem2,".$","")
	
	data = m_pron.er(data, stem, stem2)
	
	data.category = "-ger"
end

conj["ayer"] = function()
	data = m_core.make_ind_p_e(data, "ay/ai", "ay", "ay")
	
	local root = pron((data.pronstem or data.stem) .. "a")
	root = mw.ustring.gsub(root,".$","")
	
	local stem = root .. "ɛ"
	local stem2 = root .. "ɛj"
	local stem3 = root .. "e.j"
	local stem4 = root .. "ej."
	local stem5 = root .. "e"
	
	data.prons.ppr = stem3 .. "ɑ̃"
	data.prons.pp = stem3 .. "e"
	
	data = m_pron.er(data, stem2 .. "/" .. stem, stem3)
	data = m_pron.ind_f(data, stem3 .. "ə./" .. stem5 .. ".")
	
	data.category = "-ayer"
end

conj["eyer"] = function()
	data = m_core.make_ind_p_e(data, "ey")
	
	local root = pron((data.pronstem or data.stem) .. "i")
	root = mw.ustring.gsub(root,".$","")
	
	local stem = root .. "ɛj"
	local stem2 = root .. "e.j"
	local stem3 = root .. "ej"
	
	data = m_pron.er(data, stem, stem2)
	data = m_pron.ind_f(data, stem3 .. ".")
	
	data.category = "-eyer"
end

conj["yer"] = function()
	data = m_core.make_ind_p_e(data, "i", "y", "y")
	
	local stem = pron((data.pronstem or data.stem) .. "i")
	
	data = m_pron.er(data, stem, stem..".j")
	
	data.category = "-yer"
end

conj["xxer"] = function(consonant)
	data.notes = "With the exception of " .. (stem == "appel" and "''appeler''" or link("appeler")) .. ", "
	data.notes = data.notes .. (stem == "jet" and "''jeter''" or link("jeter")) .. " and their derived verbs, "
	data.notes = data.notes .. "all verbs that used to double the consonants can also now be conjugated like " .. link("amener") .. "."

	data = m_core.make_ind_p_e(data, consonant..consonant, consonant, consonant)
	
	local root = pron((data.pronstem or data.stem) .. consonant .. consonant .. "e")
	local root2 = pron((data.pronstem or data.stem) .. consonant .. "i")
	
	root2 = mw.ustring.gsub(root2,".$","")
	
	data = m_pron.er(data, root, root2)
	
	data = m_pron.ind_f(data, root .. ".")
	
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
	
	local root = pron((data.pronstem or data.stem) .. stem2 .. "e")
	local root2 = pron((data.pronstem or data.stem) .. stem .. "i")
	
	root2 = mw.ustring.gsub(root2,".$","")
	
	data = m_pron.er(data, root, root2)
	
	data = m_pron.ind_f(data, root .. ".")
	
	data.category = "-e-er"
end

conj["ecer"] = function()
	data = m_core.make_ind_p_e(data, "èc", "eç", "ec")
	
	local root = pron((data.pronstem or data.stem) .. "èce")
	local root2 = pron((data.pronstem or data.stem) .. "eci")
	
	root2 = mw.ustring.gsub(root2,".$","")
	
	data = m_pron.er(data, root, root2)
	
	data = m_pron.ind_f(data, root .. ".")
	
	data.category = "-e-er"
end

conj["eger"] = function()
	data = m_core.make_ind_p_e(data, "èg", "ege", "eg")
	
	local root = pron((data.pronstem or data.stem) .. "ège")
	local root2 = pron((data.pronstem or data.stem) .. "egi")
	
	root2 = mw.ustring.gsub(root2,".$","")
	
	data = m_pron.er(data, root, root2)
	
	data = m_pron.ind_f(data, root .. ".")
	
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
	
	
	local root = pron((data.pronstem or data.stem) .. stem2 .. "e")
	local root2 = pron((data.pronstem or data.stem) .. stem .. "i")
	
	root2 = mw.ustring.gsub(root2,".$","")
	
	data = m_pron.er(data, root,root2)
	
	data = m_pron.ind_f(data, root .. ".")
	
	data.category = "-é-er"
end

conj["écer"] = function()
	data.notes = "This verb is conjugated like " .. link("rapiécer") .. ". It has both the spelling irregularities of other verbs in ''<span lang=\"fr\">-cer</span>'' "
	data.notes = data.notes .. "(such as " .. link("pincer") .. ", where a silent ‘e’ is inserted before ‘a’ and ‘o’ endings (to indicate the " .. IPA("/s/") .. " sound), "
	data.notes = data.notes .. "and the spelling and pronunciation irregularities of other verbs in ''<span lang=\"fr\">-é-er</span>'' (such as " .. link("céder") .. ", "
	data.notes = data.notes .. "where the last stem vowel alternates between " .. IPA("/e/") .. " (written ‘é’) and " .. IPA("/ɛ/") .. " (written ‘è’)."
	
	data = m_core.make_ind_p_e(data, "èc", "éç", "éc")
	data = m_core.make_ind_f(data, {"écer", "ècer"})
	
	local root = pron((data.pronstem or data.stem) .. "èce")
	local root2 = pron((data.pronstem or data.stem) .. "éci")
	
	root2 = mw.ustring.gsub(root2,".$","")
	
	data = m_pron.er(data, root, root2)
	
	data = m_pron.ind_f(data, root .. ".")
	
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
	
	
	local root = pron((data.pronstem or data.stem) .. "ège")
	local root2 = pron((data.pronstem or data.stem) .. "égi")
	
	root2 = mw.ustring.gsub(root2,".$","")
	
	data = m_pron.er(data, root, root2)
	
	data = m_pron.ind_f(data, root .. ".")
	
	data.category = "-é-er"
end

conj["ir"] = function()
	local ending = mw.ustring.sub(data.stem, -1, -1)
	if ir_s[data.stem.."ir"] then
		data.stem = mw.ustring.sub(data.stem, 1, -2)
		data = m_core.make_ind_p(data, "", ending)
		data = m_core.make_ind_f(data, ending.."ir")
		
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
	else
		ending = ""
		data = m_core.make_ind_p(data, "i", "iss")
	end
	data = m_core.make_ind_ps(data, ending.."i")
	
	local stem, stem2, stem3, stem4
	if ir_s[data.stem..ending.."ir"] then
		stem = pron((data.pronstem or data.stem), true)
		stem2 = stem .. "." .. ending
		stem3 = stem .. ending
		stem4 = stem .. "." .. ending .. "i"
	else
		stem = pron((data.pronstem or data.stem) .. "i")
		stem2 = stem .. ".s"
		stem3 = stem .. "s"
		stem4 = stem
	end
	data = m_pron.ind_p(data, stem, stem2, stem3)
	data = m_pron.ind_ps(data, stem4)
	data = m_pron.ind_f(data, stem4 .. ".")
	
	data.category = "-ir"
end

conj["ïr"] = function()
	data = m_core.make_ind_p(data, "ï", "ïss")
	data = m_core.make_ind_ps(data, "ï")
	
	local stem, stem2, stem3, stem4
	stem = pron((data.pronstem or data.stem) .. "ï")
	stem2 = stem .. ".s"
	stem3 = stem .. "s"
	
	data = m_pron.ind_p(data, stem, stem2, stem3)
	data = m_pron.ind_ps(data, stem)
	data = m_pron.ind_f(data, stem .. ".")
	
	data.category = "-ïr"
end

conj["haïr"] = function()
	data.notes = "This verb is spelled as if conjugated like " .. link("finir") .. ", but has a [[diaeresis]] throughout its conjugation "
	data.notes = data.notes .. "(including where the circumflex would normally be used) except in the singular indicative present, "
	data.notes = data.notes .. "whose forms are pronounced " .. IPA("/ɛ/") .. " in Standard French instead of " .. IPA("/ai/") .. ", "
	data.notes = data.notes .. "a pronunciation nonetheless often found in informal speech."
	
	data = m_core.make_ind_p(data, "hai", "haïss")
	data = m_core.make_ind_ps(data, "haï")
	
	local stem, stem2, stem3, stem4
	stem = pron((data.pronstem or data.stem) .. "haï")
	stem2 = stem .. ".s"
	stem3 = stem .. "s"
	stem4 = pron((data.pronstem or data.stem) .. "hais")
	
	data.prons.ppr = stem2 .. "ɑ̃"
	data.prons.pp = stem
	
	data = m_pron.ind_p(data, stem4, stem2, stem3)
	data = m_pron.ind_ps(data, stem)
	data = m_pron.ind_f(data, stem .. ".")
	
	data.category = "haïr"
	data.typ = "irregular"
end

conj["ouïr"] = function()
	data.notes = "The forms beginning with ''oi-'', ''oy-'', or ''orr-'' are archaic."
	
	data = m_core.make_ind_p(data, "ouï/oi", "ouïss/oy", "ouïss/oi")
	data = m_core.make_ind_ps(data, "ouï")
	data = m_core.make_ind_f(data, "ouïr/oir/orr")
	
	local stem11 = pron((data.pronstem or data.stem) .. "oui")
	local stem12 = stem11 .. ".s"
	local stem13 = stem11 .. "s"
	local stem21 = pron((data.pronstem or data.stem) .. "oi")
	local stem22 = pron((data.pronstem or data.stem) .. "ɔ") .. ".j"
	local stem31 = pron((data.pronstem or data.stem) .. "ɔ")
	
	data = m_pron.ind_p(data, stem11.."/"..stem21, stem12.."/"..stem22, stem13.."/"..stem21)
	data = m_pron.ind_ps(data, stem11)
	data = m_pron.ind_f(data, stem11.."./"..stem21.."./"..stem31..".")
	
	data.category = "ouïr"
	data.typ = "irregular"
end

conj["asseoir"] = function()
	data.forms.pp = "assis"
	data.notes = "The verb " .. link("asseoir") .. " (and its derivative " .. link("rasseoir") .. ") has 2 distinct conjugations."
	
	data = m_core.make_ind_p(data, "assoi/assied", "assoy/assey", "assoi/assey")
	data.forms.ind_p_3s[2] = "assied"
	data = m_core.make_ind_ps(data, "assi")
	data = m_core.make_ind_f(data, "assoir/assiér")

	local stem11 = pron((data.pronstem or data.stem) .. "assoi")
	local stem12 = stem11 .. ".j"
	local stem13 = stem11
	local stem21 = pron((data.pronstem or data.stem) .. "assié")
	local stem22 = pron((data.pronstem or data.stem) .. "assei") .. ".j"
	local stem23 = pron((data.pronstem or data.stem) .. "asseye")
	local stem31 = pron((data.pronstem or data.stem) .. "assi")
	
	data = m_pron.ind_p(data, stem11.."/"..stem21, stem12.."/"..stem22, stem13.."/"..stem23)
	data = m_pron.ind_ps(data,stem31)
	data = m_pron.ind_f(data, stem11.."./"..stem21..".")
	
	data.category = "seoir"
	data.typ = "irregular"
end

conj["surseoir"] = function()
	data.forms.pp = "sursis"
	data = m_core.make_ind_p(data, "sursoi", "sursoy", "sursoi")
	data = m_core.make_ind_ps(data, "sursi")
	
	local stem = pron((data.pronstem or data.stem) .. "sursoi")
	local stem2 = stem .. ".j"
	local stem3 = pron((data.pronstem or data.stem) .. "sursi")
	local stem4 = stem .. "."
	
	data = m_pron.ind_p(data, stem, stem2, stem)
	data = m_pron.ind_ps(data, stem3)
	data = m_pron.ind_f(data, stem4)
	
	data.category = "seoir"
	data.typ = "irregular"
end

conj["seoir"] = function()
	data.notes = "This is a defective verb, only conjugated in the third person"
	
	data.forms.ppr = {"séant","seyant"}
	data.forms.pp = "—"
	
	data = m_core.make_ind_p(data, "—")
	data = m_core.make_ind_ps(data, "—")
	data = m_core.make_ind_f(data, "—")
	data.forms.ind_p_3s = "sied"
	data.forms.ind_p_3p = "siéent"
	data.forms.ind_i_3s = "seyait"
	data.forms.ind_i_3p = "seyaient"
	data.forms.ind_f_3s = "siéra"
	data.forms.ind_f_3p = "siéront"
	data.forms.cond_p_3s = "siérait"
	data.forms.cond_p_3p = "siéraient"
	data.forms.sub_p_3s = "siée"
	data.forms.sub_p_3p = "siéent"
	
	data.prons.ppr = {"se.ɑ̃","sɛ.jɑ̃"}
	
	data.prons.ind_p_3s = "sje"
	data.prons.ind_p_3p = "sje"
	data.prons.ind_i_3s = "sɛ.jɛ"
	data.prons.ind_i_3p = "sɛ.jɛ"
	data.prons.ind_f_3s = "sje.ʁa"
	data.prons.ind_f_3p = "sje.ʁɔ̃"
	data.prons.cond_p_3s = "sje.ʁɛ"
	data.prons.cond_p_3p = "sje.ʁɛ"
	data.prons.sub_p_3s = "sje"
	data.prons.sub_p_3p = "sje"
	
	data.category = "seoir"
	data.typ = "irregular"
end

conj["bouillir"] = function()
	data = m_core.make_ind_p(data, "bou", "bouill")
	data = m_core.make_ind_ps(data, "bouilli")
	
	local stem = pron((data.pronstem or data.stem) .. "bou", true)
	local stem2 = stem .. ".j"
	local stem3 = stem .. "j"
	local stem4 = stem .. ".ji"
	local stem5 = stem .. ".ji."
	
	data = m_pron.ind_p(data, stem, stem2, stem3)
	data = m_pron.ind_ps(data, stem4)
	data = m_pron.ind_f(data, stem5)
	
	data.category = "bouillir"
	data.typ = "irregular"
end

conj["enir"] = function()
	data.forms.pp = "enu"
	
	data = m_core.make_ind_p(data, "ien", "en", "ienn")
	data = m_core.make_ind_ps(data, "in")
	data = m_core.make_ind_f(data, "iendr")
	
	local root = mw.ustring.gsub(pron((data.pronstem or data.stem) .. "é"), "e$", "")
	
	local stem = root .. "jɛ̃"
	local stem2 = root .. "ə.n"
	local stem3 = root .. "jɛ̃n"
	local stem4 = root .. "ɛ̃"
	local stem5 = root .. "jɛ̃.d"
	
	data = m_pron.ind_p(data, stem, stem2, stem3)
	data = m_pron.ind_ps(data, stem4)
	data = m_pron.ind_f(data, stem5)
	
	data.prons.pp = stem2 .. "y"
	
	if mw.ustring.sub(data.stem,-1) == "t" then
		data.category = "tenir"
	else
		data.category = "venir"
	end
	data.typ = "irregular"
end

conj["rir"] = function()
	data.notes = "This verb is conjugated like " .. link(data.stem == "ouv" and "couvrir" or "ouvrir")
	data.notes = data.notes .. " and " .. link(data.stem == "off" and "souffrir" or "offrir") .. ". "
	data.notes = data.notes .. "It is conjugated like a regular " .. link("-er") .. " verb in the present and imperfect indicative, present subjunctive, "
	data.notes = data.notes .. "imperative, and present participle; it is conjugated like a regular " .. link("-ir") .. " verb in the infinitive, "
	data.notes = data.notes .. "future indicative, conditional, past historic, and imperfect subjunctive; "
	data.notes = data.notes .. "and its past participle " .. link("{stem}ert") .. " is irregular."
	
	data.forms.pp = "ert"
	
	data = m_core.make_ind_p_e(data, "r")
	data = m_core.make_ind_ps(data, "ri")
	data = m_core.make_ind_f(data, "rir")
	
	local root = pron((data.pronstem or data.stem), true)
	local root2 = mw.ustring.gsub(pron((data.pronstem or data.stem).."a", true),"a$","")
	
	local stem = root .. "ʁ"
	local stem2 = root2 .. "ʁ"
	local stem3 = root2 .. "ʁi"
	local stem4 = root2 .. "ʁi."
	
	data.prons.pp = root2 .. "ɛʁ"
	
	data = m_pron.er(data, stem, stem2)
	data = m_pron.ind_ps(data, stem3)
	data = m_pron.ind_f(data, stem4)
end

conj["quérir"] = function()
	data.forms.pp = "quis"
	
	data = m_core.make_ind_p(data, "quier", "quér", "quièr")
	data = m_core.make_ind_ps(data, "qui")
	data = m_core.make_ind_f(data, "querr")
	
	local root = mw.ustring.gsub(pron((data.pronstem or data.stem) .. "qué"), "e$", "")
	
	local stem = root .. "jɛʁ"
	local stem2 = root .. "e.ʁ"
	local stem3 = root .. "i"
	local stem4 = root .. "ɛ."
	
	data = m_pron.ind_p(data, stem, stem2)
	data = m_pron.ind_ps(data, stem3)
	data = m_pron.ind_f(data, stem4)
end

conj["aillir"] = function()
	data = m_core.make_ind_p_e(data, "aill")
	data = m_core.make_ind_ps(data, "ailli")
	data = m_core.make_ind_f(data, "aillir")
	
	local root = pron((data.pronstem or data.stem) .. "a")

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
	
	data = m_core.make_ind_p(data, "chauvi", "chauv/chauviss")
	data = m_core.make_ind_ps(data, "chauvi")

	local root = pron((data.pronstem or data.stem) .. "chau")
	
	local stem = root .. ".vi"
	local stem2 = root .. ".v"
	local stem22 = root .. ".vi.s"
	local stem3 = root .. "v"
	local stem32 = root .. ".vis"
	local stem4 = root .. ".vi."
	
	data = m_pron.ind_p(data, stem, stem2.."/"..stem22, stem3.."/"..stem32)
	data = m_pron.ind_ps(data, stem)
	data = m_pron.ind_f(data, stem4)
end

conj["choir"] = function()
	data = m_core.make_ind_p(data, "choi","choy","choi")
	data = m_core.make_ind_i(data, "—")
	data = m_core.make_ind_ps(data, "chu")
	
	data.forms.imp_p_2s = "—"
	data.forms.imp_p_1p = "—"
	data.forms.imp_p_2p = "—"
	
	local stem = pron((data.pronstem or data.stem) .. "choi")
	local stem2 = stem .. ".j"
	local stem3 = pron((data.pronstem or data.stem) .. "chu")
	local stem4 = pron((data.pronstem or data.stem) .. "chè")
	
	data = m_pron.ind_p(data, stem, stem2)
	data = m_pron.ind_ps(data, stem3)
	data = m_pron.ind_f(data, stem .. "./" .. stem4 .. ".")
	
	if data.stem == "" then
		data.notes = "This is a [[defective]] verb, only conjugated in certain tenses."
		data = m_core.make_ind_f(data, "choir/cherr")
		data = m_core.make_cond_p(data, "choir")
		data = m_pron.cond_p(data, stem)
		data = m_core.make_sub_p(data, "—")
		data = m_core.make_sub_pa(data, "—")
		data.forms.sub_pa_3s = "chût"
	elseif data.stem == "dé" then
		data.notes = "This verb is [[defective]] in that it is not conjugated in certain tenses. It has no indicative imperfect form, imperative form and no present participle."
		data.forms.ind_p_3s = {"choit","chet"}
		data.prons.ind_p_3s = {stem,stem4}
		data = m_core.make_ind_f(data, "choir/cherr")
	elseif data.stem == "é" then
		data.notes = "This verb is defective and is only conjugated in the third-person."
		data.forms.ppr = "chéant"
		data.prons.ppr = "e.ʃe.jɑ̃"
		data = m_core.make_ind_i(data, "choy")
		data = m_core.make_ind_f(data, "choir")
		data = m_pron.ind_f(data, stem .. ".")
		for key,val in pairs(data.forms) do
			if mw.ustring.match(key,'[12]') then data.forms[key] = "—" end
		end
		data.forms.ind_p_3s = {"choit","chet"}
		data.prons.ind_p_3s = {stem,stem4}
		data.forms.ind_p_3p = {"choient","chettent"}
		data.prons.ind_p_3p = {stem,stem4}
	end
end

conj["cueillir"] = function()
	data = m_core.make_ind_p_e(data, "cueill")
	data = m_core.make_ind_ps(data, "cueilli")
	data = m_core.make_ind_f(data, "cueiller")
	data.forms.pp = "cueilli"
	
	local root = mw.ustring.gsub(pron((data.pronstem or data.stem) .. "cueille"),"j$","")

	local stem = root .. "j"
	local stem2 = root .. ".j"
	local stem3 = root .. ".ji"
	local stem4 = root .. ".ji."
	
	data.prons.pp = stem3
	
	data = m_pron.er(data, stem, stem2)
	data = m_pron.ind_ps(data, stem3)
	data = m_pron.ind_f(data, stem4)
end

conj["courir"] = function()
	data.notes = "This verb is conjugated like other regular " .. link("-ir") .. " verbs, "
	data.notes = data.notes .. "except that in the conditional and future tenses an extra ‘r’ is added to the end of the stem "
	data.notes = data.notes .. "and the past participle ends in ''-u''. All verb ending in ''-courir'' are conjugated this way."
	
	data = m_core.make_ind_p(data, "cour")
	data = m_core.make_ind_ps(data, "couru")
	data = m_core.make_ind_f(data, "courr")
	data.forms.pp = "couru"
	
	local root = pron((data.pronstem or data.stem) .. "cou")

	local stem = root .. "ʁ"
	local stem2 = root .. ".ʁ"
	local stem3 = root .. ".ʁy"
	local stem4 = root .. "."
	
	data.prons.pp = stem3
	
	data = m_pron.er(data, stem, stem2)
	data = m_pron.ind_ps(data, stem3)
	data = m_pron.ind_f(data, stem4)
end

conj["falloir"] = function()
	data = m_core.make_ind_p(data, "—")
	data = m_core.make_ind_ps(data, "—")
	data = m_core.make_ind_f(data, "—")
	data.notes = "This verb is defective, only conjugated in the third-person singular."
	data.forms.pp = "fallu"
	data.forms.ind_p_3s = "faut"
	data.forms.ind_i_3s = "fallait"
	data.forms.ind_ps_3s = "fallut"
	data.forms.ind_f_3s = "faudra"
	data.forms.cond_p_3s = "faudrait"
	data.forms.sub_p_3s = "faille"
	data.forms.sub_pa_3s = "fallût"
	--pronunciation
	data.prons.pp = "fa.ly"
	data.prons.ind_p_3s = "fo"
	data.prons.ind_i_3s = "fa.lɛ"
	data.prons.ind_ps_3s = "fa.ly"
	data.prons.ind_f_3s = "fo.dʁa"
	data.prons.cond_p_3s = "fo.dʁɛ"
	data.prons.sub_p_3s = "faj"
	data.prons.sub_pa_3s = "fa.ly"
end

conj["férir"] = function()
	data.notes = "This verb is defective and is virtually never conjugated in Modern French, except in a few set phrases or as a mark of extreme archaism. "
	data.notes = data.notes .. "Most of its uses stem from variations on " .. link("sans coup férir") .. "."
	
	data.forms.pp = "féru"
	data.prons.pp = "fe.ʁy"
	
	data = m_core.make_ind_p(data, "—")
	data = m_core.make_ind_ps(data, "—")
	data = m_core.make_ind_f(data, "—")
end

conj["fuir"] = function()
	data.forms.pp = "fui"
	
	data = m_core.make_ind_p(data, "fui", "fuy", "fui")
	data = m_core.make_ind_ps(data, "fui")
	
	local stem = pron((data.pronstem or data.stem) .. "fui")
	local stem2 = pron((data.pronstem or data.stem) .. "fu") .. ".j"
	
	data.prons.pp = stem
	
	data = m_pron.ind_p(data, stem, stem2, stem)
	data = m_pron.ind_ps(data, stem)
	data = m_pron.ind_f(data, stem .. ".")
end

conj["gésir"] = function()
	data.notes = "This is a [[defective]] verb, and is only conjugated in the present and imperfect indicative."
	
	data = m_core.make_ind_p(data, "gi", "gis")
	data = m_core.make_ind_ps(data, "—")
	data = m_core.make_ind_f(data, "—")
	data = m_core.make_sub_p(data, "—")
	
	data.forms.ind_p_3s = "gît"
	data.forms.imp_p_2s = "—"
	data.forms.imp_p_1p = "—"
	data.forms.imp_p_2p = "—"
	
	local stem = pron((data.pronstem or data.stem) .. "gi")
	local stem2 = stem .. ".z"
	local stem3 = stem .. "z"
	
	data = m_pron.ind_p(data, stem, stem2, stem3)
end

conj["re"] = function()
	data.forms.pp = "u"
	
	data = m_core.make_ind_p(data, "")
	data.forms.ind_p_3s = ""
	data = m_core.make_ind_ps(data, "i")
	
	local stem = pron((data.pronstem or data.stem))
	local stem2 = mw.ustring.gsub(pron((data.pronstem or data.stem) .. "a"),"a$","")
	local stem3 = pron((data.pronstem or data.stem), true)
	local stem4 = stem2 .. "i"
	
	data.prons.pp = stem2 .. "y"
	
	data = m_pron.ind_p(data, stem, stem2, stem3)
	data = m_pron.ind_ps(data, stem4)
	data = m_pron.ind_f(data, stem2)
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
	
	data.forms.pp = "cu"
	
	data = m_core.make_ind_p(data, "c", "qu")
	data.forms.ind_p_3s = "c"
	data = m_core.make_ind_ps(data, "qui")
	
	local stem = pron((data.pronstem or data.stem) .. "c")
	local stem2 = mw.ustring.gsub(pron((data.pronstem or data.stem) .. "ca"),"a$","")
	local stem3 = pron((data.pronstem or data.stem) .. "c", true)
	local stem4 = stem2 .. "i"

	data.prons.pp = stem2 .. "y"
	
	data = m_pron.ind_p(data, stem, stem2, stem3)
	data = m_pron.ind_ps(data, stem4)
	data = m_pron.ind_f(data, stem2)
end

conj["crire"] = function()
	data = m_core.make_ind_p(data, "cri", "criv")
	data = m_core.make_ind_ps(data, "crivi")
	data.forms.pp = "crit"
	
	local stem = pron((data.pronstem or data.stem) .. "cri")
	local stem2 = stem .. ".v"
	local stem3 = stem .. "v"
	local stem4 = stem .. ".vi"
	
	data.prons.pp = stem
	
	data = m_pron.ind_p(data, stem, stem2, stem3)
	data = m_pron.ind_ps(data, stem4)
	data = m_pron.ind_f(data, stem .. ".")
end

conj["uire"] = function()
	data.forms.pp = "uit"
	
	data = m_core.make_ind_p(data, "ui", "uis")
	data = m_core.make_ind_ps(data, "uisi")
	
	local stem = pron((data.pronstem or data.stem) .. "ui")
	local stem2 = stem .. ".z"
	local stem3 = stem .. "z"
	local stem4 = stem .. ".zi"
	
	data.prons.pp = stem
	
	data = m_pron.ind_p(data, stem, stem2, stem3)
	data = m_pron.ind_ps(data, stem4)
	data = m_pron.ind_f(data, stem .. ".")
end

conj["aître"] = function()
	data.notes = "This verb is one of a fairly small group of " .. link("-re") .. " verbs, that are all conjugated the same way. They are unlike other verb groups in that the ‘i’ is given a circumflex before a ‘t’."
	
	data = m_core.make_ind_p(data, "ai", "aiss")
	data.forms.ind_p_3s = "aît"
	data = m_core.make_ind_ps(data, "u")
	data = m_core.make_ind_f(data, "aîtr")
	
	local stem = pron((data.pronstem or data.stem) .. "ais")
	local stem2 = stem .. ".s"
	local stem3 = stem .. "s"
	local stem4 = pron((data.pronstem or data.stem) .. "u")
	
	data = m_pron.ind_p(data, stem, stem2, stem3)
	data = m_pron.ind_ps(data, stem4)
	data = m_pron.ind_f(data, stem .. ".t")
end

conj["aitre"] = function()
	data.notes = "This verb is one of a fairly small group of " .. link("-re") .. " verbs, that are all conjugated the same way. They are conjugated the same as the alternative spelling, which has a [[circumflex]] over the ‘i’, except that the circumflex is dropped here."
	
	data = m_core.make_ind_p(data, "ai", "aiss")
	data = m_core.make_ind_ps(data, "u")
	data = m_core.make_ind_f(data, "aitr")
	
	local stem = pron((data.pronstem or data.stem) .. "ais")
	local stem2 = stem .. ".s"
	local stem3 = stem .. "s"
	local stem4 = pron((data.pronstem or data.stem) .. "u")
	
	data = m_pron.ind_p(data, stem, stem2, stem3)
	data = m_pron.ind_ps(data, stem4)
	data = m_pron.ind_f(data, stem .. ".t")
end

conj["oître"] = function()
	data.notes = "This verb is one of a fairly small group of " .. link("-re") .. " verbs, that are all conjugated the same way. They are unlike other verb groups in that the ‘i’ is given a circumflex before a ‘t’. This conjugation pattern is no longer in use and has been replaced by -aître."
	
	data = m_core.make_ind_p(data, "oi", "oiss")
	data.forms.ind_p_3s = "oît"
	data = m_core.make_ind_ps(data, "u")
	
	local stem = pron((data.pronstem or data.stem) .. "ais")
	local stem2 = stem .. ".s"
	local stem3 = stem .. "s"
	local stem4 = pron((data.pronstem or data.stem) .. "u")
	
	data = m_pron.ind_p(data, stem, stem2, stem3)
	data = m_pron.ind_ps(data, stem4)
	data = m_pron.ind_f(data, stem .. ".t")
end

conj["indre"] = function()
	data.forms.pp = "int"
	
	data = m_core.make_ind_p(data, "in", "ign")
	data = m_core.make_ind_ps(data, "igni")
	data = m_core.make_ind_f(data, "indr")
	
	local root = pron((data.pronstem or data.stem) .. "in")
	local root2 = mw.ustring.gsub(pron((data.pronstem or data.stem) .. "ine"), "n$", "")
	
	local stem = root
	local stem2 = root2 .. ".ɲ"
	local stem3 = root2 .. "ɲ"
	local stem4 = root2 .. ".ɲi"
	
	data.prons.pp = stem
	
	data = m_pron.ind_p(data, stem, stem2, stem3)
	data = m_pron.ind_ps(data, stem4)
	data = m_pron.ind_f(data, stem .. ".d")
end

conj["clure"] = function()
	data = m_core.make_ind_p(data, "clu")
	data = m_core.make_ind_ps(data, "clu")
	
	if data.stem == "in" or data.stem == "trans" or data.stem == "oc" then
		data.forms.pp = "clus"
		data.notes = "This verb is one of a few verbs in ''-clure'' where the past participle is in ''-us(e)'' instead of ''-u(e)''."
	end
	
	local stem = pron((data.pronstem or data.stem) .. "clu")
	local stem2 = stem .. "."
	
	data = m_pron.ind_p(data, stem, stem2)
	data = m_pron.ind_ps(data, stem)
	data = m_pron.ind_f(data, stem2)
end

conj["braire"] = function()
	data.forms.pp = "brait"
	data = m_core.make_ind_p(data, "brai", "bray", "brai")
	data = m_core.make_ind_ps_a(data, "bray")
	
	local stem = pron((data.pronstem or data.stem), true) .. "bʁɛ"
	data.prons.pp = stem
	local stem2 = stem .. ".j"
	local stem3 = stem .. "."
	
	data = m_pron.ind_p(data, stem, stem2)
	data = m_pron.ind_ps_a(data, stem2)
	data = m_pron.ind_f(data, stem3)
end

conj["clore"] = function()
	data.notes = "This verb is not conjugated in certain tenses."
	
	data.forms.ppr = "closant"
	data.forms.pp = "clos"
	
	data = m_core.make_ind_p(data, "clo", "clos")
	data.forms.ind_p_3s = "clôt"
	data = m_core.make_ind_i(data, "—")
	data = m_core.make_ind_ps(data, "—")
	
	local stem = pron((data.pronstem or data.stem) .. "clo")
	local stem2 = stem .. ".z"
	local stem3 = stem .. "z"
	local stem4 = pron((data.pronstem or data.stem) .. "clɔ") .. "."
	
	data.prons.pp = stem
	
	data = m_pron.ind_p(data, stem, stem2, stem3)
	data = m_pron.ind_f(data, stem4)
end

conj["confire"] = function()
	data = m_core.make_ind_p(data, "confi", "confis")
	data = m_core.make_ind_ps(data, "confi")
	
	local stem = pron((data.pronstem or data.stem) .. "confi")
	local stem2 = stem .. ".z"
	local stem3 = stem .. "z"
	local stem4 = stem .. "."
	
	data = m_pron.ind_p(data, stem, stem2, stem3)
	data = m_pron.ind_ps(data, stem)
	data = m_pron.ind_f(data, stem4)
end

conj["coudre"] = function()
	data.notes = "This verb "
	if data.stem ~= "" then
		data.notes = data.notes .. "is conjugated like " .. link("coudre") .. ". That means it"
	end
	data.notes = data.notes .. " is conjugated like " .. link("rendre") .. ", except that its stem is ''{stem}coud-'' in only part of the conjugation. "
	data.notes = data.notes .. "Before endings that begin with vowels, the stem ''{stem}cous-'' (with a " .. IPA("/-z-/") .. " sound) is used instead; "
	data.notes = data.notes .. "for example, ''nous'' " .. link("{stem}cousons") .. ", not ''*nous {stem}coudons''."
	
	data.forms.pp = "cousu"
	
	data = m_core.make_ind_p(data, "coud", "cous")
	data.forms.ind_p_3s = "coud"
	data = m_core.make_ind_ps(data, "cousi")
	
	local stem = pron((data.pronstem or data.stem) .. "cou",true)
	local stem2 = stem .. ".z"
	local stem3 = stem .. "z"
	local stem4 = stem .. ".zi"
	local stem5 = stem .. ".d"
	
	data.prons.pp = stem2 .. "y"
	
	data = m_pron.ind_p(data, stem, stem2, stem3)
	data = m_pron.ind_ps(data, stem4)
	data = m_pron.ind_f(data, stem5)
end

conj["croire"] = function()
	data = m_core.make_ind_p(data, "croi", "croy", "croi")
	data = m_core.make_ind_ps(data, "cru")
	
	local stem = pron((data.pronstem or data.stem) .. "croi")
	local stem2 = stem .. ".j"
	local stem3 = pron((data.pronstem or data.stem) .. "cru")
	
	data = m_pron.ind_ps(data, stem, stem2)
	data = m_pron.ind_ps(data, stem3)
	data = m_pron.ind_f(data, stem .. ".")
end

conj["croitre"] = function()
	if data.stem == "" then
		data.notes = "This verb takes an especially irregular conjugation, taking circumflexes in many forms, so as to distinguish from the forms of the verb " .. link("croire") .. "."
		data = m_core.make_ind_p(data, "croî", "croiss")
		data = m_core.make_ind_ps(data, "crû")
		data.forms.ind_ps_1p = "crûmes"
		data.forms.ind_ps_2p = "crûtes"
		data.forms.sub_pa_3s = "crût"
	else
		data.notes = "This verb is conjugated like " .. link("croitre")
		data = m_core.make_ind_p(data, "croi", "croiss")
		data = m_core.make_ind_ps(data, "cru")
	end
	
	local stem = pron((data.pronstem or data.stem) .. "croi")
	local stem2 = stem .. ".s"
	local stem3 = stem .. "s"
	local stem4 = pron((data.pronstem or data.stem) .. "cru")
	local stem5 = stem .. ".t"
	
	data = m_pron.ind_p(data, stem, stem2, stem3)
	data = m_pron.ind_ps(data, stem4)
	data = m_pron.ind_f(data, stem5)
end

conj["croître"] = function()
	if data.stem == "" then
		data.notes = "This verb takes an especially irregular conjugation, taking circumflexes in many forms, so as to distinguish from the forms of the verb " .. link("croire") .. "."
		data = m_core.make_ind_p(data, "croî", "croiss")
		data = m_core.make_ind_ps(data, "crû")
	else
		data.notes = "This verb is conjugated like " .. link("croître")
		data = m_core.make_ind_p(data, "croi", "croiss")
		data.forms.ind_p_3s = "croît"
		data = m_core.make_ind_ps(data, "crû")
	end
	data.forms.ind_ps_1p = "crûmes"
	data.forms.ind_ps_2p = "crûtes"
	data.forms.sub_pa_3s = "crût"
	
	local stem = pron((data.pronstem or data.stem) .. "croi")
	local stem2 = stem .. ".s"
	local stem3 = stem .. "s"
	local stem4 = pron((data.pronstem or data.stem) .. "cru")
	local stem5 = stem .. ".t"
	
	data = m_pron.ind_p(data, stem, stem2, stem3)
	data = m_pron.ind_ps(data, stem4)
	data = m_pron.ind_f(data, stem5)
end

conj["foutre"] = function()
	data.forms.pp = "foutu"
	
	data = m_core.make_ind_p(data, "fou", "fout")
	data = m_core.make_ind_ps(data, "fouti")
	
	local stem = pron((data.pronstem or data.stem) .. "fou")
	local stem2 = stem .. ".t"
	local stem3 = stem .. "t"
	local stem4 = stem .. ".ti"
	
	data.prons.pp = stem .. ".ty"
	
	data = m_pron.ind_p(data, stem, stem2, stem3)
	data = m_pron.ind_ps(data, stem4)
	data = m_pron.ind_f(data, stem2)
end

conj["soudre"] = function()
	data.forms.pp = "sous"
	
	data = m_core.make_ind_p(data, "sou", "solv")
	data = m_core.make_ind_ps(data, "solu")
	data = m_core.make_sub_pa(data, "—")
	
	local root = mw.ustring.gsub(pron((data.pronstem or data.stem) .. "sou"),"u$","")

	local stem = root .. "u"
	local stem2 = root .. "ɔl.v"
	local stem3 = root .. "ɔlv"
	local stem4 = root .. "ɔ.ly"
	local stem5 = root .. "u.d"
	
	data.prons.pp = stem
	
	data = m_pron.ind_p(data, stem, stem2, stem3)
	data = m_pron.ind_ps(data, stem4)
	data = m_pron.ind_f(data, stem5)
end

conj["voir"] = function()
	data.forms.pp = "vu"
	
	data = m_core.make_ind_p(data, "voi", "voy", "voi")
	data = m_core.make_ind_ps(data, "vi")
	data = m_core.make_ind_f(data, "verr")
	
	local root = mw.ustring.gsub(pron((data.pronstem or data.stem) .. "vou"),"u$","")

	local stem = root .. "wa"
	local stem2 = root .. "wa.j"
	local stem3 = root .. "ɛ."
	local stem4 = root .. "i"
	
	data.prons.pp = root .. "y"
	
	data = m_pron.ind_p(data, stem, stem2)
	data = m_pron.ind_ps(data, stem4)
	data = m_pron.ind_f(data, stem3)
end

conj["cevoir"] = function()
	data = m_core.make_ind_p(data, "çoi", "cev", "çoiv")
	data = m_core.make_ind_ps(data, "çu")
	data = m_core.make_ind_f(data, "cevr")
	
	local root = mw.ustring.gsub(pron((data.pronstem or data.stem) .. "ci"),"i$","")

	local stem = root .. "wa"
	local stem2 = root .. "ə.v"
	local stem3 = root .. "wav"
	local stem4 = root .. "y"
	
	data = m_pron.ind_p(data, stem, stem2, stem3)
	data = m_pron.ind_ps(data, stem4)
	data = m_pron.ind_f(data, stem2)
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
	
	data.forms.pp = "battu"
	
	data = m_core.make_ind_p(data, "bat", "batt")
	data.forms.ind_p_3s = "bat"
	data = m_core.make_ind_ps(data, "batti")
	
	local root = pron((data.pronstem or data.stem) .. "ba")

	local stem = root
	local stem2 = root .. ".t"
	local stem3 = root .. "t"
	local stem4 = root .. ".ti"
	
	data.prons.pp = root .. ".ty"
	
	data = m_pron.ind_p(data, stem, stem2, stem3)
	data = m_pron.ind_ps(data, stem4)
	data = m_pron.ind_f(data, stem2)
end

conj["circoncire"] = function()
	data = m_core.make_ind_p(data, "circonci", "circoncis")
	data = m_core.make_ind_ps(data, "circonci")
	data.forms.pp = "circoncis"
	
	local stem = "siʁ.kɔ̃.si"
	local stem2 = "siʁ.kɔ̃.si.z"
	local stem3 = "siʁ.kɔ̃.siz"
	local stem4 = "siʁ.kɔ̃.si"
	local stem5 = "siʁ.kɔ̃.si."
	
	data = m_pron.ind_p(data, stem, stem2, stem3)
	data = m_pron.ind_ps(data, stem4)
	data = m_pron.ind_f(data, stem5)
end

conj["lire"] = function()
	data = m_core.make_ind_p(data, "li", "lis")
	data = m_core.make_ind_ps(data, "lu")
	
	local stem = data.pron((data.pronstem or data.stem) .. "li")
	local stem2 = stem .. ".z"
	local stem3 = stem .. "z"
	local stem4 = data.pron((data.pronstem or data.stem) .. "lu")
	local stem5 = stem .. "."
	
	data = m_pron.ind_p(data, stem, stem2, stem3)
	data = m_pron.ind_ps(data, stem4)
	data = m_pron.ind_f(data, stem5)
end

conj["luire"] = function()
	data.forms.pp = "lui"
	data = m_core.make_ind_p(data, "lui", "luis")
	data = m_core.make_ind_ps(data, "lui/luisi")
	data = m_core.make_sub_pa(data, "luisi")
	data.forms.ind_ps_3s = "luit"
	
	local stem = pron((data.pronstem or data.stem) .. "lui")
	local stem2 = stem .. ".z"
	local stem3 = stem .. "z"
	local stem4 = stem .. "/" .. stem2 .. "i"
	local stem5 = stem .. "."
	
	data.prons.pp = stem
	
	data = m_pron.ind_p(data, stem, stem2, stem3)
	data = m_pron.ind_ps(data, stem4)
	data = m_pron.sub_pa(data, stem2)
	data = m_pron.ind_f(data, stem5)
	
	data.prons.ind_ps_3s = stem
end

conj["maudire"] = function()
	data.notes = "This is ''almost'' a regular verb of the second conjugation, like " .. link("finir") .. ", " .. link("choisir") .. ", "
	data.notes = data.notes .. "and most other verbs with infinitives ending in " .. link("-ir") .. ". Its only irregularities are in the past participle, "
	data.notes = data.notes .. "which is " .. link("maudit","maudit(e)(s)") .. " rather than *''maudi(e)(s)'', and in the infinitive, "
	data.notes = data.notes .. "which is ''maudire'' rather than *''maudir''."
	
	data.forms.pp = "maudit"
	
	data = m_core.make_ind_p("maudi", "maudiss")
	data = m_core.make_ind_ps("maudi")
	
	local stem = pron((data.pronstem or data.stem) .. "maudi")
	local stem2 = stem .. ".s"
	local stem3 = stem .. "s"
	local stem4 = stem .. "."
	
	data = m_pron.ind_p(data, stem, stem2, stem3)
	data = m_pron.ind_ps(data, stem)
	data = m_pron.ind_f(data, stem4)
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
	
	data.forms.pp =  "mis"
	
	data = m_core.make_ind_p(data, "met", "mett")
	data.forms.ind_p_3s = "met"
	data = m_core.make_ind_ps(data, "mi")
	
	local root = mw.ustring.gsub(pron((data.pronstem or data.stem) .. "ma"), "a$", "")

	local stem = root .. "ɛ"
	local stem2 = root .. "ɛ.t"
	local stem3 = root .. "ɛt"
	local stem4 = root .. "i"
	
	data = m_pron.ind_p(data, stem, stem2, stem3)
	data = m_pron.ind_ps(data, stem4)
	data = m_pron.ind_f(data, stem2)
end

conj["moudre"] = function()
	data = m_core.make_ind_p(data, "moud", "moul")
	data = m_core.make_ind_ps(data, "moulu")
	
	data.forms.ind_p_3s = "moud"
	
	local stem = pron((data.pronstem or data.stem) .. "mou")
	local stem2 = stem .. ".l"
	local stem3 = stem .. "l"
	local stem4 = stem .. ".ly"
	local stem5 = stem .. ".d"
	
	data = m_pron.ind_p(data, stem, stem2, stem3)
	data = m_pron.ind_ps(data, stem4)
	data = m_pron.ind_f(data, stem5)
end

conj["mouvoir"] = function()
	if data.stem == "" then
		data.forms.pp = "mû"
	end
	
	data = m_core.make_ind_p(data, "meu", "mouv", "meuv")
	data = m_core.make_ind_ps(data, "mu")
	data = m_core.make_ind_f(data, "mouvr")
	
	local stem = pron((data.pronstem or data.stem) .. "meu")
	local stem2 = pron((data.pronstem or data.stem) .. "mou") .. ".v"
	local stem3 = pron((data.pronstem or data.stem) .. "meuve")
	local stem4 = pron((data.pronstem or data.stem) .. "mu")
	
	data = m_pron.ind_p(data, stem, stem2, stem3)
	data = m_pron.ind_ps(data, stem4)
	data = m_pron.ind_f(data, stem2)
end

conj["paître"] = function()
	data.notes = "This verb is not conjugated in certain tenses."
	
	data = m_core.make_ind_p(data, "pai", "paiss")
	data.forms.ind_p_3s = "paît"
	data = m_core.make_ind_ps(data, "—")
	
	local stem = pron((data.pronstem or data.stem) .. "pais")
	local stem2 = stem .. ".s"
	local stem3 = stem .. "s"
	local stem4 = stem .. ".t"
	
	data = m_pron.ind_p(data, stem, stem2, stem3)
	data = m_pron.ind_f(data, stem4)
end

conj["paitre"] = function()
	data.notes = "This verb is not conjugated in certain tenses."
	
	data = m_core.make_ind_p(data, "pai", "paiss")
	data = m_core.make_ind_ps(data, "—")
	
	local stem = pron((data.pronstem or data.stem) .. "pais")
	local stem2 = stem .. ".s"
	local stem3 = stem .. "s"
	local stem4 = stem .. ".t"
	
	data = m_pron.ind_p(data, stem, stem2, stem3)
	data = m_pron.ind_f(data, stem4)
end


conj["pleuvoir"] = function()
	data.notes = "This is a [[defective]] verb, only conjugated in the [[third-person]]. The [[third-person plural]] forms are only used figuratively."
	
	data.forms.ppr = "pleuvant"
	data.forms.pp = "plu"
	
	data = m_core.make_ind_p(data, "—")
	data = m_core.make_ind_ps(data, "—")
	data = m_core.make_ind_f(data, "—")
	data.forms.ind_p_3s = "pleut"
	data.forms.ind_p_3p = "pleuvent"
	data.forms.ind_i_3s = "pleuvait"
	data.forms.ind_i_3p = "pleuvaient"
	data.forms.ind_ps_3s = "plut"
	data.forms.ind_ps_3p = "plurent"
	data.forms.ind_f_3s = "pleuvra"
	data.forms.ind_f_3p = "pleuvront"
	data.forms.cond_p_3s = "pleuvrait"
	data.forms.cond_p_3p = "pleuvraient"
	data.forms.sub_p_3s = "pleuve"
	data.forms.sub_p_3p = "pleuvent"
	data.forms.sub_pa_3s = "plût"
	data.forms.sub_pa_3p = "plussent"
	
	data.prons.ppr = "plø.vɑ̃"
	data.prons.pp = "ply"
	
	data.prons.ind_p_3s = "plø"
	data.prons.ind_p_3p = "plø"
	data.prons.ind_i_3s = "plœ.vɛ"
	data.prons.ind_i_3p = "plœ.vɛ"
	data.prons.ind_ps_3s = "ply"
	data.prons.ind_ps_3p = "plyʁ"
	data.prons.ind_f_3s = "plœ.vʁa"
	data.prons.ind_f_3p = "plœ.vʁɔ̃"
	data.prons.cond_p_3s = "plœ.vʁɛ"
	data.prons.cond_p_3p = "plœ.vʁɛ"
	data.prons.sub_p_3s = "plœv"
	data.prons.sub_p_3p = "plœv"
	data.prons.sub_pa_3s = "ply"
	data.prons.sub_pa_3p = "plys"
	
	data.typ = "irregular"
end

conj["pourvoir"] = function()
	data.notes = "''Pourvoir'' and its derived verbs conjugate like " .. link("voir") .. ", except that their past historic indicative and imperfect subjunctive are in ''-vu-'' instead of ''-vi-''."
	
	data.forms.pp = "vu"
	
	data = m_core.make_ind_p(data, "pourvoi", "pourvoy", "pourvoi")
	data = m_core.make_ind_ps(data, "pourvu")
	data = m_core.make_ind_f(data, "pourvoir")
	
	local root = mw.ustring.gsub(pron((data.pronstem or data.stem) .. "pourvou"),"u$","")

	local stem = root .. "wa"
	local stem2 = root .. "wa.j"
	local stem3 = root .. "wa."
	local stem4 = root .. "y"
	
	data.prons.pp = root .. "y"
	
	data = m_pron.ind_p(data, stem, stem2)
	data = m_pron.ind_ps(data, stem4)
	data = m_pron.ind_f(data, stem3)
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
	
	data.forms.pp = "pris"
	
	data = m_core.make_ind_p(data, "prend", "pren", "prenn")
	data.forms.ind_p_3s = "prend"
	data = m_core.make_ind_ps(data, "pri")
	
	local root = mw.ustring.gsub(pron((data.pronstem or data.stem) .. "pra"), "a$", "")

	local stem = root .. "ɑ̃"
	local stem2 = root .. "ə.n"
	local stem3 = root .. "ɛn"
	local stem4 = root .. "i"
	
	data = m_pron.ind_p(data, stem, stem2, stem3)
	data = m_pron.ind_ps(data, stem4)
	data = m_pron.ind_f(data, stem2)
end

conj["faire"] = function()
	data.forms.pp = "fait"
	
	data = m_core.make_ind_p(data, "fai", "fais")
	data.forms.ind_p_2p = "faites"
	data.forms.ind_p_3p = "font"
	data = m_core.make_ind_ps(data, "fi")
	data = m_core.make_ind_f(data, "fer")
	data = m_core.make_sub_p(data, "fass")
	data = m_core.make_imp_p_ind(data)
	
	local root = mw.ustring.gsub(pron((data.pronstem or data.stem) .. "fa"), "a$", "")

	local stem = root .. "ɛ"
	local stem2 = root .. "ə.z"
	local stem3 = root .. "i"
	local stem4 = root .. "ə."
	local stem5 = root .. "a.s"
	local stem6 = root .. "as"
	
	data.prons.ppr = stem2 .. "ɑ̃"
	data.prons.pp = stem
	
	data = m_pron.ind_p(data, stem, stem2)
	data.prons.ind_p_2p = root .. "ɛt"
	data.prons.ind_p_3p = root .. "ɔ̃"
	data = m_pron.ind_ps(data, stem3)
	data = m_pron.ind_f(data, stem4)
	data = m_pron.sub_p(data, stem6, stem5)
	data.prons.imp_p_2p = root .. "ɛt"
end

conj["boire"] = function()
	data = m_core.make_ind_p(data, "boi", "buv", "boiv")
	data = m_core.make_ind_ps(data, "bu")
	
	local root = mw.ustring.gsub(pron((data.pronstem or data.stem) .. "bi"),"i$","")

	local stem = root .. "wa"
	local stem2 = root .. "y.v"
	local stem3 = root .. "wav"
	local stem4 = root .. "y"
	
	data = m_pron.ind_p(data, stem, stem2, stem3)
	data = m_pron.ind_ps(data, stem4)
	data = m_pron.ind_f(data, stem .. ".")
end

conj["devoir"] = function()
	data = m_core.make_ind_p(data, "doi", "dev", "doiv")
	data = m_core.make_ind_ps(data, "du")
	data = m_core.make_ind_f(data, "devr")
	if data.stem == "" then
		data.forms.pp = "dû"
	end
	
	local stem = pron((data.pronstem or data.stem) .. "doi")
	local stem2 = pron((data.pronstem or data.stem) .. "de",true) .. ".v"
	local stem3 = stem .. "v"
	local stem4 = pron((data.pronstem or data.stem) .. "du")
	
	data = m_pron.ind_p(data, stem, stem2, stem3)
	data = m_pron.ind_ps(data, stem4)
	data = m_pron.ind_f(data, stem2)
end

conj["avoir"] = function()
	data.forms.ppr = "ayant"
	
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
	
	local root = mw.ustring.gsub(pron((data.pronstem or data.stem) .. "a"),"a$","")
	
	local stem = root .. "a"
	local stem2 = root .. "a.v"
	local stem3 = root .. "y"
	local stem4 = root .. "o."
	local stem5 = root .. "ɛ"
	local stem6 = root .. "ɛ."
	
	data.prons.ppr = stem6 .. "jɑ̃"
	
	data = m_pron.ind_p(data, stem, stem2)
	data.prons.ind_p_1s = root .. "e"
	data.prons.ind_p_3p = root .. "ɔ̃"
	data = m_pron.ind_ps(data, stem3)
	data = m_pron.ind_f(data, stem4)
	data = m_pron.sub_p(data, stem5, stem6)
	
	data.prons.imp_p_2s = stem5
	data.prons.imp_p_1p = stem6 .. "jɔ̃"
	data.prons.imp_p_2p = stem6 .. "je"
end

conj["être"] = function()
	data.forms.pp = "été"
	data.forms.ppr = "étant"
	
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
	
	local root_s = mw.ustring.gsub(pron((data.pronstem or data.stem) .. "sa"),"sa$","")
	local root_e = mw.ustring.gsub(pron((data.pronstem or data.stem) .. "é"),"e$","")
	local root_f = mw.ustring.gsub(pron((data.pronstem or data.stem) .. "fa"),"fa$","")
	
	local stem = root_e .. "ɛ"
	local stem2 = root_e .. "e.t"
	local stem3 = root_f .. "fy"
	local stem4 = root_s .. "sə."
	local stem5 = root_s .. "swa"
	local stem6 = root_s .. "swa."
	
	data.prons.ppr = stem2 .. "ɑ̃"
	data.prons.pp = stem2 .. "e"
	
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
end

conj["estre"] = function()
	conj["être"]()
	
	for key,val in pairs(data.forms) do
		data.forms[key] = mw.ustring.gsub(val, "[éê]", "es")
		data.forms[key] = mw.ustring.gsub(data.forms[key], "û", "us")
		data.forms[key] = mw.ustring.gsub(data.forms[key], "ai", "oi")
	end
	
	data.forms.pp = "esté"
	
	data.forms.ind_ps_1p = "fumes"
	data.forms.sub_pa_3s = "fust"
end

conj["naître"] = function()
	data.forms.pp = "né"
	
	data = m_core.make_ind_p(data, "nai", "naiss")
	data.forms.ind_p_3s = "naît"
	data = m_core.make_ind_ps(data, "naqui")
	
	local stem = pron((data.pronstem or data.stem) .. "nais")
	local stem2 = stem .. ".s"
	local stem3 = stem .. "s"
	local stem4 = pron((data.pronstem or data.stem) .. "naquis")
	local stem5 = stem .. ".t"
	
	data.prons.pp = pron((data.pronstem or data.stem) .. "né")
	
	data = m_pron.ind_p(data, stem, stem2, stem3)
	data = m_pron.ind_ps(data, stem4)
	data = m_pron.ind_f(data, stem5)
end

conj["naitre"] = function()
	data.forms.pp = "né"
	
	data = m_core.make_ind_p(data, "nai", "naiss")
	data = m_core.make_ind_ps(data, "naqui")
	
	local stem = pron((data.pronstem or data.stem) .. "nais")
	local stem2 = stem .. ".s"
	local stem3 = stem .. "s"
	local stem4 = pron((data.pronstem or data.stem) .. "naquis")
	local stem5 = stem .. ".t"
	
	data.prons.pp = pron((data.pronstem or data.stem) .. "né")
	
	data = m_pron.ind_p(data, stem, stem2, stem3)
	data = m_pron.ind_ps(data, stem4)
	data = m_pron.ind_f(data, stem5)
end

conj["envoyer"] = function()
	data.notes = "This verb is is one a few verbs that conjugate like " .. link("noyer") .. ", except in the future and conditional, where they conjugate like " .. link("voir") .. "."
	
	data = m_core.make_ind_p_e(data, "envoi", "envoy", "envoy")
	data = m_core.make_ind_f(data, "enverr")
	
	local stem = pron((data.pronstem or data.stem) .. "envoi")
	local stem2 = stem .. ".j"
	local stem3 = pron((data.pronstem or data.stem) .. "envè") .. "."
	
	data = m_pron.er(data, stem, stem2)
	data = m_pron.ind_f(data, stem3)
end

conj["irreg-aller"] = function()
	data.notes = "The verb ''{stem}aller'' has a unique and highly irregular conjugation. The second-person singular imperative ''[[va]]'' additionally combines with ''[[y]]'' to form ''[[vas-y]]'' instead of the expected ''va-y''."
	
	data = m_core.make_ind_p_e(data, "all")
	data.forms.ind_p_1s = "vais"
	data.forms.ind_p_2s = "vas"
	data.forms.ind_p_3s = "va"
	data.forms.ind_p_3p = "vont"
	data = m_core.make_ind_f(data, "ir")
	data = m_core.make_sub_p(data, "aill")
	data = m_core.make_imp_p_ind(data)
	
	local stem = pron((data.pronstem or data.stem) .. "a")
	local stem2 = pron((data.pronstem or data.stem) .. "i")
	local stem3 = pron((data.pronstem or data.stem) .. "vé")
	
	stem3 = mw.ustring.gsub(stem3, ".$", "")
	
	data = m_pron.er(data, stem .. "l", stem .. ".l")
	data = m_pron.ind_f(data, stem2)
	data = m_pron.sub_p(data, stem .. "j", stem .. "j.")
	data.prons.ind_p_1s = stem3 .. "ɛ"
	data.prons.ind_p_2s = stem3 .. "a"
	data.prons.ind_p_3s = stem3 .. "a"
	data.prons.ind_p_3p = stem3 .. "ɔ̃"
	data.prons.imp_p_2s = stem3 .. "a"
end

conj["dire"] = function()
	data.forms.pp = "dit"
	
	data = m_core.make_ind_p(data, "di", "dis")
	data = m_core.make_ind_ps(data, "di")
	
	local stem = pron((data.pronstem or data.stem) .. "di")
	local stem2 = stem .. ".z"
	local stem3 = stem .. "z"
	local stem4 = stem .. "."
	
	data = m_pron.ind_p(data, stem, stem2, stem3)
	data = m_pron.ind_ps(data, stem)
	data = m_pron.ind_f(data, stem4)
	
	if data.stem == "" or data.stem == "re" then
		data.forms.ind_p_2p = "dites"
		data.prons.ind_p_2p = stem .. "t"
		data.forms.imp_p_2p = "dites"
		data.prons.imp_p_2p = stem .. "t"
	else
		data.notes = "This verb is one of a group of " .. link("-re") .. " verbs all ending in ''-dire''. "
		data.notes = data.notes .. "They are conjugated exactly like " .. link("dire") .. ", "
		data.notes = data.notes .. "but with a different second-person plural indicative present (that is, like " .. link("confire") .. "). "
		data.notes = data.notes .. "Members of this group include " .. link(data.stem == "contre" and "dédire" or "contredire") .. " and "
		data.notes = data.notes .. link(data.stem == "inter" and "dédire" or "interdire") .. "."
	end
end

conj["vivre"] = function()
	data = m_core.make_ind_p(data, "vi", "viv")
	data = m_core.make_ind_ps(data, "vécu")
	
	local stem = pron((data.pronstem or data.stem) .. "vi")
	local stem2 = stem .. ".v"
	local stem3 = stem .. "v"
	local stem4 = pron((data.pronstem or data.stem) .. "vécu")
	
	data = m_pron.ind_p(data, stem, stem2, stem3)
	data = m_pron.ind_ps(data, stem4)
	data = m_pron.ind_f(data, stem2)
end

conj["mourir"] = function()
	data.forms.pp = "mort"
	
	data = m_core.make_ind_p(data, "meur", "mour", "meur")
	data = m_core.make_ind_ps(data, "mouru")
	data = m_core.make_ind_f(data, "mourr")
	
	local stem = pron((data.pronstem or data.stem) .. "meur")
	local stem2 = pron((data.pronstem or data.stem) .. "mou") .. ".ʁ"
	local stem3 = pron((data.pronstem or data.stem) .. "mouru")
	local stem4 = pron((data.pronstem or data.stem) .. "mou") .. "."
	
	data.prons.pp = pron((data.pronstem or data.stem) .. "mort")
	
	data = m_pron.ind_p(data, stem, stem2)
	data = m_pron.ind_ps(data, stem3)
	data = m_pron.ind_f(data, stem4)
end

local function conjugate(typ)
	data.forms.inf = typ
	local future_stem = mw.ustring.gsub(data.forms.inf, "e$", "")
	data = m_core.make_ind_f(data, future_stem)
	
	if mw.ustring.match(typ,"^[^aeéiou]er$") and typ ~= "cer" and typ ~= "ger"  and typ ~= "yer" then
		conj["xxer"](mw.ustring.gsub(typ,"er$",""))
	elseif mw.ustring.match(typ,"^e[^aeiou]+er$") and typ ~= "ecer" and typ ~= "eger"  and typ ~= "eyer" then
		conj["e-er"](mw.ustring.gsub(typ,"^e(.+)er$","%1"))
	elseif mw.ustring.match(data.stem .. typ,"é[^aàâeéèêiîoôuûäëïöü]+er$") and typ ~= "écer" and typ ~= "éger"  and typ ~= "éyer" then
		local root = data.stem .. typ
		data.stem = mw.ustring.gsub(root,"é[^aàâeéèêiîoôuûäëïöü]+er$","")
		data.forms.inf = mw.ustring.match(root,"(é[^aàâeéèêiîoôuûäëïöü]+er)$")
		conj["é-er"](mw.ustring.gsub(data.forms.inf,"^é(.+)er$","%1"))
	elseif alias[typ] then
		data.stem = data.stem .. mw.ustring.gsub(typ, alias[typ], "")
		data.forms.inf = alias[typ]
		conj[alias[typ]]()
	elseif conj[typ] then
		conj[typ]()
	elseif typ ~= "" then
		error('The type "' .. typ .. '" is not recognized')
	end
end

local function auto(pagename)
	local stem = ""
	local typ = pagename
	while typ ~= "" do
		if conj[typ] then break end
		if alias[typ] then
			stem = stem .. mw.ustring.gsub(typ,alias[typ].."$","")
			typ = alias[typ]
			break
		end
		stem = stem .. mw.ustring.gsub(typ,"^(.).*$","%1")
		typ = mw.ustring.gsub(typ,"^.","")
	end
	if typ == "" then
		return "",""
	end
	return stem,typ
end

function export.show(frame)
	local args = clone_args(frame)
	local stem = args[1] or ""
	local typ = args[2] or ""
	if typ == "" then typ = stem; stem = ""; end
	data = {
		refl = false,
		stem = stem,
		aux = "avoir",
		forms = {},
		prons = {}
	}
	
	if stem .. typ == "" then
		data.stem, typ = auto(PAGENAME)
	elseif stem == "" and mw.ustring.find(PAGENAME, typ, 1, true) and mw.ustring.find(PAGENAME, typ, 1, true) == 1 and typ ~= PAGENAME then
		data.stem = typ
		typ = mw.ustring.sub(PAGENAME, mw.ustring.len(typ) + 1)
	elseif stem == "" then
		data.stem, typ = auto(typ)
	end
	
	if args["pronstem"] then
		error("pronstem= not currently supported")
	end
	
	data.pronstem = args["pronstem"]
	
	conjugate(typ)
	
	data = m_core.extract(data, args)
	
	if data.notes then data.notes = mw.ustring.gsub(data.notes, "{stem}", data.stem) end
	for key,val in pairs(data.forms) do
		if type(val) == "table" then
			for i,form in ipairs(val) do
				data.forms[key][i] = data.stem .. form
			end
		else
			data.forms[key] = data.stem .. val
		end
	end
	
	if args.refl then data = m_core.refl(data) end
	
	if etre[data.forms.inf] then
		data.aux = "être"
	elseif avoir_or_etre[data.forms.inf] then
		data.aux = "avoir or être"
	end
	
	if stem == "ressor" and type == "tir" then
		data.aux = "avoir or être"
	elseif stem == "dépar" and type == "tir" then
		data.aux = "être"
	end
	
	data.forms.inf_nolink = data.forms.inf_nolink or data.forms.inf
	data.forms.ppr_nolink = data.forms.ppr_nolink or data.forms.ppr
	data.forms.pp_nolink = data.forms.pp_nolink or data.forms.pp
	
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
