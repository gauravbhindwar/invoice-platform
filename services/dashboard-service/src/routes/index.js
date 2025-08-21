import { Router } from 'express';
import { ok, fail } from '@invoice/common';
import mongoose from 'mongoose';

const r = Router();

r.get('/metrics', async (req, res) => {
	try {
		const userId = mongoose.Types.ObjectId(req.user.id);
		const db = mongoose.connection;
		const invCol = db.collection('invoices');
		const expCol = db.collection('expenseinvoices');

		const totalRevenueAgg = await invCol.aggregate([{ $match: { user: userId } }, { $group: { _id: null, total: { $sum: '$total' } } }]).toArray();
		const totalRevenue = totalRevenueAgg[0]?.total || 0;
		const invoiceCount = await invCol.countDocuments({ user: userId });
		const expenseTotalAgg = await expCol.aggregate([{ $match: { userId: req.user.id } }, { $group: { _id: null, total: { $sum: '$total' } } }]).toArray();
		const totalExpenses = expenseTotalAgg[0]?.total || 0;

		return ok(res, { totalRevenue, totalExpenses, invoiceCount });
	} catch (err) {
		return fail(res, 500, err.message);
	}
});

export default r;