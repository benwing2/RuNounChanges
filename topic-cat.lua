local export = {}

local label_data = require("Module:category tree/topic cat/data")

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
		local singular_label, singular_label_title
		if not no_singularize then
			singular_label = require("Module:string utilities").singularize(label)
			singular_label_title = mw.title.new(singular_label)
		end

		if wikify then
			if singular_label then
				desc = desc:gsub(label_sub, "[[w:" .. singular_label .. "|" .. label .. "]]")
			else
				desc = desc:gsub(label_sub, "[[w:" .. label .. "|" .. label .. "]]")
			end
		elseif singular_label_title and singular_label_title.exists then
			desc = desc:gsub(label_sub, "[[" .. singular_label .. "|" .. label .. "]]")
		else
			-- 'happiness' etc. that look like plurals but aren't
			local plural_label_title = mw.title.new(label)
			if plural_label_title and plural_label_title.exists then 
				desc = desc:gsub(label_sub, "[[" .. label .. "]]")
			else
				desc = desc:gsub(label_sub, label)
			end
		end
		return desc
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
			handle_label(label_sub, uclc, no_singularize, wikify)
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


function Category:getDisplay(isChild)
	if self._data["display"] then
		if self._info.code then
			return self._info.code .. ":" .. self._data["display"]:gsub("^%l", string.upper)
		else
			return self._data["display"]
		end
	end
	return nil
end

function Category:getDisplay2(isChild)
	if self._data["display"] then
		return self._data["display"]:gsub("^%l", string.upper)
	end
	return nil
end

function Category:getSort(isChild)
	return self._data["sort"]
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

		local display = self._data["display"] or mw.getContentLanguage():ucfirst(self._info.label)
		return
			"This category concerns the topic: " .. desc .. ".\n\n" ..
			"It contains no dictionary entries, only other categories. The subcategories are of two sorts:\n\n" ..
			"* Subcategories named like “aa:" .. display .. "” (with a prefixed language code) are categories of terms in specific languages. " ..
			"You may be interested especially in [[:Category:" .. en:getCategoryName() .. "|Category:en:" .. display .. "]], for English terms.\n" ..
			"* Subcategories of this one named without the prefixed language code are further categories just like this one, but devoted to finer topics."
	end
end


function Category:getParents()
	local parents = self._data["parents"]
	
	if not self._lang and ( self._info.label == "all topics" or self._info.label == "all sets" ) then
		return {{ name = "Category:Fundamental", sort = self._info.label:gsub("all ", "") }}
	end
	
	if not parents or #parents == 0 then
		return nil
	end
	
	local ret = {}
	local is_set = false
	
	if self._info.label == "all sets" then
		is_set = true
	end
	
	for key, parent in ipairs(parents) do
		parent = mw.clone(parent)
		
		if type(parent) ~= "table" then
			parent = {name = parent}
		end
		
		if not parent.sort then
			parent.sort = self._info.label
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
						self._info.label .. "' topic entry in module '" .. (self._data.module or "unknown") .. "'")
				end
				parent.name = require("Module:category tree/" .. parent.module).new(self:substitute_template_specs_in_args(parent.args))
			else
				parent.name = Category.new(pinfo)
			end
		end
		
		table.insert(ret, parent)
	end
	
	if not is_set and self._info.label ~= "list of topics" and self._info.label ~= "list of sets" then
		local pinfo = mw.clone(self._info)
		pinfo.label = "list of topics"
		table.insert(ret, {name = Category.new(pinfo), sort = (not self._lang and " " or "") .. self._info.label})
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
