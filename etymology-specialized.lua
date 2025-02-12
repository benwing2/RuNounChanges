local export = {}

local m_str_utils = require("Module:string utilities")
local en_utilities_module = "Module:en-utilities"
local etymology_module = "Module:etymology"

local gsub = m_str_utils.gsub
local insert = table.insert
local pluralize = require(en_utilities_module).pluralize
local upper = m_str_utils.upper

-- This function handles all the messiness of different types of specialized borrowings. It should insert any
-- borrowing-type-specific categories into `categories` unless `nocat` is given, and return the text to display
-- before the source + term (or "" for no text).
local function get_specialized_borrowing_text_insert_cats(data)
	local bortype, categories, lang, terms, source, nocap, nocat, senseid =
		data.bortype, data.categories, data.lang, data.terms, data.source, data.nocap, data.nocat, data.senseid

	local function inscat(cat)
		if not nocat then
			local display, sourcedisp = require(etymology_module).get_display_and_cat_name(source, "raw")
			if cat:find("DISPLAY") then
				cat = cat:gsub("DISPLAY", display)
			elseif cat:find("SOURCE") then
				cat = cat:gsub("SOURCE", sourcedisp)
			else
				cat = cat .. " " .. sourcedisp
			end
			insert(categories, lang:getCanonicalName() .. " " .. cat)
		end
	end
	
	-- `text` is the display text for the borrowing type, which gets converted
	--	into a link.
	-- `appendix` is a the glossary anchor, which defaults to `text`
	-- `prep` is the preposition between the borrowing type and the language
	--	name (e.g. "of", "from")
	-- `pos` is the part of speech for the borrowing type ("noun" or
	--	"adjective"; defaults to "noun")
	-- `plural` is the plural form of the borrowing type; if not specified,
	--	the pluralize function is used
	local text, appendix, prep, pos, plural
	
	if bortype == "calque" then
		text, prep = "calque", "of"
		inscat("terms calqued from")
	elseif bortype == "partial-calque" then
		text, prep = "partial calque", "of"
		inscat("terms partially calqued from")
	elseif bortype == "semantic-loan" then
		text, prep = "semantic loan", "from"
		inscat("semantic loans from")
	elseif bortype == "transliteration" then
		text, prep = "transliteration", "of"
		inscat("terms borrowed from")
		inscat("transliterations of DISPLAY terms")
	elseif bortype == "phono-semantic-matching" then
		text, prep = "phono-semantic matching", "of"
		inscat("phono-semantic matchings from")
	else
		local langcode = lang:getCode()
		local lang_is_source = langcode == source:getCode()
		if lang_is_source then
			-- Track, because this shouldn't be happening. A language can only have itself as a source further up the chain after a borrowing, which is always "derived".
			require("Module:debug/track"){
				"etymology/specialized/self-as-source",
				"etymology/specialized/self-as-source/" .. langcode
			}
			inscat("terms borrowed back into")
		else
			inscat("terms borrowed from")
			if bortype ~= "borrowing" then
				inscat(bortype .. " borrowings from")
			end
		end
		
		if bortype == "borrowing" then
			text, appendix, prep, pos = "borrowed", "loanword", "from", "adjective"
		elseif (
			bortype == "learned" or
			bortype == "semi-learned" or
			bortype == "orthographic" or
			bortype == "unadapted"
		) then
			text, prep = bortype .. " borrowing", "from"
		elseif bortype == "adapted" then 
			text, prep = bortype .. " borrowing", "of"
		else
			error("Internal error: Unrecognized bortype: " .. bortype)
		end
	end
	
	-- If the term is suppressed, the preposition should always be "from":
		-- "Calque of Chinese 中國".
		-- "Calque from Chinese" (not "Calque of Chinese").
	if terms[1].term == "-" then
		prep = "from"
	end
	
	appendix = "Appendix:Glossary#" .. (appendix or text)

	if senseid then
		local senseids, output = mw.text.split(senseid, '!!'), {}
		for i, id in ipairs(senseids) do
			-- FIXME: This should be done via a function.
			insert(output, mw.getCurrentFrame():preprocess('{{senseno|' .. lang:getCode() .. '|' .. id .. (i == 1 and not nocap and "|uc=1" or "") .. '}}'))
		end
		local link
		if senseid:find('!!') then
			link, text = "are", pos == "adjective" and text or plural or pluralize(text)
		else
			link = pos == "adjective" and "is" or "is a"
		end
		text = mw.text.listToText(output) .. " " .. link .. " " .. '[[' .. appendix .. '|' .. text .. ']]'
	else
		text = "[[" .. appendix .. "|" .. (nocap and text or gsub(text, "^.", upper)) .. "]]"
	end
	
	return text .. " " .. prep .. " "
end


function export.specialized_borrowing(data)
	local lang, sources, terms = data.lang, data.sources, data.terms
	local categories = {}
	local text

	for _, source in ipairs(sources) do
		text = get_specialized_borrowing_text_insert_cats {
			bortype = data.bortype,
			categories = categories,
			lang = lang,
			terms = terms,
			source = source,
			nocap = data.nocap,
			nocat = data.nocat,
			senseid = data.senseid,
		}
	end
	
	text = data.notext and "" or text
	return text .. require(etymology_module).format_sources {
		lang = lang,
		sources = sources,
		terms = terms,
		sort_key = data.sort_key,
		categories = categories,
		nocat = data.nocat,
		sourceconj = data.sourceconj,
	} .. require(etymology_module).format_links(terms, data.conj, "etymology/specialized")
end


return export
