source ~/powerlevel10k/powerlevel10k.zsh-theme

### Auto Install ###
### Added by Zinit's installer
if [[ ! -f $HOME/.local/share/zinit/zinit.git/zinit.zsh ]]; then
    print -P "%F{33} %F{220}Installing %F{33}ZDHARMA-CONTINUUM%F{220} Initiative Plugin Manager (%F{33}zdharma-continuum/zinit%F{220})…%f"
    command mkdir -p "$HOME/.local/share/zinit" && command chmod g-rwX "$HOME/.local/share/zinit"
    command git clone https://github.com/zdharma-continuum/zinit "$HOME/.local/share/zinit/zinit.git" && \
        print -P "%F{33} %F{34}Installation successful.%f%b" || \
        print -P "%F{160} The clone has failed.%f%b"
fi

source "$HOME/.local/share/zinit/zinit.git/zinit.zsh"
autoload -Uz _zinit
(( ${+_comps} )) && _comps[zinit]=_zinit

# Load a few important annexes, without Turbo
# (this is currently required for annexes)
zinit light-mode for \
    zdharma-continuum/zinit-annex-as-monitor \
    zdharma-continuum/zinit-annex-bin-gem-node \
    zdharma-continuum/zinit-annex-patch-dl \
    zdharma-continuum/zinit-annex-rust

### End of Zinit's installer chunk

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# Add deno completions to search path
if [[ ":$FPATH:" != *":/Users/kenta/.zsh/completions:"* ]]; then export FPATH="/Users/kenta/.zsh/completions:$FPATH"; fi
export PATH=$PATH:/opt/homebrew/bin
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion
export PATH="$PATH:`pwd`/flutter/bin"
. "/Users/kenta/.deno/env"

### 便利設定 ###
## パスを入力してもcd
setopt AUTO_CD

## 履歴管理
HISTFILE=$ZDOTDIR/.zsh-history
HISTSIZE=100000
SAVEHIST=1000000

# 補完 COMPOLEMENT
## zsh-completions
zinit ice wait'0';zinit light zsh-users/zsh-completions
autoload -Uz compinit && compinit

## 小文字、大文字でもマッチさせる
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'

## 補完機能を一覧表示した時に、Tabや矢印で選択できるようにする
zstyle ':completion:*:default' menu select=1

# シンタックスハイライト
zinit ice wait'0';zinit light zsh-users/zsh-syntax-highlighting

# 履歴補完
zinit ice wait'0';zinit light zsh-users/zsh-autosuggestions
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=244"

# コマンド履歴検索
zinit ice wait'0';zinit light zdharma/history-search-multi-word

# alias
alias ll="ls -la --color=auto"
alias nv="nvim"
alias dc="docker compose"

# PATH settings
export PNPM_HOME="/Users/kenta/Library/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac
export PATH=~/.npm-global/bin:$PATH
export PATH="$HOME/.cargo/bin:$PATH"
export PATH="/opt/homebrew/opt/curl/bin:$PATH"
export PATH="$HOME/.local/bin:$PATH"

# load .zshrc.local
if [[ -f ~/.zshrc.local ]]; then
    source ~/.zshrc.local
fi

# Set working dir
cd ~