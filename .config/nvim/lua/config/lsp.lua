local keymap = vim.keymap
vim.api.nvim_create_autocmd("LspAttach", {
  group = vim.api.nvim_create_augroup("UserLspConfig",{}),
  callback = function(ev)
    local opts = {buffer = ev.buf, silent = true}

    -- set keybinds
    opts.desc = "Show LSP references"
    keymap.set("n", "gR", Snacks.picker.lsp_references, opts)

    opts.desc = "Show LSP defenition"
    keymap.set("n", "gd", Snacks.picker.lsp_definitions, opts)

    opts.desc = "Go to declaration"
    keymap.set("n", "gD", vim.lsp.buf.declaration, opts)

    opts.desc = "Show LSP implementations"
    keymap.set("n", "gi", Snacks.picker.lsp_implementations, opts)

    opts.desc = "Show LSP type definitions"
    keymap.set("n", "gt", Snacks.picker.lsp_type_definitions, opts)

    opts.desc = "See available code actions"
    keymap.set({ "n", "v" }, "<leader>ca", vim.lsp.buf.code_action, opts) -- see available code actions, in visual mode will apply to selection

    opts.desc = "Smart rename"
    keymap.set("n", "<leader>rn", vim.lsp.buf.rename, opts) -- smart rename

    opts.desc = "Show buffer diagnostics"
    keymap.set("n", "<leader>D", Snacks.picker.diagnostics, opts) -- show  diagnostics for file

    opts.desc = "Show line diagnostics"
    keymap.set("n", "<leader>d", vim.diagnostic.open_float, opts) -- show diagnostics for line

    opts.desc = "Organize imports"
    keymap.set("n", "<leader>oi", function()
      vim.lsp.buf.code_action({
        apply = true,
        filter = function(a) return vim.startswith(a.kind, "source.organizeImports") end,
      })
    end, opts)
  end,
});

local severity = vim.diagnostic.severity

vim.diagnostic.config({
  signs = {
    text = {
      [severity.ERROR] = " ",
      [severity.WARN] = " ",
      [severity.HINT] = "󰠠 ",
      [severity.INFO] = " ",
    },
  },
})
