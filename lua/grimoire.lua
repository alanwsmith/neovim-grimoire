local sbuf, rbuf

local function open_search_window()
    sbuf = vim.api.nvim_create_buf(false, true)
    swin = vim.api.nvim_open_win(sbuf, true ,
            {style = "minimal",relative='win', row=5, col=5, width=40, height=4}
        )
    vim.api.nvim_command('au CursorMoved <buffer> lua require"grimoire".show_results()')
end

local function open_results_window()
  rbuf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_open_win(rbuf, false,
        {style = "minimal",relative='win', row=20, col=5, width=40, height=4}
    )
end

local function show_results()
    vim.api.nvim_command(':lua print("BEEEER")')
end

local function grimoire()
    open_results_window()
    open_search_window()
end

return {
  grimoire = grimoire,
  show_results = show_results 
}

