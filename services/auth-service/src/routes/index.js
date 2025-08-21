import { Router } from 'express';
import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import { ok, created, fail } from '../../../../packages/common/src/index.js';
import User from '../models/user.model.js';

const r = Router();

r.post('/register', async (req, res) => {
  try {
    const { email, password, firstName, lastName, role = 'user', company, phone } = req.body;
    
    // Validation
    if (!email || !password) {
      return fail(res, 400, 'Email and password are required');
    }
    if (!firstName || !lastName) {
      return fail(res, 400, 'First name and last name are required');
    }
    if (password.length < 6) {
      return fail(res, 400, 'Password must be at least 6 characters long');
    }
    
    // Email format validation
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailRegex.test(email)) {
      return fail(res, 400, 'Invalid email format');
    }
    
    // Check if user already exists
    const existing = await User.findOne({ email: email.toLowerCase() });
    if (existing) {
      return fail(res, 409, 'User with this email already exists');
    }
    
    // Hash password
    const saltRounds = 12;
    const hashedPassword = await bcrypt.hash(password, saltRounds);
    
    // Create user
    const userData = {
      email: email.toLowerCase(),
      password: hashedPassword,
      name: `${firstName} ${lastName}`,
      firstName,
      lastName,
      role,
      company,
      phone,
      createdAt: new Date()
    };
    
    const user = await User.create(userData);
    
    // Generate JWT token
    const token = jwt.sign(
      { 
        userId: user._id, 
        email: user.email,
        role: user.role 
      },
      process.env.JWT_SECRET || 'your-secret-key',
      { expiresIn: '24h' }
    );
    
    // Generate refresh token
    const refreshToken = jwt.sign(
      { userId: user._id },
      process.env.JWT_REFRESH_SECRET || 'your-refresh-secret',
      { expiresIn: '7d' }
    );
    
    // Return success response with token
    return created(res, {
      message: 'User registered successfully',
      token,
      refreshToken,
      expiresIn: 86400, // 24 hours in seconds
      user: {
        id: user._id,
        email: user.email,
        name: user.name,
        firstName: user.firstName,
        lastName: user.lastName,
        role: user.role,
        company: user.company,
        phone: user.phone
      }
    });
    
  } catch (err) {
    console.error('Registration error:', err);
    return fail(res, 500, 'Internal server error during registration');
  }
});

r.post('/login', async (req, res) => {
  try {
    const { email, password } = req.body;
    if (!email || !password) return fail(res, 400, 'Email and password required');
    const user = await User.findOne({ email: email.toLowerCase() });
    if (!user) return fail(res, 401, 'Invalid credentials');
    const okPw = await bcrypt.compare(password, user.password);
    if (!okPw) return fail(res, 401, 'Invalid credentials');
    const token = jwt.sign({ _id: String(user._id), email: user.email }, process.env.JWT_SECRET || 'changeme', { expiresIn: '7d' });
    return ok(res, { token });
  } catch (err) {
    return fail(res, 500, err.message);
  }
});

r.get('/me', async (req, res) => {
  try {
    const auth = req.headers.authorization || '';
    if (!auth.startsWith('Bearer ')) return fail(res, 401, 'Missing token');
    const token = auth.slice(7);
    const payload = jwt.verify(token, process.env.JWT_SECRET || 'changeme');
    const user = await User.findById(payload._id).lean();
    if (!user) return fail(res, 404, 'User not found');
    delete user.password;
    return ok(res, user);
  } catch (err) {
    return fail(res, 401, 'Invalid token');
  }
});

export default r;