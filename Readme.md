# Отчет по проекту курса DBOps

В данной документации представлен анализ производительности запроса к базе данных до и после внедрения индексов.

## Подготовка базы данных
Первичная настройка базы данных, создание пользователя и выдача прав:

```sql
CREATE USER store_database_user WITH PASSWORD '<pass>';
CREATE DATABASE store OWNER store_database_user;
GRANT ALL ON SCHEMA public TO store_database_user;
```

---

## Анализируемый запрос
Запрос собирает статистику по количеству проданных товаров за последние 7 дней для отправленных заказов:

```sql
SELECT o.date_created, SUM(op.quantity)
FROM orders AS o
JOIN order_product AS op ON o.id = op.order_id
WHERE o.status = 'shipped' AND o.date_created > NOW() - INTERVAL '7 DAY'
GROUP BY o.date_created;
```

---

## ДО оптимизации запросов

```sql
SELECT o.date_created, SUM(op.quantity)
FROM orders AS o
JOIN order_product AS op ON o.id = op.order_id
WHERE o.status = 'shipped' AND o.date_created > NOW() - INTERVAL '7 DAY'
GROUP BY o.date_created;
```

```text
 date_created |  sum
--------------+--------
 2026-02-16   | 954262
 2026-02-17   | 947249
 2026-02-18   | 940640
 2026-02-19   | 950250
 2026-02-20   | 951579
 2026-02-21   | 943858
 2026-02-22   | 934544
(7 rows)

Time: 28514.429 ms (00:28.514)
```

### Итог

* **Время выполнения:** `28514.429 ms` (28.5 секунд)

**Анализ запроса**

```text
                                                                             QUERY PLAN
---------------------------------------------------------------------------------------------------------------------------------------------------------------------
 Finalize GroupAggregate  (cost=266166.20..266189.00 rows=90 width=12) (actual time=3576.498..3582.985 rows=7 loops=1)
   Group Key: o.date_created
   ->  Gather Merge  (cost=266166.20..266187.20 rows=180 width=12) (actual time=3576.462..3582.948 rows=21 loops=1)
         Workers Planned: 2
         Workers Launched: 2
         ->  Sort  (cost=265166.18..265166.40 rows=90 width=12) (actual time=3537.204..3537.208 rows=7 loops=3)
               Sort Key: o.date_created
               Sort Method: quicksort  Memory: 25kB
               Worker 0:  Sort Method: quicksort  Memory: 25kB
               Worker 1:  Sort Method: quicksort  Memory: 25kB
               ->  Partial HashAggregate  (cost=265162.36..265163.26 rows=90 width=12) (actual time=3537.174..3537.178 rows=7 loops=3)
                     Group Key: o.date_created
                     Batches: 1  Memory Usage: 24kB
                     Worker 0:  Batches: 1  Memory Usage: 24kB
                     Worker 1:  Batches: 1  Memory Usage: 24kB
                     ->  Parallel Hash Join  (cost=148338.95..264638.11 rows=104849 width=8) (actual time=1498.520..3504.332 rows=86549 loops=3)
                           Hash Cond: (op.order_id = o.id)
                           ->  Parallel Seq Scan on order_product op  (cost=0.00..105361.67 rows=4166667 width=12) (actual time=0.208..569.255 rows=3333333 loops=3)
                           ->  Parallel Hash  (cost=147028.33..147028.33 rows=104849 width=12) (actual time=1496.905..1496.906 rows=86549 loops=3)
                                 Buckets: 262144  Batches: 1  Memory Usage: 14272kB
                                 ->  Parallel Seq Scan on orders o  (cost=0.00..147028.33 rows=104849 width=12) (actual time=18.959..1433.575 rows=86549 loops=3)
                                       Filter: (((status)::text = 'shipped'::text) AND (date_created > (now() - '7 days'::interval)))
                                       Rows Removed by Filter: 3246785
```

---

## ПОСЛЕ оптимизации запросов

Для ускорения фильтрации и джоинов были добавлены следующие индексы:
```sql
CREATE INDEX order_product_order_id_idx ON order_product(order_id);
CREATE INDEX orders_status_date_idx ON orders(status, date_created);
```

### Итог

```sql
SELECT o.date_created, SUM(op.quantity)
FROM orders AS o
JOIN order_product AS op ON o.id = op.order_id
WHERE o.status = 'shipped' AND o.date_created > NOW() - INTERVAL '7 DAY'
GROUP BY o.date_created;
```

```text
 date_created |  sum
--------------+--------
 2026-02-16   | 954262
 2026-02-17   | 947249
 2026-02-18   | 940640
 2026-02-19   | 950250
 2026-02-20   | 951579
 2026-02-21   | 943858
 2026-02-22   | 934544
(7 rows)

Time: 1888.637 ms (00:01.889)
```

* **Время выполнения:** `1888.637 ms` (1.88 секунды)
* **Ускорение:** в **~15 раз**

**Анализ запроса**

```text
                                                                                    QUERY PLAN
----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
 Finalize GroupAggregate  (cost=188377.56..188400.37 rows=90 width=12) (actual time=1737.912..1746.212 rows=7 loops=1)
   Group Key: o.date_created
   ->  Gather Merge  (cost=188377.56..188398.57 rows=180 width=12) (actual time=1737.901..1746.199 rows=21 loops=1)
         Workers Planned: 2
         Workers Launched: 2
         ->  Sort  (cost=187377.54..187377.77 rows=90 width=12) (actual time=1710.005..1710.008 rows=7 loops=3)
               Sort Key: o.date_created
               Sort Method: quicksort  Memory: 25kB
               Worker 0:  Sort Method: quicksort  Memory: 25kB
               Worker 1:  Sort Method: quicksort  Memory: 25kB
               ->  Partial HashAggregate  (cost=187373.72..187374.62 rows=90 width=12) (actual time=1709.983..1709.987 rows=7 loops=3)
                     Group Key: o.date_created
                     Batches: 1  Memory Usage: 24kB
                     Worker 0:  Batches: 1  Memory Usage: 24kB
                     Worker 1:  Batches: 1  Memory Usage: 24kB
                     ->  Parallel Hash Join  (cost=70550.31..186849.47 rows=104849 width=8) (actual time=244.750..1694.980 rows=86549 loops=3)
                           Hash Cond: (op.order_id = o.id)
                           ->  Parallel Seq Scan on order_product op  (cost=0.00..105361.67 rows=4166667 width=12) (actual time=0.027..383.368 rows=3333333 loops=3)
                           ->  Parallel Hash  (cost=69239.69..69239.69 rows=104849 width=12) (actual time=243.772..243.773 rows=86549 loops=3)
                                 Buckets: 262144  Batches: 1  Memory Usage: 14304kB
                                 ->  Parallel Bitmap Heap Scan on orders o  (cost=3447.72..69239.69 rows=104849 width=12) (actual time=26.204..213.864 rows=86549 loops=3)
                                       Recheck Cond: (((status)::text = 'shipped'::text) AND (date_created > (now() - '7 days'::interval)))
                                       Heap Blocks: exact=20077
                                       ->  Bitmap Index Scan on orders_status_date_idx  (cost=0.00..3384.81 rows=251637 width=0) (actual time=31.917..31.918 rows=259646 loops=1)
                                             Index Cond: (((status)::text = 'shipped'::text) AND (date_created > (now() - '7 days'::interval)))
```

---
## Вывод

До оптимизации база данных использовала **Sequential Scan** — полное последовательное чтение строк с жесткого диска, что приводило к нагрузке на CPU и IO.

После добавления индексов планировщик PostgreSQL переключился на механизм **Bitmap Scan**:

1. Сначала с помощью **Bitmap Index Scan** база строит в оперативной памяти bitmap, отмечая только те страницы данных, которые соответствуют фильтру `shipped` за последние 7 дней.
2. Затем через **Bitmap Heap Scan** система за один проход обращается к диску и считывает проиндексированные блоки данных.

В результате время выполнения тяжелого запроса **сократилось в ~15 раз**.