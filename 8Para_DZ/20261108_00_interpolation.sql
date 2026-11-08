do $$
begin
	
	-- Отдельный тип для рассчета интегрполяции
	drop type  if exists interpolation_type cascade;
	create type interpolation_type as
	(
		x0 numeric(8,2),
		x1 numeric(8,2),
		y0 numeric(8,2),
		y1 numeric(8,2)
	);

	comment on type interpolation_type is 'Отдельный тип для рассчета интегрполяции';
		
	
	-- Расчет интерполяции
	drop function if exists public.fn_calc_interpolation;
	create function public.fn_calc_interpolation(
		par_x numeric,
		par_interpolation public.interpolation_type
		)
		returns numeric
		language 'plpgsql'
	as $body$
	begin
	 		if par_interpolation.x1 = par_interpolation.x0 then
                return par_interpolation.y0;
            end if;

            return 
				round( par_interpolation.y0 + (par_x - par_interpolation.x0) * (par_interpolation.y1 - par_interpolation.y0) / (par_interpolation.x1 - par_interpolation.x0) , 2);
	end;
	$body$;

	comment on function fn_calc_interpolation is 'Расчет интерполяции';


end $$


	
