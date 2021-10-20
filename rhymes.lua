local export = {}

local function tag_rhyme(rhyme, lang)
	local formatted_rhyme, cat
	-- FIXME, should not be here. Telugu should use IPA as well.
	if lang:getCode() == "te" then
		formatted_rhyme = require("Module:script utilities").tag_text(rhyme, lang)
		cat = ""
	else
		formatted_rhyme, cat = require("Module:IPA").format_IPA(lang, rhyme, true)
	end
	return formatted_rhyme, cat
end

local function make_rhyme_link(lang, link_rhyme, display_rhyme)
	if not link_rhyme then
		return table.concat{"[[Rhymes:", lang:getCanonicalName(), "|", lang:getCanonicalName(), "]]"}
	else
		local formatted_rhyme, cat = tag_rhyme(display_rhyme or link_rhyme, lang)

		return table.concat{"[[Rhymes:", lang:getCanonicalName(), "/", link_rhyme, "|", formatted_rhyme, "]]", cat}
	end
end

function export.show_row(frame)
	local params = {
		[1] = {required = true},
		[2] = {required = true},
		[3] = {},
	}

	local args = frame.getParent and frame:getParent().args or frame

	if (not args[1] or args[1] == "") and mw.title.getCurrentTitle().nsText == "Template" then
		return '[[Rhymes:English/aɪmz|<span class="IPA">-aɪmz</span>]]'
	end

	local args = require("Module:parameters").process(args, params)
	local lang = require("Module:languages").getByCode(args[1]) or require("Module:languages").err(args[1], 1)

	return make_rhyme_link(lang, args[2], "-" .. args[2]) .. (args[3] and (" (''" .. args[3] .. "'')") or "")
end

local function add_syllable_categories(categories, lang, rhyme, num_syl)
	local prefix = "Rhymes:" .. lang .. "/" .. rhyme
	table.insert(categories, "[[Category:" .. prefix .. "]]")
	if num_syl then
		for _, n in ipairs(num_syl) do
			local c
			if n > 1 then
				c = prefix .. "/" .. n .. " syllables"
			else
				c = prefix .. "/1 syllable"
			end
			table.insert(categories, "[[Category:" .. c .. "]]")
		end
	end
end

-- Meant to be called from a module. `data` should contain the following fields:
--   lang: Language object.
--   rhymes: List of rhymes to display. Each rhyme is an object with fields `rhyme` (the IPA rhyme, without initial
--           hyphen) and optionally `num_syl` (if non-nil, a list of the number(s) of syllables of the word with
--           this rhyme).
--   qualifiers: If non-nil, a list of qualifiers to display after the caption and before the rhymes.
--   num_syl: If non-nil, a list of the number(s) of syllables of the word with each rhyme specified in `rhymes`.
--            This applies to all rhymes specified in `rhymes`, while the corresponding `num_syl` attached to an
--            individual rhyme applies only to that rhyme (and overrides the global `num_syl`, if both are given).
--
-- Note that the number of syllables is currently used only for categorization; if present, an extra category will
-- be added such as [[Rhymes:Italian/ino/3 syllables]] in addition to [[Rhymes:Italian/ino]].
function export.format_rhymes(data)
	local langname = data.lang:getCanonicalName()
	local links = {}
	local categories = {}
	for i, r in ipairs(data.rhymes) do
		local rhyme = r.rhyme
		table.insert(links, make_rhyme_link(lang, rhyme, "-" .. rhyme))
		add_syllable_categories(categories, langname, rhyme, rhyme.num_syl or data.num_syl)
	end

	local ret = "Rhymes: "
	if data.qualifiers and data.qualifiers[1] then
		ret = require("Module:qualifier").format_qualifier(data.qualifiers) .. " " .. ret
	end
	return ret .. table.concat(links, ", ") .. (mw.title.getCurrentTitle().namespace == 0 and table.concat(categories) or "")
end

function export.show(frame)
	local args = frame.getParent and frame:getParent().args or frame
	local compat = args["lang"]
	local offset = compat and 0 or 1

	local params = {
		[1 + offset] = {required = true, list = true},
		[compat and "lang" or 1] = {required = true},
		["s"] = {},
		["srhymes"] = {list = "s", allow_holes = true, require_index = true},
	}

	if (not args[1 + offset] or args[1 + offset] == "") and mw.title.getCurrentTitle().nsText == "Template" then
		return 'Rhymes: [[Rhymes:English/aɪmz|<span class="IPA">-aɪmz</span>]]'
	end

	local args = require("Module:parameters").process(args, params)
	local lang = args[compat and "lang" or 1]
	lang = require("Module:languages").getByCode(lang) or require("Module:languages").err(lang, compat and "lang" or 1)

	local function parse_num_syl(val)
		val = mw.text.split(val, "%s*,%s*")
		local ret = {}
		for _, v in ipairs(val) do
			local n = tonumber(v) or error("Unrecognized #syllables '" .. v .. "', should be a number")
			table.insert(ret, n)
		end
		return ret
	end

	local rhymes = {}
	for i, rhyme in ipairs(args[1 + offset]) do
		local rhymeobj = {rhyme = rhyme}
		if args.srhymes[i] then
			rhymeobj.num_syl = parse_num_syl(args.srhymes[i])
		end
	end

	return export.format_rhymes {
		lang = lang,
		rhymes = rhymes,
		num_syl = parse_num_syl(args.s),
	}
end

-- {{rhymes nav}}
function export.show_nav(frame)
	-- Gather parameters
	local args = frame:getParent().args
	local lang = args[1] or (mw.title.getCurrentTitle().nsText == "Template" and "und") or error("Language code has not been specified. Please pass parameter 1 to the template.")
	lang = require("Module:languages").getByCode(lang) or require("Module:languages").err(lang, 1)

	local parts = {}
	local i = 2

	while args[i] do
		local part = args[i]; if part == "" then part = nil end
		table.insert(parts, part)
		i = i + 1
	end

	-- Create steps
	local steps = {"» [[Wiktionary:Rhymes|Rhymes]]", "» " .. make_rhyme_link(lang)}
	local categories = {}

	if #parts > 0 then
		local last = parts[#parts]
		parts[#parts] = nil
		local prefix = ""

		for i, part in ipairs(parts) do
			prefix = prefix .. part
			parts[i] = prefix
		end

		for _, part in ipairs(parts) do
			table.insert(steps, "» " .. make_rhyme_link(lang, part .. "-", "-" .. part .. "-"))
		end

		if last == "-" then
			table.insert(steps, "» " .. make_rhyme_link(lang, prefix, "-" .. prefix))
			table.insert(categories, "[[Category:" .. lang:getCanonicalName() .. " rhymes" .. (prefix == "" and "" or "/" .. prefix .. "-") .. "| ]]")
		elseif mw.title.getCurrentTitle().text == lang:getCanonicalName() .. "/" .. prefix .. last .. "-" then
			table.insert(steps, "» " .. make_rhyme_link(lang, prefix .. last .. "-", "-" .. prefix .. last .. "-"))
			table.insert(categories, "[[Category:" .. lang:getCanonicalName() .. " rhymes/" .. prefix .. last .. "-|-]]")
		else
			table.insert(steps, "» " .. make_rhyme_link(lang, prefix .. last, "-" .. prefix .. last))
			table.insert(categories, "[[Category:" .. lang:getCanonicalName() .. " rhymes" .. (prefix == "" and "" or "/" .. prefix .. "-") .. "|" .. last .. "]]")
		end
	elseif lang:getCode() ~= "und" then
		table.insert(categories, "[[Category:" .. lang:getCanonicalName() .. " rhymes| ]]")
	end

	frame:callParserFunction("DISPLAYTITLE",
		mw.title.getCurrentTitle().fullText:gsub(
			"/(.+)$",
			function (rhyme)
				return "/" .. tag_rhyme(rhyme, lang)
			end))

	return table.concat(steps, " ") .. table.concat(categories)
end

return export
