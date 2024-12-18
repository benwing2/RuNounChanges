local export = {}

local m_str_utils = require("Module:string utilities")
local etymology_module = "Module:etymology"
local etymology_multi_module = "Module:etymology/multi"

local gsub = m_str_utils.gsub
local insert = table.insert
local pluralize = m_str_utils.pluralize
local upper = m_str_utils.upper

-- This function handles all the messiness of different types of specialized borrowings. It should insert any
-- borrowing-type-specific categories into `categories` unless `nocat` is given, and return the text to display
-- before the source + term (or "" for no text).
local function get_specialized_borrowing_text_insert_cats(data)
	local bortype, categories, lang, term, source, nocap, nocat, senseid =
		data.bortype, data.categories, data.lang, data.term, data.source, data.nocap, data.nocat, data.senseid

	local function inscat(cat)
		if not nocat then
			local sourcedisp = source:getDisplayForm()
			if cat:find("SOURCE") then
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
		inscat("transliterations of SOURCE terms")
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
		else
			error("Internal error: Unrecognized bortype: " .. bortype)
		end
	end
	
	-- If the term is suppressed, the preposition should always be "from":
		-- "Calque of Chinese 中國".
		-- "Calque from Chinese" (not "Calque of Chinese").
	if term == "-" then
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
	local bortype, lang, terminfo, sort_key, nocap, notext, nocat, senseid, template_name =
		data.bortype, data.lang, data.terminfo, data.sort_key, data.nocap, data.notext, data.nocat, data.senseid,
		data.template_name
	local m_etymology = require(etymology_module)
	local categories, source = {}, terminfo.lang
	
	local text = get_specialized_borrowing_text_insert_cats {
		bortype = bortype,
		categories = categories,
		lang = lang,
		term = terminfo.term,
		source = source,
		nocap = nocap,
		nocat = nocat,
		senseid = senseid,
	}
	
	text = notext and "" or text
	return text .. m_etymology.format_source {
		lang = lang,
		source = source,
		sort_key = sort_key,
		categories = categories,
		nocat = nocat
	} .. m_etymology.process_and_create_link(terminfo, template_name)
end


function export.specialized_multi_borrowing(data)
	local bortype, lang, sc, sources, terminfo, sort_key, nocap, notext, nocat, conj, senseid, template_name =
		data.bortype, data.lang, data.sc, data.sources, data.terminfo, data.sort_key, data.nocap, data.notext,
		data.nocat, data.conj, data.senseid, data.template_name
	local categories, term = {}, terminfo.term
	local text

	for _, source in ipairs(sources) do
		text = get_specialized_borrowing_text_insert_cats {
			bortype = bortype,
			categories = categories,
			lang = lang,
			term = term,
			source = source,
			nocap = nocap,
			nocat = nocat,
			senseid = senseid,
		}
	end
	
	text = notext and "" or text
	return text .. require(etymology_multi_module).format_sources {
		lang = lang,
		sc = sc,
		sources = sources,
		terminfo = terminfo,
		sort_key = sort_key,
		categories = categories,
		nocat = nocat,
		conj = conj,
	} .. require(etymology_module).process_and_create_link(terminfo, template_name)
end


return export
