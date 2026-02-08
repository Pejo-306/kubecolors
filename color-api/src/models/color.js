const mongoose = require('mongoose');

const { HEX_COLOR_REGEX } = require('#src/constant');

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

const Color = mongoose.model('Color', colorSchema);

async function getAllColors() {
  const colors = await Color.find().select('key hex -_id');
  return colors;
}

async function getColor(colorKey) {
  const color = await Color.findOne({ key: colorKey });
  if (!color) return null;
  return { key: color.key, hex: color.hex };
}

async function createColor(colorKey, color) {
  const newColor = await Color.create({ key: colorKey, hex: color });
  return { key: newColor.key, hex: newColor.hex }
}

async function updateColor(colorKey, color) {
  const updatedColor = await Color.findOneAndUpdate(
    { key: colorKey },
    { hex: color },
    { new: true }
  );
  if (!updatedColor) return null;
  return { key: updatedColor.key, hex: updatedColor.hex }
}

async function deleteColor(colorKey) {
  return await Color.findOneAndDelete({ key: colorKey });
}

module.exports = { Color, getAllColors, getColor, createColor, updateColor, deleteColor };
