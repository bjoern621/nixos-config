# GUI-style text editing keys, bound to sequences kitty sends in legacy mode.
# Kitty side (freed defaults, CSI u sends) lives in terminal.nix.
# Ctrl+Left/Right, Ctrl+Backspace, Ctrl+Del live in shell.nix, shared with ops user.

# Home/End: CSI form in normal cursor mode, SS3 form in application mode.
bindkey '^[[H' beginning-of-line
bindkey '^[OH' beginning-of-line
bindkey '^[[F' end-of-line
bindkey '^[OF' end-of-line

# Ctrl+Home/End: whole buffer.
# Builtin beginning-of-buffer-or-history falls through into history.
_buffer-start() { CURSOR=0 }
_buffer-end() { CURSOR=$#BUFFER }
zle -N buffer-start _buffer-start
zle -N buffer-end _buffer-end
bindkey '^[[1;5H' buffer-start
bindkey '^[[1;5F' buffer-end

# Ctrl+Shift+Backspace: delete to line start. Ctrl+Shift+Del: delete to line end.
# Legacy encoding drops shift from Backspace, so kitty sends CSI u form.
bindkey '^[[127;6u' backward-kill-line
bindkey '^[[3;6~' kill-line

# Ctrl+Z undo, Ctrl+Shift+Z redo.
# zle reads ^Z raw at prompt; SIGTSTP still fires while a job holds tty.
# Legacy encoding drops shift from Ctrl+Z, so kitty sends CSI u form.
bindkey '^Z' undo
bindkey '^[[122;6u' redo

# Shift selection.
# Active region switches to own keymap.
# Main keymap stays untouched, so autosuggest accept on Right/End keeps working.
bindkey -N shift-select

# Underline, not fill.
# Terminal cells cannot draw box outline; underline is closest unfilled marker.
zle_highlight=(${zle_highlight:#region:*} region:underline)

# kitty user var zsh_selection marks active region.
# kitty.conf routes Ctrl+Shift+C to zsh only while set.
_shift-select-flag() {
  if (( $1 )); then
    print -n '\e]1337;SetUserVar=zsh_selection=MQ==\a' >$TTY
  else
    print -n '\e]1337;SetUserVar=zsh_selection\a' >$TTY
  fi
}
# ^C aborts line without passing through any widget below.
autoload -Uz add-zsh-hook
_shift-select-precmd() { _shift-select-flag 0 }
add-zsh-hook precmd _shift-select-precmd

_shift-select-end() {
  REGION_ACTIVE=0
  _shift-select-flag 0
  zle -K main
}

# Cuts region from BUFFER directly.
# kill-region would overwrite kill ring (Ctrl+Y).
_shift-select-delete() {
  local start=$(( MARK < CURSOR ? MARK : CURSOR ))
  local end=$(( MARK < CURSOR ? CURSOR : MARK ))
  BUFFER=${BUFFER[1,start]}${BUFFER[end+1,-1]}
  CURSOR=$start
  _shift-select-end
}

# Unbound key drops region, replays through main keymap.
# Covers ESC, so arrow sequences replay whole.
_shift-select-deselect() {
  _shift-select-end
  zle -U -- "$KEYS"
}
zle -N shift-select-deselect _shift-select-deselect
bindkey -M shift-select -R '^@'-'^?' shift-select-deselect

# Typing replaces selection.
# High bytes cover UTF-8 lead bytes (umlauts).
_shift-select-replace() {
  _shift-select-delete
  zle -U -- "$KEYS"
}
zle -N shift-select-replace _shift-select-replace
bindkey -M shift-select -R ' '-'~' shift-select-replace
bindkey -M shift-select -R '\M-^@'-'\M-^?' shift-select-replace

# Backspace/Del, plain or Ctrl, delete selection only.
zle -N shift-select-delete _shift-select-delete
for key in '^?' '^H' '^[[3~' '^[[3;5~'; do
  bindkey -M shift-select "$key" shift-select-delete
done

# Paste replaces selection.
# Builtin reads rest of paste up to closing ^[[201~.
_shift-select-paste() {
  _shift-select-delete
  zle .bracketed-paste
}
zle -N shift-select-paste _shift-select-paste
bindkey -M shift-select '^[[200~' shift-select-paste

# Ctrl+Shift+C copies region via OSC 52, then drops it.
# kitty sends CSI u form only while zsh_selection set.
# Main keymap binding swallows stale sends.
_shift-select-copy() {
  (( REGION_ACTIVE )) || return 0
  local start=$(( MARK < CURSOR ? MARK : CURSOR ))
  local end=$(( MARK < CURSOR ? CURSOR : MARK ))
  print -n "\e]52;c;$(print -rn -- ${BUFFER[start+1,end]} | base64 -w0)\a" >$TTY
  _shift-select-end
}
zle -N shift-select-copy _shift-select-copy
bindkey -M main '^[[99;6u' shift-select-copy
bindkey -M shift-select '^[[99;6u' shift-select-copy

# Shift+movement sets mark on first press, then extends.
# Target passed as argument, not read from $WIDGET.
# zsh-autosuggestions rebinds widgets under autosuggest-orig-N-* names, which changes $WIDGET.
# Dot widgets skip autosuggest wrappers, so Shift+Right never accepts suggestion.
_shift-select-extend() {
  if (( ! REGION_ACTIVE )); then
    zle .set-mark-command
    zle -K shift-select
    _shift-select-flag 1
  fi
  zle $1
}
for widget target in \
  select-backward-char  .backward-char \
  select-forward-char   .forward-char \
  select-backward-word  .backward-word \
  select-forward-word   .forward-word \
  select-line-start     .beginning-of-line \
  select-line-end       .end-of-line \
  select-up-line        .up-line \
  select-down-line      .down-line \
  select-buffer-start   buffer-start \
  select-buffer-end     buffer-end
do
  eval "_$widget() { _shift-select-extend $target }"
  zle -N $widget _$widget
done

# Bound in both keymaps: first press comes from main, later ones from shift-select.
for keymap in main shift-select; do
  bindkey -M $keymap '^[[1;2D' select-backward-char  # Shift+Left
  bindkey -M $keymap '^[[1;2C' select-forward-char   # Shift+Right
  bindkey -M $keymap '^[[1;6D' select-backward-word  # Ctrl+Shift+Left
  bindkey -M $keymap '^[[1;6C' select-forward-word   # Ctrl+Shift+Right
  bindkey -M $keymap '^[[1;2H' select-line-start     # Shift+Home
  bindkey -M $keymap '^[[1;2F' select-line-end       # Shift+End
  bindkey -M $keymap '^[[1;2A' select-up-line        # Shift+Up
  bindkey -M $keymap '^[[1;2B' select-down-line      # Shift+Down
  bindkey -M $keymap '^[[1;6H' select-buffer-start   # Ctrl+Shift+Home
  bindkey -M $keymap '^[[1;6F' select-buffer-end     # Ctrl+Shift+End
done
