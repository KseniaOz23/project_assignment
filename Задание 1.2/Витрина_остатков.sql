create table dm.dm_account_balance_f (
    on_date date not null,
    account_rk integer not null,
    balance_out numeric(23,8),
    balance_out_rub numeric(23,8)
);


insert into dm.dm_account_balance_f (on_date, account_rk, balance_out, balance_out_rub)
select 
    f.on_date,
    f.account_rk,
    round(f.balance_out, 2) as balance_out,
    round(f.balance_out * coalesce(r.reduced_cource, 1), 2) as balance_out_rub
from ds.ft_balance_f f
left join ds.md_exchange_rate_d r 
    on f.currency_rk = r.currency_rk 
    and f.on_date between r.data_actual_date and coalesce(r.data_actual_end_date, '2050-12-31')
where f.on_date = '2017-12-31';


create or replace procedure ds.fill_account_balance_f(i_ondate date)
language plpgsql
as $$
declare
    v_prev_date date;
    v_start_time timestamp;
    v_log_id integer;
    v_rows_loaded integer;
begin
    v_start_time := now();
    v_prev_date := i_ondate - 1;
    
    -- логируем начало
    insert into logs.etl_log (table_name, start_time, status, file_name)
    values ('dm.dm_account_balance_f', v_start_time, 'STARTED', 'procedure')
    returning log_id into v_log_id;
    
    delete from dm.dm_account_balance_f where on_date = i_ondate;
    
    insert into dm.dm_account_balance_f (on_date, account_rk, balance_out, balance_out_rub)
    with 
    rates as (
        select currency_rk, reduced_cource
        from ds.md_exchange_rate_d
        where i_ondate between data_actual_date and coalesce(data_actual_end_date, '2050-12-31')
    ),
    prev_balance as (
        select account_rk, balance_out, balance_out_rub
        from dm.dm_account_balance_f
        where on_date = v_prev_date
    ),
    turnovers as (
        select account_rk, credit_amount, credit_amount_rub, debet_amount, debet_amount_rub
        from dm.dm_account_turnover_f
        where on_date = i_ondate
    ),
    active_accounts as (
        select account_rk, char_type
        from ds.md_account_d
        where i_ondate between data_actual_date and coalesce(data_actual_end_date, '2050-12-31')
    )
    select 
        i_ondate as on_date,
        a.account_rk,
        -- расчет остатка в валюте (активный: +дебет -кредит, пассивный: -дебет +кредит)
        round(
            case 
                when a.char_type = 'А' then 
                    coalesce(p.balance_out, 0) + coalesce(t.debet_amount, 0) - coalesce(t.credit_amount, 0)
                when a.char_type = 'П' then 
                    coalesce(p.balance_out, 0) - coalesce(t.debet_amount, 0) + coalesce(t.credit_amount, 0)
            end, 2
        ) as balance_out,
        -- расчет остатка в рублях
        round(
            case 
                when a.char_type = 'А' then 
                    coalesce(p.balance_out_rub, 0) + coalesce(t.debet_amount_rub, 0) - coalesce(t.credit_amount_rub, 0)
                when a.char_type = 'П' then 
                    coalesce(p.balance_out_rub, 0) - coalesce(t.debet_amount_rub, 0) + coalesce(t.credit_amount_rub, 0)
            end, 2
        ) as balance_out_rub
    from active_accounts a
    left join prev_balance p on a.account_rk = p.account_rk
    left join turnovers t on a.account_rk = t.account_rk;
    
    get diagnostics v_rows_loaded = row_count;
    
    -- обновляем лог
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