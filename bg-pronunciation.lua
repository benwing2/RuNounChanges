local export = {}

local rsubn = mw.ustring.gsub
local rmatch = mw.ustring.match
local U = mw.ustring.char

local GRAVE = U(0x300)
local ACUTE = U(0x301)
local PRIMARY = U(0x2C8)
local SECONDARY = U(0x2CC)
local TIE = U(0x361)
local FRONTED = U(0x31F)
local DOTUNDER = U(0x323)
local vowels = "aæɐəɤeɛioɔuʊʉ"
local vowels_c = "[" .. vowels .. "]"
local non_vowels_c = "[^" .. vowels .. "]"
local cons = "bvɡdʒzjklmnprstfxʃɣʲ" .. TIE
local cons_c = "[" .. cons .. "]"
local accents = PRIMARY .. SECONDARY
local accents_c = "[" .. accents .. "]"

-- single characters that map to IPA sounds
local phonetic_chars_map = {
	["а"] = "a",
	["б"] = "b",
	["в"] = "v",
	["г"] = "ɡ",
	["д"] = "d",
	["е"] = "ɛ",
	["ж"] = "ʒ",
	["з"] = "z",
	["и"] = "i",
	["й"] = "j",
	["к"] = "k",
	["л"] = "l",
	["м"] = "m",
	["н"] = "n",
	["о"] = "ɔ",
	["п"] = "p",
	["р"] = "r",
	["с"] = "s",
	["т"] = "t",
	["у"] = "u",
	["ф"] = "f",
	["х"] = "x",
	["ц"] = "t" .. TIE .. "s",
	["ч"] = "t" .. TIE .. "ʃ",
	["ш"] = "ʃ",
	["щ"] = "ʃt",
	["ъ"] = "ɤ",
	["ь"] = "ʲ",
	["ю"] = "ʲu",
	["я"] = "ʲa",

	[GRAVE] = SECONDARY,
	[ACUTE] = PRIMARY
}

local devoicing = {
	["b"] = "p", ["d"] = "t", ["ɡ"] = "k",
	["z"] = "s", ["ʒ"] = "ʃ",
	["v"] = "f"
}

local voicing = {
	["p"] = "b", ["t"] = "d", ["k"] = "ɡ",
	["s"] = "z", ["ʃ"] = "ʒ", ["x"] = "ɣ",
	["f"] = "v"
}


-- Prefixes where, if they occur at the beginning of the word and the stress is on the next syllable, we place the
-- syllable division directly after the prefix. For example, the default syllable-breaking algorithm would convert
-- безбра́чие to беˈзбрачие; but because it begins with без-, we convert it to безˈбрачие. Note that we don't (yet?)
-- convert измра́ to изˈмра instead of default измˈра, although we probably should.
--
-- Think twice before putting prefixes like на-, пре- and от- here, because of the existence of над-, пред-, and о-,
-- which are also prefixes.
local prefixes = {"без", "въз", "възпроиз", "из", "наиз", "поиз", "превъз", "произ", "раз"}


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


function export.remove_pron_notations(text, remove_grave)
	text = rsub(text, "[" .. DOTUNDER .. "]", "")
	-- Remove grave accents from annotations but maybe not from phonetic respelling
	if remove_grave then
		text = mw.ustring.toNFC(rsub(mw.ustring.toNFD(text), GRAVE, ""))
	end
	return text
end

	
function export.toIPA(term, endschwa)
	if type(term) == "table" then -- called from a template or a bot
		endschwa = term.args.endschwa
		term = term.args[1]
	end
		
	local origterm = term
	
	term = rsub(mw.ustring.toNFC(term), "й", "j")
	term = mw.ustring.toNFD(mw.ustring.lower(term))

	if term:find(GRAVE) and not term:find(ACUTE) then
		error("Use acute accent, not grave accent, for primary stress: " .. origterm)
	end

	-- allow DOTUNDER to signal same as endschwa=1	
	term = rsub(term, "а(" .. accents_c .. "?)" .. DOTUNDER, "ъ%1")
	term = rsub(term, "я(" .. accents_c .. "?)" .. DOTUNDER, "ʲɤ%1")
	term = rsub(term, ".", phonetic_chars_map)

	-- Mark word boundaries
	term = rsub(term, "(%s+)", "#%1#")
	term = "#" .. term .. "#"

	-- Convert verbal and definite endings
	if endschwa then
		term = rsub(term, "a(" .. PRIMARY .. "t?#)", "ɤ%1")
	end

	-- Change ʲ to j after vowels or word-initially
	term = rsub(term, "([" .. vowels .. "#]" .. accents_c .. "?)ʲ", "%1j")

	-------------------- Move stress ---------------

	-- First, move leftwards over the vowel.
	term = rsub(term, "(" .. vowels_c .. ")(" .. accents_c .. ")", "%2%1")
	-- Then, move leftwards over j or soft sign.
	term = rsub(term, "([jʲ])(" .. accents_c .. ")", "%2%1")
	-- Then, move leftwards over a single consonant.
	term = rsub(term, "(" .. cons_c .. ")(" .. accents_c .. ")", "%2%1")
	-- Then, move leftwards over Cl/Cr combinations where C is an obstruent (NOTE: IPA ɡ).
	term = rsub(term, "([bdɡptkxfv]" .. ")(" .. accents_c .. ")([rl])", "%2%1%3")
	-- Then, move leftwards over kv/gv (NOTE: IPA ɡ).
	term = rsub(term, "([kɡ]" .. ")(" .. accents_c .. ")(v)", "%2%1%3")
	-- Then, move leftwards over sC combinations, where C is a stop or resonant (NOTE: IPA ɡ).
	term = rsub(term, "([sz]" .. ")(" .. accents_c .. ")([bdɡptkvlrmn])", "%2%1%3")
	-- Then, move leftwards over affricates not followed by a consonant.
	term = rsub(term, "([td]" .. TIE .. "?)(" .. accents_c .. ")([szʃʒ][" .. vowels .. "ʲ])", "%2%1%3")
	-- If we ended up in the middle of a tied affricate, move to its right.
	term = rsub(term, "(" .. TIE .. ")(" .. accents_c .. ")(" .. cons_c .. ")", "%1%3%2")
	-- Then, move leftwards over any remaining consonants at the beginning of a word.
	term = rsub(term, "#(" .. cons_c .. "*)(" .. accents_c .. ")", "#%2%1")
	-- Then correct for known prefixes.
	for _, prefix in ipairs(prefixes) do
		prefix_prefix, prefix_final_cons = rmatch(prefix, "^(.-)(" .. cons_c .. "*)$")
		if prefix_final_cons then
			-- Check for accent moved too far to the left into a prefix, e.g. безбрачие accented as беˈзбрачие instead
			-- of безˈбрачие
			term = rsub(term, "#(" .. prefix_prefix .. ")(" .. accents_c .. ")(" .. prefix_final_cons .. ")", "#%1%3%2")
		end
	end
	-- Finally, if there is an explicit syllable boundary in the cluster of consonants where the stress is, put it there.
	-- First check for accent to the right of the explicit syllable boundary.
	term = rsub(term, "(" .. cons_c .. "*)%.(" .. cons_c .. "*)(" .. accents_c .. ")(" .. cons_c .. "*)", "%1%3%2%4")
	-- Then check for accent to the left of the explicit syllable boundary.
	term = rsub(term, "(" .. cons_c .. "*)(" .. accents_c .. ")(" .. cons_c .. "*)%.(" .. cons_c .. "*)", "%1%3%2%4")
	-- Finally, remove any remaining syllable boundaries.
	term = rsub(term, "%.", "")

	-------------------- Vowel reduction (in unstressed syllables) ---------------
	local function reduce_vowel(vowel)
		return rsub(vowel, "[aɔɤu]", { ["a"] = "ə", ["ɔ"] = "o", ["ɤ"] = "ə", ["u"] = "ʊ" })
	end

	-- FIXME: This needs to be rewritten entirely and moved above stress movement.
	-- /a/ directly before the stress is [ɐ].
	term = rsub(term, "a(" .. non_vowels_c .. "*" .. accents_c .. ")", "ɐ%1")
	-- Reduce all vowels before the stress, except if the word has no accent at all. (FIXME: This is presumably
	-- intended for single-syllable words without accents, but if the word is multisyllabic without accents,
	-- presumably all vowels should be reduced.)
	term = rsub(term, "(#[^#" .. accents .. "]*)(.)", function(a, b)
		if b == "#" then
			return a .. b
		else
			return reduce_vowel(a) .. b
		end
	end)
	-- Reduce all vowels after the accent except the first vowel after the accent mark (which is stressed).
	term = rsub(term, "(" .. accents_c .. "[^aɛiɔuɤ#]*[aɛiɔuɤ])([^#" .. accents .. "]*)", function(a, b)
		return a .. reduce_vowel(b)
	end)
	-- /u/ directly before the stress is [u] not [ʊ]. (FIXME: Correct?)
	term = rsub(term, "ʊ(" .. non_vowels_c .. "*" .. accents_c .. ")", "u%1")

	-------------------- Vowel assimilation to adjacent consonants (fronting/raising) ---------------
	term = rsub_repeatedly(term, "([ʲj])[aɐə](" .. non_vowels_c .. "-[ʲj])", "%1æ%2")
	term = rsub_repeatedly(term, "([ʲj])u(" .. non_vowels_c .. "-[ʲj])", "%1ʉ%2")
	term = rsub(term, "([ʃʒʲj])([aouɤ])", "%1%2" .. FRONTED)
	term = rsub(term, "([ʃʒ])ɛ", "%1e")

	-- Palatalisation
	term = rsub(term, "([kɡxl])([ieɛ])", "%1ʲ%2")

	-- Hard l
	term = rsub_repeatedly(term, "l([^ʲ])", "ɫ%1")

	-- Voicing assimilation
	term = rsub(term, "([bdɡzʒv" .. TIE .. "]*)(" .. accents_c .. "?[ptksʃfx#])", function(a, b)
		return rsub(a, ".", devoicing) .. b end)
	term = rsub(term, "([ptksʃfx" .. TIE .. "]*)(" .. accents_c .. "?[bdɡzʒ])", function(a, b)
		return rsub(a, ".", voicing) .. b end)
	term = rsub(term, "n(" .. accents_c .. "?[ɡk]+)", "ŋ%1")
	term = rsub(term, "m(" .. accents_c .. "?[fv]+)", "ɱ%1")

	-- Sibilant assimilation
	term = rsub(term, "[sz](" .. accents_c .. "?[td]?" .. TIE .. "?)([ʃʒ])", "%2%1%2")

	-- Reduce consonant clusters
	term = rsub(term, "([szʃʒ])[td](" .. accents_c .. "?)([tdknml])", "%2%1%3")
	term = rsub(term, "([sʃ])t#", "%1(t)#")

	-- ijC -> iːC, ij# -> iː#
	term = rsub(term, "ij(" .. non_vowels_c .. ")", "iː%1")

	-- Strip hashes
	term = rsub(term, "#", "")

	return term
end

function export.show(frame)
	local params = {
		[1] = {},
		["endschwa"] = { type = "boolean" },
		["ann"] = {},
	}
	
	local title = mw.title.getCurrentTitle()
	
	local args = require("Module:parameters").process(frame:getParent().args, params)
	local term = args[1] or title.nsText == "Template" and "при́мер" or title.text

	local ipa = export.toIPA(term, args.endschwa)
	
	ipa = "[" .. ipa .. "]"
	ipa = require("Module:IPA").format_IPA_full(require("Module:languages").getByCode("bg"), { { pron = ipa } } )

	local anntext
	if args.ann == "1" or args.ann == "y" then
		-- remove secondary stress annotations
		anntext = "'''" .. export.remove_pron_notations(term, true) .. "''':&#32;"
	elseif args.ann then
		anntext = "'''" .. args.ann .. "''':&#32;"
	else
		anntext = ""
	end

	return anntext .. ipa
end

return export
