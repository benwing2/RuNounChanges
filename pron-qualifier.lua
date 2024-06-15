local export = {}

local labels_module = "Module:labels"
local qualifier_module = "Module:User:Benwing2/qualifier"
local references_module = "Module:references"
local string_utilities_module = "Module:string utilities"

local function track(page)
	require("Module:debug/track")("pron qualifier/" .. page)
	return true
end

local function split_labels(term)
	if not term then
		return nil
	end
	return require(labels_module).split_labels_on_comma(term)
end

--[==[
Parse left and right regular and accent qualifiers, labels and references, for pronunciation or related modules that
want to provide support for these.

`data` is a structure containing the following fields:
* `obj`: The object to write the parsed qualifiers, labels and references into.
* `q`: Left regular qualifier.
* `qq`: Right regular qualifier.
* `qualifiers`: Regular qualifier (left or right), for compatibility.
* `a`: String of comma-separated left accent qualifiers.
* `aa`: String of comma-separated right accent qualifiers.
* `l`: String of comma-separated left labels.
* `ll`: String of comma-separated right labels.
* `refs: Spec for one or more references; see the documentation of [[Module:IPA]].
]==]
function export.parse_qualifiers(data)
	local obj = data.store_obj
	obj.refs = data.refs and require(references_module).parse_references(data.refs) or nil
	obj.q = data.q and {data.q} or nil
	obj.qq = data.qq and {data.qq} or nil
	obj.qualifiers = data.qualifiers and {data.qualifiers} or nil
	obj.a = split_labels(data.a)
	obj.aa = split_labels(data.aa)
	obj.l = split_labels(data.l)
	obj.ll = split_labels(data.ll)
end

--[==[
This function is used by any module that wants to add support for (some subset of) left and right regular and accent
qualifiers, labels and references to a template that specifies a pronunciation or related property. It is currently used
by [[Module:IPA]], [[Module:rhymes]], [[Module:hyphenation]], [[Module:homophones]] and various lang-specific modules
such as [[Module:es-pronunc]] (for specifying pronunciation, rhymes, hyphenation, homophones and audio in {{tl|es-pr}}).It should potentially also be used in {{tl|audio}}. To reduce memory usage, the caller should check that any qualifiers 
exist before loading the module.

`data` is a structure containing the following fields:
* `q`: List of left regular qualifiers, each a string.
* `qq`: List of right regular qualifiers, each a string.
* `qualifiers`: List of qualifiers, each a string, for compatibility. If `qualifiers_right` is given, these are
   right qualifiers, otherwise left qualifiers. If both `qualifiers` and `q`/`qq` (depending on the value of
   `qualifiers_right`) are non-{nil}, `qualifiers` is ignored.
* `qualifiers_right`: If specified, qualifiers in `qualifiers` are placed to the right, otherwise the left. See above.
* `a`: List of left accent qualifiers, each a string.
* `aa`: List of right accent qualifiers, each a string.
* `l`: List of left labels, each a string.
* `ll`: List of right labels, each a string.
* `refs`: {nil} or a list of references or reference specs to add directly after the text; the value of a list item
  is either a string containing the reference text (typically a call to a citation template such as {{tl|cite-book}}, or
  a template wrapping such a call), or an object with fields `text` (the reference text), `name` (the name of the
  reference, as in {{cd|<nowiki><ref name="foo">...</ref></nowiki>}} or {{cd|<nowiki><ref name="foo" /></nowiki>}})
  and/or `group` (the group of the reference, as in {{cd|<nowiki><ref name="foo" group="bar">...</ref></nowiki>}} or
  {{cd|<nowiki><ref name="foo" group="bar"/></nowiki>}}); this uses a parser function to format the reference
  appropriately and insert a footnote number that hyperlinks to the actual reference, located in the
  {{cd|<nowiki><references /></nowiki>}} section.
* `lang`: Language object for accent qualifiers.
* `text`: The text to wrap with qualifiers.

The order of qualifiers and labels, on both the left and right, is (1) labels, (2) accent qualifiers, (3) regular
qualifiers. This goes in order of relative importance.
]==]
function export.format_qualifiers(data)
	if not data.text then
		error("Missing `data.text`; did you try to pass `text` or `qualifiers_right` as separate params?")
	end
	if not data.lang then
		track("nolang")
	end
	local text = data.text
	-- Format the qualifiers and labels that go either before or after the main text. They are ordered as follows, on
	-- both the left and the right: (1) labels, (2) accent qualifiers, (3) regular qualifiers. This puts the different
	-- types of qualifiers/labels in order of relative importance. Return nil if no qualifiers or labels, otherwise
	-- a string containing all formatted qualifiers and labels surrounded by parens.
	local function format_qualifier_like(labels, accent_qualifiers, qualifiers)
		local has_qualifiers = qualifiers and qualifiers[1]
		local has_accent_qualifiers = accent_qualifiers and accent_qualifiers[1]
		local has_labels = labels and labels[1]
		if not has_qualifiers and not has_accent_qualifiers and not has_labels then
			return nil
		end
		local qualifier_like_parts = {}
		local function ins(part)
			table.insert(qualifier_like_parts, part)
		end
		local function format_label_like(labels, mode)
			return require(labels_module).show_labels {
				lang = data.lang,
				labels = labels,
				nocat = true,
				mode = mode,
				open = false,
				close = false,
				no_ib_content = true,
				no_track_already_seen = true,
			}
		end
		local m_qualifier = require(qualifier_module)
		if has_labels then
			ins(format_label_like(labels))
		end
		if has_accent_qualifiers then
			ins(format_label_like(accent_qualifiers, "accent"))
		end
		if has_qualifiers then
			ins(m_qualifier.format_qualifiers(qualifiers, false, false, nil, nil, "no-ib-content"))
		end
		local qualifier_inside
		if qualifier_like_parts[2] then
			qualifier_inside = table.concat(qualifier_like_parts, m_qualifier.wrap_qualifier_css(",", "comma") .. " ")
		else
			qualifier_inside = qualifier_like_parts[1]
		end
		qualifier_like_parts = {}
		ins(m_qualifier.wrap_qualifier_css("(", "brac"))
		ins(m_qualifier.wrap_qualifier_css(qualifier_inside, "content"))
		ins(m_qualifier.wrap_qualifier_css(")", "brac"))
		return table.concat(qualifier_like_parts)
	end

	if data.refs then
		text = text .. require(references_module).format_references(data.refs)
	end
	local leftq = format_qualifier_like(data.l, data.a, data.q or not data.qualifiers_right and data.qualifiers)
	local rightq = format_qualifier_like(data.ll, data.aa, data.qq or data.qualifiers_right and data.qualifiers)
	if leftq then
		text = leftq .. " " .. text
	end
	if rightq then
		text = text .. " " .. rightq
	end
	return text
end

return export
