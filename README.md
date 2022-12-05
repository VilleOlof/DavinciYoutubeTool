# Davinci YoutubeTool
Useful tool to download youtube videos, thumbnails and audio/songs, with a UI inside of davinci resolve.

Download Videos in high quality, you can also choose start & end points for the timeframe  
Download Audio Only In The Best Quality (requires ffmpeg)  
Download Thumbnails For Easy Use In Davinci Resolve  

**Will be updated to include things like:**  
- Resolution Options
- Audio Quality Options
- Stat field in TextEdit Instead of Label (so you can copy the data)

# Installation & Setup
Download newest release to get ffmpeg and youtube-dl included alongside the script .lua file.  
Could also clone the repo and download ffmpeg on its own since this script will download youtube-dl if not found.  

Place the .lua script (alongside ffmpeg & youtube-dl) in `%Appdata%\Roaming\Blackmagic Design\DaVinci Resolve\Support\Fusion\Scripts\Edit\`
Open the YoutubeTool.lua script and change `base_path` on line 13 to where you want files to be saved at.  

Open Davinci Resolve and look in `Workspace>Scripts>YoutubeTool` and it should give you a nice little UI.
