import { WebSocket, WebSocketServer } from "ws";
import { Board } from "./board.js";

let smLatency = process.argv[2] ? parseInt(process.argv[2]) : 0
const tps = 20; // Ticks per second
const serverDisplay = true; // Display the server's board in the console
const debugPos = false;

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

// board.addEnemies(3)

// Update all clients with the current state of the board
setInterval(() => {
  const playerPositions = board.exportPlayerPositions().map(playerString => {
    const symbol = playerString.split('-')[0]; // Extract the symbol from the string
    return `${lastPlayerInput[symbol]}-${playerString}`;
  }).join("|");

  const timestamp = Date.now();
  const message = `${timestamp}|${playerPositions}`;

  wss.clients.forEach((client) => {
    if (client.readyState === WebSocket.OPEN) {
      simulateLatency(() => {
        client.send(message);
      }, smLatency / 2)(); // One-way latency - server is only sending data
    }
  });
  
 display();

}, 1000 / tps);

wss.on("connection", (ws) => {
  ws.on("close", () => {
    if (ws.symbol !== undefined) {
      board.deletePlayer(ws.symbol);
      delete lastPlayerInput[ws.symbol];
    }
  });

  ws.on("message", simulateLatency((message) => {
    if (message.toString() === "cc") {
      board.addPlayer();
      ws.symbol =
        board.activePlayerSymbols[board.activePlayerSymbols.length - 1];
      lastPlayerInput[ws.symbol] = 0;
      simulateLatency(() => {
        ws.send("a" + ws.symbol);
      }, smLatency / 2)();
    } else if (message.toString().startsWith("i")) { // Ping
      simulateLatency(() => {
        ws.send(message.toString()); 
      }, smLatency / 2)(); // One-way latency - server is only sending data
    } else if (message.toString().startsWith("p")) { // Position
      const newPosition = parseCoordinates(message.toString());
      lastPlayerInput[ws.symbol] = newPosition[0];
      board.movePlayer(ws.symbol, newPosition[1]);
      if (debugPos) {
        console.log('In server:', newPosition[0], newPosition[1]);
      }
    }
  }, smLatency / 2)); // One-way latency - server is only receiving data
});

function parseCoordinates(message) {
  const parts = message.slice(1).split("-");
  const nInput = parts[0];
  const coordinates = parts[1].split(",");
  return [
    parseInt(nInput, 10),
    { x: parseInt(coordinates[0], 10), y: parseInt(coordinates[1], 10) },
  ];
}
