ALTER TABLE public.product
    ADD COLUMN price double precision;

ALTER TABLE public.orders
    ADD COLUMN date_created date;

UPDATE public.product p
SET price = pi.price
FROM public.product_info pi
WHERE p.id = pi.product_id;

UPDATE public.orders o
SET date_created = od.date_created
FROM public.orders_date od
WHERE o.id = od.order_id;

DROP TABLE IF EXISTS public.product_info;

DROP TABLE IF EXISTS public.orders_date;

ALTER TABLE public.product
    ADD CONSTRAINT product_pkey PRIMARY KEY (id);

ALTER TABLE public.orders
    ADD CONSTRAINT orders_pkey PRIMARY KEY (id);

ALTER TABLE public.order_product
    ADD CONSTRAINT fk_order_product_order_id
    FOREIGN KEY (order_id) REFERENCES public.orders (id) NOT VALID;

ALTER TABLE public.order_product
    ADD CONSTRAINT fk_order_product_product_id
    FOREIGN KEY (product_id) REFERENCES public.product (id) NOT VALID;

ALTER TABLE public.order_product
    VALIDATE CONSTRAINT fk_order_product_order_id;

ALTER TABLE public.order_product
    VALIDATE CONSTRAINT fk_order_product_product