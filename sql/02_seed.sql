INSERT INTO customers(full_name, email, created_at) VALUES
('Ada Lovelace', 'ada@example.com', now() - interval '60 days'),
('Grace Hopper', 'grace@example.com', now() - interval '45 days'),
('Alan Turing', 'alan@example.com', now() - interval '30 days'),
('Margaret Hamilton', 'margaret@example.com', now() - interval '10 days');

-- a handful of payments across different dates/statuses/providers
INSERT INTO payments(customer_id, provider, amount_pence, currency, status, created_at) VALUES
(1, 'card',    1299, 'GBP', 'captured',   now() - interval '20 days'),
(1, 'paypal',  2599, 'GBP', 'captured',   now() - interval '15 days'),
(2, 'card',     499, 'GBP', 'failed',     now() - interval '14 days'),
(2, 'klarna',  4999, 'GBP', 'authorised', now() - interval '13 days'),
(3, 'card',    1999, 'GBP', 'refunded',   now() - interval '12 days'),
(3, 'card',    3499, 'GBP', 'captured',   now() - interval '7 days'),
(4, 'paypal',  1599, 'GBP', 'captured',   now() - interval '2 days');
