# Portfolio 2 — Query Processing and Optimisation

## Dataset
(Table sizes after 01_bulk_data.sql; why a large dataset is needed.)

## How PostgreSQL processes a query
(Parse → rewrite → plan/optimise (cost-based, uses statistics) → execute. 3–4 sentences.)

## Queries
(For each Q1–Q6: the business question, the SQL, a result screenshot.)

## Method
1. Ran 02_explain_queries.sql → plans/before.txt (second, warm-cache run)
2. Ran 03_indexes.sql (+ ANALYZE)
3. Ran 02_explain_queries.sql → plans/after.txt

## Results
(Your before/after table, with YOUR numbers.)

## Analysis
(Q2 GiST vs B-tree, Q4 bottleneck moved, Q6 selectivity. Composite index column order.)

## Cost of indexing
(Index sizes from 03_indexes.sql; indexes slow INSERT/UPDATE because each index must
also be updated — e.g. every new booking now updates 5 indexes.)