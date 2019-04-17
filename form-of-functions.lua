--[=[
DISPLAY_HANDLERS is a list of one or more functions that provide special
handling for multipart tags. Each function takes a single argument (the
multipart tag), and should either return the formatted display text or nil to
check the next handler. If no handlers apply, there is a default handler that
appropriately formats most multipart tags.

CAT_FUNCTIONS is a map from function names to functions of a single argument,
as described in [[Module:form of/cats]]. There are two types of functions:
condition handlers (which return true or false) and spec handlers (which
return a specification, as described in [[Module:form of/cats]]). We need to
put the functions here rather than in [[Module:form of/cats]] because that
module is loaded using mw.loadData(), which can't directly handle functions.
]=]

local cat_functions = {}

local display_handlers = {}

-- Display handler to clean up display of multiple persons by omitting
-- redundant "person" in all but the last element. For example, the tag
-- "123" maps to "1//2//3", which in turn gets displayed as (approximately)
-- "first-, second- and third-person" (with appropriate glossary links, and
-- appropriate spans marking the serial comma).
table.insert(display_handlers,
	function(tags)
		local els = {}
		local numtags = #tags
		for i, tag in ipairs(tags) do
			local suffix = i == numtags and "-person]]" or "-]]"
			if tag == "first-person" then
				table.insert(els, "[[Appendix:Glossary#first person|first" .. suffix)
			elseif tag == "second-person" then
				table.insert(els, "[[Appendix:Glossary#second person|second" .. suffix)
			elseif tag == "third-person" then
				table.insert(els, "[[Appendix:Glossary#third person|third" .. suffix)
			else
				return nil
			end
		end
		return require("Module:table").serialCommaJoin(els)
	end
)

return {cat_functions = cat_functions, display_handlers = display_handlers}

-- For Vim, so we get 4-space tabs
-- vim: set ts=4 sw=4 noet:
