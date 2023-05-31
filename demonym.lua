local export = {}

local m_links = require("Module:links")
local m_languages = require("Module:languages")
local lang_en = m_languages.getByCode("en")

local force_cat = false -- set to true for testing


local function link_with_qualifiers(part, face, pretext)
	local partparts = {}
	if part.q then
		table.insert(partparts, require("Module:qualifier").format_qualifier(part.q) .. " ")
	end
	if pretext then
		table.insert(partparts, pretext)
	end
	table.insert(partparts, m_links.full_link(part, face, "allow self link"))
	if part.qq then
		table.insert(partparts, " " .. require("Module:qualifier").format_qualifier(part.qq))
	end
	return table.concat(partparts)
end


local function format_glosses(data, gloss_pretext)
	local has_gloss = data.gloss and #data.gloss > 0

	if data.lang:getCode() == "en" then
		if has_gloss then
			local glosstext
			if #data.gloss == 1 then
				glosstext = ("an English gloss '%s'"):format(data.gloss[1].term)
			else
				for i, term in ipairs(data.gloss) do
					data.gloss[i] = "'" .. term.term .. "'"
				end
				glosstext = ("English glosses %s"):format(table.concat(data.gloss, ", "))
			end
			error(("Can't specify %s for the term when the language is already English"):format(glosstext))
		end
		return ""
	elseif has_gloss then
		if data.notext then
			error("Can't specify gloss along with notext=")
		end
		for i, gloss in ipairs(data.gloss) do
			gloss.lang = gloss.lang or lang_en
			data.gloss[i] = link_with_qualifiers(gloss, nil, gloss_pretext)
		end
		return table.concat(data.gloss, ", ")
	else
		return ""
	end
end


local function format_parts(data)
	for i, part in ipairs(data.parts) do
		part.lang = part.lang or lang_en
		if part.gloss then
			-- move gloss to 'pos' so it doesn't have quotes around it
			if part.pos then
				part.pos = part.gloss .. ", " .. part.pos
			else
				part.pos = part.gloss
			end
			part.gloss = nil
		end
		data.parts[i] = link_with_qualifiers(part)
	end

	if #data.parts == 1 then
		return data.parts[1]
	else
		return require("Module:table").serialCommaJoin(data.parts, {conj = "or"})
	end
end


-- WARNING: This overwrites objects in `data`.
function export.format_demonym_adj(data)
	result = {}

	local function ins(text)
		table.insert(result, text)
	end

	local langcode = data.lang:getCode()
	local lang_is_en = langcode == "en"

	local glosstext = format_glosses(data)
	ins(glosstext)
	if glosstext ~= "" then
		ins(" (")
	end

	if not data.notext then
		if glosstext == "" and lang_is_en and not data.nocap then
			ins("Of")
		else
			ins("of")
		end
		ins(", from or relating to ")
	end

	ins(format_parts(data))

	if glosstext ~= "" then
		ins(")")
	end

	if lang_is_en and not data.nodot and not data.notext then
		ins(".")
	end

	if not data.nocat then
		local cats = {}
		table.insert(cats, langcode .. ":Demonyms")
		ins(require("Module:utilities").format_categories(cats, data.lang, data.sort, nil, force_cat))
	end

	return table.concat(result)
end


-- WARNING: This overwrites objects in `data`.
function export.format_demonym_noun(data)
	result = {}

	local function ins(text)
		table.insert(result, text)
	end

	local langcode = data.lang:getCode()
	local lang_is_en = langcode == "en"

	local has_femeq = data.m and #data.m > 0
	data.g = data.g or has_femeq and "f" or nil

	if has_femeq then
		if data.notext then
			error("Can't specify m= along with notext=")
		end
		for i, m in ipairs(data.m) do
			data.m[i].lang = data.m[i].lang or data.lang
		end
		local femeq_data = {
			text = (lang_is_en and not data.nocap and "Female" or "female") .. " equivalent of",
			terminfos = data.m,
			terminfo_face = "term",
		}
		ins(require("Module:form of").format_form_of(femeq_data))
		ins("; ")
	end

	local glosstext = format_glosses(data, data.g == "f" and not data.gloss_is_gendered and "[[female]] " or nil)
	ins(glosstext)
	if lang_is_en and not data.notext then
		if not has_femeq and not data.nocap then
			ins("A ")
		else
			ins("a ")
		end
	elseif glosstext ~= "" then
		ins(" (")
	end

	if not data.notext then
		if data.g == "f" then
			ins("[[female]] ")
		end

		ins("[[native]] or [[inhabitant]] of ")
	end

	ins(format_parts(data))

	if glosstext ~= "" then
		ins(")")
	end

	if data.g == "m" and not data.notext then
		ins(" ")
		ins(require("Module:qualifier").format_qualifier("male or of unspecified gender"))
	end

	if lang_is_en and not data.nodot and not data.notext then
		ins(".")
	end

	if not data.nocat then
		local cats = {}
		table.insert(cats, langcode .. ":Demonyms")
		if data.g == "m" then
			table.insert(cats, langcode .. ":Male people")
		elseif data.g == "f" then
			table.insert(cats, langcode .. ":Female people")
		end
		if has_femeq then
			table.insert(cats, data.lang:getCanonicalName() .. " female equivalent nouns")
		end
		ins(require("Module:utilities").format_categories(cats, data.lang, data.sort, nil, force_cat))
	end

	return table.concat(result)
end

return export
