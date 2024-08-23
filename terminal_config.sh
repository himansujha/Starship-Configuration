sudo apt update && sudo apt upgrade -y



#-----------------------------------STARSHIP INSTALLATION-----------------------------------------#

# Installing starship
echo Installing starship.........
curl -sS https://starship.rs/install.sh | sh

# Define the line to add
line='eval "$(starship init bash)"'

# Define the ~/.bashrc file
bashrc_file="$HOME/.bashrc"

# Check if the line is already in the ~/.bashrc file
if grep -Fxq "$line" "$bashrc_file"; then
    echo "Line is already present in $bashrc_file"
else
    # Append the line to ~/.bashrc
    echo "$line" >> "$bashrc_file"
    echo "Line added to $bashrc_file"
fi

# Define the directory path
DIR="$HOME/.config"

# Check if the directory exists
if [ -d "$DIR" ]; then
    echo "Directory $DIR already exists."
else
    # Create the directory
    mkdir -p "$DIR"
    echo "Directory $DIR has been created."
fi

# Run the Starship command to set the prompt configuration
echo "Setting up Starship configuration..."
starship preset gruvbox-rainbow -o "$HOME/.config/starship.toml"

# Confirm the action
echo "Starship configuration has been set up."