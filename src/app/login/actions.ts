 'use server';
import { z } from 'zod';
import { db } from '@/lib/db/server';
import { safeNext } from '@/lib/validation';
import type { Result } from '@/components/form';
export async function login(_:Result,data:FormData):Promise<Result> {const email=z.email().safeParse(data.get('email'));if(!email.success)return {error:'Enter a valid email address.'}; const url=new URL('/auth/callback',process.env.APP_URL || 'http://localhost:3000');url.searchParams.set('next',safeNext(data.get('next')));const client=await db();const {error}=await client.auth.signInWithOtp({email:email.data,options:{emailRedirectTo:url.toString()}});return error?{error:'Unable to send a sign-in link. Please wait and try again.'}:{success:'Check your inbox for a private sign-in link. It may take a minute.'};}
