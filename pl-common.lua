local export = {}

local u = mw.ustring.char
local rsplit = mw.text.split
local rfind = mw.ustring.find
local rmatch = mw.ustring.match
local rsubn = mw.ustring.gsub
local ulen = mw.ustring.len
local uupper = mw.ustring.upper

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


export.TEMP_CH = u(0xFFF0) -- used to substitute ch temporarily in the default-reducible code
export.TEMP_SOFT_LABIAL = u(0xFFF1) -- used to indicate that a labial consonant is soft and needs i after it

local lc_vowel = "aeiouyąęó"
local uc_vowel = uupper(lc_vowel)
export.vowel = lc_vowel .. uc_vowel
export.vowel_c = "[" .. export.vowel .. "]"
export.non_vowel_c = "[^" .. export.vowel .. "]"
local lc_cons = "bcćdfghjklłmnńprqstvwxzżź" .. export.TEMP_CH .. export.TEMP_SOFT_LABIAL
local uc_cons = uupper(lc_cons)
export.cons = lc_cons .. uc_cons
export.cons_c = "[" .. export.cons .. "]"
export.lowercase = lc_vowel .. lc_cons
export.lowercase_c = "[" .. export.lowercase .. "]"
export.uppercase = uc_vowel .. uc_cons
export.uppercase_c = "[" .. export.uppercase .. "]"

local lc_velar = "kgh"
local uc_velar = uupper(lc_velar)
export.velar = lc_velar .. uc_velar
export.velar_c = "[" .. export.velar .. "]"

local lc_plain_labial = "mpbfvw"
local lc_labial = lc_plain_labial .. export.TEMP_SOFT_LABIAL
local uc_plain_labial = uupper(lc_plain_labial)
local uc_labial = uupper(lc_labial)
export.plain_labial = lc_plain_labial .. uc_plain_labial
export.labial = lc_labial .. uc_labial
export.labial_c = "[" .. export.labial .. "]"

local lc_paired_palatal = "ćńśź"
local uc_paired_palatal = uupper(lc_paired_palatal)
export.paired_palatal = lc_paired_palatal .. uc_paired_palatal
local lc_paired_plain = "cnsz"
local uc_paired_plain = uupper(lc_paired_plain)
export.paired_plain = lc_paired_plain .. uc_paired_plain
export.paired_palatal_to_plain = {
	["ć"] = "c",
	["Ć"] = "C",
	["ń"] = "n",
	["Ń"] = "N",
	["ś"] = "s",
	["Ś"] = "S",
	["ź"] = "z",
	["Ź"] = "Z",
}
export.paired_plain_to_palatal = {}
for k, v in pairs(export.paired_palatal_to_plain) do
	export.paired_plain_to_palatal[v] = k
end
export.paired_palatal_to_plain[export.TEMP_SOFT_LABIAL] = ""
for labial in mw.ustring.gmatch(export.plain_labial, ".") do
	export.paired_plain_to_palatal[labial] = labial .. export.TEMP_SOFT_LABIAL
end

-- Soft consonant requiring 'i' glide in spelling to indicate this.
local lc_soft_requiring_i_glide = lc_paired_palatal .. export.TEMP_SOFT_LABIAL
local uc_soft_requiring_i_glide = uupper(lc_soft_requiring_i_glide)
export.soft_requiring_i_glide = lc_soft_requiring_i_glide .. uc_soft_requiring_i_glide
export.soft_requiring_i_glide_c = "[" .. export.soft_requiring_i_glide .. "]"


-- Soft consonant that cannot take 'y' after it (excluding velar k/g, which often need special handling).
local lc_soft = lc_soft_requiring_i_glide .. "jl"
local uc_soft = uupper(lc_soft)
export.soft = lc_soft .. uc_soft
export.soft_c = "[" .. export.soft .. "]"


-- Ends in a soft consonant that requires 'i' glide in spelling to indicate this.
function export.ends_in_soft_requiring_i_glide(word)
	return rfind(word, export.soft_requiring_i_glide_c .. "$")
end


-- Ends in a soft consonant that cannot take 'y' after it (excluding velar k/g, which often need special handling).
function export.ends_in_soft(word)
	return rfind(word, export.soft_c .. "$")
end


-- Ends in a soft velar sound that cannot take 'y' after it (k/g).
function export.ends_in_soft_velar(word)
	return word:find("[kg]$")
end


-- Ends in a soft consonant or velar that cannot take 'y' after it.
function export.ends_in_soft_or_velar(word)
	return export.ends_in_soft(word) or export.ends_in_soft_velar(word)
end


-- Ends in an originally soft sound that has been hardened and must take 'y' not 'i' after it.
function export.ends_in_hardened_soft_cons(word)
	return rfind(word, "[cż]$") or word:find("[cdrs]z$")
end


function export.apply_vowel_alternation(alt, stem, is_vowel_stem, noerror)
	local modstem, origvowel
	if alt == "quant" then
		local modtable
		if is_vowel_stem then
			-- vowel in vowel-ending stem "lengthens" before non-vowel ending: ę -> ą, o -> ó
			modtable = {
				["ę"] = "ą",
				["o"] = "ó",
			}
		else
			-- vowel in non-vowel-ending stem "shortens" before vowel ending: ą -> ę, ó -> o
			modtable = {
				["ą"] = "ę",
				["ó"] = "o",
			}
		end
		local fromvowels = {}
		for k, v in pairs(modtable) do
			table.insert(fromvowels, k)
		end
		modstem = rsub(stem, "([" .. table.concat(fromvowels) .. "])(" .. export.cons_c .. "+)$",
			function(vowel, post)
				origvowel = vowel
				return modtable[vowel] .. post
			end
		)
		if modstem == stem then
			if noerror then
				return stem, nil
			else
				error(("Quantitative vowel alternation can't be applied because stem '%s' doesn't have %s as its last vowel"):format(
					stem, require("Module:table").serialCommaJoin(fromvowels, {dontTag = true, conj = "or"})))
			end
		end
	elseif alt == "umlaut" then
		-- [[gwiazda]] -> dat/loc 'gwieźdie'; [[gniazdo]] -> loc 'gnieździe'; [[światło]] -> loc 'świetle';
		-- [[ciało]] -> loc 'ciele'; [[czoło]] -> loc 'czele'; [[lato]] -> loc 'lecie'; [[miasto]] -> loc 'mieście' (likewise
		-- [[ciasto]]); [[anioł]] -> loc/voc 'aniele'; [[niebiosa]] (neut pl) -> loc_pl 'niebiesiech'; [[kościół]] ->
		-- gen 'kościoła', loc/voc 'kościele'; [[popiół]] -> gen 'popiołu', loc/voc 'popiele'; [[świat]] -> loc/voc 'świecie';
		-- [[kwiat]] -> loc/voc 'kwiecie'.
		--
		-- In the other direction; [[przyjaciel]] -> nom_pl_1/nom_pl_2 'przyjaciele' but gen_pl 'przyjaciół',
		-- ins_pl 'przyjaciółmi', dat_pl 'przyjaciołom', loc_pl 'przyjaciołach'.
		modstem = rsub(stem, "([ao])(" .. export.cons_c .. "+)$", "e%1")
		if modstem == stem then
			if noerror then
				return stem, nil
			else
				error(("Umlaut vowel alternation can't be applied because stem '%s' doesn't have a or o as its last vowel"):format(
					stem))
			end
		end
	elseif alt then
		error("Internal error: Unrecognized vowel alternation indicator '" .. alt .. "'")
	else
		return stem, nil
	end
	return modstem, origvowel
end


local function make_try(word)
	return function(from, to)
		local subbed
		word, subbed = rsubb(word, "^(.*)" .. from .. "$", "%1" .. to)
		if subbed then
			return word
		end
		return nil
	end
end


function export.soften_masc_pers_pl(word)
	local try = make_try(word)
	return
		try("ch", "si") or
		try("h", "si") or
		try("sł", "śli") or
		try("zł", "źli") or
		try("łł", "lli") or
		try("ł", "li") or
		try("r", "rzy") or
		try("sn", "śni") or
		try("zn", "źni") or
		try("st", "ści") or
		try("t", "ci") or
		try("zd", "ździ") or
		try("d", "dzi") or
		try("sz", "si") or
		try("([cdr]z)", "%2y") or
		try("([fwmpbnsz])", "%2i") or
		try("stk", "scy") or -- [[wszystek]] -> 'wszysci'
		try("k", "cy") or
		try("g", "dzy") or
		word .. "y"
end


function export.soften_dat_loc_sg(word)
	local try = make_try(word)
	return
		try("ch", "sze") or
		try("h", "że") or
		try("sł", "śle") or
		try("zł", "źle") or
		try("ł", "lle") or
		try("ł", "le") or
		try("(" .. export.vowel_c .. ")j", "%2i") or
		try("([jl])", "%2i") or
		try("r", "rze") or
		try("sn", "śnie") or
		try("zn", "źnie") or
		-- n below
		try("sm", "śmie") or
		-- FIXME: zm? The old code had a note '-zm should not be palatalized' but also had zm -> zmie.
		-- m below
		try("st", "ście") or
		try("t", "cie") or
		try("zd", "ździe") or
		try("d", "dzie") or
		try("([cdsr]z)", "%2y") or
		try("([fwmpbnsz])", "%2ie") or
		try("([fwmpbcnsz]i)", "%2") or
		-- not -stk; lots of examples like [[stażystka]] with -stce
		try("k", "ce") or
		try("g", "dze") or
		word .. "y"
end


--[=[
Issues:
1. What is the vowel added?
2. When do we palatalize the sound (not the letter) before the e?
3. When do we depalatalize the sound before the e?
4. When do we palatalize the sound after the e?
5. When do we depalatalize the sound after the e?
]=]
function export.reduce(word)
	-- FIXME
	local pre, letter, vowel, post = rmatch(word, "^(.*)([" .. export.cons .. "y%-])([eě])(" .. export.cons_c .. "+)$")
	if not pre then
		return nil
	end
	if vowel == "ě" and rfind(letter, "[" .. export.paired_plain .. "]") then
		letter = export.paired_plain_to_palatal[letter]
	end
	return pre .. letter .. post
end


--[=[
Issues:
1. What is the vowel added?
* Apparently always e (or ie to indicate palatalization), except in -Cj, where C in [csz], where y is inserted,
  e.g. [[funkcja]] -> archaic 'funkcyj'; also in -Ci, where C in [cdrt], where y is inserted, e.g. [[parodia]]/
  [[brewerie]] (FIXME: maybe not a case of dereduction);  FIXME: do we ever insert i after a soft-only version of C?
2. When do we palatalize the sound (not the letter) before the e?
* (a) When k or g;
  (b) when second letter is c and first letter is a labial, e.g. [[owca]] -> 'owiec', [[skrzypce]] -> 'skrzypiec';
      also in żelazce/żelezce -> 'żelaziec'/'żeleziec' and [[Zamojsce]] -> 'Zamojsiec'; not when first letter is
	  unpalatalizable [jlż] or rz (e.g. [[Siedlce]] -> 'Siedlec', [[Węgrzce]] -> 'Węgrzec'); also not when the c is
	  pronounced as /k/ e.g. [[Athabasca]], [[nesca]], [[villanesca]] with -sec;
  (c) when second letter is n and first letter is a labial or [tsn] (not [dhjlłrzż]/ch/cz/sz), e.g. [[trumna]] ->
      'trumien', [[panna]] -> 'panien' (+ 12 others), [[hrywna]] -> 'hrywien' (+ ~70 others, mostly in -ówna),
	  [[drewno]] -> 'drewien', [[płotno]] -> 'płocien' (likewise Kłótno/półpłótno/Krytno/Korytno/Szczytno/Żytno),
	  [[krosno]] -> 'krosien' (likewise Krosno/Olesno/Chrosno/Prosno); NOTE: not in -sna, e.g. [[ciosna]] ->
	  'ciosn/ciosen' (likewise Ciosna/wiosna), [[sosna]] -> 'sosen' (likewise zwiesna/wiosna and 15 proper names);
  (d) when second letter in ni (i.e. ń) and first letter is d or w (only in [[studnia]]/[[Studnie]] -> 'studzien',
	  [[głownia]] -> 'głowien', [[głównia]] -> 'główien'); not in [[kuchnia]] -> 'kuchen', [[lutnia]] -> 'luteń'.
3. When do we depalatalize the sound before the e?
* Never.
4. When do we palatalize the sound after the e?
* Never.
5. When do we depalatalize the sound after the e?
* Sometimes if ni (i.e. ń); specifically in [[stajnia]] -> 'stajen' (archaic), [[kuchnia]] -> 'kuchen' (archaic); also
  [[suknia]] -> 'sukien', likewise [[minisuknia]], [[Białosuknia]], [[głownia]], [[głównia]], [[dżwignia]]; also
  [[studnia]] -> 'studzien', likewise [[Studnie]]; also [[wiśnia]] -> 'wisien', likewise [[workowiśnia]],
  [[laurowiśnia]], [[sośnia]], [[Mięsośnia]]; but not in [[wisznia]]/[[Wisznia]] -> 'wiszeń'/'Wiszeń', likewise
  [[lutnia]] -> 'luteń'.

]=]
function export.dereduce(base, stem)
	local pre, letter, post = rmatch(stem, "^(.*)(" .. export.cons_c .. ")(" .. export.cons_c .. ")$")
	if not pre then
		return nil
	end
	local epvowel = 
	if rfind(letter, "[" .. export.paired_palatal .. "]") then
		letter = export.paired_palatal_to_plain[letter]
	end
	return pre .. letter .. "e" .. post
end


function export.convert_paired_plain_to_palatal(stem, ending)
	-- FIXME
	--if ending and not rfind(ending, "^[ěií]") then
	--	return stem
	--end
	local stembegin, lastchar = rmatch(stem, "^(.*)([" .. export.paired_plain .. export.plain_labial .. "])$")
	if lastchar then
		return stembegin .. export.paired_plain_to_palatal[lastchar]
	else
		return stem
	end
end


function export.convert_paired_palatal_to_plain(stem, ending)
	-- For stems that alternate between ci/ni/si/zi and ć/ń/ś/ź, we always maintain the stem in the latter format and
	-- convert to the corresponding plain as needed. Likewise, stems ending in /bj/ /vj/ etc. use TEMP_SOFT_LABIAL.
	-- FIXME
	if ending and not rfind(ending, "^" .. export.vowel_c) then
		stem = stem:gsub(export.TEMP_SOFT_LABIAL, "")
		return stem, ending
	end
	local stembegin, lastchar = rmatch(stem, "^(.*)([" .. export.paired_palatal .. export.TEMP_SOFT_LABIAL .. "])$")
	if lastchar then
		ending = ending and rsub(ending, "^i", "") or nil
		stem = stembegin .. export.paired_palatal_to_plain[lastchar] .. "i"
	end
	-- FIXME
	-- 'E' has served its purpose of preventing the e -> ě conversion after a paired palatal (i.e. it depalatalizes
	-- paired palatals).
	-- ending = ending and rsub(ending, "^E", "e") or nil
	return stem, ending
end


function export.combine_stem_ending(base, slot, stem, ending)
	if stem == "?" then
		return "?"
	else
		if ending:find("^y") and export.ends_in_soft_or_velar(stem) then
			ending = ending:gsub("^y", "i")
		end
		-- Convert ńi -> ni, and ńe (or any other vowel) -> nie.
		stem, ending = export.convert_paired_palatal_to_plain(stem, ending)
		if rfind(stem, export.vowel_c .. "j$") and ending:find("^i") then
			stem = stem:gsub("j$", "")
		end
		-- FIXME: Review the following w/r/t EFTA dat_sg EF-cie
		if base and base.all_uppercase then
			stem = uupper(stem)
		end
		return stem .. ending
	end
end


return export
