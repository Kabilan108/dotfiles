local ls = require("luasnip")
local s = ls.snippet
local t = ls.text_node
local i = ls.insert_node

return {
  s("gofunc", {
    t("go func() {"),
    t({ "", "\t" }),
    i(0),
    t({ "", "}()"}),
  }),
}
