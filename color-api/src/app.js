const express = require('express');
const morgan = require('morgan');
const bodyParser = require('body-parser');

const { apiRouter } = require('#routes/api');
const { healthRouter } = require('#routes/health');
const { readyRouter } = require('#routes/ready');

const app = express();
const port = process.env.PORT || 80;

app.use(morgan('combined'));
app.use(bodyParser.json());

app.get('/up', (req, res) => { res.status(200).send('ok'); });
app.use('/health', healthRouter);
app.use('/ready', readyRouter);
app.use('/api', apiRouter);

app.listen(port, () => {
    console.log(`Server is running on port ${port}`);
});
