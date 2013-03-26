

" TODO: Use <LeftDrag> ?


command! IrairaStart
\   call s:start()

command! IrairaStop
\   call s:stop()


let s:BALLOON_DELAY = 50
let s:UPDATETIME = 200
let s:mouse_pos = {'col': -1, 'lnum': -1}


function! s:start()
    if !has('balloon_eval')
        call s:error('Your Vim must support +balloon_eval feature!')
        return
    endif
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

    " Fill characters in the buffer.
    " :help 'balloonexpr' says:
    "     NOTE: The balloon is displayed only if the cursor is on a text
    "     character.
    setlocal nowrap
    let s:MAX_COLUMNS = 480    " TODO
    let s:MAX_LINES = 640      " TODO
    call setline(1, repeat([repeat('o', s:MAX_COLUMNS)], s:MAX_LINES))
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
    try
        call s:main_loop()
    finally
        call feedkeys("g\<Esc>", "n")
    endtry
endfunction

function! s:main_loop()
    redraw
    echom printf('(%s, %s) at %s', s:mouse_pos.col, s:mouse_pos.lnum, reltimestr(reltime()))

    call s:setchar(s:mouse_pos.lnum, s:mouse_pos.col, 'x')
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
    return reltimestr(reltime())
endfunction

function! s:unregister_balloon_eval()
    setlocal balloondelay<
    setlocal balloonexpr=
    setlocal noballooneval
endfunction

function! s:error(msg)
    echohl ErrorMsg
    try
        echomsg a:msg
    finally
        echohl None
    endtry
endfunction

function! s:setchar(lnum, col, char)
    if a:char !=# ''
        let line = getline(a:lnum)
        let left = a:col-2 <# 0 ? '' : line[: a:col-2]
        let right = line[a:col :]
        call setline(a:lnum, left.a:char.right)
    endif
endfunction
