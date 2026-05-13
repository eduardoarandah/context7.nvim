-- lua/context7.lua
-- Context7 documentation lookup for Neovim
--
-- Setup (in your init.lua or plugin spec):
--
--   require("context7").setup({
--     api_key   = "ctx7sk_...", -- your Context7 API key
--     min_trust = 7,            -- hide libraries with trustScore below this (0–10)
--   })
--
-- How to close the prompt buffer:
--   <Esc>  →  Normal mode  →  q  or  :q<CR>
--   Ctrl-C also exits Insert mode if <Esc> is remapped elsewhere.

local M = {}

local API_BASE = "https://context7.com/api"

-- Runtime config (populated by setup())
local config = {
  api_key = nil,
  min_trust = 7,
}

-- ─── helpers ────────────────────────────────────────────────────────────────

local function auth_header()
  local key = config.api_key or ""
  if key ~= "" then
    return { "-H", "Authorization: Bearer " .. key }
  end
  return {}
end

local function curl_json(args)
  local result = vim.system(vim.list_extend({ "curl", "-s", "--max-time", "15" }, args)):wait()
  if result.code ~= 0 then
    return nil, "curl failed (exit " .. result.code .. ")"
  end
  local ok, data = pcall(vim.json.decode, result.stdout)
  if not ok then
    return nil, "JSON parse error: " .. tostring(result.stdout):sub(1, 120)
  end
  return data, nil
end

-- ─── API calls ──────────────────────────────────────────────────────────────

local function search_libraries(name, callback)
  local url = API_BASE .. "/v2/libs/search?libraryName=" .. vim.uri_encode(name) .. "&query=" .. vim.uri_encode(name) .. "&fast=false"

  local data, err = curl_json(vim.list_extend({ url }, auth_header()))
  if err or not data then
    callback(nil, err or "empty response")
    return
  end
  if data.error then
    callback(nil, data.message or data.error)
    return
  end
  callback(data.results or {}, nil)
end

local function get_context(library_id, query, callback)
  local url = API_BASE .. "/v2/context?libraryId=" .. vim.uri_encode(library_id) .. "&query=" .. vim.uri_encode(query) .. "&type=txt"

  local result = vim.system(vim.list_extend({ "curl", "-s", "--max-time", "20", url }, auth_header())):wait()

  if result.code ~= 0 then
    callback(nil, "curl failed (exit " .. result.code .. ")")
    return
  end
  if result.stdout and result.stdout ~= "" then
    callback(result.stdout, nil)
  else
    callback(nil, "empty response from Context7")
  end
end

-- ─── prompt buffer ──────────────────────────────────────────────────────────

local function open_prompt_buffer(library_id, library_title)
  vim.cmd("botright new")
  vim.cmd("resize 15")

  local buf = vim.api.nvim_get_current_buf()
  local win = vim.api.nvim_get_current_win()

  vim.bo[buf].buftype = "prompt"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].swapfile = false
  vim.bo[buf].filetype = "context7"
  vim.wo[win].wrap = true
  vim.wo[win].linebreak = true
  vim.wo[win].number = false
  vim.wo[win].signcolumn = "no"

  local key_status = (config.api_key or "") ~= "" and "🔑 using api key" or "⚠️  no api key detected (rate limits apply)"

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
    "─────────────────────────────────────────────────────",
    "  Context7 › " .. library_title,
    "  Library ID : " .. library_id,
    "  " .. key_status,
    "  <Enter> query  │  <Esc> normal mode  │  q or :q to close",
    "─────────────────────────────────────────────────────",
    "",
  })

  vim.fn.prompt_setprompt(buf, "Query › ")

  vim.fn.prompt_setcallback(buf, function(text)
    text = vim.trim(text)
    if text == "" then
      return
    end

    vim.fn.prompt_appendbuf(buf, { "", "⏳  Searching Context7…", "" })

    vim.schedule(function()
      get_context(library_id, text, function(response, err)
        vim.schedule(function()
          if err then
            vim.fn.prompt_appendbuf(buf, { "❌  Error: " .. err, "" })
          else
            local lines = vim.split(response, "\n", { plain = true })
            table.insert(lines, 1, "")
            table.insert(lines, 1, "╭─ Answer (" .. library_title .. ") " .. string.rep("─", 35))
            table.insert(lines, "╰" .. string.rep("─", 50))
            table.insert(lines, "")
            vim.fn.prompt_appendbuf(buf, lines)
          end

          local count = vim.api.nvim_buf_line_count(buf)
          if vim.api.nvim_win_is_valid(win) then
            vim.api.nvim_win_set_cursor(win, { count, 0 })
          end
        end)
      end)
    end)
  end)

  vim.keymap.set("n", "q", "<cmd>q<CR>", { buffer = buf, silent = true, desc = "Close Context7" })
  vim.cmd("startinsert")
end

-- ─── run ────────────────────────────────────────────────────────────────────

function M.run()
  vim.ui.input({ prompt = "Context7 library name: " }, function(name)
    if not name or vim.trim(name) == "" then
      return
    end
    name = vim.trim(name)

    vim.notify("Searching Context7 for '" .. name .. "'…", vim.log.levels.INFO)

    search_libraries(name, function(results, err)
      vim.schedule(function()
        if err then
          vim.notify("Context7 search error: " .. err, vim.log.levels.ERROR)
          return
        end

        local trusted = vim.tbl_filter(function(lib)
          return (lib.trustScore or 0) >= config.min_trust
        end, results)

        if #trusted == 0 then
          vim.notify("No libraries found for '" .. name .. "' with trustScore >= " .. config.min_trust, vim.log.levels.WARN)
          return
        end

        local items = {}
        for _, lib in ipairs(trusted) do
          local stars = lib.stars and ("  ★ " .. lib.stars) or ""
          local score = "  trust:" .. (lib.trustScore or "?")
          table.insert(items, lib.title .. "  [" .. lib.id .. "]" .. stars .. score)
        end

        vim.ui.select(items, {
          prompt = "Select a Context7 library:",
          format_item = function(item)
            return item
          end,
        }, function(_, idx)
          if not idx then
            return
          end
          open_prompt_buffer(trusted[idx].id, trusted[idx].title)
        end)
      end)
    end)
  end)
end

-- ─── setup ──────────────────────────────────────────────────────────────────

---@param opts? { api_key?: string, min_trust?: number }
function M.setup(opts)
  opts = opts or {}

  config.api_key = opts.api_key or nil
  config.min_trust = opts.min_trust or 7

  vim.api.nvim_create_user_command("Context7", M.run, { desc = "Query Context7 documentation" })
end

return M

