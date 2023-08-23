local export = {}

local translit_data = mw.loadData("Module:transliteration/data")
local needs_translit = translit_data[1]

-- microformat2 classes, see https://phabricator.wikimedia.org/T138709
local css_classes = {
	container_ux = 'h-usage-example',
	container_quotation = 'h-quotation',
	example = 'e-example',
	quotation = 'e-quotation',
	quotation_with_citation = 'e-quotation cited-passage',
	translation = 'e-translation',
	-- The following are added by [[Module:script utilities]], using [[Module:script utilities/data]]
--	transliteration = 'e-transliteration',	
--	transcription = 'e-transcription',
	normalization = 'e-normalization',
	literally = 'e-literally',
	source = 'e-source',
	footer = 'e-footer'
}

-- helper functions

local function track(page)
	require("Module:debug/track")("usex/" .. page)
	return true
end


local function wrap(tag, class, text, lang)
	if lang then
		lang = ' lang="' .. lang .. '"'
	else
		lang = ""
	end
	
	if text and class then
		return table.concat{'<', tag, ' class="', class, '"', lang, '>', text, '</', tag, '>'}
	else
		return nil
	end
end

local function span(class, text) return wrap('span', class, text) end
local function div(class, text) return wrap('div', class, text) end

--[==[
Format a usex or quotation. Implementation of {{tl|ux}}, {{tl|quote}} and {{tl|quote-*}} templates (e.g. {{tl|quote-book}},
{{tl|quote-journal}}, {{tl|quote-web}}, etc.). FIXME: Should also be used by {{tl|Q}} and [[Module:Quotations]].
Takes a single object `data`, containining the following fields:

* `usex`: The text of the usex or quotation to format. Mandatory.
* `lang`: The language object of the text. Mandatory.
* `sc`: The script object of the text. Autodetected if not given.
* `quote`: If specified, this is a quotation rather than a usex (uses a different CSS class that affects formatting).
* `inline`: If specified, format the usex or quotation inline (on one line).
* `translation`: Translation of the usex or quotation, if in a foreign language.
* `lit`: Literal translation (if the translation in `translation` is idiomatic and differs significantly from the
		 literal translation).
* `normalization`: Normalized version of the usex or quotation (esp. for older languages where nonstandard spellings
				   were common).
* `normsc`: Script code of the normalized text. If unspecified, use the script object given in `sc` if any, otherwise
            do script detection on the normalized text. If "auto", do script detection on the normalized text even if
			a script was specified in `sc`.
* `transliteration`: Transliteration of the usex. If unspecified, transliterate the normalization if specified and not
                     in a Latin script and transliterable, otherwise fall back to transliterating the usex text.
* `transcription`: Transcription of the usex, for languages where the transliteration differs significantly from the
                   pronunciation.
* `substs`: String indicating substitutions to perform on the usex/quotation and normalization prior to transliterating
            them. Multiple substs are comma-separated and individual substs are of the form FROM//TO where FROM is a
			Lua pattern and TO is a Lua replacement spec. (FROM/TO is also recognized if no // is present in the
			substitution.)
* `q`: If specified, a list of left qualifiers to display before the usex/quotation text.
* `qq`: If specified, a list of right qualifiers to display after the usex/quotation text.
* `qualifiers`: If specified, a list of right qualifiers to display after the usex/quotation text, for compatibility
                purposes.
* `ref`: Reference text to display directly after the qualifiers. (FIXME: Instead, this should be actual references.)
* `source`: Source of the quotation, displayed in parens after the quotation text.
* `footer`: Footer displaying miscellaneous information, shown after the quotation. (Typically this should be in a
            small font.)
* `nocat`: Suppress categorization.
* `sortkey`: Sort key for categories.
* `brackets`: If specified, show a bracket at the end (used with brackets= in {{tl|quote-*}} templates, which show the
              bracket at the beginning, to indicate a mention rather than a use).
* `class`: Additional CSS class surrounding the entire formatted text.
* `noenum`: If specified, add a newline and colon before the formatted output.
]==]

function export.format_usex(data)
	local namespace = mw.title.getCurrentTitle().nsText

	local lang = data.lang
	local sc = data.sc
	local usex = data.usex
	local translation = data.translation
	local transliteration = data.transliteration
	local transcription = data.transcription
	local quote = data.quote
	local lit = data.lit
	local substs = data.substs
	local source = data.source
	local brackets = data.brackets
	local footer = data.footer
	local sortkey = data.sortkey
	local normalization = data.normalization
	local normsc = data.normsc

	--[[
	if namespace == "Reconstruction" or lang:hasType("reconstructed") then
		error("Reconstructed languages and reconstructed terms cannot have usage examples, as we have no record of their use.")
	end
	]]
	
	if lit then
		lit = "(literally, “" .. span(css_classes.literally, lit) .. "”)"
	end

	if source then
		source = "(" .. span(css_classes.source, source) .. ")"
	end

	if footer then
		footer = span(css_classes.footer, footer)
	end
	
	local example_type = quote and "quote" or "usage example" -- used in error messages
	local categories = {}

	if normsc == "auto" then
		normsc = nil
	elseif not normsc then
		normsc = sc
	end

	if not sc then
		sc = lang:findBestScript(usex)
	end
	if not normsc and normalization then
		normsc = lang:findBestScript(normalization)
	end

	local function apply_substs(usex)
		local subbed_usex = require("Module:links").remove_links(usex)

		if substs then
			--[=[
			[[Special:WhatLinksHere/Template:tracking/usex/substs]]
			]=]
			track("substs")
			
			local substs = mw.text.split(substs, ",")
			for _, subpair in ipairs(substs) do
				local subsplit = mw.text.split(subpair,
					mw.ustring.find(subpair, "//") and "//" or track("substs-single-slash") and "/")
				subbed_usex = mw.ustring.gsub(subbed_usex, subsplit[1], subsplit[2])
			end
		end

		return subbed_usex
	end

	-- tr=- means omit transliteration altogether
	if transliteration == "-" then
		transliteration = nil
	else
		-- Try to auto-transliterate.
		if not transliteration then
			-- First, try transliterating the normalization, if supplied.
			if normalization and normsc and not normsc:getCode():find("Latn") then -- Latn, Latnx or a lang-specific variant
				local subbed_norm = apply_substs(normalization)
				transliteration = (lang:transliterate(subbed_norm, normsc))
			end
			-- If no normalization, or the normalization is in a Latin script, or the transliteration of the
			-- normalization failed, fall back to transliterating the usex.
			if not transliteration then
				local subbed_usex = apply_substs(usex)
				transliteration = (lang:transliterate(subbed_usex, sc))
			end
			
			-- If the language doesn't have capitalization and is specified in [[Module:usex/data]], then capitalize
			-- any sentences.
			if transliteration and mw.loadData("Module:usex/data").capitalize_sentences[lang:getCode()] then
				transliteration = mw.ustring.gsub(transliteration, "%f[^%z%p%s](.)(.-[%.%?!‽])",
					function(m1, m2) return mw.ustring.upper(m1) .. m2 end)
			end
		end

		-- If there is still no transliteration, then add a cleanup category.
		if not transliteration and needs_translit[lang] then
			table.insert(categories, "Requests for transliteration of " .. lang:getCanonicalName() .. " terms")
		end
	end
	if transliteration then
		transliteration = require("Module:script utilities").tag_translit(transliteration, lang:getCode(), "usex")
	end
	if transcription then
		transcription = require("Module:script utilities").tag_transcription(transcription, lang:getCode(), "usex")
		transcription = "/" .. transcription .. "/"
	end

	if translation == "-" then
		translation = nil
		table.insert(categories, "Omitted translation in the main namespace")
	elseif translation then
		translation = span(css_classes.translation, translation)
	elseif lang:getCode() ~= "en" and lang:getCode() ~= "mul" and lang:getCode() ~= "und" then
		-- add trreq category if translation is unspecified and language is not english, translingual or undetermined
		if quote then
			table.insert(categories, "Requests for translations of " .. lang:getCanonicalName() .. " quotations")
			translation = "<small>(please [[WT:Quotations#Adding translations to quotations|add an English translation]] of this " .. example_type .. ")</small>"
		else
			table.insert(categories, "Requests for translations of " .. lang:getCanonicalName() .. " usage examples")
			translation = "<small>(please add an English translation of this " .. example_type .. ")</small>"
		end
	end

	local function do_language_and_script_tagging(usex, lang, sc, css_class)
		usex = require("Module:links").embedded_language_links({term = usex, lang = lang, sc = sc}, false)
		
		local face
		if quote then
			face = nil
		else
			face = "term"
		end
		
		usex = require("Module:script utilities").tag_text(usex, lang, sc, face, css_class)
		if sc:getDirection() == "rtl" then
			usex = "&rlm;" .. usex .. "&lrm;"
		end

		return usex
	end

	if usex then
		usex = do_language_and_script_tagging(usex, lang, sc,
			quote == "quote-meta" and css_classes.quotation_with_citation or
			quote and css_classes.quotation or css_classes.example)
		
		if not data.nocat and namespace == "" or namespace == "Reconstruction" then
			table.insert(categories, lang:getCanonicalName() ..
				(quote and " terms with quotations" or " terms with usage examples"))
		end
	else
		if transliteration then
			table.insert(categories, "Requests for native script in " .. lang:getCanonicalName() .. " usage examples")
		end
		
		-- TODO: Trigger some kind of error here
		usex = "<small>(please add the primary text of this " .. example_type .. ")</small>"
	end

	if normalization then
		-- Use brackets in HTML entity format just to make sure we don't interfere with links; add brackets before
		-- script tagging so that if the script tagging increases the font size, the brackets get increased too.
		normalization = "&#91;" .. normalization .. "&#93;"
		normalization = do_language_and_script_tagging(normalization, lang, normsc, css_classes.normalization)
	end

	local result = {}
	

	if data.qualifiers then
		track("qualifier")
	end

	local leftq = data.q
	if leftq and #leftq > 0 then
		table.insert(result, require("Module:qualifier").format_qualifier(leftq) .. " ")
	end
	table.insert(result, usex)
	local rightq = data.qq or data.qualifiers
	if rightq and #rightq > 0 then
		table.insert(result, " " .. require("Module:qualifier").format_qualifier(rightq))
	end

	if data.ref and data.ref ~= "" then
		track("ref")
	end
	table.insert(result, data.ref)
	
	if data.inline then
		if normalization then
			table.insert(result, " " .. normalization)
		end
		if transliteration then
			table.insert(result, " ― " .. transliteration)
			if transcription then
				table.insert(result, " " .. transcription)
			end
		elseif transcription then
			table.insert(result, " ― " .. transcription)
		end

		if translation then
			table.insert(result, " ― " .. translation)
		end

		if lit then
			table.insert(result, " " .. lit)
		end
		
		if source then
			table.insert(result, " " .. source)
		end

		if footer then
			table.insert(result, " " .. footer)
		end

		if data.brackets then
			table.insert(result, "]")
		end
	elseif transliteration or translation or transcription or normalization or lit or source or footer then
		table.insert(result, "<dl>")
		local closing_tag = ""

		if normalization then
			table.insert(result, closing_tag)
			table.insert(result, "<dd>" .. normalization)
			closing_tag = "</dd>"
		end

		if transliteration then
			table.insert(result, closing_tag)
			table.insert(result, "<dd>" .. transliteration)
			closing_tag = "</dd>"
		end
		
		if transcription then
			table.insert(result, closing_tag)
			table.insert(result, "<dd>" .. transcription)
			closing_tag = "</dd>"
		end
		
		if translation then
			table.insert(result, closing_tag)
			table.insert(result, "<dd>" .. translation)
			closing_tag = "</dd>"
		end

		if lit then
			table.insert(result, closing_tag)
			table.insert(result, "<dd>" .. lit)
			closing_tag = "</dd>"
		end

		local extra_indent, closing_extra_indent
		if transliteration or transcription or normalization or translation or lit then
			extra_indent = "<dd><dl><dd>"
			closing_extra_indent = "</dd></dl></dd>"
		else
			extra_indent = "<dd>"
			closing_extra_indent = "</dd>"
		end
		if source then
			table.insert(result, closing_tag)
			table.insert(result, extra_indent .. source)
			closing_tag = closing_extra_indent
		end

		if footer then
			table.insert(result, closing_tag)
			table.insert(result, extra_indent .. footer)
			closing_tag = closing_extra_indent
		end

		if data.brackets then
			table.insert(result, "]")
		end
		
		table.insert(result, closing_tag)

		table.insert(result, "</dl>")
	else
		if data.brackets then
			table.insert(result, "]")
		end
	end
	
	result = table.concat(result)
	local class = quote and css_classes.container_quotation or css_classes.container_ux
	if data.class then
		class = class .. " " .. data.class
	end
	result = (data.inline and span or div)(class, result)
	result = result .. require("Module:utilities").format_categories(categories, lang, sortkey)
	if data.noenum then
		result = "\n: " .. result
	end
	return result
end

return export
