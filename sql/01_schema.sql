CREATE TABLE customers (
  customer_id  SERIAL PRIMARY KEY,
  full_name    TEXT NOT NULL,
  email        TEXT UNIQUE NOT NULL,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE payments (
  payment_id    SERIAL PRIMARY KEY,
  customer_id   INTEGER NOT NULL REFERENCES customers(customer_id),
  provider      TEXT NOT NULL,           -- e.g. card, paypal, klarna
  amount_pence  INTEGER NOT NULL CHECK (amount_pence >= 0),
  currency      CHAR(3) NOT NULL DEFAULT 'GBP',
  status        TEXT NOT NULL,           -- authorised, captured, refunded, failed
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_payments_created_at ON payments(created_at);
CREATE INDEX idx_payments_status ON payments(status);
CREATE INDEX idx_payments_customer_id ON payments(customer_id);
