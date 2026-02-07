const express = require('express');
const os = require('os');
const fs = require('fs');
const path = require('path');

const getColor = () => {
    let color = process.env.DEFAULT_COLOR;
    const filePath = process.env.COLOR_CONFIG_PATH;

    if (filePath) {
        try {
            const colorFromFile = fs.readFileSync(path.resolve(filePath), 'utf8');

            color = colorFromFile.trim();
        } catch (error) {
            console.error(`Error reading color from file ${filePath}:`, error);
        }
    }

    return color || 'blue';
};

const app = express();
const port = 80;
const color = getColor();
const hostname = os.hostname();

const delayStartup = process.env.DELAY_STARTUP === 'true';
const failLiveness = process.env.FAIL_LIVENESS === 'true';
const failReadiness = process.env.FAIL_READINESS === 'true' ? Math.random() < 0.5 : false;

console.log('Delay startup:', delayStartup);
console.log('Fail liveness:', failLiveness);
console.log('Fail readiness:', failReadiness);

app.get('/', (req, res) => {
    res.send(`<h1 style="color: ${color};">Hello from Color API</h1>
<h2>Hostname: ${hostname}</h2>`);
});

app.get('/api', (req, res) => {
    const { format } = req.query;

    if (format === 'json') {
        res.json({
            color: color,
            hostname: hostname
        })
    } else {
        res.send(`COLOR: ${color}, HOSTNAME: ${hostname}`);
    }
});

app.get('/ready', (req, res) => {
    if (failReadiness) {
        return res.sendStatus(503);
    }
    return res.send('ok');
});

app.get('/up', (req, res) => {
    return res.send('ok');
});

app.get('/health', (req, res) => {
    if (failLiveness) {
        return res.sendStatus(503);
    }
    return res.send('ok');
});

if (delayStartup) {
    const start = Date.now();

    while (Date.now() - start < 60000) {}
}

app.listen(port, () => {
    console.log(`Server is running on port ${port}`);
});