-- ДЗ 2, часть 2
-- запускать после schema_1.sql и schema_2.sql
-- setup идемпотентный, можно гонять скрипт повторно

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
SELECT 'Демо-курс для ДЗ №2', 'курс для демонстрации ограничений', t.id, 100.00
FROM teachers t JOIN users u ON u.id = t.id
WHERE u.email = 'teacher_demo@example.com'
  AND NOT EXISTS (SELECT 1 FROM courses WHERE title = 'Демо-курс для ДЗ №2');

INSERT INTO categories (name, description) VALUES
    ('Программирование', 'курсы по программированию')
ON CONFLICT (name) DO NOTHING;

INSERT INTO course_categories (course_id, category_id)
SELECT c.id, cat.id
FROM courses c, categories cat
WHERE c.title = 'Демо-курс для ДЗ №2' AND cat.name = 'Программирование'
ON CONFLICT DO NOTHING;


-- 1. CHECK, курс с отрицательной ценой
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
        RAISE NOTICE 'Ошибка: цена курса не может быть отрицательной. Текст ошибки СУБД: %', SQLERRM;
END;
$$;


-- 2. FOREIGN KEY, студент на несуществующий курс
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
        RAISE NOTICE 'Ошибка: нельзя записать студента на несуществующий курс. Текст ошибки СУБД: %', SQLERRM;
END;
$$;


-- 3. UNIQUE, повтор почты
DO $$
BEGIN
    INSERT INTO users (full_name, email, password_hash)
    VALUES ('Дубликат Почтова', 'teacher_demo@example.com', 'hash_dup');
EXCEPTION
    WHEN unique_violation THEN
        RAISE NOTICE 'Ошибка: пользователь с такой почтой уже зарегистрирован. Текст ошибки СУБД: %', SQLERRM;
END;
$$;


-- 4. NOT NULL, курс без названия
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
        RAISE NOTICE 'Ошибка: у курса должно быть название. Текст ошибки СУБД: %', SQLERRM;
END;
$$;


-- 5. PRIMARY KEY (составной), повторная привязка курса к категории
DO $$
DECLARE
    v_course_id   INTEGER;
    v_category_id INTEGER;
BEGIN
    SELECT c.id INTO v_course_id FROM courses c WHERE c.title = 'Демо-курс для ДЗ №2';
    SELECT cat.id INTO v_category_id FROM categories cat WHERE cat.name = 'Программирование';

    INSERT INTO course_categories (course_id, category_id)
    VALUES (v_course_id, v_category_id);
EXCEPTION
    WHEN unique_violation THEN
        RAISE NOTICE 'Ошибка: этот курс уже привязан к данной категории. Текст ошибки СУБД: %', SQLERRM;
END;
$$;
