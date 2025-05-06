local ls = require("luasnip")
local s = ls.snippet
local t = ls.text_node
local i = ls.insert_node

return {
  s("script", {
    t({
      "# /// script",
      "# requires-python = \">=3.11\"",
      "# dependencies = [\"ipdb\""
    }),
    i(1, ""),
    t({ "]",
      "# ///",
      "",
      "" }),
    i(0),
  }),
  s("ifmain", {
    t({ "if __name__ == \"__main__\":",
      "    " }),
    i(1, "pass"),
  }),
  s({ trig = "set_trace" }, {
    t("import ipdb; ipdb.set_trace()"),
  }),
}
