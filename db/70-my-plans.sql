-- ═══════════════════════════════════════════════════════════════════
-- db/70-my-plans.sql — 客人自己看得到私人課還剩幾堂
--
-- 專案：FFF 預約系統（fff-platform）· 第 93 步之四（最後一段）· 2026-08-22
--
-- 起因：db/68 讓「扣預收」真的扣得動、db/69 讓卡開得出來，
--   但客人打開「我的預約」只看得到【團體課】的堂數 ——
--   私人課買了十堂、上了兩堂，客人那一頭完全是黑的。
--
-- ══ ☢️ 為什麼不是在 my_credits 上多一行就好 ═════════════════════
--   my_credits 是「產品別 → 一個數字」。私人課不能這樣加總：
--   ☢️ 一個人可能同時有【一對一】和【一對二】兩張卡，
--      而兩張卡的每堂價值不一樣（15,000÷10 vs 20,000÷10）。
--      加起來的「15 堂」不代表任何東西 —— 客人也沒辦法拿它去對，
--      因為他心裡記得的是「我買了一張十堂的一對二」。
--   所以客人端要看的是【一張卡一列】，不是一個總數。
--
-- ══ 誰看得到 ═════════════════════════════════════════════════════
-- ☢️ 只看得到自己的。過濾條件是 owner_customer_id = my_customer_id()，
--    跟 my_credits／my_bookings 同一個寫法。
-- ☢️ 【不給每堂單價】。那是我們跟他之間的成交價，
--    在自己的畫面上看到「每堂 1,500」沒有任何用處，
--    但如果他截圖給朋友看，那就變成一份對外的價目表了。
-- ═══════════════════════════════════════════════════════════════════

create or replace view public.my_plans as
select
  ps.id                as plan_id,
  ps.product,
  ps.headcount,
  ps.total_credits,
  ps.remaining::int    as remaining,
  ps.opened_at,
  -- 給人看的一行：「一對二・預付 10 堂」
  case
    when ps.headcount = 1 then '一對一'
    when ps.headcount = 2 then '一對二'
    when ps.headcount is not null then ps.headcount || ' 人班'
    else ps.product
  end || '・' ||
  case when ps.total_credits > 0
       then '預付 ' || ps.total_credits || ' 堂'
       else '舊系統轉入' end               as label,
  -- 最後一次用掉是什麼時候（客人最常問的第二個問題）
  (select max(sr.done_at)
     from public.service_records sr
    where sr.plan_id = ps.id and not sr.voided) as last_used_at
from public.plan_state ps
where ps.owner_customer_id = public.my_customer_id()
  and ps.product in ('PT','PGT')
  and ps.remaining > 0;

grant select on public.my_plans to authenticated;

comment on view public.my_plans is
  '客人自己的私人課卡片，一張一列。☢️ 一張一列不是一個總數 ——'
  '一對一和一對二的每堂價值不一樣，加起來的數字不代表任何東西。'
  '☢️ 不含每堂單價：那是成交價，不該出現在客人可以截圖的畫面上。';
