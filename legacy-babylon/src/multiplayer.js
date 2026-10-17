// ============================================================
// Multiplayer client module — uses Colyseus SDK (global)
// Uses simple message broadcasting (no schema sync)
// ============================================================

const Multiplayer = {
    client: null,
    room: null,
    localSessionId: null,
    remotePlayers: {},   // sessionId -> { mesh, state }
    scene: null,
    createHorseFn: null,
    connected: false,
    sendTimer: 0,
    sendInterval: 50,    // send at 20 Hz (every 50ms)

    async connect(scene, createHorseFn) {
        this.scene = scene;
        this.createHorseFn = createHorseFn;

        try {
            this.client = new Colyseus.Client("ws://localhost:2567");
            this.room = await this.client.joinOrCreate("riding");
            this.localSessionId = this.room.sessionId;
            this.connected = true;
            console.log("Connected to server, sessionId:", this.localSessionId);

            // Server sends us init with our session ID
            this.room.onMessage("init", (data) => {
                console.log("Server confirmed session:", data.sessionId);
            });

            // Server broadcasts all player states at 20 Hz
            this.room.onMessage("state", (data) => {
                const players = data.players;
                for (const sessionId in players) {
                    if (sessionId === this.localSessionId) continue;

                    // Create mesh for new remote player
                    if (!this.remotePlayers[sessionId]) {
                        console.log("Remote player appeared:", sessionId);
                        const mesh = this.createHorseFn(this.scene, sessionId);
                        this.remotePlayers[sessionId] = { mesh, state: players[sessionId] };
                    } else {
                        // Update state
                        this.remotePlayers[sessionId].state = players[sessionId];
                    }
                }

                // Remove players no longer in the state
                for (const id in this.remotePlayers) {
                    if (!players[id]) {
                        this.remotePlayers[id].mesh.getChildMeshes().forEach(m => m.dispose());
                        this.remotePlayers[id].mesh.dispose();
                        delete this.remotePlayers[id];
                        console.log("Remote player removed:", id);
                    }
                }
            });

            // Explicit leave message
            this.room.onMessage("playerLeft", (data) => {
                const remote = this.remotePlayers[data.sessionId];
                if (remote) {
                    remote.mesh.getChildMeshes().forEach(m => m.dispose());
                    remote.mesh.dispose();
                    delete this.remotePlayers[data.sessionId];
                    console.log("Remote player left:", data.sessionId);
                }
            });

        } catch (err) {
            console.warn("Could not connect to multiplayer server:", err.message);
            console.warn("Running in offline/single-player mode.");
            this.connected = false;
        }
    },

    sendState(horseState, horsePosition, dt) {
        if (!this.connected || !this.room) return;

        // Throttle sends to 20 Hz
        this.sendTimer += dt * 1000;
        if (this.sendTimer < this.sendInterval) return;
        this.sendTimer = 0;

        this.room.send("move", {
            x: horsePosition.x,
            y: horsePosition.y,
            z: horsePosition.z,
            rotY: horseState.rotation,
            gaitIndex: horseState.targetGaitIndex,
            speed: horseState.speed,
        });
    },

    updateRemotePlayers() {
        for (const id in this.remotePlayers) {
            const { mesh, state } = this.remotePlayers[id];
            // Interpolate toward latest state for smooth visuals
            mesh.position.x += (state.x - mesh.position.x) * 0.2;
            mesh.position.y += (state.y - mesh.position.y) * 0.2;
            mesh.position.z += (state.z - mesh.position.z) * 0.2;

            // Interpolate rotation (handle wrapping)
            let rotDiff = state.rotY - mesh.rotation.y;
            if (rotDiff > Math.PI) rotDiff -= Math.PI * 2;
            if (rotDiff < -Math.PI) rotDiff += Math.PI * 2;
            mesh.rotation.y += rotDiff * 0.2;
        }
    },
};
