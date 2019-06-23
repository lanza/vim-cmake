
function! s:vui_todo_app()
    if !exists("g:vui_todos")
        let g:vui_todos      = []
        let g:vui_todos_mode = 'all'
    endif

    let screen = vui#screen#new()
    let screen.mode = g:vui_todos_mode

    function! screen.new_todo()
        let description = input("New Todo: ")

        if len(description) == 0
            return
        endif

        let todo = {"description": description, "done": 0}

        call add(g:vui_todos, todo)
        return todo
    endfunction

    function! screen.delete_item()
        if !has_key(self.get_focused_element(), 'is_todo')
            return
        endif

        let l:index = index(g:vui_todos, self.get_focused_element().item)

        if l:index == -1
            return
        endif

        call remove(g:vui_todos, l:index)
    endfunction

    function! screen.visible_todos()
        let visible = []

        for i in range(0, len(g:vui_todos) - 1)
            let todo = g:vui_todos[i]
            if todo.done && self.mode == 'pending'
                continue
            endif
            call add(visible, todo)
        endfor

        return visible
    endfunction

    function! screen.toggle_mode()
        let self.mode        = self.mode == 'all' ? 'pending' : 'all'
        let g:vui_todos_mode = self.mode
    endfunction

    function! screen.render_todos(container, todos)
        call a:container.clear_children()

        for i in range(0, len(a:todos) - 1)
            let todo           = a:todos[i]
            let toggle         = vui#component#toggle#new(todo.description)
            let toggle.is_todo = 1
            let toggle.item    = todo

            call toggle.set_checked(toggle.item.done)

            function! toggle.on_change(toggle)
                let a:toggle.item.done = a:toggle.item.done ? 0 : 1
            endfunction

            call a:container.add_child(toggle)
        endfor
    endfunction

    function! screen.on_before_render(screen)
        let width  = winwidth(0)
        let height = winheight(0)

        let subtitle   =  g:vui_todos_mode == 'all' ? ' - ALL' : ' - PENDING'

        let main_panel = vui#component#panel#new('TO-DO' . subtitle, width, height)
        let content    = main_panel.get_content_component()
        let container  = vui#component#vcontainer#new()
        let add_button = vui#component#button#new('[Add Item]')

        let todos = self.visible_todos()
        call add_button.set_y(len(todos) == 0 ? 0 : len(todos) + 1)

        function! add_button.on_action(button)
            call b:screen.new_todo()
        endfunction

        call content.add_child(container)
        call content.add_child(add_button)

        call a:screen.render_todos(container, todos)

        call a:screen.set_root_component(main_panel)
    endfunction

    function! screen.on_before_create_buffer(foo)
        execute "40wincmd v"
    endfunction

    call screen.map('a', 'new_todo')
    call screen.map('m', 'toggle_mode')
    call screen.map('dd', 'delete_item')
    call screen.show()
endfunction

command! VuiToDo call s:vui_todo_app()

nnoremap <leader>td :VuiToDo<CR>
