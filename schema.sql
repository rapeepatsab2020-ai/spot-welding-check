-- ============================================================
-- Spot Welding Check System - Supabase Schema
-- Project: spot-welding-check
-- ============================================================

-- 1) MASTER: เครื่องจักร + part ที่ผูกกับ JIG/Model
create table spot_machines (
  id           bigint generated always as identity primary key,
  machine_no   text not null,        -- เช่น RB168
  model        text,                 -- เช่น RG01
  part_no      text not null,        -- เช่น 898385 7902
  part_name    text not null,        -- เช่น SILL; ASM FLOOR RR
  rank         text,                 -- เช่น U
  doc_no       text,
  rev_no       text,
  rev_date     date,
  run_no       text,
  issue_form   date,
  is_active    boolean default true,
  created_at   timestamptz default now()
);

-- 2) MASTER: ค่ามาตรฐาน (STD) ต่อ SERVO GUN (#1 / #2) ของแต่ละเครื่อง
create table spot_gun_std (
  id               bigint generated always as identity primary key,
  machine_id       bigint references spot_machines(id) on delete cascade,
  gun_no           int not null,          -- 1 หรือ 2
  squeeze_time     numeric, squeeze_tol     numeric,  -- SQUZTIME (Sec.) ±
  slope            numeric, slope_tol       numeric,  -- SLOPE (CYC) ±
  weldtime         numeric, weldtime_tol    numeric,  -- WELDTIME (Sec.) ±
  hold_time        numeric, hold_time_tol   numeric,  -- HOLD TIME (Sec.) ±
  weld_current     numeric, weld_current_tol numeric, -- WELD CURRENT (kA) ±
  tip_force        numeric, tip_force_tol   numeric,  -- TIP FORCE (kN) ±
  tip_size         numeric,                           -- TIP (mm.) ไม่มี tolerance
  created_at       timestamptz default now(),
  unique(machine_id, gun_no)
);

-- 3) หัวใบตรวจสอบ 1 รอบ (แทน 1 บล็อก "Date ;" ในกระดาษ)
create table spot_records (
  id              bigint generated always as identity primary key,
  machine_id      bigint references spot_machines(id),
  record_date     date not null default current_date,
  inspector_name  text,
  shift           text,               -- เช้า/บ่าย/ดึก (ถ้ามี)
  total_quantity  int,
  status          text default 'draft', -- draft / submitted
  created_at      timestamptz default now()
);

-- 4) ค่าจริงที่วัดได้ (ACT) ต่อ gun ต่อ record
create table spot_gun_actual (
  id                bigint generated always as identity primary key,
  record_id         bigint references spot_records(id) on delete cascade,
  gun_no            int not null,
  act_squeeze_time  numeric,
  act_slope         numeric,
  act_weldtime      numeric,
  act_hold_time     numeric,
  act_weld_current  numeric,
  act_tip_force     numeric,
  act_tip_size      numeric
);

-- 5) Driver Check grid (pallet 1-35, ✓ ติดแน่น / X ไม่ติด)
create table spot_driver_check (
  id          bigint generated always as identity primary key,
  record_id   bigint references spot_records(id) on delete cascade,
  pallet_no   int not null,
  result      text,          -- 'O' = ติดแน่น, 'X' = ไม่ติด
  unique(record_id, pallet_no)
);

-- 6) Nugget Test (จุด A1, A2, B x Start/Middle/End, มาตรฐาน >= 4.2 mm.)
create table spot_nugget_test (
  id          bigint generated always as identity primary key,
  record_id   bigint references spot_records(id) on delete cascade,
  point       text not null,       -- 'A1' | 'A2' | 'B'
  start_val   numeric,
  middle_val  numeric,
  end_val     numeric,
  threshold   numeric default 4.2,
  result      text,                -- 'PASS' / 'FAIL' (คำนวณอัตโนมัติ)
  unique(record_id, point)
);

-- ============================================================
-- Row Level Security (internal tool = allow all ผ่าน anon key)
-- ============================================================
alter table spot_machines     enable row level security;
alter table spot_gun_std      enable row level security;
alter table spot_records      enable row level security;
alter table spot_gun_actual   enable row level security;
alter table spot_driver_check enable row level security;
alter table spot_nugget_test  enable row level security;

create policy "allow all" on spot_machines     for all using (true) with check (true);
create policy "allow all" on spot_gun_std      for all using (true) with check (true);
create policy "allow all" on spot_records      for all using (true) with check (true);
create policy "allow all" on spot_gun_actual   for all using (true) with check (true);
create policy "allow all" on spot_driver_check for all using (true) with check (true);
create policy "allow all" on spot_nugget_test  for all using (true) with check (true);

-- ============================================================
-- Seed ตัวอย่าง: ใส่เครื่อง RB168 + STD ตามเอกสารที่พี่บีส่งมา
-- ============================================================
insert into spot_machines (machine_no, model, part_no, part_name, rank, doc_no, rev_no, rev_date, run_no, issue_form)
values ('RB168', 'RG01', '898385 7902', 'SILL; ASM FLOOR RR', 'U', 'QA4-2-016', '3', '2024-11-15', 'SWC-RG01-028', '2014-11-10')
returning id;

-- หมายเหตุ: เอา id ที่ได้จากด้านบนไปแทนที่ :machine_id ด้านล่าง แล้วรันต่อ
-- insert into spot_gun_std (machine_id, gun_no, squeeze_time, squeeze_tol, slope, slope_tol, weldtime, weldtime_tol, hold_time, hold_time_tol, weld_current, weld_current_tol, tip_force, tip_force_tol, tip_size)
-- values
-- (:machine_id, 1, 30, 2, 3, 0, 5.0, 2, 20, 2, 4.5, 0.45, 5.0, 0.5, 16),
-- (:machine_id, 2, 30, 2, 1, 0, 25, 2, 20, 2, 8.5, 0.85, 5.0, 0.5, 16);
