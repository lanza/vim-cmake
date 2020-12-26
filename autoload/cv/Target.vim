if exists('cv#Target')
  finish
endif

source autoload/cv/TypeInfo.vim

let s:Target = {}
let s:Target.typeInfo = cv#TypeInfo#target()

function s:Target.printName()
  echom self.name
endf

function s:Target.setArgsList(argsList)
  call assert_true(type(a:argsList) == v:t_list,
        \  "setArgsList takes a list, use setArgs to use a string")

  let self.argsList = a:argsList
  let self.args = join(self.argsList, "")
endf

function s:Target.setArgs(args)
  call assert_true(type(a:args) == v:t_string,
        \  "setArgs takes a string, use setArgsList to pass a list")

  let self.args = a:args
  let self.argsList = split(self.args, " ")
endf

function s:Target.dump()
  echom "Target '" . self.dir . "/" . self.name . "' with args '" . self.args . "'"
endf

function cv#Target#create(name, dir)
  let l:copy = deepcopy(s:Target)
  let l:copy.name = a:name
  let l:copy.dir = a:dir
  let l:argsList = []
  let l:args = ""

  return l:copy
endf
