local export = {}

local rfind = mw.ustring.find
local rmatch = mw.ustring.match
local rsplit = mw.text.split
local u = mw.ustring.char
local TEMP0 = u(0xFFF0)

local th_pron_module = "Module:th-pron"
local string_utilities_module = "Module:string utilities"
local links_module = "Module:links"
local templateparser_module = "Module:templateparser"


local function fail(lang, request)
	local langObj, req, cat = require("Module:languages").getByCode(lang)
	if request then
		cat = {"Requests for transliteration of " .. langObj:getCanonicalName() .. " terms"}
	end
	return nil, true, cat
end

local thai_char_range = "ก-ฺเ-๎" -- U+0E01 through U+0E3A and U+0E40 through U+0E4E (skipping Bhat sign and Thai numerals)

local function translit_term(term)
	return require(th_pron_module).translit(term, "th", "Thai", "paiboon", "translit-module")
end


local function scrape_pronun(term)
	local title = mw.title.new(term)
	if title then
		local content = title:getContent()
		if content then
			local template_contents = content:match("{{th%-pron[^}]*}}")
			local pron
			if template_contents then
				local args_contents = content:match("{{th%-pron([^}]*)}}")
				if args_contents == "" then
					return term
				elseif args_contents:find("=") then
					local _, args = require(templateparser_module).parseTemplate(template_contents)
					pron = args[1]
				else
					pron = rsplit(args_contents, "|")[2]
				end
				pron = pron:gsub(":.*", "")
				return pron
			end
		end
	end

	return nil
end


local function scrape_and_translit_term(term)
	-- FIXME! Issue warning (in preview mode?) or error if respelling can't be found.
	local respelling = scrape_pronun(term) or term
	local translit = translit_term(respelling)
	-- error(term .. " || " .. respelling .. " || " .. translit)
	return translit, respelling
end


local function parse_brace_segment(segment)
	local inside = segment:match("^{ *(.-) *}$")
	if not inside then
		error(("Internal error: Can't match braces in brace-delimited segment %s"):format(segment))
	end
	local parts
	if inside:find("//") then
		parts = rsplit(inside, "//", true)
	else
		parts = rsplit(inside, "/", true)
	end
	if #parts ~= 2 then
		error(("Expected two slash-separated components in brace-delimited segment %s"):format(segment))
	end
	return unpack(parts)
end


local function process(text, fn)
	local left, right
	local scrape_and_translit, translit
	if fn == "links" then
		left = "[["
		right = "]]"
	else
		left = ""
		right = ""
	end
	if fn == "translit" then
		scrape_and_translit = scrape_and_translit_term
		translit = translit_term
	else
		scrape_and_translit = function(term) return term, term end
		translit = function(term) return term end
	end
	if not text then
		return text
	end
	local trimmed_text = text:match("^ *(.-) *$")
	if trimmed_text == "" then
		return text
	end
	text = trimmed_text

	if rfind(text, ("^[%s-]+$"):format(thai_char_range)) then
		-- Just Thai text -- a single term.
		return left .. scrape_and_translit(text) .. right
	end

	if rfind(text, ("^[%s -]+$"):format(thai_char_range)) then
		-- Just Thai text + spaces.
		local phrases = rsplit(text, "  +")
		local preceding_word
		for i, phrase in ipairs(phrases) do
			local words = rsplit(phrase, " ")
			for j, word in ipairs(words) do
				if word == "ๆ" and fn == "translit" then -- repetition marker 
					if not preceding_word then
						error(("Repetition mark ๆ cannot occur at the beginning of the sentence: %s"):format(text))
					end
					words[j] = translit(preceding_word) -- left and right are blank
					-- Leave preceding_word as-is in case of another repetition mark (can this occur?).
				else
					words[j], preceding_word = scrape_and_translit(word)
					words[j] = left .. words[j] .. right
				end
			end
			phrases[i] = table.concat(words, fn == "translit" and " " or "")
		end
		return table.concat(phrases, fn == "translit" and " • " or " ")
	end

	-- Numbers, brackets, braces, etc. may occur.
	local preceding_word
	local capturing_split = require(string_utilities_module).capturing_split
	local split_brackets = capturing_split(text, "(%[%[.-%]%])")
	for i, bracket_segment in ipairs(split_brackets) do
		if i % 2 == 1 then -- not a bracketed segment
			local split_braces = capturing_split(bracket_segment, "({.-})")
			for j, brace_segment in ipairs(split_braces) do
				if j % 2 == 1 then -- not a brace-delimited segment
					local words_and_delimiters = capturing_split(brace_segment, ("([%s-]+)"):format(thai_char_range))
					for k, word in ipairs(words_and_delimiters) do
						if k % 2 == 1 then -- outside of Thai word range
							if fn == "translit" then
								-- translit separators in case of Thai numerals
								words_and_delimiters[k] = translit_term(word)
							else
								-- Remove single spaces but convert double spaces to single
								word = word:gsub("  +", TEMP0)
								word = word:gsub(" ", "")
								word = word:gsub(TEMP0, " ")
								words_and_delimiters[k] = word
							end
						else
							if word == "ๆ" and fn == "translit" then -- repetition marker 
								if not preceding_word then
									error(("Repetition mark ๆ cannot occur at the beginning of the sentence: %s"):format(text))
								end
								words_and_delimiters[k] = translit(preceding_word) -- left and right are blank
								-- Leave preceding_word as-is in case of another repetition mark (can this occur?).
							else
								words_and_delimiters[k], preceding_word = scrape_and_translit(word)
								words_and_delimiters[k] = left .. words_and_delimiters[k] .. right
							end
						end
					end
					split_braces[j] = table.concat(words_and_delimiters)
				else -- a brace-delimited segment
					local from, to = parse_brace_segment(brace_segment)
					preceding_word = to
					if fn == "translit" then
						split_braces[j] = translit_term(to)
					else
						split_braces[j] = left .. from .. right
					end
				end
			end
			split_brackets[i] = table.concat(split_braces)
		else -- a bracketed segment
			if fn == "links" then
				split_brackets[i] = bracket_segment
				-- no need to set preceding_word; it isn't used except when fn == "translit"
			else
				local term = require(links_module).remove_links(bracket_segment)
				split_brackets[i], preceding_word = scrape_and_translit(term)
				-- no need to add left or right; they're blank
			end
		end
	end

	text = table.concat(split_brackets)
	if fn == "translit" then
		text = text:gsub("  +", " • ")
	end

	return text
end


function export.tr(text, lang, sc)
	return process(text, "translit")
end


function export.makeEntryName(text, lang, sc)
	return process(text, "entry")
end


function export.makeDisplayText(text, lang, sc)
	return process(text, "display")
end


function export.preprocessLinks(text, lang, sc)
	return process(text, "links")
end


function export.tr_template(frame)
	return export.tr(frame:getParent().args[1])
end


function export.makeEntryName_template(frame)
	return export.makeEntryName(frame:getParent().args[1])
end


function export.makeDisplayText_template(frame)
	return export.makeDisplayText(frame:getParent().args[1])
end


function export.preprocessLinks_template(frame)
	return export.preprocessLinks(frame:getParent().args[1])
end


return export
