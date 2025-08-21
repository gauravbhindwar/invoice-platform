import mongoose from 'mongoose';

const ItemSchema = new mongoose.Schema({
  id: { type: String, index: true },
  userId: { type: mongoose.Types.ObjectId, required: true, ref: 'User' },
  productName: { type: String, required: true },
  category: String,
  unitPrice: { type: Number, default: 0 },
  inStock: { type: Number, default: 0 },
  discount: { type: Number, default: 0 },
  image: String,
  note: String,
  vendor: String,
  vendorProductCode: String,
  createdAt: { type: Date, default: Date.now }
});

export default mongoose.model('Item', ItemSchema);
