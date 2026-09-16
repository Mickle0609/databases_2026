-- =====================================================================
-- Вариант №1. Онлайн-курсы (EdTech)
-- Физическая модель базы данных для PostgreSQL
--
-- Скрипт можно запускать несколько раз подряд — в начале каждая таблица
-- удаляется командой DROP TABLE IF EXISTS, а потом создаётся заново.
-- =====================================================================

DROP TABLE IF EXISTS payouts CASCADE;
DROP TABLE IF EXISTS reviews CASCADE;
DROP TABLE IF EXISTS enrollments CASCADE;
DROP TABLE IF EXISTS lessons CASCADE;
DROP TABLE IF EXISTS courses CASCADE;
DROP TABLE IF EXISTS students CASCADE;
DROP TABLE IF EXISTS teachers CASCADE;
DROP TABLE IF EXISTS users CASCADE;


-- ---------------------------------------------------------------------
-- Таблица 1. users — общие данные любого пользователя платформы:
-- имя, почта, пароль, дата регистрации.
--
-- Решение: студенты и преподаватели — это разные сущности. У них разные
-- связи с курсами: преподаватель — автор курса (1:N), а студент —
-- участник курса (M:N через enrollments). Поэтому для каждой роли
-- заведена своя таблица (teachers и students), а в users остались только
-- поля, общие для всех, чтобы не дублировать их в двух местах.
--
-- Поля role больше нет: роль определяется тем, в какой таблице
-- (teachers или students) есть запись с этим id.
-- ---------------------------------------------------------------------
CREATE TABLE users (
    id            SERIAL PRIMARY KEY,          -- номер пользователя, генерируется сам
    full_name     VARCHAR(150) NOT NULL,       -- имя, обязательно
    email         VARCHAR(150) NOT NULL UNIQUE,-- почта, обязательна и не повторяется
    password_hash VARCHAR(255) NOT NULL,       -- пароль (в базе хранится не сам пароль, а его хеш)
    created_at    TIMESTAMP NOT NULL DEFAULT now() -- дата регистрации, ставится автоматически
);


-- ---------------------------------------------------------------------
-- Таблица 2. teachers — преподаватели.
-- id одновременно первичный ключ и ссылка на users(id): запись здесь
-- означает «этот пользователь — преподаватель». Связь users–teachers 1:1.
-- ON DELETE CASCADE: если удалить пользователя, его запись преподавателя
-- тоже удалится.
-- ---------------------------------------------------------------------
CREATE TABLE teachers (
    id INTEGER PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE
);


-- ---------------------------------------------------------------------
-- Таблица 3. students — студенты. Устроена так же, как teachers.
-- ---------------------------------------------------------------------
CREATE TABLE students (
    id INTEGER PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE
);


-- ---------------------------------------------------------------------
-- Таблица 4. courses — курсы. У каждого курса есть автор-преподаватель
-- и цена. teacher_id ссылается на teachers(id), а не на users(id),
-- поэтому создать курс от имени студента база не даст — такого id
-- просто нет в таблице teachers.
-- ---------------------------------------------------------------------
CREATE TABLE courses (
    id          SERIAL PRIMARY KEY,
    title       VARCHAR(200) NOT NULL,
    description TEXT,
    teacher_id  INTEGER NOT NULL REFERENCES teachers(id), -- какой преподаватель создал курс
    price       DECIMAL(10, 2) NOT NULL CHECK (price >= 0),
    created_at  TIMESTAMP NOT NULL DEFAULT now()
);

-- Индекс на внешний ключ: помогает базе быстрее находить все курсы
-- конкретного преподавателя, не перебирая таблицу целиком.
CREATE INDEX idx_courses_teacher_id ON courses(teacher_id);


-- ---------------------------------------------------------------------
-- Таблица 5. lessons — уроки внутри курса.
-- order_number — порядковый номер урока в курсе (1, 2, 3...),
-- чтобы можно было показывать уроки по порядку.
-- ---------------------------------------------------------------------
CREATE TABLE lessons (
    id           SERIAL PRIMARY KEY,
    course_id    INTEGER NOT NULL REFERENCES courses(id) ON DELETE CASCADE,
    title        VARCHAR(200) NOT NULL,
    content      TEXT,
    order_number INTEGER NOT NULL CHECK (order_number > 0)
);

-- ON DELETE CASCADE выше значит: если удалить курс, все его уроки
-- удалятся вместе с ним автоматически (без "осиротевших" уроков).

CREATE INDEX idx_lessons_course_id ON lessons(course_id);


-- ---------------------------------------------------------------------
-- Таблица 6. enrollments — запись студента на курс.
-- Это связь "многие-ко-многим": один студент может учиться на многих
-- курсах, у одного курса может быть много студентов. Напрямую такую
-- связь в SQL не сделать, поэтому заводим отдельную таблицу-посредник.
-- student_id ссылается на students(id) — записать на курс можно только
-- студента.
--
-- status — здесь же храним, прошёл ли студент курс целиком (это ответ
-- на вопрос "как хранить статус завершения курса" из задания).
-- ---------------------------------------------------------------------
CREATE TABLE enrollments (
    id          SERIAL PRIMARY KEY,
    student_id  INTEGER NOT NULL REFERENCES students(id),
    course_id   INTEGER NOT NULL REFERENCES courses(id),
    status      VARCHAR(20) NOT NULL DEFAULT 'in_progress'
                    CHECK (status IN ('in_progress', 'completed')),
    enrolled_at TIMESTAMP NOT NULL DEFAULT now(),
    UNIQUE (student_id, course_id) -- один студент не может записаться на один курс дважды
);

CREATE INDEX idx_enrollments_student_id ON enrollments(student_id);
CREATE INDEX idx_enrollments_course_id ON enrollments(course_id);


-- ---------------------------------------------------------------------
-- Таблица 7. reviews — отзывы студентов на курсы, с оценкой от 1 до 5.
-- Оставить отзыв может только студент (student_id -> students).
-- ---------------------------------------------------------------------
CREATE TABLE reviews (
    id         SERIAL PRIMARY KEY,
    student_id INTEGER NOT NULL REFERENCES students(id),
    course_id  INTEGER NOT NULL REFERENCES courses(id),
    rating     SMALLINT NOT NULL CHECK (rating BETWEEN 1 AND 5),
    comment    TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT now(),
    UNIQUE (student_id, course_id) -- один отзыв от студента на курс, не больше
);

CREATE INDEX idx_reviews_student_id ON reviews(student_id);
CREATE INDEX idx_reviews_course_id ON reviews(course_id);


-- ---------------------------------------------------------------------
-- Таблица 8. payouts — сколько денег и за какой курс должен получить
-- преподаватель. Отдельная таблица, потому что один преподаватель может
-- вести несколько курсов и получать выплаты по каждому отдельно.
-- Выплата возможна только преподавателю (teacher_id -> teachers).
-- ---------------------------------------------------------------------
CREATE TABLE payouts (
    id         SERIAL PRIMARY KEY,
    teacher_id INTEGER NOT NULL REFERENCES teachers(id),
    course_id  INTEGER NOT NULL REFERENCES courses(id),
    amount     DECIMAL(10, 2) NOT NULL CHECK (amount >= 0),
    pay_month  DATE NOT NULL, -- за какой месяц начислена выплата
    paid_at    TIMESTAMP      -- когда фактически выплачено (пусто, если ещё не выплачено)
);

CREATE INDEX idx_payouts_teacher_id ON payouts(teacher_id);
CREATE INDEX idx_payouts_course_id ON payouts(course_id);
