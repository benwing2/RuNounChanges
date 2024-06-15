local export = {}
-- [[Module:IPA/data]]

local force_cat = false -- for testing

local m_data = mw.loadData("Module:IPA/data")
local m_str_utils = require("Module:string utilities")
local m_symbols = mw.loadData("Module:IPA/data/symbols")
local pron_qualifier_module = "Module:User:Benwing2/pron qualifier"
local qualifier_module = "Module:User:Benwing2/qualifier"
local references_module = "Module:references"
local syllables_module = "Module:syllables"
local utilities_module = "Module:utilities"
local m_syllables -- [[Module:syllables]]; loaded below if needed

local concat = table.concat
local find = string.find
local gmatch = m_str_utils.gmatch
local gsub = string.gsub
local insert = table.insert
local len = m_str_utils.len
local listToText = mw.text.listToText
local match = string.match
local sub = string.sub
local u = m_str_utils.char
local ufind = m_str_utils.find
local ugsub = m_str_utils.gsub
local umatch = m_str_utils.match
local usub = m_str_utils.sub

local namespace = mw.title.getCurrentTitle().namespace
local is_content_page = namespace == 0 or namespace == 118

local function track(page)
	require("Module:debug/track")("IPA/" .. page)
	return true
end

local function process_maybe_split_categories(split_output, categories, prontext, lang, errtext)
	if split_output ~= "raw" then
		if categories[1] then
			categories = require(utilities_module).format_categories(categories, lang, nil, nil, force_cat)
		else
			categories = ""
		end
	end
	if split_output then -- for use of IPA in links, etc.
		if errtext then
			return prontext, categories, errtext
		else
			return prontext, categories
		end
	else
		return prontext .. (errtext or "") .. categories
	end
end

--[==[
Format a line of one or more IPA pronunciations as {{tl|IPA}} would do it, i.e. with a preceding {"IPA:"} followed by
the word {"key"} linking to an Appendix page describing the language's phonology, and with an added category
{{cd|<var>lang</var> terms with IPA pronunciation}}. Other than the extra preceding text and category, this is identical
to {format_IPA_multiple()}, and the considerations described there in the documentation apply here as well. There is a
single parameter `data`, an object with the following fields:
* `lang` is an object representing the language of the pronunciations, which is used when adding cleanup categories for
   pronunciations with invalid phonemes; for determining how many syllables the pronunciations have in them, in order to
   add a category such as [[:Category:Italian 2-syllable words]] (for certain languages only); for adding a category
   {{cd|<var>lang</var> terms with IPA pronunciation}}; and for determining the proper sort keys for categories. Unlike
   for {format_IPA_multiple()}, `lang` may not be {nil}.
* `items` is a list of pronunciations, in exactly the same format as for {format_IPA_multiple()}.
* `err`, if not {nil}, is a string containing an error message to use in place of the link to the language's phonology.
* `separator`: the overall separator to use when separating formatted items. Defaults to {", "}. Except in the simplest
  cases, you should consider setting this to an empty string and using the per-item `separator` field in `items`.
* `sort_key`: explicit sort key used for categories.
* `no_count`: Suppress adding a {#-syllable words} category such as [[:Category:Italian 2-syllable words]]. Note that
  only certain languages add such categories to begin with, because it depends on knowing how to count syllables in a
  given language, which depends on the phonology of the language. Also, this does not suppress the addition of cleanup
  or other categories. If you need them suppressed, use `split_output` to return the categories separately and ignore
  them.
* `split_output`: If not given, the return value is a concatenation of the formatted pronunciation and formatted
  categories. Otherwise, two values are returned: the formatted pronunciation and the categories. If `split_output` is
  the value {"raw"}, the categories are returned in list form, where the list elements are a combination of category
  strings and category objects of the form suitable for passing to {format_categories()} in [[Module:utilities]]. If
  `split_output` is any other value besides {nil}, the categories are returned as a pre-formatted concatenated string.
* `include_langname`: If specified, prefix the result with the language name, followed by a colon.
* `q`: {nil} or a list of left qualifiers (as in {{tl|q}}) to display at the beginning, before the formatted
  pronunciation and preceding {"IPA:"}.
* `qq`: {nil} or a list of right qualifiers to display after all formatted pronunciations.
* `a`: {nil} or a list of left accent qualifiers (as in {{tl|a}}) to display at the beginning, before the formatted
  pronunciation and preceding {"IPA:"}.
* `aa`: {nil} or a list of right accent qualifiers to display all formatted pronunciations.
]==]
function export.format_IPA_full(data)
	if type(data) ~= "table" or data.getCode then
		error("Must now supply a table of arguments to format_IPA_full(); first argument should be that table, not a language object")
	end
	local lang = data.lang
	local items = data.items
	local err = data.err
	local separator = data.separator
	local sort_key = data.sort_key
	local no_count = data.no_count
	local split_output = data.split_output
	local q = data.q
	local qq = data.qq
	local a = data.a
	local aa = data.aa
	local include_langname = data.include_langname

	local hasKey = m_data.langs_with_infopages

	if not lang or not lang.getCode then
		error("Must specify language to format_IPA_full()")
	end
	local langname = lang:getCanonicalName()

	local prefix_text
	if err then
		prefix_text = '<span class="error">' .. err .. '</span>'
	else
		if hasKey[lang:getCode()] then
			prefix_text = "Appendix:" .. langname .. " pronunciation"
		else
			prefix_text = "wikipedia:" .. langname .. " phonology"
		end
		prefix_text = "[[" .. prefix_text .. "|key]]"
	end

	local prefix = "[[Wiktionary:International Phonetic Alphabet|IPA]]<sup>(" .. prefix_text .. ")</sup>:&#32;"

	local IPAs, categories = export.format_IPA_multiple(lang, items, separator, no_count, "raw")

	if is_content_page then
		insert(categories, {
			cat = langname .. " terms with IPA pronunciation",
			sort_key = sort_key
		})
	end

	local prontext = prefix .. IPAs
	if q and q[1] or qq and qq[1] or a and a[1] or aa and aa[1] then
		prontext = require(pron_qualifier_module).format_qualifiers {
			lang = lang,
			text = prontext,
			q = q,
			qq = qq,
			a = a,
			aa = aa,
		}
	end
	if include_langname then
		prontext = langname .. ": " .. prontext
	end
	return process_maybe_split_categories(split_output, categories, prontext, lang)
end

local function split_phonemic_phonetic(pron)
	local reconstructed, phonemic, phonetic = match(pron, "^(%*?)(/.-/)%s+(%[.-%])$")
	if reconstructed then
		return reconstructed .. phonemic, reconstructed .. phonetic
	else
		return pron, nil
	end
end

local function determine_repr(pron)
	local repr_mark = {}
	local repr, reconstructed

	-- remove initial asterisk before representation marks, used on some Reconstruction pages
	if sub(pron, 1, 1) == "*" then
		reconstructed = true
		pron = sub(pron, 2)
	end

	local representation_types = {
		['/'] = { right = '/', type = 'phonemic', },
		['['] = { right = ']', type = 'phonetic', },
		['⟨'] = { right = '⟩', type = 'orthographic', },
		['-'] = { type = 'rhyme' },
	}

	repr_mark.i, repr_mark.f, repr_mark.left, repr_mark.right = ufind(pron, '^(.).-(.)$')

	local representation_type = representation_types[repr_mark.left]

	if representation_type then
		if representation_type.right then
			if repr_mark.right == representation_type.right then
				repr = representation_type.type
			end
		else
			repr = representation_type.type
		end
	else
		repr = nil
	end

	return repr, reconstructed
end

local function hasInvalidSeparators(transcription)
	if match(transcription, "%.\203[\136\140]") then -- [ˈˌ]
		return true
	else
		return false
	end
end

--[==[
Format a line of one or more bare IPA pronunciations (i.e. without any preceding {"IPA:"} and without adding to a
category {{cd|<var>lang</var> terms with IPA pronunciation}}). Individual pronunciations are formatted using
{format_IPA()} and are combined with separators, qualifiers, pre-text, post-text, etc. to form a line of pronunciations.
Parameters accepted are:
* `lang` is an object representing the language of the pronunciations, which is used when adding cleanup categories for
   pronunciations with invalid phonemes; for determining how many syllables the pronunciations have in them, in order to
   add a category such as [[:Category:Italian 2-syllable words]] (for certain languages only); and for computing the
   proper sort keys for categories. `lang` may be {nil}.
* `items` is a list of pronunciations, each of which is an object with the following properties:
** `pron`: the pronunciation, in the same format as is accepted by {format_IPA()}, i.e. it should be either phonemic
     (surrounded by {/.../}), phonetic (surrounded by {[...]}), orthographic (surrounded by {⟨...⟩}) or a rhyme
	 (beginning with a hyphen);
** `pretext`: text to display directly before the formatted pronunciation, inside of any qualifiers or accent
     qualifiers;
** `posttext`: text to display directly after the formatted pronunciation, inside of any qualifiers or accent
     qualifiers;
** `q` or `qualifiers`: {nil} or a list of left qualifiers (as in {{tl|q}}) to display before the formatted
     pronunciation; note that `qualifiers` is deprecated;
** `qq`: {nil} or a list of right qualifiers to display after the formatted pronunciation;
** `a`: {nil} or a list of left accent qualifiers (as in {{tl|a}}) to display before the formatted pronunciation;
** `aa`: {nil} or a list of right accent qualifiers to after before the formatted pronunciation;
** `refs`: {nil} or a list of references or reference specs to add after the pronunciation and any posttext and
     qualifiers; the value of a list item is either a string containing the reference text (typically a call to a
	 citation template such as {{tl|cite-book}}, or a template wrapping such a call), or an object with fields `text`
	 (the reference text), `name` (the name of the reference, as in {{cd|<nowiki><ref name="foo">...</ref></nowiki>}}
	 or {{cd|<nowiki><ref name="foo" /></nowiki>}}) and/or `group` (the group of the reference, as in
	 {{cd|<nowiki><ref name="foo" group="bar">...</ref></nowiki>}} or
	 {{cd|<nowiki><ref name="foo" group="bar"/></nowiki>}}); this uses a parser function to format the reference
	 appropriately and insert a footnote number that hyperlinks to the actual reference, located in the
	 {{cd|<nowiki><references /></nowiki>}} section;
** `note`: {nil} or a single reference string or object of the same format as in `refs`; this is deprecated;
** `separator`: the separator text to insert directly before the formatted pronunciation and all qualifiers, accent
   qualifiers and pre-text; if used, you should explicitly set the outer `separator` parameter to an empty string.
* `separator`: the overall separator to use when separating formatted items. Defaults to {", "}. Except in the simplest
  cases, you should consider setting this to an empty string and using the per-item `separator` field documented above.
* `no_count`: Suppress adding a {#-syllable words} category such as [[:Category:Italian 2-syllable words]]. Note that
  only certain languages add such categories to begin with, because it depends on knowing how to count syllables in a
  given language, which depends on the phonology of the language. Also, this does not suppress the addition of cleanup
  categories. If you need them suppressed, use `split_output` to return the categories separately and ignore them.
* `split_output`: If not given, the return value is a concatenation of the formatted pronunciation and formatted
  categories. Otherwise, two values are returned: the formatted pronunciation and the categories. If `split_output` is
  the value {"raw"}, the categories are returned in list form, where the list elements are a combination of category
  strings and category objects of the form suitable for passing to {format_categories()} in [[Module:utilities]]. If
  `split_output` is any other value besides {nil}, the categories are returned as a pre-formatted concatenated string.
]==]
function export.format_IPA_multiple(lang, items, separator, no_count, split_output)
	local categories = {}
	separator = separator or ', '

	if not lang then
		track("format-multiple-nolang")
	end

	-- Format
	if not items[1] then
		if namespace == 10 then -- Template
			insert(items, {pron = "/aɪ piː ˈeɪ/"})
		else
			insert(categories, "Pronunciation templates without a pronunciation")
		end
	end

	local bits = {}

	for _, item in ipairs(items) do
		local bit

		-- If the pronunciation is entirely empty, allow this and don't do anything, so that e.g. the pretext and/or
		-- posttext can be specified to force something like ''unknown'' to appear in place of the pronunciation
		-- (as happens e.g. when ? is used as a respelling in [[Module:ca-IPA]]; see [[guèiser]] for an example).
		if item.pron == "" then
			bit = ""
		else
			local item_categories, errtext
			bit, item_categories, errtext = export.format_IPA(lang, item.pron, "raw")
			bit = bit .. errtext
			for _, cat in ipairs(item_categories) do
				insert(categories, cat)
			end
		end

		if item.pretext then
			bit = item.pretext .. bit
		end

		if item.posttext then
			bit = bit .. item.posttext
		end

		local has_qualifiers = item.q and item.q[1] or item.qq and item.qq[1] or item.qualifiers and item.qualifiers[1]
			or item.a and item.a[1] or item.aa and item.aa[1]
		local has_gloss_or_pos = item.gloss or item.pos
		if has_qualifiers or has_gloss_or_pos then
			-- FIXME: Currently we tack the gloss and POS (in that order) onto the end of the regular left qualifiers.
			-- Should we do something different?
			local q = item.q
			if has_gloss_or_pos then
				q = mw.clone(item.q) or {}
				if item.gloss then
					local m_qualifier = require(qualifier_module)
					insert(q, m_qualifier.wrap_qualifier_css("“", "quote") .. item.gloss ..
						m_qualifier.wrap_qualifier_css("”", "quote"))
				end
				if item.pos then
					insert(q, item.pos)
				end
			end

			bit = require("Module:pron qualifier").format_qualifiers {
				lang = lang,
				text = bit,
				q = q,
				qq = item.qq,
				qualifiers = item.qualifiers,
				a = item.a,
				aa = item.aa,
			}
		end

		if item.refs or item.note then
			local refspecs
			if item.note then
				-- FIXME: eliminate item.note in favor of item.refs. Use tracking to find places
				-- that use item.note.
				refspecs = {item.note}
				track("note")
			else
				refspecs = item.refs
			end
			if #refspecs > 0 then
				bit = bit .. require(references_module).format_references(refspecs)
			end
		end

		if item.separator then
			bit = item.separator .. bit
		end

		insert(bits, bit)

		--[=[	[[Special:WhatLinksHere/Wiktionary:Tracking/IPA/syntax-error]]
				The length or gemination symbol should not appear after a syllable break or stress symbol.	]=]

		-- The nature of the following pattern match is such that we don't have to split a combined '/.../ [...]' spec
		-- into its parts in order to process.
		if match(item.pron, "[.\203][\136\140]?\203[\144\145]") then -- [.ˈˌ][ːˑ]
			track("syntax-error")
		end

		if lang then
			-- Add syllable count if the language's diphthongs are listed in [[Module:syllables]].
			-- Don't do this if the term has spaces, a liaison mark (‿) or isn't in mainspace.
			if not no_count and namespace == 0 then
				m_syllables = m_syllables or require(syllables_module)
				local langcode = lang:getCode()
				if m_data.langs_to_generate_syllable_count_categories[langcode] then
					local phonemic, phonetic = split_phonemic_phonetic(item.pron)
					local use_it
					if not phonetic then -- not a '/.../ [...]' combined pronunciation
						local repr = determine_repr(phonemic)
						if m_data.langs_to_use_phonetic_notation[langcode] then
							use_it = repr == "phonetic" and phonemic or nil
						else
							use_it = repr == "phonemic" or phonemic or nil
						end
					elseif repr == "phonetic" then
						use_it = phonetic
					elseif repr == "phonemic" then
						use_it = phonemic
					end
					-- Note: two uses of find with plain patterns is much faster than umatch with [ ‿].
					if use_it and not (find(use_it, " ") or find(use_it, "‿")) then
						local syllable_count = m_syllables.getVowels(use_it, lang)
						if syllable_count then
							insert(categories, lang:getCanonicalName() .. " " .. syllable_count ..
								"-syllable words")
						end
					end
				end
			end

			-- The nature of hasInvalidSeparators() is such that we don't have to split a combined '/.../ [...]' spec into
			-- its parts in order to process.
			if lang:getCode() == "en" and hasInvalidSeparators(item.pron) then
				insert(categories, "IPA for English using .ˈ or .ˌ")
			end
		end
	end

	return process_maybe_split_categories(split_output, categories, concat(bits, separator), lang)
end

--[=[
Format a single IPA pronunciation, which cannot be a combined spec (such as {/.../ [...]}). This has been extracted from
{format_IPA()} to allow the latter to handle such combined specs. This works like {format_IPA()} but requires that
pre-created {err} (for error messages) and {categories} lists be passed in, and adds any generated error messages and
categories to those lists. A single value is returned, the pronunciation, which is usually the same as passed in, but
may have HTML added surrounding invalid characters so they appear in red.
]=]
local function format_one_IPA(lang, pron, err, categories)
	-- Remove wikilinks, so that wikilink brackets are not misinterpreted as indicating phonetic transcription
	local without_links = gsub(pron, "%[%[[^|%]]+|([^%]]+)%]%]", "%1")
	without_links = gsub(without_links, "%[%[[^%]]+%]%]", "%1")

	-- Detect whether this is a phonemic or phonetic transcription
	local repr, reconstructed = determine_repr(without_links)

	if reconstructed then
		pron = sub(pron, 2)
		without_links = sub(without_links, 2)
	end

	-- If valid, strip the representation marks
	if repr == "phonemic" then
		pron = usub(pron, 2, -2)
		without_links = usub(without_links, 2, -2)
	elseif repr == "phonetic" then
		pron = usub(pron, 2, -2)
		without_links = usub(without_links, 2, -2)
	elseif repr == "orthographic" then
		pron = usub(pron, 2, -2)
		without_links = usub(without_links, 2, -2)
	elseif repr == "rhyme" then
		pron = usub(pron, 2)
		without_links = usub(without_links, 2)
	else
		insert(categories, "IPA pronunciations with invalid representation marks")
		-- insert(err, "invalid representation marks")
		-- Removed because it's annoying when previewing pronunciation pages.
	end

	if pron == "" then
		insert(categories, "IPA pronunciations with no pronunciation present")
	end

	-- Check for obsolete and nonstandard symbols
	for i, symbol in ipairs(m_data.nonstandard) do
		local result
		for nonstandard in gmatch(pron, symbol) do
			if not result then
				result = {}
			end
			insert(result, nonstandard)
			insert(categories,
				{cat = "IPA pronunciations with obsolete or nonstandard characters", sort_key = nonstandard}
			)
		end

		if result then
			insert(err, "obsolete or nonstandard characters (" .. concat(result) .. ")")
			break
		end
	end

	--[[ Check for invalid symbols after removing the following:
			1. wikilinks (handled above)
			2. paired HTML tags
			3. bolding
			4. italics
			5. HTML entity for space
			6. asterisk at beginning of transcription
			7. comma followed by spacing characters
			8. superscripts enclosed in superscript parentheses		]]
	local found_HTML
	local result = gsub(without_links, "<(%a+)[^>]*>([^<]+)</%1>",
		function(tagName, content)
			found_HTML = true
			return content
		end)
	result = gsub(result, "'''([^']*)'''", "%1")
	result = gsub(result, "''([^']*)''", "%1")
	result = gsub(result, "&[^;]+;", "") -- This may catch things that are not valid character entities.
	result = gsub(result, "^%*", "")
	result = ugsub(result, ",%s+", "")

	-- VS15
	local vs15_class = "[" .. m_symbols.add_vs15 .. "]"
	if umatch(pron, vs15_class) then
		local vs15 = u(0xFE0E)
		if find(result, vs15) then
			result = gsub(result, vs15, "")
			pron = gsub(pron, vs15, "")
		end
		pron = ugsub(pron, "(" .. vs15_class .. ")", "%1" .. vs15)
	end

	if result ~= "" then
		local suggestions = {}
		for k, v in pairs(m_symbols.invalid) do
			if find(result, k, 1, true) then
				insert(suggestions, k .. " with " .. v)
			end
		end
		if suggestions[1] then
			suggestions = listToText(suggestions)
			if is_content_page then
				error("Invalid IPA: replace " .. suggestions)
			else
				insert(err, "replace " .. suggestions)
			end
		end
		result = ugsub(result, "⁽[".. m_symbols.superscripts .. "]+⁾", "")
		local per_lang_valid
		if lang then
			per_lang_valid = m_symbols.per_lang_valid[lang:getCode()]
		end
		per_lang_valid = per_lang_valid or ""
		result = ugsub(result, "[" .. m_symbols.valid .. per_lang_valid .. "]", "")
		if result ~= "" then
			local category = "IPA pronunciations with invalid IPA characters"
			if not is_content_page then
				category = category .. "/non_mainspace"
			end
			insert(categories, category)
			insert(err, "invalid IPA characters (" .. result .. ")")
		end
	end

	if found_HTML then
		insert(categories, "IPA pronunciations with paired HTML tags")
	end

	if repr == "phonemic" or repr == "rhyme" then
		if lang and m_data.phonemes[lang:getCode()] then
			local valid_phonemes = m_data.phonemes[lang:getCode()]
			local rest = pron
			local phonemes = {}

			while #rest > 0 do
				local longestmatch, longestmatch_len = "", 0

				local rest_init = sub(rest, 1, 1)
				if rest_init == "(" or rest_init == ")" then
					longestmatch = rest_init
					longestmatch_len = 1
				else
					for _, phoneme in ipairs(valid_phonemes) do
						local phoneme_len = len(phoneme)
						if phoneme_len > longestmatch_len and usub(rest, 1, phoneme_len) == phoneme then
							longestmatch = phoneme
							longestmatch_len = len(longestmatch)
						end
					end
				end

				if longestmatch_len > 0 then
					insert(phonemes, longestmatch)
					rest = usub(rest, longestmatch_len + 1)
				else
					local phoneme = usub(rest, 1, 1)
					insert(phonemes, "<span style=\"color: red\">" .. phoneme .. "</span>")
					rest = usub(rest, 2)
					insert(categories, "IPA pronunciations with invalid phonemes/" .. lang:getCode())
					track("invalid phonemes/" .. phoneme)
				end
			end

			pron = concat(phonemes)
		end

		if repr == "phonemic" then
			pron = "/" .. pron .. "/"
		else
			pron = "-" .. pron
		end
	elseif repr == "phonetic" then
		pron = "[" .. pron .. "]"
	elseif repr == "orthographic" then
		pron = "⟨" .. pron .. "⟩"
	end

	if reconstructed then
		pron = "*" .. pron
	end

	return pron
end

--[==[
Format an IPA pronunciation. This wraps the pronunciation in appropriate CSS classes and adds cleanup categories and
error messages as needed. The pronunciation `pron` should be either phonemic (surrounded by {/.../}), phonetic
(surrounded by {[...]}), orthographic (surrounded by {⟨...⟩}), a rhyme (beginning with a hyphen) or a combined
phonemic/phonetic spec (of the form {/.../ [...]}). `lang` indicates the language of the pronunciation and can be {nil}.
If not {nil}, and the specified language has data in [[Module:IPA/data]] indicating the allowed phonemes, then the page
will be added to a cleanup category and an error message displayed next to the outputted pronunciation. Note that {lang}
also determines sort key processing in the added cleanup categories. If `split_output` is not given, the return value is a
concatenation of the formatted pronunciation, error messages and formatted cleanup categories. Otherwise, three values are
returned: the formatted pronunciation, the cleanup categories and the concatenated error messages. If `split_output` is
the value {"raw"}, the cleanup categories are returned in list form, where the list elements are a combination of category
strings and category objects of the form suitable for passing to {format_categories()} in [[Module:utilities]]. If
`split_output` is any other value besides {nil}, the cleanup categories are returned as a pre-formatted concatenated
string.
]==]
function export.format_IPA(lang, pron, split_output)
	local err = {}
	local categories = {}

	-- `pron` shouldn't contain ref tags.
	if match(pron, "\127'\"`UNIQ%-%-ref%-[%dA-F]+%-QINU`\"'\127") then
		error("<ref> tags found inside pronunciation parameter.")
	end

	if not lang then
		track("format-nolang")
	end

	local phonemic, phonetic = split_phonemic_phonetic(pron)
	pron = format_one_IPA(lang, phonemic, err, categories)
	if phonetic then
		phonetic = format_one_IPA(lang, phonetic, err, categories)
		pron = pron .. " " .. phonetic
	end

	if err[1] then
		err = '<span class="previewonly error" style="font-size: small;>&#32;' .. concat(err, ", ") .. "</span>"
	else
		err = ""
	end

	return process_maybe_split_categories(split_output, categories, '<span class="IPA">' .. pron .. "</span>", lang,
		err)
end

function export.format_enPR_full(data)
	local prefix = "[[Appendix:English pronunciation|enPR]]: "
	local lang = require("Module:languages").getByCode("en")
	local parts = {}

	for _, item in ipairs(data.items) do
		local part = '<span class="AHD enPR">' .. item.pron .. "</span>"

		if item.q and item.q[1] or item.qq and item.qq[1] or item.a and item.a[1] or item.aa and item.aa[1] then
			part = require("Module:pron qualifier").format_qualifiers {
				lang = lang,
				text = part,
				q = item.q,
				qq = item.qq,
				a = item.a,
				aa = item.aa,
			}
		end
		insert(parts, part)
	end

	local prontext = prefix .. concat(parts, ", ")
	if data.q and data.q[1] or data.qq and data.qq[1] or data.a and data.a[1] or data.aa and data.aa[1] then
		prontext = require(pron_qualifier_module).format_qualifiers {
			lang = lang,
			text = prontext,
			q = data.q,
			qq = data.qq,
			a = data.a,
			aa = data.aa,
		}
	end

	return prontext
end

return export
