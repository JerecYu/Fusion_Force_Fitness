-- ═══════════════════════════════════════════════════════════════
--  31-legacy-vault.sql  ·  封存堂數等候區
--  2026-08-17
--
--  Jerec 整理孤兒名單時的實務判斷（原話）：
--    「資料中許多客人雖然留有剩餘堂數，但其實都不會再來消費了……
--      不來的原因可能是長期移民、搬家、甚至不喜歡我們而不來，
--      而這些變數是資料中不會知道的，只能人工判斷。」
--
--  所以 65 位孤兒分成三種：
--    ① 今天卡住綁定的           → 優先處理
--    ② 近期有機會再來的         → 主動補齊手機並綁定（走 db/30 的匯入）
--    ③ 近期確定不會再來的       → 【這一支】。資料先封存，堂數仍然有效，
--                                 人出現時再調出來。
--
--  ☢️ 第三種【絕對不能】留在 Excel 裡。
--     孤兒之所以存在，就是因為當初有人把「資料不齊的人」放在系統
--     【外面】的一個資料夾，交接時就忘了。留在 Excel 等於用同樣的
--     方式製造下一批孤兒 —— 只是這次是我們自己做的。
--     所以他們進系統，只是不進 customers。
--
--  ☢️ 而這張表真正的價值不是「存起來」，是【教練查名字時系統會自己講】。
--     只放在檔案裡的話，要靠人記得去翻 —— 而那正是失敗過一次的做法。
-- ═══════════════════════════════════════════════════════════════

create table if not exists public.legacy_credits (
  id            uuid primary key default gen_random_uuid(),
  name          text        not null,
  credits       integer     not null check (credits > 0),
  product       text        not null default 'GT',
  note          text,
  source        text,                                   -- 例如「舊表第 145 列」
  created_at    timestamptz not null default now(),
  created_by    uuid references public.employees(id),
  -- ☢️ 被領走之後【不刪】，只標記被誰領走、什麼時候 —— 事後查得到。
  claimed_customer_id uuid references public.customers(id),
  claimed_at    timestamptz,
  claimed_by    uuid references public.employees(id)
);

comment on table public.legacy_credits is
  '封存堂數等候區：舊表上還有餘課、但人近期不會再來的。☢️ 沒有手機、不是客人、不能訂課；堂數仍然有效，人出現時再轉進 credit_ledger。';

create index if not exists legacy_credits_open
  on public.legacy_credits (name) where claimed_at is null;

alter table public.legacy_credits enable row level security;

-- ☢️ 沒有 insert / update policy —— 只能走底下兩支函式。
drop policy if exists "員工可讀封存區" on public.legacy_credits;
create policy "員工可讀封存區" on public.legacy_credits
  for select using ( public.is_staff() );

grant select on public.legacy_credits to authenticated;

-- ── ① 批次封存（只有姓名和堂數，沒有手機）────────────────────
create or replace function public.import_legacy_vault(p_rows jsonb, p_dry_run boolean default true)
returns jsonb
language plpgsql security definer set search_path = public as $$
declare r jsonb; v_name text; v_credits int; v_i int := 0;
        v_errors jsonb := '[]'::jsonb; v_warn jsonb := '[]'::jsonb;
        v_total int := 0; v_near record; v_seen text[] := '{}';
begin
  if not public.is_owner() then raise exception '只有負責人可以批次封存'; end if;

  for r in select * from jsonb_array_elements(p_rows) loop
    v_i := v_i + 1;
    v_name := btrim(coalesce(r->>'name',''));
    v_credits := coalesce((r->>'credits')::int, 0);

    if length(regexp_replace(v_name,'[\s　]','','g')) < 2 then
      v_errors := v_errors || jsonb_build_object('i',v_i,'name',v_name,'why','姓名少於兩個字'); end if;
    if v_credits <= 0 then
      v_errors := v_errors || jsonb_build_object('i',v_i,'name',v_name,'why','堂數要大於 0'); end if;
    if lower(regexp_replace(v_name,'[\s　]','','g')) = any(v_seen) then
      v_errors := v_errors || jsonb_build_object('i',v_i,'name',v_name,'why','這個名字在同一批裡出現兩次'); end if;
    v_seen := v_seen || lower(regexp_replace(v_name,'[\s　]','','g'));

    -- ☢️ 封存之前先看系統裡有沒有這個人。有的話就不該封存 ——
    --    他已經是客人了，堂數應該直接補給他。
    for v_near in
      select c.name, right(c.phone,3) as tail from public.customers c
      where c.is_active and public.name_close(v_name, c.name) limit 2
    loop
      v_warn := v_warn || jsonb_build_object('i',v_i,'name',v_name,
                  'looks_like', v_near.name||'（'||v_near.tail||'）',
                  'why','☢️ 系統裡已經有名字很像的客人。如果是同一個人，堂數應該直接補給他，不要封存。');
    end loop;

    if exists (select 1 from public.legacy_credits l
               where l.claimed_at is null and public.name_close(v_name, l.name)) then
      v_warn := v_warn || jsonb_build_object('i',v_i,'name',v_name,
                  'why','☢️ 封存區裡已經有同名的，確認不是重複封存。');
    end if;

    v_total := v_total + v_credits;
  end loop;

  if jsonb_array_length(v_errors) > 0 then
    return jsonb_build_object('ok',false,'wrote',false,
      'why','有 '||jsonb_array_length(v_errors)||' 列不合格，整批都沒有寫入','errors',v_errors);
  end if;
  if p_dry_run then
    return jsonb_build_object('ok',true,'wrote',false,'dry_run',true,
      'rows',v_i,'credits_total',v_total,'warnings',v_warn);
  end if;

  insert into public.legacy_credits (name, credits, product, note, source, created_by)
  select btrim(x->>'name'), (x->>'credits')::int, 'GT',
         '舊表期初結轉（封存）', coalesce(x->>'source','舊表'), public.my_employee_id()
  from jsonb_array_elements(p_rows) x;

  return jsonb_build_object('ok',true,'wrote',true,'rows',v_i,'credits_total',v_total,
    'warnings',v_warn,
    'vault_open', (select count(*) from public.legacy_credits where claimed_at is null),
    'vault_credits', (select coalesce(sum(credits),0) from public.legacy_credits where claimed_at is null));
end $$;

revoke all on function public.import_legacy_vault(jsonb, boolean) from public;
grant execute on function public.import_legacy_vault(jsonb, boolean) to authenticated;

-- ── ② 人出現了：把封存的堂數轉給一位真的客人 ──────────────────
--  ☢️ 這是動到錢的入口，規矩跟課購一樣：走函式、記是誰做的、不刪東西。
create or replace function public.claim_legacy(p_legacy uuid, p_customer uuid)
returns jsonb
language plpgsql security definer set search_path = public as $$
declare v_l record; v_c record; v_bal int;
begin
  -- 教練就能做 —— 人站在櫃檯前面，不該等 Jerec 有空。
  if not public.is_staff() then raise exception '只有員工可以轉入封存堂數'; end if;

  select * into v_l from public.legacy_credits where id = p_legacy;
  if not found then return jsonb_build_object('ok',false,'why','not_found'); end if;
  -- ☢️ 已經領過的不能再領一次，否則同一筆堂數會被發兩份。
  if v_l.claimed_at is not null then
    return jsonb_build_object('ok',false,'why','already_claimed',
      'claimed_at', to_char(v_l.claimed_at at time zone 'Asia/Taipei','MM/DD HH24:MI'));
  end if;

  select id, name, is_active into v_c from public.customers where id = p_customer;
  if not found then return jsonb_build_object('ok',false,'why','no_customer'); end if;
  if v_c.is_active = false then return jsonb_build_object('ok',false,'why','inactive'); end if;

  -- ☢️ amount 留 null —— 封存的堂數我們不知道當時收多少錢。
  insert into public.credit_ledger (customer_id, delta, reason, product, note, created_by)
  values (p_customer, v_l.credits, 'purchase', v_l.product,
          '封存堂數轉入（' || v_l.name || '）', public.my_employee_id());

  update public.legacy_credits
     set claimed_customer_id = p_customer, claimed_at = now(), claimed_by = public.my_employee_id()
   where id = p_legacy;

  select coalesce(sum(delta),0) into v_bal
  from public.credit_ledger where customer_id = p_customer and product = v_l.product;

  return jsonb_build_object('ok',true,'legacy_name',v_l.name,'name',v_c.name,
    'credits',v_l.credits,'balance',v_bal);
end $$;

revoke all on function public.claim_legacy(uuid, uuid) from public;
grant execute on function public.claim_legacy(uuid, uuid) to authenticated;

-- ── ③ 教練查客人時要看得到的封存清單 ──────────────────────────
--  ☢️ definer，不要加 security_invoker（牆是 is_staff()，見 db/25）
create or replace view public.staff_legacy as
select l.id as legacy_id, l.name, l.credits, l.product, l.source, l.created_at,
       (l.claimed_at is not null) as claimed,
       c.name as claimed_by_customer,
       to_char(l.claimed_at at time zone 'Asia/Taipei','MM/DD HH24:MI') as claimed_when
from public.legacy_credits l
left join public.customers c on c.id = l.claimed_customer_id
where public.is_staff();

grant select on public.staff_legacy to authenticated;

-- ── 驗收（2026-08-17 實測）─────────────────────────────────────
--  · 預演時正確警告「林屏玟 ↔ 系統裡的林屏妏（650）」→ 這種不該封存 ✓
--  · 封存一筆 8 堂 → 轉給林正明 → 他從 0 變 8 堂 ✓
--  · 清乾淨後回到 0 筆封存、GT 總堂數 551 ✓
--  · 前端：查「王淑文」→ 系統裡沒有這個人，但封存卡跳出來、並提示
--    「請先建檔再回來轉」；建檔之後同一個查詢就出現「轉給 王淑文（222）」，
--    按下去餘額 0 → 9 堂，卡片變綠、按鈕鎖住；再查一次那筆封存不再出現 ✓
