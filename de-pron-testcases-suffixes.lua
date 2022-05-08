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
Wachsfigürlein	Wachs-figǘrlein	ˈvaksfiˌɡyːʁlaɪ̯n
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
]==]

function tests:check_ipa(spelling, respelling, expected, comment)
	return driver.check_ipa(self, spelling, respelling, expected, comment)
end

function tests:test()
	self:iterate(driver.parse(examples), "check_ipa")
end

return tests
