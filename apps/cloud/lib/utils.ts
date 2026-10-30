export const MAX_FILE_SIZE=50*1024*1024;
const blocked=new Set(['html','htm','svg','js','mjs','exe','dll','sh','bat','cmd','ps1']);
export function safeName(name:string){const clean=name.normalize('NFKC').replace(/[\\/\0]/g,'_').replace(/\s+/g,' ').trim().slice(0,180);if(!clean)throw new Error('The file name is empty.');const ext=clean.split('.').pop()?.toLowerCase()||'';if(blocked.has(ext))throw new Error(`.${ext} files are blocked in this prototype.`);return clean}
export function validateFile(file:File){if(!file.size)throw new Error('Empty files are not accepted.');if(file.size>MAX_FILE_SIZE)throw new Error('Nimbus accepts files up to 50 MiB.');return safeName(file.name)}
export function bytes(n:number){if(!Number.isFinite(n)||n<1)return '0 B';const u=['B','KiB','MiB','GiB'];const i=Math.min(Math.floor(Math.log(n)/Math.log(1024)),u.length-1);return `${(n/1024**i).toFixed(i?1:0)} ${u[i]}`}
export function message(e:any){return e?.message||'Something went wrong. Please try again.'}
