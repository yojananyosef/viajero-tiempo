# Exports — presets y notas (no commitear builds)

Presets en `export_presets.cfg` (Godot 4.7.2, templates ya instalados):
- `Web Local` → `web/index.html` (single-thread, renderer Compatibility).
  Los builds van a carpetas ignoradas por git (`web/`); solo se commitean
  presets + estas notas.

## Probar con gráficos en tu máquina (sale de ir a ciegas)

```sh
godot --path .
```

WASD moverse, Espacio saltar, Shift correr, E interactuar, F luz, G skill2.
F5 guarda, F9 carga. Sin peer = modo solo (el servidor no hace falta).

## Tests headless por quest + regresión

```sh
godot --headless --path . --script /tmp/test_q07.gd   # Q07 actual
godot --headless --path . --script /tmp/test_q03.gd   # regresión, etc.
```

## Build web local (probar en navegador, solo-modo-solo)

```sh
mkdir -p web
godot --headless --path . --export-release "Web Local" web/index.html
python3 -m http.server 8901 --directory web
# Abrir http://127.0.0.1:8901/index.html
```

Notas:
- El preset usa `rendering_method.web="gl_compatibility"` (una línea en
  `project.godot`); el escritorio sigue en Forward Plus.
- Single-thread: no requiere headers COOP/COEP; cualquier hosting estático
  (Vercel/Netlify) sirve estos mismos archivos tal cual.
- Límite conocido: ENet (UDP) no existe en navegadores, así que el build web
  es solo-modo-solo. El multi real se prueba con cliente+servidor de
  escritorio (SPEC-013).

## Preview en GitHub Pages (solo-modo-solo)

URL: https://yojananyosef.github.io/viajero-tiempo/

La rama `gh-pages` contiene SOLO el build (más `.nojekyll`); `main` sigue
limpio (`web/` está gitignored). Republicar tras cada slice:

```sh
mkdir -p web
godot --headless --path . --export-release "Web Local" web/index.html
touch web/.nojekyll
git worktree add /tmp/gh-pages gh-pages          # solo la primera vez
cp web/index.html web/index.js web/index.wasm web/index.pck \
   web/index.png web/index.icon.png web/index.apple-touch-icon.png \
   web/index.audio.worklet.js web/index.audio.position.worklet.js \
   web/.nojekyll /tmp/gh-pages/
git -C /tmp/gh-pages add -A
git -C /tmp/gh-pages commit -m "preview: build web <slice> (solo)"
git -C /tmp/gh-pages push origin gh-pages
```

## Servidor dedicado (SPEC-013, pendiente presets Linux/Win)

Comando server ejemplo:

```sh
./viajero-server.x86_64 --headless -- --server --port 7000 --max 20 --map Map_01_Origen
```
