// ============================================================
// Leonie Game — Basic Riding Scene
// ============================================================

const canvas = document.getElementById("renderCanvas");
const engine = new BABYLON.Engine(canvas, true);

function createScene() {
    const scene = new BABYLON.Scene(engine);
    scene.clearColor = new BABYLON.Color3(0.53, 0.81, 0.92); // sky blue

    // --- Camera: follows the horse from behind ---
    const camera = new BABYLON.ArcRotateCamera(
        "camera",
        Math.PI,            // alpha (behind the horse)
        Math.PI / 3,        // beta (looking down at ~60°)
        12,                 // radius (distance from horse)
        BABYLON.Vector3.Zero(),
        scene
    );
    camera.lowerRadiusLimit = 5;
    camera.upperRadiusLimit = 25;
    camera.lowerBetaLimit = 0.3;
    camera.upperBetaLimit = Math.PI / 2.2;
    // Only allow mouse/touch camera control (zoom via pinch/scroll), disable keyboard
    camera.attachControl(canvas, true);
    camera.inputs.removeByType("ArcRotateCameraKeyboardMoveInput");

    // --- Light ---
    const light = new BABYLON.HemisphericLight("light", new BABYLON.Vector3(0, 1, 0), scene);
    light.intensity = 0.9;

    const dirLight = new BABYLON.DirectionalLight("dirLight", new BABYLON.Vector3(-1, -2, -1), scene);
    dirLight.intensity = 0.6;

    // --- Ground ---
    const ground = BABYLON.MeshBuilder.CreateGround("ground", { width: 200, height: 200 }, scene);
    const groundMat = new BABYLON.GridMaterial("groundMat", scene);
    groundMat.mainColor = new BABYLON.Color3(0.36, 0.63, 0.19);
    groundMat.lineColor = new BABYLON.Color3(0.24, 0.45, 0.12);
    groundMat.gridRatio = 2;
    ground.material = groundMat;

    // --- Placeholder Horse (low-poly box shape) ---
    const horse = createPlaceholderHorse(scene);
    horse.position.y = 0.5;

    // --- Camera target follows horse ---
    camera.lockedTarget = horse;

    // --- Environment objects ---
    populateEnvironment(scene);

    // --- Gait definitions ---
    const gaits = [
        { name: "Halt",   maxSpeed: 0,     acceleration: 0,     turnSpeed: 0.04,  bobAmount: 0,     bobSpeed: 0,   cameraRadius: 10 },
        { name: "Walk",   maxSpeed: 0.04,  acceleration: 0.002, turnSpeed: 0.035, bobAmount: 0.02,  bobSpeed: 3,   cameraRadius: 11 },
        { name: "Trot",   maxSpeed: 0.09,  acceleration: 0.004, turnSpeed: 0.028, bobAmount: 0.04,  bobSpeed: 6,   cameraRadius: 12 },
        { name: "Canter", maxSpeed: 0.15,  acceleration: 0.005, turnSpeed: 0.022, bobAmount: 0.06,  bobSpeed: 8,   cameraRadius: 14 },
        { name: "Gallop", maxSpeed: 0.25,  acceleration: 0.006, turnSpeed: 0.015, bobAmount: 0.08,  bobSpeed: 12,  cameraRadius: 16 },
    ];

    // --- Movement controls ---
    const input = { forward: false, backward: false, left: false, right: false };
    const horseState = {
        speed: 0,
        deceleration: 0.003,
        rotation: 0,
        gaitIndex: 0,       // 0=halt, 1=walk, 2=trot, 3=canter, 4=gallop
        targetGaitIndex: 0,
        bobPhase: 0
    };

    // --- HUD ---
    const gaitHud = document.createElement("div");
    gaitHud.id = "gaitHud";
    gaitHud.style.cssText = "position:fixed;top:16px;left:50%;transform:translateX(-50%);display:flex;gap:6px;z-index:10;font-family:sans-serif;";
    document.body.appendChild(gaitHud);

    function updateGaitHud() {
        gaitHud.innerHTML = "";
        gaits.forEach((g, i) => {
            const btn = document.createElement("div");
            btn.textContent = (i === 0 ? "■" : i) + " " + g.name;
            btn.style.cssText = "padding:6px 12px;border-radius:6px;font-size:13px;font-weight:bold;cursor:pointer;user-select:none;" +
                (i === horseState.targetGaitIndex
                    ? "background:rgba(255,255,255,0.95);color:#333;"
                    : "background:rgba(0,0,0,0.4);color:#fff;");
            btn.addEventListener("click", () => { setGait(i); });
            gaitHud.appendChild(btn);
        });
    }

    function setGait(index) {
        horseState.targetGaitIndex = Math.max(0, Math.min(gaits.length - 1, index));
        updateGaitHud();
    }

    updateGaitHud();

    // Keyboard controls
    scene.onKeyboardObservable.add((kbInfo) => {
        const pressed = kbInfo.type === BABYLON.KeyboardEventTypes.KEYDOWN;
        switch (kbInfo.event.key.toLowerCase()) {
            case "w": case "arrowup":    input.forward = pressed; break;
            case "s": case "arrowdown":  input.backward = pressed; break;
            case "a": case "arrowleft":  input.left = pressed; break;
            case "d": case "arrowright": input.right = pressed; break;
        }
        // Gait switching with number keys
        if (pressed) {
            const num = parseInt(kbInfo.event.key);
            if (num >= 0 && num <= 4) setGait(num);
        }
    });

    // Touch controls — simple zone-based
    let touchStartX = 0;
    let touchStartY = 0;
    let touchActive = false;

    canvas.addEventListener("touchstart", (e) => {
        const touch = e.touches[0];
        touchStartX = touch.clientX;
        touchStartY = touch.clientY;
        touchActive = true;
        input.forward = true;
    });

    canvas.addEventListener("touchmove", (e) => {
        if (!touchActive) return;
        const touch = e.touches[0];
        const dx = touch.clientX - touchStartX;
        input.left = dx < -30;
        input.right = dx > 30;
    });

    canvas.addEventListener("touchend", () => {
        touchActive = false;
        input.forward = false;
        input.left = false;
        input.right = false;
    });

    // --- Game loop ---
    let time = 0;
    scene.registerBeforeRender(() => {
        const dt = engine.getDeltaTime() / 1000;
        time += dt;

        const targetGait = gaits[horseState.targetGaitIndex];
        const targetSpeed = targetGait.maxSpeed;

        // Accelerate or decelerate toward target gait speed
        if (input.forward && horseState.targetGaitIndex > 0) {
            // Use target gait's acceleration
            horseState.speed = Math.min(horseState.speed + targetGait.acceleration, targetSpeed);
        } else if (input.backward) {
            horseState.speed = Math.max(horseState.speed - 0.008, -0.02);
        } else if (horseState.targetGaitIndex === 0) {
            // Halt: decelerate to stop
            if (horseState.speed > 0) {
                horseState.speed = Math.max(horseState.speed - horseState.deceleration, 0);
            } else if (horseState.speed < 0) {
                horseState.speed = Math.min(horseState.speed + horseState.deceleration, 0);
            }
        } else {
            // No input but gait selected: maintain speed toward target
            if (horseState.speed < targetSpeed) {
                horseState.speed = Math.min(horseState.speed + targetGait.acceleration * 0.5, targetSpeed);
            } else if (horseState.speed > targetSpeed) {
                horseState.speed = Math.max(horseState.speed - horseState.deceleration, targetSpeed);
            }
        }

        // Determine current effective gait (based on actual speed)
        let currentGait = gaits[0];
        for (let i = gaits.length - 1; i >= 1; i--) {
            if (horseState.speed >= gaits[i].maxSpeed * 0.5) {
                currentGait = gaits[i];
                break;
            }
        }

        // Turning — harder at higher speeds
        if (Math.abs(horseState.speed) > 0.001) {
            if (input.left) horseState.rotation -= currentGait.turnSpeed;
            if (input.right) horseState.rotation += currentGait.turnSpeed;
        } else if (horseState.targetGaitIndex === 0) {
            // Allow turning in place at halt (slow)
            if (input.left) horseState.rotation -= gaits[0].turnSpeed;
            if (input.right) horseState.rotation += gaits[0].turnSpeed;
        }

        // Apply movement
        horse.rotation.y = horseState.rotation;
        horse.position.x += Math.sin(horseState.rotation) * horseState.speed;
        horse.position.z += Math.cos(horseState.rotation) * horseState.speed;

        // Body bob animation
        if (currentGait.bobAmount > 0) {
            horseState.bobPhase += currentGait.bobSpeed * dt * Math.PI * 2;
            horse.position.y = 0.5 + Math.abs(Math.sin(horseState.bobPhase)) * currentGait.bobAmount;
        } else {
            horse.position.y = 0.5;
        }

        // Smooth camera radius transition per gait
        const targetRadius = currentGait.cameraRadius;
        camera.radius += (targetRadius - camera.radius) * 0.03;

        // Multiplayer: send local state and update remote players
        Multiplayer.sendState(horseState, horse.position, dt);
        Multiplayer.updateRemotePlayers();
    });

    // Connect to multiplayer server
    const remoteColors = [
        new BABYLON.Color3(0.2, 0.2, 0.6),   // blue
        new BABYLON.Color3(0.6, 0.15, 0.15),  // red
        new BABYLON.Color3(0.15, 0.15, 0.15), // dark grey
        new BABYLON.Color3(0.9, 0.85, 0.7),   // cream
    ];
    let colorIndex = 0;
    Multiplayer.connect(scene, (sc) => {
        const c = remoteColors[colorIndex % remoteColors.length];
        colorIndex++;
        return createPlaceholderHorse(sc, c);
    });

    return scene;
}

// Build a very simple placeholder horse from boxes
// color param is optional — defaults to brown for local player
let horseIdCounter = 0;
function createPlaceholderHorse(scene, color) {
    const id = horseIdCounter++;
    const horseMat = new BABYLON.StandardMaterial("horseMat_" + id, scene);
    horseMat.diffuseColor = color || new BABYLON.Color3(0.55, 0.35, 0.17); // brown

    // Body
    const body = BABYLON.MeshBuilder.CreateBox("horseBody_" + id, { width: 1.2, height: 1, depth: 2.2 }, scene);
    body.material = horseMat;

    // Head
    const head = BABYLON.MeshBuilder.CreateBox("horseHead", { width: 0.5, height: 0.6, depth: 0.8 }, scene);
    head.material = horseMat;
    head.position = new BABYLON.Vector3(0, 0.6, 1.3);
    head.parent = body;

    // Neck
    const neck = BABYLON.MeshBuilder.CreateBox("horseNeck", { width: 0.4, height: 0.8, depth: 0.4 }, scene);
    neck.material = horseMat;
    neck.position = new BABYLON.Vector3(0, 0.4, 0.9);
    neck.parent = body;

    // Legs
    const legPositions = [
        new BABYLON.Vector3(-0.4, -0.75, 0.7),
        new BABYLON.Vector3(0.4, -0.75, 0.7),
        new BABYLON.Vector3(-0.4, -0.75, -0.7),
        new BABYLON.Vector3(0.4, -0.75, -0.7),
    ];
    legPositions.forEach((pos, i) => {
        const leg = BABYLON.MeshBuilder.CreateBox("horseLeg" + i, { width: 0.25, height: 0.8, depth: 0.25 }, scene);
        leg.material = horseMat;
        leg.position = pos;
        leg.parent = body;
    });

    // Tail
    const tail = BABYLON.MeshBuilder.CreateBox("horseTail", { width: 0.15, height: 0.6, depth: 0.15 }, scene);
    tail.material = horseMat;
    tail.position = new BABYLON.Vector3(0, 0.1, -1.2);
    tail.rotation.x = -0.4;
    tail.parent = body;

    return body;
}

// Build low-poly environment objects
function populateEnvironment(scene) {
    const treeTrunkMat = new BABYLON.StandardMaterial("trunkMat", scene);
    treeTrunkMat.diffuseColor = new BABYLON.Color3(0.4, 0.26, 0.13);

    const treeLeafMat = new BABYLON.StandardMaterial("leafMat", scene);
    treeLeafMat.diffuseColor = new BABYLON.Color3(0.18, 0.55, 0.15);

    const darkLeafMat = new BABYLON.StandardMaterial("darkLeafMat", scene);
    darkLeafMat.diffuseColor = new BABYLON.Color3(0.12, 0.42, 0.1);

    const rockMat = new BABYLON.StandardMaterial("rockMat", scene);
    rockMat.diffuseColor = new BABYLON.Color3(0.5, 0.5, 0.48);

    const fenceMat = new BABYLON.StandardMaterial("fenceMat", scene);
    fenceMat.diffuseColor = new BABYLON.Color3(0.6, 0.45, 0.25);

    // Seeded random for consistent placement
    function seededRandom(seed) {
        let s = seed;
        return function () {
            s = (s * 16807 + 0) % 2147483647;
            return s / 2147483647;
        };
    }
    const rand = seededRandom(42);

    // --- Trees (scattered around the field) ---
    for (let i = 0; i < 40; i++) {
        const x = (rand() - 0.5) * 180;
        const z = (rand() - 0.5) * 180;

        // Skip trees too close to center (spawn area)
        if (Math.abs(x) < 8 && Math.abs(z) < 8) continue;

        const trunkHeight = 1.5 + rand() * 1.5;
        const trunk = BABYLON.MeshBuilder.CreateCylinder("trunk" + i, {
            height: trunkHeight, diameterTop: 0.25, diameterBottom: 0.4, tessellation: 6
        }, scene);
        trunk.material = treeTrunkMat;
        trunk.position = new BABYLON.Vector3(x, trunkHeight / 2, z);

        const leafSize = 1.5 + rand() * 1.5;
        const leaves = BABYLON.MeshBuilder.CreateSphere("leaves" + i, {
            diameter: leafSize, segments: 4
        }, scene);
        leaves.material = rand() > 0.5 ? treeLeafMat : darkLeafMat;
        leaves.position = new BABYLON.Vector3(x, trunkHeight + leafSize * 0.3, z);
        leaves.scaling.y = 0.7 + rand() * 0.3;
    }

    // --- Rocks ---
    for (let i = 0; i < 25; i++) {
        const x = (rand() - 0.5) * 180;
        const z = (rand() - 0.5) * 180;
        if (Math.abs(x) < 6 && Math.abs(z) < 6) continue;

        const size = 0.3 + rand() * 0.8;
        const rock = BABYLON.MeshBuilder.CreateSphere("rock" + i, {
            diameter: size, segments: 3
        }, scene);
        rock.material = rockMat;
        rock.position = new BABYLON.Vector3(x, size * 0.25, z);
        rock.scaling = new BABYLON.Vector3(
            0.8 + rand() * 0.6,
            0.5 + rand() * 0.4,
            0.8 + rand() * 0.6
        );
        rock.rotation.y = rand() * Math.PI * 2;
    }

    // --- Fence line (a paddock near spawn) ---
    const fencePosts = [
        [10, 10], [14, 10], [18, 10], [22, 10],
        [22, 14], [22, 18], [22, 22],
        [18, 22], [14, 22], [10, 22],
        [10, 18], [10, 14]
    ];
    for (let i = 0; i < fencePosts.length; i++) {
        const [fx, fz] = fencePosts[i];

        // Post
        const post = BABYLON.MeshBuilder.CreateBox("fencePost" + i, {
            width: 0.15, height: 1.2, depth: 0.15
        }, scene);
        post.material = fenceMat;
        post.position = new BABYLON.Vector3(fx, 0.6, fz);

        // Rail to next post
        const next = fencePosts[(i + 1) % fencePosts.length];
        const mx = (fx + next[0]) / 2;
        const mz = (fz + next[1]) / 2;
        const len = Math.sqrt((next[0] - fx) ** 2 + (next[1] - fz) ** 2);
        const angle = Math.atan2(next[0] - fx, next[1] - fz);

        const rail = BABYLON.MeshBuilder.CreateBox("fenceRail" + i, {
            width: 0.08, height: 0.08, depth: len
        }, scene);
        rail.material = fenceMat;
        rail.position = new BABYLON.Vector3(mx, 0.9, mz);
        rail.rotation.y = angle;

        const rail2 = rail.clone("fenceRail2_" + i);
        rail2.position.y = 0.5;
    }
}

// --- Start ---
const scene = createScene();
engine.runRenderLoop(() => scene.render());
window.addEventListener("resize", () => engine.resize());
