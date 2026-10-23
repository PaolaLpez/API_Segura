'use strict';
const express = require('express');
const { requireAuth } = require('../middleware/auth.middleware');
const { validate } = require('../middleware/validate.middleware');
const {
  createTaskSchema,
  updateTaskSchema,
  listTasksSchema,
} = require('../schemas/task.schema');
const { TaskService } = require('../services/task.service');

const router = express.Router();
const service = new TaskService();

/**
 * Wraps an async route handler and forwards failures to Express error handling.
 *
 * @param {Function} handler - Async Express route handler.
 * @returns {import('express').RequestHandler} Wrapped handler.
 */
const asyncRoute = (handler) => (req, res, next) =>
  Promise.resolve(handler(req, res, next)).catch(next);

router.use(requireAuth);

router.get('/', validate(listTasksSchema, 'query'), asyncRoute(async (req, res) => {
  res.json(await service.list(req.user.id, req.query));
}));

router.post('/', validate(createTaskSchema, 'body'), asyncRoute(async (req, res) => {
  const task = await service.create(req.user.id, req.body);
  res.status(201).json({ item: task });
}));

router.patch('/:taskId', validate(updateTaskSchema, 'body'), asyncRoute(async (req, res) => {
  const item = await service.update(req.user.id, req.params.taskId, req.body);
  res.json({ item });
}));

router.delete('/:taskId', asyncRoute(async (req, res) => {
  await service.delete(req.user.id, req.params.taskId);
  res.status(204).end();
}));

module.exports = router;
