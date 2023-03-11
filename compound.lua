local m_links = require("Module:links")
local m_utilities = require("Module:utilities")
local m_lang = require("Module:languages")

local export = {}

local u = mw.ustring.char
local rsub = mw.ustring.gsub
local usub = mw.ustring.sub
local ulen = mw.ustring.len
local rfind = mw.ustring.find
local rmatch = mw.ustring.match

local debug_force_cat = false -- if set to true, always display categories even on userspace pages


local default_pos = "term"

-- ABOUT TEMPLATE AND DISPLAY HYPHENS:
--
-- The "template hyphen" is the per-script hyphen character that is used in
-- template calls to indicate that a term is an affix. This is always a single
-- Unicode char, but there may be multiple possible hyphens for a given script.
-- Normally this is just the regular hyphen character "-", but for some
-- non-Latin-script languages (currently only right-to-left languages), it
-- is different.
--
-- The "display hyphen" is the string (which might be an empty string) that
-- is added onto a term as displayed (and linked), to indicate that a term
-- is an affix. Currently this is always either the same as the template
-- hyphen or an empty string, but the code below is written generally enough
-- to handle arbitrary display hyphens. Specifically:
--
-- (1) For East Asian languages, the display hyphen is always blank.
-- (2) For Arabic-script languages, either tatweel (ـ) or ZWNJ (zero-width
--     non-joiner) are allowed as template hyphens, where ZWNJ is supported
--     primarily for Farsi, because some suffixes have non-joining behavior.
--     The display hyphen corresponding to tatweel is also tatweel, but the
--     display hyphen corresponding to ZWNJ is blank (tatweel is also the
--     default display hyphen, for calls to {{prefix}}/{{suffix}}/etc. that
--     don't include an explicit hyphen).

-- List of all Arabic scripts.
local arab_scripts = {
	"Arab",
	-- WTF? Why are there a zillion language-specific variants of the
	-- Arabic script?
	"fa-Arab",
	"kk-Arab",
	"ks-Arab",
	"ku-Arab",
	"ms-Arab",
	"mzn-Arab",
	"ota-Arab",
	"pa-Arab",
	"ps-Arab",
	"sd-Arab",
	"tt-Arab",
	"ug-Arab",
	"ur-Arab",
}

-- Per-script template hyphens. The template hyphen is what appears in the
-- {{affix}}/{{prefix}}/{{suffix}}/etc. template (in the wikicode). See below.
--
-- The value below is a string consisting of one or more hyphen characters.
-- If there is more than one character, a non-default function must be
-- specified for the script in display_hyphens[] so the correct display
-- hyphen will be specified when no template hyphen is given (in {{suffix}}/
-- {{prefix}}/etc.).
--
-- Script detection is normally done when linking, but we need to do it
-- earlier. However, under most circumstances we don't need to do script
-- detection. Specifically, we only need to do script detection for a given
-- language if
--
-- (a) the language has multiple scripts; and
-- (b) at least one of those scripts is listed below or in display_hyphens.

local ZWNJ = u(0x200C) -- zero-width non-joiner
local arab_hyphens = "ـ" .. ZWNJ .. "-"
local template_hyphens = {
	-- Arabic scripts get added below
	["Hebr"] = "־",
	-- FIXME! What about the following right-to-left scripts?
	-- Adlm (Adlam)
	-- Armi (Imperial Aramaic)
	-- Avst (Avestan)
	-- Cprt (Cypriot)
	-- Khar (Kharoshthi)
	-- Mand (Mandaic/Mandaean)
	-- Mani (Manichaean)
	-- Mend (Mende/Mende Kikakui)
	-- Narb (Old North Arabian)
	-- Nbat (Nabataean/Nabatean)
	-- Nkoo (N'Ko)
	-- Orkh (Orkhon runes)
	-- Phli (Inscriptional Pahlavi)
	-- Phlp (Psalter Pahlavi)
	-- Phlv (Book Pahlavi)
	-- Phnx (Phoenician)
	-- Prti (Inscriptional Parthian)
	-- Rohg (Hanifi Rohingya)
	-- Samr (Samaritan)
	-- Sarb (Old South Arabian)
	-- Sogd (Sogdian)
	-- Sogo (Old Sogdian)
	-- Syrc (Syriac)
	-- Thaa (Thaana)
}
for _, script in ipairs(arab_scripts) do
	template_hyphens[script] = arab_hyphens
end

-- Default display-hyphen funct
local function default_display_hyphen(script, hyph)
	if not hyph then
		return template_hyphens[script] or "-"
	end
	return hyph
end

local function no_display_hyphen(script, hyph)
	return ""
end

local function arab_get_display_hyphen(script, hyph)
	if not hyph then
		return "ـ" -- tatweel
	elseif hyph == ZWNJ then
		return ""
	else
		return hyph
	end
end

-- Per-script function to return the correct display hyphen given the
-- script and template hyphen. The function should also handle the case
-- where the passed-in template hyphen is nil, corresponding to the
-- situation in {{prefix}}/{{suffix}}/etc. where no template hyphen is
-- specified.
local display_hyphens = {
	-- Arabic scripts get added below
	["Hani"] = no_display_hyphen,
	-- The following is a mixture of several scripts. Hopefully
	-- the specs here are correct!
	["Jpan"] = no_display_hyphen,
	["Laoo"] = no_display_hyphen,
	["Nshu"] = no_display_hyphen,
	["Thaa"] = no_display_hyphen,
	["Thai"] = no_display_hyphen,
}
for _, script in ipairs(arab_scripts) do
	display_hyphens[script] = arab_get_display_hyphen
end

local function glossary_link(entry, text)
	text = text or entry
	return "[[Appendix:Glossary#" .. entry .. "|" .. text .. "]]"
end


local function track(page)
	if type(page) == "table" then
		for i, pg in ipairs(page) do
			page[i] = "compound/" .. pg
		end
	else
		page = "compound/" .. page
	end
   	require("Module:debug/track")(page)
end


local function make_compound_type(typ, alttext)
	return {
		text = glossary_link(typ, alttext) .. " compound",
		cat = typ .. " compounds",
	}
end


-- Make a compound type entry with a simple rather than glossary link.
-- These should be replaced with a glossary link when the entry in the glossary
-- is created.
local function make_non_glossary_compound_type(typ, alttext)
	local link = alttext and "[[" .. typ .. "|" .. alttext .. "]]" or "[[" .. typ .. "]]"
	return {
		text = link .. " compound",
		cat = typ .. " compounds",
	}
end


export.compound_types = {
	["alliterative"] = make_non_glossary_compound_type("alliterative"),
	["allit"] = "alliterative",
	["antonymous"] = make_non_glossary_compound_type("antonymous"),
	["ant"] = "antonymous",
	["bahuvrihi"] = make_compound_type("bahuvrihi", "bahuvrīhi"),
	["bahu"] = "bahuvrihi",
	["bv"] = "bahuvrihi",
	["coordinative"] = make_compound_type("coordinative"),
	["coord"] = "coordinative",
	["descriptive"] = make_compound_type("descriptive"),
	["desc"] = "descriptive",
	["determinative"] = make_compound_type("determinative"),
	["det"] = "determinative",
	["dvandva"] = make_compound_type("dvandva"),
	["dva"] = "dvandva",
	["endocentric"] = make_compound_type("endocentric"),
	["endo"] = "endocentric",
	["exocentric"] = make_compound_type("exocentric"),
	["exo"] = "exocentric",
	["karmadharaya"] = make_compound_type("karmadharaya", "karmadhāraya"),
	["karma"] = "karmadharaya",
	["kd"] = "karmadharaya",
	["rhyming"] = make_non_glossary_compound_type("rhyming"),
	["rhy"] = "rhyming",
	["synonymous"] = make_non_glossary_compound_type("synonymous"),
	["syn"] = "synonymous",
	["tatpurusa"] = make_compound_type("tatpurusa", "tatpuruṣa"),
	["tat"] = "tatpurusa",
	["tp"] = "tatpurusa",
}


local function pluralize(pos)
	if pos ~= "nouns" and usub(pos, -5) ~= "verbs" and usub(pos, -4) ~= "ives" then
		if pos:find("[sx]$") then
			pos = pos .. "es"
		else
			pos = pos .. "s"
		end
	end
	return pos
end

local function make_entry_name_no_links(lang, term)
	-- Remove links and call lang:makeEntryName(term).
	return (m_lang.getNonEtymological(lang):makeEntryName(m_links.remove_links(term)))
end

function export.link_term(terminfo, display_term, lang, sc, sort_key, force_cat, nocat)
	local terminfo_new = require("Module:table").shallowcopy(terminfo)
	local result

	terminfo_new.term = display_term
	terminfo_new.sc = terminfo_new.sc or sc
	if terminfo_new.lang then
		result = require("Module:etymology").format_derived(lang, terminfo_new, sort_key, nocat,
			force_cat or debug_force_cat)
	else
		terminfo_new.lang = lang
		result = m_links.full_link(terminfo_new, "term", false)
	end

	if terminfo_new.q then
		track("q-after-result")
		result = result .. " " .. require("Module:qualifier").format_qualifier(terminfo_new.q)
	end

	if terminfo_new.qq then
		result = result .. " " .. require("Module:qualifier").format_qualifier(terminfo_new.qq)
	end

	return result
end

-- Figure out the appropriate script for the given affix and language (unless
-- the script is explicitly passed in), and return the values of
-- template_hyphens[] and display_hyphens[] for that script, substituting
-- default values as appropriate. Three values are returned:
--	DETECTED_SCRIPT, TEMPLATE_HYPHEN, DISPLAY_HYPHEN
local function get_template_and_display_hyphens(text, lang, sc)
	local scode
	-- 1. If the script is explicitly passed in, use it.
	if sc then
		scode = sc:getCode()
	else
		lang = m_lang.getNonEtymological(lang)
		-- If we don't call shallowClone here, #possible_scripts always == 0.
		-- Something weird to do with the metatable that's set on the table,
		-- coming from loadData.
		local possible_scripts = require("Module:table").shallowClone(lang:getScriptCodes())
		if #possible_scripts == 0 then
			-- This shouldn't happen; if the language has no script codes,
			-- the list {"None"} should be returned.
			error("Something is majorly wrong! Language " .. lang:getCanonicalName() .. " has no script codes.")
		end
		if #possible_scripts == 1 then
			-- 2. If the language has only one possible script, use it.
			scode = possible_scripts[1]
		else
			-- 3. Check if any of the possible scripts for the language have
			--    non-default values for template_hyphens[] or
			--    display_hyphens[]. If so, we need to do script detection on
			--    the text. If not, just use "Latn", which may not be
			--    technically correct but produces the right results because
			--    Latn has all default values for template_hyphens[] and
			--    display_hyphens[].
			local may_have_nondefault_hyphen = false
			for _, script in ipairs(possible_scripts) do
				if template_hyphens[script] or display_hyphens[script] then
					may_have_nondefault_hyphen = true
					break
				end
			end
			if not may_have_nondefault_hyphen then
				scode = "Latn"
			else
				scode = lang:findBestScript(text):getCode()
			end
		end
	end
	local template_hyphen = template_hyphens[scode] or "-"
	local display_hyphen = display_hyphens[scode] or default_display_hyphen
	return scode, template_hyphen, display_hyphen
end

-- Find the type of affix ("prefix", "infix", "suffix", "circumfix" or nil
-- for non-affix). Return the affix type and the displayed/linked equivalent
-- of the part (normally the same as the part but will be different for some
-- East Asian languages that use a regular hyphen as an affix-signaling
-- hyphen but have no display hyphen).
local function get_affix_type(lang, sc, part)
	if not part then
		return nil, nil
	end

	local scode, thyph, dhyph = get_template_and_display_hyphens(part, lang, sc)
	thyph = "([" .. thyph .. "])"
	local hyphen_space_hyphen = thyph .. " " .. thyph

	if part:find("^%^") then
		-- If part begins with ^, it's not an affix no matter what.
		-- Strip off the ^ and return "no affix".
		return nil, usub(part, 2)
	end

	-- Remove an asterisk if the morpheme is reconstructed and add it in the end.
	local reconstructed = ""
	if part:find("^%*") then 
		reconstructed = "*"
		part = part:gsub("^%*", "")
	end

	local affix_type = nil

	local beginning_hyphen = rmatch(part, "^" .. thyph .. ".*$")
	local ending_hyphen = rmatch(part, "^.*" .. thyph .. "$")
	local beginning_dhyph = dhyph(scode, beginning_hyphen)
	local ending_dhyph = dhyph(scode, ending_hyphen)

	if rfind(part, hyphen_space_hyphen) then
		affix_type = "circumfix"
		-- FIXME! Change to display hyphens?
	elseif beginning_hyphen and ending_hyphen then
		affix_type = "infix"
		-- Don't do anything if the part is a single hyphen.
		-- This is probably correct.
		if (beginning_hyphen ~= beginning_dhyph or
			ending_hyphen ~= ending_dhyph) and ulen(part) > 1 then
			part = beginning_dhyph .. rsub(part, "^.(.-).$", "%1") .. ending_dhyph
		end
	elseif ending_hyphen then
		affix_type = "prefix"
		if ending_hyphen ~= ending_dhyph then
			part = rsub(part, "^(.-).$", "%1") .. ending_dhyph
		end
	elseif beginning_hyphen then
		affix_type = "suffix"
		if beginning_hyphen ~= beginning_dhyph then
			part = beginning_dhyph .. usub(part, 2)
		end
	end

	part = reconstructed .. part
	return affix_type, part
end
export.get_affix_type = get_affix_type


-- Iterate an array up to the greatest integer index found.
local function ipairs_with_gaps(t)
	local indices = require("Module:table").numKeys(t)
	local max_index = #indices > 0 and math.max(unpack(indices)) or 0
	local i = 0
	return function()
		while i < max_index do
			i = i + 1
			return i, t[i]
		end
	end
end

export.ipairs_with_gaps = ipairs_with_gaps


-- Concatenate formatted parts together with any overall lit= spec plus categories, which are formatted
-- by prepending the language name. The value of an entry in CATEGORIES can be either a string
-- (which is formatted using SORT_KEY) or a table of the form {cat=CATEGORY, sort_key=SORT_KEY, sort_base=SORT_BASE},
-- specifying the sort key and sort base to use when formatting the category. If NOCAT is given, no
-- categories are added.
function export.concat_parts(lang, parts_formatted, categories, nocat, sort_key, lit, force_cat)
	local cattext
	if nocat then
		cattext = ""
	else
		for i, cat in ipairs(categories) do
			if type(cat) == "table" then
				categories[i] = m_utilities.format_categories({lang:getCanonicalName() .. " " .. cat.cat}, lang,
					cat.sort_key, cat.sort_base, force_cat or debug_force_cat)
			else
				categories[i] = m_utilities.format_categories({lang:getCanonicalName() .. " " .. cat}, lang,
					sort_key, nil, force_cat or debug_force_cat)
			end
		end
		cattext = table.concat(categories)
	end
	return table.concat(parts_formatted, " +&lrm; ") .. (lit and ", literally " .. m_links.mark(lit, "gloss") or "") .. cattext
end


local function process_compound_type(typ, nocap, notext, has_parts)
	local text_sections = {}
	local categories = {}

	if typ then
		local typdata = export.compound_types[typ]
		if type(typdata) == "string" then
			typdata = export.compound_types[typdata]
		end
		if not typdata then
			error("Internal error: Unrecognized type '" .. typ .. "'")
		end
		local text = typdata.text
		if not nocap then
			text = require("Module:string utilities").ucfirst(text)
		end
		local cat = typdata.cat
		local oftext = typdata.oftext or "of"
	
		if not notext then
			table.insert(text_sections, text)
			if has_parts then
				table.insert(text_sections, " ")
				table.insert(text_sections, oftext)
				table.insert(text_sections, " ")
			end
		end
		table.insert(categories, cat)
	end

	return text_sections, categories
end


function export.show_affixes(lang, sc, parts, pos, sort_key, typ, nocap, notext, nocat, lit, force_cat)
	pos = pos or default_pos

	pos = pluralize(pos)

	local text_sections, categories = process_compound_type(typ, nocap, notext, #parts > 0)

	-- Process each part
	local parts_formatted = {}
	local whole_words = 0

	for i, part in ipairs_with_gaps(parts) do
		part = part or {}
		local part_lang = part.lang or lang
		local part_sc = part.sc or sc

		-- Is it an affix, and if so, what type of affix?
		local affix_type, display_term = get_affix_type(part_lang, part_sc, part.term)

		-- Make a link for the part
		-- If display_term is an empty string, either a bare ^ was specified or an empty term was used along with inline
		-- modifiers. The intention in either case is not to link the term.
		table.insert(parts_formatted, export.link_term(part, display_term ~= "" and display_term or nil, lang, sc, sort_key,
			force_cat, nocat))

		if affix_type then
			-- Make a sort key
			-- For the first part, use the second part as the sort key
			local part_sort_base = nil
			local part_sort = part.sort or sort_key

			if i == 1 and parts[2] and parts[2].term then
				local part2_lang = parts[2].lang or lang
				local part2_sc = parts[2].sc or sc
				local part2_affix_type, part2_display_term = get_affix_type(part2_lang, part2_sc, parts[2].term)
				part_sort_base = make_entry_name_no_links(part2_lang, part2_display_term)
			end

			if affix_type == "infix" then affix_type = "interfix" end

			if part.pos and rfind(part.pos, "patronym") then
				table.insert(categories, {cat="patronymics", sort_key=part_sort, sort_base=part_sort_base})
			end

			if pos ~= "terms" and part.pos and rfind(part.pos, "diminutive") then
				table.insert(categories, {cat="diminutive " .. pos, sort_key=part_sort, sort_base=part_sort_base})
			end

			table.insert(categories, {cat=pos .. " " .. affix_type .. "ed with " .. make_entry_name_no_links(part_lang, display_term) .. (part.id and " (" .. part.id .. ")" or ""), sort_key=part_sort, sort_base=part_sort_base})
		else
			whole_words = whole_words + 1

			if whole_words == 2 then
				table.insert(categories, "compound " .. pos)
			end
		end
	end

	-- If there are no categories, then there were no actual affixes, only a single regular term.
	if #categories == 0 then
		error("The parameters did not include any affixes, and the term is not a compound. Please provide at least one affix.")
	end

	table.insert(text_sections, export.concat_parts(lang, parts_formatted, categories, nocat, sort_key, lit, force_cat))
	return table.concat(text_sections)
end


function export.show_compound(lang, sc, parts, pos, sort_key, typ, nocap, notext, nocat, lit, force_cat)
	pos = pos or default_pos

	pos = pluralize(pos)

	local text_sections, categories = process_compound_type(typ, nocap, notext, #parts > 0)

	local parts_formatted = {}
	table.insert(categories, "compound " .. pos)

	-- Make links out of all the parts
	local whole_words = 0
	for i, part in ipairs(parts) do
		local part_lang = part.lang or lang
		local part_sc = part.sc or sc
		local affix_type, display_term = get_affix_type(part_lang, part_sc, part.term)

		-- If the term is an infix, recognize it as such (which means e.g. that we will display the term without hyphens for
		-- East Asian languages). Otherwise, ignore the fact that it looks like an affix and display as specified in the
		-- template (but pay attention to the detected affix type for certain tracking purposes)
		if affix_type == "infix" then
			table.insert(categories, {cat=pos .. " interfixed with " .. make_entry_name_no_links(part_lang, display_term), sort_key=part.sort or sort_key})
		else
			display_term = part.term
			if affix_type then
				track { affix_type, affix_type .. "/lang/" .. lang:getCode() }
			else
				whole_words = whole_words + 1
			end
		end
		table.insert(parts_formatted, export.link_term(part, display_term, lang, sc, sort_key, force_cat, nocat))
	end

	if whole_words == 1 then
		track("one whole word")
	elseif whole_words == 0 then
		track("looks like confix")
	end

	table.insert(text_sections, export.concat_parts(lang, parts_formatted, categories, nocat, sort_key, lit, force_cat))
	return table.concat(text_sections)
end


function export.show_compound_like(lang, sc, parts, sort_key, text, oftext, cat, nocat, lit, force_cat)
	local parts_formatted = {}
	local categories = {}

	if cat then
		table.insert(categories, cat)
	end

	-- Make links out of all the parts
	for i, part in ipairs(parts) do
		table.insert(parts_formatted, export.link_term(part, part.term, lang, sc, sort_key, force_cat, nocat))
	end

	local text_sections = {}
	if text then
		table.insert(text_sections, text)
	end
	if #parts > 0 and oftext then
		table.insert(text_sections, " ")
		table.insert(text_sections, oftext)
		table.insert(text_sections, " ")
	end
	table.insert(text_sections, export.concat_parts(lang, parts_formatted, categories, nocat, sort_key, lit, force_cat))
	return table.concat(text_sections)
end


-- Make a given part into an affix of a specific type. For example, if the desired affix type
-- is "suffix", this will (in general) add a hyphen onto the beginning of the term, alt, tr and ts
-- components of the part if not already present. The hyphen that's added is the "display hyphen"
-- (see above) and may be language-specific. In the case of East Asian languages, the display
-- hyphen is an empty string whereas the template hyphen is the regular hyphen, meaning that any
-- regular hyphen at the beginning of the part will be effectively removed.
local function make_part_affix(part, lang, sc, affix_type)
	local part_lang = part.lang or lang
	local part_sc = part.sc or sc

	part.term = export.make_affix(part.term, part_lang, part_sc, affix_type)
	part.alt = export.make_affix(part.alt, part_lang, part_sc, affix_type)
	local Latn = require("Module:scripts").getByCode("Latn")
	part.tr = export.make_affix(part.tr, part_lang, Latn, affix_type)
	part.ts = export.make_affix(part.ts, part_lang, Latn, affix_type)
end


local function track_wrong_affix_type(template, part, lang, sc, expected_affix_type, part_name)
	if part then
		local affix_type = get_affix_type(part.lang or lang, part.sc or sc, part.term)
		if affix_type ~= expected_affix_type then
			require("Module:debug/track") {
				template,
				template .. "/" .. part_name,
				template .. "/" .. part_name .. "/" .. (affix_type or "none"),
				template .. "/" .. part_name .. "/" .. (affix_type or "none") .. "/lang/" .. lang:getCode()
			}
		end
	end
end


local function insert_affix_category(categories, lang, pos, affix_type, part, sort_key, sort_base)
	if part.term then
		local part_lang = part.lang or lang
		local cat = pos .. " " .. affix_type .. "ed with " .. make_entry_name_no_links(part_lang, part.term) .. (part.id and " (" .. part.id .. ")" or "")
		if sort_key or sort_base then
			table.insert(categories, {cat=cat, sort_key=sort_key, sort_base=sort_base})
		else
			table.insert(categories, cat)
		end
	end
end


function export.show_circumfix(lang, sc, prefix, base, suffix, pos, sort_key, nocat, lit, force_cat)
	local categories = {}
	pos = pos or default_pos

	pos = pluralize(pos)

	-- Hyphenate the affixes
	make_part_affix(prefix, lang, sc, "prefix")
	make_part_affix(suffix, lang, sc, "suffix")

	track_wrong_affix_type("circumfix", prefix, lang, sc, "prefix", "prefix")
	track_wrong_affix_type("circumfix", base, lang, sc, nil, "base")
	track_wrong_affix_type("circumfix", suffix, lang, sc, "suffix", "suffix")

	-- Create circumfix term
	local circumfix = nil

	if prefix.term and suffix.term then
		circumfix = prefix.term .. " " .. suffix.term
		prefix.alt = prefix.alt or prefix.term
		suffix.alt = suffix.alt or suffix.term
		prefix.term = circumfix
		suffix.term = circumfix
	end

	-- Make links out of all the parts
	local parts_formatted = {}
	local sort_base
	if base.term then
		sort_base = make_entry_name_no_links(base.lang or lang, base.term)
	end

	table.insert(parts_formatted, export.link_term(prefix, prefix.term, lang, sc, sort_key, force_cat, nocat))
	table.insert(parts_formatted, export.link_term(base, base.term, lang, sc, sort_key, force_cat, nocat))
	table.insert(parts_formatted, export.link_term(suffix, suffix.term, lang, sc, sort_key, force_cat, nocat))

	-- Insert the categories
	table.insert(categories, {cat=pos .. " circumfixed with " .. make_entry_name_no_links(prefix.lang or lang, circumfix), sort_key=sort_key, sort_base=sort_base})

	return export.concat_parts(lang, parts_formatted, categories, nocat, sort_key, lit, force_cat)
end


function export.show_confix(lang, sc, prefix, base, suffix, pos, sort_key, nocat, lit, force_cat)
	pos = pos or default_pos

	pos = pluralize(pos)

	-- Hyphenate the affixes
	make_part_affix(prefix, lang, sc, "prefix")
	make_part_affix(suffix, lang, sc, "suffix")

	track_wrong_affix_type("confix", prefix, lang, sc, "prefix", "prefix")
	track_wrong_affix_type("confix", base, lang, sc, nil, "base")
	track_wrong_affix_type("confix", suffix, lang, sc, "suffix", "suffix")

	-- Make links out of all the parts
	local parts_formatted = {}
	local prefix_sort_base
	if base and base.term then
		prefix_sort_base = make_entry_name_no_links(base.lang or lang, base.term)
	elseif suffix.term then
		prefix_sort_base = make_entry_name_no_links(suffix.lang or lang, suffix.term)
	end
	local categories = {}

	table.insert(parts_formatted, export.link_term(prefix, prefix.term, lang, sc, sort_key, force_cat, nocat))
	insert_affix_category(categories, lang, pos, "prefix", prefix, sort_key, prefix_sort_base)

	if base then
		table.insert(parts_formatted, export.link_term(base, base.term, lang, sc, sort_key, force_cat, nocat))
	end

	table.insert(parts_formatted, export.link_term(suffix, suffix.term, lang, sc, sort_key, force_cat, nocat))
	insert_affix_category(categories, lang, pos, "suffix", suffix)

	return export.concat_parts(lang, parts_formatted, categories, nocat, sort_key, lit, force_cat)
end


function export.show_infix(lang, sc, base, infix, pos, sort_key, nocat, lit, force_cat)
	local categories = {}
	pos = pos or default_pos

	pos = pluralize(pos)

	-- Hyphenate the affixes
	make_part_affix(infix, lang, sc, "infix")

	track_wrong_affix_type("infix", base, lang, sc, nil, "base")
	track_wrong_affix_type("infix", infix, lang, sc, "infix", "infix")

	-- Make links out of all the parts
	local parts_formatted = {}

	table.insert(parts_formatted, export.link_term(base, base.term, lang, sc, sort_key, force_cat, nocat))
	table.insert(parts_formatted, export.link_term(infix, infix.term, lang, sc, sort_key, force_cat, nocat))

	-- Insert the categories
	insert_affix_category(categories, lang, pos, "infix", infix)

	return export.concat_parts(lang, parts_formatted, categories, nocat, sort_key, lit, force_cat)
end


function export.show_prefixes(lang, sc, prefixes, base, pos, sort_key, nocat, lit, force_cat)
	pos = pos or default_pos

	pos = pluralize(pos)

	-- Hyphenate the affixes
	for i, prefix in ipairs(prefixes) do
		make_part_affix(prefix, lang, sc, "prefix")
	end

	for i, prefix in ipairs(prefixes) do
		track_wrong_affix_type("prefix", prefix, lang, sc, "prefix", "prefix")
	end

	track_wrong_affix_type("prefix", base, lang, sc, nil, "base")

	-- Make links out of all the parts
	local parts_formatted = {}
	local first_sort_base = nil
	local categories = {}

	if prefixes[2] then
		first_sort_base = make_entry_name_no_links(prefixes[2].lang or lang, prefixes[2].term)
	elseif base then
		first_sort_base = make_entry_name_no_links(base.lang or lang, base.term)
	end

	for i, prefix in ipairs(prefixes) do
		table.insert(parts_formatted, export.link_term(prefix, prefix.term, lang, sc, sort_key, force_cat, nocat))
		insert_affix_category(categories, lang, pos, "prefix", prefix, sort_key, i == 1 and first_sort_base or nil)
	end

	if base then
		table.insert(parts_formatted, export.link_term(base, base.term, lang, sc, sort_key, force_cat, nocat))
	else
		table.insert(parts_formatted, "")
	end

	return export.concat_parts(lang, parts_formatted, categories, nocat, sort_key, lit, force_cat)
end


function export.show_suffixes(lang, sc, base, suffixes, pos, sort_key, nocat, lit, force_cat)
	local categories = {}
	pos = pos or default_pos

	pos = pluralize(pos)

	-- Hyphenate the affixes
	for i, suffix in ipairs(suffixes) do
		make_part_affix(suffix, lang, sc, "suffix")
	end

	track_wrong_affix_type("suffix", base, lang, sc, nil, "base")

	for i, suffix in ipairs(suffixes) do
		track_wrong_affix_type("suffix", suffix, lang, sc, "suffix", "suffix")
	end

	-- Make links out of all the parts
	local parts_formatted = {}

	if base then
		table.insert(parts_formatted, export.link_term(base, base.term, lang, sc, sort_key, force_cat, nocat))
	else
		table.insert(parts_formatted, "")
	end

	for i, suffix in ipairs(suffixes) do
		table.insert(parts_formatted, export.link_term(suffix, suffix.term, lang, sc, sort_key, force_cat, nocat))
	end

	-- Insert the categories
	for i, suffix in ipairs(suffixes) do
		if suffix.term then
			insert_affix_category(categories, lang, pos, "suffix", suffix)
		end

		if suffix.pos and rfind(suffix.pos, "patronym") then
			table.insert(categories, "patronymics")
		end
	end

	return export.concat_parts(lang, parts_formatted, categories, nocat, sort_key, lit, force_cat)
end


function export.show_transfix(lang, sc, base, transfix, pos, sort_key, nocat, lit, force_cat)
	local categories = {}
	pos = pos or default_pos

	pos = pluralize(pos)

	-- Hyphenate the affixes
	make_part_affix(transfix, lang, sc, "transfix")

	-- Make links out of all the parts
	local parts_formatted = {}

	table.insert(parts_formatted, export.link_term(base, base.term, lang, sc, sort_key, force_cat, nocat))
	table.insert(parts_formatted, export.link_term(transfix, transfix.term, lang, sc, sort_key, force_cat, nocat))

	-- Insert the categories
	insert_affix_category(categories, lang, pos, "transfix", transfix)

	return export.concat_parts(lang, parts_formatted, categories, nocat, sort_key, lit, force_cat)
end


-- Add a hyphen to a term in the appropriate place, based on the specified affix type. For example, if `affix_type` ==
-- "prefix", we'll add a hyphen onto the end if it's not already there. In general, if the template and display hyphens
-- are the same and the appropriate hyphen is already present, we leave it, else we strip off the template hyphen if
-- present and add the display hyphen.
function export.make_affix(term, lang, sc, affix_type)
	if not (affix_type == "prefix" or affix_type == "suffix" or
		affix_type == "circumfix" or affix_type == "infix" or
		affix_type == "interfix" or affix_type == "transfix") then
		error("Internal error: Invalid affix type " .. (affix_type or "(nil)"))
	end

	if not term then
		return nil
	end

	-- If the term begins with ^, leave it exactly as-is except for removing the ^.
	if usub(term, 1, 1) == "^" then
		return usub(term, 2)
	end

	if affix_type == "circumfix" or affix_type == "transfix" then
		return term
	elseif affix_type == "interfix" then
		affix_type = "infix"
	end

	local scode, thyph, dhyph = get_template_and_display_hyphens(term, lang, sc)
	thyph = "([" .. thyph .. "])"

	-- Remove an asterisk if the morpheme is reconstructed and add it in the end.
	local reconstructed = ""
	if term:find("^%*") then 
		reconstructed = "*"
		term = term:gsub("^%*", "")
	end

	local beginning_hyphen = rmatch(term, "^" .. thyph .. ".*$")
	local ending_hyphen = rmatch(term, "^.*" .. thyph .. "$")
	local beginning_dhyph = dhyph(scode, beginning_hyphen)
	local ending_dhyph = dhyph(scode, ending_hyphen)

	if affix_type == "suffix" then
		if beginning_hyphen and beginning_hyphen == beginning_dhyph then
			-- leave term alone
		else
			local term_no_hyphen = beginning_hyphen and usub(term, 2) or term
			term = beginning_dhyph .. term_no_hyphen
		end
	elseif affix_type == "prefix" then
		if ending_hyphen and ending_hyphen == ending_dhyph then
			-- leave term alone
		else
			local term_no_hyphen = ending_hyphen and rsub(term, "^(.-).$", "%1") or term
			term = term_no_hyphen .. ending_dhyph
		end
	elseif affix_type == "infix" then
		if (beginning_hyphen and ending_hyphen and
			beginning_hyphen == beginning_dhyph and
			ending_hyphen == ending_dhyph) then
			-- leave term alone
		elseif term == beginning_hyphen or term == ending_hyphen then
			-- term is a single hyphen; should probably leave alone
		else
			local term_no_hyphen = beginning_hyphen and usub(term, 2) or term
			term_no_hyphen = ending_hyphen and rsub(term_no_hyphen, "^(.-).$", "%1") or term_no_hyphen
			term = beginning_dhyph .. term_no_hyphen .. ending_dhyph
		end
	else
		error("Internal error: Bad affix type " .. affix_type)
	end

	return reconstructed .. term
end

return export
