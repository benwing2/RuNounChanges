local m_links = require("Module:links")
local m_table = require("Module:table")
local m_data = mw.loadData("Module:form of/data")

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
	-- link text. First handle two-part link, then one-part link.
	local link, linktext, remainder = rmatch(text, "^%[%[(.-)|(.-)%]%](.*)$")
	if link then
		return "[[" .. link .. "|" .. doucfirst(linktext) .. "]]" .. remainder
	end
	local linktext, remainder = rmatch(text, "^%[%[(.-)%]%](.*)$")
	if linktext then
		return "[[" .. linktext .. "|" .. doucfirst(linktext) .. "]]" .. remainder
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


local function normalize_tag(tag)
	if m_data.shortcuts[tag] then
	elseif m_data.tags[tag] then
	else
		require("Module:debug").track{
			"inflection of/unknown",
			"inflection of/unknown/" .. tag:gsub("%[", "("):gsub("%]", ")"):gsub("|", "!")
		}
	end

	tag = m_data.shortcuts[tag] or tag
	local data = m_data.tags[tag]

	-- If the tag has a special display form, use it
	if data and data.display then
		tag = data.display
	end

	-- If there is a nonempty glossary index, then show a link to it
	if data and data.glossary then
		tag = "[[Appendix:Glossary#" .. mw.uri.anchorEncode(data.glossary) .. "|" .. tag .. "]]"
	end
	return tag
end

function export.tagged_inflections(tags, terminfo, capfirst, posttext)
	local cur_infl = {}
	local inflections = {}
	
	for i, tagspec in ipairs(tags) do
		if tagspec == ";" then
			if #cur_infl > 0 then
				table.insert(inflections, table.concat(cur_infl, " "))
			end
			
			cur_infl = {}
		else
			local split_tags = rsplit(tagspec, "/", true)
			if #split_tags == 1 then
				table.insert(cur_infl, normalize_tag(split_tags[1]))
			else
				local normalized_tags = {}
				for _, tag in ipairs(split_tags) do
					table.insert(normalized_tags, normalize_tag(tag))
				end
				table.insert(cur_infl, m_table.serialCommaJoin(normalized_tags))
			end
		end
	end
	
	if #cur_infl > 0 then
		table.insert(inflections, table.concat(cur_infl, " "))
	end
	
	if #inflections == 1 then
		return export.format_form_of(
			(capfirst and export.ucfirst(inflections[1]) or inflections[1]) ..
			(terminfo and " of" or ""),
			terminfo, posttext
		)
	else
		local link = export.format_form_of(
			(capfirst and "Inflection" or "inflection") ..
			(terminfo and " of" or ""),
			terminfo, (posttext or "") .. ":"
		)
		return link .."\n## <span class='form-of-definition use-with-mention'>" .. table.concat(inflections, "</span>\n## <span class='form-of-definition use-with-mention'>") .. "</span>"
	end
end

function export.to_Wikidata_IDs(tags)
	if type(tags) == "string" then
		tags = mw.text.split(tags, "|", true)
	end
	
	local ret = {}
	
	for i, tag in ipairs(tags) do
		if tag == ";" then
			error("Semicolon is not supported for Wikidata IDs")
		end
		
		tag = m_data.shortcuts[tag] or tag
		local data = m_data.tags[tag]
		
		if not data or not data.wikidata then
			error("The tag \"" .. tag .. "\" does not have a Wikidata ID defined in Module:form of/data")
		end
		
		table.insert(ret, data.wikidata)
	end
	
	return ret
end


return export

-- For Vim, so we get 4-space tabs
-- vim: set ts=4 sw=4 noet:
