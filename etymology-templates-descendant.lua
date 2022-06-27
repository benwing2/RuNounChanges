local export = {}

local rsplit = mw.text.split


local function qualifier(content)
	if content then
		return '<span class="ib-brac qualifier-brac">(</span><span class="ib-content qualifier-content">' .. content .. '</span><span class="ib-brac qualifier-brac">)</span>'
	end
end


local function track(page)
	return require("Module:debug/track")(page)
end


local function desc_or_desc_tree(frame, desc_tree)
	local params
	if desc_tree then
		params = {
			[1] = {required = true, default = "gem-pro"},
			[2] = {required = true, default = "*fuhsaz"},
			["notext"] = { type = "boolean" },
			["noalts"] = { type = "boolean" },
			["noparent"] = { type = "boolean" },
		}
	else
		params = {
			[1] = { required = true },
			[2] = {},
			["alts"] = { type = "boolean" }
		}
	end

	for k, v in pairs({
		[3] = { alias_of = "alt" },
		[4] = { alias_of = "t" },
		["g"] = {list = true},
		["gloss"] = { alias_of = "t" },
		["alt"] = {},
		["id"] = {},
		["lit"] = {},
		["pos"] = {},
		["t"] = {},
		["tr"] = {},
		["ts"] = {},
		["sc"] = {},
		["bor"] = { type = "boolean" },
		["lbor"] = { type = "boolean" },
		["translit"] = { type = "boolean" },
		["slb"] = { type = "boolean" },
		["der"] = { type = "boolean" },
		["clq"] = { type = "boolean" },
		["cal"] = { alias_of = "clq" },
		["calq"] = { alias_of = "clq" },
		["calque"] = { alias_of = "clq" },
		["pclq"] = { type = "boolean" },
		["sml"] = { type = "boolean" },
		["unc"] = { type = "boolean" },
		["sclb"] = { type = "boolean" },
		["nolb"] = { type = "boolean" },
		["q"] = {},
		["sandbox"] = { type = "boolean" },
	}) do
		params[k] = v
	end

	local namespace = mw.title.getCurrentTitle().nsText

	local parent_args
	if frame.args[1] then
		parent_args = frame.args
	else
		parent_args = frame:getParent().args
	end

	-- Tracking for use of 3=, 4=, or g2=/g3= etc., so we can clean these uses up.
	if parent_args[3] then
		track("descendants/arg3")
	end
	if parent_args[4] then
		track("descendants/arg4")
	end

	for i=2,10 do
		if parent_args["g" .. i] then
			track("descendants/arggn")
		end
	end

	local args = require("Module:parameters").process(parent_args, params)

	if args.sandbox then
		if namespace == "" or namespace == "Reconstruction" then
			error('The sandbox module, Module:descendants tree/sandbox, should not be used in entries.')
		end
	end
	
	local lang = args[1]
	local term = args[2]
	local alt = args["alt"]
	local gloss = args["t"]
	local tr = args["tr"]
	local ts = args["ts"]
	local sc = args["sc"]
	local id = args["id"]
	
	if namespace == "Template" then
		if not ( sc or lang ) then
			sc = "Latn"
		end
		if not lang then
			lang = "en"
		end
		if not term then
			term = "word"
		end
	end
	
	local m_languages = require("Module:languages")
	lang = m_languages.getByCode(lang, 1, "allow etym")
	local entryLang = m_languages.getNonEtymological(lang)
	
	if not desc_tree and entryLang:getType() == "family" then
		error("Cannot use language family code in [[Template:desc]].")
	end
	
	if lang:getCode() ~= entryLang:getCode() then
		-- [[Special:WhatLinksHere/Template:tracking/descendant/etymological]]
		track("descendant/etymological")
		track("descendant/etymological/" .. lang:getCode())
	end
	
	if sc then
		sc = require("Module:scripts").getByCode(sc) or error("The script code \"" .. sc .. "\" is not valid.")
	end
	
	local languageName = lang:getCanonicalName()
	local link = ""

	local genders = args["g"]
	if #genders > 0 then
		local genderstr = table.concat(genders, ",")
		genders = rsplit(genderstr, "%s*,%s*")
	end

	if term ~= "-" then
		link = require("Module:links").full_link(
			{
				lang = entryLang,
				sc = sc,
				term = term,
				alt = alt,
				id = id,
				tr = tr,
				ts = ts,
				genders = genders,
				gloss = gloss,
				pos = args["pos"],
				lit = args["lit"],
			},
			nil,
			true)
	elseif ts or gloss or #genders > 0 then
		-- [[Special:WhatLinksHere/Template:tracking/descendant/no term]]
		track("descendant/no term")
		link = require("Module:links").full_link(
			{
				lang = entryLang,
				sc = sc,
				ts = ts,
				gloss = gloss,
				genders = genders,
			},
			nil,
			true)
		link = link
			:gsub("<small>%[Term%?%]</small> ", "")
			:gsub("<small>%[Term%?%]</small>&nbsp;", "")
			:gsub("%[%[Category:[^%[%]]+ term requests%]%]", "")
	else -- display no link at all
		-- [[Special:WhatLinksHere/Template:tracking/descendant/no term or annotations]]
		track("descendant/no term or annotations")
	end
	
	local function add_tooltip(text, tooltip)
		return '<span class="desc-arr" title="' .. tooltip .. '">' .. text .. '</span>'
	end
	
	local label, arrow, descendants, alts, semi_learned, calque, partial_calque, semantic_loan, qual
	
	if args["sclb"] then
		if sc then
			label = sc:getCanonicalName()
		else
			label = require("Module:scripts").findBestScript(term, lang):getCanonicalName()
		end
	else
		label = languageName
	end
	
	if args["bor"] then
		arrow = add_tooltip("→", "borrowed")
	elseif args["lbor"] then
		arrow = add_tooltip("→", "learned borrowing")
	elseif args["translit"] then
		arrow = add_tooltip("→", "transliteration")
	elseif args["slb"] then
		arrow = add_tooltip("→", "semi-learned borrowing")
	elseif args["clq"] then
		arrow = add_tooltip("→", "calque")
	elseif args["pclq"] then
		arrow = add_tooltip("→", "partial calque")
	elseif args["sml"] then
		arrow = add_tooltip("→", "semantic loan")
	elseif args["unc"] and not args["der"] then
		arrow = add_tooltip(">", "inherited")
	else
		arrow = ""
	end
	-- allow der=1 in conjunction with bor=1 to indicate e.g. English "pars recta"
	-- derived and borrowed from Latin "pars".
	if args["der"] then
		arrow = arrow .. add_tooltip("⇒", "reshaped by analogy or addition of morphemes")
	end
	
	if args["unc"] then
		arrow = arrow .. add_tooltip("?", "uncertain")
	end

	local m_desctree
	if desc_tree or args["alts"] then
		if args.sandbox or require("Module:yesno")(frame.args.sandbox, false) then
			m_desctree = require("Module:descendants tree/sandbox")
		else
			m_desctree = require("Module:descendants tree")
		end
	end

	if desc_tree then
		descendants = m_desctree.getDescendants(entryLang, term, id, true)
	end
	
	if desc_tree and not args["noalts"] or not desc_tree and args["alts"] then
		-- [[Special:WhatLinksHere/Template:tracking/desc/alts]]
		track("desc/alts")
		alts = m_desctree.getAlternativeForms(entryLang, term, id)
	end
	
	if args["lbor"] then
		learned = " " .. qualifier("learned")
	else
		learned = ""
	end
	
	if args["translit"] then
		transliteration = " " .. qualifier("transliteration")
	else
		transliteration = ""
	end
	
	if args["slb"] then
		semi_learned = " " .. qualifier("semi-learned")
	else
		semi_learned = ""
	end
	
	if args["clq"] then
		calque = " " .. qualifier("calque")
	else
		calque = ""
	end
	
	if args["pclq"] then
		partial_calque = " " .. qualifier("partial calque")
	else
		partial_calque = ""
	end

	if args["sml"] then
		semantic_loan = " " .. qualifier("semantic loan")
	else
		semantic_loan = ""
	end
	
	if args["q"] then
		qual = " " .. require("Module:qualifier").format_qualifier(args["q"])
	else
		qual = ""
	end

	if args["noparent"] then
		return descendants
	end
	
	if arrow and arrow ~= "" then
		arrow = arrow .. " "
	end
	
	local linktext = table.concat{link, alts or "", learned, transliteration, semi_learned, calque,
		partial_calque, semantic_loan, qual, descendants or ""}
	if args["notext"] then
		return linktext
	elseif args["nolb"] then
		return arrow .. linktext
	else
		return table.concat{arrow, label, ":", linktext ~= "" and " " or "", linktext}
	end
end
	
function export.descendant(frame)
	return desc_or_desc_tree(frame, false) .. require("Module:TemplateStyles")("Module:etymology/style.css")
end

function export.descendants_tree(frame)
	return desc_or_desc_tree(frame, true)
end

return export
