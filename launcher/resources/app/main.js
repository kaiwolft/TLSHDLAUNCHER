// The Last Story HD — Dionixu's Launcher (Electron / Chromium) · Windows y Linux
const { app, BrowserWindow, ipcMain, screen, protocol, net } = require('electron');
const { pathToFileURL } = require('url');
const path = require('path');
const fs = require('fs');
const { spawn, execFile } = require('child_process');

const IS_WIN = process.platform === 'win32';
const IS_LINUX = process.platform === 'linux';
const APP_NAME = "The Last Story HD — Dionixu's Launcher";
const ROOT = path.dirname(process.execPath);          // carpeta launcher
const UI = path.join(ROOT, 'ui');
const DATA = path.join(ROOT, 'data');
const CFG = path.join(DATA, 'config.json');
const PATHS = path.join(DATA, 'paths.json');
const LOG = path.join(DATA, 'launcher.log');
const WINDOWED_START = process.argv.includes('--windowed');   // primera apertura tras instalar

app.commandLine.appendSwitch('autoplay-policy', 'no-user-gesture-required');
// En Linux se fuerza X11 (también bajo Wayland vía XWayland): Dolphin usa X11 y el puente controla ventanas por X11
if (IS_LINUX) app.commandLine.appendSwitch('ozone-platform', 'x11');
// Protocolo propio para servir la interfaz (WebGL y audio necesitan un origen propio, no file://)
protocol.registerSchemesAsPrivileged([{ scheme: 'tls', privileges: { standard: true, secure: true, supportFetchAPI: true, stream: true } }]);
app.setPath('userData', path.join(DATA, 'chromium'));
app.setName("Dionixu's Launcher");

const log = (s) => { try { fs.appendFileSync(LOG, new Date().toISOString() + '  ' + s + '\n'); } catch (e) {} };
const readJson = (f, d) => { try { return JSON.parse(fs.readFileSync(f, 'utf8').replace(/^﻿/, '')); } catch (e) { return d; } };
const exists = (f) => { try { return fs.existsSync(f); } catch (e) { return false; } };
const saveCfg = () => { try { fs.writeFileSync(CFG, JSON.stringify(cfg)); } catch (e) {} };

let win = null;
let game = null;
let exitWin = null;      // menú de pausa / salir
let bridge = null;       // puente de mando y ventanas mientras se juega
let exitOpen = false;
let cfg = readJson(CFG, {});

// ---------------- rutas
// Absolutas o relativas a la carpeta del launcher. Estructura instalada:
//   <raíz>/launcher  <raíz>/juego/US_INGLES  <raíz>/juego/US_VOZ_JP
//   Windows: <raíz>/dolphin/Dolphin.exe (+ User)      Linux: Dolphin del usuario + <raíz>/dolphin-user
// En Linux dolphinExe puede ser una ruta, un comando del PATH (dolphin-emu) o "flatpak:org.DolphinEmu.dolphin-emu".
const paths = (() => {
  const raw = readJson(PATHS, {});
  const abs = (p) => path.resolve(ROOT, p);
  const out = {};
  for (const [k, d] of Object.entries({ gameEN: '../juego/US_INGLES', gameJP: '../juego/US_VOZ_JP' })) {
    const v = raw[k] ? abs(raw[k]) : null;
    out[k] = v && exists(v) ? v : abs(d);
  }
  if (IS_WIN) {
    const v = raw.dolphinExe ? abs(raw.dolphinExe) : null;
    out.dolphinExe = v && exists(v) ? v : abs('../dolphin/Dolphin.exe');
    out.dolphinUser = raw.dolphinUser ? abs(raw.dolphinUser) : path.join(path.dirname(out.dolphinExe), 'User');
  } else {
    const d = raw.dolphinExe || 'dolphin-emu';
    out.dolphinExe = d.startsWith('flatpak:') || !d.includes('/') ? d : abs(d);
    out.dolphinUser = abs(raw.dolphinUser || '../dolphin-user');
  }
  out.buttonsActive = raw.buttonsActive ? abs(raw.buttonsActive) : path.join(out.dolphinUser, 'Load', 'Textures', 'SLSEXJ', 'Botones');
  if (!exists(path.dirname(out.buttonsActive))) out.buttonsActive = path.join(out.dolphinUser, 'Load', 'Textures', 'SLSEXJ', 'Botones');
  out.root = path.resolve(ROOT, '..');
  return out;
})();
const USER = paths.dolphinUser;
const userPath = (...p) => path.join(USER, ...p);

// Cómo lanzar Dolphin según el sistema
function dolphinCommand() {
  const d = paths.dolphinExe;
  if (IS_LINUX && d.startsWith('flatpak:'))
    return { cmd: 'flatpak', pre: ['run', '--filesystem=' + paths.root, d.slice(8)], ok: true };
  if (IS_LINUX && !d.includes('/')) {   // comando del PATH
    const found = (process.env.PATH || '').split(':').some((dir) => dir && exists(path.join(dir, d)));
    return { cmd: d, pre: [], ok: found };
  }
  return { cmd: d, pre: [], ok: exists(d) };
}

const send = (type, data) => { if (win && !win.isDestroyed()) win.webContents.send('msg', JSON.stringify({ type, data })); };

// ---------------- logros (set de RetroAchievements evaluado sin conexión por tls_logros)
const LOGROS = path.join(DATA, 'logros');
const RA_SET = path.join(LOGROS, 'ra_27.json');
const PROG = path.join(LOGROS, 'progreso.json');
const BADGES = path.join(UI, 'assets', 'logros');
let achSet = null;
let prog = readJson(PROG, { unlocked: {}, progress: {} });
let achProc = null;
let toastWin = null, toastQueue = [], toastBusy = false;

const loadSet = () => {
  achSet = readJson(RA_SET, null);
  if (achSet && !Array.isArray(achSet.achievements)) achSet = null;
  // el servidor añade avisos propios (id >= 100000000, 0 puntos, "Unknown Emulator"): no son logros del juego
  if (achSet) achSet.achievements = achSet.achievements.filter((a) => a.id < 100000000 && a.points > 0);
  return achSet;
};
const saveProg = () => { try { fs.mkdirSync(LOGROS, { recursive: true }); fs.writeFileSync(PROG, JSON.stringify(prog)); } catch (e) { log('progreso: ' + e.message); } };
let progTimer = null;
const saveProgSoon = () => { if (!progTimer) progTimer = setTimeout(() => { progTimer = null; saveProg(); }, 3000); };

function achPublic() {
  if (!loadSet()) return null;
  return {
    game: achSet.game,
    list: achSet.achievements.map((a) => ({ id: a.id, title: a.title, description: a.description, points: a.points, badge: a.badge, type: a.type })),
    unlocked: prog.unlocked, progress: prog.progress,
    tr: readJson(path.join(LOGROS, 'traducciones.json'), {})
  };
}
function achText(a) {
  const tr = readJson(path.join(LOGROS, 'traducciones.json'), {});
  const t = tr[cfg.ui || 'es'] && tr[cfg.ui || 'es'][a.id];
  return t ? { title: t[0] || a.title, description: t[1] || a.description } : { title: a.title, description: a.description };
}
function badgeUrl(a, locked) {
  const f = (a.badge || '') + (locked ? '_lock' : '') + '.png';
  return exists(path.join(BADGES, f)) ? 'assets/logros/' + f : '';
}
function unlock(id) {
  if (!achSet || prog.unlocked[id]) return;
  const a = achSet.achievements.find((x) => x.id === id);
  if (!a) return;
  prog.unlocked[id] = new Date().toISOString();
  delete prog.progress[id];
  saveProg();
  log('LOGRO ' + id + ' ' + a.title);
  const tx = achText(a);
  toastQueue.push({ title: tx.title, description: tx.description, points: a.points, badge: badgeUrl(a, false), lang: cfg.ui || 'es', sound: cfg.achSound !== 'off' });
  nextToast();
  send('logro', { id, date: prog.unlocked[id] });
}

// Descarga del set desde el launcher (una sola vez): el usuario inicia sesión con su cuenta de RetroAchievements.
// No se guardan ni la contraseña ni el token; solo la lista de logros y sus iconos.
const RA_UA = "TheLastStoryLauncher/1.0 (Dionixu's Launcher)";
async function raDownload(user, pass) {
  const post = async (params) => {
    const r = await net.fetch('https://retroachievements.org/dorequest.php', {
      method: 'POST', headers: { 'User-Agent': RA_UA, 'Content-Type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams(params).toString()
    });
    return r.json();
  };
  send('raProgress', { step: 'login' });
  const login = await post({ r: 'login2', u: user, p: pass });
  if (!login || !login.Success || !login.Token) throw new Error((login && login.Error) || 'login');
  send('raProgress', { step: 'set' });
  const j = await post({ r: 'patch', u: login.User || user, t: login.Token, g: '27' });
  if (!j || !j.Success || !j.PatchData) throw new Error((j && j.Error) || 'patch');
  const p = j.PatchData;
  const list = (p.Achievements || []).filter((a) => a.Flags === 3).map((a) => ({
    id: a.ID, title: a.Title, description: a.Description, points: a.Points, badge: a.BadgeName, type: a.Type, author: a.Author, memaddr: a.MemAddr }));
  fs.mkdirSync(LOGROS, { recursive: true });
  fs.writeFileSync(RA_SET, JSON.stringify({ game: { id: p.ID, title: p.Title, icon: p.ImageIcon }, achievements: list }, null, 1));
  fs.mkdirSync(BADGES, { recursive: true });
  let done = 0;
  for (const a of list) {
    for (const suf of ['', '_lock']) {
      const f = path.join(BADGES, a.badge + suf + '.png');
      if (exists(f)) continue;
      try {
        const r = await net.fetch('https://media.retroachievements.org/Badge/' + a.badge + suf + '.png', { headers: { 'User-Agent': RA_UA } });
        if (r.ok) fs.writeFileSync(f, Buffer.from(await r.arrayBuffer()));
      } catch (e) {}
    }
    send('raProgress', { step: 'badges', done: ++done, total: list.length });
  }
  log('Set de logros descargado: ' + list.length);
}

function createToastWindow() {
  const d = screen.getPrimaryDisplay().bounds;
  toastWin = new BrowserWindow({
    x: d.x + Math.round((d.width - 600) / 2), y: d.y, width: 600, height: 150, show: false, frame: false, transparent: true,
    resizable: false, focusable: false, skipTaskbar: true, alwaysOnTop: true, fullscreenable: false, hasShadow: false, backgroundColor: '#00000000',
    webPreferences: { preload: path.join(__dirname, 'preload.js'), contextIsolation: true, nodeIntegration: false, sandbox: true, backgroundThrottling: false }
  });
  toastWin.setAlwaysOnTop(true, 'screen-saver');
  toastWin.setIgnoreMouseEvents(true);
  toastWin.setMenu(null);
  toastWin.loadURL('tls://ui/toast.html');
}
function nextToast() {
  if (toastBusy || !toastQueue.length || !toastWin || toastWin.isDestroyed()) return;
  if (cfg.achToast === 'off') { toastQueue = []; return; }
  toastBusy = true;
  const d = screen.getPrimaryDisplay().bounds;
  toastWin.setBounds({ x: d.x + Math.round((d.width - 600) / 2), y: d.y, width: 600, height: 150 });
  toastWin.showInactive();                       // sin robar el foco: el juego no se pausa
  toastWin.setAlwaysOnTop(true, 'screen-saver');
  toastWin.webContents.send('msg', JSON.stringify({ type: 'show', data: toastQueue.shift() }));
}

const helper = (name) => {   // binarios propios junto a main.js (en Linux se asegura el permiso de ejecución)
  const f = path.join(__dirname, IS_WIN ? name + '.exe' : name);
  if (!IS_WIN && exists(f)) { try { fs.chmodSync(f, 0o755); } catch (e) {} }
  return f;
};
function startAch(pid) {
  stopAch();
  // el mismo programa evalúa los logros y mantiene el 60 FPS adaptativo
  const wantAch = cfg.achievements !== 'off' && !!loadSet();
  const adapt = cfg.fps === '60';
  if (!wantAch && !adapt) return;
  const exe = helper('tls_logros');
  if (!exists(exe)) { log('Falta ' + exe); return; }
  const defs = wantAch ? achSet.achievements.filter((a) => a.memaddr && !prog.unlocked[a.id]).map((a) => a.id + '\t' + a.memaddr).join('\n') + '\n' : '';
  const f = path.join(LOGROS, 'activos.txt');
  fs.mkdirSync(LOGROS, { recursive: true });
  fs.writeFileSync(f, defs);
  achProc = spawn(exe, [String(pid), f].concat(adapt ? ['--adapt60'] : []), { windowsHide: true, stdio: ['pipe', 'pipe', 'pipe'] });
  let buf = '';
  achProc.stdout.on('data', (d) => {
    buf += d.toString(); let i;
    while ((i = buf.indexOf('\n')) >= 0) {
      const p = buf.slice(0, i).trim().split(' '); buf = buf.slice(i + 1);
      if (p[0] === 'UNLOCK') unlock(parseInt(p[1], 10));
      else if (p[0] === 'PROGRESS') { prog.progress[p[1]] = [parseInt(p[2], 10), parseInt(p[3], 10)]; saveProgSoon(); }
      else if (p[0]) log('logros: ' + p.join(' '));
    }
  });
  achProc.stderr.on('data', (d) => log('logros(err): ' + d.toString().trim()));
  achProc.on('exit', (c) => { log('motor de logros terminado (' + c + ')'); achProc = null; });
  achProc.on('error', (e) => { log('motor de logros: ' + e.message); achProc = null; });
}
function stopAch() {
  if (!achProc) return;
  const p = achProc; achProc = null;
  try { p.stdin.write('QUIT\n'); } catch (e) {}
  setTimeout(() => { try { p.kill(); } catch (e) {} }, 800);
  if (progTimer) { clearTimeout(progTimer); progTimer = null; }
  saveProg();
}

function state() {
  const dol = (dir) => path.join(dir || '', 'DATA', 'sys', 'main.dol');
  return {
    logros: achPublic(),
    config: cfg,
    platform: process.platform,
    fullscreen: !!(win && win.isFullScreen()),
    dolphinOk: dolphinCommand().ok,
    gameEnOk: exists(dol(paths.gameEN)),
    gameJpOk: exists(dol(paths.gameJP)) && exists(path.join(paths.gameJP || '', 'listo.txt')),
    fps60Ok: true,
    musicOk: exists(path.join(UI, 'assets', 'music.mp3'))
  };
}

// ---------------- controles: mando + teclado/ratón a la vez sobre el Classic Controller
// Windows: XInput + DirectInput.  Linux: SDL (mismos nombres de botón que XInput) + XInput2 (nombres de teclas X11).
const KBDEV = IS_WIN ? 'DInput/0/Keyboard Mouse' : 'XInput2/0/Virtual core pointer';
const PAD_DEF = { a: 'Button A', b: 'Button B', x: 'Button X', y: 'Button Y', zl: 'Shoulder L', zr: 'Shoulder R', l: 'Trigger L', r: 'Trigger R', plus: 'Start', minus: 'Back', du: 'Pad N', dd: 'Pad S', dl: 'Pad W', dr: 'Pad E' };
const KB_DEF = { ls_up: 'W', ls_down: 'S', ls_left: 'A', ls_right: 'D', walk: 'LCONTROL', rs_up: 'UP', rs_down: 'DOWN', rs_left: 'LEFT', rs_right: 'RIGHT',
  a: 'E', b: 'Q', x: 'R', y: 'F', zl: 'LSHIFT', zr: 'SPACE', l: 'Click 1', r: 'Click 0', plus: 'TAB', minus: 'M', du: '1', dd: '2', dl: '3', dr: '4' };
const CLASSIC = { a: 'Buttons/A', b: 'Buttons/B', x: 'Buttons/X', y: 'Buttons/Y', zl: 'Buttons/ZL', zr: 'Buttons/ZR', plus: 'Buttons/+', minus: 'Buttons/-',
  l: 'Triggers/L', r: 'Triggers/R', du: 'D-Pad/Up', dd: 'D-Pad/Down', dl: 'D-Pad/Left', dr: 'D-Pad/Right' };
const MOUSE_SENS = { 1: 0.035, 2: 0.06, 3: 0.09, 4: 0.13, 5: 0.19 };
// Nombres DirectInput (los que guarda la interfaz) → nombres X11 de Dolphin en Linux
const DI2X = { SPACE: 'space', LSHIFT: 'Shift_L', RSHIFT: 'Shift_R', LCONTROL: 'Control_L', RCONTROL: 'Control_R', LMENU: 'Alt_L', RMENU: 'ISO_Level3_Shift',
  RETURN: 'Return', NUMPADENTER: 'KP_Enter', ESCAPE: 'Escape', TAB: 'Tab', BACK: 'BackSpace', CAPITAL: 'Caps_Lock', UP: 'Up', DOWN: 'Down', LEFT: 'Left',
  RIGHT: 'Right', MINUS: 'minus', EQUALS: 'equal', LBRACKET: 'bracketleft', RBRACKET: 'bracketright', SEMICOLON: 'semicolon', APOSTROPHE: 'apostrophe',
  GRAVE: 'grave', BACKSLASH: 'backslash', OEM_102: 'less', COMMA: 'comma', PERIOD: 'period', SLASH: 'slash', INSERT: 'Insert', DELETE: 'Delete',
  HOME: 'Home', END: 'End', PRIOR: 'Prior', NEXT: 'Next', ADD: 'KP_Add', SUBTRACT: 'KP_Subtract', MULTIPLY: 'KP_Multiply', DIVIDE: 'KP_Divide',
  DECIMAL: 'KP_Decimal', 'Click 0': 'Click 1', 'Click 1': 'Click 3', 'Click 2': 'Click 2', 'Click 3': 'Click 8', 'Click 4': 'Click 9' };
const keyName = (n) => IS_WIN ? n : (DI2X[n] || (/^NUMPAD(\d)$/.test(n) ? 'KP_' + n.slice(6) : n));
// Nombres con que SDL suele presentar los mandos más comunes (más los que vea el puente). Los que no existan no hacen nada.
const SDL_PADS = ['Xbox 360 Controller', 'Xbox One Controller', 'Xbox Series X Controller', 'Xbox Wireless Controller', 'PS4 Controller', 'PS5 Controller',
  'Nintendo Switch Pro Controller', 'Steam Deck', 'Steam Virtual Gamepad', 'Steam Controller', '8BitDo Pro 2', 'Logitech Dual Action'];

function writeControls() {
  const P = Object.assign({}, PAD_DEF, cfg.padBinds || {});
  const K = Object.assign({}, KB_DEF, cfg.kbBinds || {});
  const padNames = IS_WIN ? [] : [...new Set([...(cfg.padNames || []), ...SDL_PADS])].slice(0, 16);
  const or = (...e) => e.filter(Boolean).join(' | ');
  const pad = (n, dz) => IS_WIN ? (dz ? 'deadzone(`' + n + '`, 0.15)' : '`' + n + '`')
    : or(...padNames.map((d) => dz ? 'deadzone(`SDL/0/' + d + ':' + n + '`, 0.15)' : '`SDL/0/' + d + ':' + n + '`'));
  const kb = (n) => n && n !== 'ESCAPE' && n !== 'F9' ? '`' + KBDEV + ':' + keyName(n) + '`' : '';   // Esc = pausa, F9 = captura
  const L = ['[Wiimote1]', 'Device = ' + (IS_WIN ? 'XInput/0/Gamepad' : 'SDL/0/' + padNames[0]), 'Extension = Classic'];
  const set = (k, v) => L.push('Classic/' + k + ' = ' + v);
  for (const id in CLASSIC) {
    // Enter y Retroceso siempre sirven para confirmar / cancelar en menús, salvo que se usen para otra cosa
    const extra = id === 'a' && !Object.values(K).includes('RETURN') ? 'RETURN' : id === 'b' && !Object.values(K).includes('BACK') ? 'BACK' : '';
    const e = or(pad(P[id]), kb(K[id]), kb(extra));
    set(CLASSIC[id], e);
    if (id === 'l' || id === 'r') set(CLASSIC[id].replace(/([LR])$/, '$1-Analog'), e);
  }
  set('Left Stick/Up', or(pad('Left Y+', true), kb(K.ls_up)));
  set('Left Stick/Down', or(pad('Left Y-', true), kb(K.ls_down)));
  set('Left Stick/Left', or(pad('Left X-', true), kb(K.ls_left)));
  set('Left Stick/Right', or(pad('Left X+', true), kb(K.ls_right)));
  set('Left Stick/Modifier', or(pad('Thumb L'), kb(K.walk)));
  set('Left Stick/Dead Zone', '0.');
  const pi = cfg.padInvert === 'on', ki = cfg.kbInvert === 'on';
  const k = MOUSE_SENS[cfg.kbSens || '2'] || 0.06;
  const mouse = (ax) => '`' + KBDEV + ':RelativeMouse ' + ax + '` * ' + k;
  const cam = cfg.kbCam !== 'keys';
  set('Right Stick/Up', or(pad('Right Y' + (pi ? '-' : '+'), true), cam ? mouse(ki ? 'Y+' : 'Y-') : kb(K.rs_up)));
  set('Right Stick/Down', or(pad('Right Y' + (pi ? '+' : '-'), true), cam ? mouse(ki ? 'Y-' : 'Y+') : kb(K.rs_down)));
  set('Right Stick/Left', or(pad('Right X-', true), cam ? mouse('X-') : kb(K.rs_left)));
  set('Right Stick/Right', or(pad('Right X+', true), cam ? mouse('X+') : kb(K.rs_right)));
  set('Right Stick/Modifier', pad('Thumb R'));
  set('Right Stick/Dead Zone', '0.');
  L.push('Source = 1', '[Wiimote2]', 'Source = 0', '[Wiimote3]', 'Source = 0', '[Wiimote4]', 'Source = 0', '[BalanceBoard]', 'Source = 0');
  const cfgDir = userPath('Config');
  fs.mkdirSync(cfgDir, { recursive: true });
  fs.writeFileSync(path.join(cfgDir, 'WiimoteNew.ini'), L.join('\n') + '\n');
  // Atajos de Dolphin: por defecto Esc DETIENE el juego y Tab lo acelera sin límite. Solo dejamos pantalla completa y captura.
  fs.writeFileSync(path.join(cfgDir, 'Hotkeys.ini'), ['[Hotkeys]', 'Device = ' + KBDEV,
    'General/Toggle Fullscreen = @(Alt+' + (IS_WIN ? 'RETURN' : 'Return') + ')', 'General/Take Screenshot = F9'].join('\n') + '\n');
  return cam;
}

function applyButtons(which, dyn) {
  const store = path.join(DATA, 'botones', which === 'wii' ? 'wii' : which === 'kb' ? 'teclado' : 'xbox');
  const active = paths.buttonsActive;
  if (!active || !exists(store)) return;
  // Quita duplicados del mismo nombre en el resto del pack (Dolphin no sabria cual usar)
  const names = new Set(fs.readdirSync(store).filter((f) => f.toLowerCase().endsWith('.png')));
  const sweep = (dir) => {
    for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
      const p = path.join(dir, e.name);
      if (e.isDirectory()) { if (path.resolve(p) !== path.resolve(active)) sweep(p); }
      else if (names.has(e.name)) { fs.rmSync(p, { force: true }); log('Duplicado retirado: ' + p); }
    }
  };
  try { if (exists(path.dirname(active))) sweep(path.dirname(active)); } catch (e) { log('sweep: ' + e.message); }
  fs.rmSync(active, { recursive: true, force: true });
  fs.mkdirSync(active, { recursive: true });
  for (const f of fs.readdirSync(store)) if (f.toLowerCase().endsWith('.png')) fs.copyFileSync(path.join(store, f), path.join(active, f));
  // iconos de teclado dibujados por la interfaz con las teclas elegidas
  if (which === 'kb' && dyn && typeof dyn === 'object') {
    for (const [name, url] of Object.entries(dyn)) {
      if (!/^tex1_[\w]+\.png$/.test(name) || typeof url !== 'string' || !url.startsWith('data:image/png;base64,')) continue;
      fs.writeFileSync(path.join(active, name), Buffer.from(url.slice(22), 'base64'));
    }
  }
}

// Código 60 FPS (Dolphin Wiki, NA/EU). Verificado contra main.dol USA: los 5 ganchos C2 coinciden.
const GECKO_60FPS = [
  '$60 FPS',
  '04C94DB0 0000003C', '04C94C04 3F000000', '04885A08 3F860000', '04885A50 3F333333',
  'C213CC80 00000002', 'C00303A4 EC000024', '60000000 00000000',
  'C213CB74 00000002', '396106B0 C0A29408', 'EC420172 00000000',
  '04881A08 3EAC8B44',
  'C23B6A14 00000002', '7C631A14 907F0058', '60000000 00000000',
  'C21F68C8 00000002', 'C0030054 C0428668', 'EC0000B2 00000000',
  'C21F4418 00000002', 'C0428668 EC0000B2', 'C04300A0 00000000',
  '2087FE78 00000001', '04C94DB0 0000001E', '04C94C04 3F800000', 'E0000000 80008000'
];
// Mejoras visuales de sergx12 (Dolphin Wiki). DOF y rayos verificados contra main.dol USA.
const GECKO_EXTRA = {
  shadows: ['$Sombras de alta calidad', '04C94C70 00000000'],
  grading: ['$Sin correccion de color', '04C94B84 00000000'],
  dof:     ['$Desenfoque reducido', '04C9495C 3EC00000', '04C94960 3EC00000', '04794DA0 3EC00000', '04794DA4 3EC00000'],
  rays:    ['$Rayos de luz suaves', '04880E2C 42FF0000']
};
// Escribe la configuración del juego para Dolphin (GameSettings/SLSEXJ.ini) según los ajustes
function writeGameSettings() {
  const dir = userPath('GameSettings');
  fs.mkdirSync(dir, { recursive: true });
  const lines = ["# Generado por Dionixu's Launcher",
    '[OnFrame]',
    '# Pantalla de la correa del mando (StrapTask): siempre oculta.',
    '# 1) el constructor empieza en el estado 2 (desvanecer y salir) en vez del 1 (aparecer)',
    '# 2) el contador del desvanecimiento empieza en 48 (r6) en vez de 0 -> sale en el primer frame',
    '$Saltar pantalla del mando',
    '0x805A6294:dword:0x38C00002',
    '0x805A62BC:dword:0x90DB004C',
    '[OnFrame_Enabled]',
    '$Saltar pantalla del mando',
    '[Gecko]', ...GECKO_60FPS];
  for (const k in GECKO_EXTRA) lines.push(...GECKO_EXTRA[k]);
  lines.push('', '[Gecko_Enabled]');
  let any = false;
  if (cfg.fps === '60') { lines.push('$60 FPS'); any = true; }
  for (const k in GECKO_EXTRA) if (cfg['gfx_' + k] === 'on') { lines.push(GECKO_EXTRA[k][0]); any = true; }
  fs.writeFileSync(path.join(dir, 'SLSEXJ.ini'), lines.join('\n') + '\n');
  return any;
}

// Edita claves de un .ini de Dolphin conservando el resto del archivo
function setIni(file, values) {
  let text = '';
  try { text = fs.readFileSync(file, 'utf8'); } catch (e) {}
  const lines = text.split(/\r?\n/);
  for (const [section, entries] of Object.entries(values)) {
    let start = lines.findIndex((l) => l.trim().toLowerCase() === '[' + section.toLowerCase() + ']');
    if (start < 0) { if (lines.length && lines[lines.length - 1] !== '') lines.push(''); lines.push('[' + section + ']'); start = lines.length - 1; }
    for (const [key, val] of Object.entries(entries)) {
      let end = lines.findIndex((l, i) => i > start && /^\s*\[/.test(l)); if (end < 0) end = lines.length;
      const i = lines.findIndex((l, j) => j > start && j < end && l.split('=')[0].trim().toLowerCase() === key.toLowerCase());
      const line = key + ' = ' + val;
      if (i >= 0) lines[i] = line; else lines.splice(end, 0, line);
    }
  }
  fs.mkdirSync(path.dirname(file), { recursive: true });
  fs.writeFileSync(file, lines.join(IS_WIN ? '\r\n' : '\n').replace(/(\r?\n)+$/, '') + (IS_WIN ? '\r\n' : '\n'));
}

function toggleFull(force) {
  if (!win) return;
  const on = typeof force === 'boolean' ? force : !win.isFullScreen();
  win.setFullScreen(on);
  cfg.launcherFull = on ? 'on' : 'off';
  saveCfg();
}

// Espera a que aparezca la ventana del juego (o 9 s como máximo)
let winWaiters = [];
function waitGameWindow(pid) {
  return new Promise((resolve) => {
    let done = false;
    const finish = (why) => { if (done) return; done = true; log('Ventana del juego detectada (' + why + ')'); resolve(); };
    setTimeout(() => finish('tiempo'), 9000);
    if (IS_WIN) {
      const ps = `$t=0; while ($t -lt 90) { $p = Get-Process -Id ${pid} -ErrorAction SilentlyContinue; if (-not $p) { exit 2 };
        $w = $p.MainWindowTitle; if ($w -and $w -ne 'Dolphin' -and $t -gt 5) { exit 0 }; Start-Sleep -Milliseconds 100; $t++ }; exit 1`;
      const w = spawn('powershell.exe', ['-NoProfile', '-NonInteractive', '-Command', ps], { windowsHide: true, stdio: 'ignore' });
      w.on('exit', (c) => finish('codigo ' + c));
      w.on('error', () => {});
    } else {
      winWaiters.push(() => setTimeout(() => finish('X11'), 600));   // el puente avisa con "WIN <xid>"
    }
  });
}

// ---------------- volumen en vivo
// Windows: el puente ajusta el volumen de Dolphin en el mezclador.  Linux: PulseAudio/PipeWire con pactl.
let volTarget = null, volTimer = null, volApplied = null;
const pactl = (args) => new Promise((ok) => execFile('pactl', args, { timeout: 4000 }, (e, out) => ok(e ? null : String(out))));
async function linuxApplyVolume() {
  if (volTarget == null || !game) return;
  const out = await pactl(['list', 'sink-inputs']);
  if (out == null) { if (cfg.audioCtl !== 'no') { cfg.audioCtl = 'no'; saveCfg(); log('volumen en vivo: no hay pactl'); } return; }
  const ids = [];
  for (const block of out.split(/\n(?=Sink Input #)/)) {
    const m = /Sink Input #(\d+)/.exec(block);
    if (m && /application\.(name|process\.binary) = "[^"]*dolphin/i.test(block)) ids.push(m[1]);
  }
  for (const id of ids) await pactl(['set-sink-input-volume', id, volTarget + '%']);
  if (ids.length && volApplied !== volTarget) { volApplied = volTarget; log('volumen del juego aplicado: ' + volTarget + '%'); }
}
function setGameVolume(v) {
  volTarget = Math.max(0, Math.min(100, parseInt(v, 10) || 0));
  if (IS_WIN) { if (game && cfg.audioCtl !== 'no') bridgeCmd('VOLUME ' + game.pid + ' ' + volTarget); return; }
  linuxApplyVolume();
  if (!volTimer) volTimer = setInterval(() => { if (!game) { clearInterval(volTimer); volTimer = null; volApplied = null; } else linuxApplyVolume(); }, 1500);
}

// ---------------- puente de mando + menú de pausa (L3 + R3 / Esc)
const sendExit = (type, data) => { if (exitWin && !exitWin.isDestroyed()) exitWin.webContents.send('msg', JSON.stringify({ type, data })); };
const bridgeCmd = (s) => { try { if (bridge && bridge.stdin.writable) bridge.stdin.write(s + '\n'); } catch (e) {} };
const hwnd = (w) => { const b = w.getNativeWindowHandle(); return (b.length >= 8 ? b.readBigUInt64LE(0) : BigInt(b.readUInt32LE(0))).toString(); };

function createExitWindow() {
  const d = screen.getPrimaryDisplay().bounds;
  exitWin = new BrowserWindow({
    x: d.x, y: d.y, width: d.width, height: d.height, show: false, frame: false, transparent: true, resizable: false,
    skipTaskbar: true, alwaysOnTop: true, fullscreenable: false, hasShadow: false, backgroundColor: '#00000000',
    webPreferences: { preload: path.join(__dirname, 'preload.js'), contextIsolation: true, nodeIntegration: false, sandbox: true }
  });
  exitWin.setAlwaysOnTop(true, 'screen-saver');
  exitWin.setMenu(null);
  exitWin.loadURL('tls://ui/exit.html');
}

function startBridge() {
  stopBridge();
  bridge = IS_WIN
    ? spawn('powershell.exe', ['-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass', '-File', path.join(__dirname, 'bridge.ps1')], { windowsHide: true, stdio: ['pipe', 'pipe', 'ignore'] })
    : spawn(helper('tls_bridge'), [], { stdio: ['pipe', 'pipe', 'ignore'] });
  let buf = '';
  bridge.stdout.on('data', (d) => {
    buf += d.toString(); let i;
    while ((i = buf.indexOf('\n')) >= 0) {
      const line = buf.slice(0, i).trim(); buf = buf.slice(i + 1);
      if (line.startsWith('COMBO')) openExit(line === 'COMBO KB' ? 'kb' : 'pad');
      else if (line.startsWith('BTN ') && exitOpen) sendExit('btn', line.slice(4));
      else if (line.startsWith('WIN ')) { const w = winWaiters; winWaiters = []; w.forEach((f) => f()); }
      else if (line.startsWith('PAD ')) {   // nombre del mando (Linux): se añade a los candidatos de SDL
        const n = line.slice(4).trim();
        if (n && n !== '?' && !(cfg.padNames || []).includes(n)) { cfg.padNames = [n, ...(cfg.padNames || [])].slice(0, 6); saveCfg(); }
        log('mando: ' + n);
      } else if (line === 'AUDIO OK' || line === 'AUDIO NO') {
        const v = line === 'AUDIO OK' ? 'ok' : 'no';
        if (cfg.audioCtl !== v) { cfg.audioCtl = v; saveCfg(); }
        log('volumen en vivo: ' + v);
      } else if (line.startsWith('VOLSET')) log('volumen del juego aplicado: ' + line.slice(7) + '%');
      else if (line === 'X11 OK' || line === 'X11 NO') log('puente: ' + line);
    }
  });
  bridge.on('error', (e) => { log('puente: ' + e.message); bridge = null; });
  bridge.on('exit', () => { bridge = null; });
}
function stopBridge() { if (bridge) { bridgeCmd('QUIT'); const b = bridge; setTimeout(() => { try { b.kill(); } catch (e) {} }, 500); bridge = null; } }

function openExit(via) {
  if (!game || exitOpen || !exitWin) return;
  exitOpen = true;
  const d = screen.getPrimaryDisplay().bounds; exitWin.setBounds(d);
  exitWin.show(); exitWin.setAlwaysOnTop(true, 'screen-saver');
  bridgeCmd('FOCUS ' + hwnd(exitWin));      // el juego pierde el foco -> se pausa
  exitWin.focus();
  sendExit('show', { lang: cfg.ui || 'es', via: via || 'pad', gvol: cfg.gvol || '100' });
}
function closeExit(back) {
  exitOpen = false;
  if (back) {
    // Volver al launcher: la ventana principal (en negro) cubre todo antes de cerrar Dolphin
    win.setAlwaysOnTop(true, 'screen-saver');
    win.show(); if (cfg.launcherFull !== 'off') win.setFullScreen(true);
    bridgeCmd('FOCUS ' + hwnd(win)); win.focus();
    setTimeout(() => { exitWin.hide(); sendExit('hide'); }, 120);
    if (game) {
      const g = game; bridgeCmd('CLOSEPID ' + g.pid);
      setTimeout(() => { if (game === g) { try { g.kill(); } catch (e) {} } }, 5000);
    }
  } else {
    exitWin.hide(); sendExit('hide');
    if (game) bridgeCmd('FOCUSPID ' + game.pid);   // devolver el foco al juego -> se reanuda
  }
}

function play(iconSet, kbTex) {
  if (game) return;
  const st = state();
  const dc = dolphinCommand();
  if (!dc.ok) throw new Error('No encuentro Dolphin: ' + paths.dolphinExe);
  const jp = cfg.voice === 'jp' && st.gameJpOk;
  const gameDir = jp ? paths.gameJP : paths.gameEN;
  const dol = path.join(gameDir, 'DATA', 'sys', 'main.dol');
  if (!exists(dol)) throw new Error('No encuentro el juego en ' + gameDir);

  const set = ['xbox', 'wii', 'kb'].includes(iconSet) ? iconSet : (cfg.buttons === 'wii' ? 'wii' : cfg.buttons === 'kb' ? 'kb' : 'xbox');
  applyButtons(set, kbTex);
  const mouseCam = writeControls();
  const cheats = writeGameSettings();
  // Gráficos: se escriben en GFX.ini porque Dolphin ignora los -C de la sección GFX al arrancar
  const gfxIni = userPath('Config', 'GFX.ini');
  const res = cfg.res || '1080';
  const ir = res === '720' ? 2 : 3;
  const [ww, wh] = res === '720' ? [1280, 720] : res === '900' ? [1600, 900] : [1920, 1080];
  const lng = cfg.text === 'es' ? 4 : cfg.text === 'fr' ? 3 : 1;
  const C = (k, v) => ['-C', k + '=' + v];
  const args = [
    ...dc.pre,
    ...(IS_WIN ? [] : ['-u', USER]),
    '-b', '-e', dol,
    ...C('Dolphin.Display.Fullscreen', (cfg.mode || 'full') === 'full' ? 'True' : 'False'),
    ...C('Dolphin.Display.RenderToMain', 'False'),
    ...C('Dolphin.Display.RenderWindowWidth', ww),
    ...C('Dolphin.Display.RenderWindowHeight', wh),
    ...C('Dolphin.Display.RenderWindowAutoSize', 'False'),
    ...C('Dolphin.Interface.ConfirmStop', 'False'),
    ...C('GFX.Settings.InternalResolution', ir),
    ...C('GFX.Settings.HiresTextures', (cfg.hd || 'on') === 'on' ? 'True' : 'False'),
    ...C('GFX.Hacks.ImmediateXFBEnable', 'True'),
    ...C('GFX.Hardware.VSync', (cfg.vsync || 'on') === 'on' ? 'True' : 'False'),
    ...C('SYSCONF.IPL.LNG', lng),
    ...C('Dolphin.Core.EnableCheats', cheats ? 'True' : 'False'),
    ...((() => { try { return fs.readFileSync(path.join(DATA, 'dump_textures.on'), 'utf8').trim() === 'on'; } catch (e) { return false; } })() ? C('GFX.Settings.DumpTextures', 'True') : [])
  ];
  setIni(gfxIni, {
    Settings: { InternalResolution: ir, HiresTextures: (cfg.hd || 'on') === 'on' ? 'True' : 'False', CacheHiresTextures: 'True', DumpTextures: 'False',
      ShaderCompilationMode: 2, WaitForShadersBeforeStarting: 'False', BorderlessFullscreen: 'True' },   // ubershaders: sin tirones con efectos nuevos
    Hardware: { VSync: (cfg.vsync || 'on') === 'on' ? 'True' : 'False' },
    Hacks: { ImmediateXFBEnable: 'True' }
  });
  setIni(userPath('Config', 'Dolphin.ini'), {
    // volumen: Dolphin al 100 % y el launcher lo ajusta en vivo (mezclador de Windows / pactl). Si no puede, lo pone Dolphin.
    DSP: { Volume: cfg.audioCtl === 'no' ? parseInt(cfg.gvol || '100', 10) : 100 },
    // ratón como cámara: cursor oculto y encerrado en la ventana del juego (CursorVisibility 0 = nunca, 2 = al moverse)
    Interface: { PauseOnFocusLost: 'True', ConfirmStop: 'False', LockCursor: mouseCam ? 'True' : 'False', CursorVisibility: mouseCam ? 0 : 2,
      OnScreenDisplayMessages: 'False' },   // sin avisos de Dolphin arriba a la izquierda
    Input: { BackgroundInput: 'False' }
  });
  // Los logros los evalúa el launcher sin conexión: se apaga el cliente en línea de Dolphin para no duplicar avisos
  setIni(userPath('Config', 'RetroAchievements.ini'), { Achievements: { Enabled: 'False' } });
  log('Iniciando: ' + dc.cmd + ' ' + args.join(' '));
  win.setAlwaysOnTop(true, 'screen-saver');
  game = spawn(dc.cmd, args, { cwd: IS_WIN ? path.dirname(paths.dolphinExe) : ROOT, stdio: 'ignore' });
  startBridge();
  bridgeCmd('GAMEPID ' + game.pid);
  setGameVolume(cfg.gvol || '100');
  startAch(game.pid);
  const myGame = game;
  waitGameWindow(game.pid).then(() => {
    if (cfg.mode === 'borderless') {
      // ventana sin bordes: quitar el marco y centrar (dos veces por si Dolphin la redimensiona al arrancar)
      bridgeCmd('BORDERLESS ' + myGame.pid + ' ' + ww + ' ' + wh);
      setTimeout(() => { if (game === myGame) bridgeCmd('BORDERLESS ' + myGame.pid + ' ' + ww + ' ' + wh); }, 1500);
    }
    setTimeout(() => { if (game === myGame) { win.setAlwaysOnTop(false); win.hide(); bridgeCmd('FOCUSPID ' + myGame.pid); } }, 900);
  });
  game.on('error', (e) => { log('Error al iniciar Dolphin: ' + e.message); game = null; win.setAlwaysOnTop(false); win.show(); send('error', e.message); });
  game.on('exit', (code) => {
    log('Dolphin cerrado (codigo ' + code + ')');
    game = null;
    stopBridge();
    stopAch();
    if (exitOpen) { exitOpen = false; exitWin.hide(); sendExit('hide'); }
    win.show(); if (cfg.launcherFull !== 'off') win.setFullScreen(true); win.focus();
    setTimeout(() => win.setAlwaysOnTop(false), 400);
    send('gameClosed', null);
  });
  send('gameStarted', jp ? 'jp' : 'en');
}

ipcMain.on('msg', (_e, raw) => {
  let m; try { m = JSON.parse(raw); } catch (e) { return; }
  try {
    switch (m.cmd) {
      case 'init': send('state', state()); break;
      case 'save': if (m.config) { cfg = Object.assign(m.config, { launcherFull: cfg.launcherFull, padNames: cfg.padNames, audioCtl: cfg.audioCtl }); saveCfg(); } break;
      case 'play': if (m.config) { cfg = Object.assign(m.config, { launcherFull: cfg.launcherFull, padNames: cfg.padNames, audioCtl: cfg.audioCtl }); saveCfg(); } play(m.iconSet, m.kbTex); break;
      case 'minimize': win.minimize(); break;
      case 'toggleFull': toggleFull(); break;
      case 'close': app.quit(); break;
      case 'exitYes': closeExit(true); break;
      case 'exitNo': closeExit(false); break;
      case 'gvol': {   // volumen cambiado desde el menú de pausa: en vivo + guardado
        cfg.gvol = String(Math.max(0, Math.min(100, parseInt(m.value, 10) || 0))); saveCfg();
        if (game) setGameVolume(cfg.gvol);
        send('cfgPatch', { gvol: cfg.gvol });
        break;
      }
      case 'raLogin':
        raDownload(String(m.user || ''), String(m.pass || ''))
          .then(() => { send('raDone', { ok: true }); send('state', state()); })
          .catch((e) => { log('RetroAchievements: ' + e.message); send('raDone', { ok: false, error: e.message }); });
        break;
      case 'toastDone': toastBusy = false; if (toastQueue.length) nextToast(); else if (toastWin) toastWin.hide(); break;
      case 'toastTest': toastQueue.push({ title: 'The Last Story', description: String(m.text || '').slice(0, 200), points: 10, badge: '', lang: cfg.ui || 'es', sound: cfg.achSound !== 'off' }); nextToast(); break;
    }
  } catch (e) { log('ERROR ' + m.cmd + ': ' + e.stack); send('error', e.message); }
});

function createWindow() {
  const wa = screen.getPrimaryDisplay().workAreaSize;
  const fit = Math.min(1, (wa.width * 0.9) / 1280, (wa.height * 0.9) / 720);
  if (WINDOWED_START) { cfg.launcherFull = 'off'; saveCfg(); }
  win = new BrowserWindow({
    width: Math.round(1280 * fit), height: Math.round(720 * fit), center: true,
    frame: false, resizable: true, maximizable: false, fullscreenable: true, minWidth: 640, minHeight: 360,
    backgroundColor: '#f1e5cc', show: false, title: APP_NAME,
    icon: path.join(UI, 'assets', IS_WIN ? 'icon.ico' : 'icon.png'),
    webPreferences: { preload: path.join(__dirname, 'preload.js'), contextIsolation: true, nodeIntegration: false, sandbox: true }
  });
  win.setMenu(null);
  win.loadURL('tls://ui/index.html');
  win.setAspectRatio(16 / 9);
  win.once('ready-to-show', () => { win.show(); if (cfg.launcherFull !== 'off') win.setFullScreen(true); });
  win.on('enter-full-screen', () => send('fullscreen', true));
  win.on('leave-full-screen', () => send('fullscreen', false));
  // F11 o Alt+Enter: alternar pantalla completa / ventana
  win.webContents.on('before-input-event', (e, input) => {
    if (input.type !== 'keyDown') return;
    if (input.key === 'F11' || (input.alt && input.key === 'Enter')) { e.preventDefault(); toggleFull(); }
  });
}

if (!app.requestSingleInstanceLock()) app.quit();
else {
  app.on('second-instance', () => { if (win) { win.show(); win.focus(); } });
  app.whenReady().then(() => {
    fs.mkdirSync(DATA, { recursive: true });
    protocol.handle('tls', (req) => {
      const rel = decodeURIComponent(new URL(req.url).pathname).replace(/^\/+/, '');
      const file = path.resolve(UI, rel);
      if (!file.startsWith(path.resolve(UI))) return new Response('Prohibido', { status: 403 });
      return net.fetch(pathToFileURL(file).toString());
    });
    createWindow();
    createExitWindow();
    createToastWindow();
  });
  app.on('before-quit', () => { stopBridge(); stopAch(); });
  app.on('window-all-closed', () => app.quit());
}
