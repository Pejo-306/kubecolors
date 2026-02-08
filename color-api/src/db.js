const mongoose = require('mongoose');
const XXH = require('xxhashjs');

const { 
    CONFIG_PATH,
    COLORS_USERNAME_ENV, 
    COLORS_PASSWORD_ENV,
    COLORS_DATABASE_ENV,
    HASH_SEED
} = require('#src/constant');

function getDatabaseShards() {
    const config = require(CONFIG_PATH);
    const { statefulSet, service, replicas: shardCount, port: dbPort } = config.database;

    return Array.from({ length: shardCount }, (_, i) => ({
        name: `shard-${i}`,
        host: `${statefulSet}-${i}.${service}`,
        port: dbPort
    }));
}

function getDatabaseCredentials() {
    return {
        username: process.env[COLORS_USERNAME_ENV],
        password: process.env[COLORS_PASSWORD_ENV],
        database: process.env[COLORS_DATABASE_ENV]
    };
}

function getConnectionUri(shard) {
    const { username, password, database } = getDatabaseCredentials();
    return `mongodb://${username}:${password}@${shard.host}:${shard.port}/${database}`;
}

async function checkDatabaseConnections() {
    const databaseShards = getDatabaseShards();
    const { username, password } = getDatabaseCredentials();

    for (const shard of databaseShards) {
        const { name, host, port } = shard;
        const mongoUri = getConnectionUri(shard);
        const connection = mongoose.createConnection(mongoUri, {
            auth: {
                username: username,
                password: password,
            },
            connectTimeoutMS: 1000,
        });
        await connection.asPromise();
        console.log(`Shard ${name} is reachable at ${host}:${port}`);
        await connection.close();
    }
}

/** Ring of database shards
 * 
 * This is a data structure which implements consistent hashing to evenly distribute
 * MongoDB connections and color keys across the shards.
*/
class Ring {
    static #instance = null;

    static getInstance(virtualNodes = 64) {
        if (!Ring.#instance) {
            Ring.#instance = new Ring(virtualNodes);
        }
        return Ring.#instance;
    }

    constructor(virtualNodes = 64) {
        this.virtualNodes = virtualNodes;
        this.ring = [];
        this.connections = [];
        this.build();
    }

    build() {
        const databaseShards = getDatabaseShards();

        for (const shard of databaseShards) {
            const uri = getConnectionUri(shard);
            for (let i = 0; i < this.virtualNodes; i++) {
                this.ring.push({
                    hash: this.hashUri(`${uri}#${i}`),
                    uri: uri
                });
            }
        }
        this.ring.sort((a, b) => a.hash - b.hash);
    }

    async destroy() {
        const uris = Object.keys(this.connections);
        await Promise.all(uris.map(uri => this.connections[uri].close()));
        this.connections = [];
        this.ring = [];
        Ring.#instance = null;
    }

    /** Get shard where a given key is stored */
    getShard(key) {
        const keyHash = this.hashKey(key);

        for (const node of this.ring) {
            if (keyHash <= node.hash) {
                return node.uri;
            }
        }

        // wrap around
        return this.ring[0].uri;
    }

    async getShardConnection(key) {
        const mongoUri = this.getShard(key);
        return this.#getConnection(mongoUri);
    }

    async getAllShardConnections() {
        const databaseShards = getDatabaseShards();
        const uris = databaseShards.map(shard => getConnectionUri(shard));
        return Promise.all(uris.map(uri => this.#getConnection(uri)));
    }

    async #getConnection(mongoUri) {
        if (!this.connections[mongoUri]) {
            const { username, password } = getDatabaseCredentials();
            const connection = mongoose.createConnection(mongoUri, {
                auth: { username, password },
                connectTimeoutMS: 1000,
            });

            await connection.asPromise();
            this.connections[mongoUri] = connection;
        }
        return this.connections[mongoUri];
    }

    hashKey(key) {
        return this.#hash(key);
    }

    hashUri(uri) {
        return this.#hash(uri);
    }

    #hash(value) {
        return XXH.h32(value, HASH_SEED).toNumber();
    }
}

module.exports = {
    getDatabaseShards,
    getDatabaseCredentials,
    getConnectionUri,
    checkDatabaseConnections,
    Ring
};
