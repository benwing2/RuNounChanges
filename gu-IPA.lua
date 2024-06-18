local export = {}

local lang = require("Module:languages").getByCode("gu")
local sc = require("Module:scripts").getByCode("Gujr")
local m_IPA = require("Module:IPA")

local u = require("Module:string/char")
local ufind = mw.ustring.find
local ugmatch = mw.ustring.gmatch
local ugsub = mw.ustring.gsub

local correspondences = {
    ["ṅ"] = "ŋ", ["g"] = "ɡ", 
    ["c"] = "t͡ʃ", ["j"] = "d͡ʒ", ["ñ"] = "ɲ",
    ["ṭ"] = "ʈ", ["ḍ"] = "ɖ", ["ṇ"] = "ɳ",
    ["t"] = "t̪", ["d"] = "d̪",
    ["y"] = "j", ["r"] = "ɾ", ["v"] = "ʋ", ["l"] = "l̪",
    ["ś"] = "ʃ", ["ṣ"] = "ʂ", ["h"] = "ɦ",
    ["ḷ"] = "ɭ", ["f"] = "f", ["ġ"] = "ɣ", ["ḏ"] = "ð", ["ḇ"] = "β", 
    ["ṛ"] = "ɽ",

    ["a"] = "ə", ["ā"] = "ɑ", ["i"] = "ɪ",
    ["ī"] = "i", ["o"] = "o", ["e"] = "eː", ["ŕ"] = "ɾʊ",
    ["u"] = "u", ["ū"] = "u", ["ŏ"] = "ɔ", ["ɔ"] = "ɔ", ["ě"] = "ɛ", ["â"] = "æ",
    ["ä"] = "ə̤", ["ǟ"] = "a̤", ["ï"] = "i̤", ["ü"] = "ṳ",  ["ë"] = "ɛ̤", ["ö"] = "ɔ̤", 
    ["ॐ"] = "om", ["ḥ"] = "ʰ",
    [" "] = "‿ˈ", -- get rid of spaces
}

local vowels = "aāiīuūoɔɛeæãā̃ẽĩī̃õũū̃ː"
local weak_h = "([gjdḍbṛnmaãāā̃eẽiĩīī̃uũūū̃oõː])h"
local aspirate = "([kctṭp])"
local syllabify_pattern = "([" .. vowels .. "])([^" .. vowels .. "%.]+)([" .. vowels .. "])"

local function find_consonants(text)
	local current = ""
	local cons = {}
	for cc in mw.ustring.gcodepoint(text .. " ") do
		local ch = u(cc)
		if ufind(current .. ch, "^[kgṅcjñṭḍṇtdnpbmyrlvśṣsh]$") or ufind(current .. ch, "^[kgcjṭḍṇtdpb]h$") then
			current = current .. ch
		else
			table.insert(cons, current)
			current = ch
		end
	end
	return cons
end

local function syllabify(text)
	for count = 1, 2 do
		text = ugsub(text, syllabify_pattern, function(a, b, c)
			b_set = find_consonants(b)
			table.insert(b_set, #b_set > 1 and 2 or 1, ".")
			return a .. table.concat(b_set) .. c end)
	end
	return text
end

local identical = "knlsfzθ"
for character in ugmatch(identical, ".") do
	correspondences[character] = character
end

local function transliterate(text)
	return (lang:transliterate(text))
end

function export.link(term)
	return require("Module:links").full_link{ term = term, lang = lang, sc = sc }
end

function export.toIPA(text)
	local result = {}
	local translit = text
	if lang:findBestScript(text):isTransliterated() then
		translit = transliterate(text)
	end
	if not translit then
		error('The term "' .. text .. '" could not be transliterated.')
	end
	
	local translit = ugsub(translit, "͠", "̃")
	local translit = ugsub(translit, "%-", ".")
	local translit = ugsub(translit, "ṣ([^ṭḍ])", "ś%1")
	
    local translit = syllabify(translit)
    local translit = ugsub(translit, 'jñ', 'gy')
    local translit = ugsub(translit, aspirate .. "h", '%1ʰ')
    local translit = ugsub(translit, weak_h, '%1ʱ')
	local translit = ugsub(translit, "%.ː", "ː.")
	
	for character in ugmatch(translit, ".") do
		table.insert(result, correspondences[character] or character)
	end
	
	result = table.concat(result)
	local result = ugsub(result, "ː̃", "̃ː")

	result = ugsub(result, "%.‿", "‿")
    
	return "ˈ" .. result
end

function export.make(frame)
	local args = frame:getParent().args
	local pagetitle = mw.title.getCurrentTitle().text
	
	local p, results = {}, {}
	
	if args[1] then
		for index, item in ipairs(args) do
			table.insert(p, (item ~= "") and item or nil)
		end
	else
		p = { pagetitle }
	end
	
	for _, Gujarati in ipairs(p) do
		table.insert(results, export.toIPA(Gujarati))
	end
	
	return m_IPA.format_IPA_full { lang = lang, items = {{ pron = "/" .. table.concat(results, "/, /") .. "/" }} }
end

return export
