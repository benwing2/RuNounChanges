local export = {}

--[=[

Authorship: Ben Wing <benwing2>

]=]

local m_links = require("Module:links")
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

-- version of rsubn() that discards all but the first return value
local function rsub(term, foo, bar)
	local retval = rsubn(term, foo, bar)
	return retval
end


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

export.diacritic_to_independent = {
	[AA] = "आ", [I] = "इ", [II] = "ई", [U] = "उ", [UU] = "ऊ",
	[R] = "ऋ", [E] = "ए", [AI] = "ऐ", [O] = "ओ", [AU] = "औ",
}

local diacritic_list = {}
local independent_list = {}
for dia, ind in pairs(export.diacritic_to_independent) do
	table.insert(independent_list, ind)
	table.insert(diacritic_list, dia)
end

export.diacritics = table.concat(diacritic_list)
export.independents = table.concat(independent_list) .. "अ"
export.vowels = export.diacritics .. export.independents
export.transliterated_diacritics = "aāãeẽiīĩoõuūũṛ" .. TILDE


-- variant codes
export.VAR1 = u(0xFFF0)
export.VAR2 = u(0xFFF1)
export.VAR3 = u(0xFFF2)
export.VAR4 = u(0xFFF3)
export.VAR5 = u(0xFFF4)
export.VAR6 = u(0xFFF5)
export.var_code_c = "[" .. export.VAR1 .. export.VAR2 .. export.VAR3 .. export.VAR4 .. export.VAR5 .. export.VAR6 .. "]"
export.not_var_code_c = "[^" .. export.VAR1 .. export.VAR2 .. export.VAR3 .. export.VAR4 .. export.VAR5 .. export.VAR6 .. "]"

export.index_to_variant_code = {
	[1] = export.VAR1,
	[2] = export.VAR2,
	[3] = export.VAR3,
	[4] = export.VAR4,
	[5] = export.VAR5,
	[6] = export.VAR6,
}

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


function export.add_form(base, stem, translit_stem, slot, ending, footnotes, link_words, double_word)
	if not ending then
		return
	end

	local function combine_stem_ending(stem, ending)
		local result
		if ending == "" then
			result = stem
		else
			if rfind(stem, VIRAMA .. "$") and rfind(base.lemma, VIRAMA .. "$") then
				stem = rsub(stem, VIRAMA .. "$", "")
			end
			if stem == "" or rfind(stem, "[" .. export.vowels .. "]$") then
				-- A diacritic at the beginning of the ending should be converted to its independent form
				-- if the stem does not end in a consonant.
				if rfind(ending, "^[" .. export.diacritics .. "]") then
					local ending_first = usub(ending, 1, 1)
					ending = (export.diacritic_to_independent[ending_first] or ending_first) .. usub(ending, 2)
					-- Diacritic e goes above the line and requires anusvara, but independent e does not
					-- go above the line and prefers chandrabindu in endings.
					ending = rsub(ending, "एं", "एँ")
				end
			end
			-- Don't convert independent letters to diacritics after consonants because of cases like मई
			-- where the independent letter belongs after the consonant.
			result = stem .. ending
		end
		if link_words then
			-- Add links around the words.
			result = "[[" .. rsub(result, " ", "]] [[") .. "]]"
		end
		if double_word then
			-- hack to support the progressive form of verbs, which is e.g. करते-करते
			return result .. "-" .. result
		else
			return result
		end
	end

	local function combine_stem_ending_tr(stem, ending)
		local result
		if ending == "" then
			result = stem
		else
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
			if base.lemma_translit and rfind(stem, "a$") and rfind(base.lemma_translit, "aḥ?$") and
				rfind(ending, "^[" .. export.transliterated_diacritics .. "]") then
				stem = rsub(stem, "a$", "")
			end
			result = stem .. ending
		end
		if double_word then
			-- hack to support the progressive form of verbs, which is e.g. करते-करते
			return result .. "-" .. result
		else
			return result
		end
	end

	footnotes = iut.combine_footnotes(base.footnotes, footnotes)
	local ending_obj = iut.combine_form_and_footnotes(ending, footnotes)
	if translit_stem then
		stem = {form = stem, translit = translit_stem}
	end
	iut.add_forms(base.forms, slot, stem, ending_obj, combine_stem_ending, lang,
		combine_stem_ending_tr)
end


function export.strip_ending_from_stem(stem, translit_stem, ending)
	local new_stem = rmatch(stem, "^(.*)" .. ending .. "$")
	if not new_stem then
		error("Internal error: Lemma or stem " .. stem .. " should end in " .. ending)
	end
	local new_translit_stem
	if translit_stem then
		local ending_translit = lang:transliterate(ending)
		new_translit_stem = rmatch(translit_stem, "^(.*)" .. ending_translit .. "$")
		if not new_translit_stem then
			error("Unable to strip ending " .. ending .. " (transliterated " .. ending_translit .. ") from transliteration " .. translit_stem)
		end
	end
	return new_stem, new_translit_stem
end


function export.strip_ending(base, ending)
	return export.strip_ending_from_stem(base.lemma, base.lemma_translit, ending)
end


-- Normalize all lemmas, splitting out phonetic respellings and substituting
-- the pagename for blank lemmas. Set `lemma_translit` to the transliteration of the
-- respelling, or (if `always_transliterate` is given) to the transliteration of the
-- lemma. `always_transliterate` should be specified for nouns and adjectives, where the
-- lemma transliteration should be carried over to all remaining forms (hence since अंकल
-- is transliterated 'aṅkal', the oblique plural अंकलों should be 'aṅkalõ' not #'aṅklõ',
-- the default transliteration). But it should not be specified for verbs, where this
-- carry-over doesn't apply: even though उगालना has transliteration 'ugalnā', the
-- perfective participle उगला has default transliteration 'uglā' not the carry-over
-- transliteration #'ugalā'.
function export.normalize_all_lemmas(alternant_multiword_spec, always_transliterate)
	iut.map_word_specs(alternant_multiword_spec, function(base)
		base.lemma, base.phon_lemma = export.split_term_respelling(base.lemma)
		if base.lemma == "" then
			base.lemma = PAGENAME
		end
		base.orig_lemma = base.lemma
		base.orig_lemma_no_links = m_links.remove_links(base.lemma)
		base.lemma = base.orig_lemma_no_links
		if base.phon_lemma then
			base.lemma_translit = export.transliterate_respelling(base.phon_lemma)
		elseif always_transliterate then
			base.lemma_translit = lang:transliterate(base.lemma)
		end
	end)
end


--[=[
Remove redundant translit. We need to do all declension of nouns and adjectives using
manual translit because declined forms of nouns like अचकन "jacket" and कालाधन
"black money" may need manual translit, even though the base form itself doesn't
need manual translit. For example, अचकन has default translit ''ackan'', which is
correct, but the oblique plural अचकनों has default translit ''acaknõ'', which is
incorrect (correct is ''ackanõ'', with stem translit as in the base). In general,
such words need manual translit that forces the stem of the inflected form to have
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
			if translit and lang:transliterate(m_links.remove_links(form)) == translit then
				return form, nil
			else
				return form, translit
			end
		end)
	end
end


function export.get_variants(form)
	return rsub(form, export.not_var_code_c, "")
end


function export.remove_variant_codes(form)
	return rsub(form, export.var_code_c, "")
end


-- Add variant codes to all slots with more than one form. The intention of variant
-- codes is to prevent there being N^2 slot variants in a verb like [[हिलना-डुलना]] in
-- slots that normally have N variants. Rather than combining all variants of [[हिलना]]
-- with all variants of [[डुलना]] for the given slot, we only want to combine parallel
-- variants. We implement this by tagging each variant with a "variant code" character
-- and rejecting combinations with mismatching variant code characters.
function export.add_variant_codes(base)
	for slot, forms in pairs(base.forms) do
		if #forms > 1 then
			local index = 0
			base.forms[slot] = iut.map_forms(forms, function(form, translit)
				index = index + 1
				local varcode = export.index_to_variant_code[index]
				if not varcode then
					error("Internal error: Encountered too many variants (" .. #forms .. "), no more variant codes available")
				end
				return form .. varcode, translit
			end)
		end
	end
end


return export
