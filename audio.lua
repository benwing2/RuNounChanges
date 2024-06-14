local export = {}

local headword_data_module = "Module:headword/data"
local IPA_module = "Module:IPA"
local labels_module = "Module:labels"
local links_module = "Module:links"
local parameters_module = "Module:parameters"
local pron_qualifier_module = "Module:pron qualifier"
local qualifier_module = "Module:qualifier"
local references_module = "Module:references"
local string_utilities_module = "Module:string utilities"
local table_module = "Module:table"
local template_styles_module = "Module:TemplateStyles"
local utilities_module = "Module:utilities"
local audio_styles_css = "audio/styles.css"

local function track(page)
	require("Module:debug/track")("audio/" .. page)
	return true
end

local function rsplit(text, pattern)
	return require(string_utilities_module).split(text, pattern)
end

local function wrap_css(text, classes)
	return ("<span class=\"%s\">%s</span>"):format(classes, text)
end

local function wrap_qual_css(text, suffix)
	local css_classes = ("ib-%s qualifier-%s"):format(suffix, suffix)
	return wrap_css(text, css_classes)
end


--[==[
Display a box that can be used to play an audio file. `data` is a table containing the following fields:
* `lang` ('''required'''): language object for the audio files;
* `file` ('''required'''): file containing the audio;
* `caption`: Caption to display before the audio box; normally {"Audio"}, and does not usually need to be changed;
* `nocaption`: If specified, don't display the caption;
* `q`: {nil} or a list of left regular qualifier strings, formatted using {format_qualifier()} in [[Module:qualifier]]
  and displayed before the audio box and after the caption (and any accent qualifiers);
* `qq`: {nil} or a list of right regular qualifier strings, displayed directly after the audio box (and after any
  accent qualifiers);
* `a`: {nil} or a list of left accent qualifier strings, formatted using {format_qualifiers()} in
  [[Module:accent qualifier]] and displayed before the audio box and after the caption;
* `aa`: {nil} or a list of right accent qualifier strings, displayed directly after the homophone in question;
* `refs`: {nil} or a list of references or reference specs to add directly after the audio box; the value of a list item
  is either a string containing the reference text (typically a call to a citation template such as {{tl|cite-book}}, or
  a template wrapping such a call), or an object with fields `text` (the reference text), `name` (the name of the
  reference, as in {{cd|<nowiki><ref name="foo">...</ref></nowiki>}} or {{cd|<nowiki><ref name="foo" /></nowiki>}})
  and/or `group` (the group of the reference, as in {{cd|<nowiki><ref name="foo" group="bar">...</ref></nowiki>}} or
  {{cd|<nowiki><ref name="foo" group="bar"/></nowiki>}}); this uses a parser function to format the reference
  appropriately and insert a footnote number that hyperlinks to the actual reference, located in the
  {{cd|<nowiki><references /></nowiki>}} section;
* `text`: Text of the audio snippet; if specified, should be an object of the form passed to {full_link()} in
  [[Module:links]], including a `lang` field containing the language of the text (usually the same as `data.lang`);
  displayed before the audio box, after any regular and accent qualifiers;
* `IPA`: IPA of the audio snippet, or a list of IPA specs; if specified, should be surrounded by slashes or brackets,
  and will be processed using {format_IPA_multiple()} in [[Module:IPA]] and displayed before the audio box, after any
  regular and accent qualifiers and after the text of the audio snippet, if given;
* `nocat`: If true, suppress categorization;
* `sort`: Sort key for categorization.
]==]

function export.format_audio(data)
	local cats = { data.lang:getFullName() .. " terms with audio links" }

	local function format_a(a)
		if a and a[1] then
			return require(labels_module).show_labels {
				lang = data.lang,
				labels = a,
				mode = "accent",
				nocat = true,
				open = false,
				close = false,
				no_track_already_seen = true,
			}
		end
		return nil
	end

	local function format_q(q)
		if q and q[1] then
			return require(qualifier_module).format_qualifier(q, false, false)
		end
		return nil
	end

	local function make_td_if(text)
		if text == "" then
			return text
		end
		return "<td>" .. text .. "</td>"
	end

	-- Generate the full text preceding the audio box.
	local pretext_parts = {}

	local function ins(text)
		table.insert(pretext_parts, text)
	end

	local formatted_accent_labels, formatted_qualifiers, formatted_text, formatted_ipa
	formatted_accent_labels = format_a(data.a)
	formatted_qualifiers = format_q(data.q)
	if data.text then
		formatted_text = require(links_module).full_link(data.text, "term", true)
	end
	if data.IPA then
		local ipa_cats
		local ipa = data.IPA
		if type(ipa) == "string" then
			ipa = {ipa}
		end
		local ipa_items = {}
		for _, ipa_item in ipairs(ipa) do
			table.insert(ipa_items, {pron = ipa_item})
		end
		formatted_ipa, ipa_cats = require(IPA_module).format_IPA_multiple(data.lang, ipa_items, nil, "no count", "raw")
		if ipa_cats[1] then
			require(table_module).extendList(cats, ipa_cats)
		end
	end
	local has_qual = formatted_accent_labels or formatted_qualifiers
	if not data.nocaption then
		-- Track uses of caption (3=). Over time as we eliminate most of them, we can use this to find and 
		-- eliminate the remainder.
		if data.caption then
			track("caption")
		end
		ins(data.caption or "Audio")
		if has_qual then
			ins(" " .. wrap_qual_css("(", "brac"))
		end
	end
	if formatted_accent_labels then
		ins(formatted_accent_labels)
		if formatted_qualifiers then
			ins(wrap_qual_css(",", "comma") .. " ")
		end
	end
	if formatted_qualifiers then
		ins(formatted_qualifiers)
	end
	if has_qual then
		if not data.nocaption then
			ins(wrap_qual_css(")", "brac"))
		end
	end
	if (formatted_text or formatted_ipa) and (has_qual or not data.nocaption) then
		ins(wrap_qual_css(";", "semicolon") .. " ")
	end
	if formatted_text then
		ins(formatted_text)
		if formatted_ipa then
			ins(" ")
		end
	end
	ins(formatted_ipa)
	if not data.nocaption then
		ins(wrap_qual_css(":", "colon"))
	end

	local pretext = make_td_if(table.concat(pretext_parts))

	-- Generate the full text following the audio box.
	local posttext_parts = {}

	local function ins(text)
		table.insert(posttext_parts, text)
	end

	local formatted_post_accent_labels = format_a(data.aa)
	local formatted_post_qualifiers = format_q(data.qq)
	local formatted_references = data.refs and require(references_module).format_references(data.refs) or nil
	if formatted_references then
		ins(formatted_references)
	end
	if formatted_post_accent_labels or formatted_post_qualifiers then
		if formatted_references then
			ins(" ")
		end
		ins(wrap_qual_css("(", "brac"))
		if formatted_post_accent_labels then
			ins(formatted_post_accent_labels)
			if formatted_post_qualifiers then
				ins(wrap_qual_css(",", "comma") .. " ")
			end
		end
		if formatted_post_qualifiers then
			ins(formatted_post_qualifiers)
		end
		ins(wrap_qual_css(")", "brac"))
	end
	
	if data.bad then
		track("bad-audio")
		track("bad-audio/" .. data.lang:getCode())
		ins(" " .. wrap_css("[bad recording: " .. data.bad .. "]", "bad-audio-note"))
	end

	local posttext = make_td_if(table.concat(posttext_parts))

	local template = [=[
<tr>%s<td class="audiofile">[[File:%s|noicon|175px]]</td><td class="audiometa" style="font-size: 80%%;">([[:File:%s|file]])</td>%s</tr>]=]
	local text = template:format(pretext, data.file, data.file, posttext)

	text = '<table class="audiotable" style="vertical-align: middle; display: inline-block; list-style: none; line-height: 1em; border-collapse: collapse; margin: 0;">' .. text .. "</table>"

	local stylesheet = require(template_styles_module)(audio_styles_css)
	local categories =
		data.nocat and "" or
		cats[1] and require(utilities_module).format_categories(cats, data.lang, data.sort) or ""
	return stylesheet .. text .. categories
end

--[==[
FIXME: Old entry point for formatting multiple audios in a single table. Not used anywhere and needs rewriting to the
standard of format_audio().

Meant to be called from a module. `data` is a table containing the following fields:

<pre>
{
  lang = LANGUAGE_OBJECT,
  audios = {{file = "FILENAME", qualifiers = nil or {"QUALIFIER", "QUALIFIER", ...}}, ...},
  caption = nil or "CAPTION"
}
</pre>

Here:

* `lang` is a language object.
* `audios` is the list of audio files to display. FILENAME is the name of the audio file without a namespace.
  QUALIFIER is a qualifier string to display after the specific audio file in question, formatted using
  {format_qualifier()} in [[Module:qualifier]].
* `caption`, if specified, adds a caption before the audio file.
]==]
function export.format_multiple_audios(data)
	local audiocats = { data.lang:getFullName() .. " terms with audio links" }
	local rows = { }
	local caption = data.caption

	for _, audio in ipairs(data.audios) do
		local qualifiers = audio.qualifiers
		local function repl(key)
			if key == "file" then
				return audio.file
			elseif key == "caption" then
				if not caption then return "" end
				return "<td rowspan=" .. #data.audios .. ">" .. caption .. ":</td>"
			elseif key == "qualifiers" then
				if not qualifiers or not qualifiers[1] then return "" end
				return "<td>" .. require(qualifier_module).format_qualifier(qualifiers) .. "</td>"
			end
		end
		local template = [=[
	<tr>{{{caption}}}
	<td class="audiofile">[[File:{{{file}}}|noicon|175px]]</td>
	<td class="audiometa" style="font-size: 80%;">([[:File:{{{file}}}|file]])</td>
	{{{qualifiers}}}</tr>]=]
		local text = (mw.ustring.gsub(template, "{{{([a-z0-9_:]+)}}}", repl))
		table.insert(rows, text)
		caption = nil
	end
	
	local function repl(key)
		if key == "rows" then
			return table.concat(rows, "\n")
		end
	end

	local template = [=[
<table class="audiotable" style="vertical-align: middle; display: inline-block; list-style: none; line-height: 1em; border-collapse: collapse;">
{{{rows}}}
</table>
]=]

	local stylesheet = require(template_styles_module)(audio_styles_css)
	local text = mw.ustring.gsub(template, "{{{([a-z0-9_:]+)}}}", repl)
	local categories =
		data.nocat and "" or
		#audiocats > 0 and require(utilities_module).format_categories(audiocats, data.lang, data.sort) or ""
	-- remove newlines due to HTML generator bug in MediaWiki(?) - newlines in tables cause list items to not end correctly
	text = mw.ustring.gsub(text, "\n", "")
	return stylesheet .. text .. categories
end


--[==[
Construct the `text` object passed into {format_audio()}, from raw-ish arguments (essentially, the output of {process()}
in [[Module:parameters]]). On entry, `args` contains the following fields:
* `lang` ('''required'''): Language object.
* `text`: Text. If this isn't defined and neither are any of `t`, `tr`, `ts`, `pos`, `lit` or `g`, the function returns
  {nil}.
* `t`: Gloss of text.
* `tr`: Manual transliteration of text.
* `ts`: Transcription of text.
* `pos`: Part of speech of text.
* `lit`: Literal meaning of text.
* `g`: Gender/number spec(s) of text. Automatically split on commas.
* `sc`: Optional script object of text (rarely needs to be set).
* `pagename`: Pagename; used in place of `text` when `text` is unset but other text-related parameters are set.
  If not specified, taken from the actual pagename.
]==]
function export.construct_audio_textobj(args)
	local textobj
	local g = args.g
	if g then
		if g:find(",") then
			g = rsplit(g, "%s*,%s*")
		else
			g = {g}
		end
	end
	if args.text or args.t or args.tr or args.ts or args.pos or args.lit or g then
		local text = args.text or args.pagename or mw.loadData("Module:headword/data").pagename
		textobj = {
			lang = args.lang,
			alt = wrap_qual_css("“", "quote") .. text .. wrap_qual_css("”", "quote"),
			gloss = args.t,
			tr = args.tr,
			ts = args.ts,
			pos = args.pos,
			lit = args.lit,
			genders = g,
			sc = args.sc,
		}
	end
	return textobj
end


--[==[
Entry point for {{tl|audio}} template.
]==]
function export.show(frame)
	local parent_args = frame:getParent().args
	local compat = parent_args.lang
	local offset = compat and 0 or 1

	local params = {
		[compat and "lang" or 1] = {required = true, type = "language", etym_lang = true, default = "en"},
		[1 + offset] = {required = true, default = "Example.ogg"},
		[2 + offset] = {},
		["q"] = {},
		["qq"] = {},
		["a"] = {},
		["aa"] = {},
		["ref"] = {},
		["IPA"] = {},
		["text"] = {},
		["t"] = {},
		["tr"] = {},
		["ts"] = {},
		["pos"] = {},
		["lit"] = {},
		["g"] = {},
		["sc"] = {type = "script"},
		["bad"] = {},
		["nocat"] = {type = "boolean"},
		["sort"] = {},
		["pagename"] = {},
	}

	local args = require(parameters_module).process(parent_args, params)

	local lang = args[compat and "lang" or 1]

	-- Needed in construct_audio_textobj().
	args.lang = lang
	local textobj = export.construct_audio_textobj(args)

	local caption = args[2 + offset]
	local nocaption
	if caption == "-" then
		caption = nil
		nocaption = true
	end
	if caption then
		-- Remove final colon if given, to avoid two colons.
		caption = caption:gsub(":$", "")
	end
	local data = {
		lang = lang,
		file = args[1 + offset],
		caption = caption,
		nocaption = nocaption,
		text = textobj,
		IPA = args.IPA and rsplit(args.IPA, ",") or nil,
		bad = args.bad,
		nocat = args.nocat,
		sort = args.sort,
	}
	require(pron_qualifier_module).parse_qualifiers {
		store_obj = data,
		q = args.q,
		qq = args.qq,
		a = args.a,
		aa = args.aa,
		refs = args.ref,
	}

	return export.format_audio(data)
end

return export
