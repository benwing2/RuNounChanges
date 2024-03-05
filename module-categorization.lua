local export = {}

local m_table = require("Module:table")

local rsplit = mw.text.split

local keyword_to_module_type = {
	common = "Utility",
	utilities = "Utility",
	headword = "Headword-line",
	translit = "Transliteration",
	decl = "Inflection",
	conj = "Inflection",
	noun = "Inflection",
	verb = "Inflection",
	adjective = "Inflection",
	nominal = "Inflection",
	pronun = "Pronunciation",
	pronunc = "Pronunciation",
	pronunciation = "Pronunciation",
	IPA = "Pronunciation",
	entryname = "Entry name-generating",
	sortkey = "Sortkey-generating",
}

-- If a module type is here, we will generate a lang-specific module-type category such as
-- [[:Category:Pali inflection modules]].
local module_type_generates_lang_specific_cat = {
	["Inflection"] = true,
	["Data"] = true,
	["Testcase"] = true,
	["Pronunciation testcase"] = true,
	["Transliteration testcase"] = true,
}

-- If a module type is here, we will generate a lang-specific module-type category such as
-- [[:Category:Pali inflection modules]].
local module_type_script_specific = {
	["Transliteration"] = true,
	["Entry name-generating"] = true,
	["Sortkey-generating"] = true,
}

local module_type_patterns = {
	{"/data%f[-/%z]", "Data"},
	{"/testcases%f[-/%z]", function(typ)
		if typ == "Pronunciation" then
			return "Pronunciation testcase"
		elseif type == "Transliteration" then
			return "Transliteration testcase"
		else
			return "Testcase"
		end
	end},
}

-- return_raw set to true makes function return table of categories with
-- "[[Category:" and "]]" stripped away. It is used by [[Module:documentation]].
function export.categorize(frame, return_raw)
	local title = mw.title.getCurrentTitle()
	local subpage = title.subpageText

	-- To ensure no categories are added on documentation pages.
	if subpage == "documentation" then
		return ""
	end

	local output, categories = {}, {}
	local namespace = title.nsText
	local pagename, mode

	if frame.args[1] then
		pagename = frame.args[1]
		pagename = pagename:gsub("^Module:", "")
		mode = "testing"
		mw.log("arg", pagename)
	else
		if namespace ~= "Module" then
			error("This template should only be used in the Module namespace.")
		end

		pagename = title.text

		if subpage ~= pagename then
			pagename = title.rootText
		end
	end

	local args
	if frame.args.is_template then
		local params = {
			[1] = {}, -- comma-separated list of languages; by default, inferred from module name
			[2] = {}, -- FIXME: used in several modules saying e.g. "per the Paiboon scheme"; ignored
			["type"] = {},
		}

		local parent_args = frame:getParent().args
		args = require("Module:parameters").process(parent_args, params)
	else
		args = {}
	end

	--[[
		If this is a transliteration, entry name-generating or sortkey-generating module, then parameter 1 is used as the code rather than the code in the page title.
	]]
	local inferred_code, module_type_keyword = pagename:match("([-%a]+)[- ]([^/]+)%f[/%z]")

	if not inferred_code then
		error(("Could not infer language/script code and module type from page name '%s'"):format(pagename))
	end

	if subpage == "sandbox" then
		table.insert(categories, "Sandbox modules")
	else
		local module_type = args.type or keyword_to_module_type[module_type_keyword]
		local langcodes = rsplit(args[1] or inferred_code, ",")
		for _, code in ipairs(langcodes) do
			local lang, sc
			local origcode = code

			if module_type then

				local getByCode = require("Module:languages").getByCode

				for stage=1,2 do
					lang = getByCode(code, nil, "allow etym") or getByCode(code .. "-pro", nil, "allow etym")

					if module_type_script_specific[module_type] then
						if not lang then
							sc = require("Module:scripts").getByCode(code)

							if sc then
								table.insert(categories, module_type .. " modules by script|" .. sc:getCanonicalName())
							end
						end
					end

					if lang or sc then
						break
					end

					-- Some modules have names like [[Module:bho-Kthi-translit]] or
					-- [[Module:Deva-Kthi-translit]]. If we didn't recognize the code the
					-- first time, try chopping off the attached script and try again.
					code = code:gsub("%-[A-Z].*", "")
				end

				if not (sc or lang) then
					if module_type_script_specific[module_type] then
						error('The language or script code "' .. origcode ..
							'" in the page title is not recognized by [[Module:languages]] or [[Module:scripts]].')
					else
						error('The language code "' .. origcode ..
							'" in the page title is not recognized by [[Module:languages]].')
					end
				end

				local function insert_overall_cat(lang, sortkey)
					m_table.insertIfNot(categories, lang:getNonEtymologicalName() .. " modules|" .. sortkey)
				end

				local function insert_overall_module_type_cat(module_type, sortkey)
					m_table.insertIfNot(categories, module_type .. " modules|" .. sortkey)
				end

				local function insert_module_type_cat(lang, module_type)
					insert_overall_module_type_cat(module_type, lang:getCanonicalName())
					if module_type_generates_lang_specific_cat[module_type] then
						m_table.insertIfNot(categories, lang:getNonEtymologicalName() .. " " ..
							mw.getContentLanguage():lcfirst(module_type) .. " modules")
					end
				end

				if module_type_script_specific[module_type] then
					local langs
					if module_type == "Transliteration" then
						langs = require("Module:languages/byTranslitModule")(pagename)
					elseif module_type == "Entry name-generating" then
						langs = require("Module:languages/byEntryNameModule")(pagename)
					elseif module_type == "Sortkey-generating" then
						langs = require("Module:languages/bySortkeyModule")(pagename)
					end

					local sortkey = module_type

					if sc then
						sortkey = sortkey .. ", " .. sc:getCanonicalName()
					end

					if langs[1] then
						for _, lang in ipairs(langs) do
							insert_overall_cat(lang, sortkey)
						end
					elseif lang then
						insert_overall_cat(lang, sortkey)
					end

					if sc then
						insert_overall_module_type_cat(module_type, sc:getCanonicalName())
					else
						insert_module_type_cat(lang, module_type)
					end
				else
					insert_overall_cat(lang, module_type)
					insert_module_type_cat(lang, module_type, lang:getCanonicalName())
				end
			else
				error('The module-type keyword "' .. module_type_keyword .. '" was not recognized.')
			end
		end
	end

	if return_raw then
		return categories
	else
		for i, cat in ipairs(categories) do
			categories[i] = "[[Category:" .. cat .. "]]"
		end
		categories = table.concat(categories)
	end

	if testing then
		table.insert(output, pagename)

		if categories == "" then
			categories = '<span class="error">failed to generate categories for ' .. pagename .. '</span>'
		else
			categories = mw.ustring.gsub(categories, "%]%]%[%[", "]]\n[[")
			categories = frame:extensionTag{ name = "syntaxhighlight", content = categories }
		end
	end

	return table.concat(output) .. categories
end

return export
