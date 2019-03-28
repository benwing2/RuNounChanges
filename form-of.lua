local m_links = require("Module:links")
local m_data = mw.loadData("Module:form of/data")

local export = {}


function export.format_t(text, terminfo)
	return
		"<span class='form-of-definition'>" .. text .. " " ..
		"<span class='form-of-definition-link'>" ..
		m_links.full_link(terminfo, "term", false) ..
		"</span>" ..
		"</span>"
end


function export.form_of_t(frame)
	local iparams = {
		[1] = {required = true},
		["term_param"] = {type = "number", default = 1},
		["lang"] = {},
		["sc"] = {},
		["id"] = {},
		["cat"] = {list = true},
		["ignore"] = {list = true},
		["ignorelist"] = {list = true},
	}
	
	local iargs = require("Module:parameters").process(frame.args, iparams)
	local parent_args = frame:getParent().args

	local term_param = iargs["term_param"]
	local text = iargs[1]
	local lang = iargs["lang"]
	local sc = iargs["sc"]
	local id = iargs["id"]
	
	local categories = {}

	local compat = iargs["lang"] or parent_args["lang"]
	local offset = compat and 0 or 1

	local function track(page)
		require("Module:debug").track("form-of/form-of-t/" .. page)
	end

	-- temporary tracking for term_param
	if frame.args["term_param"] then
		track("term-param")
	end
	
	if not text then
		error("No definition text provided.")
	end
	
	local params = {
		[compat and "lang" or term_param] = {required = lang == nil},
		[term_param + offset] = {required = true},
		[term_param + offset + 1] = {},
		[term_param + offset + 2] = {alias_of = "t"},
		
		["gloss"] = {alias_of = "t"},
		["id"] = {},
		["lit"] = {},
		["nocap"] = {type = "boolean"},
		["nocat"] = {type = "boolean"},
		["nodot"] = {type = "boolean"},
		["pos"] = {},
		["sc"] = {},
		["sort"] = {},
		["t"] = {},
		["tr"] = {},
		["ts"] = {},
	}

	local ignored_params = {
		["nodot"] = true,
	}
	for _, ignore in ipairs(iargs["ignore"]) do
		params[ignore] = {}
		ignored_params[ignore] = nil
	end
	for _, ignorelist in ipairs(iargs["ignorelist"]) do
		params[ignorelist] = {list = true}
	end
	
	local args = require("Module:parameters").process(parent_args, params)

	-- temporary tracking for valid but unused arguments not in ignore= or ignorelist=
	for unused_arg, _ in pairs(ignored_params) do
		if parent_args[unused_arg] then
			track("unused")
			track("unused/" .. unused_arg)
		end
	end

	local term = args[term_param + offset] or "term"
	local alt = args[term_param + offset + 1]
	
	lang = lang or args[compat and "lang" or term_param] or "und"
	sc = sc or args["sc"]
	id = id or args["id"]
	
	lang = require("Module:languages").getByCode(lang) or require("Module:languages").err(lang, "lang")
	sc = (sc and (require("Module:scripts").getByCode(sc) or error("The script code \"" .. sc .. "\" is not valid.")) or nil)

	if not args["nocat"] then
		for _, cat in ipairs(iargs["cat"]) do
			table.insert(categories, lang:getCanonicalName() .. " " .. cat)
		end
	end
	-- add tracking category if term is same as page title
	if term and mw.title.getCurrentTitle().text == lang:makeEntryName(term) then
		table.insert(categories, "Forms linking to themselves")
	end

	return export.format_t(text,
		{
			lang = lang,
			sc = sc,
			term = term,
			alt = alt,
			id = id,
			gloss = args["t"],
			tr = args["tr"],
			ts = args["ts"],
			pos = args["pos"],
			lit = args["lit"],
		}
	) .. require("Module:utilities").format_categories(categories, lang, args["sort"])
end


function export.alt_format_t(lang, text, terminfo, dot, categories, sort_key)
	return
		"<span class='use-with-mention'>" .. text .. " " ..
		m_links.full_link(terminfo, "term", false) ..
		"</span>" ..
		require("Module:utilities").format_categories(categories, lang, sort_key) ..
		dot
end


-- This replaces {{deftempboiler}}. Some templates use form_of_t in
-- [[Module:form of]], while others used to use {{deftempboiler}}, with no
-- obvious pattern. Yet a few others were manually implemented in template
-- code. Note that form_of_t exists in both [[Module:form of]] and
-- [[Module:form of/templates]], but are different. Currently, the latter is
-- used by {{form of}} and the former by more specific templates, e.g.
-- {{obsolete spelling of}}. Note also that {{deftempboiler}} and form_of_t in
-- [[Module:form of]] differed signicantly in that e.g. the former by default
-- added a final period (replicated here), which the latter doesn't do.
function export.alt_form_of_t(frame)
	local iparams = {
		["lang"] = {},
		["sc"] = {},
		["cat"] = {list = true},
		["text"] = {required = true},
		["ignore"] = {list = true},
		["ignorelist"] = {list = true},
		["nodot"] = {type = "boolean"},
		["nocap"] = {type = "boolean"},
	}
	
	local iargs = require("Module:parameters").process(frame.args, iparams)

	local parent_args = frame:getParent().args
	local categories = {}
	local compat = parent_args["lang"]
	local offset = (compat or iargs["lang"]) and 0 or 1
	
	local params = {
		[1 + offset] = {},
		[2 + offset] = {},
		[3 + offset] = {alias_of = "t"},
		
		["dot"] = {},
		["gloss"] = {alias_of = "t"},
		["t"] = {},
		["id"] = {},
		["nodot"] = {type = "boolean"},
		["nocap"] = {type = "boolean"},
		["nocat"] = {type = "boolean"},
		["notext"] = {type = "boolean"},
		["sc"] = {},
		["tr"] = {},
		["ts"] = {},
		["g"] = {list = true},
		["pos"] = {},
		["lit"] = {},
		["sort"] = {},
	}

	if not iargs["lang"] then
		params[compat and "lang" or 1] = {required = true}
	end
	
	for _, ignore in ipairs(iargs["ignore"]) do
		params[ignore] = {}
	end
	for _, ignorelist in ipairs(iargs["ignorelist"]) do
		params[ignorelist] = {list = true}
	end
	if iargs["nodot"] then
		params["dot"] = nil
		params["nodot"] = nil
	end
	if iargs["nocap"] then
		params["nocap"] = nil
	end

	local args = require("Module:parameters").process(parent_args, params)
	
	local term = args[1 + offset]
	local alt = args[2 + offset]
	local lang = iargs["lang"] or args[compat and "lang" or 1] or "und"
	local sc = args["sc"] or iargs["sc"]

	lang = require("Module:languages").getByCode(lang) or require("Module:languages").err(lang, compat and "lang" or 1)
	sc = (sc and (require("Module:scripts").getByCode(sc) or error("The script code \"" .. sc .. "\" is not valid.")) or nil)

	if not args["nocat"] then
		for _, cat in ipairs(iargs["cat"]) do
			table.insert(categories, lang:getCanonicalName() .. " " .. cat)
		end
	end
	-- add tracking category if term is same as page title
	if term and mw.title.getCurrentTitle().text == lang:makeEntryName(term) then
		table.insert(categories, "Forms linking to themselves")
	end

	local text = args["notext"] and "" or iargs["text"]
	if not iargs["nocap"] and not args["nocap"] then
		text = mw.ustring.upper(mw.ustring.sub(text, 1, 1)) .. mw.ustring.sub(text, 2)
	end

	return export.alt_format_t(
		lang, text,
		{
			lang = lang,
			sc = sc,
			term = term,
			alt = alt,
			id = args["id"],
			genders = args["g"],
			gloss = args["t"],
			tr = args["tr"],
			ts = args["ts"],
			pos = args["pos"],
			lit = args["lit"],
		},
		(iargs["nodot"] or args["nodot"]) and "" or args["dot"] or ".",
		categories, args["sort"]
	)
end


function export.tagged_inflections(tags, terminfo)
	local cur_infl = {}
	local inflections = {}
	
	for i, tag in ipairs(tags) do
		if m_data.shortcuts[tag] then
		elseif m_data.tags[tag] then
		else
			require("Module:debug").track{
				"inflection of/unknown",
				"inflection of/unknown/" .. tag:gsub("%[", "("):gsub("%]", ")"):gsub("|", "!")
			}
		end
		
		if tag == ";" then
			if #cur_infl > 0 then
				table.insert(inflections, table.concat(cur_infl, " "))
			end
			
			cur_infl = {}
		else
			tag = m_data.shortcuts[tag] or tag
			local data = m_data.tags[tag]
			
			-- If there is a nonempty glossary index, then show a link to it
			if data and data.glossary then
				tag = "[[Appendix:Glossary#" .. mw.uri.anchorEncode(data.glossary) .. "|" .. tag .. "]]"
			end
			
			table.insert(cur_infl, tag)
		end
	end
	
	if #cur_infl > 0 then
		table.insert(inflections, table.concat(cur_infl, " "))
	end
	
	if #inflections == 1 then
		return export.format_t(inflections[1] .. " of", terminfo)
	else
		return
			"<span class='form-of-definition'>inflection of " ..
			"<span class='form-of-definition-link'>" .. m_links.full_link(terminfo, "term", false) .. "</span>" ..
			":</span>\n## <span class='form-of-definition'>" .. table.concat(inflections, "</span>\n## <span class='form-of-definition'>") .. "</span>"
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
