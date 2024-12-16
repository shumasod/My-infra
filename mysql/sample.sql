INSERT INTO people (first_name, last_name, gender, title)
WITH cte AS (
  SELECT 
    CONCAT(
      CASE 
        WHEN RAND() < 0.5 THEN 'Mr.'
        ELSE 'Ms.'
      END,
      ' ',
      SUBSTRING(NAME, 1, INSTR(NAME, ' ') - 1),
      ' ',
      SUBSTRING(NAME, INSTR(NAME, ' ') + 1)
    ) AS full_name,
    CASE
      WHEN RAND() < 0.5 THEN 'M'
      ELSE 'F'
    END AS gender
  FROM
    (SELECT NAME FROM (VALUES
      ('John Doe'), ('Jane Smith'), ('Michael Johnson'), ('Emily Williams'), 
      ('David Brown'), ('Sarah Davis'), ('Christopher Miller'), ('Ashley Wilson'),
      ('Daniel Moore'), ('Sophia Taylor'), ('Matthew Anderson'), ('Olivia Thomas'),
      ('Joshua Jackson'), ('Emma Roberts'), ('Andrew Lee'), ('Ava Martinez'),
      ('Joseph Hernandez'), ('Isabella Rodriguez'), ('Ryan Gonzalez'), ('Mia Perez')
    ) AS names) AS name_list
  CROSS JOIN
    (SELECT 1 AS n UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4 UNION ALL 
     SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL
     SELECT 9 UNION ALL SELECT 10 UNION ALL SELECT 11 UNION ALL SELECT 12 UNION ALL
     SELECT 13 UNION ALL SELECT 14 UNION ALL SELECT 15 UNION ALL SELECT 16 UNION ALL
     SELECT 17 UNION ALL SELECT 18 UNION ALL SELECT 19 UNION ALL SELECT 20 UNION ALL
     SELECT 21 UNION ALL SELECT 22 UNION ALL SELECT 23 UNION ALL SELECT 24 UNION ALL
     SELECT 25 UNION ALL SELECT 26 UNION ALL SELECT 27 UNION ALL SELECT 28 UNION ALL
     SELECT 29 UNION ALL SELECT 30 UNION ALL SELECT 31 UNION ALL SELECT 32 UNION ALL
     SELECT 33 UNION ALL SELECT 34 UNION ALL SELECT 35 UNION ALL SELECT 36 UNION ALL
     SELECT 37 UNION ALL SELECT 38 UNION ALL SELECT 39 UNION ALL SELECT 40 UNION ALL
     SELECT 41 UNION ALL SELECT 42 UNION ALL SELECT 43 UNION ALL SELECT 44 UNION ALL
     SELECT 45 UNION ALL SELECT 46 UNION ALL SELECT 47 UNION ALL SELECT 48 UNION ALL
     SELECT 49 UNION ALL SELECT 50) AS nums
)
SELECT 
  SUBSTRING(full_name, INSTR(full_name, ' ') + 1, INSTR(full_name, ' ', -1) - INSTR(full_name, ' ') - 1) AS first_name,
  SUBSTRING(full_name, INSTR(full_name, ' ', -1) + 1) AS last_name,
  gender,
  SUBSTRING(full_name, 1, INSTR(full_name, ' ') - 1) AS title
FROM cte
LIMIT 100000;