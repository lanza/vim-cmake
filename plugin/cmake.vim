" cmake.vim - Vim plugin to create a CMake project system
" Maintainer: Nathan Lanza <https://github.com/lanza>
" Version:    0.1

if exists("g:loaded_vim_cmake")
  finish
else
  let g:loaded_vim_cmake = 1
endif

let g:cmake_export_compile_commands = 1
let g:cmake_build_dir = "build"
let g:cmake_generator = "Ninja"

function! s:cmake_configure_and_generate()
  let l:arguments = []
  let l:arguments += ["-G " . g:cmake_generator]
  let l:arguments += ["-DCMAKE_EXPORT_COMPILE_COMMANDS=ON"]
  let l:arguments += ["-DCMAKE_BUILD_TYPE=Debug"]

  let l:argument_string = join(l:arguments, " ")

  let l:command = 'cmake' . ' -B ' . g:cmake_build_dir . ' -S . ' . l:argument_string
  silent let l:res = system(l:command)
  echo l:res 
endfunction

function! s:cmake_build()
  let l:command = 'cmake --build ' . g:cmake_build_dir
  silent let l:res = system(l:command)
  echo l:res
endfunction


command! -nargs=0 -complete=shellcmd CMakeBuild call s:cmake_build()
command! -nargs=0 -complete=shellcmd CMakeConfigureAndGenerate call s:cmake_configure_and_generate()

if 0
  command! -nargs=1 -complete=shellcmd GdbStartLLDB call nvimgdb#Spawn('lldb', 'lldbwrap.sh', <q-args>)

  if !exists('g:nvimgdb_disable_start_keymaps') || !g:nvimgdb_disable_start_keymaps
    nnoremap <leader>dd :GdbStart gdb -q a.out
    nnoremap <leader>dl :GdbStartLLDB lldb a.out
    nnoremap <leader>dp :GdbStartPDB python -m pdb main.py
  endif
endif
