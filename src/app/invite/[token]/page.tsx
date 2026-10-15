import { session } from '@/lib/auth/session';
import { tokenInput } from '@/lib/validation';
import { Form } from '@/components/form';
import { redeemInvite } from '@/app/(private)/actions';
import { notFound } from 'next/navigation';
import { copy } from '@/lib/copy';
export const dynamic='force-dynamic';
export default async function Invite({params}:{params:Promise<{token:string}>}){const {token}=await params;if(!tokenInput.safeParse(token).success)notFound();await session('/invite/'+token);return <main id="main" className="auth"><p className="brand">◒ Together</p><section className="card"><h1>You’re invited</h1><p>{copy.inviteNotice}</p><p className="muted">Private group details appear after the server validates this invitation. Only join links from people you know.</p><Form action={redeemInvite} label="Join group"><input type="hidden" name="token" value={token}/></Form><a href="/groups">Back to your groups</a></section></main>;}
