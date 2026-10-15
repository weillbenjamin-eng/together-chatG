import { session } from '@/lib/auth/session';
import { Form } from '@/components/form';
import { saveProfile,signout } from '../actions';
export default async function Profile(){const {client,user}=await session();const {data}=await client.from('users').select('display_name').eq('id',user.id).single();return <><h1>Your profile</h1><section className="card"><Form action={saveProfile} label="Save profile"><div><label htmlFor="display-name">Display name</label><input id="display-name" name="display_name" defaultValue={data?.display_name || 'Friend'} required maxLength={80}/></div></Form><p className="muted">Your name here applies to your account. Group-scoped friend identities remain separate.</p></section><form action={signout}><button className="quiet">Sign out</button></form></>;}
