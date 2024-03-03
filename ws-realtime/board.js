export class Board {
  constructor(x, y) {
    this.x = x;
    this.y = y;
    this.tiles = [];
    this.playerSymbols = ["@", "&", "$", "#", "!", "%"];
    this.activePlayerSymbols = [];

    this.create();
  }

  create() {
    Array(this.y)
      .fill()
      .forEach((currentY, i) => {
        this.tiles[i] = [];
        Array(this.x)
          .fill()
          .forEach((currentX, j) => {
            if (i === 0 || i === this.y - 1 || j === 0 || j === this.x - 1) {
              this.tiles[i][j] = "*";
            } else {
              this.tiles[i][j] = " ";
            }
          });
      });
  }

  addPlayer() {
    if (this.playerSymbols.length === 0) {
      console.log("No more players can be added.");
      return;
    }

    const symbol = this.playerSymbols.shift();
    this.activePlayerSymbols.push(symbol);

    // Gather all possible locations
    let possibleLocations = [];
    for (let i = 0; i < this.y; i++) {
      for (let j = 0; j < this.x; j++) {
        if (this.tiles[i][j] === " ") {
          possibleLocations.push({ i, j });
        }
      }
    }

    if (possibleLocations.length === 0) {
      console.log("No empty space found on the board.");
      return;
    }

    // Select a random location
    const location =
      possibleLocations[Math.floor(Math.random() * possibleLocations.length)];

    // Place the player on the board
    this.tiles[location.i][location.j] = symbol;
  }

  deletePlayer(symbol) {
    let playerFound = false;

    this.tiles.forEach((row, i) => {
      row.forEach((tile, j) => {
        if (tile === symbol) {
          this.tiles[i][j] = " ";
          playerFound = true;
        }
      });
    });

    if (!playerFound) {
      console.log(`Player ${symbol} not found.`);
      return;
    }

    const index = this.activePlayerSymbols.indexOf(symbol);
    if (index > -1) {
      this.activePlayerSymbols.splice(index, 1);
      this.playerSymbols.unshift(symbol);
    }
  }

  draw() {
    this.tiles.forEach((row) => {
      console.log(row.join(""));
    });
  }

  exportTiles() {
    let tilesString = "";
    this.tiles.forEach((row) => {
      row.forEach((tile) => {
        tilesString += tile;
      });
      tilesString += "\n";
    });
    return tilesString;
  }

  exportPlayerPositions() {
    const playerPositions = [];
  
    this.tiles.forEach((row, rowIndex) => {
      row.forEach((tile, colIndex) => {
        if (this.activePlayerSymbols.includes(tile)) {
          const positionString = `s${tile};p${colIndex},${rowIndex}`;
          playerPositions.push(positionString);
        }
      });
    });
  
    return playerPositions;
  }

  importTiles(tilesString) {
    const rows = tilesString.split("\n");
    this.tiles = rows.map((row) => row.split(""));
  }

  movePlayer(symbol, newPosition) {
    let i, j;
  
    // Find the player on the board
    this.tiles.forEach((row, rowIndex) => {
      row.forEach((tile, colIndex) => {
        if (tile === symbol) {
          i = rowIndex;
          j = colIndex;
        }
      });
    });
  
    if (i === undefined || j === undefined) {
      console.log(`Player ${symbol} not found.`);
      return;
    }
  
    // Calculate the distance to the new position
    const distance = Math.abs(newPosition.y - i) + Math.abs(newPosition.x - j);
  
    // Check if the new position is valid
    if (distance !== 1) {
      console.log(`Player ${symbol} can only move 1 tile at a time.`);
      return;
    }
  
    // Check if the new position is a wall or another player
    const tile = this.tiles[newPosition.y][newPosition.x];
    if (tile === 'wall' || tile === 'player') {
      console.log(`Player ${symbol} cannot move into a wall or another player.`);
      return;
    }
  
    // Move the player to the new position
    this.tiles[i][j] = ' '; // Assuming ' ' represents an empty tile
    this.tiles[newPosition.y][newPosition.x] = symbol;
  }

  addEnemies(n) {
    this.enemies = [];
    const directions = ["u", "d", "l", "r"];
  
    for (let i = 0; i < n; i++) {
      let enemy;
      do {
        enemy = {
          i: Math.floor(Math.random() * this.y),
          j: Math.floor(Math.random() * this.x),
          direction: directions[Math.floor(Math.random() * directions.length)],
        };
      } while (this.tiles[enemy.i][enemy.j] !== ' ');
  
      this.enemies.push(enemy);
      this.tiles[enemy.i][enemy.j] = enemy.direction;
    }
  }

  moveEnemies() {
    for (let enemy of this.enemies) {
      let newI = enemy.i,
        newJ = enemy.j;
  
      switch (enemy.direction) {
        case "u":
          newI = enemy.i - 1;
          break;
        case "d":
          newI = enemy.i + 1;
          break;
        case "l":
          newJ = enemy.j - 1;
          break;
        case "r":
          newJ = enemy.j + 1;
          break;
      }
  
      // Check if the new position is a wall, a player, or another enemy
      if (this.tiles[newI][newJ] === "*" || this.tiles[newI][newJ] !== " ") {
        // Change direction to the opposite
        let oppositeDirection;
        switch (enemy.direction) {
          case "u":
            oppositeDirection = "d";
            break;
          case "d":
            oppositeDirection = "u";
            break;
          case "l":
            oppositeDirection = "r";
            break;
          case "r":
            oppositeDirection = "l";
            break;
        }
  
        // Check if the opposite direction is available
        let oppositeI = enemy.i,
          oppositeJ = enemy.j;
        switch (oppositeDirection) {
          case "u":
            oppositeI = enemy.i - 1;
            break;
          case "d":
            oppositeI = enemy.i + 1;
            break;
          case "l":
            oppositeJ = enemy.j - 1;
            break;
          case "r":
            oppositeJ = enemy.j + 1;
            break;
        }
  
        // If the opposite direction is available, move the enemy
        if (this.tiles[oppositeI][oppositeJ] === " ") {
          this.tiles[enemy.i][enemy.j] = " ";
          enemy.i = oppositeI;
          enemy.j = oppositeJ;
          enemy.direction = oppositeDirection;
          this.tiles[enemy.i][enemy.j] = enemy.direction;
        }
      } else {
        // Move the enemy
        this.tiles[enemy.i][enemy.j] = " ";
        enemy.i = newI;
        enemy.j = newJ;
        this.tiles[enemy.i][enemy.j] = enemy.direction;
      }
    }
  }
}

// let board = new Board(24, 8);
// board.addEnemies(3);
// board.draw();
// board.moveEnemies();
// board.draw();
// board.moveEnemies();
// board.draw();
// board.addPlayer();
// board.addPlayer();
// board.draw();
// board.movePlayer("@", "d");
// board.draw();
// board.deletePlayer("@");
// board.draw();
// board.addPlayer();
// board.draw();
