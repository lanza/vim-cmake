" cmake.vim - Vim plugin to create a CMake project system
" Maintainer: Nathan Lanza <https://github.com/lanza>
" Version:    0.1
"
function! s:decode_json(string) abort
  if exists('*json_decode')
    return json_decode(a:string)
  endif
  let [null, false, true] = ['', 0, 1]
  let stripped = substitute(a:string,'\C"\(\\.\|[^"\\]\)*"','','g')
  if stripped !~# "[^,:{}\\[\\]0-9.\\-+Eaeflnr-u \n\r\t]"
    try
      return eval(substitute(a:string,"[\r\n]"," ",'g'))
    catch
    endtry
  endif
  call s:throw("invalid JSON: ".a:string)
endfunction

function! s:encode_json(object) abort
  if exists('*json_encode')
    return json_encode(a:object)
  endif
  if type(a:object) == type('')
    return '"' . substitute(a:object, "[\001-\031\"\\\\]", '\=printf("\\u%04x", char2nr(submatch(0)))', 'g') . '"'
  elseif type(a:object) == type([])
    return '['.join(map(copy(a:object), 's:encode_json(v:val)'),', ').']'
  elseif type(a:object) == type({})
    let pairs = []
    for key in keys(a:object)
      call add(pairs, s:encode_json(key) . ': ' . s:encode_json(a:object[key]))
    endfor
    return '{' . join(pairs, ', ') . '}'
  else
    return string(a:object)
  endif
endfunction


" if exists("g:loaded_vim_cmake")
"   finish
" else
  let g:loaded_vim_cmake = 1
  call system("mkdir -p  ~/.local/share/vim-cmake")
"endif

let g:cmake_target = ""

if filereadable($HOME . "/.local/share/vim-cmake/file")
  let s:cache_file = readfile($HOME . "/.local/share/vim-cmake/file")
  if len(s:cache_file)
    let g:cmake_target = s:cache_file[0]
  endif
else
  call system("touch ~/.local/share/vim-cmake/file")
endif

let g:cmake_export_compile_commands = 1
let g:cmake_build_dir = "build/Debug"
if !isdirectory(g:cmake_build_dir)
  let g:cmake_build_dir = "build"
endif
let g:cmake_generator = "Ninja"

function! g:Parse_codemodel_json()
  if !isdirectory(g:cmake_build_dir . '/.cmake/api/v1/reply')
    echom "Must configure and generate first"
    call s:assure_query_reply()
    return 0
  endif
  let g:cmake_query_response = g:cmake_build_dir . "/.cmake/api/v1/reply/"
  let l:codemodel_file = globpath(g:cmake_query_response, "codemodel*")
  let l:codemodel_contents = readfile(l:codemodel_file)
  let l:json_string = join(l:codemodel_contents, "\n")

  let l:data = s:decode_json(l:json_string)

  let l:configurations = l:data["configurations"]
  let l:first_config = l:configurations[0]
  let l:targets_dicts = l:first_config["targets"]


  let g:execs = []
  let g:tars = []
  let g:all_tars = []

  for target in targets_dicts
    let l:jsonFile = target["jsonFile"]
    let l:name = target["name"]
    let l:file = readfile(g:cmake_query_response . l:jsonFile)
    let l:json_string = join(l:file, "\n")
    let l:target_file_data = s:decode_json(l:json_string)
    if has_key(l:target_file_data, "artifacts")
      let l:artifacts = l:target_file_data["artifacts"]
      let l:artifact = l:artifacts[0]
      let l:path = l:artifact["path"]
      let l:type = l:target_file_data["type"]
      if l:type == "Executable"
        call add(g:execs, {l:name : l:path})
      endif
      call add(g:tars, {l:name : l:path})
    else
      let l:type = l:target_file_data["type"]
      call add(g:all_tars , {l:name : l:type})
    endif
  endfor
  return 1
endfunction

function! s:make_query_files()
  if !isdirectory(g:cmake_build_dir . "/.cmake/api/v1/query")
    call mkdir(g:cmake_build_dir . "/.cmake/api/v1/query", "p")
  endif
  if !filereadable(g:cmake_build_dir . "/.cmake/api/v1/query/codemodel-v2")
    call writefile([" "], g:cmake_build_dir . "/.cmake/api/v1/query/codemodel-v2")
  endif
endfunction

function! s:assure_query_reply()
  if !isdirectory(g:cmake_build_dir . "/.cmake/api/v1/reply")
    call s:cmake_configure_and_generate()
  endif
endfunction


function! s:cmake_configure_and_generate()
  call s:make_query_files()
  let l:arguments = []
  let l:arguments += ["-G " . g:cmake_generator]
  let l:arguments += ["-DCMAKE_EXPORT_COMPILE_COMMANDS=ON"]
  let l:arguments += ["-DCMAKE_BUILD_TYPE=Debug"]

  let l:argument_string = join(l:arguments, " ")

  let l:command = 'cmake ' . l:argument_string . ' -B' . g:cmake_build_dir . ' -H.'
  "echo l:command
  " silent let l:res = system(l:command)
  " echo l:res 
  exec "Dispatch " . l:command
endfunction

function! s:cmake_build_target()
  if !g:Parse_codemodel_json()
    return
  endif
  let l:command = '!cmake --build ' . g:cmake_build_dir . ' --target'
  let l:names = []
  for target in g:tars
    let l:name = keys(target)[0]
    call add(l:names, l:name)
  endfor

  set makeprg=ninja
  let g:makeshift_root = g:cmake_build_dir
  let b:makeshift_root = g:cmake_build_dir
  call fzf#run({'source': l:names, 'sink': l:command , 'down': len(l:names) + 2})
  ". l:command
  " silent let l:res = system(l:command)
  " echo l:res
endfunction

function! s:cmake_build_non_artifacts()
  if !g:Parse_codemodel_json()
    return
  endif
  let l:command = '!cmake --build ' . g:cmake_build_dir . ' --target'
  let l:names = []
  for target in g:all_tars
    let l:name = keys(target)[0]
    call add(l:names, l:name)
  endfor

  set makeprg=ninja
  let g:makeshift_root = g:cmake_build_dir
  let b:makeshift_root = g:cmake_build_dir
  call fzf#run({'source': l:names, 'sink': l:command , 'down': len(l:names) + 2})
  ". l:command
  " silent let l:res = system(l:command)
  " echo l:res
endfunction

function! s:cmake_build()
  let l:command = 'cmake --build ' . g:cmake_build_dir

  if g:cmake_target
    let l:command += ' ' . g:cmake_target
  endif
  set makeprg=ninja
  let g:makeshift_root = g:cmake_build_dir
  let b:makeshift_root = g:cmake_build_dir
  exec "MakeshiftBuild" 
  ". l:command
  " silent let l:res = system(l:command)
  " echo l:res
endfunction

function! s:cmake_target(target)
  let g:cmake_target = a:target
  let l:list = []
  call add(l:list, g:cmake_target)
  call writefile(l:list, $HOME . "/.local/share/vim-cmake/file")
endfunction

function! s:cmake_run()
  let l:command = 'build/' . g:cmake_target
  " silent let l:res = system(l:command)
  " echo l:res
  exec "Dispatch " . l:command
endfunction

function! s:start_lldb(target)
  try
    exec "!cmake --build " . g:cmake_build_dir . ' --target ' . a:target
  catch /.*/
    echo "Failed to build " . a:target
  finally
    exec "GdbStartLLDB lldb " . g:cmake_build_dir . "/" . a:target
  endtry
endfunction

function! s:cmake_debug()
  if !g:Parse_codemodel_json()
    return
  endif
  let l:names = []

  for target in g:execs
    let l:name = values(target)[0]
    call add(l:names, l:name)
  endfor

  call fzf#run({'source': l:names, 'sink': function('s:start_lldb'), 'down': len(l:names) + 2})
endfunction


command! -nargs=0 -complete=shellcmd CMakeDebug call s:cmake_debug()
command! -nargs=0 -complete=shellcmd CMakeRun call s:cmake_run()
command! -nargs=1 -complete=shellcmd CMakeTarget call s:cmake_target(<f-args>)
command! -nargs=0 -complete=shellcmd CMakeBuild call s:cmake_build()
command! -nargs=0 -complete=shellcmd CMakeBuildTarget call s:cmake_build_target()
command! -nargs=0 -complete=shellcmd CMakeBuildNonArtifacts call s:cmake_build_non_artifacts()
command! -nargs=0 -complete=shellcmd CMakeConfigureAndGenerate call s:cmake_configure_and_generate()

if 0
  command! -nargs=1 -complete=shellcmd GdbStartLLDB call nvimgdb#Spawn('lldb', 'lldbwrap.sh', <q-args>)

  if !exists('g:nvimgdb_disable_start_keymaps') || !g:nvimgdb_disable_start_keymaps
    nnoremap <leader>dd :GdbStart gdb -q a.out
    nnoremap <leader>dl :GdbStartLLDB lldb a.out
    nnoremap <leader>dp :GdbStartPDB python -m pdb main.py
  endif
endif
