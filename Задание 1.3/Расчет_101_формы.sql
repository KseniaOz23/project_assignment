create table dm.dm_f101_round_f (
    from_date date,
    to_date date,
    chapter char(1),
    ledger_account char(5),
    characteristic char(1),
    balance_in_rub numeric(23,8),
    balance_in_val numeric(23,8),
    balance_in_total numeric(23,8),
    turn_deb_rub numeric(23,8),
    turn_deb_val numeric(23,8),
    turn_deb_total numeric(23,8),
    turn_cre_rub numeric(23,8),
    turn_cre_val numeric(23,8),
    turn_cre_total numeric(23,8),
    balance_out_rub numeric(23,8),
    balance_out_val numeric(23,8),
    balance_out_total numeric(23,8)
);



create or replace procedure dm.fill_f101_round_f(i_ondate date)
language plpgsql
as $$
declare
    v_start_date date;
    v_end_date date;
    v_prev_date date;
    v_start_time timestamp;
    v_log_id integer;
    v_rows_loaded integer;
begin
    v_start_time := now();
    
    v_end_date := i_ondate - 1;
    v_start_date := date_trunc('month', v_end_date)::date;
    v_prev_date := v_start_date - 1;
    
    insert into logs.etl_log (table_name, start_time, status, file_name)
    values ('dm.dm_f101_round_f', v_start_time, 'STARTED', 'procedure')
    returning log_id into v_log_id;
    
    delete from dm.dm_f101_round_f 
    where from_date = v_start_date and to_date = v_end_date;
    
    insert into dm.dm_f101_round_f
    with 
    account_second_order as (
        select 
            a.account_rk,
            left(a.account_number, 5) as ledger_account,
            a.char_type as characteristic,
            a.currency_rk,
            l.chapter
        from ds.md_account_d a
        left join ds.md_ledger_account_s l on left(a.account_number, 5) = l.ledger_account::char(5)
            and v_start_date between l.start_date and coalesce(l.end_date, '2050-12-31')
        where v_start_date between a.data_actual_date and coalesce(a.data_actual_end_date, '2050-12-31')
    ),
    balance_start as (
        select account_rk, balance_out_rub
        from dm.dm_account_balance_f
        where on_date = v_prev_date
    ),
    balance_end as (
        select account_rk, balance_out_rub
        from dm.dm_account_balance_f
        where on_date = v_end_date
    ),
    turnovers as (
        select 
            account_rk,
            sum(debet_amount_rub) as debet_rub,
            sum(credit_amount_rub) as credit_rub
        from dm.dm_account_turnover_f
        where on_date between v_start_date and v_end_date
        group by account_rk
    )
    select 
        v_start_date as from_date,
        v_end_date as to_date,
        a.chapter,
        a.ledger_account,
        a.characteristic,
        round(coalesce(sum(case when a.currency_rk = 34 then b_start.balance_out_rub else 0 end), 0), 2) as balance_in_rub,
        round(coalesce(sum(case when a.currency_rk != 34 then b_start.balance_out_rub else 0 end), 0), 2) as balance_in_val,
        round(coalesce(sum(b_start.balance_out_rub), 0), 2) as balance_in_total,
        round(coalesce(sum(case when a.currency_rk = 34 then t.debet_rub else 0 end), 0), 2) as turn_deb_rub,
        round(coalesce(sum(case when a.currency_rk != 34 then t.debet_rub else 0 end), 0), 2) as turn_deb_val,
        round(coalesce(sum(t.debet_rub), 0), 2) as turn_deb_total,
        round(coalesce(sum(case when a.currency_rk = 34 then t.credit_rub else 0 end), 0), 2) as turn_cre_rub,
        round(coalesce(sum(case when a.currency_rk != 34 then t.credit_rub else 0 end), 0), 2) as turn_cre_val,
        round(coalesce(sum(t.credit_rub), 0), 2) as turn_cre_total,
        round(coalesce(sum(case when a.currency_rk = 34 then b_end.balance_out_rub else 0 end), 0), 2) as balance_out_rub,
        round(coalesce(sum(case when a.currency_rk != 34 then b_end.balance_out_rub else 0 end), 0), 2) as balance_out_val,
        round(coalesce(sum(b_end.balance_out_rub), 0), 2) as balance_out_total
    from account_second_order a
    left join balance_start b_start on a.account_rk = b_start.account_rk
    left join balance_end b_end on a.account_rk = b_end.account_rk
    left join turnovers t on a.account_rk = t.account_rk
    group by a.chapter, a.ledger_account, a.characteristic
    order by a.chapter, a.ledger_account;
    
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






































