local rbuf, rwin
local sbuf, swin
local highlight_index = 0

local function close_windows()
    vim.api.nvim_win_close(rwin, true)
    vim.api.nvim_win_close(swin, true)
end

local function open_search_window()
    sbuf = vim.api.nvim_create_buf(false, true)
    swin = vim.api.nvim_open_win(sbuf, true ,
            {style = "minimal",relative='win', row=5, col=5, width=55, height=1}
        )
    vim.api.nvim_command('au CursorMoved,CursorMovedI <buffer> lua require"grimoire".show_results()')
    vim.api.nvim_buf_set_keymap(sbuf, 'i', '[', '<cmd>lua require"grimoire".change_selected_results()<CR>', {
        nowait = true, 
        noremap = true, 
        silent = true
    })
end


local function open_results_window()
  rbuf = vim.api.nvim_create_buf(false, true)
  rwin = vim.api.nvim_open_win(rbuf, false,
        {style = "minimal",relative='win', row=10, col=5, width=40, height=12}
    )
end

local function show_results()
    local query = vim.api.nvim_buf_get_lines(0, 0, 1, false)
    local query_string = string.gsub(query[1], '%s*$', '')
    local query_string2 = string.gsub(query_string, '%s', '%%20')
    local lines = vim.fn.systemlist('curl -s "http://127.0.0.1:7700/indexes/grimoire/search?q='..query_string2..'&limit=8" | jq -r ".hits[] | .name"')
    vim.api.nvim_buf_set_lines(rbuf, 0, 9, false, lines)
    vim.api.nvim_buf_add_highlight(rbuf, -1, 'GrimoireSelection', highlight_index, 0, -1)
end

local function change_selected_results()
    -- local new_pos = api.nvim_win_get_cursor(rwin)[1] + 1
    -- vim.api.nvim_win_set_cursor(rwin, {4, 0})
    vim.api.nvim_buf_add_highlight(rbuf, -1, 'GrimoireSelection', 4, 0, -1)
end

local function grimoire()
    open_results_window()
    open_search_window()
    vim.api.nvim_buf_set_keymap(sbuf, 'n', 'q', ':lua require("grimoire").close_windows()<CR>', {})
end

local function make_mappings()
end

return {
  grimoire = grimoire,
  change_selected_results = change_selected_results,
  close_windows = close_windows,
  show_results = show_results 
}

