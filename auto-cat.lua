local export = {}

-- Used in multiple places; create a variable for ease in testing.
local poscatboiler_submodule = "poscatboiler"


local function splitLabelLang(titleObject)
	local getByCanonicalName = require("Module:languages").getByCanonicalName
	local canonicalName
	local lang
	
	-- Progressively add another word to the potential canonical name until it
	-- matches an actual canonical name.
	local words = mw.text.split(titleObject.text, " ")
	for i = #words - 1, 1, -1 do
		canonicalName = table.concat(words, " ", 1, i)
		lang = getByCanonicalName(canonicalName)
		if lang then
			break
		end
	end
	
	local label = lang and titleObject.text:sub(#canonicalName + 2)
		or titleObject.text
	
	return label, lang
end


-- Add the arguments in `source` to those in `receiver`, offsetting numeric arguments by `offset`.
local function add_args(receiver, source, offset)
	for k, v in pairs(source) do
		if type(k) == "number" then
			receiver[k + offset] = v
		else
			receiver[k] = v
		end
	end
	return receiver
end


-- List of handler functions that try to match the page name.
-- A handler should return a table of template title plus arguments
-- that is passed to frame:expandTemplate.
-- If a handler does not recognise the page name, it should return nil.
-- Note that the order of functions matters!

local handlers = {}

local function add_handler(func)
	table.insert(handlers, func)
end


-- Topical categories
add_handler(function(titleObject)
	if not titleObject.text:find("^[a-z-]+:.") then
		return nil
	end
	
	local code, label = titleObject.text:match("^([a-z-]+):(.+)$")
	return {title = "topic cat", args = {code, label}}
end)


-- Letter names
add_handler(function(titleObject)
	if not titleObject.text:find("letter names$") then
		return nil
	end
	
	local langCode = titleObject.text:match("^([^:]+):")
	local lang, cat
	
	if langCode then
		lang = require("Module:languages").getByCode(langCode) or error('The language code "' .. langCode .. '" is not valid.')
		cat = titleObject.text:match(":(.+)$")
	else
		cat = titleObject.text
	end
	
	return {title = "topic cat", args = {lang and lang:getCode() or nil, cat}}
end)


-- letter cat
add_handler(function(titleObject)
	-- Only recognize cases consisting of an uppercase letter followed by the
	-- corresponding lowercase letter, either as the entire category name or
	-- followed by a colon (for cases like [[Category:Gg: ⠛]]). Cases that
	-- don't fit this profile (e.g. for Turkish [[Category:İi]] and
	-- [[Category:Iı]]) need to call {{letter cat}} directly. Formerly this
	-- handler was much less restrictive and would fire on categories named
	-- [[Category:zh:]], [[Category:RFQ]], etc.
	local upper, lower = mw.ustring.match(titleObject.text, "^(%u)(%l)%f[:%z]")
	if not upper or lower:uupper() ~= upper then
		return nil
	end

	return {title = "letter cat"}
end)


-- poscatboiler lang-specific
add_handler(function(titleObject, args)
	local label, lang = splitLabelLang(titleObject)
	if lang then
		local baseLabel, script = label:match("(.+) in (.-) script$")
		if script and baseLabel ~= "terms" then
			local scriptObj = require("Module:scripts").getByCanonicalName(script)
			if scriptObj then
				return {title = poscatboiler_submodule, args = add_args({lang:getCode(), baseLabel, scriptObj:getCode()}, args, 3)}, true
			end
		end
		return {title = poscatboiler_submodule, args = add_args({lang:getCode(), label}, args, 3)}, true
	end
end)


-- poscatboiler umbrella category
add_handler(function(titleObject, args)
	local label = titleObject.text:match("(.+) by language$")
	if label then
		return {
			title = poscatboiler_submodule,
			args = add_args({nil, mw.getContentLanguage():lcfirst(label)}, args, 3)
		}, true
	end
end)


-- topic cat
add_handler(function(titleObject)
	return {title = "topic cat", args = {nil, titleObject.text}}
end)


-- poscatboiler raw handlers
add_handler(function(titleObject, args)
	local args = add_args({nil, titleObject.text}, args, 3)
	args.raw = true
	return {
		title = poscatboiler_submodule,
		args = args,
	}, true
end)


-- poscatboiler umbrella handlers without 'by language'
add_handler(function(titleObject, args)
	local args = add_args({nil, mw.getContentLanguage():lcfirst(titleObject.text)}, args, 3)
	return {
		title = poscatboiler_submodule,
		args = args,
	}, true
end)


function export.show(frame)
	local args = frame:getParent().args
	local titleObject = mw.title.getCurrentTitle()
	
	if titleObject.nsText == "Template" then
		return "(This template should be used on pages in the Category: namespace.)"
	elseif titleObject.nsText ~= "Category" then
		error("This template/module can only be used on pages in the Category: namespace.")
	end

	local function extra_args_error(templateObject)
		local numargstext = {}
		local argstext = {}
		local maxargnum = 0
		for k, v in pairs(templateObject.args) do
			if type(v) == "number" and v > maxargnum then
				maxargnum = v
			else
				table.insert(numargstext, "|" .. k .. "=" .. v)
			end
		end
		for i = 1, maxargnum do
			local v = templateObject.args[i]
			if v == nil then
				v = "(nil)"
			elseif v == true then
				v = "(true)"
			elseif v == false then
				v = "(false)"
			end
			table.insert(argstext, "|" .. v)
		end
		error("Extra arguments to {{auto cat}} not allowed for this category (recognized as {{[[Template:" ..
			templateObject.title .. "|" .. templateObject.title .. "]]" .. numargstext .. argstext .. "}}")
	end

	local first_error_templateObject, first_error_args_handled, first_error_cattext

	-- Go through each handler in turn. If a handler doesn't recognize the format of the
	-- category, it will return nil, and we will consider the next handler. Otherwise,
	-- it returns a template name and arguments to call it with, but even then, that template
	-- might return an error, and we need to consider the next handler. This happens,
	-- for example, with the category "CAT:Mato Grosso, Brazil", where "Mato" is the name of
	-- a language, so the handler for {{poscatboiler}} fires and tries to find a label
	-- "Grosso, Brazil". This throws an error, and previously, this blocked fruther handler
	-- consideration, but now we check for the error and continue checking handlers;
	-- eventually, {{topic cat}} will fire and correctly handle the category.
	for _, handler in ipairs(handlers) do
		local templateObject, args_handled = handler(titleObject, args)
		
		if templateObject then
			require("Module:debug").track("auto cat/" .. templateObject.title)
			local cattext = frame:expandTemplate(templateObject)
			-- FIXME! We check for specific text found in most or all error messages generated
			-- by category tree templates (in particular, the second piece of text below should be
			-- in all error messages generated when a given module doesn't recognize a category name).
			-- If this text ever changes in the source modules (e.g. [[Module:category tree]],
			-- it needs to be changed here as well.)
			if cattext:find("Category:Categories with invalid label") or
				cattext:find("The automatically%-generated contents of this category has errors") then
				if not first_error_cattext then
					first_error_templateObject = templateObject
					first_error_args_handled = args_handled
					first_error_cattext = cattext
				end
			else
				if not args_handled and next(args) then
					extra_args_error(templateObject)
				end
				return cattext
			end
		end
	end
	
	if first_error_cattext then
		if not first_error_args_handled and next(args) then
			extra_args_error(first_error_templateObject)
		end
		return first_error_cattext
	end
	error("{{auto cat}} couldn't recognize format of category name")
end

-- test function for injecting title string
function export.test(title)
	if type(title) == "table" then
		if type(title.args[1]) == "string" then
			title = title.args[1]
		else
			title = title:getParent().args[1]
		end
	end
	
	local titleObject = {}
	titleObject.text = title
	
	for _, handler in ipairs(handlers) do
		local t = handler(titleObject)
		
		if t then
			return t.title
		end
	end	
end

return export
