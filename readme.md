# Context7.nvim

Context7 integration for neovim

Requires: curl, Neovim 0.10+

https://github.com/user-attachments/assets/4db1dc66-6bfc-4dfc-81a6-d7d00d0b2867

## Installation

Context7 has a free tier with a rate limit of 100 queries per day.

With a free api key you get 1,000 queries per day

https://context7.com/docs/api-key

### lazy.nvim

```lua
{
  "eduardoarandah/context7.nvim",
  config = function()
   require("context7").setup({
     api_key   = "ctx7sk_...", -- your Context7 API key
     min_trust = 7,            -- hide libraries with trustScore below this (0–10)
   })
  end,
}
```

### vim.pack

```lua
vim.pack.add({ "https://github.com/eduardoarandah/context7.nvim" })

require("context7").setup({
  api_key = vim.env.CONTEXT7_API_KEY, -- your Context7 API key
  min_trust = 7, -- hide libraries with trustScore below this (0–10)
})
```

## Usage

`:Context7`

How to close the prompt buffer:

```
  <Esc>  →  enters Normal mode  →  then press  q  or  :q<CR>
  Ctrl-C also exits Insert mode if <Esc> is remapped.
  :q and :bd both work from Normal mode (q is just a shortcut mapping).

```
