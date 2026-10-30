import {createClient} from '@supabase/supabase-js';
export const runtime='nodejs';
export async function GET(_:Request,{params}:{params:Promise<{token:string}>}){
 try{const {token}=await params;const url=process.env.NEXT_PUBLIC_SUPABASE_URL,key=process.env.SUPABASE_SECRET_KEY;if(!url||!key)return new Response('Server is not configured.',{status:503});
 const db=createClient(url,key,{auth:{persistSession:false,autoRefreshToken:false}});const {data:share,error}=await db.from('shares').select('node_id,expires_at').eq('token',token).maybeSingle();
 if(error||!share||new Date(share.expires_at)<=new Date())return new Response('This share link is invalid or expired.',{status:404});
 const {data:node}=await db.from('cloud_nodes').select('storage_path,name,kind,trashed_at').eq('id',share.node_id).maybeSingle();if(!node||node.kind!=='file'||node.trashed_at)return new Response('The shared file is unavailable.',{status:404});
 const {data:signed,error:serr}=await db.storage.from('cloud-files').createSignedUrl(node.storage_path,60,{download:node.name});if(serr||!signed)return new Response('Could not create a download.',{status:500});return Response.redirect(signed.signedUrl,302);
 }catch{return new Response('Share link failed.',{status:500})}}
