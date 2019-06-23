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


if exists("g:loaded_vim_cmake")
  finish
else
  let g:loaded_vim_cmake = 1
  call system("mkdir -p  ~/.local/share/vim-cmake")
endif

let g:cmake_target = ""


function! s:get_cache_file()
  if exists("g:cmake_cache_file")
    return g:cmake_cache_file
  endif
  let g:vim_cmake_cache_file_path = $HOME . "/.vim_cmake.json"
  let l:contents = readfile(g:vim_cmake_cache_file_path)
  let l:json_string = join(l:contents, "\n")

  let g:cmake_cache_file = s:decode_json(l:json_string)
  return g:cmake_cache_file
endfunction

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

  let g:tar_to_file = {}

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
      let g:tar_to_file[l:name] = l:path
    else
      let l:type = l:target_file_data["type"]
      call add(g:all_tars , {l:name : l:type})
    endif
  endfor
  return 1
endfunction

let s:cache_file = s:get_cache_file()
if has_key(s:cache_file, getcwd())
  let dir = s:cache_file[getcwd()]
  if has_key(dir, "current_target")
    let g:cmake_target = dir["current_target"]
  else
    let g:cmake_target = ""
  endif
endif

let g:cmake_export_compile_commands = 1
let g:cmake_build_dir = "build/Debug"
if !isdirectory(g:cmake_build_dir)
  let g:cmake_build_dir = "build"
endif
let g:cmake_generator = "Ninja"

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

function! s:update_cache_file()
  let cache = s:get_cache_file()
  let serial = s:encode_json(cache)
  let split = split(serial, "\n")
  call writefile(split, $HOME . "/.vim_cmake.json")
endfunction

function! s:cmake_target()
  if !g:Parse_codemodel_json()
    return
  endif
  let l:names = []
  for target in g:tars
    let l:name = keys(target)[0]
    call add(l:names, l:name)
  endfor

  set makeprg=ninja
  call fzf#run({'source': l:names, 'sink': function('s:update_target'), 'down': len(l:names) + 2})
endfunction


function! s:update_target(target)
  echom a:target
  let g:cmake_target = g:cmake_build_dir . '/' . g:tar_to_file[a:target]

  let cache = s:get_cache_file()
  if !has_key(cache, getcwd())
    let cache[getcwd()] = {"current_target": g:cmake_target, "targets":{}}
  else
    let dir = cache[getcwd()]
    let dir["current_target"] = g:cmake_target
  endif
  call s:update_cache_file()
endfunction

function! s:cmake_run()
  let l:command = 'build/' . g:cmake_target
  " silent let l:res = system(l:command)
  " echo l:res
  exec "Dispatch " . l:command
endfunction

function! s:start_lldb(target)
  let l:args = ""
  let l:data = s:get_cache_file()
  if has_key(l:data, getcwd())
    let l:dir = l:data[getcwd()]["targets"]
    if has_key(l:dir, g:cmake_build_dir . "/" . a:target)
      let l:target = l:dir[g:cmake_build_dir . "/" . a:target]
      if has_key(l:target, "args")
        let l:args = l:target["args"]
        echo l:args
      endif
      if has_key(l:target, "breakpoints")
        let l:breakpoints = l:target["breakpoints"]
        let l:commands = []
        for b in l:breakpoints
          if b["enabled"]
            let break = "b " . b["text"]
            call add(l:commands, break)
          endif
        endfor
        call add(l:commands, "r")
        let l:init_file = "/tmp/lldbinitvimcmake"
        let l:f = writefile(l:commands, l:init_file)
      endif
    endif
  endif
  try
    exec "!cmake --build " . g:cmake_build_dir . ' --target ' . a:target
  catch /.*/
    echo "Failed to build " . a:target
  finally
    exec "GdbStartLLDB lldb " . g:cmake_build_dir . "/" . a:target . " -s /tmp/lldbinitvimcmake -- " . l:args
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


function! g:Cmake_edit_breakpoints()
  if !exists("g:vui_breakpoints")
    let l:cache_file = s:get_cache_file()
    if has_key(l:cache_file, getcwd())
      let g:vui_breakpoints = l:cache_file[getcwd()]["targets"]
    else
      let g:vui_breakpoints = {}
    endif
    let g:vui_bp_mode = 'all'
  endif

  let screen = vui#screen#new()
  let screen.mode = g:vui_bp_mode

  function! screen.new_breakpoint()
    let breakpoint = input("Breakpoint: ")

    if len(breakpoint) == 0
      return
    endif

    let bp = {"text": breakpoint, "enabled": 1}

    if !has_key(g:vui_breakpoints, g:cmake_target)
      let g:vui_breakpoints[g:cmake_target] = {"breakpoints": []}
    endif

    call add(g:vui_breakpoints[g:cmake_target]["breakpoints"], bp)
    call s:update_cache_file()
    return bp
  endfunction

  function! screen.delete_breakpoint()
    if !has_key(self.get_focused_element(), 'is_breakpoint')
      return
    endif

    let l:index = index(g:vui_breakpoints[g:cmake_target]["breakpoints"], self.get_focused_element().item)

    if l:index == -1
      return
    endif

    call s:update_cache_file()
    call remove(g:vui_breakpoints[g:cmake_target]["breakpoints"], l:index)
  endfunction

  function! screen.visible_breakpoints()
    let visible = []
    if !has_key(g:vui_breakpoints, g:cmake_target)
      let g:vui_breakpoints[g:cmake_target] = {"breakpoints": []}
    endif

    for i in range(0, len(g:vui_breakpoints[g:cmake_target]["breakpoints"]) - 1)
      let breakpoint = g:vui_breakpoints[g:cmake_target]["breakpoints"][i]
      if breakpoint.enabled && self.mode == 'enabled'
        continue
      endif
      call add(visible, breakpoint)
    endfor

    return visible
  endfunction

  function! screen.toggle_mode()
    let self.mode = self.mode == 'all' ? 'enabled' : 'all'
    let g:vui_bp_mode = self.mode
  endfunction

  function! screen.render_breakpoints(container, breakpoints)
    call a:container.clear_children()

    for i in range(0, len(a:breakpoints) - 1)
      let breakpoint = a:breakpoints[i]
      let toggle = vui#component#toggle#new(breakpoint.text)
      let toggle.is_breakpoint = 1
      let toggle.item = breakpoint

      call toggle.set_checked(toggle.item.enabled)
      function! toggle.on_change(toggle)
        let a:toggle.item.enabled = a:toggle.item.enabled ? 0 : 1
        call s:update_cache_file()
      endfunction

      call a:container.add_child(toggle)
    endfor
  endfunction

  function! screen.on_before_render(screen)
    let width = winwidth(0)
    let height = winheight(0)

    let subtitle = g:vui_bp_mode == 'all' ? ' - ALL' : ' - ENABLED'

    let main_panel = vui#component#panel#new('BREAKPOINTS' . subtitle, width, height)
    let content = main_panel.get_content_component()
    let container = vui#component#vcontainer#new()
    let add_button = vui#component#button#new('[Add Breakpoint]')

    let breakpoints = self.visible_breakpoints()
    call add_button.set_y(len(breakpoints) == 0 ? 0 : len(breakpoints) + 1)

    function! add_button.on_action(button)
      call b:screen.new_breakpoint()
    endfunction

    call content.add_child(container)
    call content.add_child(add_button)
    call a:screen.render_breakpoints(container, breakpoints)
    call a:screen.set_root_component(main_panel)
  endfunction

  function! screen.on_before_create_buffer(foo)
    execute "40wincmd v"
  endfunction

  call screen.map('a', 'new_breakpoint')
  call screen.map('m', 'toggle_mode')
  call screen.map('dd', 'delete_breakpoint')
  call screen.show()
endfunction

function! s:cmake_args(...)
  let s = join(a:000, " ")
  let c = s:get_cache_file()
  let c[getcwd()]["targets"][g:cmake_target]["args"] = s
  call s:update_cache_file()
endfunction

command! -nargs=* -complete=shellcmd CMakeArgs call s:cmake_args(<f-args>)
command! -nargs=0 -complete=shellcmd CMakeDebug call s:cmake_debug()
command! -nargs=0 -complete=shellcmd CMakeRun call s:cmake_run()
command! -nargs=0 -complete=shellcmd CMakeTarget call s:cmake_target()
command! -nargs=0 -complete=shellcmd CMakeBuild call s:cmake_build()
command! -nargs=0 -complete=shellcmd CMakeBuildTarget call s:cmake_build_target()
command! -nargs=0 -complete=shellcmd CMakeBuildNonArtifacts call s:cmake_build_non_artifacts()
command! -nargs=0 -complete=shellcmd CMakeConfigureAndGenerate call s:cmake_configure_and_generate()
command! -nargs=0 -complete=shellcmd CMakeBreakpoints call g:Cmake_edit_breakpoints()
