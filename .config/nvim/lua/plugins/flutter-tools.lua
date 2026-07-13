return {
    'nvim-flutter/flutter-tools.nvim',
    ft = "dart",
    dependencies = {
        'nvim-lua/plenary.nvim',
        'stevearc/dressing.nvim',
    },
    opts = {
        lsp = {
            color = {
                enabled = true,
            },
            capabilities = require("cmp_nvim_lsp").default_capabilities(),
        },
        widget_guides = {
            enabled = true,
        },
        closing_tags = {
            enabled = true,
        },
    },
}
