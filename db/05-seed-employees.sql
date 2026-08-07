insert into employees (name, display_name, role) values
  ('簡基城', '簡基城',  'coach'),
  ('于郅弘', 'Jerec',   'owner'),
  ('王韻茹', 'Jessica', 'coach'),
  ('穆孝偉', 'VC',      'coach'),
  ('謝原',   'Peter',   'coach'),
  ('饒誠',   'Johnson', 'coach');

-- 確認寫進去了
select display_name, name, role, is_active from employees order by created_at;