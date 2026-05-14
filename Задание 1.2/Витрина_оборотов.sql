create table dm.dm_account_turnover_f (
    on_date date,
    account_rk integer,
    credit_amount numeric(23,8),
    credit_amount_rub numeric(23,8),
    debet_amount numeric(23,8),
    debet_amount_rub numeric(23,8)
);

create or replace procedure ds.fill_account_turnover_f(i_ondate date)
language plpgsql
as $$
declare
    v_start_time timestamp;
    v_log_id integer;
    v_rows_loaded integer;
begin
    v_start_time := now();
    
    insert into logs.etl_log (table_name, start_time, status, file_name)
    values ('dm.dm_account_turnover_f', v_start_time, 'STARTED', 'procedure')
    returning log_id into v_log_id;
    
    delete from dm.dm_account_turnover_f where on_date = i_ondate;
    
    insert into dm.dm_account_turnover_f
    with 
    -- кредитовые обороты
    credit_turn as (
        select 
            p.oper_date,
            p.credit_account_rk as account_rk,
            sum(p.credit_amount) as credit_amount,
            a.currency_rk
        from ds.ft_posting_f p
        left join ds.md_account_d a on p.credit_account_rk = a.account_rk
            and i_ondate between a.data_actual_date and coalesce(a.data_actual_end_date, '2050-12-31')
        where p.oper_date = i_ondate
        group by p.oper_date, p.credit_account_rk, a.currency_rk
    ),
    -- дебетовые обороты
    debit_turn as (
        select 
            p.oper_date,
            p.debet_account_rk as account_rk,
            sum(p.debet_amount) as debet_amount,
            a.currency_rk
        from ds.ft_posting_f p
        left join ds.md_account_d a on p.debet_account_rk = a.account_rk
            and i_ondate between a.data_actual_date and coalesce(a.data_actual_end_date, '2050-12-31')
        where p.oper_date = i_ondate
        group by p.oper_date, p.debet_account_rk, a.currency_rk
    ),
    -- курсы валют на дату
    rates as (
        select currency_rk, reduced_cource
        from ds.md_exchange_rate_d
        where i_ondate between data_actual_date and coalesce(data_actual_end_date, '2050-12-31')
    )
    select 
        coalesce(c.oper_date, d.oper_date) as on_date,
        coalesce(c.account_rk, d.account_rk) as account_rk,
        round(coalesce(c.credit_amount, 0)::numeric, 2) as credit_amount,
        round((coalesce(c.credit_amount, 0) * coalesce(r_c.reduced_cource, 1))::numeric, 2) as credit_amount_rub,
        round(coalesce(d.debet_amount, 0)::numeric, 2) as debet_amount,
        round((coalesce(d.debet_amount, 0) * coalesce(r_d.reduced_cource, 1))::numeric, 2) as debet_amount_rub
    from credit_turn c
    full join debit_turn d on c.oper_date = d.oper_date and c.account_rk = d.account_rk
    left join rates r_c on c.currency_rk = r_c.currency_rk
    left join rates r_d on d.currency_rk = r_d.currency_rk;
    
    get diagnostics v_rows_loaded = row_count;
    
    update logs.etl_log 
    set end_time = now(), rows_loaded = v_rows_loaded, status = 'SUCCESS'
    where log_id = v_log_id;
    
exception when others then
    update logs.etl_log 
    set end_time = now(), status = 'FAILED', error_message = sqlerrm
    where log_id = v_log_id;
    raise;
end;
$$;