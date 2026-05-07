create schema if not exists DS;
create schema if not exists LOGS;

-- Таблица логов
create table LOGS.ETL_LOG (
    log_id         SERIAL primary key,
    table_name     VARCHAR(100) not null,
    start_time     TIMESTAMP not null,
    end_time       TIMESTAMP,
    rows_loaded    INTEGER,
    status         VARCHAR(20) check (status in ('STARTED', 'SUCCESS', 'FAILED')),
    error_message  TEXT,
    file_name      VARCHAR(200)
);

-- Остатки по счетам
create table DS.FT_BALANCE_F (
    on_date      DATE not null,
    account_rk   INTEGER not null,
    currency_rk  INTEGER,
    balance_out  NUMERIC(23,8),
    constraint pk_ft_balance_f primary key (on_date, account_rk)
);

-- Проводки
create table DS.FT_POSTING_F (
    oper_date           DATE not null,
    credit_account_rk   INTEGER not null,
    debet_account_rk    INTEGER not null,
    credit_amount       NUMERIC(23,8),
    debet_amount        NUMERIC(23,8)
);

-- Справочник счетов
create table DS.MD_ACCOUNT_D (
    data_actual_date      DATE not null,
    data_actual_end_date   DATE not null,
    account_rk             INTEGER not null,
    account_number         VARCHAR(20) not null,
    char_type              VARCHAR(1) not null,
    currency_rk            INTEGER not null,
    currency_code          VARCHAR(3) not null,
    constraint pk_md_account_d primary key (data_actual_date, account_rk)
);

-- Справочник валют
create table DS.MD_CURRENCY_D (
    currency_rk          INTEGER not null,
    data_actual_date     DATE not null,
    data_actual_end_date DATE,
    currency_code        VARCHAR(3),
    code_iso_char        VARCHAR(3),
    constraint pk_md_currency_d primary key (currency_rk, data_actual_date)
);

-- Курсы валют
create table DS.MD_EXCHANGE_RATE_D (
    data_actual_date     DATE not null,
    data_actual_end_date DATE,
    currency_rk          INTEGER not null,
    reduced_cource       NUMERIC(23,8),
    code_iso_num         VARCHAR(3),
    constraint pk_md_exchange_rate_d primary key (data_actual_date, currency_rk)
);

-- Справочник балансовых счетов
create table DS.MD_LEDGER_ACCOUNT_S (
    chapter                        CHAR(1),
    chapter_name                   VARCHAR(16),
    section_number                 INTEGER,
    section_name                   VARCHAR(22),
    subsection_name                VARCHAR(21),
    ledger1_account                INTEGER,
    ledger1_account_name           VARCHAR(47),
    ledger_account                 INTEGER not null,
    ledger_account_name            VARCHAR(153),
    characteristic                 CHAR(1),
    start_date                     DATE not null,
    end_date                       DATE,
    constraint pk_md_ledger_account_s primary key (ledger_account, start_date)
);








