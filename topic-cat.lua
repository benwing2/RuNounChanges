local export = {}

local label_data = require("Module:category tree/topic cat/data")
local topic_cat_utilities_module = "Module:category tree/topic cat/utilities"
local labels_ancillary_module = "Module:labels/ancillary"

local rsplit = mw.text.split
local rgsplit = mw.text.gsplit

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
		self._lang = require("Module:languages").getByCode(self._info.code, true)
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


function Category:format_displaytitle(include_lang_prefix)
	local displaytitle = self._data.displaytitle
	if not displaytitle then
		return nil
	end
	if type(displaytitle) == "string" then
		if include_lang_prefix and self._lang then
			displaytitle = ("%s:%s"):format(self._lang:getCode(), displaytitle)
		end
	else
		displaytitle = displaytitle(self._info.label, lang, include_lang_prefix)
	end

	return displaytitle
end


function Category:getBreadcrumbName()
	local ret

	if self._lang then
		ret = self._data.breadcrumb or self:format_displaytitle(false)
	else
		ret = self._data.umbrella and self._data.umbrella.breadcrumb or
			self._data.breadcrumb or self:format_displaytitle(false)
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


function Category:replace_special_descriptions(desc)
	if not desc then
		return desc
	end

	local type_to_text = {
		topic = "related to",
		set = "for various",
		name = "for names of",
		type = "for types of",
	}
	local special_description_formats = {
		["default with the"] = "related to the",
	}

	local function format_partial_desc(desc)
		local desc_parts = {}
		local types = self._data.type or "topic"
		for typ in rgsplit(types, "%s*,%s*") do
			if not type_to_text[typ] then
				error(("Invalid type '%s', should be one or more of 'topic', 'set', 'name' or 'type', comma-separated")
					:format(types))
			end
			table.insert(desc_parts, type_to_text[typ] .. " " .. desc)
		end
		return require("Module:table").serialCommaJoin(desc_parts)
	end

	local function convert_to_full_desc(partial_desc)
		return "{{{langname}}} terms " .. partial_desc .. "."
	end

	if desc:find("^=") then
		desc = desc:gsub("^=", "")
		return convert_to_full_desc(format_partial_desc(desc))
	end

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
	if stripped_desc == "default" or special_description_formats[stripped_desc] then
		local label_sub = "label"
		if wikify then
			label_sub = label_sub .. "_wiki"
		end
		if no_singularize then
			label_sub = label_sub .. "_no_sing"
		end
		label_sub = ("{{{%s}}}"):format(label_sub)

		local partial_desc
		if special_description_formats[stripped_desc] then
			partial_desc = special_description_formats[stripped_desc] .. " " .. label_sub
		else
			partial_desc = format_partial_desc(label_sub)
		end

		return convert_to_full_desc(partial_desc)
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

	if desc:find("{{{umbrella_msg}}}") then
		local eninfo = mw.clone(self._info)
		eninfo.code = "en"
		local en = Category.new(eninfo)
		desc = desc:gsub("{{{umbrella_msg}}}", "This category contains no dictionary entries, only other categories. The subcategories are of two sorts:\n\n" ..
			"* Subcategories named like \"aa:" .. mw.getContentLanguage():ucfirst(self._info.label) .. 
			"\" (with a prefixed language code) are categories of terms in specific languages. " ..
			"You may be interested especially in [[:Category:" .. en:getCategoryName() .. "]], for English terms.\n" ..
			"* Subcategories of this one named without the prefixed language code are further categories just like this one, but devoted to finer topics."
		)
	end
	if self._lang then
		desc = desc:gsub("{{{langname}}}", self._lang:getCanonicalName())
		desc = desc:gsub("{{{langcode}}}", self._lang:getCode())
		desc = desc:gsub("{{{langcat}}}", self._lang:getCategoryName())
		desc = desc:gsub("{{{langlink}}}", self._lang:makeCategoryLink())
	end

	local function handle_label(label_sub, no_singularize, wikify)
		local function gsub_desc(to)
			return (desc:gsub(label_sub, require("Module:pattern utilities").replacement_escape(to)))
		end

		return gsub_desc(require(topic_cat_utilities_module).link_label(self._info.label, no_singularize, wikify))
	end

	for _, spec in ipairs {
		{"{{{label}}}"},
		{"{{{label_no_sing}}}", "no singularize"},
		{"{{{label_wiki}}}", false, "wikify"},
		{"{{{label_wiki_no_sing}}}", "no singularize", "wikify"},
	} do
		local label_sub, no_singularize, wikify = unpack(spec)
		if desc:find(label_sub) then
			desc = handle_label(label_sub, no_singularize, wikify)
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


function Category:getTopright()
	local def_topright_parts = {}
	local function process_box(val, pattern)
		if not val then
			return
		end
		local defval = mw.getContentLanguage():ucfirst(self._info.label)
		if type(val) ~= "table" then
			val = {val}
		end
		for _, v in ipairs(val) do
			if v == true then
				table.insert(def_topright_parts, pattern:format(defval))
			else
				table.insert(def_topright_parts, pattern:format(v))
			end
		end
	end

	process_box(self._data.wp, "{{wikipedia|%s}}")
	process_box(self._data.wpcat, "{{wikipedia|category=%s}}")
	process_box(self._data.commonscat, "{{commonscat|%s}}")

	local def_topright
	if #def_topright_parts > 0 then
		def_topright = table.concat(def_topright_parts, "\n")
	end

	if self._lang then
		return self:substitute_template_specs(self._data.topright or def_topright)
	else
		return self._data.umbrella and self:substitute_template_specs(self._data.umbrella.topright) or
			self:substitute_template_specs(def_topright)
	end
end


local function remove_lang_params(desc)
	desc = desc:gsub("^{{{langname}}} ", "")
	desc = desc:gsub("{{{langcode}}}:", "")
	desc = desc:gsub("^{{{langcode}}} ", "")
	desc = desc:gsub("^{{{langcat}}} ", "")
	return desc
end


function Category:getDescription(isChild)
	-- Allows different text in the list of a category's children
	local isChild = isChild == "child"

	local function display_title()
		local displaytitle = self:format_displaytitle("include lang prefix")
		if displaytitle then
			displaytitle = self:substitute_template_specs(displaytitle)
			mw.getCurrentFrame():callParserFunction("DISPLAYTITLE", "Category:" .. displaytitle)
		end
	end

	if not isChild and self._data.displaytitle then
		display_title()
	end

	local function get_labels_categorizing()
 		local topic_producing_labels = require(labels_ancillary_module).find_labels_for_topic(self._info.label, self._lang)
 		local function make_code(txt)
 			return ("<code>%s</code>"):format(txt)
		end
 		local formatted_labels = {}
 		for label, aliases in pairs(topic_producing_labels) do
 			if #aliases == 0 then
 				table.insert(formatted_labels, make_code(label))
 			elseif #aliases == 1 then
 				table.insert(formatted_labels, ("%s (alias %s)"):format(make_code(label), make_code(aliases[1])))
 			else
 				table.sort(aliases)
 				for i, alias in ipairs(aliases) do
 					aliases[i] = make_code(alias)
 				end
 				table.insert(formatted_labels, ("%s (aliases %s)"):format(make_code(label), table.concat(aliases, ", ")))
 			end
 		end
 		if #formatted_labels > 0 then
 			table.sort(formatted_labels)
 			return ("The following label%s generate%s this category: %s."):format(
 				#formatted_labels == 1 and "" or "s", #formatted_labels == 1 and "s" or "", table.concat(formatted_labels, "; "))
 		end
	end
		
	if self._lang then
		local desc = self._data.description

		desc = self:replace_special_descriptions(desc)
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
	else
		if self._info.label == "all topics" or self._info.label == "all sets" then
			return "This category applies to content and not to meta material about the Wiki."
		end

		local desc = self._data.umbrella and self._data.umbrella.description or self._data.umbrella_description
		local has_umbrella_desc = not not desc
		if not desc then
			 desc = self._data.description
			 if desc then
		 		desc = self:replace_special_descriptions(desc)
				desc = remove_lang_params(desc)
				desc = desc:gsub("%.$", "")
				desc = "This category concerns the topic: " .. desc .. "."
			 end
		end
		if not desc then
			desc = "Categories concerning " .. self._info.label .. " in various specific languages."
		end

		if not isChild then
			local preceding = self._data.umbrella and self._data.umbrella.preceding or
				not has_umbrella_desc and self._data.preceding
			local additional = self._data.umbrella and self._data.umbrella.additional or
				not has_umbrella_desc and self._data.additional
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
		elseif parent.sort:find("{{{langname}}}") or parent.sort:find("{{{langcat}}}") or parent.module then
			return nil
		end
		
		if not self._lang then
			parent.sort = " " .. parent.sort
		end
		
		if parent.name and parent.name:find("^Category:") then
			if self._lang then
				parent.name = self:substitute_template_specs(parent.name)
			elseif parent.name:find("{{{langname}}}") or parent.name:find("{{{langcat}}}") or parent.module then
				return nil
			end
		else
			local pinfo = mw.clone(self._info)
			pinfo.label = parent.name
			
			if parent.module then
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


	if self._data.type ~= "toplevel" then
		local types = self._data.type or "topic"
		for typ in rgsplit(types, "%s*,%s*") do
			local pinfo = mw.clone(self._info)
			pinfo.label =
				typ == "topic" and "list of topics" or
				typ == "type" and "list of type categories" or
				typ == "name" and "list of name categories" or
				typ == "set" and "list of sets" or
				error(("Invalid type '%s', should be one or more of 'topic', 'set', 'name' or 'type', comma-separated")
				:format(types))
			table.insert(ret, {name = Category.new(pinfo), sort = (not self._lang and " " or "") .. label})
		end
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
