local export = {}

local label_data = require("Module:category tree/topic cat/data")

local rsplit = mw.text.split

-- Category object

local Category = {}
Category.__index = Category

function Category.new_main(frame)
	local self = setmetatable({}, Category)
	
	local params = {
		[1] = {},
		[2] = {required = true},
		["sc"] = {},
	}
	
	args = require("Module:parameters").process(frame:getParent().args, params, nil, "category tree/topic cat", "new_main")
	self._info = {code = args[1], label = args[2]}
	
	self:initCommon()
	
	if not self._data then
		return nil
	end
	
	return self
end

function Category.new(info)
	for key, val in pairs(info) do
		if not (key == "code" or key == "label") then
			error("The parameter “" .. key .. "” was not recognized.")
		end
	end
	
	local self = setmetatable({}, Category)
	self._info = info
	
	if not self._info.label then
		error("No label was specified.")
	end
	
	self:initCommon()
	
	if not self._data then
		error("The label “" .. self._info.label .. "” does not exist.")
	end
	
	return self
end

export.new = Category.new
export.new_main = Category.new_main


function Category:initCommon()
	if self._info.code then
		self._lang = require("Module:languages").getByCode(self._info.code) or
			error("The language code “" .. self._info.code .. "” is not valid.")
	end
	
	-- Convert label to lowercase if possible
	local lowercase_label = mw.getContentLanguage():lcfirst(self._info.label)
	
	-- Check if the label exists
	local labels = label_data["LABELS"]

	if labels[lowercase_label] then
		self._info.label = lowercase_label
	end
	
	self._data = labels[self._info.label]
	
	-- Go through handlers
	if not self._data then
		for _, handler in ipairs(label_data["HANDLERS"]) do
			self._data = handler.handler(self._info.label)
			if self._data then
				self._data.module = handler.module
				break
			end
		end
	end
end


function Category:getInfo()
	return self._info
end


function Category:getBreadcrumbName()
	local ret

	if self._lang or self._info.raw then
		ret = self._data.breadcrumb
	else
		-- FIXME, copied from [[Module:category tree/poscatboiler]]. No support for specific umbrella info yet.
		ret = self._data.umbrella and self._data.umbrella.breadcrumb
	end
	if not ret then
		ret = self._info.label
	end

	if type(ret) == "string" or type(ret) == "number" then
		ret = {name = ret}
	end

	local name = self:substitute_template_specs(ret.name)
	local nocap = ret.nocap

	return name, nocap
end


function Category:getDataModule()
	return self._data.module
end


function Category:canBeEmpty()
	if self._lang then
		return false
	else
		return true
	end
end


function Category:isHidden()
	return false
end


function Category:getCategoryName()
	if self._lang then
		return self._lang:getCode() .. ":" .. mw.getContentLanguage():ucfirst(self._info.label)
	else
		return mw.getContentLanguage():ucfirst(self._info.label)
	end
end


local function replace_special_descriptions(desc)
	-- TODO: Should probably find a better way to do this
	local descriptionFormats = {
		["default"]					= "{{{langname}}} terms related to {{{label_lc}}}.",
		["default with capital"]	= "{{{langname}}} terms related to {{{label_uc}}}.",
		["default with the"]		= "{{{langname}}} terms related to the {{{label_uc}}}.",
		["default with the lower"]	= "{{{langname}}} terms related to the {{{label_lc}}}.",
		["default with topic"]		= "{{{langname}}} terms related to {{{label_lc}}} topics.",
		["default with topic capital"] = "{{{langname}}} terms related to {{{label_uc}}} topics.",
		["default-set"]				= "{{{langname}}} terms for various {{{label_lc}}}.",
		["default-set capital"]		= "{{{langname}}} terms for various {{{label_uc}}}.",
	}

	if descriptionFormats[desc] then
		return descriptionFormats[desc]
	end

	if desc then
		local stripped_desc = desc
		local no_singularize, wikify
		while true do
			local new_stripped_desc = stripped_desc:match("^(.+) no singularize$")
			if new_stripped_desc then
				stripped_desc = new_stripped_desc
				no_singularize = true
			else
				new_stripped_desc = stripped_desc:match("^(.+) wikify$")
				if new_stripped_desc then
					stripped_desc = new_stripped_desc
					wikify = true
				else
					break
				end
			end
		end
		if descriptionFormats[stripped_desc] then
			local repl_suf = "%1"
			if wikify then
				repl_suf = repl_suf .. "_wiki"
			end
			if no_singularize then
				repl_suf = repl_suf .. "_no_sing"
			end
			return descriptionFormats[stripped_desc]:gsub("({{{label_[ul]c)}}}", repl_suf .."}}}")
		end
	end

	return desc
end


function Category:substitute_template_specs(desc)
	if not desc then
		return desc
	end
	if type(desc) == "number" then
		desc = tostring(desc)
	end
	-- FIXME, when does this occur? It doesn't occur in the corresponding place in [[Module:category tree/poscatboiler]].
	if type(desc) ~= "string" then
		return desc
	end
	desc = desc:gsub("{{PAGENAME}}", mw.title.getCurrentTitle().text)
	if self._lang then
		desc = desc:gsub("{{{langname}}}", self._lang:getCanonicalName())
		desc = desc:gsub("{{{langcode}}}", self._lang:getCode())
		desc = desc:gsub("{{{langcat}}}", self._lang:getCategoryName())
		desc = desc:gsub("{{{langlink}}}", self._lang:makeCategoryLink())
	end

	local function handle_label(label_sub, uclc, no_singularize, wikify)
		local label = self._info.label
		if uclc == "uc" then
			label = mw.getContentLanguage():ucfirst(label)
		elseif uclc == "lc" then
			label = mw.getContentLanguage():lcfirst(label)
		end

		local function term_exists(term)
			local title = mw.title.new(term)
			return title and title.exists
		end

		local singular_label
		if not no_singularize then
			singular_label = require("Module:string utilities").singularize(label)
		end

		local function gsub_desc(to)
			return (desc:gsub(label_sub, require("Module:pattern utilities").replacement_escape(to)))
		end

		if wikify then
			if singular_label then
				return gsub_desc("[[w:" .. singular_label .. "|" .. label .. "]]")
			else
				return gsub_desc("[[w:" .. label .. "|" .. label .. "]]")
			end
		end

		-- First try to singularize the label as a whole, unless 'no singularize' was given. If the result exists,
		-- return it.
		if singular_label and term_exists(singular_label) then
			return gsub_desc("[[" .. singular_label .. "|" .. label .. "]]")
		elseif term_exists(label) then
			-- Then check if the original label as a whole exists, and return if so.
			return gsub_desc("[[" .. label .. "]]")
		else
			-- Otherwise, if the label is multiword, split into words and try the link each one, singularizing the last
			-- one unless 'no singularize' was given.
			local split_label
			if label:find(" ") then
				if not no_singularize then
					split_label = rsplit(label, " ")
					for i, word in ipairs(split_label) do
						if i == #split_label then
							local singular_word = require("Module:string utilities").singularize(word)
							if term_exists(singular_word) then
								split_label[i] = "[[" .. singular_word .. "|" .. word .. "]]"
							else
								split_label = nil
								break
							end
						else
							if term_exists(word) then
								split_label[i] = "[[" .. word .. "]]"
							else
								split_label = nil
								break
							end
						end
					end
					if split_label then
						split_label = table.concat(split_label, " ")
					end
				end

				-- If we weren't able to link individual words with the last word singularized, link all words as-is.
				if not split_label then
					split_label = rsplit(label, " ")
					for i, word in ipairs(split_label) do
						if term_exists(word) then
							split_label[i] = "[[" .. word .. "]]"
						else
							split_label = nil
							break
						end
					end
					if split_label then
						split_label = table.concat(split_label, " ")
					end
				end
			end

			if split_label then
				return gsub_desc(split_label)
			else
				return gsub_desc(label)
			end
		end
	end

	for _, spec in ipairs {
		{"{{{label_uc}}}", "uc"},
		{"{{{label_uc_no_sing}}}", "uc", "no singularize"},
		{"{{{label_lc}}}", "lc"},
		{"{{{label_lc_no_sing}}}", "lc", "no singularize"},
		{"{{{label_uc_wiki}}}", "uc", false, "wikify"},
		{"{{{label_uc_wiki_no_sing}}}", "uc", "no singularize", "wikify"},
		{"{{{label_lc_wiki}}}", "lc", false, "wikify"},
		{"{{{label_lc_wiki_no_sing}}}", "lc", "no singularize", "wikify"},
	} do
		local label_sub, uclc, no_singularize, wikify = unpack(spec)
		if desc:find(label_sub) then
			desc = handle_label(label_sub, uclc, no_singularize, wikify)
		end
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


function Category:getDescription(isChild)
	-- Allows different text in the list of a category's children
	local isChild = isChild == "child"

	if self._lang then
		local desc = self._data["description"]

		desc = replace_special_descriptions(desc)
		if desc then
			if not isChild and self._data.additional then
				desc = desc .. "\n\n" .. self._data.additional
			end

			return self:substitute_template_specs(desc)
		end
	else
		if not self._lang and ( self._info.label == "all topics" or self._info.label == "all sets" ) then
			return "This category applies to content and not to meta material about the Wiki."
		end

		local eninfo = mw.clone(self._info)
		eninfo.code = "en"
		local en = Category.new(eninfo)

		local desc = self._data["umbrella_description"] or self._data["description"]
		desc = replace_special_descriptions(desc)
		if desc then
			desc = desc:gsub("^{{{langname}}} ", "")
			desc = desc:gsub("{{{langcode}}}:", "")
			desc = desc:gsub("^{{{langcode}}} ", "")
			desc = desc:gsub("^{{{langcat}}} ", "")
			desc = desc:gsub("%.$", "")
			desc = self:substitute_template_specs(desc)
		else
			desc = self._info.label
		end

		return
			"This category concerns the topic: " .. desc .. ".\n\n" ..
			"It contains no dictionary entries, only other categories. The subcategories are of two sorts:\n\n" ..
			"* Subcategories named like “aa:" .. mw.getContentLanguage():ucfirst(self._info.label) .. "” (with a prefixed language code) are categories of terms in specific languages. " ..
			"You may be interested especially in [[:Category:" .. en:getCategoryName() .. "]], for English terms.\n" ..
			"* Subcategories of this one named without the prefixed language code are further categories just like this one, but devoted to finer topics."
	end
end


function Category:getParents()
	local parents = self._data["parents"]
	local label = self._info.label

	if not self._lang and ( label == "all topics" or label == "all sets" ) then
		return {{ name = "Category:Fundamental", sort = label:gsub("all ", "") }}
	end
	
	if not parents or #parents == 0 then
		return nil
	end
	
	local ret = {}
	local is_set = false
	
	if label == "all sets" then
		is_set = true
	end
	
	for key, parent in ipairs(parents) do
		parent = mw.clone(parent)
		
		if type(parent) ~= "table" then
			parent = {name = parent}
		end
		
		if not parent.sort then
			-- When defaulting sort key to label, strip 'The ' (e.g. in 'The Matrix', 'The Hunger Games')
			-- and 'A ' (e.g. in 'A Song of Ice and Fire', 'A Christmas Carol') from label.
			local stripped_sort = label:match("^[Tt]he (.*)$")
			if stripped_sort then
				parent.sort = stripped_sort
			end
			if not stripped_sort then
				stripped_sort = label:match("^[Aa] (.*)$")
				if stripped_sort then
					parent.sort = stripped_sort
				end
			end
			if not stripped_sort then
				parent.sort = label
			end
		end
		
		if self._lang then
			parent.sort = self:substitute_template_specs(parent.sort)
		elseif parent.sort:find("{{{langname}}}") or parent.sort:find("{{{langcat}}}") or
			parent.template == "langcatboiler" or parent.module then
			return nil
		end
		
		if not self._lang then
			parent.sort = " " .. parent.sort
		end
		
		if parent.name and parent.name:find("^Category:") then
			if self._lang then
				parent.name = self:substitute_template_specs(parent.name)
			elseif parent.name:find("{{{langname}}}") or parent.name:find("{{{langcat}}}") or
				parent.template == "langcatboiler" or parent.module then
				return nil
			end
		else
			if parent.name == "list of sets" then
				is_set = true
			end
			
			local pinfo = mw.clone(self._info)
			pinfo.label = parent.name
			
			if parent.template then
				parent.name = require("Module:category tree/" .. parent.template).new(pinfo)
			elseif parent.module then
				-- A reference to a category using another category tree module.
				if not parent.args then
					error("Missing .args in parent table with module=\"" .. parent.module .. "\" for '" ..
						label .. "' topic entry in module '" .. (self._data.module or "unknown") .. "'")
				end
				parent.name = require("Module:category tree/" .. parent.module).new(self:substitute_template_specs_in_args(parent.args))
			else
				parent.name = Category.new(pinfo)
			end
		end
		
		table.insert(ret, parent)
	end
	
	if not is_set and label ~= "list of topics" and label ~= "list of sets" then
		local pinfo = mw.clone(self._info)
		pinfo.label = "list of topics"
		table.insert(ret, {name = Category.new(pinfo), sort = (not self._lang and " " or "") .. label})
	end
	
	return ret
end


function Category:getChildren()
	return nil
end


function Category:getUmbrella()
	if not self._lang then
		return nil
	end
	
	local uinfo = mw.clone(self._info)
	uinfo.code = nil
	return Category.new(uinfo)
end


function Category:getTOCTemplateName()
	local lang = self._lang
	local code = lang and lang:getCode() or "en"
	return "Template:" .. code .. "-categoryTOC"
end


return export
