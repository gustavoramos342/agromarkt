require('dotenv').config();

const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const authRoutes = require('./routes/auth_routes');
const profileRoutes = require('./routes/profile_routes');
const productRoutes = require('./routes/product_routes');

const app = express();

app.disable('x-powered-by');
app.use(helmet());

const allowedOrigins = (process.env.CORS_ORIGIN || '')
  .split(',')
  .map((origin) => origin.trim())
  .filter(Boolean);

app.use(
  cors({
    origin(origin, callback) {
      if (!origin || allowedOrigins.includes(origin)) {
        return callback(null, true);
      }

      return callback(new Error('Origem não autorizada pelo CORS.'));
    },
  }),
);

app.use(express.json({ limit: '10kb' }));

app.get('/api/health', (req, res) => {
  res.status(200).json({
    status: 'ok',
    message: 'API do AgroMarkt funcionando!',
  });
});

app.use('/api/auth', authRoutes);
app.use('/api/profile', profileRoutes);
app.use('/api/products', productRoutes);

app.use((req, res) => {
  res.status(404).json({
    error: 'Rota não encontrada.',
  });
});

app.use((err, req, res, next) => {
  if (err.message === 'Origem não autorizada pelo CORS.') {
    return res.status(403).json({
      error: 'Origem não autorizada.',
    });
  }

  console.error(err);

  return res.status(500).json({
    error: 'Erro interno do servidor.',
  });
});

const port = Number(process.env.PORT) || 3000;

app.listen(port, '0.0.0.0', () => {
  console.log(`AgroMarkt API iniciada na porta ${port}`);
});
