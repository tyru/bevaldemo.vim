

" TODO:
" * Use <LeftDrag> instead of mouse hovering?
" * Conceal s:CURSOR_NORMAL, s:CURSOR_RED characters.
" * Do not enter Visual-mode. (:behave can prohibit this?)


command! IrairaStart
\   call s:start()

command! IrairaStop
\   call s:stop()


let s:BALLOON_DELAY = 1
let s:UPDATETIME = 50
let s:MAX_SHOOTING_ANIMATE_COUNT = 5
let s:CURSOR_NORMAL = 'o'
let s:CURSOR_RED = 'x'

function! s:initialize_variables()
    let s:mouse_pos = {'col': -1, 'lnum': -1}
    let s:shooting = 0
    let s:shooting_animate_count = 0
    let s:setchar_changed_list = []
endfunction
call s:initialize_variables()



function! s:start()
    if !has('balloon_eval')
        call s:error('Your Vim must support +balloon_eval feature!')
        return
    endif

    call s:initialize_variables()
    call s:setup_iraira_buffer()

    " Create augroup.
    augroup iraira
        autocmd!
    augroup END
    call s:register_cursorhold(s:UPDATETIME)
    call s:register_balloon_eval(s:BALLOON_DELAY)

    " Start polling.
    " call s:polling()
endfunction

function! s:stop()
    call s:close_iraira_buffer()
    call s:unregister_cursorhold()
    call s:unregister_balloon_eval()
endfunction

function! s:setup_iraira_buffer()
    " Open a buffer.
    tabedit
    silent file ___IRAIRA___

    " Add highlight.
    syn match IrairaRed /x/
    highlight IrairaRed term=reverse cterm=bold ctermfg=1 ctermbg=1 guifg=Red guibg=Red
    " FIXME
    " highlight def link IrairaCursor Cursor
    " highlight IrairaCursor term=reverse cterm=bold ctermfg=1 ctermbg=1 guifg=Red guibg=Red
    highlight Cursor term=reverse cterm=bold ctermfg=1 ctermbg=1 guifg=Red guibg=Red

    nnoremap <silent><buffer> <LeftMouse> :<C-u>call <SID>map_shot()<CR><LeftMouse>
    nmap <silent><buffer> <LeftDrag> <LeftMouse>
    nmap <silent><buffer> <2-LeftMouse> <LeftMouse><LeftMouse>
    nmap <silent><buffer> <3-LeftMouse> <LeftMouse><LeftMouse><LeftMouse>
    nmap <silent><buffer> <4-LeftMouse> <LeftMouse><LeftMouse><LeftMouse><LeftMouse>
    " nnoremap <silent><buffer> <LeftRelease> :<C-u>call <SID>map_shot_release()<CR><LeftRelease>

    " Fill characters in the buffer.
    " :help 'balloonexpr' says:
    "     NOTE: The balloon is displayed only if the cursor is on a text
    "     character.
    setlocal nowrap
    setlocal lazyredraw    " for redrawing buffer
    setlocal cursorcolumn
    setlocal cursorline
    setlocal nohlsearch
    let s:MAX_COLUMNS = 480    " TODO
    let s:MAX_LINES = 640      " TODO
    call setline(1, repeat([repeat(s:CURSOR_NORMAL, s:MAX_COLUMNS)], s:MAX_LINES))
endfunction

function! s:close_iraira_buffer()
    close!
endfunction

function! s:register_cursorhold(local_updatetime)
    " Localize updatetime.
    let b:iraira_updatetime = &updatetime
    augroup iraira
        autocmd BufLeave <buffer> call s:unregister_cursorhold()
    augroup END
    let &updatetime = a:local_updatetime

    " Register CursorHold event.
    augroup iraira
        autocmd CursorHold <buffer> call s:polling()
    augroup END
endfunction

function! s:polling()
    call s:restore_chars()
    if s:mouse_pos.lnum ># 0 && s:mouse_pos.col ># 0
    \   && s:mouse_pos.lnum isnot line('.')
    \   || s:mouse_pos.col isnot col('.')
        call cursor(s:mouse_pos.lnum, s:mouse_pos.col)
    endif
    try
        call s:main_loop()
    finally
        call feedkeys("g\<Esc>", "n")
        redraw
    endtry
endfunction

function! s:main_loop()
    redraw
    echo printf('(%s, %s) at %s', s:mouse_pos.col, s:mouse_pos.lnum, reltimestr(reltime()))

    if s:mouse_pos.lnum <=# 0 || s:mouse_pos.col <=# 0
        return
    endif

    " Change mouse position character.
    call s:setchar(s:mouse_pos.lnum, s:mouse_pos.col, s:CURSOR_RED)

    " Shot enemy.
    if s:shooting
        if s:shooting_animate_count <=# s:MAX_SHOOTING_ANIMATE_COUNT
            " left, above
            call s:setchar(
            \   s:mouse_pos.lnum - s:shooting_animate_count,
            \   s:mouse_pos.col  - s:shooting_animate_count,
            \   s:CURSOR_RED)
            " left, below
            call s:setchar(
            \   s:mouse_pos.lnum - s:shooting_animate_count,
            \   s:mouse_pos.col  + s:shooting_animate_count,
            \   s:CURSOR_RED)
            " right, above
            call s:setchar(
            \   s:mouse_pos.lnum + s:shooting_animate_count,
            \   s:mouse_pos.col  - s:shooting_animate_count,
            \   s:CURSOR_RED)
            " right, below
            call s:setchar(
            \   s:mouse_pos.lnum + s:shooting_animate_count,
            \   s:mouse_pos.col  + s:shooting_animate_count,
            \   s:CURSOR_RED)
            let s:shooting_animate_count += 1
        else
            let s:shooting = 0
            let s:shooting_animate_count = 0
        endif
    endif
endfunction

function! s:unregister_cursorhold()
    if exists('b:mousehover_updatetime')
        let &updatetime = b:mousehover_updatetime
        unlet b:mousehover_updatetime
    endif
endfunction



function! s:register_balloon_eval(balloondelay)
    augroup iraira
        autocmd BufLeave <buffer> call s:unregister_balloon_eval()
    augroup END
    let &l:balloondelay = a:balloondelay
    setlocal balloonexpr=IrairaBalloonExpr()
    setlocal ballooneval
endfunction

function! IrairaBalloonExpr()
    " 'balloonexpr' must not have side-effect.
    " Just get current mouse cursor position.
    let s:mouse_pos = {'col': v:beval_col, 'lnum': v:beval_lnum}
    " No popup.
    " return ''
    return printf('(%s, %s)', s:mouse_pos.col, s:mouse_pos.lnum)
endfunction

function! s:unregister_balloon_eval()
    setlocal balloondelay<
    setlocal balloonexpr=
    setlocal noballooneval
endfunction

function! s:map_shot()
    echom 'shot!'
    let s:shooting = 1
    let s:shooting_animate_count = 1
endfunction

function! s:map_shot_release()
    let s:shooting = 0
    let s:shooting_animate_count = 0
endfunction



function! s:error(msg)
    echohl ErrorMsg
    try
        echomsg a:msg
    finally
        echohl None
    endtry
endfunction

" NOTE: Doesn't care with multi-byte
function! s:setchar(lnum, col, char)
    let line = getline(a:lnum)
    if a:char !=# ''
    \   && 0 <# a:lnum && a:lnum <# line('$')
    \   && 0 <# a:col  && a:col  <# col('$')
    \   && line[a:col-1] !=# a:char
        let left = a:col-2 <# 0 ? '' : line[: a:col-2]
        let right = line[a:col :]
        call setline(a:lnum, left.a:char.right)
        call add(s:setchar_changed_list, [a:lnum, a:col])
    endif
endfunction

function! s:restore_chars()
    for pos in s:setchar_changed_list
        call s:setchar(pos[0], pos[1], s:CURSOR_NORMAL)
    endfor
    let s:setchar_changed_list = []
endfunction
