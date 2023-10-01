local raw_categories = {}
local raw_handlers = {}


-----------------------------------------------------------------------------
--                                                                         --
--                              RAW CATEGORIES                             --
--                                                                         --
-----------------------------------------------------------------------------


raw_categories["Wiktionary"] = {
	description = "High level category for material about Wiktionary and its operation.",
	parents = {
		"Fundamental",
	},
}

raw_categories["Wiktionary users"] = {
	description = "Pages listing Wiktionarians according to their user rights and categories listing Wiktionarians according to their linguistic and coding abilities.",
	breadcrumb = "Users",
	additional = "For an automatically generated list of all users, see [[Special:ListUsers]].",
	parents = {
		{name = "Wiktionary", sort = "Users"},
	},
}

raw_categories["User languages"] = {
	description = "Categories listing Wiktionarians according to their linguistic abilities.",
	parents = {
		"Wiktionary users",
		"Category:Wiktionary multilingual issues",
	},
}

raw_categories["User languages with invalid code"] = {
	description = "Categories listing Wiktionarians according to their linguistic abilities, where the language code is invalid for Wiktionary.",
	additional = "Most of these codes are valid ISO 639-3 codes but are invalid in Wiktionary for various reasons, " ..
	"typically due to different choices made regarding splitting and merging languages.",
	parents = {
		{name = "User languages", sort = " "},
	},
}

raw_categories["Wiktionary"] = {
	description = "High level category for material about Wiktionary and its operation.",
	parents = {
		"Fundamental",
	},
}


-----------------------------------------------------------------------------
--                                                                         --
--                                RAW HANDLERS                             --
--                                                                         --
-----------------------------------------------------------------------------


-- Fancy version of ine() (if-not-empty). Converts empty string to nil, but also strips leading/trailing space.
local function ine(arg)
	if not arg then return nil end
	arg = mw.text.trim(arg)
	if arg == "" then return nil end
	return arg
end


table.insert(raw_handlers, function(data)
	local langcode, level
	if not langcode then
		langcode, level = data.category:match("^User ([a-z][a-z][a-z]?)%-([0-5N])$")
	end
	if not langcode then
		langcode, level = data.category:match("^User ([a-z][a-z][a-z]?%-[a-zA-Z-]+)%-([0-5N])$")
	end
	if not langcode then
		langcode = data.category:match("^User ([a-z][a-z][a-z]?)$")
	end
	if not langcode then
		langcode = data.category:match("^User ([a-z][a-z][a-z]?%-[a-zA-Z-]+)$")
	end
	if not langcode then
		return
	end
	local lang = require("Module:languages").getByCode(langcode, nil, "allow etym")
	if not lang then
		-- If unrecognized language and called from inside, we're handling the parents and breadcrumb for a
		-- higher-level category, so at least return something.
		if not level and data.called_from_inside then
			return {
				breadcrumb = {name = langcode, nocap = true}, -- FIXME, scrape langname= category?
				parents = {
					{name = "User languages with invalid code", sort = langcode},
				}
			}, true
		end
				
		if not ine(data.args.langname) then
			return
		end
	end
	local params = {
		text = {},
		verb = {},
		langname = {},
		standard = {type = "boolean"},
	}

	local args = require("Module:parameters").process(data.args, params)

	local langname = args.langname or lang:getCanonicalName()

	local level_params = {
		["0"] = {
			leftcolor = "#FFB3B3",
			rightcolor = "#FFE0E8",
			en = "These users do not understand LANG (or understand it with considerable difficulty).",
		},
		["1"] = {
			leftcolor = "#C0C8FF",
			rightcolor = "#F0F8FF",
			en = "These users are able to contribute with a '''basic''' level of LANG.",
		},
		["2"] = {
			leftcolor = "#77E0E8",
			rightcolor = "#D0F8FF",
			en = "These users are able to contribute with an '''intermediate''' level of LANG.",
		},
		["3"] = {
			leftcolor = "#99B3FF",
			rightcolor = "#E0E8FF",
			en = "These users are able to contribute with an '''advanced''' level of LANG.",
		},
		["4"] = {
			leftcolor = "#CCCC00",
			rightcolor = "#FFFF99",
			en = "These users speak LANG at a '''near native''' level.",
		},
		["5"] = {
			leftcolor = "#FF5E5E",
			rightcolor = "#FF8080",
			en = "These users are able to contribute with a '''professional''' level of LANG.",
		},
		["N"] = {
			leftcolor = "#6EF7A7",
			rightcolor = "#C5FCDC",
			en = "These users are '''native''' speakers of LANG.",
		},
	}

	local parts = {}
	local function ins(txt)
		table.insert(parts, txt)
	end
	-- Insert text, appropriately script-tagged, unless already script-tagged (we check for '<span'), in which case we
	-- insert it directly. Also handle <<...>> in text and convert to bolded link to parent category.
	local function ins_and_wrap(txt)
		if not txt then
			return
		end
		-- Substitute <<...>> (where ... is supposed to be the native rendering of the language) with a link to the
		-- top-level 'User CODE' category (e.g. [[:Category:User fr]] or [[:Category:User fr-CA]]) if we're in a
		-- sublevel category, or to the top-level language category (e.g. [[:Category:French language]] or
		-- [[:Category:Canadian English]]) if we're in a top-level 'User CODE' category.
		txt = txt:gsub("<<(.-)>>", function(inside)
			if level then
				return ("'''[[:Category:User %s|%s]]'''"):format(langcode, inside)
			elseif lang then
				return ("'''[[:Category:%s|%s]]'''"):format(lang:getCategoryName(), inside)
			else
				return ("'''%s'''"):format(inside)
			end
		end)
		if txt:find("<span") or not lang then
			ins(txt)
		else
			ins(require("Module:script utilities").tag_text(txt, lang))
		end
	end

	local function insert_request_cats(parents)
		if args.text or langcode == "en" or langcode:find("^en%-") then
			return
		end
		local num_pages = mw.site.stats.pagesInCategory(data.category, "pages")
		local count_cat, count_sort
		if num_pages == 0 then
			count_cat = "Requests for translations in user-competency categories with 0 users"
			count_sort = "*" .. langcode
		elseif num_pages == 1 then
			count_cat = "Requests for translations in user-competency categories with 1 user"
			count_sort = "*" .. langcode
		else
			local lowernum, uppernum
			lowernum = 2
			while true do
				uppernum = lowernum * 2 - 1
				if num_pages <= uppernum then
					break
				end
				lowernum = lowernum * 2
			end
			count_cat = ("Requests for translations in user-competency categories with %s-%s users"):format(
				lowernum, uppernum)
			count_sort = "*" .. ("%0" .. #(tostring(uppernum)) .. "d"):format(num_pages)
		end

		table.insert(parents, {
			name = "Requests for translations in user-competency categories by language",
			sort = langcode,
		})
		table.insert(parents, {
			name = count_cat,
			sort = count_sort,
		})
	end

	local invalid_lang_warning
	if not lang then
		invalid_lang_warning = "'''WARNING''': The specified language code is invalid on Wiktionary. Please migrate all " ..
			"competency ratings to the closest valid code."
	end

	if level then
		local params = level_params[level]

		ins(('<div style="float:left;border:solid %s 1px;margin:1px">'):format(params.leftcolor))
		ins(('<table cellspacing="0" style="width:238px;background:%s"><tr>'):format(params.rightcolor))
		ins(('<td style="width:45px;height:45px;background:%s;text-align:center;font-size:14pt">'):format(params.leftcolor))
		ins(("'''%s-%s'''</td>"):format(langcode, level))
		ins('<td style="font-size:8pt;padding:4pt;line-height:1.25em">')
		ins_and_wrap(args.text)
		if args.standard ~= false then
			if args.text then
				ins("<hr />")
			end
			local langcat = ("'''[[:Category:User %s|%s]]'''"):format(langcode, langname)
			local en = params.en:gsub("LANG", langcat)
			ins(en)
		end
		ins('</td></tr></table></div><br clear="left">')
		local parents = {
			{name = ("User %s"):format(langcode), sort = level},
		}
		insert_request_cats(parents)
		return {
			description = table.concat(parts),
			additional = ("To be included on this list, add {{tl|Babel|%s}} to your user page. Complete instructions are " ..
				"available at [[Wiktionary:Babel]]."):format(level == "N" and langcode or ("%s-%s"):format(langcode, level)) ..
				(invalid_lang_warning and "\n\n" .. invalid_lang_warning or ""),
			breadcrumb = "Level " .. level,
			parents = parents,
		}, true
	else
		ins('<div style="float:left;border:solid #99b3ff 1px;margin:1px;">\n')
		ins('{| cellspacing="0" style="width:260px;background:#e0e8ff;"\n')
		ins('| style="width:45px;height:45px;background:#99b3ff;text-align:center;font-size:14pt;" | ')
		ins(("'''%s'''\n"):format(langcode))
		ins('| style="font-size:8pt;padding:4pt;line-height:1.25em;text-align:center;" | ')
		ins_and_wrap(args.text)
		-- Not all sign languages end in Sign Language (cf. [[Auslan]]). Most or all have 'sgn' or 'sgn-*' as the
		-- family, though.
		local is_sign_language = lang and lang:getFamilyCode():find("^sgn") or langname:find("Sign Language$")
		if args.standard ~= false then
			if args.text then
				ins("<hr />")
			end
			ins(("These users %s '''%s'''.\n"):format(args.verb or is_sign_language and "communicate in" or "speak",
				lang and ("[[:Category:%s|%s]]"):format(lang:getCategoryName(), langname) or ("[[%s]]"):format(langname)))
		end
		ins('|}</div><br clear="all">')
		local parents
		if lang then
			parents = {
				{name = "User languages", sort = langcode},
				{name = lang:getCategoryName(), sort = "user"},
			}
			if lang:hasType("etymology-only") then
				table.insert(parents, {name = lang:getNonEtymological():getCategoryName(), sort = " " .. langcode})
			end
		else
			parents = {
				{name = "User languages with invalid code", sort = langcode},
			}
		end
		insert_request_cats(parents)

		return {
			description = table.concat(parts),
			additional = ("To be included on this list, use {{tl|Babel}} on your user page. Complete instructions are " ..
				"available at [[Wiktionary:Babel]].") ..
				(invalid_lang_warning and "\n\n" .. invalid_lang_warning or ""),
			breadcrumb = langname,
			parents = parents,
		}, true
	end
end)


return {RAW_CATEGORIES = raw_categories, RAW_HANDLERS = raw_handlers}
