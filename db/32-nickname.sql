-- ═══════════════════════════════════════════════════════════════════
--  32-nickname.sql — 暱稱欄位 ＋ 綁定比對放寬
--
--  專案：FFF 預約系統（fff-platform）
--  路線圖第 54 步 · 2026-08-18
--
--  起因：Jerec 2026-08-18 的觀察（原話）：
--    「客人其實很奇怪，有人就是不喜歡給出中文名，因此當初舊系統時代才決定
--      在登入或綁定時，只認手機不認名，這造成了資料內會有重複名稱的問題，
--      甚至客人雖然乖乖的輸入中文全名，但也是有同名同姓的。」
--
--  盤點出來的實際數字（2026-08-18，93 位客人）：
--    · 登記姓名【完全沒有中文字】的：18 位（五分之一）
--    · 同名同姓：0 組
--    · 中文只有 1～2 個字的：5 位
--
--  ☢️ 這一版最重要的一個判斷：暱稱【不參與綁定比對的收緊】，只放寬。
--
--     Jerec 原本的想法是「暱稱也設必填，資訊量越多信心水準越高」。
--     那句話在【找人】的時候完全成立，在【驗證】的時候是反過來的 ——
--     每多一個「必須對得上」的欄位，就多一個對不上的機會。
--     而且暱稱是自由填的：櫃檯記「小虎」、客人打「虎哥」，一樣卡住，
--     等於把 Adele／Yiting 那個問題再複製一份。
--
--     所以這裡做的是：多一條【可以對得上】的路，不是多一道關卡。
--         舊：客人打的要包含「登記姓名」
--         新：客人打的要包含「登記姓名」【或】「暱稱」，對上任一個就過
--     Adele 打「陳荔芬」或「Adele」都能綁。
--
--  ☢️ 同名同姓【不會】造成綁錯人 —— 手機是唯一鎖，先用手機找到那一筆，
--     才比姓名。兩位「陳怡君」的手機不同，永遠不會互相干擾。
--     同名的麻煩在【櫃檯畫面上分不出誰是誰】，那正是暱稱要解的事。
--
--  ☢️ 資料庫這一欄【允許空白】。表單上必填是介面的事。
--     理由有二：既有 93 位客人一個暱稱都沒有，加 NOT NULL 會直接失敗；
--     而且 Jerec 已經決定「既有已綁定成功的無需追討新資訊」——
--     那它實務上就不是必填，寫成 NOT NULL 只會逼我們到處塞空字串。
-- ═══════════════════════════════════════════════════════════════════

-- ── ① 欄位 ─────────────────────────────────────────────────────
alter table public.customers add column if not exists nickname text;

comment on column public.customers.nickname is
  '客人自己說的那個稱呼（英文名、綽號）。① 給教練在畫面上分辨同名的人 '
  '② 綁定時多一條對得上的路。可以是空的。';

-- 查客人時會用名字搜尋，暱稱也要搜得到
create index if not exists customers_nickname_idx
  on public.customers (lower(nickname)) where nickname is not null;


-- ── ② 比對規則：多一條路，不是多一道關卡 ────────────────────────
--  ☢️ 兩個參數的版本【不動】。它是「一個名字對不對得上」的最小單位，
--     import_legacy_credits 和其他地方都還在用。
--  ☢️ 這一支要跟 line-bind 的 nameMatches() 【完全一致】。
--     不一致的話教練後台會說「這樣打會過」，實際上卻不會過 —— 比沒有更糟。
create or replace function public.name_matches(
  p_registered text, p_nickname text, p_typed text)
returns boolean
language sql immutable set search_path = public as $$
  select public.name_matches(p_registered, p_typed)
      or public.name_matches(p_nickname,   p_typed);
$$;

comment on function public.name_matches(text, text, text) is
  '客人打的姓名，對上「登記姓名」或「暱稱」任一個就算過。'
  '☢️ 必須跟 supabase/functions/line-bind 的 nameMatches() 完全一致。';


-- ── ③ 建客人：多收一個暱稱 ──────────────────────────────────────
--  ☢️ 不能直接加一個有預設值的第三參數 —— 那會變成兩支同名函式，
--     create_customer(a,b) 就成了「不知道要呼叫哪一支」的錯誤。
--     所以要先把兩個參數的版本丟掉。這兩句在同一個交易裡，不會有空窗。
drop function if exists public.create_customer(text, text);

create or replace function public.create_customer(
  p_name text, p_phone text, p_nickname text default null)
returns jsonb
language plpgsql security definer set search_path = public as $$
declare v_name text; v_nick text; v_phone text; v_exist record; v_id uuid;
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
  -- ☢️ 至少兩個字。比對規則是「客人打的要【包含】登記姓名」，
  --    登記只有一個字（例如「王」）的話，任何含「王」的名字都會通過。
  if length(regexp_replace(v_name, '[\s　]', '', 'g')) < 2 then
    return jsonb_build_object('ok', false, 'why', 'bad_name');
  end if;

  -- 暱稱：空白就存 null，不要存空字串（'' 和 null 在比對時行為不同，留一種就好）
  v_nick := nullif(btrim(coalesce(p_nickname, '')), '');
  -- ☢️ 暱稱如果只有一個字，【不能】拿來做包含比對 —— 登記暱稱「明」的話，
  --    任何含「明」的名字都會通過。太短就當作沒填，只留著給人看。
  --    這裡不擋、也不報錯（暱稱不是身分），交給比對那一關自己判斷長度。

  -- 已經有人用這支手機了 → 把是誰講出來，不要讓人重複建
  select c.id, c.name, (c.line_user_id is not null) as bound, c.is_active
    into v_exist
  from public.customers c where c.phone = v_phone;

  if found then
    return jsonb_build_object('ok', false, 'why', 'phone_taken',
             'name', v_exist.name, 'bound', v_exist.bound, 'active', v_exist.is_active);
  end if;

  -- ☢️ 這裡【只】寫 customers。一個字都不碰 credit_ledger ——
  --    建出來的客人就是 0 堂，堂數要另外走購課流程。
  begin
    insert into public.customers (name, nickname, phone, is_active, note)
    values (v_name, v_nick, v_phone, true,
            to_char(now() at time zone 'Asia/Taipei', 'YYYY-MM-DD') || ' 教練後台建立')
    returning id into v_id;
  exception when unique_violation then
    -- 別人在這幾毫秒之間先建好了。這不是錯誤，結果就是我們要的。
    select c.id, c.name, (c.line_user_id is not null) as bound, c.is_active
      into v_exist
    from public.customers c where c.phone = v_phone;
    return jsonb_build_object('ok', false, 'why', 'phone_taken',
             'name', v_exist.name, 'bound', v_exist.bound, 'active', v_exist.is_active,
             'race', true);
  end;

  return jsonb_build_object('ok', true, 'id', v_id, 'name', v_name,
                            'nickname', v_nick, 'phone_tail', right(v_phone, 3));
end $$;

revoke all on function public.create_customer(text, text, text) from public;
grant execute on function public.create_customer(text, text, text) to authenticated;


-- ── ④ 查客人：把暱稱帶出來 ──────────────────────────────────────
--  ☢️ 一定要 definer：餘額要讀 credit_ledger，而 authenticated
--     對那張表【故意】一個權限都沒有。
--  ☢️☢️ 不要加 with (security_invoker = true)（2026-08-17 的教訓，見 db/25）。
--  ☢️ 用 drop + create，不是 create or replace ——
--     replace 沒辦法把新欄位插到中間，會回「cannot change name of view column」。
drop view if exists public.staff_customers;

create view public.staff_customers as
select
  c.id,
  c.name,
  c.nickname,
  c.phone,
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
  '教練查客人用：剩幾堂、綁定了沒、暱稱。純讀，不含任何寫入路徑。';

grant select on public.staff_customers to authenticated;


-- ── ⑤ 綁不上的人：診斷要跟著放寬 ────────────────────────────────
--  ☢️ 這一頁的整個價值就是「講出卡在哪」。比對規則放寬了而這裡沒跟著改，
--     畫面就會叫教練去請客人改名字 —— 而他打的那個名字其實已經會過了。
--     2026-08-17 漏掉 retry 那次就是這個教訓，不要再犯第二次。
--  ☢️ 這裡也要 drop + create。第一次套用時我寫 create or replace，資料庫回：
--     「cannot change name of view column "why" to "registered_nickname"」——
--     新欄位插在 why 前面，replace 只會把第 8 欄【改名】，不會插入。
drop view if exists public.staff_signups;

create view public.staff_signups as
select
  r.line_user_id,
  r.name                                          as typed_name,
  r.phone                                         as typed_phone,
  r.tries,
  r.updated_at,
  c.id                                            as matched_customer_id,
  c.name                                          as registered_name,
  c.nickname                                      as registered_nickname,
  case
    when c.id is null               then 'no_phone'       -- 這支手機不在名單裡
    when c.line_user_id is not null then 'taken'          -- 已經被別支 LINE 綁走
    when c.is_active = false        then 'inactive'       -- 客人被停用
    -- 姓名或暱稱其實對得上，他只是還沒重送
    when public.name_matches(c.name, c.nickname, r.name) then 'retry'
    else                                 'name_mismatch'  -- 手機對、兩個名字都對不上
  end                                             as why
from public.signup_requests r
left join public.customers c on c.phone = r.phone
where public.is_staff();

comment on view public.staff_signups is
  '綁不上的人，以及卡在哪。純讀。why：no_phone／retry／name_mismatch／taken／inactive。';

grant select on public.staff_signups to authenticated;


-- ── 驗收 ───────────────────────────────────────────────────────
-- ☢️ 用回傳結果驗，【不要】用 raise exception 印 ——
--    raise 會把同一批的 DDL 一起回滾（2026-08-17 name_matches 就這樣消失過一次）。
select
  (select count(*) from information_schema.columns
    where table_schema='public' and table_name='customers' and column_name='nickname') as 欄位有了,
  (select count(*) from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public' and p.proname='create_customer')                          as 建客人函式支數,
  (select count(*) from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public' and p.proname='name_matches')                             as 比對函式支數,
  -- 放寬有沒有生效：登記「Adele」、暱稱「陳荔芬」，客人打中文名要能過
  public.name_matches('Adele', '陳荔芬', '陳荔芬')                                      as 打暱稱會過,
  public.name_matches('Adele', '陳荔芬', 'Adele')                                       as 打登記名會過,
  -- 沒填暱稱時要維持原本的行為
  public.name_matches('王小明', null, '王小明 Mike')                                     as 沒暱稱多寫會過,
  public.name_matches('王小明', null, '小明')                                            as 沒暱稱少寫不會過,
  -- ☢️ 一個字的暱稱不能變成後門
  public.name_matches('王小明', '明', '陳大明')                                          as 一個字暱稱不會過;
-- 期望：1 / 1 / 2 / true / true / true / false / false

-- ☢️ 兩張檢視表都必須是 definer（不能有 security_invoker=true）
select c.relname as 檢視表,
       case when coalesce(c.reloptions::text,'') like '%security_invoker=true%'
            then 'invoker ☢️ 不對' else 'definer ✓' end as 模式
from pg_class c join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public' and c.relkind = 'v'
  and c.relname in ('staff_signups','staff_customers');
