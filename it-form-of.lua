-- This module implements {{it-compound of}}.
local export = {}

local m_table = require("Module:table")
local rmatch = mw.ustring.match

local lang = require("Module:languages").getByCode("it")

local force_cat = false -- for testing; if true, categories appear in non-mainspace pages

local function glossary_link(entry, text)
	text = text or entry
	return "[[Appendix:Glossary#" .. entry .. "|" .. text .. "]]"
end

local pronoun_suffixes = {
	"mi",
	"me",
	"ti",
	"te",
	"si",
	"se",
	"ci",
	"ce",
	"vi",
	"ve",
	"gli", -- must precede [[li]]
	"glie",
	"lo",
	"la",
	"li",
	"le",
	"ne",
}
local pronoun_suffix_set = m_table.listToSet(pronoun_suffixes)

local conjunctive_pronouns = {
	["me"] = "mi",
	["te"] = "ti",
	["se"] = "si",
	["ce"] = "ci",
	["ve"] = "vi",
	["glie"] = "gli",
}

local imp = glossary_link("imperative") .. " form"
local inf = glossary_link("infinitive")
local parts_of_speech = {
	["ger"] = glossary_link("gerund"),
	["inf"] = inf,
	["inf1s"] = "first-person singular ({{l|it|io}}) " .. inf,
	["inf2s"] = "second-person singular ({{l|it|tu}}) " .. inf,
	["inf1p"] = "first-person plural ({{l|it|noi}}) " .. inf,
	["inf2p"] = "second-person plural ({{l|it|voi}}) " .. inf,
	["imp2s"] = "second-person singular ({{l|it|tu}}) " .. imp,
	["imp1p"] = "first-person plural ({{l|it|noi}}) " .. imp,
	["imp2p"] = "second-person plural ({{l|it|voi}}) " .. imp,
}

local pp = glossary_link("past") .. " " .. glossary_link("participle")
local pres = glossary_link("present") .. " " .. glossary_link("indicative") .. " form"
local phis = glossary_link("past historic") .. " form"

local archaic_parts_of_speech = {
	["ppms"] = "masculine singular " .. pp,
	["ppfs"] = "feminine singular " .. pp,
	["ppmp"] = "masculine plural " .. pp,
	["ppfp"] = "feminine plural " .. pp,
	["presp"] = glossary_link("present") .. " " .. glossary_link("participle"),
	["pres1s"] = "first-person singular ({{l|it|io}}) " .. pres,
	["pres2s"] = "second-person singular ({{l|it|tu}}) " .. pres,
	["pres3s"] = "third-person singular ({{l|it|lui}}, {{l|it|lei}}) " .. pres,
	["pres1p"] = "first-person plural ({{l|it|noi}}) " .. pres,
	["pres2p"] = "first-person plural ({{l|it|voi}}) " .. pres,
	["pres3p"] = "first-person plural ({{l|it|loro}}) " .. pres,
	["phis1s"] = "first-person singular ({{l|it|io}}) " .. phis,
	["phis2s"] = "second-person singular ({{l|it|tu}}) " .. phis,
	["phis3s"] = "third-person singular ({{l|it|lui}}, {{l|it|lei}}) " .. phis,
	["phis1p"] = "first-person plural ({{l|it|noi}}) " .. phis,
	["phis2p"] = "first-person plural ({{l|it|voi}}) " .. phis,
	["phis3p"] = "first-person plural ({{l|it|loro}}) " .. phis,
}

-- The main entry point.
-- FIXME: Convert itprop to go through this.
function export.it_compound(frame)
	local params = {
		[1] = {list = true},
		["inf"] = {},
		["pos"] = {},
		["t"] = {},
		["gloss"] = {alias_of = "t"},
		["sort"] = {},
		["pagename"] = {}, -- for testing
	}

	local parargs = frame:getParent().args

	local args = require("Module:parameters").process(parargs, params)
	local curtitle = mw.title.getCurrentTitle()
	local pagename = args.pagename or curtitle.subpageText
	local base
	local prons = {}
	local suff = ""
	if #args[1] == 0 and not args.inf and not args.pos and curtitle.nsText == "Template"
		and curtitle.subpageText == "it-compound of" then
		pagename = "abbracciatela"
		args.pos = "imp2p"
		args.inf = "abbracciare"
	end
	if #args[1] > 0 then
		local ind
		if not pronoun_suffix_set[args[1][1]] then
			base = args[1][1]
			ind = 2
		else
			ind = 1
		end
		while ind <= #args[1] do
			if not pronoun_suffix_set[args[1][ind]] then
				error("Unrecognized pronoun suffix '" .. args[1][ind] .. "'")
			end
			table.insert(prons, args[1][ind])
			suff = suff .. args[1][ind]
			ind = ind + 1
		end
		if not base then
			base = rmatch(pagename, "^(.*)" .. suff .. "$")
			if not base and args.pos == "inf" and args.inf then
				-- [[adeguarvisi]], pron = [[vi]], inf/base = [[adeguarsi]]
				base = args.inf
			end
			if not base then
				error("Unable to extract base form from pagename " .. pagename .. "; pagename should end in '" .. suff .. "'")
			end
			if base:find("r$") then
				base = base .. "e"
			end
		end
	else
		for _, pronsuf in ipairs(pronoun_suffixes) do
			base = rmatch(pagename, "^(.*)" .. pronsuf .. "$")
			if base then
				table.insert(prons, pronsuf)
				break
			end
		end
		if not base then
			error("Unable to extract pronominal suffix from pagename " .. pagename)
		end
		if base:find("r$") then
			base = base .. "e"
		end
	end
	local pos = args.pos
	if pos then
		if not parts_of_speech[pos] and not archaic_parts_of_speech[pos] then
			error("Unrecognized part of speech '" .. pos .. "'")
		end
	else
		if base:find("ndo$") then
			pos = "ger"
		elseif base:find("re$") then
			pos = "inf"
		elseif base:find("mo$") then
			pos = "imp1p"
		else
			error("Unable to determine part of speech of base '" .. base .. "'")
		end
	end
	local inf = args.inf
	if not inf then
		if pos == "inf" then
			inf = base
		elseif pos:find("^inf") then
			inf = base:gsub("[mtcv]i$", "si")
		elseif pos == "ger" and base:find("ando$") then
			inf = base:gsub("ando$", "are")
		else
			error("With part of speech '" .. pos .. "', must specify infinitive using inf=")
		end
	end

	local parts = {}
	local posdesc = parts_of_speech[pos]
	local function ins(text)
		table.insert(parts, text)
	end
	if not posdesc then
		posdesc = archaic_parts_of_speech[pos]
		if not posdesc then
			error("Internal error: Unrecognized part of speech '" .. pos .. "'")
		end
		ins("{{tlb|it|archaic}} ")
	end
	table.insert(parts, "''compound of ")
	if pos == "inf" then
		ins("the infinitive '''{{m|it|" .. inf .. "}}'''")
	else
		ins("'''{{m|it|" .. base .. "}}''', the ")
		ins(posdesc .. " of '''{{m|it|" .. inf .. "}}''',")
	end
	ins(" with ")
	local pronparts = {}
	for _, pron in ipairs(prons) do
		if conjunctive_pronouns[pron] then
			table.insert(pronparts, "'''{{m|it|" .. pron .. "}}''' (the conjunctive variant of '''{{m|it|" .. conjunctive_pronouns[pron] .. "}}''')")
		else
			table.insert(pronparts, "'''{{m|it|" .. pron .. "}}'''")
		end
	end
	if #pronparts == 1 then
		ins(pronparts[1])
	else
		ins(m_table.serialCommaJoin(pronparts))
	end
	ins("''")
	if args.t then
		ins(" " .. require("Module:links").format_link_annotations({lang = lang, gloss = args.t}))
	end
	local desc = mw.getCurrentFrame():preprocess(table.concat(parts))
	return desc .. require("Module:utilities").format_categories({"Italian combined forms"}, lang, args.sort, nil, force_cat)
end

return export
