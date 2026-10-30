import {createClient} from '@supabase/supabase-js';
export const runtime='nodejs';
function textOf(data:any){if(typeof data.output_text==='string')return data.output_text;for(const item of data.output||[])for(const c of item.content||[])if(c.type==='output_text'&&c.text)return c.text;return ''}
export async function POST(req:Request){
 try{
  const url=process.env.NEXT_PUBLIC_SUPABASE_URL,key=process.env.SUPABASE_SECRET_KEY,ai=process.env.OPENAI_API_KEY,model=process.env.OPENAI_MODEL;
  if(!url||!key) return Response.json({error:'Server Supabase credentials are not configured.'},{status:503});
  if(!ai||!model) return Response.json({error:'AI is optional and not configured. Set OPENAI_API_KEY and OPENAI_MODEL on the server.'},{status:503});
  const token=(req.headers.get('authorization')||'').replace(/^Bearer\s+/i,'');
  const db=createClient(url,key,{auth:{persistSession:false,autoRefreshToken:false}});
  const {data:{user},error:uerr}=await db.auth.getUser(token); if(uerr||!user)return Response.json({error:'Sign in again.'},{status:401});
  const limit=Math.min(Math.max(Number(process.env.AI_DAILY_LIMIT||20),1),100);
  const {data:allowed,error:rerr}=await db.rpc('reserve_ai_call',{p_user:user.id,p_limit:limit});
  if(rerr)throw rerr;if(!allowed)return Response.json({error:'Daily AI limit reached.'},{status:429});
  const body=await req.json();const question=String(body.question||'').trim().slice(0,1200);const context=String(body.context||'').slice(0,12000);
  if(!question)return Response.json({error:'Enter a question.'},{status:400});
  const upstream=await fetch('https://api.openai.com/v1/responses',{method:'POST',headers:{'Authorization':`Bearer ${ai}`,'Content-Type':'application/json'},body:JSON.stringify({model,store:false,max_output_tokens:500,instructions:'You are Nimbus Assistant. Answer concisely using only the supplied user-owned metadata. Never claim to have changed data. If context is insufficient, say so.',input:`Context:\n${context}\n\nQuestion: ${question}`})});
  const data=await upstream.json();if(!upstream.ok)throw new Error(data?.error?.message||'AI provider request failed.');const answer=textOf(data);if(!answer)throw new Error('AI provider returned no text.');
  return Response.json({answer});
 }catch(e:any){return Response.json({error:e?.message||'Assistant failed.'},{status:500})}
}
