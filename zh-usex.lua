local m_zh = require("Module:zh")
local m_languages = require("Module:languages")
local find = mw.ustring.find
local gsub = mw.ustring.gsub
local match = mw.ustring.match
local sub = mw.ustring.sub
local split = mw.text.split

-- Use this when the actual title needs to be known.
local actual_title = mw.title.getCurrentTitle()

-- Use this when testcases need to be able to override the title (for bolding,
-- for instance).
local title = actual_title
local PAGENAME = PAGENAME or title.text

local export = {}

local data = mw.loadData("Module:zh-usex/data")
local punctuation = data.punctuation
local ref_list = data.ref_list
local pron_correction = data.pron_correction
local polysyllable_pron_correction = data.polysyllable_pron_correction

local zh_format_end = "</span>"

local Han_pattern = '[一-鿿㐀-䶿﨎﨏﨑﨓﨔﨟﨡﨣﨤﨧-﨩𠀀-𪛟𪜀-𮯯𰀀-𱍏]'
local UTF8_char = '[%z\1-\127\194-\244][\128-\191]*'
local tag = "%b<>"

local function make_link(display, target)
	target = target or display
	-- Remove bold tags from target
	target = target:gsub("</?b>","")
	-- Generate link to Chinese section
	local result = "[[" .. target .. "#Chinese|" .. display .. "]]"
	-- For debugging purposes
	--if actual_title.nsText == "Module" then mw.log(display, target, "->", result) end
	return result
end

local function ts_convert(simp)
	if simp then
		return m_zh.st
	else
		return m_zh.ts
	end
end

-- process a segment containing ^%[]{}.
-- extracts the traditional chinese, simplified chinese, and transcription
-- does not substitute {} for the transcription
-- e.g. 繁[简]{Luó} -> (繁, 简, 繁{Luó})
local function extract(segment, simp, norm_code, form_exists, generate_tr)
	if not segment then return nil end
	local segment_derom = gsub(segment,"{[^{}]*}","")
	segment_derom = segment_derom:gsub("[%^%.]","")
	if norm_code == "nan-hbl" then
		segment_derom = segment_derom:gsub("%%","")
	end
	local segment_trad = gsub(segment_derom,"%[.%]","")
	local segment_simp = form_exists and gsub(gsub(segment_derom .. "終[终]", "([^%[%]]*).%[(.)%]", function(a, b) return ts_convert(simp)(a) .. b end), "终$", "")
	local segment_rom = generate_tr and gsub(segment,"%[.%]","")
	if generate_tr then
		if norm_code == "cmn" then
			segment_rom = segment_rom:gsub("%.%.","-")
		end
		segment_rom = segment_rom:gsub("%."," ")
	end
	return segment_trad, segment_simp, segment_rom
end

function export.show(frame)
	local params = {
		[1] = { required = true },	-- example
		[2] = {},					-- translation
		[3] = {},					-- variety
		lit = {},
		tr = {},

		ref = {}, r = { alias_of = "ref" },

		display_type = {}, type = { alias_of = "display_type" },

		inline = {},

		audio = {}, a = { alias_of = "audio" },

		collapsed = { type = "boolean" },

		-- Allow specifying pagename in testcases on documentation page.
		pagename = actual_title.nsText == "Module" and {} or nil,

		nocat = { type = "boolean" },

		tr_nocap = { type = "boolean" },
		simp = { type = "boolean" }
	}
	
	local category = frame.args["category"] or error("Please specify the category.")

	local args, unrecognized_args = require("Module:parameters").process(frame:getParent().args, params, true)

	if args.pagename then
		-- Override title in Module namespace.
		title = mw.title.new(args.pagename)
		PAGENAME = title.text
	end

	local example = args[1] or error("Example unspecified.")
	local translation = args[2]
	local literal = args["lit"]
	local reference = args["ref"]
	local manual_tr = args["tr"]
	local display = args["display_type"]
	local inline = args["inline"]
	local audio_file = args["audio"]
	local collapsed = args["collapsed"]
	local simp = args["simp"]
	local phonetic = ""
	local original_length = mw.ustring.len(gsub(example, "[^一-鿿㐀-䶿﨎﨏﨑﨓﨔﨟﨡﨣﨤﨧-﨩]", ""))
	local variety = args[3] or frame.args["variety"] or (ref_list[reference] and ref_list[reference][1] or false) or "cmn"
	local variety_data = data.varieties_by_code[variety] or data.varieties_by_old_code[variety] or error("Variety " .. variety .. " not recognized.")
	local _, std_code, norm_code, desc, tr_desc = unpack(variety_data)
	norm_code = norm_code or std_code
	variety = std_code

	local lang_obj_wikt = m_languages.getByCode(variety, 3, true)

	if next(unrecognized_args) then
		--[[Special:WhatLinksHere/Template:tracking/zh-usex/unrecognized arg]]
		require("Module:debug").track_unrecognized_args(unrecognized_args, "zh-usex")
	end
	
	if reference then
		require("Module:debug").track("zh-usex/ref")
	end
	
	if example:match("[%(%)]") then
		require("Module:debug").track("zh-usex/parentheses")
	end
	
	if (norm_code == "nan-hbl" or norm_code:find("^hak")) and example:match("-") then
		require("Module:debug").track("zh-usex/hyphen")
	end
	
	if example:match("%w%{") then
		require("Module:debug").track("zh-usex/rom-text")
	end
	
	if not translation or translation == '' then -- per standard [[Module:usex]]
		translation = '<small>(please add an English translation of this ' .. (category == "quotations" and "quotation" or "usage example") .. ')</small> [[Category:Requests for translations of ' .. lang_obj_wikt:getNonEtymologicalName() .. ' ' .. (category == "collocations" and  "usage examples" or category) .. ']]'
	end
	
	-- automatically boldify pagetitle if nothing is in bold
	if not match(example, "'''") and not punctuation[PAGENAME] then boldify = true end
	
	-- tidying up the example, making it ready for transcription
	example = gsub(example, "([？！，。、“”…；：‘’|（）「」『』—《》〈〉【】·　．～])", " %1 ")
	example = gsub(example, " —  — ", " —— ") -- double em-dash (to be converted to single em-dash later)
	example = example:gsub("<br */?>"," <br> ") -- process linebreaks
	example = example:gsub("^ *", ""):gsub(" *$", ""):gsub(" +", " ") -- process spaces
	example = example:gsub("'''([^']+)'''", "<b>%1</b>") -- normalise bold syntax
	example = gsub(example,"%^<b>","<b>^")
	example = gsub(example,"</b>(%[.%])","%1</b>")
	example = gsub(example,"</b>({[^{}]*})","%1</b>")
	
	-- parsing: convert "-", "--", "---" to "-", "..", "--" respectively
	-- further explanation will use the replacement result to refer to the commands
	if norm_code == "cmn" then
		example = example:gsub("%-+",{["--"]="..",["---"]="--"})
		if match(example,"%-[^%-%s]+\\") then
			require("Module:debug").track("zh-usex/extra-pinyin")
		end
	end
	
	local ruby_start, ruby_mid, ruby_end = "<big><ruby><span class=\"Hani\" style=\"display: inline-flex; flex-direction: column;\">", "</span><rp>&nbsp;(</rp><rt><big>", "</big></rt><rp>)</rp></ruby></big>"
	local ruby_words = {}
	local trad_words, simp_words, tr_words = {}, {}, {}
	
	-- should we generate the other (simp/trad) form; should we generate the transcription
	local form_exist
	if simp then
		if category ~= "quotations" then error("parameter simp cannot be true in [[Template:zh-x]] or [[Template:zh-co]].") end
		if norm_code == "vi" or norm_code == "ko" or norm_code == "lzh" or variety == "yue-HK" or variety == "cmn-TW" or
			variety == "nan-hbl-TW" or variety == "lzh-cmn-TW" or variety == "hak-hai" or variety == "hak-dab" or
			variety == "hak-zha" then
				error(("Parameter simp= cannot be specified for variety '%s'"):format(variety))
			end
		form_exist = m_zh.ts_determ(gsub(example, "(.)%[%1%]", "")) == "simp" or (
			match(example, "%[[^%[%]]+%]") and not match(example, "(.)%[%1%]"))
	else
		form_exist = (m_zh.ts_determ(gsub(example, "(.)%[%1%]", "")) == "trad" or (
			match(example, "%[[^%[%]]+%]") and not match(example, "(.)%[%1%]"))) and
			norm_code ~= "vi" and norm_code ~= "ko"
	end
	
	-- should we generate the transcription
	local generate_tr
	if norm_code == "cmn" or norm_code == "yue" or norm_code == "nan-hbl" or variety == "hak-six" then
		if manual_tr then
			require("Module:debug").track("zh-usex/manual-tr")
			generate_tr = false
		else
			generate_tr = true
		end
	else
		generate_tr = false
	end
	
	-- each "word" is delimited by spaces
	for word in mw.text.gsplit(example, " ", true) do
		local trad_word, simp_word, tr_word, ruby_word = "", "", "", "" -- if simp is true then trad_word and simp_word are swapped
		
		local segments -- split each "word" further according to the number of links
		if norm_code == "cmn" then
			-- only the commands "-" and "--" increase the number of links
			-- this "regex" allows us to record the number of hyphens in the commands
			segments = split(word,"%f[%-]%-")
		elseif norm_code == "nan-hbl" or variety == "hak-six" then
			segments = split(word,"~")
		else -- there should only be one link per word
			segments = {word}
		end
		
		for i, segment in ipairs(segments) do
			-- fast-track for punctuations
			if punctuation[segment] then
				trad_word = trad_word .. segment
				if form_exist then
					simp_word = simp_word .. segment
				end
				if generate_tr then
					tr_word = tr_word .. punctuation[word]
				end
			else
				-- for Mandarin, the command "--" now leaves a single "-" at the beginning
				local prepend = '' -- extract the prepended "-" in this case
				if norm_code == "cmn" and segment:sub(1,1) == "-" then
					prepend, segment = "-", segment:sub(2)
				end
				
				-- process "@" and "\"
				local occurrences
				segment, occurrences = segment:gsub("@","")
				local generate_link = (occurrences == 0)
				local target, display
				if segment:find("\\",1,true) then
					target, display = segment:match("^([^\\]-)\\(.+)$")
					-- special case for <b>: <b>甲\乙 becomes 甲\<b>乙
					if target:sub(1,3) == "<b>" then
						target, display = target:sub(4), "<b>" .. display
					end
					-- special case for ^: ^甲\乙 becomes 甲\^乙
					if target:sub(1,1) == "^" then
						target, display = target:sub(2), "^" .. display
					end
					display = display:gsub("^%^<b>","<b>^")
					if (not generate_link) or (display:match("\\")) then -- TODO: raise error
						require("Module:debug").track("zh-usex/link-contradiction")
					end
					if target:match("</?b>") then -- Check for bold tags in target.
						require("Module:debug").track("zh-usex/bold-target")
					end
				else
					display = segment
				end
				
				if boldify then
					-- TODO: make this work with [] and {}
					display = display:gsub(PAGENAME, "<b>"..PAGENAME.."</b>")
					display = display:gsub("%[<b>"..PAGENAME.."</b>%]","["..PAGENAME.."]")
					display = gsub(display,"</b>(%[.%])","%1</b>")
					display = gsub(display,"</b>(%{[^%{%}]*%})","%1</b>")
				end
				
				local target_trad, target_simp = extract(target, simp, norm_code, form_exist)
				local display_trad, display_simp, display_tr = extract(display, simp, norm_code, form_exist, generate_tr)
				
				local boldify_start, boldify_end = "", ""
				if (target_trad or display_trad):gsub("</?b>","") == PAGENAME then
					generate_link = false
					if boldify and not display_trad:match("</?b>") then
						boldify_start, boldify_end = "<b>", "</b>"
					end
				end
				
				if generate_link then
					trad_word = trad_word .. make_link(display_trad, target_trad)
					if form_exist then
						simp_word = simp_word .. make_link(display_simp, target_simp)
					end
				else
					trad_word = trad_word .. boldify_start .. display_trad .. boldify_end
					if form_exist then
						simp_word = simp_word .. boldify_start .. display_simp .. boldify_end
					end
				end
				
				if generate_tr then
					tr_word = tr_word .. prepend .. boldify_start .. display_tr .. boldify_end
				end
			end
		end
		
		-- process transcription
		if generate_tr then
			if punctuation[word] then
				tr_word = punctuation[word]
			else
				real_word = true
				local hyphen = norm_code == "nan-hbl" or norm_code:find("^hak")
				tr_word = gsub(tr_word, "(.){([^{}]*)}",function(a, b)
						if hyphen and not mw.ustring.find(a, "[a-zA-Z]") then
							return "-" .. b .. "-"
						else
							return b
						end
					end)
				for key, val in pairs(polysyllable_pron_correction[norm_code]) do
					tr_word = gsub(tr_word, key, val)
				end
				tr_word = gsub(tr_word, ".", pron_correction[norm_code])
				if norm_code == "cmn" then
					tr_word = gsub(tr_word, "[^%-%s]+", m_zh.py)
				elseif norm_code == "yue" then
					m_yue_pron = m_yue_pron or mw.loadData("Module:zh/data/yue-pron")
					tr_word = gsub(tr_word, ".", m_yue_pron.jyutping)
					tr_word = gsub(tr_word, "([a-z])([1-9])(-?)([1-9]?)", "%1%2%3%4 ")
				elseif hyphen then
					tr_word = gsub(tr_word, "[一-鿿㐀-䶿　-〿﨎﨏﨑﨓﨔﨟﨡﨣﨤﨧-﨩𠀀-𪛟𪜀-𮯯𰀀-𱍏]+", function(text)
						local text_res = m_zh.check_pron(text, norm_code, 1)
						if text_res then
							return gsub(text_res, "/.+$", "")
						else
							text = gsub(text, ".", function(ch)
								local ch_res = m_zh.check_pron(ch, norm_code, 1)
								if ch_res then
									return gsub(ch_res, "/.+$", "") .. "-"
								else
									return ch
								end
							end)
							return gsub(text, "-$", "")
						end
					end)
					--tr_word = gsub(tr_word, "%-([^ⁿa-záíúéóḿńàìùèòǹâîûêôāīūēōṳA-ZÁÍÚÉÓḾŃÀÌÙÈÒǸÂÎÛÊÔĀĪŪĒŌṲ])", "%1")
					--tr_word = gsub(tr_word, "([^ⁿa-záíúéóḿńàìùèòǹâîûêôāīūēōoóòôōṳA-ZÁÍÚÉÓḾŃÀÌÙÈÒǸÂÎÛÊÔĀĪŪĒŌOÓÒÔŌṲ̄̀́̂̍͘])%-", "%1")
					tr_word = tr_word:gsub("%-? %-?"," ")
					tr_word = tr_word:gsub("%^%-","-^")
					tr_word = tr_word:gsub("<b>%-?", "-<b>")
					tr_word = tr_word:gsub("%-?</b>", "</b>-")
					tr_word = tr_word:gsub("%-+","-"):gsub("^%-",""):gsub("%-$","")
					tr_word = tr_word:gsub("%-?%%%-?", "--")
				end
				if match(tr_word, "[一-鿿㐀-䶿﨎﨏﨑﨓﨔﨟﨡﨣﨤﨧-﨩𠀀-𪛟𪜀-𮯯𰀀-𱍏]") then
					require("Module:debug").track("zh-usex/character without transliteration")
				end
			end
		end
		
		if display == "ruby" then
			ruby_word = ruby_start .. trad_word .. (form_exist and "<br>" .. simp_word or "") .. ruby_mid .. (real_word and tr_word or "") .. ruby_end
			table.insert(ruby_words, ruby_word)
		else
			table.insert(trad_words, trad_word)
			table.insert(simp_words, form_exist and simp_word)
			table.insert(tr_words, generate_tr and tr_word or nil)
		end
	end

	local tag_start = " <span style=\"color:darkgreen; font-size:x-small;\">&#91;" -- HTML entity since "[[[w:MSC|MSC]]" is interpreted poorly
	local tag_end = "&#93;</span>"
	
	local simp_link = "<i>[[w:Simplified Chinese|simp.]]</i>"
	local trad_link = "<i>[[w:Traditional Chinese|trad.]]</i>"
	if simp then
		simp_link, trad_link = trad_link, simp_link
	end

	if display == "ruby" then
		local tag = " <ruby><rb><big>" ..
				tag_start .. desc ..
					(form_exist
						and (", " .. trad_link .. "↑ + " .. simp_link .. "↓")
						or ", " .. trad_link .. " and " .. simp_link) .. tag_end ..

				tag_start .. "''rom.'': " .. tr_desc .. tag_end ..
					"</big></rb></ruby>"

		return table.concat(ruby_words, "") .. tag .. "<dl><dd><i>" .. translation .. "</i></dd></dl>"
	else
		trad_text = gsub(table.concat(trad_words), "([a-zA-Z]%]%])(%[%[[a-zA-Z])", "%1 %2")
		simp_text = form_exist and gsub(table.concat(simp_words), "([a-zA-Z]%]%])(%[%[[a-zA-Z])", "%1 %2") or false
		phonetic = manual_tr or (#tr_words > 0 and table.concat(tr_words, " ") or false)

		-- overall transcription formatting
		if phonetic then
			phonetic = gsub(phonetic, " </b>", "</b> ")
			phonetic = gsub(phonetic, "  ", " ")
			if norm_code == "yue" or norm_code == "zhx-tai" or norm_code == "nan-tws" or norm_code == "nan-hnm" or
				norm_code == "zhx-sic" or norm_code == "cjy" or norm_code == "hsn" or norm_code == "gan" or
				variety == "hak-mei" then
				phonetic = gsub(phonetic, "([a-zê]+)([1-9%-]+)", "%1<sup>%2</sup>") -- superscript tones
			end
			phonetic = gsub(phonetic, " ([,%.?!;:’”)])", "%1") -- remove excess spaces from punctiation
			phonetic = gsub(phonetic, "([‘“(]) ", "%1")
			phonetic = phonetic:gsub(" <br> ", "<br>")
			if not manual_tr then
				phonetic = gsub(phonetic, "%'([^%'])", "%1") -- allow bolding for manual translit
				if norm_code == "nan-hbl" then
					phonetic = gsub(phonetic, " +%-%-", "--")
				end
			end

			-- capitalisation
			if not manual_tr then
				if norm_code == "yue" or norm_code == "zhx-tai" or norm_code == "cjy" or norm_code == "hsn" or
					norm_code == "cmn-wuh" or norm_code == "nan-tws" or norm_code == "wxa" or norm_code == "wuu" or
					variety == "hak-mei" then
					args.tr_nocap = true
				end
				if not args.tr_nocap and match(example, "[。？！]") then
					phonetic = "^" .. gsub(phonetic, "([%.?!]) ", "%1 ^")
				end
				if not args.tr_nocap then
					phonetic = gsub(phonetic, "([%.%?%!][”’]) (.)", "%1 ^%2")
					phonetic = gsub(phonetic, "<br>(.)", "<br>^%1")
					phonetic = gsub(phonetic, ": ([“‘])(.)", ": %1^%2")
				end
				phonetic = gsub(phonetic, "%^<b>", "<b>^")
				phonetic = gsub(phonetic, "%^+.", mw.ustring.upper)
				phonetic = gsub(phonetic, "%^", "")
			end

			if norm_code == "wuu" then
				local wuu_pron = require("Module:wuu-pron")
				if phonetic:find(":") then
					phonetic = "''" .. wuu_pron.wugniu_format(phonetic:sub(4)) .. "''"
				else
					phonetic = "''" .. wuu_pron.wugniu_format(wuu_pron.wikt_to_wugniu(phonetic)) .. "''"
				end
			elseif norm_code == "cmn-wuh" or norm_code == "wxa" then
				phonetic = "<span class=\"IPA\">[" .. phonetic .. "]</span>"

			elseif norm_code == "cdo" then
				local cdo_pron = require("Module:cdo-pron")
				phonetic = "<i>" .. phonetic .. "</i>" ..
					(not match(phonetic, "-[^ ]+-[^ ]+-[^ ]+-")
						and " / <span class=\"IPA\"><small>[" .. cdo_pron.sentence(phonetic) .. "]</small></span>"
						or "")

			else
				phonetic = "<i>" .. phonetic .. "</i>"
			end
			phonetic = "<span lang=\"zh-Latn\" style=\"color:#404D52\">" .. phonetic .. "</span>"
		end
	end

	local collapse_start, collapse_end, collapse_tag, collapse_border_div, collapse_border_div_end = '', '', '', '', ''
	simplified_start = '<br>'
	if collapsed then
		collapse_start = '<span class="vsHide">'
		collapse_end = '</span>'
		collapse_tag = '<span class="vsToggleElement" style="color:darkgreen; font-size:x-small;padding-left:10px"></span>'
		collapse_border_div = '<div class="vsSwitcher" data-toggle-category="usage examples" style="border-left: 1px solid #930; border-left-width: 2px; padding-left: 0.8em;">'
		collapse_border_div_end = '</div>'
		simplified_start = '<hr>'
	end

	if actual_title.nsText == '' and (not args.nocat) then -- fixme: probably categorize only if text contains the actual word
		if reference then
			cat = "[[Category:" .. lang_obj_wikt:getNonEtymologicalName() .. " terms with quotations]]"
		else
			cat = "[[Category:" .. lang_obj_wikt:getNonEtymologicalName() .. " terms with " .. category .. "]]"
		end
	end
	
	local zh_format_start_simp = "<span lang=\"zh-Hans\" class=\"Hans\">"
	local zh_format_start_trad = "<span lang=\"zh-Hant\" class=\"Hant\">"
	if simp then zh_format_start_simp, zh_format_start_trad = zh_format_start_trad, zh_format_start_simp end
	
	-- indentation, font and identity tags
	if
		((norm_code == "cmn" and original_length > 7)
			or (norm_code ~= "cmn" and original_length > 5)
			or reference
			or collapsed
			or (match(example, "[，。？！、：；　]") and norm_code == "wuu")
			or (norm_code == "cdo" and original_length > 3)
			or (inline or "" ~= "")) then

		trad_text = zh_format_start_trad .. trad_text .. zh_format_end

		if not phonetic then
			translation = "<i>" .. translation .. "</i>"
		end

		if phonetic then
			phonetic = "<dd>" .. collapse_start .. phonetic
			translation = "<dd>" .. translation .. "</dd>"
			tr_tag = tag_start .. tr_desc .. tag_end .. collapse_end .. "</dd>"
		else
			translation = "<dd>" .. translation .. "</dd>"
		end

		if audio_file then
			audio = "<dd>[[File:" .. audio_file .. "]]</dd>"
		end
		
		if form_exist then
			trad_tag = collapse_start .. tag_start .. desc .. ", " .. trad_link .. tag_end .. collapse_end .. collapse_tag
			simp_text = simplified_start .. collapse_start .. zh_format_start_simp .. simp_text .. zh_format_end
			simp_tag = tag_start .. desc .. ", " .. simp_link .. tag_end .. collapse_end
		elseif norm_code == "vi" or norm_code == "ko" then
			trad_tag = collapse_start .. tag_start .. desc ..", " .. trad_link .. tag_end .. collapse_end .. collapse_tag
		else
			trad_tag = collapse_start .. tag_start .. desc ..", " .. trad_link .. " and " .. simp_link .. tag_end .. collapse_end .. collapse_tag
		end

		if reference then
			reference = "<dd>" .. collapse_start .. "<small><i>From:</i> " ..
				(ref_list[reference] and ref_list[reference][2] or reference) .. "</small>" .. collapse_end .. "</dd>"
		end

		return collapse_border_div .. "<dl class=\"zhusex\">" .. trad_text .. trad_tag .. (simp_text or "") .. (simp_tag or "") .. (reference or "") ..
			(phonetic and phonetic .. tr_tag or "") .. (audio or "") .. translation .. "</dl>" .. (cat or "") .. collapse_border_div_end

	else
		trad_text = zh_format_start_trad .. trad_text .. zh_format_end
		divider = "&nbsp; ―&nbsp; "

		if variety ~= "cmn" then
			ts_tag = tag_start .. desc .. tag_end
			tr_tag = tag_start .. tr_desc .. tag_end
		end

		if not phonetic then
			translation = "<i>" .. translation .. "</i>"
		end

		if form_exist then
			simp_text = "<span lang=\"zh-Hani\" class=\"Hani\">／</span>" .. zh_format_start_simp .. simp_text .. zh_format_end
		end

		if audio_file then
			audio = " [[File:" .. audio_file .. "]]"
		end

		return trad_text .. (simp_text or "") .. (ts_tag or "") .. divider ..
			(phonetic and phonetic .. (tr_tag or "") .. (audio or "") .. divider or "") .. translation .. (literal and " (literally, “" .. literal .. "”)" or "") ..
			(cat or "")
	end
end

-- function export.migrate(text, translation, ref)
-- 	if type(text) == "table" then
-- 		if not text.args or not text.args[1] then
-- 			text = text:getParent()
-- 		end
-- 		if text.args[2] and text.args[2] ~= '' then
-- 			ref = text.args[1]
-- 			translation = text.args[3]
-- 			text = text.args[2]
-- 		else
-- 			text = text.args[1]
-- 		end
-- 	end
-- 	text = text:gsub('^[%*#: \n]+', ''):gsub('[ \n]+$', ''):gsub(' +', '　'):gsub('\n+', '<br>'):gsub('|', '\\'):gsub('\'\'\'%[%[', ' '):gsub('%]%]\'\'\'', ' '):gsub('%]%]%[%[', ' '):gsub('%]%]', ''):gsub('%[%[', '')
-- :gsub('\'\'\'', ''):gsub(',', '，'):gsub('!', '！'):gsub('%?', '？')
-- 	if translation then
-- 		if ref and ref ~= '' then
-- 			return '{{zh-x|' .. text .. '|' .. translation .. '|ref=' .. ref .. '}}'
-- 		else
-- 			return '{{zh-x|' .. text .. '|' .. translation .. '}}'
-- 		end
-- 	else
-- 		return text
-- 	end
-- end

return export
