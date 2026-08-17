-- ═══════════════════════════════════════════════════════════════
--  28-staff-tools.sql  ·  教練後台（第一期：只建人，不碰錢）
--  2026-08-17
--
--  來源：2026-08-17 林正明綁不上 → Jerec 問「遇到新客人告訴你就對了嗎」。
--        答案是「現在對，但不該長期靠我」。
--
--  ☢️ Jerec 的決定（原話）：「舊系統……不只新增客人還直接可選購買方案，
--     這會有『先上車，但不一定會補票』的問題，所以我選 1 不碰堂數，只建人」。
--     所以這一支【完全不碰 credit_ledger】。建出來的客人固定 0 堂。
--
--  ☢️ 這也守住第 39 步那條規則：動到錢的入口只有一個。
--     多開一個能加堂數的入口，就會有兩本帳要對。
--
--  三樣東西：
--    ① staff_signups   綁不上的人卡在哪（今天最痛的，診斷全靠人工跑 SQL）
--    ② staff_customers 查客人：剩幾堂、綁定了沒
--    ③ create_customer 建客人（姓名 ＋ 手機，就這樣）
-- ═══════════════════════════════════════════════════════════════

-- ── ① 綁不上的人 ─────────────────────────────────────────────
--  ☢️ 這張表【不是】待審佇列。它只是留言簿 ——
--     裡面的資料永遠不會自動變成客人（第 32 步的決定）。
--     這一頁做的是「把卡在哪講出來」，按不按下去仍然是人決定。
--
--  ☢️ 不要加 with (security_invoker = true)。
--     牆是下面那行 is_staff()，不是底層資料表的權限。
--     （2026-08-17 因為加了這一行，線上三張檢視表整個讀不到，見 db/25。）
create or replace view public.staff_signups as
select
  r.line_user_id,
  r.name                                          as typed_name,
  r.phone                                         as typed_phone,
  r.tries,
  r.updated_at,
  c.id                                            as matched_customer_id,
  c.name                                          as registered_name,
  case
    when c.id is null              then 'no_phone'        -- 這支手機不在名單裡
    when c.line_user_id is not null then 'taken'          -- 已經被別支 LINE 綁走
    when c.is_active = false       then 'inactive'        -- 客人被停用
    else                                'name_mismatch'   -- 手機對、姓名對不上
  end                                             as why
from public.signup_requests r
left join public.customers c on c.phone = r.phone
where public.is_staff();

comment on view public.staff_signups is
  '綁不上的人，以及卡在哪。純讀。why：no_phone／name_mismatch／taken／inactive。';

grant select on public.staff_signups to authenticated;

-- ── ② 查客人 ─────────────────────────────────────────────────
--  ☢️ 一定要 definer：餘額要讀 credit_ledger，而 authenticated
--     對那張表【故意】一個權限都沒有。
create or replace view public.staff_customers as
select
  c.id,
  c.name,
  c.phone,                                        -- 教練本來就讀得到（RLS 政策「員工可讀全部客人」）
  right(c.phone, 3)                               as phone_tail,
  (c.line_user_id is not null)                    as bound,
  c.is_active,
  c.created_at,
  coalesce(bal.balance, 0)                        as balance
from public.customers c
left join lateral (
  select sum(l.delta)::int as balance
  from public.credit_ledger l
  where l.customer_id = c.id and l.product = 'GT'
) bal on true
where public.is_staff();

comment on view public.staff_customers is
  '教練查客人用：剩幾堂、綁定了沒。純讀，不含任何寫入路徑。';

grant select on public.staff_customers to authenticated;

-- ── ③ 建客人 ─────────────────────────────────────────────────
--  ☢️ customers 沒有 INSERT 政策，所以只能走這一支 —— 這是刻意的。
--     走函式才有地方擋「手機格式」「重複」「姓名太短」這三件事。
create or replace function public.create_customer(p_name text, p_phone text)
returns jsonb
language plpgsql security definer set search_path = public as $$
declare v_name text; v_phone text; v_exist record; v_id uuid;
begin
  if not public.is_staff() then
    raise exception '只有員工可以建立客人資料';
  end if;

  -- 手機正規化：09xx-xxx-xxx、+886…、中間有空白，全部歸成 0912345678
  v_phone := regexp_replace(coalesce(p_phone, ''), '[\s\-()]', '', 'g');
  if v_phone like '+886%' then v_phone := '0' || substring(v_phone from 5);
  elsif v_phone like '886%' then v_phone := '0' || substring(v_phone from 4);
  end if;
  v_phone := regexp_replace(v_phone, '\D', '', 'g');

  if v_phone !~ '^09\d{8}$' then
    return jsonb_build_object('ok', false, 'why', 'bad_phone');
  end if;

  v_name := btrim(coalesce(p_name, ''));
  -- ☢️ 至少兩個字。line-bind 的姓名比對規則是「客人打的要【包含】登記姓名」，
  --    登記只有一個字（例如「王」）的話，任何含「王」的名字都會通過。
  if length(regexp_replace(v_name, '[\s　]', '', 'g')) < 2 then
    return jsonb_build_object('ok', false, 'why', 'bad_name');
  end if;

  -- 已經有人用這支手機了 → 把是誰講出來，不要讓人重複建
  select c.id, c.name, (c.line_user_id is not null) as bound, c.is_active
    into v_exist
  from public.customers c where c.phone = v_phone;

  if found then
    return jsonb_build_object('ok', false, 'why', 'phone_taken',
             'name', v_exist.name, 'bound', v_exist.bound, 'active', v_exist.is_active);
  end if;

  -- ☢️ 這裡【只】寫 customers。一個字都不碰 credit_ledger ——
  --    建出來的客人就是 0 堂，堂數要另外走課購流程（C 第二期）。
  insert into public.customers (name, phone, is_active, note)
  values (v_name, v_phone, true,
          to_char(now() at time zone 'Asia/Taipei', 'YYYY-MM-DD') || ' 教練後台建立')
  returning id into v_id;

  return jsonb_build_object('ok', true, 'id', v_id, 'name', v_name,
                            'phone_tail', right(v_phone, 3));
end $$;

revoke all on function public.create_customer(text, text) from public;
grant execute on function public.create_customer(text, text) to authenticated;

-- ── 驗收 ──────────────────────────────────────────────────────
-- ☢️ 這一支【絕對不能】碰到堂數。靜態驗一次。
select p.proname as 函式,
       (pg_get_functiondef(p.oid) ilike '%credit_ledger%') as 碰到堂數帳本,
       (pg_get_functiondef(p.oid) ilike '%is_staff%')      as 有擋非員工
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public' and p.proname = 'create_customer';
-- 期望：碰到堂數帳本 = false、有擋非員工 = true

-- ☢️ 三張新東西都必須是 definer（不能有 security_invoker=true）
select c.relname as 檢視表,
       case when coalesce(c.reloptions::text,'') like '%security_invoker=true%'
            then 'invoker ☢️ 不對' else 'definer ✓' end as 模式
from pg_class c join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public' and c.relkind = 'v'
  and c.relname in ('staff_signups','staff_customers');
