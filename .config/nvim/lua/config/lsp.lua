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

-- oxfmt（Vite+ の整形）は mason で入れず、プロジェクトのものを使う。
-- 起動するのは package.json などで oxfmt / vite-plus を使っているプロジェクトだけ（lspconfig の root_dir）
vim.lsp.config("oxfmt", {
  -- 使っていないプロジェクトでは root_dir が nil で呼ばれるので、起動しない
  workspace_required = true,
  cmd = function(dispatchers, config)
    local bin = require("devcontainer.lsp").project_bin((config or {}).root_dir or vim.fn.getcwd(), "oxfmt")
    return vim.lsp.rpc.start({ bin or "oxfmt", "--lsp" }, dispatchers)
  end,
})
vim.lsp.enable("oxfmt")

-- 保存時に整形する。ts_ls などの整形はプロジェクトの書式と合わないことがあるので、
-- 整形専用の LSP がつながっているときだけ、それで整形する
local formatters = { oxfmt = true }
vim.api.nvim_create_autocmd("BufWritePre", {
  group = vim.api.nvim_create_augroup("UserFormatOnSave", {}),
  callback = function(ev)
    local clients = vim.lsp.get_clients({ bufnr = ev.buf, method = "textDocument/formatting" })
    if not vim.iter(clients):any(function(c) return formatters[c.name] end) then return end
    vim.lsp.buf.format({
      bufnr = ev.buf,
      timeout_ms = 3000,
      filter = function(c) return formatters[c.name] end,
    })
  end,
})

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
