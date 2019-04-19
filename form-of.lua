local m_links = require("Module:links")
local m_table = require("Module:table")
local m_pos = mw.loadData("Module:form of/pos")
local m_data = mw.loadData("Module:form of/data")
local m_cats = mw.loadData("Module:form of/cats")
local m_functions = require("Module:form of/functions")

local rsubn = mw.ustring.gsub
local rmatch = mw.ustring.match
local rsplit = mw.text.split

local export = {}

-- version of rsubn() that discards all but the first return value
local function rsub(term, foo, bar)
	local retval = rsubn(term, foo, bar)
	return retval
end

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


-- Add tracking category for PAGE when called from {{inflection of}} or
-- similar TEMPLATE. The tracking category linked to is
-- [[Template:tracking/inflection of/PAGE]].
local function infl_track(page)
	require("Module:debug").track("inflection of/" ..
		-- avoid including links in pages (may cause error)
		page:gsub("%[", "("):gsub("%]", ")"):gsub("|", "!"))
end


-- Normalize a single tag, which should not be a list or multipart tag.
local function normalize_single_tag(tag, do_track)
	local normalized = m_data.shortcuts[tag] or tag
	if normalized ~= tag then
		tag = normalized
		if do_track then
			-- Track the expansion if it's not the same as the raw tag.
			infl_track("tag/" .. tag)
		end
	end
	if not m_data.tags[tag] and do_track then
		-- If after all expansions and normalizations we don't recognize
		-- the canonical tag, track it.
		infl_track("unknown")
		infl_track("unknown/" .. tag)
	end
	return tag
end


-- Normalize a single tag, which should not be a list tag but may be a
-- multipart tag. If RECOMBINE_TAGS isn't given, the return value may be a
-- list (in the case of multipart tags); otherwise, it will always be a
-- string, and multipart tags will be represented as canonical-form tags
-- joined by "//".
local function normalize_tag(tag, recombine_multitags, do_track)
	-- Check for a shortcut before splitting. (I think the only case this
	-- should apply to is when a list tag expands to a multipart tag.)
	local expanded_tag = m_data.shortcuts[tag] or tag
	if type(expanded_tag) ~= "string" then
		error("List tags should already have been expanded: " .. tag)
	end
	if expanded_tag ~= tag then
		tag = expanded_tag
		if do_track then
			-- Track the expansion if it's not the same as the raw tag.
			infl_track("tag/" .. tag)
		end
	end
	local split_tags = rsplit(tag, "//", true)
	if #split_tags == 1 then
		return normalize_single_tag(split_tags[1], do_track)
	end
	local normtags = {}
	for _, single_tag in ipairs(split_tags) do
		if do_track then
			-- If the tag was a multipart tag, track each of individual raw tags.
			infl_track("tag/" .. single_tag)
		end
		table.insert(normtags, normalize_single_tag(single_tag, do_track))
	end
	if recombine_multitags then
		return table.concat(normtags, "//")
	else
		return normtags
	end
end


-- Normalize a list of tags into a list of canonical-form tags (which
-- may be larger due to the possibility of list tags). If RECOMBINE_TAGS
-- isn't given, the return list may itself contains lists; in particular,
-- multipart tags will be represented as lists. If RECOMBINE_TAGS is given,
-- they will be represented as canonical-form tags joined by "//".
local function normalize_tags(tags, recombine_multitags, do_track)
	-- We track usage of shortcuts, normalized forms and (in the case of
	-- multipart tags or list tags) intermediate forms. For example,
	-- if the tags 1s|mn|gen|indefinite are passed in, we track the following:
	-- [[Template:tracking/inflection of/tag/1s]]
	-- [[Template:tracking/inflection of/tag/1]]
	-- [[Template:tracking/inflection of/tag/s]]
	-- [[Template:tracking/inflection of/tag/first-person]]
	-- [[Template:tracking/inflection of/tag/singular]]
	-- [[Template:tracking/inflection of/tag/mn]]
	-- [[Template:tracking/inflection of/tag/m//n]]
	-- [[Template:tracking/inflection of/tag/m]]
	-- [[Template:tracking/inflection of/tag/n]]
	-- [[Template:tracking/inflection of/tag/masculine]]
	-- [[Template:tracking/inflection of/tag/neuter]]
	-- [[Template:tracking/inflection of/tag/gen]]
	-- [[Template:tracking/inflection of/tag/genitive]]
	-- [[Template:tracking/inflection of/tag/indefinite]]
	local ntags = {}
	for _, tag in ipairs(tags) do
		if do_track then
			-- Track the raw tag.
			infl_track("tag/" .. tag)
		end
		-- Expand the tag, which may generate a new tag (either a
		-- fully canonicalized tag, a multipart tag, or a list of tags).
		local expanded_tag = m_data.shortcuts[tag] or tag
		if expanded_tag ~= tag then
			tag = expanded_tag
			-- Track the expansion if it's not the same as the raw tag.
			if do_track and type(tag) == "string" then
				infl_track("tag/" .. tag)
			end
		end
		if type(tag) == "table" then
			for _, t in ipairs(tag) do
				if do_track then
					-- If the tag expands to a list of raw tags, track each of
					-- those.
					infl_track("tag/" .. t)
				end
				table.insert(ntags, normalize_tag(t, recombine_multitags,
					do_track))
			end
		else
			table.insert(ntags, normalize_tag(tag, recombine_multitags,
				do_track))
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
		if data.glossary_type == "wikt" then
			normtag = "[[" .. data.glossary .. "|" .. normtag .. "]]"
		elseif data.glossary_type == "wp" then
			normtag = "[[w:" .. data.glossary .. "|" .. normtag .. "]]"
		else
			normtag = "[[Appendix:Glossary#" .. mw.uri.anchorEncode(data.glossary) .. "|" .. normtag .. "]]"
		end
	end
	return normtag
end


local function get_tag_display_form(normtag)
	if type(normtag) == "string" then
		return get_single_tag_display_form(normtag)
	end
	-- We have multiple tags. See if there's a display handler to
	-- display them specially.
	for _, handler in ipairs(m_functions.display_handlers) do
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
	end

	local function check_condition(spec)
		if type(spec) == "boolean" then
			return spec
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
		elseif predicate == "tags=" then
			local normalized_spec_tags = normalize_tags(spec[2],
				"recombine multitags")
			return m_table.deepEqualsList(normalized_tags, normalized_spec_tags), 3
		elseif predicate == "p=" then
			return POS == normalize_pos(spec[2]), 3
		elseif predicate == "pany" then
			for _, specpos in ipairs(spec[2]) do
				if POS == normalize_pos(specpos) then
					return true, 3
				end
			end
			return false, 3
		elseif predicate == "pexists" then
			return POS ~= nil, 2
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
		elseif predication == "call" then
			local fn = m_functions.cat_functions[spec[2]]
			if not fn then
				error("No condition function named '" .. spec[2] .. "'")
			end
			return fn(make_function_table()), 3
		else
			error("Unrecognized predicate: " .. predicate)
		end
	end

	local function process_spec(spec)
		if not spec then
			return false
		elseif type(spec) == "string" then
			-- Substitute POS request with user-specified part of speech
			-- or default
			spec = rsub(spec, "<<p=(.-)>>", function(default)
				return POS or normalize_pos(default)
			end)
			table.insert(categories, lang:getCanonicalName() .. " " .. spec)
			return true
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
		elseif predicate == "call" then
			local fn = m_functions.cat_functions[spec[2]]
			if not fn then
				error("No spec function named '" .. spec[2] .. "'")
			end
			return process_spec(fn(make_function_table()))
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
	end
	if lang:getCode() ~= "und" then
		local langspecs = m_cats["und"]
		if langspecs then
			for _, spec in ipairs(langspecs) do
				process_spec(spec)
			end
		end
	end
	return categories
end


function export.tagged_inflections(tags, terminfo, notext, capfirst, posttext)
	local cur_infl = {}
	local inflections = {}

	local ntags = normalize_tags(tags, nil, "do-track")

	for i, tagspec in ipairs(ntags) do
		if tagspec == ";" then
			if #cur_infl > 0 then
				table.insert(inflections, table.concat(cur_infl))
			end

			cur_infl = {}
		else
			local to_insert = get_tag_display_form(tagspec)
			-- Maybe insert a space before inserting the display form
			-- of the tag. We insert a space if
			-- (a) we're not the first tag; and
			-- (b) the tag we're about to insert doesn't have the
			--     "no_space_on_left" property; and
			-- (c) the preceding tag doesn't have the "no_space_on_right"
			--     property.
			-- NOTE: We depend here on the fact that all tags with either
			-- of the above proprties set have the same display form as
			-- canonical form. This is currently the case, but might not
			-- be in the future; if so, we need to track the canonical
			-- form of each tag (including the previous one) as well as
			-- the display form.
			if (#cur_infl > 0 and
				(not m_data.tags[cur_infl[#cur_infl]] or
				 not m_data.tags[cur_infl[#cur_infl]].no_space_on_right) and
				(not m_data.tags[to_insert] or
				 not m_data.tags[to_insert].no_space_on_left)) then
				table.insert(cur_infl, " ")
			end
			table.insert(cur_infl, to_insert)
		end
	end

	if #cur_infl > 0 then
		table.insert(inflections, table.concat(cur_infl))
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
