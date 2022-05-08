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
darüber	darǘber	daˈʁyːbɐ

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
überfahren	über<fahren	yːbɐˈfaːʁən # über- should be recognized, translated to ǘber- and then to ü̏ber- (i.e. with double grave), so that length is preserved.
überdimensionieren	überdimensionieren	ˈyːbɐdimɛnzi̯oˌniːʁən
überholt	ǜberhol>t	ˌyːbɐˈhoːlt # über- should still be recognized with secondary stress on it.
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
]==]

function tests:check_ipa(spelling, respelling, expected, comment)
	return driver.check_ipa(self, spelling, respelling, expected, comment)
end

function tests:test()
	self:iterate(driver.parse(examples), "check_ipa")
end

return tests
