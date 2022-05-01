local tests = require("Module:UnitTests")
local m_de_pron = require("Module:de-pron")
local m_links = require("Module:links")
local m_table = require("Module:table")
local lang = require("Module:languages").getByCode("de")

local rsplit = mw.text.split
local rmatch = mw.ustring.match

local function tag_IPA(IPA)
	return '<span class="IPA">' .. IPA .. "</span>"
end

local function link(text)
	return m_links.full_link{ term = text, lang = lang }
end

local options = { display = tag_IPA }

--[=[
In the following examples, each line is either a section header beginning with a ##, a comment beginning with # but not
##, a blank line or an example. Examples consist of three tab-separated fields, followed by an optional comment to be
shown along with the example (delimited by a # preceded by whitespace). The first field is the actual spelling of the
term in question. The second field is the respelling. The third field is the expected phonemic IPA pronunciation.

Example #1:

Aachener	Aachener	ˈaːxənɐ

This specifies a word [[Aachener]], respelled 'Aachener' (i.e. same as the actual spelling), with phonemic pronunciation
/ˈaːxənɐ/.

Example #2:

Bodyguard	Boddigàhrd	ˈbɔdiˌɡaːʁt

This specifies a word [[Bodyguard]], respelled 'Boddigàhrd', with phonemic pronunciation /ˈbɔdiˌɡaːʁt/.

Example #3:

Chefredakteur	Schef-redaktö́r	ˈʃeːfʁedakˌtøːʁ # usually in Austria

This specifies a word [[Chefredakteur]], respelled 'Schef-redaktö́r', with phonemic pronunciation /ˈʃeːfʁedakˌtøːʁ/ and
a comment "usually in Austria".


FIXME: We should have support for higher-level section headers designated using ###.
]=]

local examples = [==[
## Digraphs, trigraphs
Stadt	Stadt	ʃtat
verwandte	verwandte	fɛʁˈvantə

## Digraphs with h
Bach	Bach	bax
Aachener	Aachener	ˈaːxənɐ
Milch	Milch	mɪlç
Knöchel	Knöchel	ˈknœçəl
Agrochemie	Agro-chemie	ˈaːɡʁoçeˌmiː
durch	durch	dʊʁç
Chuzpe	X*uzpe	ˈxʊt͡spə
Tisch	Tisch	tɪʃ
Haschisch	Haschisch	ˈhaʃɪʃ
wünschen	wünschen	ˈvʏnʃən
Wünschen	Wünschen	ˈvʏnʃən
tschüss	tschüss	t͡ʃʏs
Dschungel	Dschungel	ˈd͡ʒʊŋəl
Buddha	Buddha	ˈbʊda
Abu Dhabi	Abu Dhabi	ˈabu ˈdaːbi
Sindhi	ˈzɪndi
Adhäsion	Ad.häsion	athɛˈzi̯oːn
Methode	Methóde	meˈtoːdə
Abendroth	Ab+end-roth	ˈaːbəntˌʁoːt
Absinth	Absínth	apˈzɪnt
Theater	Theáter	teˈaːtɐ
Theater	Theʔáter	teˈʔaːtɐ
Agathe	Agáthe	aˈɡaːtə
Akolyth	Akolýth	akoˈlyːt
Algorithmus	Àlgoríthmus	ˌalɡoˈʁɪtmʊs
katholisch	kathólisch	kaˈtoːlɪʃ
Khaki	Khaki	ˈkaːki
Afghane	Afgháne	afˈɡaːnə
Afghanistan	Afghánistahn	afˈɡaːnɪstaːn
Ghana	Ghana	ˈɡaːna
Ghetto	Ghetto	ˈɡɛto
Joghurt	Joghurt	ˈjoːɡʊʁt
Maghreb	Magghrebb	ˈmaɡʁɛp
Sorghum	Sorghum	ˈzɔʁɡʊm
Spaghetti	Spaghétti	ʃpaˈɡɛti
Spaghetti	S*paghétti	spaˈɡɛti
Bhutan	Bhutan	ˈbuːtan
Diarrhö	Di.arrhö́	diaˈʁøː
Diarrhoe	Di.arrhö́	diaˈʁøː
Rhythmus	Rhythmus	ˈʁʏtmʊs
Rhodos	Rhoddos	ˈʁɔdɔs
Rhabarber	Rhabárber	ʁaˈbaʁbɐ
Rhapsodie	Rhàpsodie	ˌʁapsoˈdiː
Rheda	Rheda	ˈʁeːda
Rhein	Rhein	ʁaɪ̯n
Rhenium	Rhenium	ˈʁeːni̯ʊm
Rhetorik	Rhetórik	ʁeˈtoːʁɪk
Rheuma	Rheuma	ˈʁɔɪ̯ma
Rhone	Rhone	ˈʁoːnə


## French-derived words
Absence	Abs*áNs	apˈsãːs
Baguette	Bagétt	baˈɡɛt
Chaiselongue	Schĕselóng	ʃɛzəˈlɔŋ # dewikt pron #1
Chaiselongue	SchẹselóNk	ʃɛzəˈlõːk # dewikt pron #2
Chaiselongue	SchehslóNng	ʃeːsˈlõːŋ # dewikt pron #1 (Austrian)
Chaiselongue	SchehslóNk	ʃeːsˈlõːk # dewikt pron #2 (Austrian)
Chaiselongue	Schĕz*lóNg*	ʃɛzˈlõːɡ # dewikt pron #3 (Austrian)
Champignon	Schampinjòng	ˈʃam.pɪnˌjɔŋ
Champignon	Schampinjõ̀	ˈʃam.pɪnˌjõː
Chefredakteur	Scheff-redaktö́r	ˈʃɛfʁedakˌtøːʁ
Chefredakteur	Schef-redaktö́r	ˈʃeːfʁedakˌtøːʁ # usually in Austria
Guillotine	Gi.otíne	ɡioˈtiːnə
orange	orã́ʒ	oˈʁãːʃ # enwikt pron #1
orange	orángʒ	oˈʁaŋʃ # enwikt pron #2
orange	orṍʒ	oˈʁõːʃ # enwikt pron #3
orange	oróngʒ	oˈʁɔŋʃ # enwikt pron #4
Orange	Orã́ʒe	oˈʁãːʒə # enwikt pron #1
arrangieren	arrãʒieren	aʁãˈʒiːʁən
Avance	Avã́s	aˈvãːs
Bombardement	Bòmbardəmã́	ˌbɔmbaʁdəˈmãː
Branche	Brãsche	ˈbʁãːʃə
Branche	Brangsche	ˈbʁaŋʃə
Champagner	Schampánjer	ʃamˈpanjɐ
Parfum	Parfö́N	paʁˈfœ̃ː
Nonchalance	Nõschalã́s	nõʃaˈlãːs
Pompon	Põpṍ	põˈpõː
Pompon	Pompṍ	pɔmˈpõ
Saison	Sĕsṍ	zɛˈzõː
Saison	Sĕsóng	zɛˈzɔŋ
salonfähig	salṍ-fähig	zaˈlõːˌfɛːɪç
Bain-Marie	Bẽmarie	bɛ̃maˈʁiː
Bohemien	Boemiẽ́	boeˈmjɛ̃ː
Bohemien	Bohemiẽ́	boheˈmjɛ̃ː
Cousin	Kusẽ́	kuˈzɛ̃ː
Cousin	Kuséng	kuˈzɛŋ
Lingerie	Lẽʒerie	lɛ̃ʒəˈʁiː
Lingerie	Lẽʒrie	lɛ̃ʒˈʁiː
Mannequin	Mannəkẽ́	manəˈkɛ̃ː
Mannequin	Mannəkẽ	ˈmanəkɛ̃ː
Pointe	Po̯ẽ́te	Po̯ɛ̃ːte
Pointe	POeNte	Po̯ɛ̃ːte
Toilette	To̯alétte	to̯aˈlɛtə
Toilette	Tolétte	toˈlɛtə
Voyeur	Vo̯ayö́r	vo̯aˈjøːʁ
Bourgeoisie	Bùrʒo̯asie	ˌbʊʁʒo̯aˈziː
Couloir	Kulo̯ár	kuˈlo̯aːʁ
Croissant	Cro̯assã́	kʁo̯aˈsãː
Croissant	Crôssóng	kʁoˈsɔŋ
flamboyant	flãbo̯ajant	flãbo̯aˈjant
Rendezvous	Rã̀devú	ˌʁãdeˈvuː
Negligé	Negliʒé	neɡliˈʒeː


## English-derived words
Bodyguard	Boddigàhrd	ˈbɔdiˌɡaːʁt
Champion	TschempIen	ˈt͡ʃɛmpi̯ən
Whiskey	Whiski	ˈvɪski
Whiskey	W*iski	ˈwɪski
T-Shirt	Ti-Schöhrt	ˈtiːˌʃøːʁt
Thriller	θriller	ˈθʁɪlɐ
Thriller	S*riller	ˈsʁɪlɐ
Rock	Rock	ʁɔk
Rock	ɹock	ɹɔk
Sound	S*aund	saʊ̯nt
Steak	S*teIk	stɛɪ̯k
Steak	S*tehk	stɛːk
Spray	SpreI	ʃpʁɛɪ̯
Airbag	Ähr-begg	ˈɛːʁˌbɛk
Homepage	HoUmpehdsch	ˈhɔʊ̯mpeːt͡ʃ
Homepage	Hohmpehdsch	ˈhoːmpeːt͡ʃ
Cowboy	Kauboy	ˈkaʊ̯bɔɪ̯
Playboy	Pleh-boy	ˈpleːˌbɔɪ̯
Comeback	Kambeck	ˈkambɛk
Edinburgh	Eddinbere	ˈɛdɪnbərə
Ghostwriter	GhoUst-raiter	ˈɡoʊ̯stˌʁaɪ̯tɐ
Ghostwriter	Ghohst-raiter	ˈɡoːstˌʁaɪ̯tɐ
Canyon	Kenjen	ˈkɛnjən
Jazz	Dschäß	d͡ʒɛːs
Jazz	Dschess	d͡ʒɛs

## bs, ds, gs
absurd	absúrd	apˈzʊʁt
obsessiv	obsessív	ɔpzɛˈsiːf # /ps/ in dewikt but probably wrong
Obsoleszenz	Obsoleszenz	ɔpzolɛsˈt͡sɛnt͡s
subsumtiv	subsumtív	zʊpzʊmˈtiːf
Erbse	Erbse	ˈɛʁpsə
obsen	obsen	ˈɔpsən
adsorbieren	adsorbieren	atzɔʁˈbiːʁən
Landser	Landser	ˈlant͡sɐ
Trübsal	Trüb>sal
bugsieren	bugsieren	bʊˈksiːʁən
pumperlgsund	pumperl-gsund	ˈpʊmpɐlˌksʊnt

## -h- between vowels
Bedrohung	Bedrohung	bəˈdʁoːʊŋ
arbeitsfähig	arbeit>s-fähig	ˈaʁbaɪ̯t͡sˌfɛːɪç
befähigt	befähigt	bəˈfɛːɪçt
Beruhigen	Beruhigen	bəˈʁuːɪɡən
Ehe	Ehe	ˈeːə
viehisch	fiehisch	ˈfiːɪʃ
Dschihadist	Dschihahdist	d͡ʒihaːˈdɪst
Johann	Johann	ˈjoːhan
Maharadscha	Maharáhdscha	mahaˈʁaːdʒa # prescriptive
Maharadscha	Maharádscha	mahaˈʁadʒa # enwikt: "slightly more common"
Maharadscha	Maharátscha	mahaˈʁatʃa # enwikt: "usual"
Mohammed	Mohammedd	ˈmoːhamɛt
Rehabilitation	Rèhabilitation	ˌʁehabilitaˈt͡si̯oːn
Tomahawk	Tommahahk	ˈtɔmahaːk
Tomahawk	Tommahohk	ˈtɔmahoːk
Bohemistik	Bohemistik	boheˈmɪstɪk
Ahorn	Ahorn	ˈaːhɔʁn
Alkoholismus	Àlkoholismus	ˌalkohoˈlɪsmʊs
Jehova	Jehóva	jeˈhoːva
Kohorte	Kohórte	koˈhɔʁtə
Bahuvrihi	Bahuvríhi	bahuˈvʁiːhi
nihilistisch	nihilistisch	nihiˈlɪstɪʃ
Estomihi	Estomíhi	ɛstoˈmiːhi
Tohuwabohu	Tòhhuwabóhu	ˌtoːhuvaˈboːhu
huhu	huhu	ˈhuːhu
Uhudler	U.huhdler	ˈuːhuːdlɐ

## -gu- in hiatus
Ambiguität	Ambigu.ität	ambiɡuiˈtɛːt
Antigua	Antíguah	anˌtiːɡu̯aː
Äquatorialguinea	Äquatori.al-ginéa	ɛkvatoʁiˈaːlɡiˌneːa # per enwikt
Äquatorialguinea	Ä̀quatorial-ginéa	ˌɛkvatoˈʁi̯aːlɡiˌneːa # per dewikt
Bilingualismus	Bilinggualísmus	bilɪŋɡʊ̯aˈlɪsmʊs
Guacamole	Guakamóle	ɡu̯akaˈmoːlə
Guano	Guano	ˈɡu̯aːno
Guatemalteke	Guatemaltéke	ɡu̯atemalˈteːkə
Jaguar	Jaguahr	ˈjaːɡu̯aːʁ
Papua-Neuguinea	Papua Nèuginéa	ˈpaːpu̯a ˌnɔɪ̯ɡiˈneːa # per enwikt
Papua-Neuguinea	Papu.a-*neuginéa	ˌpaːpuanɔɪ̯ɡiˈneːa # per dewikt
Paraguay	Paragway	ˈpaːʁaɡvaɪ̯ # dewikt pron #1
Paraguay	Parragway	ˈpaʁaɡvaɪ̯ # dewikt pron #2
Paraguay	Paraguáy	paʁaˈɡu̯aɪ̯ # dewikt pron #3
Patholinguistik	Pátholinguìstik	ˈpaːtolɪŋˌɡu̯ɪstɪk # dewikt pron #1
Patholinguistik	Pátholingu.ìstik	ˈpaːtolɪŋɡuˌɪstɪk # dewikt pron #2
Patholinguistik	Patholinguístik	patolɪŋˈɡu̯ɪstɪk # dewikt pron #3
Patholinguistik	Pàttholingu.ístik	ˌpatolɪŋɡuˈɪstɪk # dewikt pron #4
Patholinguistik	Pàtholinguʔístik	ˌpatolɪŋɡuˈʔɪstɪk # dewikt pron #5

## other -u- in hiatus
aktualisieren	àktu.alisieren	ˌaktualiˈziːʁən
Asexualität	Ắsexualitä̀t	ˈazɛksu̯aliˌtɛːt
Asexualität	Ássexualitä̀t	ˈasɛksu̯aliˌtɛːt
Botsuana	Botsuána	bɔˈt͡su̯aːna # enwikt
Botsuana	Botsu.ána	bɔt͡suˈaːna # dewikt pron #1
Botsuana	Botsuʔána	bɔt͡suˈʔaːna # dewikt pron #2
dual	du.ál	duˈaːl
Dual-SIM-Smartphone	Du.ál-Sịmm-Smahrtphohn	duˈaːlzɪmˌsmaːʁtfoːn
Dualsystem	Du.ál-systém	duˈaːlzʏsˌteːm
Ecuador	Ekuadór	eku̯aˈdoːʁ
evaluativ	evalu.atív	evaluaˈtiːf
evaluieren	evalu.ieren	evaluˈiːʁən
Situation	Situ.azión	zituaˈt͡si̯oːn

# --------- -y- ---------

## Stressed y
Acryl	Acrýl	aˈkʁyːl
analytisch	analýtisch	anaˈlyːtɪʃ
Beryllium	Berýllium	beˈʁʏli̯ʊm
Ägypten	Ägýpten	ɛˈɡʏptən
Harpyie	Harpýje	haʁˈpyːjə

## Initial y followed by vowel
Yacht	Yacht	jaxt
New York	Nju̇ York	njuː ˈjɔrk
Yoga	Yoga	ˈjoːɡa
Yottabyte	Yóttabàit	ˈjɔtaˌbaɪ̯t
Yuppie	Yuppi	ˈjʊpi

## Initial y followed by consonant
Ypern	Ypern	ˈyːpɐn
Ypsilon	Ypsilon	ˈʏpsilɔn
Ytterbium	Yttérbium	ʏˈtɛʁbi̯ʊm

## Final y after a consonant
Hobby	Hobby	ˈhɔbi
Sony	Sony	ˈzoːni
Monopoly	Monópoly	moˈnoːpoli
Stransky	Stransky	ˈʃtʀanski
Babyöl	Beby-öl	ˈbeːbiˌʔøːl

##  Non-final y after a consonant
symmetrisch	symmétrisch	zʏˈmeːtʁɪʃ
Psychologie	Psychologie	psyçoloˈɡiː
Aerodynamik	Aerodynámik	aeʁodyˈnaːmɪk
Zyan	Zyán	t͡syˈaːn
Myon	Myon	ˈmyːɔn
Kryometer	Kryométer	kʁyoˈmeːtɐ

## ay/oy not followed by a vowel or followed by e/i/u and no stress follows
Bayern	Bayern	ˈbaɪ̯ɐn
Hoyerswerda	Hoyers-*verda	hɔɪ̯ɐsˈvɛʁda
Mayer	Mayer	ˈmaɪ̯ɐ
Paraguay	Paragway	ˈpaːʁaɡvaɪ̯
Bayreuth	Bayréuth	baɪ̯ˈʁɔʏ̯t
Boykott	Bòykótt	ˌbɔɪ̯ˈkɔt
Malaysia	Maláysia	maˈlaɪ̯zi̯a
Maybach	Maybach	ˈmaɪbax

## ey not followed by a vowel or followed by e/i/u and no stress follows
Meyer	Meyer	ˈmaɪ̯ɐ
Leyen	Leyen	ˈlaɪ̯ən
Leyermann	Leyer-mann	ˈlaɪ̯ɐˌman
beyde	beyde	ˈbaɪ̯də
dabey	dabéy	daˈbaɪ̯
meyn	meyn	maɪ̯n
Geysir	Geysír	ɡaɪ̯ˈziːʁ

## Other y after vowels
Ayurveda	Ayurvéda	ajʊʁˈveːda
Oriya	Oríya	oˈʁiːja
Mayo	Mayo	ˈmaːjo
Toyota	Toyóta	toˈjoːta
Larmoyanz	LarmOayanz	laʁmo̯aˈjant͡s
Guyana	Guyána	ɡuˈjaːna
Cayenne	Kayén	kaˈjɛn

## y needing respelling
Myanmar	Miánmahr	ˈmi̯anmaːʁ
Libyen	LibIen	ˈliːbi̯ən
Magyar	Madjáhr	maˈdjaːʁ
Polyester	Poliéster	poˈli̯ɛstɐ
Prokaryot	Prokary̯ót	pʁokaˈʁy̯oːt
Calypso	Kalípso	kaˈlɪpso

## -ng-, -nk-
abdrängen	abdrängen	ˈapˌdʁɛŋən
Abgang	Abgang	ˈapˌɡaŋ
Abhängigkeit	Abhängigkeit	ˈaphɛŋɪçˌkaɪ̯t
distinguiert	distingiert	dɪstɪŋˈɡiːʁt
Hengst	Hengst	hɛŋst
konsanguin	konsanguín	kɔnzaŋˈɡu̯iːn
Linguistik	Linguístik	lɪŋˈɡu̯ɪstɪk
Pinguin	Pinguìn	ˈpɪŋˌɡu̯iːn
Pinguin	Pingu.ìn	ˈpɪŋɡuˌiːn
kongruent	kon.gru.ent	kɔnɡʁuˈɛnt
kongruent	kongru.ent	kɔŋɡʁuˈɛnt
Danke	Danke	ˈdaŋkə
gelenkig	gelenkig	ɡəˈlɛŋkɪç
Erkrankung	Erkrankung	ɛʁˈkʁaŋkʊŋ
trinkbar	trinkbar	ˈtʁɪŋkbaːʁ
Frankreich	Frank-reich	ˈfʁaŋkʁaɪ̯ç
Kongo	Kongo	ˈkɔŋɡo
Gangrän	Gangrä́n	ɡaŋˈɡʁɛːn
Mangrove	Mangróve	maŋˈɡʁoːvə
Anglikaner	Anglikáner	aŋɡliˈkaːnɐ
Bankett	Bankétt	baŋˈkɛt
Concorde	Konkórd	kɔŋˈkɔʁt
Delinquent	Delinquent	delɪŋˈkvɛnt
Frankierung	Frankierung	fʁaŋˈkiːʁʊŋ
melancholisch	melankólisch	melaŋˈkoːlɪʃ
ingeniös	in.geniös	ɪnɡeˈni̯øːs
Ingredienz	In.gredienz	ɪnɡʁeˈdi̯ɛnt͡s
Inkarnation	In.karnation	ɪnkaʁnaˈt͡si̯oːn
inkohärent	ìn.kohärent	ˌɪnkohɛˈʁɛnt
inkohärent	ín.kohärent	ˈɪnkohɛˌʁɛnt
inkompatibel	in.kompatibel	ɪnkɔmpaˈtiːbəl
inkompatibel	ín.kompatibel	ˈɪnkɔmpaˌtiːbəl
inkompetent	ín.kompətent	ˈɪnkɔmpəˌtɛnt
inkompetent	ìn.kompətent	ˌɪnkɔmpəˈtɛnt

## -ph-
Ableitungsmorphem	Ableitungs-morphém	ˈaplaɪ̯tʊŋsmɔʁˌfeːm
Paragraphenhengst	Paragráphen-hengst	paʁaˈɡʁaːfənˌhɛŋst

## Internal glottal stops
Osterei	Ohster-ei	 ˈoːstɐˌʔaɪ̯
unendlich	unéndlich	ʊnˈʔɛntlɪç
Patholinguistik	Pàtholinguʔístik	ˌpatolɪŋɡuˈʔɪstɪk # dewikt pron #5
Botsuana	Botsuʔána	bɔt͡suˈʔaːna # dewikt pron #2
Aufenthalt	Aufenthalt	ˈaʊ̯f(ʔ)ɛntˌhalt
aalähnlich	aal-ähnlich	ˈaːlˌʔɛːnlɪç
aalartig	aal-ahrtig	ˈaːlˌʔaːʁtɪç # secondary pronunciation ˈaːlˌʔaːʁtɪk will also be shown, with the following: "common form in southern Germany, Austria, and Switzerland"
wiederentdecken	wiederentdecken	ˈviːdɐʔɛntˌdɛkən

## Unstressed -e-
Elektrizität	Elektrizität	elɛktʁit͡siˈtɛːt
Negativität	Nègativität	ˌneɡativiˈtɛːt
Benediktiner	Benədiktíner	benədɪkˈtiːnɐ
Benediktiner	Benediktíner	benedɪkˈtiːnɐ
Idealisierung	Idealisierung	idealiˈziːʁʊŋ
Temperatur	Temperatúr	tɛmpəʁaˈtuːʁ
Generalität	Generalität	ɡenəʁaliˈtɛːt
Souveränität	Souveränität	zuvəʁɛniˈtɛːt
Heterogenität	Heterogenität	hetəʁoɡeniˈtɛːt
Kanzerogenität	Kànzerogenität	ˌkant͡səʁoɡeniˈtɛːt
Immaterialität	Ímmaterialität	ˈɪmatəʁialiˌtɛːt # dewikt (secondary stress not explicitly marked but present in audio)
Immaterialität	Ìmmatêrialität	ˌɪmateʁi̯aliˈtɛːt # enwikt
Pietät	Pìətät	ˌpiːəˈtɛːt
Sozietät	Soziətät	zot͡si̯əˈtɛːt
Varietät	Vari.etät	vaʁieˈtɛːt # dewikt
Varietät	VàrIetät	ˌvaʁi̯eˈtɛːt # enwikt
abalienieren	abalIeniéren	apʔali̯eˈniːʁən
Extremität	Extremität	ɛkstʁemiˈtɛːt
Illegalität	Illegalität	ɪleɡaliˈtɛːt
Illegalität	Íllegalität	ˈɪleɡaliˌtɛːt
Integrität	Integrität	ɪnteɡʁiˈtɛːt
Abbreviation	Abbreviation	abʁevi̯aˈt͡si̯oːn
acetylieren	acetylieren	at͡setyˈliːʁən
akkreditieren	akkreditieren	akʁediˈtiːʁən
ameliorieren	ameliorieren	ameli̯oˈʁiːʁən
anästhesieren	anästhesieren	anɛsteˈziːʁən
degenerieren	degenêrieren	deɡeneˈʁiːʁən # dewikt
degenerieren	degenerieren	deɡenəˈʁiːʁən # enwikt
zumindestens	zumindestens	t͡suˈmɪndəstəns
Latex	Latex	ˈlaːtɛks
Index	Index	ɪndɛks
Alex	Alex	ˈaːlɛks # dewikt; enwikt has short 'a'
Achilles	Achillĕs	aˈxɪlɛs
Adjektiv	Adjektìv	ˈatjɛkˌtiːf
Adjektiv	A*.djektìv	ˈadjɛkˌtiːf # first pronun of enwikt; may be wrong
Adstringens	Adstrin.gĕns	atˈstrɪŋɡɛns
Adverb	Adverb	ˈatvɛʁp
Adverb	Advérb	atˈvɛʁp
Agens	Agĕns	ˈaːɡɛns
Ahmed	Achmedd	ˈaxmɛt
Bizeps	Bizeps	ˈbiːt͡sɛps
Borretsch	Borretsch	bɔʁɛt͡ʃ
Bregenz	Bregenz	ˈbʁeːɡɛnt͡s
Clemens	Klemĕns	ˈkleːmɛns
Daniel	Daniell	ˈdaːni̯ɛl
Dezibel	Dezibell	ˈdeːt͡sibɛl
Diabetes	Di.abétes	diaˈbeːtəs
Diabetes	Di.abétĕs	diaˈbeːtɛs
Dolmetscher	Dolmetscher	ˈdɔlmɛtʃər
Dubstep	Dabstepp	ˈdapstɛp

## Syllable boundary between obstruent and [lr]
Agrobiologie	Agro-bi.ologie	ˈaːɡʁobioloˌɡiː
Algebra	Algebra	ˈalɡebʁa
Algebra	Algébra	alˈɡeːbʁa # Austria
Capri	Kapri	ˈkaːpʁi
deprekativ	deprekativ	depʁekaˈtiːf
deprimierend	deprimierend	depʁiˈmiːʁənt
Ruprecht	Ruprecht	ʁuːpʁɛçt
Ruprecht	Rupprecht	ˈʁʊpʁɛçt
Sopran	Soprán	zoˈpʁaːn
Gabelstapler	Gabel-stapler	ˈɡaːbəlˌʃtaːplɐ
Makler	Makler	ˈmaːklɐ
Deklaration	Dèklaration	ˌdeklaʁaˈt͡si̯oːn
Metrik	Metrik	ˈmeːtʁɪk
Adlatus	Àd.látus	ˌatˈlaːtʊs
Adlatus	Àdlátus	ˌaˈdlaːtʊs
Adler	Adler	ˈaːdlɐ
Bethlehem	Bethlə.hemm	ˈbeːtləhɛm
Detlef	Dettlef	ˈdɛtlɛf
ewiglich	ewiglich	ˈeː.vɪk.lɪç # because -lich is a suffix
Diglossie	Diglossie	diɡlɔˈsiː
Triglyph	Triglýph	tʁiˈɡlyːf
Epiglottis	Epiglóttis	epiˈɡlɔtɪs
Digraph	Digráph	diˈɡʁaːf
Emigrant	Emigrant	emiˈɡʁant
Epigramm	Epigrámm	epiˈɡʁam
filigran	filigrán	filiˈɡʁaːn
Kalligraphie	Kàlligraphie	ˌkaliɡʁaˈfiː
Migräne	Migrä́ne	miˈɡʁɛːnə
Milligramm	Milligràmm	ˈmɪliˌɡʁam
Milligramm	Milligrámm	mɪliˈɡʁam

## Syllable boundary in -kv-, -gv-
Liquid	Liquíd	liˈkviːt
Liquida	Liquida	ˈliːkvida
Mikwe	Mikwé	miˈkveː
Taekwondo	Täkwóndo	tɛˈkvɔndo
Uruguayerin	Ur+ugwayerin	ˈuːʁuɡvaɪ̯əʁɪn

## Syllable boundary in -gn-
Signal	Signal	zɪˈɡnaːl
designieren	designieren	dezɪˈɡniːʁən
Kognition	Koggnition	ˌkɔɡniˈt͡si̯oːn
Kognat	Koggnát	kɔˈɡnaːt
Prognose	Prògnóse	ˌpʁoˈɡnoːzə
orthognath	orthognáth	ɔʁtoˈɡnaːt
prognath	prognáth	pʁoˈɡnaːt
Agnes	Aggnĕs	ˈaɡnɛs # per dewikt
Agnes	Agnes	ˈaːɡnəs # per enwikt
regnen	regnen	ˈʁeːɡnən # enwikt: "prescriptive standard"
regnen	rehg.nen	ˈʁeːknən # enwikt: "most common"
Leugner	Leugner	ˈlɔɪ̯ɡnɐ # prescriptive
Leugner	Leug.ner	ˈlɔɪ̯knɐ # more common
Zeugnis	Zeugnis	ˈt͡sɔɪ̯knɪs # because -nis is a suffix

## Hiatus
Addition	Àddition	ˌadiˈt͡si̯oːn
Historiolinguistik	Històriolinguístik	hɪsˌtoːʁi̯olɪŋˈɡu̯ɪstɪk
Familie	Famíli̯e	faˈmiːli̯ə
Familie	FamílIe	faˈmiːli̯ə
Guerilla	Gerílja	ɡeˈʁɪlja # note short 'i' here but long in [[Familie]]
Ichthyologie	Ichthy̯ologie	ɪçty̯oloˈɡiː
Ichthyologie	IchthYologie	ɪçty̯oloˈɡiː
soigniert	so̯anjiert	zo̯anˈjiːʁt
soigniert	sOanjiert	zo̯anˈjiːʁt

## Unstressed final i
Musikerin	Musickerin	ˈmuːzɪkəʁɪn
Genesis	Genêsis	ˈɡeːnezɪs
Genesis	Gennêsis	ˈɡɛnezɪs
Organik	Orgánik	ɔʁˈɡaːnɪk
Linguistik	Linguístik	lɪŋˈɡu̯ɪstɪk
Linguistik	Lingu.ístik	lɪŋɡuˈɪstɪk
Linguistik	Linguʔístik	lɪŋɡuˈʔɪstɪk
Interim	Interim	ˈɪntəʁɪm
Isegrim	Isəgrim	ˈiːzəɡʁɪm
Joachim	Jóachim	ˈjoːaxɪm
Joachim	Joʔáchim	joˈʔaxɪm
Muslim	Muslim	ˈmʊslɪm
Muslim	Mu*slîm	ˈmuslim
privatim	privátim	pʁiˈvaːtɪm
Achim	Achim	ˈaxɪm
Achim	Achihm	ˈaxiːm
David	David	ˈdaːvɪt
Ingrid	Inggrid	ˈɪŋɡʁɪt # one pronunciation

## Unstressed medial i before g followed by unstressed vowels
Entschuldigung	Entschuldigung	ɛntˈʃʊldɪɡʊŋ
verständigen	verständigen	fɛʁˈʃtɛndɪɡən
Königin	Königin	ˈkøːnɪɡɪn
ängstigend	ängstigend	ˈɛŋstɪɡənt
ewiglich	ewi.glich	ˈeːvɪɡlɪç # explicit syllable boundary prevents suffix

## Unstressed medial i before gn
indigniert	indigniert	ɪndɪˈɡniːʁt
Lignin	Lignín	lɪˈɡniːn

## Unstressed final -us, -um
Kaktus	Kaktus	ˈkaktʊs
Tempus	Tempus	ˈtɛmpʊs
Museum	Museum	muˈzeːʊm

## Unstressed final -on, -os
Aaron	Aaron	ˈaːʁɔn
Abaton	Ab+aton	ˈaːbatɔn
Natron	Natron	ˈnaːtʁɔn
Analogon	Análogon	aˈnaːloɡɔn
Myon	Myon	ˈmyːɔn
Bariton	Barriton	ˈbaʁitɔn
Bariton	Bariton	ˈbaːʁitɔn
Biathlon	Biathlon	ˈbiːatlɔn
Bison	Bison	ˈbiːzɔn
Albatros	Albatros	ˈalbatʁɔs
Amos	Amos	ˈaːmɔs
Amphiprostylos	Àmfipróstylos	ˌamfiˈpʁɔstylɔs
Barbados	Barbádos	baʁˈbaːdɔs
Chaos	Kaos	ˈkaːɔs
Epos	Epos	ˈeːpɔs
Gyros	Gyros	ˈɡyːʁɔs
Heros	Heros	ˈheːʁɔs
Kosmos	Kosmos	ˈkɔsmɔs

## Consonant devoicing
Magd	Mahgd	maːkt
Herbst	Herbst	hɛʁpst

## Compounds
Hubschrauber	Hub-schrauber	ˈhuːpˌʃʁaʊ̯bɐ
Landeplatz	Lande-platz	ˈlandəˌplat͡s
Hubschrauberlandeplatz	Hub-schrauber--lande-platz	ˈhuːpʃʁaʊ̯bɐˌlandəplat͡s
Rundflug	Rund-flug	ˈʁʊntˌfluːk
Hubschrauberrundflug	Hub-schrauber--rund-flug	ˈhuːpʃʁaʊ̯bɐˌʁʊntfluːk
Hubschrauberpilot	Hub-schrauber--pilót	ˈhupʃʁaʊ̯bɐpiˌloːt
Hubschrauberabsturz	Hub-schrauber--absturz	ˈhuːpʃʁaʊ̯bɐˌʔapʃtʊʁt͡s
Maulwurfshügel	Maul-wurf>s--hügel	ˈmaʊ̯lvʊʁfsˌhyːɡəl
Aufenthaltsgenehmigung	Aufenthalt>s-genehmigung	ˈaʊ̯f(ʔ)ɛnthalt͡sɡəˌneːmɪɡʊŋ
Drogenabhängigkeit	Drogen-abhängigkeit	ˈdʁoːɡənˌʔaphɛŋɪçkaɪ̯t
Alkoholabhängigkeit	Alkohól-abhängigkeit	alkoˈhoːlˌʔaphɛŋɪçkaɪ̯t
Alkoholabhängigkeit	Alkohól-abhä́ngigkeit	alkoˈhoːl(ʔ)apˌhɛŋɪçkaɪ̯t
Abkürzungsverzeichnis	Abkürzung>s-verzeichnis	ˈapkʏʁt͡sʊŋsfɛʁˌt͡saɪ̯çnɪs
Abschiedsbrief	Abschied>s-brief	ˈapʃiːt͡sˌbʁiːf
Massenkarambolage	Massen-karamboláʒe	ˈmasənkaʁamboˌlaːʒə
Aufmerksamkeitsdefizit-Hyperaktivitätsstörung	Aufmerksamkeit>s-defizit--Hyper<aktivität>s-störung	ˈaʊ̯fmɛʁkzaːmkaɪ̯t͡sdeːfit͡sɪthypɐʔaktiviˌtɛːt͡sʃtøːʁʊŋ
Donaudampfschifffahrtsgesellschaftskapitän	Donau-dampf-schiff-fahrt>s-gesellschaft>s--kapitä́n	ˈdoːnaʊ̯damp͡fʃɪffaːʁt͡sɡəzɛlʃaft͡skapiˌtɛːn
Eierschalensollbruchstellenverursacher	Eier-schalen--soll-bruch-stellen--verursacher	ˈaɪ̯ɐʃaːlənˌzɔlbʁʊxʃtɛlənfɛʁˌʔuːʁzaxɐ # FIXME: dewikt has primary stress on both 'Eierschalen' and 'sollbruchstellen' rather than secondary stress on the latter.
Kraftfahrzeug-Haftpflichtversicherung	Kraft-fahr-zeug--Haft-pflicht-versicherung	ˈkʁaftfaːʁt͡sɔɪ̯kˌhaftp͡flɪçtfɛʁzɪçəʁʊŋ
neuntausendneunhundertneunundneunzig	neun-tausend--neun-hundert--neun-und--neunzig	ˈnɔɪ̯ntaʊ̯zəntˌnɔɪ̯nhʊndɐtˌnɔɪ̯nʔʊntˌnɔɪ̯nt͡sɪç # FIXME: verify the secondary stresses; not in dewikt
Arbeitsunfähigkeitsbescheinigung	Arbeit>s-unfähigkeit>s--bescheinigung	ˈaʁbaɪ̯t͡sʔʊnfɛːɪçkaɪ̯t͡sbəˌʃaɪ̯nɪɡʊŋ
Schwarzarbeitsbekämpfungsgesetz	Schwarz-arbeit>s--bekämpfung>s--gesetz	ˈʃvaʁt͡sʔaʁbaɪ̯t͡sbəˌkɛmp͡fʊŋsɡəˌzɛt͡s
Aufmerksamkeitsdefizitsyndrom	Aufmerksamkeit>s--defizit-syndróm	ˈaʊ̯fmɛʁkzaːmkaɪ̯t͡sˌdefit͡sɪtzʏndʁoːm
Bauchspeicheldrüsenentzündung	Bauch-speichel-drüsen--entzündung	ˈbaʊ̯xʃpaɪ̯çəldʁyːzn̩(ʔ)ɛntˌt͡sʏndʊŋ
Einzugsermächtigungsverfahren	Einzug>s-ermächtigung>s--verfahren	ˈaɪ̯nt͡suːks(ʔ)ɛʁmɛçtɪɡʊŋsfɛʁˌfaːʁən
Ministerpräsidentenkandidatin	Miníster-präsident>en-kandidátin	miˈnɪstɐpʁɛziˌdɛntənkandiˌdaːtɪn
Streichinstrumentenhersteller	Streich-instrument>en--hersteller	ˈʃtʁaɪ̯ç(ʔ)ɪnstʁumɛntənˌheːʁʃtɛlɐ # FIXME: enwikt has secondary stress on 'instrumenten' and stresses 'hersteller' as 'herstéller'
Geschlechtsidentitätsstörung	Geschlecht>s-identität>s-störung	ɡəˈʃlɛçt͡sʔidɛntiˌtɛːt͡sˌʃtøːʁʊŋ # FIXME: should this be segmented Geschlecht>s-identität>s--störung?
Geschwindigkeitsbeschränkung	Geschwindigkeit>s-beschränkung	ɡəˈʃvɪndɪçkaɪ̯t͡sbəˌʃʁɛŋkʊŋ
Arbeitsbeschaffungsmaßnahme	Arbeits-beschaffungs--maß-nahme	ˈaʁbaɪ̯t͡sbəʃafʊŋsˌmaːsnaːmə
Arbeitsbeschaffungsprogramm	Arbeits-beschaffungs--prográmm	ˈaʁbaɪ̯t͡sbəʃafʊŋspʁoˌɡʁam
Aufenthaltsbestimmungsrecht	Aufenthalts--bestimmungs-recht	ˈaʊ̯f(ʔ)ɛnthalt͡sbəˌʃtɪmʊŋsʁɛçt
Kreuzschlitzschraubenzieher	Kreuz-schlitz--schrauben-zieher	ˈkʁɔɪ̯t͡sʃlɪt͡sˌʃʁaʊ̯bənt͡siːɐ
Meerwasserentsalzungsanlage	Meer-wasser--entsalzungs-anlage	ˈmeːʁvasɐʔɛntˌzalt͡sʊŋsʔanlaːɡə
Nichtregierungsorganisation	Nicht-*regierung>s-organisation	ˌnɪçtʁeˈɡiːʁʊŋs(ʔ)ɔʁɡanizaˌt͡si̯oːn
Sicherheitsvertrauensperson	*Sicherheit>s--*vertrauens-persón	ˈzɪçɐhaɪ̯t͡sfɛʁˈtʁaʊ̯ənspɛʁˌzoːn # FIXME: The double primary stress matches dewikt; correct?
Sprachverschlüsselungsgerät	Sprahch-verschlüsselungs-gerät	ˈʃpʁaːxfɛʁˌʃlʏsəlʊŋsɡəˌʁɛːt
Verschlüsselungsalgorithmus	Verschlüsselungs-algoríthmus	fɛʁˈʃlʏsəlʊŋs(ʔ)alɡoˌʁɪtmʊs
Weltgesundheitsorganisation	Welt-gesundheit>s-organisation	ˈvɛltɡəˌzʊnthaɪ̯t͡s(ʔ)ɔʁɡanizaˌt͡si̯oːn # FIXME: dewikt has no secondary stress on 'organisation'; verify
Hals-Nasen-Ohren-Heilkunde	Hals--Nasen--*Ohren--Heil-kunde	ˌhalsˌnaːzənˈʔoːʁənˌhaɪ̯lkʊndə
Konspirationstheoretikerin	Konspiration>s-theorétikerin	kɔnspiʁaˈt͡si̯oːnsteoˌʁeːtɪkəʁɪn
Kopfsteinpflastersträßchen	Kopf-stein--pflaster-sträßchen	ˈkɔp͡fʃtaɪ̯nˌp͡flastɐʃtrɛːsçən
Literaturwissenschaftlerin	Litteratúr-wissenschaftlerin	lɪtəʁaˈtuːʁˌvɪsənʃaftləʁɪn
Magenschleimhautentzündung	Magen-schleim-haut--entzündung	ˈmaːɡənʃlaɪ̯mhaʊ̯t(ʔ)ɛntˌt͡sʏndʊŋ
Nachrichtenkorrespondentin	Nahch-richten--korrespondéntin	ˈnaːxʁɪçtənkɔʁɛspɔnˌdɛntɪn
Präsidentschaftskandidatin	Präsident>schaft>s-kandidátin	pʁɛziˈdɛntʃaft͡skandiˌdaːtɪn
Rundfunkberichterstatterin	Rund-funk--bericht-erstatterin	ˈʁʊntfʊŋkbəˌʁɪçt(ʔ)ɛʁʃtatəʁɪn
Zusammengehörigkeitsgefühl	Zu<sammen-gehörigkeit>s--gefühl	t͡suˈzamənɡəhøːʁɪçkaɪ̯t͡sɡəˌfyːl
Internationalprozessrecht	Inter<nazional--prozéss-recht	ɪntɐnat͡si̯oˈnaːlpʁoˌt͡sɛsʁɛçt
Lebensabschnittsgefährtin	Lebens-abschnitts-gefährtin	ˈleːbənsˌʔapʃnɪt͡sɡəˌfɛːʁtɪn
Mehrspartenhauseinführung	Mehr-sparten--haus-einführung	ˈmeːʁʃpaʁtənˌhaʊ̯sʔaɪ̯nfyːʁʊŋ
Science-Fiction-Literatur	S*aiens-*Fickschen--Litteratúr	saɪ̯ənsˈfɪkʃənlɪtəʁaˌtuːʁ
Sozialversicherungsnummer	Sozial--versicherungs-nummer	zoˈt͡si̯aːlfɛʁˌzɪçəʁʊŋsnʊmɐ
Textverarbeitungsprogramm	Text-verarbeitungs-prográmm	ˈtɛkstfɛʁˌʔaʁbaɪ̯tʊŋspʁoˌɡʁam
Vervielfältigungszahlwort	Verviel-fältigungs--zahl-wort	fɛʁˈfiːlfɛltɪɡʊŋsˌt͡saːlvɔʁt
Waffenstillstandsabkommen	Waffen-still-stands--abkommen	ˈvafənʃtɪlʃtant͡sˌapkɔmən
Betriebswirtschaftslehre	Betrieb>s-wirtschaft>s--lehre	bəˈtʁiːpsvɪʁtʃaft͡sˌleːʁə
Einschulungsuntersuchung	Einschulungs-unter<suhchung	ˈaɪ̯nʃuːlʊŋs(ʔ)ʊntɐˌzuːxʊŋ
Finanztransaktionssteuer	Finanz-trans<aktion>s-steuer	fiˈnant͡stʁans(ʔ)akˌt͡si̯oːnsˌʃtɔɪ̯ɐ
Fischfrikadellenbrötchen	Fisch-frikadéllen-brötchen	ˈfɪʃfʁikaˌdɛlənˌbʁøːtçən
Kapitalverkehrskontrolle	Kapital-verkehrs--kontrólle	kapiˈtaːlfɛʁkeːʁskɔnˌtʁɔlə
Langzeitarbeitslosigkeit	Lang-zeit--arbeitslosigkeit	ˈlaŋt͡saɪ̯tˌʔaʁbaɪ̯t͡sloːzɪçkaɪ̯t
Lebensmitteleinzelhandel	Lebens-mittel--einzel-handel	ˈleːbənsmɪtəlˌaint͡səlhandəl
Mindesthaltbarkeitsdatum	Mindest-haltbarkeit>s-datum	ˈmɪndəstˌhaltbaːʁkaɪ̯t͡sˌdaːtʊm
Abgassonderuntersuchung	Abgas--sonder-unter<suhchung	ˈapɡaːsˌzɔndɐʊntɐzuːxʊŋ
Eigenverantwortlichkeit	Eigen-verantwortlichkeit	ˈaɪ̯ɡənfɛʁˌʔantvɔʁtlɪçkaɪ̯t
Eisbearbeitungsmaschine	Eis-bearbeitung>s--maschíne	ˈaɪ̯sbəʔaʁbaɪ̯tʊŋsmaˌʃiːnə
Gebühreneinzugszentrale	Gebühren-einzug>s--zentrále	ɡəˈbyːʁənʔaɪ̯nt͡suːkst͡sɛnˌtʁaːlə
Innensechskantschlüssel	Innen-*sechs-kant--schlüssel	ɪnənˈzɛkskantˌʃlʏsəl
Junggesellinnenabschied	Jung-gesellinnen--abschied	ˈjʊŋɡəzɛlɪnənˌʔapʃiːt
Knappschaftskrankenhaus	Knappschaft>s--kranken-haus	ˈknapʃaft͡sˌkʁaŋkənhaʊ̯s
Kopfsteinpflasterstraße	Kopf-stein--pflaster-straße	ˈkɔp͡fʃtaɪ̯nˌp͡flastɐʃtraːsə
Kundgebungsteilnehmerin	Kund-ge+bung>s--teil-nehmerin	ˈkʊntɡeːbʊŋsˌtaɪ̯lneːməʁɪn
Nachrichtenübermittlung	Nahch-richten--über<mittlung	ˈnaːxʁɪçtənʔyːbɐˌmɪtlʊŋ
Medienwissenschaftlerin	MedIen-wissenschaft>lerin	ˈmeːdi̯ənˌvɪsn̩ʃaftləʁɪn
Partizipialkonstruktion	Partizipial-konstruktion	paʁtit͡siˈpi̯aːlkɔnstʁʊkˌt͡si̯oːn
Rezeptor-Bindungsdomäne	Rezéptor-Bindungs-domä́ne	ʁeˈt͡sɛptoːʁˌbɪndʊŋsdoˌmɛːnə
ungerechtfertigterweise	ungerecht-fertigterweise	ˈʊnɡəʁɛçtfɛʁtɪçtɐˌvaɪ̯zə
Untersuchungskommission	Unter<suhchung>s-kommission	ʊntɐˈzuːxʊŋskɔmɪˌsi̯oːn
Zusammenziehungszeichen	Zu<sammen-ziehung>s--zeichen	t͡suˈzamənt͡siːʊŋsˌt͡saɪ̯çən
Basisreproduktionszahl	Basis-reproduktion>s--zahl	ˈbaːzɪsʁepʁodʊkt͡si̯oːnsˌt͡saːl
Determinativkompositum	Determinativ-kompósitum	detɛʁminaˈtiːfkɔmˌpoːzitʊm
Gebärmutterschleimhaut	Gebär-mutter--schleim-haut	ɡəˈbɛːʁmʊtɐˌʃlaɪ̯mhaʊ̯t
Mecklenburg-Vorpommern	Mecklen-burg--*Vorpommern	ˌmɛklənbʊʁkˈfoːʁpɔmɐn
Lebensmittelgroßhandel	Leben>s-mittel--groß-handel	ˈleːbənsmɪtəlˌɡroːshandəl
Hochtemperaturreaktor	Hohch-temperatúr-reáktor	ˈhoːxtɛmpəʁaˌtuːʁʁeˌaktoːʁ
Hochtemperaturreaktor	Hohch-temperatúr-reʔáktor	ˈhoːxtɛmpəʁaˌtuːʁʁeˌʔaktoːʁ
Goldkopflöwenäffchen	Gold-kopf--*löwen-äffchen	ˌɡɔltkɔp͡fˈløːvənʔɛfçən

# --------- Prefix handling ---------

## Cases where prefixes should not be segmented off
Geier	Geier	ˈɡaɪ̯ɐ
Geifer	Geifer	ˈɡaɪ̯fɐ
geifern	geifern	ˈɡaɪ̯fɐn
Geiger	Geiger	ˈɡaɪ̯ɡɐ
Geisel	Geisel	ˈɡaɪ̯zəl
Geisha	Gehscha	ˈɡeːʃa
Geisha	Geischa	ˈɡaɪ̯ʃa
Geisha	GeIscha	ˈɡɛɪ̯ʃa
geißeln	geißeln	ˈɡaɪ̯səln
Geister	Geister	ˈɡaɪ̯stɐ
geizen	geizende	ˈɡaɪ̯t͡səndə
geimpft	ge<impft	ɡəˈʔɪmp͡ft
geuden	géuden	ˈɡɔɪ̯dən
beuteln	beuteln	ˈbɔɪ̯təln
Beugungen	Beugungen	ˈbɔɪ̯ɡʊŋən
geurasst	geurasst	ɡəˈʔuːʁast
geunkt	geunkt	ɡəˈʔʊŋkt
geulkt	geulkt	ɡəˈʔʊlkt
Bede	Bede	ˈbeːdə # too short after be-
Gertrud	Gertrud	ˈɡɛʁtʁuːt # impermissible onset after ge-
Geste	Gehste	ˈɡeːstə # too short after ge-
Geste	Geste	ˈɡɛstə # too short after ge-
Verve	Verve	ˈvɛʁvə # too short after ver-
vorne	forne	ˈfɔʁnə # needs respelling; vor- not recognized
erste	erste	ˈɛʁstə # too short after er-; second pronunciation
ergo	ergo	ˈɛʁɡo # too short after er-
beben	beben	ˈbeːbən # cluster + e + single consonant is too short
Becher	Becher	ˈbɛçɐ # ditto
Erker	Erker	ˈɛʁkɐ # ditto
erzen	erzen	ˈɛʁt͡sən # ditto; second pronunciation
Beleg	Be<leg	bəˈleːk # need respelling to recognize prefix
Gebet	Ge<bet	ɡəˈbeːt # need respelling to recognize prefix
Zukunft	Zukunft	ˈt͡suːˌkʊnft

## ab-
abstellen	abstellen	ˈapˌʃtɛlən
abgelegen	abgelegen	ˈapɡəˌleːɡən
aberkennen	aberkennen	ˈap(ʔ)ɛʁˌkɛnən
abfällig	abfällig	ˈapˌfɛlɪç
abzählbar	abzählbar	ˈapˌt͡sɛːlbaːʁ
ab-	ab-	ˈap
ab	ab	ap
abandonnieren	abandonnieren	abandɔnˈiːʁən
Abbreviation	Abbreviation	abʁevi̯aˈt͡si̯oːn
abundant	abundant	abʊnˈdant
abstrus	abstrús	apˈstʁuːs
Abend	Ab+end	ˈaːbənt
abenteuerdurstig	ab+enteuer-durstig	ˈaːbəntɔɪ̯ɐˌdʊʁstɪç
Aberglaube	Aber-glaube	ˈaːbɐˌɡlaʊ̯bə
Abort	Abort	ˈabˌʔɔʁt
Abort	Abórt	aˈbɔʁt
abaxial	ab<axial	ap(ʔ)aˈksi̯aːl
abalienieren	àb<alIenieren	ˌap(ʔ)ali̯eˈniːʁən

## aneinander-
aneinandergeraten	aneinandergeraten	an(ʔ)aɪ̯ˈnandɐɡəˌʁaːtən
aneinander	aneinander	an(ʔ)aɪ̯ˈnandɐ

## anheim-
anheimfallen	anheimfallen	anˈhaɪ̯mˌfalən
anheimzustellen	anheimzustellen	anˈhaɪ̯mt͡suˌʃtɛlən
anheim	anheim	anˈhaɪ̯m

## an-
anstellen	anstellen	ˈanˌʃtɛlən
anöden	anöden	ˈanˌʔøːdən
anekeln	anekeln	ˈanˌʔeːkəln
anzufangen	anzufangen	ˈant͡suˌfaŋən
angefangen	angefangen	ˈanɡəˌfaŋən
Anerbieten	Anerbieten	ˈan(ʔ)ɛʁˌbiːtən
analog	analóg	anaˈloːk
analysieren	analysieren	analyˈziːʁən
Anglistik	Anglistik	aŋˈɡlɪstɪk
Anonymität	Anonymität	anonymiˈtɛːt
anderer	an+derer	ˈandəʁɐ
Annika	An+nika	ˈanika
anhand	an<hand	anˈhant
Antiheld	Anti.held	ˈantihɛlt

## aufeinander-
aufeinanderzupassende	aufeinanderzupassende	aʊ̯f(ʔ)aɪ̯ˈnandɐt͡suˌpasəndə

## auf-
aufstöbern	aufstöbern	ˈaʊ̯fˌʃtøːbɐn
Auferstehung	Auferstehung	ˈaʊ̯f(ʔ)ɛʁˌʃteːʊŋ

## auseinander-
auseinanderstreben	auseinanderstreben	aʊ̯s(ʔ)aɪ̯ˈnandɐˌʃtʁeːbən
auseinanderentwickeln	auseinanderentwickeln	aʊ̯s(ʔ)aɪ̯ˈnandɐʔɛntˌvɪkəln

## aus-
auszubedingen	auszubedingen	ˈaʊ̯st͡subəˌdɪŋən

## bei-
beieinanderstehen	beieinanderstehen	baɪ̯(ʔ)aɪ̯ˈnandɐˌʃteːən
beisteuernder	beisteuernder	ˈbaɪ̯ˌʃtɔɪ̯ɐndɐ

## be-
beabsichtigen	beabsichtigen	bəˈʔapzɪçtɪɡən
beunruhigen	beunruhigen	bəˈʔʊnˌʁuːɪɡən
beurlauben	beurlauben	bəˈʔuːʁˌlaʊ̯bən

## dafür-
dafürsprechen	dafürsprechen	daˈfyːʁˌʃpʁɛçən
dafürzuhalten	dafürzuhalten	daˈfyːʁt͡suˌhaltən

## dagegen-
dagegenstimmen	dagegenstimmen	daˈɡeːɡənˌʃtɪmən
dagegengehaltenem	dagegengehaltenem	daˈɡeːɡənɡəˌhaltənəm

## daher-
daherreden	daherreden	daˈheːʁˌʁeːdən
daherzureden	daherzureden	daˈheːʁt͡suˌʁeːdən

## dahinter-
dahinterstehen	dahinterstehen	daˈhɪntɐˌʃteːən
dahinterzuknien	dahinterzuknien	daˈhɪntɐt͡suˌkniːn
dahinterzuknieen	dahinterzuknieen	daˈhɪntɐt͡suˌkniːən # FIXME, make sure this works

## dahin-
dahingehen	dahingehen	daˈhɪnˌɡeːən
dahinvegetieren	dahinvegetieren	daˈhɪnveɡeˌtiːʁən

## daneben-
danebengeraten	danebengeraten	daˈneːbənɡəˌʁaːtən
danebenzubenehmen	danebenzubenehmen	daˈneːbənt͡subəˌneːmən

## dar-
darstellen	darstellen	ˈdaːʁˌʃtɛlən
Darbietung	Darbietung	ˈdaːʁˌbiːtʊŋ
darzutun	darzutun	ˈdaːʁt͡suˌtuːn
darüber	darǘber	daˈʁyːbɐ

## davon-
davonstehlen	davonstehlen	daˈfɔnˌʃteːlən
davongejagte	davongejag>te	daˈfɔnɡəˌjaːktə

## davor-
davorstellen	davorstellen	daˈfoːʁˌʃtɛlən
davorzuhängen	davorzuhängen	daˈfoːʁt͡suˌhɛŋən

## dazu-
dazuaddieren	dazuaddieren	daˈt͡suːʔaˌdiːʁən
dazuzugehören	dazuzugehören	daˈt͡suːt͡suɡəˌhøːʁən

## durcheinander-
durcheinanderessen	durcheinanderessen	dʊʁç(ʔ)aɪ̯ˈnandɐˌʔɛsən

## durch-
durchschlagen	durchschlagen	ˈdʊʁçˌʃlaːɡən
durchschlagen	durch<schlagen	dʊʁçˈʃlaːɡən
durchbekommenes	durchbekommenes	ˈdʊʁçbəˌkɔmənəs
Durchmesser	Durchmesser	ˈdʊʁçˌmɛsɐ
Durchschnittsmensch	Durchschnitt>s-mensch	ˈdʊʁçʃnɪt͡sˌmɛnʃ

## ein-
einstellen	einstellen	ˈaɪ̯nˌʃtɛlən
einzubestellendem	einzubestellendem	ˈaɪ̯nt͡subəˌʃtɛləndəm
Einstein	Einstein	ˈaɪ̯nˌʃtaɪ̯n
Eintrag	Eintrag	ˈaɪ̯nˌtʁaːk
Einzelzimmer	Einzel-zimmer	ˈaɪ̯nt͡səlˌt͡sɪmɐ # "zel" is too short of a main part for "Ein-" to be partitioned off here.

## empor-
emporsteigen	emporsteigen	ɛmˈpoːʁˌʃtaɪ̯ɡən
emporgearbeiteter	emporgearbeiteter	ɛmˈpoːʁɡəˌʔaʁbaɪ̯tətɐ
Emporium	Empóri.um	ɛmˈpoːʁiʊm

## emp-
empirisch	empírisch	ɛmˈpiːʁɪʃ
emphatisch	emphátisch	ɛmˈfaːtɪʃ
Empfang	Empfang	ɛmpˈfaŋ
Empfindsamkeit	Empfindsamkeit	ɛmpˈfɪntzaːmˌkaɪ̯t

## entgegen-
entgegensehen	entgegensehen	ɛntˈɡeːɡənˌzeːən
entgegenzustrecken	entgegenzustrecken	ɛntˈɡeːɡənt͡suˌʃtʁɛkən
entgegen-	entgegen-	ɛntˈɡeːɡən

## entlang-
entlangeilen	entlangeilen	ɛntˈlaŋˌʔaɪ̯lən
entlangmarschieren	entlangmarschieren	ɛntˈlaŋmaʁˌʃiːʁən

## entzwei-
entzweispringen	entzweispringen	ɛntˈt͡svaɪ̯ˌʃpʁɪŋən
entzweigegangen	entzweigegangen	ɛntˈt͡svaɪ̯ɡəˌɡaŋən

## ent-
entsprechend	entsprechend	ɛntˈʃpʁɛçənt
entscheiden	entscheiden	ɛntˈʃaɪ̯dən

## er-
Ergebnis	Ergebnis	ɛʁˈɡeːpnɪs
erarbeiten	erarbeiten	ɛʁˈʔaʁbaɪ̯tən
errackern	errackern	ɛʁˈʁakɐn

## fort-
fortbewegen	fortbewegen	ˈfɔʁtbəˌveːɡən
Fortentwicklung	Fortentwicklung	ˈfɔʁt(ʔ)ɛntˌvɪklʊŋ
fortstoßen	fortstoßen	ˈfɔʁtˌʃtoːsən

## gegenüber-
gegenüberstehen	gegenüberstehen	ɡeːɡənˈʔyːbɐˌʃteːən
gegenübergesessen	gegenübergesessen	ɡeːɡənˈʔyːbɐɡəˌzɛsən

## herab-
herabstürzen	herabstürzen	hɛˈʁapˌʃtʏʁt͡sən
herabgestuft	herabgestuf>t	hɛˈʁapɡəˌʃtuːft

## heran-
herantasten	herantasten	hɛˈʁanˌtastən
Herangewanze	Herangewanze	hɛˈʁanɡəˌvant͡sə

## herauf-
heraufbefördernd	heraufbefördernd	hɛˈʁaʊ̯fbəˌfœʁdɐnt
herauffahren	herauffahren	hɛˈʁaʊ̯fˌfaːʁən
heraufzubeschwörendes	heraufzubeschwörendes	hɛˈʁaʊ̯ft͡subəˌʃvøːʁəndəs

## heraus-
herausstellen	herausstellen	hɛˈʁaʊ̯sˌʃtɛlən

## herbei-
herbeieilen	herbeieilen	hɛʁˈbaɪ̯ˌʔaɪ̯lən
herbeigeschafft	herbeigeschafft	hɛʁˈbaɪ̯ɡəˌʃaft

## herein-
hereinsteckendes	hereinsteckendes	hɛˈʁaɪ̯nˌʃtɛkəndəs
hereinzugeheimnissen	hereinzugeheimnissen	hɛˈʁaɪ̯nt͡suɡəˌhaɪ̯mnɪsən

## hernieder-
herniederregnen	herniederregnen	hɛʁˈniːdɐˌʁeːɡnən
herniederzubrechen	herniederzubrechen	hɛʁˈniːdɐt͡suˌbʁɛçən

## herüber-
herübergefahren	herübergefahren	hɛˈʁyːbɐɡəˌfaːʁən
herüberzuwechseln	herüberzuwechseln	hɛˈʁyːbɐt͡suˌvɛksəln

## herum-
herumscharwenzeln	herumscharwènzeln	hɛˈʁʊmʃaʁˌvɛnt͡səln
herumspinnen	herumspinnen	hɛˈʁʊmˌʃpɪnən
herumexperimentieren	herumexpêrimentieren	hɛˈʁʊm(ʔ)ɛkspeʁimɛnˌtiːʁən
herumeiernde	herumeiernde	hɛˈʁʊmˌʔaɪ̯ɐndə
herumzuerzählen	herumzuerzählen	hɛˈʁʊmt͡suʔɛʁˌt͡sɛːlən

## herunter-
herunterspielen	herunterspielen	hɛˈʁʊntɐˌʃpiːlən
herunterzuhandeln	herunterzuhandeln	hɛˈʁʊntɐt͡suˌhandəln

## hervor-
hervorstechen	hervorstechen	hɛʁˈfoːʁˌʃtɛçən

## her-
herstellen	herstellen	ˈheːʁˌʃtɛlən
hergebetene	hergebetene	ˈheːʁɡəˌbeːtənə
hereditär	hereditär	heʁediˈtɛːʁ
heraldik	heráldik	heˈʁaldɪk
Herkules	Her+kulĕs	ˈhɛʁkulɛs
Herberge	Hérberge	ˈhɛʁbɛʁɡə

## hinab-
hinabsteigen	hinabsteigen	hɪˈnapˌʃtaɪ̯ɡən
hinabbaumele	hinabbaumele	hɪˈnapˌbaʊ̯mələ

## hinan-
hinangearbeitetes	hinangearbeitetes	hɪˈnanɡəˌʔaʁbaɪ̯tətəs

## hinauf-
hinaufsteigen	hinaufsteigen	hɪˈnaʊ̯fˌʃtaɪ̯ɡən
hinaufgestiegener	hinaufgestiegener	hɪˈnaʊ̯fɡəˌʃtiːɡənɐ

## hinaus-
hinauskatapultieren	hinauskatapultieren	hɪˈnaʊ̯skatapʊlˌtiːʁən
hinausposaunen	hinausposàunen	hɪˈnaʊ̯spoˌzaʊ̯nən
hinauszuposaunen	hinauszuposàunen	hɪˈnaʊ̯st͡supoˌzaʊ̯nən

## hindurch-
hindurchbewegen	hindurchbewegen	hɪnˈdʊʁçbəˌvəɡən

## hinein-
hineinstecken	hineinstecken	hɪˈnaɪ̯nˌʃtɛkən
hineingebären	hineingebären	hɪˈnaɪ̯nɡəˌbɛːʁən

## hintan-
hintanstellen	hintanstellen	hɪntˈʔanˌʃtɛlən
hintangehalten	hintangehalten	hɪntˈʔanɡəˌhaltən

## hinterher-
hinterherhinken	hinterherhinken	hɪntɐˈheːʁˌhɪŋkən
hinterherspionieren	hinterherspionieren	hɪntɐˈheːʁʃpi̯oˌniːʁən
hinterherzugehen	hinterherzugehen	hɪntɐˈheːʁt͡suˌɡeːən

## hinter-
Hintergedanke	Hintergedanke	ˈhɪntɐɡəˌdaŋkə
Hinterwäldler	Hinterwäld.ler	ˈhɪntɐˌvɛltlɐ

## hinüber-
hinüberbefördern	hinüberbefördern	hɪˈnyːbɐbəˌfœʁdɐn

## hinunter-
hinunterbekommen	hinunterbekommen	hɪˈnʊntɐbəˌkɔmən

## hinweg-
hinwegmarschieren	hinwegmarschieren	hɪnˈvɛkmaʁˌʃiːʁən
hinwegsehen	hinwegsehen	hɪnˈvɛkˌzeːən

## hin-
hinkriegen	hinkriegen	ˈhɪnˌkʁiːɡən

## miss-
missachten	miss<achten	mɪsˈʔaxtən
missbrauchen	miss<brauchen	mɪsˈbʁaʊ̯xən
missinterpretieren	missintərpretieren	ˈmɪs(ʔ)ɪntɐpʁeˌtiːʁən
missgestaltet	missgestaltet	ˈmɪsɡəˌʃtaltət
Missverständnis	Missverständnis	ˈmɪsfɛʁˌʃtɛntnɪs

## mit-
mitbestimmen	mitbestimmen	ˈmɪtbəˌʃtɪmən
mitteilen	mitteilen	ˈmɪtˌtaɪ̯lən
mitansehen	mit<ansehen	mɪtˈʔanˌzeːən
mitanzugebenden	mit<anzuge+benden	mɪtˈʔant͡suˌɡeːbəndən
Mittag	Mit+tag	ˈmɪtaːk
mitigieren	mitigieren	mitiˈɡiːʁən

## nach-
nachalarmieren	nachalarmieren	ˈnaːx(ʔ)alaʁˌmiːʁən
nachversteuern	nachversteuern	ˈnaːxfɛʁˌʃtɔɪ̯ɐn
nachschlägt	nachschläg>t	ˈnaːxˌʃlɛːkt
Nachentgelt	Nachentgelt	ˈnaːx(ʔ)ɛntˌɡɛlt
nachzuvollziehen	nachzufollzìehen	ˈnaːxt͡sufɔlˌt͡siːən

## nieder-
niederstürzen	niederstürzen	ˈniːdɐˌʃtʏʁt͡sən
niederzuzerren	niederzuzerren	ˈniːdɐt͡suˌt͡sɛʁən

## übereinander-
übereinanderstapeln	übereinanderstapeln	yːbɐʔaɪ̯ˈnandɐˌʃtaːpəln
übereinanderzuschlagenden	übereinanderzuschlagenden	yːbɐʔaɪ̯ˈnandɐt͡suˌʃlaːɡəndən

## über-
überfahren	überfahren	ˈyːbɐˌfaːʁən
überfahren	über<fahren	yːbɐˈfaːʁən # über- should be recognized, translated to ǘber- and then to ü̏ber- (i.e. with double grave), so that length is preserved.
überdimensionieren	überdimensionieren	ˈyːbɐdimɛnzi̯oˌniːʁən
überholt	ǜberhol>t	ˌyːbɐˈhoːlt # über- should still be recognized with secondary stress on it.
übereinstimmen	über<einstimmen	yːbɐˈʔaɪ̯nˌʃtɪmən
überanstrengen	über<anstrengen	yːbɐˈʔanˌʃtʁɛŋən
überbeanspruchen	überbeanspruchen	ˈyːbɐbəˌʔanʃpʁʊxən
überzubeanspruchen	überzubeanspruchen	ˈyːbɐt͡subəˌʔanʃpʁʊxən
Überangebot	Über-angebot	ˈyːbɐˌʔanɡəboːt

## um-
umfahren	umfahren	ˈʊmˌfaːʁən # to "drive over", "to knock down by driving"
umfahren	um<fahren	ʊmˈfaːʁən # to "drive around", "to bypass"
umzustrukturieren	umzustrukturieren	ˈʊmt͡suʃtʁʊktuˌʁiːʁən
umzustrukturieren	umzus*trukturieren	ˈʊmt͡sustʁʊktuˌʁiːʁən
umzuerziehende	umzuerziehende	ˈʊmt͡suʔɛʁˌt͡siːəndə
Umgebindehaus	Umgebinde-haus	ˈʊmɡəbɪndəˌhaʊ̯s

## un-
ungar	ungar	ˈʊnˌɡaːʁ
Ungar	Un+gar	ˈʊŋɡaʁ
unglaublich	unglaublich	ˈʊnɡlaʊ̯plɪç
unglaublich	ungláublich	ʊnˈɡlaʊ̯plɪç
ungebremst	ungebremst	ˈʊnɡəˌbʁɛmst
ungelöst	ungelös>t	ˈʊnɡəˌløːst
unartig	unahrtig	ˈʊnˌʔaːʁtɪç
unanständig	unanständig	ˈʊnʔanˌʃtɛndɪç
unpathetisch	unpathètisch	ˈʊnpaˌteːtɪʃ
ungrammatisch	ungrammàttisch	ˈʊnɡʁaˌmatɪʃ
unprätentiös	unprätentiös	ˈʊnpʁɛtɛnˌt͡si̯øːs
unsexy	uns*exi	ˈʊnˌsɛksi
unislamisch	unislàmisch	ˈʊn(ʔ)ɪsˌlaːmɪʃ
unorthodox	unorthodòx	ˈʊn(ʔ)ɔʁtoˌdɔks
unangenehm	unangenehm	ˈʊnʔanɡəˌneːm
unausgegoren	unausgegoren	ˈʊnʔaʊ̯sɡəˌɡoːʁən
unkaputtbar	unkapúttbar	ʊnkaˈpʊtbaːʁ # not /ʊŋ-/
unkalkulierbar	unkalkulierbar	ˈʊnkalkuˌliːʁbaːʁ
unkalkulierbar	ùnkalkulierbar	ˌʊnkalkuˈliːʁbaːʁ # un- should be recognized even with secondary stress. We should not get /ʊŋ-/ or /un-/.
unzerstörbar	unzerstörbar	ˈʊnt͡sɛʁˌʃtøːʁbaːʁ
unzerstörbar	unzerstö́rbar	ʊnt͡sɛʁˈʃtøːʁbaːʁ
unzerstörbar	ùnzerstörbar	ˌʊnt͡sɛʁˈʃtøːʁbaːʁ
undulös	un+dulös	ʊnduˈløːs
unieren	un+ieren	uˈniːʁən
Uniform	Un+nifòrm	ˈʊniˌfɔʁm
unikal	ùn+ickal	ˌunɪˈkaːl
universal	un+iversal	univɛʁˈzaːl
Universität	Ùn+iversität	ˌunivɛʁziˈtɛːt
Union	Un+ion	uˈni̯oːn

## ur-
Urlaub	Urlaub	ˈuːʁˌlaʊ̯p
Ursache	Ursache	ˈuːʁˌzaxə
Urszene	Urszene	ˈuːʁˌst͡senə
uramerikanisch	uramêrikànisch	ˈuːʁ(ʔ)ameʁiˌkaːnɪʃ
uraufgeführt	uraufgeführt	ˈuːʁʔaʊ̯fɡəˌfyːʁt
Urvertrauen	Urvertrauen	ˈuːʁfɛʁˌtʁaʊ̯ən
Urethan	Urethán	uʁeˈtaːn # ur- should not be segmented due to following primary stress
urbanisieren	urbanisieren	ʊʁbaniˈziːʁən # ur- should not be segmented due to following primary stress
Uranus	Ur+anus	ˈuːʁanʊs
uruguayisch	ur+ugwayisch	ˈuːʁuɡvaɪ̯ɪʃ

## ver-
veranlagen	veranlagen	fɛʁˈʔanlaːɡən
verunglücken	verunglücken	fɛʁˈʔʊnɡlʏkən
Verunreinigung	Verunreinigung	fɛʁˈʔʊnˌʁaɪ̯nɪɡʊŋ
verunstalten	verunstalten	fɛʁˈʔʊnˌʃtaltən
verträglich	verträglich	fɛʁˌtʁɛːklɪç
versiert	ver+siert	vɛʁˈziːʁt
vertiert	vertiert	fɛʁˈtiːʁt
vertretbar	vertretbar	fɛʁˈtʁeːtbaːʁ

## zueinander-
zueinandergehalten	zueinandergehalten	t͡suʔaɪ̯ˈnandɐɡəˌhaltən
zueinanderzufinden	zueinanderzufinden	t͡suʔaɪ̯ˈnandɐt͡suˌfɪndən

## zurecht-
zurechtrücken	zurechtrücken	t͡suˈʁɛçtˌʁʏkən
zurechtzubekommen	zurechtzubekommen	t͡suˈʁɛçtt͡subəˌkɔmən

## zurück-
zurückstecken	zurückstecken	t͡suˈʁʏkˌʃtɛkən
zurückverlegt	zurückverleg>t	t͡suˈʁʏkfɛʁˌleːkt
zurückerstatten	zurückerstatten	t͡suˈʁʏk(ʔ)ɛʁˌʃtatən
zurücküberweisen	zurücküberweisen	t͡suˈʁʏk(ʔ)yːbɐˌvaɪ̯zən
zurückzuüberweisen	zurückzuüberweisen	t͡suˈʁʏkt͡su(ʔ)yːbɐˌvaɪ̯zən

## zusammen-
Zusammenspiel	Zusammenspiel	t͡suˈzamənˌʃpiːl
zusammenarbeitetest	zusammenarbeitetest	t͡suˈzamənˌʔaʁbaɪ̯tətəst
zusammenveranlagtem	zusammenveranlag>tem	t͡suˈzamənfɛʁˌʔanlaːktəm
zusammenzuveranlagender	zusammenzuveranlagender	t͡suˈzamənt͡sufɛʁˌʔanlaːɡəndɐ
zusammenzuaddierendes	zusammenzuaddierendes	t͡suˈzamənt͡suʔaˌdiːʁəndəs

## zu-
zuständig	zuständig	ˈt͡suːˌʃtɛndɪç
zugetan	zugetan	ˈt͡suːɡəˌtaːn
zugespitzt	zugespitzt	ˈt͡suːɡəˌʃpɪt͡st
zuzugestehen	zuzugestehen	ˈt͡suːt͡suɡəˌʃteːən

## zwischen-
Zwischenbemerkung	Zwischenbemerkung	ˈt͡svɪʃənbəˌmɛʁkʊŋ
zwischengeschlechtlich	zwischengeschlechtlich	ˈt͡svɪʃənɡəˌʃlɛçtlɪç

## Explicitly indicated prefixes
inakzeptabel	inn-akzeptabel	ˈɪn(ʔ)akt͡sɛpˌtaːbl̩ # -abel is a recognized suffix
ineffizient	inn-effizient	ˈɪn(ʔ)ɛfiˌt͡si̯ɛnt # -ent is a recognized suffix
ineffizient	inn-effiziént	ˈɪn(ʔ)ɛfiˌt͡si̯ɛnt


# --------- Suffix handling ---------

## -erweise
möglicherweise	möglicherweise	ˈmøːklɪçɐˈvaɪ̯zə
unfreundlicherweise	unfreundlicherweise	ˈʔʊnfʁɔɪ̯ntlɪçɐˌvaɪ̯zə
seltsamerweise	seltsamerweise	ˈzɛltzaːmɐˌvaɪ̯zə
ungerechterweise	ungerechterweise	ˈʊnɡəʁɛçtɐˌvaɪ̯zə
ungewöhnlicherweise	ungewöhnlicherweise	ˈʊnɡəvøːnlɪçɐˌvaɪ̯zə
unzulässigerweise	unzulässigerweise	ˈʊnt͡sulɛsɪɡɐˌvaɪ̯zə
verbotenerweise	verbotenerweise	fɛʁˈboːtənɐˌvaɪ̯zə

## -fest
bissfest	bissfest	ˈbɪsˌfɛst
wasserfest	wasserfest	ˈvasɐˌfɛst
witterungsfest	witterungsfest	ˈvɪtəʁʊŋsˌfɛst

## -frei
bleifrei	bleifrei	ˈblaɪ̯ˌfʁaɪ̯
alkoholfrei	alkohólfrei	alkoˈhoːlˌfʁaɪ̯
bündnisfrei	bündnisfrei	ˈbʏntnɪsˌfʁaɪ̯
einwandfrei	einwandfrei	ˈaɪ̯nvantˌfʁaɪ̯
schneefrei	schneefrei	ˈʃneːˌfʁaɪ̯
straffrei	straffrei	ˈʃtʁaːfˌfʁaɪ̯
unfallfrei	unfallfrei	ˈʊnfalˌfʁaɪ̯
vibrationsfrei	vibration>s>>frei	vibʁaˈt͡si̯oːnsˌfʁaɪ̯
niederschlagsfrei	niederschlag>s>>frei	ˈniːdɐʃlaːksˌfʁaɪ̯
holzschlifffrei	holz-schlifffrei	ˈhɔlt͡sʃlɪfˌfʁaɪ̯
versandkostenfrei	versand-kostenfrei	fɛʁˈzantkɔstənˌfʁaɪ̯

## -losigkeit
Reglosigkeit	Reglosigkeit	ˈʁeːkˌloːzɪçkaɪ̯t
Arbeitslosigkeit	Arbeitslosigkeit	ˈaʁbaɪ̯t͡sˌloːzɪçkaɪ̯t
Ausnahmslosigkeit	Ausnahmslosigkeit	ˈaʊ̯snaːmsˌloːzɪçkaɪ̯t
Bedeutungslosigkeit	Bedeutungslosigkeit	bəˈdɔɪ̯tʊŋsˌloːzɪçkaɪ̯t
Charakterlosigkeit	Karákterlosigkeit	kaˈʁaktɐˌloːzɪçkaɪ̯t
Gefühllosigkeit	Gefühllosigkeit	ɡəˈfyːlˌloːzɪçkaɪ̯t
Jugendarbeitslosigkeit	Jugend--arbeitslosigkeit	ˈjuːɡəntˌʔaʁbaɪ̯t͡sloːzɪçkaɪ̯t
Obdachlosigkeit	Ob-dachlosigkeit	ˈɔpdaxˌloːzɪçkaɪ̯t
Ruchlosigkeit	Ruhchlosigkeit	ˈʁuːxˌloːzɪçkaɪ̯t
Ruchlosigkeit	Ruchlosigkeit	ˈʁʊxˌloːzɪçkaɪ̯t
Schlaflosigkeit	Schlaflosigkeit	ˈʃlaːfˌloːzɪçkaɪ̯t
Teilnahmslosigkeit	Teil-nahmslosigkeit	ˈtaɪ̯lnaːmsˌloːzɪçkaɪ̯t
Pietätlosigkeit	Piːetä́tlosigkeit	piːeˈtɛːtˌlozɪçkaɪ̯t
Willenlosigkeit	Willenlosigkeit	ˈvɪlənˌloːzɪçkaɪ̯t

## -los
arglos	arglos	ˈaʁkˌloːs
fraglos	fraglos	ˈfʁaːkˌloːs
gottlos	gottlos	ˈɡɔtˌloːs
kopflos	kopflos	ˈkɔp͡fˌloːs
planlos	planlos	ˈplaːnˌloːs
reglos	reglos	ˈʁeːkˌloːs
stillos	stillos	ˈʃtiːlˌloːs
stillos	s*tillos	ˈstiːlˌloːs
atemlos	atemlos	ˈaːtəmˌloːs
konkurrenzlos	konkurrenzlos	kɔŋkʊˈʁɛnt͡sˌloːs
papierlos	papíerlos	paˈpiːʁˌloːs
systemlos	systémlos	zʏsˈteːmˌloːs
kontrolllos	kontrólllos	kɔnˈtʁɔlˌloːs
bedingungslos	bedingungslos	bəˈdɪŋʊŋsˌloːs
besitzlos	besitzlos	bəˈzɪt͡sˌloːs
ersatzlos	ersatzlos	ɛʁˈzat͡sˌloːs
gefühllos	gefühllos	ɡəˈfyːlˌloːs
gesichtslos	gesichtslos	ɡəˈzɪçt͡sˌloːs
anstandslos	anstandslos	ˈanʃtant͡sˌloːs
ausdruckslos	ausdruckslos	ˈaʊ̯sdʁʊksˌloːs
ausweglos	ausweglos	ˈaʊ̯sveːkˌloːs
einflusslos	einflusslos	ˈaɪ̯nflʊsˌloːs
alternativlos	alternatívlos	altɛʁnaˈtiːfˌloːs
bargeldlos	bar-geldlos	ˈbaːʁɡɛltˌloːs
inhaltslos	in-haltslos	ˈɪnhalt͡sˌloːs

## -reich
geistreich	geistreich	ˈɡaɪ̯stˌʁaɪ̯ç
glorreich	glorreich	ˈɡloːʁˌʁaɪ̯ç
siegreich	siegreich	ˈziːkˌʁaɪ̯ç
tugendreich	tugendreich	ˈtuːɡəntˌʁaɪ̯ç
verlustreich	verlustreich	fɛʁˈlʊstˌʁaɪ̯ç
anregungsreich	anregungsreich	ˈanʁeːɡʊŋsˌʁaɪ̯ç
einfallsreich	einfallsreich	ˈaɪ̯nfalsˌʁaɪ̯ç
einwohnerreich	einwohnerreich	ˈaɪ̯nvoːnɐˌʁaɪ̯ç
kohlenhydratreich	kohlen-hydrátreich	ˈkoːlənhydʁaːtˌʁaɪ̯ç
niederschlagsreich	niederschlag>s>>reich	ˈniːdɐʃlaːksˌʁaɪ̯ç

## -voll
kraftvoll	kraftvoll	ˈkʁaftˌfɔl
gramvoll	gramvoll	ˈɡʁaːmˌfɔl
qualvoll	qualvoll	ˈkvaːlˌfɔl
respektvoll	respéktvoll	ʁeˈspɛktˌfɔl
humorvoll	humórvoll	huˈmoːʁˌfɔl
gefühlvoll	gefühlvoll	ɡəˈfyːlˌfɔl
geräuschvoll	geräuschvoll	ɡəˈʁɔɪ̯ʃˌfɔl
geheimnisvoll	geheimnisvoll	ɡəˈhaɪ̯mnɪsˌfɔl
wundervoll	wundervoll	ˈvʊndɐˌfɔl
eindrucksvoll	eindrucksvoll	ˈaɪ̯ndʁʊksˌfɔl
verantwortungsvoll	verantwortungsvoll	fɛʁˈʔantvɔʁtʊŋsˌfɔl
rücksichtsvoll	rück-sichtsvoll	ˈʁʏkzɪçt͡sˌfɔl
unheilvoll	unheilvoll	ˈʊnhaɪ̯lˌfɔl
unschuldsvoll	unschuldsvoll	ˈʊnʃʊlt͡sˌfɔl

## -weise
stückweise	stückweise	ˈʃtʏkˌvaɪ̯zə
teilweise	teilweise	ˈtaɪ̯lˌvaɪ̯zə
leihweise	leihweise	ˈlaɪ̯ˌvaɪ̯zə
zwangsweise	zwangsweise	ˈt͡svaŋsˌvaɪ̯zə
haufenweise	haufenweise	ˈhaʊ̯fənˌvaɪ̯zə
probeweise	probeweise	ˈpʁoːbəˌvaɪ̯zə
quartalsweise	quartal>s>>weise	kvaʁˈtaːlsˌvaɪ̯zə
versuchsweise	versuhch>s>>weise	fɛʁˈzuːxsˌvaɪ̯zə
abschnittweise	abschnittweise	ˈapʃnɪtˌvaɪ̯zə
ansatzweise	ansatzweise	ˈanzat͡sˌvaɪ̯zə
ausnahmsweise	ausnahmsweise	ˈaʊ̯snaːmsˌvaɪ̯zə
beispielsweise	beispielsweise	ˈbaɪ̯ʃpiːlsˌvaɪ̯zə
allerleiweise	aller>lei>>weise	ˈalɐlaɪ̯ˌvaɪ̯zə
esslöffelweise	ess-löffelweise	ˈɛslœfl̩ˌvaɪ̯zə
scheibchenweise	scheibchenweise	ˈʃaɪ̯bçənˌvaɪ̯zə # FIXME: make sure this works!

## -ant
Emigrant	Emigrant	emiˈɡʁant
tolerant	tolerant	toləˈʁant

## -anz
Abglanz	Abglanz	ˈapˌɡlant͡s # main part too short to be interpreted as suffix
Akzeptanz	Akzeptanz	akt͡sɛpˈtant͡s
Allianz	Allianz	aˈli̯ant͡s

## -abel, -ibel
Bratengabel	Braten-gabel	ˈbʁaːtənˌɡaːbəl # main part too short to be interpreted as suffix
deplorabel	deplorabel	deploˈʁaːbəl
Dezibel	Dezi-bel	ˈdeːt͡siˌbɛl
disponibel	disponibel	dɪspoˈniːbəl

## -al
Doppelmoral	Doppel-moral	ˈdɔpəlmoˌʁaːl
dorsal	dorsal	dɔʁˈzaːl
manchmal	mánchmal	ˈmançmaːl
manchmal	manch>mal	ˈmançmaːl
optimal	optimal	ɔptiˈmaːl

## -tionär
Revolutionär	Revolutionär	ʁevolut͡si̯oˈnɛːʁ
quasistationär	quasi-stationär	ˈkvaːziʃtat͡si̯oˌnɛːʁ

## -är
singulär	singulär	zɪŋɡuˈlɛːʁ
intermediär	inter<mediär	ɪntɐmeˈdi̯ɛːʁ
Veterinär	Veterinär	vetəʁiˈnɛːʁ
unpopulär	unpopulär	ˈʊnpopuˌlɛːʁ

## -ierbar
realisierbar	realisierbar	ʁealiˈziːʁbaːʁ
prognostizierbar	prognostizierbar	pʁoɡnɔstiˈt͡siːʁbaːʁ
undefinierbar	undefinierbar	ˈʊndefiˌniːʁbaːʁ
undefinierbar	undefiniérbar	ʊndefiˈniːʁbaːʁ

## -bar
strafbar	strafbar	ˈʃtʁaːfbaːʁ
jagdbar	jahgdbar	ˈjaːktbaːʁ
abbaubar	abbaubar	ˈapˌbaʊ̯baːʁ
unbesiegbar	ùnbesiegbar	ˌʊnbəˈziːkbaːʁ
unbesiegbar	unbesiegbar	ˈʊnbəˌziːkbaːʁ
unüberschaubar	ùnüberscháubar	ˌʊnʔyːbɐˈʃaʊ̯baːʁ
unüberschaubar	unüberschaubar	ˈʊnʔyːbɐˌʃaʊ̯baːʁ
unauffindbar	unauffíndbar	ʊnʔaʊ̯fˈfɪntbaːʁ
recyclebar	rißáikelbar	ʁiˈsaɪ̯kəlˌbaːʁ
downloadbar	daun-loUdbar	ˈdaʊ̯nˌlɔʊ̯tbaːʁ
downloadbar	daun-lodbar	ˈdaʊ̯nˌloːtbaːʁ
isobar	isobár	izoˈbaːʁ

## -chen
Mädchen	Mädchen	ˈmɛːtçən
Hörnchen	Hörnchen	ˈhœʁnçən
Ehefrauchen	Ehe-frau>chen	ˈeːəˌfʁaʊ̯çən # use > to explicitly denote a suffix
Opachen	Opa>chen	ˈoːpaçən
Wodkachen	Wodka>chen	ˈvɔtkaçən
Verschen	Fers>chen	fɛʁsçən
Häuschen	Häus>chen	ˈhɔɪ̯sçən
Bläschen	Bläs>chen	ˈblɛːsçən
Füchschen	Füchs>chen	ˈfʏksçən
Gänschen	Gäns>chen	ˈɡɛnsçən
bisschen	bisschen	ˈbɪsçən
horchen	horchen	ˈhɔʁçən # -chen only recognized with an initial capital
wachen	wachen	ˈvaxən # ditto
Schnarchen	Schnar+chen	ˈʃnaʁçən # -chen is not a suffix here; without the +, -a- would be long
Freimachen	Frei-machen	ˈfʁaɪ̯ˌmaxən # -chen is not recognized as a suffix after a vowel, and is only recognized in nouns (beginning with a capital letter)
Kaputtmachen	Kapútt-machen	kaˈpʊtˌmaxən
Verachtfachen	Veracht-fachen	fɛʁˈʔaxtˌfaxən
Verfünfzehnfachen	Verfünf-zehn--fachen	fɛʁˈfʏnft͡seːnˌfaxən
Gewaltverbrechen	Gewalt-verbrechen	ɡəˈvaltfɛʁˌbʁɛçən
Absatzzeichen	Absatz-zeichen	ˈapzat͡sˌt͡saɪ̯çən
Anführungszeichen	Anführungs-zeichen	ˈanfyːʁʊŋsˌt͡saɪ̯çən
Autokennzeichen	Auto--kenn-zeichen	ˈaʊ̯toˌkɛnt͡saɪ̯çən
Hauptbetonungszeichen	Haupt-betonung>s--zeichen	ˈhaʊ̯ptbətoːnʊŋsˌt͡saɪ̯çən
Gleichheitszeichen	Gleichheit>s-zeichen	ˈɡlaɪ̯çhaɪ̯t͡sˌt͡saɪ̯çən
Minuszeichen	Minus-zeichen	ˈmiːnʊsˌt͡saɪ̯çən
Unterstreichen	Unterstreichen	ʔʊntɐˈʃtʁaɪ̯çən
Ermöglichen	Ermöglichen	ɛʁˈmøːklɪçən
Backenknochen	Backen-knochen	ˈbakənˌknɔxən
Oberschenkelknochen	Ober-schenkel--knochen	ˈoːbɐʃɛŋkəlˌknɔxən
Apfelkuchen	Apfel-kuhchen	ˈapfəlˌkuːxən
Passivrauchen	Pássiv-rauchen	ˈpasiːfˌʁaʊ̯xən
Untertauchen	Untertauchen	ˈʊn.tɐˌtaʊ̯xən
Verscheuchen	Verscheuchen	fɛʁˈʃɔɪ̯çən
Bärchen	Bärchen	ˈbɛːʁçən
Hintertürchen	Hintertürchen	ˈhɪntɐˌtyːʁçən
Dingenskirchen	Dingens-kirchen	ˈdɪŋənsˌkɪʁçən

## -erei
Bücherei	Bücherei	byçəˈʁaɪ̯ # dewikt says long /yː/ but audio doesn't agree
Gärtnerei	Gä̀rtnerei	ˌɡɛʁtnəˈʁaɪ̯
Ausbeuterei	Ausbeuterei	ˌaʊ̯sbɔɪ̯təˈʀaɪ̯
Seeräuberei	See-*räuberei	ˌzeːʁɔɪ̯bəˈʁaɪ̯
Rosinenpickerei	Rosínen-pickerei	ʁoˈziːnənpɪkəˌʁaɪ̯

## -ei
Barbarei	Barbarei	baʁbaˈʁaɪ̯
Audiodatei	Audio-datei	ˈaʊ̯di̯odaˌtaɪ̯
allerlei	aller-lei	ˈalɐˌlaɪ̯
Aufschrei	Aufschrei	ˈaʊ̯fˌʃʁaɪ̯ # -ei not interpreted here as suffix

## -ent
biolumineszent	bìolumineszent	ˌbioluminɛsˈt͡sɛnt
Bundespräsident	Bundes-präsident	ˈbʊndəspʁɛziˌdɛnt
different	different	dɪfəˈʁɛnt

## -enz
Eloquenz	Èloquenz	ˌeloˈkvɛnt͡s
Obsoleszenz	Obsoleszenz	ɔpzolɛsˈt͡sɛnt͡s

## -schaft
Wissenschaft	Wissenschaft	ˈvɪsənˌʃaft
Barschaft	Barschaft	ˈbaːʁʃaft
Botschaft	Botschaft	ˈboːtʃaft
Komplizenschaft	Komplízenschaft	kɔmˈpliːt͡sənˌʃaft
Wirtschaftswissenschaft	Wirtschaft>s-wissenschaft	ˈvɪʁtʃaft͡sˌvɪsənʃaft

## -haft
albtraumhaft	alb-traum>haft	ˈalpˌtʁaʊ̯mhaft
dauerhaft	dauerhaft	ˈdaʊ̯ɐˌhaft
schamhaft	schamhaft	ˈʃaːmhaft

## -heit
Abgeschiedenheit	Abgeschiedenheit	ˈapɡəˌʃiːdənhaɪ̯t
Absolutheit	Absolútheit	apzoˈluːthaɪ̯t
Abwesenheit	Abwesenheit	ˈapˌveːzənhaɪ̯t
Allgemeinheit	All-geméinheit	ˌalɡəˈmaɪ̯nhaɪ̯t
Freiheit	Freiheit	ˈfʁaɪ̯haɪ̯t
Bescheidenheit	Bescheidenheit	bəˈʃaɪ̯dənˌhaɪ̯t
Grobheit	Grobheit	ˈɡʁoːphaɪ̯t

## -ie
Apoplexie	Apoplexie	apoplɛˈksiː
Biologie	Bìologie	ˌbioloˈɡiː
Fotografie	Fotografie	fotoɡʁaˈfiː
Fantasie	Fantasie	fantaˈziː
Informationstechnologie	Information>s-technologie	ɪnfɔʁmaˈt͡si̯oːnstɛçnoloˌɡiː
Familie	FamílIe	faˈmiːli̯ə

## -ieren
degradieren	degradieren	deɡʁaˈdiːʁən
ausprobieren	ausprobieren	ˈaʊ̯spʁoˌbiːʁən
Umstrukturieren	Umstrukturieren	ˈʊmʃtʁʊktuˌʁiːʁən
entionisieren	entionisieren	ɛnt(ʔ)i̯oniˈziːʁən
vertelefonieren	verteləfonieren	fɛʁteləfoˈniːʁən

## -iert
definiert	definiert	defiˈniːʁt
kompliziert	kompliziert	kɔmpliˈt͡siːʁt
hochdekoriert	hohch-dekoriert	ˈhoːxdekoˌʁiːʁt
situiert	situ.iert	zituˈiːʁt

## -ierung
Konsolidierung	Konsolidierung	kɔnzoliˈdiːʁʊŋ
Maximierung	Maximierung	maksiˈmiːʁʊŋ
Quantifizierung	Quantifizierung	kvantifiˈt͡siːʁʊŋ
Stipulierung	Stipulierung	ʃtipuˈliːʁʊŋ
Stipulierung	S*tipulierung	stipuˈliːʁʊŋ
Selbstregierung	Selbst-regierung	ˈzɛlpstʁeˌɡiːʁʊŋ

## -tionismus
Exhibitionismus	Exhibitionismus	ɛkshibit͡si̯oˈnɪsmʊs
Perfektionismus	Perfektionismus	pɛʁfɛkt͡si̯oˈnɪsmʊs

## -ismus
Protestantismus	Protestantismus	pʁotɛstanˈtɪsmʊs
Sozialismus	Sozialismus	zot͡si̯aˈlɪsmʊs
Multikulturalismus	Multikulturalismus	mʊltikʊltuʁaˈlɪsmʊs
Pseudoanglizismus	Pseudo-anglizismus	ˈpsɔɪ̯doʔaŋɡliˌt͡sɪsmʊs

## -ist
dreist	dreist	dʁaɪ̯st
Deist	De.ist	deˈɪst
Deist	Deʔist	deˈʔɪst
Atheist	Athe.ist	ateˈɪst
Atheist	Atheʔist	ateˈʔɪst
verwaist	verwaist	fɛʁˈvaɪ̯st
Judaist	Juda.ist	judaˈɪst
Judaist	Judaʔist	judaˈʔɪst

## -istisch
euphemistisch	euphemistisch	ɔɪ̯feˈmɪstɪʃ
rechtsextremistisch	recht>s-extremistisch	ˈʁɛçt͡s(ʔ)ɛkstʁeˌmɪstɪʃ
postkommunistisch	post-kommunistisch	ˈpɔstkɔmuˌnɪstɪʃ
unrealistisch	unrealistisch	ˈʊnʁeaˌlɪstɪʃ
avantgardistisch	avãgardistisch	avãɡaʁˈdɪstɪʃ
computerlinguistisch	kom.pjúter-linguistisch	kɔmˈpjuːtɐlɪŋˌɡu̯ɪstɪʃ
computerlinguistisch	kom.pjúter-lingu.istisch	kɔmˈpjuːtɐlɪŋɡuˌɪstɪʃ

## -iv
Motiv	Motiv	moˈtiːf
Leitmotiv	Leit-motiv	ˈlaɪ̯tmoˌtiːf
Detektiv	Detektiv	detɛkˈtiːf
diminutiv	diminutiv	diminuˈtiːf
naiv	naiv	naˈiːf
interrogativ	inter-*rogativ	ˌɪntɐʁoɡaˈtiːf
Genitiv	Génitiv	ˈɡeːnitiːf # Should still be lengthened even when unstressed.
Passiv	Pássiv	ˈpasiːf
Adjektiv	Ádjektiv	ˈatjɛktiːf
Ablativ	Ab+blatìv	ˈablaˌtiːf
Ablativ	Ab.latìv	ˈaplaˌtiːf

## -ierbarkeit
Korrumpierbarkeit	Korrumpierbarkeit	kɔʁʊmˈpiːʁbaːʁˌkaɪ̯t

## -barkeit
Verfügbarkeit	Verfügbarkeit	fɛʁˈfyːkbaːʁˌkaɪ̯t # Here, dewikt and enwikt have no secondary stress on -keit.
Dienstbarkeit	Dienstbarkeit	ˈdiːnstbaːʁˌkaɪ̯t # Here, dewikt and enwikt agree with our rules.
Abbaubarkeit	Abbaubarkeit	ˈapˌbaʊ̯baːʁkaɪ̯t # FIXME! dewikt has ˈapbaʊ̯baːʁˌkaɪ̯t. Our rules generate ˈapˌbaʊ̯baːʁkaɪ̯t. Need to verify with native speaker.
Durchführbarkeit	Durchführbarkeit	ˈdʊʁçˌfyːʁbaːʁkaɪ̯t # Here, dewikt agrees with our rules.
Sonderbarkeit	Sonderbarkeit	ˈzɔndɐˌbaːʁkaɪ̯t # Here, enwikt agrees with our rules.
Übertragbarkeit	Über<tragbarkeit	yːbɐˈtʁaːkbaːʁˌkaɪ̯t # Here, dewikt and wikt have no secondary stress on -keit.
Unabwendbarkeit	Unabwéndbarkeit	ʊn(ʔ)apˈvɛntbaːʁˌkaɪ̯t # Here, dewikt has no secondary stress on -keit.
Unabwendbarkeit	Unabwendbarkeit	ˈʊn(ʔ)apˌvɛntbaːʁkaɪ̯t
Undankbarkeit	Undankbarkeit	ˈʊnˌdaŋkbaːʁkaɪ̯t # Here, enwikt agrees with our rules.
Unzerstörbarkeit	Unzerstörbarkeit	ˈʊnt͡sɛʁˌʃtøːʁbaːʁkaɪ̯t # Here, enwikt agrees with our rules.

## -schaftlichkeit
Wirtschaftlichkeit	Wirtschaftlichkeit	ˈvɪʁtʃaftlɪçˌkaɪ̯t
Wissenschaftlichkeit	Wissenschaftlichkeit	ˈvɪsənˌʃaftlɪçkaɪ̯t # FIXME: Is the secondary stress here correct?
Unwissenschaftlichkeit	Unwissenschaftlichkeit	ˈʊnˌvɪsənʃaftlɪçkaɪ̯t

## -lichkeit
Möglichkeit	Möglichkeit	ˈmøːklɪçˌkaɪ̯t # FIXME: Is the secondary stress here correct? In enwikt but not dewikt.
Brüderlichkeit	Brüderlichkeit	ˈbʁyːdɐlɪçˌkaɪ̯t # FIXME: Is the secondary stress here correct? In enwikt but not dewikt.
Abscheulichkeit	Abschéulichkeit	apˈʃɔɪ̯lɪçˌkaɪ̯t # FIXME: Is the secondary stress here correct? Not in dewikt or enwikt.
Behaglichkeit	Behaglichkeit	bəˈhaːklɪçˌkaɪ̯t # FIXME: Is the secondary stress here correct? Not in dewikt or enwikt.
Gemütlichkeit	Gemütlichkeit	ɡəˈmyːtlɪçˌkaɪ̯t # FIXME: Is the secondary stress here correct? Not in dewikt or enwikt.
Entzündlichkeit	Entzündlichkeit	ɛntˈt͡sʏntlɪçˌkaɪ̯t # FIXME: Is the secondary stress here correct? Not in enwikt.
Unannehmlichkeit	Unannehmlichkeit	ˈʊn(ʔ)anˌneːmlɪçkaɪ̯t
Unfreundlichkeit	Unfreundlichkeit	ˈʊnˌfʁɔɪ̯ntlɪçkaɪ̯t
Unendlichkeit	Unéndlichkeit	ʊnˈʔɛntlɪçˌkaɪ̯t # FIXME: Is the secondary stress here correct? Not in dewikt.
Anwendungsmöglichkeit	Anwendungsmöglichkeit	ˈanvɛndʊŋsˌmøːklɪçkaɪ̯t
Arbeitsmöglichkeit	Arbeits-möglichkeit	ˈaʁbaɪ̯t͡sˌmøːklɪçkaɪ̯t
Eigenverantwortlichkeit	Eigen-verantwortlichkeit	ˈaɪ̯ɡənfɛʁˌʔantvɔʁtlɪçkaɪ̯t
Flugtauglichkeit	Flug-tauglichkeit	ˈfluːkˌtaʊ̯klɪçkaɪ̯t

## -samkeit
Einsamkeit	Einsamkeit	ˈaɪ̯nzaːmˌkaɪ̯t
Langsamkeit	Langsamkeit	ˈlaŋzaːmˌkaɪ̯t # FIXME: Is the secondary stress here correct? Not in dewikt or enwikt.
Genügsamkeit	Genügsamkeit	ɡəˈnyːkzaːmˌkaɪ̯t # FIXME: Is the secondary stress here correct? Not in dewikt or enwikt.
Bedeutsamkeit	Bedeutsamkeit	bəˈdɔɪ̯tzaːmˌkaɪ̯t # FIXME: Is the secondary stress here correct? Not in dewikt or enwikt.
Beredsamkeit	Beredsamkeit	bəˈʁeːtzaːmˌkaɪ̯t # FIXME: Is the secondary stress here correct? Not in dewikt or enwikt.
Aufmerksamkeit	Aufmerksamkeit	ˈaʊ̯fˌmɛʁkzaːmkaɪ̯t
Selbstgenügsamkeit	Selbst-genügsamkeit	ˈzɛlpstɡəˌnyːkzaːmkaɪ̯t # FIXME: make sure this works!
Unachtsamkeit	Unachtsamkeit	ˈʊnˌʔaxtzaːmkaɪ̯t # FIXME: Is the secondary stress here correct? Not in dewikt or enwikt.
Unaufmerksamkeit	Unaufmerksamkeit	ˈʊn(ʔ)aʊ̯fˌmɛʁkzaːmkaɪ̯t
Unbedeutsamkeit	Unbedeutsamkeit	ˈʊnbəˌdɔɪ̯tzaːmkaɪ̯t
Waldeinsamkeit	Wald-einsamkeit	ˈvaltˌʔaɪ̯nzaːmkaɪ̯t

## -keit
Aufrichtigkeit	Aufrichtigkeit	ˈaʊ̯fˌʁɪçtɪçkaɪ̯t
Anpassungsfähigkeit	Anpassungs-fähigkeit	ˈanpasʊŋsˌfɛːɪçkaɪ̯t # FIXME! [[Anständigkeit]] is given as /ˈanʃtɛndɪçˌkaɪ̯t/ in dewikt when our rules generate /ˈanˌʃtɛndɪçkaɪ̯t/.
Bedürftigkeit	Bedürftigkeit	bəˈdʏʁftɪçˌkaɪ̯t # FIXME: Is the secondary stress here correct? Not in dewikt or enwikt.
Bereitwilligkeit	Bereit-willigkeit	bəˈʁaɪ̯tˌvɪlɪçkaɪ̯t
Bettlägerigkeit	Bett-lägerigkeit	ˈbɛtˌlɛːɡəʁɪçkaɪ̯t
Billigkeit	Billigkeit	ˈbɪlɪçˌkaɪ̯t # FIXME: Is the secondary stress here correct? Not in dewikt or enwikt.
Bitterkeit	Bitterkeit	ˈbɪtɐˌkaɪ̯t # FIXME: Is the secondary stress here correct? Not in dewikt or enwikt.
Doppeldeutigkeit	Doppel-deutigkeit	ˈdɔpəlˌdɔɪ̯tɪçkaɪ̯t
Dreifaltigkeit	Drei-fáltigkeit	dʁaɪ̯ˈfaltɪçˌkaɪ̯t
Drogenabhängigkeit	Drogen-abhängigkeit	ˈdʁoːɡənˌʔaphɛŋɪçkaɪ̯t
Dünnhäutigkeit	Dünn-häutigkeit	ˈdʏnˌhɔɪ̯tɪçkaɪ̯t
Durchsichtigkeit	Durchsichtigkeit	ˈdʊʁçˌzɪçtɪçkaɪ̯t
Einsprachigkeit	Einsprahchigkeit	ˈaɪ̯nˌʃpʁaːxɪçkaɪ̯t
Einträchtigkeit	Einträchtigkeit	ˈaɪ̯nˌtʀɛçtɪçkaɪ̯t
Endgeschwindigkeit	End-geschwindigkeit	ˈɛntɡəˌʃvɪndɪçkaɪ̯t
Ewigkeit	Ewigkeit	ˈeːvɪçˌkaɪ̯t # FIXME: Is the secondary stress here correct? Not in dewikt or enwikt.
Fingerfertigkeit	Finger-fertigkeit	ˈfɪŋɐˌfɛʁtɪçkaɪ̯t
Flüssigkeit	Flüssigkeit	ˈflʏsɪçˌkaɪ̯t
Gebärfreudigkeit	Gebär-freudigkeit	ɡəˈbɛːʁˌfʁɔɪ̯dɪçkaɪ̯t
Unauffälligkeit	Unauffälligkeit	ˈʊn(ʔ)aʊ̯fˌfɛlɪçkaɪ̯t
Undurchsichtigkeit	Undurchsichtigkeit	ˈʊndʊʁçˌzɪçtɪçkaɪ̯t
Uneinigkeit	Uneinigkeit	ˈʊnˌʔaɪ̯nɪçkaɪ̯t
Ungerechtigkeit	Ungerechtigkeit	ˈʊnɡəˌʁɛçtɪçkaɪ̯t
Unregelmäßigkeit	Unregel-mäßigkeit	ˈʊnʁeːɡəlˌmɛːsɪçkaɪ̯t # FIXME: Are we sure this is correct? Logically, it should be ˈʊnˌʁeːɡəlmɛːsɪçkaɪ̯t

## -lein
Apfelbäumlein	Apfel-bäumlein	ˈap͡fəlˌbɔɪ̯mlaɪ̯n
Äuglein	Äuglein	ˈɔɪ̯klaɪ̯n
Blumenlädlein	Blumen-lädlein	ˈbluːmənˌlɛːtlaɪ̯n
Büchlein	Bühchlein	ˈbyːçlaɪ̯n
Ecklädlein	Eck-lädlein	ˈɛkˌlɛːtlaɪ̯n
Fräulein	Fräulein	ˈfʁɔɪ̯laɪ̯n
Hofkirchlein	Hof-kirchlein	ˈhoːfˌkɪʁçlaɪ̯n
Kindelein	Kindelein	ˈkɪndəˌlaɪ̯n
Kindlein	Kindlein	ˈkɪntlaɪ̯n
Kügellein	Kügellein	ˈkyːɡəlˌlaɪ̯n
Müllerlein	Müllerlein	ˈmʏlɐˌlaɪ̯n
Osterkerzlein	Ohster-kerzlein	ˈoːstɐˌkɛʁt͡slaɪ̯n
Privatsträßlein	Privát-sträßlein	priˈvaːtˌʃtʁɛːslaɪ̯n
Wachsfigürlein	Wachs-figǘrlein	ˈvaksfiˌɡyːʁlaɪ̯n
Walnussbäumlein	Walnuss-bäumlein	ˈvalnʊsˌbɔɪ̯mlaɪ̯n
Walnussbäumlein	Wal-nuss--bäumlein	ˈvaːlnʊsˌbɔɪ̯mlaɪ̯n
Weihnachtskerzlein	Weih-nachts--kerzlein	ˈvaɪ̯naxt͡sˌkɛʁt͡slaɪ̯n

## -barlich
sichtbarlich	sichtbarlich	ˈzɪçtbaːʁlɪç
wunderbarlich	wunderbarlich	ˈvʊndɐˌbaːʁlɪç

## -schaftlich
freundschaftlich	freundschaftlich	ˈfʁɔɪ̯ntʃaftlɪç
betriebswirtschaftlich	betriebs-wirtschaftlich	bəˈtʁiːpsˌvɪʁtʃaftlɪç
geisteswissenschaftlich	geistes-wissenschaftlich	ˈɡaɪ̯stəsˌvɪsənʃaftlɪç
gemeinschaftlich	gemeinschaftlich	ɡəˈmaɪ̯nʃaftlɪç
genossenschaftlich	genossenschaftlich	ɡəˈnɔsənˌʃaftlɪç # FIXME: Is secondary stress correct?
ingenieurwissenschaftlich	inʒeniö́r-wissenschaftlich	ɪnʒeˈni̯øːʁˌvɪsənʃaftlɪç
kameradschaftlich	kamerádschaftlich	kaməˈʁaːtʃaftlɪç
landwirtschaftlich	land-wirtschaftlich	ˈlantˌvɪʁtʃaftlɪç # FIXME: Is secondary stress correct?
partnerschaftlich	partnerschaftlich	ˈpaʁtnɐˌʃaftlɪç # FIXME: Is secondary stress correct?
pseudowissenschaftlich	pseudo-wissenschaftlich	ˈpsɔɪ̯doˌvɪsənʃaftlɪç
unwirtschaftlich	unwirtschaftlich	ˈʊnvɪʁtˌʃaftlɪç # FIXME: Is the secondary stress in the right position? I might expect /ˈʊnˌvɪʁtʃaftlɪç/.
verwandtschaftlich	verwandtschaftlich	fɛʁˈvantʃaftlɪç
wirtschaftswissenschaftlich	wirtschaft>s-wissenschaftlich	ˈvɪʁtʃaft͡sˌvɪsənʃaftlɪç
wissenschaftlich	wissenschaftlich	ˈvɪsənˌʃaftlɪç # FIXME: Is secondary stress correct?

## -lich
bläulich	bläulich	ˈblɔɪ̯lɪç
fraglich	fraglich	ˈfʁaːklɪç
bitterlich	bitterlich	ˈbɪtɐlɪç
brüderlich	brüderlich	ˈbʁyːdɐlɪç
abkömmlich	abkömmlich	ˈapˌkœmlɪç
beweglich	beweglich	bəˈveːklɪç
blutähnlich	blut-ähnlich	ˈbluːtˌʔɛːnlɪç
bildungssprachlich	bildungs-sprahchlich	ˈbɪldʊŋsˌʃpʁaːxlɪç
brandgefährlich	brand-gefährlich	ˈbʁantɡəˌfɛːʁlɪç
buchstäblich	buhch-stäblich	ˈbuːxˌʃtɛːplɪç
gegenständlich	gegen-ständlich	ˈɡeːɡənˌʃtɛntlɪç
despektierlich	despektíerlich	despɛkˈtiːʁlɪç
eigenverantwortlich	eigen-verantwortlich	ˈaɪ̯ɡənfɛʁˌʔantvɔʁtlɪç
eigentümlich	eigen-tümlich	ˈaɪɡənˌtyːmlɪç
einvernehmlich	einvernehmlich	ˈaɪ̯nfɛʁˌneːmlɪç
erträglich	erträglich	ɛʁˈtʁɛːklɪç
ewiglich	ewiglich	ˈeːvɪklɪç
ewiglich	ewi.glich	ˈeːvɪɡlɪç
figürlich	figürlich	fiˈɡyːʁlɪç
freiheitlich	frei>heit>lich	ˈfʁaɪ̯haɪ̯tlɪç
gemeingefährlich	gemein-gefährlich	ɡəˈmaɪ̯nɡəˌfɛːʁlɪç
hauptamtlich	haupt-amtlich	ˈhaʊ̯ptˌʔamtlɪç
jungsteinzeitlich	jung-stein--zeitlich	ˈjʊŋʃtaɪ̯nˌt͡saɪ̯tlɪç
maschinenschriftlich	maschínen-schriftlich	maˈʃiːnənˌʃʁɪftlɪç

## -or
Gladiator	Gladiator	ɡlaˈdi̯aːtoːʁ
Korridor	Korridor	ˈkɔʁidoːʁ
Sektor	Sektor	ˈzɛktoːʁ
Fluor	Fluor	ˈfluːoːʁ

## -tion
Konvention	Konvention	kɔnvɛnˈt͡si̯oːn
Infektion	Infektion	ɪnfɛkˈt͡si̯oːn
Bastion	Bastion	basˈti̯oːn

## -tät
Fakultät	Fakultät	fakʊlˈtɛːt

## Explicitly indicated suffixes
trägt	träg>t	tʁɛːkt
wüst	wüs>t	vyːst
wachsen	wachsen	ˈvaksən
wachst	wach>st	vaxst
wachst	wachst	vakst
wachst	wachs>t	vakst
Stabsarzt	Stab>s-ahrzt	ˈʃtaːpsˌʔaːʁt͡st

## secondary stress
Lethargie	Lèthargie	ˌletaʁˈɡiː
liberal	liberal	libeˈʁaːl # dewikt
liberal	lìberal	ˌlibəˈʁaːl # enwikt
hyperaktiv	hỳ*per-áktiv	ˌhypɐˈʔaktiːf
separat	separát	zepaˈʁaːt # standard per dewikt
separat	sèparát	ˌzeːpaˈʁaːt # standard per enwikt
separat	sèpperát	ˌzɛpəˈʁaːt # variant in common speech
]==]

function tests:check_ipa(spelling, respelling, expected, comment)
	local phonemic = m_de_pron.phonemic(respelling)
	options.comment = comment or ""
	self:equals(
		link(spelling) .. (respelling == spelling and "" or ", respelled " .. respelling),
		phonemic,
		expected,
		options
	)
end

local function parse(examples)
	-- The following is a list of parsed examples where each element is a four-element list of
	-- {SPELLING, RESPELLING, EXPECTED, COMMENT}. SPELLING is the actual spelling of the term; RESPELLING is the
	-- respelling; EXPECTED is the phonemic IPA; and COMMENT is an optional comment or nil.
	local parsed_examples = {}
	-- Snarf each line.
	for line in examples:gmatch "[^\n]+" do
		-- Trim whitespace at beginning and end.
		line = line:gsub("^%s*(.-)%s*$", "%1")
		local function err(msg)
			error(msg .. ": " .. line)
		end
		if line == "" then
			-- Skip blank lines.
		elseif line:find("^##") then
			-- Line beginning with ## is a section header.
			line = line:gsub("^##%s*", "")
			table.insert(parsed_examples, line)
		elseif line:find("^#") then
			-- Line beginning with # but not ## is a comment; ignore.
		else
			local line_no_comment, comment = rmatch(line, "^(.-)%s+#%s*(.*)$")
			line_no_comment = line_no_comment or line
			local parts = rsplit(line_no_comment, "\t")
			if #parts ~= 3 then
				err("Expected 3 in example (not including any comment)")
			end
			table.insert(parts, comment)
			table.insert(parsed_examples, parts)
		end
	end
	return parsed_examples
end

function tests:test()
	self:iterate(parse(examples), "check_ipa")
end

return tests
