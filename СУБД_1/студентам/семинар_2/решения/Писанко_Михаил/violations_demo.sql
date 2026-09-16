-- =====================================================================
-- Домашнее задание №2, Часть 2. Демонстрация нарушений ограничений
--
-- Скрипт запускать ПОСЛЕ schema_1.sql и schema_2.sql.
-- Он идемпотентен: тестовые данные создаются только если их ещё нет,
-- поэтому скрипт можно запускать повторно без ошибок в блоке "Setup".
-- =====================================================================


-- ---------------------------------------------------------------------
-- Setup. Минимальный набор корректных тестовых данных, на фоне которых
-- будут демонстрироваться нарушения (иначе, например, вставка курса
-- с отрицательной ценой упала бы ещё раньше — из-за отсутствия
-- преподавателя, и мы бы проверяли не тот тип ограничения).
-- ---------------------------------------------------------------------
INSERT INTO users (full_name, email, password_hash) VALUES
    ('Иван Преподавателев', 'teacher_demo@example.com', 'hash_teacher'),
    ('Анна Студентова',     'student_demo@example.com', 'hash_student')
ON CONFLICT (email) DO NOTHING;

INSERT INTO teachers (id)
SELECT id FROM users WHERE email = 'teacher_demo@example.com'
ON CONFLICT (id) DO NOTHING;

INSERT INTO students (id)
SELECT id FROM users WHERE email = 'student_demo@example.com'
ON CONFLICT (id) DO NOTHING;

INSERT INTO courses (title, description, teacher_id, price)
SELECT 'Демо-курс для ДЗ №2', 'Курс для демонстрации ограничений целостности', t.id, 100.00
FROM teachers t JOIN users u ON u.id = t.id
WHERE u.email = 'teacher_demo@example.com'
  AND NOT EXISTS (SELECT 1 FROM courses WHERE title = 'Демо-курс для ДЗ №2');

INSERT INTO categories (name, description) VALUES
    ('Программирование', 'Курсы по программированию')
ON CONFLICT (name) DO NOTHING;

INSERT INTO course_categories (course_id, category_id)
SELECT c.id, cat.id
FROM courses c, categories cat
WHERE c.title = 'Демо-курс для ДЗ №2' AND cat.name = 'Программирование'
ON CONFLICT DO NOTHING;


-- =====================================================================
-- 1. Нарушение CHECK
-- Попытка создать курс с отрицательной ценой.
-- =====================================================================
DO $$
DECLARE
    v_teacher_id INTEGER;
BEGIN
    SELECT t.id INTO v_teacher_id
    FROM teachers t JOIN users u ON u.id = t.id
    WHERE u.email = 'teacher_demo@example.com';

    INSERT INTO courses (title, description, teacher_id, price)
    VALUES ('Курс с отрицательной ценой', 'test', v_teacher_id, -500.00);
EXCEPTION
    WHEN check_violation THEN
        RAISE NOTICE 'Ошибка: стоимость курса не может быть отрицательной — курс нельзя продавать "в минус". Текст ошибки СУБД: %', SQLERRM;
END;
$$;


-- =====================================================================
-- 2. Нарушение FOREIGN KEY
-- Попытка записать студента на несуществующий курс.
-- =====================================================================
DO $$
DECLARE
    v_student_id INTEGER;
BEGIN
    SELECT s.id INTO v_student_id
    FROM students s JOIN users u ON u.id = s.id
    WHERE u.email = 'student_demo@example.com';

    INSERT INTO enrollments (student_id, course_id)
    VALUES (v_student_id, 999999);
EXCEPTION
    WHEN foreign_key_violation THEN
        RAISE NOTICE 'Ошибка: нельзя записать студента на несуществующий курс — запись должна ссылаться на реально существующий курс в каталоге. Текст ошибки СУБД: %', SQLERRM;
END;
$$;


-- =====================================================================
-- 3. Нарушение UNIQUE
-- Попытка зарегистрировать нового пользователя с уже занятой почтой.
-- =====================================================================
DO $$
BEGIN
    INSERT INTO users (full_name, email, password_hash)
    VALUES ('Дубликат Почтова', 'teacher_demo@example.com', 'hash_dup');
EXCEPTION
    WHEN unique_violation THEN
        RAISE NOTICE 'Ошибка: пользователь с такой почтой уже зарегистрирован — почта используется как логин и должна быть уникальной. Текст ошибки СУБД: %', SQLERRM;
END;
$$;


-- =====================================================================
-- 4. Нарушение NOT NULL
-- Попытка создать курс без названия.
-- =====================================================================
DO $$
DECLARE
    v_teacher_id INTEGER;
BEGIN
    SELECT t.id INTO v_teacher_id
    FROM teachers t JOIN users u ON u.id = t.id
    WHERE u.email = 'teacher_demo@example.com';

    INSERT INTO courses (title, description, teacher_id, price)
    VALUES (NULL, 'Курс без названия', v_teacher_id, 100.00);
EXCEPTION
    WHEN not_null_violation THEN
        RAISE NOTICE 'Ошибка: у курса обязательно должно быть название — иначе студенты не смогут найти его в каталоге. Текст ошибки СУБД: %', SQLERRM;
END;
$$;


-- =====================================================================
-- 5. Другое ограничение — нарушение PRIMARY KEY
-- Попытка повторно привязать курс к той же категории (составной PK
-- таблицы course_categories запрещает дублирование пары значений).
-- =====================================================================
DO $$
DECLARE
    v_course_id   INTEGER;
    v_category_id INTEGER;
BEGIN
    SELECT c.id INTO v_course_id FROM courses c WHERE c.title = 'Демо-курс для ДЗ №2';
    SELECT cat.id INTO v_category_id FROM categories cat WHERE cat.name = 'Программирование';

    -- эта пара уже существует после блока Setup, поэтому вставка нарушит PK
    INSERT INTO course_categories (course_id, category_id)
    VALUES (v_course_id, v_category_id);
EXCEPTION
    WHEN unique_violation THEN
        RAISE NOTICE 'Ошибка: этот курс уже привязан к данной категории — повторная привязка нарушает первичный ключ таблицы-посредника. Текст ошибки СУБД: %', SQLERRM;
END;
$$;
