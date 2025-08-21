import { Router } from 'express';
import { ok, fail } from '@invoice/common';
import mongoose from 'mongoose';

const r = Router();

r.get('/summary', async (req, res) => {
	try {
		const userId = mongoose.Types.ObjectId(req.user.id);
		// Simple aggregation placeholder: sum cgst/sgst/igst on the invoices collection
		const db = mongoose.connection;
		const invoices = db.collection('invoices');
		const pipeline = [
			{ $match: { user: userId } },
			{ $group: { _id: null, taxCollected: { $sum: { $add: ['$cgst', '$sgst', '$igst'] } }, taxableSales: { $sum: '$subtotal' } } }
		];
		const resAgg = await invoices.aggregate(pipeline).toArray();
		const item = resAgg[0] || { taxCollected: 0, taxableSales: 0 };
		return ok(res, { taxCollected: item.taxCollected, taxableSales: item.taxableSales });
	} catch (err) {
		return fail(res, 500, err.message);
	}
});

export default r;