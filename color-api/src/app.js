const express = require('express');
const morgan = require('morgan');
const mongoose = require('mongoose');
const bodyParser = require('body-parser');

const { apiRouter } = require('#routes/api');
const { healthRouter } = require('#routes/health');
const { readyRouter } = require('#routes/ready');

const app = express();
const port = 80;

const colorsUsername = "colors";
const colorsPassword = "colors";
const colorsDatabase = "colors";
const databaseShards = [
    {
        name: 'shard-0',
        host: 'mongo-shards-0.database',
        port: 27017
    },
    {
        name: 'shard-1',
        host: 'mongo-shards-1.database',
        port: 27017
    },
    {
        name: 'shard-2',
        host: 'mongo-shards-2.database',
        port: 27017
    }
]

app.use(morgan('combined'));
app.use(bodyParser.json());

app.get('/up', (req, res) => { res.status(200).send('ok'); });
app.use('/health', healthRouter);
app.use('/ready', readyRouter);
app.use('/api', apiRouter);

// Temporarily use only one shard
mongoUri = `mongodb://${colorsUsername}:${colorsPassword}@${databaseShards[0].host}:${databaseShards[0].port}/${colorsDatabase}`;
mongoose.connect(mongoUri, {
    auth: {
        username: colorsUsername,
        password: colorsPassword,
    },
    connectTimeoutMS: 1000,
})
.then(() => {
    console.log('Connected to MongoDB');

    app.listen(port, () => {
      console.log(`Server is running on port ${port}`);
    });
}).catch((error) => {
    console.error('Error connecting to MongoDB:', error);
});

