const HEX_COLOR_REGEX = /^#([0-9a-fA-F]{6})$/;
const DUPLICATE_KEY_ERROR = 11000;  // MongoDB error code for duplicate key error
const DEFAULT_COLOR = '#000000';  // Default color if no color is provided - Black

module.exports = { HEX_COLOR_REGEX, DUPLICATE_KEY_ERROR, DEFAULT_COLOR };
