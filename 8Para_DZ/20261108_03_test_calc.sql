-- Тест расчета МЕТЕО-11 (после 20261108_01_migration.sql и 20261108_02_calc_meteo.sql)
-- Контрольные значения посчитаны вручную по ТЗ

do $$
declare
	var_params meteo_input_params;
	var_row record;
	var_header text;
	var_dt0 integer;
	var_tt200 text;
	var_cc200 text;
	var_hh400 text;
	var_equipment integer;
begin
	raise notice '=============== ТЕСТ 1. Пример 2 из ТЗ (ДМК) ===============';
	raise notice 'Вход: высота 100, давление 765, температура 25, направление 15, скорость 6, оборудование ДМК';
	var_params := row(100, 25, 765, 15, 6, null)::meteo_input_params;
	var_equipment := (select id from measurment_equipment where short_name = 'ДМК');

	var_dt0 := fn_calc_delta_t0(var_params.temperature);
	var_header := case when var_params.pressure - 750 >= 0 then lpad((var_params.pressure - 750)::text, 3, '0')
	                   else '5' || lpad((750 - var_params.pressure)::text, 2, '0') end
	              || lpad(abs(var_dt0)::text, 2, '0');
	raise notice 'БББТТ = % (ожидается 01511)', var_header;
	assert var_header = '01511', 'Заголовок примера 2 не совпал с ТЗ';

	raise notice ' H  TT HH CC';
	for var_row in select * from fn_calc_meteo11(var_params, var_equipment) loop
		raise notice ' %  %  %  %   (% м)', var_row.h, var_row.tt, var_row.hh, var_row.cc, var_row.height;
	end loop;

	raise notice '=============== ТЕСТ 2. Пример алгоритма ДМК (t0 = +3) ===============';
	var_params := row(100, 3, 750, 15, 6, null)::meteo_input_params;
	raise notice 'dTv = %, dT0 = % (ожидается 0.30 и -13)', fn_calc_delta_tv(3), fn_calc_delta_t0(3);
	assert fn_calc_delta_tv(3) = 0.3 and fn_calc_delta_t0(3) = -13, 'Пример t0=+3 не совпал';

	raise notice ' H  TT HH CC';
	for var_row in select * from fn_calc_meteo11(var_params, var_equipment) loop
		raise notice ' %  %  %  %   (% м)', var_row.h, var_row.tt, var_row.hh, var_row.cc, var_row.height;
		if var_row.height = 200 then
			var_tt200 := var_row.tt;
			var_cc200 := var_row.cc;
		end if;
	end loop;
	raise notice 'На 200 м: -9 + (-3) = -12 -> 12 + 50 = % (ожидается 62)', var_tt200;
	assert var_tt200 = '62', 'ТТ на 200 м для t0=+3 должно быть 62';
	assert var_cc200 = '09', 'Скорость ДМК V0=6 на 200 м должна быть 9';

	raise notice '=============== ТЕСТ 3. Пример 1 из ТЗ (t0 = 23) ===============';
	raise notice 'dTv = %, dT0 = % (ожидается 1.80 и 9)', fn_calc_delta_tv(23), fn_calc_delta_t0(23);
	assert fn_calc_delta_tv(23) = 1.8 and fn_calc_delta_t0(23) = 9, 'Пример 1 из ТЗ не совпал';

	raise notice '=============== ТЕСТ 4. Значения по умолчанию, ВР ===============';
	raise notice 'Вход: высота 100, температура 15, давление 750, направление 0, дальность 0, оборудование ВР';
	var_equipment := (select id from measurment_equipment where short_name = 'ВР');
	var_params := row(100, 15, 750, 0, null, 0)::meteo_input_params;
	raise notice ' H  TT HH CC';
	for var_row in select * from fn_calc_meteo11(var_params, var_equipment) loop
		raise notice ' %  %  %  %   (% м)', var_row.h, var_row.tt, var_row.hh, var_row.cc, var_row.height;
		assert var_row.tt = '00' and var_row.hh = '00' and var_row.cc = '00', 'Для значений по умолчанию все должно быть нулями';
	end loop;

	raise notice '=============== ТЕСТ 5. ВР, мороз, дальность между столбцами ===============';
	raise notice 'Вход: высота 100, температура -10, давление 743, направление 50, дальность 75, оборудование ВР';
	var_params := row(100, -10, 743, 50, null, 75)::meteo_input_params;
	raise notice 'dT0 = % (ожидается -26: -20 + -6 -> 26 + 50 = 76)', fn_calc_delta_t0(-10);
	raise notice ' H  TT HH CC';
	for var_row in select * from fn_calc_meteo11(var_params, var_equipment) loop
		raise notice ' %  %  %  %   (% м)', var_row.h, var_row.tt, var_row.hh, var_row.cc, var_row.height;
		if var_row.height = 200 then
			var_tt200 := var_row.tt;
			var_cc200 := var_row.cc;
		elsif var_row.height = 400 then
			var_hh400 := var_row.hh;
		end if;
	end loop;
	assert var_tt200 = '76', 'ВР: ТТ на 200 м должно быть 76';
	assert var_cc200 = '07', 'ВР: дальность 75 между 70 (6) и 80 (7) -> 6.5 -> 07';
	assert var_hh400 = '51', 'ВР: направление на 400 м = 50 + 1';

	raise notice '=============== ТЕСТ 6. Ошибочные входные данные ===============';
	begin
		perform * from fn_calc_meteo11(row(100, 70, 750, 0, 0, null)::meteo_input_params, 1);
		raise exception 'Температура 70 должна была отклониться';
	exception when raise_exception then
		raise notice 'OK: %', sqlerrm;
	end;
	begin
		perform * from fn_calc_meteo11(row(100, 15, 750, 60, 0, null)::meteo_input_params, 1);
		raise exception 'Направление 60 должно было отклониться';
	exception when raise_exception then
		raise notice 'OK: %', sqlerrm;
	end;
	begin
		perform * from fn_calc_meteo11(row(100, 15, 750, 0, 0, null)::meteo_input_params, 99);
		raise exception 'Оборудование 99 должно было отклониться';
	exception when raise_exception then
		raise notice 'OK: %', sqlerrm;
	end;

	raise notice '=============== ВСЕ ТЕСТЫ ПРОЙДЕНЫ ===============';
end $$;
