# ani-cli-wrapper 🎬

A powerful, user-friendly wrapper for [ani-cli](https://github.com/pystardust/ani-cli) with an interactive fzf-based menu system, AniList integration, and DUB/SUB fallback support.

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
- **🔍 Smart Search** - Uses Romaji for better compatibility with ani-cli

## 📋 Requirements

### Essential

- `ani-cli` - [Install from here](https://github.com/pystardust/ani-cli)
- `fzf` - Fuzzy finder for menus
- `curl` - For API requests
- `jq` - JSON processing (recommended)

### Optional (for enhanced features)

- `ani-skip` - For auto-skiping intro

## 🚀 Installation

### Method 1: Direct Download

```bash
# Download the script
curl -O https://raw.githubusercontent.com/scarletdragon9632/ani-cli-wrapper/main/ani-wrapper.sh

# Make it executable
chmod +x ani-wrapper.sh

# Move to PATH (optional)
sudo mv ani-wrapper.sh /usr/local/bin/ani-wrapper
```

### Method 2: Git Clone

```bash
git clone https://github.com/scarletdragon9632/ani-cli-wrapper.git
cd ani-cli-wrapper
chmod +x ani-wrapper.sh
./ani-wrapper.sh
```

## 🎮 Usage

### Basic Usage

```bash
./ani-wrapper.sh
```

### Main Menu

```
╔══════════════════════════════════════════════╗
║         ani-cli-wrapper v2.3.0               ║
║     Your friendly anime terminal companion   ║
║         with AniList Discovery! 🎯           ║
╚══════════════════════════════════════════════╝

🔍 Search and Watch Anime
🎯 Continue Watching
📺 Discover Anime (AniList)
📥 Download Anime
⚙️ Settings
📚 My Library/Watchlist
🔄 Check for Updates
❓ Help
🚪 Exit
```

## 📖 Detailed Features

### 1. 🔍 Search and Watch Anime

- Choose language preference (DUB/SUB) before searching
- Recent searches saved for quick access
- Auto-fallback to SUB if DUB fails

### 2. 📺 Discover Anime (AniList)

Browse and select from curated lists:

- **🔥 Trending Now** - Most popular this week
- **⭐ Most Popular** - All-time popular anime
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

### 4. ⚙️ Settings

```
🎬 Quality (current: 1080p)
🎮 Player (current: mpv)
🔤 Default Language (current: dub)
🔄 Auto Fallback to SUB (current: true)
📁 Download Directory (current: ~/Videos/ani-cli)
📜 History File (current: .local/state/ani-cli/ani-hsts)
🔄 Auto Update (current: false)
⏭️ Skip Intro (current: false)
🎨 Header Art (select ASCII art)"
🗑️ Clear Cache/History
```

### 5. 📚 My Library/Watchlist

- View/watch from watchlist
- Add anime with language preference
- Remove from watchlist
- Language memory (remembers if you added as DUB/SUB)

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
HISTORY_FILE="${HOME}/.local/state/ani-cli/ani-hsts"
HEADER_COLOR="CYAN"
CURRENT_HEADER="default.txt"
```

## 📁 Directory Structure

```
~/.config/ani-cli-wrapper/
├── config                 # Configuration file
├── cache/                 # Cache directory
│   ├── anilist/          # AniList API cache
│   └── headers           # Header Ascii Art
│   └── recent_searches    # Recent search history
├── watchlist             # Your personal watchlist
└── ani-wrapper.log       # Log file
```

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

## 🎉 Star History

[![Star History Chart](https://api.star-history.com/svg?repos=scarletdragon9632/ani-cli-wrapper&type=Date)](https://star-history.com/#scarletdragon9632/ani-cli-wrapper&Date)

---

**Made with ❤️ for the anime community**
