import mongoose from 'mongoose';

const AddressSchema = new mongoose.Schema({
  address1: String,
  address2: String,
  city: String,
  state: String,
  pincode: String,
  country: String
}, { _id: false });

const CustomerSchema = new mongoose.Schema({
  userId: { type: mongoose.Types.ObjectId, required: true, ref: 'User' },
  fullName: String,
  email: String,
  phone: String,
  companyName: String,
  website: String,
  billingAddress: AddressSchema,
  shippingAddress: AddressSchema,
  sameAsBilling: { type: Boolean, default: true },
  panNumber: String,
  isGstRegistered: Boolean,
  gstNumber: String,
  placeOfSupply: String,
  currency: String,
  paymentTerms: String,
  notes: String,
  tags: [String],
  createdAt: { type: Date, default: Date.now }
});

export default mongoose.model('Customer', CustomerSchema);