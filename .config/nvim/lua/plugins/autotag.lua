-- HTML / Vue / JSX / Svelte で閉じタグの自動挿入と、開きタグ変更時の閉じタグ追従
return {
  "windwp/nvim-ts-autotag",
  event = { "BufReadPre", "BufNewFile" },
  opts = {
    opts = {
      enable_close = true,
      enable_rename = true,
      enable_close_on_slash = true,
    },
  },
}
