-- ═══════════════════════════════════════════════════════════════════
-- 36 — 一筆預約可以是多個人（第 64 步）＋ 看得到同學是誰（第 65 步）
--
-- 專案：FFF 預約系統（fff-platform）· 2026-08-18
--
-- 起因（Jerec）：
--   吳佳芳想幫兩位兒子報名 8/19 的 GT，系統擋下來說只能報一人。
--   而且「有時候三位一起上，有時候只有兩個兒子上」。
--
-- ═══ 第一件事：把「另外帶了 N 位」改成「這一筆共幾人上課」 ═══
--
-- 舊模型：guest_count = 除了本人以外還帶幾個，扣 (1 + guest_count) 堂。
-- ☢️ 它假設了「本人一定會來」。吳佳芳不來、只有兩個兒子來的時候，
--    教練得把她標成出席才扣得到堂 —— 標「帶 2 位」會扣 3 堂，
--    但現場只有 2 個人。要扣對就得填「帶 1 位」，
--    於是紀錄上寫著「她來了 ＋ 帶 1 人」，而那是假的。
--    ☢️ 要靠心算才填得對的欄位遲早會填錯 —— 而且錯的是錢。
--
-- 新模型：attendee_count = 這一筆總共幾個人上課（預設 1），扣一樣多堂。
--   三人都來 → 3 → 扣 3　　只有兩個兒子 → 2 → 扣 2　　只有她 → 1 → 扣 1
--
-- ☢️ 「出席」的意思跟著變：從「吳佳芳本人有沒有來」變成
--    「這個名額有沒有被用到」。而堂數帳本來關心的就是後者 ——
--    舊模型其實也沒真的在追蹤本人有沒有到（她本來就可以派人來）。
--
-- ☢️☢️ 為什麼是【改名 ＋ 搬資料】而不是「沿用同一欄、改變意思」：
--    同一個欄位換意思，是這個專案能犯的最貴的錯 ——
--    舊資料還躺在那裡，數字沒變，意思卻變了，而且【不會有任何錯誤】。
--    改名之後，任何還在讀 guest_count 的地方會【當場壞掉】，
--    那正是我要的：壞掉看得見，意思悄悄改掉看不見。
--
-- ═══ 第二件事：報名後看得到同學（局部遮蔽姓名） ═══
--
-- 客人希望「報名時知道還有誰報這堂」。做成遮蔽姓名：吳〇芳、林〇明。
-- ☢️ 只有【自己也報了這一堂】的人看得到，而且看不到手機、堂數、任何其他資料。
-- ═══════════════════════════════════════════════════════════════════


-- ── ① 欄位改名並搬資料 ────────────────────────────────────────────
-- ☢️ 順序不能換：先改名 → 再 +1 → 再設預設 → 最後換檢查條件。
--    先設 default 1 的話，接下來的 +1 會把新寫入的列也算進去。
alter table public.bookings rename column guest_count to attendee_count;

-- 舊值是「額外的人數」，新值是「總人數」= 舊值 + 本人
update public.bookings set attendee_count = coalesce(attendee_count, 0) + 1;

alter table public.bookings alter column attendee_count set default 1;
alter table public.bookings alter column attendee_count set not null;

alter table public.bookings drop constraint if exists bookings_guest_count_sane;
alter table public.bookings add constraint bookings_attendee_count_sane
  check (attendee_count >= 1 and attendee_count <= 6);

comment on column public.bookings.attendee_count is
  '這一筆預約總共幾個人上課（含本人，預設 1）。點名出席時就扣這麼多堂，扣在 paid_by_customer_id 頭上。';


-- ── ② 遮蔽姓名 ────────────────────────────────────────────────────
create or replace function public.mask_name(p_name text)
returns text language sql immutable set search_path = public as $$
  with t as (select btrim(coalesce(p_name, '')) as s),
       z as (select s, substring(s from '[一-龥]+') as cn from t)
  select case
    when s = ''                      then '（未填姓名）'
    -- 完全沒有中文 → 英文名或綽號：首字母 + ***
    when cn is null                  then left(s, 1) || '***'
    -- ☢️ 只取【第一段連續的中文】，後面的英文整段丟掉。
    --    93 位客人裡有 18 位是「中文名 ＋ 英文名」（例如「吳弘琳 Wendy」），
    --    整串逐字遮會變成「吳〇〇〇〇〇〇〇y」—— 又醜又沒有比較安全，
    --    而且尾巴那個 y 反而把英文名洩出來了。取中文段之後是「吳〇琳」。
    when length(cn) = 1              then cn || '〇'
    when length(cn) = 2              then left(cn, 1) || '〇'
    else left(cn, 1) || repeat('〇', length(cn) - 2) || right(cn, 1)
  end
  from z;
$$;

comment on function public.mask_name(text) is
  '把姓名遮成 吳〇芳。混中英文的名字只取中文那一段。只給「同一堂課的同學名單」用。';


-- ── ③ 同一堂課有誰（遮蔽版） ──────────────────────────────────────
-- ☢️ 三道門，缺一不可：
--    ① 必須是已綁定的客人（my_customer_id() 不是 null）
--    ② 必須【自己也報了這一堂】—— 否則這支就變成「輸入課程編號
--       就能查出全館誰在上課」的工具
--    ③ 只回傳遮蔽後的姓名和人數，手機／堂數／狀態一律不給
create or replace function public.session_mates(p_session uuid)
returns table (masked_name text, n integer, is_me boolean)
language plpgsql stable security definer set search_path = public as $$
declare v_me uuid;
begin
  v_me := public.my_customer_id();
  if v_me is null then
    raise exception '要先綁定手機才看得到同學名單';
  end if;

  if not exists (
    select 1 from public.bookings b
     where b.session_id = p_session
       and b.customer_id = v_me
       and b.status in ('booked', 'attended')
  ) then
    raise exception '你還沒報名這一堂';
  end if;

  return query
    select public.mask_name(c.name),
           b.attendee_count::integer,
           (b.customer_id = v_me)
      from public.bookings b
      join public.customers c on c.id = b.customer_id
     where b.session_id = p_session
       and b.status in ('booked', 'attended')
     order by b.booked_at;
end $$;

comment on function public.session_mates(uuid) is
  '同一堂課還有誰報名（姓名遮蔽）。只有自己也報了這一堂的人叫得動。';

revoke all on function public.session_mates(uuid) from public, anon;
grant execute on function public.session_mates(uuid) to authenticated;


-- ── ④ 點名：扣 attendee_count 堂 ──────────────────────────────────
-- （完整內容見資料庫；與 db/33 的版本只差 v_target 那一行和備註文字）
-- v_target := case when p_present then -greatest(coalesce(v_b.attendee_count, 1), 1) else 0 end;


-- ── ⑤ 改人數 ──────────────────────────────────────────────────────
-- ☢️ 舊的 set_guests 直接【刪掉】，不留相容層。
--    留著的話前端有一支還在傳「額外人數」、另一支傳「總人數」，
--    兩邊都不會報錯，而錯的是扣幾堂。
drop function if exists public.set_guests(uuid, smallint);
-- create or replace function public.set_attendees(p_booking uuid, p_n smallint) …（見資料庫）


-- ── ⑥ 檢視表 ──────────────────────────────────────────────────────
-- staff_roster        ：guest_count → attendee_count（drop + create，不能 replace）
-- public_schedule     ：booked_count 從 count(*) 改成 sum(attendee_count)
-- gt_payout_sessions  ：n_present 從 sum(1+guest_count) 改成 sum(attendee_count)
--
-- ☢️ 名額要數【人】不是數【筆】。舊版 booked_count = count(bookings)，
--    所以吳佳芳帶兩個兒子在課表上只佔 1 個位子，而現場會坐 3 個人 ——
--    課表會說「還有空位」，教室其實已經滿了。
