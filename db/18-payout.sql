/* ═══════════════════════════════════════════════════════════════════════
   db/18-payout.sql  ——  第 40 步：GT 教練鐘點費月報表

   規則來源：HANDOVER 附錄四第 1 節（Jerec 2026-08-08 口述，當場驗算 10/10 相符）

       payout(0) = 0          未開課
       payout(1) = 200
       payout(n) = 200 + 100n （n ≥ 2）

   ☢️ n 是【實到人數】，不是報名人數。
      所以這張報表的正確性完全建立在第 39 步的點名紀律上 ——
      漏點一個人，教練就少領 100 元。

   這支檔案只建函式和檢視表，不寫任何資料，不需要保險絲。
   ═══════════════════════════════════════════════════════════════════════ */


/* ── 1  公式 ────────────────────────────────────────────────────────
   寫成函式而不是散在查詢裡：規則只有一份，改的時候只改一個地方。
   immutable 讓 Postgres 可以放心快取結果。
   ────────────────────────────────────────────────────────────────── */

create or replace function public.gt_payout(n integer)
returns integer
language sql
immutable
as $$
  select case
           when n is null or n <= 0 then 0
           when n = 1               then 200
           else 200 + 100 * n
         end;
$$;


/* ── 2  是不是老闆 ──────────────────────────────────────────────────
   薪資是敏感資料：教練只該看得到自己的，老闆看得到全部。
   is_staff() 在這裡不夠用 —— 它會讓 Peter 看到 VC 領多少。
   ────────────────────────────────────────────────────────────────── */

create or replace function public.is_owner()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (select 1 from public.employees
                  where auth_user_id = auth.uid()
                    and role = 'owner'
                    and is_active = true);
$$;


/* ── 3  每一堂的明細 ────────────────────────────────────────────────

   ☢️ 這一行就是牆：
       (public.is_owner() or s.coach_id = public.my_employee_id())

   ⚠️ 計算依據是【實際點名結果】，不是 class_sessions.status。
      搬遷進來的資料裡有「課次是 cancelled、但有人 attended」的組合
      （那幾天 app_settings.live 還是 false，午夜排程照規則取消了課，
       隔天資料才搬進來）。人既然上了課，教練就是帶了那一堂。
      切換日之後不會再出現這種組合 —— check_in() 擋掉已取消的課。
   ────────────────────────────────────────────────────────────────── */

create or replace view public.gt_payout_sessions as
select
  s.id                                        as session_id,
  to_char(s.session_date, 'YYYY-MM')          as ym,
  s.session_date,
  s.start_time,
  s.title,
  s.coach_id,
  coalesce(e.display_name, '（未指定教練）')     as coach_name,
  s.status                                    as session_status,
  count(b.id) filter (where b.status = 'attended') as n_present,
  count(b.id) filter (where b.status = 'booked')   as n_pending,
  public.gt_payout(count(b.id) filter (where b.status = 'attended')::int) as payout
from public.class_sessions s
left join public.employees e on e.id = s.coach_id
left join public.bookings  b on b.session_id = s.id
where s.product = 'GT'
  and (public.is_owner() or s.coach_id = public.my_employee_id())
group by s.id, e.display_name
having count(b.id) filter (where b.status = 'attended') > 0
    or count(b.id) filter (where b.status = 'booked')   > 0;


/* ── 4  月彙總 ──────────────────────────────────────────────────────

   ☢️「還沒點名的課次」這一欄是整張報表的良心。

      不是 0 → 這個月還沒點完 → 上面那個「鐘點費合計」是【少算的】，
      不能拿去發薪水。

      沒有這一欄的話，一張少算 1100 元的報表和一張正確的報表，
      在畫面上長得一模一樣。
   ────────────────────────────────────────────────────────────────── */

create or replace view public.coach_monthly_payout as
select
  ym,
  coach_id,
  coach_name,
  count(*) filter (where n_present > 0) as 開成的堂數,
  sum(n_present)                        as 總人次,
  sum(payout)                           as 鐘點費合計,
  count(*) filter (where n_pending > 0) as 還沒點名的課次
from public.gt_payout_sessions
group by ym, coach_id, coach_name;


/* ── 5  開權限 ──────────────────────────────────────────────────── */

grant select  on public.gt_payout_sessions   to authenticated;
grant select  on public.coach_monthly_payout to authenticated;
grant execute on function public.gt_payout(integer) to authenticated;
grant execute on function public.is_owner()         to authenticated;


/* ── 6  驗收 ────────────────────────────────────────────────────────

   6-1 公式對照附錄四那張表（0～10 人）
   ────────────────────────────────────────────────────────────────── */

select n as 實到人數,
       public.gt_payout(n) as 算出來的,
       (array[0,200,400,500,600,700,800,900,1000,1100,1200])[n+1] as 附錄四寫的,
       case when public.gt_payout(n)
               = (array[0,200,400,500,600,700,800,900,1000,1100,1200])[n+1]
            then '✓' else '☢️ 不一樣' end as 對不對
from generate_series(0,10) as n;
-- 期望：11 列全部 ✓


/* 6-2 ☢️ 直接查這兩張表會拿到 0 列，那是【正確的】——
       第 3 節那一行 is_owner() / my_employee_id() 對所有人生效，
       包括 SQL Editor 裡的 postgres（那個身分沒有 auth.uid()）。
       要看到東西，先假裝成 Jerec：                                    */

begin;
  select set_config('request.jwt.claims',
         json_build_object('sub', (select auth_user_id from public.employees
                                    where display_name = 'Jerec'),
                           'role','authenticated')::text, true) is not null as 已切換身分;
  set local role authenticated;

  select ym as 月份, coach_name as 教練,
         開成的堂數, 總人次, 鐘點費合計, 還沒點名的課次
  from public.coach_monthly_payout
  order by ym, coach_name;
rollback;
-- 期望：看得到全部教練（老闆身分）。
--       「（未指定教練）」那幾列是搬遷進來的歷史課次，見下面的說明。


/* ── 7  ☢️ 兩件要知道的事 ──────────────────────────────────────────

   ① 搬遷進來的課次【沒有教練】。
      2026-08-03～08-06 那 9 堂（＋ 7 月的 2 堂）的 coach_id 是 null，
      所以合計 4,800 元掛在「（未指定教練）」底下。
      搬遷工具把 LessonInstances 轉成 class_sessions 時沒有帶教練。

      這不需要修：那段期間的鐘點費【已經用舊系統發過了】。
      切換日之後的課次都是 pg_cron 從 class_templates 產生的，
      而範本上有 coach_id —— 那些才是這張報表真正要算的。

      ⚠️ 但切換日當天會【再匯入一次】歷史課次，一樣不會有教練。
         發薪水時「（未指定教練）」那一列直接略過。

   ② 教練看得到的只有自己。
      實測：Peter 的身分查 gt_payout_sessions 只回自己帶的課，
      月報只有一列，看不到任何其他人的金額。
   ────────────────────────────────────────────────────────────────── */
