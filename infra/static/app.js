const WS_URL = `ws://${window.location.host}/ws`;
let ws;
let nodes = [];
let services = [];

const canvas = document.getElementById('infra-canvas');
const ctx = canvas.getContext('2d');
canvas.width = 1100;
canvas.height = 600;

const connectionStatus = document.getElementById('connection-status');
const lastUpdate = document.getElementById('last-update');

const statusColors = {
    'ok': '#27ae60',
    'Ready': '#27ae60',
    'error': '#e74c3c',
    'NotReady': '#e74c3c',
    'degraded': '#f39c12',
    'unknown': '#95a5a6'
};

function connectWebSocket() {
    ws = new WebSocket(WS_URL);
    ws.onopen = () => {
        connectionStatus.innerHTML = 'Подключено';
        connectionStatus.style.color = '#27ae60';
        fetchSnapshot();
    };
    ws.onmessage = (event) => {
        const msg = JSON.parse(event.data);
        handleMessage(msg);
    };
    ws.onclose = () => {
        connectionStatus.innerHTML = 'Отключено';
        connectionStatus.style.color = '#e74c3c';
        setTimeout(connectWebSocket, 3000);
    };
    ws.onerror = () => {};
}

function handleMessage(msg) {
    switch (msg.type) {
        case 'connected':
            console.log('Connected:', msg.payload.message);
            break;
        case 'snapshot':
            nodes = msg.payload.nodes || [];
            services = msg.payload.services || [];
            lastUpdate.textContent = `Обновлено: ${new Date(msg.payload.timestamp).toLocaleTimeString()}`;
            drawCanvas();
            break;
        case 'pong':
            break;
        case 'node_status':
            const idx = nodes.findIndex(n => n.name === msg.payload.name);
            if (idx >= 0) nodes[idx] = { ...nodes[idx], ...msg.payload };
            drawCanvas();
            break;
    }
}

function fetchSnapshot() {
    if (ws && ws.readyState === WebSocket.OPEN) {
        ws.send(JSON.stringify({ type: 'get_snapshot' }));
    }
}

function drawCanvas() {
    ctx.clearRect(0, 0, canvas.width, canvas.height);
    ctx.fillStyle = '#0d0d2b';
    ctx.fillRect(0, 0, canvas.width, canvas.height);

    // Сетка
    ctx.strokeStyle = '#16213e';
    ctx.lineWidth = 0.5;
    for (let x = 0; x < canvas.width; x += 50) {
        ctx.beginPath(); ctx.moveTo(x, 0); ctx.lineTo(x, canvas.height); ctx.stroke();
    }
    for (let y = 0; y < canvas.height; y += 50) {
        ctx.beginPath(); ctx.moveTo(0, y); ctx.lineTo(canvas.width, y); ctx.stroke();
    }

    // Заголовки секций
    ctx.fillStyle = '#00d2ff';
    ctx.font = 'bold 13px Segoe UI';
    ctx.textAlign = 'left';
    ctx.fillText('УЗЛЫ KUBERNETES', 80, 185);
    ctx.fillText('СЕРВИСЫ', 80, 405);

    // Ноды
    const nodeWidth = 160, nodeHeight = 100, startX = 80, startY = 200, gap = 30;
    nodes.forEach((node, i) => {
        const x = startX + (nodeWidth + gap) * i, y = startY;
        const color = statusColors[node.Status] || statusColors.unknown;
        ctx.fillStyle = 'rgba(26, 26, 46, 0.9)';
        ctx.strokeStyle = color; ctx.lineWidth = 2;
        roundRect(x, y, nodeWidth, nodeHeight, 12);
        ctx.fillStyle = '#e0e0e0'; ctx.font = 'bold 12px Segoe UI'; ctx.textAlign = 'center';
        ctx.fillText(node.name, x + nodeWidth / 2, y + 25);
        ctx.fillStyle = '#888'; ctx.font = '10px Segoe UI';
        ctx.fillText(node.role.toUpperCase(), x + nodeWidth / 2, y + 42);
        ctx.fillStyle = color; ctx.font = 'bold 14px Segoe UI';
        ctx.fillText(node.Status, x + nodeWidth / 2, y + 65);
        ctx.fillStyle = '#aaa'; ctx.font = '10px Segoe UI';
        ctx.fillText(`CPU: ${node.CPU}% | RAM: ${node.RAM}%`, x + nodeWidth / 2, y + 85);
    });

    // Сервисы
    services.forEach((svc, i) => {
        const x = 80 + i * 170, y = 420;
        const color = statusColors[svc.Status] || statusColors.unknown;
        ctx.fillStyle = 'rgba(26, 26, 46, 0.9)';
        ctx.strokeStyle = color; ctx.lineWidth = 2;
        roundRect(x, y, 150, 60, 8);
        ctx.fillStyle = '#e0e0e0'; ctx.font = 'bold 11px Segoe UI'; ctx.textAlign = 'center';
        ctx.fillText(svc.name, x + 75, y + 25);
        ctx.fillStyle = color; ctx.font = '10px Segoe UI';
        ctx.fillText(svc.Status.toUpperCase(), x + 75, y + 45);
    });
}

function roundRect(x, y, w, h, r) {
    ctx.beginPath();
    ctx.moveTo(x + r, y);
    ctx.lineTo(x + w - r, y);
    ctx.quadraticCurveTo(x + w, y, x + w, y + r);
    ctx.lineTo(x + w, y + h - r);
    ctx.quadraticCurveTo(x + w, y + h, x + w - r, y + h);
    ctx.lineTo(x + r, y + h);
    ctx.quadraticCurveTo(x, y + h, x, y + h - r);
    ctx.lineTo(x, y + r);
    ctx.quadraticCurveTo(x, y, x + r, y);
    ctx.closePath();
    ctx.fill(); ctx.stroke();
}

document.getElementById('refresh-btn').addEventListener('click', fetchSnapshot);
connectWebSocket();
