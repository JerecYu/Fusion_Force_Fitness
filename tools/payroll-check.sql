-- 薪資驗收：在 Supabase SQL Editor 裡貼一段、按 Run
--
-- ☢️ 為什麼每一段開頭都有那五行「假裝成 Jerec」
--
-- payroll_month() 第一件事就是問「你是不是負責人或財務」。它問的方式是
-- auth.uid() —— 也就是「現在登入的那個人是誰」。
--
-- SQL Editor 沒有登入任何人。它是用資料庫最高權限 postgres 直接連進去的，
-- auth.uid() 是空的。所以直接跑會被自己的函式擋下來：
--
--     ERROR: 薪資報表只有負責人和財務看得到
--
-- 這不是壞掉，是「牆真的在資料庫裡」的證明 —— 就算拿到最高權限的連線，
-- 不表明身分一樣看不到。那五行的作用是「告訴這一次連線：我是 Jerec」，
-- 只在這一次執行有效，Run 完就沒了。
--
-- ☢️ set local role authenticated 那一行也不能省。
--    只設身分不換角色的話，跑的還是 postgres —— postgres 會繞過所有 RLS，
--    等於在測一個一般人永遠碰不到的情境。換成 authenticated 才是客人與教練
--    真正走的那條路。

-- ═══════════════════════════════════════════════════════════════
-- ① 每人小計（主要驗收）
-- ═══════════════════════════════════════════════════════════════
do $$
declare v uuid;
begin
  select auth_user_id into v from public.employees where display_name = 'Jerec';
  perform set_config('request.jwt.claims',
                     json_build_object('sub', v, 'role', 'authenticated')::text, true);
end $$;
set local role authenticated;

with r as (select public.payroll_month('2026-08-01') as j)
select x->>'coach_name'                as 教練,
       (x->>'perf')::int               as 抽成業績,
       (x->>'gt')::int                 as gt鐘點費,
       (x->>'event')::int              as 活動鐘點費,
       (x->>'allowance')::int          as 固定加給,
       (x->>'total')::int              as 合計,
       (x->>'gt_classes')::int         as gt堂數,
       (x->>'gt_heads')::int           as gt人次,
       jsonb_array_length(j->'holds')  as 待處理,
       jsonb_array_length(j->'warns')  as 提醒
from r, jsonb_array_elements(j->'rows') x
order by 合計 desc;


-- ═══════════════════════════════════════════════════════════════
-- ② 逐筆明細（想知道某個數字怎麼來的就跑這段）
-- ═══════════════════════════════════════════════════════════════
do $$
declare v uuid;
begin
  select auth_user_id into v from public.employees where display_name = 'Jerec';
  perform set_config('request.jwt.claims',
                     json_build_object('sub', v, 'role', 'authenticated')::text, true);
end $$;
set local role authenticated;

select coach_name as 教練,
       case kind when 'perf'  then '抽成業績'
                 when 'gt'    then 'GT 鐘點費'
                 when 'event' then '活動鐘點費'
                 else              '固定加給' end                        as 類別,
       to_char(done_at at time zone 'Asia/Taipei', 'MM/DD HH24:MI')      as 完成時間,
       label                                                             as 項目,
       qty                                                               as 人數或天數,
       base                                                              as 基礎,
       rate                                                              as 費率,
       round(amount, 4)                                                  as 金額,
       case when hold then '☢️ 暫停自動計薪' else '' end                  as 狀態,
       hold_why                                                          as 為什麼暫停
from public.payroll_lines('2026-08-01')
order by 教練, done_at;


-- ═══════════════════════════════════════════════════════════════
-- ③ 待處理與提醒的內容（①的最後兩欄不是 0 才需要跑）
-- ═══════════════════════════════════════════════════════════════
do $$
declare v uuid;
begin
  select auth_user_id into v from public.employees where display_name = 'Jerec';
  perform set_config('request.jwt.claims',
                     json_build_object('sub', v, 'role', 'authenticated')::text, true);
end $$;
set local role authenticated;

select '待處理' as 種類, jsonb_pretty(public.payroll_month('2026-08-01')->'holds') as 內容
union all
select '提醒',          jsonb_pretty(public.payroll_month('2026-08-01')->'warns');


-- ═══════════════════════════════════════════════════════════════
-- ④ 獨立重算 GT 鐘點費（不用 gt_payout()，直接查規則文件表 15）
-- ═══════════════════════════════════════════════════════════════
-- 這一段不用假裝身分 —— 它不呼叫薪資函式，是從最原始的資料自己算一遍。
-- 「差」這一欄如果不是全部 0，就是 gt_payout() 跟規則文件對不起來。

with t15(n, fee) as (values (0,0),(1,200),(2,400),(3,500),(4,600),(5,700),(6,800),
                            (7,900),(8,1000),(9,1100),(10,1200),(11,1300),(12,1400)),
g as (
  select s.id, e.display_name as coach,
         coalesce(sum(b.attendee_count) filter (where b.status = 'attended'), 0)::int as n
  from public.class_sessions s
  join public.employees e on e.id = s.coach_id
  left join public.bookings b on b.session_id = s.id
  where s.product = 'GT'
    and s.session_date between date '2026-08-01' and date '2026-08-31'
  group by s.id, e.display_name)
select g.coach                              as 教練,
       count(*) filter (where g.n > 0)      as 有人上的堂數,
       sum(g.n)                             as 人次,
       sum(t15.fee)                         as 表15重算,
       sum(public.gt_payout(g.n))           as 函式算的,
       sum(t15.fee) - sum(public.gt_payout(g.n)) as 差
from g join t15 on t15.n = g.n
group by g.coach
order by 表15重算 desc;
