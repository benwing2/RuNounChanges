local tests = require("Module:UnitTests")
local driver = require("Module:User:Benwing2/de-pron/testcases/driver")

--[=[
In the following examples, each line is either a section header beginning with a ##, a comment beginning with # but not
##, a blank line or an example. Examples consist of three tab-separated fields, followed by an optional comment to be
shown along with the example (delimited by a # preceded by whitespace). The first field is the actual spelling of the
term in question. The second field is the respelling. The third field is the expected phonemic IPA pronunciation.

See [[Module:de-pron/testcases/driver]] for more detailed information on the format of examples, along with information
on how to create a new subset of testcases.
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
Sindhi	Sindhi	ˈzɪndi
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
orange	orṍʒ	oˈʁõːʃ # enwikt pron #3
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
Pompon	Põpṍ	põˈpõː
Pompon	Pompṍ	pɔmˈpõ
Saison	Sĕsṍ	zɛˈzõː
Saison	Sĕsóng	zɛˈzɔŋ
salonfähig	salṍ-fähig	zaˈlõːˌfɛːɪç
Bain-Marie	Bẽmarie	bɛ̃maˈʁiː
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
Trübsal	Trüb-sal	ˈtʁyːpˌzaːl
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
Asexualität	Ắsexualitä̀t	ˈazɛksu̯aliˌtɛːt
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
	return driver.check_ipa(self, spelling, respelling, expected, comment)
end

function tests:test()
	self:iterate(driver.parse(examples), "check_ipa")
end

return tests
