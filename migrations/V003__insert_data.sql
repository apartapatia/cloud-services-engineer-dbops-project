ALTER TABLE public.order_product DROP CONSTRAINT IF EXISTS fk_order_product_order_id;
ALTER TABLE public.order_product DROP CONSTRAINT IF EXISTS fk_order_product_product_id;

INSERT INTO public.product (id, name, price, picture_url)
VALUES
  (1, 'Сливочная', 320.00, 'https://res.cloudinary.com/sugrobov/image/upload/v1623323635/repos/sausages/6.jpg'),
  (2, 'Особая', 179.00, 'https://res.cloudinary.com/sugrobov/image/upload/v1623323635/repos/sausages/5.jpg'),
  (3, 'Молочная', 225.00, 'https://res.cloudinary.com/sugrobov/image/upload/v1623323635/repos/sausages/4.jpg'),
  (4, 'Нюренбергская', 315.00, 'https://res.cloudinary.com/sugrobov/image/upload/v1623323635/repos/sausages/3.jpg'),
  (5, 'Мюнхенская', 330.00, 'https://res.cloudinary.com/sugrobov/image/upload/v1623323635/repos/sausages/2.jpg'),
  (6, 'Русская', 189.00, 'https://res.cloudinary.com/sugrobov/image/upload/v1623323635/repos/sausages/1.jpg');

INSERT INTO public.orders (id, date_created, status)
SELECT
    i,
    (CURRENT_DATE - (floor(random() * 90))::int),
    (ARRAY['pending', 'shipped', 'cancelled'])[1 + floor(random() * 3)::int]
FROM generate_series(1, 10000000) s(i);

INSERT INTO public.order_product (quantity, order_id, product_id)
SELECT
    floor(1+random()*50)::int,
    i,
    1 + floor(random()*6)::int % 6
FROM generate_series(1, 10000000) s(i);

ALTER TABLE public.order_product
    ADD CONSTRAINT fk_order_product_order_id
    FOREIGN KEY (order_id) REFERENCES public.orders (id);

ALTER TABLE public.order_product
    ADD CONSTRAINT fk_order_product_product_id
    FOREIGN KEY (product_id) REFERENCES public.product (id);

SELECT setval('public.product_id_seq', (SELECT MAX(id) FROM public.product));
SELECT setval('public.orders_id_seq', (SELECT MAX(id) FROM public.orders));