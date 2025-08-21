import mongoose from 'mongoose';

const UserSchema = new mongoose.Schema({
  email: { 
    type: String, 
    required: true, 
    unique: true, 
    lowercase: true,
    trim: true
  },
  password: { 
    type: String, 
    required: true,
    minlength: 6
  },
  firstName: { 
    type: String, 
    required: true,
    trim: true
  },
  lastName: { 
    type: String, 
    required: true,
    trim: true
  },
  name: { 
    type: String,
    trim: true
  },
  role: {
    type: String,
    enum: ['admin', 'user', 'manager'],
    default: 'user'
  },
  company: { 
    type: String,
    trim: true
  },
  address: { 
    type: String,
    trim: true
  },
  gstNumber: { 
    type: String,
    trim: true
  },
  panNumber: { 
    type: String,
    trim: true
  },
  phone: { 
    type: String,
    trim: true
  },
  website: { 
    type: String,
    trim: true
  },
  state: { 
    type: String,
    trim: true
  },
  isActive: {
    type: Boolean,
    default: true
  },
  emailVerified: {
    type: Boolean,
    default: false
  },
  lastLogin: {
    type: Date
  },
  createdAt: { 
    type: Date, 
    default: Date.now 
  },
  updatedAt: { 
    type: Date, 
    default: Date.now 
  }
}, {
  timestamps: true
});

// Index for faster email lookups
UserSchema.index({ email: 1 });

// Pre-save middleware to update name field
UserSchema.pre('save', function(next) {
  if (this.firstName && this.lastName) {
    this.name = `${this.firstName} ${this.lastName}`;
  }
  this.updatedAt = new Date();
  next();
});

export default mongoose.model('User', UserSchema);