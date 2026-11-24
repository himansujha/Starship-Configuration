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
declare -A TASK_MSGS
TASK_MSGS[zsh]="Summoning the Z shell|Negotiating with Bash|Preparing a better shell|Installing your new home"
TASK_MSGS[omz]="Cloning the good stuff|Fetching themes & magic|Oh My… downloading Zsh|Setting up your framework"
TASK_MSGS[plugins]="Cloning syntax colors|Teaching zsh to predict|Making your shell smarter|Fish features incoming"
TASK_MSGS[starship]="Reaching for the stars|Downloading rocket fuel|Warping to prompt paradise|Starship launching soon"
TASK_MSGS[preset]="Mixing Gruvbox colors|Painting your prompt|Loading the rainbow|Tuning your terminal style"
TASK_MSGS[shell]="Asking chsh politely|Switching allegiances|Registering zsh as home|Making it official"
TASK_MSGS[pkg]="Talking to the server|Fetching package lists|Refreshing repositories|Syncing with the mothership"
TASK_MSGS[nala]="Finding a better apt|Bootstrapping nala|Upgrading your frontend|Preparing nala installer"

get_msgs() { IFS='|' read -ra MSGS <<< "${TASK_MSGS[$1]:-"Working on it|Hang tight|Almost there|Stay with me"}"; }

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
    trap 'tput cnorm; tput rmcup' EXIT INT TERM
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
        tput cup 10 0

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
            IFS= read -rsn2 -t 0.1 key
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

# ─── Detect Package Manager ───────────────────────────────────────────────────
detect_pkg_manager() {
    if   command -v nala   >/dev/null 2>&1; then PKG_MGR="nala";   PKG_UPDATE="sudo nala update";           PKG_INSTALL="sudo nala install -y"
    elif command -v apt    >/dev/null 2>&1; then PKG_MGR="apt";    PKG_UPDATE="sudo apt-get update";         PKG_INSTALL="sudo apt-get install -y"
    elif command -v dnf    >/dev/null 2>&1; then PKG_MGR="dnf";    PKG_UPDATE="sudo dnf check-update";       PKG_INSTALL="sudo dnf install -y"
    elif command -v pacman >/dev/null 2>&1; then PKG_MGR="pacman"; PKG_UPDATE="sudo pacman -Sy --noconfirm"; PKG_INSTALL="sudo pacman -S --noconfirm"
    elif command -v zypper >/dev/null 2>&1; then PKG_MGR="zypper"; PKG_UPDATE="sudo zypper refresh";         PKG_INSTALL="sudo zypper install -y"
    else error "No supported package manager found (apt, dnf, pacman, zypper)."; fi
    info "Package manager: ${BOLD}$PKG_MGR${NC}"
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
    if ! grep -q "$plugin" ~/.zshrc; then
        sed -i "/^plugins=/ s/)/ $plugin)/" ~/.zshrc
        success "Registered plugin: ${BOLD}$plugin${NC}"
    else
        warn "$plugin already in plugins list"
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
    "Set zsh as default shell"
)

checkbox_menu "Select components to install:" "${MENU_ITEMS[@]}"

INSTALL_ZSH=0; INSTALL_OMZ=0; INSTALL_PLUGINS=0
INSTALL_STARSHIP=0; SET_DEFAULT_SHELL=0

for idx in "${SELECTED_ITEMS[@]}"; do
    case $idx in
        0) INSTALL_ZSH=1 ;;
        1) INSTALL_OMZ=1 ;;
        2|3) INSTALL_PLUGINS=1 ;;
        4) INSTALL_STARSHIP=1 ;;
        5) SET_DEFAULT_SHELL=1 ;;
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

if command -v apt >/dev/null 2>&1 && ! command -v nala >/dev/null 2>&1; then
    typewrite "Bootstrapping nala — a friendlier apt frontend..." 0.02
    run_silent "Installing nala" "nala" bash -c "sudo apt-get update -qq && sudo apt-get install -y nala -qq"
fi

detect_pkg_manager

if [ "$PKG_MGR" = "dnf" ]; then
    info "Refreshing package database..."
    sudo dnf check-update >/dev/null 2>&1 || true
    success "Package database refreshed"
else
    run_silent "Refreshing package database" "pkg" $PKG_UPDATE
fi

# ─── Task 1: zsh ──────────────────────────────────────────────────────────────
if [ "$INSTALL_ZSH" -eq 1 ]; then
    (( CURRENT_TASK++ ))
    announce_task "$CURRENT_TASK" "$TOTAL_TASKS" "Installing zsh"
    print_overall
    typewrite "The Z shell — more powerful, more fun." 0.025

    if command -v zsh >/dev/null 2>&1; then
        warn "zsh is already installed — skipping"
        INSTALLED_ITEMS+=("zsh ${DIM}(already present)${NC}")
    else
        run_silent "Installing zsh" "zsh" $PKG_INSTALL zsh
        command -v zsh >/dev/null 2>&1 || error "zsh installation failed"
        INSTALLED_ITEMS+=("zsh ${GREEN}✔${NC}")
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
        run_silent "Installing Starship" "starship" \
            sh -c 'curl -fsSL https://starship.rs/install.sh | sh -s -- --yes'
        command -v starship >/dev/null 2>&1 || error "Starship installation failed"
        INSTALLED_ITEMS+=("Starship ${GREEN}✔${NC}")
    fi

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

# ─── Task 6: Default Shell ────────────────────────────────────────────────────
if [ "$SET_DEFAULT_SHELL" -eq 1 ]; then
    (( CURRENT_TASK++ ))
    announce_task "$CURRENT_TASK" "$TOTAL_TASKS" "Setting zsh as Default Shell"
    print_overall
    typewrite "Making zsh your one and only..." 0.025

    ZSH_PATH="$(which zsh)"
    if [ "$SHELL" = "$ZSH_PATH" ]; then
        warn "zsh is already your default shell"
        INSTALLED_ITEMS+=("Default shell ${DIM}(already zsh)${NC}")
    elif command -v chsh >/dev/null 2>&1; then
        chsh -s "$ZSH_PATH"
        success "Default shell → ${BOLD}$ZSH_PATH${NC}"
        INSTALLED_ITEMS+=("Default shell → zsh ${GREEN}✔${NC}")
    else
        warn "chsh not available. Run manually: ${BOLD}chsh -s $ZSH_PATH${NC}"
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