<!-- MANPAGE: END EXCLUDED SECTION -->
# YT dlp gui AHK v2

## overview

yt-dlp is a feature-rich command-line audio/video downloader with support for [thousands of sites](https://github.com/yt-dlp/yt-dlp/blob/master/supportedsites.md). The project is a fork of [youtube-dl](https://github.com/ytdl-org/youtube-dl) based on the now inactive [youtube-dlc](https://github.com/blackjack4494/yt-dlc).

yt dlp GUI is an AHK script because having a GUI is good enough plus you dont want double click a TKINTER python file that it just open VSCODE instead, and giggles. It support automatically install ytdlp.exe if not found. BUT you can also choose your own yt-dlp.exe path if you want to use preexisting one.
> unfortunately for absolutely no reason some repo of GUI yt downloader has exception for some reason. So i made this one , ask CHATGPT, GEMINI3pro if you need customization because WHY NOT?

## TODO

- i am planning to add a feature to use preexisting yt-dlp if it is not exist in the same folder of the GUI. Add also the box: PATH to yt-dlp.exe and a button: use the latest version (when user click here, it will execute download and will set the path of yt-dlp to the same folder as the GUI ).
- i am planning to add playlist support but IDK if it is even working.
