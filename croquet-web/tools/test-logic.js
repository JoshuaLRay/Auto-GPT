// Runs app.js in a sandbox with minimal DOM/localStorage stubs and exercises
// the game logic. Not shipped — a dev sanity check. Run: node tools/test-logic.js
const fs = require("fs");
const path = require("path");
const vm = require("vm");

let assertions = 0, failures = 0;
function check(cond, msg) {
  assertions++;
  if (!cond) { failures++; console.error("  FAIL:", msg); }
}

const store = new Map();
const localStorage = {
  getItem: (k) => (store.has(k) ? store.get(k) : null),
  setItem: (k, v) => store.set(k, String(v)),
  removeItem: (k) => store.delete(k),
};
const saved = () => JSON.parse(store.get("croquet.game.v1"));

const elementStub = () => ({
  style: { setProperty() {} },
  set innerHTML(_) {}, get innerHTML() { return ""; },
  addEventListener() {}, showModal() {}, close() {}, dataset: {},
});
const document = {
  getElementById: () => elementStub(),
  addEventListener() {},
};
const sandbox = {
  localStorage, document,
  navigator: {}, window: { addEventListener() {} },
  console, JSON, Math, Number, Array, Object,
};
vm.createContext(sandbox);
vm.runInContext(fs.readFileSync(path.join(__dirname, "..", "app.js"), "utf8"), sandbox);

const { scoreWicket, retreatWicket, toggleDead, setFormat, setPlayerName, resetGame, load } = sandbox;

console.log("scoreWicket clears deadness and advances");
toggleDead("blue", "red");
check(saved().balls.blue.deadOn.includes("red"), "blue is dead on red after toggle");
scoreWicket("blue");
check(saved().balls.blue.wicket === 1, "blue advanced to wicket index 1");
check(saved().balls.blue.deadOn.length === 0, "deadness cleared on score");

console.log("toggle off");
toggleDead("black", "yellow");
check(saved().balls.black.deadOn.includes("yellow"), "black dead on yellow");
toggleDead("black", "yellow");
check(!saved().balls.black.deadOn.includes("yellow"), "black no longer dead on yellow");

console.log("retreat floors at 0, never negative");
retreatWicket("red");
check(saved().balls.red.wicket === 0, "red stays at 0");

console.log("score does not pass the stake");
for (let i = 0; i < 20; i++) scoreWicket("yellow");
check(saved().balls.yellow.wicket === 12, "yellow capped at Stake (12)");

console.log("setFormat to six-ball is non-destructive");
setPlayerName("blue", "Alex");
setFormat("sixBall");
let s = saved();
check(Object.keys(s.balls).length === 6, "six balls present");
check(s.balls.green && s.balls.orange, "green and orange added");
check(s.balls.blue.wicket === 1, "blue keeps its wicket");
check(s.balls.blue.player === "Alex", "blue keeps player name");

console.log("six-ball deadness then back to four-ball drops extras");
toggleDead("blue", "green");
check(saved().balls.blue.deadOn.includes("green"), "blue dead on green in six-ball");
setFormat("fourBall");
s = saved();
check(Object.keys(s.balls).length === 4, "back to four balls");
check(!s.balls.green && !s.balls.orange, "green/orange dropped");
check(!s.balls.blue.deadOn.includes("green"), "stale deadness on green removed");

console.log("reset clears to current format");
resetGame();
s = saved();
check(s.format === "fourBall" && s.balls.blue.wicket === 0 && s.balls.blue.player === "",
  "reset returns a clean four-ball game");

console.log("load migrates a formatless saved game to four-ball");
store.set("croquet.game.v1", JSON.stringify({
  balls: { blue: { player: "", wicket: 3, deadOn: ["red", "ghost"] } },
}));
const migrated = load();
check(migrated.format === "fourBall", "missing format defaults to four-ball");
check(migrated.balls.blue.wicket === 3, "wicket carried over");
check(migrated.balls.blue.deadOn.includes("red") && !migrated.balls.blue.deadOn.includes("ghost"),
  "unknown deadness target filtered out");

console.log(`\n${assertions - failures}/${assertions} checks passed`);
process.exit(failures ? 1 : 0);
