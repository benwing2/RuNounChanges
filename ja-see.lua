local format_cat = require('Module:utilities').format_categories
local gmatch = mw.ustring.gmatch
local gsub = mw.ustring.gsub
local insert = table.insert
local len = mw.ustring.len
local load_data = mw.loadData
local maintenance_cats = require("Module:headword").maintenance_cats
local match = mw.ustring.match
local new_title = mw.title.new
local split = mw.text.split
local sub = mw.ustring.sub

local export = {}

local m_ja = require('Module:ja')
local m_sc = require("Module:scripts")
local kana_to_romaji = require("Module:Hrkt-translit").tr
local headword_data = load_data("Module:headword/data")
local pagename = headword_data.pagename
local lang = require('Module:languages').getByCode('ja')
local Hira = m_sc.getByCode("Hira")
local Kana = m_sc.getByCode("Kana")
local Hrkt = m_sc.getByCode("Hrkt")
local langname = lang:getCanonicalName()
local d_kyu = load_data('Module:ja/data/kyu')
local range = mw.loadData("Module:ja/data/range")

local function gmatch_array(s, pattern)
	local output = {}
	for e in gmatch(s, pattern) do
		insert(output, e)
	end
	return output
end

local function map(arr, f)
	local output = {}
	for _, e in ipairs(arr) do
		local fe = f(e)
		if fe ~= nil then
			insert(output, fe)
		end
	end
	return output
end

local function filter(arr, f)
	local output = {}
	for _, e in ipairs(arr) do
		if f(e) then
			insert(output, e)
		end
	end
	return output
end

local function contains(arr, item)
	for _, e in ipairs(arr) do
		if e == item then
			return true
		end
	end
	return false
end

-- f should be str->str in the following functions
local function memoize(f)
	local output = {}
	return function(s)
		if not output[s] then
			output[s] = f(s)
		end
		return output[s]
	end
end

local getContent_memo = memoize(function(title)
	return new_title(title):getContent() or ''
end)

local function group(arr, f)
	local r = {}
	for _, e in ipairs(arr) do
		local fe = f(e)
		if r[#r] and r[#r].key == fe then
			insert(r[#r], e)
		else
			insert(r, { e, key = fe })
		end
	end
	return r
end

local function ja(text)
	return '<span lang="ja" class="Jpan">' .. text .. '</span>'
end

local function link(lemma, display)
	return ja("[[" .. lemma .. "#" .. langname .. "|" .. (display or lemma) .. "]]")
end

local function link_bracket(lemma, display)
	return ja("【[[" .. lemma .. "#" .. langname .. "|" .. (display or lemma) .. "]]】")
end

local result

--[[ returns an array of definitions, each having the format
	{
		def = <definition>,
		kanji_spellings = <array of alternative kanji spellings listed in {{ja-kanjitab|alt=...}}, can be overrided with {{ja-def|...}}>,
		kana_spellings = <array of alternative kana spellings listed in the headword template>,
		historical_kana_spellings = <array of historical kana spellings listed in the headword template>,
		header = <name of PoS header>,
		headword_line = <wikicode of headword line>,
	}
]]
local function get_definitions_from_wikicode(wikicode)
	local current_kanji_spellings = {}
	local current_kanji_spellings_with_labels = {}
	local current_kana_spellings = {}
	local current_historical_kana_spellings = {}
	local current_head_level = '=='
	local current_header = langname
	local current_headword_line
	local status -- nil, 'under_headword', 'under_kanji', 'in_ja_readings'

	wikicode = wikicode:gsub('\n*<br */?>\n*({{ja%-altread)', '%1')

	-- in the local function `function format_definition` below,
	-- insertion of `|hira=` affects `{{tlb}}`
	-- (`{{tlb|ja|followed by a verb phrase|hira=によって}}`)
	-- and then that bad wikitext is preprocessed
	-- (`The parameter "hira" is not used by this template`).
	-- we are not doing anything with `{{tlb}}` anyway,
	-- so remove it
	wikicode = wikicode:gsub(' *{{tlb.-}}', '')
	
	local output = {}
	for line in (wikicode:match("==" .. langname .. "==\n(.*)") or ""):gmatch"[^\n]+" do
		if status == 'under_headword' then
			if line:match'^#+[^#:*]' then
				insert(output, {
					def = line
						:gsub('<ref>.-<.ref>', '')
						:gsub('<ref .->.-<.ref>', '')
						:gsub('<ref.-/>', '')
						:gsub('{{attention|ja.-}}', '')
						:gsub('{{senseid|ja.-}}', ''),
					kanji_spellings =
						line:match'{{ja%-def|' and split(line:match'{{ja%-def|([^}]+)', '|') or
						line:match'<!%-%- kana only %-%->' and {} or
						current_kanji_spellings,
					kanji_spellings_with_labels = current_kanji_spellings_with_labels,
					kana_spellings = current_kana_spellings,
					historical_kana_spellings = current_historical_kana_spellings,
					header = current_header,
					headword_line = current_headword_line,
				})
			end
		elseif status == 'under_kanji' then
			if line:match'^#+[^#:*]' then
				insert(output, {
					def = '#' .. line
						:gsub('<ref>.-<.ref>', '')
						:gsub('<ref .->.-<.ref>', '')
						:gsub('<ref.-/>', '')
						:gsub('{{attention|ja.-}}', ''),
					kanji_spellings = {},
					kanji_spellings_with_labels = {},
					kana_spellings = {},
					historical_kana_spellings = {},
					header = current_header,
					headword_line = current_headword_line,
				})
			elseif line:match'^{{ja%-readings%f[|}%z]' then
				output[#output].kanji_readings = {}
				status = 'in_ja_readings'
			end
		elseif status == 'in_ja_readings' then
			for rs in line:gmatch'|[a-z]+=([^|}]+)' do
				for r in rs:gmatch'(..-)%f[,%z],?' do
					r = r:gsub('%-', ''):match('..-%f[<%z]'):match'^%s*(.-)%s*$'
					if not contains(output[#output].kanji_readings, r) then
						insert(output[#output].kanji_readings, r:gsub('%-', ''):match'^%s*(.-)%s*$')
					end
				end
			end
			if line:match'}}' then status = 'under_kanji' end
		end
		
		-- the following branches are ordered by frequency; read backwards
		if line:match'^{{ja%-noun[|}]' or line:match'^{{ja%-adj[|}]' or
			line:match'^{{ja%-pos[|}]' or line:match'^{{ja%-phrase[|}]' or
			line:match'^{{ja%-verb[|}]' or line:match'^{{ja%-verb form[|}]' or
			line:match'^{{ja%-verb%-suru[|}]' or line:match'{{ja%-altread[|}]' then
			
			local escaped_line = line:gsub('%[%[([^%[%]|]-)|([^%[%]|]-)%]%]', '[[%1`%2]]'):gsub('|hkata=', '|hhira=')
			escaped_line = escaped_line:gsub('|hira=', '|') -- ja-altread
			escaped_line = escaped_line:gsub('|kata=', '|') -- ja-altread
			current_kana_spellings = map(gmatch_array(escaped_line, '|([・、' .. range.kana .. '\'%^%-%. %%]+)'), m_ja.remove_ruby_markup)
			current_historical_kana_spellings = map(gmatch_array(escaped_line, '|hhira=([' .. range.kana .. '\'%^%-%. %%]+)'), m_ja.remove_ruby_markup)
			current_headword_line = line
			status = 'under_headword'
		elseif line:match'^{{ja%-kanji[|}]' then
			current_kana_spellings = {}
			current_historical_kana_spellings = {}
			current_headword_line = line
			insert(output, {
				def = '#' .. (({
					'Grade 1 kanji',
					'Grade 2 kanji',
					'Grade 3 kanji',
					'Grade 4 kanji',
					'Grade 5 kanji',
					'Grade 6 kanji',
					'Jōyō kanji',
					'Jinmeiyō kanji',
				})[tonumber(line:match'|grade=([^|}]*)')] or 'Hyōgaiji kanji'),
				kanji_spellings = {},
				kanji_spellings_with_labels = {},
				kana_spellings = {},
				historical_kana_spellings = {},
				header = current_header,
				headword_line = line,
			})
			status = 'under_kanji'
		elseif line:match'^===+[^=]+===+$' then
			local head_level_new, header_new = line:match'^(===+)([^=]+)===+$'
			if not status or head_level_new:len() <= current_head_level:len() then
				current_head_level, current_header = head_level_new, header_new
				status = nil
			end
		elseif line:match'^{{ja%-kanjitab[|}]' then
			local alt_argument = line:match'|alt=([^|}]*)'
			current_kanji_spellings = alt_argument and split(alt_argument:gsub(':[^,]*', ''), ',') or {}
			current_kanji_spellings_with_labels = alt_argument and split(alt_argument, ',') or {}
		elseif line:match'^==[^=]+==$' then
			break
		end
	end
	return output
end

-- ditto, except that each definition also contains the title of the page it is from
local function get_definitions_from_entry(title)
	local wikicode = getContent_memo(title)
	local defs = get_definitions_from_wikicode(wikicode)
	map(defs, function(def)
		def.title = title
		insert(({ Hira = true, Kana = true, ['Hira+Kana'] = true })[m_ja.script(title)] and def.kana_spellings or def.kanji_spellings, title)
		end)
	return defs
end

local function format_table_content(defs, frame, title, no_cat)
	local kanji_grade_labels = {
		'<span class="explain" title="Grade 1 kanji" style="vertical-align: top;">1</span>',
		'<span class="explain" title="Grade 2 kanji" style="vertical-align: top;">2</span>',
		'<span class="explain" title="Grade 3 kanji" style="vertical-align: top;">3</span>',
		'<span class="explain" title="Grade 4 kanji" style="vertical-align: top;">4</span>',
		'<span class="explain" title="Grade 5 kanji" style="vertical-align: top;">5</span>',
		'<span class="explain" title="Grade 6 kanji" style="vertical-align: top;">6</span>',
		'<span class="explain" title="Jōyō kanji" style="vertical-align: top;">S</span>',
		'<span class="explain" title="Jinmeiyō kanji" style="vertical-align: top;">J</span>',
		'<span class="explain" title="Hyōgaiji kanji" style="vertical-align: top;">H</span>' }
	
	local function ruby(kanji, kana) -- this function ought to be in [[Module:ja]]
		local kanji_segments = gsub(kanji, "([" .. range.kanji .. range.ideograph .. range.latin .. range.numbers .. "]+)", "`%1`")
		
		-- returns possible matches between kanji and kana
		-- for example, match_k('`物`の`哀`れ', 'もののあわれ') returns { '[物](も)の[哀](のあわ)れ', '[物](もの)の[哀](あわ)れ' }
		local function match_k(kanji_segments, kana)
			if kanji_segments:find('`') then
				local kana_portion, kanji_portion, rest = match(kanji_segments, '(.-)`(.-)`(.*)')
				kana = match(kana, '^' .. kana_portion .. '(.*)')
				if not kana then
					return {}
				end
				local candidates = {}
				for i = 1, len(kana) do
					for _, candidate in ipairs(match_k(rest, sub(kana, i + 1))) do
						insert(candidates, kana_portion .. '[' .. kanji_portion .. '](' .. sub(kana, 1, i) .. ')' .. candidate)
					end
				end
				return candidates
			else
				return (kanji_segments == kana) and { kana } or {}
			end
		end
		
		local matches = match_k(kanji_segments, kana)
		local output = #matches == 1 and matches[1] or ('[' .. kanji .. '](' .. kana .. ')')
		return output:gsub("%[([^%[%]]+)%]%(([^%(%)]+)%)", "<ruby><rb>%1</rb><rt>%2</rt></ruby>")
	end
	
	local function format_headword(defs)
		local def_title = defs[1].title
		local kana = defs[1].kana_spellings[1]
		local headword = link_bracket(def_title, kana and pagename ~= kana and ruby(def_title, kana) or def_title)
		local kanji_grade = len(def_title) == 1 and m_ja.kanji_grade(def_title)
		return '<span style="font-size:x-large">' .. headword .. '</span>' .. (kanji_grade and kanji_grade_labels[kanji_grade] or '')
	end
	
	local preprocess_memo = memoize(function (s) return frame:preprocess(s) end)
	local function format_definitions(defs)
		local headword_line_categories = {}
		local alt_forms, alt_forms_rep = {}, { [title] = true, [defs[1].title] = true }
		local kanji_readings
		local function format_definition(def)
			local cat_prefixes = {
				["CAT"] = true,
				["CATEGORY"] = true
			}
			local def_text = def.def:match'{{rfdef[|}]' and "''This term needs a translation to English.''" or preprocess_memo(def.def
					:gsub('^#+ *', '')
					--TODO: strip unwanted templates and parser functions (e.g. {{c}}). Will use wiki parser once ready, as this can get very complex.
					)
					:gsub("(%[%[[ _]*(%a-)[ _]*:.-%]%])", function(link, cat_prefix)
						if cat_prefixes[cat_prefix:upper()] then
							return ""
						end
						return link
					end)
			local def_prefix = def.def:match'^#+':gsub('#', ':')
			local def_pos_label = ' <span style="padding-right:.6em;color:#5A5C5A;font-size:80%">[' .. def.header:ulower() .. ']</span> '
			
			if not no_cat and def.kana_spellings[1] then
				local cat_hira, cat_kata = {}, {}
				require'Module:Jpan-headword'.cat{
					lang = lang,
					pagename = title,
					categories = cat_hira,
					katakana_category = cat_kata,
					pos = def.header:gsub('^.', string.ulower)
				}
				insert(headword_line_categories, format_cat(
					cat_hira,
					lang,
					lang:makeSortKey(def.kana_spellings[1])
				))
				insert(headword_line_categories, format_cat(
					cat_kata,
					lang,
					lang:makeSortKey(def.kana_spellings[1], Kana)
				))
			end
			
			if def.kana_spellings[1] then alt_forms_rep[def.kana_spellings[1]] = true end
			for _, s in ipairs(def.kanji_spellings) do
				if not alt_forms_rep[s] then
					alt_forms_rep[s] = true
					insert(alt_forms, s)
				end
			end
			for _, s in ipairs(def.kana_spellings) do
				if not alt_forms_rep[s] then
					alt_forms_rep[s] = true
					insert(alt_forms, s)
				end
			end
			
			kanji_readings = def.kanji_readings or kanji_readings
			
			return def_prefix .. def_pos_label .. def_text
		end
		local formatted_defs = table.concat(map(defs, format_definition), '\n')
		if #alt_forms == 1 and alt_forms[1] == title then alt_forms = {} end
		return table.concat(headword_line_categories) .. '\n' .. formatted_defs
			.. (#alt_forms > 0 and '\n: <div style="background:#f8f9fa"><span style="color:#5A5C5A;font-size:80%">'
				.. (#alt_forms == 1 and 'Alternative spelling' or 'Alternative spellings')
				.. '</span><br><span style="margin-left:.8em">'
				.. table.concat(map(alt_forms, link), ', ')
				.. '</span></div>' or '')
			.. (kanji_readings and '\n: <div style="background:#f8f9fa"><span style="color:#5A5C5A;font-size:80%">Kanji reading:</span><br><span style="margin-left:.8em">'
				.. table.concat(map(kanji_readings, link), ', ')
				.. '</span></div>' or '')
	end
	
	local is_first_row = true
	local function format_row(defs)
		local output = '|-\n| style="white-space:nowrap;width:15%;vertical-align:top;' .. (is_first_row and '' or 'border-top:1px solid lightgray;') .. '" | ' .. format_headword(defs)
			.. '\n| style="' .. (is_first_row and '' or 'border-top:1px solid lightgray;') .. '" |\n' .. format_definitions(defs) .. '\n'
		is_first_row = false
		return output
	end
	
	local def_groups = group(defs, function(def) return def.title .. ',' .. (def.kana_spellings[1] or '') end)
	local rows = map(def_groups, format_row)
	
	return '{| style="width: 100%"\n' .. table.concat(rows) .. '|}'
end

local redirect_type = {
	-- auto-detected types
	{
		name = 'romaji',
		article = 'the',
		detect = function(title, defs)
			if m_ja.script(title) ~= 'Romaji' then return {} end
			local rom = title:ulower():gsub('[- ]', '')
			return filter(defs, function(def)
				for _, k in ipairs(def.kana_spellings) do
					if rom == kana_to_romaji(k, "ja") then
						insert(result, format_cat({langname .. " romanizations"}, lang))
						return true
					end
				end
				return false
			end)
		end,
		display = function(title)
			return '<span lang="ja" class="Latn">' .. title .. '</span>'
		end,
		no_cat = true,
	},
	{
		name = 'hiragana spelling',
		article = 'the',
		detect = function(title, defs)
			if m_ja.script(title) ~= 'Hira' then return {} end
			local rom = kana_to_romaji(title, "ja"):ulower():gsub('[- ]', '')
			return filter(defs, function(def)
				if not contains(def.kana_spellings, title) and contains(def.historical_kana_spellings, title) then
					return false
				end
				for _, k in ipairs(def.kana_spellings) do
					if rom == kana_to_romaji(k, "ja") then
						return true
					end
				end
				return false
			end)
		end,
	},
	{
		name = 'katakana spelling',
		article = 'the',
		detect = function(title, defs)
			if m_ja.script(title) ~= 'Kana' then return {} end
			local rom = kana_to_romaji(title, "ja"):ulower():gsub('[- ]', '')
			return filter(defs, function(def)
				if not contains(def.kana_spellings, title) and contains(def.historical_kana_spellings, title) then
					return false
				end
				for _, k in ipairs(def.kana_spellings) do
					if rom == kana_to_romaji(k, "ja") then
						return true
					end
				end
				return false
			end)
		end,
	},
	{
		name = 'historical kana spelling',
		article = 'a',
		detect = function(title, defs)
			return filter(defs, function(def)
				if not contains(def.kana_spellings, title) and contains(def.historical_kana_spellings, title) then
					local sc = m_ja.script(title)
					if sc == 'Hira' then
						insert(result, format_cat(
							{langname .. " historical hiragana"},
							lang,
							lang:makeSortKey(def.historical_kana_spellings[1], Hira)
						))
					elseif sc == 'Kana' then
						insert(result, format_cat(
							{langname .. " historical katakana"},
							lang,
							lang:makeSortKey(def.historical_kana_spellings[1], Kana)
						))
					elseif sc == 'Hira+Kana' then
						insert(result, format_cat(
							{langname .. " terms spelled with mixed historical kana"},
							lang,
							lang:makeSortKey(def.historical_kana_spellings[1], Hrkt)
						))
					end
					return true
				end
			end)
		end,
	},
	{
		name = 'kyūjitai',
		article = 'the',
		detect = function(title, defs)
			local shin = title:gsub('.[\128-\191]*', function(c)
				if c == '辨' or c == '辯' or c == '瓣' then return '弁' end
				return d_kyu[1]:match('(%S*)' .. c .. '%s') or c
			end)
			if shin == title then return {} end
			return len(title) == 1 and filter(defs, function(def) return def.header == "Kanji" end) or filter(defs, function(def)
				if shin == def.title then
					if def.kana_spellings[1] then
						insert(result, format_cat({langname .. " kyūjitai spellings"}, lang, lang:makeSortKey(def.kana_spellings[1])))
					end
					return true
				end
			end)
		end,
		display = function(title)
			return ja(title:gsub('.[\128-\191]*', function(c)
				return d_kyu[1]:match(c .. '(&#x%x+;)%s') or c
			end))
		end,
		no_cat = true,
	},
	{
		name = 'kyūjitai of an alternative spelling',
		article = 'the',
		detect = function(title, defs, key)
			local shin = title:gsub('.[\128-\191]*', function(c)
				if c == '辨' or c == '辯' or c == '瓣' then return '弁' end
				return d_kyu[1]:match('(%S*)' .. c .. '%s') or c
			end)
			if shin == title then return {} end
			return filter(defs, function(def)
				if shin ~= def.title and contains(def.kanji_spellings, shin) and (not key or contains(def.kana_spellings, key)) then
					if def.kana_spellings[1] then
						insert(result, format_cat({langname .. " kyūjitai spellings"}, lang, lang:makeSortKey(def.kana_spellings[1])))
					end
					return true
				end
			end)
		end,
		display = function(title)
			return ja(title:gsub('.[\128-\191]*', function(c)
				return d_kyu[1]:match(c .. '(&#x%x+;)%s') or c
			end))
		end,
		display_labels = function(title)
			local shin = title:gsub('.[\128-\191]*', function(c)
				if c == '辨' or c == '辯' or c == '瓣' then return '弁' end
				return d_kyu[1]:match('(%S*)' .. c .. '%s') or c
			end)
			return '(' .. link(shin) .. ')'
		end,
		no_cat = true,
	},
	{
		name = 'alternative spelling',
		article = 'an',
		detect = function(title, defs, key)
			return filter(defs, function(def)
				return contains(def.kanji_spellings, title) and (not key or contains(def.kana_spellings, key)) or contains(def.kana_spellings, title)
			end)
		end,
		display_labels = function(title, defs)
			for _, def in ipairs(defs) do for _, kl in ipairs(def.kanji_spellings_with_labels) do
				local ks, lb = kl:match'^(.-):(.+)$'
				if ks == title then
					return require("Module:labels").show_labels { labels = split(lb, ' '), lang = lang }
				end
			end end
			return ''
		end,
		is_fallback = true,
	},
	-- manual input only types
	['vk'] = {
		name = 'variant kanji form',
		article = 'a',
		detect = function(title, defs)
			return len(title) == 1 and filter(defs, function(def)
				return def.header == "Kanji"
			end) or defs
		end,
	},
	['iter'] = {
		name = 'form with iteration marks',
		article = 'a',
		detect = function(_, defs)
			return defs
		end,
	},
	['niter'] = {
		name = 'form without iteration marks',
		article = 'a',
		detect = function(_, defs)
			return defs
		end,
	},
	['eshin'] = {
		name = 'extended shinjitai',
		article = 'an',
		detect = function(title, defs)
			return len(title) == 1 and filter(defs, function(def)
				return def.header == "Kanji"
			end) or defs
		end,
	},
	names = {
		['rom'] = 1,
		['hira'] = 2,
		['kata'] = 3,
		['hkana'] = 4,
		['kyu'] = 5,
		['kyualt'] = 6,
		['alt'] = 7,
		
		['vk'] = 'vk',
		['iter'] = 'iter',
		['niter'] = 'niter',
		['eshin'] = 'eshin',
	},
}

function export.show(frame)
	local title = pagename
	
	local args = require("Module:parameters").process(frame:getParent().args, {
		[1] = { list = true },
		['type'] = { list = true, allow_holes = true, separate_no_index = true },
		['key'] = { list = true, allow_holes = true },
	})
			
	result = {
		'{| class="wikitable ja-see" style="min-width:70%"\n|-\n| <b>',
		'For pronunciation and definitions of ', ja(title), ' – see the following entr',
		#args[1] > 1 and 'ies' or 'y',
		'.', 
		'</b>',
	}
	local bad_redirects = {}
	
	local name_count = 0
	local name_previous, rt_previous
	
	local function make_footnote()
		insert(result, '\n|-\n| (This term, ')
		insert(result, (rt_previous.display or ja)(title))
		insert(result, ', is ')
		insert(result, name_previous)
		insert(result, ' of the above term')
		if name_count > 1 then insert(result, 's') end
		insert(result, '.)')
	end
	
	local function add_to_result(name, rt, defs)
		if rt.display_labels then
			name = name .. ' ' .. rt.display_labels(title, defs)
		end
		
		if name_previous and name_previous ~= name then
			make_footnote()
			name_count = 1
		else
			name_count = name_count + 1
		end
						
		name_previous = name
		rt_previous = rt
	
		insert(result, '\n|-\n| style="background-color: white" |\n')
		insert(result, format_table_content(defs, frame, title, rt.no_cat))
	end
	
	for i_lemma, lemma in ipairs(args[1]) do
		local defs = get_definitions_from_entry(lemma)
		--mw.logObject(defs) --use this to inspect "defs"
		
		local label_lemma = args.type[i_lemma] or args.type.default
		if label_lemma then
			local ll1, ll2 = label_lemma:match'^(.-)(%S*)$'
			local rt = redirect_type[redirect_type.names[ll2]]
			if rt then
				defs = rt.detect(title, defs)
				if #defs > 0 then
					-- This code deals with the redirect type description's articles like "the hiragana", "a rare hiragana", "an unusual hiragana" when there is a manual input |type=....
					add_to_result((label_lemma:match'^an? ' or label_lemma:match'^the ') and ll1 .. rt.name or rt.article .. ' ' .. ll1 .. rt.name, rt, defs)
				else
					insert(bad_redirects, lemma)
				end
			else
				add_to_result(label_lemma, {}, defs)
			end
		else
			local success = false
			for _, rt in ipairs(redirect_type) do
				if not (success and rt.is_fallback) then
					local defs_try = rt.detect(title, defs, args.key[i_lemma])
					if #defs_try > 0 then
						success = true
						add_to_result(rt.article .. ' ' .. rt.name, rt, defs_try)
					end
				end
			end
			if not success then
				insert(bad_redirects, lemma)
			end
		end
	end	
	
	if name_previous then
		make_footnote()
		if new_title(langname .. ' kanji read as ' .. title, 14).exists then
			insert(result, '<br><span style="font-size:85%;">For a list of all kanji read as ')
			insert(result, ja(title))
			insert(result, ', see ')
			insert(result, '[[:Category:' .. langname .. ' kanji read as ')
			insert(result, title)
			insert(result, ']].)</span>')
		end
		insert(result, '\n|}')
	else -- failure to find any definitions
		result[6] = ': ' .. table.concat(map(args[1], function(title) return '<span style="font-size:120%">' .. link(title) .. '</span>' end), ', ') .. '\n|}'
	end
	
	if #bad_redirects > 0 then
		insert(result, '\n<small class="attentionseeking">(The following ')
		insert(result, #bad_redirects == 1 and 'entry is' or 'entries are')
		insert(result, ' uncreated: ')
		insert(result, table.concat(map(bad_redirects, link), ", "))
		insert(result, '.)</small>')
		insert(result, format_cat({langname .. " redlinks/ja-see"}, lang))
	end
	
	-- Standard maintenance categories usually done by [[Module:headword]].
	local lang_cats, page_cats = {}, {}
	maintenance_cats(headword_data, lang, lang_cats, page_cats)
	insert(result, format_cat(lang_cats, lang))
	insert(result, format_cat(page_cats, nil, "-"))
	
	return table.concat(result)
end

function export.show_kango(frame) -- to be abolished
	return export.show(frame, 'kango')
end

function export.show_gv(frame) -- to be abolished
	return export.show(frame, 'glyphvar')
end

return export
