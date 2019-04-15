local m_links = require("Module:links")
local m_table = require("Module:table")
local m_pos = mw.loadData("Module:form of/pos")
local m_data = mw.loadData("Module:form of/data")
local m_cats = mw.loadData("Module:form of/cats")

local rmatch = mw.ustring.match
local rsplit = mw.text.split

local export = {}

-- FIXME! Move to a utility module.

function export.ucfirst(text)
	local function doucfirst(text)
		-- Actual function to uppercase first letter.
		return mw.ustring.upper(mw.ustring.sub(text, 1, 1)) .. mw.ustring.sub(text, 2)
	end
	-- If there's a link at the beginning, uppercase the first letter of the
	-- link text. This pattern matches both piped and unpiped links.
	-- If the link is not piped, the second capture (linktext) will be empty.
	local link, linktext, remainder = rmatch(text, "^%[%[([^|%]]+)%|?(.-)%]%](.*)$")
	if link then
		return "[[" .. link .. "|" .. doucfirst(linktext ~= "" and linktext or link) .. "]]" .. remainder
	end
	return doucfirst(text)
end


function export.format_form_of(text, terminfo, posttext)
	local parts = {}
	table.insert(parts, "<span class='form-of-definition use-with-mention'>")
	table.insert(parts, text)
	if text ~= "" and terminfo then
		table.insert(parts, " ")
	end
	if terminfo then
		table.insert(parts, "<span class='form-of-definition-link'>")
		if type(terminfo) == "string" then
			table.insert(parts, terminfo)
		else
			table.insert(parts, m_links.full_link(terminfo, "term", false))
		end
		table.insert(parts, "</span>")
	end
	if posttext then
		table.insert(parts, posttext)
	end
	table.insert(parts, "</span>")
	return table.concat(parts)
end


local function normalize_single_tag(tag)
	if m_data.shortcuts[tag] then
	elseif m_data.tags[tag] then
	else
		require("Module:debug").track{
			"inflection of/unknown",
			"inflection of/unknown/" .. tag:gsub("%[", "("):gsub("%]", ")"):gsub("|", "!")
		}
	end

	return m_data.shortcuts[tag] or tag
end


local function normalize_tag(tag, recombine_multitags)
	-- Check for a shortcut before splitting because some shortcuts map to
	-- multiple //-separated tags, e.g. 123 -> 1//2//3.
	tag = m_data.shortcuts[tag] or tag
	local split_tags = rsplit(tag, "//", true)
	if #split_tags == 1 then
		return normalize_single_tag(split_tags[1])
	end
	local normtags = {}
	for _, single_tag in ipairs(split_tags) do
		table.insert(normtags, normalize_single_tag(single_tag))
	end
	if recombine_multitags then
		return table.concat(normtags, "//")
	else
		return normtags
	end
end


local function normalize_tags(tags, recombine_multitags)
	local ntags = {}
	for _, tag in ipairs(tags) do
		tag = m_data.shortcuts[tag] or tag
		if type(tag) == "table" then
			for _, t in ipairs(tag) do
				table.insert(ntags, normalize_tag(t, recombine_multitags))
			end
		else
			table.insert(ntags, normalize_tag(tag, recombine_multitags))
		end
	end
	return ntags
end


local function normalize_pos(pos)
	return m_pos[pos] or pos
end


local function get_single_tag_display_form(normtag)
	local data = m_data.tags[normtag]

	-- If the tag has a special display form, use it
	if data and data.display then
		normtag = data.display
	end

	-- If there is a nonempty glossary index, then show a link to it
	if data and data.glossary then
		normtag = "[[Appendix:Glossary#" .. mw.uri.anchorEncode(data.glossary) .. "|" .. tag .. "]]"
	end
	return normtag
end


local function get_tag_display_form(normtag)
	if type(normtag) == "string" then
		return get_single_tag_display_form(normtag)
	end
	-- We have multiple tags. See if there's a display handler to
	-- display them specially.
	for _, handler in ipairs(m_data.display_handlers) do
		local displayval = handler(normtag)
		if displayval then
			return displayval
		end
	end
	-- If not, just join them using serialCommaJoin.
	local displayed_tags = {}
	for _, tag in ipairs(normtag) do
		table.insert(displayed_tags, get_single_tag_display_form(tag))
	end
	return m_table.serialCommaJoin(displayed_tags)
end


function export.fetch_lang_categories(lang, tags, terminfo, POS)
	local categories = {}

	local normalized_tags = normalize_tags(tags, "recombine multitags")
	POS = normalize_pos(POS)

	local function make_function_table()
		return {
			lang=lang,
			tags=normalized_tags,
			term=term,
			p=POS
		}

	local function check_condition(spec)
		if type(spec) == "boolean" then
			return spec
		elseif type(spec) == "function" then
			return spec(make_function_table())
		elseif type(spec) ~= "table" then
			error("Wrong type of condition " .. spec .. ": " .. type(spec))
		end
		local predicate = spec[1]
		if predicate == "has" then
			return m_table.contains(normalized_tags, normalize_tag(spec[2])), 3
		elseif predicate == "hasall" then
			for _, tag in ipairs(spec[2]) do
				if not m_table.contains(normalized_tags, normalize_tag(tag)) then
					return false, 3
				end
			end
			return true, 3
		elseif predicate == "hasany" then
			for _, tag in ipairs(spec[2]) do
				if m_table.contains(normalized_tags, normalize_tag(tag)) then
					return true, 3
				end
			end
			return false, 3
		elseif predicate == "POS=" then
			return POS == normalize_pos(spec[2]), 3
		elseif predicate == "POSany" then
			for _, specpos in ipairs(spec[2]) do
				if POS == normalize_pos(specpos) then
					return true, 3
				end
			end
			return false, 3
		elseif predicate == "not" then
			local condval = check_condition(spec[2])
			return not condval, 3
		elseif predicate == "and" then
			local condval = check_condition(spec[2])
			if condval then
				condval = check_condition(spec[3])
			end
			return condval, 4
		elseif predicate == "or" then
			local condval = check_condition(spec[2])
			if not condval then
				condval = check_condition(spec[3])
			end
			return condval, 4
		else
			error("Unrecognized predicate: " .. predicate)
		end
	end

	local function process_spec(spec)
		if not spec then
			return false
		elseif type(spec) == "string" then
			table.insert(categories, lang:getCanonicalName() .. " " .. spec)
			return true
		elseif type(spec) == "function" then
			return process_spec(spec(make_function_table()))
		elseif type(spec) ~= "table" then
			error("Wrong type of specification " .. spec .. ": " .. type(spec))
		end
		local predicate = spec[1]
		if predicate == "multi" then
			-- WARNING! #spec doesn't work for objects loaded from loadData()
			for i, sp in ipairs(spec) do
				if i > 1 then
					process_spec(sp)
				end
			end
			return true
		elseif predicate == "cond" then
			-- WARNING! #spec doesn't work for objects loaded from loadData()
			for i, sp in ipairs(spec) do
				if i > 1 and process_spec(sp) then
					return true
				end
			end
			return false
		else
			local condval, ifspec = check_condition(spec)
			if condval then
				process_spec(spec[ifspec])
				return true
			else
				process_spec(spec[ifspec + 1])
				return false
			end
		end
	end

	local langspecs = m_cats[lang:getCode()]
	if langspecs then
	for _, spec in ipairs(langspecs) do
		process_spec(spec)
	end
	return categories
end


function export.tagged_inflections(tags, terminfo, notext, capfirst, posttext)
	local cur_infl = {}
	local inflections = {}

	local ntags = normalize_tags(tags)

	for i, tagspec in ipairs(ntags) do
		if tagspec == ";" then
			if #cur_infl > 0 then
				table.insert(inflections, table.concat(cur_infl, " "))
			end

			cur_infl = {}
		else
			local to_insert = get_tag_display_form(tagspec)
			-- Here we special-case various sorts of punctuation.
			-- No space to the right of a comma, rparen or slash;
			-- no space to the left of an lparen or slash.
			-- FIXME: Make this into a property of the data entry.
			if (#cur_infl > 0 and cur_infl[#cur_infl] ~= "(" and
				cur_infl[#cur_infl] ~= "/" and to_insert ~= "," and
				to_insert ~= ")" and to_insert ~= "/") then
				table.insert(cur_infl, " ")
			end
			table.insert(cur_infl, to_insert)
		end
	end

	if #cur_infl > 0 then
		table.insert(inflections, table.concat(cur_infl, " "))
	end

	if #inflections == 1 then
		return export.format_form_of(
			notext and "" or ((capfirst and export.ucfirst(inflections[1]) or inflections[1]) ..
				(terminfo and " of" or "")),
			terminfo, posttext
		)
	else
		local link = export.format_form_of(
			notext and "" or ((capfirst and "Inflection" or "inflection") ..
				(terminfo and " of" or "")),
			terminfo, (posttext or "") .. ":"
		)
		return link .."\n## <span class='form-of-definition use-with-mention'>" .. table.concat(inflections, "</span>\n## <span class='form-of-definition use-with-mention'>") .. "</span>"
	end
end

function export.to_Wikidata_IDs(tags, skip_tags_without_ids)
	if type(tags) == "string" then
		tags = mw.text.split(tags, "|", true)
	end

	local ret = {}

	local function get_wikidata_id(tag)
		if tag == ";" and not skip_tags_without_ids then
			error("Semicolon is not supported for Wikidata IDs")
		else
			return nil
		end

		local data = m_data.tags[tag]

		if not data or not data.wikidata then
			if not skip_tags_without_ids then
				error("The tag \"" .. tag .. "\" does not have a Wikidata ID defined in [[Module:form of/data]]")
			else
				return nil
			end
		else
			return data.wikidata
		end
	end

	for i, tag in ipairs(normalize_tags(tags)) do
		if type(tag) == "table" then
			local ids = {}
			for _, onetag in ipairs(tag) do
				table.insert(ids, get_wikidata_id(onetag))
			end
			table.insert(ret, ids)
		else
			table.insert(ret, get_wikidata_id(tag))
		end
	end

	return ret
end


return export

-- For Vim, so we get 4-space tabs
-- vim: set ts=4 sw=4 noet:
