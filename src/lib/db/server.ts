import 'server-only';
import { createServerClient } from '@supabase/ssr';
import { cookies } from 'next/headers';
export async function db() {
 const jar=await cookies();
 const url=process.env.NEXT_PUBLIC_SUPABASE_URL; const key=process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY;
 if(!url || !key) throw new Error('Configure Supabase using .env.example before starting Together.');
 return createServerClient(url,key,{cookies:{getAll:()=>jar.getAll(),setAll:(values)=>{try {values.forEach(({name,value,options})=>jar.set(name,value,options));} catch { /* Server components cannot set cookies; proxy refreshes them. */ }}}});
}
