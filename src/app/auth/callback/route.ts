import { NextResponse, type NextRequest } from 'next/server';
import { db } from '@/lib/db/server';
import { safeNext } from '@/lib/validation';
export async function GET(request:NextRequest) {const url=new URL(request.url);const client=await db();const token=url.searchParams.get('token_hash');const code=url.searchParams.get('code');const result=token?await client.auth.verifyOtp({token_hash:token,type:'email'}):code?await client.auth.exchangeCodeForSession(code):null;const origin=process.env.APP_URL || url.origin;return NextResponse.redirect(new URL(result && !result.error?safeNext(url.searchParams.get('next')):'/login?error=expired',origin));}
