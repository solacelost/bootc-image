local lspconfig = require("lspconfig")

-- explicitly set the yaml ls I use
lspconfig.helm_ls.setup({
  settings = {
    ["helm-ls"] = {
      yamlls = {
        path = "/home/james/.local/share/nvim/mason/packages/yaml-language-server/node_modules/yaml-language-server/bin/yaml-language-server",
      },
    },
  },
})

lspconfig.yamlls.setup({})
