local export = {}

local pagename -- generated when needed, to avoid an infinite loop with [[Module:Jpan-sortkey]]
local namespace = mw.title.getCurrentTitle().nsText

local codepoint = require("Module:string/codepoint")
local concat = table.concat
local find = mw.ustring.find
local get_by_code = require("Module:languages").getByCode
local gsub = mw.ustring.gsub
local insert = table.insert
local len = mw.ustring.len
local load_data = mw.loadData
local sub = mw.ustring.sub
local toNFC = mw.ustring.toNFC
local toNFD = mw.ustring.toNFD
local u = require("Module:string/char")

-- note that arrays loaded by mw.loadData cannot be directly used by gsub
local data = load_data("Module:ja/data")
local long_vowel = data.long_vowel
local iter_marks = data.iter_marks
local voice_marks = data.voice_marks
local specials = data.specials
local range = load_data("Module:ja/data/range")

export.data = {
	joyo_kanji = data.joyo_kanji,
	jinmeiyo_kanji = data.jinmeiyo_kanji,
	grade1 = data.grade1,
	grade2 = data.grade2,
	grade3 = data.grade3,
	grade4 = data.grade4,
	grade5 = data.grade5,
	grade6 = data.grade6
}

local function change_codepoint(added_value)
	return function(char)
		return u(codepoint(char) + added_value)
	end
end

-- Normalizes long vowels, iteration marks and non-combining voice marks to the standard equivalents.
-- Note: output text is normalized to NFD.
function export.normalize_kana(text)
	text = toNFD(text)
	
	local chars, text_len = {}, #text
	local i, c, end_c, from, b = 0
	while i < text_len do
		i = i + 1
		c = text:sub(i, i)
		if c == "<" then
			from = i
			repeat
				i = i + 1
				end_c = text:sub(i, i)
				if end_c == ">" then
					insert(chars, text:sub(from, i))
					break
				elseif i == text_len then
					i = from
					insert(chars, c)
					break
				end
			until false
		else
			b = c:byte()
			if b <= 127 then
				insert(chars, c)
			else
				from = i
				repeat
					i = i + 1
					b = text:sub(i, i):byte()
				until not b or b <= 127 or b >= 194
				i = i - 1
				insert(chars, text:sub(from, i))
			end
		end
	end
	
	local pos = 0
	
	local function do_iter(start, from, to)
		local prev = chars[start - 1]
		while start > 1 and not long_vowel[prev] do
			start = start - 1
			prev = chars[start - 1]
		end
		start = start - 1
		insert(from, 1, start)
		insert(to, pos)
		return start
	end
	
	repeat
		pos = pos + 1
		local char = chars[pos]
		if char == "ー" then
			local start = pos
			local prev = chars[pos - 1]
			while start > 1 and not long_vowel[prev] do
				start = start - 1
				prev = chars[start - 1]
			end
			chars[pos] = long_vowel[prev] or chars[pos]
		elseif voice_marks[char] then
			chars[pos] = voice_marks[char]
		elseif iter_marks[char] then
			local from, to = {}, {}
			local start = do_iter(pos, from, to)
			local next = chars[pos + 1]
			while next and (iter_marks[next] or voice_marks[next] or specials[next] or next:sub(1, 1) == "<") do
				pos = pos + 1
				if iter_marks[next] then
					start = do_iter(start, from, to)
				end
				next = chars[pos + 1]
			end
			for i, char_pos in ipairs(from) do
				local iter_pos = to[i]
				chars[iter_pos] = chars[char_pos] or chars[iter_pos]
			end
		end
	until pos >= #chars
	
	return concat(chars)
end

function export.hira_to_kata(text)
	if type(text) == "table" then text = text.args[1] end
	text = gsub(text, '[ぁ-ゖゝゞ]', change_codepoint(96))
	text = gsub(text, '[𛅐-𛅒]', change_codepoint(20))
	text = gsub(text, '[𛀆𛄟]', {["𛀆"] = "𛄠", ["𛄟"] = "𛄢"})
	return toNFC(text)
end

function export.kata_to_hira(text)
	if type(text) == "table" then text = text.args[1] end
	text = gsub(toNFD(text), '[ァ-ヶヽヾ]', change_codepoint(-96))
	text = gsub(text, '[𛅤-𛅦]', change_codepoint(-20))
	text = gsub(text, '[𛄠𛄢]', {["𛄠"] = "𛀆", ["𛄢"] = "𛄟"})
	return toNFC(text)
end

function export.fullwidth_to_halfwidth(text)
	if type(text) == "table" then text = text.args[1] end

	return (gsub(text:gsub('　', ' '), '[！-～]', change_codepoint(-65248)))
end

-- removes spaces and hyphens from input
-- intended to be used when checking manual romaji to allow the
-- insertion of spaces or hyphens in manual romaji without appearing "wrong"
function export.rm_spaces_hyphens(f)
	local text = type(f) == 'table' and f.args[1] or f
	text = text:gsub('.', { [' '] = '', ['-'] = '', ['.'] = '', ['\''] = '' })
	text = text:gsub('&nbsp;', '')
	return text
end

function export.romaji_to_kata(f)
	local text = type(f) == 'table' and f.args[1] or f
	text = text:ulower()
	text = text:gsub('[\1-\255][\128-\191]*', data.rd)
	text = text:gsub('(.)%1', {
		k = 'ッk', s = 'ッs', t = 'ッt', p = 'ッp',
		b = 'ッb', d = 'ッd', g = 'ッg', j = 'ッj'
	})
	text = text:gsub('tc', 'ッc')
	text = text:gsub('tsyu', 'ツュ')
	text = text:gsub('ts[uoiea]', {['tsu']='ツ',['tso']='ツォ',['tsi']='ツィ',['tse']='ツェ',['tsa']='ツァ'})
	text = text:gsub('sh[uoiea]', {['shu']='シュ',['sho']='ショ',['shi']='シ',['she']='シェ',['sha']='シャ'})
	text = text:gsub('ch[uoiea]', {['chu']='チュ',['cho']='チョ',['chi']='チ',['che']='チェ',['cha']='チャ'})
	text = text:gsub("n[uoiea']?", {['nu']='ヌ',['no']='ノ',['ni']='ニ',['ne']='ネ',['na']='ナ'})
	text = text:gsub('[wvtrpsnmlkjhgfdbzy][yw]?[uoiea]', data.rk)
	text = text:gsub("n'?", 'ン')
	text = text:gsub('[aeiou]', {
		u = 'ウ', o = 'オ', i = 'イ', e = 'エ', a = 'ア'
	})
	return text
end

-- expects: any mix of kanji and kana
-- determines the script types used
-- e.g. given イギリス人, it returns Kana+Hani
function export.script(f)
	local text = type(f) == 'table' and f.args[1] or f
	local script = {}
	
	-- For Hira and Kana, we remove any characters which also feature in the other first, so that we don't get false positives for ー etc.
	if find(gsub(text, "[" .. range.katakana .. "]+", ""), "[" .. range.hiragana .. "]") then
		insert(script, 'Hira')
	end
	
	if find(gsub(text, "[" .. range.hiragana .. "]+", ""), "[" .. range.katakana .. "]") then
		insert(script, 'Kana')
	end
	
	if find(text, "[" .. range.kanji .. "]") then
		insert(script, 'Hani')
	end
	
	if find(text, "[" .. range.latin .. "]") then
		insert(script, 'Romaji')
	end
	if find(text, '[' .. range.numbers .. ']') then
		insert(script, 'Number')
	end
	if find(text, '[〆々]') then
		insert(script, 'Abbreviation')
	end

	return concat(script, '+')
end

-- when counting morae, most small hiragana belong to the previous mora,
-- so for purposes of counting them, they can be removed and the characters
-- can be counted to get the number of morae.  The exception is small tsu,
-- so data.nonmora_to_empty maps all small hiragana except small tsu.
function export.count_morae(text)
	if type(text) == "table" then
		text = text.args[1]
	end
	-- convert kata to hira (hira is untouched)
	text = export.kata_to_hira(text)
	-- remove all of the small hiragana such as ょ except small tsu
	text = text:gsub('[\1-\255][\128-\191]*',data.nonmora_to_empty)
	-- remove zero-width spaces
	text = text:gsub('‎', '')
	-- return number of characters, which should be the number of morae
	return len(text)
end

-- returns a sort key with |sort= in front, e.g.
-- |sort=はつぐん' if given ばつぐん
function export.sort(f)
	return "|sort=" .. (get_by_code("ja"):makeSortKey(f))
end

-- returns the "stem" of a verb or -i adjective, that is the term minus the final character
function export.definal(f)
	return sub(f.args[1], 1, -2)
end

function export.remove_ruby_markup(text)
	return (text:gsub("[%^%-%. %%]", ""))
end

-- do the work of [[Template:ja-kanji]], [[Template:ryu-kanji]] etc.
-- should probably be folded into [[Module:Jpan-headword]]
function export.kanji(frame)
	pagename = pagename or load_data("Module:headword/data").pagename
	-- only do this if this entry is a kanji page and not some user's page
	if namespace == "" then
		local params = {
			grade = {},
			rs = {},
			shin = {},
			kyu = {},
			head = {},
		}
		local lang_code = frame.args[1]
		local lang_name = get_by_code(lang_code):getCanonicalName()
		local args = require("Module:parameters").process(frame:getParent().args, params, nil, "ja", "kanji")
		local rs = args.rs or require("Module:Hani-sortkey").makeSortKey(pagename) -- radical sort
		local shin = args.shin
		local kyu = args.kyu

		local grade_replacements = {
			['c'] = 7,
			['n'] = 8,
			['uc'] = 9,
			['r'] = 0,
		}
		local grade = args.grade
		grade = tonumber(grade) or grade
		grade = grade_replacements[grade] or grade

		local wikitext = {}
		local categories = {}

		local catsort = rs or pagename

		-- display the kanji itself at the top at 275% size
		insert(wikitext, '<div><span lang="' .. lang_code .. '" class="Jpan" style="font-size:275%; line-height:1;">' .. (args.head or pagename) .. '</span></div>')

		-- display information for the grade

		-- if grade was not specified, determine it now
		if not grade then
			grade = export.kanji_grade(pagename)
		end

		local in_parenthesis = {}
		local grade_links = {
			[1] = "[[w:Kyōiku kanji|grade 1 “Kyōiku” kanji]]",
			[2] = "[[w:Kyōiku kanji|grade 2 “Kyōiku” kanji]]",
			[3] = "[[w:Kyōiku kanji|grade 3 “Kyōiku” kanji]]",
			[4] = "[[w:Kyōiku kanji|grade 4 “Kyōiku” kanji]]",
			[5] = "[[w:Kyōiku kanji|grade 5 “Kyōiku” kanji]]",
			[6] = "[[w:Kyōiku kanji|grade 6 “Kyōiku” kanji]]",
			[7] = "[[w:Jōyō kanji|common “Jōyō” kanji]]",
			[8] = "[[w:Jinmeiyō kanji|“Jinmeiyō” kanji used for names]]",
			[9] = "[[w:Hyōgai kanji|uncommon “Hyōgai” kanji]]",
			[0] = "[[w:Radical_(Chinese_character)|Radical]]",
		}
		if grade_links[grade] then
			insert(in_parenthesis, grade_links[grade])
		else
			insert(categories, "[[Category:" .. lang_name .. " kanji missing grade|" .. catsort .. "]]")
		end

		-- link to shinjitai if shinjitai was specified, and link to kyujitai if kyujitai was specified

		if kyu then
			insert(in_parenthesis, '[[shinjitai]] kanji, [[kyūjitai]] form <span lang="' .. lang_code .. '" class="Jpan">[[' .. kyu .. '#' .. lang_name .. '|' .. kyu .. ']]</span>')
		elseif shin then
			insert(in_parenthesis, '[[kyūjitai]] kanji, [[shinjitai]] form <span lang="' .. lang_code .. '" class="Jpan">[[' .. shin .. '#' .. lang_name .. '|' .. shin .. ']]</span>')
		end
		insert(wikitext, "''(" .. concat(in_parenthesis, ",&nbsp;") .. "'')")

		-- add categories
		insert(categories, "[[Category:" .. lang_name .. " Han characters|" .. catsort .. "]]")
		local grade_categories = {
			[1] = "Grade 1 kanji",
			[2] = "Grade 2 kanji",
			[3] = "Grade 3 kanji",
			[4] = "Grade 4 kanji",
			[5] = "Grade 5 kanji",
			[6] = "Grade 6 kanji",
			[7] = "Common kanji",
			[8] = "Kanji used for names",
			[9] = "Uncommon kanji",
			[0] = "CJKV radicals",
		}
		insert(categories, "[[Category:" .. (grade_categories[grade] or error("The grade " .. grade .. " is invalid.")) .. "|" .. (grade == "0" and " " or catsort) .. "]]")

		-- error category
		if not rs then
			insert(categories, "[[Category:" .. lang_name .. " kanji missing radical and strokes]]")
		end
		
		if mw.title.new(lang_name .. " terms spelled with " .. pagename, 14).exists then
			insert(wikitext, 1, '<div class="noprint floatright catlinks" style="font-size: 90%; width: 270px"><div style="margin-left: 10px;">See also:<div style="margin-left: 10px;">[[:Category:' .. lang_name .. ' terms spelled with ' .. pagename .. ']]</div></div></div>')
		end

		return concat(wikitext) .. concat(categories, "\n")
	end
end

local grade1_pattern = ('[' .. data.grade1 .. ']')
local grade2_pattern = ('[' .. data.grade2 .. ']')
local grade3_pattern = ('[' .. data.grade3 .. ']')
local grade4_pattern = ('[' .. data.grade4 .. ']')
local grade5_pattern = ('[' .. data.grade5 .. ']')
local grade6_pattern = ('[' .. data.grade6 .. ']')
local secondary_pattern = ('[' .. data.secondary .. ']')
local jinmeiyo_kanji_pattern = ('[' .. data.jinmeiyo_kanji .. ']')
local hyogaiji_pattern = ('[^' .. data.joyo_kanji .. data.jinmeiyo_kanji .. ']')

function export.kanji_grade(kanji)
	if type(kanji) == "table" then
		kanji = kanji.args[1]
	end

	if find(kanji, hyogaiji_pattern) then return 9
	elseif find(kanji, jinmeiyo_kanji_pattern) then return 8
	elseif find(kanji, secondary_pattern) then return 7
	elseif find(kanji, grade6_pattern) then return 6
	elseif find(kanji, grade5_pattern) then return 5
	elseif find(kanji, grade4_pattern) then return 4
	elseif find(kanji, grade3_pattern) then return 3
	elseif find(kanji, grade2_pattern) then return 2
	elseif find(kanji, grade1_pattern) then return 1
	end

	return false
end

return export
