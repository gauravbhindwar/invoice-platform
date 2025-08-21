import { Router } from 'express';
import { BaseController } from '../../../../packages/service-framework/src/index.js';
import { ok, created, fail, buildPagination, formatPaginationResponse, toObjectId } from '@invoice/common';
import Invoice from '../models/invoice.model.js';
import mongoose from 'mongoose';
import { Readable } from 'stream';

const router = Router();

// Create enhanced controller with custom options
const invoiceController = new BaseController(Invoice, {
  userField: 'user',
  defaultSort: { date: -1 },
  buildQuery: (req, baseQuery) => {
    const query = { ...baseQuery };
    const { status, year, month } = req.query;
    
    // Filter by status
    if (status && status !== 'all') {
      query.status = status;
    }
    
    // Filter by date range
    if (year) {
      const yearNum = parseInt(year);
      const monthNum = month ? parseInt(month) : null;
      
      const start = new Date(yearNum, (monthNum || 1) - 1, 1);
      const end = monthNum 
        ? new Date(yearNum, monthNum, 0, 23, 59, 59)
        : new Date(yearNum, 11, 31, 23, 59, 59);
      
      query.date = { $gte: start, $lte: end };
    }
    
    return query;
  }
});

// Use standard CRUD routes
router.use('/', invoiceController.createRouter('invoices'));

// Custom endpoints
router.post('/invoices/:id/duplicate', async (req, res) => {
  try {
    const id = req.params.id;
    if (!mongoose.Types.ObjectId.isValid(id)) {
      return fail(res, 400, 'Invalid invoice ID');
    }

    const original = await Invoice.findOne({ 
      _id: id, 
      user: toObjectId(req.user.id) 
    }).lean();
    
    if (!original) {
      return fail(res, 404, 'Invoice not found');
    }

    // Create duplicate with new invoice number
    const duplicate = {
      ...original,
      _id: undefined,
      invoiceNumber: `${original.invoiceNumber}-COPY-${Date.now()}`,
      date: new Date(),
      status: 'draft',
      createdAt: new Date(),
      updatedAt: new Date()
    };

    const newInvoice = await Invoice.create(duplicate);
    return created(res, { invoiceId: newInvoice._id });
  } catch (err) {
    return fail(res, 500, err.message);
  }
});

router.get('/invoices/export', async (req, res) => {
  try {
    const { year, month, status } = req.query;
    const query = { user: toObjectId(req.user.id) };
    
    // Apply same filters as list endpoint
    if (status && status !== 'all') query.status = status;
    if (year) {
      const yearNum = parseInt(year);
      const monthNum = month ? parseInt(month) : null;
      const start = new Date(yearNum, (monthNum || 1) - 1, 1);
      const end = monthNum 
        ? new Date(yearNum, monthNum, 0, 23, 59, 59)
        : new Date(yearNum, 11, 31, 23, 59, 59);
      query.date = { $gte: start, $lte: end };
    }

    const invoices = await Invoice.find(query).sort({ date: -1 }).lean();
    
    // Generate CSV
    const csvHeader = 'Invoice Number,Date,Due Date,Customer,Status,Subtotal,CGST,SGST,IGST,Total\n';
    const csvRows = invoices.map(inv => [
      inv.invoiceNumber,
      inv.date ? new Date(inv.date).toISOString().split('T')[0] : '',
      inv.dueDate ? new Date(inv.dueDate).toISOString().split('T')[0] : '',
      inv.billTo?.name || '',
      inv.status,
      inv.subtotal || 0,
      inv.cgst || 0,
      inv.sgst || 0,
      inv.igst || 0,
      inv.total || 0
    ].join(',')).join('\n');

    const csv = csvHeader + csvRows;
    
    res.setHeader('Content-Type', 'text/csv');
    res.setHeader('Content-Disposition', 'attachment; filename="invoices.csv"');
    
    const stream = new Readable();
    stream.push(csv);
    stream.push(null);
    stream.pipe(res);
  } catch (err) {
    return fail(res, 500, err.message);
  }
});

export default router;
