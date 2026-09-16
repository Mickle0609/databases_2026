-- ДЗ 2, часть 1
-- добавляю categories (справочник категорий) и course_categories (посредник для м:н)
-- курс может быть в нескольких категориях, категория содержит много курсов
-- поэтому обычную колонку тут не сделать, нужна отдельная таблица с одной строкой на пару
-- pk составной (course_id, category_id) - и дубли не даёт вставлять, и поиск по course_id быстрый
-- для обратного поиска (курсы категории) нужен ещё индекс по category_id
-- на fk стоит on delete cascade, но это чистит только связи в посреднике,
-- сами курсы и категории при удалении друг друга не трогаются

DROP TABLE IF EXISTS course_categories CASCADE;
DROP TABLE IF EXISTS categories CASCADE;

CREATE TABLE categories (
    id          SERIAL PRIMARY KEY,
    name        VARCHAR(100) NOT NULL UNIQUE,
    description TEXT
);

CREATE TABLE course_categories (
    course_id   INTEGER NOT NULL REFERENCES courses(id) ON DELETE CASCADE,
    category_id INTEGER NOT NULL REFERENCES categories(id) ON DELETE CASCADE,
    PRIMARY KEY (course_id, category_id)
);

CREATE INDEX idx_course_categories_category_id ON course_categories(category_id);


-- индексы под частые запросы из ДЗ 1 (уроки по порядку, рейтинг курса,
-- выплаты за месяц, невыплаченные выплаты, завершенные записи на курс)
-- индексов на fk из schema_1 для этого не хватало, пришлось бы досортировывать вручную

CREATE INDEX idx_lessons_course_order ON lessons(course_id, order_number);
CREATE INDEX idx_reviews_course_rating ON reviews(course_id, rating);
CREATE INDEX idx_payouts_teacher_month ON payouts(teacher_id, pay_month);
CREATE INDEX idx_payouts_unpaid ON payouts(teacher_id) WHERE paid_at IS NULL;
CREATE INDEX idx_enrollments_course_status ON enrollments(course_id, status);
