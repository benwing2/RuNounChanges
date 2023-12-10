local export = {}

--[=[
	[[Unsupported titles]], pages with high memory usage,
	extraction modules and part-of-speech names are listed
	at [[Module:links/data]].
	
	Other modules used:
		[[Module:script utilities]]
		[[Module:scripts]]
		[[Module:languages]] and its submodules
		[[Module:gender and number]]
		[[Module:debug/track]]
]=]

-- These are prefixed with u to avoid confusion with the default string methods
-- of the same name.
local concat = table.concat
local encode = mw.text.encode
local find = mw.ustring.find
local get_entities = require("Module:utilities").get_entities
local gsub = mw.ustring.gsub
local insert = table.insert
local lower = mw.ustring.lower
local remove = table.remove
local shallowcopy = require("Module:table").shallowcopy
local split = mw.text.split
local toNFC = mw.ustring.toNFC
local trim = mw.text.trim
local unstrip = mw.text.unstrip
local u = mw.ustring.char
local TEMP_UNDERSCORE = u(0xFFF0)

local function track(page, code)
	local tracking_page = "links/" .. page
	if code then
		require("Module:debug/track"){tracking_page, tracking_page .. "/" .. code}
	else
		require("Module:debug/track")(tracking_page)
	end
	return true
end

local function escape(text, str)
	local rep
	repeat
		text, rep = text:gsub("\\\\(\\*" .. str .. ")", "\5%1")
	until rep == 0
	return (text:gsub("\\" .. str, "\6"))
end

local function unescape(text, str)
	return (text
		:gsub("\5", "\\")
		:gsub("\6", str))
end

--[==[Takes an input and splits on a double slash (taking account of escaping backslashes).]==]
function export.split_on_slashes(text)
	text = escape(text, "//")
	text = split(text, "//") or {}
	for i, v in ipairs(text) do
		text[i] = unescape(v, "//")
		if v == "" then
			text[i] = false
		end
	end
	return text
end

-- Trim only if there are non-whitespace characters.
local function cond_trim(text)
	-- Include all conventional whitespace + zero-width space.
	if find(text, "[^%s​]") then
		text = trim(text, "%s​")
	end
	return text
end

--[==[Takes a link target and outputs the actual target and the fragment (if any).]==]
function export.get_fragment(text)
	-- If there's an embedded link, just return the input.
	if text:find("%[%[.-%]%]") then
		return text
	end
	text = escape(text, "#")
	-- Replace numeric character references with the corresponding character (&#29; → '),
	-- as they contain #, which causes the numeric character reference to be
	-- misparsed (wa'a → wa&#29;a → pagename wa&, fragment 29;a).
	text = get_entities(text)
	local target, fragment = text:match("^(..-)#(.+)$")
	target = target or text
	target = unescape(target, "#")
	fragment = fragment and unescape(fragment, "#")
	return target, fragment
end

local ignore_cap
local pos_tags
function export.get_link_page(target, lang, sc, plain)
	if not target then
		return nil
	end
	
	-- Remove bold, italics, soft hyphens, strip markers and HTML tags.
	target = target
		:gsub("('*)'''(.-'*)'''", "%1%2")
		:gsub("('*)''(.-'*)''", "%1%2")
		:gsub("­", "")
	target = unstrip(target)
		:gsub("<[^<>]+>", "")
	
	-- Check if the target is an interwiki link.
	if target:match(":") and target ~= ":" then
		-- If this is an a link to another namespace or an interwiki link, ensure there's an initial colon and then return what we have (so that it works as a conventional link, and doesn't do anything weird like add the term to a category.)
		local prefix = target:gsub("^:*(.-):.*", lower)
		if (
			mw.loadData("Module:data/namespaces")[prefix] or
			mw.loadData("Module:data/interwikis")[prefix]
		) then
			return ":" .. target:gsub("^:+", ""), nil, {}
		end
		-- Convert any escaped colons
		target = target:gsub("\\:", ":")
	end
	
	-- Check if the term is reconstructed and remove any asterisk. Otherwise, handle the escapes.
	local reconstructed, escaped
	if not plain then
		target, reconstructed = target:gsub("^%*(.)", "%1")
	end
	target, escaped = target:gsub("^(\\-)\\%*", "%1*")
	
	if not require("Module:utilities").check_object("script", true, sc) or sc:getCode() == "None" then
		sc = lang:findBestScript(target)
	end
	
	-- Remove carets if they are used to capitalize parts of transliterations (unless they have been escaped).
	if (not sc:hasCapitalization()) and sc:isTransliterated() and target:match("%^") then
		target = escape(target, "^")
			:gsub("%^", "")
		target = unescape(target, "^")
	end
	
	-- Get the entry name for the language.
	target = lang:makeEntryName(target, sc)
	
	-- If the link contains unexpanded template parameters, then don't create a link.
	if target:find("{{{") then
		return nil
	end
	
	if target:sub(1, 1) == "/" then
		return ":" .. target
	
	elseif target:find("^Reconstruction:") then
		return target
		
	-- Link to appendix for reconstructed terms and terms in appendix-only languages. Plain links interpret * literally, however.
	elseif reconstructed == 1 then
		if lang:getNonEtymologicalCode() == "und" then
			return nil
		else
			target = "Reconstruction:" .. lang:getNonEtymologicalName() .. "/" .. target
		end
	-- Reconstructed languages and substrates require an initial *.	
	elseif lang:hasType("reconstructed") or lang:getFamilyCode() == "qfa-sub" then
		local check = target:match("^:*([^:]*):")
		check = check and lower(check)
		if (
			mw.loadData("Module:data/namespaces")[check] or
			mw.loadData("Module:data/interwikis")[check]
		) then
			return target
		else
			error("The specified language " .. lang:getCanonicalName()
				.. " is unattested, while the given word is not marked with '*' to indicate that it is reconstructed.")
		end
		
	elseif lang:hasType("appendix-constructed") then
		target = "Appendix:" .. lang:getNonEtymologicalName() .. "/" .. target
	end

	return target, escaped > 0
end

function export.getLinkPage(target, lang, sc, plain)
	track("getLinkPage")
	return export.get_link_page(target, lang, sc, plain)
end


-- Make a link from a given link's parts
local function make_link(link, lang, sc, id, allow_self_link, isolated, plain)
	-- Convert percent encoding to plaintext.
	link.target = mw.uri.decode(link.target, "PATH")
	link.fragment = link.fragment and mw.uri.decode(link.fragment, "PATH")
	
	-- Find fragments (if one isn't already set).
	-- Prevents {{l|en|word#Etymology 2|word}} from linking to [[word#Etymology 2#English]].
	-- # can be escaped as \#.
	if link.target and link.fragment == nil then
		link.target, link.fragment = export.get_fragment(link.target)
	end
	
	-- If there is no display form, then create a default one.
	if not link.display then
		link.display = link.target
	end
	
	local display_is_target = link.display == link.target
	
	-- Process the target
	local escaped
	link.target, escaped = export.get_link_page(link.target, lang, sc, plain)
	
	-- If the display is the target and the reconstruction * has been escaped, remove the escaping backslash.
	if display_is_target and escaped then
		link.display = link.display:gsub("\\([^\\]*%*)", "%1", 1)
	end
	
	-- Process the display form.
	link.display = lang:makeDisplayText(link.display, sc, not display_is_target)
	
	if not link.target then
		return link.display
	end

	-- If the target is the same as the current page and there is no sense id
	-- and linking to the same page hasn't been turned on, then return a "self-link"
	-- like the software does.
	if (not (allow_self_link or id)) and link.target == mw.title.getCurrentTitle().prefixedText then
		return tostring(mw.html.create("strong")
			:addClass("selflink")
			:wikitext(link.display))
	end

	-- Add fragment. Do not add a section link to "Undetermined", as such sections do not exist and are invalid. TabbedLanguages handles links without a section by linking to the "last visited" section, but adding "Undetermined" would break that feature. For localized prefixes that make syntax error, please use the format: ["xyz"] = true.
	local prefix = link.target:match("^:*([^:]+):")
	if not (prefix and mw.loadData("Module:data/interwikis")[lower(prefix)]) then
		if (link.fragment or link.target:find("#$")) and not plain then
			track("fragment", lang:getNonEtymologicalCode())
		end
		
		if (not link.fragment) and lang:getNonEtymologicalCode() ~= "und" then
			if id then
				link.fragment = require("Module:senseid").anchor(lang, id)
			elseif not (link.target:find("^Appendix:") or link.target:find("^Reconstruction:") or plain) then
				link.fragment = lang:getNonEtymologicalName()
			end
		elseif plain and id then
			link.fragment = id
		end
	end
	
	if isolated then
		link.display = mw.loadData("Module:links/data").display_change[link.display] or link.display
	end
	
	link.target = link.target:gsub("^(:?)(.*)", function(m1, m2)
		return m1 .. encode(m2, "#%%&+/:<=>@[\\%]_{|}")
	end)
	link.fragment = link.fragment and encode(link.fragment, "#%%&+/:<=>@[\\%]_{|}")
	
	return "[[" .. link.target .. (link.fragment and "#" .. link.fragment or "") .. "|" .. link.display .. "]]"
end


-- Split a link into its parts
local function parse_link(linktext)
	local link = {target = linktext}
	
	local target = link.target
	link.target, link.display = target:match("^(..-)|(.+)$")
	if not link.target then
		link.target = target
		link.display = target
	end
	
	-- There's no point in processing these, as they aren't real links.
	local target_lower = link.target:lower()
	for _, false_positive in ipairs({"category", "cat", "file", "image"}) do
		if target_lower:match("^" .. false_positive .. ":") then return nil end
	end
	
	link.display = get_entities(link.display)
	link.target, link.fragment = export.get_fragment(link.target)
	
	-- So that make_link does not look for a fragment again.
	if not link.fragment then
		link.fragment = false
	end
	
	return link
end

-- Find embedded links and ensure they link to the correct section.
local function process_embedded_links(text, data, allow_self_link, plain)
	-- Process the non-linked text.
	text = data.lang:makeDisplayText(text, data.sc[1], true)
	
	-- If the text begins with * and another character, then act as if each link begins with *. However, don't do this if the * is contained within a link at the start. E.g. `|*[[foo]]` would set all_reconstructed to true, while `|[[*foo]]` would not.
	local all_reconstructed = false
	if not plain then
		if require("Module:utilities").get_plaintext(text:gsub("%[%[.-%]%]", ".")):match("^*.") then
			all_reconstructed = true
		end
		-- Otherwise, handle any escapes.
		text = text:gsub("^(\\-)\\%*", "%1*")
	end
	
	if data.alt then
		track("alt-ignored")
		mw.log("(from Module:links)", "text with embedded wikilinks:", text,
			"ignored alt:", data.alt, "lang:", data.lang:getNonEtymologicalCode())
	end
	
	if data.id then
		track("id-ignored")
		mw.log("(from Module:links)", "text with embedded wikilinks:", text,
			"ignored id:", data.id, "lang:", data.lang:getNonEtymologicalCode())
	end
	
	local function process_link(space1, linktext, space2)
		local capture = "[[" .. linktext .. "]]"
		
		local link = parse_link(linktext)
		
		--Return unprocessed false positives untouched (e.g. categories).
		if not link then return capture end
		
		if all_reconstructed and not link.target:find("^%*") then
			link.target = "*" .. link.target
		end
		
		linktext = make_link(link, data.lang, data.sc, data.id, allow_self_link, false, plain)
			:gsub("^%[%[", "\3")
			:gsub("%]%]$", "\4")
		
		return space1 .. linktext .. space2
	end
	
	-- Use chars 1 and 2 as temporary substitutions, so that we can use charsets. These are converted to chars 3 and 4 by process_link, which means we can convert any remaining chars 1 and 2 back to square brackets (i.e. those not part of a link).
	text = text
		:gsub("%[%[", "\1")
		:gsub("%]%]", "\2")
	-- If the script uses ^ to capitalize transliterations, make sure that any carets preceding links are on the inside, so that they get processed with the following text.
	if text:match("%^") and not data.sc:hasCapitalization() and data.sc:isTransliterated() then
		text = escape(text, "^")
			:gsub("%^\1", "\1%^")
		text = unescape(text, "^")
	end
	text = text:gsub("\1(%s*)([^\1\2]-)(%s*)\2", process_link)
	
	-- Remove the extra * at the beginning of a language link if it's immediately followed by a link whose display begins with * too.
	if all_reconstructed then
		text = text:gsub("^%*\3([^|\1-\4]+)|%*", "\3%1|*")
	end
	
	return (text
		:gsub("[\1\3]", "[[")
		:gsub("[\2\4]", "]]"))
end

local function handle_redundant_wikilink(text, alt)
	local temp = text:match("^%[%[(.-)%]%]$")
	if not temp then
		return text, alt
	end
	local temp_lower = temp:lower()
	for _, false_positive in ipairs({"category", "cat", "file", "image"}) do
		if temp_lower:match("^" .. false_positive .. ":") then
			return text, alt
		end
	end
	-- Note: it's possible for "[[" or "]]" to be uninvolved in links, so we need to check for both individually (e.g. "[[aaa]] bb]]" would not have a redundant wikilink).
	if temp and not (temp:find("%[%[") or temp:find("%]%]")) then
		text, alt = temp:match("^([^|]+)|?(.-)$")
		track("redundant wikilink")
		if alt == "" then
			alt = nil
		end
	end
	return text, alt
end

--[==[Creates a basic link to the given term. It links to the language section (such as <code>==English==</code>), but it does not add language and script wrappers, so any code that uses this function should call the <code class="n">[[Module:script utilities#tag_text|tag_text]]</code> from [[Module:script utilities]] to add such wrappers itself at some point.
The first argument, <code class="n">data</code>, may contain the following items, a subset of the items used in the <code class="n">data</code> argument of <code class="n">full_link</code>. If any other items are included, they are ignored.
{ {
	term = entry_to_link_to,
	alt = link_text_or_displayed_text,
	lang = language_object,
	id = sense_id,
} }
; <code class="n">term</code>
: Text to turn into a link. This is generally the name of a page. The text can contain wikilinks already embedded in it. These are processed individually just like a single link would be. The <code class="n">alt</code> argument is ignored in this case.
; <code class="n">alt</code> (''optional'')
: The alternative display for the link, if different from the linked page. If this is {{code|lua|nil}}, the <code class="n">text</code> argument is used instead (much like regular wikilinks). If <code class="n">text</code> contains wikilinks in it, this argument is ignored and has no effect. (Links in which the alt is ignored are tracked with the tracking template {{whatlinkshere|tracking=links/alt-ignored}}.)
; <code class="n">lang</code>
: The [[Module:languages#Language objects|language object]] for the term being linked. If this argument is defined, the function will determine the language's canonical name (see [[Template:language data documentation]]), and point the link or links in the <code class="n">term</code> to the language's section of an entry, or to a language-specific senseid if the <code class="n">id</code> argument is defined.
; <code class="n">id</code> (''optional'')
: Sense id string. If this argument is defined, the link will point to a language-specific sense id ({{ll|en|identifier|id=HTML}}) created by the template {{temp|senseid}}. A sense id consists of the language's canonical name, a hyphen (<code>-</code>), and the string that was supplied as the <code class="n">id</code> argument. This is useful when a term has more than one sense in a language. If the <code class="n">term</code> argument contains wikilinks, this argument is ignored. (Links in which the sense id is ignored are tracked with the tracking template {{whatlinkshere|tracking=links/id-ignored}}.)
The second argument is as follows:
; <code class="n">allow_self_link</code>
: If {{code|lua|true}}, the function will also generate links to the current page. The default ({{code|lua|false}}) will not generate a link but generate a bolded "self link" instead.
The following special options are processed for each link (both simple text and with embedded wikilinks):
* The target page name will be processed to generate the correct entry name. This is done by the [[Module:languages#makeEntryName|makeEntryName]] function in [[Module:languages]], using the <code class="n">entry_name</code> replacements in the language's data file (see [[Template:language data documentation]] for more information). This function is generally used to automatically strip dictionary-only diacritics that are not part of the normal written form of a language.
* If the text starts with <code class="n">*</code>, then the term is considered a reconstructed term, and a link to the Reconstruction: namespace will be created. If the text contains embedded wikilinks, then <code class="n">*</code> is automatically applied to each one individually, while preserving the displayed form of each link as it was given. This allows linking to phrases containing multiple reconstructed terms, while only showing the * once at the beginning.
* If the text starts with <code class="n">:</code>, then the link is treated as "raw" and the above steps are skipped. This can be used in rare cases where the page name begins with <code class="n">*</code> or if diacritics should not be stripped. For example:
** {{temp|l|en|*nix}} links to the nonexistent page [[Reconstruction:English/nix]] (<code class="n">*</code> is interpreted as a reconstruction), but {{temp|l|en|:*nix}} links to [[*nix]].
** {{temp|l|sl|Franche-Comté}} links to the nonexistent page [[Franche-Comte]] (<code>é</code> is converted to <code>e</code> by <code class="n">makeEntryName</code>), but {{temp|l|sl|:Franche-Comté}} links to [[Franche-Comté]].]==]
function export.language_link(data, allow_self_link)
	if type(data) ~= "table" then
		error("The first argument to the function language_link must be a table. See Module:links/documentation for more information.")
	-- Nothing to process, return nil.
	elseif not (data.term or data.alt) then
		return nil
	end
	
	local text = data.term
	
	data.sc = data.sc or data.lang:findBestScript(text)
	
	ignore_cap = ignore_cap or mw.loadData("Module:links/data").ignore_cap
	if (ignore_cap[data.lang:getCode()] or ignore_cap[data.lang:getNonEtymologicalCode()]) and text then
		text = text:gsub("%^", "")
	end
	
	-- Do we have a redundant wikilink? If so, remove it.
	if text then
		text, data.alt = handle_redundant_wikilink(text, data.alt)
	end
	
	-- Do we have embedded wikilinks?
	if text and text:find("%[%[.-%]%]") then
		text = process_embedded_links(text, data, allow_self_link)
	-- If not, make a link using the parameters.
	else
		text = text and cond_trim(text)
		data.alt = data.alt and cond_trim(data.alt)
		text = make_link({target = text, display = data.alt, fragment = data.fragment}, data.lang, data.sc, data.id, allow_self_link, true)
	end
	
	return text
end

function export.plain_link(data, allow_self_link)
	if type(data) ~= "table" then
		error("The first argument to the function language_link must be a table. See Module:links/documentation for more information.")
	-- Nothing to process, return nil.
	elseif not (data.term or data.alt) then
		return nil
	-- Only have alt, just return it.
	elseif not data.term then
		return data.alt
	end
	
	local text = data.term
	if (not data.lang) or data.lang:getNonEtymologicalCode() ~= "und" then
		data.lang = require("Module:languages").getByCode("und")
	end
	data.sc = data.sc or require("Module:scripts").findBestScriptWithoutLang(text)
	
	-- Do we have a redundant wikilink? If so, remove it.
	if text then
		text, data.alt = handle_redundant_wikilink(text, data.alt)
	end
	
	-- Do we have embedded wikilinks?
	if text:find("%[%[.-%]%]") then
		text = process_embedded_links(text, data, allow_self_link, true)
	-- If not, make a link using the parameters.
	else
		text = cond_trim(text)
		data.alt = data.alt and cond_trim(data.alt)
		text = make_link({target = text, display = data.alt, fragment = data.fragment}, data.lang, data.sc, data.id, allow_self_link, true, true)
	end
	
	return text
end

--[==[Replace any links with links to the correct section, but don't link the whole text if no embedded links are found. Returns the display text form.]==]
function export.embedded_language_links(data, allow_self_link)
	if type(data) ~= "table" then
		error("The first argument to the function language_link must be a table. See Module:links/documentation for more information.")
	end
	
	local text = data.term
	data.sc = data.sc or data.lang:findBestScript(text)
	
	-- Do we have embedded wikilinks?
	if text:find("%[%[.-%]%]") then
		text = process_embedded_links(text, data, allow_self_link)
	else
		-- If there are no embedded wikilinks, return the display text.
		text = cond_trim(text)
		-- FIXME: Double-escape any percent-signs, because we don't want to treat non-linked text as having percent-encoded characters.
		text = text:gsub("%%", "%%25")
		text = (data.lang:makeDisplayText(text, data.sc, true))
	end
	
	return text
end

function export.mark(text, item_type, face, lang)
	local tag = { "", "" }

	if item_type == "gloss" then
		tag = { '<span class="mention-gloss-double-quote">“</span><span class="mention-gloss">',
			'</span><span class="mention-gloss-double-quote">”</span>' }
	elseif item_type == "tr" then
		if face == "term" then
			tag = { '<span lang="' .. lang:getNonEtymologicalCode() .. '" class="tr mention-tr Latn">',
				'</span>' }
		else
			tag = { '<span lang="' .. lang:getNonEtymologicalCode() .. '" class="tr Latn">', '</span>' }
		end
	elseif item_type == "ts" then
		-- \226\129\160 = word joiner (zero-width non-breaking space) U+2060
		tag = { '<span class="ts mention-ts Latn">/\226\129\160', '\226\129\160/</span>' }
	elseif item_type == "pos" then
		tag = { '<span class="ann-pos">', '</span>' }
	elseif item_type == "annotations" then
		tag = { '<span class="mention-gloss-paren annotation-paren">(</span>',
			'<span class="mention-gloss-paren annotation-paren">)</span>' }
	end

	if type(text) == "string" then
		return tag[1] .. text .. tag[2]
	else
		return ""
	end
end

--[==[Formats the annotations that are displayed with a link created by {{code|lua|full_link}}. Annotations are the extra bits of information that are displayed following the linked term, and include things such as gender, transliteration, gloss and so on. 
* The first argument is a table possessing some or all of the following keys:
*:; <code class="n">genders</code>
*:: Table containing a list of gender specifications in the style of [[Module:gender and number]].
*:; <code class="n">tr</code>
*:: Transliteration.
*:; <code class="n">gloss</code>
*:: Gloss that translates the term in the link, or gives some other descriptive information.
*:; <code class="n">pos</code>
*:: Part of speech of the linked term. If the given argument matches one of the templates in [[:Category:Part of speech tags]], then call that to show a part-of-speech tag. Otherwise, just show the given text as it is.
*:; <code class="n">lit</code>
*:: Literal meaning of the term, if the usual meaning is figurative or idiomatic.
*:Any of the above values can be omitted from the <code class="n">info</code> argument. If a completely empty table is given (with no annotations at all), then an empty string is returned.
* The second argument is a string. Valid values are listed in [[Module:script utilities/data]] "data.translit" table.]==]
function export.format_link_annotations(data, face)
	local output = {}

	-- Interwiki link
	if data.interwiki then
		insert(output, data.interwiki)
	end

	-- Genders
	if type(data.genders) ~= "table" then
		data.genders = { data.genders }
	end

	if data.genders and #data.genders > 0 then
		local m_gen = require("Module:gender and number")
		insert(output, "&nbsp;" .. m_gen.format_list(data.genders, data.lang))
	end

	local annotations = {}

	-- Transliteration and transcription
	if data.tr and data.tr[1] or data.ts and data.ts[1] then
		local kind
		if face == "term" then
			kind = face
		else
			kind = "default"
		end

		if data.tr[1] and data.ts[1] then
			insert(annotations,
				require("Module:script utilities").tag_translit(data.tr[1], data.lang, kind)
				.. " " .. export.mark(data.ts[1], "ts"))
		elseif data.ts[1] then
			insert(annotations, export.mark(data.ts[1], "ts"))
		else
			insert(annotations,
				require("Module:script utilities").tag_translit(data.tr[1], data.lang, kind))
		end
	end

	-- Gloss/translation
	if data.gloss then
		insert(annotations, export.mark(data.gloss, "gloss"))
	end

	-- Part of speech
	if data.pos then
		-- debug category for pos= containing transcriptions
		if data.pos:find("/[^><]*/") then
			data.pos = data.pos .. "[[Category:links likely containing transcriptions in pos]]"
		end

		pos_tags = pos_tags or mw.loadData("Module:links/data").pos_tags
		insert(annotations, export.mark(pos_tags[data.pos] or data.pos, "pos"))
	end

	-- Literal/sum-of-parts meaning
	if data.lit then
		insert(annotations, "literally " .. export.mark(data.lit, "gloss"))
	end

	if #annotations > 0 then
		insert(output, " " .. export.mark(concat(annotations, ", "), "annotations"))
	end

	return concat(output)
end

-- Add any left or right qualifiers or references to a formatted term. `data` is the object specifying the term, which
-- should optionally contain:
-- * left qualifiers in `q` (an array of strings or a single string); an empty array or blank string will be ignored;
-- * right qualifiers in `qq` (an array of strings or a single string); an empty array or blank string will be ignored;
-- * references in `refs`, an array either of strings (formatted reference text) or objects containing fields `text`
--   (formatted reference text) and optionally `name` and/or `group`.
-- `formatted` is the formatted version of the term itself.
function export.add_qualifiers_and_refs_to_term(data, formatted)
	local left_qualifiers, right_qualifiers
	local reftext

	left_qualifiers = data.q and #data.q > 0 and data.q
	if left_qualifiers then
		left_qualifiers = require("Module:qualifier").format_qualifier(left_qualifiers) .. " "
	end

	right_qualifiers = data.qq and #data.qq > 0 and data.qq
	if right_qualifiers then
		right_qualifiers = " " .. require("Module:qualifier").format_qualifier(right_qualifiers)
	end
	if data.refs and #data.refs > 0 then
		local refs = {}
		for _, ref in ipairs(data.refs) do
			if type(ref) ~= "table" then
				ref = {text = ref}
			end
			local refargs
			if ref.name or ref.group then
				refargs = {name = ref.name, group = ref.group}
			end
			insert(refs, mw.getCurrentFrame():extensionTag("ref", ref.text, refargs))
		end
		reftext = concat(refs)
	end

	if left_qualifiers then
		formatted = left_qualifiers .. formatted
	end
	if reftext then
		formatted = formatted .. reftext
	end
	if right_qualifiers then
		formatted = formatted .. right_qualifiers
	end

	return formatted
end


--[==[Creates a full link, with annotations (see <code class="n">[[#format_link_annotations|format_link_annotations]]</code>), in the style of {{temp|l}} or {{temp|m}}.
The first argument, <code class="n">data</code>, must be a table. It contains the various elements that can be supplied as parameters to {{temp|l}} or {{temp|m}}:
{ {
	term = entry_to_link_to,
	alt = link_text_or_displayed_text,
	lang = language_object,
	sc = script_object,
	fragment = link_fragment
	id = sense_id,
	genders = { "gender1", "gender2", ... },
	tr = transliteration,
	ts = transcription,
	gloss = gloss,
	pos = part_of_speech_tag,
	lit = literal_translation,
	accel = {accelerated_creation_tags},
	interwiki = interwiki,
	q = { "left_qualifier1", "left_qualifier2", ...} or "left_qualifier",
	qq = { "right_qualifier1", "right_qualifier2", ...} or "right_qualifier",
	refs = { "formatted_ref1", "formatted_ref2", ...} or { {text = "text", name = "name", group = "group"}, ... },
} }
Any one of the items in the <code class="n">data</code> table may be {{code|lua|nil}}, but an error will be shown if neither <code class="n">term</code> nor <code class="n">alt</code> nor <code class="n">tr</code> is present.
Thus, calling {{code|lua|2=full_link{ term = term, lang = lang, sc = sc } }}, where <code class="n">term</code> is an entry name, <code class="n">lang</code>  is a [[Module:languages#Language objects|language object]] from [[Module:languages]], and <code class="n">sc</code> is a [[Module:scripts#Script objects|script object]] from [[Module:scripts]], will give a plain link similar to the one produced by the template {{temp|l}}, and calling {{code|lua|2=full_link( { term = term, lang = lang, sc = sc }, "term" )}} will give a link similar to the one produced by the template {{temp|m}}.
The function will:
* Try to determine the script, based on the characters found in the term or alt argument, if the script was not given.
* Call <code class="n">[[#language_link|language_link]]</code> on the term or alt forms, to remove diacritics in the page name, process any embedded wikilinks and create links to Reconstruction or Appendix pages when necessary.
* Call <code class="n">[[Module:script utilities#tag_text]]</code> to add the appropriate language and script tags to the term, and to italicize terms written in the Latin script if necessary. Accelerated creation tags, as used by [[WT:ACCEL]], are included.
* Generate a transliteration, based on the alt or term arguments, if the script is not Latin and no transliteration was provided.
* Add the annotations (transliteration, gender, gloss etc.) after the link.
* If <code class="n">show_qualifiers</code> is specified, left and right qualifiers and references will be displayed. (This is for compatibility reasons, since a fair amount of code stores qualifiers and/or references in these fields and displays them itself, expecting {{code|lua|full_link()}} to ignore them.]==]
function export.full_link(data, face, allow_self_link, show_qualifiers)
	-- Prevent data from being destructively modified.
	local data = shallowcopy(data)
	
	if type(data) ~= "table" then
		error("The first argument to the function full_link must be a table. "
			.. "See Module:links/documentation for more information.")
	end

	local terms = {true}
	
	-- Generate multiple forms if applicable.
	for _, param in ipairs{"term", "alt"} do
		if type(data[param]) == "string" and data[param]:find("//") then
			data[param] = export.split_on_slashes(data[param])
		elseif type(data[param]) == "string" and not (type(data.term) == "string" and data.term:find("//")) then
			data[param] = data.lang:generateForms(data[param])
		else
			data[param] = {}
		end
	end
	
	for _, param in ipairs{"sc", "tr", "ts"} do
		data[param] = {data[param]}
	end
	
	for _, param in ipairs{"term", "alt", "sc", "tr", "ts"} do
		for i in pairs(data[param]) do
			terms[i] = true
		end
	end
	
	-- Create the link
	local output = {}
	local categories = {}
	local link = ""
	local annotations
	
	for i in ipairs(terms) do
		-- Is there any text to show?
		if (data.term[i] or data.alt[i]) then
			-- Try to detect the script if it was not provided
			local best = data.lang:findBestScript(data.alt[i] or data.term[i])
			if not data.sc[i] then
				data.sc[i] = best
			else
				-- Track uses of sc parameter
				track("sc")
				
				if data.sc[i]:getCode() == best:getCode() then
					track("sc/redundant", data.sc[i]:getCode())
				else
					track("sc/needed", data.sc[i]:getCode())
				end
			end
			
			-- If using a discouraged character sequence, add to maintenance category
			if data.sc[i]:hasNormalizationFixes() == true then
				if (data.term[i] and data.sc[i]:fixDiscouragedSequences(toNFC(data.term[i])) ~= toNFC(data.term[i])) or (data.alt[i] and data.sc[i]:fixDiscouragedSequences(toNFC(data.alt[i])) ~= toNFC(data.alt[i])) then
					insert(categories, "Pages using discouraged character sequences")
				end
			end

			local class = ""

			-- Encode certain characters to avoid various delimiter-related issues at various stages. We need to encode < and >
			-- because they end up forming part of CSS class names inside of <span ...> and will interfere with finding the end
			-- of the HTML tag. I first tried converting them to URL encoding, i.e. %3C and %3E; they then appear in the URL as
			-- %253C and %253E, which get mapped back to %3C and %3E when passed to [[Module:accel]]. But mapping them to &lt;
			-- and &gt; somehow works magically without any further work; they appear in the URL as < and >, and get passed to
			-- [[Module:accel]] as < and >. I have no idea who along the chain of calls is doing the encoding and decoding. If
			-- someone knows, please modify this comment appropriately!
			local encode_accel_char_map = {
				["%"] = ".",
				[" "] = "_",
				["_"] = TEMP_UNDERSCORE,
				["<"] = "&lt;",
				[">"] = "&gt;",
			}
			local function encode_accel_param_chars(param)
				local retval = param:gsub("[% <>_]", encode_accel_char_map) -- discard second return value
				return retval
			end

			local function encode_accel_param(prefix, param)
				if not param then
					return ""
				end
				if type(param) == "table" then
					local filled_params = {}
					-- There may be gaps in the sequence, especially for translit params.
					local maxindex = 0
					for k, v in pairs(param) do
						if type(k) == "number" and k > maxindex then
							maxindex = k
						end
					end
					for i=1,maxindex do
						filled_params[i] = param[i] or ""
					end
					-- [[Module:accel]] splits these up again.
					param = concat(filled_params, "*~!")
				end
				-- This is decoded again by [[WT:ACCEL]].
				return prefix .. encode_accel_param_chars(param)
			end

			if data.accel then
				local form = data.accel.form and encode_accel_param_chars(data.accel.form) .. "-form-of" or ""
				local gender = encode_accel_param("gender-", data.accel.gender)
				local pos = encode_accel_param("pos-", data.accel.pos)
				local translit = encode_accel_param("transliteration-",
					data.accel.translit or (data.tr[i] ~= "-" and data.tr[i] or nil))
				local target = encode_accel_param("target-", data.accel.target)
				local lemma = encode_accel_param("origin-", data.accel.lemma)
				local lemma_translit = encode_accel_param("origin_transliteration-", data.accel.lemma_translit)
				local no_store = data.accel.no_store and "form-of-nostore" or ""

				local accel =
					form .. " " ..
					gender .. " " ..
					pos .. " " ..
					translit .. " " ..
					target .. " " ..
					lemma .. " " ..
					lemma_translit .. " " ..
					no_store .. " "

				class = "form-of lang-" .. data.lang:getNonEtymologicalCode() .. " " .. accel
			end
			
			-- Only make a link if the term has been given, otherwise just show the alt text without a link
			local term_data = {
				term = data.term[i],
				alt = data.alt[i],
				lang = data.lang,
				sc = data.sc[i],
				fragment = data.fragment,
				id = data.id,
				genders = data.genders,
				tr = data.tr[i],
				ts = data.ts[i],
				gloss = data.gloss,
				pos = data.pos,
				lit = data.lit,
				accel = data.accel,
				interwiki = data.interwiki
			}
			link = require("Module:script utilities").tag_text(
				data.term[i] and export.language_link(term_data, allow_self_link)
				or data.alt[i], data.lang, data.sc[i], face, class)
		else
			--[[	No term to show.
					Is there at least a transliteration we can work from?	]]
			link = require("Module:script utilities").request_script(data.lang, data.sc[i])
			-- No link to show, and no transliteration either. Show a term request (unless it's a substrate, as they rarely take terms).
			if (link == "" or (not data.tr[i]) or data.tr[i] == "-") and data.lang:getFamilyCode() ~= "qfa-sub" then
				-- If there are multiple terms, break the loop instead.
				if i > 1 then
					remove(output)
					break
				elseif mw.title.getCurrentTitle().nsText ~= "Template" then
					insert(categories, data.lang:getNonEtymologicalName() .. " term requests")
				end
				link = "<small>[Term?]</small>"
			end
		end
		insert(output, link)
		if i < #terms then insert(output, "<span class=\"Zsym mention\" style=\"font-size:100%;\">／</span>") end
	end
	
	-- TODO: Currently only handles the first transliteration, pending consensus on how to handle multiple translits for multiple forms, as this is not always desirable (e.g. traditional/simplified Chinese).
	if data.tr[1] == "" or data.tr[1] == "-" then
		data.tr[1] = nil
		
	else
		local phonetic_extraction = mw.loadData("Module:links/data").phonetic_extraction
		phonetic_extraction = phonetic_extraction[data.lang:getCode()] or phonetic_extraction[data.lang:getNonEtymologicalCode()]
		
		if phonetic_extraction then
			data.tr[1] = data.tr[1] or require(phonetic_extraction).getTranslit(export.remove_links(data.alt[1] or data.term[1]))
			
		elseif (data.term[1] or data.alt[1]) and data.sc[1]:isTransliterated() then
			-- Track whenever there is manual translit. The categories below like 'terms with redundant transliterations'
			-- aren't sufficient because they only work with reference to automatic translit and won't operate at all in
			-- languages without any automatic translit, like Persian and Hebrew.
			if data.tr[1] then
				track("manual-tr", data.lang:getNonEtymologicalCode())
			end
	
			-- Try to generate a transliteration, unless transliteration has been supplied and data.no_check_redundant_translit is
			-- given. (Checking for redundant transliteration can use up significant amounts of memory so we don't want to do it
			-- if memory is tight. `no_check_redundant_translit` is currently set when called ultimately from
			-- {{multitrans|...|no-check-redundant-translit=1}}.)
			if not (data.tr[1] and data.no_check_redundant_translit) then
				local text = data.alt[1] or data.term[1]
				if not data.lang:link_tr() then
					text = export.remove_links(text, true)
				end
				
				local automated_tr, tr_categories
				automated_tr, data.tr_fail, tr_categories = data.lang:transliterate(text, data.sc[1])
				
				if automated_tr or data.tr_fail then
					local manual_tr = data.tr[1]
	
					if manual_tr then
						if (export.remove_links(manual_tr) == export.remove_links(automated_tr)) and (not data.tr_fail) then
							insert(categories, "Terms with redundant transliterations")
							insert(categories, "Terms with redundant transliterations/" .. data.lang:getNonEtymologicalCode())
						elseif not data.tr_fail then
							-- Prevents Arabic root categories from flooding the tracking categories.
							if mw.title.getCurrentTitle().nsText ~= "Category" then
								insert(categories, "Terms with manual transliterations different from the automated ones")
								insert(categories, "Terms with manual transliterations different from the automated ones/" .. data.lang:getNonEtymologicalCode())
							end
						end
					end
	
					if (not manual_tr) or data.lang:overrideManualTranslit() then
						data.tr[1] = automated_tr
						for _, category in ipairs(tr_categories) do
							insert(categories, category)
						end
					end
				end
			end
		end
	end
	
	-- Link to the transliteration entry for languages that require this
	if data.tr[1] and data.lang:link_tr() and not (data.tr[1]:match("%[%[(.-)%]%]") or data.tr_fail) then
		data.tr[1] = export.language_link{
			lang = data.lang,
			term = data.tr[1],
			sc = require("Module:scripts").getByCode("Latn")
		}
	elseif data.tr[1] and not (data.lang:link_tr() or data.tr_fail) then
		-- Remove the pseudo-HTML tags added by remove_links.
		data.tr[1] = data.tr[1]:gsub("</?link>", "")
	end
	if data.tr[1] and gsub(data.tr[1], "[%s%p]", ""):len() == 0 then data.tr[1] = nil end
	
	insert(output, export.format_link_annotations(data, face))
	
	categories = #categories > 0 and require("Module:utilities").format_categories(categories, data.lang, "-", nil, nil, data.sc) or ""

	output = concat(output)
	if show_qualifiers then
		output = export.add_qualifiers_and_refs_to_term(data, output)
	end
	return output .. categories
end

--[==[Replaces all wikilinks with their displayed text, and removes any categories. This function can be invoked either from a template or from another module.
-- Strips links: deletes category links, the targets of piped links, and any double square brackets involved in links (other than file links, which are untouched). If `tag` is set, then any links removed will be given pseudo-HTML tags, which allow the substitution functions in [[Module:languages]] to properly subdivide the text in order to reduce the chance of substitution failures in modules which scrape pages like [[Module:zh-translit]].
-- FIXME: This is quite hacky. We probably want this to be integrated into [[Module:languages]], but we can't do that until we know that nothing is pushing pipe linked transliterations through it for languages which don't have link_tr set.
* <code><nowiki>[[page|displayed text]]</nowiki></code> &rarr; <code><nowiki>displayed text</nowiki></code>
* <code><nowiki>[[page and displayed text]]</nowiki></code> &rarr; <code><nowiki>page and displayed text</nowiki></code>
* <code><nowiki>[[Category:English lemmas|WORD]]</nowiki></code> &rarr; ''(nothing)'']==]
function export.remove_links(text, tag)
	if type(text) == "table" then
		text = text.args[1]
	end

	if not text or text == "" then
		return ""
	end
	
	text = text
		:gsub("%[%[", "\1")
		:gsub("%]%]", "\2")

	-- Parse internal links for the display text.
	text = text:gsub("(\1)([^\1\2]-)(\2)",
		function(c1, c2, c3)
			-- Don't remove files.
			for _, false_positive in ipairs({"file", "image"}) do
				if c2:lower():match("^" .. false_positive .. ":") then return c1 .. c2 .. c3 end
			end
			-- Remove categories completely.
			for _, false_positive in ipairs({"category", "cat"}) do
				if c2:lower():match("^" .. false_positive .. ":") then return "" end
			end
			-- In piped links, remove all text before the pipe, unless it's the final character (i.e. the pipe trick), in which case just remove the pipe.
			c2 = c2:match("^[^|]*|(.+)") or c2:match("([^|]+)|$") or c2
			if tag then
				return "<link>" .. c2 .. "</link>"
			else
				return c2
			end
		end)
		
	text = text
		:gsub("\1", "[[")
		:gsub("\2", "]]")

	return text
end

--[=[
This decodes old section encodings.
For example, Norwegian_Bokm.C3.A5l → Norwegian_Bokmål.
It isn't picky about whether the section encodings represent the UTF-8 encoding
of a real Unicode character, so it will mangle section names that contain
a period followed by two uppercase hex characters. At least such section names
are probably pretty rare.

Wiktionary adds an additional id="" attribute for sections
using a legacy encoding, if it is different from the modern minimally modified attribute.
It is like percent encoding (URI or URL encoding) except with "." instead of "%".
See [[mw:Manual:$wgFragmentMode]] and the code that does the encoding at
https://gerrit.wikimedia.org/r/plugins/gitiles/mediawiki/core/+/7bf779524ab1fd8e1d74f79ea4840564d48eea4d/includes/parser/Sanitizer.php#893
]=]

-- The character class %x should not be used, as it includes the characters a-f,
-- which do not occur in these anchor encodings.
local capital_hex = "[0-9A-F]"

local function decode_anchor(anchor)
	return (anchor:gsub("%.(" .. capital_hex .. capital_hex .. ")",
		function(hex_byte)
			return string.char(tonumber(hex_byte, 16))
		end))
end

function export.section_link(link)
	if type(link) ~= "string" then
		error("The first argument to section_link was a " .. type(link) .. ", but it should be a string.")
	end

	link = link:gsub("_", " ")

	local number_signs = select(2, link:gsub("#", ""))

	if number_signs > 1 then
		error("The section link should only contain one number sign (#).")
	end

	link = mw.uri.decode(link, "WIKI")
	local page, section = link:match("^([^#]*)#(.+)$")
	if page == "" then
		page = nil
	end

	if section then
		section = decode_anchor(section)

		-- URI-encode (percent-encode) section to allow square brackets and
		-- other dodgy characters in section name.
		-- If not percent-encoded, they prevent the parser from creating a link.
		-- Decode percent-encoding in the displayed text
		if page then
			return "[[" .. page .. "#" .. mw.uri.encode(section, "WIKI")
				.. "|" .. page .. " §&nbsp;" .. section .. "]]"
		else
			return "[[#" .. mw.uri.encode(section, "WIKI")
				.. "|§&nbsp;" .. section .. "]]"
		end
	else
		error("The function “section_link” could not find a number sign marking a section name.")
	end
end

return export
