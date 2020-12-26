if exists("cv#CMakeState")
  finish
endif

source autoload/cv/TypeInfo.vim

let s:CMakeState = {}
let s:CMakeState.typeInfo = cv#TypeInfo#cmakeState()

function cv#CMakeState#create(args, buildDir, sourceDir)
  let l:copy = deepcopy(cv#CMakeState)
  let l:copy.args = a:args
  let l:copy.buildDir = a:buildDir
  let l:copy.sourceDir = a:sourceDir
  return l:copy
endf


