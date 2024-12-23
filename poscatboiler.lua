local concat = table.concat
local insert = table.insert
local type = type
local uupper = require("Module:string utilities").upper

local lang_independent_data = require("Module:category tree/poscatboiler/data")
local lang_specific_module = "Module:category tree/poscatboiler/data/lang-specific"
local lang_specific_module_prefix = lang_specific_module .. "/"
local auto_cat_module = "Module:auto cat"
local labels_utilities_module = "Module:labels/utilities"

-- Category object

local Category = {}
Category.__index = Category


function Category:get_originating_info()
	local originating_info = ""
	if self._info.originating_label then
		originating_info = " (originating from label \"" .. self._info.originating_label .. "\" in module [[" .. self._info.originating_module .. "]])"
	end
	return originating_info
end

local valid_keys = require("Module:table").listToSet{"code", "label", "sc", "raw", "args", "called_from_inside", "originating_label", "originating_module"}

function Category.new(info)
	for key in pairs(info) do
		if not valid_keys[key] then
			error("The parameter \"" .. key .. "\" was not recognized.")
		end
	end

	local self = setmetatable({}, Category)
	self._info = info

	if not self._info.label then
		error("No label was specified.")
	end

	self:initCommon()

	if not self._data then
		error("The " .. (self._info.raw and "raw " or "") .. "label \"" .. self._info.label .. "\" does not exist" .. self:get_originating_info() .. ".")
	end

	return self
end


function Category:initCommon()
	local args_handled = false
	if self._info.raw then
		-- Check if the category exists
		local raw_categories = lang_independent_data["RAW_CATEGORIES"]
		self._data = raw_categories[self._info.label]

		if self._data then
			if self._data.lang then
				self._lang = require("Module:languages").getByCode(self._data.lang, true, nil, nil, true)
				self._info.code = self._lang:getCode()
			end
			if self._data.sc then
				self._sc = require("Module:scripts").getByCode(self._data.sc, true, nil, true)
				self._info.sc = self._sc:getCode()
			end
		else
			-- Go through raw handlers
			local data = {
				category = self._info.label,
				args = self._info.args or {},
				called_from_inside = self._info.called_from_inside,
			}
			for _, handler in ipairs(lang_independent_data["RAW_HANDLERS"]) do
				self._data, args_handled = handler.handler(data)
				if self._data then
					self._data.module = self._data.module or handler.module
					break
				end
			end
			if self._data then
				-- Update the label if the handler specified a canonical name for it.
				if self._data.canonical_name then
					self._info.canonical_name = self._data.canonical_name
				end
				if self._data.lang then
					if type(self._data.lang) ~= "string" then
						error("Received non-string value " .. mw.dumpObject(self._data.lang) .. " for self._data.lang, label \"" .. self._info.label .. "\"" .. self:get_originating_info() .. ".")
					end
					self._lang = require("Module:languages").getByCode(self._data.lang, true, nil, nil, true)
					self._info.code = self._lang:getCode()
				end
				if self._data.sc then
					if type(self._data.sc) ~= "string" then
						error("Received non-string value " .. mw.dumpObject(self._data.sc) .. " for self._data.sc, label \"" .. self._info.label .. "\"" .. self:get_originating_info() .. ".")
					end
					self._sc = require("Module:scripts").getByCode(self._data.sc, true, nil, true)
					self._info.sc = self._sc:getCode()
				end
			end
		end
	else
		-- Already parsed into language + label
		if self._info.code then
			self._lang = require("Module:languages").getByCode(self._info.code, 1, nil, nil, true)
		else
			self._lang = nil
		end

		if self._info.sc then
			self._sc = require("Module:scripts").getByCode(self._info.sc, true, nil, true) or error("The script code \"" .. self._info.sc .. "\" is not valid.")
		else
			self._sc = nil
		end

		self._info.orig_label = self._info.label
		if not self._lang then
			-- Umbrella categories without a preceding language always begin with a capital letter, but the actual label may be
			-- lowercase (cf. [[:Category:Nouns by language]] with label 'nouns' with per-language [[:Category:English nouns]];
			-- but [[:Category:Reddit slang by language]] with label 'Reddit slang' with per-language
			-- [[:Category:English Reddit slang]]). Since the label is almost always lowercase, we lowercase it for umbrella
			-- categories, storing the original into `orig_label`, and correct it later if needed.
			self._info.label = mw.getContentLanguage():lcfirst(self._info.label)
		end
		
		-- First, check lang-specific labels and handlers if this is not an umbrella category.
		if self._lang then
			local langs_with_modules = mw.loadData(lang_specific_module)
			local obj, seen = self._lang, {}
			repeat
				if langs_with_modules[obj:getCode()] then
					local module = lang_specific_module_prefix .. obj:getCode()
					local labels_and_handlers = require(module)
					if labels_and_handlers.LABELS then
						self._data = labels_and_handlers.LABELS[self._info.label]
						if self._data then
							if self._data.umbrella == nil and self._data.umbrella_parents == nil then
								self._data.umbrella = false
							end
							self._data.module = self._data.module or module
						end
					end
					if not self._data and labels_and_handlers.HANDLERS then
						for _, handler in ipairs(labels_and_handlers.HANDLERS) do
							local data = {
								label = self._info.label,
								lang = self._lang,
								sc = self._sc,
								args = self._info.args or {},
								called_from_inside = self._info.called_from_inside,
							}
							self._data, args_handled = handler(data)
							if self._data then
								if self._data.umbrella == nil and self._data.umbrella_parents == nil then
									self._data.umbrella = false
								end
								self._data.module = self._data.module or module
								break
							end
						end
					end
					if self._data then
						break
					end
				end
				seen[obj:getCode()] = true
				obj = obj:getFamily()
			until not obj or seen[obj:getCode()]
		end

		-- Then check lang-independent labels.
		if not self._data then
			local labels = lang_independent_data["LABELS"]
			self._data = labels[self._info.label]
			-- See comment above about uppercase- vs. lowercase-initial labels, which are indistinguishable
			-- in umbrella categories.
			if not self._data then
				self._data = labels[self._info.orig_label]
				if self._data then
					self._info.label = self._info.orig_label
				end
			end
		end

		-- Then check lang-independent handlers.
		if not self._data then
			local data = {
				label = self._info.label,
				lang = self._lang,
				sc = self._sc,
				args = self._info.args or {},
				called_from_inside = self._info.called_from_inside,
			}
			for _, handler in ipairs(lang_independent_data["HANDLERS"]) do
				self._data, args_handled = handler.handler(data)
				if self._data then
					self._data.module = self._data.module or handler.module
					break
				end
			end
		end
	end

	if not args_handled and self._data and self._info.args and next(self._info.args) then
		local module_text = " (handled in [[" .. (self._data.module or "UNKNOWN").. "]])"
		local args_text = {}
		for k, v in pairs(self._info.args) do
			insert(args_text, k .. "=" .. ((type(v) == "string" or type(v) == "number") and v or mw.dumpObject(v)))
		end
		error("poscatboiler label '" .. self._info.label .. "' " .. module_text .. " doesn't accept extra args " ..
			concat(args_text, ", "))
	end

	if self._sc and not self._lang then
		error("Umbrella categories cannot have a script specified.")
	end
end


function Category:convert_spec_to_string(desc)
	if not desc then
		return desc
	elseif type(desc) == "number" then
		return tostring(desc)
	elseif type(desc) == "function" then
		return desc{
			lang = self._lang,
			sc = self._sc,
			label = self._info.label,
			raw = self._info.raw,
		}
	end
	return desc
end

-- TODO: use the template parser with this, for more sophisticated handling of multiple brackets.
function Category:substitute_template_specs(desc)
	-- This may end up happening twice but that's OK as the function is (usually) idempotent.
		-- FIXME: Not idempotent if a preprocessed template returns wikicode.
	desc = self:convert_spec_to_string(desc)

	if not desc then
		return desc
	end

	desc = desc:gsub("{{PAGENAME}}", mw.title.getCurrentTitle().text)
	desc = desc:gsub("{{{umbrella_msg}}}", "This is an umbrella category. It contains no dictionary entries, but " ..
		"only other, language-specific categories, which in turn contain relevant terms in a given language.")
	desc = desc:gsub("{{{umbrella_meta_msg}}}", "This is an umbrella metacategory, covering a general area such as " ..
		'"lemmas", "names" or "terms by etymology". It contains no dictionary entries, but holds only umbrella ' ..
		'("by language") categories covering specific subtopics, which in turn contain language-specific categories ' ..
		"holding terms in a given language for that same topic.")
	local lang = self._lang
	if lang then
		desc = desc:gsub("{{{langname}}}", lang:getCanonicalName())
		desc = desc:gsub("{{{langcode}}}", lang:getCode())
		desc = desc:gsub("{{{langcat}}}", lang:getCategoryName())
		desc = desc:gsub("{{{langlink}}}", lang:makeCategoryLink())
	end
	local sc = self._sc
	if sc then
		desc = desc:gsub("{{{scname}}}", sc:getCanonicalName())
		desc = desc:gsub("{{{sccode}}}", sc:getCode())
		desc = desc:gsub("{{{sccat}}}", sc:getCategoryName())
		desc = desc:gsub("{{{scdisp}}}", sc:getDisplayForm())
		desc = desc:gsub("{{{sclink}}}", sc:makeCategoryLink())
	end
	if desc:find("{") then
		desc = mw.getCurrentFrame():preprocess(desc)
	end
	return desc
end


function Category:substitute_template_specs_in_args(args)
	if not args then
		return args
	end
	local pinfo = {}
	for k, v in pairs(args) do
		k = self:substitute_template_specs(k)
		v = self:substitute_template_specs(v)
		pinfo[k] = v
	end
	return pinfo
end


function Category:make_new(info)
	info.originating_label = self._info.label
	info.originating_module = self._data.module
	info.called_from_inside = true
	return Category.new(info)
end


function Category:getBreadcrumbName()
	local ret

	if self._lang or self._info.raw then
		ret = self._data.breadcrumb
	else
		ret = self._data.umbrella and self._data.umbrella.breadcrumb
	end
	if not ret then
		ret = self._info.label
	end

	if type(ret) ~= "table" then
		ret = {name = ret}
	end

	local name = self:substitute_template_specs(ret.name)
	local nocap = ret.nocap

	if self._sc then
		name = name .. " in " .. self._sc:getDisplayForm()
	end

	return name, nocap
end


function Category:getTOC(toc_type)
	-- Type "none" means everything fits on a single page; in that case, display nothing.
	if toc_type == "none" then
		return nil
	end

	local function expand_toc_template_if(template)
		local template_obj = mw.title.new("Template:" .. template)
		if template_obj.exists then
			return mw.getCurrentFrame():expandTemplate{title = template_obj.text, args = {}}
		end
		return nil
	end

	-- Return the textual expansion of the first existing template among the given templates, first performing
	-- substitutions on the template name such as replacing {{{langcode}}} with the current language's code (if any).
	-- If no templates exist after expansion, or if nil is passed in, return nil. If a single string is passed in,
	-- treat it like a one-element list consisting of that string.
	local function get_template_text(templates)
		if templates == nil then
			return nil
		end
		if type(templates) ~= "table" then
			templates = {templates}
		end
		for _, template in ipairs(templates) do
			if template == false then
				return false
			end
			template = self:substitute_template_specs(template)
			return expand_toc_template_if(template)
		end
		return nil
	end

	local templates, fallback_templates

	-- If TOC type is "full" (more than 2500 entries), do the following, in order:
	-- 1. look up and expand the `toc_template_full` templates (normal or umbrella, depending on whether there is
	--    a current language);
	-- 2. look up and expand the `toc_template` templates (normal or umbrella, as above);
	-- 3. do the default behavior, which is as follows:
	-- 3a. look up a language-specific "full" template according to the current language (using English if there
	--     is no current language);
	-- 3b. look up a script-specific "full" template according to the first script of current language (using English
	--     if there is no current language);
	-- 3c. look up a language-specific "normal" template according to the current language (using English if there
	--     is no current language);
	-- 3d. look up a script-specific "normal" template according to the first script of the current language (using
	--     English if there is no current language);
	-- 3e. display nothing.
	--
	-- If TOC type is "normal" (between 200 and 2500 entries), do the following, in order:
	-- 1. look up and expand the `toc_template` templates (normal or umbrella, depending on whether there is
	--    a current language);
	-- 2. do the default behavior, which is as follows:
	-- 2a. look up a language-specific "normal" template according to the current language (using English if there
	--     is no current language);
	-- 2b. look up a script-specific "normal" template according to the first script of the current language (using
	--     English if there is no current language);
	-- 2c. display nothing.

	local data_source
	if self._lang or self._info.raw then
		data_source = self._data
	else
		data_source = self._data.umbrella
	end

	if data_source then
		if toc_type == "full" then
			templates = data_source.toc_template_full
			fallback_templates = data_source.toc_template
		else
			templates = data_source.toc_template
		end
	end

	local text = get_template_text(templates)
	if text then
		return text
	end
	if text == false then
		return nil
	end
	text = get_template_text(fallback_templates)
	if text then
		return text
	end
	if text == false then
		return nil
	end
	local default_toc_templates_to_check = {}

	local lang, sc = self:getCatfixInfo()
	local langcode = lang and lang:getCode() or "en"
	local sccode = sc and sc:getCode() or lang and lang:getScriptCodes()[1] or "Latn"
	-- FIXME: What is toctemplateprefix used for?
	local tocname = (self._data.toctemplateprefix or "") .. "categoryTOC"
	if toc_type == "full" then
		table.insert(default_toc_templates_to_check, ("%s-%s/full"):format(langcode, tocname))
		table.insert(default_toc_templates_to_check, ("%s-%s/full"):format(sccode, tocname))
	end
	table.insert(default_toc_templates_to_check, ("%s-%s"):format(langcode, tocname))
	table.insert(default_toc_templates_to_check, ("%s-%s"):format(sccode, tocname))

	for _, toc_template in ipairs(default_toc_templates_to_check) do
		local toc_template_text = expand_toc_template_if(toc_template)
		if toc_template_text then
			return toc_template_text
		end
	end

	return nil
end


function Category:getInfo()
	return self._info
end


function Category:getDataModule()
	return self._data.module
end


function Category:canBeEmpty()
	if self._lang or self._info.raw then
		return self._data.can_be_empty
	else
		return self._data.umbrella and self._data.umbrella.can_be_empty
	end
end


function Category:isHidden()
	if self._lang or self._info.raw then
		return self._data.hidden
	else
		return self._data.umbrella and self._data.umbrella.hidden
	end
end


function Category:getCategoryName()
	if self._info.raw then
		return self._info.canonical_name or self._info.label
	elseif self._lang then
		local ret = self._lang:getCanonicalName() .. " " .. self._info.label

		if self._sc then
			ret = ret .. " in " .. self._sc:getDisplayForm()
		end

		return mw.getContentLanguage():ucfirst(ret)
	else
		local ret = mw.getContentLanguage():ucfirst(self._info.label)
		if not (self._data.no_by_language or self._data.umbrella and self._data.umbrella.no_by_language) then
			ret = ret .. " by language"
		end
		return ret
	end
end


function Category:getTopright()
	if self._lang or self._info.raw then
		return self:substitute_template_specs(self._data.topright)
	else
		return self._data.umbrella and self:substitute_template_specs(self._data.umbrella.topright)
	end
end


local function remove_lang_params(desc)
	-- Simply remove a language name/code/category from the beginning of the string, but replace the language name
	-- in the middle of the string with either "specific languages" or "specific-language" depending on whether the
	-- language name appears to be an attributive qualifier of another noun or to stand by itself. This may be wrong,
	-- in which case the category in question should supply its own umbrella description.
	desc = desc:gsub("^{{{langname}}} ", "")
	desc = desc:gsub("^{{{langcode}}} ", "")
	desc = desc:gsub("^{{{langcat}}} ", "")
	desc = desc:gsub("^{{{langlink}}} ", "")
	desc = desc:gsub("{{{langname}}} %(", "specific languages (")
	desc = desc:gsub("{{{langname}}}([.,])", "specific languages%1")
	desc = desc:gsub("{{{langname}}} ", "specific-language ")
	desc = desc:gsub("{{{langcode}}} ", "")
	desc = desc:gsub("{{{langcat}}} ", "")
	desc = desc:gsub("{{{langlink}}} ", "")
	return desc
end

function Category:getDescription(isChild)
	-- Allows different text in the list of a category's children
	local isChild = isChild == "child"

	local function display_title(displaytitle, lang)
		if type(displaytitle) == "string" then
			displaytitle = self:substitute_template_specs(displaytitle)
		else
			displaytitle = displaytitle(self:getCategoryName(), lang)
		end
		mw.getCurrentFrame():callParserFunction("DISPLAYTITLE", "Category:" .. displaytitle)
	end

	local function get_labels_categorizing()
		local m_labels_utilities = require(labels_utilities_module)
		local pos_cat_labels, sense_cat_labels, use_tlb
		pos_cat_labels = m_labels_utilities.find_labels_for_category(self._info.label, "pos", self._lang)
		local sense_label = self._info.label:match("^(.*) terms$")
		if sense_label then
			use_tlb = true
		else
			sense_label = self._info.label:match("^terms with (.*) senses$")
		end
		if sense_label then
			sense_cat_labels = m_labels_utilities.find_labels_for_category(sense_label, "sense", self._lang)
			if use_tlb then
				return m_labels_utilities.format_labels_categorizing(pos_cat_labels, sense_cat_labels, self._lang)
			else
				local all_labels = pos_cat_labels
				for k, v in pairs(sense_cat_labels) do
					all_labels[k] = v
				end
				return m_labels_utilities.format_labels_categorizing(all_labels, nil, self._lang)
			end
		end
	end

	if self._lang or self._info.raw then
		if not isChild and self._data.displaytitle then
			display_title(self._data.displaytitle, self._lang)
		end

		if self._sc then
			return self:getCategoryName() .. "."
		else
			local desc = self:convert_spec_to_string(self._data.description)

			if not isChild and desc then
				if self._data.preceding then
					desc = self._data.preceding .. "\n\n" .. desc
				end
				if self._data.additional then
					desc = desc .. "\n\n" .. self._data.additional
				end
				local labels_msg = get_labels_categorizing()
				if labels_msg then
					desc = desc .. "\n\n" .. labels_msg
				end
			end

			return self:substitute_template_specs(desc)
		end
	else
		if not isChild and self._data.umbrella and self._data.umbrella.displaytitle then
			display_title(self._data.umbrella.displaytitle, nil)
		end

		local desc = self:convert_spec_to_string(self._data.umbrella and self._data.umbrella.description)
		local has_umbrella_desc = not not desc
		if not desc then
			desc = self:convert_spec_to_string(self._data.description)
			if desc then
				desc = remove_lang_params(desc)
				-- Use the following in preference to mw.getContentLanguage():lcfirst(), which will only lowercase the first
				-- character, whereas the following will correctly handle links at the beginning of the text.
				desc = require("Module:string utilities").lcfirst(desc)
				desc = desc:gsub("%.$", "")
				desc = "Categories with " .. desc .. "."
			end
		end
		if not desc then
			desc = "Categories with " .. self._info.label .. " in various specific languages."
		end
		if not isChild then
			local preceding = self:convert_spec_to_string(self._data.umbrella and self._data.umbrella.preceding or
				not has_umbrella_desc and self._data.preceding)
			local additional = self:convert_spec_to_string(self._data.umbrella and self._data.umbrella.additional or
				not has_umbrella_desc and self._data.additional)
			if preceding then
				desc = remove_lang_params(preceding) .. "\n\n" .. desc
			end
			if additional then
				desc = desc .. "\n\n" .. remove_lang_params(additional)
			end
			desc = desc .. "\n\n{{{umbrella_msg}}}"
			local labels_msg = get_labels_categorizing()
			if labels_msg then
				desc = desc .. "\n\n" .. labels_msg
			end
		end
		desc = self:substitute_template_specs(desc)
		return desc
	end
end

function Category:new_sortkey(sortkey)
	if type(sortkey) == "string" then
		sortkey = uupper(sortkey)
	elseif type(sortkey) == "table" then
		function sortkey:makeSortKey()
			if self.sort_func then
				return self.sort_func(self.sort_base)
			end
			local lang = self.lang and require("Module:languages").getByCode(self.lang, true, true, nil, true) or nil
			if lang then
				return lang:makeSortKey(
					self.sort_base,
					require("Module:scripts").getByCode(self.sc, true, nil, true)
				)
			end
			return self.sort_base
		end
	end
	
	return sortkey
end

function Category:inherit_spec(spec, parent_spec)
	if spec == false then
		return nil
	end
	return self:substitute_template_specs(spec or parent_spec)
end

function Category:canonicalize_parents_children(cats, is_children)
	if not cats then
		return nil
	end
	if type(cats) ~= "table" then
		cats = {cats}
	end
	if cats.name or cats.module then
		cats = {cats}
	end
	if #cats == 0 then
		return nil
	end

	local ret = {}

	for _, cat in ipairs(cats) do
		if type(cat) ~= "table" or not cat.name and not cat.module then
			cat = {name = cat}
		end
		insert(ret, cat)
	end

	local is_umbrella = not self._lang and not self._info.raw
	local table_type = is_children and "extra_children" or "parents"

	for i, cat in ipairs(ret) do
		local raw
		if self._info.raw or is_umbrella then
			raw = not cat.is_label
		else
			raw = cat.raw
		end
		
		local lang = self:inherit_spec(cat.lang, not raw and self._info.code or nil)
		local sc = self:inherit_spec(cat.sc, not raw and self._info.sc or nil)
		
		-- Get the sortkey.
		local sortkey = cat.sort
		if type(sortkey) == "table" then
			sortkey.sort_base = self:substitute_template_specs(sortkey.sort_base) or
				error("Missing .sort_base in '" .. table_type .. "' .sort table for '" ..
					self._info.label .. "' category entry in module '" .. (self._data.module or "unknown") .. "'")
			if sortkey.sort_func then
				-- Not allowed to give a lang and/or script if sort_func is given.
				local bad_spec = sortkey.lang and "lang" or sortkey.sc and "sc" or nil
				if bad_spec then
					error("Cannot specify both ." .. bad_spec .. " and .sort_func in '" .. table_type ..
						"' .sort table for '" .. self._info.label .. "' category entry in module '" ..
						(self._data.module or "unknown") .. "'")
				end
			else
				sortkey.lang = self:inherit_spec(sortkey.lang, lang)
				sortkey.sc = self:inherit_spec(sortkey.sc, sc)
			end
		else
			sortkey = self:substitute_template_specs(sortkey)
		end
		
		local name
		if cat.module then
			-- A reference to a category using another category tree module.
			if not cat.args then
				error("Missing .args in '" .. table_type .. "' table with module=\"" .. cat.module .. "\" for '" ..
					self._info.label .. "' category entry in module '" .. (self._data.module or "unknown") .. "'")
			end
			name = require("Module:category tree/" .. cat.module).new(self:substitute_template_specs_in_args(cat.args))
		else
			name = cat.name
			if not name then
				error("Missing .name in " .. (is_umbrella and "umbrella " or "") .. "'" .. table_type .. "' table for '" ..
					self._info.label .. "' category entry in module '" .. (self._data.module or "unknown") .. "'")
			elseif type(name) == "string" then -- otherwise, assume it's a category object and use it directly
				name = self:substitute_template_specs(name)
				if name:find("^Category:") then
					-- It's a non-poscatboiler category name.
					sortkey = sortkey or is_children and name:gsub("^Category:", "") or self:getCategoryName()
				else
					-- It's a label.
					sortkey = sortkey or is_children and name or self._info.label
					name = self:make_new{
						label = name, code = lang, sc = sc,
						raw = raw, args = self:substitute_template_specs_in_args(cat.args)
					}
				end
			end
		end
		
		sortkey = sortkey or is_children and " " or self._info.label
		
		ret[i] = {
			name = name,
			description = is_children and self:substitute_template_specs(cat.description) or nil,
			sort = self:new_sortkey(sortkey)
		}
	end

	return ret
end


function Category:getParents()
	local is_umbrella = not self._lang and not self._info.raw
	local retval
	if self._sc then
		local parent1 = self:make_new{code = self._info.code, label = "terms in " .. self._sc:getCanonicalName() .. " script"}
		local parent2 = self:make_new{code = self._info.code, label = self._info.label, raw = self._info.raw, args = self._info.args}

		retval = {
			{name = parent1, sort = self._sc:getCanonicalName()},
			{name = parent2, sort = self._sc:getCanonicalName()},
		}
	else
		local parents
		if is_umbrella then
			parents = self._data.umbrella and self._data.umbrella.parents or self._data.umbrella_parents
		else
			parents = self._data.parents
		end

		retval = self:canonicalize_parents_children(parents)
	end

	if not retval then
		return nil
	end

	local self_cat = self:getCategoryName()
	for _, parent in ipairs(retval) do
		local parent_cat = parent.name.getCategoryName and parent.name:getCategoryName()
		if self_cat == parent_cat then
			error(("Internal error: Infinite loop would occur, as parent category '%s' is the same as the child category"):
				format(self_cat))
		end
	end

	return retval
end


function Category:getChildren()
	local is_umbrella = not self._lang and not self._info.raw
	local children = self._data.children

	local ret = {}

	if not is_umbrella and children then
		for _, child in ipairs(children) do
			child = mw.clone(child)

			if type(child) ~= "table" then
				child = {name = child}
			end

			if not child.sort then
				child.sort = child.name
			end

			-- FIXME, is preserving the script correct?
			child.name = self:make_new{code = self._info.code, label = child.name, raw = child.raw, sc = self._info.sc}

			insert(ret, child)
		end
	end

	local extra_children
	if is_umbrella then
		extra_children = self._data.umbrella and self._data.umbrella.extra_children
	else
		extra_children = self._data.extra_children
	end

	extra_children = self:canonicalize_parents_children(extra_children, "children")
	if extra_children then
		for _, child in ipairs(extra_children) do
			insert(ret, child)
		end
	end

	if #ret == 0 then
		return nil
	end
	return ret
end


function Category:getUmbrella()
	local umbrella = self._data.umbrella
	if umbrella == false or self._info.raw or not self._lang or self._sc then
		return nil
	end
	-- If `umbrella` is a string, use that; otherwise, use the label.
	return self:make_new({label = type(umbrella) == "string" and umbrella or self._info.label})
end


function Category:getAppendix()
	-- FIXME, this should be customizable.
	if not self._info.raw and self._info.label and self._lang then
		local appendixName = "Appendix:" .. self._lang:getCanonicalName() .. " " .. self._info.label
		local appendix = mw.title.new(appendixName).exists
		if appendix then
			return appendixName
		else
			return nil
		end
	else
		return nil
	end
end


function Category:getCatfixInfo()
	if self._lang or self._info.raw then
		if self._data.catfix == false then
			return nil
		end
		local lang, sc
		if self._data.catfix then
			lang = require("Module:languages").getByCode(self:substitute_template_specs(self._data.catfix), true, nil, nil, true)
		else
			lang = self._lang
		end
		if self._data.catfix_sc then
			sc = require("Module:scripts").getByCode(self:substitute_template_specs(self._data.catfix_sc), true, nil, true)
		else
			sc = self._sc
		end
		return lang, sc
	else -- umbrella
		if not self._data.umbrella or not self._data.umbrella.catfix then
			return nil
		end
		local lang = require("Module:languages").getByCode(self:substitute_template_specs(self._data.umbrella.catfix), true, nil, nil, true)
		local sc = self:substitute_template_specs(self._data.umbrella.catfix_sc)
		if sc then
			sc = require("Module:scripts").getByCode(sc, true, nil, true)
		end
		return lang, sc
	end
end


function Category:getTOCTemplateName()
	-- This should only be invoked if getTOC() returns true, meaning to do the default algorithm, but getTOC()
	-- implements its own default algorithm.
	error("Internal error: This should never get called")
end


local export = {}

function export.main(info)
	local self = setmetatable({_info = info}, Category)
	
	self:initCommon()
	
	return self._data and self or nil
end

export.new = Category.new

return export
