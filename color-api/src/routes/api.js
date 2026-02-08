const os = require('os');
const express = require('express');

const { getAllColors, getColor, createColor, updateColor, deleteColor } = require('#models/color');
const { HEX_COLOR_REGEX, DUPLICATE_KEY_ERROR, DEFAULT_COLOR } = require('#src/constant');

const hostname = os.hostname();
const apiRouter = express.Router();

apiRouter.get('/', async (req, res) => {
  const { format, colorKey } = req.query;
  let color = DEFAULT_COLOR;

  if (colorKey) {
    try {
      const colorData = await getColor(colorKey);
      if (!colorData) {
        return res.status(404).json({ error: `Color '${colorKey}' not found` });
      }
      color = colorData.hex;
    } catch (error) {
      console.error('Error getting color:', error);
      return res.status(500).json({ error: 'Internal server error' });
    }
  }

  if (format === 'json') {
    return res.status(200).json({
      color: color,
      hostname: hostname
    });
  }

  return res.status(200).send(`COLOR: ${color}, HOSTNAME: ${hostname}`);
});

apiRouter.get('/color', async (req, res) => {
  try {
    const colors = await getAllColors();
    return res.status(200).json(colors);
  } catch (error) {
    console.error('Error getting colors:', error);
    return res.status(500).json({ error: 'Internal server error' });
  }
});

apiRouter.get('/color/:key', async (req, res) => {
  const { key: colorKey } = req.params;

  try {
    const color = await getColor(colorKey);
    if (!color) {
      return res.status(404).json({ error: 'Color not found' });
    }
    return res.status(200).json(color);
  } catch (error) {
    console.error('Error getting color:', error);
    return res.status(500).json({ error: 'Internal server error' });
  }
});

apiRouter.post('/color/:key', async (req, res) => {
  const { key: colorKey } = req.params;
  const { color } = req.body;
  const hex = color.startsWith('#') ? color : `#${color}`;

  if (!HEX_COLOR_REGEX.test(hex)) {
    return res.status(400).json({ error: `Invalid hex color: ${color}` });
  }

  try {
    const newColor = await createColor(colorKey, hex);
    return res.status(201).json(newColor);
  } catch (error) {
    if (error.code === DUPLICATE_KEY_ERROR) {
      return res.status(400).json({ error: `Color '${colorKey}' already exists` });
    }
    console.error('Error creating color:', error);
    return res.status(500).json({ error: `Failed to create color ${colorKey}` });
  }
});

apiRouter.put('/color/:key', async (req, res) => {
  const { key: colorKey } = req.params;
  const { color } = req.body;
  const hex = color.startsWith('#') ? color : `#${color}`;

  if (!HEX_COLOR_REGEX.test(hex)) {
    return res.status(400).json({ error: `Invalid hex color: ${color}` });
  }

  try {
    const updatedColor = await updateColor(colorKey, hex);
    if (!updatedColor) {
      return res.status(404).json({ error: `Color '${colorKey}' not found` });
    }
    return res.status(200).json(updatedColor);
  } catch (error) {
    console.error('Error updating color:', error);
    return res.status(500).json({ error: 'Internal server error' });
  }
});

apiRouter.delete('/color/:key', async (req, res) => {
  const { key: colorKey } = req.params;

  try {
    const deletedColor = await deleteColor(colorKey);
    if (!deletedColor) {
      return res.status(404).json({ error: `Color '${colorKey}' not found` });
    }
    return res.status(204).send();
  } catch (error) {
    console.error('Error deleting color:', error);
    return res.status(500).json({ error: 'Internal server error' });
  }
});

module.exports = { apiRouter };
