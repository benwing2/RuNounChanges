local export = {}

--[=[
This module contains driver code for running a given set of testcases for [[Module:de-pron]]. The testcases are split
into multiple subsets because there are too many of them to include in a single module (you get a time-expired error).
The maximum number of examples in a subset is not completely clear but it is somewhere between 600 and 1500.

To create a new subset, copy an existing subset and modify the examples, and set up the corresponding documentation page
as appropriate. For example, to create a subset specifically for English-origin words, copy an existing subset page such
as [[Module:de-pron/testcases/prefixes]] to e.g. [[Module:de-pron/testcases/english]]. Also copy the documentation page
[[Module:de-pron/testcases/prefixes/documentation]] to e.g. [[Module:de-pron/testcases/english/documentation]],
modifying the module invocation reference in the documentation page as appropriate to point to your subset module.
Then modify the examples in e.g. [[Module:de-pron/testcases/english]] according to the following format.

Each line of the example text is either a section header beginning with a ##, a comment beginning with # but not
##, a blank line or an example. Examples consist of three tab-separated fields, followed by an optional comment to be
shown along with the example (delimited by a # preceded by whitespace). The first field is the actual spelling of the
term in question. The second field is the respelling. The third field is the expected phonemic IPA pronunciation.

Example #1:

Aachener	Aachener	ˈaːxənɐ

This specifies a word [[Aachener]], respelled 'Aachener' (i.e. same as the actual spelling), with phonemic pronunciation
/ˈaːxənɐ/.

Example #2:

Bodyguard	Boddigàhrd	ˈbɔdiˌɡaːʁt

This specifies a word [[Bodyguard]], respelled 'Boddigàhrd', with phonemic pronunciation /ˈbɔdiˌɡaːʁt/.

Example #3:

Chefredakteur	Schef-redaktö́r	ˈʃeːfʁedakˌtøːʁ # usually in Austria

This specifies a word [[Chefredakteur]], respelled 'Schef-redaktö́r', with phonemic pronunciation /ˈʃeːfʁedakˌtøːʁ/ and
a comment "usually in Austria".


FIXME: We should have support for higher-level section headers designated using ###.
]=]

local m_de_pron = require("Module:User:Benwing2/de-pron")
local m_links = require("Module:links")
local lang = require("Module:languages").getByCode("de")

local rsplit = mw.text.split
local rmatch = mw.ustring.match

local function tag_IPA(IPA)
	return '<span class="IPA">' .. IPA .. "</span>"
end

local function link(text)
	return m_links.full_link{ term = text, lang = lang }
end

local options = { display = tag_IPA }

function export.check_ipa(self, spelling, respelling, expected, comment)
	local phonemic = m_de_pron.phonemic(respelling)
	options.comment = comment or ""
	self:equals(
		link(spelling) .. (respelling == spelling and "" or ", respelled " .. respelling),
		phonemic,
		expected,
		options
	)
end

function export.parse(examples)
	-- The following is a list of parsed examples where each element is a four-element list of
	-- {SPELLING, RESPELLING, EXPECTED, COMMENT}. SPELLING is the actual spelling of the term; RESPELLING is the
	-- respelling; EXPECTED is the phonemic IPA; and COMMENT is an optional comment or nil.
	local parsed_examples = {}
	-- Snarf each line.
	for line in examples:gmatch "[^\n]+" do
		-- Trim whitespace at beginning and end.
		line = line:gsub("^%s*(.-)%s*$", "%1")
		local function err(msg)
			error(msg .. ": " .. line)
		end
		if line == "" then
			-- Skip blank lines.
		elseif line:find("^##") then
			-- Line beginning with ## is a section header.
			line = line:gsub("^##%s*", "")
			table.insert(parsed_examples, line)
		elseif line:find("^#") then
			-- Line beginning with # but not ## is a comment; ignore.
		else
			local line_no_comment, comment = rmatch(line, "^(.-)%s+#%s*(.*)$")
			line_no_comment = line_no_comment or line
			local parts = rsplit(line_no_comment, "\t")
			if #parts ~= 3 then
				err("Expected 3 tab-separated components in example (not including any comment)")
			end
			table.insert(parts, comment)
			table.insert(parsed_examples, parts)
		end
	end
	return parsed_examples
end

return export
