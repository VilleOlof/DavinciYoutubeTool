-- Made by: VilleOlof
-- https://github.com/VilleOlof

projman = resolve:GetProjectManager()
proj = projman:GetCurrentProject()
mediapool = proj:GetMediaPool()
mediaStorage = resolve:GetMediaStorage()
-------------------------------------------

davinci_Edit_path = [[%appdata%/Blackmagic Design/DaVinci Resolve/Support/Fusion/Scripts/Edit/]]
youtubeDL_path = [[']]..davinci_Edit_path..[[youtube-dl.exe']]

base_path = [[G:/Video Material/Project/YoutubeTool/]]
download_path = base_path..proj:GetName()..[[/]]
thumbnail_path = base_path..[[MQ-Thumbnails/]]

line_break = "───────────────────────────────────────────"

youtube_url = ""
youtube_CMD = ""
--dl_thumbnail_argument = [[--write-thumbnail --skip-download --console-title --restrict-filenames --output \"]]
dl_video_argument = [[-f best --console-title --restrict-filenames --output \"]]
dl_sound_argument = [[-x --audio-format mp3 --console-title --restrict-filenames --output \"]]
dl_external_argument = [[--external-downloader ffmpeg --external-downloader-args \"-ss ]]

dataTable = {}

function FileExists(_file)
    local ok, err, code = os.rename(_file, _file)
    if not ok then
       if code == 13 then
          -- Permission denied, but it exists
          return true
       end
    end
    return ok, err
 end

 local json = {}

local function kind_of(obj)
  if type(obj) ~= 'table' then return type(obj) end
  local i = 1
  for _ in pairs(obj) do
    if obj[i] ~= nil then i = i + 1 else return 'table' end
  end
  if i == 1 then return 'table' else return 'array' end
end

local function escape_str(s)
  local in_char  = {'\\', '"', '/', '\b', '\f', '\n', '\r', '\t'}
  local out_char = {'\\', '"', '/',  'b',  'f',  'n',  'r',  't'}
  for i, c in ipairs(in_char) do
    s = s:gsub(c, '\\' .. out_char[i])
  end
  return s
end

local function skip_delim(str, pos, delim, err_if_missing)
  pos = pos + #str:match('^%s*', pos)
  if str:sub(pos, pos) ~= delim then
    if err_if_missing then
      error('Expected ' .. delim .. ' near position ' .. pos)
    end
    return pos, false
  end
  return pos + 1, true
end

local function parse_str_val(str, pos, val)
  val = val or ''
  local early_end_error = 'End of input found while parsing string.'
  if pos > #str then error(early_end_error) end
  local c = str:sub(pos, pos)
  if c == '"'  then return val, pos + 1 end
  if c ~= '\\' then return parse_str_val(str, pos + 1, val .. c) end
  -- We must have a \ character.
  local esc_map = {b = '\b', f = '\f', n = '\n', r = '\r', t = '\t'}
  local nextc = str:sub(pos + 1, pos + 1)
  if not nextc then error(early_end_error) end
  return parse_str_val(str, pos + 2, val .. (esc_map[nextc] or nextc))
end

-- Returns val, pos; the returned pos is after the number's final character.
local function parse_num_val(str, pos)
  local num_str = str:match('^-?%d+%.?%d*[eE]?[+-]?%d*', pos)
  local val = tonumber(num_str)
  if not val then error('Error parsing number at position ' .. pos .. '.') end
  return val, pos + #num_str
end

json.null = {}  -- This is a one-off table to represent the null value.

function json.parse(str, pos, end_delim)
  pos = pos or 1
  if pos > #str then error('Reached unexpected end of input.') end
  local pos = pos + #str:match('^%s*', pos)  -- Skip whitespace.
  local first = str:sub(pos, pos)
  if first == '{' then  -- Parse an object.
    local obj, key, delim_found = {}, true, true
    pos = pos + 1
    while true do
      key, pos = json.parse(str, pos, '}')
      if key == nil then return obj, pos end
      if not delim_found then error('Comma missing between object items.') end
      pos = skip_delim(str, pos, ':', true)  -- true -> error if missing.
      obj[key], pos = json.parse(str, pos)
      pos, delim_found = skip_delim(str, pos, ',')
    end
  elseif first == '[' then  -- Parse an array.
    local arr, val, delim_found = {}, true, true
    pos = pos + 1
    while true do
      val, pos = json.parse(str, pos, ']')
      if val == nil then return arr, pos end
      if not delim_found then error('Comma missing between array items.') end
      arr[#arr + 1] = val
      pos, delim_found = skip_delim(str, pos, ',')
    end
  elseif first == '"' then  -- Parse a string.
    return parse_str_val(str, pos + 1)
  elseif first == '-' or first:match('%d') then  -- Parse a number.
    return parse_num_val(str, pos)
  elseif first == end_delim then  -- End of an object or array.
    return nil, pos + 1
  else  -- Parse true, false, or null.
    local literals = {['true'] = true, ['false'] = false, ['null'] = json.null}
    for lit_str, lit_val in pairs(literals) do
      local lit_end = pos + #lit_str - 1
      if str:sub(pos, lit_end) == lit_str then return lit_val, lit_end + 1 end
    end
    local pos_info_str = 'position ' .. pos .. ': ' .. str:sub(pos, pos + 10)
    error('Invalid json syntax starting at ' .. pos_info_str)
  end
end

local function unicode_to_utf8(code)
    -- converts numeric UTF code (U+code) to UTF-8 string
    local t, h = {}, 128
    while code >= h do
       t[#t+1] = 128 + code%64
       code = math.floor(code/64)
       h = h > 32 and 32 or h/2
    end
    t[#t+1] = 256 - 2*h + code
    return string.char(unpack(t)):reverse()
 end

function Wait(second, millisecond)
    local ostime_vrbl = os.time() + second, millisecond
    while os.time() < ostime_vrbl do end
end

function FileTimeout(file_path)
    local count = 0
    local limit = 10

    ::Attempt::
    local file = io.open(file_path)
    if (file == nil) then
        if (count == limit) then return false end
        count = count+1
        Wait(0.25)
        goto Attempt
    end

    return true
end

function GetFileCount(path,thumbnail_Box)
    local count = 0
    local suffix = dataTable.title
    if (thumbnail_Box) then suffix = dataTable.id end

    --just removing the last / from the 'selectedPath' to make the command
    local text = path:sub(1, -2)

    local Dir_CMD = "dir \""..text.."\" /b"

    for file in io.popen(Dir_CMD):lines() do 


        local fixed_cap = file:sub(1,#suffix)

        if (fixed_cap == suffix) then
            count = count + 1
        end
    end

    return count
end
 
function WindowPopup()
    local ui = fu.UIManager
    local disp = bmd.UIDispatcher(ui)
    local width,height = 755,410

    win = disp:AddWindow({
        ID = 'TextInYT',
        WindowTitle = 'YoutubeTool',
        Geometry = {650, 650, width, height},
        Spacing = 10,
        Margin = 10,
    
        ui:HGroup{

            ui:VGroup{
                ID = 'root',
                ui:TextEdit{
                    ID = 'URL_Text',
                    Text = '',
                    PlaceholderText = 'Input a Youtube URL',
                },
                ui:TextEdit{
                    ID = 'arguments',
                    Text = youtube_CMD,
                    PlaceholderText = 'Input Custom Youtube-DL Arguments',
                },

                ui:Label{
                    ID = "timestamp_label",
                    Text = line_break.."\nInput Format In \"MM:SS\" - Example: \"01:20\"\n[Requires ffmpeg In Youtube-DL Directory] ",
                    Alignment = {
                        AlignHCenter = true,
                        AlignVCenter = true,
                    },
                },
                
                ui:HGroup{
                    ui:LineEdit{
                        ID = 'timestamp_start',
                        Text = "00:00",
                        PlaceholderText = 'Input Custom Start Time',
                        ClearButtonEnabled = true,
                    },
                    ui:Label{
                        ID = "timestamp_arrow",
                        Text = "────►",
                        Alignment = {
                            AlignHCenter = true,
                            AlignVCenter = true,
                        },
                    },
                    ui:LineEdit{
                        ID = 'timestamp_end',
                        Text = "00:00",
                        PlaceholderText = 'Input Custom End Time',
                        ClearButtonEnabled = true,
                    },
                },

                ui:Label{
                    ID = "line-breaker1",
                    Text = line_break
                },

                ui:CheckBox{
                    ID = 'ThumbnailBox',
                    Text = 'Thumbnail',
                },
                ui:CheckBox{
                    ID = 'VideoBox',
                    Text = 'Video w/ Audio',
                },
                ui:CheckBox{
                    ID = 'SoundBox',
                    Text = 'Audio Only (Requires ffmpeg)',
                },

                ui:HGroup{
                    ui:Button{
                        ID = 'B',
                        Text = 'Download',
                    },
                },

                ui:HGroup{
                    ui:Button{
                        ID = 'FolderButton',
                        Text = 'Open Folder In Explorer',
                    },
                    ui:Button{
                        ID = 'AddButton',
                        Text = 'Open Latest In Explorer',
                    },
                },
            },

            ui:VGroup{
                Margin = 10,
                ui:TextEdit{
                    ID = "VideoThumbnail",
                    Text = "",
                    ReadOnly = true,
                    Alignment = {
                        AlignHCenter = true,
                        AlignVCenter = true,
                    },
                },
                ui:Label{
                    ID = "VideoInformation",
                    Text = "No Video Selected",
                    Alignment = {
                        AlignHCenter = true,
                        AlignVCenter = true,
                    },
                },
            }  
        },
    })
    function win.On.TextInYT.Close(ev)
        disp:ExitLoop()
    end
    
    itm = win:GetItems()

    function win.On.URL_Text.TextChanged(ev)
        youtube_url = itm.URL_Text.PlainText
        UpdateArgumentText()

        Json_CommandPrompt = [[powershell.exe -WindowStyle Hidden -Command "& {Start-Process -NoNewWindow -FilePath ]]..youtubeDL_path..[[ -ArgumentList ']]..[[--skip-download ]]..youtube_url..[[ --print-json]]..[[' }"]]
        Json_Command = io.popen(Json_CommandPrompt)
        JsonString = Json_Command:read("*a")

        JsonString = string.gsub(JsonString,"\\u(....)", function(b) 
            local number = tonumber(b,16)
            return unicode_to_utf8(number) 
        end)

        dataTable = json.parse(JsonString)

        local _ImagePath = thumbnail_path..dataTable.id..".jpg"
        io.popen([[curl https://img.youtube.com/vi/]]..dataTable.id..[[/mqdefault.jpg -o "]].._ImagePath..[["]])
        local image_success = FileTimeout(_ImagePath)
        if (image_success) then
            local HTML_Image = [[<html style="height:100%;"><body style="height:100%;"><div style="text-align:center;"><img src='file:///]].._ImagePath..[['/></div></body></html>]]
            itm.VideoThumbnail.HTML = HTML_Image
        end

        if (dataTable.start_time) then
            itm.timestamp_start.Text = disp_time(dataTable.start_time,false)
            itm.timestamp_end.Text = disp_time(dataTable.start_time+30,false)
        end

        itm.VideoInformation.Text = "Uploaded By: "..dataTable["uploader"].."\nView Count: "..dataTable["view_count"].."\nDuration: "..disp_time(dataTable["duration"],true).."\nResolution: "..dataTable.width.."x"..dataTable.height.."\n\n"..dataTable["title"]
    end

    function win.On.arguments.TextChanged(ev)
        youtube_CMD = itm.arguments.PlainText
    end

    function win.On.timestamp_start.TextChanged(ev)
        AddExternalDownloaderIfBothFields()
    end

    function win.On.timestamp_end.TextChanged(ev)
        AddExternalDownloaderIfBothFields()
    end

    function win.On.ThumbnailBox.Clicked(ev)

        local currentCheck = AllowOneChecked()

        if (currentCheck == true) then
            itm.ThumbnailBox.Checked = false
            return
        end

        if (itm.ThumbnailBox.Checked == true) then
            local _ImagePath = download_path..dataTable.id..GetFileCount(download_path,true)..".jpg"
            --youtube_CMD = youtube_CMD..dl_thumbnail_argument..download_path..[[%(title)s.%(ext)s\" ]]..youtube_url
            youtube_CMD = youtube_CMD..[[curl https://img.youtube.com/vi/]]..dataTable.id..[[/maxresdefault.jpg -o "]].._ImagePath..[["]]
        end
        UpdateArgumentText()
    end

    function win.On.VideoBox.Clicked(ev)

        local currentCheck = AllowOneChecked()

        if (currentCheck == true) then
            itm.VideoBox.Checked = false
            return
        end

        if (itm.VideoBox.Checked == true) then
            youtube_CMD = youtube_CMD..dl_video_argument..download_path..[[%(title)s]]..GetFileCount(download_path,false)..[[.%(ext)s\" ]]..youtube_url
            AddExternalDownloaderIfBothFields()
        end
        UpdateArgumentText()
    end

    function win.On.SoundBox.Clicked(ev)

        local currentCheck = AllowOneChecked()

        if (currentCheck == true) then
            itm.SoundBox.Checked = false
            return
        end

        if (itm.SoundBox.Checked == true) then
            youtube_CMD = youtube_CMD..dl_sound_argument..download_path..[[%(title)s]]..GetFileCount(download_path,false)..[[.%(ext)s\" ]]..youtube_url
            AddExternalDownloaderIfBothFields()
        end
        UpdateArgumentText()
    end

    function win.On.B.Clicked(ev)
        if (itm.ThumbnailBox.Checked) then 
            local _ImagePath = download_path..dataTable.id..GetFileCount(download_path,true)..".jpg"
            io.popen([[curl https://img.youtube.com/vi/]]..dataTable.id..[[/maxresdefault.jpg -o "]].._ImagePath..[["]])
            return
        end  
        io.popen([[powershell.exe -WindowStyle Hidden -Command "& {Start-Process -FilePath ]]..youtubeDL_path..[[ -ArgumentList ']]..youtube_CMD..[[' }"]])

        --disp:ExitLoop()
    end
    
    function win.On.FolderButton.Clicked(ev)
        io.popen([[explorer "]]..download_path:gsub([[/]],[[\]])..[["]])
    end

    function win.On.AddButton.Clicked(ev)

        tc_Command = [[powershell.exe -WindowStyle Hidden -Command "& {(Get-ChildItem -Path ']]..download_path..[[' -Attributes !Directory | Sort-Object -Descending -Property LastWriteTime | select -First 1).Name}"]]
        local sOut = io.popen(tc_Command)
        local fileName = sOut:read('*a')

        mediaStorage = resolve:GetMediaStorage()

        rootFolder = mediapool:GetRootFolder()
        mediapool:SetCurrentFolder(rootFolder)

        latestPath = download_path..fileName
        latestPath = latestPath:gsub([[/]],[[\]])
        -- local success = FileTimeout(latestPath);
        -- if (success) then mediaStorage:AddItemListToMediaPool(latestPath) end
        io.popen([[explorer /select,"]]..latestPath..[["]])
    end

    win:Show()
    disp:RunLoop()
    win:Hide()

end

function disp_time(time,includeHours)
    local hours = math.floor(math.fmod(time, 86400)/3600)
    local minutes = math.floor(math.fmod(time,3600)/60)
    local seconds = math.floor(math.fmod(time,60))
    local _formatString = "%02d:%02d"
    if (includeHours) then 
        _formatString = _formatString..":%02d" 
        return string.format(_formatString,hours,minutes,seconds)
    end
    return string.format(_formatString,minutes,seconds)
  end

function AddExternalDownloaderIfBothFields()
    if (itm.timestamp_start.Text ~= "" and itm.timestamp_end.Text ~= "") then

        if (itm.VideoBox.Checked == true) then
            youtube_CMD = dl_external_argument..itm.timestamp_start.Text..[[ -to ]]..itm.timestamp_end.Text..[[\" ]]..dl_video_argument..download_path..[[%(title)s]]..GetFileCount(download_path,false)..[[.%(ext)s\" ]]..youtube_url
        end

        if (itm.SoundBox.Checked == true) then
            youtube_CMD = dl_external_argument..itm.timestamp_start.Text..[[ -to ]]..itm.timestamp_end.Text..[[\" ]]..dl_sound_argument..download_path..[[%(title)s]]..GetFileCount(download_path,false)..[[.%(ext)s\" ]]..youtube_url
        end
        UpdateArgumentText()
    end
end

function AllowOneChecked()
    local thumbnail_bool = itm.ThumbnailBox.Checked
    local video_bool = itm.VideoBox.Checked
    local sound_bool = itm.SoundBox.Checked

    local _count = 0
    if (thumbnail_bool == true) then _count = _count + 1 end
    if (video_bool == true) then _count = _count + 1 end
    if (sound_bool == true) then _count = _count + 1 end

    if (_count >= 2) then
        return true
    end

    youtube_CMD = ""
    UpdateArgumentText()
    return false
end

function UpdateArgumentText()
    itm.arguments.Text = youtube_CMD
    return
end

function Wait(second, millisecond)
    local ostime_vrbl = os.time() + second, millisecond
    while os.time() < ostime_vrbl do end
end

function DownloadYoutubeDL()

    if (FileExists(youtubeDL_path)) then return end

    dl_Command = [[curl -L https://yt-dl.org/downloads/2021.12.17/youtube-dl.exe -o ]]
    io.popen(dl_Command..youtubeDL_path)
end

-- Main:
_fileExists = FileExists(youtubeDL_path)
if (not _fileExists) then DownloadYoutubeDL() end

_DirExists = FileExists(download_path)
if (not _DirExists) then io.popen([[mkdir "]]..download_path..[["]]) end

_ThumbnailDirExists = FileExists(thumbnail_path)
if (not _ThumbnailDirExists) then io.popen([[mkdir "]]..thumbnail_path..[["]]) end

WindowPopup()