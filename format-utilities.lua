local export = {}


local debug_track_module = "Module:debug/track"
local links_module = "Module:links"
local table_module = "Module:table"
local utilities_module = "Module:utilities"

export.allowed_conjs_for_join_segments = {
	-- ",and" joins using serialCommaJoin(): "foo and bar", "foo, bar and baz", etc. 
	-- ";and" should be used when there are embedded commas: "foo and bar", "foo; bar; and baz", etc.
	-- "and" selects ";and" if there are embedded commas, ",and" otherwise.
	-- If the final term is marked as a continuation (is_continuation = true), the conjunction "and" isn't displayed;
	-- instead, all terms are joined with comma or semicolon as appropriate.
	"and", ";and", ",and",
	-- ",or", ";or" and "or" work like the corresponding "and" conjunctions.
	"or", ";or", ",or",
	-- ",and/or", ";and/or" and "and/or" work like the corresponding "and" conjunctions.
	"and/or", ";and/or", ",and/or",
	-- 
	",", ";", "/", "~", "+",
}


--[==[
Loaders for functions in other modules, which overwrite themselves with the target function when called. This ensures
modules are only loaded when needed, retains the speed/convenience of locally-declared pre-loaded functions, and has no
overhead after the first call, since the target functions are called directly in any subsequent calls.
]==]
local function debug_track(...)
	debug_track = require(debug_track_module)
	return debug_track(...)
end

local function full_link(...)
	full_link = require(links_module).full_link
	return full_link(...)
end

----------------- end loaders ----------------

local function track(page, track_module)
	return debug_track((track_module or "format utilities") .. "/" .. page)
end

function export.wrap_in_span(text, classes)
	if classes then
		return ("<span class='%s'>%s</span>"):format(classes, text)
	end
	return text
end

--[==[
A combination of `serialCommaJoin` and `concat`. Option `conj` is either {"and"}, {"or"}, (join `segs` using
`serialCommaJoin`) or a punctuation delimiter (currently {","}, {"/"}, {"~"} and {";"} are allowed and converted to the appropriate displayed separator, and then `segs` joined using `concat`).
]==]
function export.join_segments(data)
	local segments, conj = data.segments, data.conj
	if not conj then
		error("Internal error: Missing conjunction in call to join_segments()")
	end
	if not segments[2] then
		return segments[1].output
	end
	if conj == "and" or conj == "or" or conj == "and/or" then
		saw_embedded_comma = false
		for _, seg in ipairs(segments) do
			if seg.raw and require(utilities_module).get_plaintext(seg.raw):find(",") then
				-- Saw embedded comma
				saw_embedded_comma = true
			end
		end
		if saw_embedded_comma then
			conj = ";" .. conj
		else
			conj = "," .. conj
		end
	end
	if conj:find("^[;,][a-z]") then
		-- semicolon + conjunction
		if segments[#segments].is_continuation then
			conj = conj:sub(1, 1)
		else
			local punc, final_conj = conj:match("^(.)(.*)$")
			if not segments[3] then
				return ("%s %s %s"):format(segments[1].output, final_conj, segments[2].output)
			end
			if punc == "," then
				local seg_output = {}
				for i, seg in ipairs(segments) do
					seg_output[i] = seg.output
				end
				return require(table_module).serialCommaJoin(seg_output, {dontTag = data.dont_tag})
			else
				local parts = {}
				for i, seg in ipairs(segments) do
					if i == #segments then
						table.insert(parts, "; " .. conj)
					elseif i > 1 then
						table.insert(parts, "; ")
					end
					table.insert(parts, seg.output)
				end
				return table.concat(parts)
			end
		end
		local sep
		if conj == "," then
			sep = ", "
		elseif conj == "/" then
			sep = "/"
		elseif conj == "~" then
			sep = " ~ "
		elseif conj == ";" then
			sep = "; "
		else
			error(("Internal error: Unrecognized conjunction '%s'"):format(conj))
		end
		local seg_output = {}
		for i, seg in ipairs(segments) do
			seg_output[i] = seg.output
		end
		return table.concat(seg_output, sep)
	end
end


function export.get_source_lang_display_name(source, raw)
	local display
	local source_code = source:getCode()
	if source_code == "und" then
		display = "undetermined"
	elseif source_code == "mul" then
		display = raw and "translingual" or "[[w:Translingualism|translingual]]"
	elseif source_code == "mul-tax" then
		display = raw and "taxonomic name" or "[[w:Biological nomenclature|taxonomic name]]"
	else
		display = raw and source:getCanonicalName() or source:makeWikipediaLink()
	end
	return display
end


function export.format_one_term(data)
	local termobj, object_classes, link_face, no_show_qualifiers, track_module =
		data.termobj, data.object_classes, data.link_face, data.no_show_qualifiers, data.track_module
	if termobj.is_continuation then
		return {
			output = '<i class="Latn continuation">' .. termobj.alt .. '</i>',
			raw = termobj.alt,
			is_continuation = true,
		}
	end
	local return_empty
	if termobj.lang:hasType("family") then
		if termobj.term and termobj.term ~= "-" then
			track("family-with-term", track_module)
		end
		return_empty = true
	end
	if termobj.term == "-" then
		track("no-term", track_module)
		return_empty = true
	end
	if return_empty then
		return {
			output = "",
			raw = "",
		}
	end
	local link = full_link(termobj, link_face, nil, not no_show_qualifiers and "show qualifiers" or nil)
	return {
		output = export.wrap_in_span(link, object_classes),
		raw = termobj.alt or termobj.term,
	}
end


--[==[
Format sources for etymology templates such as {{tl|bor}}, {{tl|der}}, {{tl|inh}} and {{tl|cog}}. There may potentially
be more than one source language (except currently {{tl|inh}}, which doesn't support it because it doesn't really
make sense). In that case, if `link_sources_to_term` is set, all but the last source language is linked to the first
term, but only if there is such a term and this linking makes sense, i.e. either (1) the term page exists after
stripping diacritics according to the source language in question, or (2) the result of stripping diacritics according
to the source language in question results in a different page from the same process applied with the last source
language. For example, {{m|ru|соля́нка}} will link to [[солянка]] but {{m|en|соля́нка}} will link to [[соля́нка]] with an
accent, and since they are different pages, the use of English as a non-final source with term 'соля́нка' will link to
[[соля́нка]] even though it doesn't exist, on the assumption that it is merely a redlink that might exist. If none of the
above criteria apply, a non-final source language will be linked to the Wikipedia entry for the language, just as final
source languages always are.

`data` contains the following fields:
* `sources`: List of source objects. Most commonly there is only one. If there are multiple, the non-final ones may be
             handled specially; see above.
* `link_sources_to_term`: If true, link non-final sources to the term object in `termobj`, under the conditions
                          described above.
* `termobj`: Term object to link non-final sources to; see above.
* `sourceconj`: Conjunction used to separate multiple source languages. Defaults to {"and"}.
* `source_classes`: Space-separated CSS class or classes to wrap each source in.
]==]
function export.format_sources(data)
	local sources, termobj, sourceconj, source_classes = data.sources, data.termobj, data.sourceconj, source_classes
	
	local source_segs = {}
	local no_term = not termobj or not termobj.term or termobj.term == "-" or termobj.lang:hasType("family")
	final_link_page = sources[2] and not no_term and
		m_links.get_link_page(termobj.term, sources[#sources], termobj.sc) or nil
	for i, source in ipairs(sources) do
		local seg
		local display_term
		if i < #sources and data.link_sources_to_term and not no_term then
			local link_page = m_links.get_link_page(termobj.term, source, termobj.sc)
			local exists = link_page and mw.title.new(link_page).exists
			local different = link_page ~= final_link_page
			display_term = exists or different
		end
		if display_term then
			local display = export.get_source_lang_display_name(source, raw)
			seg = require(links_module).language_link {
				lang = source, term = termobj.term, alt = display, tr = "-"
			}
		else
			seg = export.get_source_lang_display_name(source)
		end
		table.insert(source_segs, wrap_in_span(seg, source_classes))
	end
	return join_segments(source_segs, sourceconj or "and")
end


function export.format_one_term_with_sources(data)
	local termobj, sources, no_show_qualifiers, no_move_qualifiers_outside =
		data.termobj, data.sources, data.no_show_qualifiers, data.no_move_qualifiers_outside
	if termobj.is_continuation or not sources then
		return export.format_one_term(data)
	end
	local formatted_sources = export.format_sources(data)
	local q, qq, l, ll, refs = data.q, data.qq, data.l, data.ll, data.refs
	local link = export.format_one_term(data)
	local retval
	if link == "" then
		retval = formatted_sources
	else
		retval = formatted_sources .. " " .. link
	end
	local result = export.format_sources(data) .. export.format_links(data.terms, data.conj, data.template_name)
	if q and q[1] or qq and qq[1] or l and l[1] or ll and ll[1] or refs and refs[1] then
		result = require(pron_qualifier_module).format_qualifiers {
			lang = data.terms[1].lang,
			text = result,
			q = q,
			qq = qq,
			l = l,
			ll = ll,
			refs = refs,
		}
	end
	return result
end


function export.format_terms(data)
	local parts = {}
	local function ins(txt)
		table.insert(parts, txt)
	end
end


return export
