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

local VIRAMA = u(0x094d)


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


function export.add_form(base, stem, translit_stem, slot, ending, footnotes)
	if not ending then
		return
	end

	local function combine_stem_ending(stem, ending)
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
		elseif rfind(stem, "a$") and rfind(base.lemma_translit, "a$") then
			return rsub(stem, "a$", "") .. ending
		elseif rfind(stem, VIRAMA .. "$") and rfind(base.lemma, VIRAMA .. "$") then
			return rsub(stem, VIRAMA .. "$", "") .. ending
		else
			return stem .. ending
		end
	end

	footnotes = iut.combine_footnotes(base.footnotes, footnotes)
	local ending_obj = iut.generate_form(ending, footnotes)
	if translit_stem then
		-- Check to see if manual translit for form would be same as auto translit
		-- and if so, remove it, so it doesn't get propagated to accelerators.
		local form_with_ending = combine_stem_ending(stem, ending)
		local form_with_ending_translit = lang:transliterate(form_with_ending)
		local translit_with_ending = combine_stem_ending(translit_stem, lang:transliterate(ending))
		if form_with_ending_translit ~= translit_with_ending then
			stem = {form = stem, translit = translit_stem}
		end
	end
	iut.add_forms(base.forms, slot, stem, ending_obj, combine_stem_ending, lang,
		combine_stem_ending)
end


function export.strip_ending(base, ending)
	local stem = rmatch(base.lemma, "^(.*)" .. ending .. "$")
	if not stem then
		error("Internal error: Lemma " .. base.lemma .. " should end in " .. ending)
	end
	local ending_translit = lang:transliterate(ending)
	local translit_stem = rmatch(base.lemma_translit, "^(.*)" .. ending_translit .. "$")
	if not translit_stem then
		error("Internal error: Unable to strip ending " .. ending .. " (transliterated " .. ending_translit .. ") from transliteration " .. base.lemma_translit)
	end
	return stem, translit_stem	
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
