
require('dotenv').config();

const { pool } = require('../config/database');

const products = [
  {
    name: 'Fertilizante NPK 04-14-08',
    category: 'Fertilizante NPK',
    unit: 'kg',
    price: 4.50,
    location: 'Cáceres - MT',
  },
  {
    name: 'Fertilizante NPK 20-05-20',
    category: 'Fertilizante NPK',
    unit: 'kg',
    price: 5.20,
    location: 'Cáceres - MT',
  },
  {
    name: 'Fertilizante foliar completo',
    category: 'Fertilizante foliar',
    unit: 'L',
    price: 32.90,
    location: 'Cáceres - MT',
  },
  {
    name: 'Fertilizante foliar com micronutrientes',
    category: 'Fertilizante foliar',
    unit: 'L',
    price: 38.50,
    location: 'Cáceres - MT',
  },
];

async function main() {
  const supplier = await pool.query(
    `SELECT id
     FROM users
     WHERE role = 'fornecedor'
       AND is_active = TRUE
     ORDER BY id
     LIMIT 1`,
  );

  if (supplier.rows.length === 0) {
    throw new Error(
      'Nenhum fornecedor ativo encontrado. Cadastre um fornecedor primeiro.',
    );
  }

  const supplierId = supplier.rows[0].id;
  let inserted = 0;

  for (const product of products) {
    const exists = await pool.query(
      `SELECT id
       FROM products
       WHERE name = $1 AND supplier_id = $2
       LIMIT 1`,
      [product.name, supplierId],
    );

    if (exists.rows.length > 0) {
      console.log(`Já existe: ${product.name}`);
      continue;
    }

    await pool.query(
      `INSERT INTO products
        (name, category, unit, price, supplier_id, location)
       VALUES ($1, $2, $3, $4, $5, $6)`,
      [
        product.name,
        product.category,
        product.unit,
        product.price,
        supplierId,
        product.location,
      ],
    );

    inserted++;
    console.log(`Cadastrado: ${product.name}`);
  }

  console.log(`\nConcluído. Novos produtos cadastrados: ${inserted}`);
}

main()
  .catch((error) => {
    console.error('Erro ao cadastrar produtos:', error.message);
    process.exitCode = 1;
  })
  .finally(async () => {
    await pool.end();
  });
