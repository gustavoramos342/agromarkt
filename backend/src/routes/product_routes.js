
const express = require('express');
const { pool } = require('../config/database');
const {
  authenticateToken,
  authorizeRoles,
} = require('../middleware/auth_middleware');

const router = express.Router();

const allowedUnits = ['kg', 'L', 'unidade'];

// Valida os dados enviados pelo fornecedor.
function validateProduct(data) {
  const {
    name,
    category,
    unit,
    price,
    location = '',
  } = data || {};

  if (
    typeof name !== 'string' ||
    !name.trim() ||
    name.trim().length > 180 ||
    typeof category !== 'string' ||
    !category.trim() ||
    category.trim().length > 80 ||
    typeof unit !== 'string' ||
    !allowedUnits.includes(unit) ||
    typeof location !== 'string' ||
    location.trim().length > 180
  ) {
    return {
      error: 'Dados inválidos. Confira nome, categoria, unidade e localização.',
    };
  }

  const numericPrice =
    typeof price === 'number' || typeof price === 'string'
      ? Number(price)
      : NaN;

  if (
    !Number.isFinite(numericPrice) ||
    numericPrice < 0 ||
    !/^\d+(\.\d{1,2})?$/.test(String(price).trim())
  ) {
    return {
      error: 'O preço deve ser um número não negativo com até duas casas decimais.',
    };
  }

  return {
    value: {
      name: name.trim(),
      category: category.trim(),
      unit,
      price: numericPrice,
      location: location.trim(),
    },
  };
}

// Lista pública de produtos ativos.
router.get('/', async (req, res, next) => {
  try {
    const query = String(req.query.q || '').trim();

    const result = await pool.query(
      `
      SELECT
        p.id,
        p.name,
        p.category,
        p.unit,
        p.price,
        u.name AS supplier,
        p.location
      FROM products p
      INNER JOIN users u ON u.id = p.supplier_id
      WHERE p.is_active = TRUE
        AND u.is_active = TRUE
        AND u.role = 'fornecedor'
        AND (
          $1 = ''
          OR p.name ILIKE '%' || $1 || '%'
          OR p.category ILIKE '%' || $1 || '%'
          OR u.name ILIKE '%' || $1 || '%'
          OR p.location ILIKE '%' || $1 || '%'
        )
      ORDER BY p.name ASC
      LIMIT 100
      `,
      [query],
    );

    return res.status(200).json({
      products: result.rows.map((product) => ({
        ...product,
        id: Number(product.id),
        price: Number(product.price),
      })),
    });
  } catch (error) {
    return next(error);
  }
});

// Lista as ofertas do fornecedor autenticado.
router.get(
  '/mine',
  authenticateToken,
  authorizeRoles('fornecedor'),
  async (req, res, next) => {
    try {
      const result = await pool.query(
        `
        SELECT
          id,
          name,
          category,
          unit,
          price,
          location,
          created_at,
          updated_at
        FROM products
        WHERE supplier_id = $1
          AND is_active = TRUE
        ORDER BY created_at DESC
        `,
        [req.user.id],
      );

      return res.status(200).json({
        products: result.rows.map((product) => ({
          ...product,
          id: Number(product.id),
          price: Number(product.price),
        })),
      });
    } catch (error) {
      return next(error);
    }
  },
);

// Cadastra uma nova oferta.
router.post(
  '/',
  authenticateToken,
  authorizeRoles('fornecedor'),
  async (req, res, next) => {
    try {
      const validation = validateProduct(req.body);

      if (validation.error) {
        return res.status(400).json({
          error: validation.error,
        });
      }

      const {
        name,
        category,
        unit,
        price,
        location,
      } = validation.value;

      const result = await pool.query(
        `
        INSERT INTO products
          (name, category, unit, price, supplier_id, location)
        VALUES ($1, $2, $3, $4, $5, $6)
        RETURNING id, name, category, unit, price, location
        `,
        [
          name,
          category,
          unit,
          price,
          req.user.id,
          location,
        ],
      );

      const product = result.rows[0];

      return res.status(201).json({
        message: 'Produto cadastrado com sucesso.',
        product: {
          ...product,
          id: Number(product.id),
          price: Number(product.price),
        },
      });
    } catch (error) {
      return next(error);
    }
  },
);

// Edita uma oferta pertencente ao fornecedor autenticado.
router.put(
  '/:id',
  authenticateToken,
  authorizeRoles('fornecedor'),
  async (req, res, next) => {
    try {
      const id = req.params.id;

      if (!/^\d+$/.test(id) || Number(id) < 1) {
        return res.status(400).json({
          error: 'ID do produto inválido.',
        });
      }

      const validation = validateProduct(req.body);

      if (validation.error) {
        return res.status(400).json({
          error: validation.error,
        });
      }

      const {
        name,
        category,
        unit,
        price,
        location,
      } = validation.value;

      const result = await pool.query(
        `
        UPDATE products
        SET
          name = $1,
          category = $2,
          unit = $3,
          price = $4,
          location = $5,
          updated_at = NOW()
        WHERE id = $6
          AND supplier_id = $7
          AND is_active = TRUE
        RETURNING id, name, category, unit, price, location
        `,
        [
          name,
          category,
          unit,
          price,
          location,
          id,
          req.user.id,
        ],
      );

      if (result.rowCount === 0) {
        return res.status(404).json({
          error: 'Produto não encontrado ou sem permissão para editá-lo.',
        });
      }

      const product = result.rows[0];

      return res.status(200).json({
        message: 'Produto atualizado com sucesso.',
        product: {
          ...product,
          id: Number(product.id),
          price: Number(product.price),
        },
      });
    } catch (error) {
      return next(error);
    }
  },
);

// Exclui logicamente (desativa) uma oferta do fornecedor autenticado.
router.delete(
  '/:id',
  authenticateToken,
  authorizeRoles('fornecedor'),
  async (req, res, next) => {
    try {
      const id = req.params.id;

      if (!/^\d+$/.test(id) || Number(id) < 1) {
        return res.status(400).json({
          error: 'ID do produto inválido.',
        });
      }

      const result = await pool.query(
        `
        UPDATE products
        SET
          is_active = FALSE,
          updated_at = NOW()
        WHERE id = $1
          AND supplier_id = $2
          AND is_active = TRUE
        RETURNING id
        `,
        [id, req.user.id],
      );

      if (result.rowCount === 0) {
        return res.status(404).json({
          error: 'Produto não encontrado ou sem permissão para excluí-lo.',
        });
      }

      return res.status(200).json({
        message: 'Produto desativado com sucesso.',
      });
    } catch (error) {
      return next(error);
    }
  },
);

module.exports = router;
