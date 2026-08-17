-- ═══════════════════════════════════════════════════════════════
--  25-fix-view-security.sql  ·  修掉我自己弄壞的三張檢視表
--  2026-08-17
--
--  ☢️ 這是一次真正的線上故障，不是預防性修補。
--     現場症狀：教練點進課次名單 → 「讀不到名單　permission denied
--     for table class_sessions」。
--
--  ── 我做錯了什麼 ────────────────────────────────────────────
--  我在 19、20、23、24 這四支裡，把檢視表寫成
--      create or replace view ... with (security_invoker = true)
--  但 `pg_get_viewdef()` 【不會顯示這個選項】。我抄舊定義的時候
--  只抄到 SELECT 的部分，看不到原本沒有這一行，就自己加了上去。
--
--  加上去的後果：檢視表改成「用查詢者的身分」去讀底下的資料表。
--  而 authenticated 對 class_sessions 和 credit_ledger 【故意沒有
--  SELECT 權限】（第 33 步就是這樣設計的）——所以整張表讀不到。
--
--  ☢️ 這幾張檢視表本來就【必須】是 definer：
--     它們的安全牆是自己 where 裡那一行（my_customer_id() / is_staff()），
--     不是底層資料表的權限。用 definer 的身分讀 class_sessions、
--     然後只回傳該給的那幾列 —— 這正是 13-booking.sql 第 187 行
--     寫下來的原話：「它用 definer 身分讀 class_sessions（客人自己讀不到）」。
--
--  ☢️ 而且 17-checkin.sql 的驗收清單第 7-4 條【早就寫著】：
--        staff_sessions / staff_roster 兩列都必須是 definer ✓
--     我自己寫的檢查，自己違反，而且沒有回頭跑那份清單。
--
--  ── 為什麼沒有當場發現 ──────────────────────────────────────
--  ☢️ 因為錯誤被前端吞掉了。
--     GT-booking 的「我的預約」：`if (b.error) console.error(...)`
--     —— 錯誤只進了主控台，畫面上 myBookings 還是空陣列，
--     結果長得跟「你沒有任何預約」一模一樣。
--     checkin 的逾期清單更徹底：整段 catch 掉、設成空陣列。
--
--     所以 my_bookings 從 8/16 晚上（19-attest.sql）就壞了，
--     一直到 8/17 下午教練踩到 staff_roster 才被發現。
--     這一支修資料庫，同一批的前端改動把這兩個地方改成【會出聲】。
--     （規則 14：不要吞掉錯誤。這次是被自己的例外咬到。）
-- ═══════════════════════════════════════════════════════════════

-- ── 修正 ──────────────────────────────────────────────────────
--  reset 是拿掉這個選項，回到「沒有寫」的狀態 —— 跟原本一模一樣。
--  不要寫成 set (security_invoker = false)：值一樣，但 reloptions
--  會留下一行字，之後查「有沒有被動過」的時候會誤判。
alter view public.my_bookings      reset (security_invoker);
alter view public.staff_roster     reset (security_invoker);
alter view public.overdue_checkins reset (security_invoker);

-- ── 驗收 ①：四張檢視表都必須是 definer ────────────────────────
select c.relname as 檢視表,
       case when coalesce(c.reloptions::text,'') like '%security_invoker=true%'
            then 'invoker ☢️ 不對' else 'definer ✓' end as 模式
from pg_class c join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public' and c.relkind = 'v'
  and c.relname in ('my_bookings','staff_roster','staff_sessions','overdue_checkins')
order by c.relname;
-- 期望：四列都是 definer ✓

-- ── 驗收 ②：authenticated 真的讀得到了 ────────────────────────
do $$
declare msg text := '';
begin
  set local role authenticated;
  begin perform count(*) from public.my_bookings;      msg := msg || 'my_bookings ✓　';
  exception when others then msg := msg || 'my_bookings ☢️ ' || sqlerrm || '　'; end;
  begin perform count(*) from public.staff_roster;     msg := msg || 'staff_roster ✓　';
  exception when others then msg := msg || 'staff_roster ☢️ ' || sqlerrm || '　'; end;
  begin perform count(*) from public.staff_sessions;   msg := msg || 'staff_sessions ✓　';
  exception when others then msg := msg || 'staff_sessions ☢️ ' || sqlerrm || '　'; end;
  begin perform count(*) from public.overdue_checkins; msg := msg || 'overdue_checkins ✓';
  exception when others then msg := msg || 'overdue_checkins ☢️ ' || sqlerrm; end;
  reset role;
  raise notice '%', msg;
end $$;

-- ── 驗收 ③：☢️ 最重要的一條 ───────────────────────────────────
--  definer 會繞過 RLS，所以檢視表自己的 where 就是【唯一】那道牆。
--  改完一定要重驗：一般客人看不看得到不該看的東西。
do $$
declare v_auth uuid; v_cust uuid; wrong int; n_r int; n_s int; n_od int;
begin
  select c.id, c.auth_user_id into v_cust, v_auth
  from public.customers c join public.bookings b on b.customer_id = c.id
  where c.auth_user_id is not null
    and not exists (select 1 from public.employees e where e.auth_user_id = c.auth_user_id)
  limit 1;

  perform set_config('request.jwt.claims',
    json_build_object('sub', v_auth, 'role', 'authenticated')::text, true);
  set local role authenticated;

  select count(*) into wrong from public.my_bookings mb
    join public.bookings b on b.id = mb.id where b.customer_id <> v_cust;
  select count(*) into n_r  from public.staff_roster;
  select count(*) into n_s  from public.staff_sessions;
  select count(*) into n_od from public.overdue_checkins;
  reset role;

  raise notice '一般客人：my_bookings 混到別人的 % 列（要 0）／staff_roster % 列（要 0）／staff_sessions % 列（要 0）／overdue % 列（要 0）',
    wrong, n_r, n_s, n_od;
end $$;
-- 2026-08-17 實測：0 / 0 / 0 / 0，教練身分則讀得到 63 / 20 列。
