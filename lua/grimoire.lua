local sbuf, rbuf

local function open_search_window()
    sbuf = vim.api.nvim_create_buf(false, true)
    swin = vim.api.nvim_open_win(sbuf, true ,
            {style = "minimal",relative='win', row=5, col=5, width=55, height=1}
        )
    vim.api.nvim_command('au CursorMoved,CursorMovedI <buffer> lua require"grimoire".show_results()')
end

local function open_results_window()
  rbuf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_open_win(rbuf, false,
        {style = "minimal",relative='win', row=10, col=5, width=40, height=12}
    )
end

local function show_results()
    local query = vim.api.nvim_buf_get_lines(0, 0, 1, false)
    local query_string = string.gsub(query[1], '%s*$', '')
    local lines = vim.fn.systemlist('curl -s "http://127.0.0.1:7700/indexes/grimoire/search?q='..query_string..'" | jq -r ".hits[] | .name"')
    vim.api.nvim_buf_set_lines(rbuf, 0, 3, false, lines)
end

local function grimoire()
    open_results_window()
    open_search_window()
end

return {
  grimoire = grimoire,
  show_results = show_results 
}

