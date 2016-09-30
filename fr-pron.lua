--[=[

Author: Originally Kc kennylau; rewritten and expanded by Benwing

Generates French IPA from spelling. Implements template {{fr-IPA}}; also
used in [[Module:fr-verb]] (particularly [[Module:fr-verb/pron]], the submodule
handling pronunciation of verbs).

--]=]

local export = {}

local u = mw.ustring.char
local rfind = mw.ustring.find
local rsubn = mw.ustring.gsub
local rmatch = mw.ustring.match
local rsplit = mw.text.split
local ulower = mw.ustring.lower
local uupper = mw.ustring.upper
local usub = mw.ustring.sub
local ulen = mw.ustring.len

-- version of rsubn() that discards all but the first return value
local function rsub(term, foo, bar)
	local retval = rsubn(term, foo, bar)
	return retval
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

local function ine(x)
	if x == "" then return nil else return x end
end

-- pairs of consonants where a schwa between then can never be deleted;
-- primarily, consonants that are the same except possibly for voicing
local no_delete_schwa_between_list = {
	'kɡ', 'ɡk', 'kk', 'ɡɡ', -- WARNING: IPA ɡ used here
	'td', 'dt', 'tt', 'dd',
	'bp', 'pb', 'pp', 'bb',
	'ʃʒ', 'ʒʃ', 'ʃʃ', 'ʒʒ',
	'fv', 'vf', 'ff', 'vv',
	'sz', 'zs', 'ss', 'zz',
	'jj', 'ww', 'ʁʁ', 'll', 'ɲɲ',
	-- pairs of non-homorganic consonants:
	'pz', -- empeser, repeser, soupeser
	'sv' -- forms or recevoir, décevoir, concevoir
	-- FIXME, should be others
}
-- generate set
local no_delete_schwa_between = {}
for _, x in ipairs(no_delete_schwa_between_list) do
	no_delete_schwa_between[x] = true
end

local remove_diaeresis_from_vowel =
	{['ä']='a',['ë']='e',['ï']='i',['ö']='o',['ü']='u',['ÿ']='i'}

-- list of vowels, including both input Latin and output IPA; note that
-- IPA nasal vowels are two-character sequences with a combining tilde,
-- which we include as the last char
local vowel_no_tilde = "aeiouyəAEIOUYƏéàèùâêîôûŷäëïöüÿăĕŏŭɑɛɔæœø"
local vowel = vowel_no_tilde .. "̃"
local vowel_c = "[" .. vowel .. "]"
local vowel_no_tilde_c = "[" .. vowel_no_tilde .. "]"
local vowel_no_i = "aeouəAEOUƏéàèùâêôûäëöüăĕŏŭɛɔæœø"
local vowel_no_i_c = "[" .. vowel_no_i .. "]"
local cons_c = "[^" .. vowel .. ".⁀ ]"
local cons_no_quote_c = "[^" .. vowel .. "'‿.⁀ ]"
local front_vowel = "eiéèêɛæy" -- should not include capital E, used in cœur etc.
local front_vowel_c = "[" .. front_vowel .. "]"

	
function export.show(text, pos, do_debug)
	if type(text) == 'table' then
		text, pos, do_debug = ine(text.args[1]), ine(text.args.pos), ine(text.args.debug)
	end
	text = text or mw.title.getCurrentTitle().text
	text = ulower(text)
	
	local debug = {}

	-- To simplify checking for word boundaries and liaison markers, we
	-- add ⁀ at the beginning and end of all words, and remove it at the end.
	-- Note that the liaison marker is ‿.
	text = rsub(text, "[%s-]+", '⁀ ⁀')
	text = '⁀' .. text .. '⁀'

	if pos == "v" then
		-- special-case for verbs
		text = rsub(text,'ai⁀', 'é⁀')
		-- vient, tient, and compounds will have to be special-cased, no easy
		-- way to distinguish e.g. initient (silent) from retient (not silent).
		text = rsub(text, 'ent⁀', 'e⁀')
		-- portions, retiens as verbs should not have /s/
		text = rsub(text, 'ti([oe])ns([⁀‿])', "t'i%1ns%2")
	end
	-- various early substitutions
	text = rsub(text,'œu', 'Eu') -- capital E so it doesn't trigger c -> s
	text = rsub(text,'oeu', 'Eu')
	text = rsub(text,'œil', 'Euil')
	text = rsub(text,'o[eê]l', 'wal') -- moelle, poêle; don't map to 'oil'
	text = rsub(text, 'œ', 'æ') -- keep as æ, mapping later to è or é
	text = rsub(text,'[aä]([sz])⁀', 'â%1⁀') -- pas, gaz; later on we affect all a before /z/
	text = rsub(text,'à','a')
	text = rsub(text,'ù','u')
	text = rsub(text,'î','i')
	text = rsub(text,'[Ee]û','ø')
	text = rsub(text,'û','u')
	text = rsub(text,'bs','ps') -- absolute, obstacle, subsumer, etc.
	text = rsub(text,'ph','f')
	text = rsub(text,'gn','ɲ')
	text = rsub(text,'⁀désh','⁀déz')
	text = rsub(text,'⁀ress','⁀rəss') -- ressortir, etc. should have schwa
	text = rsub(text,'⁀trans(' .. vowel_c .. ')','⁀tranz%1')
	-- adverbial -emment is pronounced -amment
	text = rsub(text, 'emment⁀', 'amment⁀') 
	text = rsub(text, 'ieds?⁀', 'ié⁀') -- pied, assieds, etc.
	text = rsub(text, 'oien', 'oyen') -- iroquoien

	--s, c, ç, g, j, qu
	text = rsub(text,'cueil', 'keuil') -- accueil, etc.
	text = rsub(text,'gueil', 'gueuil') -- orgueil
	text = rsub(text,'(' .. vowel_c .. ')s(‿?' .. vowel_c .. ')','%1z%2')
	text = rsub(text,'ç','s') -- must follow s -> z between vowels
	text = rsub(text,'c(' .. front_vowel_c .. ')','s%1')
	text = rsub(text,"qu'", "k'") -- qu'on
	text = rsub(text,'qu(' .. vowel_c .. ')','k%1')
	text = rsub(text,'ge(' .. vowel_c .. ')','j%1')
	text = rsub(text,'g(' .. front_vowel_c .. ')','j%1')
	-- gu+vowel -> g+vowel, but gu+vowel+diaeresis -> gu+vowel
	text = rsub(text,'gu(' .. vowel_c .. ')', function(vowel)
		local undo_diaeresis = remove_diaeresis_from_vowel[vowel]
		return undo_diaeresis and 'gu' .. undo_diaeresis or 'g' .. vowel
		end)
	text = rsub(text,'gü','gu') -- aiguë might be spelled aigüe
	text = rsub(text, '(' .. cons_c .. ')ing⁀', '%1iŋ⁀') -- parking, footing etc.
	-- also -ing' e.g. swinguer respelled swing'guer, Washington respelled Washing'tonne
	text = rsub(text, '(' .. cons_c .. ")ing'", "%1iŋ'")
	text = rsub(text, 'ng⁀', 'n⁀') -- long, sang, poing, parpaing, shampooing etc.
	text = rsub(text, 'ngt', 'nt') -- vingt, longtemps
	text = rsub(text,'j','ʒ')
	text = rsub(text,'s?[cs]h','ʃ')
	text = rsub(text,'[cq]','k')
	-- following two must follow s -> z between vowels
	text = rsub(text,'([^sçx⁀])ti([oe])n','%1si%2n') -- tion, tien
	text = rsub(text,'([^sçx⁀])tial','%1sial')
	table.insert(debug, text)

	-- special hack for uï; must follow guï handling and precede ill handling
	text = rsub(text, 'uï', 'ui') -- ouir, etc.

	-- ill, il; must follow j -> ʒ above
	-- special-casing for C+uill (juillet, cuillère, aiguille respelled
	-- aiguïlle)
	text = rsub_repeatedly(text,'(' .. cons_c .. ')uill(' .. vowel_c .. ')',
		'%1ɥij%2')
	-- repeat if necessary in case of VillVill sequence (ailloille
	-- respelling of ayoye)
	text = rsub_repeatedly(text,'(' .. vowel_c .. ')ill(' .. vowel_c .. ')',
		'%1j%2')
	-- any other ill, except word-initially
	text = rsub(text,'([^⁀])ill(' .. vowel_c .. ')','%1ij%2')
	text = rsub(text,'(' .. vowel_c .. ')il⁀','%1j⁀')
	text = rsub(text,'(' .. vowel_c .. ')il(' .. cons_c .. ')','%1j%2')

	-- y; include before removing final -e so we can distinguish -ay from
	-- -aye
	text = rsub(text, 'ay⁀', 'ai⁀') -- Gamay
	text = rsub(text, 'éy', 'éj') -- used in respellings, eqv. to 'éill'
	text = rsub(text,'(' .. vowel_no_i_c .. ')y','%1iy')
	text = rsub(text,'yi([' .. vowel .. '.])', 'y.y%1')
	text = rsub(text,'(' .. cons_c .. ')y(' .. cons_c .. ')','%1i%2')
	text = rsub(text,'(' .. cons_c .. ')ye?⁀', '%1i⁀')
	text = rsub(text,'⁀y(' .. cons_c .. ')', '⁀i%1')
	text = rsub(text,'⁀y⁀', '⁀i⁀')
	text = rsub(text,'y','j')

	-- nasal hacks
	text = rsub(text, 'mn', 'Mn') -- make 'm' in 'mn' pronounced in full
	text = rsub(text, 'n‿', 'nN‿') -- make 'n' before liaison both nasal and pronounced

	--silent letters
	text = rsub(text, '⁀(' .. cons_c .. '*)es⁀', '⁀%1é⁀') -- ses, tes, etc.
	text = rsub(text,'[sx]⁀','⁀')
	-- silence -c and -ct in nc(t), but not otherwise
	text = rsub(text,'nkt?⁀', 'n⁀')
	text = rsub(text,'([ks])t⁀', '%1te⁀')
	text = rsub(text,'e[rz]⁀', 'é⁀') -- assez, premier, etc.
	-- do the following two after er -> é so we don't affect dessert
	text = rsub(text,'[eæ][dgpt]⁀','è⁀') -- permet
	text = rsub(text,'[dgpt]⁀','⁀')
	text = rsub(text,'mb⁀', 'm⁀') -- plomb
	-- remove final -e in various circumstances; leave primarily when
	-- preceded by two or more distinct consonants; in V[mn]e and Vmme/Vnne,
	-- use [MN] so they're pronounced in full
	text = rsub(text,'(' .. vowel_c .. ')n+e⁀','%1N⁀')
	text = rsub(text,'(' .. vowel_c .. ')m+e⁀','%1M⁀')
	text = rsub(text,'(' .. cons_c .. ')%1e⁀','%1⁀')
	text = rsub(text,'([mn]' .. cons_c .. ')e⁀','%1⁀')
	text = rsub(text,'(' .. vowel_c .. cons_c .. '?)e⁀','%1⁀')
	table.insert(debug,text)
	
	-- x
	text = rsub(text,'[eæ]x(' .. vowel_c .. ')','egz%1')
	text = rsub(text,'⁀x', '⁀gz')
	text = rsub(text,'x','ks')
	-- double consonants: eCC treated specially, then CC -> C
	text = rsub(text,'⁀e([mn])%1(' .. vowel_c .. ')', "⁀e%1'%1%2") -- emmener, ennui
	text = rsub(text, '⁀(h?)[eæ](' .. cons_c .. ')%2', '⁀%1é%2') -- effacer, essui, errer, emmental, henné
	text = rsub(text, '[eæ](' .. cons_c .. ')%1', 'è%1') -- mett(r)ons, etc.
	text = rsub(text, '(' .. cons_c .. ')%1', '%1')
	table.insert(debug,text)

	--diphthongs
	--uppercase is used to avoid the output of one change becoming the input
	--to another; we later lowercase the vowels; î and û converted early;
	--we do this before i/u/ou before vowel -> glide (for e.g. bleuet),
	--and before nasal handling because e.g. ou before n is not converted
	--into a nasal vowel (Bouroundi, Cameroun); au probably too, but there
	--may not be any such words
	text = rsub(text,'ou','U')
	text = rsub(text,'e?au','O')
	text = rsub(text,'[Ee]uz','øz')
	text = rsub(text,'[Ee]u⁀','ø⁀')
	text = rsub(text,'[Ee][uŭ]','œ')
	text = rsub(text,'oi','wA')
	text = rsub(text,'[ae]i','ɛ')

	-- remove silent h
	-- do after diphthongs to keep vowels apart as in envahir, but do
	-- before syllabification so it is ignored in words like hémorrhagie
	text = rsub(text,'h','')

	--syllabify
	-- (1) break up VCV as V.CV, and VV as V.V; repeat to handle successive
	--     syllables
	text = rsub_repeatedly(text, "(" .. vowel_c .. "['‿]*)(" .. cons_no_quote_c .. "?['‿]*" .. vowel_c .. ')', '%1.%2')
	-- (2) break up V[mn]CCV as V[mn]C.CV; repeat to handle successive syllables
	text = rsub_repeatedly(text, "(" .. vowel_c .. "[mn]['‿]*" .. cons_no_quote_c .. "['‿]*)(" .. cons_no_quote_c .. "['‿]*" .. vowel_c .. ")", "%1.%2")
	-- (3) break up other VCCCV as VC.CCV, and VCCV as VC.CV; repeat to handle successive syllables
	text = rsub_repeatedly(text, "(" .. vowel_c .. "['‿]*" .. cons_no_quote_c .. "['‿]*)(" .. cons_c .. "+" .. vowel_c .. ")", '%1.%2')
	-- (4) resyllabify C.[lr] as .C[lr] for C = various obstruents
	text = rsub(text, "([bkdfgpstv])%.([lr])", ".%1%2")
	-- (5) resyllabify d.ʒ, C.w, C.ɥ as .dʒ, .Cw, .Cɥ (C.w comes from
	--     written Coi; C.ɥ comes from written Cuill; post-consonantal j
	--     generated later)
	text = rsub(text, "d%.ʒ", ".dʒ")
	text = rsub(text, '(' .. cons_c .. ')%.([wWɥ])', '.%1%2')
	-- [(6) resyllabify C.sC as Cs.C]
	-- comment this out; seems wrong in most cases e.g. perçois should be
	-- /pɛʁ.swa/ not */pɛʁs.wa/, and only maybe makes sense in expansion
	-- and other words in exC-, but even then it makes just as much sense
	-- to write /ɛk.spɑ̃.sjɔ̃/ as /ɛks.pɑ̃.sjɔ̃/.
	-- text = rsub(text, '(' .. cons_c .. ')%.s(' .. cons_c .. ')', "%1s.%2")
	-- (7) eliminate diaeresis (note, uï converted early)
	text = rsub(text, '[äëïöüÿ]', remove_diaeresis_from_vowel)
	table.insert(debug, text)

	--n
	text = rsub(text,'([éi])%.e[mn]','%1.ɛ̃') -- bien, européen
	text = rsub(text,'je[mn]','jɛ̃') -- moyen
	text = rsub(text,'wA[mn]','wɛ̃') -- coin, point
	text = rsub(text,'[ae][mn]','ɑ̃')
	text = rsub(text,'[ɛi][mn]','ɛ̃')
	text = rsub(text,'o[mn]','ɔ̃')
	text = rsub(text,'[øœ][mn]','œ̃') -- à jeun
	text = rsub(text,'um⁀','ɔm⁀') -- maximum, aquarium, etc.
	text = rsub(text,'u[mn]','œ̃')
	table.insert(debug,text)

	--single vowels
	text = rsub(text, 'â', 'ɑ')
	text = rsub(text, 'az', 'ɑz')
	text = rsub(text, 'ă', 'a')
	text = rsub(text, 'e%.j', 'ɛ.j') -- réveiller
	text = rsub(text, 'e%.', 'ə.')
	text = rsub(text, 'e⁀', 'ə⁀')
	text = rsub(text, 'æ%.', 'é.')
	text = rsub(text, 'æ⁀', 'é⁀')
	text = rsub(text, '[eèêæ]','ɛ')
	text = rsub(text, 'é', 'e')
	text = rsub(text, 'o⁀', 'O⁀')
	text = rsub(text, 'o(%.?)z', 'O%1z')
	text = rsub(text, '[oŏ]', 'ɔ')
	text = rsub(text, 'ô', 'o')
	text = rsub(text, 'u', 'y')

	--other consonants
	text = rsub(text,'r','ʁ')
	text = rsub(text,'g','ɡ') -- use IPA variant of g
	table.insert(debug,text)
	
	--various changes for vowels in context
	--delete final schwa
	text = rsub(text,'%.([^ə.]+)ə⁀','%1⁀')
	--delete schwa after any vowel (agréerons, soierie)
	text = rsub(text, '(' .. vowel_c .. ').ə', '%1')

	--i/u/ou -> glide before vowel
	-- -- do from right to left to handle continuions and étudiions
	--    correctly
	-- -- do repeatedly until no more subs (required due to right-to-left
	--    action)
	-- -- convert to capital J and W as	a signal that we can convert them
	--    back to /i/ and /u/ later on if they end up preceding a schwa or
	--    following two consonants in the same syllable, whereas we don't
	--    do this to j from other sources (y or ill) and w from other
	--    sources (w or oi); will be lowercased later; not necessary to do 
	--    something similar to ɥ, which can always be converted back to /y/
	--    because it always originates from /y/.
	while true do
		local new_text = rsub(text,'^(.*)i%.?(' .. vowel_c .. ')','%1J%2')
		new_text = rsub(new_text,'^(.*)y%.?(' .. vowel_c .. ')','%1ɥ%2')
		new_text = rsub(new_text,'^(.*)U%.?(' .. vowel_c .. ')','%1W%2')
		if new_text == text then
			break
		end
		text = new_text
	end

	--hack for agréions, pronounced with /j.j/
	text = rsub(text, 'e.J', 'ej.J')

	--glides -> full vowels after two consonants in the same syllable
	--(e.g. fl, tr, etc.), but only glides from original i/u/ou (see above)
	--and not in the sequence 'ui' (e.g. bruit), and only when the second
	--consonant is l or r (not in abstiennent)
	text = rsub(text,'(' .. cons_c .. '[lʁ])J(' .. vowel_c .. ')','%1i.j%2')
	text = rsub(text,'(' .. cons_c .. '[lʁ])W(' .. vowel_c .. ')','%1u.%2')
	text = rsub(text,'(' .. cons_c .. '[lʁ])ɥ(' .. vowel_no_i_c .. ')','%1y.%2')
	-- remove ' that prevents interpretation of letter sequences; do this
	-- before deleting internal schwas
	text = rsub(text, "'", "")
	-- make optional internal schwa in VCəCV sequence (FIXME, needs to be
	-- smarter); needs to happen after /e/ -> /ɛ/ before schwa in next
	-- syllable and after removing ' (or we need to take ' into account);
	-- include .* so we go right-to-left, convert to uppercase schwa so
	-- we can handle sequences of schwas and not get stuck if we want to
	-- leave a schwa alone.
	text = rsub_repeatedly(text,'(.*' .. vowel_c .. '[⁀‿ .]*)(' .. cons_c .. ')([⁀‿ .]*)ə([⁀‿ .]*)(' .. cons_c .. ')([⁀‿ .]*' .. vowel_c .. ')',
		function(v1,c1,sep1,sep2,c2,v2)
			if no_delete_schwa_between[c1 .. c2] then
				return v1 .. c1 .. sep1 .. 'Ə' .. sep2 .. c2 .. v2
			else
				return v1 .. c1 .. sep1 .. '(Ə)' .. sep2 .. c2 .. v2
			end
		end)

	-- lowercase any uppercase letters (AOUMNJW etc.); they were there to
	-- prevent certain later rules from firing
	text = ulower(text)
	
	--ĕ forces a pronounced schwa
	text = rsub(text, 'ĕ', 'ə')

	text = rsub(text, '⁀', '')
	if do_debug == 'yes' then return table.concat(debug, ':') end
	return text
end

return export
