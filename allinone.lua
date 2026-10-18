-- Windows XP Ultimate CC - instalador autocontenido
-- Crea los modulos, conserva los archivos personales y respeta el autostart elegido.
local payload = {}
payload["/startup.lua"] = [=[
-- Inicio configurable para Windows XP Ultimate CC.
-- Por defecto muestra el menu para que siempre se pueda entrar a CraftOS.
local setting = "/.xpultimate/autostart"
local function readAutoStart()
  if not fs.exists(setting) then return false end
  local f = fs.open(setting, "r")
  if not f then return false end
  local value = f.readAll()
  f.close()
  return value == "on"
end
local function writeAutoStart(enabled)
  if not fs.exists("/.xpultimate") then fs.makeDir("/.xpultimate") end
  local f = fs.open(setting, "w")
  if not f then return false end
  f.write(enabled and "on" or "off")
  f.close()
  return true
end
local function startXP()
  term.setBackgroundColor(colors.black)
  term.setTextColor(colors.white)
  term.clear()
  shell.run("/sys/kernel.lua")
end

local autoStart = readAutoStart()
if autoStart then
  local timer = os.startTimer(4)
  term.setBackgroundColor(colors.black)
  term.setTextColor(colors.white)
  term.clear()
  term.setCursorPos(2, 2)
  print("Windows XP Ultimate CC se iniciara en 4 segundos.")
  print("Pulsa cualquier tecla para cancelar y abrir el menu.")
  local cancelled = false
  while true do
    local event, p1 = os.pullEventRaw()
    if event == "key" or event == "char" or event == "mouse_click" or event == "terminate" then cancelled = true; break end
    if event == "timer" and p1 == timer then startXP(); return end
  end
  if not cancelled then return end
end

while true do
  term.setBackgroundColor(colors.blue)
  term.setTextColor(colors.white)
  term.clear()
  term.setCursorPos(2, 2)
  print("Windows XP Ultimate CC - Inicio")
  print("")
  print("[1] Iniciar XP esta vez")
  print("[2] Volver a CraftOS")
  print("[A] Activar autostart e iniciar XP")
  print("[D] Desactivar autostart y volver al menu")
  print("")
  print("Autostart: " .. (autoStart and "ACTIVADO" or "DESACTIVADO"))
  print("Elige una opcion:")
  local event, value = os.pullEvent("key")
  if value == keys.one then startXP(); return
  elseif value == keys.two then return
  elseif value == keys.a then writeAutoStart(true); startXP(); return
  elseif value == keys.d then autoStart=false;writeAutoStart(false) end
end
]=]
payload["/sys/kernel.lua"] = [=[
-- Windows XP Ultimate CC: escritorio Luna para terminales CC:Tweaked.
local W,H=term.getSize()
local baseTerminal=term.current()
-- Compatibility guard for CraftOS-PC. Some builds report an incomplete
-- Redirect object even after all native methods have been copied, so retry
-- the actual validation error and fill the exact missing method each time.
local nativeTerminal=term.native and term.native() or baseTerminal
local rawTermRedirect=term.redirect
if type(rawTermRedirect)=="function" then
 term.redirect=function(target)
  if type(target)~="table" then return rawTermRedirect(target) end
  if type(nativeTerminal)=="table" then
   for method,fn in pairs(nativeTerminal) do
    if type(method)=="string" and type(fn)=="function" and type(target[method])~="function" then rawset(target,method,fn) end
   end
  end
  for attempt=1,64 do
   local ok,previous=pcall(rawTermRedirect,target)
   if ok then return previous end
   local missing=tostring(previous):match("Redirect object is missing method ([%w_]+)")
   if not missing then error(previous,2) end
   local fn=target[missing]
   if type(fn)~="function" then fn=baseTerminal and baseTerminal[missing] end
   if type(fn)~="function" and nativeTerminal then fn=nativeTerminal[missing] end
   if type(fn)~="function" then fn=function() return false end end
   rawset(target,missing,fn)
  end
  error("Redirect validation exceeded 64 missing methods",2)
 end
end
local C=colors
local apps={
 {id="computer",name="Mi PC",icon="[PC]"},{id="browser",name="Internet Explorer",icon="[WEB]"},
 {id="studio",name="FL Studio XP",icon="[FL]"},
 {id="create",name="Create Manager",icon="[RPM]"},{id="players",name="Jugadores/AP",icon="[AP]"},
 {id="explorer",name="Mis documentos",icon="[DIR]"},{id="notepad",name="Bloc de notas",icon="[TXT]"},
 {id="cmd",name="Simbolo del sistema",icon=">_"},{id="media",name="Windows Media Player",icon="[M]"},
 {id="control",name="Panel de control",icon="[CFG]"},
 {id="settings",name="Ajustes XP",icon="[OPT]"},{id="taskmgr",name="Administrador de tareas",icon="[TASK]"},
 {id="clock",name="Cronometro",icon="[TIME]"},
 {id="games",name="Juegos XP",icon="[GAME]"},
 {id="youtube",name="XP YouTube",icon="[YT]"},
 {id="tools",name="Centro de herramientas",icon="[TOOLS]"},
 {id="ide",name="XP Visual Lua Studio",icon="[IDE]"},
 {id="packages",name="Gestor de paquetes",icon="[PKG]"},
 {id="users",name="Cuentas de usuario",icon="[USR]"},
 {id="calculator",name="Calculadora",icon="[+ -]"},
 {id="paint",name="Paint XP",icon="[ART]"},
 {id="system",name="Informacion del sistema",icon="[PC+]"},
}
local windows,active={},nil
local renderSurface,renderParent,renderWidth,renderHeight=nil,nil,0,0
local menu,logged=false,false
local menuSearch=""
local username="Usuario"
local inputMode,inputText=nil,""
local suppressNextChar=false
local status="Bienvenido a Windows XP Ultimate CC"
local createAlert=false
local createDevices={}
local autoStartPath="/.xpultimate/autostart"
local function getAutoStart()
 if not fs.exists(autoStartPath) then return false end
 local f=fs.open(autoStartPath,"r");if not f then return false end
 local value=f.readAll();f.close();return value=="on"
end
local function setAutoStart(enabled)
 if not fs.exists("/.xpultimate") then fs.makeDir("/.xpultimate") end
 local f=fs.open(autoStartPath,"w");if not f then return false end
 f.write(enabled and "on" or "off");f.close();return true
end
local ap=dofile("/drivers/peripherals.lua")
local browser=dofile("/apps/browser.lua")
local files=dofile("/apps/files.lua")
local audio=dofile("/apps/audio.lua")
local calculator=dofile("/apps/calculator.lua")
local studio=dofile("/apps/studio.lua")
local games=dofile("/apps/games.lua")
local youtube=dofile("/apps/youtube.lua")
local tools=dofile("/apps/tools.lua")
local ide=dofile("/apps/ide.lua")
local packages=dofile("/apps/packages.lua")
local soundOK,sounds=pcall(dofile,"/sys/sounds.lua")
if not soundOK then sounds={play=function() return false end} end
local soundEnabled=true
local function playSound(name) if soundEnabled then pcall(sounds.play,name) end end
local wallpaper=C.cyan
local accentColor=C.gray
local themes={{name="LevelOS Aqua",wall=C.cyan,accent=C.gray,level=true},{name="Luna azul",wall=C.lightBlue,accent=C.blue},{name="Aqua",wall=C.cyan,accent=C.blue},{name="Violeta",wall=C.purple,accent=C.blue},{name="Cielo",wall=C.lightBlue,accent=C.cyan},{name="Bosque",wall=C.lime,accent=C.green},{name="Atardecer",wall=C.orange,accent=C.red}}
local themeIndex=1
local settingsPath="/.xpultimate/settings"
local monitorSetting="/.xpultimate/monitor"
local selectedDisplay="terminal"
local activeMonitor=nil
local outputTargets={baseTerminal}
local mirrorTerminal={}
local function refreshOutputTargets()
 outputTargets={baseTerminal}
 if activeMonitor then outputTargets[#outputTargets+1]=activeMonitor end
end
local function readSize(target)
 local ok,width,height=pcall(target.getSize)
 if ok then return tonumber(width) or 1,tonumber(height) or 1 end
 return 1,1
end
local function forward(method,...)
 local firstResult
 for index,target in ipairs(outputTargets) do
  local fn=target[method]
  if type(fn)=="function" then
   local ok,a,b,c=pcall(fn,...)
   if index==1 and ok then firstResult={a,b,c} end
  end
 end
 if firstResult then return firstResult[1],firstResult[2],firstResult[3] end
end
for _,method in ipairs({"write","blit","clear","clearLine","scroll","setCursorPos","setTextColor","setBackgroundColor","setCursorBlink","setPaletteColor"}) do
 local name=method
 mirrorTerminal[name]=function(...) return forward(name,...) end
end
mirrorTerminal.getSize=function()
 local width,height=readSize(baseTerminal)
 if activeMonitor then local mw,mh=readSize(activeMonitor);width=math.min(width,mw);height=math.min(height,mh) end
 W,H=width,height
 return width,height
end
for _,method in ipairs({"getCursorPos","getTextColor","getBackgroundColor","getCursorBlink","getPaletteColor"}) do
 local name=method
 mirrorTerminal[name]=function(...)
  local fn=baseTerminal[name]
  if type(fn)=="function" then return fn(...) end
 end
end
mirrorTerminal.isColor=function()
 local fn=baseTerminal.isColor
 local ok,color=false,false
 if type(fn)=="function" then ok,color=pcall(fn) end
 color=ok and color or false
 if activeMonitor and type(activeMonitor.isColor)=="function" then
  local monitorOk,monitorColor=pcall(activeMonitor.isColor)
  color=color and monitorOk and monitorColor
 end
 return color
end
local redirectedMethods={"write","blit","clear","clearLine","getCursorPos","setCursorPos","getSize","scroll",
 "getTextColor","setTextColor","getBackgroundColor","setBackgroundColor","isColor","getCursorBlink","setCursorBlink",
 "getPaletteColor","setPaletteColor"}
local function redirectWindow(target,fallback)
 -- Patch the actual window table before term.redirect validates it. A proxy
 -- can still be rejected by CraftOS-PC's native Redirect checks.
 local native=term.native and term.native()
 local methods={}
 for _,method in ipairs(redirectedMethods) do methods[method]=true end
 if type(native)=="table" then
  for method,fn in pairs(native) do
   if type(method)=="string" and type(fn)=="function" then methods[method]=true end
  end
 end
 for method in pairs(methods) do
  if type(target[method])~="function" then
   local fn=fallback and fallback[method]
   if type(fn)~="function" and native then fn=native[method] end
   if type(fn)=="function" then rawset(target,method,fn) end
  end
 end
 return target
end
local function listExternalMonitors()
 local result={}
 if not peripheral or type(peripheral.getNames)~="function" then return result end
 for _,name in ipairs(peripheral.getNames()) do
  local ok,kinds=pcall(peripheral.getType,name)
  local typeName=type(kinds)=="table" and table.concat(kinds," ") or tostring(kinds or "")
  if typeName:lower():find("monitor",1,true) then
   local wrappedOk,device=pcall(peripheral.wrap,name)
   if wrappedOk and device and type(device.getSize)=="function" and type(device.write)=="function" then
    result[#result+1]={name=name,device=device}
   end
  end
 end
 table.sort(result,function(a,b)return a.name<b.name end)
 return result
end
local function applyDisplay(name,persist)
 local output=nil
 if name~="terminal" then
  for _,entry in ipairs(listExternalMonitors()) do
   if entry.name==name then
    output=entry.device
    if type(output.setTextScale)=="function" then pcall(output.setTextScale,0.5) end
    break
   end
  end
  if not output then name="terminal" end
 end
 activeMonitor=output
 refreshOutputTargets()
 selectedDisplay=name
 W,H=mirrorTerminal.getSize()
 renderSurface=nil;renderParent=nil;renderWidth=0;renderHeight=0
 for _,target in ipairs(outputTargets) do
  pcall(target.setBackgroundColor,wallpaper)
  pcall(target.clear)
 end
 if persist then
  if not fs.exists("/.xpultimate") then fs.makeDir("/.xpultimate") end
  local file=fs.open(monitorSetting,"w")
  if file then file.write(selectedDisplay);file.close() end
 end
end
local function cycleDisplay()
 local choices={{name="terminal"}}
 for _,entry in ipairs(listExternalMonitors()) do choices[#choices+1]=entry end
 local current=1
 for i,entry in ipairs(choices) do if entry.name==selectedDisplay then current=i;break end end
 local nextEntry=choices[current%#choices+1]
 applyDisplay(nextEntry.name,true)
 status=selectedDisplay=="terminal" and "Pantalla: terminal CraftOS" or ("Pantalla: monitor "..selectedDisplay)
end
local function saveSettings()
 if not fs.exists("/.xpultimate") then fs.makeDir("/.xpultimate") end
 local f=fs.open(settingsPath,"w");if f then f.write(textutils.serialize({theme=themeIndex,sounds=soundEnabled}));f.close() end
end
if fs.exists(settingsPath) then
 local f=fs.open(settingsPath,"r")
 if f then local ok,saved=pcall(textutils.unserialize,f.readAll());f.close()
  if ok and type(saved)=="table" then
   themeIndex=math.max(1,math.min(#themes,tonumber(saved.theme) or 1));wallpaper=themes[themeIndex].wall;accentColor=themes[themeIndex].accent
   if type(saved.sounds)=="boolean" then soundEnabled=saved.sounds end
  end
 end
end
local paintColors={C.black,C.red,C.green,C.blue,C.orange,C.purple}
local desktopRows,desktopColumns,desktopPage=4,3,0
local userFile="/.xpultimate/users"
local function clipped(s,n) s=tostring(s or ""); if #s>n then return s:sub(1,math.max(1,n-3)).."..." end; return s end
local function appendWrapped(lines,text,width)
 width=math.max(8,width)
 for paragraph in tostring(text or ""):gmatch("[^\n]+") do
  local line=""
  for word in paragraph:gmatch("%S+") do
   while #word>width do
    if line~="" then lines[#lines+1]=line;line="" end
    lines[#lines+1]=word:sub(1,width);word=word:sub(width+1)
   end
   if line=="" then line=word elseif #line+#word+1<=width then line=line.." "..word else lines[#lines+1]=line;line=word end
  end
  if line~="" then lines[#lines+1]=line end
 end
end
local function box(x,y,w,h,bg)
  for yy=math.max(1,y),math.min(H,y+h-1) do term.setCursorPos(math.max(1,x),yy); term.setBackgroundColor(bg); term.write(string.rep(" ",math.max(0,math.min(W,x+w-1)-math.max(1,x)+1))) end
end
local function put(x,y,s,fg,bg)
 if y<1 or y>H or x>W then return end
 term.setCursorPos(math.max(1,x),y); term.setTextColor(fg or C.white); if bg then term.setBackgroundColor(bg) end
 term.write(clipped(s,math.max(0,W-math.max(1,x)+1)))
end
local function center(y,s,fg,bg) put(math.floor((W-#s)/2)+1,y,s,fg,bg) end
local function matchingApps()
 local matches={};local needle=(menuSearch or ""):lower()
 for _,app in ipairs(apps) do if needle=="" or app.name:lower():find(needle,1,true) then matches[#matches+1]=app end end
 return matches
end
local function loadUsers()
 local out={}
 if fs.exists(userFile) then local f=fs.open(userFile,"r"); local ok,t=pcall(textutils.unserialize,f.readAll());f.close();if ok and type(t)=="table" then out=t end end
 if #out==0 then out={{name="Usuario",pin=""}};fs.makeDir("/.xpultimate");local f=fs.open(userFile,"w");f.write(textutils.serialize(out));f.close() end
 return out
end
local users=loadUsers()
local function boot()
 playSound("startup")
 -- Recreacion textual de la pantalla de arranque XP Professional.
 -- Cuatro paneles de color evocan el logotipo; el terminal no puede dibujar pixeles.
 local logoX=math.max(1,math.floor(W/2)-13)
 local logoY=math.max(1,math.floor(H*.19))
 local titleY=math.min(H-5,math.max(logoY+5,math.floor(H*.49)))
 local barW=math.max(8,math.min(20,W-6))
 local barX=math.floor((W-barW)/2)+1
 local barY=math.min(H,math.max(titleY+4,H-3))
 local pane={{C.red,C.orange},{C.blue,C.lime}}
 for frame=1,24 do
  term.setBackgroundColor(C.black);term.clear()
  -- Bandera 2x2, usando bloques de color disponibles en CC:Tweaked.
  for row=0,1 do for col=0,1 do
   local x=logoX+col*3+(row==0 and col or 0)
   put(x,logoY+row,"  ",C.white,pane[row+1][col+1])
  end end
  put(logoX+7,logoY+1,"Microsoft",C.white,C.black)
  put(logoX+7,logoY+2,"Windows",C.white,C.black)
  put(logoX+15,logoY+2,"XP",C.orange,C.black)
  put(logoX+7,logoY+3,"Professional",C.white,C.black)
  -- Barra estrecha azul con un bloque luminoso animado.
  put(barX,barY,"["..string.rep(" ",barW-2).."]",C.lightGray,C.black)
  local inside=barW-2
  local dot=1+((frame-1)%math.max(1,inside-2))
  put(barX+dot,barY,"###",C.lightBlue,C.black)
  sleep(.09)
 end
end
local function login()
 while true do
  term.setBackgroundColor(C.lightBlue);term.clear();box(1,1,W,3,C.blue)
  put(2,2,"Windows XP Ultimate",C.white,C.blue);put(math.max(1,W-12),2,"LUNA EDITION",C.yellow,C.blue)
  center(5,"Bienvenido",C.white,C.lightBlue);center(7,"Selecciona tu cuenta",C.white,C.blue)
  for i,u in ipairs(users) do
   local y=8+i;local bg=i==1 and C.lightBlue or C.blue
   local width=math.min(W-8,28);local x=math.floor((W-width)/2)+1
   box(x,y,width,1,bg);put(x+2,y,(i==1 and "> " or "  ")..u.name,C.white,bg);put(x+width-4,y,"["..i.."]",C.yellow,bg)
  end
  center(H-2,"ENTER inicia | Pulsa el numero de cuenta",C.white,C.blue)
  local e,k=os.pullEvent("key")
  if k>=keys.one and k<=keys.nine then local u=users[k-keys.one+1];if u then username=u.name; if u.pin=="" then return true end;term.setCursorPos(2,H-1);term.write("PIN: ");local pin=read();if pin==u.pin then return true end end
  elseif k==keys.enter then username=users[1].name;return true end
 end
end
local function open(id)
 playSound("open")
 for _,w in ipairs(windows) do if w.id==id then w.min=false;active=w;return end end
 local name=id;for _,a in ipairs(apps) do if a.id==id then name=a.name end end
 local ww=math.max(1,math.min(W-2,math.max(24,math.floor(W*.74))))
 -- Reserve the last two rows for the XP status strip and taskbar.
 local hh=math.max(4,math.min(math.max(4,H-3),math.max(10,H-5)))
 local offset=(#windows%4)*2
 local w={id=id,name=name,x=math.max(1,math.min(math.floor((W-ww)/2)+1+offset,W-ww+1)),y=math.max(1,math.min(2+offset,H-hh-2)),w=ww,h=hh,min=false,max=false,scroll=0,data={}}
 windows[#windows+1]=w;active=w
 if id=="browser" then
  w.data.url="https://www.google.es"
  local page,err=browser.fetch(w.data.url)
  if page then w.data.url=page.url;w.data.title=page.title;w.data.text=page.text;w.data.links=page.links
  else w.data.title="Google Espana (sin conexion)";w.data.text="No se pudo abrir Google Espana.\n"..tostring(err).."\nPulsa A para cambiar la direccion o buscar." end
 elseif id=="explorer" or id=="computer" then w.data.path=id=="explorer" and "/Mis documentos" or "/";w.data.entries=files.list(w.data.path) or {}
 elseif id=="notepad" then w.data.path="/Mis documentos/nota.txt";w.data.text=files.read(w.data.path) or "";w.data.lines={"Editor de texto integrado.","Pulsa E para editar y guardar."}
 elseif id=="cmd" then w.data.lines={"XP Ultimate CC [CraftOS]","Comandos: help, ls, pwd, clear, reboot, shutdown"};w.data.command=""
 elseif id=="players" then w.data.lines={"Centro de control Advanced Peripherals","Datos actualizados al abrir la ventana."}
 elseif id=="create" then w.data.lines={"Create Manager: lectores de velocidad y stressometer","Pulsa R para actualizar; S para fijar velocidad."}
 elseif id=="media" then w.data.lines={"Windows Media Player","Pulsa P para reproducir una nota de prueba.","DFPWM: escribe ruta en el boton Abrir DFPWM."}
 elseif id=="users" then w.data.lines={"Cuentas locales","[A] Anadir una cuenta sin PIN",""}
 elseif id=="calculator" then w.data.expression="";w.data.result="Listo"
 elseif id=="studio" then w.data.project=studio.new()
 elseif id=="settings" then w.data.theme=themeIndex
 elseif id=="taskmgr" then w.data.selected=1
 elseif id=="clock" then w.data.elapsed=0;w.data.running=false;w.data.started=0
 elseif id=="games" then w.data.game=games.new()
 elseif id=="youtube" then w.data.youtube=youtube.new()
 elseif id=="tools" then w.data.tools=tools.new()
 elseif id=="ide" then w.data.ide=ide.new()
 elseif id=="packages" then w.data.packages=packages.new()
 elseif id=="paint" then w.data.pixels={};w.data.brush=paintColors[2]
 elseif id=="system" then w.data.lines={"Informacion del sistema"}
 end
end
local function appLines(w)
 local d=w.data;local lines={}
 if w.id=="computer" or w.id=="explorer" then
  lines={"Ubicacion: "..d.path,"Doble clic: entrar; ..: subir directorio",""}
  d.entries=files.list(d.path) or {}
  for _,e in ipairs(d.entries) do lines[#lines+1]=(e.dir and "[DIR] " or "      ")..e.name end
 elseif w.id=="browser" then
  lines={"Direccion:"};appendWrapped(lines,d.url or "",w.w-4)
  lines[#lines+1]="[A] Cambiar URL o buscar"
  lines[#lines+1]="[ENTER] Abrir pagina"
  lines[#lines+1]="Pagina: "..(d.title or "Google Espana")
  lines[#lines+1]=""
  appendWrapped(lines,d.text or "",w.w-4)
  if d.links and #d.links>0 then lines[#lines+1]="";lines[#lines+1]="Enlaces:";for i=1,math.min(5,#d.links) do appendWrapped(lines,d.links[i].title.." -> "..d.links[i].url,w.w-4) end end
 elseif w.id=="players" then
  local p,err=ap.players();lines={"Advanced Peripherals - detector de jugadores",err or (tostring(#p).." jugador(es) detectado(s)"),""};for _,v in ipairs(p or {}) do local pos=v.pos;lines[#lines+1]=v.name..(pos and string.format("  X %.1f Y %.1f Z %.1f",pos.x or 0,pos.y or 0,pos.z or 0) or "") end
  local env=ap.environment();if env then lines[#lines+1]="";for k,v in pairs(env) do lines[#lines+1]=k..": "..tostring(v) end end
  local me,meErr=ap.me();lines[#lines+1]="";lines[#lines+1]="ME Bridge: "..(me and "conectado" or meErr);for k,v in pairs(me or {}) do lines[#lines+1]=k..": "..tostring(v) end
  lines[#lines+1]="[M] Enviar mensaje (confirmacion requerida)"
 elseif w.id=="create" then
  local devices=createDevices;lines={"Create / CC:C Bridge / Create mod peripherals","[R] Actualizar  [S] Fijar RPM  [C] Redstone (clutch/sequencer)",""};w.data.devices=devices
  for _,d in ipairs(devices) do lines[#lines+1]=d.name.." ("..d.kind..")";for side,rpm in pairs(d.speed) do lines[#lines+1]="  "..side..": "..rpm.." RPM" end;for side,value in pairs(d.stress) do local cap=d.capacity[side];lines[#lines+1]="  "..side..": stress "..value..(cap and ("/"..cap) or "");if cap and cap>0 and value>=cap then createAlert=true end end end
  if #devices==0 then lines[#lines+1]="No se encontraron lectores de Create compatibles." end
 elseif w.id=="control" then lines={"Panel de control","[U] Administrar usuarios","[L] Cerrar sesion","[A] Autostart: "..(getAutoStart() and "ACTIVADO" or "DESACTIVADO"),"HTTP API: "..tostring(http and http.get~=nil)}
 elseif w.id=="settings" then
  local monitorCount=#listExternalMonitors()
  lines={"Ajustes de Windows XP Ultimate","Flechas: elegir tema | ENTER: aplicar","S: sonidos - "..(soundEnabled and "ACTIVADOS" or "DESACTIVADOS"),"M: cambiar monitor duplicado","Computer: siempre activo","Monitor: "..(selectedDisplay=="terminal" and "sin duplicar" or selectedDisplay),"Monitores detectados: "..monitorCount,"Temas disponibles:"}
  for i,t in ipairs(themes) do lines[#lines+1]=(i==w.data.theme and "> " or "  ")..i..". "..t.name end
 elseif w.id=="taskmgr" then
  lines={"Administrador de tareas","Flechas: seleccionar | ENTER: activar","X: cerrar ventana seleccionada",""};w.data.targets={}
  for _,target in ipairs(windows) do if target~=w and not target.min then w.data.targets[#w.data.targets+1]=target end end
  if #w.data.targets==0 then lines[#lines+1]="No hay otras ventanas abiertas." else
   w.data.selected=math.max(1,math.min(#w.data.targets,w.data.selected or 1))
   for i,target in ipairs(w.data.targets) do lines[#lines+1]=(i==w.data.selected and "> " or "  ")..target.name..(target==active and " (activa)" or "") end
  end
 elseif w.id=="clock" then
  local elapsed=w.data.elapsed or 0;if w.data.running then elapsed=elapsed+math.max(0,os.clock()-w.data.started) end
  lines={"Cronometro XP","",string.format("%02d:%02d.%02d",math.floor(elapsed/60),math.floor(elapsed)%60,math.floor(elapsed*100)%100),"","SPACE: iniciar/pausar","R: reiniciar"}
 elseif w.id=="games" then lines=games.lines(d.game)
 elseif w.id=="youtube" then lines=youtube.lines(d.youtube)
 elseif w.id=="tools" then lines=tools.lines(d.tools)
 elseif w.id=="ide" then lines=ide.lines(d.ide)
 elseif w.id=="packages" then lines=packages.lines(d.packages)
 elseif w.id=="users" then lines={"Cuentas locales", "Usuario actual: "..username, "[A] Agregar cuenta local", "", "Cuentas:"};for _,u in ipairs(users) do lines[#lines+1]="- "..u.name end
 elseif w.id=="calculator" then lines={"Calculadora XP","Expresion: "..(d.expression or ""),"Resultado: "..(d.result or "Listo"),"","ENTER: calcular | + - * / % | parentesis"}
 elseif w.id=="studio" then lines=studio.lines(d.project,d.project.selected,d.project.page)
 elseif w.id=="paint" then
  lines={"Paint XP - colores 1-6 | C limpiar","Clic para dibujar | B cambiar pincel",""}
  local canvasH=math.max(1,math.min(w.h-6,H-w.y-5));for _=1,canvasH do lines[#lines+1]="" end
 elseif w.id=="system" then
  local sw,sh=term.getSize();local free="desconocido"
  if fs.getFreeSpace then local ok,v=pcall(fs.getFreeSpace,"/");if ok then free=tostring(v) end end
  lines={"Centro de informacion del sistema","","Sistema: Windows XP Ultimate CC","Entorno: "..tostring(os.version()),"Pantalla: "..sw.." x "..sh,"Hora local: "..os.date("%H:%M:%S"),"Memoria Lua: "..math.floor(collectgarbage("count")).." KB","Espacio libre: "..free,"Perifericos conectados: "..#peripheral.getNames(),"HTTP API: "..tostring(http and http.get~=nil),"","Pulsa R para actualizar."}
 elseif w.id=="media" then lines={"Windows Media Player","[P] reproducir nota de prueba","[D] reproducir archivo DFPWM desde una ruta","Speaker: "..tostring(peripheral.find("speaker")~=nil)}
 elseif w.id=="notepad" then lines={"Archivo: "..d.path,"[E] Editar texto; guarda al salir del editor","",d.text or ""}
 else lines=d.lines or {} end
 return lines
end
local function drawWindow(w)
 if w.min then return end
 local x,y,ww,hh=w.x,w.y,w.w,w.h
 local levelTheme=themes[themeIndex] and themes[themeIndex].level
 local frame=levelTheme and C.gray or C.gray
 local body=levelTheme and C.lightGray or C.white
 local title=levelTheme and C.gray or accentColor
 -- Shadows are kept inside the desktop; they must never paint over the status strip.
 if y+hh < H-2 then box(x+1,y+hh,ww,1,C.black) end
 if x+ww<=W and y+1<=H-3 then box(x+ww,y+1,1,math.max(0,math.min(hh,H-3-y)),C.gray) end
 box(x,y,ww,hh,frame);box(x+1,y+1,ww-2,hh-2,body);box(x+1,y,ww-2,1,title)
 put(x+2,y," "..clipped(w.name,math.max(1,ww-18)),C.white,title)
 put(x+ww-13,y," - ",C.white,title);put(x+ww-9,y," + ",C.white,title);put(x+ww-5,y," X ",C.white,C.red)
 if not w.max and ww>=3 and hh>=3 then put(x+ww-2,y+hh-1,"#",C.white,C.gray) end
 local y0=y+2;local bottom=math.min(H-3,y+hh-2)
 local lines=appLines(w);local max=math.max(0,#lines-(bottom-y0+1));w.scroll=math.max(0,math.min(w.scroll,max))
 if w.id=="studio" then
  local visible=bottom-y0+1;local selectedLine=(w.data.project.selected or 1)+6
  if selectedLine>w.scroll+visible then w.scroll=math.min(max,selectedLine-visible) end
  if selectedLine<=w.scroll then w.scroll=math.max(0,selectedLine-1) end
 elseif w.id=="ide" and w.data.ide.path then
  local visible=bottom-y0+1;local selectedLine=w.data.ide.y+4
  if selectedLine>w.scroll+visible then w.scroll=selectedLine-visible end
  if selectedLine<=w.scroll then w.scroll=selectedLine-1 end
 end
 for i=y0,bottom do
  local lineIndex=i-y0+1+w.scroll
  local row=lines[lineIndex]
  if w.id=="ide" and w.data.ide.path and lineIndex>=5 and lineIndex<=#w.data.ide.lines+4 then
   local codeLine=lineIndex-4;local source=w.data.ide.lines[codeLine] or ""
   local visibleCode=math.max(1,ww-8)
   if w.data.ide.x>w.data.ide.hscroll+visibleCode then w.data.ide.hscroll=w.data.ide.x-visibleCode end
   if w.data.ide.x<=w.data.ide.hscroll then w.data.ide.hscroll=w.data.ide.x-1 end
   local fg=C.black
   if source:match("^%s*%-%-") then fg=C.green
   else local first=source:match("^%s*([%a_]+)");local keywords={["local"]=true,["function"]=true,["if"]=true,["then"]=true,["else"]=true,["elseif"]=true,["end"]=true,["for"]=true,["while"]=true,["return"]=true,["do"]=true,["repeat"]=true,["until"]=true};if keywords[first] then fg=C.blue end end
   put(x+2,i,string.format("%03d ",codeLine),C.gray,C.white);put(x+6,i,source:sub(w.data.ide.hscroll+1),fg,C.white)
   if codeLine==w.data.ide.y then
    local cx=x+5+w.data.ide.x-w.data.ide.hscroll
    if cx<x+ww-1 then put(cx,i,"|",C.white,C.blue) end
   end
  elseif w.id=="paint" and lineIndex>=4 then
   local canvasRow=lineIndex-3
   for col=1,ww-4 do
    local pixel=w.data.pixels[canvasRow] and w.data.pixels[canvasRow][col]
    put(x+1+col,i,pixel and pixel.char or " ",pixel and pixel.color or C.black,C.white)
   end
  elseif w.id=="studio" and lineIndex>=7 and lineIndex<7+#w.data.project.tracks then
   local trackIndex=lineIndex-6;local track=w.data.project.tracks[trackIndex]
   local labelBg=trackIndex==w.data.project.selected and C.lightBlue or C.white
   put(x+2,i,string.format("%d %-4s ",trackIndex,tostring(track.name):sub(1,4)),C.black,labelBg)
   local color=C[track.color] or C.blue;local offset=((w.data.project.page or 1)-1)*16
   for step=1,16 do
    local enabled=track.pattern[offset+step]
    put(x+9+step-1,i,enabled and "#" or ".",enabled and C.white or C.gray,enabled and color or C.white)
   end
  elseif w.id=="youtube" and w.data.youtube.playing and lineIndex>=3 and lineIndex<=10 then
   local pixels=youtube.pixelRows(w.data.youtube)
   local pixelRow=pixels and pixels[lineIndex-2]
   if pixelRow then
    pcall(term.setCursorPos,x+2,i)
    if type(term.blit)=="function" then pcall(term.blit,pixelRow[1],pixelRow[2],pixelRow[3]) end
   end
  elseif row then put(x+2,i,row,C.black,body) end
 end
end
local function redraw()
 W,H=term.getSize()
 local parent=term.current()
 if not renderSurface or renderParent~=parent or renderWidth~=W or renderHeight~=H then
  renderParent=parent;renderWidth=W;renderHeight=H
  renderSurface=window.create(parent,1,1,W,H,false)
 end
 renderSurface.setVisible(false)
 local previousTerm=term.redirect(redirectWindow(renderSurface,parent))
 createAlert=false
 local maxH=math.max(4,H-3)
 for _,w in ipairs(windows) do
  if w.max then w.x=1;w.y=1;w.w=W;w.h=maxH
  else
   w.w=math.max(1,math.min(w.w,W));w.h=math.max(4,math.min(w.h,maxH))
   w.x=math.max(1,math.min(w.x,W-w.w+1));w.y=math.max(1,math.min(w.y,math.max(1,H-w.h-2)))
  end
 end
 for _,d in ipairs(createDevices) do for side,value in pairs(d.stress) do local cap=d.capacity[side];if cap and cap>0 and value>=cap then createAlert=true end end end
 term.setBackgroundColor(wallpaper);term.clear()
 if themes[themeIndex] and themes[themeIndex].level then
  -- Fondo pixelado inspirado en LevelOS V2.4: cielo, nubes escalonadas y campo.
  box(1,1,W,H,C.cyan)
  local cloudX=math.max(2,math.floor(W*.42));local cloudY=math.max(3,math.floor(H*.16))
  box(cloudX,cloudY,12,2,C.white);box(cloudX+3,cloudY-1,8,1,C.white);box(cloudX+2,cloudY+2,15,1,C.gray)
  local cloud2=math.max(4,math.floor(W*.78));box(cloud2,math.max(5,cloudY+4),8,2,C.white);box(cloud2+2,math.max(4,cloudY+3),4,1,C.white);box(cloud2+1,math.max(7,cloudY+6),10,1,C.gray)
  local horizon=math.max(5,math.floor(H*.62));for y=horizon,H-2 do box(1,y,W,y%2==0 and C.lime or C.green) end
  for x=4,W,9 do box(x,horizon-1,2,2,C.green) end
 else
  -- Fondo XP clásico.
  box(1,1,W,H,wallpaper)
  put(math.max(1,W-9),2,"(o)",C.yellow,C.lightBlue)
  put(math.max(1,W-22),3," .--.  .--. ",C.white,C.lightBlue)
  put(math.max(1,W-22),4,"(____)(____)",C.white,C.lightBlue)
  local horizon=math.max(3,math.floor(H*.62))
  for y=horizon,H-2 do box(1,y,W,1,C.green) end
  put(1,horizon,string.rep("~",W),C.lime,C.green)
 end
 desktopColumns=math.max(1,math.floor((W-10)/15)+1)
 desktopRows=math.max(1,math.floor((H-5)/3))
 local perPage=desktopColumns*desktopRows;local pageCount=math.max(1,math.ceil(#apps/perPage));desktopPage=math.max(0,math.min(pageCount-1,desktopPage))
 for slot=1,perPage do
  local index=desktopPage*perPage+slot;local a=apps[index]
  if a then local col=math.floor((slot-1)/desktopRows);local row=(slot-1)%desktopRows;local x=2+col*15;local y=2+row*3
   if x<W-8 and y+1<H-3 then put(x,y,a.icon,C.yellow,wallpaper);put(x,y+1,clipped(a.name,13),C.white,accentColor) end
  end
 end
 for _,w in ipairs(windows) do drawWindow(w) end
 local taskbar=themes[themeIndex] and themes[themeIndex].level and C.gray or accentColor
 box(1,H-1,W,1,taskbar);put(1,H-1,themes[themeIndex] and themes[themeIndex].level and " L " or " XP Inicio ",C.white,themes[themeIndex] and themes[themeIndex].level and C.black or C.green)
 local x=12;for _,w in ipairs(windows) do if x<W-12 then put(x,H-1,"["..clipped(w.name,10).."]",C.white,w==active and C.lightBlue or accentColor);x=x+13 end end
 if createAlert then put(math.max(10,W-29),H-1,"CREATE STALLED",C.white,C.red) end
 put(math.max(1,W-9),H-1," "..os.date("%H:%M").." ",C.white,C.blue)
 box(1,H-2,W,1,themes[themeIndex] and themes[themeIndex].level and C.black or C.lightGray);put(2,H-2,"XP Ultimate | "..status,C.white,themes[themeIndex] and themes[themeIndex].level and C.black or C.lightGray)
 put(math.max(1,W-12),H-2,string.format("Desk %d/%d",desktopPage+1,math.max(1,math.ceil(#apps/(desktopColumns*desktopRows)))),C.blue,C.lightGray)
 if menu then
  local found=matchingApps();box(1,H-9,27,8,C.lightGray);box(1,H-9,27,1,accentColor)
  put(2,H-9,"Inicio: "..(menuSearch~="" and menuSearch or username),C.white,accentColor)
  for i=1,math.min(6,#found) do put(2,H-9+i,i..". "..found[i].name,C.black,C.lightGray) end
  put(2,H-2,"0. Apagar equipo",C.white,C.green)
 end
 if inputMode then box(2,H-3,W-4,2,C.black);put(3,H-3,inputMode..": "..inputText,C.white,C.black) end
 term.redirect(previousTerm)
 -- Force the completed frame onto monitors. Some monitor implementations do
 -- not repaint reliably when an invisible window is made visible again.
 for row=1,H do
  local line,fg,bg=renderSurface.getLine(row)
  if line and fg and bg then
   pcall(parent.setCursorPos,1,row)
   if type(parent.blit)=="function" then pcall(parent.blit,line,fg,bg)
   else
    pcall(parent.setTextColor,C.white);pcall(parent.setBackgroundColor,wallpaper)
    pcall(parent.write,line)
   end
  end
 end
end
local function startInput(mode,initial,suppressChar) inputMode=mode;inputText=initial or "";suppressNextChar=suppressChar==true end
local function submitInput()
 local value=inputText;local mode=inputMode;inputMode=nil;inputText=""
 if active and active.id=="studio" and (mode=="studio-save" or mode=="studio-export" or mode=="studio-load" or mode=="studio-title" or mode=="studio-track") then
  local ok,result
  if mode=="studio-save" then ok,result=studio.save(active.data.project,value);status=ok and ("Proyecto guardado: "..value) or ("No se pudo guardar: "..tostring(result))
  elseif mode=="studio-export" then ok,result=studio.export(active.data.project,value);status=ok and ("Cancion exportada: "..value) or ("No se pudo exportar: "..tostring(result))
  elseif mode=="studio-title" then studio.renameSong(active.data.project,value);status="Titulo actualizado"
  elseif mode=="studio-track" then studio.renameTrack(active.data.project,value);status="Pista renombrada"
  else result=studio.load(value);if result then active.data.project=result;status="Proyecto cargado: "..value else status="No se pudo cargar el proyecto" end end
  return
 end
 if active and active.id=="tools" and mode=="tool-task" then
  local ok,err=tools.addTask(active.data.tools,value);status=ok and "Tarea guardada" or tostring(err);return
 end
 if active and active.id=="youtube" and mode=="youtube-search" then
  youtube.search(active.data.youtube,value);return
 end
 if active and active.id=="ide" and mode=="ide-new" then
  local ok,err=ide.newFile(active.data.ide,value);status=ok and "Programa creado" or tostring(err);return
 end
 if active and active.id=="ide" and mode=="ide-find" then
  local ok,msg=ide.find(active.data.ide,value);status=msg or (ok and "Texto encontrado" or "Sin resultados");return
 end
 if active and active.id=="ide" and mode=="ide-replace-search" then
  active.data.ide.pendingSearch=value;startInput("Texto nuevo","");inputMode="ide-replace-with";return
 end
 if active and active.id=="ide" and mode=="ide-replace-with" then
  local count,msg=ide.replaceAll(active.data.ide,active.data.ide.pendingSearch or "",value);status=msg or ("Reemplazos: "..count);active.data.ide.pendingSearch=nil;return
 end
 if not active then return end
 local d=active.data
 if active.id=="browser" then
  local page,err=browser.fetch(value);if page then d.url=page.url;d.title=page.title;d.text=page.text;d.links=page.links;status="Pagina cargada: "..page.title else d.url=value;d.title="No se pudo abrir la pagina";d.text=tostring(err).."\nComprueba HTTP y la direccion, o prueba otra busqueda.";d.links={} end
 elseif active.id=="cmd" then
  d.lines[#d.lines+1]="> "..value
  if value=="clear" then d.lines={}
  elseif value=="pwd" then d.lines[#d.lines+1]=shell.dir()
  elseif value=="ls" then for _,v in ipairs(fs.list(shell.dir())) do d.lines[#d.lines+1]=v end
  elseif value=="help" then d.lines[#d.lines+1]="Usa comandos de CraftOS (shell.run); cuidado con scripts externos."
  elseif value=="shutdown" then playSound("shutdown");os.shutdown()
  elseif value=="reboot" then os.reboot()
  elseif value~="" then
   local capture=window.create(term.current(),1,1,W,H,false)
   local previous=term.redirect(redirectWindow(capture,term.current()))
   local ok,err=pcall(shell.run,value)
   term.redirect(previous)
   if not ok then d.lines[#d.lines+1]=tostring(err) else
    local _,height=capture.getSize()
    for row=1,height do local line=capture.getLine(row);line=line:gsub("%s+$","");if line~="" then d.lines[#d.lines+1]=line end end
   end
  end
  d.command=""
 elseif active.id=="create" then
  if value:sub(1,2)=="r:" then local side,state=value:sub(3):match("^(%w+)%s+(%w+)$");local sides={top=true,bottom=true,left=true,right=true,front=true,back=true};state=state and state:lower();if sides[side or ""] and (state=="on" or state=="off") then redstone.setOutput(side,state=="on");status="Salida redstone actualizada" else status="Formato: lado on|off (ej. back on)" end
  else local index,side,rpm=value:match("^(%d+)%s+(%w+)%s+(-?%d+)$");local dev=d.devices[tonumber(index or "")]
   if dev then local ok,err=ap.setSpeed(dev.name,side,tonumber(rpm));status=ok and "Consigna enviada" or tostring(err) else status="Formato: indice lado rpm (ej. 1 top 16)" end
  end
 elseif active.id=="calculator" then
  d.expression=value;local result,err=calculator.evaluate(value);d.result=result or ("Error: "..tostring(err))
 elseif active.id=="media" then local ok,err=audio.playDfpwm(value);status=ok and "Audio finalizado" or tostring(err)
 elseif active.id=="players" then local p=ap.find("chat");if p and p.sendMessage then local ok,err=pcall(p.sendMessage,value);status=ok and "Mensaje enviado" or tostring(err) else status="Chat Box no conectado" end
 elseif active.id=="notepad" then d.text=value;local ok,err=files.write(d.path,d.text);status=ok and "Archivo guardado" or tostring(err)
 elseif active.id=="users" then users[#users+1]={name=value,pin=""};fs.makeDir("/.xpultimate");local f=fs.open(userFile,"w");f.write(textutils.serialize(users));f.close();status="Cuenta creada" end
end
local function launch(id) open(id);menu=false end
local function click(x,y)
 playSound("click")
 if menu then
  if y==H-2 then menu=false;playSound("shutdown");os.shutdown();return end
  local n=y-(H-9);local found=matchingApps();if n>=1 and n<=math.min(6,#found) and found[n] then launch(found[n].id);return end
  menu=false
 end
 if y==H-1 and x<=11 then menu=not menu;menuSearch="";return end
 if y==H-1 then local i=math.floor((x-12)/13)+1;if x>=12 and windows[i] then active=windows[i];active.min=false end;return end
 for i=#windows,1,-1 do local w=windows[i];if not w.min and x>=w.x and x<w.x+w.w and y>=w.y and y<w.y+w.h then
  active=w
  if i<#windows then table.remove(windows,i);windows[#windows+1]=w end
  if not w.max and x>=w.x+w.w-3 and y>=w.y+w.h-2 then
   w.resize={x=x,y=y,w=w.w,h=w.h};w.drag=nil;return
  end
  if y==w.y then if x>=w.x+w.w-4 then playSound("close");for j,v in ipairs(windows) do if v==w then table.remove(windows,j);break end end;active=windows[#windows]
    elseif x>=w.x+w.w-7 and x<=w.x+w.w-6 then w.max=not w.max;if w.max then w.old={w.x,w.y,w.w,w.h};w.x=1;w.y=1;w.w=W;w.h=math.max(4,H-3) else w.x,w.y,w.w,w.h=unpack(w.old) end
    elseif x>=w.x+w.w-11 and x<=w.x+w.w-10 then w.min=true
    else w.drag={x-w.x,y-w.y} end;return end
  local row=y-w.y-2+w.scroll
  if w.id=="settings" then
   local choice=y-(w.y+5)+w.scroll
  choice=choice-4
  if choice>=1 and choice<=#themes then w.data.theme=choice;themeIndex=choice;wallpaper=themes[choice].wall;accentColor=themes[choice].accent;saveSettings();status="Tema aplicado: "..themes[choice].name;return end
  elseif w.id=="taskmgr" then
   local choice=y-(w.y+5)+w.scroll
   if w.data.targets and w.data.targets[choice] then w.data.selected=choice;return end
  end
  if w.id=="studio" then
   local track=y-(w.y+7)+w.scroll;local step=x-(w.x+9)+1
   if track>=1 and track<=#w.data.project.tracks then
    studio.select(w.data.project,track)
    if step>=1 and step<=16 then studio.toggle(w.data.project,track,step+((w.data.project.page or 1)-1)*16) end
    return
   end
  end
  if w.id=="games" then games.click(w.data.game,x-(w.x+4),y-(w.y+4));return end
  if w.id=="paint" and y>=w.y+5 and y<=w.y+w.h-2 and x>=w.x+2 and x<=w.x+w.w-3 then
   local rr=y-(w.y+5)+1;local cc=x-(w.x+2)+1;w.data.pixels[rr]=w.data.pixels[rr] or {};w.data.pixels[rr][cc]={color=w.data.brush,char=w.data.brushChar or "*"}
  end
  if (w.id=="computer" or w.id=="explorer") and row>=3 then local entry=w.data.entries[row-2];if entry then if entry.dir then w.data.path=fs.combine(w.data.path,entry.name);w.scroll=0 else w.data.path=fs.combine(w.data.path,entry.name);local txt=files.read(w.data.path);if txt then open("notepad");active.data.path=w.data.path;active.data.text=txt end end end end
  return
 end end
 -- Click an icon once to launch; page keys expose additional shortcuts on small terminals.
 local col=math.floor((x-2)/15);local row=math.floor((y-2)/3)
 if x>=2 and row>=0 and row<desktopRows and col>=0 and col<desktopColumns then
  local n=desktopPage*desktopColumns*desktopRows+col*desktopRows+row+1;local a=apps[n];if a then launch(a.id) end
 end
end
local function dragWindow(x,y)
 if not active or (not active.drag and not active.resize) then return end
 if active.resize then
  local r=active.resize
  local maxW=math.max(1,W-active.x+1);local maxH=math.max(4,H-active.y-2)
  active.w=math.max(math.min(18,maxW),math.min(maxW,r.w+x-r.x))
  active.h=math.max(math.min(6,maxH),math.min(maxH,r.h+y-r.y))
  return
 end
 active.x=math.max(1,math.min(W-active.w+1,x-active.drag[1]))
 active.y=math.max(1,math.min(math.max(1,H-active.h-2),y-active.drag[2]))
end
local function key(k)
 playSound("click")
 if inputMode then if k==keys.enter then submitInput() elseif k==keys.backspace then inputText=inputText:sub(1,-2) elseif k==keys.escape then inputMode=nil;inputText="" end;return end
 if menu then
  if k==keys.escape then menu=false
  elseif k==keys.backspace then menuSearch=menuSearch:sub(1,-2)
  elseif k==keys.enter then local found=matchingApps();if found[1] then launch(found[1].id) end
  elseif k==keys.zero then playSound("shutdown");os.shutdown()
  elseif k>=keys.one and k<=keys.six then local found=matchingApps();local app=found[k-keys.one+1];if app then launch(app.id) end end
  return
 end
 if k==keys.pageUp then desktopPage=math.max(0,desktopPage-1);return end
 if k==keys.pageDown then desktopPage=desktopPage+1;return end
 if k==keys.escape then menu=false;return end
 if not active then return end
 local w=active
 if w.id=="games" then games.key(w.data.game,k);return end
 if w.id=="youtube" then
  local action=youtube.key(w.data.youtube,k,keys)
  if action=="search" then startInput("Buscar en YouTube",w.data.youtube.query,true);inputMode="youtube-search"
  elseif action=="search-play" then
   if #w.data.youtube.videos==0 then startInput("Buscar en YouTube",w.data.youtube.query,true);inputMode="youtube-search"
   else youtube.play(w.data.youtube) end
  end
  return
 end
 if w.id=="ide" then
  local action=ide.key(w.data.ide,k)
  if action=="newFile" then startInput("Nombre de archivo (ej. hola.lua)","");inputMode="ide-new"
  elseif action=="run" then local ok,msg=ide.run(w.data.ide,redirectWindow);status=msg or (ok and "Ejecucion terminada" or "Error al ejecutar")
  elseif action=="find" then startInput("Buscar","");inputMode="ide-find"
  elseif action=="replace" then startInput("Buscar texto","");inputMode="ide-replace-search"
  elseif action and action~="redraw" then status=tostring(action) end
  return
 end
 if w.id=="packages" then
  local action=packages.key(w.data.packages,k)
  if type(action)=="string" and action~="redraw" then
   local output=window.create(term.current(),1,1,W,H,false);local previous=term.redirect(redirectWindow(output,term.current()))
   local callOk,result=pcall(shell.run,action);term.redirect(previous)
   local _,height=output.getSize();w.data.packages.output={}
   for row=1,height do local line=output.getLine(row):gsub("%s+$","");if line~="" then w.data.packages.output[#w.data.packages.output+1]=line end end
   w.data.packages.status=(callOk and result~=false) and "Programa terminado" or ("Programa terminado con errores")
  elseif action and action~="redraw" then w.data.packages.status=tostring(action) end
  return
 end
 if w.id=="tools" then
  local result=tools.key(w.data.tools,k)
  if result=="addTask" then startInput("Nueva tarea", "", true);inputMode="tool-task" elseif result and result~="redraw" then status=result end
  return
 end
 if k==keys.enter then
  if w.id=="browser" then startInput("URL",w.data.url)
  elseif w.id=="cmd" then startInput("CMD","")
  elseif w.id=="calculator" then startInput("Expresion",w.data.expression or "") end
 elseif k==keys.r and w.id=="create" then w.data.devices=ap.create()
 elseif k==keys.s and w.id=="create" then startInput("Indice lado rpm","",true)
 elseif k==keys.c and w.id=="create" then startInput("Redstone lado on/off","r:",true)
 elseif k==keys.a and w.id=="browser" then startInput("URL o busqueda",w.data.url,true)
 elseif k==keys.p and w.id=="media" then local ok,err=audio.playNote(12);status=ok and "Nota reproducida" or err
 elseif k==keys.d and w.id=="media" then startInput("Ruta DFPWM","",true)
 elseif k==keys.space and w.id=="clock" then
  if w.data.running then w.data.elapsed=w.data.elapsed+math.max(0,os.clock()-w.data.started);w.data.running=false
  else w.data.started=os.clock();w.data.running=true end
 elseif k==keys.r and w.id=="clock" then w.data.elapsed=0;w.data.started=os.clock()
 elseif k==keys.s and w.id=="settings" then soundEnabled=not soundEnabled;saveSettings();status="Sonidos "..(soundEnabled and "activados" or "desactivados")
 elseif k==keys.m and w.id=="settings" then cycleDisplay()
 elseif k==keys.up and w.id=="settings" then w.data.theme=math.max(1,w.data.theme-1)
 elseif k==keys.down and w.id=="settings" then w.data.theme=math.min(#themes,w.data.theme+1)
 elseif k==keys.enter and w.id=="settings" then themeIndex=w.data.theme;wallpaper=themes[themeIndex].wall;accentColor=themes[themeIndex].accent;saveSettings();status="Tema aplicado: "..themes[themeIndex].name
 elseif k==keys.up and w.id=="taskmgr" then w.data.selected=math.max(1,(w.data.selected or 1)-1)
 elseif k==keys.down and w.id=="taskmgr" then w.data.selected=(w.data.selected or 1)+1
 elseif k==keys.enter and w.id=="taskmgr" then local target=w.data.targets and w.data.targets[w.data.selected or 1];if target then active=target;target.min=false;status="Ventana activada: "..target.name end
 elseif k==keys.x and w.id=="taskmgr" then local target=w.data.targets and w.data.targets[w.data.selected or 1];if target then for i,v in ipairs(windows) do if v==target then table.remove(windows,i);break end end;active=w;status="Ventana cerrada" end
 elseif k==keys.p and w.id=="studio" then local ok,err=studio.play(w.data.project);status=ok and "Reproduccion terminada" or err
 elseif k==keys.s and w.id=="studio" then startInput("Guardar proyecto en ruta","/xp_song.xpm",true);inputMode="studio-save"
 elseif k==keys.e and w.id=="studio" then startInput("Exportar reproductor Lua","/xp_song.lua",true);inputMode="studio-export"
 elseif k==keys.o and w.id=="studio" then startInput("Abrir proyecto .xpm","/xp_song.xpm",true);inputMode="studio-load"
 elseif k==keys.t and w.id=="studio" then startInput("Titulo de la cancion",w.data.project.title,true);inputMode="studio-title"
 elseif k==keys.r and w.id=="studio" then startInput("Nombre de la pista",w.data.project.tracks[w.data.project.selected].name,true);inputMode="studio-track"
 elseif k==keys.a and w.id=="studio" then local ok,err=studio.addTrack(w.data.project);status=ok and "Pista nueva agregada" or err
 elseif k==keys.x and w.id=="studio" then local ok,err=studio.removeTrack(w.data.project);status=ok and "Pista eliminada" or err
 elseif k==keys.i and w.id=="studio" then studio.cycleInstrument(w.data.project)
 elseif k==keys.n and w.id=="studio" then studio.cycleNote(w.data.project,1)
 elseif k==keys.m and w.id=="studio" then studio.cycleNote(w.data.project,-1)
 elseif k==keys.c and w.id=="studio" then studio.clearTrack(w.data.project)
 elseif k==keys.g and w.id=="studio" then studio.preset(w.data.project,w.data.project.preset or 0);status="Preset aplicado"
 elseif k==keys.up and w.id=="studio" then studio.select(w.data.project,w.data.project.selected-1)
 elseif k==keys.down and w.id=="studio" then studio.select(w.data.project,w.data.project.selected+1)
 elseif k==keys.left and w.id=="studio" then studio.page(w.data.project,w.data.project.page-1)
 elseif k==keys.right and w.id=="studio" then studio.page(w.data.project,w.data.project.page+1)
 elseif k==keys.backspace and (w.id=="computer" or w.id=="explorer") then w.data.path=fs.getDir(w.data.path);if w.data.path=="" then w.data.path="/" end;w.scroll=0
 elseif k==keys.e and w.id=="notepad" then startInput("Texto (sobrescribe archivo)",w.data.text,true)
 elseif k==keys.u and w.id=="control" then open("users")
 elseif k==keys.l and w.id=="control" then playSound("logoff");windows={};active=nil;logged=false
 elseif k==keys.a and w.id=="control" then setAutoStart(not getAutoStart())
 elseif k==keys.t and w.id=="control" then themeIndex=themeIndex%#themes+1;wallpaper=themes[themeIndex].wall;accentColor=themes[themeIndex].accent;saveSettings();status="Tema aplicado: "..themes[themeIndex].name
 elseif k==keys.a and w.id=="users" then startInput("Nombre de cuenta","Nuevo usuario",true)
 elseif k==keys.m and w.id=="players" then startInput("Mensaje para Chat Box","",true)
 elseif k==keys.r and w.id=="system" then w.data.refresh=os.clock()
 elseif w.id=="paint" and k>=keys.one and k<=keys.six then w.data.brush=paintColors[k-keys.one+1]
 elseif w.id=="paint" and k==keys.c then w.data.pixels={}
 elseif w.id=="paint" and k==keys.b then w.data.brushChar=(w.data.brushChar=="*" and "#" or "*")
 end
end
local function char(c)
 if suppressNextChar then suppressNextChar=false;return end
 if inputMode then inputText=inputText..c
 elseif menu then menuSearch=menuSearch..c
 elseif active and active.id=="studio" then
  if c=="+" or c=="=" then studio.tempo(active.data.project,5)
  elseif c=="-" then studio.tempo(active.data.project,-5) end
 elseif active and active.id=="ide" then ide.char(active.data.ide,c)
 end
end
local preferredDisplay=nil
if fs.exists(monitorSetting) then
 local file=fs.open(monitorSetting,"r")
 if file then preferredDisplay=file.readAll():gsub("%s+$","");file.close() end
end
if not preferredDisplay or preferredDisplay=="" then
 local available=listExternalMonitors()
 preferredDisplay=available[1] and available[1].name or "terminal"
end
applyDisplay(preferredDisplay,false)
term.redirect(mirrorTerminal)
boot()
while not logged do if login() then logged=true end end
createDevices=ap.create()
redraw()
local clockTimer=os.startTimer(1)
local videoTimer=os.startTimer(0.34)
local peripheralTimer=os.startTimer(5)
while true do
 if not logged then login();logged=true;redraw() end
 local ev={os.pullEvent()}
 if ev[1]=="term_resize" then redraw()
 elseif ev[1]=="monitor_resize" then
  if ev[2]==selectedDisplay then W,H=term.getSize();renderSurface=nil;redraw() end
 elseif ev[1]=="monitor_touch" then
  if ev[2]==selectedDisplay then click(ev[3],ev[4]);redraw() end
 elseif ev[1]=="peripheral_detach" then
  if ev[2]==selectedDisplay then applyDisplay("terminal",true);status="Monitor desconectado; usando terminal CraftOS" end
  redraw()
 elseif ev[1]=="peripheral" then
  if selectedDisplay=="terminal" then
   local available=listExternalMonitors()
   if available[1] then applyDisplay(available[1].name,true);status="Monitor duplicado: "..selectedDisplay end
  end
  redraw()
 elseif ev[1]=="mouse_click" then click(ev[3],ev[4]);redraw()
 elseif ev[1]=="mouse_drag" then dragWindow(ev[3],ev[4]);redraw()
 elseif ev[1]=="mouse_up" then if active then active.drag=nil;active.resize=nil end
 elseif ev[1]=="key" then key(ev[2]);redraw()
 elseif ev[1]=="char" then char(ev[2]);redraw()
 elseif ev[1]=="timer" and ev[2]==clockTimer then
  for _,w in ipairs(windows) do if w.id=="games" then games.update(w.data.game) end end
  redraw();clockTimer=os.startTimer(1)
 elseif ev[1]=="timer" and ev[2]==videoTimer then
  local changed=false
  for _,w in ipairs(windows) do
   if w.id=="youtube" and youtube.poll(w.data.youtube) then changed=true end
  end
  if changed then redraw() end
  videoTimer=os.startTimer(0.34)
 elseif ev[1]=="timer" and ev[2]==peripheralTimer then
  createDevices=ap.create();redraw();peripheralTimer=os.startTimer(5)
 end
end
]=]
payload["/sys/sounds.lua"] = [=[
-- Efectos originales, suaves y sintetizados para XP Ultimate CC.
-- No usa HTTP ni archivos externos: funciona con cualquier speaker de CC:Tweaked.
local M = {}
local function note(instrument, pitch, volume)
  local speaker = peripheral and peripheral.find and peripheral.find("speaker")
  if not speaker then return false end
  return pcall(speaker.playNote, instrument or "chime", volume or 0.35, pitch or 18)
end
function M.play(effect)
  if effect == "click" then return note("pling", 19, 0.18)
  elseif effect == "open" then note("chime", 16, 0.28); return note("chime", 21, 0.22)
  elseif effect == "close" then note("chime", 20, 0.24); return note("chime", 15, 0.2)
  elseif effect == "logoff" then
    note("bell", 19, 0.3); sleep(0.12); note("bell", 16, 0.28); sleep(0.12); return note("bell", 12, 0.24)
  elseif effect == "shutdown" then
    note("chime", 17, 0.3); sleep(0.13); note("chime", 13, 0.27); sleep(0.13); return note("chime", 9, 0.22)
  elseif effect == "startup" then
    note("chime", 12, 0.28); sleep(0.12); note("chime", 16, 0.3); sleep(0.12)
    note("bell", 19, 0.3); sleep(0.12); note("chime", 23, 0.32); sleep(0.16)
    return note("bell", 19, 0.26)
  end
  return false
end
return M
]=]
payload["/drivers/peripherals.lua"] = [=[
-- XP Ultimate CC: deteccion segura de perifÃ©ricos (nombres legacy y actuales).
local M = {}
local aliases = {
  player = {"player_detector", "playerDetector"},
  environment = {"environment_detector", "environmentDetector"},
  chat = {"chat_box", "chatBox"},
  me = {"me_bridge", "meBridge"},
  colony = {"colony_integrator", "colonyIntegrator"},
}

function M.devices()
  local out = {}
  for _, name in ipairs(peripheral.getNames()) do
    local ok, kind = pcall(peripheral.getType, name)
    out[#out + 1] = {name = name, kind = ok and (type(kind) == "table" and table.concat(kind, ", ") or tostring(kind)) or "unknown"}
  end
  table.sort(out, function(a, b) return a.name < b.name end)
  return out
end

function M.find(group)
  for _, kind in ipairs(aliases[group] or {group}) do
    local ok, p = pcall(peripheral.find, kind)
    if ok and p then return p, kind end
  end
end

function M.environment()
  local p = M.find("environment")
  if not p then return nil, "Environment Detector no conectado" end
  local data = {}
  local methods = {"getBiome", "getDimension", "getTime", "getMoonName", "getDayLightLevel", "getBlockLightLevel", "isRaining", "isSunny", "isThunder"}
  for _, method in ipairs(methods) do
    if type(p[method]) == "function" then
      local ok, value = pcall(p[method])
      if ok then data[method] = value end
    end
  end
  return data
end

function M.players()
  local p = M.find("player")
  if not p then return nil, "Player Detector no conectado" end
  local fn = p.getOnlinePlayers
  local ok, list
  if fn then ok, list = pcall(fn)
  elseif p.getPlayersInRange then ok, list = pcall(p.getPlayersInRange, 64)
  else return nil, "Este modelo no ofrece listado de jugadores" end
  if not ok then return nil, tostring(list) end
  local result = {}
  for _, name in ipairs(list or {}) do
    local row = {name = tostring(name)}
    if p.getPlayerPos then
      local good, pos = pcall(p.getPlayerPos, name)
      if good and type(pos) == "table" then row.pos = pos end
    elseif p.getPlayer then
      local good, pos = pcall(p.getPlayer, name)
      if good and type(pos) == "table" then row.pos = pos end
    end
    result[#result + 1] = row
  end
  return result
end

function M.me()
  local p = M.find("me")
  if not p then return nil, "ME Bridge no conectado" end
  local out = {}
  for _, method in ipairs({"getEnergyStorage", "getEnergyUsage", "getUsedItemStorage", "getTotalItemStorage", "getUsedFluidStorage", "getTotalFluidStorage"}) do
    if type(p[method]) == "function" then
      local ok, value = pcall(p[method])
      if ok then out[method] = value end
    end
  end
  return out
end

function M.create()
  local out = {}
  for _, d in ipairs(M.devices()) do
    local ok, p = pcall(peripheral.wrap, d.name)
    if ok and p then
      local row = {name=d.name, kind=d.kind, speed={}, stress={}, capacity={}}
      for _, side in ipairs({"top", "bottom", "left", "right", "front", "back"}) do
        for _, method in ipairs({"getSpeed", "getKineticSpeed", "getTargetSpeed"}) do
          if type(p[method]) == "function" then
            local good, value = pcall(p[method], side)
            if not good then good, value = pcall(p[method]) end
            if good and type(value) == "number" then row.speed[side] = value; break end
          end
        end
        for _, method in ipairs({"getKineticStress", "getStress"}) do
          if type(p[method]) == "function" then
            local good, value = pcall(p[method], side)
            if not good then good, value = pcall(p[method]) end
            if good and type(value) == "number" then row.stress[side] = value; break end
          end
        end
        for _, method in ipairs({"getKineticCapacity", "getStressCapacity"}) do
          if type(p[method]) == "function" then
            local good, value = pcall(p[method], side)
            if not good then good, value = pcall(p[method]) end
            if good and type(value) == "number" then row.capacity[side] = value; break end
          end
        end
      end
      row.peripheral = p
      out[#out + 1] = row
    end
  end
  return out
end

function M.setSpeed(name, side, speed)
  local p = peripheral.wrap(name)
  if not p then return false, "PerifÃ©rico desconectado" end
  speed = math.max(-256, math.min(256, math.floor(tonumber(speed) or 0)))
  if type(p.setTargetSpeed) == "function" then
    local ok, err = pcall(p.setTargetSpeed, side, speed)
    if ok then return true end
    return false, tostring(err)
  elseif type(p.setSpeed) == "function" then
    local ok, err = pcall(p.setSpeed, speed)
    if ok then return true end
    return false, tostring(err)
  end
  return false, "Este dispositivo no permite ajustar velocidad"
end

return M
]=]
payload["/apps/youtube.lua"] = [=[
-- Cliente para la pasarela local youtube_bridge.py (CraftOS-PC).
-- En CC:Tweaked sin Graphics Mode se conserva la interfaz de lista y estado.
local M = {}
local BASE = "http://127.0.0.1:8765"

local function encode(value)
  return (tostring(value or ""):gsub("([^%w%-_%.~])", function(char)
    return string.format("%%%02X", string.byte(char))
  end))
end

local function request(path, binary)
  if not http or type(http.get) ~= "function" then
    return nil, "La API HTTP de CraftOS esta desactivada."
  end
  local ok, response, err = pcall(http.get, BASE .. path, nil, binary == true)
  if not ok then return nil, tostring(response) end
  if not response then return nil, tostring(err or "No hay respuesta del servicio local.") end
  local readOk, body = pcall(response.readAll)
  pcall(response.close)
  if not readOk then return nil, tostring(body) end
  return body
end

local function json(path)
  local body, err = request(path)
  if not body then return nil, err end
  local ok, value = pcall(textutils.unserializeJSON, body)
  if not ok or type(value) ~= "table" then return nil, "Respuesta invalida de youtube_bridge.py." end
  if value.error then return nil, tostring(value.error) end
  return value
end

function M.new()
  return {query="", videos={}, selected=1, title="", playing=false,
    frame=nil, frameAt=0, status="Inicia youtube_bridge.py en el PC y pulsa R.",
    graphics=type(term.setGraphicsMode)=="function" and type(term.drawPixels)=="function"}
end

function M.search(state, query)
  query = tostring(query or state.query or ""):gsub("^%s+", ""):gsub("%s+$", "")
  if query == "" then state.status="Escribe una busqueda primero.";return false end
  state.query=query
  local result,err=json("/search?q="..encode(query))
  if not result then state.status="Busqueda no disponible: "..tostring(err);return false end
  state.videos={};for i=1,math.min(5,#(result.videos or {})) do state.videos[i]=result.videos[i] end
  state.selected=1;state.status="Resultados: "..#state.videos
  if #state.videos==0 then state.status="No se encontraron videos." end
  return true
end

function M.play(state)
  local video=state.videos[state.selected]
  if not video then state.status="Selecciona un video de la lista.";return false end
  local result,err=json("/play?id="..encode(video.id))
  if not result then state.status="No se pudo reproducir: "..tostring(err);return false end
  state.title=video.title or "YouTube"
  state.playing=true;state.frame=nil;state.frameAt=0;state.status="Reproduciendo: "..state.title
  return true
end

function M.stop(state)
  local result,err=json("/stop")
  state.playing=false;state.frame=nil
  state.status=result and "Reproduccion detenida." or ("No se pudo detener: "..tostring(err))
end

function M.poll(state)
  if not state.playing or os.clock()-state.frameAt<0.35 then return false end
  state.frameAt=os.clock()
  local frame,err=request("/frame",true)
  if frame and #frame==32*8*3 then state.frame=frame
  elseif err then state.status="Perdi la conexion con la pasarela: "..tostring(err);state.playing=false end
  return true
end

function M.lines(state)
  local lines={"XP YouTube | video por pixeles y audio del PC",
    "Estado: "..tostring(state.status)}
  if state.playing then
    for _=1,8 do lines[#lines+1]="" end
    lines[#lines+1]="Ahora: "..tostring(state.title)
    lines[#lines+1]="X detener | R buscar otro video"
    return lines
  end
  lines[#lines+1]="R buscar | Flechas elegir | ENTER reproducir | X detener"
  lines[#lines+1]=""
  if #state.videos==0 then
    lines[#lines+1]="Sin resultados cargados. Pulsa R y escribe una busqueda."
    lines[#lines+1]="Servicio requerido: youtube_bridge.py en el PC."
  else
    for i=1,math.min(#state.videos,5) do
      local video=state.videos[i]
      lines[#lines+1]=(i==state.selected and "> " or "  ")..i..". "..tostring(video.title or "Video")
    end
  end
  lines[#lines+1]=""
  lines[#lines+1]=state.playing and ("Ahora: "..tostring(state.title)) or ""
  lines[#lines+1]="CraftOS-PC: video por pixeles | Minecraft: controles sin video."
  return lines
end

function M.pixelRows(state)
  if not state.frame then return nil end
  -- Un espacio coloreado por celda funciona incluso en terminales CC sin Unicode.
  -- El orden es el de los bits de colores de CC:Tweaked; toBlit da el codigo exacto.
  local rgb={
    {240,240,240},{242,178,51},{229,127,216},{153,178,242},{222,222,108},{127,204,25},{242,178,204},{76,76,76},
    {153,153,153},{76,153,178},{178,102,229},{51,102,204},{127,102,51},{87,166,78},{204,76,76},{17,17,17}
  }
  local blit={}
  local ccColors={colors.white,colors.orange,colors.magenta,colors.lightBlue,colors.yellow,colors.lime,colors.pink,colors.gray,
    colors.lightGray,colors.cyan,colors.purple,colors.blue,colors.brown,colors.green,colors.red,colors.black}
  for i,color in ipairs(ccColors) do blit[i]=colors.toBlit(color) end
  local function nearest(r,g,b)
    local best,bestD=1,math.huge
    for i,p in ipairs(rgb) do local dr,dg,db=r-p[1],g-p[2],b-p[3];local d=dr*dr+dg*dg+db*db
      if d<bestD then best,bestD=i,d end
    end
    return best
  end
  local rows={}
  for y=0,7 do
    local chars,fg,bg={},{},{}
    for x=0,31 do
      local pixel=(y*32+x)*3+1
      local color=blit[nearest(state.frame:byte(pixel) or 0,state.frame:byte(pixel+1) or 0,state.frame:byte(pixel+2) or 0)]
      chars[#chars+1]=" ";fg[#fg+1]=color;bg[#bg+1]=color
    end
    rows[y+1]={table.concat(chars),table.concat(fg),table.concat(bg)}
  end
  return rows
end

function M.key(state,key,keys)
  if key==keys.up then state.selected=math.max(1,state.selected-1)
  elseif key==keys.down then state.selected=math.min(#state.videos,state.selected+1)
  elseif key==keys.enter then return "search-play"
  elseif key==keys.r then return "search"
  elseif key==keys.x then M.stop(state);return "redraw" end
  return "redraw"
end

return M
]=]
payload["/apps/browser.lua"] = [=[
-- Visor web textual compatible con respuestas HTML UTF-8 comunes.
-- No ejecuta JavaScript ni renderiza CSS, imagenes o contenido multimedia.
local M = {}

local function decode(s)
  s = s:gsub("<[!][%-%-].-%-%->", " ")
  s = s:gsub("<[sS][cC][rR][iI][pP][tT][^>]*>.-</[sS][cC][rR][iI][pP][tT]%s*>", " ")
  s = s:gsub("<[sS][tT][yY][lL][eE][^>]*>.-</[sS][tT][yY][lL][eE]%s*>", " ")
  s = s:gsub("<[bB][rR]%s*/?>", "\n")
  s = s:gsub("</[pP]%s*>", "\n\n"):gsub("</[lL][iI]%s*>", "\n")
  s = s:gsub("</[dD][iI][vV]%s*>", "\n"):gsub("</[hH]%d%s*>", "\n")
  s = s:gsub("<[lL][iI][^>]*>", "* ")
  s = s:gsub("<[^>]->", " ")
  local entities = {
    ["&nbsp;"]=" ",["&amp;"]="&",["&lt;"]="<",["&gt;"]=">",["&quot;"]='"',
    ["&#39;"]="'",["&apos;"]="'",["&copy;"]="(c)",["&reg;"]="(R)",
    ["&eacute;"]="e",["&Eacute;"]="E",["&aacute;"]="a",["&Aacute;"]="A",
    ["&iacute;"]="i",["&oacute;"]="o",["&uacute;"]="u",["&ntilde;"]="n",
    ["&hellip;"]="...",["&ndash;"]="-",["&mdash;"]="-",["&rsquo;"]="'",["&rdquo;"]='"',
  }
  for from,to in pairs(entities) do s=s:gsub(from,to) end
  s = s:gsub("&#(%d+);", function(n) local v=tonumber(n);return v and v>31 and v<127 and string.char(v) or "?" end)
  local accents = {
    ["\195\161"]="a",["\195\169"]="e",["\195\173"]="i",["\195\179"]="o",["\195\186"]="u",["\195\177"]="n",
    ["\195\129"]="A",["\195\137"]="E",["\195\141"]="I",["\195\147"]="O",["\195\154"]="U",["\195\145"]="N",
    ["\194\161"]="",["\194\191"]="",["\226\128\147"]="-",["\226\128\148"]="-",["\226\128\153"]="'",
    ["\226\128\156"]='"',["\226\128\157"]='"',["\226\128\166"]="...",
  }
  for from,to in pairs(accents) do s=s:gsub(from,to) end
  s = s:gsub("[\128-\255]", "?"):gsub("[ \t\r]+", " "):gsub("\n *\n *\n+", "\n\n"):gsub("\n +", "\n")
  return s
end

local function encodeQuery(s)
  return (s:gsub("([^%w%-_%.~])", function(c) return string.format("%%%02X", string.byte(c)) end))
end

function M.normalizeUrl(input)
  input = tostring(input or ""):gsub("^%s+", ""):gsub("%s+$", "")
  if input:match("^https?://") then return input end
  if input:match("^[%w%-%.]+%.[%a]+[:/%?#]?.*$") then return "https://" .. input end
  return "https://www.google.es/search?q=" .. encodeQuery(input)
end

function M.fetch(input)
  if not http or not http.get then return nil, "HTTP esta desactivado en CraftOS-PC." end
  local url = M.normalizeUrl(input)
  local ok, response, err = pcall(http.get, url, { ["User-Agent"] = "Mozilla/5.0 (compatible; XP-Ultimate-CC/1.0)" }, false)
  if not ok then return nil, tostring(response) end
  if not response then return nil, tostring(err or "No se pudo conectar con el sitio.") end
  local good, html = pcall(response.readAll)
  pcall(response.close)
  if not good then return nil, tostring(html) end
  html = tostring(html):sub(1, 250000)
  local title = html:match("<[tT][iI][tT][lL][eE][^>]*>(.-)</[tT][iI][tT][lL][eE]>") or url
  local links = {}
  for href, label in html:gmatch('<[aA][^>]-[hH][rR][eE][fF]=["\']([^"\']+)["\'][^>]*>(.-)</[aA]%s*>') do
    if #links < 40 then
      local text = decode(label):gsub("\n", " "):gsub("^%s+", ""):gsub("%s+$", "")
      if text ~= "" then links[#links + 1] = {url=href, title=text} end
    end
  end
  return {url=url, title=decode(title), text=decode(html), links=links}
end

return M
]=]
payload["/apps/files.lua"] = [=[
local M = {}
function M.list(path)
  path = fs.combine("/", path or "")
  local out = {}
  local ok, names = pcall(fs.list, path)
  if not ok then return nil, tostring(names) end
  table.sort(names, function(a,b)
    local ad, bd = fs.isDir(fs.combine(path,a)), fs.isDir(fs.combine(path,b))
    if ad ~= bd then return ad end
    return a:lower() < b:lower()
  end)
  for _, name in ipairs(names) do out[#out+1] = {name=name, dir=fs.isDir(fs.combine(path,name))} end
  return out, path
end
function M.read(path)
  local f, err = fs.open(path, "r")
  if not f then return nil, err end
  local data = f.readAll(); f.close(); return data
end
function M.write(path, data)
  local dir = fs.getDir(path)
  if dir ~= "" and not fs.exists(dir) then fs.makeDir(dir) end
  local f, err = fs.open(path, "w")
  if not f then return false, err end
  f.write(data); f.close(); return true
end
return M
]=]
payload["/apps/audio.lua"] = [=[
local M = {}
function M.playNote(note, instrument, volume)
  local speaker = peripheral.find("speaker")
  if not speaker then return false, "No hay speaker conectado" end
  local ok, err = pcall(speaker.playNote, instrument or "harp", volume or 1, note or 12)
  if not ok then return false, tostring(err) end
  return true
end
function M.playDfpwm(path)
  if not require or not peripheral.find("speaker") then return false, "No hay speaker conectado" end
  local ok, decoder = pcall(require, "cc.audio.dfpwm")
  if not ok then return false, "Este CC:Tweaked no incluye el decodificador DFPWM" end
  local file, err = fs.open(path, "rb")
  if not file then return false, tostring(err) end
  local speaker = peripheral.find("speaker")
  local decode = decoder.make_decoder()
  while true do
    local chunk = file.read(16 * 1024)
    if not chunk then break end
    local audio = decode(chunk)
    while not speaker.playAudio(audio) do os.pullEvent("speaker_audio_empty") end
  end
  file.close(); return true
end
return M
]=]
payload["/apps/studio.lua"] = [=[
-- Secuenciador personalizable inspirado en FL Studio, para CC:Tweaked.
local M = {}
local instruments={"harp","pling","chime","bell","flute","xylophone","iron_xylophone","guitar","bass","banjo"}
local trackNames={"Melodia","Acordes","Bajo","Brillo","Percusion","Arpegio","Pads","Extra"}
local colors={"cyan","lime","orange","pink","yellow","lightBlue","purple","red"}
local function blankPattern() local p={};for i=1,32 do p[i]=false end;return p end

function M.new()
  local song={title="Mi primera pista",bpm=120,steps=32,selected=1,page=1,tracks={}}
  for i=1,4 do
    local pattern=blankPattern();pattern[1]=true
    if i==1 then pattern[5]=true;pattern[9]=true;pattern[13]=true end
    if i==3 then pattern[9]=true end
    song.tracks[i]={name=trackNames[i],instrument=instruments[i],note=({24,19,12,22})[i],pattern=pattern,color=colors[i]}
  end
  return song
end

function M.lines(song,selected,page)
  local tracks=song.tracks or {};selected=math.max(1,math.min(#tracks,selected or song.selected or 1));page=page or song.page or 1
  local lines={"FL Studio XP | "..tostring(song.title),"P Play  S Save  E Export  O Abrir","A+ pista X- pista I inst N nota","C limpia G preset T titulo R pista","M nota- | Flechas: pista/pagina","BPM "..song.bpm.." | Pag "..page.."/2 | Pista "..selected.."/"..#tracks}
  local offset=(page-1)*16
  for i,track in ipairs(tracks) do
    local cells=""
    for step=1,16 do cells=cells..(track.pattern[offset+step] and "#" or ".") end
    lines[#lines+1]=string.format("%d %-4s %s",i,tostring(track.name):sub(1,4),cells)
  end
  local current=tracks[selected]
  lines[#lines+1]=""
  if current then lines[#lines+1]="Editando: "..current.name.." | "..current.instrument.." | Nota "..current.note end
  lines[#lines+1]="Click pasos | [+/-] tempo | export Lua portable"
  return lines
end

function M.toggle(song,track,step)
  local row=song.tracks[track];if not row or step<1 or step>(song.steps or 32) then return false end
  row.pattern[step]=not row.pattern[step];song.selected=track;return true
end
function M.play(song)
  local speaker=peripheral.find("speaker");if not speaker then return false,"Conecta un speaker para reproducir" end
  local delay=15/math.max(40,math.min(240,tonumber(song.bpm) or 120))
  for step=1,(song.steps or 32) do
    for _,track in ipairs(song.tracks or {}) do
      if track.pattern[step] then pcall(speaker.playNote,track.instrument or "harp",0.7,tonumber(track.note) or 18) end
    end
    sleep(delay)
  end
  return true
end
local function readSong(path)
  local file,err=fs.open(path,"r");if not file then return nil,err end
  local raw=file.readAll();file.close();local ok,song=pcall(textutils.unserialize,raw)
  if not ok or type(song)~="table" or type(song.tracks)~="table" then return nil,"El archivo no es un proyecto XP valido" end
  song.steps=math.max(16,math.min(32,tonumber(song.steps) or 32));song.bpm=math.max(40,math.min(240,tonumber(song.bpm) or 120))
  song.selected=math.max(1,math.min(#song.tracks,tonumber(song.selected) or 1));song.page=math.max(1,math.min(2,tonumber(song.page) or 1))
  for _,track in ipairs(song.tracks) do if type(track.pattern)~="table" then track.pattern=blankPattern() end end
  return song
end
function M.save(song,path)
  local file,err=fs.open(path,"w");if not file then return false,err end
  file.write(textutils.serialize(song));file.close();return true
end
function M.load(path) return readSong(path) end
function M.export(song,path)
  local serialized=textutils.serialize(song)
  local code="-- Cancion exportada desde FL Studio XP. Copiala a otro CC:Tweaked y ejecutala.\n"
    .."local song=textutils.unserialize("..textutils.serialize(serialized)..")\n"
    .."local speaker=peripheral.find('speaker')\nif not speaker then print('Conecta un speaker para reproducir.'); return end\n"
    .."local bpm=math.max(40,math.min(240,tonumber(song.bpm) or 120))\n"
    .."for step=1,(song.steps or 32) do\n  for _,track in ipairs(song.tracks or {}) do\n"
    .."    if track.pattern[step] then pcall(speaker.playNote,track.instrument or 'harp',0.7,tonumber(track.note) or 18) end\n"
    .."  end\n  sleep(15/bpm)\nend\nprint('Reproduccion terminada.')\n"
  local file,err=fs.open(path,"w");if not file then return false,err end
  file.write(code);file.close();return true
end

function M.tempo(song,delta) song.bpm=math.max(40,math.min(240,(tonumber(song.bpm) or 120)+delta)) end
function M.select(song,index) song.selected=math.max(1,math.min(#song.tracks,index));return song.selected end
function M.page(song,page) song.page=math.max(1,math.min(2,page));return song.page end
function M.addTrack(song)
  if #song.tracks>=8 then return false,"Maximo 8 pistas" end
  local i=#song.tracks+1;song.tracks[i]={name=trackNames[i] or ("Pista"..i),instrument=instruments[(i-1)%#instruments+1],note=12+i,pattern=blankPattern(),color=colors[(i-1)%#colors+1]};song.selected=i
  return true
end
function M.removeTrack(song)
  if #song.tracks<=1 then return false,"Debe quedar al menos una pista" end
  table.remove(song.tracks,song.selected or #song.tracks);song.selected=math.max(1,math.min(#song.tracks,song.selected or 1));return true
end
function M.cycleInstrument(song)
  local track=song.tracks[song.selected];if not track then return end
  local current=1;for i,name in ipairs(instruments) do if name==track.instrument then current=i;break end end
  track.instrument=instruments[current%#instruments+1]
end
function M.cycleNote(song,delta)
  local track=song.tracks[song.selected];if track then track.note=math.max(0,math.min(24,(tonumber(track.note) or 12)+delta)) end
end
function M.clearTrack(song)
  local track=song.tracks[song.selected];if track then track.pattern=blankPattern() end
end
function M.renameTrack(song,name)
  local track=song.tracks[song.selected];if track then track.name=tostring(name):sub(1,12) end
end
function M.renameSong(song,name) song.title=tostring(name):sub(1,24) end
function M.preset(song,index)
  local presets={
    {{1,5,9,13},{1,9},{1,9},{5,13}},
    {{1,4,7,11,15},{1,5,9,13},{1,7,9,15},{3,11}},
    {{1,9},{1,5,9,13},{1,5,9,13},{4,8,12,16}},
  }
  index=index%#presets+1
  for ti,track in ipairs(song.tracks) do
    track.pattern=blankPattern()
    local beat=presets[index][(ti-1)%#presets[index]+1]
    for _,step in ipairs(beat) do track.pattern[step]=true end
  end
  song.preset=index
end
return M
]=]
payload["/apps/games.lua"] = [=[
-- Mini-juegos para el escritorio XP, dibujados con caracteres de terminal.
local M={}
local function empty4() local b={};for y=1,4 do b[y]={0,0,0,0} end;return b end
local function spawn(b)
 local free={};for y=1,4 do for x=1,4 do if b[y][x]==0 then free[#free+1]={x,y} end end end
 if #free>0 then local p=free[math.random(#free)];b[p[2]][p[1]]=math.random(10)==1 and 4 or 2 end
end
local function new2048()
 local b=empty4();spawn(b);spawn(b);return {mode="2048",board=b,score=0,over=false,won=false}
end
local function newTic()
 local b={{" "," "," "},{" "," "," "},{" "," "," "}}
 return {mode="tic",board=b,turn="X",winner=nil}
end
local function newReaction() return {mode="reaction",ready=false,start=0,result=nil} end
local function newGuess() return {mode="guess",target=math.random(1,10),tries=0,history={}} end
local function newDice() return {mode="dice",round=0,player=0,cpu=0,last="Pulsa ESPACIO para lanzar"} end
function M.new() return {mode="menu",game=nil} end
function M.choose(state,choice)
 if choice==1 then state.game=new2048();state.mode="2048"
 elseif choice==2 then state.game=newTic();state.mode="tic"
 elseif choice==3 then state.game=newReaction();state.mode="reaction" end
 if choice==4 then state.game=newGuess();state.mode="guess"
 elseif choice==5 then state.game=newDice();state.mode="dice" end
end
local function ticWinner(b)
 local lines={{b[1][1],b[1][2],b[1][3]},{b[2][1],b[2][2],b[2][3]},{b[3][1],b[3][2],b[3][3]},
  {b[1][1],b[2][1],b[3][1]},{b[1][2],b[2][2],b[3][2]},{b[1][3],b[2][3],b[3][3]},
  {b[1][1],b[2][2],b[3][3]},{b[1][3],b[2][2],b[3][1]}}
 for _,l in ipairs(lines) do if l[1]~=" " and l[1]==l[2] and l[2]==l[3] then return l[1] end end
 for y=1,3 do for x=1,3 do if b[y][x]==" " then return nil end end end
 return "Empate"
end
function M.click(state,x,y)
 local g=state.game;if not g then return end
 if g.mode=="tic" and not g.winner then
  local col=math.floor((x-1)/4)+1;local row=math.floor((y-1)/2)+1
  if row>=1 and row<=3 and col>=1 and col<=3 and g.board[row][col]==" " then
   g.board[row][col]=g.turn;g.winner=ticWinner(g.board);g.turn=g.turn=="X" and "O" or "X"
  end
 elseif g.mode=="reaction" then
  if not g.ready then g.result="Espera a que se ilumine el aviso." else g.result=string.format("Tiempo: %.3f s",os.clock()-g.start);g.ready=false end
 end
end
local function lineCells(b,dir,line)
 local cells={}
 for i=1,4 do
  if dir=="left" then cells[i]={line,i} elseif dir=="right" then cells[i]={line,5-i}
  elseif dir=="up" then cells[i]={i,line} else cells[i]={5-i,line} end
 end
 return cells
end
local function slide(g,dir)
 local b=g.board;local changed=false
 for line=1,4 do
  local coords=lineCells(b,dir,line);local vals={}
  for _,p in ipairs(coords) do local v=b[p[1]][p[2]];if v~=0 then vals[#vals+1]=v end end
  local merged={};local out={};local i=1
  while i<=#vals do
   if vals[i]==vals[i+1] then out[#out+1]=vals[i]*2;g.score=g.score+vals[i]*2;i=i+2 else out[#out+1]=vals[i];i=i+1 end
  end
  for k,p in ipairs(coords) do local value=out[k] or 0;if b[p[1]][p[2]]~=value then changed=true end;b[p[1]][p[2]]=value end
 end
 if changed then spawn(b) end
 local moves=false;local hasWin=false
 for y=1,4 do for x=1,4 do local v=b[y][x];if v==2048 then hasWin=true end;if v==0 then moves=true end
  if x<4 and v==b[y][x+1] then moves=true end;if y<4 and v==b[y+1][x] then moves=true end
 end end
 g.won=g.won or hasWin;g.over=not moves
end
function M.key(state,key)
 if state.mode=="menu" then
  if key==keys.one then M.choose(state,1) elseif key==keys.two then M.choose(state,2) elseif key==keys.three then M.choose(state,3) elseif key==keys.four then M.choose(state,4) elseif key==keys.five then M.choose(state,5) end;return
 end
 local g=state.game;if not g then return end
 if key==keys.escape then state.mode="menu";state.game=nil;return end
 if g.mode=="2048" and key==keys.r then state.game=new2048();return end
 if g.mode=="guess" then
  if key==keys.r then state.game=newGuess()
  elseif key>=keys.one and key<=keys.nine then
   local n=key-keys.one+1;g.tries=g.tries+1
   local hint=n==g.target and "Correcto!" or (n<g.target and "Mas alto" or "Mas bajo")
   g.history[#g.history+1]=tostring(n)..": "..hint
   if #g.history>5 then table.remove(g.history,1) end
   if n==g.target then g.won=true end
  elseif key==keys.zero then g.tries=g.tries+1;local n=10;g.history[#g.history+1]="10: "..(n==g.target and "Correcto!" or (n<g.target and "Mas alto" or "Mas bajo"));if n==g.target then g.won=true end end
  return
 end
 if g.mode=="dice" and (key==keys.space or key==keys.enter) and g.round<5 then
  local player=math.random(1,6);local cpu=math.random(1,6);g.round=g.round+1
  if player>cpu then g.player=g.player+1 elseif cpu>player then g.cpu=g.cpu+1 end
  g.last="Ronda "..g.round..": tu "..player.." - CPU "..cpu
  return
 end
 if g.mode=="2048" and not g.over then
  if key==keys.left then slide(g,"left") elseif key==keys.right then slide(g,"right") elseif key==keys.up then slide(g,"up") elseif key==keys.down then slide(g,"down") end
 elseif g.mode=="reaction" and key==keys.r then g.ready=false;g.start=os.clock()+math.random(1,4);g.result="Preparado... espera la senal" end
end
function M.update(state)
 local g=state.game
 if g and g.mode=="reaction" and not g.ready and g.start>0 and os.clock()>=g.start then g.ready=true;g.start=os.clock();g.result="AHORA: haz clic" end
end
function M.lines(state)
 local g=state.game
 if state.mode=="menu" then return {"Juegos XP","","1. 2048 - fusiona numeros","2. Tres en raya - dos jugadores","3. Reflejos - pulsa cuando cambie","4. Adivina el numero (1-10)","5. Dados contra CPU","","Pulsa 1-5 para jugar."} end
 if g.mode=="2048" then
  local lines={"2048  |  Puntos: "..g.score..(g.won and "  GANASTE" or "")..(g.over and "  FIN" or ""),"Flechas para mover | R reinicia | ESC menu",""}
  for y=1,4 do local cells="";for x=1,4 do local n=g.board[y][x];cells=cells..string.format("|%4s",n==0 and " " or tostring(n)) end;lines[#lines+1]=cells.."|" end
  lines[#lines+1]="";lines[#lines+1]="Combina fichas iguales para llegar a 2048.";return lines
 elseif g.mode=="tic" then
  local lines={"Tres en raya | Turno: "..(g.winner or g.turn),"Haz clic en una casilla | ESC menu",""}
  for y=1,3 do lines[#lines+1]="   "..table.concat(g.board[y]," | ").."   ";if y<3 then lines[#lines+1]="  ---+---+---" end end
  if g.winner then lines[#lines+1]="Resultado: "..g.winner end;return lines
 elseif g.mode=="reaction" then return {"Prueba de reflejos","","R: preparar una ronda","Haz clic solo cuando aparezca AHORA.","",g.result or "Pulsa R para empezar", "ESC: volver a juegos"}
 elseif g.mode=="guess" then
  local lines={"Adivina el numero (1-10)","Pulsa 1-9 o 0 para 10; R nueva partida","Intentos: "..g.tries..(g.won and " - GANASTE! Era "..g.target or "") ,""}
  for _,v in ipairs(g.history) do lines[#lines+1]=v end
  lines[#lines+1]="Usa R para iniciar otra partida.";return lines
 else return {"Dados contra CPU","Pulsa ESPACIO o ENTER para lanzar","Ronda: "..g.round.."/5","Puntuacion: Tu "..g.player.." - CPU "..g.cpu,"",g.last,g.round>=5 and (g.player==g.cpu and "Empate!" or (g.player>g.cpu and "Has ganado!" or "Gana la CPU")) or "ESC: volver al selector"} end
end
return M
]=]
payload["/apps/tools.lua"] = [=[
-- Centro de herramientas: calendario, tareas, perifericos, redstone y diagnostico.
local M={}
local SIDES={"top","bottom","left","right","front","back"}
local TODO="/.xpultimate/todo"
local function freeSpace()
 if not fs.getFreeSpace then return "N/D" end
 local ok,value=pcall(fs.getFreeSpace,"/");return ok and tostring(value) or "N/D"
end
local function luaMemory()
 local ok,value=pcall(collectgarbage,"count");return ok and math.floor(tonumber(value) or 0) or 0
end
local function currentDirectory()
 if shell and type(shell.dir)=="function" then
  local ok,value=pcall(shell.dir)
  if ok and type(value)=="string" and value~="" then return fs.combine("/",value) end
 end
 if shell and type(shell.getRunningProgram)=="function" then
  local ok,value=pcall(shell.getRunningProgram)
  if ok and type(value)=="string" and value~="" then return fs.getDir(value) end
 end
 return "/"
end
local function loadTasks()
 if not fs.exists(TODO) then return {} end
 local f=fs.open(TODO,"r");if not f then return {} end
 local raw=f.readAll();f.close();local ok,data=pcall(textutils.unserialize,raw)
 return ok and type(data)=="table" and data or {}
end
local function saveTasks(state)
 if not fs.exists("/.xpultimate") then fs.makeDir("/.xpultimate") end
 local f=fs.open(TODO,"w");if not f then return false end
 f.write(textutils.serialize(state.tasks));f.close();return true
end
function M.new() return {page=1,side=1,selected=1,tasks=loadTasks(),month=0} end
local function peripherals()
 local out={}
 if peripheral and peripheral.getNames then
  for _,name in ipairs(peripheral.getNames()) do
   local ok,kind=pcall(peripheral.getType,name)
   out[#out+1]={name=name,kind=type(kind)=="table" and table.concat(kind,",") or tostring(kind or "desconocido")}
  end
 end
 return out
end
local function fileStats(path,stats)
 stats=stats or {files=0,dirs=0}
 if stats.files+stats.dirs>500 then return stats end
 local ok,list=pcall(fs.list,path);if not ok then return stats end
 for _,name in ipairs(list) do
  local full=fs.combine(path,name)
  if fs.isDir(full) then stats.dirs=stats.dirs+1;fileStats(full,stats)
  else stats.files=stats.files+1 end
  if stats.files+stats.dirs>500 then break end
 end
 return stats
end
local function calendar(state)
 local now=os.date("*t");local month=now.month+state.month;local year=now.year
 while month<1 do month=month+12;year=year-1 end
 while month>12 do month=month-12;year=year+1 end
 local first=os.time({year=year,month=month,day=1,hour=12})
 local start=(tonumber(os.date("%w",first)) or 0)
 local days=tonumber(os.date("%d",os.time({year=year,month=month+1,day=0,hour=12}))) or 30
 local lines={"Calendario XP",os.date("%B %Y",first),"Do Lu Ma Mi Ju Vi Sa"}
 local cells={};for _=1,start do cells[#cells+1]="  " end
 for day=1,days do cells[#cells+1]=string.format("%2d",day) end
 for i=1,#cells,7 do lines[#lines+1]=table.concat(cells," ",i,math.min(i+6,#cells)) end
 lines[#lines+1]="Hoy: "..os.date("%d/%m/%Y")
 lines[#lines+1]="Flechas izquierda/derecha: mes anterior/siguiente"
 return lines
end
function M.lines(state)
 local page=state.page
 if page==1 then
  local stats=fileStats("/");local free=freeSpace()
  local lines={"Centro de herramientas XP","Selecciona panel con teclas 1-8","", "1. Resumen del equipo","2. Perifericos conectados","3. Control Redstone","4. Tareas","5. Calendario","6. Almacenamiento","7. Red y modem","8. Sonido",""}
  lines[#lines+1]=string.format("Hora: %s",os.date("%H:%M:%S"))
  lines[#lines+1]=string.format("Memoria Lua: %d KB",luaMemory())
  lines[#lines+1]=string.format("Archivos: %s  Carpetas: %s",tostring(stats.files),tostring(stats.dirs))
  lines[#lines+1]=string.format("Espacio libre: %s",tostring(free))
  return lines
 elseif page==2 then
  local lines={"Perifericos detectados","Nombre | tipo",""};local list=peripherals()
  for _,p in ipairs(list) do lines[#lines+1]=p.name.." | "..p.kind end
  if #list==0 then lines[#lines+1]="No hay perifericos conectados." end
  lines[#lines+1]="Pulsa R para volver a escanear.";return lines
 elseif page==3 then
  local side=SIDES[state.side];local input=false;local output=false
  if redstone then pcall(function() input=redstone.getInput(side);output=redstone.getOutput(side) end) end
  local lines={"Panel Redstone","Lado seleccionado: "..side,"Entrada: "..tostring(input),"Salida: "..tostring(output),"","Flechas: elegir lado","ENTER: alternar salida","","Estado de todos los lados:"}
  for _,s in ipairs(SIDES) do local ok,v=pcall(redstone.getInput,s);local ok2,o=pcall(redstone.getOutput,s);lines[#lines+1]=s.."  IN="..tostring(ok and v).." OUT="..tostring(ok2 and o) end
  return lines
 elseif page==4 then
  local lines={"Lista de tareas","A: anadir | X: borrar seleccionada | ENTER: completar",""}
  if #state.tasks==0 then lines[#lines+1]="No hay tareas. Pulsa A para crear una." end
  state.selected=math.max(1,math.min(math.max(1,#state.tasks),state.selected))
  for i,t in ipairs(state.tasks) do lines[#lines+1]=(i==state.selected and "> " or "  ")..(t.done and "[x] " or "[ ] ")..t.text end
  lines[#lines+1]="Guardado local: /.xpultimate/todo";return lines
 elseif page==5 then return calendar(state)
 elseif page==6 then
  local stats=fileStats("/");local free=freeSpace()
  local lines={"Almacenamiento"}
  lines[#lines+1]=string.format("Archivos encontrados (max 500): %s",tostring(stats.files))
  lines[#lines+1]=string.format("Directorios encontrados (max 500): %s",tostring(stats.dirs))
  lines[#lines+1]=string.format("Espacio libre: %s",tostring(free))
  lines[#lines+1]=string.format("Ruta de usuario: %s",currentDirectory())
  lines[#lines+1]="";lines[#lines+1]="Los datos se actualizan al volver a abrir este panel."
  return lines
 elseif page==7 then
  local modems={};for _,p in ipairs(peripherals()) do if p.kind:find("modem",1,true) then modems[#modems+1]=p.name end end
  local lines={"Red y comunicaciones","HTTP API: "..tostring(http and http.get~=nil),"Modem: "..(#modems>0 and table.concat(modems,", ") or "no detectado"),"Computer ID: "..tostring(os.getComputerID and os.getComputerID() or "N/D"),"Nombre: "..tostring(os.getComputerLabel and os.getComputerLabel() or "sin etiqueta"),"", "La API HTTP depende de la configuracion del entorno."};return lines
 else
  local speakers={};for _,p in ipairs(peripherals()) do if p.kind:find("speaker",1,true) then speakers[#speakers+1]=p.name end end
  return {"Diagnostico de audio","Speaker: "..(#speakers>0 and table.concat(speakers,", ") or "no conectado"),"Pulsa P para una prueba de sonido.","Efectos de interfaz: se controlan en Ajustes XP."}
 end
end
function M.key(state,key)
 if key>=keys.one and key<=keys.eight then state.page=key-keys.one+1;return "redraw" end
 if state.page==2 and key==keys.r then return "redraw"
 elseif state.page==3 then
  if key==keys.left or key==keys.up then state.side=(state.side-2)%#SIDES+1
  elseif key==keys.right or key==keys.down then state.side=state.side%#SIDES+1
  elseif key==keys.enter and redstone then local side=SIDES[state.side];redstone.setOutput(side,not redstone.getOutput(side));return "redraw" end
 elseif state.page==4 then
  if key==keys.up then state.selected=math.max(1,state.selected-1)
  elseif key==keys.down then state.selected=math.min(math.max(1,#state.tasks),state.selected+1)
  elseif key==keys.enter and state.tasks[state.selected] then state.tasks[state.selected].done=not state.tasks[state.selected].done;saveTasks(state)
  elseif key==keys.x and state.tasks[state.selected] then table.remove(state.tasks,state.selected);state.selected=math.max(1,math.min(#state.tasks,state.selected));saveTasks(state)
  elseif key==keys.a then return "addTask" end
 elseif state.page==5 then
  if key==keys.left then state.month=state.month-1 elseif key==keys.right then state.month=state.month+1 end
 elseif state.page==8 and key==keys.p then
  local speaker=peripheral.find("speaker");if not speaker then return "No hay speaker conectado" end
  local ok,err=pcall(speaker.playNote,"chime",0.7,18);return ok and "Prueba de sonido enviada" or tostring(err)
 end
 return "redraw"
end
function M.addTask(state,text)
 text=tostring(text or ""):gsub("^%s+",""):gsub("%s+$","")
 if text=="" then return false,"La tarea no puede estar vacia" end
 if #state.tasks>=50 then return false,"Maximo 50 tareas" end
 state.tasks[#state.tasks+1]={text=text:sub(1,80),done=false};state.selected=#state.tasks;saveTasks(state);return true
end
return M
]=]
payload["/apps/ide.lua"] = [=[
-- Editor Lua estilo IDE para CraftOS: proyectos, edicion, guardado y ejecucion manual.
local M={}
local ROOT="/Programs"
local function safePath(path)
 path=fs.combine(ROOT,tostring(path or ""))
 if path==ROOT or path:sub(1,#ROOT+1)~=ROOT.."/" then return nil,"Ruta fuera de /Programs" end
 return path
end
local function readLines(text)
 local lines={};text=tostring(text or "")
 for line in (text.."\n"):gmatch("(.-)\n") do lines[#lines+1]=line end
 if #lines==0 then lines[1]="" end
 return lines
end
local function listFiles()
 if not fs.exists(ROOT) then fs.makeDir(ROOT) end
 local out={};for _,name in ipairs(fs.list(ROOT)) do
  if not fs.isDir(fs.combine(ROOT,name)) and name:lower():match("%.lua$") then out[#out+1]=name end
 end
 table.sort(out,function(a,b)return a:lower()<b:lower() end);return out
end
function M.new() return {path=nil,lines={},x=1,y=1,scroll=0,hscroll=0,selected=1,status="Listo",output={},dirty=false,files=listFiles()} end
function M.refresh(state) state.files=listFiles();state.selected=math.max(1,math.min(#state.files, state.selected or 1)) end
function M.open(state,path)
 local full,err=safePath(path);if not full then return false,err end
 if fs.isDir(full) then return false,"Abre un archivo .lua de /Programs" end
 local f,e=fs.open(full,"r");if not f then return false,e end
 local data=f.readAll();f.close();state.path=full;state.lines=readLines(data);state.x=1;state.y=1;state.scroll=0;state.hscroll=0;state.dirty=false;state.status="Abierto: "..full;return true
end
function M.newFile(state,name)
 name=tostring(name or ""):gsub("^%s+",""):gsub("%s+$","")
 if name=="" then return false,"Escribe un nombre de archivo" end
 if not name:lower():match("%.lua$") then name=name..".lua" end
 if name:find("[/\\]") or name=="." or name==".." then return false,"Nombre de archivo no valido" end
 if not fs.exists(ROOT) then fs.makeDir(ROOT) end
 local full=fs.combine(ROOT,name);if fs.exists(full) then return false,"Ese archivo ya existe" end
 state.path=full;state.lines={"-- Nuevo programa Lua","print(\"Hola desde XP IDE\")"};state.x=1;state.y=1;state.hscroll=0;state.dirty=true;state.status="Archivo nuevo: "..full;return true
end
function M.save(state)
 if not state.path then return false,"Crea o abre un archivo primero" end
 local f,err=fs.open(state.path,"w");if not f then return false,err end
 f.write(table.concat(state.lines,"\n"));f.close();state.dirty=false;state.status="Guardado: "..state.path;M.refresh(state);return true
end
function M.back(state)
 if state.dirty then local ok,err=M.save(state);if not ok then state.status="No se pudo guardar: "..tostring(err);return false end end
 state.path=nil;state.status="Proyecto /Programs";state.scroll=0;M.refresh(state);return true
end
function M.lines(state)
 if not state.path then
  local out={"XP Visual Lua Studio","Proyectos Lua en /Programs","F2: nuevo | ENTER: abrir | R: actualizar","", "Archivos:"}
  if #state.files==0 then out[#out+1]="No hay programas. Pulsa N para crear uno." end
  for i,name in ipairs(state.files) do out[#out+1]=(i==state.selected and "> " or "  ")..name end
  out[#out+1]="";out[#out+1]=state.status;return out
 end
 local out={"XP Visual Lua Studio | "..fs.getName(state.path)..(state.dirty and " *" or ""),"F2: guardar | F5: ejecutar | F3: buscar | F4: reemplazar","Flechas mueven cursor | ENTER linea | TAB sangria | ESC volver",""}
 for i,line in ipairs(state.lines) do out[#out+1]=string.format("%03d %s",i,line) end
 out[#out+1]=""..state.status
 if #state.output>0 then out[#out+1]="-- Salida de la ultima ejecucion --";for i=math.max(1,#state.output-4),#state.output do out[#out+1]=state.output[i] end end
 return out
end
function M.key(state,key)
 if not state.path then
  if key==keys.up then state.selected=math.max(1,state.selected-1)
  elseif key==keys.down then state.selected=math.min(math.max(1,#state.files),state.selected+1)
  elseif key==keys.enter and state.files[state.selected] then local ok,err=M.open(state,state.files[state.selected]);return ok and "redraw" or err
  elseif key==keys.f2 then return "newFile"
  elseif key==keys.r then M.refresh(state) end
  return "redraw"
 end
 local line=state.lines[state.y] or "";local x=math.max(1,math.min(state.x,#line+1))
 if key==keys.escape then M.back(state)
 elseif key==keys.f2 then local ok,err=M.save(state);if not ok then state.status=tostring(err) end
 elseif key==keys.f5 then return "run"
 elseif key==keys.f3 then return "find"
 elseif key==keys.f4 then return "replace"
 elseif key==keys.left then state.x=math.max(1,x-1)
 elseif key==keys.right then state.x=math.min(#line+1,x+1)
 elseif key==keys.up then state.y=math.max(1,state.y-1);state.x=math.min(state.x,#(state.lines[state.y] or "")+1)
 elseif key==keys.down then state.y=math.min(#state.lines,state.y+1);state.x=math.min(state.x,#(state.lines[state.y] or "")+1)
 elseif key==keys.home then state.x=1
 elseif key==keys["end"] then state.x=#line+1
 elseif key==keys.backspace then
  state.dirty=true
  if x>1 then state.lines[state.y]=line:sub(1,x-2)..line:sub(x);state.x=x-1
  elseif state.y>1 then local prev=state.lines[state.y-1];state.x=#prev+1;state.lines[state.y-1]=prev..line;table.remove(state.lines,state.y);state.y=state.y-1 end
 elseif key==keys.delete then
  state.dirty=true
  if x<=#line then state.lines[state.y]=line:sub(1,x-1)..line:sub(x+1)
  elseif state.y<#state.lines then state.lines[state.y]=line..state.lines[state.y+1];table.remove(state.lines,state.y+1) end
 elseif key==keys.enter then
  state.dirty=true
  local before,after=line:sub(1,x-1),line:sub(x);local indent=before:match("^%s*") or ""
  local first=before:match("^%s*([%a_]+)")
  if before:match("then%s*$") or before:match("do%s*$") or first=="function" then indent=indent.."  " end
  state.lines[state.y]=before;table.insert(state.lines,state.y+1,indent..after);state.y=state.y+1;state.x=#indent+1
 elseif key==keys.tab then state.dirty=true;state.lines[state.y]=line:sub(1,x-1).."  "..line:sub(x);state.x=x+2 end
 return "redraw"
end
function M.char(state,char)
 if not state.path then return end
 local line=state.lines[state.y] or "";local x=math.max(1,math.min(state.x,#line+1))
 state.lines[state.y]=line:sub(1,x-1)..char..line:sub(x);state.x=x+#char;state.dirty=true
end
function M.find(state,needle)
 if not needle or needle=="" then return false,"Busqueda vacia" end
 local startY,startX=state.y,state.x+1
 for pass=1,2 do
  local first=pass==1 and startY or 1;local last=pass==1 and #state.lines or startY
  for y=first,last do
   local from=(pass==1 and y==startY) and startX or 1
   local x=(state.lines[y] or ""):find(needle,from,true)
   if x then state.y=y;state.x=x;state.status="Encontrado en linea "..y;return true end
  end
 end
 state.status="No se encontro: "..needle;return false,state.status
end
function M.replaceAll(state,needle,replacement)
 if not needle or needle=="" then return 0,"Texto de busqueda vacio" end
 local count=0
 for i,line in ipairs(state.lines) do
  local out={};local from=1
  while true do local a,b=line:find(needle,from,true);if not a then out[#out+1]=line:sub(from);break end;out[#out+1]=line:sub(from,a-1);out[#out+1]=replacement;from=b+1;count=count+1 end
  state.lines[i]=table.concat(out)
 end
 if count>0 then state.dirty=true end
 state.status="Reemplazos: "..count;return count,state.status
end
function M.cursor(state) return state.x,state.y end
function M.run(state,redirectWindow)
 if not state.path then return false,"Abre un programa primero" end
 local ok,err=M.save(state);if not ok then return false,err end
 local sw,sh=term.getSize();local w=window.create(term.current(),1,1,sw,sh,false)
 local output=type(redirectWindow)=="function" and redirectWindow(w,term.current()) or w
 local previous=term.redirect(output);local callOk,result=pcall(shell.run,state.path);term.redirect(previous)
 local success=callOk and result~=false
 state.output={}
 local _,height=w.getSize()
 for row=1,height do local line=w.getLine(row);line=line:gsub("%s+$","");if line~="" then state.output[#state.output+1]=line end end
 if not callOk then state.output[#state.output+1]=tostring(result) end
 state.status=success and "Ejecucion terminada (F5)" or "Error al ejecutar"
 return success,state.status
end
return M
]=]
payload["/apps/packages.lua"] = [=[
-- Gestor local de paquetes. Solo instala catalogo incluido; ejecutar es una accion manual.
local M={}
local ROOT="/packages"
local catalog={
 {id="hello",name="Hola mundo",version="1.0",description="Ejemplo comentado de programa Lua.",source="-- Hola Mundo para CC:Tweaked\nprint('Hola desde Windows XP Ultimate CC!')\nprint('Computer ID: '..os.getComputerID())\n"},
 {id="hardware",name="Inspector de perifericos",version="1.0",description="Lista perifericos y sus tipos.",source="print('Perifericos conectados:')\nfor _,name in ipairs(peripheral.getNames()) do\n local kinds=peripheral.getType(name)\n print(name..' - '..(type(kinds)=='table' and table.concat(kinds, ', ') or tostring(kinds)))\nend\n"},
 {id="redstone",name="Prueba Redstone",version="1.0",description="Muestra entradas y salidas; no altera el circuito.",source="for _,side in ipairs({'top','bottom','left','right','front','back'}) do\n print(side..' IN='..tostring(redstone.getInput(side))..' OUT='..tostring(redstone.getOutput(side)))\nend\n"},
 {id="diskinfo",name="Informe del sistema",version="1.0",description="Muestra sistema, memoria y espacio disponible.",source="print(os.version())\nprint('ID: '..os.getComputerID())\nprint('Memoria Lua: '..math.floor(collectgarbage('count'))..' KB')\nif fs.getFreeSpace then print('Espacio libre: '..tostring(fs.getFreeSpace('/'))) end\n"},
 {id="clock",name="Reloj de consola",version="1.0",description="Imprime fecha y hora del ordenador.",source="print('Fecha: '..os.date('%Y-%m-%d'))\nprint('Hora: '..os.date('%H:%M:%S'))\n"},
}
local function path(id)return fs.combine(ROOT,id..".lua") end
local function installed(id)return fs.exists(path(id)) end
function M.new() return {selected=1,status="Catalogo local; ejecutar requiere confirmacion manual."} end
function M.lines(state)
 local out={"XP Package Manager","Catalogo local | I instalar | X quitar","R ejecutar paquete instalado | flechas seleccionar",""}
 for i,p in ipairs(catalog) do out[#out+1]=(i==state.selected and "> " or "  ")..p.name.." v"..p.version..(installed(p.id) and " [INSTALADO]" or "") end
 local p=catalog[state.selected];if p then out[#out+1]="";out[#out+1]=p.description;out[#out+1]="ID: "..p.id end
 out[#out+1]="";out[#out+1]=state.status;out[#out+1]="Ruta: /packages"
 for _,line in ipairs(state.output or {}) do out[#out+1]=line end
 return out
end
function M.key(state,key)
 if key==keys.up then state.selected=math.max(1,state.selected-1)
 elseif key==keys.down then state.selected=math.min(#catalog,state.selected+1)
 elseif key==keys.i then
  local p=catalog[state.selected];if not fs.exists(ROOT) then fs.makeDir(ROOT) end
  if installed(p.id) then state.status="Ya esta instalado"
  else local f,err=fs.open(path(p.id),"w");if not f then state.status=tostring(err) else f.write(p.source);f.close();state.status="Instalado: "..p.name end end
 elseif key==keys.x then
  local p=catalog[state.selected];if installed(p.id) then fs.delete(path(p.id));state.status="Desinstalado: "..p.name else state.status="El paquete no esta instalado" end
 elseif key==keys.r then local p=catalog[state.selected];if installed(p.id) then return path(p.id) else state.status="Instala el paquete antes de ejecutarlo" end end
 return "redraw"
end
function M.isPackage(pathname)
 return type(pathname)=="string" and pathname:sub(1,#ROOT+1)==ROOT.."/" and fs.exists(pathname)
end
function M.catalog() return catalog end
return M
]=]
payload["/apps/calculator.lua"] = [=[
-- Evaluador aritmetico pequeno: no ejecuta codigo Lua arbitrario.
local M = {}

function M.evaluate(source)
  if type(source) ~= "string" or #source > 96 then return nil, "Expresion demasiado larga" end
  local pos = 1
  local function spaces()
    while source:sub(pos,pos):match("%s") do pos=pos+1 end
  end
  local expression, term, unary, atom
  atom = function()
    spaces()
    if source:sub(pos,pos) == "(" then
      pos=pos+1
      local value=expression()
      spaces()
      if source:sub(pos,pos) ~= ")" then error("Falta )") end
      pos=pos+1
      return value
    end
    local rest=source:sub(pos)
    local token=rest:match("^%d+%.?%d*") or rest:match("^%.%d+")
    if not token then error("Numero no valido en la posicion "..pos) end
    pos=pos+#token
    return tonumber(token)
  end
  unary = function()
    spaces()
    local ch=source:sub(pos,pos)
    if ch=="+" then pos=pos+1;return unary() end
    if ch=="-" then pos=pos+1;return -unary() end
    return atom()
  end
  term = function()
    local value=unary()
    while true do
      spaces()
      local ch=source:sub(pos,pos)
      if ch=="*" then pos=pos+1;value=value*unary()
      elseif ch=="/" then pos=pos+1;local divisor=unary();if divisor==0 then error("No se puede dividir entre cero") end;value=value/divisor
      elseif ch=="%" then pos=pos+1;local divisor=unary();if divisor==0 then error("No se puede dividir entre cero") end;value=value%divisor
      else return value end
    end
  end
  expression = function()
    local value=term()
    while true do
      spaces()
      local ch=source:sub(pos,pos)
      if ch=="+" then pos=pos+1;value=value+term()
      elseif ch=="-" then pos=pos+1;value=value-term()
      else return value end
    end
  end
  local ok,result=pcall(function()
    local value=expression();spaces()
    if pos<=#source then error("Caracter no valido: "..source:sub(pos,pos)) end
    return value
  end)
  if not ok then return nil,tostring(result) end
  if result~=result or result==math.huge or result==-math.huge then return nil,"Resultado fuera de rango" end
  return string.format("%.10g",result)
end

return M
]=]
local function ensureDir(path)
  local current = ""
  for part in path:gmatch("[^/]+") do
    current = current .. "/" .. part
    if not fs.exists(current) then fs.makeDir(current) end
  end
end

if not fs.exists("/.xpultimate") then fs.makeDir("/.xpultimate") end
if fs.exists("/startup.lua") and not fs.exists("/.xpultimate/startup.backup.lua") then
  local ok, err = pcall(fs.copy, "/startup.lua", "/.xpultimate/startup.backup.lua")
  if not ok then print("Aviso: no pude guardar una copia del startup anterior: " .. tostring(err)) end
end

local ok, err = pcall(function()
  for path, source in pairs(payload) do
    local dir = fs.getDir(path)
    if dir ~= "" then ensureDir(dir) end
    local file, openError = fs.open(path, "w")
    if not file then error("No se pudo crear " .. path .. ": " .. tostring(openError)) end
    file.write(source)
    file.close()
    print("Instalado: " .. path)
  end
end)
if not ok then
  printError("La instalacion no termino: " .. tostring(err))
  return
end
print("")
print("Windows XP Ultimate CC instalado.")
print("Autostart: abre /startup.lua para elegir; la preferencia actual se conserva.")
print("Reinicia o ejecuta startup para continuar.")
