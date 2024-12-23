--[=[

This module implements {{ca-conj}} and provides the underlying conjugation functions for {{ca-verb}}
(whose actual formatting is done in [[Module:ca-headword]]).


Authorship: Ben Wing <benwing2>

]=]

local export = {}

--[=[

TERMINOLOGY:

-- "slot" = A particular combination of tense/mood/person/number/etc.
	 Example slot names for verbs are "pres_1s" (present indicative first-person singular), "pres_sub_2s" (present
	 subjunctive second-person singular) "impf_sub_3p" (imperfect subjunctive third-person plural).
	 Each slot is filled with zero or more forms.

-- "form" = The conjugated Catalan form representing the value of a given slot.

-- "lemma" = The dictionary form of a given Catalan term. For Catalan, always the infinitive.
]=]

--[=[

FIXME:

--]=]

local lang = require("Module:languages").getByCode("ca")
local m_string_utilities = require("Module:string utilities")
local m_links = require("Module:links")
local m_table = require("Module:table")
local iut = require("Module:inflection utilities")
local com = require("Module:ca-common")

local force_cat = false -- set to true for debugging
local check_for_red_links = false -- set to false for debugging

local rfind = mw.ustring.find
local rmatch = mw.ustring.match
local rsplit = mw.text.split
local rsubn = mw.ustring.gsub
local rsub = com.rsub
local u = mw.ustring.char

-- version of rsubn() that returns a 2nd argument boolean indicating whether a substitution was made.
local function rsubb(term, foo, bar)
	local retval, nsubs = rsubn(term, foo, bar)
	return retval, nsubs > 0
end


local function link_term(term, display, face)
	return m_links.full_link({ lang = lang, term = term, alt = display }, face)
end


local front_vowel = "eèéiíï"
local front_vowel_c = "[" .. front_vowel .. "]"
local V = com.V -- vowel regex class
local C = com.C -- consonant regex class
-- IS_USER_STEM_OVERRIDE is prepended to user-supplied stem overrides to prevent `base.prefix` from being prepended.
-- IS_USER_FORM_OVERRIDE is similar but also prevents final devoicing (cf. Balearic pres_1s 'trob' of [[trobar]]).
-- Don't use 0xFFF0 in case we call a [[Module:parse-utilities]] function that uses it temporarily.
local IS_USER_STEM_OVERRIDE = u(0xFFF1)
local IS_USER_FORM_OVERRIDE = u(0xFFF2)

--[=[

Irregular verbs:

-ldre/-ndre verbs:

infinitive	pres1s	pres3s	pres1p	impf1s	fut1s		pret1s		sub1s		sub1p		pp
caldre		-		cal		[calent] calia	caldrà		calgué		calgui		-			calgut,-
coldre		colc	col		colem	colia	coldré		colguí		colgui		colguem		colt,colta
doldre		dolc	dol		dolem	dolia	doldré		dolguí		dolgui		dolguem		dolgut,dolguda
moldre		molc	mol		molem	molia	moldré		molguí		molgui		molguem		molt,molta
oldre		olc		ol		olem	olia	oldré		olguí		olgui		olguem		olgut,olguda
-soldre		-solc	-sol	-solem	-solia	-soldré		-solguí		-solgui		-solguem	-solt,-solta
(absoldre, dissoldre, resoldre)
toldre		tolc	tol		tolem	tolia	toldré		tolguí		tolgui		tolguem		tolt,tolta
romandre	romanc	roman	romanem	romania	romandré	romanguí	romangui	romanguem	romàs,romasa,romasos
encendre	encenc	encén	encenem	encenia	encendré	encenguí	encengui	encenguem	encès,encesa,encesos
fendre		fenc	fen/-fèn fenem	fenia	fendré		fenguí		fengui		fenguem		fes/-fès,fesa,fesos
(defendre, ofendre)
-pendre		-depenc	-pèn	-penem	-penia	-pendré		-penguí		-pengui		-penguem	-pès,-pesa,-pesos
(dependre,despendre,expendre,suspendre)
prendre		prenc	pren/-prèn prenem prenia prendré	prenguí		prengui		prenguem	pres/-près,presa,presos
(aprendre, comprendre, desprendre, emprendre, reprendre, sorprendre)
-tendre		-tenc	-tén	-tenem	-tenia	-tendré		-tenguí		-tengui		-tenguem	-tès,-tesa,-tesos
					(pres2s: atens, pres3p: atenen)
(atendre, contendre, distendre, entendre, estendre, pretendre)
vendre		venc	ven		venem	venia	vendré		venguí		vengui		venguem		venut,venuda
(malvendre, revendre)
fondre		fonc	fon		fonem	fonia	fondré		fonguí		fongui		fonguem		fos/-fós,fosa,fosos
(confondre, difondre, infondre, refondre)
enfondre	enfonc	enfon	enfonem	enfonia	enfondré	enfonguí	enfongui	enfonguem	enfús,enfusa,enfusos
pondre		ponc	pon		ponem	ponia	pondré		ponguí		pongui		ponguem		post,posta,postos
(compondre, correspondre, descompondre, respondre)
tondre		tonc	ton		tonem	tonia	tondré		tonguí		tongui		tonguem		tos,tosa,tosos
cerndre		cerno	cern	cernem	cernia	cerndré		cerní		cerni		cernem		cernut,cernuda


-ler verbs (mostly like -ldre verbs):

infinitive	pres1s	pres3s	pres1p	impf1s	fut1s		pret1s		sub1s		sub1p		pp
caler (var. of caldre)
doler (var. of doldre)
soler		solc	sol		solem	solia	soldré		solguí		solgui		solguem		solgut,solguda
valer/valdre valc	val		valem	valia	valdré		valguí		valgui		valguem		valgut,valguda
(prevaler, equivaler)


other -dre/-tre verbs (regular except sometimes pp):

infinitive	pres1s	pres3s	pres1p	impf1s	fut1s		pret1s		sub1s		sub1p		pp
batre		bato	bat		batem	batia	batré		batí		bati		batem		batut,batuda
-metre		-meto	-met	-metem	-metia	-metré		-metí		-meti		-metem		-mès,-mesa,-mesos
(ad-, co-, compro-, e-, entremetre's, mal-, o-, per-, pro-, read-, re-, retrans-, sot-, tra-, trans-)
perdre		perdo	perd	perdem	perdia	perdré		perdí		perdi		perdem		perdut,perduda


-ure verbs

infinitive	pres1s	pres3s	pres1p	impf1s	impf1p	fut1s		pret1s		sub1s		sub1p		pp
caure		caic	cau		caiem	queia	quèiem	cauré		caiguí		caigui		caiguem		caigut,caiguda
(decaure, recaure)
plaure		plac	plau	plaem	plaïa	plaíem	plauré		plaguí		plagui		plaguem		plagut,plaguda
(complaure)
raure		rac		rau		raem	raïa	raíem	rauré	raguí		ragui		raguem		ragut,raguda
beure		bec		beu		bevem	bevia	bevíem	beuré		beguí		begui		beguem		begut,beguda
(embeure)
creure		crec	creu	creiem	creia	crèiem	creuré		creguí		cregui		creguem		cregut,creguda
deure		dec		deu		devem	devia	devíem	deuré		deguí		degui		deguem		degut,deguda
jeure		jec		jeu		jaiem	jeia	jèiem	jauré		jaguí		jegui		jaguem		jagut,jaguda
(ajeure)
lleure		-		lleu	[-]		llevia	-		lleurà		llegué		llegui		-			llegut,-
seure		sec		seu		seiem	seia	sèiem	seuré		seguí		segui		seguem		segut,seguda
(asseure)
treure		trec	treu	traiem	treia	trèiem	trauré		traguí		tregui		traguem		tret,treta
(abstreure, atreure, contreure, distreure, extreure, retreure, sostreure)
veure		veig	veu		veiem	veia	vèiem	veuré		viu,veieres/veres, vegi	vegem		vist,vista,vists/vistos
(entreveure, preveure, reveure)									veié/veu,veiérem/vérem
riure		ric		riu		riem	reia	rèiem	riuré		riguí		rigui		riguem		rigut,riguda
(somriure)
(e)scriure	escric	escriu	escrivim escrivia escrivíem escriuré escriví/escriguí escrigui escriguem escrit,escrita
(circumscriure, descriure, inscriure, prescriure, proscriure, subscriure, transcriure)
viure		visc	viu		vivim	vivia	vivíem	viuré		visquí		visqui		visquem		viscut,viscuda
(conviure, sobreviure)
cloure		cloc	clou	cloem	cloïa	cloíem	clouré		cloguí		clogui		cloguem		clos,closa,closos
(concloure, descloure, encloure, excloure, incloure, recloure)
encloure	encloc	enclou	encloem	encloïa	encloíem enclouré	encloguí	enclogui	encloguem	enclòs,enclosa,enclosos
coure		coc		cou		coem	coïa	coíem	couré		coguí		cogui		coguem		cuit/cogut,cuita/coguda
moure		moc		mou		movem	movia	movíem	mouré		moguí		mogui		moguem		mogut,moguda
(promoure)
noure		noc		nou		noem	noïa	noíem	nouré		noguí		nogui		noguem		nogut,noguda
ploure		-		plou	[plovent] plovia -		plourà		plogué		plogui		-			plogut,ploguda


-nyer verbs (regular except pp)

infinitive	pres1s	pres3s	pres1p	impf1s	fut1s		pret1s		sub1s		sub1p		pp
atènyer		atenyo	ateny	atenyem	atenyia	atenyeré	atenyí		atenyi		atenyem		atès,atesa,atesos
empènyer	empenyo	empeny	empenyem empenyia empenyeré	empenyí		empenyi		empenyem	empès,empesa,empesos
estrènyer	estrenyo estreny estrenyem estrenyia estrenyeré	estrenyí estrenyi	estrenyem	estret,estreta
estrènyer
(constrènyer,restrènyer)
fènyer		fenyo	feny	fenyem	fenyia	fenyeré		fenyí/fenguí fenyi		fenyem		fenyut/fengut,fenyuda/fenguda
pertànyer	pertanyo pertany pertanyem pertanyia pertanyeré	pertanyí/pertanguí pertanyi	pertanyem pertanyut/pertangut,pertanyuda/pertanguda
plànyer		planyo	plany	planyem	planyia	planyeré	planyí/planguí planyi	planyem		plangut/planyut,planguda/planyuda


-xer verbs (NOTE: pres2s in -xes)

infinitive	pres1s	pres3s	pres1p	impf1s	fut1s		pret1s		sub1s		sub1p		pp
créixer		creixo	creix	creixem	creixia	creixeré	creixí/cresquí creixi	creixem		 crescut,crescuda
(acréixer,decréixer)
conèixer	conec	coneix	coneixem coneixia coneixeré	coneguí		conegui		coneguem	conegut,coneguda
(desconèixer,reconèixer)
merèixer	mereixo	mereix	mereixem mereixia mereixeré	mereixí/meresquí mereixi mereixem	merescut,merescuda
néixer/		neixo/	neix/	naixem	naixia	naixeré		naixí/nasquí neixi/		naixem/nasquem nascut,nascuda
nàixer		naixo	naix											 naixi
(renéixer)
parèixer	parec	pareix	pareixem pareixia pareixeré	pareguí		paregui		pareguem	paregut,pareguda
(aparèixer,comparèixer,desaparèixer,reaparèixer)
péixer		peixo	peix	paixem	paixia	paixeré		paixí		peixi		paixem		pascut,pascuda


misc. -er verbs

infinitive	pres1s	pres3s	pres1p	impf1s	impf1p	fut1s		pret1s		sub1s		sub1p		pp
córrer		corro	corre	correm	corria	corríem	correré		correguí	corri		correm		corregut,correguda
fúmer		fumo	fum		fumem	fumia	fumíem	fumeré		fumí		fumi		fumem		fumut,fumuda
prémer		premo	prem	premem	premia	premíem	premeré		premí		premi		premem		premut,premuda
(es-, re-)
témer		temo	tem		temem	temia	temíem	temeré		temí		temi		temem		temut,temuda
trémer		[regular]
tòrcer		torço	torç	torcem	torcia	torcíem	torceré		torcí		torci		torcem		torçut,torçuda
(des-)				[pres2s torces]
vèncer		venço	venç	vencem	vencia	vencíem	venceré		vencí		venci		vencem		vençut,vençuda
(con-, re-)			[pres2s vences]
cabre/caber	cabo	cap		cabem	cabia	cabíem	cabré		cabí		càpiga		capiguem	cabut,cabuda
																			[sub2s càpigues]
haver		he/haig	ha		havem/hem havia	havíem	hauré		haguí		hagi		hàgim/haguem hagut,haguda
					[noimp]							[cond1s hauria/haguera; impsub2s haguessis/haguesses]
poder		puc		pot		podem	podia	podíem	podré		poguí		pugui		puguem		pogut,poguda
saber		sé		sap		sabem	sabia	sabíem	sabré		sabí		sàpiga		sapiguem	sabut,sabuda
					[imp2s sàpigues, imp2p sapigueu]
voler		vull	vol		volem	volia	volíem	voldré		volguí		vulgui		vulguem		volgut,volguda
ser/ésser	soc		és		som		era		érem	seré		fui			sigui		siguem		estat/sigut,estada/siguda
							[ger sent/essent]		[cond1s seria/fora]
[pres: soc,ets,éts,som,sou,són; pret: fui,fores,fou,fórem,fóreu,foren; impsub: fos,fossis,fos,fóssim,fóssiu,fossin]
[imp: sigues,sigueu]
fer			faig	fa		fem		feia	fèiem	faré		fiu			faci		fem			fet,feta
					[pres3p fan]
[pret: fiu,feres,feu,férem,féreu,feren]

]=]
local all_persons_numbers = {
	["1s"] = "1|s",
	["2s"] = "2|s",
	["3s"] = "3|s",
	["1p"] = "1|p",
	["2p"] = "2|p",
	["3p"] = "3|p",
}

local person_number_list = {"1s", "2s", "3s", "1p", "2p", "3p"}
local imp_person_number_list = {"2s", "3s", "1p", "2p", "3p"}
local neg_imp_person_number_list = {"2s", "3s", "1p", "2p", "3p"}

proclitic_non_elided_person_number_to_reflexive_pronoun = {
	["1s"] = "em ",
	["2s"] = "et ",
	["3s"] = "es ",
	["1p"] = "ens ",
	["2p"] = "us ",
	["3p"] = "es ",
}

proclitic_elided_person_number_to_reflexive_pronoun = {
	["1s"] = "m'",
	["2s"] = "t'",
	["3s"] = "s'",
	["1p"] = "ens ",
	["2p"] = "us ",
	["3p"] = "s'",
}

enclitic_non_elided_person_number_to_reflexive_pronoun = {
	["1s"] = "-me",
	["2s"] = "-te",
	["3s"] = "-se",
	["1p"] = "-nos",
	["2p"] = "-vos",
	["3p"] = "-se",
}

enclitic_elided_person_number_to_reflexive_pronoun = {
	["1s"] = "'m",
	["2s"] = "'t",
	["3s"] = "'s",
	["1p"] = "'ns",
	["2p"] = "-us",
	["3p"] = "'s",
}

local indicator_flags = m_table.listToSet {
	"no_pres_stressed",
	"only3s", "only3sp", "only3p", "noimp",
	"pp_inv", "irreg", "no_built_in",
}

-- Initialize all the slots for which we generate forms.
local function add_slots(alternant_multiword_spec)
	-- "Basic" slots: All slots that go into the regular table (not the reflexive form-of table).
	alternant_multiword_spec.verb_slots_basic = {
		{"infinitive", "inf"},
		{"infinitive_linked", "inf"},
		{"gerund", "ger"},
		{"pp_ms", "m|s|past|part"},
		{"pp_fs", "f|s|past|part"},
		{"pp_mp", "m|p|past|part"},
		{"pp_fp", "f|p|past|part"},
	}

	-- Special slots used to handle non-reflexive parts of reflexive verbs in {{ca-verb form of}}. For example, for a
	-- reflexive-only verb like [[arrepentirse]], we want to be able to use {{ca-verb form of}} on [[arrepinta]] (which
	-- should mention that it is a part of 'me arrepinta', first-person singular present subjunctive, and
	-- 'se arrepinta', third-person singular present subjunctive) or on [[arrepentimos]] (which should mention that it
	-- is a part of 'arrepentímonos', first-person plural present indicative or preterite). Similarly, we want to use
	-- {{ca-verb form of}} on [[arrepentindo]] (which should mention that it is a part of 'se ... arrepentindo',
	-- syntactic variant of [[arrepentíndose]], which is the gerund of [[arrepentirse]]). To do this, we need to be
	-- able to map non-reflexive parts like [[arrepinta]], [[arrepentimos]], [[arrepentindo]], etc. to their reflexive
	-- equivalent(s), to the tag(s) of the equivalent(s), and, in the case of forms like [[arrepentindo]],
	-- [[arrepentir]] and imperatives, to the separated syntactic variant of the verb+clitic combination. We do this by
	-- creating slots for the non-reflexive part equivalent of each basic reflexive slot, and for the separated
	-- syntactic-variant equivalent of each basic reflexive slot that is formed of verb+clitic. We use slots in this
	-- way to deal with multiword lemmas. Note that we run into difficulties mapping between reflexive verbs,
	-- non-reflexive part equivalents, and separated syntactic variants if a slot contains more than one form. To
	-- handle this, if there are the same number of forms in two slots we're trying to match up, we assume the forms
	-- match one-to-one; otherwise we don't match up the two slots (which means {{ca-verb form of}} won't work in this
	-- case, but such a case is extremely rare and not worth worrying about). Alternatives that handle this "properly"
	-- are significantly more complicated and require non-trivial modifications to [[Module:inflection utilities]].
	local need_special_verb_form_of_slots = alternant_multiword_spec.source_template == "ca-verb form of" and
		alternant_multiword_spec.refl

	if need_special_verb_form_of_slots then
		alternant_multiword_spec.verb_slots_reflexive_verb_form_of = {
			{"infinitive_non_reflexive", "-"},
			{"infinitive_variant", "-"},
			{"gerund_non_reflexive", "-"},
			{"gerund_variant", "-"},
		}
	else
		alternant_multiword_spec.verb_slots_reflexive_verb_form_of = {}
	end

	-- Add entries for a slot with person/number variants.
	-- `verb_slots` is the table to add to.
	-- `slot_prefix` is the prefix of the slot, typically specifying the tense/aspect.
	-- `tag_suffix` is a string listing the set of inflection tags to add after the person/number tags.
	-- `person_number_list` is a list of the person/number slot suffixes to add to `slot_prefix`.
	local function add_personal_slot(verb_slots, slot_prefix, tag_suffix, person_number_list)
		for _, persnum in ipairs(person_number_list) do
			local persnum_tag = all_persons_numbers[persnum]
			local slot = slot_prefix .. "_" .. persnum
			local accel = persnum_tag .. "|" .. tag_suffix
			table.insert(verb_slots, {slot, accel})
		end
	end

	-- Add a personal slot (i.e. a slot with person/number variants) to `verb_slots_basic`.
	local function add_basic_personal_slot(slot_prefix, tag_suffix, person_number_list, no_special_verb_form_of_slot)
		add_personal_slot(alternant_multiword_spec.verb_slots_basic, slot_prefix, tag_suffix, person_number_list)
		-- Add special slots for handling non-reflexive parts of reflexive verbs in {{ca-verb form of}}.
		-- See comment above in `need_special_verb_form_of_slots`.
		if need_special_verb_form_of_slots and not no_special_verb_form_of_slot then
			for _, persnum in ipairs(person_number_list) do
				local persnum_tag = all_persons_numbers[persnum]
				local basic_slot = slot_prefix .. "_" .. persnum
				local accel = persnum_tag .. "|" .. tag_suffix
				table.insert(alternant_multiword_spec.verb_slots_reflexive_verb_form_of, {basic_slot .. "_non_reflexive", "-"})
			end
		end
	end

	add_basic_personal_slot("pres", "pres|ind", person_number_list)
	add_basic_personal_slot("impf", "impf|ind", person_number_list)
	add_basic_personal_slot("pret", "pret|ind", person_number_list)
	add_basic_personal_slot("fut", "fut|ind", person_number_list)
	add_basic_personal_slot("cond", "cond", person_number_list)
	add_basic_personal_slot("pres_sub", "pres|sub", person_number_list)
	add_basic_personal_slot("impf_sub", "impf|sub", person_number_list)
	add_basic_personal_slot("imp", "imp", imp_person_number_list)
	-- Don't need special non-reflexive-part slots because the negative imperative is multiword, of which the
	-- individual words are 'no' + subjunctive.
	add_basic_personal_slot("neg_imp", "neg|imp", neg_imp_person_number_list, "no special verb form of")
	-- Don't need special non-reflexive-part slots because we don't want [[arrependendo]] mapping to [[arrependendo-me]]
	-- (only [[arrependendo-se]]) or [[arrepender]] mapping to [[arrepender-me]] (only [[arrepender-se]]).
	add_basic_personal_slot("infinitive", "inf", person_number_list, "no special verb form of")
	add_basic_personal_slot("gerund", "ger", person_number_list, "no special verb form of")

	-- Generate the list of all slots.
	alternant_multiword_spec.all_verb_slots = {}
	for _, slot_and_accel in ipairs(alternant_multiword_spec.verb_slots_basic) do
		table.insert(alternant_multiword_spec.all_verb_slots, slot_and_accel)
	end
	for _, slot_and_accel in ipairs(alternant_multiword_spec.verb_slots_reflexive_verb_form_of) do
		table.insert(alternant_multiword_spec.all_verb_slots, slot_and_accel)
	end

	alternant_multiword_spec.verb_slots_basic_map = {}
	for _, slotaccel in ipairs(alternant_multiword_spec.verb_slots_basic) do
		local slot, accel = unpack(slotaccel)
		alternant_multiword_spec.verb_slots_basic_map[slot] = accel
	end
end


local overridable_stems = {}

local function allow_multiple_values_for_override(separated_groups, data, is_form_override)
	local retvals = {}
	for _, separated_group in ipairs(separated_groups) do
		local footnotes = data.fetch_footnotes(separated_group)
		local form = separated_group[1]
		-- Prepend marker to prevent prefixing with `base.prefix`, and (in the case of form overrides) prevent
		-- final devoicing.
		if is_form_override then
			form = IS_USER_FORM_OVERRIDE .. form
		else
			form = IS_USER_STEM_OVERRIDE .. form
		end
		local retval = {form = form, footnotes = footnotes}
		table.insert(retvals, retval)
	end
	return retvals
end

for _, overridable_stem in ipairs {
	"stem",
	"stressed_stem",
	"unstressed_stem",
	"pres_unstressed",
	"pres_stressed",
	"pres3s", -- overrides just pres_2s and pres_3s
	-- Don't include pres1s, pres3p; use pres_1s etc. if you need to override just those forms
	"impf1",
	"impf2",
	"pret",
	"fut",
	"cond",
	"pres_sub_stressed",
	"pres_sub_unstressed",
	"impf_sub",
	"pp",
	"g_infix",
	"eix_infix",
} do
	-- Written so we can substitute a different validator; parallel code in [[Module:es-verb]] and [[Module:pt-verb]]
	-- has simple_choice validators.
	overridable_stems[overridable_stem] = allow_multiple_values_for_override
end


-- Useful as the value of the `match` property of a built-in verb. `main_verb_spec` is a Lua pattern that should match
-- the non-prefixed part of a verb, and `prefix_specs` is a list of Lua patterns that should match the prefixed part of
-- a verb. If a prefix spec is preceded by ^, it must match exactly at the beginning of the verb; otherwise, additional
-- prefixes (e.g. re-, des-) may precede. Return the prefix and main verb.
local function match_against_verbs(main_verb_spec, prefix_specs)
	return function(verb)
		for _, prefix_spec in ipairs(prefix_specs) do
			if prefix_spec:find("^%^") then
				-- must match exactly
				prefix_spec = prefix_spec:gsub("^%^", "")
				if prefix_spec == "" then
					-- We can't use the second branch of the if-else statement because an empty () returns the current position
					-- in rmatch().
					local main_verb = rmatch(verb, "^(" .. main_verb_spec .. ")$")
					if main_verb then
						return "", main_verb
					end
				else
					local prefix, main_verb = rmatch(verb, "^(" .. prefix_spec .. ")(" .. main_verb_spec .. ")$")
					if prefix then
						return prefix, main_verb
					end
				end
			else
				local prefix, main_verb = rmatch(verb, "^(.*" .. prefix_spec .. ")(" .. main_verb_spec .. ")$")
				if prefix then
					return prefix, main_verb
				end
			end
		end
		return nil
	end
end

--[=[

Built-in (usually irregular) conjugations.

Each entry is processed in turn and consists of an object with two fields:
1. match=: Specifies the built-in verbs that match this object.
2. forms=: Specifies the built-in stems and forms for these verbs.

The value of match= is either a string beginning with "^" (match only the specified verb), a string not beginning
with "^" (match any verb ending in that string), or a function that is passed in the verb and should return the prefix
of the verb if it matches, otherwise nil. The function match_against_verbs() is provided to facilitate matching a set
of verbs with a common ending and specific prefixes (e.g. [[ter]] and [[ater]] but not [[abater]], etc.).

The value of forms= is a table specifying stems and individual override forms. Each key of the table names either a
stem (e.g. `pres_stressed`), a stem property (e.g. `g_infix`) or an individual override form (e.g. `pres_1s`).
Each value of a stem can either be a string (a single stem), a list of strings, or a list of objects of the form
{form = STEM, footnotes = {FOONOTES}}. Each value of an individual override should be of exactly the same form except
that the strings specify full forms rather than stems. The values of a stem property depend on the specific property
but are generally strings or booleans.

In order to understand how the stem specifications work, it's important to understand the phonetic modifications done
by combine_stem_ending(). In general, the complexities of predictable prefix, stem and ending modifications are all
handled in this function. In particular:

1. Spelling-based modifications (c/qu, ç/c, g/gu, j/g, gu/gü, qu/qü) occur automatically as appropriate for the ending.
2. If the ending begins with an asterisk, this is a signal to delete the accent on the last syllable of the stem, e.g.
   veié -> veierem.
3. If ending begins with i, it may turn into í or ï after an unstressed vowel (in some but not all cases) to prevent the
   two merging into a diphthong. See combine_stem_ending() for specifics.

The following stems are recognized [FIXME: This is not correct for Catalan, needs rewriting]:

-- pres_unstressed: The present indicative unstressed stem (1p, 2p). Also controls the imperative 2p
     and gerund. Defaults to the infinitive stem (minus the ending -ar/-er/-ir/-or).
-- pres_stressed: The present indicative stressed stem (1s, 2s, 3s, 3p). Also controls the imperative 2s.
     Default is empty if indicator `no_pres_stressed`, else a vowel alternation if such an indicator is given
	 (e.g. `ue`, `ì`), else the infinitive stem.
-- pres1: Special stem for 1s present indicative. Normally, do not set this explicitly. If you need to specify an
     irregular 1s present indicative, use the form override pres_1s= to specify the entire form. Defaults to
	 pres_stressed.
-- pres_sub_unstressed: The present subjunctive unstressed stem (1p, 2p). Defaults to the infinitive stem.
-- pres_sub_stressed: The present subjunctive stressed stem (1s, 2s, 3s, 1p). Defaults to pres1.
-- impf: The imperfect stem (not including the -av-/-i- stem suffix, which is determined by the conjugation). Defaults
     to the infinitive stem.
-- pret: The full preterite stem missing only the endings (-ste, -mos, etc.), e.g. 'fige', 'fo'. Only used for verbs
	 with irregular preterites (pret_conj == "irreg") such as [[facer]], [[poder]], [[traer]], etc. Defaults to
	 `pret_base` + the conjugation vowel.
-- fut: The future stem. Defaults to the infinitive stem + the conjugation vowel.
-- cond: The conditional stem. Defaults to `fut`.
-- impf_sub: The imperfect subjunctive stem. Defaults to `pret`.
-- pp: The masculine singular past participle. Default is based on the verb conjugation: infinitive stem + '-ado' for
     -ar verbs, otherwise infinitive stem + '-ido'.
-- pp_inv: `true` if the past participle exists only in the masculine singular.
]=]

local built_in_conjugations = {

	--------------------------------------------------------------------------------------------
	--                                             -ar                                        --
	--------------------------------------------------------------------------------------------

	-- Orthographic consonant alternations in endings are handled automatically in combine_stem_ending().

	{
		-- [[aguar]]:
		--   pres agúo, agúes, agúa, agüem, agüeu, agúen
		--   pres_sub aguï, aguïs, aguï, agüem, agüeu, aguïn
		-- contrast a more typical verb in -guar, [[enaiguar]]:
		--   pres enaiguo, enaigües, enaigua, enaigüem, enaigüeu, enaigüen
		--   pres_sub enaigüi, enaigüis, enaigüi, enaigüem, enaigüeu, enaigüin
		match = "^aguar",
		forms = {
			pres_stressed = "agú",
			pres_sub_stressed = "aguï",
			irreg = true,
		}
	},
	{
		-- [[anar]] (full verb); highly irregular
		match = "^anar",
		var = "full",
		forms = {
			fut = "anir",
			pres_1s = "vaj", -- will be converted to 'vaig'; 'vaig' gets converted to 'vaic'
			pres_2s = "vas",
			pres_3s = "va",
			pres_3p = "van",
			pres_sub_stressed = "vagi",
			imp_2s = "ves",
			irreg = true,
		}
	},
	{
		-- [[anar]] (auxiliary); highly irregular
		match = "^anar",
		var = "aux",
		forms = {
			pres_1s = "vaj", -- will be converted to 'vaig'; 'vaig' gets converted to 'vaic'
			pres_2s = {"vas", "vares"},
			pres_3s = "va",
			pres_1p = {"vam", "vàrem"},
			pres_2p = {"vau", "vàreu"},
			pres_3p = {"van", "varen"},
			pres_sub_stressed = "vagi",
			pres_sub_unstressed = "vàgi",
			impf1 = {},
			impf2 = {},
			fut = {},
			pret = {},
			pp = {},
			gerund = {},
			noimp = true,
			irreg = true,
		}
	},
	{
		-- [[dar]]
		match = "^dar",
		forms = {
			pres_1s = {form = "do", footnotes = {"[obsolete]"}},
			pres_2s = {form = "das", footnotes = {"[obsolete]"}},
			pres_3s = {form = "da", footnotes = {"[obsolete]"}},
			pres_3p = {form = "dan", footnotes = {"[obsolete]"}},
			pres_sub_1s = {form = "de", footnotes = {"[obsolete]"}},
			pres_sub_2s = {form = "des", footnotes = {"[obsolete]"}},
			pres_sub_3s = {form = "de", footnotes = {"[obsolete]"}},
			pres_sub_3p = {form = "den", footnotes = {"[obsolete]"}},
			pret_1s = "di", -- regular except for lack of accent
			pret_3s = "da", -- regular except for lack of accent
			impf_sub_1s = "des", -- regular except for lack of accent
			impf_sub_3s = "des", -- regular except for lack of accent
			irreg = true,
		}
	},
	{
		-- [[estar]]; highly irregular
		match = "^estar",
		forms = {
			pres_2s = "estàs",
			pres_3s = "està",
			pres_3p = "estan",
			g_infix = "estig",
			imp_2s = "estigues",
			imp_2p = "estigueu",
			pp = "estad",
		}
	},

	--------------------------------------------------------------------------------------------
	--                                           -er/-re                                      --
	--------------------------------------------------------------------------------------------

	-- Regular verbs not needing entries here:
	--
	-- [[rebre]], [[concebre]], [[decebre]], [[percebre]]
	-- [[rompre]]
	-- [[fúmer]], [[prémer]], [[témer]], [[trémer]]
	-- [[perdre]], [[batre]], [[botre]], [[fotre]], [[retre]]
	-- [[tòrcer]], [[vèncer]]
	-- etc.

	------------------------------------------- -ldre/-ler --------------------------------------

	{
		-- [[caldre]], [[doldre]], [[condoldre's]], [[oldre]]
		match = match_against_verbs("ldre", {"ca", "do", "^o"}),
		forms = {
			-- g_infix implies irreg = true
			-- g_infix adds -g to pres_1s, sub, pret and pp stems; combine_stem_ending() changes final -g to -c
			g_infix = "+",
		}
	},
	{
		-- [[caler]]
		match = "caler",
		like = "caldre",
	},
	{
		-- [[doler]] and compounds
		match = "doler",
		like = "doldre",
	},
	{
		-- [[valer]], [[equivaler]], [[prevaler]], [[sobrevaler]]
		match = "valer",
		forms = {
			-- see above for g_infix effects
			fut = "valdr",
			g_infix = "+",
		}
	},
	{
		-- [[valdre]] and compounds
		match = "valdre",
		like = "valer",
	},
	{
		-- [[soler]]
		match = "^soler", -- this must precede -oldre rule below for alt form [[soldre]]
		forms = {
			-- see above for g_infix effects
			fut = {},
			pret = {},
			impf_sub = "solgué", -- regular, but we disabled the preterite, which would normally disable impf_sub too
			g_infix = "+",
			pp = {},
			noimp = true,
		}
	},
	{
		-- [[soldre]]
		match = "^soldre", -- this must precede -oldre rule below
		like = "soler",
	},
	{
		-- [[coldre]], [[moldre]], [[absoldre]], [[dissoldre]], [[resoldre]], [[toldre]]
		match = "oldre", -- this must follow [[doldre]]/[[oldre]] rule above
		forms = {
			-- see above for g_infix effects
			g_infix = "+",
			pp = "olt",
		}
	},
	{
		-- [[voler]], [[malvoler]]
		match = "voler",
		forms = {
			fut = "voldr",
			pres_1s = "vull",
			pres_sub_stressed = "vulgui",
			pres_sub_unstressed = "vulgue",
			g_infix = "+",
			imp_2s = "vulgues",
			imp_2p = "vulgueu",
		}
	},

	--------------------------------------------- -ndre ----------------------------------------

	{
		-- [[romandre]]; write it this way so there's a prefix with a vowel to prevent against the accent in the pp
		-- from being removed while still removing it in the feminine.
		match = match_against_verbs("mandre", {"^ro"}),
		forms = {
			-- see above for g_infix effects
			g_infix = "+",
			pp = "màs#",
		}
	},
	{
		-- [[encendre]], [[atendre]], [[contendre]], [[desentendre's]], [[distendre]], [[entendre]], [[estendre]],
		-- [[pretendre]]
		match = match_against_verbs("endre", {"enc", "t"}),
		forms = {
			pres_3s = "én#", -- remove final accent without prefix with vowel; also removed when adding a suffix
			-- see above for g_infix effects
			g_infix = "+",
			pp = "ès#", -- see above for effect of final #
		}
	},
	{
		-- [[vendre]], [[malvendre]], [[revendre]]
		match = "vendre",
		forms = {
			pres_3s = "vèn#", -- see above for effect of final #
			-- see above for g_infix effects
			g_infix = "+",
			pp = "venud", -- g_infix would normally make it vengud
		}
	},
	{
		-- [[fendre]], [[defendre]], [[ofendre]], [[dependre]], [[despendre]], [[expendre]], [[suspendre]], [[prendre]],
		-- [[aprendre]], [[comprendre]], [[desprendre]], [[emprendre]], [[reprendre]], [[sorprendre]]
		match = "endre", -- this must follow previous -endre rules above
		forms = {
			pres_3s = "èn#", -- see above for effect of final #
			-- see above for g_infix effects
			g_infix = "+",
			pp = "ès#", -- see above for effect of final #
		}
	},
	{
		-- [[enfondre]]; write it this way so there's a prefix with a vowel to prevent against the accent in the pp
		-- from being removed while still removing it in the feminine.
		match = match_against_verbs("fondre", {"^en"}),
		forms = {
			-- see above for g_infix effects
			g_infix = "+",
			pp = "fús#",
		}
	},
	{
		-- [[pondre]], [[compondre]], [[correspondre]], [[descompondre]], [[despondre's]], [[respondre]]
		match = "pondre",
		forms = {
			-- see above for g_infix effects
			g_infix = "+",
			pp = "post",
		}
	},
	{
		-- [[fondre]], [[confondre]], [[difondre]], [[infondre]], [[refondre]], [[tondre]]
		match = "ondre", -- this must follow previous -ondre rules above
		forms = {
			-- see above for g_infix effects
			g_infix = "+",
			pp = "ós#", -- see above for effect of final #
		}
	},

	--------------------------------------------- -nyer ----------------------------------------

	{
		-- [[atènyer]]; write it this way so there's a prefix with a vowel to prevent against the accent in the pp
		-- from being removed while still removing it in the feminine.
		match = match_against_verbs("tènyer", {"^a"}),
		forms = {
			pp = "tès#",
			irreg = true,
		}
	},
	{
		-- [[empènyer]], [[espènyer]]
		match = match_against_verbs("pènyer", {"^em", "^es"}),
		forms = {
			pp = "pès#",
			irreg = true,
		}
	},
	{
		-- [[estrènyer]], [[constrènyer]], [[destrènyer]], [[restrènyer]]
		match = match_against_verbs("strènyer", {"^e", "con", "^de", "^re"}),
		forms = {
			pp = "stret",
			irreg = true,
		}
	},
	{
		-- [[fènyer]]
		match = "fènyer",
		forms = {
			pp = {"fengud", "fenyud"},
			irreg = true,
		}
	},
	{
		-- [[júnyer]]
		match = "júnyer",
		like = "junyir",
	},
	{
		-- [[plànyer]], [[complànyer]], [[pertànyer]]
		match = match_against_verbs("ànyer", {"pl", "pert"}),
		forms = {
			pp = {"angud", "anyud"},
			irreg = true,
		}
	},

	--------------------------------------------- -aure ----------------------------------------

	{
		-- [[caure]], [[decaure]], [[recaure]]
		match = "caure",
		forms = {
			-- stem ending in -ai and imperfect in -ia causes special stressed imperfect logic to take effect; we get
			-- impf1s queia, impf1p quèiem (preceding vowel changed to è and attached to initial consonant using
			-- combine_stem_ending(), which changes c- to qu-)
			stem = "caie", -- i dropped by g_infix before u
			-- g_infix implies irreg = true
			-- g_infix adds -g to pres_1s, sub, pret and pp stems; combine_stem_ending() changes final -g to -c
			-- g_infix sets pres_stressed to end in -u, removing a preceding -i or -v
			g_infix = "+",
		}
	},
	{
		-- [[plaure]], [[complaure]]
		match = "plaure",
		forms = {
			stem = "plae", -- ï in impf1s -aïa gets generated automatically by combine_stem_ending()
			g_infix = "+",
		}
	},
	{
		-- [[raure]]
		match = "^raure",
		forms = {
			stem = "rae", -- ï in impf1s -aïa gets generated automatically by combine_stem_ending()
			g_infix = "+",
			pp = {"ragud", "ras"},
		}
	},

	--------------------------------------------- -eure ----------------------------------------

	{
		-- [[beure]], [[embeure]], [[deure]], [[lleure]]
		match = match_against_verbs("eure", {"b", "d", "ll"}),
		forms = {
			stem = "eve", -- v dropped by g_infix before g and u
			g_infix = "+",
		}
	},
	{
		-- [[creure]], [[seure]], [[asseure]]
		match = match_against_verbs("eure", {"cr", "s"}),
		forms = {
			stem = "ee",
			pres_unstressed = "eie", -- affects pres_1p, pres_2p, gerund, imperfect (see [[caure]])
			g_infix = "+",
		}
	},
	{
		-- [[jeure]], [[ajeure]]
		match = "jeure",
		forms = {
			fut = "jaur", -- affects future and cond
			stressed_stem = "jee", -- affects stressed forms, which get g added by g_infix by added except for
								   -- pres_stressed, which gets u added (controls pres_3s, pres_2s, pres_3p)
			unstressed_stem = "jae", -- affects unstressed_stem, which get g added by g_infix
			pres_stressed = {"jeu", "jau"},
			pres_unstressed = "jaie", -- affects pres_1p, pres_2p, gerund, imperfect (see [[caure]])
			pres_1s = {"jec", "jac"},
			impf1 = "jei", -- otherwise we'd get impf_1s '#geia' etc.
			impf2 = "jèi",
			g_infix = "+",
		}
	},
	{
		match = "jaure",
		like = "jeure",
	},
	{
		-- [[treure]], [[abstreure]], [[atreure]], [[bestreure]], [[contreure]], [[detreure]], [[distreure]],
		-- [[extreure]], [[retreure], [[retrotreure]], [[sostreure]]
		match = "treure",
		forms = {
			-- like [[jeure]] except for irregular pp
			fut = "traur",
			stressed_stem = "tree",
			unstressed_stem = "trae",
			pres_stressed = {"treu", "trau"},
			pres_unstressed = "traie",
			pres_1s = {"trec", "trac"},
			g_infix = "+",
			pp = "tret",
		}
	},
	{
		match = "traure",
		like = "treure",
	},
	{
		-- [[veure]], [[entreveure]], [[preveure]], [[reveure]]
		match = "veure",
		forms = {
			stem = "veie",
			-- impf1s veia, impf1p vèiem (preceding vowel changed to è)
			pres_stressed = "veu",
			pres_1s = "vej", -- will be converted to 'veig'; 'veig' gets converted to 'veic'
			pres_sub_stressed = "vegi",
			pres_sub_unstressed = "vege",
			pret = {"veié", "vé"},
			pret_1s = "viu",
			pret_3s = {"veié", "veu"},
			impf_sub = "veié",
			pp = "vist",
			imp_2s = "veges",
			imp_2p = {"vegeu", "veieu"},
			irreg = true,
		}
	},

	--------------------------------------------- -iure ----------------------------------------

	{
		-- [[escriure]], [[circumscriure]], [[descriure]], [[inscriure]], [[prescriure]], [[proscriure]],
		-- [[subscriure]], [[transcriure]]
		match = "scriure",
		forms = {
			stem = "scrivi", -- v dropped by g_infix before g and u; pres_1p/pres_2p have -ir endings
			g_infix = "+",
			pret = {"scriví", "scrigué"},
			pp = "scrit",
		}
	},
	{
		-- [[riure]], [[somriure]]
		match = "riure", -- must follow rule for 'scriure'
		forms = {
			stem = "rie",
			-- impf1s reia, impf1p rèiem (preceding vowel changed to è)
			g_infix = "+",
		}
	},
	{
		-- [[viure]], [[conviure]], [[desviure's]], [[sobreviure]]
		match = "viure",
		forms = {
			stem = "vivi", -- v dropped by g_infix before g and u; pres_1p/pres_2p have -ir endings
			g_infix = "visc", -- applies to pres1s, sub, pret, pp
		}
	},

	--------------------------------------------- -oure ----------------------------------------

	{
		-- [[cloure]], [[concloure]], [[descloure]], [[encloure]], [[excloure]], [[incloure]], [[recloure]]
		match = "cloure",
		forms = {
			stem = "cloe", -- ï in impf1s cloïa gets generated automatically by combine_stem_ending()
			g_infix = "+",
			pp = "clòs#", -- remove final accent without prefix with vowel; also removed when adding a suffix
		}
	},
	{
		-- [[coure]] "to cook"
		match = "coure",
		var = "cook",
		forms = {
			stem = "coe", -- ï in impf1s coïa gets generated automatically by combine_stem_ending()
			g_infix = "+",
			pp = "cuit",
		}
	},
	{
		-- [[coure]] "to sting"
		match = "coure",
		var = "sting",
		forms = {
			stem = "coe", -- ï in impf1s coïa gets generated automatically by combine_stem_ending()
			g_infix = "+",
			-- pp regular 'cogud'
		}
	},
	{
		-- [[moure]], [[promoure]], [[remoure]], [[somoure]], [[ploure]]
		match = match_against_verbs("oure", {"m", "pl"}),
		forms = {
			stem = "ove", -- v dropped by g_infix before g and u
			g_infix = "+",
		}
	},
	{
		-- [[noure]]
		match = "noure",
		forms = {
			stem = "noe", -- ï in impf1s -aïa gets generated automatically by combine_stem_ending()
			g_infix = "+",
		}
	},

	--------------------------------------------- -xer ----------------------------------------

	{
		-- [[conèixer]], [[desconèixer]], [[reconèixer]]
		match = "conèixer",
		forms = {
			g_infix = "coneg",
		}
	},
	{
		-- [[créixer]], [[acréixer]], [[decréixer]], [[recréixer]], [[sobrecréixer]]
		match = "créixer",
		forms = {
			pret = {"creixé", "cresqué"},
			pres_sub_unstressed = {"creixe", "cresque"},
			pp = "crescud",
			irreg = true,
		}
	},
	{
		-- [[merèixer]], [[desmerèixer]], [[irèixer-se]]
		match = match_against_verbs("rèixer", {"me", "^i"}),
		forms = {
			pret = {"reixé", "resqué"},
			pres_sub_unstressed = {"reixe", "resque"},
			pp = "rescud",
			irreg = true,
		}
	},
	{
		-- [[néixer]]/[[nàixer]], [[renéixer]]/[[renàixer]], [[sobrenéixer]]/[[sobrenàixer]], [[péixer]]/[[pàixer]]
		match = match_against_verbs("éixer", {"n", "p"}),
		forms = {
			stem = "aixe",
			fut = "aixer",
			pres_stressed = {"eix", "aix"},
			pres_1s = "eixo",
			pret = {"aixé", "asqué"},
			pres_sub_stressed = "eixi",
			pres_sub_unstressed = {"aixe", "asque"},
			pp = "ascud",
			irreg = true,
		}
	},
	{
		match = "àixer",
		like = "éixer",
	},
	{
		-- [[parèixer]], [[aparèixer]], [[comparèixer]], [[desaparèixer]], [[reaparèixer]]
		match = "parèixer",
		forms = {
			g_infix = "pareg",
		}
	},


	--------------------------------------------- misc ----------------------------------------

	{
		-- [[cabre]]
		match = "cabre",
		forms = {
			pres_sub_stressed = "càpiga",
			pres_sub_unstressed = "capigue",
			irreg = true,
		}
	},
	{
		-- [[caber]]
		match = "caber",
		like = "cabre",
	},
	{
		-- [[saber]]
		match = "saber",
		forms = {
			fut = "sabr",
			pres_1s = "sé",
			pres_sub_stressed = "sàpiga",
			pres_sub_unstressed = "sapigue",
			imp_2s = "sàpiga",
			imp_2p = "sapigueu",
			irreg = true,
		}
	},
	{
		-- [[poder]]
		match = "poder",
		forms = {
			fut = "podr",
			pres_1s = "puc",
			pres_sub_stressed = "pugui",
			pres_sub_unstressed = "pugue",
			g_infix = "pog",
			imp_2s = "pugues",
			imp_2p = "pugueu",
			irreg = true,
		}
	},
	{
		-- [[córrer]], [[acórrer]], [[concórrer]], [[decórrer]], [[descórrer]], [[discórrer]], [[encórrer]],
		-- [[escórrer]], [[incórrer]], [[ocórrer]], [[recórrer]], [[socórrer]], [[transcórrer]]
		match = "córrer",
		forms = {
			pret = "corregué",
			pres_sub_unstressed = {"corre", "corregue"},
			pp = "corregud",
			irreg = true,
		}
	},
	{
		-- [[metre]], [[admetre]], [[arremetre]], [[cometre]], [[comprometre]], [[demetre]], [[descomprometre]],
		-- [[emetre]], [[entremetre's]], [[escometre]], [[malmetre]], [[manumetre]], [[ometre]], [[permetre]],
		-- [[prometre]], [[readmetre]], [[remetre]], [[retransmetre]], [[sotmetre]], [[trametre]], [[transmetre]]
		match = "metre",
		forms = {
			pp = "mès#",
			irreg = true,
		}
	},

	--------------------------------------------------------------------------------------------
	--                                             -ir                                        --
	--------------------------------------------------------------------------------------------

	{
		-- [[acudir]]; NOTE: Separation by meaning does not occur in DCC, DIEC, DEIEC, and DCVB says the distinction
		-- is geographical and makes no mention of distinction by meaning. OTOH ca.wikt does say that the pronominal
		-- sense "to occur" tends to conjugate non-inchoative.
		match = "acudir",
		forms = {
			eix_infix = {{
				form = "+",
				footnotes = {'[especially in the sense "to turn up, to be present"]'}
			}, {
				form = "-",
				footnotes = {'[especially in the pronominal sense "to occur"]'}
			}}
		}
	},
	-- [[afegir]]: -- non-inchoative in Valencia, inchoative elsewhere
	{
		-- [[ajupir]]
		-- [[buixir]]
		-- [[bullir]], [[rebullir]]
		-- [[cruixir]], [[escruixir]] (Routledge says this is inchoative but DIEC, DEIEC and DCC all disagree; note
		--   pres_2s 'cruixes', handled automatically)
		-- [[dormir]], [[adormir]]
		-- [[funyir]]
		-- [[grunyir]]
		-- [[munyir]], [[esmunyir]]
		-- [[pudir]]
		-- [[punyir]]
		-- [[retrunyir]]
		-- [[sentir]], [[pressentir]], [[ressentir-se]]; not [[consentir]], with can be either non-inchoative or
		-- inchoative, and not [[assentir]] or [[dissentir]], which are only inchoative
		match = match_against_verbs("ir", {"ajup", "buix", "bull", "cruix", "dorm", "funy", "gruny", "muny", "pud",
										   "puny", "retruny", "^sent", "pressent", "^ressent"}),
		forms = {
			eix_infix = "-",
		}
	},
	{
		-- [[arrupir-se]];
		-- [[brumir]];
		-- [[brunzir]];
		-- [[consumir]], [[resumir]], [[presumir]] (not [[sumir]], [[assumir]], [[subsumir]], which are regular)
		-- [[mentir]], [[desmentir]]
		-- [[percudir]]; cf. also [[acudir]], which to some extent has separate conjugations per meaning
		-- [[consentir]]
		match = match_against_verbs("ir", {"arrup", "brum", "brunz", "consum", "^resum", "presum", "ment", "percud",
										   "consent"}),
		forms = {
			eix_infix = {"+", "-"},
		}
	},
	-- [[cenyir]]: -- non-inchoative or inchoative in Balearics, inchoative elsewhere
	{
		-- [[cobrir]], [[descobrir]], [[encobrir]], [[recobrir]], [[redescobrir]]
		match = "cobrir",
		forms = {
			pp = "cobert",
			irreg = true,
		}
	},
	{
		-- [[collir]], [[acollir]], [[escollir]], [[recollir]]
		match = "collir",
		forms = {
			stressed_stem = "culli",
			eix_infix = "-",
			irreg = true,
		}
	},
	{
		-- [[complir]], [[acomplir]], [[incomplir]]
		match = "complir",
		forms = {
			pp = {"complert", "complid"},
			irreg = true,
		}
	},
	{
		-- [[cosir]], [[descosir]], [[recosir]]
		match = "cosir",
		forms = {
			stressed_stem = "cusi",
			pres_3s = "cús#",
			eix_infix = "-",
			irreg = true,
		}
	},
	{
		-- [[eixir]], [[deseixir-se]]; not [[teixir]] or [[entreteixir]], and not [[reeixir]] or [[sobreeixir]],
		-- which have an ï in the stem-stressed forms
		match = match_against_verbs("eixir", {"^", "des"}),
		forms = {
			stressed_stem = "ixi",
			eix_infix = "-",
			irreg = true,
		}
	},
	{
		-- [[reeixir]], [[sobreeixir]]
		match = match_against_verbs("eixir", {"^re", "sobre"}),
		forms = {
			stressed_stem = "ïxi",
			eix_infix = "-",
			irreg = true,
		}
	},
	-- [[engolir]]: -- non-inchoative in Valencia, inchoative elsewhere
	{
		-- [[escopir]]
		match = "escopir",
		forms = {
			stressed_stem = "escupi",
			eix_infix = "-",
			irreg = true,
		}
	},
	{
		-- [[establir]], [[preestablir]], [[restablir]]
		match = "establir",
		forms = {
			pp = {"establert", "establid"},
			irreg = true,
		}
	},
	-- [[ferir]]: -- non-inchoative in Balearics, inchoative elsewhere
	-- [[fregir]]: -- non-inchoative in Valencia, inchoative elsewhere
	{
		-- [[fugir]], [[confugir]], [[defugir]], [[enfugir-se]]; pres sing ''fujo, fuges, fuig'' handled by
		--   combine_stem_ending(); can't be handled by rule above that lists many non-inchoative verbs because the
		--   prefix would be 'fug' and the front-back alternation code doesn't apply to prefixes.
		match = "fugir",
		forms = {
			eix_infix = "-",
		}
	},
	{
		-- [[imprimir]], [[reimprimir]], [[sobreimprimir]]; not any other verbs in -primir; write it this way so
		-- there's a prefix with a vowel to prevent against the accent in the pp from being removed while still
		-- removing it in the feminine.
		match = match_against_verbs("primir", {"im"}),
		forms = {
			pp = "près#",
			irreg = true,
		}
	},
	-- [[llegir]]: -- non-inchoative in Valencia and Minorca, inchoative elsewhere
	{
		-- [[lluir]]: regular inchoative in the figurative meaning "to display (something), to be showy" also in the
		-- legal meaning "free from a pecuniary obligation, such as a land-based tax (emphyteusis)"; irregular in the
		-- literal meaning "to shine"; use <no_built_in> to get regular conjugation. In the regular conjugation,
		-- umlauts appear in the following forms: pres_1p/pres_sub_1p/imp_1p lluïm, pres_2p/pres_sub_2p/imp_2p lluïu,
		-- impf_1s/impf_3s lluïa, impf_2s lluïes, impf_3p lluïen, pret_2s lluïres, pret_3p lluïren,
		-- impf_sub_2s lluïssis, impf_sub_3p lluïssin, throughout the pp: lluït, lluïda, lluïts, lluïdes. IN the
		-- irregular conjugation, umlauts appear in the same places as well as elsewhere in the present subjunctive:
		-- pres_sub_1s/pres_sub_3s/imp_3s lluï, pres_sub_2s lluïs, pres_sub_3p/imp_3p lluïn. Notably, they do *NOT*
		-- appear in the gerund lluint, the infinitive lluir, or anywhere in the future or conditional. Note that
		-- verbs.cat [https://www.verbs.cat/en/conjugation/899-lluir.html] lists additional irregular forms pres_1s
		-- lluu, and alternative impf_sub forms in -e- instead of -i- (lluïsses, lluíssem, lluísseu, lluïssen), but
		-- these are nonstandard or dialectal per both Routledge and DEIEC.
		match = "^lluir",
		forms = {
			eix_infix = "-",
			pres3s = {"lluu", "llu"}, -- generates pres_2s, imp_2s
			irreg = true,
		}
	},
	{
		-- [[entrelluir]] "to be half-seen", [[relluir]] "to shine", [[traslluir-se]] "to be translucent"; either
		-- inchoative or non-inchoative, not distinguished by meaning; note, [[deslluir]] and [[enlluir]] are regular
		-- inchoative verbs.
		match = match_against_verbs("lluir", {"entre", "^re", "tras"}),
		forms = {
			eix_infix = {"+", "-"},
			pres3s = {"llueix", "lluu", "llú"}, -- generates pres_2s, imp_2s; note, pres_2s will end in -es due to
											    -- combine_stem_ending()
			irreg = true,
		}
	},
	{
		-- [[morir]], [[premorir]]; but not [[atemorir]]
		match = match_against_verbs("morir", {"^", "pre"}),
		forms = {
			eix_infix = "-",
			pp = "mort",
			irreg = true,
		}
	},
	{
		-- [[obrir]], [[entreobrir]], [[reobrir]]; not [[cobrir]] and derivatives, not [[empobrir]], so we have to list
		-- them individually
		match = match_against_verbs("obrir", {"^", "entre", "^re"}),
		forms = {
			eix_infix = "-",
			pp = "obert",
			irreg = true,
		}
	},
	{
		-- [[oferir]]; but not [[proferir]]
		match = "^oferir",
		forms = {
			pp = {"ofert", "oferid"},
			irreg = true,
		}
	},
	-- [[oir]], [[desoir]], [[entreoir]]: -- per Routledge, non-inchoative or inchoative normally but only
	-- non-inchoative in Valencian; but all dictionaries disagree and say it is a regular inchoative-only verb.
	-- It has the same umlauts as lluir (and [[corroir]], another regular inchoative verb).
	{
		-- [[omplir]], [[desomplir-se]], [[reomplir]]; not [[complir]] and derivatives, so we have to list them
		-- individually
		match = match_against_verbs("omplir", {"^", "des", "^re"}),
		forms = {
			eix_infix = "-",
			pp = {"omplert", "omplid"},
			irreg = true,
		}
	},
	-- [[penedir-se]]: -- non-inchoative in Balearics, inchoative elsewhere
	{
		-- [[pruir]] "to itch": same umlauts as in [[lluir]].
		match = "^pruir",
		forms = {
			eix_infix = "-",
			pres3s = {"pruu", "pru"}, -- generates pres_2s, imp_2s
			irreg = true,
		}
	},
	{
		-- [[reblir]]
		match = "^reblir",
		forms = {
			pp = {"reblert", "reblid"},
			irreg = true,
		}
	},
	-- [[renyir]]: -- non-inchoative in Valencia, inchoative elsewhere
	{
		-- [[sofrir]]
		match = "^sofrir",
		forms = {
			pp = {"sofert", "sofrid"},
			irreg = true,
		}
	},
	{
		-- [[sortir]], [[ressortir]], [[sobresortir]]; but not [[assortir]], which is regular inchoative
		match = match_against_verbs("sortir", {"^", "^res", "sobre"}),
		forms = {
			stressed_stem = "surti",
			eix_infix = "-",
			irreg = true,
		}
	},
	{
		-- [[suplir]]
		match = "^suplir",
		forms = {
			pp = {"suplert", "suplid"},
			irreg = true,
		}
	},
	-- [[teixir]], [[entreteixir]]: -- non-inchoative in Valencia, inchoative elsewhere
	{
		-- [[tenir]] but not any compounds; highly irregular
		match = "^tenir",
		forms = {
			fut = "tindr",
			pres_stressed = "ten",
			pres_3s = "té",
			imp_2s = {"té", "ten", "tingues"},
			imp_2p = {"teniu", "tingueu"},
			g_infix = "ting",
		}
	},
	{
		-- [[abstenir-se]], [[atenir-se]], [[captenir-se]], [[cartenir]], [[contenir]], [[detenir]], [[entretenir]],
		-- [[mantenir]], [[menystenir]], [[obtenir]], [[retenir]], [[sostenir]], [[viltenir]]; highly irregular
		match = "tenir",
		forms = {
			fut = "tindr",
			pres_stressed = "ten",
			pres_3s = "té",
			imp_2s = {"tén", "tingues"},
			imp_2p = {"teniu", "tingueu"},
			g_infix = "ting",
		}
	},
	{
		-- [[tindre]]: variant of [[tenir]]
		match = "tindre",
		like = "tenir",
	},
	-- [[tenyir]], [[destenyir]]: -- non-inchoative in Valencia, but [[retenyir]] inchoative or non-inchoative in
	-- Valencia? (per Routledge); regular inchoative elsewhere
	{
		-- [[tossir]] "to cough"
		match = "^tossir",
		forms = {
			stressed_stem = "tussi", -- pres_2s gets 'tusses'
			pres_3s = "tus", -- note, pres_3s (a single form override) not pres3s (a stem override, which also affects
							 -- pres_2s; but imp_2s is physically copied from pres_3s, so imp_2s correctly gets 'tus')
			eix_infix = "-",
			irreg = true,
		}
	},
	{
		-- [[venir]] but not any compounds; highly irregular
		match = "^venir",
		forms = {
			fut = "vindr",
			pres_stressed = "ven",
			pres_3s = "ve",
			imp_2s = "vine",
			g_infix = "ving",
		}
	},
	{
		-- compounds of [[venir]]: [[advenir]], [[avenir]], [[contravenir]], [[convenir]], [[desavenir-se]],
		-- [[desconvenir]], [[entrevenir]], [[esdevenir]], [[intervenir]], [[obvenir]], [[pervenir]], [[prevenir]],
		-- [[provenir]], [[reconvenir]], [[revenir]], [[sobrevenir]], [[subvenir]]; but not [[enjovenir]] or
		-- [[rejovenir]]; highly irregular
		match = match_against_verbs("venir", {"^ad", "^a", "contra", "con", "desa", "entre", "esde", "inter", "ob",
											  "per", "pre", "pro", "^re", "sobre", "sub"}),
		forms = {
			fut = "vindr",
			pres_stressed = "ven",
			pres_3s = "vé",
			imp_2s = "vén",
			g_infix = "ving",
		}
	},
	{
		-- [[vindre]]: variant of [[venir]]
		match = "vindre",
		like = "venir",
	},
	-- [[vestir]], [[desvestir]], [[revestir]], maybe [[transvestir]]: non-inchoative in Valencia, inchoative or
	-- non-inchoative in the Balearics; regular inchoative elsewhere; but not [[envestir]] or [[investir]], which are
	-- regular inchoative everywhere
	{
		-- [[fer]], [[contrafer]], [[desfer]], [[estrafer]], [[perfer]], [[refer]], [[satisfer]]; highly irregular
		match = "fer",
		forms = {
			fut = "far",
			pres_1s = "faj", -- will be converted to 'faig'; 'faig' gets converted to 'faic'
			pres_2s = "fàs#",
			pres_3s = "fà#",
			pres_3p = "fan",
			pres_unstressed = "fe",
			impf1 = "fei",
			impf2 = "fèi",
			pres_sub_stressed = "faci",
			pres_sub_unstressed = "fe",
			pret = "fé",
			pret_1s = "fiu",
			pret_3s = "feu",
			impf_sub_1s = "fés#", -- regular except for base form [[fes]], lacking an accent
			impf_sub_3s = "fés#", -- same
			imp_2s = "fés#",
			pp = "fet",
			irreg = true,
		}
	},
	{
		-- [[dir]], [[adir-se]], [[contradir]], [[desdir]], [[entredir]], [[interdir]], [[maldir]], [[predir]], [[redir]];
		-- behaves like an -er/-re verb
		match = match_against_verbs("dir", {"^", "^a", "contra", "des", "entre", "inter", "mal", "pre", "^re"}),
		forms = {
			stem = "die",
			g_infix = "+",
			imp_2s = "digues",
			imp_2p = "digueu",
			pp = "dit",
		}
	},
	{
		-- [[dur]], [[endur-se]]; behaves like an -er/-re verb
		match = "dur",
		forms = {
			stem = "due",
			g_infix = "+",
			pres3s = {"duu", "du"}, -- generates pres_2s, imp_2s
			impf1 = "dui",
			impf2 = "dúi",
			pp = "dut",
		}
	},
	{
		-- [[ser]]; highly irregular
		match = "^ser",
		forms = {
			pres_1s = "soc",
			pres_2s = "ets",
			pres_3s = "és",
			pres_1p = "som",
			pres_2p = "sou",
			pres_3p = "són",
			impf1 = "er",
			impf2 = "ér",
			pres_sub_stressed = "sigui",
			pres_sub_unstressed = "sigue",
			pret = "fó",
			pret_1s = "fui",
			pret_3s = "fou",
			impf_sub_1s = "fos", -- regular except for lack of accent
			impf_sub_3s = "fos", -- same
			cond = {"serí", "fór"},
			imp_2s = "sigues",
			imp_2p = "sigueu",
			pp = {"estad", "sigud"},
			gerund = {"sent", "essent"},
			irreg = true,
		}
	},
	{
		-- [[ésser]]; variant of [[ser]]
		match = "^ésser",
		like = "ser",
	},
	{
		-- [[haver]] as auxiliary; highly irregular
		match = "^haver",
		var = "aux",
		forms = {
			pres_1s = "he",
			pres_2s = "has",
			pres_3s = "ha",
			pres_1p = "hem",
			pres_2p = "heu",
			pres_3p = "han",
			fut = "haur",
			cond = {"haurí", "haguér"},
			pres_sub_stressed = "hagi",
			pres_sub_unstressed = "hàgi",
			noimp = true,
			g_infix = "+",
		}
	},
	{
		-- [[haver]] as full verb; highly irregular
		match = "^haver",
		var = "full",
		forms = {
			pres_1s = {"hec", "hac"},
			pres_stressed = {"heu", "hau"},
			fut = "haur",
			pres_sub_stressed = "hegui",
			g_infix = "+",
		}
	},
	{
		-- [[heure]]; variant of full verb [[haver]]
		match = "^heure",
		like = "haver",
		likevar = "full",
	},
	{
		-- [[haure]]; variant of full verb [[haver]]
		match = "^haure",
		like = "haver",
		likevar = "full",
	},
}

local function skip_slot(base, slot, allow_overrides)
	if not allow_overrides and (base.basic_overrides[slot] or
		base.refl and base.basic_reflexive_only_overrides[slot]) then
		-- Skip any slots for which there are overrides.
		return true
	end

	if base.only3s and (slot:find("^pp_f") or slot:find("^pp_mp")) then
		-- diluviar, atardecer, neviscar; impersonal verbs have only masc sing pp
		return true
	end

	if not slot:find("[123]") then
		-- Don't skip non-personal slots.
		return false
	end

	if base.nofinite then
		return true
	end

	if (base.only3s or base.only3sp or base.only3p) and (slot:find("^imp_") or slot:find("^neg_imp_")) then
		return true
	end

	if base.only3s and not slot:find("3s") then
		-- diluviar, atardecer, neviscar
		return true
	end

	if base.only3sp and not slot:find("3[sp]") then
		-- atañer, concernir
		return true
	end

	if base.only3p and not slot:find("3p") then
		-- [[caer cuatro gotas]], [[caer chuzos de punta]], [[entrarle los siete males]]
		return true
	end

	return false
end

local function add_stem_ending(stem, ending)
	if ending == "" then
		return stem
	end
	if stem:find("#$") then -- remove final accent when adding a suffix
		stem = com.remove_accents((stem:gsub("#$", "")), "final syllable only")
	end
	return stem .. ending
end

local function process_stem(stem, fn)
	if stem:find("#$") then
		local stem_no_pound_sign = stem:match("^(.*)#$")
		return fn(stem_no_pound_sign) .. "#"
	else
		return fn(stem)
	end
end

-- Add the `stem` to the `ending` and apply any phonetic modifications. `is_full_word` indicates that we're creating
-- a "full word" not a stem, and turns on devoicing of final consonants. `dont_include_prefix` is used when creating
-- stems and indicates not to prepend the prefix in `base.prefix` to the result. `is_pres_sub_stressed` is used when
-- creating the pres_sub_stressed stem, to correctly handle both [[desaiguar]] and [[argüir]], whose respective
-- interactions between ü and i/ï are very tricky.
--
-- WARNING: This function is written very carefully; changes to it can easily have unintended consequences.
local function combine_stem_ending(base, stem, ending, is_full_word, dont_include_prefix, is_pres_sub_stressed)
	-- Include the prefix in the stem unless dont_include_prefix is given (used in construct_stems()), or the value of
	-- `stem` comes from a user-specified stem or form override.
	if not dont_include_prefix and not stem:find(IS_USER_STEM_OVERRIDE) and not stem:find(IS_USER_FORM_OVERRIDE) then
		stem = base.prefix .. stem
	end

	-- A * at the beginning of the ending is a signal to remove a stressed accent from the stem. This may feed any of
	-- the following rules.
	if ending:find("^%*") then
		ending = ending:gsub("^%*", "")
		stem = com.remove_accents(stem, "final syllable only")
	end

	-- If ending begins with s and stem ends in a sibilant, we need an e in between; cf. pres_2s 'apareixes' of
	-- [[aparèixer]], pres_2s 'torces' of [[tòrcer]], pres_2s 'fuges' of [[fugir]], pres_2s 'brunzes' of [[brunzir]].
	-- This may feed the next rule.
	if ending:find("^s") and rfind(stem, "[çjsxz]$") then
		ending = "e" .. ending
	end

	-- By default, stems are in their "back" (standalone) form. Before a front vowel, convert the final consonant to
	-- its "front" form so the pronunciation doesn't change.
	if rfind(ending, "^" .. front_vowel_c) then
		-- adequar -> adeqües
		-- enaiguar -> enaigües
		-- pegar -> pegues
		-- arranjar -> arranges
		-- marcar -> marques
		-- abraçar -> abraces
		stem = com.back_to_front(stem)
	end

	-- Ending beginning in -i after diphthong ending in V + i compresses the two i's into one (cf. pret_1s 'desmaí' and
	-- pres_sub_1s 'desmaï' of [[desmaiar]]). This rule doesn't apply after pseudo-vowel u in gu/qu; cf. pret_1s 'guií'
	-- of [[guiar]] and contrast pret_1s 'cruí' of [[cruiar]]. This may feed the next rule.
	if rfind(ending, "^[iíï]") and rfind(stem, V .. "i$") and not rfind(stem, "[gq][uü]i$") then
		stem = stem:gsub("i$", "")
	end

	-- If ending begins with i (not í), it must get a diaeresis after a true vowel (not gu/qu, cf. pres_1p 'delinquim'
	-- of [[delinquir]], not '#delinquïm'; also not a diphthong ending in u, cf. pres_sub_1s 'apreui' of [[apreuar]]
	-- not '#apreuï') to prevent the two merging into a diphthong. Note that ü -> u before ï, but to simplify things
	-- we leave the double umlauts in place and remove the first one during postprocessing, in fix_double_umlauts().
	-- Cf.:
	-- * impf_1s 'raïa' of [[raure]];
	-- * pres_sub_1s 'creï' of [[crear]];
	-- * pres_sub_1s 'associï' of [[associar]];
	-- * impf_1s 'cloïa' of [[cloure]];
	-- * pres_1p 'lluïm' of [[lluir]];
	-- * pres_1p 'arguïm' of [[argüir]].
	if ending:find("^i") and rfind(stem, "[aeiouü]$") and not stem:find("[aeiogq]u$") and
		-- Unstressed subjunctive endings of [[enaiguar]] remain without umlaut: enaigüi/enaigüis/enaigüin;
		-- but stressed endings of [[argüir]] that begin with 'i' do get an umlaut: arguït, impf. arguïa, including
		-- stressed subjunctive endings arguïm/arguïu. In both cases the ending is '-i' as part of the creation of
		-- the respective stems. There seems no way of distinguishing the two cases other than with a special flag.
		not (rfind(stem, "[gq]ü$") and ending == "i" and is_pres_sub_stressed) then
		ending = ending:gsub("^i", "ï")
	end

	local retval = add_stem_ending(stem, ending)
	if retval:find("#$") then -- remove final accent if no vowels in prefix
		retval = retval:gsub("#$", "")
		if not rfind(base.prefix, V) then
			retval = com.remove_accents(retval, "final syllable only")
		end
	end
	if is_full_word then
		local saw_is_user_form_override
		retval, saw_is_user_form_override = rsubb(retval, IS_USER_FORM_OVERRIDE, "")
		retval = retval:gsub(IS_USER_STEM_OVERRIDE, "")
		if not saw_is_user_form_override then
			-- Devoice final voiced obstruent (cf. pres_2s 'caps', pres_3s 'cap' of [[cabre]]). But not after a
			-- consonant (cf. pres_2s 'perds', pres_3s 'perd' of [[perdre]]), except for g -> c, which operates
			-- even after a consonant (pres_1s 'resolc' of [[resoldre]], pres_1s 'tinc' of [[tenir]]).
			retval = retval:gsub("g(s?)$", "c%1")
			retval = rsub(retval, "(" .. V .. ")([bdj])(s?)$", function(before, voiced, after)
				local devoice = {
					b = "p",
					d = "t",
					j = "ig", -- pres_3s 'fuj' of [[fugir]] -> 'fuig'
				}
				return before .. devoice[voiced] .. after
			end)
		end
	end

	return retval
end


local function add3(base, slot, stems, endings, footnotes, allow_overrides)
	if skip_slot(base, slot, allow_overrides) then
		return
	end

	local function do_combine_stem_ending(stem, ending)
		return combine_stem_ending(base, stem, ending, "is full word")
	end

	iut.add_forms(base.forms, slot, stems, endings, do_combine_stem_ending, nil, nil, footnotes)
end


local function insert_form(base, slot, form)
	if not skip_slot(base, slot) then
		iut.insert_form(base.forms, slot, form)
	end
end


local function insert_forms(base, slot, forms)
	if not skip_slot(base, slot) then
		iut.insert_forms(base.forms, slot, forms)
	end
end


local function add_single_stem_tense(base, slot_pref, stems, s1, s2, s3, p1, p2, p3)
	local function addit(slot, ending)
		add3(base, slot_pref .. "_" .. slot, stems, ending)
	end
	addit("1s", s1)
	addit("2s", s2)
	addit("3s", s3)
	addit("1p", p1)
	addit("2p", p2)
	addit("3p", p3)
end


local function map_general(stemforms, fn)
	return iut.map_forms(iut.convert_to_general_list_form(stemforms), fn)
end


local function flatmap_general(stemforms, fn)
	return iut.flatmap_forms(iut.convert_to_general_list_form(stemforms), fn)
end


-- Given a stem ending in a conjugation vowel -a/-e/-i/-ï, split into stem base and conjugation vowel, converting the
-- stem base to "back" form if the conjugation vowel is front (hence 'torce' of [[tòrcer]] splits into 'torç' and 'e',
-- and 'fugi' of [[fugir]] splits into 'fuj' and 'i').
local function split_conj_vowel(stem)
	local stem_base, conj_vowel = rmatch(stem, "^(.*)([aeiï])$")
	if not stem_base then
		error(("Internal error: Stem '%s' doesn't end in conjugation vowel a/e/i"):format(stem))
	end
	if conj_vowel == "ï" then
		-- To simplify handling of ï, convert to i. It will be converted back to ï as necessary in
		-- combine_stem_ending().
		conj_vowel = "i"
	end
	if rfind(conj_vowel, front_vowel_c) then
		stem_base = com.front_to_back(stem_base)
	end
	return stem_base, conj_vowel
end


local function construct_stems(base)
	base.output_stems = {}
	local stems = base.output_stems
	local bst = base.input_stems

	-- YUCK, see combine_stem_ending() for the necessity of is_pres_sub_stressed.
	local function combine(stem, ending, is_pres_sub_stressed)
		return combine_stem_ending(base, stem, ending, false, "dont include prefix", is_pres_sub_stressed)
	end

	stems.irreg = bst.irreg or bst.g_infix
	-- NOTE: Some stems end in a conjugation or similar vowel, specifically:
	-- * `stem` (ends in conjugation vowel -a/-e/-i);
	-- * `stressed_stem` (likewise);
	-- * `unstressed_stem` (likewise);
	-- * `pres_unstressed` (which assumes the form of the gerund minus the -nt; note that `pres_stressed` does *NOT*
	--   end in a conjugation vowel, but assumes the stem form; the value of pres_3s will be derived by adding -a for
	--   -ar verbs and otherwise adding an -e prop vowel when required, as in [[cobrir]], and otherwise adding no
	--   vowel);
	-- * `pres_sub_stressed` (which assumes the form of pres_sub_3s and hence usually ends in -i, occasionally -a);
	-- * `pres_sub_unstressed` (which assumes the form of pres_sub_1p minus the -m, hence ends in -e or -i).

	-- Save stem for use in add_categories_and_annotation() for determining the conjugation class.
	stems.stem = bst.stem or base.stem
	local eix_infix_stem
	if base.conj_vowel == "i" then
		-- Save eix_infix value for use in add_categories_and_annotation() for determining whether consonant
		-- alternations exist.
		stems.eix_infix = bst.eix_infix or bst.g_infix and "-" or "+"
		eix_infix_stem = flatmap_general(stems.eix_infix, function(form)
			if form == "+" then
				return map_general(stems.stem, function(form)
					local stem_base, conj_vowel = split_conj_vowel(form)
					return combine(stem_base, "eixe")
				end)
			elseif form == "-" then
				return stems.stem
			else
				return form
			end
		end)
	end

	local stressed_stem = bst.stressed_stem or eix_infix_stem or stems.stem
	local unstressed_stem = bst.unstressed_stem or stems.stem

	-- Add the 'g' that is characteristic of g-infix verbs. We remove a stem-final v, e.g. [[beure]] with stem 'beve'
	-- becomes 'beg'.
	local function add_g(stemforms)
		return map_general(stemforms, function(form)
			local stem_base, conj_vowel = split_conj_vowel(form)
			stem_base = stem_base:gsub("v$", "")
			return combine(stem_base, "g")
		end)
	end
	-- Add the 'u' of the pres_3s that is characteristic of g-infix verbs (and conjugation vowel 'e', later removed).
	-- We remove a stem-final v, as well as i as part of a diphthong, e.g. [[beure]] with stem 'beve' becomes 'beue'
	-- and [[veure]] with stem 'veie' becomes 'veue' (but [[riure]] with stem 'rie' becomes 'riue' not '#rue'). We
	-- don't add -u after a consonant, e.g. [[doldre]] with stem 'dole' becomes 'dole' not '#dolue'.
	local function add_u(stemforms)
		return map_general(stemforms, function(form)
			local stem_base, conj_vowel = split_conj_vowel(form)
			if stem_base:find("v$") then
				stem_base = stem_base:gsub("v$", "")
			else
				stem_base = rsub(stem_base, "(" .. V .. ")i$", "%1")
			end
			-- Add u after vowel but not after another u, so we get pres_3p 'duen' of [[dur]] not '#duuen'.
			if rfind(stem_base, V .. "$") and not stem_base:find("u$") then
				return combine(stem_base, "u")
			else
				return stem_base
			end
		end)
	end

	local stressed_g_infix, unstressed_g_infix, g_infix_pres_stressed
	if bst.g_infix then
		local function flatmap_g_infix(default)
			return flatmap_general(bst.g_infix, function(form)
				if form == "+" then
					return default
				else
					return form
				end
			end)
		end

		stressed_g_infix = flatmap_g_infix(add_g(stressed_stem))
		unstressed_g_infix = flatmap_g_infix(add_g(unstressed_stem))
		g_infix_pres_stressed = add_u(stressed_stem)
	end

	stems.pres_unstressed = bst.pres_unstressed or unstressed_stem
	stems.pres_stressed =
		-- If no_pres_stressed given, pres_stressed stem should be empty so no forms are generated.
		base.no_pres_stressed and {} or
		bst.pres_stressed or
		g_infix_pres_stressed or
		map_general(stressed_stem, function(form)
			local stem_base, conj_vowel = split_conj_vowel(form)
			return stem_base
		end)
	stems.pres1s =
		-- If no_pres_stressed given, pres1s stem should be empty so no forms are generated.
		base.no_pres_stressed and {} or
		stressed_g_infix or
		map_general(stems.pres_stressed, function(form)
			return combine(form, "o")
		end)
	stems.pres3s =
		-- If no_pres_stressed given, pres3s stem should be empty so no forms are generated.
		base.no_pres_stressed and {} or
		bst.pres3s or
		map_general(stems.pres_stressed, function(form)
			if base.conj_vowel == "a" then
				return combine(form, "a")
			elseif rfind(form, C .. "[lr]$") and not rfind(form, V .. "ll$") then
				return combine(form, "e")
			else
				return form
			end
		end)
	stems.pres3p =
		-- If no_pres_stressed given, pres3p stem should be empty so no forms are generated.
		base.no_pres_stressed and {} or
		map_general(stems.pres_stressed, function(form)
			return combine(form, "en")
		end)

	local function compute_impf_stem(with_accent)
		return map_general(stems.pres_unstressed, function(form)
			local stem_base, conj_vowel = split_conj_vowel(form)
			if conj_vowel == "a" then
				return combine(stem_base, with_accent and "àv" or "av")
			elseif stem_base:find("i#?$") then
				form = form:gsub("i#?$", "")
				return combine(rmatch(stem_base, "^(.-)" .. V .. "*$"), with_accent and "èi" or "ei")
			else
				return combine(stem_base, with_accent and "í" or "i") -- i -> ï after a vowel
			end
		end)
	end
	stems.impf1 = bst.impf1 or compute_impf_stem(false)
	stems.impf2 = bst.impf2 or compute_impf_stem(true)
	stems.pret = bst.pret or
		unstressed_g_infix and map_general(unstressed_g_infix,
			function(form) return combine(form, "é") end
		) or
		map_general(unstressed_stem, function(form)
			local accent_conj_vowel = {
				a = "à",
				e = "é",
				i = "í",
			}
			local stem_base, conj_vowel = split_conj_vowel(form)
			return combine(stem_base, accent_conj_vowel[conj_vowel])
		end)
	stems.fut = bst.fut or base.inf_stem
	stems.cond = bst.cond or map_general(stems.fut, function(form) return combine(form, "í") end)
	stems.pres_sub_stressed = bst.pres_sub_stressed or
		stressed_g_infix and map_general(stressed_g_infix, function(form) return combine(form, "i") end) or
		map_general(stressed_stem, function(form)
			local stem_base, conj_vowel = split_conj_vowel(form)
			return combine(stem_base, "i", "is pres_sub_stressed")
		end)
	stems.pres_sub_unstressed = bst.pres_sub_unstressed or
		unstressed_g_infix and map_general(unstressed_g_infix, function(form) return combine(form, "e") end) or
		map_general(unstressed_stem, function(form)
			local stem_base, conj_vowel = split_conj_vowel(form)
			return combine(stem_base, conj_vowel == "i" and conj_vowel or "e")
		end)
	stems.impf_sub = bst.impf_sub or map_general(stems.pret, function(form)
		local stem_base = rmatch(form, "^(.*)à$") -- already in "back" form, no need to convert
		if stem_base then
			return combine(stem_base, "é")
		else
			return form
		end
	end)

	stems.pp = bst.pp or
		unstressed_g_infix and map_general(unstressed_g_infix,
			function(form) return combine(form, "ud") end
		) or
		map_general(unstressed_stem, function(form)
			local stem_base, conj_vowel = split_conj_vowel(form)
			-- use combine() so we get 'abduïd' from 'abdu-' of [[abduir]], 'seguid' from 'seg-' from [[seguir]], etc.
			return combine(stem_base, (conj_vowel == "e" and "u" or conj_vowel) .. "d")
		end)
end


local function a_to_e(base, stems, suffix)
	return map_general(stems, function(form)
		local stem_base = form:match("^(.-)a$")
		if stem_base then
			suffix = "e" .. suffix
		else
			stem_base = form
		end
		return combine_stem_ending(base, stem_base, suffix, "is full word")
	end)
end


local function add_present_indic(base)
	local stems = base.output_stems
	local function addit(slot, stems, ending)
		add3(base, "pres_" .. slot, stems, ending)
	end

	addit("1s", stems.pres1s, "")
	insert_forms(base, "pres_2s", a_to_e(base, stems.pres3s, "s"))
	addit("3s", stems.pres3s, "")
	insert_forms(base, "pres_1p", a_to_e(base, stems.pres_unstressed, "m"))
	insert_forms(base, "pres_2p", a_to_e(base, stems.pres_unstressed, "u"))
	addit("3p", stems.pres3p, "")
end


local function add_present_subj(base)
	local stems = base.output_stems
	local function addit(slot, stems, ending)
		add3(base, "pres_sub_" .. slot, stems, ending)
	end

	-- Regular -ar verb: [[amar]]: ami, amis, ami, amem, ameu, amin
	-- Regular -re verb: [[batre]]: bati, batis, bati, batem, bateu, batin (same as -ar verb)
	-- Regular -ir verb, no -eix- infix: [[dormir]]: dormi, dormis, dormi, dormim, dormiu, dormin
	-- Regular -ir verb, -eix- infix: [[imprimir]]: imprimeixi, imprimeixis, imprimeixi, imprimim, imprimiu, imprimeixin
	-- Stem changing in 123s/3p vs. 12p:
	-- * -eix- infix (-eix- in all stressed forms: 123s/3p of pres ind/sub, 2s imp)
	-- * [[collir]]: culli, cullis, culli, collim, colliu, cullin (cull- in all stressed forms)
	-- * [[cabre]]: càpiga, càpigues, càpiga, capiguem, capigueu, càpiguen (also different endings)

	addit("1s", stems.pres_sub_stressed, "")
	insert_forms(base, "pres_sub_2s", a_to_e(base, stems.pres_sub_stressed, "s"))
	addit("3s", stems.pres_sub_stressed, "")
	addit("1p", stems.pres_sub_unstressed, "m")
	addit("2p", stems.pres_sub_unstressed, "u")
	insert_forms(base, "pres_sub_3p", a_to_e(base, stems.pres_sub_stressed, "n"))
end


local function add_finite_non_present(base)
	local stems = base.output_stems
	local function add_tense(slot, stem, s1, s2, s3, p1, p2, p3)
		add_single_stem_tense(base, slot, stem, s1, s2, s3, p1, p2, p3)
	end

	add_tense("impf", stems.impf1, "a", "es", "a", nil, nil, "en")
	add_tense("impf", stems.impf2, nil, nil, nil, "em", "eu", nil)

	-- pret_1s ends in -í regardless of the normal vowel of the stem.
	insert_forms(base, "pret_1s", map_general(stems.pret, function(form)
		local stem_base, conj_vowel = rmatch(form, "^(.*)(" .. V .. ")$")
		if not stem_base then
			error(("Internal error: Preterite stem '%s' doesn't end in vowel"):format(form))
		end
		if rfind(conj_vowel, front_vowel_c) then
			stem_base = com.front_to_back(stem_base)
		end
		-- Use combine_stem_ending() to handle back-to-front conversions, e.g. pegà -> peguí for [[pegar]] and ensure
		-- that the prefix gets added.
		return combine_stem_ending(base, stem_base, "í", "is full word") end))
	-- * at the beginning of the ending means to remove an accent from the last vowel of the preterite stem.
	add_tense("pret", stems.pret, nil, "*res", "", "rem", "reu", "*ren")

	-- * at the beginning of the ending means to remove an accent from the last vowel of the imperfect subjunctive stem.
	add_tense("impf_sub", stems.impf_sub, "s", "*ssis", "s", "ssim", "ssiu", "*ssin")
	add_tense("fut", stems.fut, "é", "às", "à", "em", "eu", "an")
	add_tense("cond", stems.cond, "*a", "*es", "*a", "em", "eu", "*en")
end


local function add_non_finite_forms(base)
	local stems = base.output_stems
	local function addit(slot, stems, ending, footnotes)
		add3(base, slot, stems, ending, footnotes)
	end

	insert_form(base, "infinitive", {form = base.orig_verb})
	-- Also insert "infinitive + reflexive pronoun" combinations if we're handling a reflexive verb. See comment below
	-- for "gerund + reflexive pronoun" combinations.
	if base.refl then
		for _, persnum in ipairs(person_number_list) do
			insert_form(base, "infinitive_" .. persnum, {form = base.orig_verb})
		end
	end
	-- Gerunds don't have an umlaut over the i in cases like 'abduint' of 'abduir' (not '#abduïnt').
	local pres_unstressed_no_umlaut = map_general(stems.pres_unstressed, function(form)
		return rsub(form, "ï$", "i")
	end)
	addit("gerund", pres_unstressed_no_umlaut, "nt")
	-- Also insert "gerund + reflexive pronoun" combinations if we're handling a reflexive verb. We insert exactly the
	-- same form as for the bare gerund; later on in add_reflexive_or_fixed_clitic_to_forms(), we add the appropriate
	-- clitic pronouns. It's important not to do this for non-reflexive verbs, because in that case, the clitic
	-- pronouns won't be added, and {{ca-verb form of}} will wrongly consider all these combinations as possible
	-- inflections of the bare gerund. Thanks to [[User:JeffDoozan]] for this bug fix.
    if base.refl then
		for _, persnum in ipairs(person_number_list) do
			addit("gerund_" .. persnum, pres_unstressed_no_umlaut, "nt")
		end
	end
	addit("pp_ms", stems.pp, "")
	if not base.pp_inv then
		addit("pp_fs", stems.pp, "a")
		-- make_plural() handles the complexities of e.g. 'vist' of [[veure]] -> 'vistos'/'vists' and 'romàs' of
		-- [[romandre]] -> 'romasos'. We need to use flatmap_general() because make_plural() may return more than one
		-- plural, and we need to use map_general() on the result, applying combine_stem_ending(), to ensure that
		-- prefixes get properly added and plurals like 'amads' of stem 'amad' of [[amar]] get converted to 'amats'.
		insert_forms(base, "pp_mp", map_general(flatmap_general(stems.pp, function(form)
			-- Remove any # indicating that an accent will be dropped; it will be dropped in any case by make_plural().
			form = form:gsub("#$", "")
			return com.make_plural(form, "m")
		end), function(form)
			return combine_stem_ending(base, form, "", "is full word")
		end))
		addit("pp_fp", stems.pp, "es")
	end
end


local function add_imperatives(base)
	if base.noimp then
		return
	end
	-- Copy pres3s to imperative since they are almost always the same.
	insert_forms(base, "imp_2s", iut.map_forms(base.forms.pres_3s, function(form) return form end))
	-- Copy pres2p to imperative plural since they are almost always the same.
	insert_forms(base, "imp_2p", iut.map_forms(base.forms.pres_2p, function(form) return form end))
	-- Copy subjunctives to imperatives.
	for _, persnum in ipairs({"3s", "1p", "3p"}) do
		local from = "pres_sub_" .. persnum
		local to = "imp_" .. persnum
		insert_forms(base, to, iut.map_forms(base.forms[from], function(form) return form end))
	end
end


local function fix_double_umlauts(base)
	for slot, forms in pairs(base.forms) do
		for _, form in ipairs(forms) do
			form.form = form.form:gsub("üï", "uï")
		end
	end
end


local function process_slot_overrides(base, filter_slot, reflexive_only)
	local overrides = reflexive_only and base.basic_reflexive_only_overrides or base.basic_overrides
	for slot, forms in pairs(overrides) do
		if not filter_slot or filter_slot(slot) then
			add3(base, slot, forms, "", nil, "allow overrides")
		end
	end
end


local function link_clitic(clitic)
	return (clitic:gsub("([^ %-]+)", "[[%1]]"))
end

-- Prefix `form` with `clitic`, adding fixed text `between` between them. Add links as appropriate unless the user
-- requested no links. Check whether form already has brackets (as will be the case if the form has a fixed clitic).
local function prefix_clitic_to_form(base, clitic, between, form)
	if base.alternant_multiword_spec.args.noautolinkverb then
		return clitic .. between .. form
	else
		local clitic_pref = link_clitic(clitic) .. between
		if form:find("%[%[") then
			return clitic_pref .. form
		else
			return clitic_pref .. "[[" .. form .. "]]"
		end
	end
end


-- Suffix `form` with `clitic`. Add links as appropriate unless the user requested no links. Check whether form already
-- has brackets (as will be the case if the form has a fixed clitic).
local function suffix_clitic_to_form(base, clitic, form)
	local autolink = not base.alternant_multiword_spec.args.noautolinkverb
	if base.alternant_multiword_spec.args.noautolinkverb then
		return form .. clitic
	else
		local clitic_suf = link_clitic(clitic)
		if form:find("%[%[") then
			return form .. clitic_suf
		else
			return "[[" .. form .. "]]" .. clitic_suf
		end
	end
end


-- Add a reflexive pronoun or fixed clitic (FIXME: not working), as appropriate to the base forms that were generated.
-- `do_joined` means to do only the forms where the pronoun is joined to the end of the form; otherwise, do only the
-- forms where it is not joined and precedes the form.
local function add_reflexive_or_fixed_clitic_to_forms(base, do_reflexive, do_joined)
	for _, slotaccel in ipairs(base.alternant_multiword_spec.verb_slots_basic) do
		local slot, accel = unpack(slotaccel)
		local persnum
		if slot:find("[123]") then
			persnum = slot:match("^.*_(.-)$")
		else
			persnum = "3s"
		end
		local function get_proclitic(form)
			--if not do_reflexive then
			--	return base.clitic
			if form:find("^[aeiouh]") then
				return proclitic_elided_person_number_to_reflexive_pronoun[persnum]
			else
				return proclitic_non_elided_person_number_to_reflexive_pronoun[persnum]
			end
		end
		local function get_enclitic(form)
			--if not do_reflexive then
			--	return base.clitic
			if rfind(form, C .. "$") or rfind(form, V .. "[iu]$") and not form:find("[gq]ui$") then
				return enclitic_non_elided_person_number_to_reflexive_pronoun[persnum]
			else
				return enclitic_elided_person_number_to_reflexive_pronoun[persnum]
			end
		end

		if base.forms[slot] then
			if do_reflexive and slot:find("^pp_") or slot == "infinitive_linked" then
				-- do nothing with reflexive past participles or with infinitive linked (handled at the end)
			elseif slot:find("^neg_imp_") then
				error("Internal error: Should not have forms set for negative imperative at this stage")
			else
				local slot_has_suffixed_clitic = slot:find("infinitive") or slot:find("gerund") or slot:find("^imp_")
				-- Maybe generate non-reflexive parts and separated syntactic variants for use in
				-- {{ca-verb form of}}. See comment in add_slots() above `need_special_verb_form_of_slots`.
				-- Check for do_joined so we only run this code once.
				if do_reflexive and do_joined and base.alternant_multiword_spec.source_template == "ca-verb form of" and
					-- Skip personal variants of infinitives and gerunds so we don't think [[arrependendo]] is a
					-- non-reflexive equivalent of [[arrependendo-me]].
					not slot:find("infinitive_") and not slot:find("gerund_") then
					-- Clone the forms because we will be destructively modifying them just below, adding the reflexive
					-- pronoun.
					insert_forms(base, slot .. "_non_reflexive", mw.clone(base.forms[slot]))
					if slot_has_suffixed_clitic then
						insert_forms(base, slot .. "_variant", iut.map_forms(base.forms[slot], function(form)
							return prefix_clitic_to_form(base, get_proclitic(form), "... ", form)
						end))
					end
				end
				if slot_has_suffixed_clitic then
					if do_joined then
						-- Add clitic after form.
						for _, form in ipairs(base.forms[slot]) do
							form.form = suffix_clitic_to_form(base, get_enclitic(form.form), form.form)
						end
					end
				elseif not do_joined then
					-- Add clitic before form.
					for _, form in ipairs(base.forms[slot]) do
						form.form = prefix_clitic_to_form(base, get_proclitic(form.form), "", form.form)
					end
				end
			end
		end
	end
end


local function handle_infinitive_linked(base)
	-- Compute linked versions of potential lemma slots, for use in {{ca-verb}}.
	-- We substitute the original lemma (before removing links) for forms that
	-- are the same as the lemma, if the original lemma has links.
	for _, slot in ipairs({"infinitive"}) do
		insert_forms(base, slot .. "_linked", iut.map_forms(base.forms[slot], function(form)
			if form == base.lemma and rfind(base.linked_lemma, "%[%[") then
				return base.linked_lemma
			else
				return form
			end
		end))
	end
end


local function generate_negative_imperatives(base)
	if base.noimp then
		return
	end
	-- Copy subjunctives to negative imperatives, preceded by "no".
	for _, persnum in ipairs(neg_imp_person_number_list) do
		local from = "pres_sub_" .. persnum
		local to = "neg_imp_" .. persnum
		insert_forms(base, to, iut.map_forms(base.forms[from], function(form)
			if base.alternant_multiword_spec.args.noautolinkverb then
				return "no " .. form
			elseif form:find("%[%[") then
				-- already linked, e.g. when reflexive
				return "[[no]] " .. form
			else
				return "[[no]] [[" .. form .. "]]"
			end
		end))
	end
end


-- Process specs given by the user using 'addnote[SLOTSPEC][FOOTNOTE][FOOTNOTE][...]'.
local function process_addnote_specs(base)
	for _, spec in ipairs(base.addnote_specs) do
		for _, slot_spec in ipairs(spec.slot_specs) do
			slot_spec = "^" .. slot_spec .. "$"
			for slot, forms in pairs(base.forms) do
				if rfind(slot, slot_spec) then
					-- To save on memory, side-effect the existing forms.
					for _, form in ipairs(forms) do
						form.footnotes = iut.combine_footnotes(form.footnotes, spec.footnotes)
					end
				end
			end
		end
	end
end


local function add_missing_links_to_forms(base)
	-- Any forms without links should get them now. Redundant ones will be stripped later.
	for slot, forms in pairs(base.forms) do
		for _, form in ipairs(forms) do
			if not form.form:find("%[%[") then
				form.form = "[[" .. form.form .. "]]"
			end
		end
	end
end


local function conjugate_verb(base)
	construct_stems(base)
	add_present_indic(base)
	add_present_subj(base)
	add_finite_non_present(base)
	add_non_finite_forms(base)
	fix_double_umlauts(base)
	-- do non-reflexive non-imperative slot overrides
	process_slot_overrides(base, function(slot)
		return not slot:find("^imp_") and not slot:find("^neg_imp_")
	end)
	-- This should happen after process_slot_overrides() in case a derived slot is based on an override
	-- (as with the imp_3s of [[dar]], [[estar]]).
	add_imperatives(base)
	-- do non-reflexive positive imperative slot overrides
	process_slot_overrides(base, function(slot)
		return slot:find("^imp_")
	end)
	-- We need to add joined reflexives, then joined and non-joined clitics, then non-joined reflexives, so we get
	-- [[arrepéndete]] but [[no]] [[te]] [[arrependas]].
	if base.refl then
		add_reflexive_or_fixed_clitic_to_forms(base, "do reflexive", "do joined")
		process_slot_overrides(base, nil, "do reflexive") -- do reflexive-only slot overrides
		add_reflexive_or_fixed_clitic_to_forms(base, "do reflexive", false)
	end
	-- This should happen after add_reflexive_or_fixed_clitic_to_forms() so negative imperatives get the reflexive pronoun
	-- and clitic in them.
	generate_negative_imperatives(base)
	-- do non-reflexive negative imperative slot overrides
	-- FIXME: What about reflexive negative imperatives?
	process_slot_overrides(base, function(slot)
		return slot:find("^neg_imp_")
	end)
	-- This should happen before add_missing_links_to_forms() so that the comparison `form == base.lemma`
	-- in handle_infinitive_linked() works correctly and compares unlinked forms to unlinked forms.
	handle_infinitive_linked(base)
	process_addnote_specs(base)
	if not base.alternant_multiword_spec.args.noautolinkverb then
		add_missing_links_to_forms(base)
	end
end


local function parse_indicator_spec(angle_bracket_spec)
	-- Store the original angle bracket spec so we can reconstruct the overall conj spec with the lemma(s) in them.
	local base = {
		angle_bracket_spec = angle_bracket_spec,
		user_basic_overrides = {},
		user_stems = {},
		addnote_specs = {},
	}
	local function parse_err(msg)
		error(msg .. ": " .. angle_bracket_spec)
	end
	local function fetch_footnotes(separated_group)
		local footnotes
		for j = 2, #separated_group - 1, 2 do
			if separated_group[j + 1] ~= "" then
				parse_err("Extraneous text after bracketed footnotes: '" .. table.concat(separated_group) .. "'")
			end
			if not footnotes then
				footnotes = {}
			end
			table.insert(footnotes, separated_group[j])
		end
		return footnotes
	end

	local inside = angle_bracket_spec:match("^<(.*)>$")
	assert(inside)
	if inside == "" then
		return base
	end
	local segments = iut.parse_balanced_segment_run(inside, "[", "]")
	local dot_separated_groups = iut.split_alternating_runs(segments, "%.")
	for i, dot_separated_group in ipairs(dot_separated_groups) do
		local first_element = dot_separated_group[1]
		if first_element == "addnote" then
			local spec_and_footnotes = fetch_footnotes(dot_separated_group)
			if #spec_and_footnotes < 2 then
				parse_err("Spec with 'addnote' should be of the form 'addnote[SLOTSPEC][FOOTNOTE][FOOTNOTE][...]'")
			end
			local slot_spec = table.remove(spec_and_footnotes, 1)
			local slot_spec_inside = rmatch(slot_spec, "^%[(.*)%]$")
			if not slot_spec_inside then
				parse_err("Internal error: slot_spec " .. slot_spec .. " should be surrounded with brackets")
			end
			local slot_specs = rsplit(slot_spec_inside, ",")
			-- FIXME: Here, [[Module:it-verb]] called strip_spaces(). Generally we don't do this. Should we?
			table.insert(base.addnote_specs, {slot_specs = slot_specs, footnotes = spec_and_footnotes})
		elseif indicator_flags[first_element] then
			if #dot_separated_group > 1 then
				parse_err("No footnotes allowed with '" .. first_element .. "' spec")
			end
			if base[first_element] then
				parse_err("Spec '" .. first_element .. "' specified twice")
			end
			base[first_element] = true
		elseif first_element:find("^var:") then
			if #dot_separated_group > 1 then
				parse_err(("Can't attach footnotes to 'var:' spec '%s'"):format(first_element))
			end
			base.var = first_element:match("^var:(.*)$")
		elseif first_element:find(":") then
			local colon_separated_groups = iut.split_alternating_runs(dot_separated_group, "%s*:%s*")
			local first_element = colon_separated_groups[1][1]
			if #colon_separated_groups[1] > 1 then
				parse_err("Can't attach footnotes directly to '" .. first_element .. "' spec; attach them to the " ..
					"colon-separated values following the initial colon")
			end
			if overridable_stems[first_element] then
				if base.user_stems[first_element] then
					parse_err("Overridable stem '" .. first_element .. "' specified twice")
				end
				table.remove(colon_separated_groups, 1)
				base.user_stems[first_element] = overridable_stems[first_element](colon_separated_groups,
					{prefix = first_element, base = base, parse_err = parse_err, fetch_footnotes = fetch_footnotes})
			else -- assume a basic override; we validate further later when the possible slots are available
				if base.user_basic_overrides[first_element] then
					parse_err("Basic override '" .. first_element .. "' specified twice")
				end
				table.remove(colon_separated_groups, 1)
				base.user_basic_overrides[first_element] = allow_multiple_values_for_override(colon_separated_groups,
					{prefix = first_element, base = base, parse_err = parse_err, fetch_footnotes = fetch_footnotes},
					"is form override")
			end
		else
			parse_err("Unrecognized spec '" .. first_element .. "'")
		end
	end

	return base
end


-- Normalize all lemmas, substituting the pagename for blank lemmas and adding links to multiword lemmas.
local function normalize_all_lemmas(alternant_multiword_spec, head)

	-- (1) Add links to all before and after text. Remember the original text so we can reconstruct the verb spec later.
	if not alternant_multiword_spec.args.noautolinktext then
		iut.add_links_to_before_and_after_text(alternant_multiword_spec, "remember original")
	end

	-- (2) Remove any links from the lemma, but remember the original form so we can use it below in the 'lemma_linked'
	-- form.
	iut.map_word_specs(alternant_multiword_spec, function(base)
		if base.lemma == "" then
			base.lemma = head
		end

		base.user_specified_lemma = base.lemma

		base.lemma = m_links.remove_links(base.lemma)
		local refl_verb = base.lemma
		local verb, refl = rmatch(refl_verb, "^(.-)%-(se)$")
		if not verb then
			verb, refl = rmatch(refl_verb, "^(.-)('s)$")
		end
		if not verb then
			verb, refl = refl_verb, nil
		end
		base.user_specified_verb = verb
		base.refl = refl
		base.verb = base.user_specified_verb

		local linked_lemma
		if alternant_multiword_spec.args.noautolinkverb or base.user_specified_lemma:find("%[%[") then
			linked_lemma = base.user_specified_lemma
		elseif base.refl then
			-- Reconstruct the linked lemma with separate links around base verb, reflexive pronoun and clitic.
			linked_lemma = base.user_specified_verb == base.verb and "[[" .. base.user_specified_verb .. "]]" or
				"[[" .. base.verb .. "|" .. base.user_specified_verb .. "]]"
			linked_lemma = linked_lemma .. (refl and "-[[" .. refl .. "]]" or "")
		else
			-- Add links to the lemma so the user doesn't specifically need to, since we preserve links in multiword
			-- lemmas and include links in non-lemma forms rather than allowing the entire form to be a link.
			linked_lemma = iut.add_links(base.user_specified_lemma)
		end
		base.linked_lemma = linked_lemma
	end)
end


local function detect_indicator_spec(base)
	if (base.only3s and 1 or 0) + (base.only3sp and 1 or 0) + (base.only3p and 1 or 0) > 1 then
		error("Only one of 'only3s', 'only3sp' and 'only3p' can be specified")
	end

	base.forms = {}
	base.input_stems = {}
	base.basic_overrides = {}
	base.basic_reflexive_only_overrides = {}
	base.orig_verb = base.verb -- in case of a 'like = "..."' redirect
	if not base.no_built_in then
		local function match_built_in_spec(verb, built_in_spec)
			local prefix, non_prefixed_verb
			if type(built_in_spec.match) == "function" then
				prefix, non_prefixed_verb = built_in_spec.match(verb)
			elseif built_in_spec.match:find("^%^") and rsub(built_in_spec.match, "^%^", "") == verb then
				-- begins with ^, for exact match, and matches
				prefix, non_prefixed_verb = "", verb
			else
				prefix, non_prefixed_verb = rmatch(verb, "^(.*)(" .. built_in_spec.match .. ")$")
			end
			return prefix, non_prefixed_verb
		end

		local function find_built_in(verb, var)
			for _, built_in_spec in ipairs(built_in_conjugations) do
				local prefix, non_prefixed_verb = match_built_in_spec(verb, built_in_spec)
				if prefix then
					if not built_in_spec.var then
						if var then
							error(("Can't specify a variant spec 'var:%s' with verb '%s'"):format(var, verb))
						end
						return prefix, non_prefixed_verb, built_in_spec
					elseif not var then
						local possible_vars = {}
						for _, built_in_spec in ipairs(built_in_conjugations) do
							local prefix, non_prefixed_verb = match_built_in_spec(verb, built_in_spec)
							if prefix then
								table.insert(possible_vars, built_in_spec.var)
							end
						end
						error(("For verb '%s', must specify a variant using 'var:...'; possible values are %s"):format(
							verb, table.concat(possible_vars, ", ")))
					elseif built_in_spec.var == var then
						return prefix, non_prefixed_verb, built_in_spec
					end
				end
			end
			return nil
		end

		local prefix, non_prefixed_verb, built_in_spec = find_built_in(base.verb, base.var)
		if prefix then
			-- we found a built-in verb
			if built_in_spec.like then
				-- we found a redirect to another verb that has the same conjugation, just a different infinitive
				base.verb = prefix .. built_in_spec.like
				local new_prefix, new_non_prefixed_verb, new_built_in_spec = find_built_in(base.verb, built_in_spec.likevar)
				if new_prefix then
					-- redirected to another built-in verb
					base.prefix = new_prefix
					base.non_prefixed_verb = new_non_prefixed_verb
					built_in_spec = new_built_in_spec
				else
					built_in_spec = nil
				end
			else
				base.prefix = prefix
				base.non_prefixed_verb = non_prefixed_verb
			end
		end

		if built_in_spec then
			-- we found a built-in verb, possibly redirecting to another built-in verb
			for stem, forms in pairs(built_in_spec.forms) do
				if type(forms) == "function" then
					forms = forms(base, base.prefix)
				end
				if stem:find("^refl_") then
					stem = stem:gsub("^refl_", "")
					if not base.alternant_multiword_spec.verb_slots_basic_map[stem] then
						error("Internal error: setting for 'refl_" .. stem .. "' does not refer to a basic verb slot")
					end
					base.basic_reflexive_only_overrides[stem] = forms
				elseif base.alternant_multiword_spec.verb_slots_basic_map[stem] then
					-- an individual form override of a basic form
					base.basic_overrides[stem] = forms
				else
					base.input_stems[stem] = forms
				end
			end
		end
	end

	-- Override built-in-verb stems and overrides with user-specified ones.
	for stem, values in pairs(base.user_stems) do
		base.input_stems[stem] = values
	end
	for override, values in pairs(base.user_basic_overrides) do
		if not base.alternant_multiword_spec.verb_slots_basic_map[override] then
			error("Unrecognized override '" .. override .. "': " .. base.angle_bracket_spec)
		end
		base.basic_overrides[override] = values
	end

	base.prefix = base.prefix or ""
	base.non_prefixed_verb = base.non_prefixed_verb or base.verb
	local inf_stem, suffix = rmatch(base.non_prefixed_verb, "^(.*)(re)$")
	if not inf_stem then
		inf_stem, suffix = rmatch(base.non_prefixed_verb, "^(.*)([aeiu]r)$")
	end
	if not inf_stem then
		error("Unrecognized infinitive: " .. base.verb)
	end
	-- Remove accents from e.g. [[parèixer]], [[córrer]].
	inf_stem = com.remove_accents(inf_stem)
	-- Save full infinitive stem for use in future and conditional.
	base.inf_stem = (inf_stem .. suffix):gsub("e$", "")
	local stem = inf_stem
	if suffix == "re" then
		-- verbs in -ldre, -ndre have stem without the d
		stem = stem:gsub("([ln])d$", "%1")
	elseif suffix == "ur" then
		stem = stem .. "u"
	end
	base.conj_vowel = (suffix == "re" or suffix == "ur") and "e" or suffix:gsub("r$", "")
	-- If the stem is followed by a front vowel, convert it to its "back" form before calling combine_stem_ending(),
	-- which expects the "back" form of the stem and may convert it back to the "front" form. Don't do this conversion
	-- for ï so we leave [[arguïr]] (underlyingly 'argüïr') as 'argu' ("back" form), which becomes 'argü' ("front" form)
	-- before front vowel ï and we end up with base.stem containing the underlying form 'argüï'. We remove the first of
	-- two umlauts in a row in a postprocessing step (fix_double_umlauts()).
	if rfind(suffix, "^[ei]") then
		stem = com.front_to_back(stem)
	end
	-- Use combine_stem_ending() so we get ï if necessary.
	base.stem = combine_stem_ending(base, stem, base.conj_vowel, false, "dont include prefix")

	-- Propagate built-in-verb indicator flags to `base` and combine with user-specified flags.
	for indicator_flag, _ in pairs(indicator_flags) do
		base[indicator_flag] = base[indicator_flag] or base.input_stems[indicator_flag]
	end
end


local function detect_all_indicator_specs(alternant_multiword_spec)
	-- Propagate some settings up; some are used internally, others by [[Module:pt-headword]].
	iut.map_word_specs(alternant_multiword_spec, function(base)
		-- Internal indicator flags. Do these before calling detect_indicator_spec() because add_slots() uses them.
		for  _, prop in ipairs { "refl", "clitic" } do
			if base[prop] then
				alternant_multiword_spec[prop] = true
			end
		end
		base.alternant_multiword_spec = alternant_multiword_spec
	end)

	add_slots(alternant_multiword_spec)

	iut.map_word_specs(alternant_multiword_spec, function(base)
		detect_indicator_spec(base)
		-- User-specified indicator flags. Do these after calling detect_indicator_spec() because the latter may set these
		-- indicators for built-in verbs.
		for prop, _ in pairs(indicator_flags) do
			if base[prop] then
				alternant_multiword_spec[prop] = true
			end
		end
	end)
end


local function add_categories_and_annotation(alternant_multiword_spec, base, multiword_lemma)
	local function insert_ann(anntype, value)
		m_table.insertIfNot(alternant_multiword_spec.annotation[anntype], value)
	end

	local function insert_cat(cat, also_when_multiword)
		-- Don't place multiword terms in categories like 'Catalan verbs ending in -ar' to avoid spamming the
		-- categories with such terms.
		if also_when_multiword or not multiword_lemma then
			m_table.insertIfNot(alternant_multiword_spec.categories, "Catalan " .. cat)
		end
	end

	if check_for_red_links and alternant_multiword_spec.source_template == "ca-conj" and multiword_lemma then
		for _, slot_and_accel in ipairs(alternant_multiword_spec.all_verb_slots) do
			local slot = slot_and_accel[1]
			local forms = base.forms[slot]
			local must_break = false
			if forms then
				for _, form in ipairs(forms) do
					if not form.form:find("%[%[") then
						local title = mw.title.new(form.form)
						if title and not title.exists then
							insert_cat("verbs with red links in their inflection tables")
							must_break = true
						break
						end
					end
				end
			end
			if must_break then
				break
			end
		end
	end

	map_general(base.output_stems.stem, function(stem)
		local stem_base, conj_vowel = split_conj_vowel(stem)
		local need_no_eix_infix = true
		if conj_vowel ~= base.conj_vowel then
			insert_ann("conj", "[[Appendix:Catalan verbs#Irregular verbs|mixed conjugation]]")
			insert_cat("mixed conjugation verbs")
		elseif conj_vowel == "a" then
			insert_ann("conj", "[[Appendix:Catalan verbs#First conjugation|first conjugation]]")
			insert_cat("first conjugation verbs")
		elseif conj_vowel == "e" then
			insert_ann("conj", "[[Appendix:Catalan verbs#Second conjugation|second conjugation]]")
			insert_cat("second conjugation verbs")
		elseif conj_vowel == "i" then
			insert_ann("conj", "[[Appendix:Catalan verbs#Third conjugation|third conjugation]]")
			insert_cat("third conjugation verbs")
			need_no_eix_infix = false
			map_general(base.output_stems.eix_infix, function(form)
				if form == "+" then
					insert_ann("eix_infix", "with -eix-")
					insert_cat("third conjugation verbs with -eix-")
				elseif form == "-" then
					insert_ann("eix_infix", "without -eix-")
					insert_cat("third conjugation verbs without -eix-")
				end
			end)
		else
			error(("Internal error: Stem '%s' doesn't end in conjugation vowel a/e/i and split_conj_vowel() didn't catch it"
				):format(stem))
		end
		if need_no_eix_infix then
			insert_ann("eix_infix", "no infix")
		end
	end)

	if base.input_stems.g_infix then
		insert_ann("g_infix", "with velar infix")
			insert_cat("verbs with velar infix")
	else
		insert_ann("g_infix", "no infix")
	end

	if base.output_stems.irreg then
		insert_ann("irreg", "irregular")
		insert_cat("irregular verbs")
	else
		insert_ann("irreg", "regular")
	end

	if base.only3s then
		insert_ann("defective", "impersonal")
		insert_cat("impersonal verbs")
	elseif base.only3sp then
		insert_ann("defective", "third-person only")
		insert_cat("third-person-only verbs")
	elseif base.only3p then
		insert_ann("defective", "third-person plural only")
		insert_cat("third-person-plural-only verbs")
	elseif base.no_pres_stressed then
		insert_ann("defective", "defective")
		insert_cat("defective verbs")
	else
		insert_ann("defective", "regular")
	end

	--if base.clitic then
	--	insert_cat("verbs with lexical clitics")
	--end

	if base.refl then
		insert_cat("reflexive verbs")
	end

	local stem_base, conj_vowel = split_conj_vowel(base.stem)
	local cons_alt
	if conj_vowel == "i" and base.output_stems.eix_infix == "+" then
		-- no alternations in verbs like [[afligir]] because all endings are front
	elseif stem_base:find("ç$") then
		cons_alt = "ç-c"
	elseif stem_base:find("c$") then
		cons_alt = "c-qu"
	elseif stem_base:find("g$") then
		cons_alt = "g-gu"
	elseif stem_base:find("gu$") then
		cons_alt = "gu-gü"
	elseif stem_base:find("j$") then
		cons_alt = "j-g"
	elseif stem_base:find("qu$") then
		cons_alt = "qu-qü"
	end

	if cons_alt then
		local desc = cons_alt .. " alternation"
		insert_ann("cons_alt", desc)
		insert_cat("verbs with " .. desc)
	else
		insert_ann("cons_alt", "non-alternating")
	end
end


-- Compute the categories to add the verb to, as well as the annotation to display in the
-- conjugation title bar. We combine the code to do these functions as both categories and
-- title bar contain similar information.
local function compute_categories_and_annotation(alternant_multiword_spec)
	alternant_multiword_spec.categories = {}
	local ann = {}
	alternant_multiword_spec.annotation = ann
	ann.conj = {}
	ann.g_infix = {}
	ann.eix_infix = {}
	ann.irreg = {}
	ann.defective = {}
	ann.cons_alt = {}

	local multiword_lemma = false
	for _, form in ipairs(alternant_multiword_spec.forms.infinitive) do
		if form.form:find(" ") then
			multiword_lemma = true
			break
		end
	end

	iut.map_word_specs(alternant_multiword_spec, function(base)
		add_categories_and_annotation(alternant_multiword_spec, base, multiword_lemma)
	end)
	local ann_parts = {}
	local conj = table.concat(ann.conj, " or ")
	if conj ~= "" then
		table.insert(ann_parts, conj)
	end
	local eix_infix = table.concat(ann.eix_infix, " or ")
	if eix_infix ~= "" and eix_infix ~= "no infix" then
		table.insert(ann_parts, eix_infix)
	end
	local irreg = table.concat(ann.irreg, " or ")
	if irreg ~= "" and irreg ~= "regular" then
		table.insert(ann_parts, irreg)
	end
	local g_infix = table.concat(ann.g_infix, " or ")
	if g_infix ~= "" and g_infix ~= "no infix" then
		table.insert(ann_parts, g_infix)
	end
	local defective = table.concat(ann.defective, " or ")
	if defective ~= "" and defective ~= "regular" then
		table.insert(ann_parts, defective)
	end
	local cons_alt = table.concat(ann.cons_alt, " or ")
	if cons_alt ~= "" and cons_alt ~= "non-alternating" then
		table.insert(ann_parts, cons_alt)
	end
	alternant_multiword_spec.annotation = table.concat(ann_parts, ", ")
end


local function show_forms(alternant_multiword_spec)
	local lemmas = alternant_multiword_spec.forms.infinitive
	alternant_multiword_spec.lemmas = lemmas -- save for later use in make_table()

	local reconstructed_verb_spec = iut.reconstruct_original_spec(alternant_multiword_spec)

	local function transform_accel_obj(slot, formobj, accel_obj)
		-- No accelerators for negative imperatives, which are always multiword and derived directly from the
		-- present subjunctive.
		if slot:find("^neg_imp") then
			return nil
		end
		if accel_obj then
			accel_obj.form = "verb-form-" .. reconstructed_verb_spec
		end
		return accel_obj
	end

	local props = {
		lang = lang,
		lemmas = lemmas,
		transform_accel_obj = transform_accel_obj,
		slot_list = alternant_multiword_spec.verb_slots_basic,
	}
	iut.show_forms(alternant_multiword_spec.forms, props)
	alternant_multiword_spec.footnote_basic = alternant_multiword_spec.forms.footnote
end


local notes_template = [=[
<div class="roa-footnote-outer-div" style="width:100%;">
<div class="roa-footnote-inner-div">
{footnote}
</div></div>
]=]

local basic_table = [=[
{description}<div class="NavFrame">
<div class="NavHead">&nbsp; &nbsp; Conjugation of {title}</div>
<div class="NavContent">
{\op}| class="roa-inflection-table" data-toggle-category="inflection"
|-
! colspan="3" class="roa-nonfinite-header" | <span title="infinitiu">infinitive</span>
| colspan="5" | {infinitive}
|-
! colspan="3" class="roa-nonfinite-header" | <span title="gerundi">gerund</span>
| colspan="5" | {gerund}
|-
! rowspan="3" colspan="2" class="roa-nonfinite-header" | <span title="participi passat">past participle</span>
| colspan="2" class="roa-nonfinite-header" |
! colspan="2" class="roa-nonfinite-header" | masculine
! colspan="2" class="roa-nonfinite-header" | feminine
|-
! colspan="2" class="roa-nonfinite-header" | singular
| colspan="2" | {pp_ms}
| colspan="2" | {pp_fs}
|-
! colspan="2" class="roa-nonfinite-header" | plural
| colspan="2" | {pp_mp}
| colspan="2" | {pp_fp}
|-
! colspan="2" rowspan="2" class="roa-person-number-header" | person
! colspan="3" class="roa-person-number-header" | singular
! colspan="3" class="roa-person-number-header" | plural
|-
! class="roa-person-number-header" style="width:12.5%;" | first
! class="roa-person-number-header" style="width:12.5%;" | second
! class="roa-person-number-header" style="width:12.5%;" | third
! class="roa-person-number-header" style="width:12.5%;" | first
! class="roa-person-number-header" style="width:12.5%;" | second
! class="roa-person-number-header" style="width:12.5%;" | third
|-
! rowspan="6" class="roa-indicative-left-rail" | <span title="indicatiu">indicative</span>
! class="roa-indicative-left-rail" |
! class="roa-indicative-left-rail" | <<jo>>
! class="roa-indicative-left-rail" | <<tu>>
! class="roa-indicative-left-rail" | <<ell>>/<<ella>><br /><<vostè>>
! class="roa-indicative-left-rail" | <<nosaltres>><br /><<nós>>
! class="roa-indicative-left-rail" | <<vosaltres>><br /><<vós>>
! class="roa-indicative-left-rail" | <<ells>>/<<elles>><br /><<vostès>>
|-
! class="roa-indicative-left-rail" style="height:3em;" | <span title="present">present</span>
| {pres_1s}
| {pres_2s}
| {pres_3s}
| {pres_1p}
| {pres_2p}
| {pres_3p}
|-
! class="roa-indicative-left-rail" style="height:3em;" | <span title="imperfet">imperfect</span>
| {impf_1s}
| {impf_2s}
| {impf_3s}
| {impf_1p}
| {impf_2p}
| {impf_3p}
|-
! class="roa-indicative-left-rail" style="height:3em;" | <span title="futur">future</span>
| {fut_1s}
| {fut_2s}
| {fut_3s}
| {fut_1p}
| {fut_2p}
| {fut_3p}
|-
! class="roa-indicative-left-rail" style="height:3em;" | <span title="passat">preterite</span>
| {pret_1s}
| {pret_2s}
| {pret_3s}
| {pret_1p}
| {pret_2p}
| {pret_3p}
|-
! class="roa-indicative-left-rail" style="height:3em;" | <span title="condicional">conditional</span>
| {cond_1s}
| {cond_2s}
| {cond_3s}
| {cond_1p}
| {cond_2p}
| {cond_3p}
|-
! class="roa-subjunctive-left-rail" rowspan="3" | <span title="subjuntiu">subjunctive</span>
! class="roa-subjunctive-left-rail" |
! class="roa-subjunctive-left-rail" | <<jo>>
! class="roa-subjunctive-left-rail" | <<tu>>
! class="roa-subjunctive-left-rail" | <<ell>>/<<ella>><br /><<vostè>>
! class="roa-subjunctive-left-rail" | <<nosaltres>><br /><<nós>>
! class="roa-subjunctive-left-rail" | <<vosaltres>><br /><<vós>>
! class="roa-subjunctive-left-rail" | <<ells>>/<<elles>><br /><<vostès>>
|-
! class="roa-subjunctive-left-rail" style="height:3em;" | <span title="present">present</span>
| {pres_sub_1s}
| {pres_sub_2s}
| {pres_sub_3s}
| {pres_sub_1p}
| {pres_sub_2p}
| {pres_sub_3p}
|-
! class="roa-subjunctive-left-rail" style="height:3em;" rowspan="1" | <span title="imperfet">imperfect</span>
| {impf_sub_1s}
| {impf_sub_2s}
| {impf_sub_3s}
| {impf_sub_1p}
| {impf_sub_2p}
| {impf_sub_3p}
|-
! rowspan="3" class="roa-imperative-left-rail" style="height:3em;" | <span title="imperatiu">imperative</span>
! class="roa-imperative-left-rail" |
! class="roa-imperative-left-rail" | &mdash;
! class="roa-imperative-left-rail" | <<tu>>
! class="roa-imperative-left-rail" | <<vostè>>
! class="roa-imperative-left-rail" | <<nosaltres>>
! class="roa-imperative-left-rail" | <<vosaltres>><br /><<vós>>
! class="roa-imperative-left-rail" | <<vostès>>
|-
! class="roa-imperative-left-rail" style="height:3em;" | <span title="afirmatiu">affirmative</span>
| &mdash;
| {imp_2s}
| {imp_3s}
| {imp_1p}
| {imp_2p}
| {imp_3p}
|-
! class="roa-imperative-left-rail" style="height:3em;" | <span title="negatiu">negative</span> (<<no>>)
| &mdash;
| {neg_imp_2s}
| {neg_imp_3s}
| {neg_imp_1p}
| {neg_imp_2p}
| {neg_imp_3p}
|{\cl}{notes_clause}</div></div>]=]

local function make_table(alternant_multiword_spec)
	local forms = alternant_multiword_spec.forms

	forms.title = link_term(alternant_multiword_spec.lemmas[1].form, nil, "term")
	local ann_parts = {}
	if alternant_multiword_spec.annotation ~= "" then
		table.insert(ann_parts, alternant_multiword_spec.annotation)
	end
	if alternant_multiword_spec.args.titlenote then
		table.insert(ann_parts, alternant_multiword_spec.args.titlenote)
	end
	local annotation = table.concat(ann_parts, ", ")
	if annotation ~= "" then
		forms.title = forms.title .. " (" .. annotation .. ")"
	end
	forms.description = ""

	-- Format the table.
	forms.footnote = alternant_multiword_spec.footnote_basic
	forms.notes_clause = forms.footnote ~= "" and m_string_utilities.format(notes_template, forms) or ""
	local table_with_pronouns = rsub(basic_table, "<<([^<>|]-)|([^<>|]-)>>", link_term)
	local table_with_pronouns = rsub(table_with_pronouns, "<<(.-)>>", link_term)
	return require("Module:TemplateStyles")("Module:roa-verb/style.css") ..
		m_string_utilities.format(table_with_pronouns, forms)
end


-- Externally callable function to parse and conjugate a verb given user-specified arguments.
-- Return value is WORD_SPEC, an object where the conjugated forms are in `WORD_SPEC.forms`
-- for each slot. If there are no values for a slot, the slot key will be missing. The value
-- for a given slot is a list of objects {form=FORM, footnotes=FOOTNOTES}.
function export.do_generate_forms(args, source_template, headword_head)
	local PAGENAME = mw.title.getCurrentTitle().text
	local function in_template_space()
		return mw.title.getCurrentTitle().nsText == "Template"
	end

	-- Determine the verb spec we're being asked to generate the conjugation of. This may be taken from the
	-- current page title or the value of |pagename=; but not when called from {{ca-verb form of}}, where the
	-- page title is a non-lemma form. Note that the verb spec may omit the infinitive; e.g. it may be "<i-e>".
	-- For this reason, we use the value of `pagename` computed here down below, when calling normalize_all_lemmas().
	local pagename = source_template ~= "ca-verb form of" and args.pagename or PAGENAME
	local head = headword_head or pagename
	local arg1 = args[1]

	if not arg1 then
		if (pagename == "ca-conj" or pagename == "ca-verb" or pagename == "ca-verb form of") and in_template_space() then
			arg1 = "amar<>"
		else
			arg1 = "<>"
		end
	end

	-- When called from {{ca-verb form of}}, determine the non-lemma form whose inflections we're being asked to
	-- determine. This normally comes from the page title or the value of |pagename=.
	local verb_form_of_form
	if source_template == "ca-verb form of" then
		verb_form_of_form = args.pagename
		if not verb_form_of_form then
			if PAGENAME == "ca-verb form of" and in_template_space() then
				verb_form_of_form = "ami"
			else
				verb_form_of_form = PAGENAME
			end
		end
	end

	local incorporated_headword_head_into_lemma = false
	if arg1:find("^<.*>$") then -- missing lemma
		if head:find(" ") then
			-- If multiword lemma, try to add arg spec after the first word.
			-- Try to preserve the brackets in the part after the verb, but don't do it
			-- if there aren't the same number of left and right brackets in the verb
			-- (which means the verb was linked as part of a larger expression).
			local refl_clitic_verb, post = rmatch(head, "^(.-)( .*)$")
			local left_brackets = rsub(refl_clitic_verb, "[^%[]", "")
			local right_brackets = rsub(refl_clitic_verb, "[^%]]", "")
			if #left_brackets == #right_brackets then
				arg1 = iut.remove_redundant_links(refl_clitic_verb) .. arg1 .. post
				incorporated_headword_head_into_lemma = true
			else
				-- Try again using the form without links.
				local linkless_head = m_links.remove_links(head)
				if linkless_head:find(" ") then
					refl_clitic_verb, post = rmatch(linkless_head, "^(.-)( .*)$")
					arg1 = refl_clitic_verb .. arg1 .. post
				else
					error("Unable to incorporate <...> spec into explicit head due to a multiword linked verb or " ..
						"unbalanced brackets; please include <> explicitly: " .. arg1)
				end
			end
		else
			-- Will be incorporated through `head` below in the call to normalize_all_lemmas().
			incorporated_headword_head_into_lemma = true
		end
	end

	local function split_bracketed_runs_into_words(bracketed_runs)
		return iut.split_alternating_runs(bracketed_runs, " ", "preserve splitchar")
	end

	local parse_props = {
		parse_indicator_spec = parse_indicator_spec,
		-- Split words only on spaces, not on hyphens, because that messes up reflexive verb parsing.
		split_bracketed_runs_into_words = split_bracketed_runs_into_words,
		allow_default_indicator = true,
		allow_blank_lemma = true,
	}
	local alternant_multiword_spec = iut.parse_inflected_text(arg1, parse_props)
	alternant_multiword_spec.pos = pos or "verbs"
	alternant_multiword_spec.args = args
	alternant_multiword_spec.source_template = source_template
	alternant_multiword_spec.verb_form_of_form = verb_form_of_form
	alternant_multiword_spec.incorporated_headword_head_into_lemma = incorporated_headword_head_into_lemma

	normalize_all_lemmas(alternant_multiword_spec, head)
	detect_all_indicator_specs(alternant_multiword_spec)
	local inflect_props = {
		slot_list = alternant_multiword_spec.all_verb_slots,
		inflect_word_spec = conjugate_verb,
		-- We add links around the generated verbal forms rather than allow the entire multiword
		-- expression to be a link, so ensure that user-specified links get included as well.
		include_user_specified_links = true,
	}
	iut.inflect_multiword_or_alternant_multiword_spec(alternant_multiword_spec, inflect_props)

	-- Remove redundant brackets around entire forms.
	for slot, forms in pairs(alternant_multiword_spec.forms) do
		for _, form in ipairs(forms) do
			form.form = iut.remove_redundant_links(form.form)
		end
	end

	compute_categories_and_annotation(alternant_multiword_spec)
	if args.json and source_template == "ca-conj" then
		return require("Module:JSON").toJSON(alternant_multiword_spec.forms)
	end
	return alternant_multiword_spec
end


-- Entry point for {{ca-conj}}. Template-callable function to parse and conjugate a verb given
-- user-specified arguments and generate a displayable table of the conjugated forms.
function export.show(frame)
	local parent_args = frame:getParent().args
	local params = {
		[1] = {},
		["titlenote"] = {},
		["noautolinktext"] = {type = "boolean"},
		["noautolinkverb"] = {type = "boolean"},
		["pagename"] = {}, -- for testing/documentation pages
		["json"] = {type = "boolean"}, -- for bot use
	}
	local args = require("Module:parameters").process(parent_args, params)
	local alternant_multiword_spec = export.do_generate_forms(args, "ca-conj")
	if type(alternant_multiword_spec) == "string" then
		-- JSON return value
		return alternant_multiword_spec
	end
	show_forms(alternant_multiword_spec)
	return make_table(alternant_multiword_spec) ..
		require("Module:utilities").format_categories(alternant_multiword_spec.categories, lang, nil, nil, force_cat)
end


return export
