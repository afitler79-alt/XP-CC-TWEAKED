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
local C=colors
local apps={
 {id="computer",name="Mi PC",icon="[PC]"},{id="browser",name="Internet Explorer",icon="[WEB]"},
 {id="studio",name="FL Studio XP",icon="[FL]"},
 {id="create",name="Create Manager",icon="[RPM]"},{id="players",name="Jugadores/AP",icon="[AP]"},
 {id="explorer",name="Mis documentos",icon="[DIR]"},{id="notepad",name="Bloc de notas",icon="[TXT]"},
 {id="cmd",name="Simbolo del sistema",icon=">_"},{id="media",name="Windows Media Player",icon="[M]"},
 {id="control",name="Panel de control",icon="[CFG]"},
 {id="users",name="Cuentas de usuario",icon="[USR]"},
 {id="calculator",name="Calculadora",icon="[+ -]"},
 {id="paint",name="Paint XP",icon="[ART]"},
 {id="system",name="Informacion del sistema",icon="[PC+]"},
}
local windows,active={},nil
local menu,logged=false,false
local username="Usuario"
local inputMode,inputText=nil,""
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
local soundOK,sounds=pcall(dofile,"/sys/sounds.lua")
if not soundOK then sounds={play=function() return false end} end
local function playSound(name) pcall(sounds.play,name) end
local wallpaper=C.lightBlue
local paintColors={C.black,C.red,C.green,C.blue,C.orange,C.purple}
local desktopRows=4
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
 local w={id=id,name=name,x=math.max(2,math.floor(W*.13)),y=2,w=math.max(24,math.floor(W*.74)),h=math.max(10,H-5),min=false,max=false,scroll=0,data={}}
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
 box(x+1,y+hh,ww,1,C.black);box(x+ww,y+1,1,hh,C.gray)
 box(x,y,ww,hh,C.gray);box(x+1,y+1,ww-2,hh-2,C.white);box(x+1,y,ww-2,1,C.blue)
 put(x+2,y," "..clipped(w.name,math.max(1,ww-18)),C.white,C.blue)
 put(x+ww-13,y,"[_]",C.white,C.lightBlue);put(x+ww-9,y,"[+]",C.white,C.lightBlue);put(x+ww-5,y,"[X]",C.white,C.red)
 local y0=y+2;local bottom=math.min(H-2,y+hh-2)
 local lines=appLines(w);local max=math.max(0,#lines-(bottom-y0+1));w.scroll=math.max(0,math.min(w.scroll,max))
 if w.id=="studio" then
  local visible=bottom-y0+1;local selectedLine=(w.data.project.selected or 1)+6
  if selectedLine>w.scroll+visible then w.scroll=math.min(max,selectedLine-visible) end
  if selectedLine<=w.scroll then w.scroll=math.max(0,selectedLine-1) end
 end
 for i=y0,bottom do
  local lineIndex=i-y0+1+w.scroll
  local row=lines[lineIndex]
  if w.id=="paint" and lineIndex>=4 then
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
  elseif row then put(x+2,i,row,C.black,C.white) end
 end
end
local function redraw()
 W,H=term.getSize();createDevices=ap.create();createAlert=false
 for _,d in ipairs(createDevices) do for side,value in pairs(d.stress) do local cap=d.capacity[side];if cap and cap>0 and value>=cap then createAlert=true end end end
 term.setBackgroundColor(wallpaper);term.clear()
 -- Cielo Luna con sol, nubes y pradera.
 box(1,1,W,H,C.lightBlue)
 put(math.max(1,W-9),2,"(o)",C.yellow,C.lightBlue)
 put(math.max(1,W-22),3," .--.  .--. ",C.white,C.lightBlue)
 put(math.max(1,W-22),4,"(____)(____)",C.white,C.lightBlue)
 local horizon=math.max(3,math.floor(H*.62))
 for y=horizon,H-2 do box(1,y,W,1,C.green) end
 put(1,horizon,string.rep("~",W),C.lime,C.green)
 local columns=math.max(1,math.floor((W-10)/15)+1)
 desktopRows=math.max(1,math.floor((H-5)/3),math.ceil(#apps/columns))
 for i,a in ipairs(apps) do local col=math.floor((i-1)/desktopRows);local row=(i-1)%desktopRows;local x=2+col*15;local y=2+row*3
  if x<W-8 then put(x,y,a.icon,C.yellow,wallpaper);put(x,y+1,clipped(a.name,13),C.white,C.blue) end
 end
 for _,w in ipairs(windows) do drawWindow(w) end
 box(1,H-1,W,1,C.blue);put(1,H-1," XP Inicio ",C.white,C.green)
 local x=12;for _,w in ipairs(windows) do if x<W-12 then put(x,H-1,"["..clipped(w.name,10).."]",C.white,w==active and C.lightBlue or C.blue);x=x+13 end end
 if createAlert then put(math.max(10,W-29),H-1,"CREATE STALLED",C.white,C.red) end
 put(math.max(1,W-9),H-1," "..os.date("%H:%M").." ",C.white,C.blue)
 box(1,H-2,W,1,C.lightGray);put(2,H-2,"XP Ultimate | "..status,C.black,C.lightGray)
 if menu then box(1,H-9,23,8,C.lightGray);box(1,H-9,23,1,C.blue);put(2,H-9,"Windows XP Ultimate",C.white,C.blue);for i,a in ipairs(apps) do if i<7 then put(2,H-9+i,""..i..". "..a.name,C.black,C.lightGray) end end;put(2,H-2,"0. Apagar equipo",C.black,C.lightGray) end
 if inputMode then box(2,H-3,W-4,2,C.black);put(3,H-3,inputMode..": "..inputText,C.white,C.black) end
end
local function startInput(mode,initial) inputMode=mode;inputText=initial or "" end
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
   local previous=term.redirect(capture)
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
  local n=y-(H-9);if n>=1 and n<=#apps and apps[n] then launch(apps[n].id);return end
  menu=false
 end
 if y==H-1 and x<=11 then menu=not menu;return end
 if y==H-1 then local i=math.floor((x-12)/13)+1;if x>=12 and windows[i] then active=windows[i];active.min=false end;return end
 for i=#windows,1,-1 do local w=windows[i];if not w.min and x>=w.x and x<w.x+w.w and y>=w.y and y<w.y+w.h then
  active=w
  if i<#windows then table.remove(windows,i);windows[#windows+1]=w end
  if y==w.y then if x>=w.x+w.w-4 then playSound("close");for j,v in ipairs(windows) do if v==w then table.remove(windows,j);break end end;active=windows[#windows]
    elseif x>=w.x+w.w-7 and x<=w.x+w.w-6 then w.max=not w.max;if w.max then w.old={w.x,w.y,w.w,w.h};w.x=1;w.y=1;w.w=W;w.h=H-2 else w.x,w.y,w.w,w.h=unpack(w.old) end
    elseif x>=w.x+w.w-11 and x<=w.x+w.w-10 then w.min=true
    else w.drag={x-w.x,y-w.y} end;return end
  local row=y-w.y-2+w.scroll
  if w.id=="studio" then
   local track=y-(w.y+7)+w.scroll;local step=x-(w.x+9)+1
   if track>=1 and track<=#w.data.project.tracks then
    studio.select(w.data.project,track)
    if step>=1 and step<=16 then studio.toggle(w.data.project,track,step+((w.data.project.page or 1)-1)*16) end
    return
   end
  end
  if w.id=="paint" and y>=w.y+5 and y<=w.y+w.h-2 and x>=w.x+2 and x<=w.x+w.w-3 then
   local rr=y-(w.y+5)+1;local cc=x-(w.x+2)+1;w.data.pixels[rr]=w.data.pixels[rr] or {};w.data.pixels[rr][cc]={color=w.data.brush,char=w.data.brushChar or "*"}
  end
  if (w.id=="computer" or w.id=="explorer") and row>=3 then local entry=w.data.entries[row-2];if entry then if entry.dir then w.data.path=fs.combine(w.data.path,entry.name);w.scroll=0 else w.data.path=fs.combine(w.data.path,entry.name);local txt=files.read(w.data.path);if txt then open("notepad");active.data.path=w.data.path;active.data.text=txt end end end end
  return
 end end
 -- Desktop icons, double click not required: click launches.
 local col=math.floor((x-2)/15);local row=math.floor((y-2)/3);local n=col*desktopRows+row+1;if y>=2 then local a=apps[n];if a then launch(a.id) end end
end
local function dragWindow(x,y)
 if not active or not active.drag then return end
 active.x=math.max(1,math.min(W-active.w+1,x-active.drag[1]))
 active.y=math.max(1,math.min(H-active.h,y-active.drag[2]))
end
local function key(k)
 playSound("click")
 if inputMode then if k==keys.enter then submitInput() elseif k==keys.backspace then inputText=inputText:sub(1,-2) elseif k==keys.escape then inputMode=nil;inputText="" end;return end
 if k==keys.escape then menu=false;return end
 if not active then return end
 local w=active
 if k==keys.enter then
  if w.id=="browser" then startInput("URL",w.data.url)
  elseif w.id=="cmd" then startInput("CMD","")
  elseif w.id=="calculator" then startInput("Expresion",w.data.expression or "") end
 elseif k==keys.r and w.id=="create" then w.data.devices=ap.create()
 elseif k==keys.s and w.id=="create" then startInput("Indice lado rpm","")
 elseif k==keys.c and w.id=="create" then startInput("Redstone lado on/off","r:")
 elseif k==keys.a and w.id=="browser" then startInput("URL o busqueda",w.data.url)
 elseif k==keys.p and w.id=="media" then local ok,err=audio.playNote(12);status=ok and "Nota reproducida" or err
 elseif k==keys.d and w.id=="media" then startInput("Ruta DFPWM","")
 elseif k==keys.p and w.id=="studio" then local ok,err=studio.play(w.data.project);status=ok and "Reproduccion terminada" or err
 elseif k==keys.s and w.id=="studio" then startInput("Guardar proyecto en ruta","/xp_song.xpm");inputMode="studio-save"
 elseif k==keys.e and w.id=="studio" then startInput("Exportar reproductor Lua","/xp_song.lua");inputMode="studio-export"
 elseif k==keys.o and w.id=="studio" then startInput("Abrir proyecto .xpm","/xp_song.xpm");inputMode="studio-load"
 elseif k==keys.t and w.id=="studio" then startInput("Titulo de la cancion",w.data.project.title);inputMode="studio-title"
 elseif k==keys.r and w.id=="studio" then startInput("Nombre de la pista",w.data.project.tracks[w.data.project.selected].name);inputMode="studio-track"
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
 elseif k==keys.e and w.id=="notepad" then startInput("Texto (sobrescribe archivo)",w.data.text)
 elseif k==keys.u and w.id=="control" then open("users")
 elseif k==keys.l and w.id=="control" then playSound("logoff");windows={};active=nil;logged=false
 elseif k==keys.a and w.id=="control" then setAutoStart(not getAutoStart())
 elseif k==keys.t and w.id=="control" then wallpaper=wallpaper==C.lightBlue and C.cyan or (wallpaper==C.cyan and C.purple or C.lightBlue)
 elseif k==keys.a and w.id=="users" then startInput("Nombre de cuenta","Nuevo usuario")
 elseif k==keys.m and w.id=="players" then startInput("Mensaje para Chat Box","")
 elseif k==keys.r and w.id=="system" then w.data.refresh=os.clock()
 elseif w.id=="paint" and k>=keys.one and k<=keys.six then w.data.brush=paintColors[k-keys.one+1]
 elseif w.id=="paint" and k==keys.c then w.data.pixels={}
 elseif w.id=="paint" and k==keys.b then w.data.brushChar=(w.data.brushChar=="*" and "#" or "*")
 end
end
local function char(c)
 if inputMode then inputText=inputText..c
 elseif active and active.id=="studio" then
  if c=="+" or c=="=" then studio.tempo(active.data.project,5)
  elseif c=="-" then studio.tempo(active.data.project,-5) end
 end
end
boot()
while not logged do if login() then logged=true end end
redraw()
local clockTimer=os.startTimer(1)
while true do
 if not logged then login();logged=true;redraw() end
 local ev={os.pullEvent()}
 if ev[1]=="term_resize" then redraw()
 elseif ev[1]=="mouse_click" then click(ev[3],ev[4]);redraw()
 elseif ev[1]=="mouse_drag" then dragWindow(ev[3],ev[4]);redraw()
 elseif ev[1]=="mouse_up" then if active then active.drag=nil end
 elseif ev[1]=="key" then key(ev[2]);redraw()
 elseif ev[1]=="char" then char(ev[2]);redraw()
 elseif ev[1]=="timer" and ev[2]==clockTimer then redraw();clockTimer=os.startTimer(1) end
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
