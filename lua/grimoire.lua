local api = vim.api
local buf, win, sbuf, rbuf
local position = 0

local function do_search()


end

local function open_search_window()
  -- api.nvim_command('au CursorMovedI <buffer> :lua vim.api.nvim_buf_set_lines(rbuf, 2, 3, false, ["sadf", "werwer"] ')
  -- api.nvim_command('au TextChangedI * silent! lua api.nvim_buf_set_lines(rbuf, 2, 3, false, ["asdf", "qwer"] ')
  -- api.nvim_command('au TextChangedI * silent! lua print("asdf")')
  sbuf = api.nvim_create_buf(false, true)

  api.nvim_buf_set_option(sbuf, 'bufhidden', 'wipe')
  api.nvim_buf_set_option(sbuf, 'filetype', 'whid')

  swin = api.nvim_open_win(sbuf, true ,
                      {style = "minimal",relative='win', row=5, col=5, width=40, height=4})

  -- api.nvim_command('au CursorMoved,CursorMovedI <buffer> :lua print("qwerty")')
  api.nvim_buf_set_option(buf, 'modifiable', true)
    -- api.nvim_command('au CursorMoved,CursorMovedI <buffer> :lua vim.api.nvim_buf_set_lines(2, 2, 4, false, {"asdf"})')
    -- api.nvim_command('au CursorMoved,CursorMovedI <buffer> :exe ":lua require\"aws\".show_results()"')
    -- api.nvim_command('au CursorMoved,CursorMovedI <buffer> :exe ":AWS.show_results()"')
    vim.api.nvim_command('au CursorMoved <buffer> lua require"aws".show_results()')
  -- api.nvim_buf_set_option(sbuf, 'modifiable', false)
end

local function open_results_window()
  rbuf = api.nvim_create_buf(false, true)
  api.nvim_buf_set_option(rbuf, 'bufhidden', 'wipe')
  api.nvim_buf_set_option(rbuf, 'filetype', 'whid')
  api.nvim_open_win(rbuf, false,
                      {style = "minimal",relative='win', row=20, col=5, width=40, height=4})

end

local function show_results()
    api.nvim_command(':lua print("BEEEER")')
--  api.nvim_buf_set_option(rbuf, 'modifiable', true)

--  local result = vim.fn.systemlist('ls ~/Desktop')
--  for k,v in pairs(result) do
--    result[k] = '  '..result[k]
-- end
--  api.nvim_buf_set_lines(rbuf, 3, -1, false, results)
end

local function center(str)
  local width = api.nvim_win_get_width(0)
  local shift = math.floor(width / 2) - math.floor(string.len(str) / 2)
  return string.rep(' ', shift) .. str
end


local function update_results(direction)
-- Look at: TextChangedI
  api.nvim_buf_set_option(rbuf, 'modifiable', true)
  position = position + direction
  if position < 0 then position = 0 end

    -- local result = vim.fn.systemlist('git diff-tree --no-commit-id --name-only -r  HEAD~'..position)
  local result = vim.fn.systemlist('ls')
  if #result == 0 then table.insert(result, '') end -- add  an empty line to preserve layout if there is no results
  for k,v in pairs(result) do
    result[k] = '  '..result[k]
  end

  api.nvim_buf_set_lines(rbuf, 3, -1, false, result)
  api.nvim_buf_set_option(rbuf, 'modifiable', false)
end

local function open_window()
  buf = api.nvim_create_buf(false, true)
  local border_buf = api.nvim_create_buf(false, true)

  api.nvim_buf_set_option(buf, 'bufhidden', 'wipe')
  api.nvim_buf_set_option(buf, 'filetype', 'whid')

  local width = api.nvim_get_option("columns")
  local height = api.nvim_get_option("lines")

  local win_height = math.ceil(height * 0.8 - 18)
  local win_width = math.ceil(width * 0.8)
  local row = math.ceil((height - win_height) / 2 - 1)
  local col = math.ceil((width - win_width) / 2)

  local border_opts = {
    style = "minimal",
    relative = "editor",
    width = win_width + 2,
    height = win_height + 2,
    row = row - 1,
    col = col - 1
  }

  local opts = {
    style = "minimal",
    relative = "editor",
    width = win_width,
    height = win_height,
    row = row,
    col = col
  }

  local border_lines = { '╔' .. string.rep('═', win_width) .. '╗' }
  local middle_line = '║' .. string.rep(' ', win_width) .. '║'
  for i=1, win_height do
    table.insert(border_lines, middle_line)
  end
  table.insert(border_lines, '╚' .. string.rep('═', win_width) .. '╝')
  api.nvim_buf_set_lines(border_buf, 0, -1, false, border_lines)

  local border_win = api.nvim_open_win(border_buf, true, border_opts)
  win = api.nvim_open_win(buf, true, opts)
  api.nvim_command('au BufWipeout <buffer> exe "silent bwipeout! "'..border_buf)

  api.nvim_win_set_option(win, 'cursorline', true) -- it highlight line with the cursor on it

  -- we can add title already here, because first line will never change
  api.nvim_buf_set_lines(buf, 0, -1, false, { center('What have i done?'), '', ''})
  api.nvim_buf_add_highlight(buf, -1, 'WhidHeader', 0, 0, -1)
end

local function update_view(direction)
  api.nvim_buf_set_option(buf, 'modifiable', true)
  position = position + direction
  if position < 0 then position = 0 end

    -- local result = vim.fn.systemlist('git diff-tree --no-commit-id --name-only -r  HEAD~'..position)
  local result = vim.fn.systemlist('ls')
  if #result == 0 then table.insert(result, '') end -- add  an empty line to preserve layout if there is no results
  for k,v in pairs(result) do
    result[k] = '  '..result[k]
  end

  api.nvim_buf_set_lines(buf, 1, 2, false, {center('HEAD~'..position)})
  api.nvim_buf_set_lines(buf, 3, -1, false, result)

  api.nvim_buf_add_highlight(buf, -1, 'whidSubHeader', 1, 0, -1)
  api.nvim_buf_set_option(buf, 'modifiable', false)
end

local function close_window()
  api.nvim_win_close(win, true)
end

local function open_file()
  local str = api.nvim_get_current_line()
  close_window()
  api.nvim_command('edit '..str)
end

local function move_cursor()
  local new_pos = math.max(4, api.nvim_win_get_cursor(win)[1] - 1)
  api.nvim_win_set_cursor(win, {new_pos, 0})
end

local function set_mappings()
    api.nvim_command(':lua print("HEREREER")')
  local mappings = {
    ['['] = 'show_results()',
    [']'] = 'show_results()',
    ['<cr>'] = 'open_file()',
    h = 'update_view(-1)',
    l = 'update_view(1)',
    q = 'close_window()',
    k = 'move_cursor()',
    a = 'show_results()'
  }

  for k,v in pairs(mappings) do
    api.nvim_buf_set_keymap(buf, 'n', k, ':lua require"aws".'..v..'<cr>', {
        nowait = true, noremap = true, silent = true
      })
  end
  local other_chars = {
    'a', 'b', 'c', 'd', 'e', 'f', 'g', 'i', 'n', 'o', 'p', 'r', 's', 't', 'u', 'v', 'w', 'x', 'y', 'z'
  }
  for k,v in ipairs(other_chars) do
    api.nvim_buf_set_keymap(buf, 'n', v, '', { nowait = true, noremap = true, silent = true })
    api.nvim_buf_set_keymap(buf, 'n', v:upper(), '', { nowait = true, noremap = true, silent = true })
    api.nvim_buf_set_keymap(buf, 'n',  '<c-'..v..'>', '', { nowait = true, noremap = true, silent = true })
  end
end


local function grimoire()
--  position = 0
--  open_window()
--    set_mappings()
--  update_view(0)
    open_results_window()
    open_search_window()
--    update_results(0)
--    api.nvim_command('au CursorMoved <buffer> :lua print("asdf")')
--  api.nvim_win_set_cursor(win, {4, 0})
end

return {
  grimoire = grimoire,
    do_search = do_search,
--  update_view = update_view,
--  open_file = open_file,
--  move_cursor = move_cursor,
--  close_window = close_window,
  show_results = show_results 
}

