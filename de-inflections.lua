local export = {}

local m_links = require("Module:links")
local m_form_of = require("Module:form of")

local lang = require("Module:languages").getByCode("de")
local PAGENAME = mw.title.getCurrentTitle().text

local rmatch = mw.ustring.match
local rfind = mw.ustring.find
local rsplit = mw.text.split
local rsubn = mw.ustring.gsub
local usub = mw.ustring.sub

-- version of rsubn() that discards all but the first return value
local function rsub(term, foo, bar)
	local retval = rsubn(term, foo, bar)
	return retval
end


ending_tags = {
  ["en"] = {"str|gen|m//n|s", "wk//mix|gen//dat|all-gender|s", "str//wk//mix|acc|m|s", "str|dat|p", "wk//mix|all-case|p"},
  ["e"] = {"str//mix|nom//acc|f|s", "str|nom//acc|p", "wk|nom|all-gender|s", "wk|acc|f//n|s"},
  ["er"] = {"str//mix|nom|m|s", "str|gen//dat|f|s", "str|gen|p"},
  ["es"] = {"str//mix|nom//acc|n|s"},
  ["em"] = {"str|dat|m//n|s"},
}

ending_keys = {}
for key, _ in pairs(ending_tags) do
	table.insert(ending_keys, key)
end

for _, key in ipairs(ending_keys) do
	local tags = ending_tags[key]
	local erkey = "er" .. key
	ending_tags[erkey] = {}
	for _, tag in ipairs(tags) do
		table.insert(ending_tags[erkey], tag .. "|comd")
	end
end

for _, key in ipairs(ending_keys) do
	local tags = ending_tags[key]
	local stkey = "st" .. key
	ending_tags[stkey] = {}
	for _, tag in ipairs(tags) do
		table.insert(ending_tags[stkey], tag .. "|supd")
	end
	-- flott -> flottesten, barsch -> barschesten, betagt -> betagtesten,
	-- herzlos -> herzlosesten, frohgemut -> frohgemutesten,
	-- amyloid -> amyloidesten, erdnah -> erdnahesten, and others
	-- unpredictably; allow for endings like -esten
	ending_tags["e" .. stkey] = ending_tags[stkey]
end

function export.show_adj_form(frame)
	local params = {
		[1] = {required = true, default = "flott"},
		[2] = {},
		["sort"] = {},
	}

	local parargs = frame:getParent().args
	local args = require("Module:parameters").process(parargs, params)

	local lemma = args[1]
	local ending = args[2]

	if PAGENAME == "de-adj form of" and not ending then
		ending = "esten"
	end

	local function try(modlemma)
		-- Need to escape regex chars in lemma, esp. hyphen
		local potential_ending = rmatch(PAGENAME, "^" .. rsub(modlemma, "([^A-Za-z0-9 ])", "%%%1") .. "(.*)$")
		if potential_ending and ending_tags[potential_ending] then
			ending = potential_ending
		end
	end

	if not ending then
		try(lemma)
	end
	if not ending and lemma:find("e[mnlr]$") then
		-- simpel -> simplen
		try(lemma:gsub("e([mnlr])$", "%1"))
	end
	if not ending and lemma:find("e$") then
		-- bitweise -> bitweisen
		try(lemma:gsub("e$", ""))
	end
	if not ending and rfind(lemma, "[^aeiouy][aeiouy][^aeiouy]$") then
		-- fit -> fitten
		try(lemma .. usub(lemma, -1))
	end
	if not ending then
		-- Umlautable adjectives: nass -> nässeren, gesund -> gesünderen, geraum -> geräumeren
		local init, vowel, final_cons = rmatch(lemma, "^(.-)(au)([^aeiouy]+)$")
		if not init then
			init, vowel, final_cons = rmatch(lemma, "^(.-)([aou])([^aeiouy]+)$")
		end
		if init then
			umlauts = {["a"] = "ä", ["o"] = "ö", ["u"] = "ü", ["au"] = "äu"}
			try(init .. umlauts[vowel] .. final_cons)
		end
	end
	if not ending then
		error("Unable to find adjective ending from page name '" .. PAGENAME .. "' based on lemma '" .. lemma .. "'")
	end

	local tags = ending_tags[ending]

	if not tags then
		error("Unrecognized adjective ending '" .. ending .. "'")
	end

	tags = rsplit(table.concat(tags, "|;|"), "|")

	local terminfo = {
		lang = lang,
		term = args[1],
	}

	local categories = m_form_of.fetch_lang_categories(lang, tags, terminfo, "adjective")
	return m_form_of.tagged_inflections({ tags = tags, terminfo = terminfo, terminfo_face = "term" }) .. 
		require("Module:utilities").format_categories(categories, lang, args["sort"])
end

return export
