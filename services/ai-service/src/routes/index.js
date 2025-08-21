import { Router } from 'express';
import { ok, fail } from '@invoice/common';
import base64 from 'base64-js';

const r = Router();

// Accept a multipart upload (middleware required in server), or JSON body with fileContent
r.post('/scan-invoice', async (req, res) => {
  try {
    // If file provided as base64 in body
    if (req.body && req.body.fileContent) {
      // echo back and return placeholder parse
      const b = req.body.fileContent;
      return ok(res, { parsed: null, filePreview: b.slice(0, 200) });
    }

    // If file was uploaded via middleware, expect req.file.buffer
    const file = req.file;
    if (!file) return fail(res, 400, 'No file provided');
    const b64 = file.buffer.toString('base64');
    return ok(res, { parsed: null, filePreview: b64.slice(0, 200) });
  } catch (err) {
    return fail(res, 500, err.message);
  }
});

export default r;