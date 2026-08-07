-- 檢查工具：確認所有資料表都有開啟 RLS 並且有規則
-- 可重複執行，不會改動任何資料
-- 每次新增資料表後都跑一次
select
  c.relname                          as 資料表,
  case when c.relrowsecurity
       then '✅ 已上鎖' else '❌ 未上鎖' end as RLS,
  count(p.polname)                   as 規則數
from pg_class c
left join pg_policy p on p.polrelid = c.oid
where c.relnamespace = 'public'::regnamespace
  and c.relkind = 'r'
group by c.relname, c.relrowsecurity
order by c.relname;