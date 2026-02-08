const HEX_COLOR_REGEX = /^#([0-9a-fA-F]{6})$/;
const DEFAULT_COLOR = '#000000';  // Default color if no color is provided - Black
const DUPLICATE_KEY_ERROR = 11000;  // MongoDB error code for duplicate key error
const HASH_SEED = 0xCAFEBABE;  // Seed for XXH hash function

const CONFIG_PATH = '/app/config/config.json';  // Path to mounted config file on container
const COLORS_USERNAME_ENV = 'COLORS_USERNAME';  // Environment variable for MongoDB username
const COLORS_PASSWORD_ENV = 'COLORS_PASSWORD';  // Environment variable for MongoDB password
const COLORS_DATABASE_ENV = 'COLORS_DATABASE';  // Environment variable for MongoDB database name

module.exports = { 
  HEX_COLOR_REGEX,
  DUPLICATE_KEY_ERROR,
  DEFAULT_COLOR,
  HASH_SEED,
  CONFIG_PATH,
  COLORS_USERNAME_ENV,
  COLORS_PASSWORD_ENV,
  COLORS_DATABASE_ENV
};
