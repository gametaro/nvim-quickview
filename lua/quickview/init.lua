local M = {}

local group = vim.api.nvim_create_augroup('qf', {})
---@type integer?
local last_line
---@type table<string, unknown>
local org_opts = {}
local qflist = {}

M.win_opts = {
  number = true,
  cursorline = true,
}

---@return integer
---@return integer
---@return vim.fn.winsaveview.ret
function M.saveview()
  local win = vim.fn.win_getid(vim.fn.winnr('#'))
  local buf = vim.api.nvim_win_get_buf(win)
  ---@type vim.fn.winsaveview.ret
  local view = vim.api.nvim_win_call(win, vim.fn.winsaveview)
  vim.iter(M.win_opts):each(function(k)
    org_opts[k] = vim.wo[win][k]
  end)
  return win, buf, view
end

---@param win integer
function M.preview(win)
  local current_line = vim.fn.line('.')
  if current_line ~= last_line then
    last_line = current_line
    local item = qflist and qflist[current_line] or vim.fn.getqflist()[current_line]
    if not item then
      return
    end
    ---@type integer
    local buf = item.bufnr
    if item and vim.api.nvim_win_is_valid(win) and vim.api.nvim_buf_is_valid(buf) then
      if not vim.api.nvim_buf_is_loaded(buf) then
        vim.fn.bufload(buf)
      end
      vim.api.nvim_win_set_buf(win, buf)
      vim.api.nvim_win_set_cursor(win, { item.lnum, item.col })
      vim.api.nvim_win_call(win, function()
        vim.cmd.normal({ 'zzzv', bang = true })
      end)
      vim.iter(M.win_opts):each(function(k, v)
        vim.wo[win][k] = v
      end)
    end
  end
end

---@param win integer
---@param buf integer
---@param view vim.fn.winsaveview.ret
function M.restview(win, buf, view)
  if vim.api.nvim_win_is_valid(win) and vim.api.nvim_buf_is_valid(buf) then
    if not vim.api.nvim_buf_is_loaded(buf) then
      vim.fn.bufload(buf)
    end
    vim.api.nvim_win_set_buf(win, buf)
    vim.api.nvim_win_call(win, function()
      vim.fn.winrestview(view)
    end)
    vim.iter(org_opts):each(function(k, v)
      vim.wo[win][k] = v
    end)
  end
end

function M.setup()
  vim.api.nvim_create_autocmd('FileType', {
    group = group,
    pattern = 'qf',
    callback = function()
      vim.api.nvim_clear_autocmds({ group = group, event = { 'CursorMoved', 'WinClosed' } })

      local prev_win, prev_buf, prev_view = M.saveview()

      vim.api.nvim_create_autocmd('CursorMoved', {
        group = group,
        buffer = 0,
        callback = function()
          M.preview(prev_win)
        end,
      })

      vim.api.nvim_create_autocmd({ 'WinEnter', 'WinLeave' }, {
        group = group,
        buffer = 0,
        callback = function(a)
          local opts = a.event == 'WinEnter' and M.win_opts or org_opts
          vim.iter(opts):each(function(k, v)
            vim.wo[prev_win][k] = v
          end)
        end,
      })

      vim.api.nvim_create_autocmd('WinClosed', {
        group = group,
        buffer = 0,
        callback = function()
          M.restview(prev_win, prev_buf, prev_view)
          last_line = nil
          org_opts = {}
          qflist = {}
        end,
      })
    end,
  })
end

return M
