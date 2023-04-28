local export = {}

local lang = require("Module:languages").getByCode("fa")
local m_IPA = require("Module:IPA")
local m_table = require("Module:table")
local m_qual = require("Module:qualifier")

local u = mw.ustring.char
local rsplit = mw.text.split
local rsubn = mw.ustring.gsub
local ulen = mw.ustring.len

local AC = u(0x0301) -- acute =  ́
local GR = u(0x0300) -- grave =  ̀

local SYLDIV = u(0xFFF0) -- used to represent a user-specific syllable divider (.) so we won't change it
local vowels = "aiuāīūēō"
local V = "[" .. vowels .. "]"
local NV = "[^" .. vowels .. "]"
local accent = AC .. GR
local accent_c = "[" .. accent .. "]"
local ipa_stress = "`ˈˌ"
local ipa_stress_c = "[" .. ipa_stress .. "]"
local sylsep = "%-." .. SYLDIV -- hyphen included for syllabifying from spelling
local sylsep_c = "[" .. sylsep .. "]"
local wordsep = "# "
local separator_not_wordsep = accent .. ipa_stress .. sylsep
local separator = separator_not_wordsep .. wordsep
local separator_c = "[" .. separator .. "]"
local C = "[^" .. vowel .. separator .. "]" -- consonant class
local C_OR_WORDSEP = "[^" .. vowel .. separator_not_wordsep .. "]" -- consonant class, or word separator


-- version of rsubn() that discards all but the first return value
local function rsub(term, foo, bar)
	local retval = rsubn(term, foo, bar)
	return retval
end

export.all_styles = {"cls", "prs", "kbl", "fa", "teh", "tg"}
export.all_style_groups = {
	all = export.all_styles,
	cls = {"cls"},
	dari = {"prs", "kbl"},
	ir = {"fa", "teh"},
	tg = {"tg"}
}

export.all_style_descs = {
	cls = "Classical Persian",
	prs = "Dari Persian",
	kabul = "Kabuli",
	fa = "Iranian Persian",
	teh = "Tehrani",
	tg = "Tajik"
}

local function flatmap(items, fun)
	local new = {}
	for _, item in ipairs(items) do
		local results = fun(item)
		for _, result in ipairs(results) do
			table.insert(new, result)
		end
	end
	return new
end

local iranian_persian_short_vowels = {['a'] = 'æ', ['i'] = 'e', ['u'] = 'o'}

local iranian_persian_long_vowels = {
	['ā'] = 'ɒː',
	['ī'] = 'iː',
	['ū'] = 'uː',
	['ō'] = 'uː',
	['ē'] = 'iː'
}

local iranian_persian_consonants = {['ḏ'] = 'z', ['q'] = 'ɢ', ['ğ'] = 'ɢ'}

local dari_persian_short_vowels = {['a'] = 'a', ['i'] = 'ɪ', ['u'] = 'ʊ'}

local dari_persian_long_vowels = {
	['ā'] = 'ɑː',
	['ī'] = 'iː',
	['ū'] = 'uː',
	['ō'] = 'oː',
	['ē'] = 'eː'
}

local dari_persian_consonants = {['ḏ'] = 'z', ['v'] = 'w'}

local tajik_short_vowels = {['a'] = 'a', ['i'] = 'i', ['u'] = 'u'}

local tajik_long_vowels = {
	['ā'] = 'ɔ',
	['ī'] = 'i',
	['ū'] = 'u',
	['ō'] = 'ɵ',
	['ē'] = 'e'
}

local tajik_vowels = "aieuɵɔ"

local tajik_consonants = {['ḏ'] = 'z', ['w'] = 'v'}

local classical_persian_short_vowels = {['a'] = 'a', ['i'] = 'i', ['u'] = 'u'}

local classical_persian_long_vowels = {
	['ā'] = 'ɑː',
	['ī'] = 'iː',
	['ū'] = 'uː',
	['ō'] = 'oː',
	['ē'] = 'eː'
}

local classical_persian_consonants = {['ḏ'] = 'ð', ['v'] = 'w'}

local common_consonants = {
	['j'] = 'd͡ʒ',
	['\''] = 'ʔ',
	['ḍ'] = 'z',
	['ğ'] = 'ɣ',
	['ḥ'] = 'h',
	['r'] = 'ɾ',
	['ṣ'] = 's',
	['š'] = 'ʃ',
	['ṯ'] = 's',
	['ṭ'] = 't',
	['y'] = 'j',
	['ž'] = 'ʒ',
	['ẓ'] = 'z',
	['č'] = 't͡ʃ',
	['g'] = 'ɡ',
	['`'] = 'ˈ'
}

local function one_term_ipa(text, style)
	text = rsubn(text, "[.]", " ")
	text = rsubn(text, "[-]", "#DASH#")

	text = rsubn(text, " | ", "# | #")
	text = "##" .. rsubn(text, " ", "# #") .. "##"

	text = rsubn(text, "v", "w")
	if style == "cls" then
		-- Replace xwV with xʷV for certain vowels
		text = rsubn(text, "xw([aāē])", "xʷ%1")
	else
		text = rsubn(text, "xwa", "xu")
		text = rsubn(text, "xw([āē])", "x%1")
	end
	text = rsubn(text, "jj", "dj")
	text = rsubn(text, "čč", "tč")

	if style == "fa" or style == "teh" then
		-- Replace diphthong
		text = rsubn(text, "a([wy])(" .. C_OR_WORDSEP .. ")", function(semivowel, after)
			if semivowel == "w" then
				return "uw" .. after
			else
				return "ey" .. after
			end
		end)
		-- Replace iy with Ey to protect it from the following changes; later we undo it
		text = rsubn(text, "iy", "Ey")
		-- Replace w with v before vowels
		text = rsubn(text, "w([" .. vowels .. "])", "v%1")
		-- Replace final w with v after a consonant; final w after a vowel remains (v -> w above)
		text = rsubn(text, "(" .. consonants .. ")w#", "%1v#")
		-- Replace short vowels
		text = rsubn(text, ".", iranian_persian_short_vowels)
		-- Replace long vowels
		text = rsubn(text, ".", iranian_persian_long_vowels)
		text = rsubn(text, "Ey", "iy")
		text = rsubn(text, "æ#", "e#")
		-- Replace consonants
		text = rsubn(text, ".", iranian_persian_consonants)
	elseif style == "prs" or style == "kab" then
		-- Replace short vowels
		text = rsubn(text, ".", dari_persian_short_vowels)
		-- Replace long vowels
		text = rsubn(text, ".", dari_persian_long_vowels)
		-- Replace consonants
		text = rsubn(text, ".", dari_persian_consonants)
	elseif style == "tg" then
		-- Replace ih, īh, i\', ī\' by ēh, ē\'
		text = rsubn(text, "[iī]([hʔ])([^" .. vowels .. "])", "ē%1%2")
		-- Replace uh, ūh, u\', ū\' by ɵh, ɵ\'
		text = rsubn(text, "[uū]([hʔ])([^" .. vowels .. "])", "ō%1%2")
		-- Replace short vowels
		text = rsubn(text, ".", tajik_short_vowels)
		-- Replace long vowels
		text = rsubn(text, ".", tajik_long_vowels)
		text = rsubn(text, ".", tajik_consonants)
	elseif style == "cls" then
		-- Replace d with ḏ after vowels
		text = rsubn(text, "([" .. vowels .. "]+`?)d", "%1ḏ")
		-- Replace short vowels
		text = rsubn(text, ".", classical_persian_short_vowels)
		-- Replace long vowels
		text = rsubn(text, ".", classical_persian_long_vowels)
		-- Replace consonants
		text = rsubn(text, ".", classical_persian_consonants)
	else
		error("Internal error: Unrecognized style '" .. style .. "'")
	end

	text = rsubn(text, ".", common_consonants)

	if style == "teh" then
		text = rsubn(
	end

	text = rsubn(text, "#DASH#", "")
	text = rsubn(text, "#", "")

	return text
end

-- style == one of the following:
-- "cls": Classical Persian
-- "prs": Dari Persian
-- "kbl": Kabuli
-- "fa": Iranian Persian
-- "teh": Tehrani
-- "tg": Tajik
function export.IPA(text, style)

	local variants = {text}

	local function call_one_term_ipa(variant)
		local result = {{
			phonemic = one_term_ipa(variant, style, false, err),
		}}
		return result
	end

	return flatmap(variants, call_one_term_ipa)
end

function export.express_styles(inputs, args_style)
	local pronuns_by_style = {}
	local expressed_styles = {}

	local function dostyle(style)
		pronuns_by_style[style] = {}
		for _, val in ipairs(inputs[style]) do
			local pronuns = export.IPA(val, style)
			for _, pronun in ipairs(pronuns) do
				table.insert(pronuns_by_style[style], pronun)
			end
		end
	end

	local function all_available(styles)
		local available_styles = {}
		for _, style in ipairs(styles) do
			if pronuns_by_style[style] then
				table.insert(available_styles, style)
			end
		end
		return available_styles
	end

	local function express_style(hidden_tag, tag, styles, indent)
		indent = indent or 1
		if hidden_tag == true then
			hidden_tag = tag
		end
		if type(styles) == "string" then
			styles = {styles}
		end
		styles = all_available(styles)
		if #styles == 0 then
			return
		end
		local style = styles[1]

		-- If style specified, make sure it matches the requested style.
		local style_matches
		if not args_style then
			style_matches = true
		else
			local or_styles = rsplit(args_style, "%s*,%s*")
			for _, or_style in ipairs(or_styles) do
				local and_styles = rsplit(or_style, "%s*%+%s*")
				local and_matches = true
				for _, and_style in ipairs(and_styles) do
					local negate
					if and_style:find("^%-") then
						and_style = and_style:gsub("^%-", "")
						negate = true
					end
					local this_style_matches = false
					for _, part in ipairs(styles) do
						if part == and_style then
							this_style_matches = true
							break
						end
					end
					if negate then
						this_style_matches = not this_style_matches
					end
					if not this_style_matches then
						and_matches = false
					end
				end
				if and_matches then
					style_matches = true
					break
				end
			end
		end
		if not style_matches then
			return
		end

		local new_style = {
			tag = tag,
			represented_styles = styles,
			pronuns = pronuns_by_style[style],
			indent = indent,
		}
		for _, hidden_tag_style in ipairs(expressed_styles) do
			if hidden_tag_style.tag == hidden_tag then
				table.insert(hidden_tag_style.styles, new_style)
				return
			end
		end
		table.insert(expressed_styles, {
			tag = hidden_tag,
			styles = {new_style},
		})
	end

	for style, _ in pairs(inputs) do
		dostyle(style)
	end

	local function diff(style1, style2)
		if not pronuns_by_style[style1] or not pronuns_by_style[style2] then
			return true
		end
		return not m_table.deepEquals(pronuns_by_style[style1], pronuns_by_style[style2])
	end

	local fa_teh_different = diff("fa", "teh")
	local prs_kbl_different = diff("prs", "kbl")

	-- Classical Persian
	express_style("[[w:Classical Persian|Classical Persian]]",
				  "[[w:Classical Persian|Classical Persian]]", "cls")

	-- Dari Persian
	express_style("[[w:Dari Persian|Dari Persian]]",
				  "[[w:Dari Persian|Dari Persian]]", "prs")
	if prs_kbl_different then
		express_style("[[w:Dari Persian|Dari Persian]]", "Kabuli", "kbl", 2)
	end

	-- Iranian Persian
	express_style("[[w:Iranian Persian|Iranian Persian]]",
				  "[[w:Iranian Persian|Iranian Persian]]", "fa")
	if fa_teh_different then
		express_style("[[w:Iranian Persian|Iranian Persian]]", "[[w:Tehrani accent|Tehrani]]", "teh",
					  2)
	end

	-- Tajik
	express_style("[[w:Tajik language|Tajik language]]",
				  "[[w:Tajik language|Tajik]]", "tg")

	return expressed_styles
end

function export.show(frame)
	-- Create parameter specs
	local params = {
		[1] = {}, -- this replaces style group 'all'
		["pre"] = {},
		["post"] = {},
		["ref"] = {},
		["style"] = {},
		["bullets"] = {type = "number", default = 1},
	}
	for group, _ in pairs(export.all_style_groups) do
		if group ~= "all" then
			params[group] = {}
		end
	end
	for _, style in ipairs(export.all_styles) do
		params[style] = {}
	end

	-- Parse arguments
	local parargs = frame:getParent().args
	local args = require("Module:parameters").process(parargs, params)

	-- Set inputs
	local inputs = {}
	-- If 1= specified, do all styles.
	if args[1] then
		for _, style in ipairs(export.all_styles) do
			inputs[style] = args[1]
		end
	end
	-- Then do remaining style groups other than 'all', overriding 1= if given.
	for group, styles in pairs(export.all_style_groups) do
		if group ~= "all" and args[group] then
			for _, style in ipairs(styles) do
				inputs[style] = args[group]
			end
		end
	end
	-- Then do individual style settings.
	for _, style in ipairs(export.all_styles) do
		if args[style] then
			inputs[style] = args[style]
		end
	end
	-- If no inputs given, set all styles based on current pagename.
	if not next(inputs) then
		local text = mw.title.getCurrentTitle().text
		for _, style in ipairs(export.all_styles) do
			inputs[style] = text
		end
	end

	for style, input in pairs(inputs) do
		inputs[style] = rsplit(input, ",")
	end
	local expressed_styles = export.express_styles(inputs, args.style)

	local lines = {}

	local function format_style(tag, expressed_style, is_first)
		local pronunciations = {}
		local formatted_pronuns = {}
		for _, pronun in ipairs(expressed_style.pronuns) do
			table.insert(pronunciations, {
				pron = "/" .. pronun.phonemic .. "/",
				qualifiers = pronun.qualifiers,
			})
			local formatted_phonemic = "/" .. pronun.phonemic .. "/"
			if pronun.qualifiers then
				formatted_phonemic = "(" .. table.concat(pronun.qualifiers, ", ") .. ") " .. formatted_phonemic
			end
			table.insert(formatted_pronuns, formatted_phonemic)
		end
		-- Number of bullets: When indent = 1, we want the number of bullets given by `args.bullets`,
		-- and when indent = 2, we want `args.bullets + 1`, hence we subtract 1.
		local bullet = string.rep("*", args.bullets + expressed_style.indent - 1) .. " "
		-- Here we construct the formatted line in `formatted`, and also try to construct the equivalent without HTML
		-- and wiki markup in `formatted_for_len`, so we can compute the approximate textual length for use in sizing
		-- the toggle box with the "more" button on the right.
		local pre = is_first and args.pre and args.pre .. " " or ""
		local pre_for_len = pre .. (tag and "(" .. tag .. ") " or "")
		pre = pre .. (tag and m_qual.format_qualifier(tag) .. " " or "")
		local post = is_first and (args.ref or "") .. (args.post and " " .. args.post or "") or ""
		local formatted = bullet .. pre .. m_IPA.format_IPA_full(lang, pronunciations) .. post
		local formatted_for_len = bullet .. pre .. "IPA(key): " .. table.concat(formatted_pronuns, ", ") .. post
		return formatted, formatted_for_len
	end

	for i, style_group in ipairs(expressed_styles) do
		if #style_group.styles == 1 then
			style_group.formatted, style_group.formatted_for_len =
				format_style(style_group.styles[1].tag, style_group.styles[1], i == 1)
		else
			style_group.formatted, style_group.formatted_for_len =
				format_style(style_group.tag, style_group.styles[1], i == 1)
			for j, style in ipairs(style_group.styles) do
				style.formatted, style.formatted_for_len =
					format_style(style.tag, style, i == 1 and j == 1)
			end
		end
	end

	local function textual_len(text)
		text = rsub(text, "<.->", "")
		return ulen(text)
	end

	local maxlen = 0
	for i, style_group in ipairs(expressed_styles) do
		local this_len = textual_len(style_group.formatted_for_len)
		if #style_group.styles > 1 then
			for _, style in ipairs(style_group.styles) do
				this_len = math.max(this_len, textual_len(style.formatted_for_len))
			end
		end
		maxlen = math.max(maxlen, this_len)
	end

	for i, style_group in ipairs(expressed_styles) do
		if #style_group.styles == 1 then
			table.insert(lines, "<div>\n" .. style_group.formatted .. "</div>")
		else
			local inline = '\n<div class="vsShow" style="display:none">\n' .. style_group.formatted .. "</div>"
			local full_prons = {}
			for _, style in ipairs(style_group.styles) do
				table.insert(full_prons, style.formatted)
			end
			local full = '\n<div class="vsHide">\n' .. table.concat(full_prons, "\n") .. "</div>"
			local em_length = math.floor(maxlen * 0.68) -- from [[Module:grc-pronunciation]]
			table.insert(lines, '<div class="vsSwitcher" data-toggle-category="pronunciations" style="width: ' .. em_length .. 'em; max-width:100%;"><span class="vsToggleElement" style="float: right;">&nbsp;</span>' .. inline .. full .. "</div>")
		end
	end

	-- major hack to get bullets working on the next line
	return table.concat(lines, "\n") .. "\n<span></span>"
end

return export
