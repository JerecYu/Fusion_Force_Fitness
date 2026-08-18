-- ═══════════════════════════════════════════════════════════════════
--  33-confirm-wording.sql — 「代確認」改成「幫他確認」
--
--  專案：FFF 預約系統（fff-platform）
--  路線圖第 56 步 · 2026-08-18
--
--  起因：Jerec 看到點名頁上的按鈕，問「『代確認』應該是『待確認』對嗎？」
--
--  ☢️ 不是錯字 —— 那是「代替」的代。但那一行其實是兩個東西：
--         還沒確認                    [ 代確認 ]
--           ↑ 狀態（意思就是「待確認」）  ↑ 按鈕（教練代替客人確認）
--     兩個詞同音、形近，又剛好貼在一起。
--
--  ☢️ 老闆看錯，教練就會看錯。要靠解釋才懂的字不該留在按鈕上。
--     改成「幫他確認」—— 沒有同音字可以混淆，而且跟「幫學員購課」同一種語氣。
--
--  ☢️ 為什麼連資料庫也要改：這兩句 raise exception 【會浮到教練畫面上】。
--     checkin.html 的 proxyConfirm 在 catch 裡直接把 e.message 丟給 toast。
--     所以它們不是內部訊息，是文案，要跟按鈕上的字一致。
-- ═══════════════════════════════════════════════════════════════════

create or replace function public.confirm_by_staff(p_booking uuid)
returns jsonb
language plpgsql security definer set search_path = public as $$
declare v_b record; v_starts timestamptz;
begin
  if not public.is_staff() then
    raise exception '只有教練可以幫客人確認';
  end if;

  select b.id, b.status, b.confirmed_at, s.session_date, s.start_time
    into v_b
  from public.bookings b
  join public.class_sessions s on s.id = b.session_id
  where b.id = p_booking;

  if not found then
    return jsonb_build_object('ok', false, 'why', 'not_found');
  end if;
  if v_b.status = 'cancelled' then
    return jsonb_build_object('ok', false, 'why', 'cancelled');
  end if;
  if v_b.confirmed_at is not null then
    return jsonb_build_object('ok', true, 'already', true);
  end if;

  v_starts := (v_b.session_date + v_b.start_time) at time zone 'Asia/Taipei';
  if now() < v_starts - interval '15 minutes' or now() > v_starts + interval '2 hours' then
    raise exception '幫客人確認只能在課前 15 分鐘到課後 2 小時之間';
  end if;

  -- 只寫這兩欄。確認到課和核銷扣課是兩件事，混在一起會讓客人有辦法扣自己的課。
  update public.bookings
     set confirmed_at = now(), confirmed_by = 'staff'
   where id = p_booking;

  return jsonb_build_object('ok', true);
end $$;

revoke all on function public.confirm_by_staff(uuid) from public;
grant execute on function public.confirm_by_staff(uuid) to authenticated;


-- ── 驗收 ───────────────────────────────────────────────────────
-- ☢️☢️ 這裡修掉了一個從第 47 步就存在的【驗證方法本身的錯】。
--
--    原本的靜態檢查是：
--        pg_get_functiondef(oid) ilike '%credit_ledger%'
--    但 pg_get_functiondef 會【連註解一起吐出來】。
--    所以只要函式裡有一句註解寫著「一個字都不碰 credit_ledger」，
--    這個檢查就會回 true —— 明明沒碰，卻報告成碰到了。
--
--    ☢️ 反過來更危險：「有擋非員工」那一項也可能只是因為註解裡提到 is_staff
--       就通過，而真正的 if not is_staff() 根本沒寫。
--       一個會說謊的檢查比沒有檢查更糟 —— 它讓人停止懷疑。
--
--    修法：先用 regexp_replace 把 -- 開頭的註解拿掉，再驗。
with f as (
  select p.proname,
         regexp_replace(pg_get_functiondef(p.oid), '--[^\n]*', '', 'g') as src
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public'
    and p.proname in ('confirm_by_staff','confirm_attendance','check_in','add_purchase',
                      'void_purchase','confirm_payment','create_customer','claim_legacy')
)
select proname                                        as 函式,
       (src ilike '%credit_ledger%')                  as 碰堂數帳本,
       (src ~* '(is_staff|is_owner)\s*\(\)')          as 有員工關卡
from f order by 1;
-- 期望：
--   confirm_by_staff / confirm_attendance / create_customer → 碰堂數帳本 = false
--   其餘四支 → 碰堂數帳本 = true（它們本來就該碰）、有員工關卡 = true
--   ☢️ confirm_attendance 的「有員工關卡」是 false，這是【對的】——
--      那一支是客人自己掃碼在用的，牆是 my_customer_id() 不是 is_staff()。

-- ☢️ 最關鍵的一條單獨驗：這一支的 update 到底寫了哪幾欄
with d as (
  select regexp_replace(pg_get_functiondef(p.oid), '--[^\n]*', '', 'g') as src
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.proname = 'confirm_by_staff'
)
select (regexp_match(src, 'update\s+public\.bookings\s+set\s+([^;]+?)\s+where'))[1] as update只寫了這些欄位
from d;
-- 期望：confirmed_at = now(), confirmed_by = 'staff' —— 就這兩欄，沒有別的
