
drop table if exists batches        cascade;
drop table if exists parameters     cascade;
drop table if exists equipment_types cascade;
drop table if exists users          cascade;
drop table if exists positions      cascade;

-- Должности

create table positions (
    code integer not null,
    name varchar(100) not null,
    primary key (code)
);

comment on table  positions      is 'Справочник должностей сотрудников метеопоста';
comment on column positions.code is 'Уникальный код должности';
comment on column positions.name is 'Название должности';

insert into positions (code, name) values
    (1, 'Оператор'),
    (2, 'Метеоролог'),
    (3, 'Начальник поста'),
    (4, 'Администратор');


-- пользователи

create table users (
    code          integer not null,
    full_name     varchar(150) not null,
    login         varchar(50) not null,
    position_code integer not null,
    primary key (code)
);

comment on table  users               is 'Пользователи ПАК';
comment on column users.code          is 'Уникальный код пользователя';
comment on column users.full_name     is 'ФИО пользователя';
comment on column users.login         is 'Логин для входа в систему';
comment on column users.position_code is 'Код должности (positions.code)';

insert into users (code, full_name, login, position_code) values
    (1, 'Иванов Иван Иванович',    'ivanov',   2),
    (2, 'Петров Пётр Петрович',    'petrov',   1),
    (3, 'Сидорова Анна Сергеевна', 'sidorova', 2),
    (4, 'Кузнецов Кузьма Кузьмич', 'kuznetsov',3),
    (5, 'Смирнова Ольга Ивановна', 'smirnova', 4);


-- типы оборудования
-- ровно два — ДМК и ВР.

create table equipment_types (
    code        integer not null,
    name        varchar(100) not null,
    description varchar(255),
    primary key (code)
);

comment on table  equipment_types             is 'Справочник типов метеорологического оборудования';
comment on column equipment_types.code        is 'Уникальный код типа оборудования';
comment on column equipment_types.name        is 'Краткое обозначение (ДМК, ВР)';
comment on column equipment_types.description is 'Полное название типа оборудования';

insert into equipment_types (code, name, description) values
    (1, 'ДМК', 'Десантный метеокомплект'),
    (2, 'ВР',  'Ветровое ружьё');


-- параметры
-- входные параметры бюллетеня.

create table parameters (
    code                integer not null,
    name                varchar(100) not null,
    unit                varchar(20) not null,
    equipment_type_code integer not null,
    min_value           numeric(12,3),
    max_value           numeric(12,3),
    primary key (code)
);

comment on table  parameters                     is 'Справочник входных параметров метеобюллетеня';
comment on column parameters.code                is 'Уникальный код параметра';
comment on column parameters.name                is 'Название параметра';
comment on column parameters.unit                is 'Единица измерения';
comment on column parameters.equipment_type_code is 'Код типа оборудования (equipment_types.code)';
comment on column parameters.min_value           is 'Минимально допустимое значение';
comment on column parameters.max_value           is 'Максимально допустимое значение';

insert into parameters (code, name, unit, equipment_type_code, min_value, max_value) values
    (1,  'Высота метеопоста',    'м',           1, -100, 5000),
    (2,  'Температура',          '°C',          1,  -58,   58),
    (3,  'Давление',             'мм рт. ст.',  1,  500,  900),
    (4,  'Направление ветра',    'бол. дел.',   1,    0,   59),
    (5,  'Скорость ветра',       'м/с',         1,    0,   15),
    (6,  'Высота метеопоста',    'м',           2, -100, 5000),
    (7,  'Температура',          '°C',          2,  -58,   58),
    (8,  'Давление',             'мм рт. ст.',  2,  500,  900),
    (9,  'Направление ветра',    'бол. дел.',   2,    0,   59),
    (10, 'Дальность сноса пуль', 'м',           2,    0,  150);

--  Пачки (сеансы измерений)
create table batches (
    code                integer not null,
    number              varchar(50) not null,
    produced_at         timestamp not null,
    user_code           integer not null,
    equipment_type_code integer not null,
    temperature         numeric(5,1),
    pressure            integer,
    wind_direction      integer,
    wind_speed          integer,
    bullet_drift        integer,
    primary key (code)
);

comment on table  batches                     is 'Сеансы измерения (пачки), по которым составлен бюллетень';
comment on column batches.code                is 'Уникальный код пачки';
comment on column batches.number              is 'Номер пачки';
comment on column batches.produced_at         is 'Дата и время измерения';
comment on column batches.user_code           is 'Код пользователя (users.code)';
comment on column batches.equipment_type_code is 'Код типа оборудования (equipment_types.code)';
comment on column batches.temperature         is 'Измеренная температура воздуха, °C';
comment on column batches.pressure            is 'Измеренное давление, мм рт. ст.';
comment on column batches.wind_direction      is 'Направление приземного ветра, бол. дел.';
comment on column batches.wind_speed          is 'Скорость приземного ветра, м/с (только для ДМК)';
comment on column batches.bullet_drift        is 'Дальность сноса пуль, м (только для ВР)';

insert into batches (code, number, produced_at, user_code, equipment_type_code,
                     temperature, pressure, wind_direction, wind_speed, bullet_drift) values
    (1, 'М-0001', timestamp '2024-01-15 09:30', 1, 1, 15.0, 750, 10, 5,    null),
    (2, 'М-0002', timestamp '2024-02-03 10:15', 2, 1, -3.0, 745, 25, 3,    null),
    (3, 'М-0003', timestamp '2024-03-11 14:00', 3, 2, 25.0, 765, 15, null, 60),
    (4, 'М-0004', timestamp '2024-04-22 08:45', 4, 2, 10.0, 758, 40, null, 100),
    (5, 'М-0005', timestamp '2024-05-30 16:20', 5, 1, 18.0, 752, 30, 7,    null);



-- Основной запрос — объединение через UNION
select 'positions'       as source, code, name      from positions
union all
select 'users'           as source, code, full_name from users
union all
select 'equipment_types' as source, code, name      from equipment_types
union all
select 'parameters'      as source, code, name      from parameters
union all
select 'batches'         as source, code, number    from batches
order by source, code;