local categorize = require("Module:zh-cat").categorize
local change_to_variant = require("Module:zh-forms").change_to_variant
local concat = table.concat
local extract_gloss = require("Module:zh/extract").extract_gloss
local findTemplates = require("Module:template parser").findTemplates
local format_cat = require("Module:utilities").format_categories
local full_link = require("Module:links").full_link
local get_lang = require("Module:languages").getByCode
local get_section = require("Module:utilities").get_section
local gsplit = mw.text.gsplit
local html_create = mw.html.create
local insert = table.insert
local ipairs = ipairs
local maintenance_cats = require("Module:headword").maintenance_cats
local pairs = pairs
local tostring = tostring
local track = require('Module:debug').track
local type = type
local ulen = mw.ustring.len
local usub = mw.ustring.sub

local m_data = mw.loadData("Module:zh-see/data")
local lect_codes = mw.loadData("Module:zh/data/lect codes")
local headword_data = mw.loadData("Module:headword/data")
local namespace = mw.title.getCurrentTitle().namespace

local langs = setmetatable({}, {
	__index = function(t, k)
		local lang = get_lang(k)
		t[k] = lang
		return lang
	end
})

local function get_content(title)
	local content = mw.title.new(title)
	if not content then
		return false
	end
	return get_section(content:getContent(), "Chinese", 2)
end

local function do_preprocess(frame, args)
	for k, v in pairs(args) do
		if type(k) == "string" then
			k = frame:preprocess(k)
		end
		args[k] = frame:preprocess(v)
	end
	return args
end

local function process_zh_forms(data, abbrevs, args)
	for k, v in pairs(args) do
		if k == "alt" then
			for altform in gsplit(v, "%s*,%s*") do
				if altform:match("^" .. data.pagename .. "%f[%z%-]") then
					abbrevs.v = true
				end
			end
		elseif v == data.pagename then
			if k:match("^s%d*$") then
				abbrevs.s = true
			elseif k:match("^ss%d*$") then
				abbrevs.ss = true
			elseif k:match("^t%d*$") then
				abbrevs.v = true
				abbrevs.t = true
			end
		end
	end
end

local function process_categories(frame, template, args)
	local cat_type = m_data.cat_type[template]
	if not cat_type then
		return
	end
	args = do_preprocess(frame, args)
	local code = lect_codes.langcode_to_abbr[args[1]] and args[1]
	if not code then
		return
	end
	local lang = langs[code]
	local cat_prefix = (
		cat_type == "topics" and (lang:getCode() .. ":") or
		cat_type == "catlangname" and (lang:getCanonicalName() .. " ") or
		""
	)
	local categories = {}
	for i = 2, #args do
		insert(categories, cat_prefix .. args[i])
	end
	return format_cat(categories, lang)
end

local function iterate_templates(frame, data, abbrev, chained)
	local zh_forms, zh_see, zh_pron, zh_char_comp
	local abbrevs
	if not abbrev then
		abbrevs = {}
	end
	for template, args in findTemplates(data.content) do
		if template == "zh-forms" then
			zh_forms = true
			if not abbrev then
				process_zh_forms(data, abbrevs, do_preprocess(frame, args))
			end
		elseif template == "zh-see" and not chained then
			args = do_preprocess(frame, args)
			zh_see = args[1]
			data.new_abbrev = args[2]
		elseif template == "zh-pron" then
			zh_pron = zh_pron or do_preprocess(frame, args)
		elseif abbrev ~= "poj" and abbrev ~= "trc" then
			if template == "zh-character component" then
				zh_char_comp = true
			else
				local cats = process_categories(frame, template, args)
				if cats then
					insert(data.categories, cats)
				end
			end
		end
	end
	if zh_forms then
		if not abbrev then
			-- Note: Don't mention second-round simplified if there's a match for (first-round) simplified.
			abbrev = (abbrevs.s and "s" or "") ..
				(abbrevs.ss and not abbrevs.s and "ss" or "") ..
				(abbrevs.v and "v" or "") ..
				(abbrevs.t and "t" or "")
			if abbrev ~= "" then
				if chained then
					data.new_abbrev = abbrev
				else
					data.abbrev = abbrev
				end
			end
		end
	elseif zh_see then
		data.new_title = zh_see
		data.content = get_content(zh_see)
		if data.content then
			data.chain = true
			return iterate_templates(frame, data, data.new_abbrev, true)
		end
	end
	if zh_pron then
		if abbrev == "poj" or abbrev == "trc" then
			local new_zh_pron = {}
			for k, v in pairs(zh_pron) do
				if k == "mn" or k == "cat" then
					new_zh_pron[k] = v
				end
			end
			zh_pron = new_zh_pron
			zh_pron.no_foreign_script_cat = "yes"
		end
		zh_pron.only_cat = "yes"
		local cats = frame:expandTemplate{
			title = "Template:zh-pron",
			args = zh_pron
		}
		if cats then
			insert(data.categories, cats)
		end
	end
	if zh_char_comp then
		insert(data.categories, format_cat({"zh:Chinese character components"}, langs.zh))
	end
	if not data.chain then
		data.new_title = nil
		data.new_abbrev = nil
	end
	if not (chained or zh_forms or zh_pron) then
		track("zh-see/unidirectional reference to variant")
	elseif not (chained or data.content:match(data.pagename)) then
		track("zh-see/unidirectional reference variant→orthodox")
	end
end

local export = {}

function export.show(frame)
	local data = {
		args = frame:getParent().args,
		pagename = headword_data.pagename,
		categories = {}
	}
	data.title = data.args[1]
	data.abbrev = data.args[2] ~= "" and data.args[2]
	data.simp = data.args.simp or false

	if data.title == data.pagename then
		return error("The soft-directed item is the same as the page title.")
	end
	
	data.content = get_content(data.title)
	
	if not data.content then
		insert(data.categories, format_cat({"Chinese redlinks/zh-see"}, langs.zh))
	else
		iterate_templates(frame, data, data.abbrev)
	end
	
	-- automatically generated |t2=
	if not data.abbrev and change_to_variant(data.title) == data.pagename then
		data.abbrev = "vt"
	end
	
	local non_lemma_cat = m_data.non_lemma_type[data.abbrev or "s"]
	
	if not non_lemma_cat then
		error("Please specify a valid type of non-lemma; the value \"" .. data.abbrev .. "\" is not valid (see [[Template:zh-see]]).")
	end
	
	local self_link_chars
	if data.abbrev == "poj" then
		self_link_chars = full_link{
			term = data.pagename .. "//",
			lang = langs["nan-hbl"],
			tr = "-"
		}
	else
		self_link_chars = full_link{
			term = data.pagename:gsub("[%z\1-\127\194-\244][\128-\191]*", "[[%0]]") .. "//",
			lang = langs.zh,
			tr = "-"
		}
	end
	
	local title_link = full_link{
		term = data.title .. "//",
		lang = langs.zh,
		tr = "-"
	}
	
	local new_title_link
	if data.chain then
		new_title_link = full_link{
			term = data.new_title .. "//",
			lang = langs.zh,
			tr = "-"
		}
	end
	
	local gloss_text = data.args[3] or (data.content and extract_gloss(data.content, true))
		
	local wikitext1 = "'''For pronunciation and definitions of '''" ..
		self_link_chars .. "''' – see " .. (new_title_link or title_link)
	if gloss_text and #gloss_text > 0 then
		wikitext1 = wikitext1 .. " (“" .. gloss_text .. "”)"
	end
	wikitext1 = wikitext1 .. ".'''"
	
	local wikitext2 = "(''This " .. (data.abbrev ~= "poj" and ulen(data.pagename) == 1 and "character" or "term") .. " is " .. non_lemma_cat .. " form of'' " .. title_link
	
	if data.simp then
		local link1 = full_link{
			term = usub(data.simp, 1, 1) .. "//",
			lang = langs.zh,
			tr = "-"
		}
		local link2 = full_link{
			term = usub(data.simp, 2, 2) .. "//",
			lang = langs.zh,
			tr = "-"
		}
		data.simp = html_create("small")
			:wikitext(":&nbsp; " .. link1 .. " → " .. link2)
			:allDone()
	end
	
	if data.chain then
		data.chain = ", which is in turn ''" .. m_data.non_lemma_type[data.new_abbrev ~= "" and data.new_abbrev or "v"] .. "'' form of " .. new_title_link
	end
	
	local box = html_create("table")
		:addClass("wikitable")
		:allDone()
	if non_lemma_cat:match("simplified") then
		box = box:addClass("mw-collapsible")
			:addClass("mw-collapsed")
	end
	box = box:css("border", "1px")
		:css("border", "1px solid #797979")
		:css("margin-left", "1px")
		:css("text-align", "left")
		:css("min-width", (data.chain and "80" or "70") .. "%")
		:tag("tr")
			:tag("td")
				:css("background-color", "#eeeeee")
				:css("padding-left", "0.5em")
				:wikitext(wikitext1)
				:tag("br")
					:done()
				:wikitext(wikitext2)
				:node(data.simp)
				:wikitext(data.chain)
				:wikitext(").")
		:allDone()
	if non_lemma_cat:match("simplified") then
		box = box:tag("tr")
			:tag("td")
				:addClass("mw-collapsible-content")
				:css("background-color", "#F5DEB3")
				:css("font-size", "smaller")
				:tag("b")
					:wikitext("Notes:")
					:done()
				:tag("ul")
					:tag("li")
						:wikitext("[[w:Simplified Chinese|Simplified Chinese]] is mainly used in Mainland China, Malaysia")
						:tag("span")
							:addClass("serial-comma")
							:wikitext(",")
							:done()
						:wikitext(" and Singapore.")
						:done()
					:tag("li")
						:wikitext("[[w:Traditional Chinese|Traditional Chinese]] is mainly used in Hong Kong, Macau")
						:tag("span")
							:addClass("serial-comma")
							:wikitext(",")
							:done()
						:wikitext(" and Taiwan.")
			:allDone()
	end
	
	box = tostring(box)
	
	if not data.content and (namespace == 0 or namespace == 118) then
		insert(data.categories, format_cat({"Chinese terms with uncreated forms"}, langs.zh))
	end
	
	for _, word in ipairs(m_data.categorize) do
		if non_lemma_cat:match(word) then
			insert(data.categories, categorize(word))
		end
	end
	
	local lang
	if data.abbrev == "poj" then
		lang = langs["nan-hbl"]
		insert(data.categories, format_cat({"Hokkien pe̍h-ōe-jī forms"}, lang))
	else
		lang = langs.zh
	end
	
	-- Standard maintenance categories usually done by [[Module:headword]].
	local lang_maintenance_cats = {}
	local page_maintenance_cats = {}
	
	maintenance_cats(
		headword_data,
		lang,
		lang_maintenance_cats,
		page_maintenance_cats
	)
	lang_maintenance_cats = format_cat(lang_maintenance_cats, lang)
	page_maintenance_cats = format_cat(page_maintenance_cats, nil, "-")
	
	return box .. concat(data.categories) .. lang_maintenance_cats .. page_maintenance_cats
end

return export
