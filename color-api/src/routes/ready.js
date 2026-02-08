const express = require('express');

const { Ring } = require('#src/db');

const readyRouter = express.Router();

readyRouter.get('/', async (req, res) => {
  try {
    const ring = Ring.getInstance();
    const connections = await ring.getAllShardConnections();
    const allReady = connections.every(conn => conn.readyState === 1);

    if (!allReady) {
      return res.status(503).json({ error: 'Not all database shards are ready' });
    }

    return res.status(200).send('ok');
  } catch (error) {
    return res.status(503).json({ error: 'Failed to connect to database shards' });
  }
});

module.exports = { readyRouter };