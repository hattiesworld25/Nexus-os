import test from 'node:test';import assert from 'node:assert/strict';
function safeSQL(sql){const s=sql.trim().replace(/;\s*$/,'');if(!s)throw new Error('empty');if(s.includes(';'))throw new Error('multi');if(!/^(select|with|explain|describe|show|summarize)\b/i.test(s))throw new Error('readonly');if(/\b(attach|detach|copy|install|load|call|pragma|export|import|create|drop|alter|insert|update|delete|merge|vacuum|checkpoint|force_install)\b/i.test(s))throw new Error('blocked');return s}
test('allows read-only SQL',()=>assert.equal(safeSQL('SELECT 1;'),'SELECT 1'));
test('allows CTE',()=>assert.match(safeSQL('with x as (select 1) select * from x'),/^with/));
test('blocks mutations',()=>assert.throws(()=>safeSQL('delete from x')));
test('blocks stacked statements',()=>assert.throws(()=>safeSQL('select 1; drop table x')));
test('blocks attachment and extensions',()=>{assert.throws(()=>safeSQL("attach 'x'"));assert.throws(()=>safeSQL('INSTALL httpfs'))});
