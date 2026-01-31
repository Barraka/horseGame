const { Room } = require("colyseus");

class RidingRoom extends Room {
    onCreate() {
        // Track players as plain objects (no schema needed)
        this.playerStates = {};

        // Handle movement updates from clients
        this.onMessage("move", (client, data) => {
            this.playerStates[client.sessionId] = {
                x: data.x,
                y: data.y,
                z: data.z,
                rotY: data.rotY,
                gaitIndex: data.gaitIndex,
                speed: data.speed,
            };
        });

        // Broadcast all player states at 20 Hz
        this.setSimulationInterval(() => {
            this.broadcast("state", {
                players: this.playerStates,
            });
        }, 50);
    }

    onJoin(client) {
        console.log(`Player joined: ${client.sessionId}`);
        this.playerStates[client.sessionId] = {
            x: 0, y: 0.5, z: 0, rotY: 0, gaitIndex: 0, speed: 0,
        };
        // Tell the new client their session ID
        client.send("init", { sessionId: client.sessionId });
        // Tell everyone about the join
        this.broadcast("playerJoined", { sessionId: client.sessionId });
    }

    onLeave(client) {
        console.log(`Player left: ${client.sessionId}`);
        delete this.playerStates[client.sessionId];
        this.broadcast("playerLeft", { sessionId: client.sessionId });
    }
}

module.exports = { RidingRoom };
