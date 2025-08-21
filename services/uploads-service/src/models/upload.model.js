import mongoose from 'mongoose';

const UploadSchema = new mongoose.Schema({
  userId: { type: mongoose.Types.ObjectId, ref: 'User' },
  filename: String,
  contentType: String,
  size: Number,
  path: String,
  createdAt: { type: Date, default: Date.now }
});

export default mongoose.model('Upload', UploadSchema);