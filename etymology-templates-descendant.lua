local export = {}

local rsplit = mw.text.split

local error_on_no_descendants = false


local function qualifier(content)
	if content then
		return '<span class="ib-brac qualifier-brac">(</span><span class="ib-content qualifier-content">' .. content .. '</span><span class="ib-brac qualifier-brac">)</span>'
	end
end


local function track(page)
	return require("Module:debug/track")("descendant/" .. page)
end


local function ine(arg)
	if arg == "" then
		return nil
	else
		return arg
	end
end


local function add_tooltip(text, tooltip)
	return '<span class="desc-arr" title="' .. tooltip .. '">' .. text .. '</span>'
end


local function desc_or_desc_tree(frame, desc_tree)
	local params
	if desc_tree then
		params = {
			[1] = {required = true, default = "gem-pro"},
			[2] = {required = true, list = true, allow_holes = true, default = "*fuhsaz"},
			["notext"] = {type = "boolean"},
			["noalts"] = {type = "boolean"},
			["noparent"] = {type = "boolean"},
		}
	else
		params = {
			[1] = {required = true},
			[2] = {list = true, allow_holes = true},
			["alts"] = {type = "boolean"}
		}
	end

	for k, v in pairs({
		["alt"] = {list = true, allow_holes = true},
		["g"] = {list = true, allow_holes = true},
		["gloss"] = {alias_of = "t", list = true, allow_holes = true},
		["id"] = {list = true, allow_holes = true},
		["lit"] = {list = true, allow_holes = true},
		["pos"] = {list = true, allow_holes = true},
		["t"] = {list = true, allow_holes = true},
		["tr"] = {list = true, allow_holes = true},
		["ts"] = {list = true, allow_holes = true},
		["sc"] = {list = true, allow_holes = true},
		["inh"] = {type = "boolean"},
		["partinh"] = {type = "boolean", list = "inh", allow_holes = true, require_index = true},
		["bor"] = {type = "boolean"},
		["partbor"] = {type = "boolean", list = "bor", allow_holes = true, require_index = true},
		["lbor"] = {type = "boolean"},
		["partlbor"] = {type = "boolean", list = "lbor", allow_holes = true, require_index = true},
		["slb"] = {type = "boolean"},
		["partslb"] = {type = "boolean", list = "slb", allow_holes = true, require_index = true},
		["translit"] = {type = "boolean"},
		["parttranslit"] = {type = "boolean", list = "translit", allow_holes = true, require_index = true},
		["der"] = {type = "boolean"},
		["partder"] = {type = "boolean", list = "der", allow_holes = true, require_index = true},
		["clq"] = {type = "boolean"},
		["partclq"] = {type = "boolean", list = "clq", allow_holes = true, require_index = true},
		["cal"] = {alias_of = "clq", type = "boolean"},
		["partcal"] = {alias_of = "partclq", type = "boolean", list = "cal", allow_holes = true, require_index = true},
		["calq"] = {alias_of = "clq", type = "boolean"},
		["partcalq"] = {alias_of = "partclq", type = "boolean", list = "calq", allow_holes = true, require_index = true},
		["calque"] = {alias_of = "clq", type = "boolean"},
		["partcalque"] = {alias_of = "partclq", type = "boolean", list = "calque", allow_holes = true, require_index = true},
		["pclq"] = {type = "boolean"},
		["partpclq"] = {type = "boolean", list = "pclq", allow_holes = true, require_index = true},
		["sml"] = {type = "boolean"},
		["partsml"] = {type = "boolean", list = "sml", allow_holes = true, require_index = true},
		["unc"] = {type = "boolean"},
		["partunc"] = {type = "boolean", list = "unc", allow_holes = true, require_index = true},
		["sclb"] = {type = "boolean"},
		["nolb"] = {type = "boolean"},
		["q"] = {},
		["qq"] = {},
		["partqq"] = {list = "qq", allow_holes = true, require_index = true},
		["sandbox"] = {type = "boolean"},
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

	-- Error to catch most uses of old-style parameters.
	if ine(parent_args[4]) and not ine(parent_args[3]) and not ine(parent_args.tr2) and not ine(parent_args.ts2)
		and not ine(parent_args.t2) and not ine(parent_args.gloss2) and not ine(parent_args.g2)
		and not ine(parent_args.alt2) then
		error("You specified a term in 4= and not one in 3=. You probably meant to use t= to specify a gloss instead. "
			.. "If you intended to specify two terms, put the second term in 3=.")
	end
	if not ine(parent_args[3]) and not ine(parent_args.alt2) and not ine(parent_args.tr2) and not ine(parent_args.ts2)
		and ine(parent_args.g2) then
		error("You specified a gender in g2= but no term in 3=. You were probably trying to specify two genders for "
			.. "a single term. To do that, put both genders in g=, comma-separated.")
	end

	if parent_args.q then
		track("q")
		error("Please use qq= not q=. q= will be switching to put the qualifier *before* the term, not after.")
	end

	local args = require("Module:parameters").process(parent_args, params)

	if args.sandbox then
		if namespace == "" or namespace == "Reconstruction" then
			error("The sandbox module, Module:descendants tree/sandbox, should not be used in entries.")
		end
	end

	local m_desctree
	if desc_tree or args["alts"] then
		if args.sandbox or require("Module:yesno")(frame.args.sandbox, false) then
			m_desctree = require("Module:descendants tree/sandbox")
		else
			m_desctree = require("Module:descendants tree")
		end
	end

	local lang = args[1]
	local terms = args[2]

	if mw.title.getCurrentTitle().nsText == "Template" then
		lang = lang or "en"
		if #terms == 0 then
			terms = {"word"}
			terms.maxindex = 1
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
		track("etymological")
		track("etymological/" .. lang:getCode())
	end

	local languageName = lang:getCanonicalName()

	local label

	if args["sclb"] then
		local sc = args["sc"][1] and require("Module:scripts").getByCode(args["sc"][1], "sc")
		local term = terms[1]
		if sc then
			label = sc:getCanonicalName()
		else
			label = require("Module:scripts").findBestScript(term, lang):getCanonicalName()
		end
	else
		label = languageName
	end

	-- Find the maximum index among any of the list parameters.
	local maxmaxindex = terms.maxindex
	for k, v in pairs(args) do
		if type(v) == "table" and v.maxindex and v.maxindex > maxmaxindex then
			maxmaxindex = v.maxindex
		end
	end

	local function get_arrow(index)
		local function val(arg)
			if index == 0 then
				return args[arg]
			else
				return args["part" .. arg][index]
			end
		end

		local arrow

		if val("bor") then
			arrow = add_tooltip("→", "borrowed")
		elseif val("lbor") then
			arrow = add_tooltip("→", "learned borrowing")
		elseif val("slb") then
			arrow = add_tooltip("→", "semi-learned borrowing")
		elseif args["translit"] then
			arrow = add_tooltip("→", "transliteration")
		elseif val("clq") then
			arrow = add_tooltip("→", "calque")
		elseif val("pclq") then
			arrow = add_tooltip("→", "partial calque")
		elseif val("sml") then
			arrow = add_tooltip("→", "semantic loan")
		elseif val("inh") or (val("unc") and not val("der")) then
			arrow = add_tooltip(">", "inherited")
		else
			arrow = ""
		end
		-- allow der=1 in conjunction with bor=1 to indicate e.g. English "pars recta"
		-- derived and borrowed from Latin "pars".
		if val("der") then
			arrow = arrow .. add_tooltip("⇒", "reshaped by analogy or addition of morphemes")
		end

		if val("unc") then
			arrow = arrow .. add_tooltip("?", "uncertain")
		end

		if arrow ~= "" then
			arrow = arrow .. " "
		end

		return arrow
	end

	local function get_post_qualifiers(index)
		local function val(arg)
			if index == 0 then
				return args[arg]
			else
				return args["part" .. arg][index]
			end
		end

		local postqs = {}
		if val("inh") then
			table.insert(postqs, qualifier("inherited"))
		end
		if val("lbor") then
			table.insert(postqs, qualifier("learned"))
		end
		if val("slb") then
			table.insert(postqs, qualifier("semi-learned"))
		end
		if val("translit") then
			table.insert(postqs, qualifier("transliteration"))
		end
		if val("clq") then
			table.insert(postqs, qualifier("calque"))
		end
		if val("pclq") then
			table.insert(postqs, qualifier("partial calque"))
		end
		if val("sml") then
			table.insert(postqs, qualifier("semantic loan"))
		end
		-- FIXME, should we use the qualifier support in full_link() (in which case the qualifier precedes the term)?
		if index == 0 and val("q") then -- FIXME: Switch to pre-term qualifier
			table.insert(postqs, require("Module:qualifier").format_qualifier(val("q")))
		end
		if val("qq") then
			table.insert(postqs, require("Module:qualifier").format_qualifier(val("qq")))
		end
		if #postqs > 0 then
			return " " .. table.concat(postqs, " ")
		else
			return ""
		end
	end

	local parts = {}
	local descendants = {}
	local saw_descendants = false
	local seen_terms = {}

	for i = 1, maxmaxindex do
		local term = terms[i]
		local alt = args["alt"][i]
		local id = args["id"][i]
		local sc = args["sc"][i] and require("Module:scripts").getByCode(args["sc"][i], "sc" .. (i == 1 and "" or i))
		local tr = args["tr"][i]
		local ts = args["ts"][i]
		local gloss = args["t"][i]
		local pos = args["pos"][i]
		local lit = args["lit"][i]
		local g = args["g"][i] and rsplit(args["g"][i], "%s*,%s*") or {}

		local link = ""

		if term ~= "-" then -- including term == nil
			link = require("Module:links").full_link(
				{
					lang = entryLang,
					sc = sc,
					term = term,
					alt = alt,
					id = id,
					tr = tr,
					ts = ts,
					genders = g,
					gloss = gloss,
					pos = pos,
					lit = lit,
				},
				nil,
				true)
		elseif ts or gloss or #g > 0 then
			-- [[Special:WhatLinksHere/Template:tracking/descendant/no term]]
			track("no term")
			link = require("Module:links").full_link(
				{
					lang = entryLang,
					sc = sc,
					ts = ts,
					gloss = gloss,
					genders = g,
				},
				nil,
				true)
			link = link
				:gsub("<small>%[Term%?%]</small> ", "")
				:gsub("<small>%[Term%?%]</small>&nbsp;", "")
				:gsub("%[%[Category:[^%[%]]+ term requests%]%]", "")
		else -- display no link at all
			-- [[Special:WhatLinksHere/Template:tracking/descendant/no term or annotations]]
			track("no term or annotations")
		end

		local arrow = get_arrow(i)
		local postqs = get_post_qualifiers(i)
		local alts

		if desc_tree and term and term ~= "-" then
			table.insert(seen_terms, term)
			-- This is what I ([[User:Benwing2]]) had in Nov 2020 when I first implemented this.
			-- Since then, [[User:Fytcha]] added `true` as the fourth param.
			-- descendants[i] = m_desctree.getDescendants(entryLang, term, id, maxmaxindex > 1)
			descendants[i] = m_desctree.getDescendants(entryLang, term, id, true)
			if descendants[i] then
				saw_descendants = true
			end
		end

		descendants[i] = descendants[i] or ""

		if term and (desc_tree and not args["noalts"] or not desc_tree and args["alts"]) then
			-- [[Special:WhatLinksHere/Template:tracking/descendant/alts]]
			track("alts")
			alts = m_desctree.getAlternativeForms(entryLang, term, id)
		else
			alts = ""
		end

		local linktext = table.concat{link, alts, postqs}
		if not args["notext"] then
			linktext = arrow .. linktext
		end
		if linktext ~= "" then
			table.insert(parts, linktext)
		end
	end

	if error_on_no_descendants and desc_tree and not saw_descendants then
		if #seen_terms == 0 then
			error("[[Template:desctree]] invoked but no terms to retrieve descendants from")
		elseif #seen_terms == 1 then
			error("No Descendants section was found in the entry [[" .. seen_terms[1] ..
				"]] under the header for " .. entryLang:getCanonicalName() .. ".")
		else
			for i, term in ipairs(seen_terms) do
				seen_terms[i] = "[[" .. term .. "]]"
			end
			error("No Descendants section was found in any of the entries " ..
				table.concat(seen_terms, ", ") .. " under the header for " .. entryLang:getCanonicalName() .. ".")
		end
	end

	descendants = table.concat(descendants)
	if args["noparent"] then
		return descendants
	end

	local initial_arrow = get_arrow(0)
	local final_postqs = get_post_qualifiers(0)

	local all_linktext = table.concat(parts, ", ") .. final_postqs .. descendants

	if args["notext"] then
		return all_linktext
	elseif args["nolb"] then
		return initial_arrow .. all_linktext
	else
		return table.concat{initial_arrow, label, ":", all_linktext ~= "" and " " or "", all_linktext}
	end
end

function export.descendant(frame)
	return desc_or_desc_tree(frame, false) .. require("Module:TemplateStyles")("Module:etymology/style.css")
end

function export.descendants_tree(frame)
	return desc_or_desc_tree(frame, true)
end

return export
