-- 49｜人工核對後的個別更正（1 位客人，＋1 堂）
--
-- 第 48 步把「舊系統凍結當下的餘額」定為真相，71/72 人對得上。
-- 但舊系統的『期初』本身也只是 08/01 從舊表抄過去的一個數字 ——
-- 抄錯的話，拿舊系統當基準的對帳永遠抓不到，因為基準就是錯的那個。
--
-- 這一位就是。三份資料三個數字：
--
--   舊 ERP 期初（08/01）    1 堂   ← 08/16 凍結前她完全沒有異動，只有一筆取消的預約
--   手寫流水帳（07/04 最後一列 9/12）  3 堂
--   Jerec 08/20 再次人工核對「最新紀錄」   2 堂   ← 採用這個
--
-- 只有認得客人的人能判斷，系統判斷不了。所以這一步沒有通則，就是照人工核對改。

begin;

do $$
declare v_bal int;
begin
  select coalesce(sum(delta), 0) into v_bal
  from public.credit_ledger
  where customer_id = 'fd63c17c-471a-4cb9-9639-4d94da1bfff4' and product = 'GT';

  if v_bal <> 1 then
    raise exception '☢️ 預期目前 1 堂，實際 % 堂 —— 這支只能在第 48 步之後、而且沒有其他異動時跑', v_bal;
  end if;
end $$;

insert into public.credit_ledger (customer_id, delta, reason, product, note)
values ('fd63c17c-471a-4cb9-9639-4d94da1bfff4', 1, 'adjust', 'GT',
        '人工核對更正：舊 ERP 期初登記 1 堂，Jerec 核對舊表最新紀錄為 2 堂，補 1 堂');

commit;

-- ── 驗收 ────────────────────────────────────────────────────
-- 這位客人餘課 1 → 2；全系統 GT 總堂數 624 → 625。
--
-- select coalesce(sum(delta),0) from public.credit_ledger
-- where customer_id='fd63c17c-471a-4cb9-9639-4d94da1bfff4' and product='GT';
