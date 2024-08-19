local export = {}

local lang = require("Module:languages").getByCode("ar")
local sc = require("Module:scripts").getByCode("Arab")

local str_gsub = string.gsub
local ugsub = mw.ustring.gsub

local correspondences = {
	["ʾ"] = "ʔ",
	["ṯ"] = "θ",
	["j"] = "d͡ʒ",
	["ḥ"] = "ħ",
	["ḵ"] = "x",
	["ḏ"] = "ð",
	["š"] = "ʃ",
	["ṣ"] = "sˤ",
	["ḍ"] = "dˤ",
	["ṭ"] = "tˤ",
	["ẓ"] = "ðˤ",
	["ž"] = "ʒ",
	["ʿ"] = "ʕ",
	["ḡ"] = "ɣ",
	["ḷ"] = "ɫ",
	["ū"] = "uː",
	["ī"] = "iː",
	["ā"] = "aː",
	["y"] = "j",
	["g"] = "ɡ",
	["ē"] = "eː",
	["ō"] = "oː",
	[""] = "",
}

local vowels = "aāeēiīoōuū"
local vowel = "[" .. vowels .. "]"
local long_vowels = "āēīōū"
local long_vowel = "[" .. long_vowels .. "]"
local consonant = "[^" .. vowels .. ". -]"
local syllabify_pattern = "(" .. vowel .. ")(" .. consonant .. "?)(" .. consonant .. "?)(" .. vowel .. ")"
local tie = "‿"
local closed_syllable_shortening_pattern = "(" .. long_vowel .. ")(" .. tie .. ")" .. "(" .. consonant .. ")"

local function syllabify(text)
	text = ugsub(text, "%-(" .. consonant .. ")%-(" .. consonant .. ")", "%1.%2")
	text = str_gsub(text, "%-", ".")

	-- Add syllable breaks.
	for _ = 1, 2 do
		text = ugsub(
				text,
				syllabify_pattern,
				function(a, b, c, d)
					if c == "" and b ~= "" then
						c, b = b, ""
					end

					return a .. b .. "." .. c .. d
				end
		)
	end

	-- Add ties between word-final vowels and word-initial consonant clusters.
	text = ugsub(text, "(" .. vowel .. ") (" .. consonant .. ")%.?(" ..
			consonant .. ")", "%1" .. tie .. "%2.%3")

	return text
end

local function closed_syllable_shortening(text)
	local shorten = {
		["ā"] = "a",
		["ē"] = "e",
		["ī"] = "i",
		["ō"] = "o",
		["ū"] = "u",
	}

	text = ugsub(text,
			closed_syllable_shortening_pattern,
			function(vowel, tie, consonant)
				return shorten[vowel] .. tie .. consonant
			end)

	return text
end

function export.link(term)
	return require("Module:links").full_link { term = term, lang = lang, sc = sc }
end

function export.toIPA(list, silent_error)
	local translit

	if list.tr then
		translit = list.tr
	elseif list.Arabic then
		--	Returns an error if the word contains alphabetic characters that are not Arabic.
		require("Module:script utilities").checkScript(list.Arabic, "Arab")

		translit = lang:transliterate(list.Arabic)

		if not translit then
			if silent_error then
				return ''
			else
				error('Module:ar-translit failed to generate a transliteration from "' .. list.Arabic .. '".')
			end
		end
	else
		if silent_error then
			return ''
		else
			error('No Arabic text or transliteration was provided to the function "toIPA".')
		end
	end

	translit = str_gsub(translit, "llāh", "ḷḷāh")
	translit = ugsub(translit, "([iī] ?)ḷḷ", "%1ll")

	-- Remove the transliterations of any tāʾ marbūṭa not marked with a sukūn.
	translit = str_gsub(translit, "%(t%)", "")
	-- Prodelision after tāʾ marbūṭa
	translit = ugsub(translit, "(" .. vowel .. ") " .. vowel, "%1 ")
	
	translit = ugsub(translit, "%-?l%-?", "l")

	translit = syllabify(translit)
	translit = closed_syllable_shortening(translit)

	local output = ugsub(translit, ".", correspondences)

	output = str_gsub(output, "%-", "")

	return output
end

function export.show(frame)
	local params = {
		[1] = { list = true, allow_holes = true },
		["tr"] = { list = true, allow_holes = true },
		["qual"] = { list = true, allow_holes = true },
		["nl"] = {type = "boolean"},
		["ann"] = {},
	}

	local args = require("Module:parameters").process(frame:getParent().args, params)
	mw.logObject(args)
	local Arabic_words = args[1]
	local transliterations = args.tr
	local qualifiers = args.qual
	local nl = args.nl

	if not (Arabic_words.maxindex > 0 or transliterations.maxindex > 0) then
		if mw.title.getCurrentTitle().nsText == "Template" then
			Arabic_words[1] = "كَلِمَة"
			Arabic_words.maxindex = 1
		else
			error('Please provide vocalized Arabic in the first parameter of {{[[Template:ar-IPA|ar-IPA]]}}, or transliteration in the "tr" parameter.')
		end
	end

	local pronunciations = {}
	local function parameter(name)
		return "|" .. name .. "="
	end
	for i = 1, math.max(Arabic_words.maxindex, transliterations.maxindex) do
		local Arabic = Arabic_words[i]
		local tr = transliterations[i]
		local qual = qualifiers[i]

		if not (Arabic or tr) then
			error("There is a gap in the parameters. Provide either "
					.. parameter(i) .. " or " .. parameter("tr" .. i) .. ".")
		elseif Arabic and tr then
			mw.logObject("Duplicate parameters " .. parameter(i) .. " and "
					.. parameter("tr" .. i) .. " in {{ar-IPA}},")
		end

		-- Could check here that there isn ot
		local pron = export.toIPA { Arabic = Arabic, tr = tr }
		table.insert(pronunciations, { pron = "/" .. pron .. "/", qualifiers = { qual } })
	end

	local anntext
	if args.ann then
		anntext = args.ann
		if args.ann:find("%+") then
			local anndefs = {}
			for i = 1, math.max(Arabic_words.maxindex, transliterations.maxindex) do
				local Arabic = Arabic_words[i]
				if Arabic then
					table.insert(anndefs, "'''" .. Arabic .. "'''")
				end
			end
			if not anndefs[1] then
				error(("No Arabic-script respellings available for substitution into + in annotation '%s'"):format(
					args.ann))
			end
			anndefs = table.concat(anndefs, ", ")
			anntext = anntext:gsub("%+", require("Module:string utilities").replacement_escape(anndefs))
		end
		anntext = require("Module:qualifier").format_qualifier(anntext, "", "") .. ":&#32;"
	else
		anntext = ""
	end

	if nl then
		return anntext .. require("Module:IPA").format_IPA_multiple(lang, pronunciations)
	else
		return anntext .. require("Module:IPA").format_IPA_full { lang = lang, items = pronunciations }
	end
end

return export
