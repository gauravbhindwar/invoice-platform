import { Router } from 'express';
import { BaseController } from '@invoice/service-framework';
import Customer from '../models/customer.model.js';

const router = Router();

// Create enhanced controller for customers
const customerController = new BaseController(Customer, {
  userField: 'userId',
  defaultSort: { createdAt: -1 },
  searchFields: ['name', 'email', 'company'],
  enableSoftDelete: false,
  validateCreate: async (data) => {
    if (!data.name) {
      return { valid: false, message: 'Customer name is required' };
    }
    if (!data.email) {
      return { valid: false, message: 'Customer email is required' };
    }
    return { valid: true };
  }
});

// Use standard CRUD routes
router.use('/', customerController.createRouter('customers'));

export default router;
