-- ═══════════════════════════════════════════════════════════
-- 10-public-views.sql
-- 公開課表檢視表 — 對外唯一開的那扇窗
-- 2026-08-08　建立
-- 2026-08-09　加上 where s.product = 'GT'（第 24 步）
--
-- 這一支不塞任何資料，所以不需要保險絲。
-- create or replace 可以安全重複執行，跑幾次結果都一樣。
-- ═══════════════════════════════════════════════════════════

create or replace view public.public_schedule as
select
  x.session_id,
  x.session_date,
  x.start_time,
  x.duration_min,
  x.title,
  x.level,
  x.coach_name,
  x.capacity,
  x.booked_count,
  greatest(x.capacity - x.booked_count, 0)::int as seats_left,
  (x.booked_count >= x.capacity)                as is_full,
  x.status
from (
  select
    s.id            as session_id,
    s.session_date,
    s.start_time,
    s.duration_min,
    s.title,
    s.level,
    -- 只拿 display_name。name / phone / email / auth_user_id 一律不出去
    e.display_name  as coach_name,
    s.capacity,
    -- 人數用「沒有取消時間」來數，不猜 status 存什麼字
    (select count(*)
       from public.bookings bk
      where bk.session_id = s.id
        and bk.cancelled_at is null)::int as booked_count,
    s.status
  from public.class_sessions s
  -- ⚠️ 一定要 left join：coach_id 可以留空，
  --    用一般 join 的話「還沒指定教練」的課會整堂從課表消失
  left join public.employees e
    on e.id = s.coach_id
  -- ☢️ 這一行是一道牆，不是一個篩選條件。
  --    class_sessions 裡面會有 PT／PGT／RT —— 場地要排班，它們一定得進這張表。
  --    少了這一行，「週二 14:00 私人課 · 王小姐」就會出現在官網課表上，
  --    而且不會報錯、不會有人通知你。
  --    新增商品別的時候，預設是「不給看」，要公開才明確加進來。
  where s.product = 'GT'
) x;


-- ── 門禁：先全部關死，再只開一條縫 ──
revoke all on public.public_schedule from public, anon, authenticated;
grant  select on public.public_schedule to anon, authenticated;

comment on view public.public_schedule is
  '公開課表。對外唯一開放讀取的對象，只含可公開欄位、且只含 product=GT 的課。修改前先想清楚有沒有多開什麼。';