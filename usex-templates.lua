local export = {}

local m_languages = require("Module:languages")
local table_module = "Module:table"
local usex_module = "Module:usex"

local rsplit = mw.text.split
local rfind = mw.ustring.find

local function track(page)
	require("Module:debug/track")("usex/templates/" .. page)
	return true
end

function export.usex_t(frame)
	local params = {
		[1] = {required = true},
		[2] = {},
		[3] = {},
		
		["inline"] = {type = "boolean"},
		["noenum"] = {type = "boolean"},
		["ref"] = {},
		["lit"] = {},
		["q"] = {list = true},
		["qq"] = {list = true},
		["sc"] = {},
		["source"] = {},
		["footer"] = {},
		["subst"] = {},
		["t"] = {alias_of = 3},
		["translation"] = {alias_of = 3},
		["tr"] = {},
		["transliteration"] = {alias_of = "tr"},
		["ts"] = {},
		["transcription"] = {alias_of = "ts"},
		["norm"] = {},
		["normalization"] = {alias_of = "norm"},
		["normsc"] = {},
		["nocat"] = {type = "boolean"},
		["brackets"] = {type = "boolean"},
		["sort"] = {},
	}
	
	local quote = (frame.args["quote"] or "") ~= ""
	local compat = (frame.args["compat"] or "") ~= ""
	local template_inline = (frame.args["inline"] or "") ~= ""
	local template_nocat = (frame.args["nocat"] or "") ~= ""
	local class = frame.args["class"]
	
	if compat then
		params["lang"] = {required = true}
		params["t"].alias_of = 2
		params["translation"].alias_of = 2
		table.remove(params, 1)
	end
	
	local args = require("Module:parameters").process(frame:getParent().args, params)
	
	local lang = args[compat and "lang" or 1] or "und"
	local sc = args["sc"]
	sc = sc and require("Module:scripts").getByCode(sc, "sc") or nil
	local normsc = args["normsc"]
	normsc = normsc == "auto" and normsc or normsc and require("Module:scripts").getByCode(normsc, "normsc") or nil

	if #args.qq > 0 then
		track("qq")
	end
	if #args.q > 0 then
		track("q")
	end
	
	local data = {
		lang = m_languages.getByCode(lang, compat and "lang" or 1),
		sc = sc,
		normsc = normsc,
		usex = args[compat and 1 or 2],
		translation = args[compat and 2 or 3],
		transliteration = args["tr"],
		transcription = args["ts"],
		normalization = args["norm"],
		noenum = args["noenum"],
		inline = args["inline"] or template_inline,
		ref = args["ref"],
		quote = quote,
		lit = args["lit"],
		substs = args["subst"],
		-- FIXME, change to left and right qualifiers
		qq = #args.qq > 0 and args.qq or args.q,
		source = args["source"],
		footer = args["footer"],
		nocat = args["nocat"] or template_nocat,
		brackets = args["brackets"],
		sortkey = args["sort"],
		class = class,
	}
	
	return require(usex_module).format_usex(data)
end

-- Convert a comma-separated list of language codes to a comma-separated list of language names. Meant to be called
-- from a template. Template argument 1 is the language codes. Optional template argument param= is the name of the
-- parameter from which the list of language codes was fetched, defaulting to 1.
--
-- FIXME: Remove this once we get rid of {{quote-meta}}.
function export.format_langs(frame)
	local langs = frame.args[1]
	local paramname = frame.args.param or 1
	langs = rsplit(langs, ",")
	for i, langcode in ipairs(langs) do
		local lang = m_languages.getByCode(langcode, paramname)
		langs[i] = lang:getCanonicalName()
	end
	if #langs == 1 then
		return langs[1]
	else
		return require(table_module).serialCommaJoin(langs)
	end
end

-- Given a comma-separated list of language codes, return the first one.
function export.first_lang(frame)
	local langcodes = rsplit(frame.args[1], ",")
	return langcodes[1]
end

local ignore_prefixes = {"User:", "Talk:",
	"Wiktionary:Beer parlour", "Wiktionary:Translation requests",
	"Wiktionary:Grease pit", "Wiktionary:Etymology scriptorium",
	"Wiktionary:Information desk", "Wiktionary:Tea room",
	"Wiktionary:Requests for", "Wiktionary:Votes"
}

function export.page_should_be_ignored(page)
	-- Ignore user pages, talk pages and certain Wiktionary pages
	for _, ip in ipairs(ignore_prefixes) do
		if rfind(page, "^" .. ip) then
			return true
		end
	end
	if rfind(page, " talk:") then
		return true
	end
	return false
end

function export.page_should_be_ignored_t(frame)
	return export.page_should_be_ignored(frame.args[1]) and "true" or ""
end

return export
