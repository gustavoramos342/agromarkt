require('dotenv').config();

const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const { rateLimit } = require('express-rate-limit');
const authRoutes = require('./routes/auth_routes');
const profileRoutes = require('./routes/profile_routes');
const productRoutes = require('./routes/product_routes');
const quoteRoutes = require('./routes/quote_routes');

const app = express();
const loginLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  limit: 5,
  standardHeaders: 'draft-8',
  legacyHeaders: false,
  message: {
    error: 'Muitas tentativas de login. Tente novamente em 15 minutos.',
  },
});

app.disable('x-powered-by');
app.use('/api/auth/login', loginLimiter);
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
app.use('/api/quotes', quoteRoutes);

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

  if (err.type === 'entity.parse.failed') {
    return res.status(400).json({
      error: 'O JSON enviado é inválido.',
    });
  }

  if (err.type === 'entity.too.large') {
    return res.status(413).json({
      error: 'O conteúdo enviado excede o limite permitido.',
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
