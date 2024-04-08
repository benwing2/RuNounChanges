local export = {}

local sc = require("Module:scripts").getByCode("Morse")

local submap = {
	["."] = "[[File:Morse code dot.svg|link=]]",
	["-"] = "[[File:Morse code dash.svg|link=]]",
	[" "] = "[[File:60x15transparent spacer.svg|27px|link=]]",
}

function export.textToImages(text)
	return mw.ustring.gsub(text, "[-. ]", submap)
end

local types = {
	["letter"] = "letters",
	["number"] = "numbers",
	["punctuation mark"] = "punctuation marks",
	["symbol"] = "symbols",
	["interjection"] = "interjections",
}

function export.headword(frame)

	local m_head = require("Module:headword")

	local type = frame.args["1"] ~= "" and frame.args["1"]
	local head = frame:getParent().args["head"]
	if not head or head == "" then
		head = mw.loadData("Module:headword/data").page.pagename
	end
	local langCode = frame.args["lang"] or "mul"
	local lang = require("Module:languages").getByCode(langCode)

	local display = '<span style="display:inline-block;vertical-align:middle">' .. export.textToImages(head) .. '</span>'
	
	local data = {lang = lang, sc = sc, categories = {}, sort_key = head, heads = {display}, translits = {"-"}}
	
	if types[type] then
		data.pos_category = types[type]
	end

	return m_head.full_headword(data)

end

return export
