-- ═══════════════════════════════════════════════════════════════════
-- db/78-legacy-hint.sql — 「這位客人可能有沒認領的封存堂數」
--
-- 專案：FFF 預約系統（fff-platform）· 2026-08-23
--
-- ☢️☢️ 起因：張詩佩 2026-08-22 綁定 LINE，系統開了一筆【全新的空白資料】，
--    她看到 0 堂，半夜傳訊息來問。她的 12 堂一直都在封存區 ——
--    只是【沒有任何地方告訴任何人這件事】。
--
--    封存區的認領介面早就有了（staff-tools 用名字搜就會跳出來），
--    但它只有在【有人主動去搜那個名字】的時候才會動。
--    ☢️ 沒有人會去搜一個自己不知道存在的名字。
--    所以真正缺的不是功能，是【提示】。
--
-- ══ 被動原則（Jerec 2026-08-23 決定）═══════════════════════════
-- ☢️ 封存認領一律【被動】：系統只負責【講出來】，不負責【給出去】。
--    · 不自動認領。堂數轉給誰永遠是人按的。
--    · 不主動聯絡客人說「你還有堂數喔」。
--    · ☢️ 客人自己的畫面【看不到】這個提示 —— 客人端寫著
--      「你有 12 堂在封存區」等於是在邀請他來領，那就不是被動了。
--    這張檢視表因此是【員工才看得到】的。
--
-- ══ 配對規則：寧可漏，不可錯 ═══════════════════════════════════
-- ☢️ 認錯人＝把別人的堂數送出去，而且送出去之後看起來完全正常。
--    所以分兩級，而且【英文暱稱對上不算數】：
--
--    exact ＝ 中文姓名真的對上（「賴素玲 Doreen」對「賴素玲」）
--    nick  ＝ ☢️ 只有英文暱稱一樣，中文姓名不同
--
--    實測那四組 nick 全部是不同人：
--      吳佳玲 Ivy／王禎苡 Ivy、楊小寧 Joanne／楊淑瓊 Joanne、
--      陳怡萱 Joyce／朱友琪 Joyce、郭綺晴 Sunny／沈玲 Sunny
--    ☢️ 但還是要列出來，不能直接丟掉 —— 改過名字、或舊本子只寫
--       英文名的情況真的存在。列出來但標成低信心，讓人決定。
--
-- ══ 誰排在最前面 ═══════════════════════════════════════════════
-- ☢️ 【已經綁定 LINE 的排最前面】。那些人現在打開手機就看到 0 堂，
--    是下一個會傳訊息來問的人。沒綁定的還不知道有這回事。
-- ═══════════════════════════════════════════════════════════════════

create or replace view public.staff_legacy_hint as
select
  v.id                                   as legacy_id,
  v.name                                 as legacy_name,
  v.credits                              as credits,
  v.product                              as product,
  coalesce(v.source, '舊表')             as source,
  c.id                                   as customer_id,
  c.name                                 as customer_name,
  coalesce(c.nickname, '')               as nickname,
  right(c.phone, 3)                      as phone_tail,
  (c.auth_user_id is not null)           as bound,
  (select coalesce(sum(l.delta), 0) from public.credit_ledger l
    where l.customer_id = c.id and l.product = v.product) as now_balance,
  case
    when v.name = c.name                 then 'exact'
    when v.name like c.name || ' %'      then 'exact'
    else 'nick'
  end                                    as confidence
from public.legacy_credits v
join public.customers c
  on c.is_active
 and (
      v.name = c.name
   or v.name like c.name || ' %'
   -- ☢️ 暱稱要至少兩個字才拿來比。一個字的暱稱（「安」「玲」）
   --    會對上一大片人，那種提示等於雜訊，而雜訊會讓人開始忽略提示。
   or (c.nickname is not null and length(c.nickname) >= 2
       and v.name like '%' || c.nickname || '%')
 )
where v.claimed_customer_id is null
  and public.is_staff()
order by (c.auth_user_id is not null) desc,
         (case when v.name = c.name or v.name like c.name || ' %' then 0 else 1 end),
         v.credits desc;

grant select on public.staff_legacy_hint to authenticated;

comment on view public.staff_legacy_hint is
  '沒認領的封存堂數，配上系統裡可能是同一個人的客人。'
  '☢️ 只是【提示】，不會自動認領 —— 轉給誰永遠是人按的（被動原則）。'
  '☢️ confidence=nick 代表只有英文暱稱一樣，實測幾乎都是不同人。';
