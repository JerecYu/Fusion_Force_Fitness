-- 抽成累進的數學檢查（五個情境，全程 rollback 不留資料）
--
-- ☢️ 為什麼要獨立一支：累進分段是整套薪資裡【最容易錯、也最難事後發現】的部分。
--    算錯的金額看起來永遠是「合理的」—— 不是一個明顯的錯數字。
--    改過 payroll_lines、coach_grade_on、或抽成級距之後，重跑這一支。
--
-- ☢️ 最後一行是故意 raise exception —— 那是唯一能同時「拿到結果」又
--    「保證整批回捲」的寫法。看到紅色的錯誤訊息才是正常的，訊息本身就是答案。
--
-- ☢️ 測試月份用 2099-01，不是「下個月」。用真實月份的話，等到系統裡開始
--    有真的服務紀錄，這支就會把真資料一起加進來算，然後永遠說「☢️錯」。
--    另外每一個 select 都加了 coach_id = v_coach，只看測試對象那一位。
--
-- ☢️ 教練、客人、財務帳號都是「隨便挑一個」，不寫名字 —— 這個 repo 是公開的，
--    而且寫死名字的話那個人離職就壞了。
--
-- 規則第五篇 2 的兩個官方範例：
--    主管    90,000 ＝ 80,000 × 45% ＋ 10,000 × 50% ＝ 41,000
--    一般教練 90,000 ＝ 80,000 × 40% ＋ 10,000 × 50% ＝ 37,000

do $$
declare
  v_coach uuid; v_cust uuid; v_uid uuid; v_id uuid;
  v_got numeric; out_txt text := '';
begin
  select id into v_coach from employees where is_active order by id limit 1;
  select id into v_cust  from customers order by id limit 1;
  select auth_user_id into v_uid from employees
   where is_active and can_finance and auth_user_id is not null order by id limit 1;
  if v_coach is null or v_cust is null or v_uid is null then
    raise exception '找不到可用的教練／客人／財務帳號，這支檢查沒辦法跑';
  end if;

  -- payroll_lines 要 is_finance()，SQL Editor 沒有 auth.uid()，先冒充一位財務
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_uid, 'role','authenticated')::text, true);

  -- ☢️ 借來的這位教練可能本來就有職級紀錄，先清掉（一樣會回捲），
  --    不然情境 A 會被他原本的職級影響。
  delete from coach_grades where employee_id = v_coach;

  -- A：一般教練，單筆 90,000
  insert into service_records (service_type, done_at, customer_id, headcount, charge_method,
    revenue_amount, travel_fee, perf_amount, fin_status)
  values ('PT','2099-01-05 10:00+08', v_cust, 1,'single', 90000,0,90000,'final') returning id into v_id;
  insert into service_coaches (service_id, coach_id, is_lead) values (v_id, v_coach, true);
  select coalesce(sum(amount),0) into v_got
    from payroll_lines('2099-01-01') where kind='perf' and coach_id = v_coach;
  out_txt := out_txt || format('A 一般 90000 一筆 => %s (應 37000) %s | ', v_got,
    case when v_got = 37000 then 'OK' else '☢️錯' end);

  -- B：同樣業績，職級改主管
  insert into coach_grades (employee_id, grade, effective_from) values (v_coach,'supervisor','2099-01-01');
  select coalesce(sum(amount),0) into v_got
    from payroll_lines('2099-01-01') where kind='perf' and coach_id = v_coach;
  out_txt := out_txt || format('B 主管 90000 一筆 => %s (應 41000) %s | ', v_got,
    case when v_got = 41000 then 'OK' else '☢️錯' end);

  -- C：拆成三筆 30000。☢️ 總額一樣，抽成就必須一樣 ——
  --    不一樣的話代表累進是「每筆各自從 0 開始算」，那是最典型的錯法。
  delete from service_coaches where service_id = v_id;
  delete from service_records where id = v_id;
  for i in 1..3 loop
    insert into service_records (service_type, done_at, customer_id, headcount, charge_method,
      revenue_amount, travel_fee, perf_amount, fin_status)
    values ('PT', ('2099-01-0'||i||' 10:00+08')::timestamptz, v_cust,1,'single',30000,0,30000,'final')
    returning id into v_id;
    insert into service_coaches (service_id, coach_id, is_lead) values (v_id, v_coach, true);
  end loop;
  select coalesce(sum(amount),0) into v_got
    from payroll_lines('2099-01-01') where kind='perf' and coach_id = v_coach;
  out_txt := out_txt || format('C 主管 30000x3 => %s (應 41000) %s | ', v_got,
    case when v_got = 41000 then 'OK' else '☢️錯' end);

  -- D：職級 01/10 才生效。☢️ 生效日之前的業績要用舊職級 ——
  --    規則第五篇 2：「以生效日前後的實際業績分段套用相應比例。」
  delete from coach_grades where employee_id = v_coach;
  insert into coach_grades (employee_id, grade, effective_from) values (v_coach,'supervisor','2099-01-10');
  delete from service_coaches where service_id in (select id from service_records where done_at >= '2099-01-01');
  delete from service_records where done_at >= '2099-01-01';
  insert into service_records (service_type, done_at, customer_id, headcount, charge_method,
    revenue_amount, travel_fee, perf_amount, fin_status)
  values ('PT','2099-01-05 10:00+08', v_cust,1,'single',40000,0,40000,'final') returning id into v_id;
  insert into service_coaches (service_id, coach_id, is_lead) values (v_id, v_coach, true);
  insert into service_records (service_type, done_at, customer_id, headcount, charge_method,
    revenue_amount, travel_fee, perf_amount, fin_status)
  values ('PT','2099-01-20 10:00+08', v_cust,1,'single',50000,0,50000,'final') returning id into v_id;
  insert into service_coaches (service_id, coach_id, is_lead) values (v_id, v_coach, true);
  -- 01/05：40000 × 40% ＝ 16000
  -- 01/20：門檻還剩 40000 × 45% ＝ 18000，超過的 10000 × 50% ＝ 5000
  select coalesce(sum(amount),0) into v_got
    from payroll_lines('2099-01-01') where kind='perf' and coach_id = v_coach;
  out_txt := out_txt || format('D 月中升職 40000+50000 => %s (應 39000) %s | ', v_got,
    case when v_got = 39000 then 'OK' else '☢️錯' end);

  -- E：還沒財務最終認列的一律不算（規則第六篇 6）
  update service_records set fin_status = 'pending' where done_at >= '2099-01-01';
  select coalesce(sum(amount),0) into v_got
    from payroll_lines('2099-01-01') where kind='perf' and coach_id = v_coach;
  out_txt := out_txt || format('E 待確認 => %s (應 0) %s', v_got,
    case when v_got = 0 then 'OK' else '☢️錯' end);

  raise exception '%', out_txt;   -- ☢️ 故意的：唯一能同時拿到結果又保證回捲的寫法
end $$;

-- 2026-08-20 實測結果（五項全過）：
--   A 一般 90000 一筆 => 37000.00 OK
--   B 主管 90000 一筆 => 41000.00 OK
--   C 主管 30000x3   => 41000.00 OK
--   D 月中升職        => 39000.00 OK
--   E 待確認          => 0        OK
