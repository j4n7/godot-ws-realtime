
import { WebSocket, WebSocketServer } from "ws"
import { Board } from "./board.js";

let tps = 20 // Ticks per second

const wss = new WebSocketServer({ port: '8080' })
let board = new Board(20, 15)

// board.addEnemies(3)

// Update all clients with the current state of the board
setInterval(() => {
    console.clear()
    // board.moveEnemies()
    board.draw()

    wss.clients.forEach(client => {
        if (client.readyState === WebSocket.OPEN) {
            client.send(board.exportTiles())
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

        // wss.clients.forEach(client => {
        //     if (client.readyState === WebSocket.OPEN) {
        //         client.send(board.exportTiles())
        //     }
        // })
    })

    ws.on('message', message => {
        if (message.toString() === 'cc') {
            board.addPlayer()
            ws.symbol = board.activePlayerSymbols[board.activePlayerSymbols.length - 1]
            ws.send('s' + ws.symbol)
            console.clear()
            board.draw()

            // wss.clients.forEach(client => {
            //     if (client.readyState === WebSocket.OPEN) {
            //         client.send(board.exportTiles())
            //     }
            // })
        } else {
            console.log(message.toString())
            board.movePlayer(ws.symbol, message.toString())
            console.clear()
            board.draw()
    
            // wss.clients.forEach(client => {
            //     if (client.readyState === WebSocket.OPEN) {
            //         client.send(board.exportTiles())
            //     }
            // })
        }
    })
})