import mongoose from 'mongoose';
const schema = new mongoose.Schema({
  period: String,
  amount: Number,
  collectedOn: Date
}, { timestamps: true });
export default mongoose.model('TaxRecord', schema);