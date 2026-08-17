-- ═══════════════════════════════════════════════════════════════
--  26-fix-token-random.sql  ·  修：確認碼產生不出來
--  2026-08-17
--
--  現場症狀（13:45）：教練按「出示確認碼」→ 蓋板裡跳紅字
--      function gen_random_bytes(integer) does not exist
--
--  ── 原因 ────────────────────────────────────────────────────
--  gen_random_bytes 來自 pgcrypto，而 Supabase 把 pgcrypto 裝在
--  extensions schema，不是 public。
--  issue_checkin_token 是 security definer，search_path 鎖成 public
--  （這是對的，不能為了一個函式去放寬它）—— 所以找不到。
--
--  ☢️ 第 19 支寫的時候只在 SQL Editor 裡跑過建立，【沒有真的呼叫過一次】。
--     建立的時候 plpgsql 不會去解析函式體裡的函式呼叫，所以不會報錯。
--     一直到教練在現場按下去，才第一次真的執行到那一行。
--
--  ── 解法 ────────────────────────────────────────────────────
--  改用核心內建的 gen_random_uuid()：
--    · PostgreSQL 13 以後它就在 pg_catalog 裡，不依賴任何擴充套件
--    · 底層是 pg_strong_random，一樣是密碼學等級的亂數
--    · 去掉連字號剛好 32 個十六進位字元 —— 跟原本
--      encode(gen_random_bytes(16),'hex') 完全一樣長，
--      所以 QR 的版本（6）和大小都不會變，前端一個字都不用改
--
--  ☢️ 為什麼不寫成 extensions.gen_random_bytes(16)？
--     那也能動，但它讓這支函式多依賴一個「擴充套件裝在哪個 schema」的
--     假設。不依賴比較好 —— 尤其是這支在現場最忙的三十秒才會被呼叫。
-- ═══════════════════════════════════════════════════════════════

create or replace function public.issue_checkin_token(p_session uuid)
returns text
language plpgsql security definer set search_path = public as $$
declare v_token text; v_start timestamptz;
begin
  if not public.is_staff() then
    raise exception '只有教練可以產生確認碼';
  end if;

  select (s.session_date + s.start_time) at time zone 'Asia/Taipei'
    into v_start
  from public.class_sessions s
  where s.id = p_session and s.product = 'GT' and s.status <> 'cancelled';

  if v_start is null then
    raise exception '找不到這堂課，或這堂課已經取消';
  end if;

  -- ☢️ 只有「課前 15 分鐘 ～ 課後 2 小時」之間才發得出來。
  --    憑證能在任何時間發的話，就等於一張可以帶回家的空白簽名。
  if now() < v_start - interval '15 min' or now() > v_start + interval '2 hour' then
    raise exception '確認碼只能在課前 15 分鐘到課後 2 小時之間產生';
  end if;

  -- ☢️ 這一行是這支修正的全部。原本是 encode(gen_random_bytes(16),'hex')。
  v_token := replace(gen_random_uuid()::text, '-', '');

  insert into public.checkin_tokens (token, session_id, issued_by, expires_at)
  values (v_token, p_session, public.my_employee_id(), now() + interval '60 sec');

  -- 順手清掉過期的，這張表不需要留歷史
  delete from public.checkin_tokens where expires_at < now() - interval '1 day';

  return v_token;
end $$;

revoke all on function public.issue_checkin_token(uuid) from public;
grant execute on function public.issue_checkin_token(uuid) to authenticated;

-- ── 驗收：☢️ 真的呼叫一次，不要只建立就算過 ──────────────────
--    （這一支之所以會壞，就是因為當初只建立、沒呼叫。）
do $$
declare v_auth uuid; v_sess uuid; v_title text; v_tok text; v_n int;
begin
  select s.id, s.title into v_sess, v_title
  from public.class_sessions s
  where s.product = 'GT' and s.status <> 'cancelled'
    and ((s.session_date + s.start_time) at time zone 'Asia/Taipei')
          between now() - interval '2 hour' and now() + interval '15 min'
  order by s.session_date desc, s.start_time desc limit 1;

  if v_sess is null then
    raise notice '現在沒有課在時窗內 —— 換一個時間再跑這一段。';
    return;
  end if;

  select auth_user_id into v_auth from public.employees where display_name = 'Jerec';
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_auth, 'role', 'authenticated')::text, true);
  set local role authenticated;
  v_tok := public.issue_checkin_token(v_sess);
  reset role;

  select count(*) into v_n from public.checkin_tokens where token = v_tok;
  raise notice '課「%」發碼成功：% 字元，表裡 % 列（期望 32 字元、1 列）', v_title, length(v_tok), v_n;
end $$;
-- 2026-08-17 實測：課「功能性核心」發碼成功：32 字元，表裡 1 列。
