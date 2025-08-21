import mongoose from 'mongoose';

const ExpenseItemSchema = new mongoose.Schema({
  description: String,
  hsn: String,
  quantity: Number,
  price: Number,
  gst: Number,
  discount: Number,
  total: Number
}, { _id: false });

const ExpenseSchema = new mongoose.Schema({
  userId: { type: mongoose.Types.ObjectId, required: true, ref: 'User' },
  invoiceNumber: String,
  date: { type: Date, default: Date.now },
  dueDate: Date,
  currency: String,
  status: String,
  billFrom: { type: Object },
  billTo: { type: Object },
  items: { type: [ExpenseItemSchema], default: [] },
  subtotal: Number,
  cgst: Number,
  sgst: Number,
  igst: Number,
  total: Number,
  createdAt: { type: Date, default: Date.now }
});

export default mongoose.model('Expense', ExpenseSchema);