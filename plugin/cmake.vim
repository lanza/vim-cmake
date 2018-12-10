if exists("g:loaded_vim_cmake")
    finish
endif
let g:loaded_vim_cmake = 1

function! CMakeBuild()
  !cmake -G Ninja -DCMAKE_BUILD_TYPE=Debug -DCMAKE_EXPORT_COMPILE_COMMANDS=ON -S . -B build
endfunction

command! -nargs=0 -complete=shellcmd CMakee call CMakeBuild()
if 0
  command! -nargs=1 -complete=shellcmd GdbStartLLDB call nvimgdb#Spawn('lldb', 'lldbwrap.sh', <q-args>)

  if !exists('g:nvimgdb_disable_start_keymaps') || !g:nvimgdb_disable_start_keymaps
    nnoremap <leader>dd :GdbStart gdb -q a.out
    nnoremap <leader>dl :GdbStartLLDB lldb a.out
    nnoremap <leader>dp :GdbStartPDB python -m pdb main.py
  endif
endif
