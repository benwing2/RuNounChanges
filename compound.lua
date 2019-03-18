local m_links = require("Module:links")
local m_utilities = require("Module:utilities")

local export = {}

local rsub = mw.ustring.gsub
local usub = mw.ustring.sub
local ulen = mw.ustring.len
local rfind = mw.ustring.find
local rmatch = mw.ustring.match

-- FIXME: should be script-based
-- But we can't do that unless we do script detection before linking.
local hyphens = {
	["ar"] = "ـ",
	["fa"] = "ـ",
	["he"] = "־",
	["yi"] = "־",
}

local no_displayed_hyphens = {
	["ja"] = true,
	["ko"] = true,
	["lo"] = true,
	["th"] = true,
	["zh"] = true,
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

local function link_term(terminfo, display_term, lang, sc, sort_key)
	local terminfo_new = require("Module:table").shallowcopy(terminfo)
	local result

	terminfo_new.term = display_term	
	if terminfo_new.lang then
		result = require("Module:etymology").format_borrowed(lang, terminfo_new, sort_key, false, true, "plain")
	else
		terminfo_new.lang = lang
		terminfo_new.sc = terminfo_new.sc or sc
		result = m_links.full_link(terminfo_new, "term", false)
	end
	
	if terminfo_new.q then
		result = result .. " " .. require("Module:qualifier").format_qualifier(terminfo_new.q)
	end
	
	return result
end

-- ABOUT TEMPLATE AND DISPLAY HYPHENS:
--
-- The "template hyphen" is the hyphen character (always a single Unicode char)
-- that is used in template calls to indicate that a term is an affix.
-- Normally this is just the regular hyphen character "-", but for some
-- non-Latin-script languages (currently only right-to-left languages), it
-- is different.
--
-- The "display hyphen" is the string (which might be an empty string) that
-- is added onto a term as displayed (and linked), to indicate that a term
-- is an affix. It is different for East Asian languages, which use a regular
-- hyphen in calls to {{affix}} and such to indicate an affix, but which
-- don't include any visible hyphen in the displayed and linked terms.
-- Currently this is the only situation where template and display hyphens
-- are different, but the code below is written generally enough to handle
-- arbitrary display hyphens.

-- Get the single character that signals an affix in template params.
local function get_template_hyphen(lang, sc)
	--The script will be "Latn" for transliterations.
	if sc and sc:getCode() == "Latn" then
		return "-"
	else
		return hyphens[lang:getCode()] or "-"
	end
end

-- Get the string (possibly empty) that signals an affix in displayed
-- and linked terms. This differs from get_template_hyphen() in various
-- East Asian languages, where the parameters to {{affix}} will still
-- contain a hyphen to signal an affix, but the affix will be displayed
-- and linked without such a hyphen.
local function get_display_hyphen(lang, sc)
	--The script will be "Latn" for transliterations.
	if sc and sc:getCode() == "Latn" then
		return "-"
	end
	local langcode = lang:getCode()
	if no_displayed_hyphens[langcode] then
		return ""
	else
		return hyphens[langcode] or "-"
	end
end

-- Find the type of affix ("prefix", "infix", "suffix", "circumfix" or nil
-- for non-affix). Return the affix type and the displayed/linked equivalent
-- of the part (normally the same as the part but will be different for some
-- East Asian languages that use a regular hyphen as an affix-signaling
-- hyphen but have no displayed hyphen).
local function get_affix_type(lang, sc, part)
	if not part then
		return nil, nil
	end
	
	local thyph = get_template_hyphen(lang, sc)
	local dhyph = get_display_hyphen(lang, sc)
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

	local begins_with_hyphen = usub(part, 1, 1) == thyph
	local ends_with_hyphen = usub(part, -1) == thyph
	if rfind(part, hyphen_space_hyphen, 1, true) then
		affix_type = "circumfix"
	elseif begins_with_hyphen and ends_with_hyphen then
		affix_type = "infix"
		-- Don't do anything if the part is a single hyphen.
		-- This is probably correct.
		if thyph ~= dhyph and ulen(part) > 1 then
			part = dhyph .. rsub(part, "^.(.-).$", "%1") .. dhyph
		end
	elseif ends_with_hyphen then
		affix_type = "prefix"
		if thyph ~= dhyph then
			part = rsub(part, "^(.-).$", "%1") .. dhyph
		end
	elseif begins_with_hyphen then
		affix_type = "suffix"
		if thyph ~= dhyph then
			part = dhyph .. usub(part, 2)
		end
	end

	part = reconstructed .. part
	return affix_type, part
end


-- Iterate an array up to the greatest integer index found.
local function ipairs_with_gaps(t)
	local max_index = math.max(unpack(require("Module:table").numKeys(t)))
	local i = 0
	return function()
		while i < max_index do
			i = i + 1
			return i, t[i]
		end
	end
end

export.ipairs_with_gaps = ipairs_with_gaps


function export.show_affixes(lang, sc, parts, pos, sort_key, nocat)
	pos = pos or "word"
	
	pos = pluralize(pos)
	
	-- Process each part
	local parts_formatted = {}
	local categories_formatted = {}
	local whole_words = 0
	
	for i, part in ipairs_with_gaps(parts) do
		part = part or {}
		local part_lang = part.lang or lang
		local part_sc = part.sc or sc
		
		-- Is it an affix, and if so, what type of affix?
		local affix_type, display_term = get_affix_type(part_lang, part_sc, part.term)
		
		-- Make a link for the part
		table.insert(parts_formatted, link_term(part, display_term, lang, sc, sort_key))
		
		if affix_type then
			-- Make a sort key
			-- For the first part, use the second part as the sort key
			local part_sort_base = nil
			local part_sort = part.sort or sort_key
			
			if i == 1 and parts[2] and parts[2].term then
				local part2_lang = parts[2].lang or lang
				local part2_sc = parts[2].sc or sc
				local part2_affix_type, part2_display_term = get_affix_type(part2_lang, part2_sc, parts[2].term)
				part_sort_base = part2_lang:makeEntryName(part2_display_term)
			end
			
			if affix_type == "infix" then affix_type = "interfix" end
			
			if part.pos and rmatch(part.pos, "patronym") then
				table.insert(categories_formatted, m_utilities.format_categories({lang:getCanonicalName() .. " patronymics"}, lang, part_sort, part_sort_base))
			end
			
			if pos ~= "words" and part.pos and rmatch(part.pos, "diminutive") then
				table.insert(categories_formatted, m_utilities.format_categories({lang:getCanonicalName() .. " diminutive " .. pos}, lang, part_sort, part_sort_base))
			end
			
			table.insert(categories_formatted, m_utilities.format_categories({lang:getCanonicalName() .. " " .. pos .. " " .. affix_type .. "ed with " .. part_lang:makeEntryName(display_term) .. (part.id and " (" .. part.id .. ")" or "")}, lang, part_sort, part_sort_base))
		else
			whole_words = whole_words + 1
			
			if whole_words == 2 then
				table.insert(categories_formatted, m_utilities.format_categories({lang:getCanonicalName() .. " compound " .. pos}, lang, sort_key))
			end
		end
	end
	
	-- If there are no categories, then there were no actual affixes, only regular words.
	-- This function does not support compounds (yet?), so show an error.
	if #categories_formatted == 0 then
		error("The parameters did not include any affixes, and the word is not a compound. Please provide at least one affix.")
	end
	
	return table.concat(parts_formatted, " +&lrm; ") .. (nocat and "" or table.concat(categories_formatted))
end


function export.show_compound(lang, sc, parts, pos, sort_key, nocat)
	pos = pos or "words"
	local parts_formatted = {}
	local categories_formatted = {}
	table.insert(categories_formatted, m_utilities.format_categories({lang:getCanonicalName() .. " compound words"}, lang, sort_key))
	
	-- Make links out of all the parts
	local whole_words = 0
	for i, part in ipairs(parts) do
		local part_lang = part.lang or lang
		local part_sc = part.sc or sc
		local affix_type, display_term = get_affix_type(part_lang, part_sc, part.term)

		-- If the word is an infix, recognize it as such (which means
		-- e.g. that we will display the word without hyphens for
		-- East Asian languages). Otherwise, ignore the fact that it
		-- looks like an affix and display as specified in the template
		-- (but pay attention to the detected affix type for certain
		-- tracking purposes)
		if affix_type == "infix" then
			table.insert(categories_formatted, m_utilities.format_categories({lang:getCanonicalName() .. " " .. pos .. " interfixed with " .. part_lang:makeEntryName(display_term)}, lang, part.sort or sort_key))
		else
			display_term = part.term
			if affix_type then
				require("Module:debug").track{
					"compound",
					"compound/" .. affix_type,
					"compound/" .. affix_type .. "/lang/" .. lang:getCode()
				}
			else
				whole_words = whole_words + 1
			end
		end
		table.insert(parts_formatted, link_term(part, display_term, lang, sc, sort_key))
	end

	if whole_words == 1 then
		require("Module:debug").track("compound/one whole word")
	elseif whole_words == 0 then
		require("Module:debug").track("compound/looks like confix")
	end
	
	return table.concat(parts_formatted, " +&lrm; ") .. (nocat and "" or table.concat(categories_formatted))
end


function export.show_compound_like(lang, sc, parts, sort_key, text, oftext, cat)
	local parts_formatted = {}
	local categories_formatted = {}

	if cat then	
		table.insert(categories_formatted, m_utilities.format_categories({lang:getCanonicalName() .. " " .. cat}, lang, sort_key))
	end
	
	-- Make links out of all the parts
	for i, part in ipairs(parts) do
		table.insert(parts_formatted, link_term(part, part.term, lang, sc, sort_key))
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
	table.insert(text_sections, table.concat(parts_formatted, " +&lrm; "))
	table.insert(text_sections, table.concat(categories_formatted, ""))
	return table.concat(text_sections, "")
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
	part.tr = export.make_affix(part.tr, part_lang, require("Module:scripts").getByCode("Latn"), affix_type)
	part.ts = export.make_affix(part.ts, part_lang, require("Module:scripts").getByCode("Latn"), affix_type)
end


local function track_wrong_affix_type(template, part, lang, sc, expected_affix_type, part_name)
	local affix_type = get_affix_type(part.lang or lang, part.sc or sc, part.term)
	if affix_type ~= expected_affix_type then
		require("Module:debug").track{
			template,
			template .. "/" .. part_name,
			template .. "/" .. part_name .. "/" .. (affix_type or "none"),
			template .. "/" .. part_name .. "/" .. (affix_type or "none") .. "/lang/" .. lang:getCode()
		}
	end
end


local function insert_affix_category(categories, lang, pos, affix_type, part)
	if part.term then
		local part_lang = part.lang or lang
		table.insert(categories, lang:getCanonicalName() .. " " .. pos .. " " .. affix_type .. "ed with " .. part_lang:makeEntryName(part.term) .. (part.id and " (" .. part.id .. ")" or ""))
	end
end


function export.show_circumfix(lang, sc, prefix, base, suffix, pos, sort_key, nocat)
	local categories = {}
	pos = pos or "word"
	
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
	local sort_base = (base.lang or lang):makeEntryName(base.term)
	
	table.insert(parts_formatted, link_term(prefix, prefix.term, lang, sc, sort_key))
	table.insert(parts_formatted, link_term(base, base.term, lang, sc, sort_key))
	table.insert(parts_formatted, link_term(suffix, suffix.term, lang, sc, sort_key))
	
	-- Insert the categories
	table.insert(categories, lang:getCanonicalName() .. " " .. pos .. " circumfixed with " .. (prefix.lang or lang):makeEntryName(circumfix))
	
	return table.concat(parts_formatted, " +&lrm; ") .. (nocat and "" or m_utilities.format_categories(categories, lang, sort_key, sort_base))
end


function export.show_confix(lang, sc, prefix, base, suffix, pos, sort_key, nocat)
	pos = pos or "word"
	
	pos = pluralize(pos)
	
	-- Hyphenate the affixes
	make_part_affix(prefix, lang, sc, "prefix")
	make_part_affix(suffix, lang, sc, "suffix")
	
	track_wrong_affix_type("confix", prefix, lang, sc, "prefix", "prefix")
	track_wrong_affix_type("confix", base, lang, sc, nil, "base")
	track_wrong_affix_type("confix", suffix, lang, sc, "suffix", "suffix")
	
	-- Make links out of all the parts
	local parts_formatted = {}
	local prefix_sort_base = (suffix.lang or lang):makeEntryName(suffix.term)
	local prefix_categories = {}
	local suffix_categories = {}
	
	table.insert(parts_formatted, link_term(prefix, prefix.term, lang, sc, sort_key))
	insert_affix_category(categories, lang, pos, "prefix", prefix)
	
	if base then
		prefix_sort_base = (base.lang or lang):makeEntryName(base.term)
		table.insert(parts_formatted, link_term(base, base.term, lang, sc, sort_key))
	end
	
	table.insert(parts_formatted, link_term(suffix, suffix.term, lang, sc, sort_key))
	insert_affix_category(categories, lang, pos, "suffix", suffix)
	
	return table.concat(parts_formatted, " +&lrm; ") .. (nocat and "" or m_utilities.format_categories(prefix_categories, lang, sort_key, prefix_sort_base) .. m_utilities.format_categories(suffix_categories, lang, sort_key))
end


function export.show_infix(lang, sc, base, infix, pos, sort_key, nocat)
	local categories = {}
	pos = pos or "word"
	
	pos = pluralize(pos)
	
	-- Hyphenate the affixes
	make_part_affix(infix, lang, sc, "infix")
	
	track_wrong_affix_type("infix", base, lang, sc, nil, "base")
	track_wrong_affix_type("infix", infix, lang, sc, "infix", "infix")
	
	-- Make links out of all the parts
	local parts_formatted = {}
	
	table.insert(parts_formatted, link_term(base, base.term, lang, sc, sort_key))
	table.insert(parts_formatted, link_term(infix, infix.term, lang, sc, sort_key))
	
	-- Insert the categories
	insert_affix_category(categories, lang, pos, "infix", infix)
	
	return table.concat(parts_formatted, " +&lrm; ") .. (nocat and "" or m_utilities.format_categories(categories, lang, sort_key))
end


function export.show_prefixes(lang, sc, prefixes, base, pos, sort_key, nocat)
	pos = pos or "word"
	
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
	
	for i, prefix in ipairs(prefixes) do
		table.insert(parts_formatted, link_term(prefix, prefix.term, lang, sc, sort_key))
		insert_affix_category(categories, lang, pos, "prefix", prefix)
		
		if i > 1 and first_sort_base == nil then
			first_sort_base = (prefix.lang or lang):makeEntryName(prefix.term)
		end
	end
	
	if base then
		if first_sort_base == nil then
			first_sort_base = (base.lang or lang):makeEntryName(base.term)
		end
		
		table.insert(parts_formatted, link_term(base, base.term, lang, sc, sort_key))
	else
		table.insert(parts_formatted, "")
	end
	
	local first_category = table.remove(categories, 1)
	return table.concat(parts_formatted, " +&lrm; ") .. (nocat and "" or m_utilities.format_categories({first_category}, lang, sort_key, first_sort_base) .. m_utilities.format_categories(categories, lang, sort_key))
end


function export.show_suffixes(lang, sc, base, suffixes, pos, sort_key, nocat)
	local categories = {}
	pos = pos or "word"
	
	pos = pluralize(pos)
	
	-- Hyphenate the affixes
	for i, suffix in ipairs(suffixes) do
		make_part_affix(suffix, lang, sc, "suffix")
	end
	
	if base then
		track_wrong_affix_type("suffix", base, lang, sc, nil, "base")
	end
	
	for i, suffix in ipairs(suffixes) do
		track_wrong_affix_type("suffix", suffix, lang, sc, "suffix", "suffix")
	end
	
	-- Make links out of all the parts
	local parts_formatted = {}
	
	if base then
		table.insert(parts_formatted, link_term(base, base.term, lang, sc, sort_key))
	else
		table.insert(parts_formatted, "")
	end
	
	for i, suffix in ipairs(suffixes) do
		table.insert(parts_formatted, link_term(suffix, suffix.term, lang, sc, sort_key))
	end
	
	-- Insert the categories
	for i, suffix in ipairs(suffixes) do
		if suffix.term then
			insert_affix_category(categories, lang, pos, "suffix", suffix)
		end
		
		if suffix.pos and rmatch(suffix.pos, "patronym") then
			table.insert(categories, lang:getCanonicalName() .. " patronymics")
		end
	end
	
	return table.concat(parts_formatted, " +&lrm; ") .. (nocat and "" or m_utilities.format_categories(categories, lang, sort_key))
end


function export.show_transfix(lang, sc, base, transfix, pos, sort_key, nocat)
	local categories = {}
	pos = pos or "word"
	
	pos = pluralize(pos)
	
	-- Hyphenate the affixes
	make_part_affix(transfix, lang, sc, "transfix")
	
	-- Make links out of all the parts
	local parts_formatted = {}
	
	table.insert(parts_formatted, link_term(base, base.term, lang, sc, sort_key))
	table.insert(parts_formatted, link_term(transfix, transfix.term, lang, sc, sort_key))
	
	-- Insert the categories
	insert_affix_category(categories, lang, pos, "transfix", transfix)
	
	return table.concat(parts_formatted, " +&lrm; ") .. (nocat and "" or m_utilities.format_categories(categories, lang, sort_key))
end


-- Add a hyphen to a word in the appropriate place, based on the specified
-- affix type. For example, if `affix_type` == "prefix", we'll add a hyphen
-- onto the end if it's not already there. In general, if the template and
-- display hyphens are the same and the appropriate hyphen is already
-- present, we leave it, else we strip off the template hyphen if present
-- and add the display hyphen.
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
	
	local thyph = get_template_hyphen(lang, sc)
	local dhyph = get_display_hyphen(lang, sc)
	
	-- Remove an asterisk if the morpheme is reconstructed and add it in the end.
	local reconstructed = ""
	if term:find("^%*") then 
		reconstructed = "*"
		term = term:gsub("^%*", "")
	end
	
	local begins_with_hyphen = usub(term, 1, 1) == thyph
	local ends_with_hyphen = usub(term, -1) == thyph

	if affix_type == "suffix" then
		if thyph == dhyph and begins_with_hyphen then
			-- leave term alone
		else
			local term_no_hyphen = begins_with_hyphen and usub(term, 2) or term
			term = dhyph .. term_no_hyphen
		end
	elseif affix_type == "prefix" then
		if thyph == dhyph and ends_with_hyphen then
			-- leave term alone
		else
			local term_no_hyphen = ends_with_hyphen and rsub(term, "^(.-).$", "%1") or term
			term = term_no_hyphen .. dhyph
		end
	elseif affix_type == "infix" then
		if thyph == dhyph and begins_with_hyphen and ends_with_hyphen then
			-- leave term alone
		elseif term == thyph then
			-- term is a single hyphen; should probably leave alone
		else
			local term_no_hyphen = begins_with_hyphen and usub(term, 2) or term
			term_no_hyphen = ends_with_hyphen and rsub(term_no_hyphen, "^(.-).$", "%1") or term_no_hyphen
			term = dhyph .. term_no_hyphen .. dhyph
		end
	else
		error("Internal error: Bad affix type " .. affix_type)
	end
	
	return reconstructed .. term
end

return export

-- For Vim, so we get 4-space tabs
-- vim: set ts=4 sw=4 noet:
