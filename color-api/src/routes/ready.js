const express = require('express');

const readyRouter = express.Router();

readyRouter.get('/', (req, res) => {
    res.status(200).send('ok');
});

module.exports = { readyRouter };