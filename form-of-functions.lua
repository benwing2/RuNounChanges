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

local export = {}

function export.multipart_join_strategy()
	-- Other recognized values are "en-dash", to join with an en dash (–).
	return "serial-comma-join"
end

function export.join_multiparts(parts)
	-- Display the elements of a multipart tag. Currently we use "and",
	-- with commas when then are three or more elements, of the form
	-- "foo, bar, baz and bat"; but we are seriously considering switching
	-- to en-dash, e.g. "foo–bar–baz–bat". Arguably,
	--   dative–ablative masculine–feminine–neuter plural
	-- looks better then
	--   dative and ablative masculine, feminine and neuter plural
	-- and
	--   first–second–third-person singular present subjunctive
	-- looks better than
	--   first-, second- and third-person singular present subjunctive
	local strategy = export.multipart_join_strategy()
	if strategy == "serial-comma-join" then
		return require("Module:table").serialCommaJoin(parts)
	elseif strategy == "en-dash" then
		return table.concat(parts, "–")
	else
		error("Unrecognized multipart join strategy: " .. strategy)
	end
end

export.cat_functions = {}

export.display_handlers = {}

-- Display handler to clean up display of multiple persons by omitting
-- redundant "person" in all but the last element. For example, the tag
-- "123" maps to "1//2//3", which in turn gets displayed as (approximately)
-- "first-, second- and third-person" (with appropriate glossary links, and
-- appropriate spans marking the serial comma).
table.insert(export.display_handlers,
	function(tags)
		local els = {}
		local numtags = #tags
		for i, tag in ipairs(tags) do
			local suffix = i == numtags and "-person]]" or
				export.multipart_join_strategy() == "serial-comma-join" and "-]]" or
				"]]"
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
		return export.join_multiparts(els)
	end
)

return export

-- For Vim, so we get 4-space tabs
-- vim: set ts=4 sw=4 noet:
