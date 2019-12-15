--[=[

Common utilities and definitions used by various Old English modules.

Author: Benwing
]=]

local m_table = require("Module:table")

local u = mw.ustring.char
local rsubn = mw.ustring.gsub

-- version of rsubn() that discards all but the first return value
local function rsub(term, foo, bar, n)
	local retval = rsubn(term, foo, bar, n)
	return retval
end

local export = {}

export.ACUTE = u(0x0301)
export.GRAVE = u(0x0300)
export.CFLEX = u(0x0302)
export.MACRON = u(0x0304)
export.DOTABOVE = u(0x0307)
export.SYLLABIC = u(0x0329)
export.DOUBLE_BREVE_BELOW = u(0x035C)

local accent = export.MACRON .. export.ACUTE .. export.GRAVE .. export.CFLEX

local recomposer = {
	["g" .. export.DOTABOVE] = "ġ",
	["G" .. export.DOTABOVE] = "Ġ",
	["c" .. export.DOTABOVE] = "ċ",
	["C" .. export.DOTABOVE] = "Ċ",
}

-- Decompose macron, acute, grave, circumflex, but leave alone ġ, ċ and uppercase equiv
function export.decompose(text)
	text = mw.ustring.toNFD(text)
	text = rsub(text, ".[" .. export.DOTABOVE .. "]", recomposer)
	return text
end

-- We use the following syllable-splitting algorithm.
-- (1) A single consonant goes with the following syllable.
-- (2) Two consonants are split down the middle.
-- (3) For three or more consonants, check for clusters ending in
--     onsets_3 then onsets_2, with at least one preceding consonant.
--     If so, split between the onset and the preceding consonant(s).
-- (4) Check similarly for secondary_onsets_2. If seen, then check
--     the preceding consonant; if it's not an l or r, split before
--     the onset.
-- (5) Otherwise, split before the last consonant (i.e. the last
--     consonant goes with the following syllable, and all preceding
--     consonants go with the preceding syllable).
export.onsets_2 = m_table.listToSet({
	"pr", "pl",
	"br", "bl",
	"tr", "tw",
	"dr", "dw",
	"cr", "cl", "cw", --skip "cn"
	"kr", "kl", "kw", --skip "kn"
	"gr", "gl", -- skip "gn"
	"sm", "sn", "sl", "sw",
	"sp",
	"st",
	"sc", "sk", "sċ",
	"fr", "fl", --skip "fn",
	"þr", "þw",
	"ðr", "ðw",
	"hr", "hl", "hw", -- skip "hn"
	"wr", "wl",
})

export.secondary_onsets_2 = m_table.listToSet({
	"cn", "kn",
	"gn",
	"fn",
	"hn",
})

export.onsets_3 = m_table.listToSet({
	"spr", "spl",
	"str",
	"scr", "skr", "sċr",
})

export.diphthongs = m_table.listToSet({
	"ea", export.decompose("ēa"), export.decompose("eā"),
	"eo", export.decompose("ēo"), export.decompose("eō"),
	"io", export.decompose("īo"), export.decompose("iō"),
	"ie", export.decompose("īe"), export.decompose("iē"),
})

export.prefixes = {
	{export.decompose("ā"), {verb = "unstressed", noun = "stressed"}},
	{"æt", {verb = "unstressed"}},
	{"æfter", {verb = "secstressed", noun = "stressed"}}, -- not very common
	{"and", {verb = "unstressed", noun = "stressed"}},
	{"an", {verb = "unstressed", noun = "stressed"}},
	{"be", {verb = "unstressed", noun = "unstressed", restriction = "^[^" .. accent .. "ao]"}},
	{export.decompose("bī"), {noun = "stressed"}},
	{"ed", {verb = "unstressed", noun = "stressed"}}, -- not very common
	{"fore", {verb = "unstressed", noun = "stressed", restriction = "^[^" .. accent .. "ao]"}},
	{"for[þð]", {verb = "unstressed", noun = "stressed"}},
	{"for", {verb = "unstressed", noun = "unstressed"}},
	{"fram", {verb = "unstressed", noun = "stressed"}}, -- not very common
	-- following is rare as a noun, mostly from verbal forms
	{"ġeond", {verb = "unstressed"}}, 
	{"ġe", {verb = "unstressed", noun = "unstressed", restriction = "^[^" .. accent .. "ao]"}},
	{"in", {verb = "unstressed", noun = "stressed"}}, -- not very common
	{"mis", {verb = "unstressed"}},
	{"ofer", {verb = "secstressed", noun = "stressed"}},
	{"of", {verb = "unstressed", noun = "stressed"}},
	{"on", {verb = "unstressed", noun = "stressed"}},
	{"or", {noun = "stressed"}},
	{"o[þð]", {verb = "unstressed"}},
	{export.decompose("stēop"), {noun = "stressed"}},
	{export.decompose("tō"), {verb = "unstressed", noun = "stressed"}},
	{"under", {verb = "secstressed", noun = "stressed"}},
	{"un", {verb = "secstressed", noun = "stressed"}}, -- uncommon as verb
	{"up", {verb = "unstressed", noun = "stressed"}},
	{export.decompose("ūt"), {verb = "unstressed", noun = "stressed"}},
	{export.decompose("ū[þð]"), {noun = "stressed"}},
	{"[wƿ]i[þð]er", {verb = "secstressed", noun = "stressed"}},
	{"[wƿ]i[þð]", {verb = "unstressed"}},
	{"ymb", {verb = "unstressed", noun = "stressed"}},
	{"[þð]urh", {verb = "unstressed", noun = "stressed"}},
}

export.suffixes = {
	{"bǣre", {noun = "secstressed"}},
	{"fæst", {noun = "secstressed"}},
	{"feald", {noun = "secstressed"}},
	{"full?", {noun = "unstressed"}},
	{"lēas", {noun = "secstressed"}},
	-- These can be "verbal" if following a verbal past participle or similar
	{"l[īi][ċc]", {noun = "unstressed", verb = "unstressed"}},
	{"ness?", {noun = "unstressed", verb = "unstressed"}},
	{"n[iy]s", {noun = "unstressed", verb = "unstressed"}},
	{"sum", {noun = "unstressed"}},
}

return export
