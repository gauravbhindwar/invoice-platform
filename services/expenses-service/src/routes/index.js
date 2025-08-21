import { Router } from 'express';
import { ok, created, fail } from '../../../../packages/common/src/index.js';
import Expense from '../models/expense.model.js';
import mongoose from 'mongoose';
import { Readable } from 'stream';
import { stringify } from 'csv-stringify/sync';

const r = Router();

r.get('/expenses', async (req, res) => {
	try {
		const docs = await Expense.find({ userId: mongoose.Types.ObjectId(req.user.id) }).sort({ date: -1 }).limit(100).lean();
		return ok(res, docs);
	} catch (err) {
		return fail(res, 500, err.message);
	}
});

r.post('/expenses', async (req, res) => {
	try {
		const payload = { ...req.body, userId: req.user?.id || req.body.userId };
		const ex = await Expense.create(payload);
		return created(res, { id: ex._id });
	} catch (err) {
		return fail(res, 500, err.message);
	}
});

r.get('/expenses/export', async (req, res) => {
	try {
		const docs = await Expense.find({ userId: mongoose.Types.ObjectId(req.user.id) }).lean();
		if (!docs.length) return res.status(204).end();
		const records = docs.map(d => ({ 'Invoice #': d.invoiceNumber, Date: d.date ? new Date(d.date).toISOString().split('T')[0] : '', Vendor: d.billFrom?.name || '', Amount: d.total, Status: d.status }));
		const csv = stringify(records, { header: true });
		res.setHeader('Content-Type', 'text/csv');
		res.setHeader('Content-Disposition', 'attachment; filename=expenses.csv');
		Readable.from([csv]).pipe(res);
	} catch (err) {
		return fail(res, 500, err.message);
	}
});

export default r;