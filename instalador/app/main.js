// Instalador de The Last Story HD — Dionixu's Launcher (Windows y Linux)
// No incluye el juego: lo construye a partir de las copias originales del usuario (USA + Japón) y las verifica.
const { app, BrowserWindow, ipcMain, dialog, protocol, net, shell } = require('electron');
const { pathToFileURL } = require('url');
const path = require('path');
const fs = require('fs');
const os = require('os');
const crypto = require('crypto');
const { spawn, execFile } = require('child_process');

const IS_WIN = process.platform === 'win32';
const IS_LINUX = process.platform === 'linux';
const ROOT = path.dirname(process.execPath);
const UI = path.join(__dirname, 'ui');
// payload: junto al ejecutable (Windows) o en la carpeta superior (Linux: INSTALADOR/Linux/runtime + payload)
const PAYLOAD = [path.join(ROOT, 'payload'), path.resolve(ROOT, '..', 'payload')].find((p) => fs.existsSync(p)) || path.join(ROOT, 'payload');

if (IS_LINUX) app.commandLine.appendSwitch('ozone-platform', 'x11');
protocol.registerSchemesAsPrivileged([{ scheme: 'tls', privileges: { standard: true, secure: true, supportFetchAPI: true, stream: true } }]);
app.setPath('userData', path.join(os.tmpdir(), 'tls-hd-installer'));
app.setName("Dionixu's Launcher");

let win = null;
const send = (type, data) => { if (win && !win.isDestroyed()) win.webContents.send('msg', JSON.stringify({ type, data })); };
const exists = (f) => { try { return fs.existsSync(f); } catch (e) { return false; } };
const logLines = [];
const log = (s) => { logLines.push(new Date().toISOString() + '  ' + s); send('log', s); };

// ---------------------------------------------------------------- datos de las copias originales
const GAMES = {
  us: { id: 'SLSEXJ', md5: { 'DATA/sys/main.dol': 'E9F0CEC7DD0E088B6D2A78F7084007E1', 'DATA/sys/boot.bin': 'E6D0D3A12097E4A6C2A081F52D52C349',
    'DATA/files/sound/lastworld.brsar': 'E67F13C0558047667C4167399D60EF0F' }, bytes: 5.24e9 },
  jp: { id: 'SLSJ01', md5: { 'DATA/sys/main.dol': '225805AF6CA3E5CD6413D1B2BF4F842B', 'DATA/sys/boot.bin': 'C2054F48D9B3D1B94E238125C26CB2AF',
    'DATA/files/sound/lastworld.brsar': 'F515780FC5D77A255A0881C64438FB77' }, bytes: 5.2e9 }
};
const BRSAR_JP_MD5 = '378DE37B5EA4EFAE338390BC423BF2CF';
// archivos que se toman de la versión japonesa: voces, efectos de voz, audio de escenas, videos en tiempo real y las 8 cinemáticas con diálogo
const VOICE_RE = /^(VO_.*|SE_VO.*|ev\d.*)\.brstm$|^RTMV_.*\.thp$/i;
const MOVIES_JP = new Set(['mv01_ev0405.thp', 'mv04-3-1_ev1510.thp', 'mv04-3-3_ev1510.thp', 'mv06_ev0507.thp', 'mv13_ev2005.thp',
  'mv17_ev3206.thp', 'mv18_ev3209.thp', 'mv19_ev3212.thp']);

// ---------------------------------------------------------------- utilidades
const md5 = (file) => new Promise((ok, ko) => {
  const h = crypto.createHash('md5'); const s = fs.createReadStream(file);
  s.on('data', (d) => h.update(d)); s.on('end', () => ok(h.digest('hex').toUpperCase())); s.on('error', ko);
});
function walk(dir, base = dir, out = []) {
  for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
    const p = path.join(dir, e.name);
    if (e.isDirectory()) walk(p, base, out); else if (e.isFile()) out.push(path.relative(base, p));
  }
  return out;
}
function dirBytes(dir) {
  let n = 0;
  const go = (d) => { let l; try { l = fs.readdirSync(d, { withFileTypes: true }); } catch (e) { return; }
    for (const e of l) { const p = path.join(d, e.name); if (e.isDirectory()) go(p); else { try { n += fs.statSync(p).size; } catch (x) {} } } };
  go(dir);
  return n;
}
function copyDir(src, dst, filter) {
  fs.mkdirSync(dst, { recursive: true });
  for (const e of fs.readdirSync(src, { withFileTypes: true })) {
    const s = path.join(src, e.name), d = path.join(dst, e.name);
    if (filter && !filter(s, e)) continue;
    if (e.isDirectory()) copyDir(s, d, filter); else fs.copyFileSync(s, d);
  }
}
function linkOrCopy(src, dst) {
  try { fs.linkSync(src, dst); return true; } catch (e) { fs.copyFileSync(src, dst); return false; }
}
function freeBytes(dir) {
  let d = path.resolve(dir);
  while (!exists(d)) { const up = path.dirname(d); if (up === d) break; d = up; }
  try { const s = fs.statfsSync(d); return s.bavail * s.bsize; } catch (e) { return Infinity; }
}
const which = (cmd) => (process.env.PATH || '').split(IS_WIN ? ';' : ':').map((d) => path.join(d, cmd)).find((p) => exists(p)) || null;
const run = (cmd, args, opts = {}) => new Promise((ok) => {
  const p = spawn(cmd, args, Object.assign({ windowsHide: true }, opts));
  let out = '', err = '';
  if (p.stdout) p.stdout.on('data', (d) => { out += d; });
  if (p.stderr) p.stderr.on('data', (d) => { err += d; });
  p.on('error', (e) => ok({ code: -1, out, err: err + e.message }));
  p.on('exit', (code) => ok({ code, out, err }));
});

// ---------------------------------------------------------------- Dolphin / DolphinTool
// Windows: Dolphin incluido en el instalador.  Linux: el del usuario (paquete, AppImage o Flatpak).
function linuxDetect() {
  const found = [];
  const bin = which('dolphin-emu');
  if (bin) found.push({ kind: 'bin', path: bin, tool: which('dolphin-tool') || (exists(path.join(path.dirname(bin), 'dolphin-tool')) ? path.join(path.dirname(bin), 'dolphin-tool') : null) });
  for (const base of ['/var/lib/flatpak/app/org.DolphinEmu.dolphin-emu', path.join(os.homedir(), '.local/share/flatpak/app/org.DolphinEmu.dolphin-emu')])
    if (exists(base)) { found.push({ kind: 'flatpak', path: 'flatpak:org.DolphinEmu.dolphin-emu', tool: 'flatpak:org.DolphinEmu.dolphin-emu' }); break; }
  return found;
}
// comando para DolphinTool: { cmd, pre }  (en Flatpak con acceso a las carpetas necesarias)
function toolCommand(sel, extraDirs = []) {
  if (IS_WIN) return { cmd: path.join(PAYLOAD, 'dolphin', 'DolphinTool.exe'), pre: [] };
  const t = sel.tool || '';
  if (t.startsWith('flatpak:'))
    return { cmd: 'flatpak', pre: ['run', ...extraDirs.map((d) => '--filesystem=' + d), '--command=dolphin-tool', t.slice(8)] };
  return { cmd: t, pre: [] };
}
async function gameId(file, sel) {
  const tc = toolCommand(sel, [path.dirname(file)]);
  const r = await run(tc.cmd, [...tc.pre, 'header', '-i', file, '-j']);
  try { return JSON.parse(r.out.slice(r.out.indexOf('{'))).game_id || null; } catch (e) {}
  const m = /Game ID:\s*(\w+)/.exec(r.out); return m ? m[1] : null;
}

// ---------------------------------------------------------------- instalación
let installing = false;
async function install(o) {
  const L = o.lang || 'es';
  const step = (key, pct, extra) => send('prog', { key, pct, extra });
  const dir = path.resolve(o.dir);
  const tmpJp = path.join(dir, '_jp_temp');
  const en = path.join(dir, 'juego', 'US_INGLES');
  const jpDir = path.join(dir, 'juego', 'US_VOZ_JP');
  const sel = { tool: o.tool, dolphin: o.dolphin };
  if (!exists(PAYLOAD)) throw new Error('payload');
  // 1. espacio y copias
  const need = 11.5e9;
  if (freeBytes(dir) < need) throw new Error('space:' + Math.ceil(need / 1e9));
  step('check', 2);
  for (const [k, f] of [['us', o.us], ['jp', o.jp]]) {
    const id = await gameId(f, sel);
    log(k.toUpperCase() + ': ' + f + ' -> ' + id);
    if (id !== GAMES[k].id) throw new Error('id:' + k + ':' + (id || '?'));
  }
  fs.mkdirSync(dir, { recursive: true });
  // 2. extraer USA (con progreso por tamaño)
  const extract = async (file, out, key, p0, p1, total) => {
    fs.rmSync(out, { recursive: true, force: true }); fs.mkdirSync(out, { recursive: true });
    const tc = toolCommand(sel, [path.dirname(file), dir]);
    const t = setInterval(() => step(key, p0 + Math.min(1, dirBytes(out) / total) * (p1 - p0)), 1500);
    const r = await run(tc.cmd, [...tc.pre, 'extract', '-i', file, '-o', out, '-q']);
    clearInterval(t);
    if (!exists(path.join(out, 'DATA', 'sys', 'main.dol'))) throw new Error('extract:' + (r.err || r.out || r.code).toString().slice(0, 300));
  };
  const verify = async (base, k) => {
    for (const [rel, want] of Object.entries(GAMES[k].md5)) {
      const f = path.join(base, ...rel.split('/'));
      const got = exists(f) ? await md5(f) : 'falta';
      log('verificar ' + k + ' ' + rel + ': ' + got);
      if (got !== want) throw new Error('verify:' + k);
    }
  };
  step('extractUS', 4);
  await extract(o.us, en, 'extractUS', 4, 40, GAMES.us.bytes);
  step('verifyUS', 41); await verify(en, 'us');
  step('extractJP', 44);
  await extract(o.jp, tmpJp, 'extractJP', 44, 76, GAMES.jp.bytes);
  step('verifyJP', 77); await verify(tmpJp, 'jp');
  // 3. variante con voces japonesas (enlaces duros: no ocupa espacio extra)
  step('voices', 79);
  fs.rmSync(jpDir, { recursive: true, force: true });
  const files = walk(en);
  let i = 0, nj = 0;
  for (const rel of files) {
    const name = path.basename(rel);
    const jpFile = path.join(tmpJp, rel);
    const useJp = (VOICE_RE.test(name) || MOVIES_JP.has(name)) && exists(jpFile);
    const dst = path.join(jpDir, rel);
    fs.mkdirSync(path.dirname(dst), { recursive: true });
    linkOrCopy(useJp ? jpFile : path.join(en, rel), dst);
    if (useJp) nj++;
    if (++i % 500 === 0) step('voices', 79 + (i / files.length) * 10);
  }
  log('voces japonesas: ' + nj + ' archivos');
  // 4. parche del archivo de sonido (tamaños de los streams japoneses)
  step('patch', 90);
  const brsarSrc = path.join(en, 'DATA', 'files', 'sound', 'lastworld.brsar');
  const brsarDst = path.join(jpDir, 'DATA', 'files', 'sound', 'lastworld.brsar');
  const b = fs.readFileSync(brsarSrc);
  const pt = fs.readFileSync(path.join(PAYLOAD, 'patch', 'brsar_voces_jp.tlsp'));
  if (pt.toString('ascii', 0, 4) !== 'TLSP') throw new Error('patch');
  const n = pt.readUInt32LE(4);
  for (let k = 0; k < n; k++) {
    const o2 = 8 + k * 12, off = pt.readUInt32LE(o2), oldV = pt.readUInt32LE(o2 + 4), newV = pt.readUInt32LE(o2 + 8);
    if (b.readUInt32BE(off) !== oldV) throw new Error('patch');
    b.writeUInt32BE(newV, off);
  }
  fs.rmSync(brsarDst, { force: true });
  fs.writeFileSync(brsarDst, b);
  if ((await md5(brsarDst)) !== BRSAR_JP_MD5) throw new Error('patch');
  fs.writeFileSync(path.join(jpDir, 'listo.txt'), 'voces japonesas + brsar parcheado\n');
  fs.rmSync(tmpJp, { recursive: true, force: true });   // los archivos enlazados siguen en US_VOZ_JP
  // 5. launcher, Dolphin y texturas
  step('launcher', 92);
  const L_DIR = path.join(dir, 'launcher');
  fs.rmSync(L_DIR, { recursive: true, force: true });
  const runtime = IS_WIN ? ROOT : ROOT;   // Electron del propio instalador
  copyDir(runtime, L_DIR, (s, e) => {
    const rel = path.relative(runtime, s);
    return !(rel === 'resources' && e.isDirectory()) && rel !== 'payload' && !/\.txt$/i.test(rel) && !/^instalar/i.test(rel);
  });
  // el ejecutable se renombra
  const exeSrc = IS_WIN ? fs.readdirSync(L_DIR).find((f) => /\.exe$/i.test(f) && !/crashpad|squirrel/i.test(f)) : 'electron';
  const exeName = IS_WIN ? 'TheLastStory.exe' : 'thelaststory';
  if (exeSrc && exeSrc !== exeName) fs.renameSync(path.join(L_DIR, exeSrc), path.join(L_DIR, exeName));
  copyDir(path.join(PAYLOAD, 'launcher', 'app'), path.join(L_DIR, 'resources', 'app'));
  copyDir(path.join(PAYLOAD, 'launcher', 'ui'), path.join(L_DIR, 'ui'));
  copyDir(path.join(PAYLOAD, 'launcher', 'data'), path.join(L_DIR, 'data'));
  const userDir = IS_WIN ? path.join(dir, 'dolphin', 'User') : path.join(dir, 'dolphin-user');
  if (IS_WIN) {
    copyDir(path.join(PAYLOAD, 'dolphin'), path.join(dir, 'dolphin'));
    fs.writeFileSync(path.join(dir, 'dolphin', 'portable.txt'), '');
  }
  step('textures', 95);
  copyDir(path.join(PAYLOAD, 'textures'), path.join(userDir, 'Load', 'Textures'));
  // configuración inicial (idioma elegido, ventana en la primera apertura)
  const cfg = { ui: L, text: L === 'en' ? 'en' : L, voice: 'jp', launcherFull: 'off', buttonsV2: true };
  fs.writeFileSync(path.join(L_DIR, 'data', 'config.json'), JSON.stringify(cfg));
  const pj = IS_WIN
    ? { dolphinExe: '../dolphin/Dolphin.exe', dolphinUser: '../dolphin/User', gameEN: '../juego/US_INGLES', gameJP: '../juego/US_VOZ_JP' }
    : { dolphinExe: o.dolphin, dolphinUser: '../dolphin-user', gameEN: '../juego/US_INGLES', gameJP: '../juego/US_VOZ_JP' };
  fs.writeFileSync(path.join(L_DIR, 'data', 'paths.json'), JSON.stringify(pj, null, 1));
  if (!IS_WIN) {
    for (const f of [exeName, 'chrome_crashpad_handler', 'chrome-sandbox', path.join('resources', 'app', 'tls_bridge'), path.join('resources', 'app', 'tls_logros')])
      try { fs.chmodSync(path.join(L_DIR, f), 0o755); } catch (e) {}
  }
  // 6. accesos directos
  step('shortcuts', 97);
  const exe = path.join(L_DIR, exeName);
  if (IS_WIN) {
    const lnk = (where) => `$s=(New-Object -ComObject WScript.Shell).CreateShortcut('${where.replace(/'/g, "''")}');` +
      `$s.TargetPath='${exe.replace(/'/g, "''")}';$s.WorkingDirectory='${L_DIR.replace(/'/g, "''")}';` +
      `$s.IconLocation='${path.join(L_DIR, 'ui', 'assets', 'icon.ico').replace(/'/g, "''")}';$s.Description="The Last Story HD - Dionixu's Launcher";$s.Save()`;
    const targets = [path.join(dir, 'The Last Story HD.lnk')];
    if (o.desktop) targets.push(path.join(app.getPath('desktop'), 'The Last Story HD.lnk'));
    if (o.menu) targets.push(path.join(app.getPath('appData'), 'Microsoft', 'Windows', 'Start Menu', 'Programs', 'The Last Story HD.lnk'));
    await run('powershell.exe', ['-NoProfile', '-NonInteractive', '-Command', targets.map(lnk).join(';')]);
  } else {
    const desk = ['[Desktop Entry]', 'Type=Application', 'Name=The Last Story HD', "Comment=Dionixu's Launcher", 'Categories=Game;',
      `Exec="${exe}" --no-sandbox`, `Path=${L_DIR}`, `Icon=${path.join(L_DIR, 'ui', 'assets', 'icon.png')}`, 'Terminal=false', 'StartupWMClass=thelaststory', ''].join('\n');
    const write = (f) => { fs.mkdirSync(path.dirname(f), { recursive: true }); fs.writeFileSync(f, desk); try { fs.chmodSync(f, 0o755); } catch (e) {} };
    write(path.join(dir, 'The Last Story HD.desktop'));
    if (o.menu) write(path.join(os.homedir(), '.local', 'share', 'applications', 'the-last-story-hd.desktop'));
    if (o.desktop) {
      const r = await run('xdg-user-dir', ['DESKTOP']);
      const d = (r.code === 0 && r.out.trim()) || path.join(os.homedir(), 'Desktop');
      if (exists(d)) { const f = path.join(d, 'the-last-story-hd.desktop'); write(f); await run('gio', ['set', f, 'metadata::trusted', 'true']); }
    }
  }
  fs.writeFileSync(path.join(dir, 'instalacion.log'), logLines.join('\n') + '\n');
  step('done', 100);
  return { exe, dir: L_DIR };
}

// si algo falla, se borra lo extraído (no deja gigas sueltos); nunca se toca nada fuera de la carpeta elegida
async function installSafe(o) {
  try { return await install(o); }
  catch (e) {
    const dir = path.resolve(o.dir);
    for (const d of [path.join(dir, '_jp_temp'), path.join(dir, 'juego')]) { try { fs.rmSync(d, { recursive: true, force: true }); } catch (x) {} }
    throw e;
  }
}

// ---------------------------------------------------------------- IPC
let lastInstall = null;
ipcMain.on('msg', async (_e, raw) => {
  let m; try { m = JSON.parse(raw); } catch (e) { return; }
  try {
    switch (m.cmd) {
      case 'init': {
        const home = os.homedir();
        send('state', {
          platform: process.platform, payloadOk: exists(path.join(PAYLOAD, 'launcher', 'app', 'main.js')),
          defaultDir: IS_WIN ? path.join(app.getPath('documents'), 'The Last Story HD') : path.join(home, 'Games', 'The Last Story HD'),
          dolphins: IS_LINUX ? linuxDetect() : []
        });
        break;
      }
      case 'pick': {
        const opts = m.kind === 'dir'
          ? { properties: ['openDirectory', 'createDirectory'], defaultPath: m.current || undefined }
          : m.kind === 'us' || m.kind === 'jp'
            ? { properties: ['openFile'], filters: [{ name: 'Wii', extensions: ['rvz', 'iso', 'wbfs', 'wia', 'gcz', 'ciso'] }, { name: '*', extensions: ['*'] }] }
            : { properties: ['openFile', 'showHiddenFiles'] };
        const r = await dialog.showOpenDialog(win, opts);
        if (r.canceled || !r.filePaths[0]) return;
        send('picked', { kind: m.kind, path: r.filePaths[0] });
        break;
      }
      case 'check': {   // ID del disco elegido
        const id = await gameId(m.path, { tool: m.tool });
        send('checked', { kind: m.kind, path: m.path, id });
        break;
      }
      case 'checkTool': {   // Linux: DolphinTool responde
        const tc = toolCommand({ tool: m.tool });
        const r = await run(tc.cmd, [...tc.pre, 'header', '--help']);
        send('toolChecked', { ok: r.code !== -1 && /input|usage|Usage/i.test(r.out + r.err) });
        break;
      }
      case 'install':
        if (installing) return;
        installing = true;
        try { lastInstall = await installSafe(m.opts); send('done', lastInstall); }
        catch (e) { log('ERROR: ' + (e.stack || e.message)); send('fail', { error: e.message }); }
        installing = false;
        break;
      case 'launch':
        if (lastInstall) {
          const p = spawn(lastInstall.exe, ['--windowed', ...(IS_LINUX ? ['--no-sandbox'] : [])], { cwd: lastInstall.dir, detached: true, stdio: 'ignore' });
          p.unref();
        }
        setTimeout(() => app.quit(), 600);
        break;
      case 'openFolder': if (lastInstall) shell.openPath(path.dirname(lastInstall.dir)); break;
      case 'minimize': win.minimize(); break;
      case 'close': if (!installing) app.quit(); break;
    }
  } catch (e) { send('fail', { error: e.message }); }
});

app.whenReady().then(() => {
  protocol.handle('tls', (req) => {
    const rel = decodeURIComponent(new URL(req.url).pathname).replace(/^\/+/, '');
    const file = path.resolve(UI, rel);
    if (!file.startsWith(path.resolve(UI))) return new Response('', { status: 403 });
    return net.fetch(pathToFileURL(file).toString());
  });
  win = new BrowserWindow({
    width: 1040, height: 640, minWidth: 900, minHeight: 560, frame: false, resizable: false, backgroundColor: '#f1e5cc', show: false,
    title: "Dionixu's Launcher — The Last Story HD", icon: path.join(UI, 'assets', IS_WIN ? 'icon.ico' : 'icon.png'),
    webPreferences: { preload: path.join(__dirname, 'preload.js'), contextIsolation: true, nodeIntegration: false, sandbox: true }
  });
  win.setMenu(null);
  win.loadURL('tls://ui/index.html');
  win.once('ready-to-show', () => win.show());
  win.on('close', (e) => { if (installing) e.preventDefault(); });
});
app.on('window-all-closed', () => app.quit());
