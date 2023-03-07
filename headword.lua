local export = {}

local rfind = mw.ustring.find
local rgmatch = mw.ustring.gmatch
local rsubn = mw.ustring.gsub
local ulen = mw.ustring.len
local unfc = mw.ustring.toNFC
local uupper = mw.ustring.upper

local m_data = mw.loadData("Module:headword/data")

local isLemma = m_data.lemmas
local isNonLemma = m_data.nonlemmas
local notranslit = m_data.notranslit
local toBeTagged = m_data.toBeTagged

-- If set to true, categories always appear, even in non-mainspace pages
local test_force_categories = false

-- version of rsubn() that discards all but the first return value
local function rsub(term, foo, bar)
	local retval = rsubn(term, foo, bar)
	return retval
end

local function track(page, code)
	local tracking_page = "headword/" .. page
	if code then
		require("Module:debug/track"){tracking_page, tracking_page .. "/" .. code}
	else
		require("Module:debug/track")(tracking_page)
	end
	return true
end

local function test_script(text, script_code)
	if type(text) == "string" and type(script_code) == "string" then
		local sc = require("Module:scripts").getByCode(script_code)
		local characters
		if sc then
			characters = sc:getCharacters()
		end

		local out
		if characters then
			text = rsub(text, "%W", "")
			out = rfind(text, "[" .. characters .. "]")
		end

		if out then
			return true
		else
			return false
		end
	else
		mw.log("Parameters to test_script were incorrect.")
		return nil
	end
end


local spacingPunctuation = "[%s%p]+"
--[[ List of punctuation or spacing characters that are found inside of words.
	 Used to exclude characters from the regex above. ]]
local wordPunc = "-־׳״'.·*’་•:"
local notWordPunc = "[^" .. wordPunc .. "]+"


-- Return true if the given head is multiword according to the algorithm used
-- in full_headword().
function export.head_is_multiword(head)
	for possibleWordBreak in rgmatch(head, spacingPunctuation) do
		if rfind(possibleWordBreak, notWordPunc) then
			return true
		end
	end

	return false
end


-- Add links to a multiword head.
function export.add_multiword_links(head)
	local function workaround_to_exclude_chars(s)
		return rsub(s, notWordPunc, "]]%1[[")
	end

	head = "[[" .. rsub(head, spacingPunctuation, workaround_to_exclude_chars) .. "]]"
	--[=[
	use this when workaround is no longer needed:

	head = "[[" .. rsub(head, WORDBREAKCHARS, "]]%1[[") .. "]]"

	Remove any empty links, which could have been created above
	at the beginning or end of the string.
	]=]
	head = head:gsub("%[%[%]%]", "")
	return head
end


local function non_categorizable(data)
	return (data.title:inNamespace("") and data.title.text:find("^Unsupported titles/"))
		or (data.title:inNamespace("Appendix") and data.title.text:find("^Gestures/"))
end


-- Format a headword with transliterations
local function format_headword(data)
	local m_scriptutils = require("Module:script utilities")

	-- Are there non-empty transliterations?
	-- Need to do it this way because translit[1] might be nil while translit[2] is not
	local has_translits = false
	local has_manual_translits = false

	-- Format the headwords
	for i, head in ipairs(data.heads) do
		if data.translits[i] or data.transcriptions[i] then
			has_translits = true
		end
		if data.translits[i] and data.translits[i].is_manual or data.transcriptions[i] then
			has_manual_translits = true
		end

		-- Apply processing to the headword, for formatting links and such
		if head:find("[[", nil, true) and (not data.sc[i] or data.sc[i]:getCode() ~= "Imag") then
			head = require("Module:links").language_link({term = head, lang = data.lang}, false)
		else
			head = data.lang:makeDisplayText(head, data.sc[i], true)
		end

		-- Add language and script wrapper
		if i == 1 then
			head = m_scriptutils.tag_text(head, data.lang, data.sc[i], "head", nil, data.id)
		else
			head = m_scriptutils.tag_text(head, data.lang, data.sc[i], "head", nil)
		end

		data.heads[i] = head
	end

	local translits_formatted = ""

	if has_manual_translits then
		-- [[Special:WhatLinksHere/Template:tracking/headword/has-manual-translit]]
		-- [[Special:WhatLinksHere/Template:tracking/headword/has-manual-translit/LANG]]
		track("has-manual-translit", data.lang:getCode())
	end

	if has_translits then

		-- Format the transliterations
		local translits = data.translits
		local transcriptions = data.transcriptions

		if translits then
			-- using pairs() instead of ipairs() in case there is a gap
			for i, _ in pairs(translits) do
				if type(i) == "number" then
					translits[i] = m_scriptutils.tag_translit(translits[i].display, data.lang:getCode(), "head", nil, translits[i].is_manual)
				end
			end
		end

		if transcriptions then
			for i, _ in pairs(transcriptions) do
				if type(i) == "number" then
					transcriptions[i] = m_scriptutils.tag_transcription(transcriptions[i], data.lang:getCode(), "head")
				end
			end
		end

		for i = 1, math.max(#translits, #transcriptions) do
			local translits_formatted = {}
			table.insert(translits_formatted, translits[i] and translits[i] or "")
			table.insert(translits_formatted, (translits[i] and transcriptions[i]) and " " or "")
			table.insert(translits_formatted, transcriptions[i] and "/" .. transcriptions[i] .. "/" or "")
			data.translits[i] = table.concat(translits_formatted)
		end

		translits_formatted = " (" .. table.concat(data.translits, " <i>or</i> ") .. ")"

		local transliteration_page = mw.title.new(data.lang:getCanonicalName() .. " transliteration", "Wiktionary")

		if transliteration_page then
			local success, exists = pcall(function () return transliteration_page.exists end)
			if success and exists then
				translits_formatted = " [[Wiktionary:" .. data.lang:getCanonicalName() .. " transliteration|•]]" .. translits_formatted
			end
		end
	end

	return table.concat(data.heads, " <i>or</i> ") .. translits_formatted
end


local function format_genders(data)
	if data.genders and #data.genders > 0 then
		local pos_for_cat
		if not data.nogendercat and not m_data.no_gender_cat[data.lang:getCode()] then
			local pos_category = data.pos_category:gsub("^reconstructed ", "")
			pos_for_cat = m_data.pos_for_gender_number_cat[pos_category]
		end
		local text, cats = require("Module:gender and number").format_genders(data.genders, data.lang, pos_for_cat)
		for _, cat in ipairs(cats) do
			table.insert(data.categories, cat)
		end
		return "&nbsp;" .. text
	else
		return ""
	end
end


local function format_inflection_parts(data, parts)
	for j, part in ipairs(parts) do
		if type(part) ~= "table" then
			part = {term = part}
		end

		local left_qualifiers, right_qualifiers
		local reftext

		left_qualifiers = part.q and #part.q > 0 and part.q or part.qualifiers and #part.qualifiers > 0 and part.qualifiers
		if left_qualifiers then
			left_qualifiers = require("Module:qualifier").format_qualifier(left_qualifiers) .. " "

			-- [[Special:WhatLinksHere/Template:tracking/headword/qualifier]]
			track("qualifier")
		end
		right_qualifiers = part.qq and #part.qq > 0 and part.qq
		if right_qualifiers then
			right_qualifiers = " " .. require("Module:qualifier").format_qualifier(right_qualifiers)

			-- [[Special:WhatLinksHere/Template:tracking/headword/qualifier]]
			track("qualifier")
		end
		if part.refs and #part.refs > 0 then
			local refs = {}
			for _, ref in ipairs(part.refs) do
				if type(ref) ~= "table" then
					ref = {text = ref}
				end
				local refargs
				if ref.name or ref.group then
					refargs = {name = ref.name, group = ref.group}
				end
				table.insert(refs, mw.getCurrentFrame():extensionTag("ref", ref.text, refargs))
			end
			reftext = table.concat(refs)
		end

		local partaccel = part.accel
		local face = part.hypothetical and "hypothetical" or "bold"

		-- Here the final part 'or data.nolink' allows to have 'nolink=true'
		-- right into the 'data' table to disable links of the entire headword
		-- when inflected forms aren't entry-worthy, e.g.: in Vulgar Latin
		local nolink = part.hypothetical or part.nolink or data.nolink

		local separator = part.separator or j > 1 and " <i>or</i> " -- use "" to request no separator

		if part.label then
			-- There should be a better way of italicizing a label. As is, this isn't customizable.
			part = "<i>" .. part.label .. "</i>"
		else
			-- Convert the term into a full link
			-- Don't show a transliteration here, the consensus seems to be not to
			-- show them in headword lines to avoid clutter.
			part = require("Module:links").full_link(
				{
					term = not nolink and part.term or nil,
					alt = part.alt or (nolink and part.term or nil),
					lang = part.lang or data.lang,
					sc = part.sc or parts.sc or (not part.lang and data.sc[1]),
					id = part.id,
					genders = part.genders,
					tr = part.translit or (not (parts.enable_auto_translit or data.inflections.enable_auto_translit) and "-" or nil),
					ts = part.transcription,
					accel = parts.accel or partaccel,
				},
				face,
				false
				)
		end

		if left_qualifiers then
			part = left_qualifiers .. part
		end
		if reftext then
			part = part .. reftext
		end
		if right_qualifiers then
			part = part .. right_qualifiers
		end
		if separator then
			part = separator .. part
		end

		parts[j] = part
	end

	local parts_output = ""

	if #parts > 0 then
		parts_output = " " .. table.concat(parts)
	elseif parts.request then
		parts_output = " <small>[please provide]</small>"
			.. require("Module:utilities").format_categories(
				{"Requests for inflections in " .. data.lang:getCanonicalName() .. " entries"},
				lang,
				nil,
				nil,
				data.force_cat_output or test_force_categories,
				data.sc[1]
				)
	end

	return "<i>" .. parts.label .. "</i>" .. parts_output
end

-- Format the inflections following the headword
local function format_inflections(data)
	if data.inflections and #data.inflections > 0 then
		-- Format each inflection individually
		for key, infl in ipairs(data.inflections) do
			data.inflections[key] = format_inflection_parts(data, infl)
		end

		return " (" .. table.concat(data.inflections, ", ") .. ")"
	else
		return ""
	end
end


-- Return "lemma" if the given POS is a lemma, "non-lemma form" if a non-lemma form, or nil
-- if unknown. The POS passed in must be in its plural form ("nouns", "prefixes", etc.).
-- If you have a POS in its singular form, call pluralize() in [[Module:string utilities]] to
-- pluralize it in a smart fashion that knows when to add '-s' and when to add '-es'.
--
-- If `best_guess` is given and the POS is in neither the lemma nor non-lemma list, guess
-- based on whether it ends in " forms"; otherwise, return nil.
function export.pos_lemma_or_nonlemma(plpos, best_guess)
	-- Is it a lemma category?
	if isLemma[plpos] or isLemma[plpos:gsub("^reconstructed ", "")] then
		return "lemma"
	-- Is it a nonlemma category?
	elseif isNonLemma[plpos]
		or isNonLemma[plpos:gsub("^reconstructed ", "")]
		or isLemma[plpos:gsub("^mutated ", "")]
		or isNonLemma[plpos:gsub("^mutated ", "")] then
		return "non-lemma form"
	elseif best_guess then
		return plpos:find(" forms$") and "non-lemma form" or "lemma"
	else
		return nil
	end
end


local function show_headword_line(data)
	local namespace = data.title.nsText
	local langname = data.lang:getCanonicalName()

	-- Check the namespace against the language type
	if namespace == "" then
		local langtype = data.lang:getType()
		if langtype == "reconstructed" then
			error("Entries in " .. langname .. " must be placed in the Reconstruction: namespace")
		elseif langtype == "appendix-constructed" then
			error("Entries in " .. langname .. " must be placed in the Appendix: namespace")
		end
	end

	local tracking_categories = {}

	if not data.noposcat then
		local pos_category = langname .. " " .. data.pos_category
		-- FIXME: [[User:Theknightwho]] Why is this special case here? Please add an explanatory comment.
		if pos_category ~= "Translingual Han characters" then
			table.insert(data.categories, 1, pos_category)
		end
	end

	if data.sccat and data.sc then
		for i, script in ipairs(data.sc) do
			table.insert(data.categories, langname .. " " .. data.pos_category
				.. " in " .. script:getDisplayForm())
		end
	end

	-- Is it a lemma category?
	local postype = export.pos_lemma_or_nonlemma(data.pos_category)
	if not postype then
		-- We don't know what this category is, so tag it with a tracking category.
		--[=[
		[[Special:WhatLinksHere/Template:tracking/headword/unrecognized pos]]
		]=]
		table.insert(tracking_categories, "head tracking/unrecognized pos")
		track("unrecognized pos", data.lang:getCode())
		track("unrecognized pos/pos/" .. data.pos_category, data.lang:getCode())
	elseif not data.noposcat then
		table.insert(data.categories, 1, langname .. " " .. postype .. "s")
	end

	-- Preprocess
	preprocess(data, postype)

	if namespace == "" and data.lang:getType() ~= "reconstructed" then
		local m_links = require("Module:links")
		for i, head in ipairs(data.heads) do
			if data.title.prefixedText ~= m_links.getLinkPage(m_links.remove_links(head), data.lang, data.sc[i]) then
				--[=[
				[[Special:WhatLinksHere/Template:tracking/headword/pagename spelling mismatch]]
				]=]
				track("pagename spelling mismatch", data.lang:getCode())
				break
			end
		end
	end

	-- Format and return all the gathered information
	return
		format_headword(data) ..
		format_genders(data) ..
		format_inflections(data) ..
		require("Module:utilities").format_categories(
			tracking_categories, data.lang, data.sort_key, nil,
			data.force_cat_output or test_force_categories, data.sc[1]
			)
end


local function init_and_find_maximum_index(data, element, allow_blank_string)
	local maxind = 0
	if not data[element] then
		data[element] = {}
	end
	local typ = type(data[element])
	if typ ~= "table" then
		error(("In full_headword(), `data.%s` must be an array but is a %s"):format(element, typ))
	end
	for k, v in pairs(array) do
		if k ~= "maxindex" then
			if type(k) ~= "number" then
				error(("Unrecognized non-numeric key '%s' in `data.%s`"):format(k, name))
			end
			if k > maxind then
				maxind = k
			end
			if v then
				if type(v) ~= "string" then
					error(("For key '%s' in `data.%s`, value should be a string but is a %s"):format(k, element, type(v)))
				end
				if not allow_blank_string and v == "" then
					error(("For key '%s' in `data.%s`, blank string not allowed; use 'false' for the default"):format(k, element))
				end
			end
		end
	end
	return maxind
end


function export.full_headword(data)
	local tracking_categories = {}

	------------ Basic checks for old-style (multi-arg) calling convention. ------------

	if data.getCanonicalName then
		error("In full_headword(), the first argument `data` needs to be a Lua object (table) of properties, not a language object")
	end

	if not data.lang or type(data.lang) ~= "table" or not data.lang.getCode then
		error("In full_headword(), the first argument `data` needs to be a Lua object (table) and `data.lang` must be a language object")
	end

	if data.id and type(data.id) ~= "string" then
		error("The id in the data table should be a string.")
	end

	------------ Initialize pagename etc. ------------

	if data.pagename then -- for testing, doc pages, etc.
		data.title = mw.title.new(data.pagename)
		if not data.title then
			error(("Bad value for `data.pagename`: '%s'"):format(data.pagename))
		end
	else
		data.title = mw.title.getCurrentTitle()
	end

	local pagename = data.title.text
	local namespace = data.title.nsText

	local langcode = data.lang:getCode()

	------------ Initialize `data.heads` table; if old-style, convert to new-style. ------------

	if type(data.heads) == "table" and type(data.heads[1]) == "table" then
		-- new-style
		if data.translits or data.transcriptions then
			error("In full_headword(), if `data.heads` is new-style (array of head objects), `data.translits` and `data.transcriptions` cannot be given")
		end
	else
		-- convert old-style `heads`, `translits` and `transcriptions` to new-style
		local maxind = math.max(
			init_and_find_maximum_index(data, "heads"),
			init_and_find_maximum_index(data, "translits", true),
			init_and_find_maximum_index(data, "transcriptions", true),
		)
		for i = 1, maxind do
			data.heads[i] = {
				head = data.heads[i],
				tr = data.translits[i],
				ts = data.transcriptions[i],
			}
		end
	end

	-- Make sure there's at least one head.
	if not data.heads[1] then
		data.heads[1] = {}
	end

	------------ Create a default headword, and add links to multiword page names. ------------

	-- Determine if term is reconstructed
	local is_reconstructed = data.lang:getType() == "reconstructed" or namespace == "Reconstruction"

	-- Create a default headword.
	local subpagename = data.title.subpageText:gsub("^Unsupported titles/", "")
	local default_head
	if is_reconstructed then
		default_head = require("Module:utilities").plain_gsub(pagename, data.lang:getCanonicalName() .. "/", "")
	else
		default_head = subpagename
	end

	local unmodified_default_head = default_head

	-- Add links to multi-word page names when appropriate
	if not m_data.no_multiword_links[langcode] and not is_reconstructed and export.head_is_multiword(default_head) then
		default_head = export.add_multiword_links(default_head)
	end

	if is_reconstructed then
		default_head = "*" .. default_head
	end

	------------ Fill in missing values in `data.heads`. ------------

	-- True if any script among the headword scripts has spaces in it.
	local any_script_has_spaces = false

	for _, head in ipairs(data.heads) do

		------ 1. If missing head, replace with default head.
		if not head.head then
			head.head = default_head
		elseif head.head == default_head and langcode == "en" then
			-- FIXME! Why are we only doing this for English?
			table.insert(data.categories, data.lang:getCanonicalName() .. " terms with redundant head parameter")
		end

		------ 2. Try to detect the script(s) if not provided. If a per-head script is provided, that takes precedence,
		------     otherwise fall back to the overall script if given. If neither given, autodetect the script.

		if head.sc or data.sc then
			-- Only create this closure when needed.
			local function check_redundant_sc()
				if data.noscripttracking then
					return
				end
				track("sc")

				local auto_sc = data.lang:findBestScript(head.head)
				local manual_code = head.sc:getCode()
				if manual_code == auto_sc:getCode() then
					track("sc/redundant", manual_code)
				else
					track("sc/needed", manual_code)
				end
			end
			if head.sc then
				-- Per-head script given.
				check_redundant_sc()
			else
				-- Overall script given.
				head.sc = data.sc
				-- Only check for redundant script if there's a single head present. If multiple heads present, it
				-- gets complicated (might be redundant for one but not the other), so don't try.
				if #data.heads == 1 then
					check_redundant_sc()
				end
			end
		else
			head.sc = data.lang:findBestScript(head.head)
		end

		-- If using a discouraged character sequence, add to maintenance category.
		if head.sc:hasNormalizationFixes() == true then
			local composed_head = unfc(head.head)
			if head.sc:fixDiscouragedSequences(composed_head) ~= composed_head then
				table.insert(data.categories, "Pages using discouraged character sequences")
			end
		end

		any_script_has_spaces = any_script_has_spaces or head.sc:hasSpaces()

		------ 3. Create automatic transliterations for any non-Latin headwords without manual translit given
		------    (provided automatic translit is available, e.g. not in Persian or Hebrew).

		-- Make transliterations
		if head.tr then
			head.tr = {display = head.tr, is_manual = true}
		end

		local translit = head.tr

		-- Try to generate a transliteration if necessary
		if translit and translit.display == "-" then
			translit = nil
		elseif not translit and not notranslit[langcode] and head.sc:isTransliterated() then
			translit = (data.lang:transliterate(require("Module:links").remove_links(head), head.sc))
			translit = translit and mw.text.trim(translit)

			-- There is still no transliteration?
			-- Add the entry to a cleanup category.
			if not translit then
				translit = "<small>transliteration needed</small>"
				table.insert(data.categories, "Requests for transliteration of " .. data.lang:getCanonicalName() .. " terms")
			end

			if translit then
				translit = {display = translit, is_manual = false}
			end
		end

		-- Link to the transliteration entry for languages that require this.
		if translit and data.lang:link_tr() then
			translit.display = require("Module:links").full_link {
				term = translit.display,
				lang = data.lang,
				sc = require("Module:scripts").getByCode("Latn"),
				tr = "-"
			}
		end

		head.tr = translit
	end

	-- If the first head is multiword (after removing links), maybe insert into "LANG multiword terms".
	if not data.nomultiwordcat and any_script_has_spaces and postype == "lemma" and not m_data.no_multiword_cat[langcode] then
		-- Check for spaces or hyphens, but exclude prefixes and suffixes.
		-- Use the pagename, not the head= value, because the latter may have extra
		-- junk in it, e.g. superscripted text that throws off the algorithm.
		local checkpattern = ".[%s%-፡]."
		if m_data.hyphen_not_multiword_sep[langcode] then
			-- Exclude hyphens if the data module states that they should for this language
			checkpattern = ".[%s፡]."
		end
		if rfind(unmodified_default_head, checkpattern) and not non_categorizable(data) then
			table.insert(data.categories, data.lang:getCanonicalName() .. " multiword terms")
		end
	end

	-- Assumes that the scripts in "toBeTagged" will never occur in the Reconstruction namespace.
	-- (FIXME: Don't make assumptions like this, and if you need to do so, throw an error if the assumption is violated.)
	-- Avoid tagging ASCII as Hani even when it is tagged as Hani in the headword, as in [[check]]. The check for ASCII
	-- might need to be expanded to a check for any Latin characters and whitespace or punctuation. Where there are
	-- multiple headwords, use the script for the first. (FIXME: [[User:Theknightwho]] Why are we using the script for the
	-- first headword for all of them rather than the correct per-headword script? Please either expand this comment
	-- explaining why, or correct it if it's a problem.)
	local displayTitle
	if (namespace == "" and data.sc and toBeTagged[data.sc[1]:getCode()]
			and not pagename:find "^[%z\1-\127]+$")
			or (data.sc[1]:getCode() == "Jpan" and (test_script(pagename, "Hira") or test_script(pagename, "Kana")))
			or (data.sc[1]:getCode() == "Kore" and (test_script(pagename, "Hang"))) then
		displayTitle = '<span class="' .. data.sc[1]:getCode() .. '">' .. pagename .. '</span>'
	-- Keep Han entries region-neutral in the display title.
	elseif namespace == "" and data.sc and not pagename:find "^[%z\1-\127]+$"
			and (data.sc[1]:getCode() == "Hant" or data.sc[1]:getCode() == "Hans") then
		displayTitle = '<span class="Hani">' .. pagename .. '</span>'
	elseif namespace == "Reconstruction" then
		displayTitle, matched = rsubn(
			data.title.fullText,
			"^(Reconstruction:[^/]+/)(.+)$",
			function(before, term)
				return before ..
					require("Module:script utilities").tag_text(
						term,
						data.lang,
						data.sc[1]
					)
			end
		)

		if matched == 0 then
			displayTitle = nil
		end
	end

	if displayTitle then
		local frame = mw.getCurrentFrame()
		frame:callParserFunction(
			"DISPLAYTITLE",
			displayTitle
		)
	end

	if data.force_cat_output then
		--[=[
		[[Special:WhatLinksHere/Template:tracking/headword/force cat output]]
		]=]
		track("force cat output")
	end

	-- Were any categories specified?
	if data.categories and #data.categories > 0 then
		local lang_name = require("Module:pattern utilities").pattern_escape(data.lang:getCanonicalName())
		for _, cat in ipairs(data.categories) do
			-- Does the category begin with the language name? If not, tag it with a tracking category.
			if not rfind(cat, "^" .. lang_name) then
				mw.log(cat, data.lang:getCanonicalName())
				table.insert(tracking_categories, "head tracking/no lang category")

				--[=[
				[[Special:WhatLinksHere/Template:tracking/head tracking/no lang category]]
				]=]
				track("no lang category", langcode)
			end
		end

		if not data.pos_category
			and data.categories[1]:find("^" .. data.lang:getCanonicalName())
				then
			data.pos_category = data.categories[1]:gsub("^" .. data.lang:getCanonicalName() .. " ", "")
			table.remove(data.categories, 1)
		end
	end

	if not data.pos_category then
		error(
			'No valid part-of-speech categories were found in the list '
			.. 'of categories passed to the function "full_headword". '
			.. 'The part-of-speech category should consist of a language\'s '
			.. 'canonical name plus a part of speech.'
			)
	end

	-- Categorise for unusual characters
	local standard = data.lang:getStandardCharacters()

	if standard then
		if ulen(data.title.subpageText) ~= 1 and not non_categorizable(data) then
			for character in rgmatch(data.title.subpageText, "([^" .. standard .. "])") do
				local upper = uupper(character)
				if not rfind(upper, "[" .. standard .. "]") then
					character = upper
				end
				table.insert(
					data.categories,
					data.lang:getCanonicalName() .. " terms spelled with " .. character
				)
			end
		end
	end

	-- Categorise for palindromes
	if not data.nopalindromecat and namespace ~= "Reconstruction" and ulen(data.title.subpageText) > 2
		-- FIXME: Use of first script here seems hacky. What is the clean way of doing this in the presence of
		-- multiple scripts?
		and require("Module:palindromes").is_palindrome(data.title.subpageText, data.lang, data.heads[1].sc) then
		table.insert(data.categories, data.lang:getCanonicalName() .. " palindromes")
	end

	-- This may add more categories (e.g. gender categories), so make sure it gets
	-- evaluated first.
	local text = show_headword_line(data)
	return
		text ..
		require("Module:utilities").format_categories(
			data.categories, data.lang, data.sort_key, nil,
			data.force_cat_output or test_force_categories, data.heads[1].sc
			) ..
		require("Module:utilities").format_categories(
			tracking_categories, data.lang, data.sort_key, nil,
			data.force_cat_output or test_force_categories, data.heads[1].sc
			)
end

return export
