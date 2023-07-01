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


adjective_ending_tags = {
	["en"] = {"str|gen|m//n|s", "wk//mix|gen//dat|all-gender|s", "str//wk//mix|acc|m|s", "str|dat|p", "wk//mix|all-case|p"},
	["e"] = {"str//mix|nom//acc|f|s", "str|nom//acc|p", "wk|nom|all-gender|s", "wk|acc|f//n|s"},
	["er"] = {"str//mix|nom|m|s", "str|gen//dat|f|s", "str|gen|p"},
	["es"] = {"str//mix|nom//acc|n|s"},
	["em"] = {"str|dat|m//n|s"},
}

noun_ending_tags = {
	["m"] = {
		["en"] = {"str|gen|s", "wk//mix|gen//dat|s", "str//wk//mix|acc|s", "str|dat|p", "wk//mix|all-case|p"},
		["e"] = {"str|nom//acc|p", "wk|nom|s"},
		-- lemma: ["er"] = {"str//mix|nom|s", "str|gen|p"},
		["em"] = {"str|dat|s"},
	},
	["f"] = {
		["en"] = {"wk//mix|gen//dat|s", "str|dat|p", "wk//mix|all-case|p"},
		-- lemma: ["e"] = {"str//wk//mix|nom//acc|s", "str|nom//acc|p"},
		["er"] = {"str|gen//dat|f|s", "str|gen|p"},
	},
	["n"] = {
		["en"] = {"str|gen|s", "wk//mix|gen//dat|s", "str|dat|p", "wk//mix|all-case|p"},
		["e"] = {"str|nom//acc|p", "wk|nom//acc|s"},
		["er"] = {"str|gen|p"},
		-- lemma: ["es"] = {"str//mix|nom//acc|s"},
		["em"] = {"str|dat|s"},
	}
}


-- Generate the correct tags for each recognized adjective ending key.

-- (1) The positive form keys.
adjective_ending_keys = {}
for key, _ in pairs(adjective_ending_tags) do
	table.insert(adjective_ending_keys, key)
end

-- (2) The comparative form keys.
for _, key in ipairs(adjective_ending_keys) do
	local tags = adjective_ending_tags[key]
	local erkey = "er" .. key
	adjective_ending_tags[erkey] = {}
	for _, tag in ipairs(tags) do
		table.insert(adjective_ending_tags[erkey], tag .. "|comd")
	end
end

-- (3) The superlative form keys.
for _, key in ipairs(adjective_ending_keys) do
	local tags = adjective_ending_tags[key]
	local stkey = "st" .. key
	adjective_ending_tags[stkey] = {}
	for _, tag in ipairs(tags) do
		table.insert(adjective_ending_tags[stkey], tag .. "|supd")
	end
	-- flott -> flottesten, barsch -> barschesten, betagt -> betagtesten,
	-- herzlos -> herzlosesten, frohgemut -> frohgemutesten,
	-- amyloid -> amyloidesten, erdnah -> erdnahesten, and others
	-- unpredictably; allow for endings like -esten
	adjective_ending_tags["e" .. stkey] = adjective_ending_tags[stkey]
end


function export.determine_adj_ending(lemma, form)
	local ending

	local function try(modlemma)
		-- Need to escape regex chars in lemma, esp. hyphen
		local potential_ending = rmatch(form, "^" .. rsub(modlemma, "([^A-Za-z0-9 ])", "%%%1") .. "(.*)$")
		if potential_ending and adjective_ending_tags[potential_ending] then
			ending = potential_ending
		end
	end

	try(lemma)
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

	return ending
end


function export.show_adj_form(frame)
	local params = {
		[1] = {required = true, default = "flott"},
		[2] = {},
		["pagename"] = {},
		["sort"] = {},
	}

	local parargs = frame:getParent().args
	local args = require("Module:parameters").process(parargs, params)

	local lemma = args[1]
	local ending = args[2]

	local pagename = args.pagename or PAGENAME
	if pagename == "de-adj form of" and not ending then
		ending = "esten"
	end

	if not ending then
		ending = export.determine_adj_ending(lemma, pagename)
	end

	if not ending then
		error("Unable to find adjective ending from page name '" .. pagename .. "' based on lemma '" .. lemma .. "'")
	end

	local tags = adjective_ending_tags[ending]

	if not tags then
		error("Unrecognized adjective ending '" .. ending .. "'")
	end

	tags = rsplit(table.concat(tags, "|;|"), "|")

	local lemma_obj = {
		lang = lang,
		term = args[1],
	}

	return m_form_of.tagged_inflections {
		lang = lang, tags = tags, lemmas = {lemma_obj}, lemma_face = "term", POS = "adjective", sort = args.sort
	}
end


function export.show_adj_noun_forms(frame)
	local params = {
		[1] = {required = true, default = "mfn"},
		["etymno"] = {type = "number"},
		["etym"] = {alias_of = "etymno", type = "number"},
		["level"] = {type = "number"},
		["pagename"] = {},
		["sort"] = {},
	}

	local parargs = frame:getParent().args
	local args = require("Module:parameters").process(parargs, params)

	-- Validate and fetch etymno and level params.
	if args.etymno and args.level then
		error("Specify only one of etymno= or level=")
	end
	if args.etymno and args.etymno < 1 then
		error("etymno=" .. args.etymno .. ", but should be >= 1")
	end
	if args.level and args.level < 3 then
		error("level=" .. args.level .. ", but should be >= 3")
	end
	local level = args.level or args.etymno and 4 or 3

	-- Validate and fetch genders.
	local genders = args[1]
	local gender_list = rsplit(genders, "") -- split into individual characters
	for _, gender in ipairs(gender_list) do
		if gender ~= "m" and gender ~= "f" and gender ~= "n" then
			error("Unrecognized gender '" .. gender .. "' in gender spec '" .. genders .. "'")
		end
	end

	-- Get the pagename, stem and ending.
	local args_pagename
	if PAGENAME == "de-adj noun forms of" and not args.pagename then
		args_pagename = "Guten"
	else
		args_pagename = args.pagename
	end
	local pagename = args_pagename or PAGENAME

	local stem, ending = rmatch(pagename, "^(.*)(e[mnrs]?)$")
	if not stem then
		error("Pagename '" .. pagename .. "' should end with -e, -em, -en, -er or -es; use pagename= for testing purposes")
	end

	local parts = {}

	-- Generate text for each gender.
	for i, gender in ipairs(gender_list) do
		local lemma_ending
		if gender == "m" then
			lemma_ending = "er"
		elseif gender == "f" then
			lemma_ending = "e"
		elseif gender == "n" then
			lemma_ending = "es"
		else
			error("Internal error: Unrecognized gender '" .. gender .. "'")
		end

		if ending == lemma_ending then
			error("Pagename '" .. pagename .. "' is the lemma for gender '" .. gender .. "', but this template is " ..
				"intended for non-lemma forms")
		end
		local tags = noun_ending_tags[gender][ending]
		if not tags then
			error("Unrecognized ending '" .. ending .. "' for gender '" .. gender .. "'")
		end
		tags = table.concat(tags, "|;|")
		local lemma = stem .. lemma_ending

		local function add(text)
			table.insert(parts, text)
		end

		if i ~= 1 then
			add("\n\n")
		end
		if args.etymno then
			add(("===Etymology %s===\n{{nonlemma}}\n\n"):format(args.etymno + i - 1))
		end
		local indent = ("="):rep(level)
		add(("%sNoun%s\n"):format(indent, indent))
		local explicit_head = args_pagename and "|head=" .. args_pagename or ""
		add(("{{head|de|noun form%s|g=%s}}\n\n"):format(explicit_head, gender))
		add(("# {{inflection of|de|%s||%s}}"):format(lemma, tags))
	end

	return frame:preprocess(table.concat(parts))
end


return export
