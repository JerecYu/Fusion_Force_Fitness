-- 47｜期初結轉被記兩次：沖掉重複的那一筆
--
-- 現象：8 位客人的「期初剩餘堂數」被匯入了兩次
--   第一批 note='原團課堂數'（2026-08-02~08-07，來源＝舊 ERP FusionForceErp 的 PassLedger）
--   第二批 note='舊表期初結轉'（2026-08-18，來源＝團課流水帳 Excel＝舊表）
-- 第二批本來是要「更正」第一批的數字，卻被當成「再加一次」寫進去。
--
-- 以舊表為準（團課流水帳是實際手寫帳，比舊 ERP 完整）。
-- credit_ledger 是 append-only：不刪資料，用一筆負數 adjust 沖掉。

begin;

-- ── 1）先確認影響範圍，數字不對就整批停下 ────────────────────────
do $$
declare n int; s int;
begin
  select count(*), coalesce(sum(b1), 0) into n, s
  from (
    select l1.customer_id, sum(l1.delta) as b1
    from public.credit_ledger l1
    where l1.product = 'GT'
      and coalesce(l1.note, '') = '原團課堂數'
      and exists (
        select 1 from public.credit_ledger l2
        where l2.customer_id = l1.customer_id
          and l2.product = 'GT'
          and coalesce(l2.note, '') = '舊表期初結轉')
    group by 1
  ) t;

  if n <> 8 or s <> 66 then
    raise exception '☢️ 預期 8 人 / 66 堂，實際 % 人 / % 堂 —— 先停下來看清楚再跑', n, s;
  end if;
end $$;

-- ── 2）沖掉舊 ERP 那一筆 ──────────────────────────────────────
insert into public.credit_ledger (customer_id, delta, reason, product, note)
select l1.customer_id, -sum(l1.delta), 'adjust', 'GT',
       '☢️ 期初結轉重複：舊 ERP 與舊表各記了一次，這筆沖掉舊 ERP 的，以舊表為準'
from public.credit_ledger l1
where l1.product = 'GT'
  and coalesce(l1.note, '') = '原團課堂數'
  and exists (
    select 1 from public.credit_ledger l2
    where l2.customer_id = l1.customer_id
      and l2.product = 'GT'
      and coalesce(l2.note, '') = '舊表期初結轉')
group by l1.customer_id;

-- ── 3）分享次數要跟著減 ──────────────────────────────────────
-- 原本只算 delta > 0，負數的 adjust 算不進來，堂數退了但分享次數不會退。
-- 改成：正數一律算，adjust 不管正負都算（adjust 就是用來更正購課紀錄的）。
create or replace function public.gt_share_quota(p_customer uuid)
returns integer
language sql
stable
security definer
set search_path to 'public'
as $function$
  select (floor(coalesce(sum(delta), 0) / 12.0) * 2)::integer
  from public.credit_ledger
  where customer_id = p_customer
    and product = 'GT'
    and (delta > 0 or reason = 'adjust')
    and reason <> 'transfer_in';
$function$;

commit;

-- ── 驗收 ────────────────────────────────────────────────────
-- 期望：8 列，bal 分別是 33 / 10 / 8 / 8 / 7 / 5 / 5 / 2，沒有人是負的
--
-- select c.name, right(c.phone,3) as 末三碼,
--        sum(l.delta) as bal, public.gt_share_quota(c.id) as 可分享
-- from public.credit_ledger l
-- join public.customers c on c.id = l.customer_id
-- where l.product = 'GT'
--   and c.id in (select customer_id from public.credit_ledger
--                where product='GT' and coalesce(note,'')='舊表期初結轉')
--   and c.id in (select customer_id from public.credit_ledger
--                where product='GT' and coalesce(note,'')='原團課堂數')
-- group by c.id, c.name, c.phone
-- order by bal desc;
