# ani-cli-wrapper
# ani-cli-wrapper 🎬

A powerful, user-friendly wrapper for [ani-cli](https://github.com/pystardust/ani-cli) with an interactive fzf-based menu system, AniList integration, and DUB/SUB fallback support.

![ani-cli-wrapper Demo](https://via.placeholder.com/800x400.png?text=ani-cli-wrapper+Demo)

## ✨ Features

### 🎯 Core Features
- **🔍 Smart Search** - Search anime with language preference (DUB/SUB)
- **📺 Continue Watching** - Resume from where you left off with episode selection
- **📥 Download Manager** - Batch downloads with episode range support
- **📚 Personal Library** - Watchlist with language memory
- **⚙️ Persistent Settings** - Your preferences saved between sessions

### 🚀 Advanced Features
- **🎨 AniList Discovery** - Browse trending, popular, top-rated, seasonal, and upcoming anime
- **🔄 Auto Fallback** - Automatically try SUB if DUB fails
- **🖼️ Anime Posters** - ASCII art posters (requires `chafa`)
- **📊 History Statistics** - Track your watching habits
- **🔍 Smart Search** - Uses Romaji for better compatibility with ani-cli

## 📋 Requirements

### Essential
- `ani-cli` - [Install from here](https://github.com/pystardust/ani-cli)
- `fzf` - Fuzzy finder for menus
- `curl` - For API requests
- `jq` - JSON processing (recommended)

### Optional (for enhanced features)
- `chafa` - For ASCII art posters
- `mpv` or `vlc` - Video players

### Installation Commands by OS

```bash
# Ubuntu/Debian
sudo apt install fzf curl jq chafa mpv

# Arch Linux
sudo pacman -S fzf curl jq chafa mpv

# macOS
brew install fzf curl jq chafa mpv

# Termux (Android)
pkg install fzf curl jq mpv
```

## 🚀 Installation

### Method 1: Direct Download
```bash
# Download the script
curl -O https://raw.githubusercontent.com/yourusername/ani-cli-wrapper/main/ani-wrapper.sh

# Make it executable
chmod +x ani-wrapper.sh

# Move to PATH (optional)
sudo mv ani-wrapper.sh /usr/local/bin/ani-wrapper
```

### Method 2: Git Clone
```bash
git clone https://github.com/yourusername/ani-cli-wrapper.git
cd ani-cli-wrapper
chmod +x ani-wrapper.sh
./ani-wrapper.sh
```

## 🎮 Usage

### Basic Usage
```bash
./ani-wrapper.sh
```

### Command Line Options
```bash
ani-wrapper --help        # Show help
ani-wrapper --version     # Show version
ani-wrapper --debug       # Run in debug mode
ani-wrapper -s "One Piece" # Quick search
ani-wrapper -d "Jujutsu Kaisen" # Quick download
```

### Main Menu

```
╔══════════════════════════════════════════════╗
║         ani-cli-wrapper v2.3.0               ║
║     Your friendly anime terminal companion   ║
║         with AniList Discovery! 🎯           ║
╚══════════════════════════════════════════════╝

1. 🔍 Search and Watch Anime
2. 📺 Discover Anime (AniList)
3. 📥 Download Anime
4. ⚙️  Settings
5. 📚 My Library/Watchlist
6. 🔄 Check for Updates
7. ❓ Help
8. 🚪 Exit
```

## 📖 Detailed Features

### 1. 🔍 Search and Watch Anime
- Choose language preference (DUB/SUB) before searching
- Recent searches saved for quick access
- ASCII art poster display (if chafa installed)
- Auto-fallback to SUB if DUB fails

### 2. 📺 Discover Anime (AniList)
Browse and select from curated lists:
- **🔥 Trending Now** - Most popular this week
- **⭐ Most Popular** - All-time popular anime
- **🏆 Top Rated** - Highest scored anime
- **🌸 Current Season** - Airing this season
- **🚀 Upcoming** - Soon to be released

Each selection shows:
- Title (English/Romaji)
- Episode count
- Duration
- Status
- Season & Year
- Score
- Genres
- Description preview

### 3. 📥 Download Anime
- Select language (DUB/SUB)
- Choose episodes:
  - Interactive selection
  - Single episode
  - Range (e.g., 1-12)
  - All episodes
- Auto-fallback for failed downloads

### 4. ⚙️ Settings
```
🎬 Quality (current: 1080p)
🎮 Player (current: mpv)
🔤 Default Language (current: dub)
🎯 Dub by Default (current: false)
🔄 Auto Fallback to SUB (current: true)
📁 Download Directory (current: ~/Videos/ani-cli)
💾 Save History (current: true)
🔄 Auto Update (current: false)
⏭️ Skip Intro (current: false)
🗑️ Clear Cache/History
```

### 5. 📚 My Library/Watchlist
- View/watch from watchlist
- Add anime with language preference
- Remove from watchlist
- Language memory (remembers if you added as DUB/SUB)

### 6. 📊 History Statistics
- Total entries count
- Unique anime count
- Total episodes watched
- Most watched anime
- Search through history
- Clear history option

## 🎨 Keyboard Shortcuts

In fzf menus:
| Key | Action |
|-----|--------|
| `Type` | Filter/search |
| `Ctrl+n` / `Ctrl+p` | Navigate up/down |
| `Enter` | Select |
| `Esc` / `Ctrl+c` | Cancel |
| `Tab` | Multi-select |
| `?` | Toggle preview |

## 🔧 Configuration

Config file location: `~/.config/ani-cli-wrapper/config`

```bash
# ani-cli-wrapper Configuration File
QUALITY="1080p"
PLAYER="mpv"
LANGUAGE="dub"
DUB_SEARCH=false
DOWNLOAD_DIR="${HOME}/Videos/ani-cli"
SAVE_HISTORY=true
AUTO_UPDATE=false
SKIP_INTRO=false
RECENT_SEARCHES=5
AUTO_FALLBACK=true
```

## 📁 Directory Structure

```
~/.config/ani-cli-wrapper/
├── config                 # Configuration file
├── cache/                 # Cache directory
│   ├── posters/          # ASCII art posters
│   ├── anilist/          # AniList API cache
│   └── recent_searches    # Recent search history
├── watchlist             # Your personal watchlist
└── ani-wrapper.log       # Log file
```

## 🐛 Troubleshooting

### Common Issues

**Q: AniList discovery shows no results?**
A: Install jq: `sudo apt install jq` (Ubuntu) or `brew install jq` (macOS)

**Q: Posters not showing?**
A: Install chafa: `sudo apt install chafa`

**Q: Single quotes in titles causing errors?**
A: Use Romaji titles (e.g., "Hells Paradise" instead of "Hell's Paradise")

**Q: DUB fallback not working?**
A: Enable in Settings: "Auto Fallback to SUB"

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📝 License

This project is licensed under the GNU General Public License v3.0 - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- [ani-cli](https://github.com/pystardust/ani-cli) - The amazing CLI anime viewer
- [AniList](https://anilist.co/) - For the fantastic API
- [fzf](https://github.com/junegunn/fzf) - The incredible fuzzy finder
- [chafa](https://hpjansson.org/chafa/) - For image to ASCII conversion

## 📞 Contact & Support

- **GitHub Issues**: [Report a bug](https://github.com/yourusername/ani-cli-wrapper/issues)
- **Discussions**: [Join the conversation](https://github.com/yourusername/ani-cli-wrapper/discussions)

## 🎉 Star History

[![Star History Chart](https://api.star-history.com/svg?repos=yourusername/ani-cli-wrapper&type=Date)](https://star-history.com/#yourusername/ani-cli-wrapper&Date)

---

**Made with ❤️ for the anime community**
