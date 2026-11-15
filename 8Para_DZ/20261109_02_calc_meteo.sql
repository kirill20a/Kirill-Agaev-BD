-- Расчет МЕТЕО-11 (ДМК / ВР) по структуре справочников из 20261102.sql и 20261109_01_normalize.sql
-- Процедура не может вернуть набор строк, поэтому функция с returns table

do $$
begin

	-- Тип "входящие параметры"
	begin
		create type meteo_input_params as
		(
			station_height integer,
			temperature numeric(8,2),
			pressure integer,
			wind_direction integer,
			wind_speed integer,
			bullet_drift integer
		);
	exception when duplicate_object then
		raise notice 'Тип meteo_input_params уже существует';
	end;

	comment on type meteo_input_params is 'Входящие параметры расчета МЕТЕО-11';

	-- Таблица 1: виртуальная поправка (интерполяция из учебного скрипта)
	create or replace function fn_calc_delta_tv(par_temperature numeric)
	returns numeric
	language plpgsql
	as $BODY$
	begin
		if par_temperature < 0 then
			return 0;
		end if;

		if par_temperature > (select max(temperature) from calc_correction_temperature) then
			return (select correction from calc_correction_temperature order by temperature desc limit 1);
		end if;

		return fn_calc_temperature_interpolation(par_temperature);
	end;
	$BODY$;

	-- Отклонение приземной виртуальной температуры
	create or replace function fn_calc_delta_t0(par_temperature numeric)
	returns integer
	language plpgsql
	as $BODY$
	begin
		return round(par_temperature + fn_calc_delta_tv(par_temperature) - 15.9)::integer;
	end;
	$BODY$;

	-- Значение из таблицы корректировок. Нет точного столбца - интерполяция между соседними
	create or replace function fn_calc_correction_value(par_type_id integer, par_height_id integer, par_x numeric)
	returns numeric
	language plpgsql
	as $BODY$
	declare
		var_interpolation interpolation_type;
	begin
		select hv.value, v.value
		into var_interpolation.x0, var_interpolation.y0
		from calc_correction c
		join calc_correction_values v on v.correction_id = c.id
		join calc_correction_header_values hv on hv.id = v.header_value_id
		where c.type_id = par_type_id and c.height_id = par_height_id and hv.value <= par_x
		order by hv.value desc
		limit 1;

		select hv.value, v.value
		into var_interpolation.x1, var_interpolation.y1
		from calc_correction c
		join calc_correction_values v on v.correction_id = c.id
		join calc_correction_header_values hv on hv.id = v.header_value_id
		where c.type_id = par_type_id and c.height_id = par_height_id and hv.value >= par_x
		order by hv.value
		limit 1;

		if var_interpolation.x0 is null or var_interpolation.x1 is null then
			raise exception 'Значение % не покрывается таблицей корректировок (тип %, высота %)', par_x, par_type_id, par_height_id;
		end if;

		return fn_calc_interpolation(par_x, var_interpolation);
	end;
	$BODY$;

	-- Среднее отклонение температуры на высоте (Таблица 2). Для минуса: |сумма| + 50
	create or replace function fn_calc_mean_temperature(par_delta_t0 integer, par_height_id integer)
	returns integer
	language plpgsql
	as $BODY$
	declare
		var_type_id integer;
		var_tens integer := (abs(par_delta_t0) / 10) * 10;
		var_ones integer := abs(par_delta_t0) % 10;
		var_sum integer := 0;
	begin
		if par_delta_t0 = 0 then
			return 0;
		end if;

		select id into var_type_id from calc_correction_types
		where description = case when par_delta_t0 < 0 then 'Таблица 2, Отрицательные температуры'
		                         else 'Таблица 2, Положительные температуры' end;

		if var_tens > 0 then
			var_sum := var_sum + fn_calc_correction_value(var_type_id, par_height_id, var_tens);
		end if;
		if var_ones > 0 then
			var_sum := var_sum + fn_calc_correction_value(var_type_id, par_height_id, var_ones);
		end if;

		if var_sum < 0 then
			return abs(var_sum) + 50;
		end if;
		return var_sum;
	end;
	$BODY$;

	-- Расчет МЕТЕО-11: по строке на каждую стандартную высоту
	create or replace function fn_calc_meteo11(par_params meteo_input_params, par_equipment_id integer)
	returns table (height integer, h text, tt text, hh text, cc text)
	language plpgsql
	as $BODY$
	declare
		var_short_name text;
		var_delta_t0 integer;
		var_speed_type integer;
		var_dir_type integer;
		var_input numeric;
		var_zero boolean := false;
		var_row record;
		var_dir integer;
	begin
		select short_name into var_short_name from measurment_equipment where id = par_equipment_id;
		if var_short_name is null then
			raise exception 'Неизвестный тип оборудования: %', par_equipment_id;
		end if;

		if par_params.temperature not between -58 and 58 then
			raise exception 'Температура % вне диапазона -58..58', par_params.temperature;
		end if;
		if par_params.pressure not between 500 and 900 then
			raise exception 'Давление % вне диапазона 500..900', par_params.pressure;
		end if;
		if par_params.wind_direction not between 0 and 59 then
			raise exception 'Направление ветра % вне диапазона 0..59', par_params.wind_direction;
		end if;

		if var_short_name = 'ДМК' then
			var_input := par_params.wind_speed;
			if var_input is null or var_input not between 0 and 15 then
				raise exception 'Скорость ветра % вне диапазона 0..15', var_input;
			end if;
			var_zero := var_input < 3;
		else
			var_input := par_params.bullet_drift;
			if var_input is null or var_input not between 0 and 150 then
				raise exception 'Дальность сноса пуль % вне диапазона 0..150', var_input;
			end if;
			var_zero := var_input < 40;
		end if;

		select id into var_speed_type from calc_correction_types
		where measurment_equipment_id = par_equipment_id and description like '%Скорость%';
		select id into var_dir_type from calc_correction_types
		where measurment_equipment_id = par_equipment_id and description like '%Направление%';

		var_delta_t0 := fn_calc_delta_t0(par_params.temperature);

		for var_row in select ch.id, ch.height from calc_correction_heights ch order by ch.height loop
			height := var_row.height;
			h := lpad((var_row.height / 100)::text, 2, '0');
			tt := lpad(fn_calc_mean_temperature(var_delta_t0, var_row.id)::text, 2, '0');

			if var_zero then
				hh := '00';
				cc := '00';
			else
				var_dir := fn_calc_correction_value(var_dir_type, var_row.id, 0);
				hh := lpad(((par_params.wind_direction + var_dir) % 60)::text, 2, '0');
				cc := lpad(round(fn_calc_correction_value(var_speed_type, var_row.id, var_input))::text, 2, '0');
			end if;

			return next;
		end loop;
	end;
	$BODY$;

	comment on function fn_calc_meteo11(meteo_input_params, integer) is 'Расчет приближенного МЕТЕО-11: по строке на каждую стандартную высоту';

end $$;
