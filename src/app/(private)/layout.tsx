import { Shell } from '@/components/shell';
import { session } from '@/lib/auth/session';
export const dynamic='force-dynamic';
export default async function Layout({children}:{children:React.ReactNode}){await session();return <Shell>{children}</Shell>;}
