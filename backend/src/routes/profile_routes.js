const express = require('express');
const {
  authenticateToken,
  authorizeRoles,
} = require('../middleware/auth_middleware');

const router = express.Router();

router.get(
  '/produtor',
  authenticateToken,
  authorizeRoles('produtor'),
  (req, res) => {
    res.status(200).json({
      message: 'Acesso autorizado à área do produtor.',
      role: req.user.role,
    });
  },
);

router.get(
  '/fornecedor',
  authenticateToken,
  authorizeRoles('fornecedor'),
  (req, res) => {
    res.status(200).json({
      message: 'Acesso autorizado à área do fornecedor.',
      role: req.user.role,
    });
  },
);

router.get(
  '/admin',
  authenticateToken,
  authorizeRoles('admin'),
  (req, res) => {
    res.status(200).json({
      message: 'Acesso autorizado à área administrativa.',
      role: req.user.role,
    });
  },
);

module.exports = router;
