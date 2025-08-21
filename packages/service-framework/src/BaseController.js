import { Router } from 'express';

/**
 * Base controller class with common CRUD operations
 */
export class BaseController {
  constructor(Model, options = {}) {
    this.Model = Model;
    this.options = {
      userField: 'user', // field name for user association
      allowPublicRead: false,
      enableSoftDelete: false,
      searchFields: [], // fields to search in list operation
      populateFields: [], // fields to populate
      defaultLimit: 10,
      maxLimit: 100,
      ...options
    };
  }

  /**
   * Create a new document
   */
  create = async (req, res, next) => {
    try {
      const { ok, created, fail } = await import('@invoice/common');
      const payload = { ...req.body };
      
      // Add user association if authenticated
      if (req.user && this.options.userField) {
        payload[this.options.userField] = req.user.id;
      }

      // Validate required fields
      if (this.options.validateCreate) {
        const validation = await this.options.validateCreate(payload);
        if (!validation.valid) {
          return fail(res, 400, validation.message);
        }
      }

      const doc = await this.Model.create(payload);
      const response = { id: doc._id };
      
      if (this.options.createResponse) {
        Object.assign(response, this.options.createResponse(doc));
      }

      return created(res, response);
    } catch (error) {
      if (error.code === 11000) {
        const field = Object.keys(error.keyPattern)[0];
        return next(new Error(`${field} already exists`));
      }
      next(error);
    }
  };

  /**
   * List documents with pagination and search
   */
  list = async (req, res, next) => {
    try {
      const { ok, buildPagination, formatPaginationResponse } = await import('@invoice/common');
      
      const pagination = buildPagination(req, this.options.defaultLimit, this.options.maxLimit);
      const query = this.buildQuery(req);
      
      // Add search functionality
      if (req.query.search && this.options.searchFields.length > 0) {
        const searchRegex = new RegExp(req.query.search, 'i');
        query.$or = this.options.searchFields.map(field => ({
          [field]: searchRegex
        }));
      }

      // Handle soft delete
      if (this.options.enableSoftDelete && req.query.includeDeleted !== 'true') {
        query.deletedAt = { $exists: false };
      }

      const total = await this.Model.countDocuments(query);
      
      let queryBuilder = this.Model.find(query)
        .sort(this.options.defaultSort || { createdAt: -1 })
        .skip(pagination.skip)
        .limit(pagination.limit);

      // Populate fields if specified
      if (this.options.populateFields.length > 0) {
        this.options.populateFields.forEach(field => {
          queryBuilder = queryBuilder.populate(field);
        });
      }

      const docs = await queryBuilder.lean();

      return ok(res, formatPaginationResponse(docs, pagination, total));
    } catch (error) {
      next(error);
    }
  };

  /**
   * Get a single document by ID
   */
  get = async (req, res, next) => {
    try {
      const { ok, fail, validateObjectId } = await import('@invoice/common');
      const mongoose = await import('mongoose');
      
      const id = req.params.id;
      if (!validateObjectId(id)) {
        return fail(res, 400, 'Invalid ID format');
      }

      const query = { _id: id };
      
      // Add user filter if required
      if (req.user && this.options.userField && !this.options.allowPublicRead) {
        query[this.options.userField] = mongoose.Types.ObjectId(req.user.id);
      }

      // Handle soft delete
      if (this.options.enableSoftDelete) {
        query.deletedAt = { $exists: false };
      }

      let queryBuilder = this.Model.findOne(query);

      // Populate fields if specified
      if (this.options.populateFields.length > 0) {
        this.options.populateFields.forEach(field => {
          queryBuilder = queryBuilder.populate(field);
        });
      }

      const doc = await queryBuilder.lean();
      
      if (!doc) {
        return fail(res, 404, 'Document not found');
      }

      return ok(res, doc);
    } catch (error) {
      next(error);
    }
  };

  /**
   * Update a document by ID
   */
  update = async (req, res, next) => {
    try {
      const { ok, fail, validateObjectId } = await import('@invoice/common');
      const mongoose = await import('mongoose');
      
      const id = req.params.id;
      if (!validateObjectId(id)) {
        return fail(res, 400, 'Invalid ID format');
      }

      const query = { _id: id };
      
      // Add user filter if required
      if (req.user && this.options.userField) {
        query[this.options.userField] = mongoose.Types.ObjectId(req.user.id);
      }

      // Handle soft delete
      if (this.options.enableSoftDelete) {
        query.deletedAt = { $exists: false };
      }

      // Validate update data
      if (this.options.validateUpdate) {
        const validation = await this.options.validateUpdate(req.body);
        if (!validation.valid) {
          return fail(res, 400, validation.message);
        }
      }

      const update = { 
        ...req.body, 
        updatedAt: new Date(),
        updatedBy: req.user?.id
      };

      // Remove fields that shouldn't be updated
      delete update._id;
      delete update.createdAt;
      delete update.createdBy;

      const result = await this.Model.updateOne(query, { $set: update });

      if (result.matchedCount === 0) {
        return fail(res, 404, 'Document not found');
      }

      return ok(res, { updated: true });
    } catch (error) {
      next(error);
    }
  };

  /**
   * Delete a document by ID (soft or hard delete)
   */
  delete = async (req, res, next) => {
    try {
      const { ok, fail, validateObjectId } = await import('@invoice/common');
      const mongoose = await import('mongoose');
      
      const id = req.params.id;
      if (!validateObjectId(id)) {
        return fail(res, 400, 'Invalid ID format');
      }

      const query = { _id: id };
      
      // Add user filter if required
      if (req.user && this.options.userField) {
        query[this.options.userField] = mongoose.Types.ObjectId(req.user.id);
      }

      let result;
      
      if (this.options.enableSoftDelete) {
        // Soft delete
        query.deletedAt = { $exists: false };
        result = await this.Model.updateOne(query, { 
          $set: { 
            deletedAt: new Date(),
            deletedBy: req.user?.id
          }
        });
      } else {
        // Hard delete
        result = await this.Model.deleteOne(query);
      }

      if (result.matchedCount === 0 && result.deletedCount === 0) {
        return fail(res, 404, 'Document not found');
      }

      return ok(res, { deleted: true });
    } catch (error) {
      next(error);
    }
  };

  /**
   * Restore a soft-deleted document
   */
  restore = async (req, res, next) => {
    try {
      const { ok, fail, validateObjectId } = await import('@invoice/common');
      const mongoose = await import('mongoose');
      
      if (!this.options.enableSoftDelete) {
        return fail(res, 400, 'Soft delete is not enabled for this resource');
      }

      const id = req.params.id;
      if (!validateObjectId(id)) {
        return fail(res, 400, 'Invalid ID format');
      }

      const query = { 
        _id: id,
        deletedAt: { $exists: true }
      };
      
      // Add user filter if required
      if (req.user && this.options.userField) {
        query[this.options.userField] = mongoose.Types.ObjectId(req.user.id);
      }

      const result = await this.Model.updateOne(query, { 
        $unset: { 
          deletedAt: 1,
          deletedBy: 1
        },
        $set: {
          updatedAt: new Date(),
          updatedBy: req.user?.id
        }
      });

      if (result.matchedCount === 0) {
        return fail(res, 404, 'Deleted document not found');
      }

      return ok(res, { restored: true });
    } catch (error) {
      next(error);
    }
  };

  /**
   * Build query based on request parameters and user context
   */
  buildQuery(req) {
    const mongoose = require('mongoose');
    const query = {};

    // Add user filter if authenticated and required
    if (req.user && this.options.userField && !this.options.allowPublicRead) {
      query[this.options.userField] = mongoose.Types.ObjectId(req.user.id);
    }

    // Add custom filters from options
    if (this.options.buildQuery) {
      return this.options.buildQuery(req, query);
    }

    return query;
  }

  /**
   * Create router with standard CRUD routes
   */
  createRouter(resourceName = '') {
    const router = Router();
    
    router.post(`/${resourceName}`, this.create);
    router.get(`/${resourceName}`, this.list);
    router.get(`/${resourceName}/:id`, this.get);
    router.put(`/${resourceName}/:id`, this.update);
    router.patch(`/${resourceName}/:id`, this.update);
    router.delete(`/${resourceName}/:id`, this.delete);

    // Add restore route for soft delete
    if (this.options.enableSoftDelete) {
      router.post(`/${resourceName}/:id/restore`, this.restore);
    }

    return router;
  }
}

export default BaseController;
