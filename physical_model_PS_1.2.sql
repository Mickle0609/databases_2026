drop table if exists Review cascade;
drop table if exists Enrollment cascade;
drop table if exists Lesson cascade;
drop table if exists Course cascade;
drop table if exists "User" cascade;

create Table "User"(
    id serial primary key,
    login varchar(50) not null unique,
    password_user varchar(50) not null,
    role varchar(20) not null
    check (role in('student','teacher'))
);

create Table Course (
    id serial primary key,
    title varchar(50) not null,
    price decimal(10,2) not null check (price>=0),
    id_teacher integer not null
    references "User"(id) on delete cascade
);

create Table Lesson (
    id serial primary key,
    id_course integer not null
    references Course(id) on delete cascade,
    title varchar(50) not null,
    order_index integer not null,
    unique(order_index, id_course)
);

create table Enrollment (
    id serial primary key,
    id_course integer not null
    references Course(id) on delete cascade,
    id_user integer not null
    references "User"(id) on delete cascade,
    progress integer default 0 check(progress between 0 and 100),
    unique(id_user, id_course)
);

create table Review (
    id serial primary key,
    id_course integer not null
    references Course(id) on delete cascade,
    id_user integer not null
    references "User"(id) on delete cascade,
    rating integer not null check (rating between 1 and 5),
    comment text
);

create index idx_course_teacher on Course(id_teacher);
create index idx_lesson_course on Lesson(id_course);
create index idx_enrollment_course on Enrollment(id_course);
create index idx_enrollment_user on Enrollment(id_user);
create index idx_review_course on Review(id_course);
create index idx_review_user on Review(id_user);