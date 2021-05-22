-- This module contains code for Italian headword templates.
-- Templates covered are it-adj, it-noun and it-proper noun.
-- See [[Module:it-conj]] for Italian conjugation templates.
local export = {}

local lang = require("Module:languages").getByCode("it")

local function glossary_link(entry, text)
	text = text or entry
	return "[[Appendix:Glossary#" .. entry .. "|" .. text .. "]]"
end

function export.itadj(frame)
	local params = {
		[1] = {},
		[2] = {},
		[3] = {},
		[4] = {},
		[5] = {},
		
		["head"] = {},
		["sort"] = {},
	}
	
	local args = require("Module:parameters").process(frame:getParent().args, params)
	
	local data = {lang = lang, pos_category = "adjectives", categories = {}, sort_key = args["sort"], heads = {args["head"]}, genders = {}, inflections = {}}
	
	local stem = args[1]
	local end1 = args[2]
	
	if not stem then -- all specified
		data.heads = args[2]
		data.inflections = {
			{label = "feminine singular", args[3]},
			{label = "masculine plural", args[4]},
			{label = "feminine plural", args[5]}
		}
	elseif not end1 then -- no ending vowel parameters - generate default
		data.inflections = {
			{label = "feminine singular", stem .. "a"},
			{label = "masculine plural", make_plural(stem .. "o","m")},
			{label = "feminine plural", make_plural(stem .. "a","f")}
		}
	else
		local end2 = args[3] or error("Either 0, 2 or 4 vowel endings should be supplied!")
		local end3 = args[4]
		
		if not end3 then -- 2 ending vowel parameters - m and f are identical
			data.inflections = {
				{label = "masculine and feminine plural", stem .. end2}
			}
		else -- 4 ending vowel parameters - specify exactly
			local end4 = args[5] or error("Either 0, 2 or 4 vowel endings should be supplied!")
			data.inflections = {
				{label = "feminine singular", stem .. end2},
				{label = "masculine plural", stem .. end3},
				{label = "feminine plural", stem .. end4}
			}
		end
	end
	
	return require("Module:headword").full_headword(data)
end

local allowed_genders = require("Module:table").listToSet(
	{"m", "f", "mf", "mfbysense", "m-p", "f-p", "mf-p", "mfbysense-p", "?", "?-p"}
)

function export.itnoun(frame)
	local PAGENAME = mw.title.getCurrentTitle().text
	
	local params = {
		[1] = {list = "g", default = "?"},
		[2] = {list = "pl"},
		
		["head"] = {list = true},
		["m"] = {list = true},
		["mpl"] = {list = true},
		["f"] = {list = true},
		["fpl"] = {list = true},
		["sort"] = {},
	}
	
	local args = require("Module:parameters").process(frame:getParent().args, params)
	
	local data = {
		lang = lang, pos_category = "nouns", categories = {}, sort_key = args["sort"],
		heads = args["head"], genders = args[1], inflections = {}
	}

	local is_plurale_tantum = false

	for _, g in ipairs(args[1]) do
		if not allowed_genders[g] then
			error("Unrecognized gender: " .. g)
		end
		if g:find("-p$") then
			is_plurale_tantum = true
		end
	end

	local head = data.heads[1] and require("Module:links").remove_links(data.heads[1]) or PAGENAME
	-- Plural
	if is_plurale_tantum then
		if #args[2] > 0 then
			error("Can't specify plurals of plurale tantum noun")
		end
		table.insert(data.inflections, {label = glossary_link("plural only")})
	else
		local plural = args[2][1]
		
		if not plural and #args["mpl"] == 0 and #args["fpl"] == 0 then
			args[2][1] = make_plural(head, data.genders[1])
		end
		
		if plural == "~" then
			table.insert(data.inflections, {label = glossary_link("uncountable")})
			table.insert(data.categories, "Italian uncountable nouns")
		else
			table.insert(data.categories, "Italian countable nouns")
		end
		
		if plural == "-" then
			table.insert(data.inflections, {label = glossary_link("invariable")})
		end
		
		if plural ~= "-" and plural ~= "~" and #args[2] > 0 then
			args[2].label = "plural"
			args[2].accel = {form = "p"}
			table.insert(data.inflections, args[2])
		end
	end
	
	-- Other gender
	if #args["f"] > 0 then
		args["f"].label = "feminine"
		table.insert(data.inflections, args["f"])
	end
	
	if #args["m"] > 0  then
		args["m"].label = "masculine"
		table.insert(data.inflections, args["m"])
	end
	
	if #args["mpl"] > 0 then
		args["mpl"].label = "masculine plural"
		table.insert(data.inflections, args["mpl"])
	end

	if #args["fpl"] > 0 then
		args["fpl"].label = "feminine plural"
		table.insert(data.inflections, args["fpl"])
	end

	-- Category
	if head:find("o$") and data.genders[1] == "f" then
		table.insert(data.categories, "Italian nouns with irregular gender")
	end
	
	if head:find("a$") and data.genders[1] == "m" then
		table.insert(data.categories, "Italian nouns with irregular gender")
	end
	
	return require("Module:headword").full_headword(data)
end

-- Generate a default plural form, which is correct for most regular nouns
function make_plural(word, gender)
	-- If there are spaces in the term, then we can't reliably form the plural.
	-- Return nothing instead.
	if word:find(" ") then
		return nil
	elseif word:find("io$") then
		word = word:gsub("io$", "i")
	elseif word:find("ologo$") then
		word = word:gsub("o$", "i")
	elseif word:find("[cg]o$") then
		word = word:gsub("o$", "hi")
	elseif word:find("o$") then
		word = word:gsub("o$", "i")
	elseif word:find("[cg]a$") then
		word = word:gsub("a$", (gender == "m" and "hi" or "he"))
	elseif word:find("[cg]ia$") then
		word = word:gsub("ia$", "e")
	elseif word:find("a$") then
		word = word:gsub("a$", (gender == "m" and "i" or "e"))
	elseif word:find("e$") then
		word = word:gsub("e$", "i")
	end
	return word
end

-- Generate a default feminine form
function make_feminine(word, gender)
	if word:find("o$") then
		return word:gsub("o$", "a")
	else
		return word
	end
end

function export.itprop(frame)
	local params = {
		[1] = {list = "g", default = "?"},

		["head"] = {list = true},
		["m"] = {list = true},
		["f"] = {list = true},
		["sort"] = {},
	}
	
	local args = require("Module:parameters").process(frame:getParent().args, params)
	
	local data = {
		lang = lang, pos_category = "proper nouns", categories = {}, sort_key = args["sort"],
		heads = args["head"], genders = args[1], inflections = {}
	}

	local is_plurale_tantum = false

	for _, g in ipairs(args[1]) do
		if not allowed_genders[g] then
			error("Unrecognized gender: " .. g)
		end
		if g:find("-p$") then
			is_plurale_tantum = true
		end
	end

	if is_plurale_tantum then
		table.insert(data.inflections, {label = glossary_link("plural only")})
	end

	-- Other gender
	if #args["f"] > 0 then
		args["f"].label = "feminine"
		table.insert(data.inflections, args["f"])
	end
	
	if #args["m"] > 0  then
		args["m"].label = "masculine"
		table.insert(data.inflections, args["m"])
	end
	
	return require("Module:headword").full_headword(data)
end

return export
