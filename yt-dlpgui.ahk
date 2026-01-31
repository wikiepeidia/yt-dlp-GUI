; ==============================================================================
; YT-DLP GUI WRAPPER (AHK v2)
; Native Windows GUI.
; Supports Custom yt-dlp path OR Auto-download.
; Real-time progress. Robust.
; ==============================================================================
#Requires AutoHotkey v2.0
#SingleInstance Force
SetWorkingDir(A_ScriptDir)

; ==============================================================================
; GLOBAL VARIABLES
; ==============================================================================
global YtDlpExeName := "yt-dlp.exe"
global YtDlpUrl := "https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp.exe"
global LogFile := A_Temp "\ytdlp_gui_log.txt"
global IniFile := A_ScriptDir "\settings.ini"
global PID := 0

; Variables to store active paths
global CurrentYtDlpPath := ""
global CurrentFFmpegPath := ""

; ==============================================================================
; STARTUP LOGIC
; ==============================================================================

; 1. Load Settings from INI
SavedYtDlp := IniRead(IniFile, "Settings", "YtDlpPath", "")
SavedOutDir := IniRead(IniFile, "Settings", "OutputDir", A_Desktop)
SavedFFmpeg := IniRead(IniFile, "Settings", "FFmpegPath", "")

; 2. Determine which yt-dlp to use
LocalYtDlp := A_ScriptDir "\" YtDlpExeName

if FileExist(LocalYtDlp) {
    ; Priority 1: If local file exists, prefer it (or use saved if valid)
    ; But if user explicitly saved a custom path that exists, use that.
    if (SavedYtDlp != "" && FileExist(SavedYtDlp))
        CurrentYtDlpPath := SavedYtDlp
    else
        CurrentYtDlpPath := LocalYtDlp
}
else if (SavedYtDlp != "" && FileExist(SavedYtDlp)) {
    ; Priority 2: Local missing, but saved custom path exists
    CurrentYtDlpPath := SavedYtDlp
}
else {
    ; Priority 3: Nothing found. Ask User.
    Result := MsgBox(
        "yt-dlp.exe was not found.`n`nClick 'Yes' to Download the latest version.`nClick 'No' to Browse for an existing file.",
        "Missing Component", "YesNo Icon!")

    if (Result = "Yes") {
        DownloadGui("Install")
        CurrentYtDlpPath := LocalYtDlp
    } else {
        SelectedFile := FileSelect(3, , "Select yt-dlp.exe", "Executables (*.exe)")
        if (SelectedFile != "") {
            CurrentYtDlpPath := SelectedFile
        } else {
            MsgBox("No yt-dlp selected. Exiting.", "Error", 16)
            ExitApp
        }
    }
}

; Double check we actually have a valid path now
if !FileExist(CurrentYtDlpPath) {
    MsgBox("Critical Error: yt-dlp path is invalid. Exiting.", "Error", 16)
    ExitApp
}

; ==============================================================================
; MAIN GUI CONSTRUCTION
; ==============================================================================
MyGui := Gui(, "yt-dlp GUI Wrapper")
MyGui.OnEvent("Close", GuiClose)
MyGui.SetFont("s9", "Segoe UI")

; --- Row 1: URL ---
MyGui.Add("Text", "xm y+10 w80", "URL:")
GuiUrl := MyGui.Add("Edit", "x+10 w350 vURL", "")

; --- Row 2: Output Directory ---
MyGui.Add("Text", "xm y+15 w80", "Save to:")
GuiDir := MyGui.Add("Edit", "x+10 w270 vOutputDir ReadOnly", SavedOutDir)
BtnDir := MyGui.Add("Button", "x+5 w75", "Browse...")
BtnDir.OnEvent("Click", SelectFolder)

; --- Row 3: yt-dlp Path (NEW) ---
MyGui.Add("Text", "xm y+30 w80", "yt-dlp Path:")
GuiYtDlp := MyGui.Add("Edit", "x+10 w200 vYtDlpPath ReadOnly", CurrentYtDlpPath)
BtnYtBrowse := MyGui.Add("Button", "x+5 w70", "Browse...")
BtnYtBrowse.OnEvent("Click", SelectYtDlp)
BtnYtReset := MyGui.Add("Button", "x+5 w70", "Use Local")
BtnYtReset.OnEvent("Click", SwitchToLocal)

; --- Row 4: FFmpeg Path ---
MyGui.Add("Text", "xm y+30 w80", "FFmpeg Path:")
GuiFFmpeg := MyGui.Add("Edit", "x+10 w200 vFFmpegPath ReadOnly", SavedFFmpeg)
BtnFFBrowse := MyGui.Add("Button", "x+5 w70", "Browse...")
BtnFFBrowse.OnEvent("Click", SelectFFmpeg)
BtnFFPath := MyGui.Add("Button", "x+5 w70", "Use PATH")
BtnFFPath.OnEvent("Click", ResetFFmpegToPath)

; --- Row 5: Format & Quality Selectors ---
MyGui.Add("GroupBox", "xm y+15 w440 h130", "Download Options")

MyGui.Add("Text", "xp+15 yp+25", "Mode:")
GuiMode := MyGui.Add("DropDownList", "x+10 w100 vMode Choose1", ["Best Quality", "Video Only", "Audio Only"])
GuiMode.OnEvent("Change", UpdateOptions)

MyGui.Add("Text", "x+20", "Audio Format:")
GuiAudioFmt := MyGui.Add("DropDownList", "x+10 w80 vAudioFmt Choose1 Disabled", ["mp3", "m4a", "opus", "wav"])

; DYNAMIC LABEL
GuiQualityLabel := MyGui.Add("Text", "xm+15 y+15 w100", "Video Resolution:")
GuiQuality := MyGui.Add("DropDownList", "x+10 w120 vQuality Choose1", ["Best Available", "1080p", "720p", "480p"])

; --- Row 6: Checkboxes ---
GuiMeta := MyGui.Add("Checkbox", "xm+15 y+15 vEmbedMeta Checked", "Embed Metadata")
GuiThumb := MyGui.Add("Checkbox", "x+20 vEmbedThumb Checked", "Embed Thumbnail")

; --- Row 7: Action Buttons ---
BtnDownload := MyGui.Add("Button", "xm y+25 w100 h30 Default", "DOWNLOAD")
BtnDownload.OnEvent("Click", StartDownload)

BtnUpdate := MyGui.Add("Button", "x+10 w100 h30", "Update yt-dlp")
BtnUpdate.OnEvent("Click", TriggerUpdate)

BtnCancel := MyGui.Add("Button", "x+140 w90 h30 Disabled", "Stop")
BtnCancel.OnEvent("Click", StopProcess)

; --- Row 8: Log / Terminal Output ---
MyGui.Add("Text", "xm y+15", "Terminal Output:")
GuiLog := MyGui.Add("Edit", "xm y+5 w440 h150 ReadOnly vLogOutput -Wrap +HScroll", "Ready.")

MyGui.Show("w460")

; ==============================================================================
; MAIN LOGIC
; ==============================================================================

SelectFolder(*) {
    Selected := DirSelect(GuiDir.Value, 3, "Select Download Folder")
    if (Selected != "")
        GuiDir.Value := Selected
}

SelectYtDlp(*) {
    Selected := FileSelect(3, GuiYtDlp.Value, "Select yt-dlp.exe", "Executables (*.exe)")
    if (Selected != "") {
        GuiYtDlp.Value := Selected
    }
}

SwitchToLocal(*) {
    ; Check if local file exists
    LocalPath := A_ScriptDir "\" YtDlpExeName

    if !FileExist(LocalPath) {
        ; If not exist, download it
        Res := MsgBox("Local yt-dlp.exe not found.`nDownload it now?", "Download", "YesNo Icon?")
        if (Res = "Yes") {
            DownloadGui("Install")
            if FileExist(LocalPath) {
                GuiYtDlp.Value := LocalPath
                MsgBox("Switched to local version.", "Success", 64)
            }
        }
    } else {
        ; If exists, just switch path
        GuiYtDlp.Value := LocalPath
        MsgBox("Switched to local version.", "Info", 64)
    }
}

SelectFFmpeg(*) {
    Selected := DirSelect(GuiFFmpeg.Value, 3, "Select FFmpeg Folder (usually 'bin')")
    if (Selected != "") {
        GuiFFmpeg.Value := Selected
        if !FileExist(Selected "\ffmpeg.exe") {
            MsgBox("Warning: 'ffmpeg.exe' was not found in:`n" Selected, "Check Path", 48)
        }
    }
}

ResetFFmpegToPath(*) {
    GuiFFmpeg.Value := ""
    GuiLog.Value := "FFmpeg path cleared. Using system PATH."
}

UpdateOptions(*) {
    Saved := MyGui.Submit(0)

    if (Saved.Mode = "Audio Only") {
        GuiAudioFmt.Enabled := True
        GuiQualityLabel.Value := "Audio Bitrate:"
    } else {
        GuiAudioFmt.Enabled := False
        GuiQualityLabel.Value := "Video Resolution:"
    }

    GuiQuality.Delete()

    if (Saved.Mode = "Audio Only") {
        GuiQuality.Add(["Best (VBR)", "320 kbps", "256 kbps", "192 kbps", "128 kbps"])
    } else {
        GuiQuality.Add(["Best Available", "4K / 2160p", "2K / 1440p", "1080p", "720p", "480p"])
    }
    GuiQuality.Choose(1)
}

StartDownload(*) {
    global PID
    Saved := MyGui.Submit(0)

    if (Saved.URL = "") {
        MsgBox("Please enter a URL first.", "Error", 48)
        return
    }

    if !FileExist(Saved.YtDlpPath) {
        MsgBox("The selected yt-dlp.exe does not exist.", "Error", 16)
        return
    }

    ; Save Settings
    IniWrite(Saved.OutputDir, IniFile, "Settings", "OutputDir")
    IniWrite(Saved.FFmpegPath, IniFile, "Settings", "FFmpegPath")
    IniWrite(Saved.YtDlpPath, IniFile, "Settings", "YtDlpPath")

    Args := []
    Args.Push("--newline")
    Args.Push("-P", Quote(Saved.OutputDir))
    Args.Push("-o", Quote("%(title)s [%(id)s].%(ext)s"))

    if (Saved.FFmpegPath != "")
        Args.Push("--ffmpeg-location", Quote(Saved.FFmpegPath))

    switch Saved.Mode {
        case "Audio Only":
            Args.Push("-x", "--audio-format", Saved.AudioFmt)
            switch Saved.Quality {
                case "Best (VBR)": Args.Push("--audio-quality", "0")
                case "320 kbps": Args.Push("--audio-quality", "320K")
                case "256 kbps": Args.Push("--audio-quality", "256K")
                case "192 kbps": Args.Push("--audio-quality", "192K")
                case "128 kbps": Args.Push("--audio-quality", "128K")
            }
        case "Video Only":
            Args.Push("-f", "bestvideo")
        Default:
            ; Best Quality
    }

    if (Saved.Mode != "Audio Only") {
        switch Saved.Quality {
            case "4K / 2160p": Args.Push("-f", Quote("bv*[height<=2160]+ba/b[height<=2160] / best"))
            case "2K / 1440p": Args.Push("-f", Quote("bv*[height<=1440]+ba/b[height<=1440] / best"))
            case "1080p": Args.Push("-f", Quote("bv*[height<=1080]+ba/b[height<=1080] / best"))
            case "720p": Args.Push("-f", Quote("bv*[height<=720]+ba/b[height<=720] / best"))
            case "480p": Args.Push("-f", Quote("bv*[height<=480]+ba/b[height<=480] / best"))
        }
    }

    if (Saved.EmbedMeta)
        Args.Push("--embed-metadata")
    if (Saved.EmbedThumb)
        Args.Push("--embed-thumbnail")

    Args.Push(Quote(Saved.URL))
    CmdStr := Join(Args, " ")
    RunCommand(Saved.YtDlpPath, CmdStr)
}

TriggerUpdate(*) {
    ; Update always targets the LOCAL file
    MyGui.Destroy()
    DownloadGui("Update")
}

RunCommand(ExePath, Params) {
    global PID, LogFile
    BtnDownload.Enabled := False
    BtnUpdate.Enabled := False
    BtnCancel.Enabled := True
    GuiLog.Value := "Building command...`r`n"

    if FileExist(LogFile)
        FileDelete(LogFile)

    FullCmd := A_ComSpec ' /c ""' ExePath '" ' Params ' > "' LogFile '" 2>&1"'
    GuiLog.Value .= "Executing: " FullCmd "`r`n`r`n"

    try {
        Run(FullCmd, A_ScriptDir, "Hide", &PID)
    } catch as e {
        GuiLog.Value .= "Error starting process: " e.Message
        ResetGUI()
        return
    }
    SetTimer(CheckLog, 100)
}

CheckLog() {
    global PID, LogFile
    if FileExist(LogFile) {
        try {
            f := FileOpen(LogFile, "r-d")
            if IsObject(f) {
                CurrentLog := GuiLog.Value
                NewData := f.Read()
                f.Close()
                if (StrLen(NewData) > StrLen(CurrentLog)) {
                    GuiLog.Value := NewData
                    SendMessage(0x0115, 7, 0, GuiLog.Hwnd, "Integer")
                }
            }
        }
    }
    if !ProcessExist(PID) {
        SetTimer(CheckLog, 0)
        GuiLog.Value .= "`r`n--- Process Finished ---"
        ResetGUI()
    }
}

StopProcess(*) {
    global PID
    if ProcessExist(PID) {
        ProcessClose(PID)
        GuiLog.Value .= "`r`n--- Process Terminated by User ---"
    }
}

ResetGUI() {
    BtnDownload.Enabled := True
    BtnUpdate.Enabled := True
    BtnCancel.Enabled := False
    global PID := 0
}

GuiClose(*) {
    StopProcess()
    ExitApp
}

; ==============================================================================
; DOWNLOADER GUI
; ==============================================================================
DownloadGui(Mode) {
    global DlGui, DlText, DlProgress

    DlGui := Gui("+AlwaysOnTop -SysMenu", Mode " yt-dlp")
    DlGui.SetFont("s9", "Segoe UI")

    if (Mode = "Install")
        TitleMsg := "yt-dlp not found. Initializing..."
    else
        TitleMsg := "Updating yt-dlp..."

    DlGui.Add("Text", "xm w350 Center vTitle", TitleMsg)
    DlProgress := DlGui.Add("Progress", "xm y+10 w350 h20 -Smooth", 0)
    DlText := DlGui.Add("Text", "xm y+5 w350 Center vDlText", "Fetching file info...")

    DlGui.Show()

    SetTimer(() => DownloadRoutine(Mode), 100)
    WinWaitClose("ahk_id " DlGui.Hwnd)

    if (Mode = "Update")
        Reload
}

DownloadRoutine(Mode) {
    SetTimer(, 0)
    TempFile := A_ScriptDir "\yt-dlp.exe.tmp"
    TargetFile := A_ScriptDir "\" YtDlpExeName

    try {
        WebRequest := ComObject("WinHttp.WinHttpRequest.5.1")
        WebRequest.Open("HEAD", YtDlpUrl, true)
        WebRequest.Send()
        WebRequest.WaitForResponse()

        SizeLabel := "Unknown Size"
        if (WebRequest.Status == 200) {
            TotalBytes := Integer(WebRequest.GetResponseHeader("Content-Length"))
            SizeLabel := Format("{:.2f} MB", TotalBytes / 1024 / 1024)
        }

        DlText.Value := "Downloading... (Size: " SizeLabel ")"
        DlProgress.Value := 50

        Download(YtDlpUrl, TempFile)

        DlProgress.Value := 100
        DlText.Value := "Finalizing..."
        Sleep(500)

        if FileExist(TargetFile)
            FileDelete(TargetFile)
        FileMove(TempFile, TargetFile)

        DlGui.Opt("+OwnDialogs")
        MsgBox("Operation Complete!", "Success", 64)
        DlGui.Destroy()

    } catch as e {
        DlGui.Destroy()
        MsgBox("Download Error: " e.Message, "Error", 16)
        ExitApp
    }
}

; ==============================================================================
; HELPER FUNCTIONS
; ==============================================================================
Quote(Str) {
    return '"' Str '"'
}

Join(Arr, Delim) {
    Str := ""
    for Index, Value in Arr
        Str .= Value . Delim
    return SubStr(Str, 1, StrLen(Str) - StrLen(Delim))
}
