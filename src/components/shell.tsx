import Link from 'next/link';
import { copy } from '@/lib/copy';
export function Shell({children}:{children:React.ReactNode}) {return <div className="shell"><aside className="sidebar"><Link href="/dashboard" className="brand">◒ {copy.brand}</Link><br/><small className="muted">{copy.tagline}</small><nav aria-label="Main navigation"><Link href="/dashboard">Home</Link><Link href="/groups">Groups</Link><Link href="/profile">Profile</Link></nav></aside><main id="main">{children}</main></div>;}
