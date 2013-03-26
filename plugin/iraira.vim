

command! IrairaStart
\   call s:start()

command! IrairaStop
\   call s:stop()


let s:BALLOON_DELAY = 100
let s:mouse_pos = {'x': -1, 'y': -1}
let s:rewriting = 0


function! s:start()
    if !has('balloon_eval')
        call s:error('Your Vim must support +balloon_eval feature!')
        return
    endif
    call s:setup_iraira_buffer()
    call s:register_balloon_eval(s:BALLOON_DELAY)
endfunction

function! s:stop()
    call s:close_iraira_buffer()
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
    call setline(1, repeat([repeat('x', s:MAX_COLUMNS)], s:MAX_LINES))
endfunction

function! s:close_iraira_buffer()
    close!
endfunction

function! s:register_balloon_eval(balloondelay)
    augroup iraira
        autocmd!
        autocmd BufLeave <buffer> call s:unregister_balloon_eval()
    augroup END
    let &l:balloondelay = a:balloondelay
    setlocal balloonexpr=IrairaBalloonExpr()
    setlocal ballooneval
endfunction

function! IrairaBalloonExpr()
    " Get current mouse cursor position.
    let s:mouse_pos = {'x': v:beval_col, 'y': v:beval_lnum}
    " 'balloonexpr' must not have side-effect.
    " Queue a process of rewriting a buffer.
    if !s:rewriting
        call feedkeys(":\<C-u>call IrairaRewriteBuffer()\<CR>", 'n')
        let s:rewriting = 1
    endif
    " No popup.
    return ''
endfunction

function! IrairaRewriteBuffer()
    echom 'rewrite!'
    let s:rewriting = 0
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
