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
endif

let g:cmake_target = ""


function! s:get_cache_file()
  if exists("g:cmake_cache_file")
    return g:cmake_cache_file
  endif
  let g:vim_cmake_cache_file_path = $HOME . "/.vim_cmake.json"
  if filereadable(g:vim_cmake_cache_file_path)
    let l:contents = readfile(g:vim_cmake_cache_file_path)
    let l:json_string = join(l:contents, "\n")

    let g:cmake_cache_file = s:decode_json(l:json_string)
  else
    let g:cmake_cache_file = s:decode_json("{}")
  endif
  return g:cmake_cache_file
endfunction

function! g:Parse_codemodel_json()
  let l:build_dir = s:get_build_dir()
  if !isdirectory(l:build_dir . '/.cmake/api/v1/reply')
    echom "Must configure and generate first"
    call s:assure_query_reply()
    return 0
  endif
  let g:cmake_query_response = l:build_dir . "/.cmake/api/v1/reply/"
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
try
  let g:cmake_target = s:cache_file[getcwd()].current_target
catch /.*/
  let g:cmake_target = ""
endtry

let g:cmake_export_compile_commands = 1
let g:cmake_generator = "Ninja"

function! s:make_query_files()
  let l:build_dir = s:get_build_dir()
  if !isdirectory(l:build_dir . "/.cmake/api/v1/query")
    call mkdir(l:build_dir . "/.cmake/api/v1/query", "p")
  endif
  if !filereadable(l:build_dir . "/.cmake/api/v1/query/codemodel-v2")
    call writefile([" "], l:build_dir . "/.cmake/api/v1/query/codemodel-v2")
  endif
endfunction

function! s:assure_query_reply()
  let l:build_dir = s:get_build_dir()
  if !isdirectory(l:build_dir . "/.cmake/api/v1/reply")
    call s:cmake_configure_and_generate()
  endif
endfunction

function! s:get_cmake_argument_string()
  call s:make_query_files()
  let l:arguments = []
  let l:arguments += ["-G " . g:cmake_generator]
  let l:arguments += ["-DCMAKE_EXPORT_COMPILE_COMMANDS=ON"]
  let l:arguments += ["-DCMAKE_BUILD_TYPE=Debug"]

  let l:argument_string = join(l:arguments, " ")
  let l:command = l:argument_string . ' -B ' . s:get_build_dir() . ' -S ' . s:get_source_dir()
  return l:command
endfunction

function! s:cmdb_configure_and_generate()
  "echo 'CMDB ' . s:get_cmake_argument_string()
  exec 'CMDB ' . s:get_cmake_argument_string()
endfunction

python3 << endpython
import os
import vim

def get_build_relative_path(build, path):
    path = os.path.relpath(path, build)
    vim.command('return "%s"' % path)

def get_path_to_current_buffer():
    path = vim.current.buffer.name
    vim.command('return "%s"' % path)
endpython

function! s:get_path_to_current_buffer()
  python3 get_path_to_current_buffer()
endfunction

function! s:get_build_relative_path(current_path)
  python3 get_build_relative_path(vim.call('s:get_build_dir()'), vim.eval('a:current_path'))
endfunction


function! s:cmake_compile_current_file()
  let l:current_path = s:get_path_to_current_buffer()
  let l:rel_path = s:get_build_relative_path(l:current_path)
  let &makeprg = "ninja -C " .  s:get_build_dir() . ' ' . l:rel_path . '^'
  Make
  if !has('gui_running')
    redraw!
  endif
endfunction

function g:CMake_configure_and_generate()
  call s:cmake_configure_and_generate()
endfunction
function! s:cmake_configure_and_generate()
  let l:command = 'cmake ' . s:get_cmake_argument_string()
  exec "Dispatch " . l:command
endfunction

function! s:cmake_build_target()
  if !g:Parse_codemodel_json()
    return
  endif
  let l:command = '!cmake --build ' . s:get_build_dir() . ' --target'
  let l:names = []
  for target in g:tars
    let l:name = keys(target)[0]
    call add(l:names, l:name)
  endfor

  set makeprg=ninja
  call fzf#run({'source': l:names, 'sink': l:command , 'down': len(l:names) + 2})
  ". l:command
  " silent let l:res = system(l:command)
  " echo l:res
endfunction

function! s:cmake_build_non_artifacts()
  if !g:Parse_codemodel_json()
    return
  endif
  let l:command = '!cmake --build ' . s:get_build_dir() . ' --target'
  let l:names = []
  for target in g:all_tars
    let l:name = keys(target)[0]
    call add(l:names, l:name)
  endfor

  set makeprg=ninja
  call fzf#run({'source': l:names, 'sink': l:command , 'down': len(l:names) + 2})
  ". l:command
  " silent let l:res = system(l:command)
  " echo l:res
endfunction

function! s:cmake_build()
  let l:command = 'cmake --build ' . s:get_build_dir()

  if g:cmake_target
    let l:command += ' --target ' . g:cmake_target
  endif
  let &makeprg = l:command
  ". l:command
  " silent let l:res = system(l:command)

  Make

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
  let g:cmake_target = s:get_build_dir() . '/' . g:tar_to_file[a:target]

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
  exec "Dispatch " . g:cmake_target
endfunction

function! s:start_lldb(target)
  let l:args = ""
  let l:data = s:get_cache_file()
  if has_key(l:data, getcwd())
    let l:dir = l:data[getcwd()]["targets"]
    if has_key(l:dir, s:get_build_dir() . "/" . a:target)
      let l:target = l:dir[s:get_build_dir() . "/" . a:target]
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
    exec "!cmake --build " . s:get_build_dir() . ' --target ' . a:target
  catch /.*/
    echo "Failed to build " . a:target
  finally
    if exists("l:init_file")
      let l:lldb_init_arg = " -s /tmp/lldbinitvimcmake "
    else
      let l:lldb_init_arg = ""
    endif
    exec "GdbStartLLDB lldb " . s:get_build_dir() . "/" . a:target . l:lldb_init_arg . ' -- ' . l:args
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
  if g:cmake_target == ""
    echo "Please set g:cmake_target first"
    return
  endif
  let s = join(a:000, " ")
  let c = s:get_target_cache()
  let c["args"] = s
  call s:update_cache_file()
endfunction

function!  s:get_targets_cache()
  let c = s:get_cwd_cache()
  if !has_key(c, "targets")
    let c["targets"] = {}
  endif
  return c["targets"]
endfunction

function! s:get_target_cache()
  let c = s:get_targets_cache()
  if !has_key(c, g:cmake_target)
    let c[g:cmake_target] = {}
  endif
  return c[g:cmake_target]
endfunction

function! s:cmake_set_build_dir(...)
  let dir = a:1
  let c = s:get_cwd_cache()
  let c["build_dir"] = dir
  call s:update_cache_file()
endfunction

function! s:cmake_set_source_dir(...)
  let dir = a:1
  let c = s:get_cwd_cache()
  let c["source_dir"] = dir
  call s:update_cache_file()
endfunction

function! s:get_cwd_cache()
  let c = s:get_cache_file()
  if !has_key(c, getcwd())
    let c[getcwd()] = {"targets" : {}}
  endif
  return c[getcwd()]
endfunction

function! s:get_source_dir()
  let c = s:get_cwd_cache()
  if !has_key(c, "source_dir")
    let c["source_dir"] = "."
  endif
  return c["source_dir"]
endfunction

function! s:get_build_dir()
  let c = s:get_cwd_cache()
  if !has_key(c, "build_dir")
    let c["build_dir"] = "build/Debug"
  endif
  return c["build_dir"]
endfunction

function! g:Cmake_edit_args()
  if !exists("g:vui_args")
    let l:cache_file = s:get_cache_file()
    if has_key(l:cache_file, getcwd())
      let g:vui_breakpoints = s:get_cwd_cache()["targets"]
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

command! -nargs=1 -complete=shellcmd CMakeSetBuildDir call s:cmake_set_build_dir(<f-args>)
command! -nargs=1 -complete=shellcmd CMakeSetSourceDir call s:cmake_set_source_dir(<f-args>)
command! -nargs=* -complete=shellcmd CMakeArgs call s:cmake_args(<f-args>)
command! -nargs=0 -complete=shellcmd CMakeCompileFile call s:cmake_compile_current_file()
command! -nargs=0 -complete=shellcmd CMakeDebug call s:cmake_debug()
command! -nargs=0 -complete=shellcmd CMakeRun call s:cmake_run()
command! -nargs=0 -complete=shellcmd CMakeTarget call s:cmake_target()
command! -nargs=0 -complete=shellcmd CMakeBuild call s:cmake_build()
command! -nargs=0 -complete=shellcmd CMakeBuildTarget call s:cmake_build_target()
command! -nargs=0 -complete=shellcmd CMakeBuildNonArtifacts call s:cmake_build_non_artifacts()
command! -nargs=0 -complete=shellcmd CMakeConfigureAndGenerate call s:cmake_configure_and_generate()
command! -nargs=0 -complete=shellcmd CMDBConfigureAndGenerate call s:cmdb_configure_and_generate()
command! -nargs=0 -complete=shellcmd CMakeBreakpoints call g:Cmake_edit_breakpoints()
