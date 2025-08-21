import mongoose from 'mongoose';

const InvoiceItemSchema = new mongoose.Schema({
  description: { type: String },
  hsn: { type: String },
  quantity: { type: Number, default: 0 },
  unitPrice: { type: Number, default: 0 },
  gst: { type: Number, default: 0 },
  discount: { type: Number, default: 0 },
  amount: { type: Number, default: 0 }
}, { _id: false });

const BillToSchema = new mongoose.Schema({
  name: String,
  email: String,
  address: String,
  state: String,
  gst: String,
  pan: String,
  phone: String
}, { _id: false });

const InvoiceSchema = new mongoose.Schema({
  user: { type: mongoose.Types.ObjectId, required: true, ref: 'User' },
  invoiceNumber: { type: String, required: true },
  date: { type: Date, required: true, default: Date.now },
  dueDate: { type: Date },
  billTo: BillToSchema,
  shipTo: { type: Object },
  items: { type: [InvoiceItemSchema], default: [] },
  notes: String,
  currency: { type: String, default: 'INR' },
  status: { type: String, default: 'draft' },
  subtotal: { type: Number, default: 0 },
  cgst: { type: Number, default: 0 },
  sgst: { type: Number, default: 0 },
  igst: { type: Number, default: 0 },
  total: { type: Number, default: 0 },
  termsAndConditions: String,
  createdAt: { type: Date, default: Date.now },
  updatedAt: { type: Date, default: Date.now }
});

InvoiceSchema.pre('save', function (next) {
  this.updatedAt = new Date();
  next();
});

export default mongoose.model('Invoice', InvoiceSchema);