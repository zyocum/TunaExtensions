# Open Terminal Here

Open a folder in your terminal from Tuna. A file opens the folder that contains it.

Requires Tuna 0.108 or later.

## Actions

| Action | App | How the folder is passed |
| --- | --- | --- |
| **Open in Alacritty** | Alacritty | `alacritty msg create-window --working-directory`, or a new instance with `--working-directory` when no instance is listening |
| **Open in Ghostty** | Ghostty | Opens the folder with the app |
| **Open in iTerm2** | iTerm2 | Opens the folder with the app |
| **Open in kitty** | kitty | Opens the folder with the app |
| **Open in Terminal** | Terminal | Opens the folder with the app |
| **Open in Warp** | Warp | `warp://action/new_window?path=` |
| **Open in WezTerm** | WezTerm | `wezterm-gui start --cwd`, which reuses a running WezTerm |

Each action applies to:

- file and folder subjects, including Current Selection and items staged with **Stage in Tuna**;
- text that is an existing absolute path, a `~` path, or a `file:` URL.

Several subjects open one window per distinct folder. An action is hidden when its app is not
installed.

Whether the folder opens in a tab or a window follows each app's own settings, such as Ghostty's
`macos-dock-drop-behavior`. Terminal opens a new window.

## Privacy

The actions read only the subject's path, check that it exists, and hand the folder to the chosen
app. They need no permissions and make no network requests.
