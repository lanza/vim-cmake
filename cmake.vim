let s:typeInfo = {}
let s:typeInfo.target = -1
let s:typeInfo.breakpoint = -2
let s:typeInfo.app = -3
let s:typeInfo.cmakeState = -4


let s:CMakeState = {}
let s:CMakeState.typeInfo = s:typeInfo.cmakeState
function s:createCMakeState(args, buildDir, sourceDir)
  let l:copy = deepcopy(s:CMakeState)
  let l:copy.args = a:args
  let l:copy.buildDir = a:buildDir
  let l:copy.sourceDir = a:sourceDir
  return l:copy
endf


let g:App = {}
let g:App.currentTarget = v:null
let g:App.breakpoints = []
let g:App.typeInfo = s:typeInfo.app
function g:App.dumpBreakpoints()
  for breakpoint in self.breakpoints
    call breakpoint.dump()
  endfor
endfunction
function g:App.addBreakpoint(breakpoint)
  call assert_true(a:breakpoint.typeInfo == s:typeInfo.breakpoint, "Invalid object passed to addBreakpoint")
  call add(self.breakpoints, a:breakpoint)
endf

let s:Target = {}
let s:Target.typeInfo = s:typeInfo.target
function s:Target.printName()
  echom self.name
endf
function s:Target.setArgsList(argsList)
  call assert_true(type(a:argsList) == v:t_list, "setArgsList takes a list, use setArgs to use a string")
  let self.argsList = a:argsList
  let self.args = join(self.argsList, "")
endf
function s:Target.setArgs(args)
  call assert_true(type(a:args) == v:t_string, "setArgs takes a string, use setArgsList to pass a list")
  let self.args = a:args
  let self.argsList = split(self.args, " ")
endf
function s:Target.dump()
  echom "Target '" . self.dir . "/" . self.name . "' with args '" . self.args . "'"
endf

function s:createTarget(name, dir)
  let l:copy = deepcopy(s:Target)
  let l:copy.name = a:name
  let l:copy.dir = a:dir
  let l:argsList = []
  let l:args = ""

  return l:copy
endf


let s:Breakpoint = {}
let s:Breakpoint.typeInfo = s:typeInfo.breakpoint
function s:Breakpoint.dump()
  echom "Breakpoint: " . self.file . ':' . self.line
endf
function s:createBreakpoint(file, line, column)
  let l:copy = deepcopy(s:Breakpoint)
  let l:copy.file = a:file
  let l:copy.line = a:line
  let l:copy.column = a:column
  return l:copy
endf


let target = s:createTarget("test", "build")

function g:CMakeToggleBreakpoint()
  let l:currentPosition = getcurpos()
  let l:bufferNumber = l:currentPosition[0]
  let l:lineNumber = l:currentPosition[1]
  let l:column = l:currentPosition[2]
  let l:offset = l:currentPosition[3]
  let l:curswant = l:currentPosition[4]

  let l:breakpoint = s:createBreakpoint(expand("%"), l:lineNumber, l:column)
  call g:App.addBreakpoint(l:breakpoint)
endf

call target.setArgs("-cc1 /tmp/test.c")
call target.dump()

call g:CMakeToggleBreakpoint()

call g:App.dumpBreakpoints()
