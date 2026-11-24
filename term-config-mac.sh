#!/bin/bash

# ─── Colors & Styles ──────────────────────────────────────────────────────────
RED='\033[0;31m';    BRED='\033[1;31m'
GREEN='\033[0;32m';  BGREEN='\033[1;32m'
YELLOW='\033[1;33m'; BYELLOW='\033[1;33m'
CYAN='\033[0;36m';   BCYAN='\033[1;36m'
BLUE='\033[0;34m';   BBLUE='\033[1;34m'
MAGENTA='\033[0;35m';BMAGENTA='\033[1;35m'
WHITE='\033[1;37m'
BOLD='\033[1m'
DIM='\033[2m'
ITALIC='\033[3m'
UNDER='\033[4m'
NC='\033[0m'

# ─── Helpers ──────────────────────────────────────────────────────────────────
info()    { echo -e "  ${BCYAN}◆${NC} ${WHITE}$1${NC}"; }
success() { echo -e "  ${BGREEN}✔${NC} ${GREEN}$1${NC}"; }
warn()    { echo -e "  ${BYELLOW}⚡${NC} ${YELLOW}$1${NC}"; }
error()   { echo -e "  ${BRED}✘${NC} ${RED}$1${NC}"; exit 1; }
dim()     { echo -e "  ${DIM}$1${NC}"; }

section() {
    echo ""
    echo -e "  ${BCYAN}╭─────────────────────────────────────────────────╮${NC}"
    printf  "  ${BCYAN}│${NC}  ${BOLD}%-47s${NC}${BCYAN}│${NC}\n" "$1"
    echo -e "  ${BCYAN}╰─────────────────────────────────────────────────╯${NC}"
    echo ""
}

# ─── Typewriter effect ────────────────────────────────────────────────────────
typewrite() {
    local text="$1"
    local delay="${2:-0.03}"
    printf "  "
    for (( i=0; i<${#text}; i++ )); do
        printf "%s" "${text:$i:1}"
        sleep "$delay"
    done
    echo ""
}

# ─── Progress Bar ─────────────────────────────────────────────────────────────
draw_progress() {
    local current=$1
    local total=$2
    local label="$3"
    local width=40
    local filled=$(( current * width / total ))
    local empty=$(( width - filled ))
    local pct=$(( current * 100 / total ))

    local bar="${BGREEN}"
    for (( i=0; i<filled; i++ )); do bar+="█"; done
    bar+="${DIM}"
    for (( i=0; i<empty; i++ )); do bar+="░"; done
    bar+="${NC}"

    printf "\r  ${bar}  ${BOLD}%3d%%${NC}  ${DIM}%s${NC}   " "$pct" "$label"
}

# ─── Fun rotating messages per task ──────────────────────────────────────────
# (macOS ships bash 3.2, which has no associative arrays — use a case lookup)
task_msgs() {
    case "$1" in
        zsh)      echo "Summoning the Z shell|Negotiating with Bash|Preparing a better shell|Installing your new home" ;;
        omz)      echo "Cloning the good stuff|Fetching themes & magic|Oh My… downloading Zsh|Setting up your framework" ;;
        plugins)  echo "Cloning syntax colors|Teaching zsh to predict|Making your shell smarter|Fish features incoming" ;;
        starship) echo "Reaching for the stars|Downloading rocket fuel|Warping to prompt paradise|Starship launching soon" ;;
        preset)   echo "Mixing Gruvbox colors|Painting your prompt|Loading the rainbow|Tuning your terminal style" ;;
        font)     echo "Forging glyphs|Pouring icons into fonts|Polishing ligatures|Nerding out" ;;
        shell)    echo "Asking chsh politely|Switching allegiances|Registering zsh as home|Making it official" ;;
        pkg)      echo "Talking to the server|Fetching formulae|Refreshing Homebrew|Syncing with the mothership" ;;
        brew)     echo "Pouring a fresh Homebrew|Fetching the brew kettle|Setting up /opt/homebrew|Brewing your package manager" ;;
        *)        echo "Working on it|Hang tight|Almost there|Stay with me" ;;
    esac
}

get_msgs() { IFS='|' read -ra MSGS <<< "$(task_msgs "$1")"; }

# ─── Animated Spinner with rotating messages & elapsed time ──────────────────
run_silent() {
    local label="$1"
    local msg_key="${2:-default}"; shift 2
    get_msgs "$msg_key"

    local frames=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
    local dots_frames=('·  ' '·· ' '···' ' ··' '  ·')
    local i=0 d=0 m=0
    local tmpout; tmpout=$(mktemp)
    local start_time; start_time=$(date +%s)

    "$@" >"$tmpout" 2>&1 &
    local pid=$!

    while kill -0 "$pid" 2>/dev/null; do
        local now; now=$(date +%s)
        local elapsed=$(( now - start_time ))
        local elapsed_str
        if (( elapsed < 60 )); then
            elapsed_str="${elapsed}s"
        else
            elapsed_str="$(( elapsed/60 ))m$(( elapsed%60 ))s"
        fi

        local msg="${MSGS[$m]}"
        local frame="${frames[$i]}"
        local dot="${dots_frames[$d]}"

        printf "\r  ${BCYAN}%s${NC}  ${DIM}%s${NC}${MAGENTA}%s${NC}  ${DIM}[%s]${NC}   " \
            "$frame" "$msg" "$dot" "$elapsed_str"

        i=$(( (i + 1) % ${#frames[@]} ))
        d=$(( (d + 1) % ${#dots_frames[@]} ))
        # Change message every ~2s (20 * 0.1)
        if (( (i % 20) == 0 )); then
            m=$(( (m + 1) % ${#MSGS[@]} ))
        fi
        sleep 0.1
    done

    wait "$pid"; local exit_code=$?
    local end_time; end_time=$(date +%s)
    local total=$(( end_time - start_time ))

    printf "\r%-80s\r" " "  # clear line

    if [ $exit_code -ne 0 ]; then
        echo -e "  ${BRED}✘${NC}  ${RED}${label}${NC} ${DIM}failed after ${total}s${NC}"
        echo -e "\n  ${DIM}┌─ Error Output ──────────────────────────────${NC}"
        while IFS= read -r line; do
            echo -e "  ${DIM}│${NC} $line"
        done < "$tmpout"
        echo -e "  ${DIM}└─────────────────────────────────────────────${NC}\n"
        rm -f "$tmpout"; exit 1
    fi

    rm -f "$tmpout"
    success "${label} ${DIM}(${total}s)${NC}"
}

# ─── Interactive Checkbox Menu ────────────────────────────────────────────────
checkbox_menu() {
    local title="$1"; shift
    local items=("$@")
    local count=${#items[@]}
    local cursor=0
    local checked=()

    for (( i=0; i<count; i++ )); do checked[$i]=1; done

    tput civis
    trap 'tput cnorm; tput rmcup' EXIT
    trap 'tput cnorm; tput rmcup; exit 130' INT TERM
    tput smcup
    tput clear

    print_banner() {
        echo -e "\n${BOLD}${BCYAN}"
        cat << 'BANNER'
  ████████╗███████╗██████╗ ███╗   ███╗ ██████╗ ██████╗ ███╗   ██╗███████╗██╗ ██████╗
     ██╔══╝██╔════╝██╔══██╗████╗ ████║██╔════╝██╔═══██╗████╗  ██║██╔════╝██║██╔════╝
     ██║   █████╗  ██████╔╝██╔████╔██║██║     ██║   ██║██╔██╗ ██║█████╗  ██║██║  ███╗
     ██║   ██╔══╝  ██╔══██╗██║╚██╔╝██║██║     ██║   ██║██║╚██╗██║██╔══╝  ██║██║   ██║
     ██║   ███████╗██║  ██║██║ ╚═╝ ██║╚██████╗╚██████╔╝██║ ╚████║██║     ██║╚██████╔╝
     ╚═╝   ╚══════╝╚═╝  ╚═╝╚═╝     ╚═╝ ╚═════╝ ╚═════╝ ╚═╝  ╚═══╝╚═╝     ╚═╝ ╚═════╝
BANNER
        echo -e "${NC}"
        echo -e "  ${DIM}          Terminal environment setup — zsh · Oh My Zsh · Starship${NC}"
        echo -e "  ${DIM}          ─────────────────────────────────────────────────────────${NC}\n"
    }

    draw_menu() {
        tput cup 12 0

        # Count selected
        local sel_count=0
        for (( i=0; i<count; i++ )); do
            [ "${checked[$i]}" -eq 1 ] && (( sel_count++ ))
        done

        echo -e "  ${BOLD}${WHITE}$title${NC}  ${DIM}(${sel_count}/${count} selected)${NC}"
        echo -e "  ${DIM}↑↓ navigate  ·  Space toggle  ·  A toggle all  ·  Enter confirm${NC}"
        echo ""

        for (( i=0; i<count; i++ )); do
            local checkbox
            if [ "${checked[$i]}" -eq 1 ]; then
                checkbox="${BGREEN}[✔]${NC}"
            else
                checkbox="${DIM}[  ]${NC}"
            fi

            if [ "$i" -eq "$cursor" ]; then
                echo -e "  ${BCYAN}▶${NC} $checkbox  ${BOLD}${WHITE}${items[$i]}${NC}"
            else
                echo -e "    $checkbox  ${DIM}${items[$i]}${NC}"
            fi
        done

        echo ""
        # Mini progress bar for selection
        local bar_w=30
        local filled=$(( sel_count * bar_w / count ))
        local bar_str="${BGREEN}"
        for (( b=0; b<filled; b++ )); do bar_str+="▪"; done
        bar_str+="${DIM}"
        for (( b=filled; b<bar_w; b++ )); do bar_str+="▫"; done
        bar_str+="${NC}"
        echo -e "  ${bar_str}  ${BCYAN}${sel_count}${NC}${DIM}/${count} ready to install${NC}"
    }

    print_banner
    draw_menu

    while true; do
        local key
        IFS= read -rsn1 key

        if [[ "$key" == $'\x1b' ]]; then
            # bash 3.2 only accepts whole-second timeouts
            IFS= read -rsn2 -t 1 key
            case "$key" in
                '[A') (( cursor > 0 )) && (( cursor-- )) ;;
                '[B') (( cursor < count - 1 )) && (( cursor++ )) ;;
            esac
        else
            case "$key" in
                ' ')
                    if [ "${checked[$cursor]}" -eq 1 ]; then
                        checked[$cursor]=0
                    else
                        checked[$cursor]=1
                    fi
                    ;;
                'a'|'A')
                    local all_on=1
                    for (( i=0; i<count; i++ )); do
                        [ "${checked[$i]}" -eq 0 ] && all_on=0
                    done
                    for (( i=0; i<count; i++ )); do
                        checked[$i]=$(( all_on ? 0 : 1 ))
                    done
                    ;;
                '') break ;;
            esac
        fi

        draw_menu
    done

    tput rmcup
    tput cnorm
    trap - EXIT INT TERM

    SELECTED_ITEMS=()
    for (( i=0; i<count; i++ )); do
        [ "${checked[$i]}" -eq 1 ] && SELECTED_ITEMS+=("$i")
    done
}

# ─── macOS / Homebrew helpers ─────────────────────────────────────────────────
[ "$(uname -s)" = "Darwin" ] || error "This script is for macOS. Use term-config-linux.sh on Linux, term-config-win.ps1 on Windows."

# Put brew on PATH for this script (Apple Silicon: /opt/homebrew, Intel: /usr/local)
load_brew_env() {
    local b
    for b in /opt/homebrew/bin/brew /usr/local/bin/brew; do
        if [ -x "$b" ]; then eval "$("$b" shellenv)"; return 0; fi
    done
    command -v brew >/dev/null 2>&1
}

# Make brew available in future zsh login shells
persist_brew_env() {
    local brew_bin; brew_bin="$(command -v brew)" || return 0
    local line="eval \"\$($brew_bin shellenv)\""
    touch "$HOME/.zprofile"
    if ! grep -qF "$brew_bin shellenv" "$HOME/.zprofile"; then
        printf '\n%s\n' "$line" >> "$HOME/.zprofile"
        success "Added Homebrew to ${BOLD}~/.zprofile${NC}"
    fi
}

# Ask for the sudo password once up front and keep it fresh in the background,
# so installers running behind the spinner never block on a hidden prompt.
SUDO_KEEPALIVE_PID=""
sudo_keepalive() {
    [ -n "$SUDO_KEEPALIVE_PID" ] && return 0
    info "Administrator password may be needed:"
    sudo -v || error "sudo authentication failed"
    ( while true; do sudo -n true 2>/dev/null; sleep 50; kill -0 "$$" 2>/dev/null || exit; done ) &
    SUDO_KEEPALIVE_PID=$!
    trap '[ -n "$SUDO_KEEPALIVE_PID" ] && kill "$SUDO_KEEPALIVE_PID" 2>/dev/null' EXIT
}

ensure_homebrew() {
    if load_brew_env; then
        info "Package manager: ${BOLD}Homebrew${NC} ${DIM}($(command -v brew))${NC}"
        return 0
    fi
    typewrite "Homebrew not found — installing the missing package manager for macOS..." 0.02
    sudo_keepalive
    run_silent "Installing Homebrew" "brew" \
        /bin/bash -c 'NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
    load_brew_env || error "Homebrew installation failed"
    persist_brew_env
    info "Package manager: ${BOLD}Homebrew${NC} ${DIM}($(command -v brew))${NC}"
}

# Portable in-place sed (BSD sed on macOS needs a backup suffix argument)
sed_inplace() {
    local expr="$1" file="$2"
    sed -i.termcon_tmp "$expr" "$file" && rm -f "${file}.termcon_tmp"
}

backup_zshrc() {
    if [ -f "$HOME/.zshrc" ]; then
        local backup="$HOME/.zshrc.bak.$(date +%Y%m%d_%H%M%S)"
        cp "$HOME/.zshrc" "$backup"
        info "Backed up .zshrc → ${DIM}$backup${NC}"
    fi
}

add_plugin() {
    local plugin=$1
    touch ~/.zshrc
    if grep -q "$plugin" ~/.zshrc; then
        warn "$plugin already in plugins list"
    elif grep -q "^plugins=(" ~/.zshrc; then
        sed_inplace "/^plugins=(/ s/)/ $plugin)/" ~/.zshrc
        success "Registered plugin: ${BOLD}$plugin${NC}"
    elif [ -d "$HOME/.oh-my-zsh" ]; then
        warn "No plugins=() line in .zshrc — add ${BOLD}$plugin${NC} manually"
    else
        warn "Oh My Zsh not installed — select it too so ${BOLD}$plugin${NC} gets loaded"
    fi
}

# ─── Task step announcement ───────────────────────────────────────────────────
announce_task() {
    local num="$1"
    local total="$2"
    local name="$3"
    echo ""
    echo -e "  ${BCYAN}┌──────────────────────────────────────────────────────┐${NC}"
    printf  "  ${BCYAN}│${NC}  ${BOLD}Task %s/%s${NC}  ${BCYAN}·${NC}  %-41s${BCYAN}│${NC}\n" "$num" "$total" "$name"
    echo -e "  ${BCYAN}└──────────────────────────────────────────────────────┘${NC}"
    echo ""
}

# ─── Track installed items for summary ───────────────────────────────────────
INSTALLED_ITEMS=()

# ══════════════════════════════════════════════════════════════════════════════
MENU_ITEMS=(
    "zsh                     — Z Shell (required base)"
    "Oh My Zsh               — zsh framework & theme manager"
    "zsh-syntax-highlighting — Fish-like syntax colors in terminal"
    "zsh-autosuggestions     — Fish-like command suggestions"
    "Starship                — Cross-shell prompt (gruvbox-rainbow)"
    "JetBrainsMono Nerd Font — icons for the Starship prompt"
    "Set zsh as default shell"
)

checkbox_menu "Select components to install:" "${MENU_ITEMS[@]}"

INSTALL_ZSH=0; INSTALL_OMZ=0; INSTALL_PLUGINS=0
INSTALL_STARSHIP=0; INSTALL_FONT=0; SET_DEFAULT_SHELL=0

for idx in "${SELECTED_ITEMS[@]}"; do
    case $idx in
        0) INSTALL_ZSH=1 ;;
        1) INSTALL_OMZ=1 ;;
        2|3) INSTALL_PLUGINS=1 ;;
        4) INSTALL_STARSHIP=1 ;;
        5) INSTALL_FONT=1 ;;
        6) SET_DEFAULT_SHELL=1 ;;
    esac
done

if [ ${#SELECTED_ITEMS[@]} -eq 0 ]; then
    echo -e "\n  ${BYELLOW}⚡${NC} Nothing selected. Exiting.\n"
    exit 0
fi

# ─── Count tasks for progress ─────────────────────────────────────────────────
TOTAL_TASKS=1  # env detection always runs
[ "$INSTALL_ZSH" -eq 1 ]         && (( TOTAL_TASKS++ ))
[ "$INSTALL_OMZ" -eq 1 ]         && (( TOTAL_TASKS++ ))
[ "$INSTALL_PLUGINS" -eq 1 ]     && (( TOTAL_TASKS++ ))
[ "$INSTALL_STARSHIP" -eq 1 ]    && (( TOTAL_TASKS += 2 ))
[ "$INSTALL_FONT" -eq 1 ]        && (( TOTAL_TASKS++ ))
[ "$SET_DEFAULT_SHELL" -eq 1 ]   && (( TOTAL_TASKS++ ))
CURRENT_TASK=0

# ─── Print Main Banner ────────────────────────────────────────────────────────
clear
echo -e "\n${BOLD}${BCYAN}"
cat << 'EOF'
  ████████╗███████╗██████╗ ███╗   ███╗ ██████╗ ██████╗ ███╗   ██╗███████╗██╗ ██████╗
     ██╔══╝██╔════╝██╔══██╗████╗ ████║██╔════╝██╔═══██╗████╗  ██║██╔════╝██║██╔════╝
     ██║   █████╗  ██████╔╝██╔████╔██║██║     ██║   ██║██╔██╗ ██║█████╗  ██║██║  ███╗
     ██║   ██╔══╝  ██╔══██╗██║╚██╔╝██║██║     ██║   ██║██║╚██╗██║██╔══╝  ██║██║   ██║
     ██║   ███████╗██║  ██║██║ ╚═╝ ██║╚██████╗╚██████╔╝██║ ╚████║██║     ██║╚██████╔╝
     ╚═╝   ╚══════╝╚═╝  ╚═╝╚═╝     ╚═╝ ╚═════╝ ╚═════╝ ╚═╝  ╚═══╝╚═╝     ╚═╝ ╚═════╝
EOF
echo -e "${NC}"
echo -e "  ${DIM}Terminal environment setup — zsh · Oh My Zsh · Starship${NC}"
echo -e "  ${DIM}─────────────────────────────────────────────────────────${NC}"
echo ""
echo -e "  ${BCYAN}▸${NC} ${BOLD}${TOTAL_TASKS} tasks${NC} queued  ${DIM}·  let's gooo${NC}"
echo ""

# ─── Overall progress header ──────────────────────────────────────────────────
print_overall() {
    draw_progress "$CURRENT_TASK" "$TOTAL_TASKS" "Overall progress"
    echo ""
}

# ─── Task 0: Detect Environment ───────────────────────────────────────────────
(( CURRENT_TASK++ ))
announce_task "$CURRENT_TASK" "$TOTAL_TASKS" "Detecting Environment"
print_overall

info "macOS $(sw_vers -productVersion) on $(uname -m)"

# git/curl come from the Xcode Command Line Tools
if ! xcode-select -p >/dev/null 2>&1 && ! command -v brew >/dev/null 2>&1 \
   && [ ! -x /opt/homebrew/bin/brew ] && [ ! -x /usr/local/bin/brew ]; then
    info "Xcode Command Line Tools will be installed along with Homebrew"
fi

NEED_BREW=0
{ [ "$INSTALL_ZSH" -eq 1 ] || [ "$INSTALL_STARSHIP" -eq 1 ] || [ "$INSTALL_FONT" -eq 1 ]; } && NEED_BREW=1
if [ "$NEED_BREW" -eq 1 ]; then
    ensure_homebrew
    run_silent "Refreshing Homebrew" "pkg" brew update
else
    load_brew_env >/dev/null 2>&1 || true
fi

if ! command -v git >/dev/null 2>&1 || ! git --version >/dev/null 2>&1; then
    error "git is unavailable. Run ${BOLD}xcode-select --install${NC}${RED}, then re-run this script."
fi

# ─── Task 1: zsh ──────────────────────────────────────────────────────────────
if [ "$INSTALL_ZSH" -eq 1 ]; then
    (( CURRENT_TASK++ ))
    announce_task "$CURRENT_TASK" "$TOTAL_TASKS" "Installing zsh"
    print_overall
    typewrite "The Z shell — more powerful, more fun." 0.025

    # macOS ships /bin/zsh; we install Homebrew's newer zsh alongside it
    if brew list --formula zsh >/dev/null 2>&1; then
        warn "Homebrew zsh is already installed — skipping"
        INSTALLED_ITEMS+=("zsh ${DIM}(already present)${NC}")
    else
        run_silent "Installing zsh (Homebrew)" "zsh" brew install zsh
        [ -x "$(brew --prefix)/bin/zsh" ] || error "zsh installation failed"
        INSTALLED_ITEMS+=("zsh $("$(brew --prefix)/bin/zsh" --version | awk '{print $2}') ${GREEN}✔${NC}")
    fi
fi

# ─── Task 2: Oh My Zsh ────────────────────────────────────────────────────────
if [ "$INSTALL_OMZ" -eq 1 ]; then
    (( CURRENT_TASK++ ))
    announce_task "$CURRENT_TASK" "$TOTAL_TASKS" "Installing Oh My Zsh"
    print_overall
    typewrite "Themes. Plugins. 2000+ contributors. Here we go." 0.025

    if [ -d "$HOME/.oh-my-zsh" ]; then
        warn "Oh My Zsh is already installed — skipping"
        INSTALLED_ITEMS+=("Oh My Zsh ${DIM}(already present)${NC}")
    else
        run_silent "Installing Oh My Zsh" "omz" \
            sh -c 'RUNZSH=no CHSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" --unattended < /dev/null'
        [ -d "$HOME/.oh-my-zsh" ] || error "Oh My Zsh installation failed"
        INSTALLED_ITEMS+=("Oh My Zsh ${GREEN}✔${NC}")
    fi
fi

# ─── Task 3: Plugins ──────────────────────────────────────────────────────────
if [ "$INSTALL_PLUGINS" -eq 1 ]; then
    (( CURRENT_TASK++ ))
    announce_task "$CURRENT_TASK" "$TOTAL_TASKS" "Installing Oh My Zsh Plugins"
    print_overall
    typewrite "Fish-style superpowers, coming right up..." 0.025

    ZSH_CUSTOM=${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}
    backup_zshrc

    if [ -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ]; then
        warn "zsh-syntax-highlighting already installed"
        INSTALLED_ITEMS+=("zsh-syntax-highlighting ${DIM}(already present)${NC}")
    else
        run_silent "Cloning zsh-syntax-highlighting" "plugins" \
            git clone https://github.com/zsh-users/zsh-syntax-highlighting.git \
            "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"
        INSTALLED_ITEMS+=("zsh-syntax-highlighting ${GREEN}✔${NC}")
    fi
    add_plugin "zsh-syntax-highlighting"

    if [ -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]; then
        warn "zsh-autosuggestions already installed"
        INSTALLED_ITEMS+=("zsh-autosuggestions ${DIM}(already present)${NC}")
    else
        run_silent "Cloning zsh-autosuggestions" "plugins" \
            git clone https://github.com/zsh-users/zsh-autosuggestions \
            "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
        INSTALLED_ITEMS+=("zsh-autosuggestions ${GREEN}✔${NC}")
    fi
    add_plugin "zsh-autosuggestions"
fi

# ─── Task 4 & 5: Starship ─────────────────────────────────────────────────────
if [ "$INSTALL_STARSHIP" -eq 1 ]; then
    (( CURRENT_TASK++ ))
    announce_task "$CURRENT_TASK" "$TOTAL_TASKS" "Installing Starship Prompt"
    print_overall
    typewrite "Blazing-fast. Infinitely configurable. Zero compromise." 0.025

    if command -v starship >/dev/null 2>&1; then
        warn "Starship is already installed — skipping"
        INSTALLED_ITEMS+=("Starship ${DIM}(already present)${NC}")
    else
        run_silent "Installing Starship" "starship" brew install starship
        command -v starship >/dev/null 2>&1 || error "Starship installation failed"
        INSTALLED_ITEMS+=("Starship ${GREEN}✔${NC}")
    fi

    touch ~/.zshrc
    if ! grep -q "starship init zsh" ~/.zshrc; then
        echo 'eval "$(starship init zsh)"' >> ~/.zshrc
        success "Starship init injected into .zshrc"
    else
        warn "Starship init already in .zshrc"
    fi

    (( CURRENT_TASK++ ))
    announce_task "$CURRENT_TASK" "$TOTAL_TASKS" "Applying gruvbox-rainbow Preset"
    print_overall
    typewrite "Warm earth tones meet electric neon. Your prompt will glow." 0.025

    mkdir -p "$HOME/.config"
    run_silent "Applying gruvbox-rainbow preset" "preset" \
        starship preset gruvbox-rainbow -o "$HOME/.config/starship.toml"
    INSTALLED_ITEMS+=("gruvbox-rainbow preset ${GREEN}✔${NC}")
fi

# ─── Task: Nerd Font ──────────────────────────────────────────────────────────
if [ "$INSTALL_FONT" -eq 1 ]; then
    (( CURRENT_TASK++ ))
    announce_task "$CURRENT_TASK" "$TOTAL_TASKS" "Installing JetBrainsMono Nerd Font"
    print_overall
    typewrite "Starship's icons need a Nerd Font to render properly." 0.025

    if brew list --cask font-jetbrains-mono-nerd-font >/dev/null 2>&1; then
        warn "JetBrainsMono Nerd Font is already installed — skipping"
        INSTALLED_ITEMS+=("JetBrainsMono Nerd Font ${DIM}(already present)${NC}")
    else
        run_silent "Installing JetBrainsMono Nerd Font" "font" \
            brew install --cask font-jetbrains-mono-nerd-font
        INSTALLED_ITEMS+=("JetBrainsMono Nerd Font ${GREEN}✔${NC}")
    fi
    dim "Select it in Terminal → Settings → Profiles → Text → Font (or iTerm2 → Profiles → Text)"
fi

# ─── Task: Default Shell ──────────────────────────────────────────────────────
if [ "$SET_DEFAULT_SHELL" -eq 1 ]; then
    (( CURRENT_TASK++ ))
    announce_task "$CURRENT_TASK" "$TOTAL_TASKS" "Setting zsh as Default Shell"
    print_overall
    typewrite "Making zsh your one and only..." 0.025

    # Prefer Homebrew's zsh if it was installed, otherwise the system /bin/zsh
    if command -v brew >/dev/null 2>&1 && [ -x "$(brew --prefix)/bin/zsh" ]; then
        ZSH_PATH="$(brew --prefix)/bin/zsh"
    else
        ZSH_PATH="/bin/zsh"
    fi

    # macOS keeps the login shell in Directory Services, not just $SHELL
    CURRENT_SHELL="$(dscl . -read "/Users/$USER" UserShell 2>/dev/null | awk '{print $2}')"
    [ -n "$CURRENT_SHELL" ] || CURRENT_SHELL="$SHELL"

    if [ "$CURRENT_SHELL" = "$ZSH_PATH" ]; then
        warn "zsh ($ZSH_PATH) is already your default shell"
        INSTALLED_ITEMS+=("Default shell ${DIM}(already zsh)${NC}")
    else
        # chsh refuses shells not listed in /etc/shells (Homebrew's zsh isn't by default)
        if ! grep -qxF "$ZSH_PATH" /etc/shells; then
            info "Adding ${BOLD}$ZSH_PATH${NC} to /etc/shells (needs sudo)"
            echo "$ZSH_PATH" | sudo tee -a /etc/shells >/dev/null || error "Could not update /etc/shells"
        fi
        info "chsh may ask for your login password:"
        if chsh -s "$ZSH_PATH"; then
            success "Default shell → ${BOLD}$ZSH_PATH${NC}"
            INSTALLED_ITEMS+=("Default shell → zsh ${GREEN}✔${NC}")
        else
            warn "chsh failed. Run manually: ${BOLD}chsh -s $ZSH_PATH${NC}"
        fi
    fi
fi

# ─── Final Overall Progress (100%) ───────────────────────────────────────────
draw_progress "$TOTAL_TASKS" "$TOTAL_TASKS" "All tasks complete"
echo -e "\n"

# ─── Completion Summary ───────────────────────────────────────────────────────
echo -e "  ${BGREEN}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "  ${BGREEN}║${NC}                                                      ${BGREEN}║${NC}"
echo -e "  ${BGREEN}║${NC}   ${BOLD}${WHITE}  ✔  Setup Complete!${NC}                                ${BGREEN}║${NC}"
echo -e "  ${BGREEN}║${NC}                                                      ${BGREEN}║${NC}"
echo -e "  ${BGREEN}╠══════════════════════════════════════════════════════╣${NC}"
echo -e "  ${BGREEN}║${NC}  ${BOLD}Installed / Verified:${NC}                                ${BGREEN}║${NC}"
echo ""

for item in "${INSTALLED_ITEMS[@]}"; do
    printf "  ${BGREEN}║${NC}    ${BCYAN}▸${NC}  %-48b${BGREEN}║${NC}\n" "$item"
done

echo ""
echo -e "  ${BGREEN}╠══════════════════════════════════════════════════════╣${NC}"
echo -e "  ${BGREEN}║${NC}  ${BOLD}Next step:${NC}  ${ITALIC}Restart your terminal or run:${NC}           ${BGREEN}║${NC}"
echo -e "  ${BGREEN}║${NC}  ${BCYAN}  \$  ${NC}${BOLD}source ~/.zshrc${NC}                                  ${BGREEN}║${NC}"
echo -e "  ${BGREEN}║${NC}                                                      ${BGREEN}║${NC}"
echo -e "  ${BGREEN}╚══════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  ${DIM}Enjoy your new terminal. You earned it. 🚀${NC}"
echo ""