import 'server-only';
import { redirect } from 'next/navigation';
import { db } from '../db/server';
export async function session(next='/dashboard') { const client=await db(); const {data:{user},error}=await client.auth.getUser(); if(error || !user) redirect('/login?next='+encodeURIComponent(next)); return {client,user}; }
