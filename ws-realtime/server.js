import { WebSocket, WebSocketServer } from "ws";
import { Board } from "./board.js";

let smLatency = process.argv[2] ? parseInt(process.argv[2]) : 0
const tps = 20; // Ticks per second
const serverDisplay = true; // Display the server's board in the console
const debugPos = false;
const debugMsg = false;

const wss = new WebSocketServer({ port: "8080" });
let lastPlayerInput = {};

let board = new Board(20, 15);

// Simulate latency function
function simulateLatency(func, delay) {
  return function(...args) {
    setTimeout(() => {
      func.apply(this, args);
    }, delay);
  };
}

let display = () => {
  if (serverDisplay) {
    console.clear();
    board.draw();
  }
}

board.addEnemies(3)

// Update all clients with the current state of the board
setInterval(() => {
  board.moveEnemies();
  const playerPositions = board.exportPlayerPositions().map(playerString => {
    const id = playerString.split('-')[0];
    const position = playerString.split('-')[1];
    return `${id}-${lastPlayerInput[id]}-${position}`;
  }).join("|");

  const enemyPositions = board.exportEnemyPositions().map(enemyString => {
    return enemyString;
  }).join("|");    

  const timestamp = Date.now();
  const message = `${timestamp}=p|${playerPositions}=e|${enemyPositions}`;

  wss.clients.forEach((client) => {
    if (client.readyState === WebSocket.OPEN) {
      simulateLatency(() => {
        client.send(message);
      }, smLatency / 2)(); // One-way latency - server is only sending data
    }
  });
  
  display();
  if (debugMsg) {
    console.log('Sent:', message);
  }

}, 1000 / tps);

wss.on("connection", (ws) => {
  ws.on("close", () => {
    if (ws.id !== undefined) {
      board.deletePlayer(ws.id);
      delete lastPlayerInput[ws.id];
    }
  });

  ws.on("message", simulateLatency((message) => {
    if (message.toString() === "cc") {
      ws.id = board.addPlayer();
      lastPlayerInput[ws.id] = 0;
      simulateLatency(() => {
        ws.send("a" + ws.id);
      }, smLatency / 2)();
    } else if (message.toString().startsWith("i")) { // Ping
      simulateLatency(() => {
        ws.send(message.toString()); 
      }, smLatency / 2)(); // One-way latency - server is only sending data
    } else if (message.toString().startsWith("p")) { // Position
      const newPosition = parseCoordinates(message.toString());
      lastPlayerInput[ws.id] = newPosition[0];
      board.movePlayer(ws.id, newPosition[1]);
      if (debugPos) {
        console.log('In server:', newPosition[0], newPosition[1]);
      }
    }
  }, smLatency / 2)); // One-way latency - server is only receiving data
});

function parseCoordinates(message) {
  const parts = message.slice(1).split("-");
  const nInput = parts[0];
  const coordinates = parts[1].split("·");
  return [
    parseInt(nInput, 10),
    { x: parseInt(coordinates[0], 10), y: parseInt(coordinates[1], 10) },
  ];
}
