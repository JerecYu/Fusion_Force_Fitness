-- ============================================================
-- 44 · 誰算「授課教練」—— 職稱是教練，不代表他會站上課堂
--
-- Jerec 2026-08-19：<服務登記> 的授課教練清單要排除
--   林智謙、簡基城、櫃檯平板。
--
-- 為什麼不能靠 role 過濾：
--   林智謙   role = staff　　→ 用 role 濾得掉
--   櫃檯平板 role = staff　　→ 用 role 濾得掉
--   簡基城   role = coach　　→ ☢️ 用 role【濾不掉】
--     他是顧問／股東身分，職稱是教練但不實際授課
--     （第 67 步就是因為同一個理由，沒把他加進教練圖文選單）。
--
-- ☢️ 也不能把名字寫死在前端。名字寫死的話，
--    下次來一位新教練、或有人離職，畫面就跟事實對不上，
--    而且沒有人會記得去改那一行。
--    → 做成資料庫的一個欄位，事實只放一個地方。
-- ============================================================

alter table public.employees
  add column if not exists can_teach boolean not null default true;

comment on column public.employees.can_teach is
  '會不會實際站上課堂。☢️ 跟 role 是兩回事 —— 顧問／股東的 role 可能是 coach，但不授課。';

-- ☢️ 用顯示名稱而不是 uuid：uuid 換一個環境就對不上，
--    而這三個名字在 employees 裡是唯一的。
update public.employees set can_teach = false
 where display_name in ('林智謙', '簡基城', '櫃檯平板');

-- ── 客人看得到的教練名單也要跟著濾 ──────────────────────────
-- ☢️ pt-request.js 拿這張表把「教練名字」對回 uuid。
--    不濾的話，客人在私人課需求單上有機會選到不授課的人。
create or replace view public.public_coaches as
select id, display_name, role
from public.employees
where is_active = true
  and role in ('owner', 'coach')
  and can_teach;

comment on view public.public_coaches is '會實際授課、而且在職的教練。給客人選教練用。';
grant select on public.public_coaches to anon, authenticated;

-- ── 資料庫這一關也要擋 ──────────────────────────────────────
-- ☢️ 前端把不授課的人濾掉【不是安全】（專案規則第 3 條）。
--    有人改一下網頁原始碼，就能把課記到不授課的人身上 —— 那會變成他的薪水。
--
-- ☢️ 做成 trigger 而不是寫進 add_service()：
--    trigger 守的是【這張表】，不管資料從哪條路進來都會被檢查。
--    寫在 add_service 裡的話，以後多一條路（匯入舊資料、修正腳本）就繞過去了。
create or replace function public.guard_service_coach()
returns trigger
language plpgsql security definer set search_path = public as $fn$
declare v_e record;
begin
  select display_name, can_teach, is_active into v_e
  from public.employees where id = new.coach_id;

  if not found then
    raise exception '找不到這位員工';
  end if;
  if not v_e.is_active then
    raise exception '% 已經停用，不能記為授課教練', v_e.display_name;
  end if;
  if not v_e.can_teach then
    raise exception '% 不是授課教練 —— 服務紀錄要記【實際站上課堂的人】', v_e.display_name;
  end if;

  return new;
end $fn$;

drop trigger if exists service_coaches_guard on public.service_coaches;
create trigger service_coaches_guard
  before insert or update on public.service_coaches
  for each row execute function public.guard_service_coach();
