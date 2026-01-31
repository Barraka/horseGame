const { Server } = require("colyseus");
const { WebSocketTransport } = require("@colyseus/ws-transport");
const { RidingRoom } = require("./RidingRoom");

const gameServer = new Server({
    transport: new WebSocketTransport(),
});

gameServer.define("riding", RidingRoom);

const port = 2567;
gameServer.listen(port).then(() => {
    console.log(`Colyseus server listening on ws://localhost:${port}`);
});
