"use strict";

// ---- Domain data (mirrors the native app) ---------------------------------

const BALL_INFO = {
  blue:   { name: "Blue",   color: "#1a59d9", on: "#ffffff", team: "blueBlack" },
  red:    { name: "Red",    color: "#d92626", on: "#ffffff", team: "redYellow" },
  black:  { name: "Black",  color: "#1f1f24", on: "#ffffff", team: "blueBlack" },
  yellow: { name: "Yellow", color: "#facc1a", on: "#000000", team: "redYellow" },
  green:  { name: "Green",  color: "#329e4d", on: "#ffffff", team: "blueBlack" },
  orange: { name: "Orange", color: "#f28c1a", on: "#000000", team: "redYellow" },
};

const FORMATS = {
  fourBall: { name: "4-ball", balls: ["blue", "red", "black", "yellow"] },
  sixBall:  { name: "6-ball", balls: ["blue", "red", "black", "yellow", "green", "orange"] },
};

const WICKET_LABELS = [
  "1", "2", "3", "4", "5", "6",
  "1-back", "2-back", "3-back", "4-back",
  "Penult", "Rover", "Stake",
];
const FINISHED = WICKET_LABELS.length - 1;

const TEAMS = ["blueBlack", "redYellow"];
const STORAGE_KEY = "croquet.game.v1";

// ---- State ----------------------------------------------------------------

function newBall() {
  return { player: "", wicket: 0, deadOn: [] };
}

function newGame(format = "fourBall") {
  const balls = {};
  for (const b of FORMATS[format].balls) balls[b] = newBall();
  return { format, balls, teamNames: { blueBlack: "", redYellow: "" } };
}

let state = load();

function load() {
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    if (!raw) return newGame();
    const parsed = JSON.parse(raw);
    const format = FORMATS[parsed.format] ? parsed.format : "fourBall";
    const game = newGame(format);
    // Carry over saved per-ball state and names for balls in this format.
    for (const b of FORMATS[format].balls) {
      const saved = parsed.balls && parsed.balls[b];
      if (saved) {
        game.balls[b] = {
          player: typeof saved.player === "string" ? saved.player : "",
          wicket: clampWicket(saved.wicket),
          deadOn: Array.isArray(saved.deadOn)
            ? saved.deadOn.filter((d) => FORMATS[format].balls.includes(d) && d !== b)
            : [],
        };
      }
    }
    if (parsed.teamNames) {
      for (const t of TEAMS) {
        if (typeof parsed.teamNames[t] === "string") game.teamNames[t] = parsed.teamNames[t];
      }
    }
    return game;
  } catch (e) {
    return newGame();
  }
}

function save() {
  try {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(state));
  } catch (e) {
    /* storage full / disabled — keep running in memory */
  }
}

function clampWicket(n) {
  n = Number.isFinite(n) ? Math.trunc(n) : 0;
  return Math.min(Math.max(n, 0), FINISHED);
}

// ---- Derived helpers ------------------------------------------------------

const ballsInPlay = () => FORMATS[state.format].balls;
const teamBalls = (team) => ballsInPlay().filter((b) => BALL_INFO[b].team === team);
const defaultTeamName = (team) => teamBalls(team).map((b) => BALL_INFO[b].name).join(" / ");

function teamName(team) {
  const custom = (state.teamNames[team] || "").trim();
  return custom || defaultTeamName(team);
}

const isDead = (striker, target) =>
  striker !== target && state.balls[striker].deadOn.includes(target);

// ---- Mutations ------------------------------------------------------------

function toggleDead(striker, target) {
  if (striker === target) return;
  const arr = state.balls[striker].deadOn;
  const i = arr.indexOf(target);
  if (i >= 0) arr.splice(i, 1);
  else arr.push(target);
  save();
}

function scoreWicket(ball) {
  const b = state.balls[ball];
  if (b.wicket >= FINISHED) return;
  b.wicket = clampWicket(b.wicket + 1);
  b.deadOn = []; // scoring a wicket clears deadness
  save();
  renderAll();
}

function retreatWicket(ball) {
  const b = state.balls[ball];
  b.wicket = clampWicket(b.wicket - 1);
  save();
  renderAll();
}

function setFormat(format) {
  if (!FORMATS[format] || format === state.format) return;
  const next = FORMATS[format].balls;
  const balls = {};
  for (const b of next) {
    const existing = state.balls[b];
    balls[b] = existing
      ? { player: existing.player, wicket: existing.wicket,
          deadOn: existing.deadOn.filter((d) => next.includes(d)) }
      : newBall();
  }
  state.format = format;
  state.balls = balls;
  save();
  renderAll();
  renderSettings();
}

function setPlayerName(ball, name) {
  state.balls[ball].player = name;
  save(); // no re-render: keep input focus while typing
}

function setTeamName(team, name) {
  state.teamNames[team] = name;
  save();
}

function resetGame() {
  state = newGame(state.format);
  save();
  renderAll();
  renderSettings();
}

// ---- Rendering ------------------------------------------------------------

const esc = (s) =>
  String(s).replace(/[&<>"']/g, (c) =>
    ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));

function chipHTML(ball, size) {
  const info = BALL_INFO[ball];
  return `<span class="chip" title="${info.name}" style="width:${size}px;height:${size}px;background:${info.color}"></span>`;
}

function renderBoard() {
  const balls = ballsInPlay();
  const chipSize = balls.length > 4 ? 22 : 26;
  const board = document.getElementById("board");
  board.style.setProperty("--cols", balls.length);

  let grid = `<div class="board-grid" style="--cols:${balls.length}">`;
  // Top-left corner is empty, then a header chip per column.
  grid += `<div></div>`;
  for (const b of balls) grid += `<div class="col-head">${chipHTML(b, chipSize)}</div>`;

  for (const striker of balls) {
    grid += `<div class="row-head">${chipHTML(striker, chipSize)}<span>${BALL_INFO[striker].name}</span></div>`;
    for (const target of balls) {
      if (striker === target) {
        grid += `<button class="cell diag" disabled aria-hidden="true">–</button>`;
      } else {
        const dead = isDead(striker, target);
        const style = dead ? `style="background:${BALL_INFO[target].color}"` : "";
        const label = `${BALL_INFO[striker].name} dead on ${BALL_INFO[target].name}: ${dead ? "dead" : "alive"}`;
        grid += `<button class="cell ${dead ? "dead" : ""}" ${style}
          data-action="toggle-dead" data-striker="${striker}" data-target="${target}"
          aria-label="${label}" aria-pressed="${dead}">${dead ? "✕" : ""}</button>`;
      }
    }
  }
  grid += `</div>`;

  board.innerHTML =
    `<h2>Deadness Board</h2>
     <p class="hint">Row is dead on column. Tap a cell to toggle.</p>${grid}`;
}

function renderCards() {
  const cards = document.getElementById("cards");
  cards.innerHTML = ballsInPlay().map((ball) => {
    const info = BALL_INFO[ball];
    const b = state.balls[ball];
    const done = b.wicket >= FINISHED;
    return `
      <div class="ball-card" style="--ball:${info.color};--ball-on:${info.on}">
        <div class="head">
          ${chipHTML(ball, 32)}
          <div>
            <div class="title">${info.name}</div>
            <div class="team">${esc(teamName(info.team))}</div>
          </div>
        </div>
        <input class="player" type="text" inputmode="text" autocomplete="off"
          placeholder="Player name" value="${esc(b.player)}"
          data-action="player-name" data-ball="${ball}" aria-label="${info.name} player name" />
        <div class="wicket-row">
          <div class="wicket-info">
            <span class="label">${done ? "Finished" : "Next wicket"}</span>
            <span class="value ${done ? "done" : ""}">${WICKET_LABELS[b.wicket]}</span>
          </div>
          <div class="spacer"></div>
          <button class="step" data-action="retreat" data-ball="${ball}"
            aria-label="Step ${info.name} back a wicket">−</button>
          <button class="score" data-action="score" data-ball="${ball}" ${done ? "disabled" : ""}
            title="Advances the wicket and clears deadness">✓ Scored</button>
        </div>
      </div>`;
  }).join("");
}

function renderSettings() {
  // Format segmented control
  const toggle = document.getElementById("format-toggle");
  toggle.innerHTML = Object.keys(FORMATS).map((f) =>
    `<button type="button" class="${f === state.format ? "active" : ""}"
       data-action="set-format" data-format="${f}"
       aria-pressed="${f === state.format}">${FORMATS[f].name}</button>`
  ).join("");

  // Team name rows
  const rows = document.getElementById("team-names");
  rows.innerHTML = TEAMS.map((team) => {
    const chips = teamBalls(team).map((b) => chipHTML(b, 22)).join("");
    return `<div class="team-row">
      <div class="chips">${chips}</div>
      <input type="text" autocomplete="off" placeholder="${esc(defaultTeamName(team))}"
        value="${esc(state.teamNames[team] || "")}"
        data-action="team-name" data-team="${team}" aria-label="${esc(defaultTeamName(team))} name" />
    </div>`;
  }).join("");
}

function renderAll() {
  renderBoard();
  renderCards();
}

// ---- Events ---------------------------------------------------------------

const dialog = document.getElementById("settings");

document.addEventListener("click", (e) => {
  const el = e.target.closest("[data-action]");
  if (!el) return;
  const action = el.dataset.action;
  switch (action) {
    case "open-settings": renderSettings(); dialog.showModal(); break;
    case "toggle-dead":
      toggleDead(el.dataset.striker, el.dataset.target);
      renderBoard();
      break;
    case "score": scoreWicket(el.dataset.ball); break;
    case "retreat": retreatWicket(el.dataset.ball); break;
    case "set-format": setFormat(el.dataset.format); break;
    case "reset": resetGame(); break;
  }
});

document.addEventListener("input", (e) => {
  const el = e.target.closest("[data-action]");
  if (!el) return;
  if (el.dataset.action === "player-name") setPlayerName(el.dataset.ball, el.value);
  else if (el.dataset.action === "team-name") setTeamName(el.dataset.team, el.value);
});

// Re-render cards when settings closes so edited team names show through.
dialog.addEventListener("close", renderCards);

// ---- Boot -----------------------------------------------------------------

renderAll();

if ("serviceWorker" in navigator) {
  window.addEventListener("load", () => {
    navigator.serviceWorker.register("sw.js").catch(() => {});
  });
}
