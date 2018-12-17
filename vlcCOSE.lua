------ Constants
-- BaseFolder constant, should only be set
BaseFolder = ""
------ Basic functions
 -- Print data in vlc console
function info(s)
  if s ~= null then vlc.msg.info("[vlcCOSE] "..s) else vlc.msg.info("[vlcCOSE] ".. "A value other than a string has been submitted") end
end
function split(s, delimiter)
    result = {};
    if (s ~= nil) then
      i = 0
      for match in (s..delimiter):gmatch("(.-)"..delimiter) do
          result[i] = match
          i = i + 1
      end
    end
    return result;
end

function returnFiles(list, ext)
  local files = {}
  for i,v in pairs(list)do
    if(string.find(v,ext)) then
      files[i] = v:gsub("\\","")
    end
  end
  return files
end

 function file_exists(name)
   local f=io.open(name,"r")
   if f~=nil then io.close(f) return true else return false end
end

function getTxtConfigFiles(directory)
  local f = io.popen('dir "'.. directory ..'"')
  local txtFiles = {}
  if f then
    local fread = f:read("*a")
     local splittedFiles = split(fread,"\n")
      txtFiles = returnFiles(splittedFiles, ".txt")
      info("Done getting config files")
  else
      info("failed to read config files")
  end
  
  f:close()
  return txtFiles
end

function getFiles(directory)
  -- For some reason not working in the COSE Directory, Maybe its still opened somewhere? weird bug
  local f = io.popen('dir "'.. directory ..'"')
  local mkvFiles = {}
  if f then
     local splittedFiles = split(f:read("*a"),"\n")
      mkvFiles = returnFiles(splittedFiles, ".mkv")
  else
      info("failed to read show config file")
  end
  
  f:close()
  return mkvFiles
end

------ Objects
---- Show
Show = {}
Show.__index = Show
-- create a show
function Show:Create(name,path)
  local sh = {}
  setmetatable(sh,Show)
  
  sh.ConfigFile = name .. ".txt"
  sh.Name = name
  sh.Path = path
  --sh.LastEpisode = getFiles(path)[0]
  sh.LastEpisode = "somePath"
  sh.Time = 0
  sh.Playing = ""   
  sh:Save()
  
  info("Created Show: " .. name)
  return sh
end

-- open a excisting show should end on .txt
function Show:Open(File)
  local sh = {}
  setmetatable(sh,Show)

  ShowLines = io.lines(BaseFolder .. File)
  sh.ConfigFile = File
  sh.Name = ShowLines(0)
  sh.Path = ShowLines(1) 
  sh.LastEpisode = ShowLines(2)
  sh.Time = ShowLines(3)
  sh.Playing = "" 
  
  info("Opened Show: " .. sh.Name)
  return sh
end
-- start the show
function Show:PrepareAndPlay()
  local playlistTable = {}
  local videoTime = self.Time
  
  for i, video in pairs(getFiles(self.Path)) do
    -- pick first video so if the file does not excist atleast something is playing
    if (first == true) then 
      self.Playing = "file://"..self.Path .. video
      first = false
    end
    
    -- add file to playlist
    playlistTable[i] = {}
		playlistTable[i].path = "file://"..self.Path .. video
		playlistTable[i].title = video
    
    -- if video is last played set this video as first in playlist
    if (video == self.LastEpisode) then
      self.Playing = "file://" .. self.Path .. video
      -- divided by 1 000 000 because the seconds are saved
      videoTime= videoTime / 1000000
      -- set video start time
			playlistTable[i].options = {"start-time=" .. videoTime}
    end
  end
  
  vlc.playlist.clear()
	vlc.playlist.enqueue(playlistTable)

	vlc.playlist.loop("on")
	vlc.playlist.random("off")

  local videoNotFoundYet = true
	for i, item in pairs(vlc.playlist.get("playlist",false).children) do
    -- skip this code if video is found
    if (videoNotFoundYet == true) then     
      if (item.path == self.Playing) then
        startVideoID = item.id
        videoNotFoundYet = false
      else
          startVideoID = item.id
      end
    end
  end
	vlc.playlist.gotoitem( startVideoID ) -- for vlc v2.1.4 rincewind on linux mint 17 -> also works on windows
  info("Now Playing: " .. self.Name)
end



-- save show
function Show:Save()
  -- If vlc is playing it will save new time and path
  if(self.Playing ~= "") then
    -- should work, but dont know for sure if table doesnt do weird stuff
    for i,v in ipairs(split(vlc.playlist.get( vlc.playlist.current() ).path,"/")) do
      videoPath = v
    end
    
    self.LastEpisode = videoPath
    local videoTime = vlc.var.get(vlc.object.input(), "time") - 5
    if (videoTime <= 0) then
      videoTime = 0
    end
    self.Time = videoTime
    info("New time: " .. videoTime)
  end
  
  -- just save it to the file
  io.output( BaseFolder .. self.ConfigFile )
	io.write(self.Name, "\n")
  io.write(self.Path, "\n")
  io.write(self.LastEpisode, "\n")
  io.write(self.Time, "\n")
	io.close()
  info("Saved Show: " .. self.Name)
end
---- ConfigFile
Config = {}
Config.__index = Config
-- Open config file
function Config:Open()
  local config = {}
  setmetatable(config, Config)
  
  config.LastPlayed = ""
  config.Shows = {}
  config.ConfigFile = BaseFolder .. "COSECONFIG.txt"
  
  config:Read()
  config:SetShows()
  
  config.Playing = Show:Open(config.LastPlayed)
  
  info("Opened Config")
  
  return config
end
-- read the configFile declared in the config object
function Config:Read()
    local ShowName = ""

  -- check if dir excists so no error has to be given, learned standard c has not an check option so ill let it happen for now
  info("making directory for home file, should fail after first time")
  os.execute("mkdir " .. BaseFolder)
  
  -- check if files excists
  local excists = file_exists(self.ConfigFile)
  if (excists == false) then
    io.output(self.ConfigFile)
    io.close()
  else
    local ConfigLines = io.lines(self.ConfigFile)
    io.close()
    ShowName = ConfigLines(0)
  end
  -- set Lastplayed of config file
  self.LastPlayed = ShowName
  
  info("Read Config")
end
-- Play Show declared in Config
function Config:PlayShow()
  self.Playing:PrepareAndPlay()
  info("Playing Last Played Show")
end
--
function Config:NewShow(name, path)
  self:SaveShow()
  self.Playing = Show:Create(name,path)
  self.LastPlayed = self.Playing.ConfigFile
  self:SaveConfig()
  self.Playing:PrepareAndPlay()
  
  info("Saved and created a new show")
end
-- Save Current Playing Show
function Config:SaveShow()
  self.Playing:Save()
  info("Save Show which is being played")
end
-- Save config file
function Config:SaveConfig()
  io.output(self.ConfigFile)
  io.write(self.LastPlayed)
  io.close()
  info("Saving Configuration")
end
-- set all shows the config folder has
function Config:SetShows()  
  j = 1
  for i,v in pairs(getTxtConfigFiles(BaseFolder)) do
    if(v ~= "COSECONFIG.txt")then
      self.Shows[j] = v
      j = j+1
      end
  end
  info("Retrieved all shows")
end
-- get Config Name
function Config:GetLastPlayedName()
  info("return name of lastplayed")
  return self.LastPlayed
end
-- Config Change Shows
function Config:ChangeShows(newShowFile)
  self:SaveShow()
  self.Playing = Show:Open(newShowFile)
  self.LastPlayed = self.Playing.ConfigFile
  self:SaveConfig()
  self.Playing:PrepareAndPlay()
  info("Changed Shows")
end
------ Dialogs
-- Reset the Dialog
function resetDialog()
  i = 0
  for index,value in pairs(widgets) do 
		dialog:del_widget(widgets[index])
		widgets[index] = nil
	end
end
-- Open The Dialog
function openDialog(func)
  widgets = {}
  dialog = vlc.dialog("COSE")
  resetDialog()
  func()
end
-- get an increasing number so no ugly hardcoded numbers or random numbers
function getI()
  i = i +1
  return i
end
-- Add pairs for widget
function addPairs(widget,pair)
  for index,value in ipairs(pair) do 
		widget:add_value(value, index)
	end
end
-- Open selected show
function ReadSelected()
  Configuration:ChangeShows(Configuration.Shows[widgets[dialogWidgetIndex]:get_value()])
  dialog:hide()
end
-- Play File declared in config
function PlayLastPlayed()
  Configuration:PrepareAndPlay()
  dialog:hide()
end
--
function OpenLastPlayed()
  Configuration:PlayShow()
  dialog:hide()
end
-- open startup dialog
function openStartupDialog()
  local lastplayed = "PLAY " .. Configuration:GetLastPlayedName()
	widgets[getI()] = dialog:add_button(lastplayed,OpenLastPlayed,1,1)
  dialogWidgetIndex = getI()
  widgets[dialogWidgetIndex] = dialog:add_dropdown(1,2)
  addPairs(widgets[dialogWidgetIndex],Configuration.Shows)
  widgets[getI()] = dialog:add_button("Play Other show",ReadSelected,1,3)
  widgets[getI()] = dialog:add_button("Create New Show",createDialog,1,4)
  dialog:show()
end
-- Create new Dialog
function createDialog()
  resetDialog()
  DialogCreateShow()
end
--
function DialogCreateShow()
  resetDialog()
  widgets[getI()] = dialog:add_label("Show Name",1,1)
  nameIndex = getI()
  widgets[nameIndex] = dialog:add_text_input( "", 2,1 )
  widgets[getI()] = dialog:add_label("Path to Show",1,2)
  PathIndex = getI()
  widgets[PathIndex] = dialog:add_text_input( "", 2,2 )

  widgets[getI()] = dialog:add_button("Create The Show",createInputForShow,1,4)
  dialog:show()
end
--
function createInputForShow()
  local name = widgets[nameIndex]:get_text()
  local path =widgets[PathIndex]:get_text()  
  Configuration:NewShow(name,path)
  dialog:hide()
end
------ vlc functions
function meta_changed()
  -- maybe add feature to skip openings and endings
  -- this seems to get called pretty often, I heard, dont know for sure
end

function input_changed()
  -- save show
  Configuration:SaveShow()
end

function playing_changed()
  -- save show
  Configuration:SaveShow()
end

function close()
  -- Deactivate folder
end

function descriptor()
	return {
		title = "vlcCOSE";
		version = "1.0";
		author = "Ik-Jelle";
		shortdesc = "Continue Serie";
		description = "Easy opening season instead of opening and finding file";
		capabilities = {"input-listener","meta-listener","playing-listener"}
	}
end

function activate()
  BaseFolder =  vlc.config.homedir() .. "/Documents/COSE/"
  
  Configuration = Config:Open()
  
  openDialog(openStartupDialog)
end

function deactivate()
  -- save show
  Configuration:SaveShow()
end