local export = {}


--[=[

Authorship: Ben Wing <benwing2>

]=]

--[=[

TERMINOLOGY:

-- "slot" = A particular combination of case/number.
	 Example slot names for nouns are "gen_s" (genitive singular) and
	 "voc_p" (vocative plural). Each slot is filled with zero or more forms.

-- "form" = The declined Czech form representing the value of a given slot.

-- "lemma" = The dictionary form of a given Czech term. Generally the nominative
     masculine singular, but may occasionally be another form if the nominative
	 masculine singular is missing.
]=]

--[=[

Word examples:

Masculine:
---------

[[rozbor]] "analysis" {{cs-ndecl<m>}}
[[plat]] "salary" {{cs-ndecl<m>}}
[[ostrov]] "island" {{cs-ndecl|<m.gena.locě>}}
[[car]] "tsar" {{cs-ndecl|<m.an.nomplové>}}
[[bratr]] "brother" {{cs-ndecl|((<m.an>,bratři<np.overriding_gender:m-an.[collective, normally archaic]>))}}




Feminine:
---------

- Reducible vs. non-reducible: If before final a is a two-consonant cluster whose second consonant is b, k, h or a
  resonant l,r,m,n,v, default to reducible. If second consonant is something else, default to non-reducible. Exception:
  In a three-consonant cluster ClC and CrC, default to non-reducible as the l and r are vocalic (e.g. [[vrba]]).

Default reducible:

[[bavlnka]] "cotton" {{cs-ndecl|<f>}}
[[čtvrtka]] "Thursday" {{cs-ndecl|<f>}}
[[dršťka]] "tripe" {{cs-ndecl|<f>}} [gen pl drštěk]
[[jiskra]] "spark" {{cs-ndecl|<f>}}
[[kostra]] "skeleton" {{cs-ndecl|<f>}}
[[kůstka]] "bone" {{cs-ndecl|<f>}}
[[pastva]] "pasture" {{cs-ndecl|<f>}}
[[sestra]] "sister" {{cs-ndecl|<f>}}
[[tundra]] "tundra" {{cs-ndecl|<f>}}
[[vrstva]] "layer" {{cs-ndecl|<f>}}
[[vyjížďka]] "ride" {{cs-ndecl|<f>}} [gen pl vyjížděk]
[[hra]] "game" {{cs-ndecl|<f>}} [dat/loc sg hře, gen pl her]
[[kra]] "floe, iceberg" {{cs-ndecl|<f>}} [dat/loc sg kře, gen pl ker]
[[kresba]] "drawing" {{cs-ndecl|<f>}}
[[malba]] "painting" {{cs-ndecl|<f>}}
[[orba]] "ploughing" {{cs-ndecl|<f>}}
[[volba]] "choice, (pl) elections" {{cs-ndecl|<f>}}
[[kuchařka]] "cookbook; female cook" {{cs-ndecl|<f>}}
[[lebka]] "skull" {{cs-ndecl|<f>}}
[[loďka]] "small ship; rowing boat" {{cs-ndecl|<f>}} [gen pl loděk]
[[občanka]] "female citizen" {{cs-ndecl|<f>}}
[[oháňka]] "tail, oxtail" {{cs-ndecl|<f>}} [gen pl oháněk]
[[sirka]] "match (for lighting a fire)" {{cs-ndecl|<f>}}
[[cihla]] "brick" {{cs-ndecl|<f>}}
[[jehla]] "needle" {{cs-ndecl|<f>}}
[[metla]] "whisk, scourge, rod (for punishment)" {{cs-ndecl|<f>}}
[[modla]] "idol" {{cs-ndecl|<f>}}
[[truhla]] "chest (strong box)" {{cs-ndecl|<f>}}
[[firma]] "firm (business)" {{cs-ndecl|<f>}}
[[forma]] "form, mold" {{cs-ndecl|<f>}}
[[helma]] "helmet" {{cs-ndecl|<f>}}
[[palma]] "palm tree" {{cs-ndecl|<f>}}
[[šelma]] "beast of prey; carnivore" {{cs-ndecl|<f>}}
[[kašna]] "fountain" {{cs-ndecl|<f>}}
[[kněžna]] "princess" {{cs-ndecl|<f>}}
[[kůlna]] "shed, hut" {{cs-ndecl|<f>}}
[[putna]] "indifference, unimportance" {{cs-ndecl|<f>}}
[[učebna]] "classroom" {{cs-ndecl|<f>}}
[[cifra]] "digit" {{cs-ndecl|<f>}}
[[jikra]] "roe" {{cs-ndecl|<f>}}
[[souhra]] "" {{cs-ndecl|<f>}}
[[zebra]] "zebra" {{cs-ndecl|<f>}}
[[barva]] "color" {{cs-ndecl|<f>}}
[[jizva]] "scar" {{cs-ndecl|<f>}}
[[larva]] "larva" {{cs-ndecl|<f>}}

Default reducible but should not be reduced:

[[bomba]] "bomb" {{cs-ndecl|<f.-*>}}
[[plomba]] "filling, seal" {{cs-ndecl|<f.-*>}}
[[banka]] "bank (financial institution)" {{cs-ndecl|<f.-*>}}
[[konzerva]] "can, tin" {{cs-ndecl|<f.-*>}}
[[rezerva]] "reserve" {{cs-ndecl|<f.-*>}}
[[salva]] "" {{cs-ndecl|<f.-*>}}
[[želva]] "turtle" {{cs-ndecl|<f.-*>}}

Default non-reducible:

[[pomsta]] "revenge" {{cs-ndecl|<f>}} [gen pl pomst]
[[garda]] "" {{cs-ndecl|<f>}}
[[hvězda]] "star" {{cs-ndecl|<f>}}
[[pravda]] "truth" {{cs-ndecl|<f>}}
[[vražda]] "murder" {{cs-ndecl|<f>}}
[[harfa]] "harp" {{cs-ndecl|<f>}}
[[nymfa]] "nymph" {{cs-ndecl|<f>}}
[[archa]] "ark" {{cs-ndecl|<f>}}
[[valcha]] "washboard" {{cs-ndecl|<f>}}
[[lampa]] "lamp" {{cs-ndecl|<f>}}
[[pumpa]] "pump" {{cs-ndecl|<f>}}
[[rampa]] "ramp" {{cs-ndecl|<f>}}
[[škarpa]] "" {{cs-ndecl|<f>}}
[[elipsa]] "ellipse" {{cs-ndecl|<f>}}
[[římsa]] "windowsill, mantelpiece" {{cs-ndecl|<f>}}
[[gejša]] "geisha" {{cs-ndecl|<f>}}
[[celta]] "" {{cs-ndecl|<f>}}
[[cesta]] "road, journey" {{cs-ndecl|<f>}}
[[fakulta]] "faculty (of a university)" {{cs-ndecl|<f>}}
[[fronta]] "queue; front (meteorology, military)" {{cs-ndecl|<f>}}
[[krypta]] "crypt" {{cs-ndecl|<f>}}
[[lišta]] "slat; bar" {{cs-ndecl|<f>}}
[[aorta]] "aorta" {{cs-ndecl|<f>}}
[[plenta]] "" {{cs-ndecl|<f>}}
[[sekta]] "sect, cult" {{cs-ndecl|<f>}}
[[brynza]] "bryndza (type of soft cheese)" {{cs-ndecl|<f>}}
[[burza]] "stock exchange" {{cs-ndecl|<f>}}

Default non-reducible but should be reduced:

[[výspa]] "islet" {{cs-ndecl|<f.*>}}
[[kapsa]] "pocket" {{cs-ndecl|<f.*>}}
[[buchta]] "bun" {{cs-ndecl|<f.*>}}
[[plachta]] "sail" {{cs-ndecl|<f.*>}}
[[šachta]] "shaft, chute" {{cs-ndecl|<f.*>}}

Should not be reduced due to vocalic l or r:

[[vrba]] "willow" {{cs-ndecl|<f>}}
[[srha]] "cocksfoot" {{cs-ndecl|<f>}}

Exceptional reducible:

[[mzda]] "wage" {{cs-ndecl|<f.*.genpl:mezd>}}
[[msta]] "revenge" {{cs-ndecl|<f.*.genpl:mest>}}

Optional reducible:

[[deska]] "plate" {{cs-ndecl|<f.*,-*>}}
[[jachta]] "yacht" {{cs-ndecl|<f.*,-*>}}
[[karta]] "card" {{cs-ndecl|<f.*,-*[very rare]>}}
[[kruchta]] "church porch" {{cs-ndecl|<f.*,-*>}}
[[přilba]] "helmet" {{cs-ndecl|<f.*,-*[rare]>}}

Shortening in gen pl and maybe elsewhere:

[[bába]] "old woman" {{cs-ndecl|<f.#>}} [gen pl bab]
[[chvála]] "praise" {{cs-ndecl|<f.#>}} [gen pl chval]
[[jáma]] "pit, hole" {{cs-ndecl|<f.#>}} [gen pl jam]
[[sláma]] "straw" {{cs-ndecl|<f.#>}} [gen pl slam]
[[díra]] "hole" {{cs-ndecl|<f.#ě>}} [gen pl děr, dat/loc sg díře]
[[houba]] "mushroom, sponge" {{cs-ndecl|<f.#>}} [gen pl hub]
[[smlouva]] "contract, treaty" {{cs-ndecl|<f.#>}} [gen pl smlouv]
[[moucha]] "fly" {{cs-ndecl|<f.#>}} [gen pl much, dat/log sg mouše]
[[touha]] "desire" {{cs-ndecl|<f.#>}} [gen pl tuh, dat/log sg touze]
[[brána]] "gate" {{cs-ndecl|<f.##,#>}} [gen pl bran, dat pl branám/bránám, loc pl branách/bránách, ins pl branami/bránami, ins sg branou/bránou]
[[žába]] "frog" {{cs-ndecl|<f.##,#.ins:žábou>}} [gen pl žab, dat pl žabám/žábám, loc pl žabách/žábách, ins pl žabami/žábami, ins sg žábou only]
[[vrána]] "frog" {{cs-ndecl|<f.##,#.ins:vránou>}} [gen pl vran, dat pl vranám/vránám, loc pl vranách/vránách, ins pl vranami/vránami, ins sg vránou only]
[[žíla]] "vein" {{cs-ndecl|<f.##,#>}} [gen pl žil, dat pl žilám/žílám, loc pl žilách/žílách, ins pl žilami/žílami, ins sg žilou/žílou]
[[lípa]] "lime tree, linden" {{cs-ndecl|<f.##,#>}} [gen pl lip, dat pl lipám/lípám, loc pl lipách/lípách, ins pl lipami/lípami, ins sg lipou/lípou]
[[síla]] "strength, force" {{cs-ndecl|<f.##,#>}} [gen pl sil, dat pl silám/sílám, loc pl silách/sílách, ins pl silami/sílami, ins sg silou/sílou]
[[dráha]] "track, lane" {{cs-ndecl|<f.##,#>}} [gen pl drah, dat pl drahám/dráhám, loc pl drahách/dráhách, ins pl drahami/dráhami, ins sg drahou/dráhou]
[[míra]] "measure" {{cs-ndecl|<f.##ě,#ě>}} [gen pl měr, dat pl měrám/mírám, loc pl měrách/mírách, ins pl měrami/mírami, ins sg měrou/mírou, dat/log sg míře]
[[práce]] "work" {{cs-ndecl|<f.##>}} [gen pl prací, dat pl pracím, loc pl pracích, ins pl pracemi, ins sg prací]
[[autodráha]] "slot car set" {{cs-ndecl|<f.ins:autodrahou:autodráhou>}}
[[kláda]] "log" {{cs-ndecl|<f>}}
[[žláza]] "gland" {{cs-ndecl|<f>}}
[[bříza]] "birch" {{cs-ndecl|<f>}}
[[hlíza]] "tuber" {{cs-ndecl|<f>}}
[[jáhla]] "millet" {{cs-ndecl|<f.*#,*>}}
[[slíva]] "plum" {{cs-ndecl|<f.-,#>}}
[[mísa]] "bowl" {{cs-ndecl|<f.#,->}}




Neuter:
-------

- Reducible vs. non-reducible: Same rule as for feminines.

Default reducible:

[[clo]] "" {{cs-ndecl|<n>}} [gen pl cel]
[[dno]] "" {{cs-ndecl|<n>}} [gen pl den]
[[jho]] "" {{cs-ndecl|<n.locu.locplách>}} [gen pl jeh]
[[sklo]] "glass" {{cs-ndecl|<n.loce>}} [gen pl skel, loc sg skle]
[[zlo]] "evil" {{cs-ndecl|<n.locu:e>}} [gen pl zel, loc sg zlu/zle]
[[božstvo]] "deity" {{cs-ndecl|<n>}}

Default reducible but should not be reduced:

[[hejno]] "flock" {{cs-ndecl|<n.-*>}}
[[manko]] "" {{cs-ndecl|<n.-*>}}

Should not be reduced due to vocalic l or r:

[[zrno]] "grain" {{cs-ndecl|<n>}}

Default non-reducible but should be reduced:

[[jablko]] "apple" {{cs-ndecl|<n.*>}}

Shortening in gen pl and maybe elsewhere:

[[dílo]] "work" {{cs-ndecl|<n.#ě.loce>}} [gen pl děl]
[[jádro]] "kernel, core" {{cs-ndecl|<n.*#.locu:e>}} [gen pl jader, loc sg jádru/jádře]
[[jméno]] "name" {{cs-ndecl|<n.#>}} [gen pl jmen, loc sg jméně/jménu]
[[játra]] "liver" {{cs-ndecl|<n.*#.pl>}} [gen pl jater]
[[péro]] "pen" {{cs-ndecl|<n.#.locu>}} [gen pl per, loc sg péru]
[[záda]] "back" {{cs-ndecl|<n.#.pl>}} [gen pl zad]
[[léto]] "summer; (pl) years" {{cs-ndecl|<n.##,#.ins:létem>}} [gen pl let, dat pl letům/létům, loc pl letech/létech, ins pl lety/léty, ins sg only létem]

Pluralia tantum:
----------------

Masculine:

[[alimenty]] "alimony" {{cs-ndecl|<mp>}}
[[Blíženci]] "Gemini" (pl. of [[blíženec]] "twin" reducible) {{cs-ndecl|<mp-an>}}
[[Bory]] "Bory" (Czech village) {{cs-ndecl|<mp>}}
[[Cookovy ostrovy]] "Cook Islands" {{cs-ndecl|[[Cookovy]]<+> [[ostrovy]]<mp>}}
[[čáry]] "magic, spells"


Adjectival:
-----------

Masculine:

Feminine:

Neuter:

[[výživné]] "alimony"

Adjectival pluralia tantum:
---------------------------

Masculine:

Feminine:

Neuter:

[[výživné]] "alimony"


]=]

--[=[

FIXME:

1. Finish synthesize_singular_lemma().
2. Implement feminines in -ea, -oa/-ua, -ia, -oe. [DONE]
3. Implement "mixed" masculine nouns in -l, -n, -t (each different, also inanimate vs. animate).
4. Allow 'stem:' override after vowel-final words like [[centurio]]. [DONE using decllemma:]
5. Support masculine foreign nouns in -us/-os/-es.
6. Support masculine foreign nouns in unpronounced final -e (e.g. [[software]]).
7. Support neuter foreign nouns in -um/-on. [DONE]
8. Support neuter foreign nouns in -ium/-ion.
9. Support paired body parts, e.g. [[ruka]], [[noha]], [[oko]], [[ucho]], [[koleno]], [[rameno]].
10. Support masculine nouns in -e/ě that are neuter in the plural.
11. Correctly handle -e vs. -ě, e.g. soft neuters have both [[kutě]] and [[poledne]]. [DONE]

]=]

local lang = require("Module:languages").getByCode("cs")
local m_table = require("Module:table")
local m_links = require("Module:links")
local m_string_utilities = require("Module:string utilities")
local iut = require("Module:inflection utilities")
local m_para = require("Module:parameters")
local com = require("Module:User:Benwing2/cs-common")

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
local usub = mw.ustring.sub
local uupper = mw.ustring.upper
local ulower = mw.ustring.lower

local force_cat = false -- set to true to make categories appear in non-mainspace pages, for testing

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


local output_noun_slots = {
	nom_s = "nom|s",
	gen_s = "gen|s",
	dat_s = "dat|s",
	acc_s = "acc|s",
	voc_s = "voc|s",
	loc_s = "loc|s",
	ins_s = "ins|s",
	nom_p = "nom|p",
	gen_p = "gen|p",
	dat_p = "dat|p",
	acc_p = "acc|p",
	voc_p = "voc|p",
	loc_p = "loc|p",
	ins_p = "ins|p",
}


local output_noun_slots_with_linked = m_table.shallowcopy(output_noun_slots)
output_noun_slots_with_linked["nom_s_linked"] = "nom|s"
output_noun_slots_with_linked["nom_p_linked"] = "nom|p"

local input_params_to_slots_both = {
	[1] = "nom_s",
	[2] = "nom_p",
	[3] = "gen_s",
	[4] = "gen_p",
	[5] = "dat_s",
	[6] = "dat_p",
	[7] = "acc_s",
	[8] = "acc_p",
	[9] = "voc_s",
	[10] = "voc_p",
	[11] = "loc_s",
	[12] = "loc_p",
	[13] = "ins_s",
	[14] = "ins_p",
}


local input_params_to_slots_sg = {
	[1] = "nom_s",
	[2] = "gen_s",
	[3] = "dat_s",
	[4] = "acc_s",
	[5] = "voc_s",
	[6] = "loc_s",
	[7] = "ins_s",
}


local input_params_to_slots_pl = {
	[1] = "nom_p",
	[2] = "gen_p",
	[3] = "dat_p",
	[4] = "acc_p",
	[5] = "voc_p",
	[6] = "loc_p",
	[7] = "ins_p",
}


local cases = {
	nom = true,
	gen = true,
	dat = true,
	acc = true,
	voc = true,
	loc = true,
	ins = true,
}


local gender_code_to_desc = {
	m = "masculine",
	f = "feminine",
	n = "neuter",
}


--[=[

Maybe modify the stem and/or ending in certain special cases:
1. Final -e in vocative singular triggers first palatalization of the stem in some cases (e.g. hard masc).
2. Endings beginning with ě, i, í trigger second palatalization, as does -e in the loc_s.

NOTE: Correctly handling -e vs. -ě and -tdn/-ťďň alternations is tricky. It's especially tricky with labials, because
e.g. we have both soft neuter [[Labe]] and t-stem neuter [[hříbě]]. It's true that t-stems generally prefer ě when
possible and soft stems don't, but some soft stems do have -ě, e.g. [[kutě]] "bed". The way we handle this as follows:
1. We maintain the underlying stems always in their "pronounced" form, i.e. if the last consonant is pronounced ť/ď/ň
   we maintain the stem in that form, but if pronounced t/d/n, we use those consonants. Hence neuter [[poledne]] "noon"
   has stem 'poledn-' but neuter [[štěně]] "puppy" has stem 'štěň'. If the stem ends in labial + /j/, we use a special
   TEMP_SOFT_LABIAL character after the labial (rather than 'j', in case of stems that actually have a written 'j' in
   them such as [[banjo]]).
2. In combine_stem_ending(), we convert the stem back to the written form before adding the ending. If the ending begins
   with -e, this may entail converting -e to -ě. "Converting to the written form" converts ť/ď/ň to plain equivalents
   and deleting TEMP_SOFT_LABIAL before -e, converting -e to -ě with such consonants. The same conversions happen
   before other front consonants -ě/-é/-i/-í, which don't allow ť/ď/ň to precede, and in all cases with
   TEMP_SOFT_LABIAL, which is not an actual consonant.
3. Some endings, e.g. feminine dative/locative singular -ě/e, convert underlying plain t/d/n and labials to their
   palatalized form. This is associated with the second palatalization. In these cases we specify the ending as -ě in
   the code, which is maintained after plain coronals and labials in combine_stem_ending(); in all other cases we
   specify the ending as -e.
]=]
local function apply_special_cases(base, slot, stem, ending)
	local palatalize_voc
	if slot == "voc_s" and ending == "e" and base.palatalize_voc then
		local palstem = com.apply_first_palatalization(stem)
		-- According to IJP, nouns ending in -Cr palatalize in the vocative, but those in -Vr don't. In reality,
		-- though, it's more complex. It appears that animate nouns in -Cr tend to palatalize but inanimate nouns
		-- do it optionally. Specifics:
		-- -- Inanimate nouns with optional palatalization (ř listed second): [[alabastr]], [[amfiteátr]], [[barometr]],
		--    [[centilitr]], [[centrimetr]], [[decilitr]], [[decimetr]], [[Dněstr]], [[filtr]], [[galvanometr]],
		--    [[hektolitr]], [[kalorimetr]], [[litr]], [[lustr]], [[manometr]], [[manšestr]], [[metr]] (NOTE: is both
		--    animate and inanimate), [[mikrometr]], [[miliampérmetr]], [[mililitr]], [[nanometr]], [[orchestr]],
		--    [[parametr]], [[piastr]], [[půllitr]], [[radiometr]], [[registr]], [[rotmistr]], [[semestr]], [[skútr]],
		--    [[spirometr]], [[svetr]], [[šutr]], [[tachometr]], [[titr]], [[vítr]] (NOTE: has í-ě alternation),
		--    [[voltmetr]]; [[bagr]], [[bunkr]], [[cedr]], [[Dněpr]], [[fofr]], [[habr]] (NOTE: ř listed first), [[hadr]]
		--    (NOTE: ř listed first), [[hamr]], [[kafr]], [[kepr]], [[kopr]], [[koriandr]], [[krekr]], [[kufr]],
		--    [[Kypr]], [[lágr]], [[lógr]], [[manévr]], [[masakr]], [[okr]], [[oleandr]], [[pulovr]], [[šlágr]],
		--    [[vichr]] (NOTE: ř listed first), [[žánr]]
		--
		-- -- Inanimate nouns that don't palatalize: [[ampérmetr]], [[anemometr]], [[sfygmomanometr]], [[sfygmometr]];
		--    [[dodekaedr]], [[Hamr]], [[ikozaedr]], [[kvádr]], [[sandr]], [[torr]]
		--    
		-- -- Animate nouns that palatalize: [[arbitr]], [[bratr]], [[ekonometr]], [[foniatr]], [[fotr]], [[geometr]],
		--    [[kmotr]], [[lotr]], [[magistr]], [[metr]] (NOTE: is both animate and inanimate), [[ministr]], [[mistr]],
		--    [[pediatr]], [[Petr]], [[psychiatr]], [[purkmistr]], [[setr]], [[šamstr]]; [[bobr]], [[fajnšmekr]],
		--    [[humr]], [[hypochondr]], [[kapr]], [[lídr]], [[negr]], [[obr]], [[salamandr]], [[sólokapr]], [[švagr]],
		--    [[tygr]], [[zlobr]], [[zubr]]
		--
		-- -- Animate nouns with optional palatalization (ř listed first): [[Silvestr]]; [[Alexandr]], [[snajpr]]
		--
		-- Note the inconsistencies, e.g. [[sfygmomanometr]] and [[ampérmetr]] don't palatalize but [[manometr]] and
		-- [[miliampérmetr]] do it optionally. In reality, inanimate vocatives are extremely rare so this may not be the
		-- final word.
		if base.animacy == "inan" and rfind(stem, com.cons_c .. "r$") and not rfind(stem, "rr$") then
			-- optional r -> ř
			stem = {stem, palstem}
		else
			stem = palstem
		end
	elseif rfind(ending, "^[ěií]") or slot == "loc_s" and ending == "e" then
		if ending == "ích" and rfind(stem, "ck$") then
			-- IJP says nouns in -ck (back, comeback, crack, deadlock, hatchback, hattrick, joystick, paperback, quarterback,
			-- rock, soundtrack, track, truck) simplify the resulting -cc ending in the loc_p to -c.
			stem = rsub(stem, "ck$", "k")
		end
		-- loc_s of hard masculines is sometimes -e/ě; the user might indicate this as -e, which we should handle
		-- correctly
		stem = com.apply_second_palatalization(stem)
	end
	return stem, ending
end


local function skip_slot(number, slot)
	return number == "sg" and rfind(slot, "_p$") or
		number == "pl" and rfind(slot, "_s$")
end


local function add(base, slot, stems, endings, footnotes)
	if not endings then
		return
	end
	if skip_slot(base.number, slot) then
		return
	end
	footnotes = iut.combine_footnotes(iut.combine_footnotes(base.footnotes, stems.footnotes), footnotes)
	if type(endings) == "string" then
		endings = {endings}
	end
	for _, ending in ipairs(endings) do
		local stem
		if ending == "-" then
			stem = base.user_specified_lemma
			ending = ""
		elseif slot == "ins_s" or slot == "dat_p" or slot == "loc_p" or slot == "ins_p" then
			stem = stems.oblique_stem
		elseif rfind(ending, "^" .. com.vowel_c) then
			stem = stems.vowel_stem
		else
			stem = stems.nonvowel_stem
		end
		stem, ending = apply_special_cases(base, slot, stem, ending)
		ending = iut.combine_form_and_footnotes(ending, footnotes)
		local function combine_stem_ending(stem, ending)
			return com.combine_stem_ending(base, slot, stem, ending)
		end
		iut.add_forms(base.forms, slot, stem, ending, combine_stem_ending)
	end
end


local function process_slot_overrides(base, do_slot)
	for slot, overrides in pairs(base.overrides) do
		if skip_slot(base.number, slot) then
			error("Override specified for invalid slot '" .. slot .. "' due to '" .. base.number .. "' number restriction")
		end
		if do_slot(slot) then
			base.slot_overridden[slot] = true
			base.forms[slot] = nil
			for _, override in ipairs(overrides) do
				for _, value in ipairs(override.values) do
					local form = value.form
					local combined_notes = iut.combine_footnotes(base.footnotes, value.footnotes)
					if override.full then
						if form ~= "" then
							iut.insert_form(base.forms, slot, {form = form, footnotes = combined_notes})
						end
					else
						for _, stems in ipairs(base.stem_sets) do
							add(base, slot, stems, form, combined_notes)
						end
					end
				end
			end
		end
	end
end


local function add_decl(base, stems,
	gen_s, dat_s, acc_s, voc_s, loc_s, ins_s,
	nom_p, gen_p, dat_p, acc_p, loc_p, ins_p, footnotes
)
	add(base, "nom_s", stems, "-", footnotes)
	add(base, "gen_s", stems, gen_s, footnotes)
	add(base, "dat_s", stems, dat_s, footnotes)
	add(base, "acc_s", stems, acc_s, footnotes)
	add(base, "voc_s", stems, voc_s, footnotes)
	add(base, "loc_s", stems, loc_s, footnotes)
	add(base, "ins_s", stems, ins_s, footnotes)
	add(base, "nom_p", stems, nom_p, footnotes)
	add(base, "gen_p", stems, gen_p, footnotes)
	add(base, "dat_p", stems, dat_p, footnotes)
	add(base, "acc_p", stems, acc_p, footnotes)
	add(base, "loc_p", stems, loc_p, footnotes)
	add(base, "ins_p", stems, ins_p, footnotes)
end


local function handle_derived_slots_and_overrides(base)
	local function is_non_derived_slot(slot)
		return slot ~= "voc_s" and slot ~= "voc_p" and slot ~= "acc_s"
	end

	local function is_derived_slot(slot)
		return not is_non_derived_slot(slot)
	end

	base.slot_overridden = {}
	-- Handle overrides for the non-derived slots. Do this before generating the derived
	-- slots so overrides of the source slots (e.g. nom_p) propagate to the derived slots.
	process_slot_overrides(base, is_non_derived_slot)

	-- Generate the remaining slots that are derived from other slots.
	iut.insert_forms(base.forms, "voc_p", base.forms.nom_p)
	if not base.forms.acc_s and not base.slot_overridden.acc_s then
		iut.insert_forms(base.forms, "acc_s", base.forms[base.animacy == "inan" and "nom_s" or "gen_s"])
	end
	local function tag_with_variant(variant)
		return function(form) return form .. variant end
	end
	local function maybe_tag_with_variant(forms, variant)
		if base.multiword then
			return iut.map_forms(forms, tag_with_variant(variant))
		else
			return forms
		end
	end
	if base.surname then
		iut.insert_forms(base.forms, "voc_s", base.forms.nom_s)
	end

	-- Handle overrides for derived slots, to allow them to be overridden.
	process_slot_overrides(base, is_derived_slot)

	-- Compute linked versions of potential lemma slots, for use in {{cs-noun}}.
	-- We substitute the original lemma (before removing links) for forms that
	-- are the same as the lemma, if the original lemma has links.
	for _, slot in ipairs({"nom_s", "nom_p"}) do
		iut.insert_forms(base.forms, slot .. "_linked", iut.map_forms(base.forms[slot], function(form)
			if form == base.orig_lemma_no_links and rfind(base.orig_lemma, "%[%[") then
				return base.orig_lemma
			else
				return form
			end
		end))
	end
end


-- Table mapping declension types to functions to decline the noun. The function takes two arguments, `base` and
-- `stems`; the latter specifies the computed stems (vowel vs. non-vowel, singular vs. plural) and whether the noun
-- is reducible and/or has vowel alternations in the stem. Most of the specifics of determining which stem to use
-- and how to modify it for the given ending are handled in add_decl(); the declension functions just need to generate
-- the appropriate endings.
local decls = {}
-- Table specifying additional properties for declension types. Every declension type must have such a table, which
-- specifies which category or categories to add and what annotation to show in the title bar of the declension table.
--
-- * Only the `cat` property of this table is mandatory; there is also a `desc` property to specify the annotation, but
--   this can be omitted and the annotation will then be computed from the `cat` property. The `cat` property is either
--   a string, a list of strings or a function (of two arguments, `base` and `stems` as above) returning a string or
--   list of strings. The string can contain the keywords GENDER to substitute the gender (and animacy for masculine
--   nouns) and POS (to substitute the pluralized part of speech). The keyword GENPOS is equivalent to 'GENDER POS'. If
--   no keyword is present, ' GENPOS' is added onto the end. If only GENDER is present, ' POS' is added onto the end.
--   In all cases, the language name is added onto the beginning to form the full category name.
-- * The `desc` property is of the same form as the `cat` property and specifies the annotation to display in the title
--   bar (which may have the same format as the category minus the part of speech, or may be abbreviated). The value
--   may not be a list of strings, as only one annotation is displayed. If omitted, it is derived from the category
--   spec(s) by taking the last category (if more than one is given) and removing ' POS' before keyword substitution.
local declprops = {}

local function default_nom_pl_animate_masc(base)
	return
		-- monosyllabic words: Dánové, Irové, králové, mágové, Rusové, sokové, synové, špehové, zběhové, zeťové, manové, danové
		-- (but Žid → Židé, Čech → Češi).
		com.is_monosyllabic(base.lemma) and "ové" or
		-- barmani, gentlemani, jazzmani, kameramani, narkomani, ombudsmani, pivotmani, rekordmani, showmani, supermani, toxikomani
		rfind(base.lemma, "^" .. com.lowercase_c .. ".*man$") and "i" or
		-- terms ending in -an after a palatal or potentially palatal consonant (but -man forms -mani unless in a proper noun):
		-- Brňan → Brňané, křesťan → křesťané, měšťan → měšťané, Moravan → Moravané, občan → občané, ostrovan → ostrované,
		-- Pražan → Pražané, Slovan → Slované, svatebčan → svatebčané, venkovan → venkované; some late formations pluralize this way
		-- but don't have a palatal consonant preceding the -an, e.g. [[pohan]], [[Oděsan]]; these need manual overrides
		rfind(base.lemma, "[ňďťščžřj" .. com.labial .. "]an$") and {"é", "i"} or -- most now can also take -i
		-- proper names: Baťové, Novákové, Petrové, Tomášové, Vláďové; but exclude demonyms
		rfind(base.lemma, "^" .. com.uppercase_c) and not rfind(base.lemma, "ec$") and "ové" or
		-- demonyms: [[Albánec]], [[Gruzínec]], [[Izraelec]], [[Korejec]], [[Libyjec]], [[Litevec]], [[Němec]], [[Portugalec]]
		rfind(base.lemma, "^" .. com.uppercase_c .. ".*ec$") and "i" or
		-- From here on down, we're dealing only with lowercase terms.
		-- buditelé, budovatelé, čekatelé, činitelé, hostitelé, jmenovatelé, pisatelé, ručitelé, velitelé, živitelé
		rfind(base.lemma, ".*tel$") and "é" or
		-- husita → husité, izraelita → izraelité, jezuita → jezuité, kosmopolita → kosmopolité, táborita → táborité
		-- fašista → fašisté, filatelista → filatelisté, fotbalista → fotbalisté, kapitalista → kapitalisté,
		--   marxista → marxisté, šachista → šachisté, terorista → teroristé
		rfind(base.lemma, ".*is?ta$") and "é" or
		-- gymnasta → gymnasté, fantasta → fantasté
		rfind(base.lemma, ".*asta$") and "é" or
		-- remaining masculines in -a (which may not go through this code at all);
		-- nouns in -j: čaroděj → čarodějové, lokaj → lokajové, patricij → patricijové, plebej → plebejové, šohaj → šohajové, žokej → žokejové
		-- nouns in -l: apoštol → apoštolové, břídil → břídilové, fňukal → fňukalové, hýřil → hýřilové, kutil → kutilové,
		--   loudal → loudalové, mazal → mazalové, škrabal → škrabalové, škudlil → škudlilové, vyvrhel → vyvrhelové, žvanil → žvanilové
		--   (we excluded those in -tel above)
		rfind(base.lemma, ".*[jla]$") and "ové" or
		-- archeolog → archeologové, biolog → biologové, geolog → geologové, meteorolog → meteorologové
		rfind(base.lemma, ".*log$") and "ové" or
		-- dramaturg → dramaturgové, chirurg → chirurgové
		rfind(base.lemma, ".*urg$") and "ové" or
		-- fotograf → fotografové, geograf → geografové, lexikograf → lexikografové
		rfind(base.lemma, ".*graf$") and "ové" or
		-- bibliofil → bibliofilové, germanofil → germanofilové
		rfind(base.lemma, ".*fil$") and "ové" or
		-- rusofob → rusofobové
		rfind(base.lemma, ".*fob$") and "ové" or
		-- agronom → agronomové, ekonom → ekonomové
		rfind(base.lemma, ".*nom$") and "ové" or
		"i"
end


decls["hard-m"] = function(base, stems)
	-- Nouns ending in hard -c, e.g. [[hec]] "joke", [[kibuc]] "kibbutz", don't palatalize.
	base.palatalize_voc = not rfind(stems.vowel_stem, "c$")
	base.hard_c = true
	local velar = rfind(stems.vowel_stem, com.velar_c .. "$")
	-- inanimate gen_s in -a (e.g. [[zákon]] "law", [[oběd]] "lunch", [[kostel]] "church", [[Jičín]] (a place),
	-- [[Tachov]] (a place), [[dnešek]] "today", [[leden]] "January", [[trujúhelník]] "triangle") needs to be given
	-- manually, using '<gena>' 
	local gen_s = base.animacy == "inan" and "u" or "a"
	-- animates with dat_s only in -u (e.g. [[člověk]] "person", [[Bůh]] "God") need to give this manually,
	-- using '<datu>'
	local dat_s = base.animacy == "inan" and "u" or {"ovi", "u"}
	-- inanimates with loc_s in -e/ě need to give this manually, using <locě>, but it will trigger the second
	-- palatalization automatically
	local loc_s = dat_s
	-- velar-stem animates with voc_s in -e (e.g. [[Bůh]] "God", voc_s 'Bože'; [[člověk]] "person", voc_s 'člověče')
	-- need to give this manually using <voce>; it will trigger the first palatalization automatically
	local voc_s = velar and "u" or "e" -- 'e' will trigger first palatalization in apply_special_cases()
	-- nom_p in -i will trigger second palatalization in apply_special_cases()
	local nom_p = base.animacy == "inan" and "y" or default_nom_pl_animate_masc(base)
	-- Per IJP and Janda and Townsend:
	-- * loc_p in -ích is currently the default for velars but not otherwise; it will automatically trigger the second
	--   palatalization (e.g. [[práh]] "threshold", loc_p 'prazích'). Otherwise, -ích needs to be given manually using
	--   <locplích>, e.g. [[les]] "forest"; [[hotel]] "hotel"; likewise for loc_p in -ách (e.g. [[plech]]
	--   "metal plate"), using <locplách>.
	-- * Inanimate hard nouns in -c normally have -ech: [[hec]] "joke", [[tác]] "tray", [[truc]], [[kec]], [[frc]],
	--   [[flanc]], [[kibuc]] "kibbutz", [[pokec]] "chat".
	local loc_p = velar and "ích" or "ech"
	add_decl(base, stems, gen_s, dat_s, nil, voc_s, loc_s, "em",
		-- loc_p in -ích (e.g. [[les]] "forest"; [[hotel]] "hotel"; [[práh]] "threshold", loc_p 'prazích') needs to be
		-- given manually using <locplích>; it will automatically trigger the second palatalization; loc_p in -ách (e.g.
		-- [[plech]] "metal plate") also needs to be given manually using <locplách>
		nom_p, "ů", "ům", "y", loc_p, "y")
end

declprops["hard-m"] = {
	desc = function(base, stems)
		if rfind(stems.vowel_stem, com.velar_c .. "$") then
			return "velar GENDER"
		else
			return "hard GENDER"
		end
	end,
	cat = function(base, stems)
		if rfind(stems.vowel_stem, com.velar_c .. "$") then
			return "velar-stem"
		else
			return "hard"
		end
	end
}


decls["soft-m"] = function(base, stems)
	base.palatalize_voc = true
	-- animates with dat_s only in -i need to give this manually, using '<dati>'
	local dat_s = base.animacy == "inan" and "i" or {"ovi", "i"}
	local loc_s = dat_s
	-- Per IJP, the vast majority of soft masculine animates take -i in the voc_s, but those in -ec take -e with first
	-- palatalization to -če (e.g. [[otec]] "father", [[lovec]] "hunter", [[blbec]] "fool, idiot",
	-- [[horolezec]] "mountaineer", [[znalec]] "expert", [[chlapec]] "boy", [[nadšenec]] "enthusiast").
	-- [[švec]] "shoemaker" has stem 'ševc-' and voc_s 'ševče' so we need to check the lemma not stem for -ec.
	local voc_s = base.animacy == "an" and rfind(base.lemma, "ec$") and "e" or "i"
	local nom_p = base.animacy == "inan" and "e" or default_nom_pl_animate_masc(base)
	-- nouns with loc_p in -ech (e.g. [[cíl]] "goal") need to give this manually, using <locplech>
	add_decl(base, stems, "e", dat_s, nil, voc_s, loc_s, "em",
		nom_p, "ů", "ům", "e", "ích", "i")
end

declprops["soft-m"] = {
	cat = "soft"
}


decls["mixed-m"] = function(base, stems)
	-- FIXME: Implement different handling for -l, -n, -t and animate
	-- combination of hard and soft endings; inanimate only; e.g. [[kotel]] "cauldron", [[řemen]] "strap",
	-- [[pramen]] "source", [[kámen]] "stone", [[loket]] "elbow"
	add_decl(base, stems, {"u", "e"}, {"u", "i"}, nil, "i", {"u", "i"}, "em",
		{"e", "y"}, "ů", "ům", {"e", "y"}, {"ech", "ích"}, {"i", "y"})
end

declprops["mixed-m"] = {
	cat = "mixed"
}


decls["a-m"] = function(base, stems)
	-- Nouns in -ita (e.g. [[husita]] "Hussite"), -ista (e.g. [[houslista]] "violinist") and -asta (e.g.
	-- [[gymnasta]] "male gymnast") have -é in the nom_p instead of -ové
	local it_ist = rfind(stems.vowel_stem, "is?t$") or rfind(stems.vowel_stem, "ast$")
	-- Velar nouns (e.g. [[sluha]] "servant") have -ích in the loc_p (which triggers the second palatalization)
	-- instead of -ech. Nouns whose stem ends in a soft consonant ([[rikša]], [[paša]], [[bača]], [[mahárádža]],
	-- [[paňáca]], etc.) behave likewise.
	-- FIXME: [[pária]] "pariah", [[Maria]] etc.
	local loc_p =
		(rfind(stems.vowel_stem, com.velar_c .. "$") or rfind(stems.vowel_stem, com.inherently_soft_c .. "$")) and
		"ích" or "ech"
	add_decl(base, stems, "y", "ovi", "u", "o", "ovi", "ou",
		it_ist and "é" or "ové", "ů", "ům", "y", loc_p, "y")
end

declprops["a-m"] = {
	cat = "GENPOS in -a"
}


decls["e-m"] = function(base, stems)
	-- [[zachránce]] "savior"; [[soudce]] "judge"
	add_decl(base, stems, "e", {"ovi", "i"}, nil, "-", {"ovi", "i"}, "em",
		-- nouns with -ové as well (e.g. [[soudce]] "judge") will need to specify that manually, e.g. <nompli:ové>
		"i", "ů", "ům", "e", "ích", "i")
end

declprops["e-m"] = {
	cat = "GENPOS in -e"
}


decls["i-m"] = function(base, stems)
	-- [[kivi]] "kiwi (bird)"; [[kuli]] "coolie"; [[lori]] "lory, lorikeet (bird)" (loc_pl 'loriech/loriích/lorich');
	-- [[vini]] "parrot of the genus Vini"; [[yetti]]/[[yeti]] "yeti".
	--
	-- [[grizzly]]/[[grizly]] "grizzly bear"; [[pony]] "pony"; [[husky]] "husky"; [[Billy]] "billy".
	--
	-- NOTE also: [[zombie]]: 'zombie, zombieho, zombiemu, zombieho, zombie, zombiem, zombiem'; pl.
	--   'zombiové, zombiů, zombiům, zombie, zombiové, zombiích, zombii' or 'zombies' (indeclinable)
	--
	-- NOTE: Some nouns in -y are regular soft stems, e.g. [[gray]] "gray (unit of absorbed radiation)";
	-- [[Nagy]] (surname).
	--
	-- NOTE: The stem ends in -i/-y.
	add_decl(base, stems, "ho", "mu", nil, "-", "m", "m",
		-- ins_pl 'kivii/kivimi'
		{"ové", ""}, {"ů", "ch"}, {"ům", "m"}, {"e", ""}, {"ích", "ch"}, {"i", "mi"})
end

declprops["i-m"] = {
	cat = "GENPOS in -i/-y"
}


decls["o-m"] = function(base, stems)
	-- [[kápo]] "head, leader"; [[lamželezo]] "strongman"; [[torero]] "bullfighter"; [[žako]] "African gray parrot";
	-- [[dingo]] "dingo"; [[kakapo]] "kakapo" (given in Wiktionary with dat_s/loc_s in -ovi only not -ovi/-u; probably
	-- wrong but not in IJP); [[maestro]] "maestro"; [[Bruno]] "Bruno", [[Hugo]] "Hugo"; [[Ivo]] "Yves" (these names
	-- are singular-only per IJP); [[Kvido]] "Guido, Guy" (per IJP has accusative in -a or -ona); [[Oto]] "Otto" (per
	-- IJP also declinable like virile -a masculines; singular-only); [[Kuřátko]] (a surname; how declined?);
	-- [[Picasso]] (surname; how declined?); [[Pluto]] "Pluto (God)", also "Pluto (planet)", which is inanimate;
	-- [[Samo]]/[[Sámo]] "Samo (7th century Slavic ruler)" (dat_s/loc_s only in -ovi, needs override); [[Tomio]]
	-- "Tomio (Japanese male given name)" (how declined?); [[nemakačenko]] "idler, loafer" (given in Wiktionary with
	-- dat_s/loc_s in -ovi only, as for [[kakapo]]); [[nefachčenko]] "idler, loafer"; note also [[gadžo]] "gadjo",
	-- which has a unique declension.
	--
	-- Velar nouns ([[žako]], [[dingo]], etc.) have -ích in the loc_p (which triggers the second palatalization)
	-- instead of -ech.
	local velar = rfind(stems.vowel_stem, com.velar_c .. "$")
	-- inanimates e.g. [[Pluto]] (planet) have -u only, like for normal hard masculines.
	local dat_s = base.animacy == "inan" and "u" or {"ovi", "u"}
	local loc_s = dat_s
	local loc_p = velar and "ích" or "ech"
	add_decl(base, stems, "a", dat_s, nil, "-", loc_s, "em",
		"ové", "ů", "ům", "y", loc_p, "y")
end

declprops["o-m"] = {
	cat = "GENPOS in -o"
}


decls["u-m"] = function(base, stems)
	-- [[emu]] "emu", [[guru]] "guru", [[kakadu]] "cockatoo", [[marabu]] "marabou" (declined the same way)
	-- [[Osamu]] "Osamu (Japanese male given name)" [how declined?]
	-- [[Višnu]] "Vishnu" (declined like [[guru]] but singular-only)
	-- [[budižkničemu]] "good-for-nothing, ne'er-do-well" (indeclinable in the singular, declinable as masculine hard stem
	-- budižkničemové etc. in the plural, declinable as feminine hard stem budižkničemy etc. in the plural when feminine).
	--
	-- NOTE: The stem ends in -u.
	add_decl(base, stems, "a", "ovi", nil, "-", "ovi", "em",
		"ové", "ů", "ům", "y", "ech", "y")
end

declprops["u-m"] = {
	cat = "GENPOS in -u"
}


decls["t-m"] = function(base, stems)
	-- E.g. [[kníže]] "prince", [[hrabě]] "earl", [[markrabě]] "margrave".
	add_decl(base, stems, "ete", "eti", "ete", "-", "eti", "etem",
		"ata", "at", "atům", "ata", "atech", "aty")
end

declprops["t-m"] = {
	cat = "t-stem"
}


decls["hard-f"] = function(base, stems)
	base.no_palatalize_c = true
	add_decl(base, stems, "y", "ě", "u", "o", "ě", "ou")
	if base.pldual then
		-- Currently [[ruka]] "hand" and [[noha]] "leg" use a special template {{cs-decl-noun-dual}} that includes
		-- two columns, one for plural and one for dual; need to investigate further.
		error("FIXME")
	else
		add_decl(base, stems, nil, nil, nil, nil, nil, nil,
			"y", "", "ám", "y", "ách", "ami")
	end
end

declprops["hard-f"] = {
	cat = "hard"
}


decls["soft-f"] = function(base, stems, overriding_nom_sg)
	-- [[ulice]] "street" with gen pl 'ulic'; some nouns have both e.g. [[přítelkyně]] "girlfriend" with gen pl
	-- 'přítelkyň' or 'přítelkyní' and need an override <genpl-:í> (alternation between -ň and -n and between -e and -ě
	-- handled automatically by the different stems and by combine_stem_ending()).
	-- overriding_nom_sg is used for feminines in -ia, which behave like soft feminines except for the nominative
	-- singular.
	--
	-- This also includes feminines in -ie, e.g. [[belarie]], [[signorie]], [[uncie]], and feminines in -oe, e.g.
	-- [[kánoe]], [[aloe]] and medical terms like [[dyspnoe]], [[apnoe]], [[hemoptoe]], [[kalanchoe]].
	local gen_p = rfind(stems.vowel_stem, "ic$") and "" or "í"
	-- Vocative really ends in -e, not just a copy of the nominative; cf. [[sinfonia]], which is soft-f except for
	-- the nominative and has -e in the vocative singular.
	add_decl(base, stems, "e", "i", "i", "e", "i", "í",
		"e", gen_p, "ím", "e", "ích", "emi")
end

declprops["soft-f"] = {
	cat = "soft"
}


decls["cons-f"] = function(base, stems)
	-- [[dlaň]] "palm (of the hand)"
	-- [[paní]] "Mrs." is vaguely of this type but totally irregular; indeclinable in the singular, with plural forms
	-- nom/gen/acc 'paní', dat 'paním', loc 'paních', ins 'paními'.
	add_decl(base, stems, "e", "i", "-", "i", "i", "í",
		"e", "í", "ím", "e", "ích", "emi")
end

declprops["cons-f"] = {
	cat = "soft zero-ending"
}


decls["i-f"] = function(base, stems)
	-- Note convergence between cons-f and i-f, e.g. [[loď]] "boat", which has gen_s/nom_p/acc_p 'lodi' or 'lodě',
	-- and ins_p 'loděmi' or 'loďmi'.
	add_decl(base, stems, "i", "i", "-", "i", "i", "í",
		"i", "í", "em", "i", "ech", "mi")
end

declprops["i-f"] = {
	cat = "i-stem"
}


decls["ea-f"] = function(base, stems)
	-- Stem ends in -e.
	if base.tech then
		-- diarea, gonorea, chorea, nauzea, paleogea, seborea, trachea
		add_decl(base, stems, "y", "i", "u", "o", "i", "ou",
			"y", "í", {"ám", "ím"}, "y", {"ách", "ích"}, "ami")
	else
		-- idea, odysea ("wandering pilgrimage"), orchidea, palea, spirea
		-- proper names Galilea, Judea, Caesarea, Korea, Odyssea ("epic poem")
		add_decl(base, stems, {"y", "je"}, "ji", "u", "o", "ji", "ou",
			{"y", "je"}, "jí", {"ám", "jím"}, {"y", "je"}, {"ách", "jích"}, {"ami", "jemi"})
	end
end

declprops["ea-f"] = {
	cat = function(base, stems)
		if base.tech then
			return {"GENPOS in -ea", "technical GENPOS in -ea"}
		else
			return "GENPOS in -ea"
		end
	end
}


decls["oa-f"] = function(base, stems)
	-- Stem ends in -o/-u.
	-- stoa, kongrua; proper names Samoa, Managua, Nikaragua, Capua
	add_decl(base, stems, "y", "i", "u", "o", "i", "ou",
		"y", "í", "ám", "y", "ách", "ami")
end

declprops["oa-f"] = {
	cat = "GENPOS in -oa/-ua"
}


decls["ia-f"] = function(base, stems)
	-- Stem ends in -i.
	-- belaria, signoria, uncia; paranoia, sinfonia;
	-- proper names Alexandria, Alexia, Livia, Monrovia, Olympia, Sofia
	-- Identical to soft declension except for nom sg.
	decls["soft-f"](base, stems)
end

declprops["ia-f"] = {
	cat = "GENPOS in -ia"
}


decls["hard-n"] = function(base, stems)
	local velar = rfind(stems.vowel_stem, com.velar_c .. "$")
	-- NOTE: Per IJP it appears the meaning of the preceding preposition makes a difference: 'o' = "about" takes
	-- '-u' or '-ě', while 'na/v' = "in, on" normally takes '-ě'.
	local loc_sg =
		-- Exceptions: [[mléko]] "milk" ('mléku' or 'mléce'), [[břicho]] "belly" ('břiše' or (less often) 'břichu'),
		-- [[roucho]] ('na rouchu' or 'v rouše'; why the difference in preposition?).
		velar and "u" or
		-- IJP says nouns in -dlo take only -e but the declension tables show otherwise. It appears -u is possible
		-- but significantly less common. Other nouns in -lo usually take just -e ([[čelo]] "forehead",
		-- [[kolo]] "wheel", [[křeslo]] "armchair", [[máslo]] "butter", [[peklo]] "hell", [[sklo]] "glass",
		-- [[světlo]] "light", [[tělo]] "body"; but [[číslo]] "number' with -e/-u; [[zlo]] "evil" and [[kouzlo]] "spell"
		-- with -u/-e).
		rfind(base.lemma, "[^d]lo$") and "ě" or
		(rfind(base.lemma, "[sc]tvo$") or rfind(base.lemma, "ivo$")) and "u" or
		-- Per IJP: Borrowed words and abstracts (e.g. [[banjo]]/[[bendžo]]/[[benžo]] "banjo", [[depo]] "depot",
		-- [[chladno]] "cold", [[mokro]] "damp, dampness", [[právo]] "law, right", [[šeru]] "twilight?",
		-- [[temno]] "dark, darkness", [[tempo]] "rate, tempo", [[ticho]] "quiet, silence", [[vedro]] "heat".
		-- We have no way of determining this so these need overrides.
		{"ě", "u"}
	local loc_pl =
		-- Note, lemmas in -isko also have mixed-reducible as default, handled in determine_default_reducible().
		-- Note also, ending -ích triggers the second palatalization.
		rfind(base.lemma, "isko$") and {"ích", "ách"} or
		-- Diminutives in -ko, -čko, -tko; also [[lýtko]], [[děcko]], [[vrátka]], [[dvířka]], [[jho]], [[roucho]],
		-- [[tango]], [[mango]], [[sucho]], [[blaho]], [[víko]], [[echo]], [[embargo]], [[largo]], [[jericho]] (from
		-- IJP). Also foreign nouns in -kum: [[antibiotikum]], [[narkotikum]], [[afrodiziakum]], [[analgetikum]], etc.
		-- [[jablko]] "apple" has '-ách' or '-ích' and needs an override; likewise for [[vojsko]] "troop"; [[riziko]]
		-- "risk" normally has '-ích' and needs and override.
		velar and "ách" or
		"ech"
	add_decl(base, stems, "a", "u", "-", "-", loc_sg, "em",
		"a", "", "ům", "a", loc_pl, "y")
	-- FIXME: paired body parts e.g. [[rameno]] "shoulder" (gen_p/loc_p 'ramenou/ramen'), [[koleno]] "knee"
	-- (gen_p/loc_p 'kolenou/kolen'), [[prsa]] "chest, breasts" (plurale tantum; gen_p/loc_p 'prsou').
	-- FIXME: Nouns with both neuter and feminine forms in the plural, e.g. [[lýtko]] "calf (of the leg)",
	-- [[bedro]] "hip", [[vrátka]] "gate".
end

declprops["hard-n"] = {
	desc = function(base, stems)
		if rfind(stems.vowel_stem, com.velar_c .. "$") then
			return "velar GENDER"
		else
			return "hard GENDER"
		end
	end,
	cat = function(base, stems)
		if rfind(stems.vowel_stem, com.velar_c .. "$") then
			return "velar-stem"
		else
			return "hard"
		end
	end
}


decls["soft-n"] = function(base, stems)
	-- Examples: [[moře]] "sea", [[slunce]] "sun", [[srdce]] "heart", [[citoslovce]] "interjection", 
	-- [[dopoledne]] "late morning", [[odpoledne]] "afternoon", [[hoře]] "sorrow, grief" (archaic or literary),
	-- [[inhalace]] "inhalation", [[kafe]] "coffee", [[kanape]] "sofa", [[kutě]] "bed", [[Labe]] "Elbe (singular only)",
	-- [[líce]] "cheek", [[lože]] "bed", [[nebe]] "sky; heaven", [[ovoce]] "fruit", [[pole]] "field", [[poledne]]
	-- "noon", [[příslovce]] "adverb", [[pukrle]] "curtsey" (also t-n), [[vejce]] "egg" (NOTE: gen pl 'vajec').
	--
	-- Many nouns in -iště, with null genitive plural.
	local gen_pl = rfind(base.vowel_stem, "išť$") and "" or "í"
	add_decl(base, stems, "e", "i", "-", "-", "i", "em",
		"e", gen_pl, "ím", "e", "ích", "i")
	-- NOTE: Some neuter words in -e indeclinable, e.g. [[Belize]], [[Chile]], [[garde]] "chaperone", [[karaoke]],
	-- [[karate]], [[re]] "double raise (card games)", [[ukulele]], [[Zimbabwe]], [[zombie]] (pl. 'zombie' or
	-- 'zombies')
	-- some nearly indeclinable, e.g. [[finále]], [[chucpe]]; see mostly-indecl-n below
end

declprops["soft-n"] = {
	cat = "soft"
}


decls["í-n"] = function(base, stems)
	-- [[nábřeží]] "waterfront"
	add_decl(base, stems, "í", "í", "-", "-", "í", "ím",
		"í", "í", "ím", "í", "ích", "ími")
end

declprops["í-n"] = {
	cat = "soft GENPOS in -í"
}


decls["en-n"] = function(base, stems)
	-- E.g. [[břemeno]] "burden" (also [[břímě]] FIXME); [[rameno]] (also [[rámě]] FIXME); [[semeno]] (also [[sémě]],
	-- [[símě]] FIXME)
	decls["hard-n"](base, stems)
	add_decl(base, stems, "e", "i", nil, nil, "i")
end

declprops["en-n"] = {
	cat = "n-stem"
}


decls["t-n"] = function(base, stems)
	-- E.g. [[batole]] "toddler", [[čuně]] "pig", [[daňče]] "fallow deer fawn", [[děvče]] "girl", [[ďouče]] "girl"
	-- (dialectal), [[dítě]] "child" (NOTE: feminine in the plural [[děti]], declined as a feminine i-stem), [[dvojče]]
	-- "twin", [[hádě]] "young snake", [[house]] "gosling", [[hříbě]] "foal" (pl. hříbata), [[jehně]] "lamb", [[kavče]]
	-- "young jackdaw; chough", [[káče]] "duckling", [[káně]] "buzzard chick" (NOTE: also feminine meaning "buzzard"),
	-- [[klíště]] "tick", [[kose]] "blackbird chick" (rare), [[kuře]] "chick (young chicken)", [[kůzle]]
	-- "kid (young goat)", [[lišče]] "fox cub", [[lvíče]] "lion cub", [[medvídě]] "bear cub", [[mládě]] "baby animal",
	-- [[morče]] "guinea pig", [[mrně]] "toddler", [[nemluvně]] "infant", [[novorozeně]] "newborn", [[orle]] "eaglet",
	-- [[osle]] "donkey foal", [[pachole]] "boy (obsolete); page, squire", [[páže]] "page, squire", [[podsvinče]]
	-- "suckling pig", [[prase]] "pig", [[prtě]] "toddler", [[ptáče]] "chick (young bird)",
	-- [[robě]] "baby, small child", [[saranče]] "locust" (NOTE: also feminine), [[sele]] "piglet",
	-- [[slůně]] "baby elephant", [[škvrně]] "toddler", [[štěně]] "puppy", [[tele]] "calf", [[velbloudě]] "camel colt",
	-- [[vlče]] "wolf cub", [[vnouče]] "grandchild", [[vyžle]] "small hunting dog; slender person",
	-- [[zvíře]] "animal, beast".
	--
	-- Some referring to inanimates, e.g. [[doupě]] "lair" (pl. doupata), [[koště]]/[[chvoště]] "broom", [[paraple]]
	-- "umbrella", [[poupě]] "bud", [[pukrle]] "curtsey" (also soft-n), [[rajče]] "tomato", [[šuple]] "drawer",
	-- [[varle]] "testicle", [[vole]] "craw (of a bird); goiter".
	add_decl(base, stems, "ete", "eti", "-", "-", "eti", "etem",
		"ata", "at", "atům", "ata", "atech", "aty")
end

declprops["t-n"] = {
	cat = "t-stem"
}


decls["ma-n"] = function(base, stems)
	-- E.g. [[drama]] "drama", [[dogma]] "dogma", [[aneurysma]]/[[aneuryzma]] "aneurysm", [[dilema]] "dilemma",
	-- [[gumma]] "gumma" (non-cancerous syphilitic growth), [[klima]] "climate", [[kóma]] "coma", [[lemma]] "lemma",
	-- [[melisma]] "melisma", [[paradigma]] "paradigm", [[plasma]]/[[plazma]] "plasma [partly ionized gas]"
	-- (note [[plasma]]/[[plazma]] "blood plasma" is feminine), [[revma]] "rheumatism", [[schéma]] "schema, diagram",
	-- [[schisma]]/[[schizma]] "schism", [[smegma]] "smegma", [[sofisma]]/[[sofizma]] "sophism", [[sperma]] "sperm",
	-- [[stigma]] "stigma", [[téma]] "theme", [[trauma]] "trauma", [[trilema]] "trilemma", [[zeugma]] "zeugma".
	add_decl(base, stems, "atu", "atu", "-", "-", "atu", "atem",
		"ata", "at", "atům", "ata", "atech", "aty")
end

declprops["ma-n"] = {
	cat = "ma-stem"
}


decls["mostly-indecl-n"] = function(base, stems)
	-- E.g. [[finále]] "final (sports)", [[čtvrtfinále]] "quarterfinal", [[chucpe]] "chutzpah", [[penále]]
	-- "fine, penalty", [[promile]] "" (NOTE: loc pl also promilech), [[rande]] "rendezvous", [[semifinále]]
	-- "semifinal", [[skóre]] "score"
	add_decl(base, stems, "", "", "-", "-", "", {"", "m"},
		"", "", "", "", "", "")
end

declprops["mostly-indecl-n"] = {
	cat = "mostly indeclinable"
}


decls["adj"] = function(base, stems)
	local props = {}
	if base.surname then
		table.insert(props, "surname")
	end
	local propspec = table.concat(props, ".")
	if propspec ~= "" then
		propspec = "<" .. propspec .. ">"
	end
	local adj_alternant_multiword_spec = require("Module:cs-adjective").do_generate_forms({base.lemma .. propspec})
	local function copy(from_slot, to_slot)
		base.forms[to_slot] = adj_alternant_multiword_spec.forms[from_slot]
	end
	if base.number ~= "pl" then
		if base.gender == "m" then
			copy("nom_m", "nom_s")
			copy("gen_mn", "gen_s")
			copy("dat_mn", "dat_s")
			copy("loc_mn", "loc_s")
			copy("ins_mn", "ins_s")
		elseif base.gender == "f" then
			copy("nom_f", "nom_s")
			copy("gen_f", "gen_s")
			copy("dat_f", "dat_s")
			copy("acc_f", "acc_s")
			copy("loc_f", "loc_s")
			copy("ins_f", "ins_s")
		else
			copy("nom_n", "nom_s")
			copy("gen_mn", "gen_s")
			copy("dat_mn", "dat_s")
			copy("acc_n", "acc_s")
			copy("loc_mn", "loc_s")
			copy("ins_mn", "ins_s")
		end
		if not base.forms.voc_s then
			iut.insert_forms(base.forms, "voc_s", base.forms.nom_s)
		end
	end
	if base.number ~= "sg" then
		if base.gender == "m" then
			if base.animacy == "an" then
				copy("nom_mp_an", "nom_p")
			else
				copy("nom_fp", "nom_p")
			end
			copy("acc_mfp", "acc_p")
		elseif base.gender == "f" then
			copy("nom_fp", "nom_p")
			copy("acc_mfp", "acc_p")
		else
			copy("nom_np", "nom_p")
			copy("acc_np", "acc_p")
		end
		copy("gen_p", "gen_p")
		copy("dat_p", "dat_p")
		copy("ins_p", "ins_p")
		copy("loc_p", "loc_p")
	end
end

local function get_stemtype(base)
	if rfind(base.lemma, "ý$") then
		return "hard"
	elseif rfind(base.lemma, "í$") then
		return "soft"
	elseif base.surname then
		return "surname"
	else
		return "possessive"
	end
end

declprops["adj"] = {
	cat = function(base, stems)
		return {"adjectival POS", get_stemtype(base) .. " GENDER adjectival POS"}
	end,
}


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
Parse a single override spec (e.g. 'nomplé:ové' or 'ins:autodráhou:autodrahou[rare]') and return
two values: the slot the override applies to, and an object describing the override spec.
The input is actually a list where the footnotes have been separated out; for example,
given the spec 'inspl:čоbotami:čobоtámi[rare]:čobitmi[archaic]', the input will be a list
{"inspl:čоbotami:čobоtámi", "[rare]", ":čobitmi", "[archaic]", ""}. The object returned
for 'ins:autodráhou:autodrahou[rare]' looks like this:

{
  full = true,
  values = {
    {
      form = "autodráhou"
    },
    {
      form = "autodrahou",
      footnotes = {"[rare]"}
    }
  }
}

The object returned for 'nomplé:ové' looks like this:

{
  values = {
    {
      form = "é",
    },
    {
      form = "ové",
    }
  }
}
]=]
local function parse_override(segments)
	local retval = {values = {}}
	local part = segments[1]
	local case = usub(part, 1, 3)
	if cases[case] then
		-- ok
	else
		error("Internal error: unrecognized case in override: '" .. table.concat(segments) .. "'")
	end
	local rest = usub(part, 4)
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
			value.form = form
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
  stems = { -- may be missing
	{
	  reducible = TRUE_OR_FALSE,
	  footnotes = {"FOOTNOTE", "FOOTNOTE", ...}, -- may be missing
	  -- The following fields are filled in by determine_stems()
	  vowel_stem = "STEM",
	  nonvowel_stem = "STEM",
	  oblique_stem = "STEM",
	},
	...
  },
  gender = "GENDER", -- "m", "f", "n"
  number = "NUMBER", -- "sg", "pl"; may be missing
  animacy = "ANIMACY", -- "inan", "an"; may be missing
  thirddecl = true, -- may be missing
  surname = true, -- may be missing
  adj = true, -- may be missing
  stem = "STEM", -- may be missing

  -- The following additional fields are added by other functions:
  orig_lemma = "ORIGINAL-LEMMA", -- as given by the user
  orig_lemma_no_links = "ORIGINAL-LEMMA-NO-LINKS", -- links removed
  lemma = "LEMMA", -- `orig_lemma_no_links`, converted to singular form if plural and lowercase if all-uppercase
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
  decl = "DECL", -- declension, e.g. "hard-m"
  vowel_stem = "VOWEL-STEM", -- derived from vowel-ending lemmas
  nonvowel_stem = "NONVOWEL-STEM", -- derived from non-vowel-ending lemmas
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
			elseif rfind(part, "^[-*#ě]*$") or rfind(part, "^[-*#ě]*,") then
				if base.stems then
					error("Can't specify reducible/vowel-alternant indicator twice: '" .. inside .. "'")
				end
				local comma_separated_groups = iut.split_alternating_runs(dot_separated_group, ",")
				local stem_sets = {}
				for i, comma_separated_group in ipairs(comma_separated_groups) do
					local pattern = comma_separated_group[1]
					local orig_pattern = pattern
					local reducible, vowelalt, oblique_case_vowelalt
					if pattern == "-" then
						-- default reducible, no vowel alt
					else
						local before, after
						before, reducible, after = rmatch(pattern, "^(.-)(%-?%*)(.-)$")
						if before then
							pattern = before .. after
							reducible = reducible == "*"
						end
						if pattern ~= "" then
							if not rfind(pattern, "^##?ě?$") then
								error("Unrecognized vowel-alternation pattern '" .. pattern .. "', should be one of #, ##, #ě or ##ě: '" .. inside .. "'")
							end
							if pattern == "#ě" or pattern == "##ě" then
								vowelalt = "quant-ě"
							else
								vowelalt = "quant"
							end
							if pattern == "##" or pattern == "##ě" then
								oblique_case_vowelalt = vowelalt
							end
						end
					end
					table.insert(stem_sets, {
						reducible = reducible,
						vowelalt = vowelalt,
						oblique_case_vowelalt = oblique_case_vowelalt,
						footnotes = fetch_footnotes(comma_separated_group)
					})
				end
				base.stem_sets = stem_sets
			elseif #dot_separated_group > 1 then
				error("Footnotes only allowed with slot overrides, reducible or vowel alternation specs or by themselves: '" .. table.concat(dot_separated_group) .. "'")
			elseif part == "m" or part == "f" or part == "n" then
				if base.gender then
					error("Can't specify gender twice: '" .. inside .. "'")
				end
				base.gender = part
			elseif part == "sg" or part == "pl" then
				if base.number then
					error("Can't specify number twice: '" .. inside .. "'")
				end
				base.number = part
			elseif part == "an" or part == "inan" then
				if base.animacy then
					error("Can't specify animacy twice: '" .. inside .. "'")
				end
				base.animacy = part
			elseif part == "hard" or part == "soft" or part == "mixed" or part == "surname" or part == "istem"
				or part == "-istem" or part == "tstem" or part == "tech" or part == "foreign" then
				if base[part] then
					error("Can't specify '" .. part .. "' twice: '" .. inside .. "'")
				end
				base[part] = true
				-- Allow 'hard' to signal that -y is allowed after -c, as in hard masculine nouns such as [[hec]]
				-- "joke", and also feminines in -ca where the c is pronounced as /k/, e.g. [[ayahuasca]], [[pororoca]],
				-- [[Petrarca]], [[Mallorca]], [[Casablanca]]. (Contrast [[mangalica]], [[Kusturica]], [[Bjelica]],
				-- where the c is pronounced as /ts/ and -y is disallowed.)
				if part == "hard" then
					base.hard_c = true
				end
			elseif part == "+" then
				if base.adj then
					error("Can't specify '+' twice: '" .. inside .. "'")
				end
				base.adj = true
			elseif rfind(part, "^decllemma:") then
				if base.decllemma then
					error("Can't specify 'decllemma:' twice: '" .. inside .. "'")
				end
				base.decllemma = rsub(part, "^decllemma:", "")
			elseif rfind(part, "^stem:") then
				if base.stem then
					error("Can't specify stem twice: '" .. inside .. "'")
				end
				base.stem = rsub(part, "^stem:", "")
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
		base.animacy = base.animacy or "inan"
	end
	-- Check for bad indicator combinations.
	if (base.hard and 1 or 0) + (base.soft and 1 or 0) + (base.mixed and 1 or 0) > 1 then
		error("At most one of 'hard', 'soft' and 'mixed' can be specified")
	end
	if base.istem and base["-istem"] then
		error("'istem' and '-istem' cannot be specified together")
	end
	if (base.istem or base["-istem"]) then
		if base.gender ~= "f" then
			error("'istem' and '-istem' can only be specified with the feminine gender")
		end
		if base.adj then
			error("'istem' and '-istem' cannot be specified with adjectival nouns")
		end
	end
end


local function set_all_defaults_and_check_bad_indicators(alternant_multiword_spec)
	local is_multiword = #alternant_multiword_spec.alternant_or_word_specs > 1
	iut.map_word_specs(alternant_multiword_spec, function(base)
		set_defaults_and_check_bad_indicators(base)
		base.multiword = is_multiword
	end)
end


local function undo_vowel_alternation(base, stem)
	error("Needs rethinking, may not be needed at all")
	if base.vowelalt == "quant" then
		local modstem = rsub(stem, "([aeěo])(" .. com.cons_c .. "*)$",
			function(vowel, post)
				if vowel == "a" then
					return "á" .. post
				elseif vowel == "e" or vowel == "ě" then
					return "í" .. post
				else
					return "ů" .. post
				end
			end
		)
		if modstem == stem then
			error("Indicator 'quant' can't be undone because stem '" .. stem .. "' doesn't have a, e, ě or o as its last vowel")
		end
		return modstem
	else
		return stem
	end
end


local function undo_second_palatalization(base, word)
	local function try(from, to)
		local stem = rmatch(word, "^(.*)" .. from .. "$")
		if stem then
			return stem .. to
		end
		return nil
	end
	return try("št", "sk") or
		try("čt", "ck") or
		try("c", "k") or -- FIXME, this could be wrong and c correct
		try("ř", "r") or
		try("z", "h") or -- FIXME, this could be wrong and z or g correct
		try("š", "ch") or
		word
end


-- For a plural-only lemma, synthesize a likely singular lemma. It doesn't have to be
-- theoretically correct as long as it generates all the correct plural forms.
local function synthesize_singular_lemma(base)
	local stem
	while true do
		if base.gender == "m" then
			if base.animacy == "an" then
				error("Implement me")
			else
				stem = rmatch(base.lemma, "^(.*)y$")
				if stem then
					-- [[droby]] "giblets"; [[tvarůžky]] "Olomouc cheese"; [[alimenty]] "alimony"; etc.
					base.lemma = stem
					break
				end
				local ending
				stem, ending = rmatch(base.lemma, "^(.*)([eě])$")
				if stem then
					-- [[peníze]] "money", [[tvargle]] "Olomouc cheese" (mixed declension), [[údaje]] "data",
					-- [[Lazce]] (a village), [[lováče]] "money", [[Krkonoše]] "Giant Mountains", [[kříže]] "clubs"
					base.lemma = com.convert_paired_plain_to_palatal(stem, ending)
					if not base.mixed then
						base.soft = true
					end
					break
				end
				error(("Inanimate masculine plural-only lemma '%s' should end in -y, -e or -ě"):format(base.lemma))
			end
		elseif base.gender == "f" then
			error("Implement me")
		else
			-- -ata nouns like [[slůně]] "baby elephant" nom pl 'slůňata' are declined in the plural same as if
			-- the singular were 'slůňato' so we don't have to worry about them.
			stem = rmatch(base.lemma, "^(.*)a$")
			if stem then
				base.lemma = stem .. "o"
				break
			end
			local ending
			stem, ending = rmatch(base.lemma, "^(.*)([eěí])$")
			if stem then
				-- singular lemma also in -e, -ě or -í
				if ending == "ě" or ending == "í" then
					-- cf. [[věčná loviště]] "[[happy hunting ground]]", gen pl 'věčných lovišť'
					stem = com.convert_paired_plain_to_palatal(stem)
				end
				break
			end
			error(("Neuter plural-only lemma '%s' should end in -a, -í, -ě or -e"):format(base.lemma))
		end
	end

	-- Now set the stem sets if not given.
	if not base.stem_sets then
		base.stem_sets = {{}}
	end
end


-- For an adjectival lemma, synthesize the masc singular form.
local function synthesize_adj_lemma(base)
	local stem
	local gender, number
	while true do
		if base.number == "pl" then
			if base.gender == "m" then
				stem = rmatch(base.lemma, "^(.*)í$")
				if stem then
					if base.soft then
						-- nothing to do
					else
						if base.animacy ~= "an" then
							error(("Masculine plural-only adjectival lemma '%s' ending in -í can only be animate unless '.soft' is specified"):
								format(base.lemma))
						end
						base.lemma = undo_second_palatalization(base, stem) .. "ý"
					end
					break
				end
				stem = rmatch(base.lemma, "^(.*)é$")
				if stem then
					if base.animacy == "an" then
						error(("Masculine plural-only adjectival lemma '%s' ending in -é must be inanimate"):
							format(base.lemma))
					end
					base.lemma = stem .. "ý"
					break
				end
				stem = rmatch(base.lemma, "^(.*ův)i$") or rmatch(base.lemma, "^(.*in)i$")
				if stem then
					if base.animacy ~= "an" then
						error(("Masculine plural-only possessive adjectival lemma '%s' ending in -i must be animate"):
							format(base.lemma))
					end
					base.lemma = stem
					break
				end
				stem = rmatch(base.lemma, "^(.*ův)y$") or rmatch(base.lemma, "^(.*in)y$")
				if stem then
					if base.animacy == "an" then
						error(("Masculine plural-only adjectival lemma '%s' ending in -y must be inanimate"):
							format(base.lemma))
					end
					base.lemma = stem
					break
				end
				if base.animacy == "an" then
					error(("Animate masculine plural-only adjectival lemma '%s' should end in -í, -ůvi or -ini"):
						format(base.lemma))
				elseif base.soft then
					error(("Soft masculine plural-only adjectival lemma '%s' should end in -í"):format(base.lemma))
				else
					error(("Inanimate masculine plural-only adjectival lemma '%s' should end in -é, -ůvy or -iny"):
						format(base.lemma))
				end
			elseif base.gender == "f" then
				stem = rmatch(base.lemma, "^(.*)é$") -- hard adjective
				if stem then
					base.lemma = stem .. "ý"
					break
				end
				stem = rmatch(base.lemma, "^(.*)í$") -- soft adjective
				if stem then
					break
				end
				stem = rmatch(base.lemma, "^(.*ův)y$") or rmatch(base.lemma, "^(.*in)y$") -- possessive adjective
				if stem then
					base.lemma = stem
					break
				end
				error(("Feminine plural-only adjectival lemma '%s' should end in -é, -í, -ůvy or -iny"):format(base.lemma))
			else
				stem = rmatch(base.lemma, "^(.*)á$") -- hard adjective
				if stem then
					base.lemma = stem .. "ý"
					break
				end
				stem = rmatch(base.lemma, "^(.*)í$") -- soft adjective
				if stem then
					break
				end
				stem = rmatch(base.lemma, "^(.*ův)a$") or rmatch(base.lemma, "^(.*in)a$") -- possessive adjective
				if stem then
					base.lemma = stem
					break
				end
				error(("Neuter plural-only adjectival lemma '%s' should end in -á, -í, -ůva or -ina"):format(base.lemma))
			end
		else
			if base.gender == "m" then
				stem = rmatch(base.lemma, "^(.*)[ýí]$") or rmatch(base.lemma, "^(.*)ův$") or rmatch(base.lemma, "^(.*)in$")
				if stem then
					break
				end
				error(("Masculine adjectival lemma '%s' should end in -ý, -í, -ův or -in"):format(base.lemma))
			elseif base.gender == "f" then
				stem = rmatch(base.lemma, "^(.*)á$")
				if stem then
					base.lemma = stem .. "ý"
					break
				end
				stem = rmatch(base.lemma, "^(.*)í$")
				if stem then
					break
				end
				stem = rmatch(base.lemma, "^(.*ův)a$") or rmatch(base.lemma, "^(.*in)a$")
				if stem then
					base.lemma = stem
					break
				end
				error(("Feminine adjectival lemma '%s' should end in -á, -í, -ůva or -ina"):format(base.lemma))
			else
				stem = rmatch(base.lemma, "^(.*)é$")
				if stem then
					base.lemma = stem .. "ý"
					break
				end
				stem = rmatch(base.lemma, "^(.*)í$")
				if stem then
					break
				end
				stem = rmatch(base.lemma, "^(.*ův)o$") or rmatch(base.lemma, "^(.*in)o$")
				if stem then
					base.lemma = stem
					break
				end
				error(("Neuter adjectival lemma '%s' should end in -é, -í, -ůvo or -ino"):format(base.lemma))
			end
		end
	end

	-- Now set the stem sets if not given.
	if not base.stem_sets then
		base.stem_sets = {{reducible = false}}
	end
	for _, stems in ipairs(base.stem_sets) do
		-- Set the stems.
		stems.vowel_stem = stem
		stems.nonvowel_stem = stem
		stems.oblique_stem = stem
	end
	base.decl = "adj"
end


-- Determine the declension based on the lemma, gender and number. The declension is set in base.decl. In the process,
-- we set either base.vowel_stem (if the lemma ends in a vowel) or base.nonvowel_stem (if the lemma does not end in a
-- vowel), which is used by determine_stems().
local function determine_declension(base)
	-- For now we require that the gender be given; there are too many exceptions otherwise.
	if not base.gender then
		error("Gender must be specified")
	end
	-- Determine declension
	stem = rmatch(base.lemma, "^(.*)a$")
	if stem then
		if base.gender == "m" then
			if base.animacy ~= "an" then
				error("Masculine lemma in -a must be animate")
			end
			base.decl = "a-m"
		elseif base.gender == "f" then
			if rfind(stem, "e$") then
				-- [[idea]], [[diarea]] (subtype '.tech'), [[Korea]], etc.
				base.decl = "ea-f"
			elseif rfind(stem, "i$") then
				-- [[signoria]], [[sinfonia]], [[paranoia]], etc.
				base.decl = "ia-f"
			elseif rfind(stem, "[ou]$") then
				-- [[stoa]], [[kongrua]], [[Samoa]], [[Nikaragua]], etc.
				base.decl = "oa-f"
			else
				base.decl = "hard-f"
			end
		elseif base.gender == "n" then
			if rfind(stem, "m$") then
				base.decl = "ma-n"
			else
				error("Lemma ending in -a and neuter must end in -ma")
			end
		end
		base.vowel_stem = stem
		return
	end
	local ending
	stem, ending = rmatch(base.lemma, "^(.*)([eě])$")
	if stem then
		if ending == "ě" then
			stem = com.convert_paired_plain_to_palatal(stem)
		end
		if base.gender == "m" then
			if base.animacy ~= "an" then
				error("Masculine lemma in -e must be animate")
			end
			if base.stem then
				base.decl = "t-m"
			else
				base.decl = "e-m"
			end
		elseif base.gender == "f" then
			base.decl = "soft-f"
		else
			if base.tstem then
				base.decl = "t-n"
			else
				base.decl = "soft-n"
			end
		end
		base.vowel_stem = stem
		return
	end
	stem = rmatch(base.lemma, "^(.*)o$")
	if stem then
		if base.gender == "m" then
			-- Cf. [[maestro]] m.
			base.decl = "o-m"
		elseif base.gender == "f" then
			-- [[zoo]]; [[Žemaitsko]]?
			error("Feminine nouns in -o are indeclinable")
		else
			base.decl = "hard-n"
		end
		base.vowel_stem = stem
		return
	end
	stem = rmatch(base.lemma, "^(.*[iy])$")
	if stem then
		if base.gender == "m" then
			if base.soft then
				-- [[gay]] "gay man", [[gray]] "gray (scientific unit)", [[Nagy]] (surname)
				base.decl = "soft-m"
			else
				-- Cf. [[kivi]] "kiwi (bird)", [[husky]] "kusky", etc.
				base.decl = "i-m"
			end
		elseif base.gender == "f" then
			-- [[tsunami]]/[[cunami]], [[okapi]]
			error("Feminine nouns in -i are indeclinable")
		else
			error("Neuter nouns in -i are indeclinable")
		end
		base.vowel_stem = stem
		return
	end
	stem = rmatch(base.lemma, "^(.*u)$")
	if stem then
		if base.gender == "m" then
			-- Cf. [[emu]], [[guru]], etc.
			base.decl = "u-m"
		elseif base.gender == "f" then
			-- Only one I know is [[budižkničemu]], which is usually masculine.
			error("Support for feminine nouns in -u not yet implemented")
		else
			error("Neuter nouns in -u are indeclinable")
		end
		base.vowel_stem = stem
		return
	end
	stem = rmatch(base.lemma, "^(.*)í$")
	if stem then
		if base.gender == "m" or base.gender == "f" then
			-- FIXME: Do any exist? If not, update this message.
			error("Support for masculine or feminine nouns in -í not yet implemented")
		else
			base.decl = "í-n"
		end
		base.vowel_stem = stem
		return
	end
	stem = rmatch(base.lemma, "^(.*" .. com.cons_c .. ")$")
	if stem then
		if base.gender == "m" then
			if base.hard then
				base.decl = "hard-m"
			elseif base.soft then
				base.decl = "soft-m"
			elseif base.mixed then
				base.decl = "mixed-m"
			elseif rfind(base.lemma, com.inherently_soft_c .. "$") or rfind(base.lemma, "tel$") then
				base.decl = "soft-m"
			else
				base.decl = "hard-m"
			end
		elseif base.gender == "f" then
			if base.istem then
				base.decl = "i-f"
			elseif base["-istem"] then
				base.decl = "cons-f"
			elseif rfind(base.lemma, "st$") then
				base.decl = "i-f"
			else
				base.decl = "cons-f"
			end
		elseif base.gender == "n" then
			if base.foreign then
				stem = rmatch(base.lemma, "^(.*)um$") or rmatch(base.lemma, "^(.*)on$")
				if not stem then
					error("Unrecognized neuter foreign ending, should be -um or -on")
				end
				if rfind(stem, "[ei]$") then
					error("Implement support for this")
				else
					base.decl = "hard-n"
					base.lemma = stem .. "o"
				end
			else
				error("Neuter nouns ending in a consonant should use '.foreign' or '.decllemma:...'")
			end
		end
		base.nonvowel_stem = stem
		return
	end
	error("Unrecognized ending for lemma: '" .. base.lemma .. "'")
end


-- Determine the default value for the 'reducible' flag.
local function determine_default_reducible(base)
	if rfind(base.lemma, "[iyu]$") then
		base.default_reducible = false
		return
	end
		
	local stem
	stem = rmatch(base.lemma, "^(.*" .. com.cons_c .. ")$")
	if stem then
		-- When analyzing existing manual declensions in -ec and -ek, 290 were reducible vs. 23 non-reducible. Of these
		-- 23, 15 were monosyllabic (and none of the 290 reducible nouns were monosyllabic) -- and two of these were
		-- actually reducible but irregularly: [[švec]] "shoemaker" (gen sg 'ševce') and [[žnec]] "reaper (person)"
		-- (gen sg. 'žence'). Of the remaining 8 multisyllabic non-reducible words, two were actually reducible but
		-- irregularly: [[stařec]] "old man" (gen sg 'starce') and [[tkadlec]] "weaver" (gen sg 'tkalce'). The remaining
		-- six consisted of 5 compounds of monosyllabic words: [[dotek]], [[oblek]], [[kramflek]], [[pucflek]],
		-- [[pokec]], plus [[česnek]], which should be reducible but would lead to an impossible consonant cluster.
		if rfind(stem, "e[ck]$") and not com.is_monosyllabic(stem) then
			base.default_reducible = true
		else
			base.default_reducible = false
		end
		return
	end
	if rfind(base.lemma, "isko$") then
		-- e.g. [[středisko]] then
		base.default_reducible = "mixed"
		return
	end
	stem = rmatch(base.lemma, "^(.*)" .. com.vowel_c .. "$")
	if not stem then
		error(("Internal error: Something wrong, lemma '%s' doesn't end in consonant or vowel"):format(base.lemma))
	end
	-- Substitute 'ch' with a single character to make the following code simpler.
	stem = stem:gsub("ch", com.TEMP_CH)
	if rfind(stem, com.cons_c .. "[lr]" .. com.cons_c .. "$") then
		-- [[vrba]], [[slha]]; not reducible. (But note [[jablko]], reducible; needs override.)
		base.default_reducible = false
	elseif rfind(stem, com.cons_c .. "[bkhlrmnv]$") then
		base.default_reducible = true
	else
		base.default_reducible = false
	end
end


-- Determine the stems to use for each stem set: vowel and nonvowel stems, for singular
-- and plural. We assume that one of base.vowel_stem or base.nonvowel_stem has been
-- set in determine_declension(), depending on whether the lemma ends in
-- a vowel. We construct all the rest given the reducibility, vowel alternation spec and
-- any explicit stems given. We store the determined stems inside of the stem-set objects
-- in `base.stem_sets`, meaning that if the user gave multiple reducible or vowel-alternation
-- patterns, we will compute multiple sets of stems. The reason is that the stems may vary
-- depending on the reducibility and vowel alternation.
local function determine_stems(base)
	if not base.stem_sets then
		base.stem_sets = {{}}
	end
	-- Set default reducible and check for default mixed reducible, which needs to be expanded into two entries.
	local default_mixed_reducible = false
	for _, stems in ipairs(base.stem_sets) do
		if stems.reducible == nil then
			stems.reducible = base.default_reducible
		end
		if stems.reducible == "mixed" then
			default_mixed_reducible = true
		end
	end
	if default_mixed_reducible then
		local new_stem_sets = {}
		for _, stems in ipairs(base.stem_sets) do
			if stems.reducible == "mixed" then
				local non_reducible_copy = m_table.shallowcopy(stems)
				non_reducible_copy.reducible = false
				stems.reducible = true
				table.insert(new_stem_sets, stems)
				table.insert(new_stem_sets, non_reducible_copy)
			else
				table.insert(new_stem_sets, stems)
			end
		end
		base.stem_sets = new_stem_sets
	end

	-- Now determine all the stems for each stem set.
	for _, stems in ipairs(base.stem_sets) do
		local function dereduce(stem)
			local dereduced_stem = com.dereduce(stem)
			if not dereduced_stem then
				error("Unable to dereduce stem '" .. stem .. "'")
			end
			return dereduced_stem
		end
		local lemma_is_vowel_stem = not not base.vowel_stem
		if base.vowel_stem then
			if base.stem then
				-- FIXME: This will have to change, e.g. for [[centurio]]
				error("Can't specify 'stem:' with lemma ending in a vowel")
			end
			stems.vowel_stem = base.vowel_stem
			stems.nonvowel_stem = stems.vowel_stem
			-- Apply vowel alternation first in cases like jádro -> jader; apply_vowel_alternation() will throw an error
			-- if the vowel being modified isn't the last vowel in the stem.
			stems.nonvowel_stem, stems.origvowel = com.apply_vowel_alternation(stems.vowelalt, stems.nonvowel_stem)
			if stems.reducible then
				stems.nonvowel_stem = dereduce(stems.nonvowel_stem)
			end
		else
			stems.nonvowel_stem = base.nonvowel_stem
			if stems.reducible then
				local stem_to_reduce = base.stem_for_reduce or base.nonvowel_stem
				stems.vowel_stem = com.reduce(stem_to_reduce)
				if not stems.vowel_stem then
					error("Unable to reduce stem '" .. stem_to_reduce .. "'")
				end
			else
				stems.vowel_stem = base.nonvowel_stem
			end
			if base.stem and base.stem ~= stems.vowel_stem then
				stems.irregular_stem = true
				stems.vowel_stem = base.stem
			end
			stems.vowel_stem, stems.origvowel = com.apply_vowel_alternation(stems.vowelalt, stems.vowel_stem)
		end
		stems.oblique_stem = com.apply_vowel_alternation(stems.oblique_case_vowelalt, stems.vowel_stem)
	end
end


local function detect_indicator_spec(base)
	if base.adj then
		synthesize_adj_lemma(base)
	else
		if base.number == "pl" then
			synthesize_singular_lemma(base)
		end
		determine_declension(base)
		determine_default_reducible(base)
		determine_stems(base)
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
			is_nounal = not word_specs[i].adj
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
1. We assume the properties in question are already set on all nouns. This should happen in
   set_defaults_and_check_bad_indicators().
2. We first propagate properties upwards and sideways. We recurse downwards from the top. When we encounter a multiword
   spec, we proceed left to right looking for a noun. When we find a noun, we fetch its property (recursing if the noun
   is an alternant), and propagate it to any adjectives to its left, up to the next noun to the left. When we have
   processed the last noun, we also propagate its property value to any adjectives to the right (to handle e.g.
   [[anděl strážný]] "guardian angel", where the adjective [[strážný]] should inherit the 'masculine' and 'animate'
   properties of [[anděl]]). Finally, we set the property value for the multiword spec itself by combining all the
   non-nil properties of the individual elements. If all non-nil properties have the same value, the result is that
   value, otherwise it is `mixed_value` (which is "mixed" for animacy and gender, but "both" for number).
3. When we encounter an alternant spec in this process, we recursively process each alternant (which is a multiword
   spec) using the previous step, and combine any non-nil properties we encounter the same way as for multiword specs.
4. The effect of steps 2 and 3 is to set the property of each alternant and multiword spec based on its children or its
   neighbors.
]=]
local function propagate_properties(alternant_multiword_spec, property, default_propval, mixed_value)
	propagate_multiword_properties(alternant_multiword_spec, property, mixed_value, "nouns only")
	propagate_multiword_properties(alternant_multiword_spec, property, mixed_value, false)
	propagate_properties_downward(alternant_multiword_spec, property, default_propval)
end


local function determine_noun_status(alternant_multiword_spec)
	for i, alternant_or_word_spec in ipairs(alternant_multiword_spec.alternant_or_word_specs) do
		if alternant_or_word_spec.alternants then
			local is_noun = false
			for _, multiword_spec in ipairs(alternant_or_word_spec.alternants) do
				for j, word_spec in ipairs(multiword_spec.word_specs) do
					if not word_spec.adj then
						multiword_spec.first_noun = j
						is_noun = true
						break
					end
				end
			end
			if is_noun then
				alternant_multiword_spec.first_noun = i
			end
		elseif not alternant_or_word_spec.adj then
			alternant_multiword_spec.first_noun = i
			return
		end
	end
end


local function normalize_all_lemmas(alternant_multiword_spec)
	iut.map_word_specs(alternant_multiword_spec, function(base)
		base.orig_lemma = base.lemma
		base.orig_lemma_no_links = m_links.remove_links(base.lemma)
		local lemma = base.orig_lemma_no_links
		-- If the lemma is all-uppercase, lowercase it but note this, so that later in combine_stem_ending() we convert it
		-- back to uppercase. This allows us to handle all-uppercase acronyms without a lot of extra complexity.
		-- FIXME: This may not make sense at all.
		if uupper(lemma) == lemma then
			base.all_uppercase = true
			lemma = ulower(lemma)
		end
		base.user_specified_lemma = lemma
		base.lemma = base.decllemma or lemma
	end)
end


local function decline_noun(base)
	for _, stems in ipairs(base.stem_sets) do
		if not decls[base.decl] then
			error("Internal error: Unrecognized declension type '" .. base.decl .. "'")
		end
		decls[base.decl](base, stems)
	end
	handle_derived_slots_and_overrides(base)
end


local function get_variants(form)
	return nil
	--[=[
	return
		form:find(com.VAR1) and "var1" or
		form:find(com.VAR2) and "var2" or
		form:find(com.VAR3) and "var3" or
		nil
	]=]
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
					iut.insert_form(forms, slot, {form=form})
				end
			end
		end
	end
end


-- Compute the categories to add the noun to, as well as the annotation to display in the
-- declension title bar. We combine the code to do these functions as both categories and
-- title bar contain similar information.
local function compute_categories_and_annotation(alternant_multiword_spec)
	local all_cats = {}
	local function insert(cattype)
		m_table.insertIfNot(all_cats, "Czech " .. cattype)
	end
	if alternant_multiword_spec.pos == "noun" then
		if alternant_multiword_spec.number == "sg" then
			insert("uncountable nouns")
		elseif alternant_multiword_spec.number == "pl" then
			insert("pluralia tantum")
		end
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
		local vowelalts = {}
		local irregs = {}
		local stemspecs = {}
		local reducible = nil
		local function do_word_spec(base)
			local genanim = gender_code_to_desc[base.gender]
			if base.gender == "m" then
				genanim = genanim .. " " .. (base.animacy == "an" and "animate" or "inanimate")
				-- Insert a category for 'Czech masculine animate nouns' or 'Czech masculine inanimate nouns'; the base categories
				-- [[:Category:Czech masculine nouns]], [[:Czech animate nouns]] are auto-inserted.
				insert(genanim .. " " .. alternant_multiword_spec.plpos)
			end
			for _, stems in ipairs(base.stem_sets) do
				local props = declprops[base.decl]
				local cats = props.cat
				if type(cats) == "function" then
					cats = cats(base, stems)
				end
				if type(cats) == "string" then
					cats = {cats}
				end
				local default_desc
				for i, cat in ipairs(cats) do
					if not cat:find("GENDER") and not cat:find("GENPOS") and not cat:find("POS") then
						cat = cat .. " GENPOS"
					end
					cat = cat:gsub("GENPOS", "GENDER POS")
					if not cat:find("POS") then
						cat = cat .. " POS"
					end
					if i == #cats then
						default_desc = cat:gsub(" POS", "")
					end
					cat = cat:gsub("GENDER", genanim)
					cat = cat:gsub("POS", alternant_multiword_spec.plpos)
					insert(cat)
				end

				local desc = props.desc
				if type(desc) == "function" then
					desc = desc(base, stems)
				end
				desc = desc or default_desc
				desc = desc:gsub("GENDER", genanim)
				m_table.insertIfNot(decldescs, desc)

				local vowelalt
				if stems.vowelalt == "quant" then
					vowelalt = "quant-alt"
					insert("nouns with quantitative vowel alternation")
				elseif stems.vowelalt == "quant-ě" then
					vowelalt = "í-ě-alt"
					insert("nouns with í-ě alternation")
				end
				if vowelalt then
					m_table.insertIfNot(vowelalts, vowelalt)
				end
				if reducible == nil then
					reducible = stems.reducible
				elseif reducible ~= stems.reducible then
					reducible = "mixed"
				end
				if stems.reducible then
					insert("nouns with reducible stem")
				end
				if stems.irregular_stem or base.user_specified_lemma ~= base.lemma then
					m_table.insertIfNot(irregs, "irreg-stem")
					insert("nouns with irregular stem")
				end
				m_table.insertIfNot(stemspecs, stems.vowel_stem)
			end
		end
		local key_entry = alternant_multiword_spec.first_noun or 1
		if #alternant_multiword_spec.alternant_or_word_specs >= key_entry then
			local alternant_or_word_spec = alternant_multiword_spec.alternant_or_word_specs[key_entry]
			if alternant_or_word_spec.alternants then
				for _, multiword_spec in ipairs(alternant_or_word_spec.alternants) do
					key_entry = multiword_spec.first_noun or 1
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
		if #vowelalts > 0 then
			table.insert(annparts, table.concat(vowelalts, "/"))
		end
		if reducible == "mixed" then
			table.insert(annparts, "mixed-reducible")
		elseif reducible then
			table.insert(annparts, "reducible")
		end
		if #irregs > 0 then
			table.insert(annparts, table.concat(irregs, " // "))
		end
		alternant_multiword_spec.annotation = table.concat(annparts, " ")
		if #stemspecs > 1 then
			insert("nouns with multiple stems")
		end
	end
	alternant_multiword_spec.categories = all_cats
end


local function show_forms(alternant_multiword_spec)
	local lemmas = {}
	if alternant_multiword_spec.forms.nom_s then
		for _, nom_s in ipairs(alternant_multiword_spec.forms.nom_s) do
			table.insert(lemmas, nom_s.form)
		end
	elseif alternant_multiword_spec.forms.nom_p then
		for _, nom_p in ipairs(alternant_multiword_spec.forms.nom_p) do
			table.insert(lemmas, nom_p.form)
		end
	end
	local props = {
		lemmas = lemmas,
		slot_table = output_noun_slots_with_linked,
		lang = lang,
		canonicalize = function(form)
			-- return com.remove_variant_codes(form)
			return form
		end,
		-- Explicit additional top-level footnotes only occur with {{cs-ndecl-manual}} and variants.
		footnotes = alternant_multiword_spec.footnotes,
		allow_footnote_symbols = not not alternant_multiword_spec.footnotes,
	}
	iut.show_forms(alternant_multiword_spec.forms, props)
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
!style="background:#eff7ff"|nominative
| {nom_s}
| {nom_p}
|-
!style="background:#eff7ff"|genitive
| {gen_s}
| {gen_p}
|-
!style="background:#eff7ff"|dative
| {dat_s}
| {dat_p}
|-
!style="background:#eff7ff"|accusative
| {acc_s}
| {acc_p}
|-
!style="background:#eff7ff"|vocative
| {voc_s}
| {voc_p}
|-
!style="background:#eff7ff"|locative
| {loc_s}
| {loc_p}
|-
!style="background:#eff7ff"|instrumental
| {ins_s}
| {ins_p}
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
!style="background:#eff7ff"|nominative
| {nom_s}
|-
!style="background:#eff7ff"|genitive
| {gen_s}
|-
!style="background:#eff7ff"|dative
| {dat_s}
|-
!style="background:#eff7ff"|accusative
| {acc_s}
|-
!style="background:#eff7ff"|vocative
| {voc_s}
|-
!style="background:#eff7ff"|locative
| {loc_s}
|-
!style="background:#eff7ff"|instrumental
| {ins_s}
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
!style="background:#eff7ff"|nominative
| {nom_p}
|-
!style="background:#eff7ff"|genitive
| {gen_p}
|-
!style="background:#eff7ff"|dative
| {dat_p}
|-
!style="background:#eff7ff"|accusative
| {acc_p}
|-
!style="background:#eff7ff"|vocative
| {voc_p}
|-
!style="background:#eff7ff"|locative
| {loc_p}
|-
!style="background:#eff7ff"|instrumental
| {ins_p}
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
		forms.title = 'Declension of <i lang="cs">' .. forms.lemma .. '</i>'
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
		local animacy = base.animacy
		if animacy == "inan" then
			animacy = "in"
		end
		m_table.insertIfNot(genders, base.gender .. "-" .. animacy .. number)
	end)
	return genders
end


-- Externally callable function to parse and decline a noun given user-specified arguments.
-- Return value is ALTERNANT_MULTIWORD_SPEC, an object where the declined forms are in
-- `ALTERNANT_MULTIWORD_SPEC.forms` for each slot. If there are no values for a slot, the
-- slot key will be missing. The value for a given slot is a list of objects
-- {form=FORM, footnotes=FOOTNOTES}.
function export.do_generate_forms(parent_args, from_headword)
	local params = {
		[1] = {required = true, default = "bůh<#.voce>"},
		footnote = {list = true},
		title = {},
		pos = {default = "noun"},
	}

	if from_headword then
		params["lemma"] = {list = true}
		params["g"] = {list = true}
		params["f"] = {list = true}
		params["m"] = {list = true}
		params["adj"] = {list = true}
		params["dim"] = {list = true}
		params["id"] = {}
	end

	local args = m_para.process(parent_args, params)
	local parse_props = {
		parse_indicator_spec = parse_indicator_spec,
	}
	local alternant_multiword_spec = iut.parse_inflected_text(args[1], parse_props)
	alternant_multiword_spec.title = args.title
	alternant_multiword_spec.pos = args.pos
	alternant_multiword_spec.plpos = require("Module:string utilities").pluralize(alternant_multiword_spec.pos)
	alternant_multiword_spec.footnotes = args.footnote
	alternant_multiword_spec.args = args
	normalize_all_lemmas(alternant_multiword_spec)
	set_all_defaults_and_check_bad_indicators(alternant_multiword_spec)
	-- These need to happen before detect_all_indicator_specs() so that adjectives get their genders and numbers set
	-- appropriately, which are needed to correctly synthesize the adjective lemma.
	propagate_properties(alternant_multiword_spec, "animacy", "inan", "mixed")
	propagate_properties(alternant_multiword_spec, "number", "both", "both")
	-- FIXME, the default value (third param) used to be 'm' with a comment indicating that this applied only to
	-- plural adjectives, where it didn't matter; but in Czech, plural adjectives are distinguished for gender and
	-- animacy. Make sure 'mixed' works.
	propagate_properties(alternant_multiword_spec, "gender", "mixed", "mixed")
	detect_all_indicator_specs(alternant_multiword_spec)
	determine_noun_status(alternant_multiword_spec)
	local inflect_props = {
		skip_slot = function(slot)
			return skip_slot(alternant_multiword_spec.number, slot)
		end,
		slot_table = output_noun_slots_with_linked,
		get_variants = get_variants,
		inflect_word_spec = decline_noun,
	}
	iut.inflect_multiword_or_alternant_multiword_spec(alternant_multiword_spec, inflect_props)
	compute_categories_and_annotation(alternant_multiword_spec)
	alternant_multiword_spec.genders = compute_headword_genders(alternant_multiword_spec)
	return alternant_multiword_spec
end


-- Externally callable function to parse and decline a noun where all forms
-- are given manually. Return value is ALTERNANT_MULTIWORD_SPEC, an object where the declined
-- forms are in `ALTERNANT_MULTIWORD_SPEC.forms` for each slot. If there are no values for a
-- slot, the slot key will be missing. The value for a given slot is a list of
-- objects {form=FORM, footnotes=FOOTNOTES}.
function export.do_generate_forms_manual(parent_args, number, from_headword)
	if number ~= "sg" and number ~= "pl" and number ~= "both" then
		error("Internal error: number (arg 1) must be 'sg', 'pl' or 'both': '" .. number .. "'")
	end

	local params = {
		footnote = {list = true},
		title = {},
		pos = {default = "noun"},
	}
	if number == "both" then
		params[1] = {required = true, default = "žuk"}
		params[2] = {required = true, default = "žuky"}
		params[3] = {required = true, default = "žuka"}
		params[4] = {required = true, default = "žukiv"}
		params[5] = {required = true, default = "žuka"}
		params[6] = {required = true, default = "žukam"}
		params[7] = {required = true, default = "žukоvi, žuku"}
		params[8] = {required = true, default = "žuky, žukiv"}
		params[9] = {required = true, default = "žukоm"}
		params[10] = {required = true, default = "žukamy"}
		params[11] = {required = true, default = "žukоvi, žuku"}
		params[12] = {required = true, default = "žuky"}
		params[13] = {required = true, default = "žuče"}
		params[14] = {required = true, default = "žukách"}
	elseif number == "sg" then
		params[1] = {required = true, default = "lyst"}
		params[2] = {required = true, default = "lystu"}
		params[3] = {required = true, default = "lystu, lystovi"}
		params[4] = {required = true, default = "lyst"}
		params[5] = {required = true, default = "lyste"}
		params[6] = {required = true, default = "lysti, lystu"}
		params[7] = {required = true, default = "lystom"}
	else
		params[1] = {required = true, default = "dveře"}
		params[2] = {required = true, default = "dveři"}
		params[3] = {required = true, default = "dveřím"}
		params[4] = {required = true, default = "dveře"}
		params[5] = {required = true, default = "dveře"}
		params[6] = {required = true, default = "dveřích"}
		params[7] = {required = true, default = "dveřmi"}
	end

	local args = m_para.process(parent_args, params)
	local alternant_multiword_spec = {
		title = args.title,
		footnotes = args.footnote,
		pos = args.pos,
		forms = {},
		number = number,
		manual = true,
	}
	process_manual_overrides(alternant_multiword_spec.forms, args, alternant_multiword_spec.number)
	compute_categories_and_annotation(alternant_multiword_spec)
	return alternant_multiword_spec
end


-- Entry point for {{cs-ndecl}}. Template-callable function to parse and decline a noun given
-- user-specified arguments and generate a displayable table of the declined forms.
function export.show(frame)
	local parent_args = frame:getParent().args
	local alternant_multiword_spec = export.do_generate_forms(parent_args)
	show_forms(alternant_multiword_spec)
	return make_table(alternant_multiword_spec) ..
		require("Module:utilities").format_categories(alternant_multiword_spec.categories, lang, nil, nil, force_cat)
end


-- Entry point for {{cs-ndecl-manual}}, {{cs-ndecl-manual-sg}} and {{cs-ndecl-manual-pl}}.
-- Template-callable function to parse and decline a noun given manually-specified inflections
-- and generate a displayable table of the declined forms.
function export.show_manual(frame)
	local iparams = {
		[1] = {required = true},
	}
	local iargs = m_para.process(frame.args, iparams)
	local parent_args = frame:getParent().args
	local alternant_multiword_spec = export.do_generate_forms_manual(parent_args, iargs[1])
	show_forms(alternant_multiword_spec)
	return make_table(alternant_multiword_spec) ..
		require("Module:utilities").format_categories(alternant_multiword_spec.categories, lang, nil, nil, force_cat)
end


return export
