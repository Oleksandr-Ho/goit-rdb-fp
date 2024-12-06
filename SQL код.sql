-- 1. Завантажте дані: 
-- 1.1	Створіть схему pandemic у базі даних за допомогою SQL-команди.

CREATE SCHEMA IF NOT EXISTS pandemic;

-- 1.2	Оберіть її як схему за замовчуванням за допомогою SQL-команди.

USE pandemic;

-- Імпортую таблиці infectious_cases.csv за допомогою Import wizard
SELECT * FROM infectious_cases;

-- 2. Нормалізуйте таблицю infectious_cases до 3ї нормальної форми. Збережіть у цій же схемі дві таблиці з нормалізованими даними.
-- Зверніть увагу, атрибути Entity та Code постійно повторюються. Позбудьтеся цього за допомогою нормалізації даних.

-- Створення таблиці entities
CREATE TABLE entities (
    entity_id INT AUTO_INCREMENT PRIMARY KEY,
    entity_name VARCHAR(255) NOT NULL,
    code VARCHAR(10) NOT NULL,
    UNIQUE(entity_name, code)
);

-- Наповнення таблиці entities унікальними значеннями Entity і Code
INSERT INTO entities (entity_name, code)
SELECT DISTINCT Entity, Code
FROM infectious_cases;

SELECT * FROM entities;

-- Створення таблиці cases
CREATE TABLE cases (
    case_id INT AUTO_INCREMENT PRIMARY KEY, entity_id INT NOT NULL, year INT, number_yaws INT, polio_cases INT, cases_guinea_worm INT,
    number_rabies FLOAT, number_malaria FLOAT, number_hiv FLOAT, number_tuberculosis FLOAT, number_smallpox INT, number_cholera_cases INT,
    FOREIGN KEY (entity_id) REFERENCES entities(entity_id)
);
-- Наповнення таблиці cases даними
INSERT INTO cases (
    entity_id, year, number_yaws, polio_cases, cases_guinea_worm, number_rabies, number_malaria, 
    number_hiv, number_tuberculosis, number_smallpox, number_cholera_cases
)
SELECT 
    e.entity_id AS entity_id, ic.Year AS year, 
    NULLIF(ic.Number_yaws, '') AS number_yaws,     NULLIF(ic.polio_cases, '') AS polio_cases,     NULLIF(ic.cases_guinea_worm, '') AS cases_guinea_worm, 
    NULLIF(ic.Number_rabies, '') AS number_rabies,     NULLIF(ic.Number_malaria, '') AS number_malaria,     NULLIF(ic.Number_hiv, '') AS number_hiv, 
    NULLIF(ic.Number_tuberculosis, '') AS number_tuberculosis,     NULLIF(ic.Number_smallpox, '') AS number_smallpox,     NULLIF(ic.Number_cholera_cases, '') AS number_cholera_cases
FROM infectious_cases ic
JOIN entities e
ON ic.Entity = e.entity_name AND ic.Code = e.code;

SELECT * FROM cases;

-- 3. Проаналізуйте дані:
-- 	Для кожної унікальної комбінації Entity та Code або їх id порахуйте середнє, мінімальне, максимальне значення та суму для атрибута Number_rabies.
-- Врахуйте, що атрибут Number_rabies може містити порожні значення ‘’ — вам попередньо необхідно їх відфільтрувати.
-- Результат відсортуйте за порахованим середнім значенням у порядку спадання.
-- Оберіть тільки 10 рядків для виведення на екран.*/

SELECT 
    e.entity_name AS Entity,    e.code AS Code,
    COUNT(c.number_rabies) AS Total_Count,     AVG(c.number_rabies) AS Average_Rabies, 
    MIN(c.number_rabies) AS Min_Rabies,     MAX(c.number_rabies) AS Max_Rabies,     SUM(c.number_rabies) AS Total_Rabies 
FROM cases c
JOIN entities e ON c.entity_id = e.entity_id
WHERE c.number_rabies IS NOT NULL -- Враховуємо лише рядки з числовими значеннями
GROUP BY e.entity_name, e.code -- Групуємо за Entity та Code
ORDER BY Average_Rabies DESC
LIMIT 10;

-- 4. Побудуйте колонку різниці в роках.
-- Для оригінальної або нормованої таблиці для колонки Year побудуйте з використанням вбудованих SQL-функцій:
-- 4.1	атрибут, що створює дату першого січня відповідного року. Наприклад, якщо атрибут містить значення ’1996’, то значення нового атрибута має бути ‘1996-01-01’.
-- 4.2	атрибут, що дорівнює поточній даті,
-- 4.3	атрибут, що дорівнює різниці в роках двох вищезгаданих колонок.
-- Перераховувати всі інші атрибути, такі як Number_malaria, не потрібно.
ALTER TABLE cases
ADD COLUMN start_of_year DATE,
ADD COLUMN current_date_column DATE,
ADD COLUMN year_difference INT;

SET SQL_SAFE_UPDATES = 0;
UPDATE cases
SET 
    start_of_year = DATE(CONCAT(year, '-01-01')),
    current_date_column = CURRENT_DATE(),
    year_difference = TIMESTAMPDIFF(YEAR, DATE(CONCAT(year, '-01-01')), CURRENT_DATE())
WHERE year IS NOT NULL;
SET SQL_SAFE_UPDATES = 1;
    
SELECT 
    year,     start_of_year,     current_date,     year_difference
FROM cases;


-- 5. Побудуйте власну функцію.
-- 5.1	Створіть і використайте функцію, що будує такий же атрибут, як і в попередньому завданні: функція має приймати на вхід значення року, 
-- а повертати різницю в роках між поточною датою та датою, створеною з атрибута року (1996 рік → ‘1996-01-01’).

DELIMITER //
CREATE FUNCTION calculate_year_difference_from_date(start_date DATE)
RETURNS INT
DETERMINISTIC
BEGIN
    RETURN TIMESTAMPDIFF(YEAR, start_date, CURDATE());
END //
DELIMITER ;

SELECT 
    start_of_year,
    calculate_year_difference_from_date(start_of_year) AS year_difference
FROM cases;

-- 5.2	Побудуйте функцію — функцію, що рахує кількість захворювань за певний період. Для цього треба поділити кількість захворювань на рік на певне число:  
-- 12 — для отримання середньої кількості захворювань на місяць, 4 — на квартал або 2 — на півріччя. 
-- Таким чином, функція буде приймати два параметри: кількість захворювань на рік та довільний дільник. Ви також маєте використати її — запустити на даних.  
-- Оскільки не всі рядки містять число захворювань, вам необхідно буде відсіяти ті, що не мають чисельного значення (≠ ‘’).

DELIMITER //
CREATE FUNCTION calculate_cases_per_period(cases_per_year FLOAT, divider INT)
RETURNS FLOAT
DETERMINISTIC
BEGIN
    IF cases_per_year IS NULL OR divider = 0 THEN
        RETURN NULL;
    ELSE
        RETURN cases_per_year / divider;
    END IF;
END //
DELIMITER ;

-- Наприклад, розрахувати середню кількість випадків за місяць
SELECT 
    year,
    number_rabies,
    calculate_cases_per_period(number_rabies, 12) AS rabies_per_month
FROM cases
WHERE number_rabies IS NOT NULL;

