// Battleship — Aegis Naval Command Interactive Tactical Simulator
const GRID_SIZE = 10;
const ROW_LETTERS = ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J'];

const FLEET_SPEC = [
  { id: 'carrier', name: 'USS Enterprise', code: 'CVN-65', size: 5 },
  { id: 'battleship', name: 'USS Iowa', code: 'BB-61', size: 4 },
  { id: 'cruiser', name: 'USS Ticonderoga', code: 'CG-47', size: 3 },
  { id: 'submarine', name: 'USS Seawolf', code: 'SSN-21', size: 3 },
  { id: 'destroyer', name: 'USS Arleigh Burke', code: 'DDG-51', size: 2 },
];

const state = {
  ships: [],
  board: [], // 'unknown' | 'miss' | 'hit' | 'sunk'
  sonarRevealed: {}, // key -> 'clear' | 'contact'
  weapon: 'torpedo', // 'torpedo' | 'sonar' | 'airstrike' | 'tomahawk'
  arsenal: { sonar: 2, airstrike: 2, tomahawk: 1 },
  showProbability: true,
  soundEnabled: true,
  salvosFired: 0,
  hitsScored: 0,
};

let audioCtx = null;

function ensureAudio() {
  if (!state.soundEnabled) return null;
  if (!audioCtx) {
    const AudioContextClass = window.AudioContext || window.webkitAudioContext;
    if (AudioContextClass) audioCtx = new AudioContextClass();
  }
  if (audioCtx && audioCtx.state === 'suspended') {
    audioCtx.resume();
  }
  return audioCtx;
}

function playNavalSound(type) {
  const ctx = ensureAudio();
  if (!ctx) return;
  const now = ctx.currentTime;

  if (type === 'sonar') {
    const osc = ctx.createOscillator();
    const gain = ctx.createGain();
    osc.type = 'sine';
    osc.frequency.setValueAtTime(1320, now);
    osc.frequency.exponentialRampToValueAtTime(1280, now + 0.45);
    gain.gain.setValueAtTime(0.18, now);
    gain.gain.exponentialRampToValueAtTime(0.001, now + 0.5);
    osc.connect(gain).connect(ctx.destination);
    osc.start(now);
    osc.stop(now + 0.52);
  } else if (type === 'hit' || type === 'sunk') {
    const osc = ctx.createOscillator();
    const gain = ctx.createGain();
    osc.type = 'sawtooth';
    osc.frequency.setValueAtTime(type === 'sunk' ? 95 : 140, now);
    osc.frequency.exponentialRampToValueAtTime(32, now + 0.38);
    gain.gain.setValueAtTime(0.22, now);
    gain.gain.exponentialRampToValueAtTime(0.001, now + 0.4);
    osc.connect(gain).connect(ctx.destination);
    osc.start(now);
    osc.stop(now + 0.42);
  } else if (type === 'miss') {
    const osc = ctx.createOscillator();
    const gain = ctx.createGain();
    osc.type = 'triangle';
    osc.frequency.setValueAtTime(320, now);
    osc.frequency.exponentialRampToValueAtTime(110, now + 0.18);
    gain.gain.setValueAtTime(0.12, now);
    gain.gain.exponentialRampToValueAtTime(0.001, now + 0.2);
    osc.connect(gain).connect(ctx.destination);
    osc.start(now);
    osc.stop(now + 0.22);
  }
}

function coordKey(r, c) {
  return `${r},${c}`;
}

function formatCoord(r, c) {
  return `${ROW_LETTERS[r]}-${String(c + 1).padStart(2, '0')}`;
}

function initMission() {
  state.board = Array.from({ length: GRID_SIZE }, () =>
    Array.from({ length: GRID_SIZE }, () => 'unknown')
  );
  state.sonarRevealed = {};
  state.weapon = 'torpedo';
  state.arsenal = { sonar: 2, airstrike: 2, tomahawk: 1 };
  state.salvosFired = 0;
  state.hitsScored = 0;
  state.ships = placeFleetRandomly();

  const logEl = document.getElementById('combat-log');
  if (logEl) {
    logEl.innerHTML = '';
    appendLog('AEGIS LINK ONLINE. 5 hostile hulls detected in sector.', 'sonar');
  }
  updateWeaponButtons();
  renderAll();
}

function placeFleetRandomly() {
  const occupied = new Set();
  const placed = [];

  for (const spec of FLEET_SPEC) {
    let success = false;
    while (!success) {
      const horiz = Math.random() < 0.5;
      const maxR = horiz ? GRID_SIZE : GRID_SIZE - spec.size + 1;
      const maxC = horiz ? GRID_SIZE - spec.size + 1 : GRID_SIZE;
      const r0 = Math.floor(Math.random() * maxR);
      const c0 = Math.floor(Math.random() * maxC);

      const coords = [];
      let collision = false;
      for (let i = 0; i < spec.size; i++) {
        const r = horiz ? r0 : r0 + i;
        const c = horiz ? c0 + i : c0;
        if (occupied.has(coordKey(r, c))) {
          collision = true;
          break;
        }
        coords.push([r, c]);
      }
      if (!collision) {
        coords.forEach(([r, c]) => occupied.add(coordKey(r, c)));
        placed.push({
          ...spec,
          coords,
          hits: new Set(),
        });
        success = true;
      }
    }
  }
  return placed;
}

function computeProbabilityMatrix() {
  const matrix = Array.from({ length: GRID_SIZE }, () => Array(GRID_SIZE).fill(0));
  const survivingShips = state.ships.filter((s) => s.hits.size < s.size);
  if (survivingShips.length === 0) return matrix;

  const hitCells = [];
  for (let r = 0; r < GRID_SIZE; r++) {
    for (let c = 0; c < GRID_SIZE; c++) {
      if (state.board[r][c] === 'hit') hitCells.push([r, c]);
    }
  }

  for (const ship of survivingShips) {
    for (const horiz of [true, false]) {
      const maxR = horiz ? GRID_SIZE : GRID_SIZE - ship.size + 1;
      const maxC = horiz ? GRID_SIZE - ship.size + 1 : GRID_SIZE;
      for (let r0 = 0; r0 < maxR; r0++) {
        for (let c0 = 0; c0 < maxC; c0++) {
          let valid = true;
          let overlapsHit = 0;
          const cells = [];
          for (let i = 0; i < ship.size; i++) {
            const r = horiz ? r0 : r0 + i;
            const c = horiz ? c0 + i : c0;
            const cellState = state.board[r][c];
            if (cellState === 'miss' || cellState === 'sunk' || state.sonarRevealed[coordKey(r, c)] === 'clear') {
              valid = false;
              break;
            }
            if (cellState === 'hit') overlapsHit++;
            cells.push([r, c]);
          }
          if (!valid) continue;
          const weight = overlapsHit > 0 ? 1 + overlapsHit * 6 : 1;
          for (const [r, c] of cells) {
            if (state.board[r][c] === 'unknown') {
              matrix[r][c] += weight;
            }
          }
        }
      }
    }
  }

  let maxVal = 0;
  for (let r = 0; r < GRID_SIZE; r++) {
    for (let c = 0; c < GRID_SIZE; c++) {
      if (matrix[r][c] > maxVal) maxVal = matrix[r][c];
    }
  }
  if (maxVal > 0) {
    for (let r = 0; r < GRID_SIZE; r++) {
      for (let c = 0; c < GRID_SIZE; c++) {
        matrix[r][c] = Math.round((matrix[r][c] / maxVal) * 100);
      }
    }
  }
  return matrix;
}

function getWeaponPattern(r, c, weapon) {
  const coords = [];
  if (weapon === 'torpedo') {
    coords.push([r, c]);
  } else if (weapon === 'sonar') {
    for (let dr = -1; dr <= 1; dr++) {
      for (let dc = -1; dc <= 1; dc++) {
        const nr = r + dr;
        const nc = c + dc;
        if (nr >= 0 && nr < GRID_SIZE && nc >= 0 && nc < GRID_SIZE) {
          coords.push([nr, nc]);
        }
      }
    }
  } else if (weapon === 'airstrike') {
    for (let dc = -1; dc <= 1; dc++) {
      const nc = c + dc;
      if (nc >= 0 && nc < GRID_SIZE) coords.push([r, nc]);
    }
  } else if (weapon === 'tomahawk') {
    const deltas = [
      [0, 0],
      [-1, 0],
      [1, 0],
      [0, -1],
      [0, 1],
    ];
    for (const [dr, dc] of deltas) {
      const nr = r + dr;
      const nc = c + dc;
      if (nr >= 0 && nr < GRID_SIZE && nc >= 0 && nc < GRID_SIZE) {
        coords.push([nr, nc]);
      }
    }
  }
  return coords;
}

function fireAt(r, c) {
  const weapon = state.weapon;
  if (weapon !== 'torpedo' && state.arsenal[weapon] <= 0) return;

  const targets = getWeaponPattern(r, c, weapon);

  if (weapon === 'sonar') {
    state.arsenal.sonar--;
    state.salvosFired++;
    let contacts = 0;
    for (const [tr, tc] of targets) {
      if (state.board[tr][tc] !== 'unknown') continue;
      const hasShip = state.ships.some((s) =>
        s.coords.some(([sr, sc]) => sr === tr && sc === tc)
      );
      state.sonarRevealed[coordKey(tr, tc)] = hasShip ? 'contact' : 'clear';
      if (hasShip) contacts++;
    }
    playNavalSound('sonar');
    appendLog(
      `SONAR PING @ ${formatCoord(r, c)}: ${contacts} hull contact(s) localized.`,
      'sonar'
    );
    if (state.arsenal.sonar <= 0) state.weapon = 'torpedo';
    updateWeaponButtons();
    renderAll();
    return;
  }

  const actionable = targets.filter(([tr, tc]) => state.board[tr][tc] === 'unknown');
  if (actionable.length === 0) return;

  if (weapon !== 'torpedo') {
    state.arsenal[weapon]--;
    if (state.arsenal[weapon] <= 0) state.weapon = 'torpedo';
  }

  state.salvosFired++;
  let anyHit = false;
  let anySunk = false;

  for (const [tr, tc] of actionable) {
    const key = coordKey(tr, tc);
    delete state.sonarRevealed[key];
    const hitShip = state.ships.find((s) =>
      s.coords.some(([sr, sc]) => sr === tr && sc === tc)
    );
    if (hitShip) {
      hitShip.hits.add(key);
      state.board[tr][tc] = 'hit';
      state.hitsScored++;
      anyHit = true;

      if (hitShip.hits.size === hitShip.size) {
        anySunk = true;
        for (const [sr, sc] of hitShip.coords) {
          state.board[sr][sc] = 'sunk';
        }
        appendLog(
          `CONFIRMED SINKING: ${hitShip.name} (${hitShip.code}) neutralized!`,
          'sunk'
        );
      } else {
        appendLog(`DIRECT HIT on hostile vessel @ ${formatCoord(tr, tc)}`, 'hit');
      }
    } else {
      state.board[tr][tc] = 'miss';
      if (actionable.length === 1) {
        appendLog(`TORPEDO MISS @ ${formatCoord(tr, tc)} — open water.`, 'normal');
      }
    }
  }

  if (anySunk) {
    playNavalSound('sunk');
  } else if (anyHit) {
    playNavalSound('hit');
  } else {
    playNavalSound('miss');
  }

  if (state.ships.every((s) => s.hits.size === s.size)) {
    appendLog('VICTORY — All hostile Task Force vessels eliminated!', 'sunk');
  }

  updateWeaponButtons();
  renderAll();
}

function appendLog(msg, kind) {
  const logEl = document.getElementById('combat-log');
  if (!logEl) return;
  const item = document.createElement('div');
  item.className = `combat-log__entry ${kind ? `combat-log__entry--${kind}` : ''}`;
  item.textContent = `> ${msg}`;
  logEl.prepend(item);
}

function updateWeaponButtons() {
  document.querySelectorAll('[data-weapon]').forEach((btn) => {
    const w = btn.getAttribute('data-weapon');
    btn.classList.toggle('is-selected', state.weapon === w);
    if (w !== 'torpedo') {
      const rem = state.arsenal[w];
      btn.disabled = rem <= 0;
      const countSpan = btn.querySelector('.weapon-count');
      if (countSpan) countSpan.textContent = `(${rem})`;
    }
  });
}

function renderAll() {
  const gridEl = document.getElementById('tactical-grid');
  if (!gridEl) return;

  const probMatrix = state.showProbability ? computeProbabilityMatrix() : null;
  gridEl.innerHTML = '';

  for (let r = 0; r < GRID_SIZE; r++) {
    for (let c = 0; c < GRID_SIZE; c++) {
      const cell = document.createElement('button');
      cell.type = 'button';
      cell.className = 'grid-cell';
      cell.id = `cell-${r}-${c}`;
      cell.setAttribute('aria-label', `Sector ${formatCoord(r, c)}`);

      const cellState = state.board[r][c];
      const sonarState = state.sonarRevealed[coordKey(r, c)];

      if (cellState === 'miss') {
        cell.classList.add('is-miss');
      } else if (cellState === 'hit') {
        cell.classList.add('is-hit');
      } else if (cellState === 'sunk') {
        cell.classList.add('is-hit', 'is-sunk');
      } else if (sonarState === 'contact') {
        cell.classList.add('is-sonar-contact');
      } else if (sonarState === 'clear') {
        cell.classList.add('is-sonar-clear');
      } else if (probMatrix && probMatrix[r][c] > 0) {
        const p = probMatrix[r][c];
        const alpha = (p / 100) * 0.28;
        cell.style.background = `rgba(0, 235, 255, ${alpha.toFixed(3)})`;
        if (p >= 45) {
          cell.textContent = `${p}`;
        }
      }

      cell.addEventListener('mouseenter', () => highlightPattern(r, c, true));
      cell.addEventListener('mouseleave', () => highlightPattern(r, c, false));
      cell.addEventListener('click', () => fireAt(r, c));

      gridEl.appendChild(cell);
    }
  }

  // Render Fleet Status
  const fleetEl = document.getElementById('fleet-status-list');
  if (fleetEl) {
    fleetEl.innerHTML = '';
    for (const ship of state.ships) {
      const destroyed = ship.hits.size === ship.size;
      const row = document.createElement('div');
      row.className = `fleet-row ${destroyed ? 'is-destroyed' : ''}`;

      const nameSpan = document.createElement('span');
      nameSpan.className = 'fleet-row__name';
      nameSpan.textContent = ship.code;

      const pips = document.createElement('div');
      pips.className = 'fleet-pips';
      for (let i = 0; i < ship.size; i++) {
        const pip = document.createElement('span');
        pip.className = `fleet-pip ${i < ship.hits.size ? 'is-hit' : ''}`;
        pips.appendChild(pip);
      }

      row.append(nameSpan, pips);
      fleetEl.appendChild(row);
    }
  }

  // Update telemetry counters
  const salvosEl = document.getElementById('stat-salvos');
  const hitsEl = document.getElementById('stat-hits');
  if (salvosEl) salvosEl.textContent = String(state.salvosFired);
  if (hitsEl) hitsEl.textContent = `${state.hitsScored} / 17`;
}

function highlightPattern(r, c, active) {
  const coords = getWeaponPattern(r, c, state.weapon);
  for (const [tr, tc] of coords) {
    const el = document.getElementById(`cell-${tr}-${tc}`);
    if (el) el.classList.toggle('is-target-preview', active);
  }
}

document.addEventListener('DOMContentLoaded', () => {
  document.querySelectorAll('[data-weapon]').forEach((btn) => {
    btn.addEventListener('click', () => {
      const w = btn.getAttribute('data-weapon');
      if (w === 'torpedo' || state.arsenal[w] > 0) {
        state.weapon = w;
        updateWeaponButtons();
      }
    });
  });

  const probBtn = document.getElementById('btn-toggle-prob');
  if (probBtn) {
    probBtn.addEventListener('click', () => {
      state.showProbability = !state.showProbability;
      probBtn.classList.toggle('is-active', state.showProbability);
      probBtn.textContent = state.showProbability ? 'PROBABILITY: ON' : 'PROBABILITY: OFF';
      renderAll();
    });
  }

  const audioBtn = document.getElementById('btn-toggle-audio');
  if (audioBtn) {
    audioBtn.addEventListener('click', () => {
      state.soundEnabled = !state.soundEnabled;
      audioBtn.classList.toggle('is-active', state.soundEnabled);
      audioBtn.textContent = state.soundEnabled ? 'AUDIO: ON' : 'AUDIO: MUTE';
    });
  }

  const resetBtn = document.getElementById('btn-reset-sim');
  if (resetBtn) {
    resetBtn.addEventListener('click', initMission);
  }

  initMission();
});
