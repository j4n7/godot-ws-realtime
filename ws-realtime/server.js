
import { WebSocket, WebSocketServer } from "ws"
import { Board } from "./board.js";

let tps = 20 // Ticks per second

const wss = new WebSocketServer({ port: '8080' })
let board = new Board(20, 15)

// board.addEnemies(3)

// Update all clients with the current state of the board
setInterval(() => {
    console.clear()
    board.draw()

    const playerPositions = board.exportPlayerPositions().join(':')

    wss.clients.forEach(client => {
        if (client.readyState === WebSocket.OPEN) {
            client.send(playerPositions)
        }
    })
}, 1000 / tps)

wss.on('connection', ws => {

    ws.on('close', () => {
        if (ws.symbol !== undefined) {
            board.deletePlayer(ws.symbol)
        }
        console.clear()
        board.draw()
    })

    ws.on('message', message => {
        if (message.toString() === 'cc') {
            board.addPlayer()
            ws.symbol = board.activePlayerSymbols[board.activePlayerSymbols.length - 1]
            ws.send('a' + ws.symbol)
            console.clear()
            board.draw()
        } else if (message.toString().startsWith('p')) {
            const newPosition = parseCoordinates(message.toString())
            board.movePlayer(ws.symbol, newPosition)
            console.clear()
            board.draw()
        }
    })
})

function parseCoordinates(message) {
    const parts = message.slice(1).split(',')
    return {
        x: parseInt(parts[0], 10),
        y: parseInt(parts[1], 10)
    }
}