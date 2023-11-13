local export = {}
local m_string_utils = require("Module:string utilities")

local rfind = m_string_utils.find
local rgmatch = m_string_utils.gmatch
local rsubn = m_string_utils.gsub
local ulen = mw.ustring.len
local unfc = mw.ustring.toNFC

local m_data = mw.loadData("Module:headword/data")

local isLemma = m_data.lemmas
local isNonLemma = m_data.nonlemmas
local notranslit = m_data.notranslit
local toBeTagged = m_data.toBeTagged

-- If set to true, categories always appear, even in non-mainspace pages
local test_force_categories = false

-- Version of rsubn() that discards all but the first return value.
local function rsub(term, foo, bar)
	return (rsubn(term, foo, bar))
end

-- Add a tracking category to track entries with certain (unusually undesirable) properties. `track_id` is an identifier
-- for the particular property being tracked and goes into the tracking page. Specifically, this adds a link in the
-- page text to [[Template:tracking/headword/TRACK_ID]], meaning you can find all entries with the `track_id` property
-- by visiting [[Special:WhatLinksHere/Template:tracking/headword/TRACK_ID]].
--
-- If `code` (a language or script code) is given, an additional tracking page
-- [[Template:tracking/headword/TRACK_ID/CODE]] is linked to, and you can find all entries in the combination of
-- `track_id` and `code` by visiting [[Special:WhatLinksHere/Template:tracking/headword/TRACK_ID/CODE]]. This makes it
-- possible to isolate only the entries with a specific tracking property that are in a given language or script.
local function track(track_id, code)
	local tracking_page = "headword/" .. track_id
	local m_debug_track = require("Module:debug/track")
	if code then
		m_debug_track{tracking_page, tracking_page .. "/" .. code}
	else
		m_debug_track(tracking_page)
	end
	return true
end


local function text_in_script(text, script_code)
	local sc = require("Module:scripts").getByCode(script_code)
	if not sc then
		error("Internal error: Bad script code " .. script_code)
	end
	local characters = sc:getCharacters()

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
end


local spacingPunctuation = "[%s%p]+"
--[[ List of punctuation or spacing characters that are found inside of words.
	 Used to exclude characters from the regex above. ]]
local wordPunc = "-־׳״'.·*’་•:"
local notWordPunc = "[^" .. wordPunc .. "]+"


-- Format a term (either a head term or an inflection term) along with any left or right qualifiers, references or
-- customized separator: `part` is the object specifying the term, which should optionally contain:
-- * left qualifiers in `q`, an array of strings (or `qualifiers` for compatibility purposes);
-- * right qualifiers in `qq`, an array of strings;
-- * references in `refs`, an array either of strings (formatted reference text) or objects containing fields `text`
--   (formatted reference text) and optionally `name` and/or `group`;
-- * a separator in `separator`, defaulting to " <i>or</i> " if this is not the first term (j > 1), otherwise "".
-- `formatted` is the formatted version of the term itself, and `j` is the index of the term.
local function format_term_with_qualifiers_and_refs(part, formatted, j)
	local left_qualifiers, right_qualifiers
	local reftext

	left_qualifiers = part.q and #part.q > 0 and part.q
	if left_qualifiers then
		left_qualifiers = require("Module:qualifier").format_qualifier(left_qualifiers) .. " "
	end

	right_qualifiers = part.qq and #part.qq > 0 and part.qq
	if right_qualifiers then
		right_qualifiers = " " .. require("Module:qualifier").format_qualifier(right_qualifiers)
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

	local separator = part.separator or j > 1 and " <i>or</i> " -- use "" to request no separator

	if left_qualifiers then
		formatted = left_qualifiers .. formatted
	end
	if reftext then
		formatted = formatted .. reftext
	end
	if right_qualifiers then
		formatted = formatted .. right_qualifiers
	end
	if separator then
		formatted = separator .. formatted
	end

	return formatted
end


--[==[Return true if the given head is multiword according to the algorithm used in full_headword().]==]
function export.head_is_multiword(head)
	for possibleWordBreak in rgmatch(head, spacingPunctuation) do
		if rfind(possibleWordBreak, notWordPunc) then
			return true
		end
	end

	return false
end


--[==[Add links to a multiword head.]==]
function export.add_multiword_links(head, default)
	local function workaround_to_exclude_chars(s)
		return rsub(s, notWordPunc, "\2%1\1")
	end

	head = "\1" .. rsub(head, spacingPunctuation, workaround_to_exclude_chars) .. "\2"
	if default then
		head = head
			:gsub("(\1[^\2]*)\\([:#][^\2]*\2)", "%1\\\\%2")
			:gsub("(\1[^\2]*)([:#][^\2]*\2)", "%1\\%2")
	end

	--Escape any remaining square brackets to stop them breaking links (e.g. "[citation needed]").
	head = require("Module:utilities").make_entities(head, "%[%]")

	--[=[
	use this when workaround is no longer needed:

	head = "[[" .. rsub(head, WORDBREAKCHARS, "]]%1[[") .. "]]"

	Remove any empty links, which could have been created above
	at the beginning or end of the string.
	]=]
	return (head
		:gsub("\1\2", "")
		:gsub("[\1\2]", {["\1"] = "[[", ["\2"] = "]]"}))
end


local function non_categorizable(data)
	return data.title:inNamespace("Appendix") and data.title.text:find("^Gestures/")
end


-- Format a headword with transliterations.
local function format_headword(data)
	local m_scriptutils = require("Module:script utilities")

	-- Are there non-empty transliterations?
	local has_translits = false
	local has_manual_translits = false

	------ Format the headwords. ------

	local head_parts = {}
	local unique_head_parts = {}

	local has_multiple_heads = #data.heads > 1

	for j, head in ipairs(data.heads) do
		if head.tr or head.ts then
			has_translits = true
		end
		if head.tr and head.tr_manual or head.ts then
			has_manual_translits = true
		end

		local formatted

		-- Apply processing to the headword, for formatting links and such.
		if head.term:find("[[", nil, true) and head.sc:getCode() ~= "Imag" then
			formatted = require("Module:links").language_link({term = head.term, lang = data.lang}, false)
		else
			formatted = data.lang:makeDisplayText(head.term, head.sc, true)
		end

		local function tag_text_and_add_quals_and_refs(head, formatted, j)
			-- Add language and script wrapper.
			formatted = m_scriptutils.tag_text(formatted, data.lang, head.sc, "head", nil, j == 1 and data.id or nil)

			-- Add qualifiers, references and separator.
			return format_term_with_qualifiers_and_refs(head, formatted, j)
		end

		local head_part = tag_text_and_add_quals_and_refs(head, formatted, j)
		table.insert(head_parts, head_part)

		-- If multiple heads, try to determine whether all heads display the same. To do this we need to effectively
		-- rerun the text tagging and addition of qualifiers and references, using 1 for all indices.
		if has_multiple_heads then
			local unique_head_part
			if j == 1 then
				unique_head_part = head_part
			else
				unique_head_part = tag_text_and_add_quals_and_refs(head, formatted, 1)
			end
			unique_head_parts[unique_head_part] = true
		end
	end

	local set_size = 0
	if has_multiple_heads then
		for k, _ in pairs(unique_head_parts) do
			set_size = set_size + 1
		end
	end
	if set_size == 1 then
		head_parts = head_parts[1]
	else
		head_parts = table.concat(head_parts)
	end

	if has_manual_translits then
		-- [[Special:WhatLinksHere/Template:tracking/headword/has-manual-translit]]
		-- [[Special:WhatLinksHere/Template:tracking/headword/has-manual-translit/LANGCODE]]
		track("has-manual-translit", data.lang:getCode())
	end

	------ Format the transliterations and transcriptions. ------

	local translits_formatted

	if has_translits then
		local translit_parts = {}
		for i, head in ipairs(data.heads) do
			if head.tr or head.ts then
				local this_parts = {}
				if head.tr then
					table.insert(this_parts, m_scriptutils.tag_translit(head.tr, data.lang:getCode(), "head", nil, head.tr_manual))
					if head.ts then
						table.insert(this_parts, " ")
					end
				end
				if head.ts then
					table.insert(this_parts, "/" .. m_scriptutils.tag_transcription(head.ts, data.lang:getCode(), "head") .. "/")
				end
				table.insert(translit_parts, table.concat(this_parts))
			end
		end

		translits_formatted = " (" .. table.concat(translit_parts, " <i>or</i> ") .. ")"

		local transliteration_page = mw.title.new(data.lang:getCanonicalName() .. " transliteration", "Wiktionary")

		if transliteration_page then
			local success, exists = pcall(function () return transliteration_page.exists end)
			if success and exists then
				translits_formatted = " [[Wiktionary:" .. data.lang:getCanonicalName() .. " transliteration|•]]" .. translits_formatted
			end
		end
	else
		translits_formatted = ""
	end

	------ Paste heads and transliterations/transcriptions. ------

	return head_parts .. translits_formatted
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
	local any_part_translit = false

	for j, part in ipairs(parts) do
		if type(part) ~= "table" then
			part = {term = part}
		end

		local partaccel = part.accel
		local face = part.hypothetical and "hypothetical" or "bold"

		-- Here the final part 'or data.nolink' allows to have 'nolink=true'
		-- right into the 'data' table to disable links of the entire headword
		-- when inflected forms aren't entry-worthy, e.g.: in Vulgar Latin
		local nolink = part.hypothetical or part.nolink or data.nolink

		local formatted
		if part.label then
			-- FIXME: There should be a better way of italicizing a label. As is, this isn't customizable.
			formatted = "<i>" .. part.label .. "</i>"
		else
			-- Convert the term into a full link. Don't show a transliteration here unless enable_auto_translit is
			-- requested, either at the `parts` level (i.e. per inflection) or at the `data.inflections` level (i.e.
			-- specified for all inflections). This is controllable in {{head}} using autotrinfl=1 for all inflections,
			-- or fNautotr=1 for an individual inflection (remember that a single inflection may be associated with
			-- multiple terms). The reason for doing this is to avoid clutter in headword lines by default in languages
			-- where the script is relatively straightforward to read by learners (e.g. Greek, Russian), but allow it
			-- to be enabled in languages with more complex scripts (e.g. Arabic).
			local tr = part.translit or (not (parts.enable_auto_translit or data.inflections.enable_auto_translit) and "-" or nil)
			if tr ~= "-" then
				any_part_translit = true
			end
			formatted = require("Module:links").full_link(
				{
					term = not nolink and part.term or nil,
					alt = part.alt or (nolink and part.term or nil),
					lang = part.lang or data.lang,
					-- FIXME, code smell in always using the first script.
					sc = part.sc or parts.sc or (not part.lang and data.heads[1].sc),
					id = part.id,
					genders = part.genders,
					tr = tr,
					ts = part.transcription,
					accel = partaccel or parts.accel,
				},
				face,
				false
				)
		end

		parts[j] = format_term_with_qualifiers_and_refs(part, formatted, j)
	end

	local parts_output

	if #parts > 0 then
		parts_output = (parts.label and " " or "") .. table.concat(parts)
	elseif parts.request then
		parts_output = " <small>[please provide]</small>"
		table.insert(data.categories, "Requests for inflections in " .. data.lang:getCanonicalName() .. " entries")
	else
		parts_output = ""
	end

	local parts_label = parts.label and ("<i>" .. parts.label .. "</i>") or ""
	return parts_label .. parts_output, any_part_translit
end


-- Format the inflections following the headword.
local function format_inflections(data)
	local any_part_translit = false
	if data.inflections and #data.inflections > 0 then
		-- Format each inflection individually.
		for key, infl in ipairs(data.inflections) do
			local this_any_part_translit
			data.inflections[key], this_any_part_translit = format_inflection_parts(data, infl)
			if this_any_part_translit then
				any_part_translit = true
			end
		end

		local concat_result = table.concat(data.inflections, ", ")
		return " (" .. concat_result .. ")"
	else
		return ""
	end
end

--[==[
-- Return "lemma" if the given POS is a lemma, "non-lemma form" if a non-lemma form, or nil
-- if unknown. The POS passed in must be in its plural form ("nouns", "prefixes", etc.).
-- If you have a POS in its singular form, call pluralize() in [[Module:string utilities]] to
-- pluralize it in a smart fashion that knows when to add '-s' and when to add '-es'.
--
-- If `best_guess` is given and the POS is in neither the lemma nor non-lemma list, guess
-- based on whether it ends in " forms"; otherwise, return nil.]==]
function export.pos_lemma_or_nonlemma(plpos, best_guess)
	-- Is it a lemma category?
	if isLemma[plpos] then
		return "lemma"
	end
	local plpos_no_recon = plpos:gsub("^reconstructed ", "")
	if isLemma[plpos_no_recon] then
		return "lemma"
	end
	-- Is it a nonlemma category?
	if isNonLemma[plpos] or isNonLemma[plpos_no_recon] then
		return "non-lemma form"
	end
	local plpos_no_mut = plpos:gsub("^mutated ", "")
	if isLemma[plpos_no_mut] or isNonLemma[plpos_no_mut] then
		return "non-lemma form"
	elseif best_guess then
		return plpos:find(" forms$") and "non-lemma form" or "lemma"
	else
		return nil
	end
end


-- Find and return the maximum index in the array `data[element]` (which may have gaps in it), and initialize it to a
-- zero-length array if unspecified. Check to make sure all keys are numeric (other than "maxindex", which is set by
-- [[Module:parameters]] for list parameters), all values are strings, and unless `allow_blank_string` is given,
-- no blank (zero-length) strings are present.
local function init_and_find_maximum_index(data, element, allow_blank_string)
	local maxind = 0
	if not data[element] then
		data[element] = {}
	end
	local typ = type(data[element])
	if typ ~= "table" then
		error(("In full_headword(), `data.%s` must be an array but is a %s"):format(element, typ))
	end
	for k, v in pairs(data[element]) do
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

--[==[
-- Add the page to various maintenance categories for the language and the
-- whole page. These are placed in the headword somewhat arbitrarily, but
-- mainly because headword templates are mandatory for entries (meaning that
-- in theory it provides full coverage).
-- 
-- This is provided as an external entry point so that modules which transclude
-- information from other entries (such as {{tl|ja-see}}) can take advantage
-- of this feature as well, because they are used in place of a conventional
-- headword template.]==]
function export.maintenance_cats(m_data, lang, lang_cats, page_cats)
	if m_data.unsupported_title then
		table.insert(page_cats, "Unsupported titles")
	end
	if m_data.unencoded_char then
		table.insert(page_cats, "Terms containing unencoded characters")
	end
	if m_data.wikitext_topic_cat[lang:getCode()] then
		table.insert(lang_cats, lang:getCanonicalName() .. " entries with topic categories using raw markup")
	end
	if m_data.wikitext_langname_cat[lang:getCanonicalName()] then
		table.insert(lang_cats, lang:getCanonicalName() .. " entries with language name categories using raw markup")
	end
	if m_data.pagename_defaultsort_conflict then
		table.insert(page_cats, m_data.pagename_defaultsort_conflict)
	end
	if m_data.pagename_displaytitle_conflict then
		table.insert(page_cats, m_data.pagename_displaytitle_conflict)
	end
end


--[==[This is the primary external entry point.
{{lua|full_headword(data)}}
This is used by {{temp|head}} and various language-specific headword templates (e.g. {{temp|ru-adj}} for Russian adjectives, {{temp|de-noun}} for German nouns, etc.) to display an entire headword line.
See [[#Further explanations for full_headword()]]
]==]
function export.full_headword(data)
	local remove_links = require("Module:links").remove_links
	local format_categories = require("Module:utilities").format_categories

	-- Prevent data from being destructively modified.
	local data = require("Module:table").shallowcopy(data)

	------------ 1. Basic checks for old-style (multi-arg) calling convention. ------------

	if data.getCanonicalName then
		error("In full_headword(), the first argument `data` needs to be a Lua object (table) of properties, not a language object")
	end

	if not data.lang or type(data.lang) ~= "table" or not data.lang.getCode then
		error("In full_headword(), the first argument `data` needs to be a Lua object (table) and `data.lang` must be a language object")
	end

	if data.id and type(data.id) ~= "string" then
		error("The id in the data table should be a string.")
	end

	------------ 2. Initialize pagename etc. ------------

	local langcode = data.lang:getCode()
	local langname = data.lang:getCanonicalName()

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

	-- Check the namespace against the language type.
	if namespace == "" then
		if data.lang:hasType("reconstructed") then
			error("Entries in " .. langname .. " must be placed in the Reconstruction: namespace")
		elseif data.lang:hasType("appendix-constructed") then
			error("Entries in " .. langname .. " must be placed in the Appendix: namespace")
		end
	end

	------------ 3. Initialize `data.heads` table; if old-style, convert to new-style. ------------

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
			init_and_find_maximum_index(data, "transcriptions", true)
		)
		for i = 1, maxind do
			data.heads[i] = {
				term = data.heads[i],
				tr = data.translits[i],
				ts = data.transcriptions[i],
			}
		end
	end

	-- Make sure there's at least one head.
	if not data.heads[1] then
		data.heads[1] = {}
	end

	------------ 4. Initialize and validate `data.categories` and `data.whole_page_categories`, and determine `pos_category` if not given, and add basic categories. ------------

	init_and_find_maximum_index(data, "categories")
	init_and_find_maximum_index(data, "whole_page_categories")
	local pos_category_already_present = false
	if #data.categories > 0 then
		local escaped_langname = require("Module:pattern utilities").pattern_escape(langname)
		local matches_lang_pattern = "^" .. escaped_langname .. " "
		for _, cat in ipairs(data.categories) do
			-- Does the category begin with the language name? If not, tag it with a tracking category.
			if not cat:find(matches_lang_pattern) then
				-- [[Special:WhatLinksHere/Template:tracking/headword/no lang category]]
				-- [[Special:WhatLinksHere/Template:tracking/headword/no lang category/LANGCODE]]
				track("no lang category", langcode)
			end
		end

		-- If `pos_category` not given, try to infer it from the first specified category. If this doesn't work, we
		-- throw an error below.
		if not data.pos_category and data.categories[1]:find(matches_lang_pattern) then
			data.pos_category = data.categories[1]:gsub(matches_lang_pattern, "")
			-- Optimization to avoid inserting category already present.
			pos_category_already_present = true
		end
	end

	if not data.pos_category then
		error("`data.pos_category` not specified and could not be inferred from the categories given in "
			.. "`data.categories`. Either specify the plural part of speech in `data.pos_category` "
			.. "(e.g. \"proper nouns\") or ensure that the first category in `data.categories` is formed from the "
			.. "language's canonical name plus the plural part of speech (e.g. \"Norwegian Bokmål proper nouns\")."
			)
	end

	-- Insert a category at the beginning for the part of speech unless it's already present or `data.noposcat` given.
	if not pos_category_already_present and not data.noposcat then
		local pos_category = langname .. " " .. data.pos_category
		-- FIXME: [[User:Theknightwho]] Why is this special case here? Please add an explanatory comment.
		if pos_category ~= "Translingual Han characters" then
			table.insert(data.categories, 1, pos_category)
		end
	end

	-- Try to determine whether the part of speech refers to a lemma or a non-lemma form; if we can figure this out,
	-- add an appropriate category.
	local postype = export.pos_lemma_or_nonlemma(data.pos_category)
	if not postype then
		-- We don't know what this category is, so tag it with a tracking category.
		-- [[Special:WhatLinksHere/Template:tracking/headword/unrecognized pos]]
		-- [[Special:WhatLinksHere/Template:tracking/headword/unrecognized pos/LANGCODE]]
		track("unrecognized pos", langcode)
		-- [[Special:WhatLinksHere/Template:tracking/headword/unrecognized pos/POS]]
		-- [[Special:WhatLinksHere/Template:tracking/headword/unrecognized pos/POS/LANGCODE]]
		track("unrecognized pos/pos/" .. data.pos_category, langcode)
	elseif not data.noposcat then
		table.insert(data.categories, 1, langname .. " " .. postype .. "s")
	end

	------------ 5. Create a default headword, and add links to multiword page names. ------------

	-- Determine if term is reconstructed
	local is_reconstructed = namespace == "Reconstruction" or data.lang:hasType("reconstructed")

	-- Create a default headword based on the pagename, which is determined in
	-- advance by the data module so that it only needs to be done once.
	local default_head = m_data.pagename
	local unmodified_default_head = default_head

	-- Add links to multi-word page names when appropriate
	if not m_data.no_multiword_links[langcode] and not is_reconstructed and export.head_is_multiword(default_head) then
		default_head = export.add_multiword_links(default_head, true)
	end

	if is_reconstructed then
		default_head = "*" .. default_head
	end

	------------ 6. Fill in missing values in `data.heads`. ------------

	-- True if any script among the headword scripts has spaces in it.
	local any_script_has_spaces = false
	-- True if any term has a redundant head= param.
	local has_redundant_head_param = false

	for _, head in ipairs(data.heads) do

		------ 6a. If missing head, replace with default head.
		if not head.term then
			head.term = default_head
		elseif head.term == default_head then
			has_redundant_head_param = true
		end

		------ 6b. Try to detect the script(s) if not provided. If a per-head script is provided, that takes precedence,
		------     otherwise fall back to the overall script if given. If neither given, autodetect the script.

		if not head.sc then
			if data.sc then
				-- Overall script given.
				head.sc = data.sc
			else
				-- Autodetect script.
				head.sc = data.lang:findBestScript(head.term)
			end
		end

		-- If using a discouraged character sequence, add to maintenance category.
		if head.sc:hasNormalizationFixes() == true then
			local composed_head = unfc(head.term)
			if head.sc:fixDiscouragedSequences(composed_head) ~= composed_head then
				table.insert(data.whole_page_categories, "Pages using discouraged character sequences")
			end
		end

		any_script_has_spaces = any_script_has_spaces or head.sc:hasSpaces()

		------ 6c. Create automatic transliterations for any non-Latin headwords without manual translit given
		------     (provided automatic translit is available, e.g. not in Persian or Hebrew).

		-- Make transliterations
		head.tr_manual = nil

		-- Try to generate a transliteration if necessary
		if head.tr == "-" then
			head.tr = nil
		elseif not notranslit[langcode] and head.sc:isTransliterated() then
			head.tr_manual = not not head.tr

			local text = head.term
			if not data.lang:link_tr() then
				text = remove_links(text)
			end

			local automated_tr, tr_categories
			automated_tr, head.tr_fail, tr_categories = data.lang:transliterate(text, head.sc)

			if automated_tr or head.tr_fail then
				local manual_tr = head.tr

				if manual_tr then
					if (remove_links(manual_tr) == remove_links(automated_tr)) and (not head.tr_fail) then
						table.insert(data.categories, "Terms with redundant transliterations")
						table.insert(data.categories, "Terms with redundant transliterations/" .. langcode)
					elseif not head.tr_fail then
						table.insert(data.categories, "Terms with manual transliterations different from the automated ones")
						table.insert(data.categories, "Terms with manual transliterations different from the automated ones/" .. langcode)
					end
				end

				if not manual_tr then
					head.tr = automated_tr
					for _, category in ipairs(tr_categories) do
						table.insert(data.categories, category)
					end
				end
			end

			-- There is still no transliteration?
			-- Add the entry to a cleanup category.
			if not head.tr then
				head.tr = "<small>transliteration needed</small>"
				table.insert(data.categories, "Requests for transliteration of " .. langname .. " terms")
			else
				-- Otherwise, trim it.
				head.tr = mw.text.trim(head.tr)
			end
		end

		-- Link to the transliteration entry for languages that require this.
		if head.tr and data.lang:link_tr() then
			head.tr = require("Module:links").full_link {
				term = head.tr,
				lang = data.lang,
				sc = require("Module:scripts").getByCode("Latn"),
				tr = "-"
			}
		end
	end

	------------ 7. Maybe tag the title with the appropriate script code, using the `display_title` mechanism. ------------

	-- Assumes that the scripts in "toBeTagged" will never occur in the Reconstruction namespace.
	-- (FIXME: Don't make assumptions like this, and if you need to do so, throw an error if the assumption is violated.)
	-- Avoid tagging ASCII as Hani even when it is tagged as Hani in the headword, as in [[check]]. The check for ASCII
	-- might need to be expanded to a check for any Latin characters and whitespace or punctuation.
	local display_title
	-- Where there are multiple headwords, use the script for the first. This assumes the first headword is similar to
	-- the pagename, and that headwords that are in different scripts from the pagename aren't first. This seems to be
	-- about the best we can do (alternatively we could potentially do script detection on the pagename).
	local dt_script = data.heads[1].sc
	local dt_script_code = dt_script:getCode()
	local page_non_ascii = namespace == "" and not pagename:find("^[%z\1-\127]+$")
	local unsupported_pagename, unsupported = pagename:gsub("^Unsupported titles/", "")
	if unsupported == 1 and m_data.unsupported_titles[unsupported_pagename] then
		display_title = 'Unsupported titles/<span class="' .. dt_script_code .. '">' .. m_data.unsupported_titles[unsupported_pagename] .. '</span>'
	elseif page_non_ascii and toBeTagged[dt_script_code]
		or (dt_script_code == "Jpan" and (text_in_script(pagename, "Hira") or text_in_script(pagename, "Kana")))
		or (dt_script_code == "Kore" and text_in_script(pagename, "Hang")) then
		display_title = '<span class="' .. dt_script_code .. '">' .. pagename .. '</span>'
	-- Keep Han entries region-neutral in the display title.
	elseif page_non_ascii and (dt_script_code == "Hant" or dt_script_code == "Hans") then
		display_title = '<span class="Hani">' .. pagename .. '</span>'
	elseif namespace == "Reconstruction" then
		display_title, matched = rsubn(
			data.title.fullText,
			"^(Reconstruction:[^/]+/)(.+)$",
			function(before, term)
				return before ..
					require("Module:script utilities").tag_text(
						term,
						data.lang,
						dt_script
					)
			end
		)
		if matched == 0 then
			display_title = nil
		end
	end

	if display_title then
		mw.getCurrentFrame():callParserFunction(
			"DISPLAYTITLE",
			display_title
		)
	end

	------------ 8. Insert additional categories. ------------

	if data.force_cat_output then
		-- [[Special:WhatLinksHere/Template:tracking/headword/force cat output]]
		track("force cat output")
	end

	if has_redundant_head_param then
		if not data.no_redundant_head_cat then
			table.insert(data.categories, langname .. " terms with redundant head parameter")
		end
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
			table.insert(data.categories, langname .. " multiword terms")
		end
	end

	if data.sccat then
		for _, head in ipairs(data.heads) do
			table.insert(data.categories, langname .. " " .. data.pos_category .. " in " .. head.sc:getDisplayForm())
		end
	end

	-- Categorise for unusual characters. Takes into account combining characters, so that we can categorise for characters with diacritics that aren't encoded as atomic characters (e.g. U̠). These can be in two formats: single combining characters (i.e. character + diacritic(s)) or double combining characters (i.e. character + diacritic(s) + character). Each can have any number of diacritics.
	local standard = data.lang:getStandardCharacters()
	if standard and not non_categorizable(data) then
		local function char_category(char)
			local specials = {["#"] = "number sign", ["<"] = "less-than sign", [">"] = "greater-than sign", ["["] = "left square bracket", ["]"] = "right square bracket", ["_"] = "underscore", ["{"] = "left curly bracket", ["|"] = "vertical line", ["}"] = "right curly bracket", ["ß"] = "ẞ", ["ͅ"] = "ͅ", ["\239\191\189"] = "replacement character"}
			char = mw.ustring.toNFD(char)
				:gsub("[%z\1-\127\194-\244][\128-\191]*", function(m)
					local new_m = specials[m]
					new_m = new_m or m:uupper()
					return new_m
				end)
			return mw.ustring.toNFC(char)
		end
		if langcode ~= "hi" and langcode ~= "lo" then
			local standard_chars_scripts = {}
			for _, head in ipairs(data.heads) do
				standard_chars_scripts[head.sc:getCode()] = true
			end
			-- Iterate over the scripts, in case there is more than one (as they can have different sets of standard characters).
			for code in pairs(standard_chars_scripts) do
				local sc_standard = data.lang:getStandardCharacters(code)
				if sc_standard then
					if m_data.pagename_len > 1 then
						local explode_standard = {}
						local function explode(char)
							explode_standard[char] = true
							return ""
						end
						local sc_standard = rsub(sc_standard, m_data.comb_chars.combined_double, explode)
						sc_standard = rsub(sc_standard, m_data.comb_chars.combined_single, explode)
							:gsub("[%z\1-\127\194-\244][\128-\191]*", explode)
						local num
						for char in pairs(m_data.explode_pagename) do
							if not explode_standard[char] then
								if char:find("[0-9]") then
									if not num then
										table.insert(data.categories, langname .. " terms spelled with numbers")
									end
								else
									local upper = char_category(char)
									if not explode_standard[upper] then
										char = upper
									end
									table.insert(data.categories, langname .. " terms spelled with " .. char)
								end
							end
						end
					end
					-- If a diacritic doesn't appear in any of the standard characters, also categorise for it generally.
					sc_standard = mw.ustring.toNFD(sc_standard)
					for diacritic in rgmatch(m_data.decompose_pagename, m_data.comb_chars.diacritics_single) do
						if not mw.ustring.find(sc_standard, diacritic) then
							table.insert(data.categories, langname .. " terms spelled with ◌" .. diacritic)
						end
					end
					for diacritic in rgmatch(m_data.decompose_pagename, m_data.comb_chars.diacritics_double) do
						if not mw.ustring.find(sc_standard, diacritic) then
							table.insert(data.categories, langname .. " terms spelled with ◌" .. diacritic .. "◌")
						end
					end
				end
			end
		-- Ancient Greek, Hindi and Lao handled the old way for now, as their standard chars still need to be converted to the new format (because there are a lot of them).
		elseif ulen(m_data.pagename) ~= 1 then
			for character in rgmatch(m_data.pagename, "([^" .. standard .. "])") do
				local upper = char_category(character)
				if not rfind(upper, "[" .. standard .. "]") then
					character = upper
				end
				table.insert(data.categories, langname .. " terms spelled with " .. character)
			end
		end
	end

	-- Categorise for palindromes
	if not data.nopalindromecat and namespace ~= "Reconstruction" and ulen(data.title.subpageText) > 2
		-- FIXME: Use of first script here seems hacky. What is the clean way of doing this in the presence of
		-- multiple scripts?
		and require("Module:palindromes").is_palindrome(data.title.subpageText, data.lang, data.heads[1].sc) then
		table.insert(data.categories, langname .. " palindromes")
	end

	if namespace == "" and not data.lang:hasType("reconstructed") then
		local m_links = require("Module:links")
		for _, head in ipairs(data.heads) do
			if data.title.prefixedText ~= m_links.getLinkPage(remove_links(head.term), data.lang, head.sc) then
				-- [[Special:WhatLinksHere/Template:tracking/headword/pagename spelling mismatch]]
				-- [[Special:WhatLinksHere/Template:tracking/headword/pagename spelling mismatch/LANGCODE]]
				track("pagename spelling mismatch", langcode)
				break
			end
		end
	end

	-- Add to various maintenance categories.
	export.maintenance_cats(m_data, data.lang, data.categories, data.whole_page_categories)

	------------ 9. Format and return headwords, genders, inflections and categories. ------------

	-- Format and return all the gathered information. This may add more categories (e.g. gender/number categories),
	-- so make sure we do it before evaluating `data.categories`.
	local text = '<span class="headword-line">' ..
		format_headword(data) ..
		format_genders(data) ..
		format_inflections(data) .. '</span>'

	-- Language-specific categories.
	local cats = format_categories(
		data.categories, data.lang, data.sort_key, m_data.encoded_pagename,
		data.force_cat_output or test_force_categories, data.heads[1].sc
	)
	-- Language-agnostic categories.
	local whole_page_cats = format_categories(
		data.whole_page_categories, nil, "-"
	)
	return text .. cats .. whole_page_cats
end

return export
