import { Router } from 'express';
import { ok, created, fail } from '@invoice/common';
import Upload from '../models/upload.model.js';

const r = Router();

r.post('/upload', async (req, res) => {
  try {
    // For now expect that some middleware saved file info in req.file
    const file = req.file || req.body.file;
    if (!file) return fail(res, 400, 'No file provided');
    const doc = await Upload.create({
      userId: req.user?.id,
      filename: file.originalname || file.filename || file.name,
      contentType: file.mimetype || file.contentType || 'application/octet-stream',
      size: file.size || 0,
      path: file.path || `/uploads/${file.filename || file.name}`
    });
    return created(res, { url: doc.path, id: doc._id });
  } catch (err) {
    return fail(res, 500, err.message);
  }
});

export default r;