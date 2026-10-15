 'use server';
import { revalidatePath } from 'next/cache';
import { redirect } from 'next/navigation';
import { randomBytes, createHash } from 'node:crypto';
import { z } from 'zod';
import { session } from '@/lib/auth/session';
import { sealContact } from '@/lib/contacts';
import { name, friendInput, tokenInput } from '@/lib/validation';
import type { Result } from '@/components/form';
function message(error:{message:string;code?:string}|null):Result {if(!error)return {success:'Saved.'};if(error.message.includes('rate_limit'))return {error:'Too many requests. Please wait an hour and try again.'};if(error.message.includes('unavailable'))return {error:'This invitation or group is unavailable, expired, or revoked.'};return {error:'Unable to save. Check your access and try again.'};}
async function rpc(fn:string,args:Record<string,unknown>,path='/groups'):Promise<Result> {const {client}=await session();const {error}=await client.rpc(fn,args);if(!error)revalidatePath(path,'layout');return message(error);}
function id(value:FormDataEntryValue|null){return z.uuid().parse(value);}
export async function createGroup(_:Result,data:FormData):Promise<Result>{const parsed=name.safeParse(data.get('name'));if(!parsed.success)return {error:'Enter a group name between 1 and 80 characters.'};const {client}=await session();const {data:group,error}=await client.rpc('create_group',{p_name:parsed.data});if(error)return message(error);revalidatePath('/groups');redirect('/groups/'+group);}
export async function renameGroup(_:Result,data:FormData):Promise<Result>{const parsed=name.safeParse(data.get('name'));if(!parsed.success)return {error:'Enter a group name between 1 and 80 characters.'};return rpc('rename_group',{p_group:id(data.get('group_id')),p_name:parsed.data});}
export async function addFriend(_:Result,data:FormData):Promise<Result>{const parsed=friendInput.safeParse(Object.fromEntries(data));if(!parsed.success)return {error:parsed.error.issues[0].message};let encrypted=null;try{if(parsed.data.contact)encrypted=sealContact(parsed.data.contact);}catch(error){return {error:(error as Error).message};}return rpc('add_friend',{p_group:id(data.get('group_id')),p_name:parsed.data.display_name,p_contact:encrypted});}
export async function saveProfile(_:Result,data:FormData):Promise<Result>{const parsed=name.safeParse(data.get('display_name'));if(!parsed.success)return {error:'Enter a display name between 1 and 80 characters.'};return rpc('update_profile',{p_name:parsed.data},'/');}
export async function signout(){const {client}=await session();await client.auth.signOut();redirect('/login');}
export async function issueInvite(_:Result,data:FormData):Promise<Result>{const {client}=await session();const token=randomBytes(32).toString('hex');const {error}=await client.rpc('issue_group_invite',{p_group:id(data.get('group_id')),p_hash:createHash('sha256').update(token).digest('hex')});if(error)return message(error);revalidatePath('/groups');return {success:'Invitation created. No email was sent.',link:new URL('/invite/'+token,process.env.APP_URL || 'http://localhost:3000').toString()};}
export async function revokeInvite(_:Result,data:FormData):Promise<Result>{return rpc('revoke_group_invite',{p_invite:id(data.get('invite_id'))});}
export async function redeemInvite(_:Result,data:FormData):Promise<Result>{const parsed=tokenInput.safeParse(data.get('token'));if(!parsed.success)return {error:'This invitation is unavailable.'};const {client}=await session('/invite/'+parsed.data);const {data:group,error}=await client.rpc('redeem_group_invite',{p_hash:createHash('sha256').update(parsed.data).digest('hex')});if(error)return message(error);revalidatePath('/groups');redirect('/groups/'+group);}
export async function removeMember(_:Result,data:FormData):Promise<Result>{return rpc('remove_group_member',{p_group:id(data.get('group_id')),p_person:id(data.get('person_id'))});}
export async function transferOwner(_:Result,data:FormData):Promise<Result>{return rpc('transfer_group_owner',{p_group:id(data.get('group_id')),p_person:id(data.get('person_id'))});}
export async function leaveGroup(_:Result,data:FormData):Promise<Result>{const result=await rpc('leave_group',{p_group:id(data.get('group_id'))});if(result.error)return result;redirect('/groups');}
