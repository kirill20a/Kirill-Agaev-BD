-- если запускаем не в первый раз, сначала сносим старое
-- порядок обратный, чтобы не ругалось на FK
drop table if exists batches cascade;
drop table if exists parameters cascade;
drop table if exists equipment_types cascade;
drop table if exists users cascade;
drop table if exists positions cascade;


-- должности
create table positions (
    code     integer not null,
    name     varchar(100) not null,
    salary   numeric(12,2),
    primary key (code),
    unique (name)
);

insert into positions (code, name, salary) values
    (1, 'Оператор', 45000),
    (2, 'Технолог', 65000),
    (3, 'Инженер', 80000),
    (4, 'Начальник смены', 95000),
    (5, 'Директор', 150000);


-- пользователи
create table users (
    code          integer not null,
    full_name     varchar(150) not null,
    login         varchar(50) not null,
    email         varchar(100),
    position_code integer not null,
    hired_at      date not null,
    primary key (code),
    unique (login),
    foreign key (position_code) references positions (code)
);

insert into users (code, full_name, login, email, position_code, hired_at) values
    (1, 'Иванов Иван Иванович', 'ivanov', 'ivanov@example.com', 3, date '2020-03-15'),
    (2, 'Петров Пётр Петрович', 'petrov', 'petrov@example.com', 2, date '2021-07-01'),
    (3, 'Сидорова Анна Сергеевна', 'sidorova', 'sidorova@example.com', 1, date '2022-01-10'),
    (4, 'Кузнецов Кузьма Кузьмич', 'kuznetsov', 'kuznetsov@example.com', 4, date '2019-09-05'),
    (5, 'Смирнова Ольга Ивановна', 'smirnova', 'smirnova@example.com', 5, date '2018-02-20');


-- типы оборудования
create table equipment_types (
    code integer not null,
    name varchar(100) not null,
    description varchar(255),
    primary key (code),
    unique (name)
);

insert into equipment_types (code, name, description) values
    (1, 'Станок ЧПУ', 'станок с числовым программным управлением'),
    (2, 'Пресс', 'гидравлический пресс'),
    (3, 'Конвейер', 'ленточный конвейер'),
    (4, 'Робот-манипулятор', 'промышленный робот'),
    (5, 'Компрессор', 'воздушный компрессор');


-- параметры (относятся к типу оборудования)
create table parameters (
    code integer not null,
    name varchar(100) not null,
    unit varchar(20) not null,
    equipment_type_code integer not null,
    min_value numeric(12,3),
    max_value numeric(12,3),
    primary key (code),
    unique (name),
    foreign key (equipment_type_code) references equipment_types (code)
);

insert into parameters (code, name, unit, equipment_type_code, min_value, max_value) values
    (1, 'Скорость вращения', 'об/мин', 1, 100, 3000),
    (2, 'Давление', 'бар', 2, 5, 200),
    (3, 'Скорость ленты', 'м/с', 3, 0.1, 5),
    (4, 'Точность позиции', 'мм', 4, 0.01, 1),
    (5, 'Производительность', 'м3/ч', 5, 10, 1000);


-- пачки
create table batches (
    code integer not null,
    number varchar(50) not null,
    produced_at date not null,
    quantity integer not null,
    user_code integer not null,
    equipment_type_code integer not null,
    primary key (code),
    unique (number),
    foreign key (user_code) references users (code),
    foreign key (equipment_type_code) references equipment_types (code)
);

insert into batches (code, number, produced_at, quantity, user_code, equipment_type_code) values
    (1, 'B-2024-0001', date '2024-01-15', 100, 1, 1),
    (2, 'B-2024-0002', date '2024-02-03', 250, 2, 2),
    (3, 'B-2024-0003', date '2024-03-11', 500, 3, 3),
    (4, 'B-2024-0004', date '2024-04-22', 120, 4, 4),
    (5, 'B-2024-0005', date '2024-05-30', 300, 5, 5);


-- итоговая выборка: собираем всё в одну таблицу
select
    b.code as batch_code,
    b.number as batch_number,
    b.produced_at,
    b.quantity,
    u.code as user_code,
    u.full_name,
    p.code as position_code,
    p.name as position_name,
    et.code as equipment_code,
    et.name as equipment_name,
    pr.code as parameter_code,
    pr.name as parameter_name,
    pr.unit,
    pr.min_value,
    pr.max_value
from batches b
join users u on u.code = b.user_code
join positions p on p.code = u.position_code
join equipment_types et on et.code = b.equipment_type_code
join parameters pr on pr.equipment_type_code = et.code
order by b.code, pr.code;