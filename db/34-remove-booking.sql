-- ═══════════════════════════════════════════════════════════════════
--  34-remove-booking.sql — 把加錯的人從名單上拿掉
--
--  專案：FFF 預約系統（fff-platform）
--  路線圖第 58 步 · 2026-08-18
--
--  起因：Jerec 示範「現場加人」給其他教練看的時候按錯人，名單上多了一位
--        根本沒報名的客人。他自己拿不掉 —— 因為 add_walkin() 有，
--        相對的那一顆從來沒做。最後是我進資料庫改的。
--
--  ☢️ 這是一個「只有加、沒有減」的缺口。而現場加人本來就是站在櫃檯、
--     一邊講話一邊按的動作 —— 按錯是常態，不是意外。
--     沒有「拿掉」的話，每按錯一次就要 教練→Jerec→我 走一輪。
--
--  ☢️ 為什麼不是 delete：紀錄要留著。改成 cancelled，
--     這樣「誰在什麼時候加的、誰又在什麼時候拿掉」都還查得到。
--     再加一欄 cancelled_by 才分得出「客人自己取消」和「教練拿掉」——
--     客人自己取消走的是 RLS 政策，不經過這一支，那一欄會是空的。
-- ═══════════════════════════════════════════════════════════════════

-- ── ① 誰拿掉的 ─────────────────────────────────────────────────
alter table public.bookings
  add column if not exists cancelled_by uuid references public.employees(id);

comment on column public.bookings.cancelled_by is
  '教練把人從名單上拿掉時記下是誰做的。客人自己取消時是空的 —— 空／不空剛好分得出兩種來源。';


-- ── ② 拿掉 ─────────────────────────────────────────────────────
create or replace function public.remove_booking(p_booking uuid, p_why text default null)
returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_b record; v_moved int; v_me uuid; v_why text;
begin
  -- ☢️ 教練就可以做。如果只有 Jerec 能拿掉，櫃檯按錯就得等他回訊息 ——
  --    而「加」本來就是教練做的，能加不能減只會讓錯誤留在畫面上更久。
  if not public.is_staff() then
    raise exception '只有教練可以把人從名單上拿掉';
  end if;

  select b.id, b.status, b.customer_id, c.name as customer_name,
         s.session_date, s.start_time, s.title
    into v_b
  from public.bookings b
  join public.customers c      on c.id = b.customer_id
  join public.class_sessions s on s.id = b.session_id
  where b.id = p_booking;

  if not found then
    return jsonb_build_object('ok', false, 'why', 'not_found');
  end if;

  if v_b.status = 'cancelled' then
    -- 已經被別的教練拿掉了。這不是錯誤，結果就是我們要的。
    return jsonb_build_object('ok', true, 'already', true, 'name', v_b.customer_name);
  end if;

  -- ☢️ 最重要的一道關卡：這一筆動過堂數就不能只改狀態。
  --    已經記出席的人，堂數扣掉了；直接把預約改成取消，
  --    那一堂課的錢就【永遠消失在帳上】—— 客人少一堂，而且查不出為什麼。
  --    正確順序是先按「改成缺席」（那會把堂數退回去），再拿掉。
  --    ☢️ 用「加總 = 0」而不是「一列都沒有」：出席過又改成缺席的人，
  --       帳本上有 -1 和 +1 兩列，但淨值是 0，客人已經被補回來了，可以拿掉。
  select coalesce(sum(l.delta), 0) into v_moved
  from public.credit_ledger l where l.booking_id = p_booking;

  if v_moved <> 0 then
    return jsonb_build_object('ok', false, 'why', 'credits_moved',
             'name', v_b.customer_name, 'moved', v_moved);
  end if;

  -- ☢️ 上限跟點名一樣：課後 7 天。再久以前的名單不該還能改 ——
  --    那已經是歷史，不是「現在正在發生的事」。
  --    ☢️ 故意【沒有】下限：現場加人在開課前就能按，那拿掉也必須能按，
  --       否則按錯的人要等到課前 15 分鐘才拿得掉。
  if v_b.session_date < ((now() at time zone 'Asia/Taipei')::date - 7) then
    return jsonb_build_object('ok', false, 'why', 'too_old', 'name', v_b.customer_name);
  end if;

  select e.id into v_me from public.employees e where e.auth_user_id = auth.uid();
  v_why := nullif(btrim(coalesce(p_why, '')), '');

  update public.bookings
     set status       = 'cancelled',
         cancelled_at = now(),
         cancelled_by = v_me
   where id = p_booking
     and status <> 'cancelled';          -- 兩個教練同時按也只會成功一次

  return jsonb_build_object('ok', true, 'name', v_b.customer_name,
                            'title', v_b.title, 'was', v_b.status);
end $$;

comment on function public.remove_booking(uuid, text) is
  '把加錯的人從名單上拿掉：改成 cancelled，不刪除。'
  '☢️ 這一筆動過堂數（加總不為 0）就擋下來 —— 要先按「改成缺席」把堂數退回去。';

revoke all on function public.remove_booking(uuid, text) from public;
grant execute on function public.remove_booking(uuid, text) to authenticated;


-- ── 驗收 ───────────────────────────────────────────────────────
-- ☢️ 先去掉註解再驗（第 56 步學到的：pg_get_functiondef 連註解一起吐，
--    只要註解裡提到 credit_ledger，沒去掉註解的檢查就會誤報成「碰到了」）。
with f as (
  select regexp_replace(pg_get_functiondef(p.oid), '--[^\n]*', '', 'g') as src
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.proname = 'remove_booking'
)
select (src ~* 'insert\s+into\s+public\.credit_ledger') as 會寫堂數帳本,
       (src ~* 'delete\s+from')                          as 有刪除資料,
       (src ~* 'is_staff\s*\(\)')                        as 有員工關卡,
       (regexp_match(src, 'update\s+public\.bookings\s+set\s+([^;]+?)\s+where'))[1] as update只寫這些
from f;
-- 期望：會寫堂數帳本 = false（它只改狀態，一毛錢都不動）
--       有刪除資料   = false（紀錄要留著）
--       有員工關卡   = true
--       update 只寫 status / cancelled_at / cancelled_by 三欄

select (select count(*) from information_schema.columns
        where table_schema='public' and table_name='bookings'
          and column_name='cancelled_by') as 欄位有了;
-- 期望：1
