local export = {}
-- [[Module:IPA/data]]

local force_cat = false -- for testing

local m_data = mw.loadData("Module:IPA/data") -- [[Module:IPA/data]]
local m_str_utils = require("Module:string utilities")
local m_symbols = mw.loadData("Module:IPA/data/symbols") -- [[Module:IPA/data/symbols]]
local syllables_module = "Module:syllables"
local utilities_module = "Module:utilities"
local pron_qualifier_module = "Module:pron qualifier"
local m_syllables -- [[Module:syllables]]; loaded below if needed

local find = m_str_utils.find
local gmatch = m_str_utils.gmatch
local gsub = m_str_utils.gsub
local len = m_str_utils.len
local sub = m_str_utils.sub
local u = m_str_utils.char

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
to {format_IPA_multiple()}, and the considerations described there in the documentation apply here as well. The
preferred calling convention is to pass in a single parameter `data`, an object with the following fields:
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
* `q`: {nil} or a list of left qualifiers (as in {{tl|q}}) to display at the beginning, before the formatted
  pronunciation and preceding {"IPA:"}.
* `qq`: {nil} or a list of right qualifiers to display after all formatted pronunciations.
* `a`: {nil} or a list of left accent qualifiers (as in {{tl|a}}) to display at the beginning, before the formatted
  pronunciation and preceding {"IPA:"}.
* `aa`: {nil} or a list of right accent qualifiers to display all formatted pronunciations.

You can currently pass in all but `q`, `qq`, `a` and `aa` as separate parameters, although this will be going away.
]==]
function export.format_IPA_full(data_or_lang, items, err, separator, sort_key, no_count, split_output)
	local lang, q, qq, a, aa
	if type(data_or_lang) == "table" and not data_or_lang.getCode then
		-- new-style
		lang = data_or_lang.lang
		items = data_or_lang.items
		err = data_or_lang.err
		separator = data_or_lang.separator
		sort_key = data_or_lang.sort_key
		no_count = data_or_lang.no_count
		split_output = data_or_lang.split_output
		q = data_or_lang.q
		qq = data_or_lang.qq
		a = data_or_lang.a
		aa = data_or_lang.aa
	else
		lang = data_or_lang
	end

	local IPA_key, key_link, err_text, prefix, IPAs, categories
	local hasKey = m_data.langs_with_infopages
	local namespace = mw.title.getCurrentTitle().nsText

	if not lang then
		track("format-full-nolang")
	end

	if err then
		err_text = '<span class="error">' .. err .. '</span>'
	else
		if hasKey[lang:getCode()] then
			IPA_key = "Appendix:" .. lang:getCanonicalName() .. " pronunciation"
		else
			IPA_key = "wikipedia:" .. lang:getCanonicalName() .. " phonology"
		end

		key_link = "[[" .. IPA_key .. "|key]]"
	end


	local prefix = "[[Wiktionary:International Phonetic Alphabet|IPA]]<sup>(" .. ( key_link or err_text ) .. ")</sup>:&#32;"

	IPAs, categories = export.format_IPA_multiple(lang, items, separator, no_count, "raw")

	if lang and (namespace == "" or namespace == "Reconstruction") then
		table.insert(categories, {
			cat = lang:getCanonicalName() .. " terms with IPA pronunciation",
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
	return process_maybe_split_categories(split_output, categories, prontext, lang)
end

local function determine_repr(pron)
	local repr_mark = {}
	local repr, reconstructed

	-- remove initial asterisk before representation marks, used on some Reconstruction pages
	if find(pron, "^%*") then
		reconstructed = true
		pron = sub(pron, 2)
	end

	local representation_types = {
		['/'] = { right = '/', type = 'phonemic', },
		['['] = { right = ']', type = 'phonetic', },
		['⟨'] = { right = '⟩', type = 'orthographic', },
		['-'] = { type = 'rhyme' },
	}

	repr_mark.i, repr_mark.f, repr_mark.left, repr_mark.right = find(pron, '^(.).-(.)$')

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
	if find(transcription, "%.[ˈˌ]") then
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
		if mw.title.getCurrentTitle().nsText == "Template" then
			table.insert(items, {pron = "/aɪ piː ˈeɪ/"})
		else
			table.insert(categories, "Pronunciation templates without a pronunciation")
		end
	end

	local bits = {}

	for _, item in ipairs(items) do
		local bit, item_categories, errtext = export.format_IPA(lang, item.pron, "raw")
		bit = bit .. errtext
		for _, cat in ipairs(item_categories) do
			table.insert(categories, cat)
		end

		if item.pretext then
			bit = item.pretext .. bit
		end

		if item.posttext then
			bit = bit .. item.posttext
		end

		if item.q and item.q[1] or item.qq and item.qq[1] or item.qualifiers and item.qualifiers[1]
			or item.a and item.a[1] or item.aa and item.aa[1] then
			bit = require("Module:pron qualifier").format_qualifiers {
				lang = lang,
				text = bit,
				q = item.q,
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
			local refs = {}
			if #refspecs > 0 then
				for _, refspec in ipairs(refspecs) do
					if type(refspec) ~= "table" then
						refspec = {text = refspec}
					end
					local refargs
					if refspec.name or refspec.group then
						refargs = {name = refspec.name, group = refspec.group}
					end
					table.insert(refs, mw.getCurrentFrame():extensionTag("ref", refspec.text, refargs))
				end
				bit = bit .. table.concat(refs)
			end
		end

		if item.separator then
			bit = item.separator .. bit
		end

		table.insert(bits, bit)

		--[=[	[[Special:WhatLinksHere/Wiktionary:Tracking/IPA/syntax-error]]
				The length or gemination symbol should not appear after a syllable break or stress symbol.	]=]

		if find(item.pron, "[ˈˌ%.][ːˑ]") then
			track("syntax-error")
		end

		if lang then
			-- Add syllable count if the language's diphthongs are listed in [[Module:syllables]].
			-- Don't do this if the term has spaces or a liaison mark (‿).
			if not no_count and mw.title.getCurrentTitle().namespace == 0 then
				m_syllables = m_syllables or require("Module:syllables")
				local langcode = lang:getCode()
				if m_data.langs_to_generate_syllable_count_categories[langcode] then
					local repr = determine_repr(item.pron)
					local use_it
					if m_data.langs_to_use_phonetic_notation[langcode] then
						use_it = repr == "phonetic"
					else
						use_it = repr == "phonemic"
					end
					if use_it and not find(item.pron, "[ ‿]") then
						local syllable_count = m_syllables.getVowels(item.pron, lang)
						if syllable_count then
							table.insert(categories, lang:getCanonicalName() .. " " .. syllable_count ..
								"-syllable words")
						end
					end
				end
			end

			if lang:getCode() == "en" and hasInvalidSeparators(item.pron) then
				table.insert(categories, "IPA for English using .ˈ or .ˌ")
			end
		end
	end

	return process_maybe_split_categories(split_output, categories, table.concat(bits, separator), lang)
end

--[==[
Format an IPA pronunciation. This wraps the pronunciation in appropriate CSS classes and adds cleanup categories and
error messages as needed. The pronunciation `pron` should be either phonemic (surrounded by {/.../}), phonetic
(surrounded by {[...]}), orthographic (surrounded by {⟨...⟩}) or a rhyme (beginning with a hyphen). `lang` indicates the
language of the pronunciation and can be {nil}. If not {nil}, and the specified language has data in [[Module:IPA/data]]
indicating the allowed phonemes, then the page will be added to a cleanup category and an error message displayed next
to the outputted pronunciation. Note that {lang} also determines sort key processing in the added cleanup categories.
If `split_output` is not given, the return value is a concatenation of the formatted pronunciation, error messages and
formatted cleanup categories. Otherwise, three values are returned: the formatted pronunciation, the cleanup categories
and the concatenated error messages. If `split_output` is the value {"raw"}, the cleanup categories are returned in list
form, where the list elements are a combination of category strings and category objects of the form suitable for
passing to {format_categories()} in [[Module:utilities]]. If `split_output` is any other value besides {nil}, the
cleanup categories are returned as a pre-formatted concatenated string.
]==]
function export.format_IPA(lang, pron, split_output)
	local err = {}
	local categories = {}

	if not lang then
		track("format-nolang")
	end

	-- Remove wikilinks, so that wikilink brackets are not misinterpreted as
	-- indicating phonemic transcription
	local str_gsub = string.gsub
	local without_links = str_gsub(pron, "%[%[[^|%]]+|([^%]]+)%]%]", "%1")
	without_links = str_gsub(without_links, "%[%[[^%]]+%]%]", "%1")

	-- Detect whether this is a phonemic or phonetic transcription
	local repr, reconstructed = determine_repr(without_links)

	if reconstructed then
		pron = sub(pron, 2)
		without_links = sub(without_links, 2)
	end

	-- If valid, strip the representation marks
	if repr == "phonemic" then
		pron = sub(pron, 2, -2)
		without_links = sub(without_links, 2, -2)
	elseif repr == "phonetic" then
		pron = sub(pron, 2, -2)
		without_links = sub(without_links, 2, -2)
	elseif repr == "orthographic" then
		pron = sub(pron, 2, -2)
		without_links = sub(without_links, 2, -2)
	elseif repr == "rhyme" then
		pron = sub(pron, 2)
		without_links = sub(without_links, 2)
	else
		table.insert(categories, "IPA pronunciations with invalid representation marks")
		-- table.insert(err, "invalid representation marks")
		-- Removed because it's annoying when previewing pronunciation pages.
	end

	if pron == "" then
		table.insert(categories, "IPA pronunciations with no pronunciation present")
	end

	-- Check for obsolete and nonstandard symbols
	for i, symbol in ipairs(m_data.nonstandard) do
		local result
		for nonstandard in gmatch(pron, symbol) do
			if not result then
				result = {}
			end
			table.insert(result, nonstandard)
			table.insert(categories,
				{cat = "IPA pronunciations with obsolete or nonstandard characters", sort_key = nonstandard}
			)
		end

		if result then
			table.insert(err, "obsolete or nonstandard characters (" .. table.concat(result) .. ")")
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
	local result = str_gsub(without_links, "<(%a+)[^>]*>([^<]+)</%1>",
		function(tagName, content)
			found_HTML = true
			return content
		end)
	result = str_gsub(result, "'''([^']*)'''", "%1")
	result = str_gsub(result, "''([^']*)''", "%1")
	result = str_gsub(result, "&[^;]+;", "") -- This may catch things that are not valid character entities.
	result = str_gsub(result, "^%*", "")
	result = gsub(result, ",%s+", "")

	-- VS15
	local vs15_class = "[" .. m_symbols.add_vs15 .. "]"
	if find(pron, vs15_class) then
		local vs15 = u(0xFE0E)
		if find(result, vs15) then
			result = gsub(result, vs15, "")
			pron = gsub(pron, vs15, "")
		end
		pron = gsub(pron, "(" .. vs15_class .. ")", "%1" .. vs15)
	end

	if result ~= "" then
		local namespace = mw.title.getCurrentTitle().namespace
		local suggestions = {}
		for k, v in pairs(m_symbols.invalid) do
			if result:match(k) then
				table.insert(suggestions, k .. " with " .. v)
			end
		end
		if suggestions[1] then
			if namespace == 0 or namespace == 118 then
				error("Invalid IPA: replace " .. mw.text.listToText(suggestions))
			else
				table.insert(err, "replace " .. mw.text.listToText(suggestions))
			end
		end
		result = gsub(result, "⁽[".. m_symbols.superscripts .. "]+⁾", "")
		result = gsub(result, "[" .. m_symbols.valid .. "]", "")
		if result ~= "" then
			local category = "IPA pronunciations with invalid IPA characters"
			if namespace ~= 0 and namespace ~= 118 then
				category = category .. "/non_mainspace"
			end
			table.insert(categories, category)
			table.insert(err, "invalid IPA characters (" .. result .. ")")
		end
	end

	if found_HTML then
		table.insert(categories, "IPA pronunciations with paired HTML tags")
	end

	-- Reference inside IPA template usage
	-- FIXME: Doesn't work; you can't put HTML in module output.
	--if find(pron, '</ref>') then
	--	table.insert(categories, "IPA pronunciations with reference")
	--end

	if repr == "phonemic" or repr == "rhyme" then
		if lang and m_data.phonemes[lang:getCode()] then
			local valid_phonemes = m_data.phonemes[lang:getCode()]
			local rest = pron
			local phonemes = {}

			while len(rest) > 0 do
				local longestmatch = ""

				if sub(rest, 1, 1) == "(" or sub(rest, 1, 1) == ")" then
					longestmatch = sub(rest, 1, 1)
				else
					for _, phoneme in ipairs(valid_phonemes) do
						if len(phoneme) > len(longestmatch) and sub(rest, 1, len(phoneme)) == phoneme then
							longestmatch = phoneme
						end
					end
				end

				if len(longestmatch) > 0 then
					table.insert(phonemes, longestmatch)
					rest = sub(rest, len(longestmatch) + 1)
				else
					local phoneme = sub(rest, 1, 1)
					table.insert(phonemes, "<span style=\"color: red\">" .. phoneme .. "</span>")
					rest = sub(rest, 2)
					table.insert(categories, "IPA pronunciations with invalid phonemes/" .. lang:getCode())
					track("invalid phonemes/" .. phoneme)
				end
			end

			pron = table.concat(phonemes)
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

	if err[1] then
		err = '<span class="previewonly error" style="font-size: small;>&#32;' .. table.concat(err, ", ") .. "</span>"
	else
		err = ""
	end

	return process_maybe_split_categories(split_output, categories, '<span class="IPA">' .. pron .. "</span>", lang,
		err)
end

return export
