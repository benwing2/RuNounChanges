local export = {}

local debug_force_cat = false -- if set to true, always display categories even on userspace pages

local m_links = require("Module:links")
local m_str_utils = require("Module:string utilities")
local m_table = require("Module:table")
local etymology_module = "Module:etymology"
local pron_qualifier_module = "Module:pron qualifier"
local scripts_module = "Module:scripts"
local utilities_module = "Module:utilities"
-- Export this so the category code in [[Module:category tree/poscatboiler/data/terms by etymology]] can access it.
export.affix_lang_data_module_prefix = "Module:affix/lang-data/"

local rsub = m_str_utils.gsub
local usub = m_str_utils.sub
local ulen = m_str_utils.len
local rfind = m_str_utils.find
local rmatch = m_str_utils.match
local pluralize = require("Module:en-utilities").pluralize
local u = m_str_utils.char
local ucfirst = m_str_utils.ucfirst

-- Export this so the category code in [[Module:category tree/poscatboiler/data/terms by etymology]] can access it.
export.langs_with_lang_specific_data = {
	["az"] = true,
	["fi"] = true,
	["izh"] = true,
	["la"] = true,
	["sah"] = true,
	["tr"] = true,
}

local default_pos = "term"

--[==[ intro:
===About different types of hyphens ("template", "display" and "lookup"):===

* The "template hyphen" is the per-script hyphen character that is used in template calls to indicate that a term is an
  affix. This is always a single Unicode char, but there may be multiple possible hyphens for a given script. Normally
  this is just the regular hyphen character "-", but for some non-Latin-script languages (currently only right-to-left
  languages), it is different.
* The "display hyphen" is the string (which might be an empty string) that is added onto a term as displayed and linked,
  to indicate that a term is an affix. Currently this is always either the same as the template hyphen or an empty
  string, but the code below is written generally enough to handle arbitrary display hyphens. Specifically:
  *# For East Asian languages, the display hyphen is always blank.
  *# For Arabic-script languages, either tatweel (ـ) or ZWNJ (zero-width non-joiner) are allowed as template hyphens,
	 where ZWNJ is supported primarily for Farsi, because some suffixes have non-joining behavior. The display hyphen
	 corresponding to tatweel is also tatweel, but the display hyphen corresponding to ZWNJ is blank (tatweel is also
	 the default display hyphen, for calls to {{tl|prefix}}/{{tl|suffix}}/etc. that don't include an explicit hyphen).
* The "lookup hyphen" is the hyphen that is used when looking up language-specific affix mappings. (These mappings are
  discussed in more detail below when discussing link affixes.) It depends only on the script of the affix in question.
  Most scripts (including East Asian scripts) use a regular hyphen "-" as the lookup hyphen, but Hebrew and Arabic
  have their own lookup hyphens (respectively maqqef and tatweel). Note that for Arabic in particular, there are
  three possible template hyphens that are recognized (tatweel, ZWNJ and regular hyphen), but mappings must use tatweel.

===About different types of affixes ("template", "display", "link", "lookup" and "category"):===

* A "template affix" is an affix in its source form as it appears in a template call. Generally, a template affix has
  an attached template hyphen (see above) to indicate that it is an affix and indicate what type of affix it is
  (prefix, suffix, interfix/infix or circumfix), but some of the older-style templates such as {{tl|suffix}},
  {{tl|prefix}}, {{tl|confix}}, etc. have "positional" affixes where the presence of the affix in a certain position
  (e.g. the second or third parameter) indicates that it is a certain type of affix, whether or not it has an attached
  template hyphen.
* A "display affix" is the corresponding affix as it is actually displayed to the user. The display affix may differ
  from the template affix for various reasons:
  *# The display affix may be specified explicitly using the {{para|alt<var>N</var>}} parameter, the `<alt:...>` inline
     modifier or a piped link of the form e.g. `<nowiki>[[-kas|-käs]]</nowiki>` (here indicating that the affix should
	 display as `-käs` but be linked as `-kas`). Here, the template affix is arguably the entire piped link, while the
	 display affix is `-käs`.
  *# Even in the absence of {{para|alt<var>N</var>}} parameters, `<alt:...>` inline modifiers and piped links, certain
     languages have differences between the "template hyphen" specified in the template (which always needs to be
	 specified somehow or other in templates like {{tl|affix}}, to indicate that the term is an affix and what type of
	 affix it is) and the display hyphen (see above), with corresponding differences between template and display affixes.
* A (regular) "link affix" is the affix that is linked to when the affix is shown to the user. The link affix is usually
  the same as the display affix, but will differ in one of three circumstances:
  *# The display and link affixes are explicitly made different using {{para|alt<var>N</var>}} parameters, `<alt:...>`
     inline modifiers or piped links, as described above under "display affix".
  *# For certain languages, certain affixes are mapped to canonical form using language-specific mappings. For example,
	 in Finnish, the adjective-forming suffix [[-kas]] appears as [[-käs]] after front vowels, but logically both
	 forms are the same suffix and should be linked and categorized the same. Similarly, in Latin, the negative and
	 intensive prefixes spelled [[in-]] (etymologically two distinct prefixes) appear variously as [[il-]], [[im-]] or
	 [[ir-]] before certain consonants. Mappings are supplied in [[Module:affix/lang-data/LANGCODE]] to convert
	 Finnish [[-käs]] to [[-kas]] for linking and categorization purposes. Note that the affixes in the mappings use
	 "lookup hyphens" to indicate the different types of affixes, which is usually the same as the template hyphen but
	 differs for Arabic scripts, because there are multiple possible template hyphens recognized but only one lookup
	 hyphen (tatweel). The form of the affix as used to look up in the mapping tables is called the "lookup affix";
	 see below.
* A "stripped link affix" is a link affix that has been passed through the language's `makeEntryName()` function, which
  may strip certain diacritics: e.g. macrons in Latin and Old English (indicating length); acute and grave accents in
  Russian and various other Slavic languages (indicating stress); vowel diacritics in most Arabic-script languages; and
  also tatweel in some Arabic-script languages (currently, for example, Persian, Arabic and Urdu strip tatweel, but
  Ottoman Turkish does not). Stripped link affixes are currently what are used in category names.
* A "lookup affix" is the form of the affix as it is looked up in the language-specific lookup mappings described above
  under link affixes. There are actually two lookup stages:
  *# First, the affix is looked up in a modified display form (specifically, the same as the display affix but using
	 lookup hyphens). Note that this lookup does not occur if an explicit display form is given using
	 {{para|alt<var>N</var>}} or an `<alt:...>` inline modifier, or if the template affix contains a piped or embedded
	 link.
  *# If no entry is found, the affix is then looked up in a modified link form (specifically, the modified display
	 form passed through the language's `makeEntryName()` function, which strips out certain diacritics, but with the
	 lookup hyphen re-added if it was stripped out, as in the case of tatweel in many Arabic-script languages).
  The reason for this double lookup procedure is to allow for mappings that are sensitive to the extra diacritics, but
  also allow for mappings that are not sensitive in this fashion (e.g. Russian [[-ливый]] occurs both stressed and
  unstressed, but is the same prefix either way).
* A "category affix" is the affix as it appears in categories such as [[:Category:Finnish terms suffixed with -kas]].
  The category affix is currently always the same as the stripped link affix. This means that for Arabic-script
  languages, it may or may not have a tatweel, even if the correponding display affix and regular link affix have a
  tatweel. As mentioned above, makeEntryName() strips tatweel for Arabic, Persian and Urdu, but not for Ottoman Turkish.
  Hence affix categories for Arabic, Persian and Urdu will be missing the tatweel, but affix categories for
  Ottoman Turkish will have it. An additional complication is that if the template affix contains a ZWNJ, the display
  (and hence the link and category affixes) will have no hyphen attached in any case.
]==]

-----------------------------------------------------------------------------------------
--                               Template and display hyphens                          --
-----------------------------------------------------------------------------------------

--[=[
Per-script template hyphens. The template hyphen is what appears in the {{affix}}/{{prefix}}/{{suffix}}/etc. template
(in the wikicode). See above.

They key below is a script code, after removing a hyphen and anything preceding. Hence, script codes like 'fa-Arab'
and 'ur-Arab' will match 'Arab'.

The value below is a string consisting of one or more hyphen characters. If there is more than one character, the
default hyphen must come last and a non-default function must be specified for the script in display_hyphens[] so
the correct display hyphen will be specified when no template hyphen is given (in {{suffix}}/{{prefix}}/etc.).

Script detection is normally done when linking, but we need to do it earlier. However, under most circumstances we
don't need to do script detection. Specifically, we only need to do script detection for a given language if

(a) the language has multiple scripts; and
(b) at least one of those scripts is listed below or in display_hyphens.
]=]

local ZWNJ = u(0x200C) -- zero-width non-joiner
local template_hyphens = {
	["Arab"] = "ـ" .. ZWNJ .. "-", -- tatweel + zero-width non-joiner + regular hyphen
	["Hebr"] = "־", -- Hebrew-specific hyphen termed "maqqef"
	-- This covers all Arabic scripts. See above.
	["Mong"] = "᠊",
	["mnc-Mong"] = "᠊",
	["sjo-Mong"] = "᠊",
	["xwo-Mong"] = "᠊",
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

-- Hyphens used when looking up an affix in a lang-specific affix mapping. Defaults to regular hyphen (-). The keys
-- are script codes, after removing a hyphen and anything preceding. Hence, script codes like 'fa-Arab' and 'ur-Arab'
-- will match 'Arab'. The value should be a single character.
local lookup_hyphens = {
	["Hebr"] = "־",
	-- This covers all Arabic scripts. See above.
	["Arab"] = "ـ",
}

-- Default display-hyphen function.
local function default_display_hyphen(script, hyph)
	if not hyph then
		return template_hyphens[script] or "-"
	end
	return hyph
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

local function no_display_hyphen(script, hyph)
	return ""
end

-- Per-script function to return the correct display hyphen given the script and template hyphen. The function should
-- also handle the case where the passed-in template hyphen is nil, corresponding to the situation in
-- {{prefix}}/{{suffix}}/etc. where no template hyphen is specified. The key is the script code after removing a hyphen
-- and anything preceding, so 'fa-Arab', 'ur-Arab' etc. will match 'Arab'.
local display_hyphens = {
	-- This covers all Arabic scripts. See above.
	["Arab"] = arab_get_display_hyphen,
	["Bopo"] = no_display_hyphen,
	["Hani"] = no_display_hyphen,
	["Hans"] = no_display_hyphen,
	["Hant"] = no_display_hyphen,
	-- The following is a mixture of several scripts. Hopefully the specs here are correct!
	["Jpan"] = no_display_hyphen,
	["Jurc"] = no_display_hyphen,
	["Kitl"] = no_display_hyphen,
	["Kits"] = no_display_hyphen,
	["Laoo"] = no_display_hyphen,
	["Nshu"] = no_display_hyphen,
	["Shui"] = no_display_hyphen,
	["Tang"] = no_display_hyphen,
	["Thaa"] = no_display_hyphen,
	["Thai"] = no_display_hyphen,
}

-----------------------------------------------------------------------------------------
--                                 Basic Utility functions                             --
-----------------------------------------------------------------------------------------

local function glossary_link(entry, text)
	text = text or entry
	return "[[Appendix:Glossary#" .. entry .. "|" .. text .. "]]"
end


local function track(page)
	if type(page) == "table" then
		for i, pg in ipairs(page) do
			page[i] = "affix/" .. pg
		end
	else
		page = "affix/" .. page
	end
	require("Module:debug/track")(page)
end


local function ine(val)
	return val ~= "" and val or nil
end


-----------------------------------------------------------------------------------------
--                                      Compound types                                 --
-----------------------------------------------------------------------------------------

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


local function make_raw_compound_type(typ, alttext)
	return {
		text = glossary_link(typ, alttext),
		cat = pluralize(typ),
	}
end


local function make_borrowing_type(typ, alttext)
	return {
		text = glossary_link(typ, alttext),
		borrowing_type = pluralize(typ),
	}
end


export.etymology_types = {
	["adapted borrowing"] = make_borrowing_type("adapted borrowing"),
	["adap"] = "adapted borrowing",
	["abor"] = "adapted borrowing",
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
	["dvigu"] = make_compound_type("dvigu"),
	["dvi"] = "dvigu",
	["endocentric"] = make_compound_type("endocentric"),
	["endo"] = "endocentric",
	["exocentric"] = make_compound_type("exocentric"),
	["exo"] = "exocentric",
	["izafet I"] = make_compound_type("izafet I"),
	["iz1"] = "izafet I",
	["izafet II"] = make_compound_type("izafet II"),
	["iz2"] = "izafet II",
	["izafet III"] = make_compound_type("izafet III"),
	["iz3"] = "izafet III",
	["karmadharaya"] = make_compound_type("karmadharaya", "karmadhāraya"),
	["karma"] = "karmadharaya",
	["kd"] = "karmadharaya",
	["kenning"] = make_raw_compound_type("kenning"),
	["ken"] = "kenning",
	["rhyming"] = make_non_glossary_compound_type("rhyming"),
	["rhy"] = "rhyming",
	["synonymous"] = make_non_glossary_compound_type("synonymous"),
	["syn"] = "synonymous",
	["tatpurusa"] = make_compound_type("tatpurusa", "tatpuruṣa"),
	["tat"] = "tatpurusa",
	["tp"] = "tatpurusa",
}


local function process_etymology_type(typ, nocap, notext, has_parts)
	local text_sections = {}
	local categories = {}
	local borrowing_type

	if typ then
		local typdata = export.etymology_types[typ]
		if type(typdata) == "string" then
			typdata = export.etymology_types[typdata]
		end
		if not typdata then
			error("Internal error: Unrecognized type '" .. typ .. "'")
		end
		local text = typdata.text
		if not nocap then
			text = ucfirst(text)
		end
		local cat = typdata.cat
		borrowing_type = typdata.borrowing_type
		local oftext = typdata.oftext or " of"

		if not notext then
			table.insert(text_sections, text)
			if has_parts then
				table.insert(text_sections, oftext)
				table.insert(text_sections, " ")
			end
		end
		if cat then
			table.insert(categories, cat)
		end
	end

	return text_sections, categories, borrowing_type
end


-----------------------------------------------------------------------------------------
--                                     Utility functions                               --
-----------------------------------------------------------------------------------------

-- Iterate an array up to the greatest integer index found.
local function ipairs_with_gaps(t)
	local indices = m_table.numKeys(t)
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


--[==[
Join formatted parts (in `parts_formatted`) together with any overall {{para|lit}} spec (in `lit`) plus categories,
which are formatted by prepending the language name as found in `lang`. The value of an entry in `categories` can be
either a string (which is formatted using `sort_key`) or a table of the form `{ {cat=<var>category</var>,
sort_key=<var>sort_key</var>, sort_base=<var>sort_base</var>}`, specifying the sort key and sort base to use when
formatting the category. If `nocat` is given, no categories are added; otherwise, `force_cat` causes categories to be
added even on userspace pages.
]==]
function export.join_formatted_parts(data)
	local cattext
	local lang = data.data.lang
	local force_cat = data.data.force_cat or debug_force_cat
	if data.data.nocat then
		cattext = ""
	else
		for i, cat in ipairs(data.categories) do
			if type(cat) == "table" then
				data.categories[i] = require(utilities_module).format_categories(lang:getFullName() .. " " .. cat.cat,
					lang, cat.sort_key, cat.sort_base, force_cat)
			else
				data.categories[i] = require(utilities_module).format_categories(lang:getFullName() .. " " .. cat, lang,
					data.data.sort_key, nil, force_cat)
			end
		end
		cattext = table.concat(data.categories)
	end
	local result = table.concat(data.parts_formatted, " +&lrm; ") .. (data.data.lit and ", literally " ..
		m_links.mark(data.data.lit, "gloss") or "")
	local q = data.data.q
	local qq = data.data.qq
	local l = data.data.l
	local ll = data.data.ll
	if q and q[1] or qq and qq[1] or l and l[1] or ll and ll[1] then
		result = require(pron_qualifier_module).format_qualifiers {
			lang = lang,
			text = result,
			q = q,
			qq = qq,
			l = l,
			ll = ll,
		}
	end

	return result .. cattext
end


--[==[
Older entry point for calling `join_formatted_parts(). FIXME: Convert callers.
]==]
function export.concat_parts(lang, parts_formatted, categories, nocat, sort_key, lit, force_cat)
	return export.join_formatted_parts {
		data = {
			lang = lang,
			nocat = nocat,
			sort_key = sort_key,
			lit = lit,
			force_cat = force_cat,
		},
		parts_formatted = parts_formatted,
		categories = categories,
	}
end


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


-- Remove links and call lang:makeEntryName(term).
local function make_entry_name_no_links(lang, term)
	-- Double parens because makeEntryName() returns multiple values. Yuck.
	return (lang:makeEntryName(m_links.remove_links(term)))
end


--[=[
Convert a raw part as passed into an entry point into a part ready for linking. `lang` and `sc` are the overall
language and script objects. This uses the overall language and script objects as defaults for the part and parses off
any fragment from the term. We need to do the latter so that fragments don't end up in categories and so that we
correctly do affix mapping even in the presence of fragments.
]=]
local function canonicalize_part(part, lang, sc)
	if not part then
		return
	end
	-- Save the original (user-specified, part-specific) value of `lang`. If such a value is specified, we don't insert
	-- a '*fixed with' category, and we format the part using format_derived() in [[Module:etymology]] rather than
	-- full_link() in [[Module:links]].
	part.part_lang = part.lang
	part.lang = part.lang or lang
	part.sc = part.sc or sc
	local term = part.term
	if not term then
		return
	elseif not part.fragment then
		part.term, part.fragment = m_links.get_fragment(term)
	else
		part.term = m_links.get_fragment(term)
	end
end


--[==[
Construct a single linked part based on the information in `part`, for use by `show_affix()` and other entry points.
This should be called after `canonicalize_part()` is called on the part. This is a thin wrapper around `full_link()` in
[[Module:links]] unless `part.part_lang` is specified (indicating that a part-specific language was given), in which
case `format_derived()` in [[Module:etymology]] is called to display a term in a language other than the language of
the overall term (specified in `data.lang`). `data` contains the entire object passed into the entry point and is used
to access information for constructing the categories added by `format_derived()`.
]==]
function export.link_term(part, data)
	local result

	if part.part_lang then
		result = require(etymology_module).format_derived {
			lang = data.lang,
			terminfo = part,
			sort_key = data.sort_key,
			nocat = data.nocat,
			borrowing_type = data.borrowing_type,
			force_cat = data.force_cat or debug_force_cat,
		}
	else
		-- language (e.g. in a pseudo-loan).
		result = m_links.full_link(part, "term")
	end

	if part.q and part.q[1] or part.qq and part.qq[1] or part.l and part.l[1] or part.ll and part.ll[1] or
		part.refs and part.refs[1] then
		result = require(pron_qualifier_module).format_qualifiers {
			lang = part.lang,
			text = result,
			q = part.q,
			qq = part.qq,
			l = part.l,
			ll = part.ll,
			refs = part.refs,
		}
	end

	return result
end


local function canonicalize_script_code(scode)
	-- Convert fa-Arab, ur-Arab etc. to Arab.
	return (scode:gsub("^.*%-", ""))
end


-----------------------------------------------------------------------------------------
--                                  Affix-handling functions                           --
-----------------------------------------------------------------------------------------

-- Figure out the appropriate script for the given affix and language (unless the script is explicitly passed in), and
-- return the values of template_hyphens[], display_hyphens[] and lookup_hyphens[] for that script, substituting
-- default values as appropriate. Four values are returned:
--	DETECTED_SCRIPT, TEMPLATE_HYPHEN, DISPLAY_HYPHEN, LOOKUP_HYPHEN
local function detect_script_and_hyphens(text, lang, sc)
	local scode
	-- 1. If the script is explicitly passed in, use it.
	if sc then
		scode = sc:getCode()
	else
		local possible_script_codes = lang:getScriptCodes()
		-- YUCK! `possible_script_codes` comes from loadData() so #possible_scripts doesn't work (always returns 0).
		local num_possible_script_codes = m_table.length(possible_script_codes)
		if num_possible_script_codes == 0 then
			-- This shouldn't happen; if the language has no script codes,
			-- the list {"None"} should be returned.
			error("Something is majorly wrong! Language " .. lang:getCanonicalName() .. " has no script codes.")
		end
		if num_possible_script_codes == 1 then
			-- 2. If the language has only one possible script, use it.
			scode = possible_script_codes[1]
		else
			-- 3. Check if any of the possible scripts for the language have non-default values for template_hyphens[]
			--    or display_hyphens[]. If so, we need to do script detection on the text. If not, just use "Latn",
			--    which may not be technically correct but produces the right results because Latn has all default
			--    values for template_hyphens[] and display_hyphens[].
			local may_have_nondefault_hyphen = false
			for _, script_code in ipairs(possible_script_codes) do
				script_code = canonicalize_script_code(script_code)
				if template_hyphens[script_code] or display_hyphens[script_code] then
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
	scode = canonicalize_script_code(scode)
	local template_hyphen = template_hyphens[scode] or "-"
	local lookup_hyphen = lookup_hyphens[scode] or "-"
	local display_hyphen = display_hyphens[scode] or default_display_hyphen
	return scode, template_hyphen, display_hyphen, lookup_hyphen
end


--[=[
Given a template affix `term` and an affix type `affix_type`, change the relevant template hyphen(s) in the affix to
the display or lookup hyphen specified in `new_hyphen`, or add them if they are missing. `new_hyphen` can be a string,
specifying a fixed hyphen, or a function of two arguments (the script code `scode` and the discovered template hyphen,
or nil of no relevant template hyphen is present). `thyph_re` is a Lua pattern (which must be enclosed in parens) that
matches the possible template hyphens. Note that not all template hyphens present in the affix are changed, but only
the "relevant" ones (e.g. for a prefix, a relevant template hyphen is one coming at the end of the affix).
]=]
local function reconstruct_term_per_hyphens(term, affix_type, scode, thyph_re, new_hyphen)
	local function get_hyphen(hyph)
		if type(new_hyphen) == "string" then
			return new_hyphen
		end
		return new_hyphen(scode, hyph)
	end

	if not affix_type then
		return term
	elseif affix_type == "circumfix" then
		local before, before_hyphen, after_hyphen, after = rmatch(term, "^(.*)" .. thyph_re .. " " .. thyph_re
			.. "(.*)$")
		if not before or ulen(term) <= 3 then
			-- Unlike with other types of affixes, don't try to add hyphens in the middle of the term to convert it to
			-- a circumfix. Also, if the term is just hyphen + space + hyphen, return it.
			return term
		end
		return before .. get_hyphen(before_hyphen) .. " " .. get_hyphen(after_hyphen) .. after
	elseif affix_type == "infix" or affix_type == "interfix" then
		local before_hyphen, middle, after_hyphen = rmatch(term, "^" .. thyph_re .. "(.*)" .. thyph_re .. "$")
		if before_hyphen and ulen(term) <= 1 then
			-- If the term is just a hyphen, return it.
			return term
		end
		return get_hyphen(before_hyphen) .. (middle or term) .. get_hyphen(after_hyphen)
	elseif affix_type == "prefix" then
		local middle, after_hyphen = rmatch(term, "^(.*)" .. thyph_re .. "$")
		if middle and ulen(term) <= 1 then
			-- If the term is just a hyphen, return it.
			return term
		end
		return (middle or term) .. get_hyphen(after_hyphen)
	elseif affix_type == "suffix" then
		local before_hyphen, middle = rmatch(term, "^" .. thyph_re .. "(.*)$")
		if before_hyphen and ulen(term) <= 1 then
			-- If the term is just a hyphen, return it.
			return term
		end
		return get_hyphen(before_hyphen) .. (middle or term)
	else
		error(("Internal error: Unrecognized affix type '%s'"):format(affix_type))
	end
end


--[=[
Look up a mapping from a given affix variant to the canonical form used in categories and links. The lookup tables are
language-specific according to `lang`, and may be ID-specific according to `affix_id`. The affixes as they appear in the
lookup tables (both the variant and the canonical form) are in "lookup affix" format (approximately speaking, they use a
regular hyphen for most scripts, but a tatweel for Arabic-script entries and a maqqef for Hebrew-script entries), but
the passed-in `affix` param is in "template affix" format (which differs from the lookup affix for Arabic-script
entries, because more types of hyphens are allowed in template affixes; see the comments at the top of the file). The
remaining parameters to this function are used to convert from template affixes to lookup affixes; see the
reconstruct_term_per_hyphens() function above.

If the affix contains brackets, no lookup is done. Otherwise, a two-stage process is used, first looking up the affix
directly and then stripping diacritics and looking it up again. The reason for this is documented above in the comments
at the top of the file (specifically, the comments describing lookup affixes).

The value of a mapping can either be a string (do the mapping regardless of affix ID) or a table indexed by affix ID
(where the special value `false` indicates no affix ID). The values of entries in this table can also be strings, or
tables with keys `affix` and `id` (again, use `false` to indicate no ID). This allows an affix mapping to map from one
ID to another (for example, this is used in English to map the [[an-]] prefix with no ID to the [[a-]] prefix with the
ID 'not').

The Given a template affix `term` and an affix type `affix_type`, change the relevant template hyphen(s) in the affix to
the display or lookup hyphen specified in `new_hyphen`, or add them if they are missing. `new_hyphen` can be a string,
specifying a fixed hyphen, or a function of two arguments (the script code `scode` and the discovered template hyphen,
or nil of no relevant template hyphen is present). `thyph_re` is a Lua pattern (which must be enclosed in parens) that
matches the possible template hyphens. Note that not all template hyphens present in the affix are changed, but only
the "relevant" ones (e.g. for a prefix, a relevant template hyphen is one coming at the end of the affix).
]=]
local function lookup_affix_mapping(affix, affix_type, lang, scode, thyph_re, lookup_hyph, affix_id)
	local function do_lookup(affix)
		-- Ensure that the affix uses lookup hyphens regardless of whether it used a different type of hyphens before
		-- or no hyphens.
		local lookup_affix = reconstruct_term_per_hyphens(affix, affix_type, scode, thyph_re, lookup_hyph)
		local function do_lookup_for_langcode(langcode)
			if export.langs_with_lang_specific_data[langcode] then
				local langdata = mw.loadData(export.affix_lang_data_module_prefix .. langcode)
				if langdata.affix_mappings then
					local mapping = langdata.affix_mappings[lookup_affix]
					if mapping then
						if type(mapping) == "table" then
							mapping = mapping[affix_id or false]
							if mapping then
								return mapping
							end
						else
							return mapping
						end
					end
				end
			end
		end

		-- If `lang` is an etymology-only language, look for a mapping both for it and its full parent.
		local langcode = lang:getCode()
		local mapping = do_lookup_for_langcode(langcode)
		if mapping then
			return mapping
		end
		local full_langcode = lang:getFullCode()
		if full_langcode ~= langcode then
			mapping = do_lookup_for_langcode(full_langcode)
			if mapping then
				return mapping
			end
		end
		return nil
	end

	if affix:find("%[%[") then
		return nil
	end

	-- Double parens because makeEntryName() returns multiple values. Yuck.
	return do_lookup(affix) or do_lookup((lang:makeEntryName(affix))) or nil
end


--[==[
For a given template term in a given language (see the definition of "template affix" near the top of the file),
possibly in an explicitly specified script `sc` (but usually nil), return the term's affix type ({"prefix"}, {"infix"},
{"suffix"}, {"circumfix"} or {nil} for non-affix) along with the corresponding link and display affixes (see definitions
near the top of the file); also the corresponding lookup affix (if `return_lookup_affix` is specified). The term passed
in should already have any fragment (after the # sign) parsed off of it. Four values are returned: `affix_type`,
`link_term`, `display_term` and `lookup_term`. The affix type can be passed in instead of autodetected (pass in {false}
if the term is not an affix); in this case, the template term need not have any attached hyphens, and the appropriate
hyphens will be added in the appropriate places. If `do_affix_mapping` is specified, look up the affix in the
lang-specific affix mappings, as described in the comment at the top of the file; otherwise, the link and display terms
will always be the same. (They will be the same in any case if the template term has a bracketed link in it or is not
an affix.) If `return_lookup_affix` is given, the fourth return value contains the term with appropriate lookup hyphens
in the appropriate places; otherwise, it is the same as the display term. (This functionality is used in
[[Module:category tree/poscatboiler/data/affixes and compounds]] to convert link affixes into lookup affixes so that
they can be looked up in the affix mapping tables.)
]==]
local function parse_term_for_affixes(term, lang, sc, affix_type, do_affix_mapping, return_lookup_affix, affix_id)
	if not term then
		return nil, nil, nil, nil
	end

	if term:find("^%^") then
		-- HACK! ^ at the beginning of Korean languages has a special meaning, triggering capitalization of the
		-- transliteration. Don't interpret it as "force non-affix" for those languages.
		local langcode = lang:getCode()
		if langcode ~= "ko" and langcode ~= "okm" and langcode ~= "jje" then
			-- If term begins with ^, it's not an affix no matter what. Strip off the ^ and return "no affix".
			term = usub(term, 2)
			return nil, term, term, term
		end
	end

	-- Remove an asterisk if the morpheme is reconstructed and add it back at the end.
	local reconstructed = ""
	if term:find("^%*") then
		reconstructed = "*"
		term = term:gsub("^%*", "")
	end

	local scode, thyph, dhyph, lhyph = detect_script_and_hyphens(term, lang, sc)
	thyph = "([" .. thyph .. "])"

	if affix_type == nil then
		if rfind(term, thyph .. " " .. thyph) then
			affix_type = "circumfix"
		else
			local has_beginning_hyphen = rfind(term, "^" .. thyph)
			local has_ending_hyphen = rfind(term, thyph .. "$")
			if has_beginning_hyphen and has_ending_hyphen then
				affix_type = "infix"
			elseif has_ending_hyphen then
				affix_type = "prefix"
			elseif has_beginning_hyphen then
				affix_type = "suffix"
			end
		end
	end

	local link_term, display_term, lookup_term
	if affix_type then
		display_term = reconstruct_term_per_hyphens(term, affix_type, scode, thyph, dhyph)
		if do_affix_mapping then
			link_term = lookup_affix_mapping(term, affix_type, lang, scode, thyph, lhyph, affix_id)
			-- The return value of lookup_affix_mapping() may be an affix mapping with lookup hyphens if a mapping
			-- was found, otherwise nil if a mapping was not found. We need to convert to display hyphens in
			-- either case, but in the latter case we can reuse the display term, which has already been converted.
			if link_term then
				link_term = reconstruct_term_per_hyphens(link_term, affix_type, scode, thyph, dhyph)
			else
				link_term = display_term
			end
		else
			link_term = display_term
		end
		if return_lookup_affix then
			lookup_term = reconstruct_term_per_hyphens(term, affix_type, scode, thyph, lhyph)
		else
			lookup_term = display_term
		end
	else
		link_term = term
		display_term = term
		lookup_term = term
	end

	link_term = reconstructed .. link_term
	display_term = reconstructed .. display_term
	lookup_term = reconstructed .. lookup_term

	return affix_type, link_term, display_term, lookup_term
end


--[==[
Add a hyphen to a term in the appropriate place, based on the specified affix type, stripping off any existing hyphens
in that place. For example, if `affix_type` == {"prefix"}, we'll add a hyphen onto the end if it's not already there (or
is of the wrong type). Three values are returned: the link term, display term and lookup term. This function is a thin
wrapper around `parse_term_for_affixes`; see the comments above that function for more information. Note that this
function is exposed externally because it is called by [[Module:category tree/poscatboiler/data/affixes and compounds]];
see the comment in `parse_term_for_affixes` for more information.
]==]
function export.make_affix(term, lang, sc, affix_type, do_affix_mapping, return_lookup_affix, affix_id)
	if not (affix_type == "prefix" or affix_type == "suffix" or affix_type == "circumfix" or affix_type == "infix" or
		affix_type == "interfix") then
		error("Internal error: Invalid affix type " .. (affix_type or "(nil)"))
	end

	local _, link_term, display_term, lookup_term = parse_term_for_affixes(term, lang, sc, affix_type,
		do_affix_mapping, return_lookup_affix, affix_id)
	return link_term, display_term, lookup_term
end


-----------------------------------------------------------------------------------------
--                                     Main entry points                               --
-----------------------------------------------------------------------------------------

--[==[
Implementation of {{tl|affix}} and {{tl|surface analysis}}. `data` contains all the information describing the affixes to
be displayed, and contains the following:

* `.lang` ('''required'''): Overall language object. Different from term-specific language objects (see `.parts` below).
* `.sc`: Overall script object (usually omitted). Different from term-specific script objects.
* `.parts` ('''required'''): List of objects describing the affixes to show. The general format of each object is as would
           be passed to `full_link()`, except that the `.lang` field should be missing unless the term is of a language
		   different from the overall `.lang` value (in such a case, the language name is shown along with the term and
		   an additional "derived from" category is added). '''WARNING''': The data in `.parts` will be destructively
		   modified.
* `.pos`: Overall part of speech (used in categories, defaults to {"terms"}). Different from term-specific part of speech.
* `.sort_key`: Overall sort key. Normally omitted except e.g. in Japanese.
* `.type`: Type of compound, if the parts in `.parts` describe a compound. Strictly optional, and if supplied, the
		   compound type is displayed before the parts (normally capitalized, unless `.nocap` is given).
* `.nocap`: Don't capitalize the first letter of text displayed before the parts (relevant only if `.type` or
		    `.surface_analysis` is given).
* `.notext`: Don't display any text before the parts (relevant only if `.type` or `.surface_analysis` is given).
* `.nocat`: Disable all categorization.
* `.lit`: Overall literal definition. Different from term-specific literal definitions.
* `.force_cat`: Always display categories, even on userspace pages.
* `.surface_analysis`: Implement {{surface analysis}}; adds `By surface analysis, ` before the parts.

'''WARNING''': This destructively modifies both `data` and the individual structures within `.parts`.
]==]
function export.show_affix(data)
	data.pos = data.pos or default_pos
	data.pos = pluralize(data.pos)

	local text_sections, categories, borrowing_type =
		process_etymology_type(data.type, data.surface_analysis or data.nocap, data.notext, #data.parts > 0)
	data.borrowing_type = borrowing_type

	-- Process each part
	local parts_formatted = {}
	local whole_words = 0
	local is_affix_or_compound = false

	-- Canonicalize and generate links for all the parts first; then do categorization in a separate step, because when
	-- processing the first part for categorization, we may access the second part and need it already canonicalized.
	for i, part in ipairs_with_gaps(data.parts) do
		part = part or {}
		data.parts[i] = part
		canonicalize_part(part, data.lang, data.sc)

		-- Determine affix type and get link and display terms (see text at top of file). Store them in the part
		-- (in fields that won't clash with fields used by full_link() in [[Module:links]] or link_term()), so they
		-- can be used in the loop below when categorizing.
		part.affix_type, part.affix_link_term, part.affix_display_term = parse_term_for_affixes(part.term,
			part.lang, part.sc, nil, not part.alt, nil, part.id)

		-- If link_term is an empty string, either a bare ^ was specified or an empty term was used along with inline
		-- modifiers. The intention in either case is not to link the term.
		part.term = ine(part.affix_link_term)
		-- If part.alt would be the same as part.term, make it nil, so that it isn't erroneously tracked as being
		-- redundant alt text.
		part.alt = part.alt or (part.affix_display_term ~= part.affix_link_term and part.affix_display_term) or nil

		-- Make a link for the part.
		table.insert(parts_formatted, export.link_term(part, data))
	end

	-- Now do categorization.
	for i, part in ipairs_with_gaps(data.parts) do
		local affix_type = part.affix_type
		if affix_type then
			is_affix_or_compound = true
			-- We cannot distinguish interfixes from infixes by appearance. Prefer interfixes; infixes will need to
			-- use {{infix}}.
			if affix_type == "infix" then affix_type = "interfix" end

			-- Make a sort key. For the first part, use the second part as the sort key; the intention is that if the
			-- term has a prefix, sorting by the prefix won't be very useful so we sort by what follows, which is
			-- presumably the root.
			local part_sort_base = nil
			local part_sort = part.sort or data.sort_key

			if i == 1 and data.parts[2] and data.parts[2].term then
				local part2 = data.parts[2]
				-- If the second-part link term is empty, the user requested an unlinked term; avoid a wikitext error
				-- by using the alt value if available.
				part_sort_base = ine(part2.affix_link_term) or ine(part2.alt)
				if part_sort_base then
					part_sort_base = make_entry_name_no_links(part2.lang, part_sort_base)
				end
			end

			if part.pos and rfind(part.pos, "patronym") then
				table.insert(categories, {cat = "patronymics", sort_key = part_sort, sort_base = part_sort_base})
			end

			if data.pos ~= "terms" and part.pos and rfind(part.pos, "diminutive") then
				table.insert(categories, {cat = "diminutive " .. data.pos, sort_key = part_sort,
					sort_base = part_sort_base})
			end

			-- Don't add a '*fixed with' category if the link term is empty or is in a different language.
			if ine(part.affix_link_term) and not part.part_lang then
				table.insert(categories, {cat = data.pos .. " " .. affix_type .. "ed with " ..
					make_entry_name_no_links(part.lang, part.affix_link_term) ..
						(part.id and " (" .. part.id .. ")" or ""),
					sort_key = part_sort, sort_base = part_sort_base})
			end
		else
			whole_words = whole_words + 1

			if whole_words == 2 then
				is_affix_or_compound = true
				table.insert(categories, "compound " .. data.pos)
			end
		end
	end

	-- Make sure there was either an affix or a compound (two or more regular terms).
	if not is_affix_or_compound then
		error("The parameters did not include any affixes, and the term is not a compound. Please provide at least one affix.")
	end

	if data.surface_analysis then
		local text = "by " .. glossary_link("surface analysis") .. ", "
		if not data.nocap then
			text = ucfirst(text)
		end

		table.insert(text_sections, 1, text)
	end

	table.insert(text_sections, export.join_formatted_parts { data = data, parts_formatted = parts_formatted,
		categories = categories })
	return table.concat(text_sections)
end


function export.show_surface_analysis(data)
	data.surface_analysis = true
	return export.show_affix(data)
end


--[==[
Implementation of {{tl|compound}}.

'''WARNING''': This destructively modifies both `data` and the individual structures within `.parts`.
]==]
function export.show_compound(data)
	data.pos = data.pos or default_pos
	data.pos = pluralize(data.pos)

	local text_sections, categories, borrowing_type =
		process_etymology_type(data.type, data.nocap, data.notext, #data.parts > 0)
	data.borrowing_type = borrowing_type

	local parts_formatted = {}
	table.insert(categories, "compound " .. data.pos)

	-- Make links out of all the parts
	local whole_words = 0
	for i, part in ipairs(data.parts) do
		canonicalize_part(part, data.lang, data.sc)
		-- Determine affix type and get link and display terms (see text at top of file).
		local affix_type, link_term, display_term = parse_term_for_affixes(part.term, part.lang, part.sc,
			nil, not part.alt, nil, part.id)

		-- If the term is an infix, recognize it as such (which means e.g. that we will display the term without
		-- hyphens for East Asian languages). Otherwise, ignore the fact that it looks like an affix and display as
		-- specified in the template (but pay attention to the detected affix type for certain tracking purposes).
		if affix_type == "infix" then
			-- If link_term is an empty string, either a bare ^ was specified or an empty term was used along with
			-- inline modifiers. The intention in either case is not to link the term. Don't add a '*fixed with'
			-- category in this case, or if the term is in a different language.
			-- If part.alt would be the same as part.term, make it nil, so that it isn't erroneously tracked as being
			-- redundant alt text.
			if link_term and link_term ~= "" and not part.part_lang then
				table.insert(categories, {cat = data.pos .. " interfixed with " .. make_entry_name_no_links(part.lang,
					link_term), sort_key = part.sort or data.sort_key})
			end
			part.term = link_term ~= "" and link_term or nil
			part.alt = part.alt or (display_term ~= link_term and display_term) or nil
		else
			if affix_type then
				local langcode = data.lang:getCode()
				-- If `data.lang` is an etymology-only language, track both using its code and its full parent's code.
				track { affix_type, affix_type .. "/lang/" .. langcode }
				local full_langcode = data.lang:getFullCode()
				if langcode ~= full_langcode then
					track(affix_type .. "/lang/" .. full_langcode)
				end
			else
				whole_words = whole_words + 1
			end
		end
		table.insert(parts_formatted, export.link_term(part, data))
	end

	if whole_words == 1 then
		track("one whole word")
	elseif whole_words == 0 then
		track("looks like confix")
	end

	table.insert(text_sections, export.join_formatted_parts { data = data, parts_formatted = parts_formatted,
		categories = categories })
	return table.concat(text_sections)
end


--[==[
Implementation of {{tl|blend}}, {{tl|univerbation}} and similar "compound-like" templates.

'''WARNING''': This destructively modifies both `data` and the individual structures within `.parts`.
]==]
function export.show_compound_like(data)
	local parts_formatted = {}
	local categories = {}

	if data.cat then
		table.insert(categories, data.cat)
	end

	-- Make links out of all the parts
	for i, part in ipairs(data.parts) do
		canonicalize_part(part, data.lang, data.sc)
		table.insert(parts_formatted, export.link_term(part, data))
	end

	local text_sections = {}
	if data.text then
		table.insert(text_sections, data.text)
	end
	if #data.parts > 0 and data.oftext then
		table.insert(text_sections, " ")
		table.insert(text_sections, data.oftext)
		table.insert(text_sections, " ")
	end
	table.insert(text_sections, export.join_formatted_parts { data = data, parts_formatted = parts_formatted,
		categories = categories })
	return table.concat(text_sections)
end


--[==[
Make `part` (a structure holding information on an affix part) into an affix of type `affix_type`, and apply any
relevant affix mappings. For example, if the desired affix type is "suffix", this will (in general) add a hyphen onto
the beginning of the term, alt, tr and ts components of the part if not already present. The hyphen that's added is the
"display hyphen" (see above) and may be script-specific. (In the case of East Asian scripts, the display hyphen is an
empty string whereas the template hyphen is the regular hyphen, meaning that any regular hyphen at the beginning of the
part will be effectively removed.) `lang` and `sc` hold overall language and script objects.

Note that this also applies any language-specific affix mappings, so that e.g. if the language is Finnish and the user
specified [[-käs]] in the affix and didn't specify an `.alt` value, `part.term` will contain [[-kas]] and `part.alt` will
contain [[-käs]].

This function is used by the "legacy" templates ({{tl|prefix}}, {{tl|suffix}}, {{tl|confix}}, etc.) where the nature of
the affix is specified by the template itself rather than auto-determined from the affix, as is the case with
{{tl|affix}}.

'''WARNING''': This destructively modifies `part`.
]==]
local function make_part_into_affix(part, lang, sc, affix_type)
	canonicalize_part(part, lang, sc)
	local link_term, display_term = export.make_affix(part.term, part.lang, part.sc, affix_type, not part.alt, nil, part.id)
	part.term = link_term
	-- When we don't specify `do_affix_mapping` to make_affix(), link and display terms (first and second retvals of
	-- make_affix()) are the same.
	-- If part.alt would be the same as part.term, make it nil, so that it isn't erroneously tracked as being
	-- redundant alt text.
	part.alt = part.alt and export.make_affix(part.alt, part.lang, part.sc, affix_type) or (display_term ~= link_term and display_term) or nil
	local Latn = require(scripts_module).getByCode("Latn")
	part.tr = export.make_affix(part.tr, part.lang, Latn, affix_type)
	part.ts = export.make_affix(part.ts, part.lang, Latn, affix_type)
end


local function track_wrong_affix_type(template, part, expected_affix_type)
	if part then
		local affix_type = parse_term_for_affixes(part.term, part.lang, part.sc)
		if affix_type ~= expected_affix_type then
			local part_name = expected_affix_type or "base"
			local langcode = part.lang:getCode()
			local full_langcode = part.lang:getFullCode()
			require("Module:debug/track") {
				template,
				template .. "/" .. part_name,
				template .. "/" .. part_name .. "/" .. (affix_type or "none"),
				template .. "/" .. part_name .. "/" .. (affix_type or "none") .. "/lang/" .. langcode
			}
			-- If `part.lang` is an etymology-only language, track both using its code and its full parent's code.
			if full_langcode ~= langcode then
				require("Module:debug/track")(
					template .. "/" .. part_name .. "/" .. (affix_type or "none") .. "/lang/" .. full_langcode
				)
			end
		end
	end
end


local function insert_affix_category(categories, pos, affix_type, part, sort_key, sort_base)
	-- Don't add a '*fixed with' category if the link term is empty or is in a different language.
	if part.term and not part.part_lang then
		local cat = pos .. " " .. affix_type .. "ed with " .. make_entry_name_no_links(part.lang, part.term) ..
			(part.id and " (" .. part.id .. ")" or "")
		if sort_key or sort_base then
			table.insert(categories, {cat = cat, sort_key = sort_key, sort_base = sort_base})
		else
			table.insert(categories, cat)
		end
	end
end


--[==[
Implementation of {{tl|circumfix}}.

'''WARNING''': This destructively modifies both `data` and `.prefix`, `.base` and `.suffix`.
]==]
function export.show_circumfix(data)
	data.pos = data.pos or default_pos
	data.pos = pluralize(data.pos)

	canonicalize_part(data.base, data.lang, data.sc)
	-- Hyphenate the affixes and apply any affix mappings.
	make_part_into_affix(data.prefix, data.lang, data.sc, "prefix")
	make_part_into_affix(data.suffix, data.lang, data.sc, "suffix")

	track_wrong_affix_type("circumfix", data.prefix, "prefix")
	track_wrong_affix_type("circumfix", data.base, nil)
	track_wrong_affix_type("circumfix", data.suffix, "suffix")

	-- Create circumfix term.
	local circumfix = nil

	if data.prefix.term and data.suffix.term then
		circumfix = data.prefix.term .. " " .. data.suffix.term
		data.prefix.alt = data.prefix.alt or data.prefix.term
		data.suffix.alt = data.suffix.alt or data.suffix.term
		data.prefix.term = circumfix
		data.suffix.term = circumfix
	end

	-- Make links out of all the parts.
	local parts_formatted = {}
	local categories = {}
	local sort_base
	if data.base.term then
		sort_base = make_entry_name_no_links(data.base.lang, data.base.term)
	end

	table.insert(parts_formatted, export.link_term(data.prefix, data))
	table.insert(parts_formatted, export.link_term(data.base, data))
	table.insert(parts_formatted, export.link_term(data.suffix, data))

	-- Insert the categories, but don't add a '*fixed with' category if the link term is in a different language.
	if not data.prefix.part_lang then
		table.insert(categories, {cat=data.pos .. " circumfixed with " .. make_entry_name_no_links(data.prefix.lang,
			circumfix), sort_key=data.sort_key, sort_base=sort_base})
	end

	return export.join_formatted_parts { data = data, parts_formatted = parts_formatted, categories = categories }
end


--[==[
Implementation of {{tl|confix}}.

'''WARNING''': This destructively modifies both `data` and `.prefix`, `.base` and `.suffix`.
]==]
function export.show_confix(data)
	data.pos = data.pos or default_pos
	data.pos = pluralize(data.pos)

	canonicalize_part(data.base, data.lang, data.sc)
	-- Hyphenate the affixes and apply any affix mappings.
	make_part_into_affix(data.prefix, data.lang, data.sc, "prefix")
	make_part_into_affix(data.suffix, data.lang, data.sc, "suffix")

	track_wrong_affix_type("confix", data.prefix, "prefix")
	track_wrong_affix_type("confix", data.base, nil)
	track_wrong_affix_type("confix", data.suffix, "suffix")

	-- Make links out of all the parts.
	local parts_formatted = {}
	local prefix_sort_base
	if data.base and data.base.term then
		prefix_sort_base = make_entry_name_no_links(data.base.lang, data.base.term)
	elseif data.suffix.term then
		prefix_sort_base = make_entry_name_no_links(data.suffix.lang, data.suffix.term)
	end

	-- Insert the categories and parts.
	local categories = {}

	table.insert(parts_formatted, export.link_term(data.prefix, data))
	insert_affix_category(categories, data.pos, "prefix", data.prefix, data.sort_key, prefix_sort_base)

	if data.base then
		table.insert(parts_formatted, export.link_term(data.base, data))
	end

	table.insert(parts_formatted, export.link_term(data.suffix, data))
	-- FIXME, should we be specifying a sort base here?
	insert_affix_category(categories, data.pos, "suffix", data.suffix)

	return export.join_formatted_parts { data = data, parts_formatted = parts_formatted, categories = categories }
end


--[==[
Implementation of {{tl|infix}}.

'''WARNING''': This destructively modifies both `data` and `.base` and `.infix`.
]==]
function export.show_infix(data)
	data.pos = data.pos or default_pos
	data.pos = pluralize(data.pos)

	canonicalize_part(data.base, data.lang, data.sc)
	-- Hyphenate the affixes and apply any affix mappings.
	make_part_into_affix(data.infix, data.lang, data.sc, "infix")

	track_wrong_affix_type("infix", data.base, nil)
	track_wrong_affix_type("infix", data.infix, "infix")

	-- Make links out of all the parts.
	local parts_formatted = {}
	local categories = {}

	table.insert(parts_formatted, export.link_term(data.base, data))
	table.insert(parts_formatted, export.link_term(data.infix, data))

	-- Insert the categories.
	-- FIXME, should we be specifying a sort base here?
	insert_affix_category(categories, data.pos, "infix", data.infix)

	return export.join_formatted_parts { data = data, parts_formatted = parts_formatted, categories = categories }
end


--[==[
Implementation of {{tl|prefix}}.

'''WARNING''': This destructively modifies both `data` and the structures within `.prefixes`, as well as `.base`.
]==]
function export.show_prefix(data)
	data.pos = data.pos or default_pos
	data.pos = pluralize(data.pos)

	canonicalize_part(data.base, data.lang, data.sc)
	-- Hyphenate the affixes and apply any affix mappings.
	for i, prefix in ipairs(data.prefixes) do
		make_part_into_affix(prefix, data.lang, data.sc, "prefix")
	end

	for i, prefix in ipairs(data.prefixes) do
		track_wrong_affix_type("prefix", prefix, "prefix")
	end

	track_wrong_affix_type("prefix", data.base, nil)

	-- Make links out of all the parts.
	local parts_formatted = {}
	local first_sort_base = nil
	local categories = {}

	if data.prefixes[2] then
		first_sort_base = ine(data.prefixes[2].term) or ine(data.prefixes[2].alt)
		if first_sort_base then
			first_sort_base = make_entry_name_no_links(data.prefixes[2].lang, first_sort_base)
		end
	elseif data.base then
		first_sort_base = ine(data.base.term) or ine(data.base.alt)
		if first_sort_base then
			first_sort_base = make_entry_name_no_links(data.base.lang, first_sort_base)
		end
	end

	for i, prefix in ipairs(data.prefixes) do
		table.insert(parts_formatted, export.link_term(prefix, data))
		insert_affix_category(categories, data.pos, "prefix", prefix, data.sort_key, i == 1 and first_sort_base or nil)
	end

	if data.base then
		table.insert(parts_formatted, export.link_term(data.base, data))
	else
		table.insert(parts_formatted, "")
	end

	return export.join_formatted_parts { data = data, parts_formatted = parts_formatted, categories = categories }
end


--[==[
Implementation of {{tl|suffix}}.

'''WARNING''': This destructively modifies both `data` and the structures within `.suffixes`, as well as `.base`.
]==]
function export.show_suffix(data)
	local categories = {}

	data.pos = data.pos or default_pos
	data.pos = pluralize(data.pos)

	canonicalize_part(data.base, data.lang, data.sc)
	-- Hyphenate the affixes and apply any affix mappings.
	for i, suffix in ipairs(data.suffixes) do
		make_part_into_affix(suffix, data.lang, data.sc, "suffix")
	end

	track_wrong_affix_type("suffix", data.base, nil)
	for i, suffix in ipairs(data.suffixes) do
		track_wrong_affix_type("suffix", suffix, "suffix")
	end

	-- Make links out of all the parts.
	local parts_formatted = {}

	if data.base then
		table.insert(parts_formatted, export.link_term(data.base, data))
	else
		table.insert(parts_formatted, "")
	end

	for i, suffix in ipairs(data.suffixes) do
		table.insert(parts_formatted, export.link_term(suffix, data))
	end

	-- Insert the categories.
	for i, suffix in ipairs(data.suffixes) do
		-- FIXME, should we be specifying a sort base here?
		insert_affix_category(categories, data.pos, "suffix", suffix)

		if suffix.pos and rfind(suffix.pos, "patronym") then
			table.insert(categories, "patronymics")
		end
	end

	return export.join_formatted_parts { data = data, parts_formatted = parts_formatted, categories = categories }
end

return export
