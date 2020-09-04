local export = {}

--[=[

Authorship: Ben Wing <benwing2>

]=]

local iut = require("Module:inflection utilities")

local lang = require("Module:languages").getByCode("hi")

local current_title = mw.title.getCurrentTitle()
local PAGENAME = current_title.text

local u = mw.ustring.char
local rsplit = mw.text.split
local rfind = mw.ustring.find
local rmatch = mw.ustring.match
local rsubn = mw.ustring.gsub
local usub = mw.ustring.sub

-- vowel diacritics; don't display nicely on their own
local AA = u(0x093e)
local AI = u(0x0948)
local AU = u(0x094c)
local E = u(0x0947)
local I = u(0x093f)
local II = u(0x0940)
local O = u(0x094b)
local U = u(0x0941)
local UU = u(0x0942)
local R = u(0x0943)
local VIRAMA = u(0x094d)
local TILDE = u(0x0303)

local diacritic_to_independent = {
	[AA] = "आ", [I] = "इ", [II] = "ई", [U] = "उ", [UU] = "ऊ",
	[R] = "ऋ", [E] = "ए", [AI] = "ऐ", [O] = "ओ", [AU] = "औ",
}

local diacritic_list = {}
local independent_list = {}
for dia, ind in pairs(diacritic_to_independent) do
	table.insert(independent_list, ind)
	table.insert(diacritic_list, dia)
end

local diacritics = table.concat(diacritic_list)
local independents = table.concat(independent_list) .. "अ"
local vowels = diacritics .. independents
local transliterated_diacritics = "aāãeẽiīĩoõuūũṛ" .. TILDE


-- version of rsubn() that discards all but the first return value
local function rsub(term, foo, bar)
	local retval = rsubn(term, foo, bar)
	return retval
end


function export.split_term_respelling(term)
	if rfind(term, "//") then
		local split = rsplit(term, "//")
		if #split ~= 2 then
			error("Term with respelling should have only one // in it: " .. term)
		end
		return unpack(split)
	else
		return term, nil
	end
end


function export.transliterate_respelling(phon)
	if not phon then
		return nil
	end
	local hindi_range = "[ऀ-ॿ*]" -- 0x0900 to 0x097f; include *, which is a translit signal
	if rfind(phon, "^%-?" .. hindi_range) then
		return rsub(lang:transliterate(phon), "%.", "")
	end
	return phon -- already transliterated
end


function export.add_form(base, stem, translit_stem, slot, ending, footnotes, link_words)
	if not ending then
		return
	end

	local function combine_stem_ending(stem, ending)
		if ending == "" then
			return stem
		elseif rfind(stem, VIRAMA .. "$") and rfind(base.lemma, VIRAMA .. "$") then
			stem = rsub(stem, VIRAMA .. "$", "")
		end
		if stem == "" or rfind(stem, "[" .. vowels .. "]$") then
			-- A diacritic at the beginning of the ending should be converted to its independent form
			-- if the stem does not end in a consonant.
			if rfind(ending, "^[" .. diacritics .. "]") then
				local ending_first = usub(ending, 1, 1)
				ending = (diacritic_to_independent[ending_first] or ending_first) .. usub(ending, 2)
			end
		end
		-- Don't convert independent letters to diacritics after consonants because of cases like मई
		-- where the independent letter belongs after the consonant.
		local result = stem .. ending
		if link_words then
			-- Add links around the words.
			result = "[[" .. rsub(result, " ", "]] [[") .. "]]"
		end
		return result
	end

	local function combine_stem_ending_tr(stem, ending)
		if ending == "" then
			return stem
		-- When adding a non-null ending, remove final '-a' from the stem, but only
		-- if the transliterated lemma also ended in '-a'. This way, a noun like
		-- पुनश्च transliterated 'punaśca' "postscript" gets oblique plural transliterated
		-- 'punaścõ' with dropped '-a', but मई transliterated 'maī' "May" with
		-- transliterated stem 'ma' and ending singular ending '-ī' doesn't get the
		-- '-a' dropped. A third case we need to handle correctly is इंटरव्यू "interview";
		-- if we truncate the final ू  '-ū' and then transliterate, we get 'iṇṭarvya'
		-- with extra '-a' that may appear in the transliteration if we're not careful.
		--
		-- HACK! Handle प्रातः correctly by checking specially for lemma_translit ending
		-- in -a or -aḥ and ending starting with a vowel. The proper way to do this
		-- correctly that handles all of the above cases requires access to the original
		-- (Devanagari) ending, and checks to see if the stem ends in '-a' and the ending
		-- begins with a Devanagari diacritic; in this case, it's correct to elide the '-a'.
		elseif rfind(stem, "a$") and rfind(base.lemma_translit, "aḥ?$") and
			rfind(ending, "^[" .. transliterated_diacritics .. "]") then
			stem = rsub(stem, "a$", "")
		end
		return stem .. ending
	end

	footnotes = iut.combine_footnotes(base.footnotes, footnotes)
	local ending_obj = iut.generate_form(ending, footnotes)
	if translit_stem then
		stem = {form = stem, translit = translit_stem}
	end
	iut.add_forms(base.forms, slot, stem, ending_obj, combine_stem_ending, lang,
		combine_stem_ending)
end


function export.strip_ending_from_stem(stem, translit_stem, ending)
	local new_stem = rmatch(stem, "^(.*)" .. ending .. "$")
	if not new_stem then
		error("Internal error: Lemma or stem " .. stem .. " should end in " .. ending)
	end
	local ending_translit = lang:transliterate(ending)
	local new_translit_stem = rmatch(translit_stem, "^(.*)" .. ending_translit .. "$")
	if not new_translit_stem then
		error("Unable to strip ending " .. ending .. " (transliterated " .. ending_translit .. ") from transliteration " .. translit_stem)
	end
	return new_stem, new_translit_stem
end


function export.strip_ending(base, ending)
	return export.strip_ending_from_stem(base.lemma, base.lemma_translit, ending)
end


-- Normalize all lemmas, splitting out phonetic respellings and substituting
-- the pagename for blank lemmas.
function export.normalize_all_lemmas(alternant_multiword_spec)
	iut.map_word_specs(alternant_multiword_spec, function(base)
		base.lemma, base.phon_lemma = export.split_term_respelling(base.lemma)
		if base.lemma == "" then
			base.lemma = PAGENAME
		end
		base.orig_lemma = base.lemma
		base.orig_lemma_no_links = require("Module:links").remove_links(base.lemma)
		base.lemma = base.orig_lemma_no_links
		local translit
		if base.phon_lemma then
			base.lemma_translit = export.transliterate_respelling(base.phon_lemma)
		else
			base.lemma_translit = lang:transliterate(base.lemma)
		end
	end)
end


--[=[
Remove redundant translit. We need to do all declension using manual translit
because declined forms of words like अचकन "jacket" and कालाधन "blood money" may
need manual translit, even though the base form itself doesn't need manual
translit. For example, अचकन has default translit ''ackan'', which is correct,
but the oblique plural अचकनों has default translit ''acaknõ'', which is incorrect
(correct is ''ackanõ'', with stem translit as in the base). In general, such
words need manual translit that forces the stem of the inflected form to have
the same translit as the stem of the base form. We want to remove redundant
manual translit so that accelerator-generated entries don't have unnecessary
manual translit in them. Finally, we need to remove redundant manual translit at
the very end, not as we decline each part of a multiword expression (which we
used to do), because of cases like कालाधन, which declines as if written काला धन.
Hence it has oblique plural कालेधनों, which has incorrect default translit
''kaledhnõ'' instead of correct ''kaledhanõ'', even though the individual parts
काले and धनों both have correct default translits.
]=]
function export.remove_redundant_translit(alternant_multiword_spec)
	for slot, forms in pairs(alternant_multiword_spec.forms) do
		alternant_multiword_spec.forms[slot] = iut.map_forms(forms, function(form, translit)
			if translit and lang:transliterate(form) == translit then
				return form, nil
			else
				return form, translit
			end
		end)
	end
end


return export
