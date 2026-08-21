-- ═══════════════════════════════════════════════════════════════════
-- db/60-undo.sql — 兩顆「還原」：作廢的服務紀錄、取消的課次
--
-- 專案：FFF 預約系統（fff-platform）· 第 88 步 · 2026-08-21
--
-- 起因：同一天撞到兩次「只有 SQL 做得到、畫面上沒有」的操作。
--   ① VC 誤按了一筆服務紀錄的「作廢」（原因欄填「爽」），畫面上沒有還原鍵。
--   ② 8/21 19:00 那堂課被夜間排程判定無人報名而取消，
--      而點名頁的紅字寫著「請找 Jerec 在後台改課次狀態」——
--      ☢️ 但後台【根本沒有那個開關】。那句話從第 39 步寫到現在都是假的。
--
-- ☢️☢️ 兩顆都遵守同一條規則：【還原不是抹掉】。
--   作廢過、取消過這件事本身要留在紀錄上。靜靜地變回去，
--   比錯誤本身更難查 —— 三個月後沒有人知道那筆錢中間消失過。
--
-- ☢️☢️ reopen_session 最重要的一行是「哪些預約可以跟著還原」：
--   · cancelled_by 是 null  → 客人自己取消的，或夜間排程判定的
--                             【一律不還原】。他真的不想來。
--   · cancelled_by 有值      → 職員取消課次時連帶取消的
--                             【而且時間要對得上那次取消】才還原。
--   只看 cancelled_by 不夠：櫃檯可能為了別的理由單獨取消過某一個人的預約，
--   那一筆不該被「還原課次」連帶救回來。所以要拿 class_notices 的
--   取消時間當基準，只還原那個時間點之後被取消的。
-- ═══════════════════════════════════════════════════════════════════

-- ── ① 還原作廢的服務紀錄 ───────────────────────────────────────
create or replace function public.restore_service(p_id uuid, p_why text)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $fn$
declare v_r record; v_who text;
begin
  if not public.is_finance() then
    raise exception '只有財務可以還原服務紀錄';
  end if;
  -- ☢️ 還原也要寫理由。作廢要理由、還原不用的話，
  --    帳上就會出現「有人作廢了，然後不知道為什麼又回來了」。
  if coalesce(btrim(p_why),'') = '' then
    return jsonb_build_object('ok', false, 'why', 'no_reason', 'msg', '要寫還原原因');
  end if;

  select * into v_r from public.service_records where id = p_id;
  if not found then
    return jsonb_build_object('ok', false, 'why', 'not_found', 'msg', '找不到這筆紀錄');
  end if;
  if not v_r.voided then
    return jsonb_build_object('ok', false, 'why', 'not_voided', 'msg', '這筆沒有作廢，不用還原');
  end if;

  select display_name into v_who from public.employees where id = v_r.voided_by;

  update public.service_records
     set voided      = false,
         void_reason = null,
         voided_by   = null,
         voided_at   = null,
         -- 作廢那件事留在人工註記裡，永遠不會消失
         manual_note = concat_ws(' ｜ ', nullif(manual_note,''),
           to_char(now() at time zone 'Asia/Taipei','YYYY-MM-DD HH24:MI')
           || ' 還原作廢（原作廢：' || coalesce(v_who,'不明') || ' 於 '
           || to_char(v_r.voided_at at time zone 'Asia/Taipei','MM-DD HH24:MI')
           || '，原因「' || coalesce(v_r.void_reason,'') || '」）｜ 還原原因：' || btrim(p_why))
   where id = p_id;

  return jsonb_build_object('ok', true, 'id', p_id,
    'perf', v_r.perf_amount, 'fin_status', v_r.fin_status,
    'was_voided_by', coalesce(v_who,'不明'), 'was_reason', v_r.void_reason);
end $fn$;

revoke all on function public.restore_service(uuid, text) from public, anon;
grant execute on function public.restore_service(uuid, text) to authenticated;

comment on function public.restore_service(uuid, text) is
  '還原被作廢的服務紀錄。只有財務按得動，必須寫原因；作廢的歷史會留在 manual_note，不會被抹掉。';


-- ── ② 重新開課 ─────────────────────────────────────────────────
-- ☢️ class_notices.kind 原本只認得 cancel／change／note。
--    直接寫 'reopen' 會被 CHECK 擋下來 —— 而那會發生在 update 之後，
--    整個交易回捲，畫面上看起來是「按了沒反應」。先把它加進去。
alter table public.class_notices drop constraint if exists class_notices_kind_check;
alter table public.class_notices add constraint class_notices_kind_check
  check (kind = any (array['cancel','change','note','reopen']));

create or replace function public.reopen_session(p_session uuid, p_why text)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $fn$
declare
  v_me uuid; v_s record; v_cut timestamptz;
  v_back int := 0; v_self int := 0; v_status text;
begin
  if not public.is_staff() then raise exception '只有職員可以重新開課'; end if;
  if coalesce(btrim(p_why),'') = '' then
    return jsonb_build_object('ok', false, 'why', 'no_reason', 'msg', '要寫重新開課的原因');
  end if;
  v_me := public.my_employee_id();

  select s.*, e.display_name as coach_name into v_s
    from public.class_sessions s
    left join public.employees e on e.id = s.coach_id
   where s.id = p_session;
  if not found then
    return jsonb_build_object('ok', false, 'why', 'no_session', 'msg', '找不到這堂課');
  end if;
  if v_s.status <> 'cancelled' then
    return jsonb_build_object('ok', false, 'why', 'not_cancelled',
      'msg', '這堂課現在不是取消狀態（' || v_s.status || '）');
  end if;

  -- 未來的課回到「待結算」，今天和過去的課回到「確定開課」——
  -- 夜間排程已經跑過的日子不該再被它處理一次。
  v_status := case when v_s.session_date > ((now() at time zone 'Asia/Taipei')::date)
                   then 'pending' else 'confirmed' end;

  update public.class_sessions set status = v_status where id = p_session;

  -- 上一次「職員取消這堂課」的時間點。夜間排程不寫 class_notices，
  -- 所以找不到就代表這堂是排程取消的 → 沒有任何預約該被還原。
  select max(created_at) into v_cut
    from public.class_notices where session_id = p_session and kind = 'cancel';

  if v_cut is not null then
    update public.bookings
       set status = 'booked', cancelled_at = null, cancelled_by = null
     where session_id = p_session
       and status = 'cancelled'
       and cancelled_by is not null
       and cancelled_at >= v_cut - interval '5 seconds';
    get diagnostics v_back = row_count;
  end if;

  -- ☢️ 客人自己取消的永遠不還原 —— 只算給人看，讓櫃檯知道要不要通知他們回來。
  select count(*) into v_self from public.bookings
   where session_id = p_session and status = 'cancelled' and cancelled_by is null;

  insert into public.class_notices (session_id, kind, body, sent_by, n_target)
  values (p_session, 'reopen', btrim(p_why), v_me, v_back);

  return jsonb_build_object('ok', true,
    'status', v_status,
    'restored_bookings', v_back,
    'self_cancelled', v_self,
    'session', jsonb_build_object('date', v_s.session_date,
      'time', to_char(v_s.start_time,'HH24:MI'), 'title', v_s.title,
      'coach', v_s.coach_name));
end $fn$;

revoke all on function public.reopen_session(uuid, text) from public, anon;
grant execute on function public.reopen_session(uuid, text) to authenticated;

comment on function public.reopen_session(uuid, text) is
  '把取消的課次重新打開。只還原「職員取消課次時連帶取消」的預約；'
  '客人自己取消的一律不還原，只回報筆數讓櫃檯決定要不要找他們回來。';
