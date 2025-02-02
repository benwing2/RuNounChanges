local export = {}

local concat = table.concat

--[==[
Wrap text in one or more CSS classes. `classes` should be a string; separate multiple classes with a space.
]==]
function export.wrap_css(text, classes)
	return ("<span class=\"%s\">%s</span>"):format(classes, text)
end

--[==[
Wrap text in one or more qualifier CSS classes. `suffix` is the suffix describing the type of content, e.g. `brac`
for parens, `content` for content, `comma` for commas. CSS classes <code>ib-<var>suffix</var></code> and
i<code>qualifier-<var>suffix</var></code> are added.
]==]
function export.wrap_qualifier_css(text, suffix)
	local css_classes = ("ib-%s qualifier-%s"):format(suffix, suffix)
	return export.wrap_css(text, css_classes)
end

--[==[
Format one or more qualifiers. `data` is an object with the following fields:
* `qualifiers`: A single qualifier or a list or qualifiers.
* `open`: Override the open paren displayed before the qualifiers. If `false` or an empty string, no paren is displayed.
* `close`: Override the close paren displayed before the qualifiers. If `false` or an empty string, no paren is
  displayed.
* `opencontent`: Content to display before the qualifiers, after the open paren.
* `closecontent`: Content to display after the qualifiers, before the close paren.
* `no_ib_content`: Suppress wrapping the content with classes `ib-content` and `qualifier-content`. Parens and commas
  will still be wrapped in CSS.
* `raw`: Suppress all CSS wrapping.
]==]
function export.format_qualifiers(data)
	local qualifiers, open, close = data.qualifiers, data.open, data.close
	if type(qualifiers) ~= "table" then
		qualifiers = {qualifiers}
	end

	if not qualifiers[1] then
		return ""
	end

	local parts = {}
	local function ins(text)
		table.insert(parts, text)
	end
	local function wrap_qualifier_css(text, suffix)
		if data.raw then
			return text
		end
		return export.wrap_qualifier_css(text, suffix)
	end

	if open ~= false and open ~= ""then
		ins(wrap_qualifier_css(open or "(", "brac"))
	end
	if data.opencontent then
		ins(data.opencontent)
	end
	local content = concat(qualifiers, wrap_qualifier_css(",", "comma") .. " ")
	if not data.no_ib_content then
		content = wrap_qualifier_css(content, "content")
	end
	ins(content)
	if data.closecontent then
		ins(data.closecontent)
	end
	if close ~= false and close ~= "" then
		ins(wrap_qualifier_css(close or ")", "brac"))
	end
	return concat(parts)
end

--[==[
An older interface onto `format_qualifiers`. Eventually code should be converted to use the new entry point.
]==]
function export.format_qualifier(qualifiers, open, close, opencontent, closecontent, no_ib_content)
	return export.format_qualifiers {
		qualifiers = qualifiers,
		open = open,
		close = close,
		opencontent = opencontent,
		closecontent = closecontent,
		no_ib_content = no_ib_content,
	}
end

local function format_qualifiers_with_clarification(qualifiers, clarification, openquote, closequote)
	local opencontent = export.wrap_css(clarification, "qualifier-clarification") ..
		export.wrap_css(openquote or "“", "qualifier-clarification qualifier-quote")

	local closecontent = export.wrap_css(closequote or "”", "qualifier-clarification qualifier-quote")

	return export.format_qualifiers {
		qualifiers = qualifiers,
		open = "(",
		close = ")",
		opencontent = opencontent,
		closecontent = closecontent,
	}
end

--[==[
Internal implementation of {{tl|sense}}.
]==]
function export.sense(qualifiers)
	return export.format_qualifiers {
		qualifiers = qualifiers
	}.. export.wrap_css(":", "ib-colon sense-qualifier-colon")
end

--[==[
Internal implementation of {{tl|antsense}}.
]==]
function export.antsense(qualifiers)
	return format_qualifiers_with_clarification(qualifiers, "antonym(s) of ") ..
		export.wrap_css(":", "ib-colon sense-qualifier-colon")
end

return export
