import Joi from 'joi';

export const envValidationSchema = Joi.object({
  NODE_ENV: Joi.string()
    .valid('development', 'production', 'test')
    .default('development'),
  PORT: Joi.number().default(3000),
  CORS_ORIGINS: Joi.string().default('*'),

  DB_TYPE: Joi.string().valid('postgres', 'sqlite').default('postgres'),
  DB_HOST: Joi.string().default('localhost'),
  DB_PORT: Joi.number().default(5432),
  DB_USERNAME: Joi.string().default('postgres'),
  DB_PASSWORD: Joi.string().allow('').default(''),
  DB_NAME: Joi.string().default('essentially'),
  DB_SQLITE_PATH: Joi.string().default('data/essentially.sqlite'),
  DB_SYNCHRONIZE: Joi.boolean().default(true),
  DB_LOGGING: Joi.boolean().default(false),

  JWT_SECRET: Joi.string().min(16).required(),
  JWT_EXPIRES_IN: Joi.string().default('7d'),

  ADMIN_EMAIL: Joi.string().email().default('admin@essentially.app'),
  // Optional: the admin account is only bootstrapped when a password is set.
  ADMIN_PASSWORD: Joi.string().min(8).allow(''),
  ADMIN_NAME: Joi.string().default('Admin Team'),
});
