const mongoose = require('mongoose');

const { HEX_COLOR_REGEX } = require('#src/constant');
const { Ring } = require('#src/db');

const colorSchema = new mongoose.Schema({
  key: {
    type: String,
    required: true,
    unique: true,
  },
  hex: {
    type: String,
    required: true,
    match: HEX_COLOR_REGEX,
  }
});

function getColorModel(connection) {
  return connection.models.Color || connection.model('Color', colorSchema);
}

async function getAllColors() {
  const ring = Ring.getInstance();
  const connections = await ring.getAllShardConnections();

  const results = await Promise.all(
    connections.map(conn => getColorModel(conn).find().select('key hex -_id'))
  );
  return results.flat();
}

async function getColor(colorKey) {
  const ring = Ring.getInstance();
  const connection = await ring.getShardConnection(colorKey);
  const Color = getColorModel(connection);

  const color = await Color.findOne({ key: colorKey });
  if (!color) return null;
  return { key: color.key, hex: color.hex };
}

async function createColor(colorKey, hex) {
  const ring = Ring.getInstance();
  const connection = await ring.getShardConnection(colorKey);
  const Color = getColorModel(connection);

  const newColor = await Color.create({ key: colorKey, hex });
  return { key: newColor.key, hex: newColor.hex };
}

async function updateColor(colorKey, color) {
  const ring = Ring.getInstance();
  const connection = await ring.getShardConnection(colorKey);
  const Color = getColorModel(connection);

  const updatedColor = await Color.findOneAndUpdate(
    { key: colorKey },
    { hex: color },
    { new: true }
  );
  if (!updatedColor) return null;
  return { key: updatedColor.key, hex: updatedColor.hex };
}

async function deleteColor(colorKey) {
  const ring = Ring.getInstance();
  const connection = await ring.getShardConnection(colorKey);
  const Color = getColorModel(connection);

  return await Color.findOneAndDelete({ key: colorKey });
}

module.exports = { getAllColors, getColor, createColor, updateColor, deleteColor };
