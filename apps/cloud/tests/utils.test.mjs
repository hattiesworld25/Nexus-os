import test from 'node:test';import assert from 'node:assert/strict';
const blocked=new Set(['html','htm','svg','js','mjs','exe','dll','sh','bat','cmd','ps1']);
function safeName(name){const clean=name.normalize('NFKC').replace(/[\\/\0]/g,'_').replace(/\s+/g,' ').trim().slice(0,180);if(!clean)throw new Error('empty');const ext=clean.split('.').pop()?.toLowerCase()||'';if(blocked.has(ext))throw new Error('blocked');return clean}
test('normalizes paths',()=>assert.equal(safeName('../report final.pdf'),'.._report final.pdf'));
test('blocks active content',()=>assert.throws(()=>safeName('attack.HTML')));
test('blocks empty names',()=>assert.throws(()=>safeName('   ')));
