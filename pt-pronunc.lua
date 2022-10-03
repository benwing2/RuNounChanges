--[=[
This module implements the template {{pt-IPA}}.

Author: Benwing

-- FIXME:

1. Implement i^ not before vowel = epenthetic i or deleted epenthetic i in Brazil (in that order), and i^^ not before
   vowel = opposite order. Epenthetic i should not affect stress but should otherwise be treated like a normal vowel.
   Deleted epenthetic i should trigger palatalization of t/d but have no other effects. [DONE]
2. Implement i^ before vowel = i.V or yV (in that order), and i^^ before vowel = opposite order.
3. Implement i* = mandatory epenthetic i in Brazil.
4. Implement o^ = o or u in Brazil (in that order), and o^^ = opposite order.
5. Implement e^ = e or i in Brazil (in that order), and e^^ = opposite order.
6. Implement é* = é in Portugal, ê in Brazil (useful especially before nasal consonants).
6. Implement ó* = ó in Portugal, ô in Brazil (useful especially before nasal consonants).
6. Implement des^ at beginning of word = /dis+/ or /des/ in Brazil (in that order), and des^^ = opposite order.
7. In Portugal, before [ɫ], unstressed 'a' should be /a/; unstressed 'e' should be /ɛ/; and unstressed 'o' should be
   either /o/ or /ɔ/ (in that order).
8. Support qualifiers using <q:...> and <qq:...>.
9. Support references using <ref:...>. Syntax is the same as for IPA ref=.
10. In Portugal, unstressed o in hiatus should be /w/, and unstressed e in hiatus should be /j/.
11. Support - (hyphen) = left and right parts should be treated as distinct phonological words but written joined
    together, and non-final primary stresses turn into secondary stresses. Word-initial and word-final behavior should
	happen, e.g. Brazil epenthesis of (j) before word-final /s/ followed a stressed vowel, Brazil raising of esC- and
	Portugal rendering of o- as ò-, but syllabification should ignore the hyphen, e.g. if the hyphen follows a
	consonant and precedes a vowel, the syllable division should happen before the consonant as normal.
12. Support : (colon), similar to hyphen but in non-final parts, final vowels aren't rendered as closed.
13. Support + (colon), similar to colon but non-final primary stresses aren't displayed.
14. In Brazil, word-initial enC-, emC- should display as (careful pronunciation) ẽ-, (natural pronunciation) ĩ-.
15. In Portugal, -sç- and -sc(e/i)- should show as (careful pronunciation) /ʃs/, (natural pronunciation) /ʃ/.
16. In Portugal, grave accent indicates unstressed open a/e/o and macron indicates unstressed closed a/e/o; both are
    ignored in Brazil.
17. In Portugal, iCi where the first i is before the stress should (maybe) show as iCi, (traditional pronunciation) ɨCi.
    In iCiCi, both of the first two i's show as ɨ in the traditional pronunciation (FIXME: verify this). C should be
	only a single consonant, hence not in [[piscina]] or [[distrito]] (FIXME: verify this). Does not apply if the first
	i is stressed (e.g. [[mínimo]], [[tília]], [[pírico]], [[tísica]]) or if the stressed i is word-final ([[Mimi]],
	[[Lili]], [[chichizinho]], [[piripiri]]), or in certain other words ([[felicíssimo]], [[filhinho]], [[estilista]],
	[[pirite]]). Possibly this means it doesn't apply when the stressed i is in a suffix (-íssimo, -inho, -ista). We
	can always disable the eCi spelling by adding an h in 'ihCi' to make it look like a cluster between the i's. NOTE:
	It appears that iCi -> eCi should apply in [[dicionário]], meaning if we apply it at the end, we have to distinguish
	between glides from original i and glides from e or y.
18. In Portugal and Brazil, stressed o in hiatus should automatically be ô (voo, Samoa, Alagoas, perdoe, abençoe). [DONE]
19. In Portugal, stressed closed ô in hiatus (whether written explicitly as e.g. vôo, Côa or generated automatically)
    should show as e.g. /ˈbo.ɐ/, (regional) /ˈbo.wɐ/. (FIXME: Verify syllable division in second.) [DONE]
20. Recognize -zinha like -zinho, -mente. Just use hyphen (-) to handle these. We don't recognize -zão, -zona, -zito,
    -zita because of too many false positives; you can just write the hyphen explicitly before the suffix as needed.
	Cf. among our current vocabulary we have 10 -zão augmentatives (animalzão, aviãozão, cipozão, cuzão, homenzão,
	leãozão, paizão, pãozão, pezão, tatuzão), 2 -ão augmentatives after a word ending in -z (codornizão, felizão), and
	7 non-augmentatives (alazão, coalizão, razão, rezão, sazão, sezão, vazão). Similarly for -zona: we have 5 -zona
	augmentatives (boazona, cuzona, maçãzona, mãezona, mãozona) against 8 non-augmentatives (amazona, aminofenazona,
	arilidrazona, Arizona, cronozona, ecozona, Eurozona, fenazona) and no -ona augmentatives after words ending in -z.
	For -zito, we have 1 -ito diminutive after a word ending in -z (Queluzito), one non-diminutive (quartzito), and no
	-zito diminutives. For -zita we have 1 -zita diminutive (maçãzita) and 4 non-diminutives (andaluzita, monazita,
	pedzita, stolzita).
21. Final 'r' isn't optional before -zinho, -zinha, -mente.
22. Consider making secondary stress optional in cases like traduçãozinha where the stress is directly before the
    primary stress.
23. In Brazil, unstressed final-syllable /a/ should be reduced even before a final consonant. Cf. [[açúcar]], [[tórax]].
    (Except possibly /l/? FIXME: Verify.)
24. Support + = pagename, and pagename= argument.
25. Deduplicate final pronunciations without distinct qualifiers.
26. Implement support for dot-under without accompanying quality diacritic. When attached to a/e/o, it defaults to acute
    = open pronun, except in the following circumstances, where it defaults to circumflex: (1) in the diphthongs
	ei/eu/oi/ou; (2) in a nasal vowel.
27. Portugal final -e should show as optional (ɨ) unless there is a vowel-initial word following, in which case it
    should not be displayed at all.
28. Syllabification: "Improper" clusters of non-sibiliant-obstruent + obstruent (pt, bt, bd, dk, kt; ps, bs, bv, bʒ, tz,
    dv, ks; ft), non-sibiliant-obstruent + nasal (pn, bn, tm, tn, dm, dn, gm, gn), nasal + nasal (mn) are syllabified in
	Portugal as .pt, .bv, .mn, etc. Note ʃ.t, ʃ.p, ʃ.k, etc. But in Brazil, all of these divide between the consonants
	(p.t, b.v, ʃ.t, s.p, etc.). Particular case: [[ab-rogação]] divides as a.brr in Portugal but ab.rr in Brazil.
29. -ão, -ãe, -õe should be recognized as nasal diphthongs with a circumflex added to force stress.
30. Recognize obsolete -aõ, -aẽ, -oẽ as equivalent to -ão, -ãe, -õe.
31. In CluV, CruV, CliV, CriV, the 'u' and 'i' are vowels not glides in both Portugal and Brazil.
32. Epenthesis of (j) before final stressed s in Brazil should not happen after i.
33. Dialect markers such as "Brazil", "Portugal" should go at the beginning. [DONE]
34. Portugal exC, êxC should be rendered like eiʃC (FIXME: Does this apply to "Central Portugal" as well?). Unstressed
    word-initial exC- should have two pronunciations, one with eiʃC- and the other with (i)ʃC-. exs- needs handling like
	eiʃs-/(i)ʃs- not like eiss-.
]=]

local export = {}

local m_IPA = require("Module:IPA")
local m_table = require("Module:table")
local m_strutils = require("Module:string utilities")
local m_qual = require("Module:qualifier")

local lang = require("Module:languages").getByCode("pt")

local u = mw.ustring.char
local rfind = mw.ustring.find
local rsubn = mw.ustring.gsub
local rmatch = mw.ustring.match
local rsplit = mw.text.split
local ulower = mw.ustring.lower
local uupper = mw.ustring.upper
local usub = mw.ustring.sub
local ulen = mw.ustring.len

local AC = u(0x0301) -- acute =  ́
local GR = u(0x0300) -- grave =  ̀ = open vowel quality without stress in Portugal only
local MACRON = u(0x0304) -- macron =  ̄ = closed vowel quality without stress in Portugal only
local CFLEX = u(0x0302) -- circumflex =  ̂
local TILDE = u(0x0303) -- tilde =  ̃
local DIA = u(0x0308) -- diaeresis =  ̈
local CEDILLA = u(0x0327) -- cedilla =  ̧
local DOTOVER = u(0x0307) -- dot over =  ̇
-- DOTUNDER indicates an explicitly unstressed syllable; useful when accompanied by a quality marker (acute or
-- circumflex), or by itself with a/e/o, where it defaults to acute (except in the following circumstances, where it
-- defaults to circumflex: (1) in the diphthongs ei/eu/oi/ou; (2) in a nasal vowel).
local DOTUNDER = u(0x0323) -- dot under =  ̣
-- LINEUNDER indicates an explicit secondary stress; normally not necessary as primary stress is converted to secondary
-- stress if another primary stress follows, but can be used e.g. after a primary stress; can be accompanied by a
-- quality marker (acute or circumflex) with a/e/o; if not, defaults to acute (except in the same circumstances where
-- dot under defaults to circumflex).
local LINEUNDER = u(0x0331) -- line under =  ̱
local TEMP1 = u(0xFFF0)
local SYLDIV = u(0xFFF1) -- used to represent a user-specific syllable divider (.) so we won't change it

-- Since we lowercase all symbols at the beginning, we can later use capital letters to represent additional
-- distinctions, typically in cases where we want to remember the source of a given phoneme. We can also use composed
-- Unicode symbols with diacritics on them, since we maintain everything in decomposed format except for ç and ü.
-- Specifically:
-- * A/E/O represent written a/e/o where we don't yet know the vowel quality. Towards the beginning, we convert all
--   written a/e/o to A/E/O and later convert them to their final qualities (which might include /a/ /e/ /o/, so we
--   can't use those symbols directly for this purpose).
-- * I is used to represent epenthetic i in Brazilian variants (which should not affect stress assignment but is
--   otherwise treated as a normal sound), and Ɨ represents deleted epenthetic i (which still palatalizes /t/ and /d/).
-- * Ẽ stands for a word-initial Brazilian sound that can be pronounced either /ẽ/ (in careful speech) or /ĩ/ (in
--   natural speech) and originates from en- or em- before a consonant. We distinguish this from written in-/im-,
--   which can be only /ĩ/, and written ehn-/ehm- (or similar), which can be only /ẽ/.
-- * Ɔ (capital version of ɔ) stands for a Portugal sound that can be pronounced either /o/ or /ɔ/ (depending on the
--   speaker), before syllable-final /l/.
local vowel = "aɐeɛiɨoɔuüAEẼIƗOƆ"
local V = "[" .. vowel .. "]"
local NV_NOT_CFLEX = "[^" .. vowel .. "%^]"
local high_front_vocalic = "iIƗy"
local front_vocalic = "eɛɨẼ" .. high_front_vocalic
local FRONTV = "[" .. front_vocalic .. "]"
-- W stands for regional /w/ between stressed /o/ and a following vowel in hiatus ([[voo]], [[boa]], [[perdoe]]).
local glide = "ywW"
local W = "[" .. glide .. "]" -- glide
local ipa_stress = "ˈˌ"
local ipa_stress_c = "[" .. ipa_stress .. "]"
local quality = AC .. CFLEX .. GR .. MACRON
local quality_c = "[" .. quality .. "]"
local stress = LINEUNDER .. DOTOVER .. DOTUNDER .. ipa_stress
local stress_c = "[" .. stress .. "]"
local non_primary_stress = LINEUNDER .. DOTOVER .. DOTUNDER .. "ˌ"
local non_primary_stress_c = "[" .. non_primary_stress .. "]"
local accent = quality .. stress .. TILDE
local accent_c = "[" .. accent .. "]"
local charsep = accent .. "_." .. SYLDIV
local charsep_c = "[" .. charsep .. "]"
local wordsep = charsep .. " #"
local wordsep_c = "[" .. wordsep .. "]"
local C = "[^" .. vowel .. wordsep .. "]" -- consonant
local C_NOT_H_OR_GLIDE = "[^h" .. glide .. vowel .. wordsep .. "]" -- consonant other than h, w or y
local C_OR_WORD_BOUNDARY = "[^" .. vowel .. charsep .. "]" -- consonant or word boundary
local voiced_cons = "bdgjlʎmnɲŋrɾʁvwyzʒʤ" -- voiced sound

-- Unstressed words with vowel reduction in Brazil and Portugal.
local unstressed_words = require("Module:table").listToSet({
	"o", "os", "la", "las", -- definite articles
	"me", "te", "se", "lhe", "lhes", "nos", "vos", -- unstressed object pronouns
	"mo", "to", "lho", "lhos", -- object pronouns combined with articles
	"que", -- subordinating conjunctions
	"e", -- coordinating conjunctions
	"de", "do", "dos", "no", "por", -- basic prepositions + combinations with articles; [[nos]] above as object pronoun
})

-- Unstressed words with vowel reduction in Portugal only.
local unstressed_full_vowel_words_brazil = require("Module:table").listToSet({
	"a", "as", -- definite articles
	"da", "das", "na", "nas", -- basic prepositions + combinations with articles
	"ma", "ta", "lha", "lhas", -- object pronouns combined with articles
	"mas", -- coordinating conjunctions
})

-- Unstressed words without vowel reduction.
local unstressed_full_vowel_words = require("Module:table").listToSet({
	"um", "uns", -- single-syllable indefinite articles
	"meu", "teu", "seu", "meus", "teus", "seus", -- single-syllable possessives
	"ou", -- coordinating conjunctions
	"ao", "aos", "a" .. GR, "a" .. GR .. "s", -- basic prepositions + combinations with articles
	"em", "com", -- other prepositions
})

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

-- apply rsub() repeatedly until no change
local function rsub_repeatedly(term, foo, bar)
	while true do
		local new_term = rsub(term, foo, bar)
		if new_term == term then
			return term
		end
		term = new_term
	end
end

-- Dialects and subdialects:
export.all_styles = {"gbr", "rio", "sp", "gpt", "cpt", "spt"}
export.all_style_groups = {
	all = export.all_styles,
	br = {"gbr", "rio", "sp"},
	pt = {"gpt", "cpt", "spt"},
}

export.all_style_descs = {
	gbr = "Brazil", -- "general" Brazil
	rio = "Rio de Janeiro", -- Carioca accent
	sp = "São Paulo", -- Paulistano accent
	-- sbr = "Southern Brazil", -- (not added yet)
	gpt = "Portugal", -- "general" Portugal
	-- lisbon = "Lisbon", -- (not added yet)
	cpt = "Central Portugal", -- Central Portugal outside of Lisbon
	spt = "Southern Portugal"
}

local function flatmap(items, fun)
	local new = {}
	for _, item in ipairs(items) do
		local results = fun(item)
		for _, result in ipairs(results) do
			table.insert(new, result)
		end
	end
	return new
end

local function reorder_accents(text, err)
	-- There can conceivably be up to three accents on a vowel: a quality mark (acute/circumflex/grave/macron); a mark
	-- indicating secondary stress (lineunder), tertiary stress (dotunder; i.e. no stress but no vowel reduction) or
	-- forced vowel reduction (dotover); and a nasalization mark (tilde). Order them as follows: quality - stress -
	-- nasalization.
	local function reorder_accent_string(accentstr)
		local accents = rsplit(accentstr, "")
		local accent_order = {
			[AC] = 1,
			[CFLEX] = 1,
			[GR] = 1,
			[MACRON] = 1,
			[LINEUNDER] = 2,
			[DOTUNDER] = 2,
			[DOTOVER] = 2,
			[TILDE] = 3,
		}
		table.sort(accents, function(ac1, ac2)
			return accent_order[ac1] < accent_order[ac2]
		end)
		return table.concat(accents)
	end
	text = rsub(text, "(" .. accent_c .. "+)", reorder_accent_string)
	-- Remove duplicate accents.
	text = rsub_repeatedly(text, "(" .. accent_c .. ")%1", "%1")
	-- Make sure we don't have more than one of a given class.
	if rfind(text, quality_c .. quality_c) then
		err("Two different quality diacritics cannot occur together")
	end
	if rfind(text, stress_c .. stress_c) then
		err("Two different stress diacritics cannot occur together")
	end
	-- Only a/e/o can receive a circumflex, grave or macron.
	if rfind(text, "[^aeo][" .. CFLEX .. GR .. MACRON .. "]") then
		err("Only a/e/o can be followed by circumflex, grave or macron")
	end
	return text
end

local function one_term_ipa(text, style, phonetic, err)
	local brazil = m_table.contains(export.all_style_groups.br, style)
	local portugal = m_table.contains(export.all_style_groups.pt, style)

	-- x
	text = rsub(text, "#x", "#ʃ") -- xérox, xilofone, etc.
	text = rsub(text, "x#", "kç#") -- xérox, córtex, etc.
	text = rsub(text, "(" .. V .. charsep_c .. "*[iu]" .. charsep_c .. "*)x", "%1ʃ") -- baixo, peixe, frouxo, etc.
	-- -exC- should be pronounced like -esC- in Brazil but -eisC- in Portugal. Cf. excelente, experiência, têxtil,
	-- êxtase. Not with other vowels (cf. [[Felixlândia]], [[Laxmi]], [[Oxford]]).
	-- FIXME: Maybe this applies only to Lisbon and environs?
	text = rsub(text, "(e" .. accent_c .. "*)x(" .. C .. ")", function(v, c)
		if brazil then
			return v .. "s" .. c
		else
			return v .. "is" .. c
		end
	end)
	if rfind(text, "x") then
		err("x must be respelled z, ch, sh, cs, ss or similar")
	end

	-- combinations with h; needs to precede handling of c and s, and needs to precede syllabification so that
	-- the consonant isn't divided from the following h.
	text = rsub(text, "([scln])h", {["s"]="ʃ", ["c"]="ʃ", ["n"]="ɲ", ["l"]="ʎ" })

	-- remove initial <h>
	text = rsub(text, "#h([^" .. accent .. "])", "#%1")

	-- c, g, q
	-- This should precede syllabification especially so that the latter isn't confused by gu, qu, gü, qü
	-- also, c -> ç before front vowel ensures that cc e.g. in [[cóccix]], [[occitano]] isn't reduced to single c.
	text = rsub(text, "c(" .. FRONTV .. ")", "ç%1")
	text = rsub(text, "g(" .. FRONTV .. ")", "j%1")
	text = rsub(text, "gu(" .. FRONTV .. ")", "g%1")
	-- [[camping]], [[doping]], [[jogging]], [[Bangkok]], [[angstrom]], [[tungstênio]]
	text = rsub(text, "ng([^" .. vowel .. glide .. "hlr])", "n%1")
	text = rsub(text, "qu(" .. FRONTV .. ")", "k%1")
	text = rsub(text, "ü", "u") -- [[agüentar]], [[freqüentemente]], [[Bündchen]], [[hübnerita]], etc.
	text = rsub(text, "([gq])u(" .. V .. ")", "%1w%2") -- [[quando]], [[guarda]], etc.
	text = rsub(text, "[cq]", "k") -- [[Qatar]], [[burqa]], [[Iraq]], etc.

	-- y -> i between non-vowels, cf. [[Itamaraty]] /i.ta.ma.ɾa.ˈt(ʃ)i/, [[Sydney]] respelled 'Sýdjney' or similar
	-- /ˈsid͡ʒ.nej/ (Brazilian). Most words with y need respelling in any case, but this may help.
	text = rsub(text, "(" .. C_OR_WORD_BOUNDARY .. ")y(" .. accent_c .. "*" .. C_OR_WORD_BOUNDARY .. ")", "%1i%2")

	-- Reduce double letters to single, except for rr, mm, nn and ss, which map to special single sounds. Do this
	-- before syllabification so double letters don't get divided across syllables. The case of cci, cce is handled
	-- above. nn always maps to /n/ and mm to /m/ and can be used to force a coda /n/ or /m/. As a result,
	-- [[connosco]] will need respelling 'comnôsco', 'cõnôsco' or 'con.nôsco', and [[comummente]] will similarly
	-- need respelling e.g. as 'comum.mente' or 'comũmente'. Examples of words with double letters (Brazilian
	-- pronunciation):
	-- * [[Accra]] no respelling needed /ˈa.kɾɐ/;
	-- * [[Aleppo]] respelled 'Aléppo' /aˈlɛ.pu/;
	-- * [[buffer]] respelled 'bâfferh' /ˈbɐ.feʁ/;
	-- * [[cheddar]] respelled 'chéddarh' /ˈʃɛ.daʁ/;
	-- * [[Hanna]] respelled 'Ranna' /ˈʁɐ̃.nɐ/;
	-- * [[jazz]] respelled 'djézz' /ˈd͡ʒɛs/;
	-- * [[Minnesota]] respelled 'Mìnnessôta' /ˌmi.neˈso.tɐ/;
	-- * [[nutella]] respelled 'nutélla' /nuˈtɛ.lɐ/;
	-- * [[shopping]] respeled 'shópping' /ˈʃɔ.pĩ/ or 'shóppem' /ˈʃɔ.pẽj̃/;
	-- * [[Stonehenge]] respelled 'Stòwnn.rrendj' /ˌstownˈʁẽd͡ʒ/;
	-- * [[Yunnan]] no respelling needed /juˈnɐ̃/.
	--
	-- Note that further processing of r and s happens after syllabification and stress assignment, because we need
	-- e.g. to know the distinction between final -s and -z to assign the stress properly.
	text = rsub(text, "rr", "ʁ")
	text = rsub(text, "nn", "N")
	text = rsub(text, "mm", "M")
	text = rsub(text, "ss", "S") -- will map later to /s/; need to special case to support spellings like 'nóss'
	text = rsub(text, "(" .. C .. ")%1", "%1")

	-- Respell [[homenzinho]] as 'homemzinho' so it is stressed correctly.
	text = rsub(text, "n(" .. SYLDIV .. "?ziɲo#)", "m%1")

	if brazil then
		-- Palatalize t/d + i -> affricates in Brazil. Use special unitary symbols, which we later convert to regular
		-- affricate symbols, so we can distinguish palatalized d from written dj.
		local palatalize_td = {["t"] = "ʧ", ["d"] = "ʤ"}
		text = rsub(text, "([td])([" .. high_front_vocalic .. "])",
			function(td, high_vocalic) return palatalize_td[td] .. high_vocalic end)
		-- Now delete the symbol for deleted epenthetic /i/; it still triggers palatalization of t and d.
		text = rsub(text, "Ɨ", "")
	end

	-- Divide words into syllables.
	-- First, change user-specified . into a special character so we won't move it around. We need to keep this
	-- going forward until after we place the stress, so we can correctly handle initial i- + vowel, as in [[ia]],
	-- [[iate]] and [[Iaundé]]. We need to divide [[ia]] as 'i.a' but [[iate]] as 'ia.te' and [[Iaundé]] as 'Ia.un.dé'.
	-- In the former case, the stress goes on i but in the latter cases not; so we always divide <ia> as 'i.a',
	-- and then after stress assignment remove the syllable divider if the <i> isn't stressed. The tricky thing is
	-- that we want to allow the user to override this by explicitly adding a . between the <i> and <a>. So we need
	-- to keep the distinction between user-specified . and auto-determined . until after stress assignment.
	text = rsub(text, "%.", SYLDIV)
	text = rsub_repeatedly(text, "(" .. V .. accent_c .. "*)(" .. C .. W .. "?" .. V .. ")", "%1.%2")
	text = rsub_repeatedly(text, "(" .. V .. accent_c .. "*" .. C .. ")(" .. C .. V .. ")", "%1.%2")
	text = rsub_repeatedly(text, "(" .. V .. accent_c .. "*" .. C .. "+)(" .. C .. C .. V .. ")", "%1.%2")
	text = rsub(text, "([pbfvktdg])%.([lr])", ".%1%2")
	-- /tʃ/, /dʒ/ are normally single sounds, but adj- in [[adjetivo]], [[adjunto]] etc. should be 'ad.j'
	text = rsub(text, "t%.ʃ", ".tʃ")
	text = rsub(text, "d%.j", ".dj")
	text = rsub(text, "#a.dj", "#ad.j")
	text = rsub_repeatedly(text, "(" .. C .. ")%.s(" .. C .. ")", "%1s.%2")
	-- All vowels should be separated from adjacent vowels by a syllable division except
	-- (1) aeo + unstressed i/u, ([[saiba]], [[peixe]], [[noite]], [[Paulo]], [[deusa]], [[ouro]]), except when
	-- followed by nh or m/n/r/l + (non-vowel or word end), e.g. Bom.ba.im, ra.i.nha, Co.im.bra, sa.ir, but Jai.me,
	-- a.mai.nar, bai.le, ai.ro.so, quei.mar, bei.ra;
	-- (2) iu(s), ui(s) at end of word, e.g. fui, Rui, a.zuis, pa.riu, viu, sa.iu;
	-- (3) ão, ãe, õe.
	--
	-- The easiest way to handle this is to put a special symbol between vowels that should not have a syllable
	-- division between them.
	--
	-- First, put a syllable divider between [aeo].[iu][mnlr], as in [[Bombaim]], [[Coimbra]], [[saindo]], [[sair]],
	-- [[Iaundé]], [[Raul]]. Note that in cases like [[Jaime]], [[queimar]], [[fauna]], [[baile]], [[Paulo]], [[beira]],
	-- where a vowel follows the m/n/l/r, there will already be a syllable division between i.m, u.n, etc., which will
	-- block the following substitution.
	text = rsub(text, "([aeo]" .. accent_c .. "*)([iu][mnlr])", "%1.%2")
	-- Also put a syllable divider between [aeo].[iu].ɲ coming from 'nh' ([[rainha]], [[moinho]]).
	text = rsub(text, "([aeo]" .. accent_c .. "*)([iu]%.ɲ)", "%1.%2")
	-- Prevent syllable division between final -ui(s), -iu(s). This should precede the following rule that prevents
	-- syllable division between ai etc., so that [[saiu]] "he left" gets divided as sa.iu.
	text = rsub(text, "(u" .. accent_c .. "*)(is?#)", "%1" .. TEMP1 .. "%2")
	text = rsub(text, "(i" .. accent_c .. "*)(us?#)", "%1" .. TEMP1 .. "%2")
	-- Prevent syllable division between ai, ou, etc. unless either the second vowel is accented [[saído]]) or there's
	-- a TEMP1 marker already after the second vowel (which will occur e.g. in [[saiu]] divided as 'sa.iu').
	text = rsub_repeatedly(text, "([aeo]" .. accent_c .. "*)([iu][^" .. accent .. TEMP1 .. "])", "%1" .. TEMP1 .. "%2")
	-- Prevent syllable division between nasal diphthongs unless somehow the second vowel is accented.
	text = rsub_repeatedly(text, "(a" .. TILDE .. ")([eo][^" .. accent .. "])", "%1" .. TEMP1 .. "%2")
	text = rsub_repeatedly(text, "(o" .. TILDE .. ")(e[^" .. accent .. "])", "%1" .. TEMP1 .. "%2")
	-- All other sequences of vowels get divided.
	text = rsub_repeatedly(text, "(" .. V .. accent_c .. "*)(" .. V .. ")", "%1.%2")
	-- Remove the marker preventing syllable division.
	text = rsub(text, TEMP1, "")

	-- An acute or circumflex not followed by a stress marker has primary stress, so indicate it.
	text = rsub_repeatedly(text, "(" .. V .. quality_c .. ")([^" .. stress .. "])", "%1ˈ%2")
	-- Line-under indicates secondary stress.
	text = rsub(text, LINEUNDER, "ˌ")

	-- Add primary stress to the word if not already present. If the word ends in -mente or -zinho, we add two
	-- primary stresses; the first one will be converted to secondary stress down below. Note that `syllables` is
	-- a list that includes the syllable dividers as separate items (either SYLDIV if user-specified, or . if
	-- auto-added), so the actual syllables are found at indices 1, 3, 5, etc.
	local function accent_word(word, syllables)
		-- Check if stress already marked. We check first for primary stress before checking for tilde in case both
		-- primary stress and tilde occur, e.g. [[bênção]], [[órgão]], [[hétmã]], [[connosco]] respelled 'cõnôsco'.
		if rfind(word, "ˈ") then
			return
		end

		-- Check for nasal vowel marked with tilde and without non-primary stress; assign stress to the last such
		-- syllable in case there's more than one tilde, e.g. [[pãozão]]. Note, this can happen in the part before
		-- -mente, cf. [[anticristãmente]], and before -zinho, cf. [[coraçãozinho]].
		for i = #syllables, 1, -2 do -- -2 because of the syllable dividers; see above.
			local changed
			syllables[i], changed = rsubb(syllables[i], "(" .. V .. quality_c .. "*)" .. TILDE, "%1ˈ" .. TILDE)
			if changed then
				return
			end
		end

		-- Apply the default stress rule.
		local sylno
		if #syllables > 1 and (rfind(word, "[aeo]s?#") or rfind(word, "[ae]m#") or rfind(word, "[ae]ns#")) then
			-- Stress the last syllable but one. The -2 is because of the syllable dividers; see above.
			sylno = #syllables - 2
			-- Don't put stress on epenthetic i; instead, we stress the preceding syllable, as if epenthetic i weren't
			-- there.
			while sylno > 1 and rfind(syllables[sylno], "I") do
				sylno = sylno - 2
			end
			-- It is (vaguely) possible that we have a one-syllable word beginning with a complex cluster such as gn-
			-- followed by a normally unstressed ending such as -em. In this case, we want the ending to be stressed.
			while sylno < #syllables and rfind(syllables[sylno], "I") do
				sylno = syno + 2
			end
		else
			sylno = #syllables
		end
		if rfind(syllables[sylno], stress_c) then
			-- Don't do anything if stress mark already present. (Since we check for primary stress above, this check
			-- specifically affects non-primary stress.)
			return
		end
		-- Add stress mark after first vowel (and any quality mark).
		syllables[sylno] = rsub(syllables[sylno], "^(.-" .. V .. quality_c .. "*)", "%1ˈ")
	end

	-- Split the text into words and the words into syllables so we can correctly add stress to words without it.
	local words = rsplit(text, " ")
	for j, word in ipairs(words) do
		-- Preserve the syllable divider, which may be auto-added or user-specified.
		local syllables = m_strutils.capturing_split(word, "([." .. SYLDIV .. "])")

		if rfind(word, "[%." .. SYLDIV .. "]men%.te#") or rfind(word, "[%." .. SYLDIV .. "]zi%.ɲo#") then
			local mente_syllables
			-- Words ends in -mente or -zinho; add primary stress to the preceding portion as if stressed
			-- (e.g. [[agitadamente]] -> 'agitádamente') unless already stressed (e.g. [[rapidamente]]
			-- respelled 'rápidamente'). The primary stress will be converted to secondary stress further below.
			-- Essentially, we rip the word apart into two words ('mente'/'zinho' and the preceding portion) and
			-- stress each one independently. Note that the effect of adding a primary stress will also be to cause
			-- an error if stressed 'e' or 'o' is not properly marked as é/ê or ó/ô; cf. [[certamente]], which must
			-- be respelled 'cértamente', and [[posteriormente]], which must be respelled 'posteriôrmente', just as
			-- with [[certa]] and [[posterior]]. To prevent this happening, you can add an accent to -mente or
			-- -zinho, e.g. [[dormente]] respelled 'dormênte', [[vizinho]] respelled 'vizínho'.
			mente_syllables = {}
			mente_syllables[3] = table.remove(syllables)
			mente_syllables[2] = table.remove(syllables) -- this will be a syllable divider
			mente_syllables[1] = table.remove(syllables)
			table.remove(syllables) -- this will be a syllable divider
			accent_word(table.concat(syllables, "") .. "#", syllables)
			accent_word("#" .. table.concat(mente_syllables, ""), mente_syllables)
			-- Reconstruct the word. Put a # instead of . between the two parts so e.g. the vowel at the end
			-- of the first part is treated as word-final. Don't cache the concat() before accent_word() changes
			-- the syllables.
			words[j] = table.concat(syllables, "") .. "#" .. table.concat(mente_syllables, "")
		else
			accent_word(word, syllables)
			-- Reconstruct the word.
			words[j] = table.concat(syllables, "")
		end
	end

	-- Reconstruct the text from the words.
	text = table.concat(words, " ")

	-- I has served its purpose (not considered when accenting).
	text = rsub(text, "I", "i")

	-- Remove hiatus between initial <i> and following vowel ([[Iasmim]]) unless the <i> is stressed ([[ia]]) or the
	-- user explicitly added a . (converted to SYLDIV above).
	text = rsub(text, "#i%.(" .. V .. ")", "#y%1")
	if not brazil then
		-- Outside of Brazil, remove hiatus more generally whenever 'e./i.' or 'o./u.' precedes a vowel. Do this before
		-- eliminating SYLDIV so the user can force hiatus using a period.
		local hiatus_to_glide = {["e."] = "y", ["i."] = "y", ["o."] = "w", ["u."] = "w"}
		text = rsub(text, "(" .. C_OR_WORD_BOUNDARY .. ")([eiou]%.)(" .. V .. ")",
			function(before, hiatus, after) return before .. hiatus_to_glide[hiatus] .. after end)
	end

	-- Convert user-specified syllable division back to period. See comment above when we add SYLDIV.
	text = rsub(text, SYLDIV, ".")

	-- Vowel quality handling. First convert all a -> A, e -> E, o -> O. We will then convert A -> a/ɐ, E -> e/ɛ/ɨ,
	-- O -> o/ɔ/u depending on accent marks and context. Ultimately all vowels will be one of the nine qualities
	-- aɐeɛiɨoɔu and following each vowel will either be nothing (no stress), an IPA primary stress mark (ˈ) or an
	-- IPA secondary stress mark (ˌ), in turn possibly followed by a tilde (nasalization). After doing everything
	-- that depends on the position of stress, we will move the IPA stress marks to the beginning of the syllable.
	text = rsub(text, "[aeo]", {["a"] = "A", ["e"] = "E", ["o"] = "O"})
	text = rsub(text, DOTOVER, "") -- eliminate DOTOVER; it served its purpose of preventing stress

	-- Nasal vowel handling.

	-- Final unstressed -am (in third-person plural verbs) pronounced like unstressed -ão.
	text = rsub(text, "Am#", "A" .. TILDE .. "O#")
	if portugal then
		-- In Portugal, final -n is really /n/, and preceding unstressed e/o are open.
		text = rsub(text, "n#", "N#")
		text = rsub(text, "([EO])(N#)", "%1" .. AC .. "%2")
		-- In Portugal, final unstressed -r opens the preceding e.
		text = rsub(text, "(E)(r#)", "%1" .. AC .. "%2")
	end
	-- Acute accent on final -em ([[além]], [[também]]) and final -ens ([[parabéns]]) does not indicate an open
	-- pronunciation.
	text = rsub(text, "E" .. AC .. "(ˈ[mn]s?#)", "E" .. CFLEX .. "%1")
	-- Vowel + m/n within a syllable gets converted to tilde.
	text = rsub(text, "(" .. V .. quality_c .. "*" .. stress_c .. "*)[mn]", "%1" .. TILDE)
	-- Vowel without quality mark + tilde needs to get the circumflex (possibly fed by the previous change).
	text = rsub(text, "(" .. V .. ")(" .. stress_c .. "*)" .. TILDE, "%1" .. CFLEX .. "%2" .. TILDE)
	-- Primary-stressed vowel without quality mark + m/n/nh across syllable boundary gets a circumflex, cf. [[cama]],
	-- [[ano]], [[banho]].
	text = rsub(text, "(" .. V .. ")(ˈ%.[mnɲMN])", "%1" .. CFLEX .. "%2")
	if brazil then
		-- Primary-stressed vowel + m/n across syllable boundary gets nasalized in Brazil, cf. [[cama]], [[ano]].
		text = rsub(text, "(" .. V .. quality_c .. "*)(ˈ%.[mnMN])", "%1" .. TILDE .. "%2")
		-- All vowels before nh (always across syllable boundary) get circumflexed and nasalized in Brazil,
		-- cf. [[ganhar]].
		text = rsub(text, "(" .. V .. stress_c .. "*)(%.ɲ)", "%1" .. CFLEX .. "%2")
		text = rsub(text, "(" .. V .. quality_c .. "*" .. stress_c .. "*)(%.ɲ)", "%1" .. TILDE .. "%2")
		-- Convert initial unstressed em-/en- before consonant to special symbol /Ẽ/, which later on is converted
		-- to /e/ (careful pronunciation) or /i/ (natural pronunciation).
		text = rsub(text, "(#E".. CFLEX .. TILDE ..")(%." .. C ..")", "#Ẽ" .. TILDE .. "%2")
	end

	-- Nasal diphthongs.
	local nasal_termination_to_glide = {["E"] = "y", ["O"] = "w"}
	-- In ãe, ão, the second letter represents a glide.
	text = rsub(text, "(A" .. CFLEX .. stress_c .. "*" .. TILDE .. ")([EO])",
		function(v1, v2) return v1 .. nasal_termination_to_glide[v2] .. TILDE end)
	-- Likewise for õe.
	text = rsub(text, "(O" .. CFLEX .. stress_c .. "*" .. TILDE .. ")E", "%1y" .. TILDE)
	-- Final -em and -ens (stressed or not) pronounced /ẽj̃(s)/. (Later converted to /ɐ̃j̃(s)/ in Portugal.)
	text = rsub(text, "(E" .. CFLEX .. stress_c .. "*" .. TILDE .. ")(s?#)", "%1y" .. TILDE .. "%2")

	-- Oral diphthongs.
	-- ei, eu, oi, ou -> êi, êu, ôi, ôu
	text = rsub(text, "([EO])(" .. stress_c .. "*[iuywY])", "%1" .. CFLEX .. "%2")
	-- ai, au -> ái, áu
	text = rsub(text, "(A)(" .. stress_c .. "*[iuywY])", "%1" .. AC .. "%2")

	-- Convert A/E/O as appropriate when followed by a secondary or tertiary stress marker. If a quality is given,
	-- it takes precedence; otherwise, act as if an acute accent were given.
	text = rsub(text, "([AEO])(" .. non_primary_stress_c .. ")", "%1" .. AC .. "%2")

	-- Unstressed syllables.
	-- Before final <x>, unstressed e/o are open, e.g. [[córtex]], [[xérox]].
	text = rsub(text, "([EO])(kç#)", "%1" .. AC .. "%2")
	if brazil then
		-- Final unstressed -e(s), -o(s) -> /i/ /u/ (including before -mente)
		local brazil_final_vowel = {["E"] = "i", ["O"] = "u"}
		text = rsub(text, "([EO])(s?#)", function(v, after) return brazil_final_vowel[v] .. after end)
		-- Word-final unstressed -a(s) -> /ɐ/ (not before -mente)
		text = rsub(text, "A(s?#[# ])", function(after) return "ɐ" .. after end)
		-- Initial unmarked unstressed non-nasal e- + -sC- -> /i/ ([[estar]], [[esmeralda]]). To defeat this,
		-- explicitly mark the <e> e.g. as <ệ> or <eh>.
		if not rfind(text, "#Es.ç") then
			text = rsub(text, "#E(s" .. C .. "*%.)", "#i%1")
		end
		-- Remaining unstressed a, e, o without quality mark -> /a/ /e/ /o/.
		local brazil_unstressed_vowel = {["A"] = "a", ["E"] = "e", ["O"] = "o"}
		text = rsub(text, "([AEO])([^" .. accent .. "])",
			function(v, after) return brazil_unstressed_vowel[v] .. after end)
	elseif portugal then
		text = rsub(text, "Al(" .. C .. "*[.#])", "al%1")
		text = rsub(text, "El(" .. C .. "*[.#])", "ɛl%1")
		-- The symbol Ɔ is later converter to /o/ or /ɔ/.
		text = rsub(text, "Ol(" .. C .. "*[.#])", "Ɔl%1")
		
		-- Initial unmarked unstressed non-nasal e- + -sC- -> /ɨ/ (later changed to /(i)/)
		text = rsub(text, "#E(s" .. C .. "*%.)", "#ɨ%1")
		-- Initial unmarked unstressed non-nasal e- -> /i/
		text = rsub(text, "#E([^" .. accent .. "])", "#i%1")
		-- Initial unmarked unstressed non-nasal o- -> /ɔ/
		text = rsub(text, "#O([^" .. accent .. "])", "#ɔ%1")
		-- All other unmarked unstressed non-nasal e, o, a -> /ɨ/ /u/ /ɐ/
		local portugal_unstressed_vowel = {["A"] = "ɐ", ["E"] = "ɨ", ["O"] = "u"}
		text = rsub(text, "([AEO])([^" .. accent .. "])",
			function(v, after) return portugal_unstressed_vowel[v] .. after end)
	end

	-- Remaining vowels.
	-- All remaining a -> /a/ (should always be stressed).
	text = rsub(text, "A([^" .. quality .. "])", "a%1")
	-- Ignore quality markers on i, u; only one quality.
	text = rsub(text, "([iu])" .. quality_c, "%1")
	-- Convert a/e/o + quality marker appropriately.
	local vowel_quality = {
		["A" .. AC] = "a", ["A" .. CFLEX] = "ɐ",
		["E" .. AC] = "ɛ", ["E" .. CFLEX] = "e",
		["O" .. AC] = "ɔ", ["O" .. CFLEX] = "o",
	}
	text = rsub(text, "([AEO]" .. quality_c .. ")", vowel_quality)
	-- Stressed o in hiatus ([[voo]], [[boa]], [[perdoe]], etc.) is closed /o/.
	text = rsub(text, "O(ˈ%." .. V .. ")", "o%1")
	-- Stressed closed /o/ in Portugal in hiatus regionally has a following /w/. Indicate using W.
	if portugal then
		text = rsub(text, "(oˈ%.)(" .. V .. ")", "%1W%2")
	end
	-- Any remaining E or O (always without quality marker) is an error.
	if rfind(text, "[EO]") then
		err("Stressed e or o not occurring nasalized or in a diphthong must be marked for quality using é/ê or ó/ô")
	end

	-- Finally, eliminate DOTUNDER, now that we have done all vowel reductions.
	text = rsub(text, DOTUNDER, "")

	if brazil then
		-- Epenthesize /(j)/ in [[faz]], [[mas]], [[três]], [[dez]], [[feroz]], [[luz]], [[Jesus]], etc. Note, this only
		-- triggers at actual word boundaries (not before -mente/-zinho), and not on nasal vowels or diphthongs. To
		-- defeat this (e.g. in plurals), respell using 'ss' or 'hs'.
		text = rsub(text, "(" .. V .. "ˈ)([sz]#[# ])", "%1Y%2")
		-- But should not happen after /i/.
		text = rsub(text, "iˈY", "iˈ")
	end
	-- 'S' here represents earlier ss. Word-finally it is used to prevent epenthesis of (j) and should behave
	-- like 's'. Elsewhere (between vowels) it should behave like 'ç'.
	text = rsub(text, "S#", "s#")
	text = rsub(text, "S", "ç")

	-- s, z
	-- s in trans + V -> z: [[transação]], [[intransigência]]
	text = rsub(text, "(trɐ" .. stress_c .. "*" .. TILDE .. ".)s(" .. V .. ")", "%1z%2")
	-- word final z -> s
	text = rsub(text, "z#", "s#")
	-- s is voiced between vowels (not nasalized) or between vowel and voiced consonant, including across word boundaries;
	-- may be fed by previous rule
	text = rsub(text, "(" .. V .. stress_c .. "*Y?%.?)s(" .. wordsep_c .. "*h?[" .. vowel .. voiced_cons .. "])", "%1z%2")
	-- z before voiceless consonant, e.g. [[Nazca]]; c and q already removed
	text = rsub(text, "z(" .. wordsep_c .. "*[çfkpsʃt])", "%1s%2")
	--Change Portugal initial /ɨʃ/ to /(i)ʃ/
	text = rsub(text, "##ɨs", "(i)s")
	text = rsub(text, "##ɨz", "(i)z")
	if not brazil or style == "rio" then
		-- Outside Brazil except for Rio; s/z before consonant (including across word boundaries) or end of utterance -> ʃ/ʒ
		local shibilant = {["s"] = "ʃ", ["z"] = "j"}
		text = rsub(text, "([sz])(##)", function(sz, after) return shibilant[sz] .. after end)
		text = rsub(text, "([sz])(" .. wordsep_c .. "*" .. C_NOT_H_OR_GLIDE .. ")",
			function(sz, after) return shibilant[sz] .. after end)
	end
	text = rsub(text, "ç", "s")
	text = rsub(text, "j", "ʒ")
	-- Reduce identical sibilants, including across word boundaries.
	text = rsub(text, "([szʃʒ])(" .. wordsep_c .. "*)(%1)", "%2%1")
	if style == "rio" then
		-- Also reduce shibilant + sibilant ([[descer]], [[as]] [[zonas]]); not in Portugal.
		text = rsub(text, "ʃ(" .. wordsep_c .. "*s)", "%1")
		text = rsub(text, "ʒ(" .. wordsep_c .. "*z)", "%1")
	end

	-- N/M from double n/m
	text = rsub(text, "[NM]", {["N"] = "n", ["M"] = "m"})

	-- r
	-- Double rr -> ʁ already handled above.
	-- Initial r or l/n/s/z + r -> strong r (ʁ).
	text = rsub(text, "([#" .. TILDE .. "lszʃʒ]%.?)r", "%1ʁ")
	if brazil then
		-- Coda r before vowel in verbs is /(ɾ)/.
		text = rsub(text, "([aɛei]ˈ)r(#" .. wordsep_c .. "*h?" .. V .. ")", "%1(ɾ)%2")
		-- Coda r before vowel is /ɾ/.
		text = rsub(text, "r(" .. C .. "*[.#]" .. wordsep_c .. "*h?" .. V .. ")", "%1ɾ%2")
	end
	-- Word-final r in Brazil in verbs (not [[pôr]]) is usually dropped. Use a spelling like 'marh' for [[mar]]
	-- to prevent this.
	if style == "sp" then
		text = rsub(text, "([aɛei]ˈ)r#", "%1(ɾ)#")
	elseif brazil then
		text = rsub(text, "([aɛei]ˈ)r#", "%1(ʁ)#")
		-- Coda r outside of São Paulo is /ʁ/.
		text = rsub(text, "r(" .. C .. "*[.#])", "ʁ%1")
	end
	-- All other r -> /ɾ/.
	text = rsub(text, "r", "ɾ")
	if brazil and phonetic then
		-- "Strong" ʁ before voiced consonant is [ɦ] in much of Brazil, [ʁ] in Rio. Use R as a temporary symbol.
		text = rsub(text, "ʁ(" .. wordsep_c .. "*[" .. voiced_cons .. "])", style == "rio" and "R%1" or "ɦ%1")
		-- Other "strong" ʁ is [h] in much of Brazil, [χ] in Rio. Use H because later we remove all <h>.
		text = rsub(text, "ʁ", style == "rio" and "χ" or "H")
		text = rsub(text, "R", "ʁ")
	end
	
	-- Diphtong <ei>
	if brazil then
		-- In Brazil, add optional /j/ in <eir>, <eij>, <eig> and <eix> (as in [[cadeira]], [[beijo]], [[manteiga]] and
		-- [[peixe]]).
		text = rsub(text, "(e" .. accent_c .. "*)i(%.[ɾʒgʃ])", "%1(j)%2")
		-- [In Brazil, add optional /j/ in <aix> (as in [[caixa]] and [[baixo]]).] -- This was added by an IP, see
		-- [[Special:Contributions/186.212.6.138]]; this seems non-standard to me. (Benwing2)
		-- text = rsub(text, "(a" .. accent_c .. "*)i(%.ʃ)", "%1(j)%2")
	end
	if style == "spt"  then
		-- In South of Portugal, <ei>, <ou> monophthongizes to <e>, <o>
		text = rsub(text, "(e" .. accent_c .. "*)i", "%1")
		text = rsub(text, "(o" .. accent_c .. "*)u", "%1")
	end
	if style == "gpt" then
		-- In general Portugal, lower e -> ɐ before i in <ei>.
		text = rsub(text, "e(" .. accent_c .. "*i)", "ɐ%1")
	end
	
	if style == "gpt" then
		-- In general Portugal, lower ɛ -> ɐ before i in <ɛi>.
		text = rsub(text, "ɛ(" .. accent_c .. "*i)", "ɐ%1")
		-- In general Portugal, lower e -> ɐ before j, including when nasalized.
		text = rsub(text, "e(" .. accent_c .. "*%.?y)", "ɐ%1")
		-- In general Portugal, lower e -> ɐ(j) before other palatals.
		text = rsub(text, "e(" .. stress_c .. "*)(%.?[ʒʃɲʎ](" .. V .. "))", phonetic and "ɐ%1(ɪ̯)%2" or "ɐ%1(j)%2")
	end

	-- Glides and l. ou -> o(w) must precede coda l -> w in Brazil, because <ol> /ow/ cannot be reduced to /o/.
	-- ou -> o(w) before conversion of remaining diphthongs to vowel-glide combinations so <ow> can be used to
	-- indicate a non-reducible glide.
	-- Optional /w/ in <ou>.
	text = rsub(text, "(o" .. accent_c .. "*)u", "%1(w)")
	-- Handle coda /l/.
	if brazil then
		-- Coda l -> /w/ in Brazil.
		text = rsub(text, "l(" .. C .. "*[.#])", "w%1")
	elseif portugal and phonetic then
		-- Coda l -> [ɫ] in Portugal.
		text = rsub(text, "l(" .. C .. "*[.#])", "ɫ%1")
	end
	text = rsub(text, "y", "j")
	text = rsub(text, "Y", "(j)") -- epenthesized in [[faz]], [[três]], etc.
	local vowel_termination_to_glide = brazil and phonetic and
	{["i"] = "ɪ̯", ["j"] = "ɪ̯", ["u"] = "ʊ̯", ["w"] = "ʊ̯"} or
	{["i"] = "j", ["j"] = "j", ["u"] = "w", ["w"] = "w"}
	-- i/u as second part of diphthong becomes glide.
	text = rsub(text, "(" .. V .. accent_c .. "*" .. "%(?)([ijuw])",
		function(v1, v2) return v1 .. vowel_termination_to_glide[v2] end)

	-- nh
	if brazil and phonetic then
		-- [[unha]] pronounced [ˈũ.j̃ɐ]; nasalization of previous vowel handled above.
		-- But initial nh- e.g. [[nhaca]], [[nheengatu]], [[nhoque]] is [ɲ].
		text = rsub(text, "([^#])ɲ", "%1j" .. TILDE)
	end

	-- Stop consonants.
	if brazil then
		-- Palatalize t/d + i -> affricates in Brazil.
		local palatalize_td = {["t"] = "t͡ʃ", ["d"] = "d͡ʒ"}
		text = rsub(text, "([td])([ij])", function(td, high_vocalic) return palatalize_td[td] .. high_vocalic end)
	elseif phonetic then
		-- Fricativize voiced stops in Portugal when not utterance-initial or after a nasal; also not in /ld/.
		-- Easiest way to do this is to convert all voiced stops to fricative and then back to stop in the
		-- appropriate contexts.
		local fricativize_stop = { ["b"] = "β", ["d"] = "ð", ["g"] = "ɣ" }
		local occlude_fricative = { ["β"] = "b", ["ð"] = "d", ["ɣ"] = "g" }
		text = rsub(text, "[bdg]", fricativize_stop)
		text = rsub(text, "##([βðɣ])", function(bdg) return "##" .. occlude_fricative[bdg] end)
		text = rsub(text, "(" .. TILDE .. "%.?)([βðɣ])", function(before, bdg) return before .. occlude_fricative[bdg] end)
		text = rsub(text, "([lɫ]%.?)ð", "%1d")
	end
	text = rsub(text, "g", "ɡ") -- U+0261 LATIN SMALL LETTER SCRIPT G
	text = rsub(text, "[ʧʤ]", {["ʧ"] = "t͡ʃ", ["ʤ"] = "d͡ʒ"})
	text = rsub(text, "tʃ", "t͡ʃ")
	text = rsub(text, "dʒ", "d͡ʒ")
	text = rsub(text, "h", "")
	text = rsub(text, "H", "h")

	-- Stress marks.
	-- Change # in the middle of a word (words ending in -mente/-zinho) back to period.
	text = rsub_repeatedly(text, "([^ #])#([^ #])", "%1.%2")
	-- Move IPA stress marks to the beginning of the syllable.
	text = rsub_repeatedly(text, "([#.])([^#.]*)(" .. ipa_stress_c .. ")", "%1%3%2")
	-- Suppress syllable mark before IPA stress indicator.
	text = rsub(text, "%.(" .. ipa_stress_c .. ")", "%1")
	-- Make all primary stresses but the last one in a given word be secondary. May be fed by the first rule above.
	text = rsub_repeatedly(text, "ˈ([^ #]+)ˈ", "ˌ%1ˈ")

	-- Remove # symbols at word/text boundaries, as well as _ to force separate interpretation, and recompose.
	text = rsub(text, "[#_]", "")
	text = mw.ustring.toNFC(text)

	return text
end


-- text = Raw respelling 
-- style = gbr, rio, etc. (see all_style_descs above).
-- Return value is a list of objects of the following form:
--   { phonemic = STRING, phonetic = STRING, qualifiers = {STRING, ...} }
function export.IPA(text, style, phonetic)
	local brazil = m_table.contains(export.all_style_groups.br, style)

	local origtext = text

	local function err(msg)
		error(msg .. ": " .. origtext)
	end

	text = ulower(text or mw.title.getCurrentTitle().text)
	-- decompose everything but ç and ü
	text = mw.ustring.toNFD(text)
	text = rsub(text, ".[" .. CEDILLA .. DIA .. "]", {
		["c" .. CEDILLA] = "ç",
		["u" .. DIA] = "ü",
	})
	text = reorder_accents(text, err)

	-- convert commas and en/en dashes to IPA foot boundaries
	text = rsub(text, "%s*[,–—]%s*", " | ")
	-- question mark or exclamation point in the middle of a sentence -> IPA foot boundary
	text = rsub(text, "([^%s])%s*[!?]%s*([^%s])", "%1 | %2")

	-- canonicalize multiple spaces and remove leading and trailing spaces
	local function canon_spaces(text)
		text = rsub(text, "%s+", " ")
		text = rsub(text, "^ ", "")
		text = rsub(text, " $", "")
		return text
	end

	text = canon_spaces(text)

	-- Make prefixes unstressed with vowel reduction unless they have an explicit stress marker;
	-- likewise for certain monosyllabic words (e.g. [[o]], [[se]], [[de]], etc.; also [[a]], [[das]], etc.
	-- in Portugal) without stress marks.
	local words = rsplit(text, " ")
	for i, word in ipairs(words) do
		if rfind(word, "%-$") and not rfind(word, accent_c) or unstressed_words[word] or
			not brazil and unstressed_full_vowel_words_brazil[word] then
			-- add DOTOVER to the last vowel not the first one, or we will mess up 'que' by
			-- adding the DOTOVER after the 'u'
			words[i] = rsub(word, "^(.*" .. V .. quality_c .. "*)", "%1" .. DOTOVER)
		end
	end
	-- Make certain monosyllabic words (e.g. [[meu]], [[com]]; also [[a]], [[das]], etc. in Brazil)
	-- without stress marks be unstressed without vowel reduction.
	for i, word in ipairs(words) do
		if rfind(word, "%-$") and not rfind(word, accent_c) or unstressed_full_vowel_words[word] or
			brazil and unstressed_full_vowel_words_brazil[word] then
			-- add DOTUNDER to the first vowel not the last one, or we will mess up 'meu' by
			-- adding the DOTUNDER after the 'u'; add after a quality marker for à, às
			words[i] = rsub(word, "^(.-" .. V .. quality_c .. "*)", "%1" .. DOTUNDER)
		end
	end

	text = table.concat(words, " ")
	-- Convert hyphens to spaces, to handle [[Áustria-Hungria]], [[franco-italiano]], etc.
	text = rsub(text, "%-", " ")
	-- canonicalize multiple spaces again, which may have been introduced by hyphens
	text = canon_spaces(text)
	-- now eliminate punctuation
	text = rsub(text, "[!?']", "")
	-- put # at word beginning and end and double ## at text/foot boundary beginning/end
	text = rsub(text, " | ", "# | #")
	text = "##" .. rsub(text, " ", "# #") .. "##"

	-- [[à]], [[às]]; remove grave accent
	text = rsub(text, "(#a)" .. GR .. "(" .. DOTUNDER .. "?s?#)", "%1%2")

	local variants

	local function apply_sub(from, to1, to2)
		return function(item)
			if rfind(item, from) then
				if to2 then
					return {rsub(item, from, to1), rsub(item, from, to2)}
				else
					return {rsub(item, from, to1)}
				end
			else
				return {item}
			end
		end
	end

	if brazil then
		-- Remove grave accents and macrons, which have special meaning only for Portugal. Do this before handling o^
		-- and similar so we can write autò^:... and have it correctly give 'autò-' in Portugal but 'autu-,auto-' in
		-- Brazil.
		text = rsub(text, "[" .. GR .. MACRON .. "]", "")

		variants = {text}
		variants = flatmap(variants, apply_sub("i%^%^(" .. V .. ")", "y%1", "i.%1"))
		variants = flatmap(variants, apply_sub("i%^(" .. V .. ")", "i.%1", "y%1"))
		variants = flatmap(variants, apply_sub("i%^%^(" .. NV_NOT_CFLEX .. ")", "Ɨ%1", "I%1"))
		variants = flatmap(variants, apply_sub("i%^(" .. NV_NOT_CFLEX .. ")", "I%1", "Ɨ%1"))
		variants = flatmap(variants, apply_sub("i%*", "I"))
		variants = flatmap(variants, apply_sub("e%^%^", "e", "i"))
		variants = flatmap(variants, apply_sub("e%^", "i", "e"))
		variants = flatmap(variants, apply_sub("o%^%^", "o", "u"))
		variants = flatmap(variants, apply_sub("o%^", "u", "o"))
	else -- Portugal
		-- Convert grave accents and macrons to explicit dot-under + quality marker.
		local grave_macron_to_quality = {
			[GR] = AC,
			[MACRON] = CFLEX,
		}
		text = rsub(text, "[" .. GR .. MACRON .. "]", function(acc) return grave_macron_to_quality[acc] .. DOTUNDER end)
		-- Remove i*, i^ and i^^ not followed by a vowel (i.e. Brazilian epenthetic i), but not i^ and i^^ followed by
		-- a vowel (which has a totally different meaning, i.e. i or y in Brazil).
		text = rsub(text, "i[*%^]+(" .. NV_NOT_CFLEX .. ")", "%1")
		text = rsub(text, "[*%^]+", "")
		variants = {text}
	end

	local function call_one_term_ipa(variant)
		local result = {{
			phonemic = one_term_ipa(variant, style, false, err),
			phonetic = one_term_ipa(variant, style, true, err),
		}}
		local function apply_sub(from, to1, qual1, to2, qual2)
			return function(item)
				if rfind(item.phonemic, from) or rfind(item.phonetic, from) then
					return {
						{
							phonemic = rsub(item.phonemic, from, to1),
							phonetic = rsub(item.phonetic, from, to1),
							qualifiers = qual1,
						},
						{
							phonemic = rsub(item.phonemic, from, to2),
							phonetic = rsub(item.phonetic, from, to2),
							qualifiers = qual2,
						},
					}
				else
					return {item}
				end
			end
		end

		if brazil then
			result = flatmap(result, apply_sub("Ẽ", "e", {"careful pronunciation"}, "i", {"natural pronunciation"}))
		else -- Portugal
			result = flatmap(result, apply_sub("W", "", nil, "w", {"regional"}))
			result = flatmap(result, apply_sub("ʃ([." .. ipa_stress .. "])s",
					"ʃ%1s", {"careful pronunciation"}, "%1ʃ", {"natural pronunciation"}))
			result = flatmap(result, apply_sub(item, "Ɔ", "o", nil, "ɔ", nil))
		end

		return result
	end

	return flatmap(variants, call_one_term_ipa)
end


-- For bot usage; {{#invoke:pt-pronunc|IPA_string|SPELLING|style=STYLE|phonetic=PHONETIC}}
-- where
--
--   1. SPELLING is the word or respelling to generate pronunciation for;
--   2. required parameter style= indicates the pronunciation style to generate
--      (e.g. "rio" for Rio/Carioca pronunciation, "lisbon" for Lisbon pronunciation;
--      see the comment above export.IPA() above for the full list);
--   3. phonetic=1 specifies to generate the phonetic rather than phonemic pronunciation;
function export.IPA_string(frame)
	local iparams = {
		[1] = {},
		["style"] = {required = true},
		["phonetic"] = {type = "boolean"},
	}
	local iargs = require("Module:parameters").process(frame.args, iparams)
	return export.IPA(iargs[1], iargs.style, iargs.phonetic)
end


function export.express_styles(inputs, args_style)
	local pronuns_by_style = {}
	local expressed_styles = {}

	local function dostyle(style)
		pronuns_by_style[style] = {}
		for _, val in ipairs(inputs[style]) do
			local pronuns = export.IPA(val, style)
			for _, pronun in ipairs(pronuns) do
				table.insert(pronuns_by_style[style], pronun)
			end
		end
	end

	local function all_available(styles)
		local available_styles = {}
		for _, style in ipairs(styles) do
			if pronuns_by_style[style] then
				table.insert(available_styles, style)
			end
		end
		return available_styles
	end

	local function express_style(hidden_tag, tag, styles, indent)
		indent = indent or 1
		if hidden_tag == true then
			hidden_tag = tag
		end
		if type(styles) == "string" then
			styles = {styles}
		end
		styles = all_available(styles)
		if #styles == 0 then
			return
		end
		local style = styles[1]

		-- If style specified, make sure it matches the requested style.
		local style_matches
		if not args_style then
			style_matches = true
		else
			local or_styles = rsplit(args_style, "%s*,%s*")
			for _, or_style in ipairs(or_styles) do
				local and_styles = rsplit(or_style, "%s*%+%s*")
				local and_matches = true
				for _, and_style in ipairs(and_styles) do
					local negate
					if and_style:find("^%-") then
						and_style = and_style:gsub("^%-", "")
						negate = true
					end
					local this_style_matches = false
					for _, part in ipairs(styles) do
						if part == and_style then
							this_style_matches = true
							break
						end
					end
					if negate then
						this_style_matches = not this_style_matches
					end
					if not this_style_matches then
						and_matches = false
					end
				end
				if and_matches then
					style_matches = true
					break
				end
			end
		end
		if not style_matches then
			return
		end

		local new_style = {
			tag = tag,
			represented_styles = styles,
			pronuns = pronuns_by_style[style],
			indent = indent,
		}
		for _, hidden_tag_style in ipairs(expressed_styles) do
			if hidden_tag_style.tag == hidden_tag then
				table.insert(hidden_tag_style.styles, new_style)
				return
			end
		end
		table.insert(expressed_styles, {
			tag = hidden_tag,
			styles = {new_style},
		})
	end

	for style, _ in pairs(inputs) do
		dostyle(style)
	end

	local function diff(style1, style2)
		if not pronuns_by_style[style1] or not pronuns_by_style[style2] then
			return true
		end
		return not m_table.deepEquals(pronuns_by_style[style1], pronuns_by_style[style2])
	end
	local gbr_sp_different = diff("gbr", "sp")
	local gbr_rio_different = diff("gbr", "rio")
	local gpt_cpt_different = diff("gpt", "cpt")
	local gpt_spt_different = diff("gpt", "spt")
	local gbr_gpt_different = diff("gbr", "gpt") -- general differences between BP and EP
	
	if not gbr_sp_different and not gbr_rio_different and not gpt_cpt_different and not gbr_gpt_different then
		-- All the same
		express_style(false, false, export.all_styles)
	else
		-- Within Brazil
		express_style("[[w:Brazilian_Portuguese|Brazil]]", "[[w:Brazilian_Portuguese|Brazil]]", "gbr")
		if gbr_sp_different then
			express_style("[[w:Brazilian_Portuguese|Brazil]]", "[[w:Paulistano_dialect|São Paulo]]", "sp", 2)
		end
		if gbr_rio_different then
			express_style("[[w:Brazilian_Portuguese|Brazil]]", "[[w:Carioca#Sociolect|Rio de Janeiro]]", "rio", 2)
		end
		
		-- Within Portugal
		express_style("[[w:European_Portuguese|Portugal]]", "[[w:European_Portuguese|Portugal]]", "gpt")
		if gpt_cpt_different then
			express_style("[[w:European_Portuguese|Portugal]]", "Central Portugal", "cpt", 2)
		end
		if gpt_spt_different then
			express_style("[[w:European_Portuguese|Portugal]]", "Southern Portugal", "spt", 2)
		end
	end
	return expressed_styles
end


function export.show(frame)
	-- Create parameter specs
	local params = {
		[1] = {}, -- this replaces style group 'all'
		["pre"] = {},
		["post"] = {},
		["ref"] = {},
		["style"] = {},
		["bullets"] = {type = "number", default = 1},
	}
	for group, _ in pairs(export.all_style_groups) do
		if group ~= "all" then
			params[group] = {}
		end
	end
	for _, style in ipairs(export.all_styles) do
		params[style] = {}
	end

	-- Parse arguments
	local parargs = frame:getParent().args
	local args = require("Module:parameters").process(parargs, params)

	-- Set inputs
	local inputs = {}
	-- If 1= specified, do all styles.
	if args[1] then
		for _, style in ipairs(export.all_styles) do
			inputs[style] = args[1]
		end
	end
	-- Then do remaining style groups other than 'all', overriding 1= if given.
	for group, styles in pairs(export.all_style_groups) do
		if group ~= "all" and args[group] then
			for _, style in ipairs(styles) do
				inputs[style] = args[group]
			end
		end
	end
	-- Then do individual style settings.
	for _, style in ipairs(export.all_styles) do
		if args[style] then
			inputs[style] = args[style]
		end
	end
	-- If no inputs given, set all styles based on current pagename.
	if not next(inputs) then
		local text = mw.title.getCurrentTitle().text
		for _, style in ipairs(export.all_styles) do
			inputs[style] = text
		end
	end

	for style, input in pairs(inputs) do
		inputs[style] = rsplit(input, ",")
	end
	local expressed_styles = export.express_styles(inputs, args.style)

	local lines = {}

	local function format_style(tag, expressed_style, is_first)
		local pronunciations = {}
		local formatted_pronuns = {}
		for _, pronun in ipairs(expressed_style.pronuns) do
			table.insert(pronunciations, {
				pron = "/" .. pronun.phonemic .. "/",
				qualifiers = pronun.qualifiers,
			})
			local formatted_phonemic = "/" .. pronun.phonemic .. "/"
			if pronun.qualifiers then
				formatted_phonemic = "(" .. table.concat(pronun.qualifiers, ", ") .. ") " .. formatted_phonemic
			end
			table.insert(formatted_pronuns, formatted_phonemic)
			table.insert(pronunciations, {
				pron = "[" .. pronun.phonetic .. "]",
			})
			table.insert(formatted_pronuns, "[" .. pronun.phonetic .. "]")
		end
		-- Number of bullets: When indent = 1, we want the number of bullets given by `args.bullets`,
		-- and when indent = 2, we want `args.bullets + 1`, hence we subtract 1.
		local bullet = string.rep("*", args.bullets + expressed_style.indent - 1) .. " "
		-- Here we construct the formatted line in `formatted`, and also try to construct the equivalent without HTML
		-- and wiki markup in `formatted_for_len`, so we can compute the approximate textual length for use in sizing
		-- the toggle box with the "more" button on the right.
		local pre = is_first and args.pre and args.pre .. " " or ""
		local pre_for_len = pre .. (tag and "(" .. tag .. ") " or "")
		pre = pre .. (tag and m_qual.format_qualifier(tag) .. " " or "")
		local post = is_first and (args.ref or "") .. (args.post and " " .. args.post or "") or ""
		local formatted = bullet .. pre .. m_IPA.format_IPA_full(lang, pronunciations) .. post
		local formatted_for_len = bullet .. pre .. "IPA(key): " .. table.concat(formatted_pronuns, ", ") .. post
		return formatted, formatted_for_len
	end

	for i, style_group in ipairs(expressed_styles) do
		if #style_group.styles == 1 then
			style_group.formatted, style_group.formatted_for_len =
				format_style(style_group.styles[1].tag, style_group.styles[1], i == 1)
		else
			style_group.formatted, style_group.formatted_for_len =
				format_style(style_group.tag, style_group.styles[1], i == 1)
			for j, style in ipairs(style_group.styles) do
				style.formatted, style.formatted_for_len =
					format_style(style.tag, style, i == 1 and j == 1)
			end
		end
	end

	local function textual_len(text)
		text = rsub(text, "<.->", "")
		return ulen(text)
	end

	local maxlen = 0
	for i, style_group in ipairs(expressed_styles) do
		local this_len = textual_len(style_group.formatted_for_len)
		if #style_group.styles > 1 then
			for _, style in ipairs(style_group.styles) do
				this_len = math.max(this_len, textual_len(style.formatted_for_len))
			end
		end
		maxlen = math.max(maxlen, this_len)
	end

	for i, style_group in ipairs(expressed_styles) do
		if #style_group.styles == 1 then
			table.insert(lines, "<div>\n" .. style_group.formatted .. "</div>")
		else
			local inline = '\n<div class="vsShow" style="display:none">\n' .. style_group.formatted .. "</div>"
			local full_prons = {}
			for _, style in ipairs(style_group.styles) do
				table.insert(full_prons, style.formatted)
			end
			local full = '\n<div class="vsHide">\n' .. table.concat(full_prons, "\n") .. "</div>"
			local em_length = math.floor(maxlen * 0.68) -- from [[Module:grc-pronunciation]]
			table.insert(lines, '<div class="vsSwitcher" data-toggle-category="pronunciations" style="width: ' .. em_length .. 'em; max-width:100%;"><span class="vsToggleElement" style="float: right;">&nbsp;</span>' .. inline .. full .. "</div>")
		end
	end

	-- major hack to get bullets working on the next line
	return table.concat(lines, "\n") .. "\n<span></span>"
end


return export
