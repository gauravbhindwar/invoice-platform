import { Router } from 'express';
import { ok, created, fail } from '@invoice/common';
import Item from '../models/item.model.js';
import mongoose from 'mongoose';

const r = Router();

r.post('/items', async (req, res) => {
	try {
		const payload = { ...req.body, userId: req.user?.id || req.body.userId };
		if (!payload.id) payload.id = String(new mongoose.Types.ObjectId());
		const existing = await Item.findOne({ id: payload.id, userId: payload.userId });
		if (existing) return fail(res, 409, 'Item id already exists');
		const it = await Item.create(payload);
		return created(res, { id: it._id });
	} catch (err) {
		return fail(res, 500, err.message);
	}
});

r.get('/items', async (req, res) => {
	try {
		const page = parseInt(req.query.page) || 1;
		const limit = Math.min(parseInt(req.query.limit) || 10, 100);
		const query = { userId: mongoose.Types.ObjectId(req.user.id) };
		if (req.query.search) query.productName = { $regex: req.query.search, $options: 'i' };
		const total = await Item.countDocuments(query);
		const docs = await Item.find(query).sort({ createdAt: -1 }).skip((page - 1) * limit).limit(limit).lean();
		return ok(res, { data: docs, pagination: { total, page, limit, totalPages: Math.ceil(total / limit) } });
	} catch (err) {
		return fail(res, 500, err.message);
	}
});

export default r;