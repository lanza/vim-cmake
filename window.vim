
if !exists("g:godbolt_config")
  let g:godbolt_config = {
    \ "winid": -1
    \ }
endif


function! g:Godbolt(...)
  let l:args = join(a:000, ' ')
  let l:file = expand("%")
  let l:emission = " -S"

endfunction


function! s:check_if_window_is_alive(win)
  try
    call nvim_win_get_config(a:win)
    return v:true
  catch /.*/
    return v:false
  endtry
endf


" get the current window or create a new one if it's already open
function! s:get_or_make_window()
  if !s:check_if_window_is_alive(g:godbolt_config.winid)
    call termopen("ls")
    let g:godbolt_config.winid = nvim_get_current_win()
  endif
  return g:godbolt_config.winid
endf


let s:w = s:get_or_make_window()

call term_getsize()
